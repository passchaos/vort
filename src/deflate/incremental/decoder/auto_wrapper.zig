//! Auto-detecting zlib-or-gzip incremental facade. Raw DEFLATE remains
//! explicit because it has no wrapper signature.
const std = @import("std");
const core = @import("../../../core.zig");
const Count = core.StreamCount;
const clone_storage = @import("../clone_storage.zig");
const step_borrows = @import("step_borrows.zig");
const dictionary_borrows = @import("dictionary_borrows.zig");

pub fn Decoder(comptime Codec: type) type {
    return struct {
        options: Options,
        history: []u8,
        configured_dictionary: DictionaryConfig = .none,
        active: Active = .detecting,
        prefix: [2]u8 = undefined,
        prefix_received: u2 = 0,
        detection_error_name: []const u8 = "",
        detection_error_input_offset: ?Count = null,
        last_step_progress: core.Progress = .{},

        const Self = @This();
        pub const Error = Codec.Error;
        pub const CloneError = Codec.ZlibDecoder.CloneError;
        pub const CloneStorage = Codec.ZlibDecoder.CloneStorage;
        pub const DictionarySet = Codec.DictionarySet;
        pub const Format = Codec.Format;
        pub const Phase = enum { detecting, zlib, gzip };
        pub const Options = struct {
            max_output_len: Count = std.math.maxInt(Count),
            expected_output_len: ?Count = null,
            allow_concatenated: bool = false,
            allow_trailing_data: bool = false,
            ignore_zlib_adler: bool = false,
            ignore_gzip_crc32: bool = false,
            ignore_gzip_isize: bool = false,
            max_gzip_header_metadata_len: usize = 1 << 20,
        };
        pub const Snapshot = struct {
            phase: Phase,
            format: ?Format,
            total_input: Count,
            total_output: Count,
            member_end_offset: ?Count,
            trailing_prefix_len: usize,
            required_dictionary_id: ?u32,
            last_error_name: []const u8,
            last_error_input_offset: ?Count,
            last_error_output_offset: ?Count,
            last_step_progress: core.Progress,
            done: bool,
            detail: Detail,
        };
        pub const Detail = union(enum) {
            detecting,
            zlib: Codec.ZlibDecoder.Snapshot,
            gzip: Codec.GzipDecoder.Snapshot,
        };

        const DictionaryConfig = union(enum) {
            none,
            single: []const u8,
            set: DictionarySet,
        };
        const Active = union(enum) {
            detecting,
            zlib: Codec.ZlibDecoder,
            gzip: Codec.GzipDecoder,
        };

        pub fn init(options: Options, history: []u8) Error!Self {
            _ = try Codec.ZlibDecoder.init(zlibOptions(options), history);
            _ = try Codec.GzipDecoder.init(gzipOptions(options), history);
            return .{ .options = options, .history = history };
        }

        pub fn initWithDictionary(options: Options, history: []u8, dictionary: []const u8) Error!Self {
            _ = try Codec.ZlibDecoder.initWithDictionary(zlibOptions(options), history, dictionary);
            _ = try Codec.GzipDecoder.init(gzipOptions(options), history);
            return .{ .options = options, .history = history, .configured_dictionary = .{ .single = dictionary } };
        }

        pub fn initWithDictionarySet(options: Options, history: []u8, dictionaries: DictionarySet) Error!Self {
            _ = try Codec.ZlibDecoder.initWithDictionarySet(zlibOptions(options), history, dictionaries);
            _ = try Codec.GzipDecoder.init(gzipOptions(options), history);
            return .{ .options = options, .history = history, .configured_dictionary = .{ .set = dictionaries } };
        }

        pub fn reset(self: *Self) void {
            self.active = .detecting;
            self.prefix_received = 0;
            self.detection_error_name = "";
            self.detection_error_input_offset = null;
            self.last_step_progress = .{};
        }

        pub fn cloneHistoryLen(self: *const Self) usize {
            return switch (self.active) {
                .detecting => self.history.len,
                .zlib => |*decoder| decoder.cloneHistoryLen(),
                .gzip => |*decoder| decoder.cloneHistoryLen(),
            };
        }

        pub fn cloneInto(self: *const Self, destination: *Self, storage: CloneStorage) CloneError!void {
            const required = self.cloneHistoryLen();
            if (storage.history.len < required) return error.InvalidCloneStorage;
            try clone_storage.disjoint(std.mem.asBytes(self), std.mem.asBytes(destination));
            try clone_storage.disjoint(std.mem.asBytes(self), storage.history);
            try clone_storage.disjoint(std.mem.asBytes(destination), self.history);
            try clone_storage.disjoint(std.mem.asBytes(destination), storage.history);
            try clone_storage.disjoint(self.history, storage.history);
            switch (self.configured_dictionary) {
                .none => {},
                .single => |dictionary| try clone_storage.rejectDestinationOverlap(destination, storage, dictionary),
                .set => |dictionaries| {
                    try clone_storage.rejectDestinationOverlap(destination, storage, std.mem.sliceAsBytes(dictionaries.entries));
                    for (dictionaries.entries) |entry| try clone_storage.rejectDestinationOverlap(destination, storage, entry.bytes);
                },
            }

            var copy = self.*;
            copy.history = storage.history[0..required];
            switch (self.active) {
                .detecting => {
                    if (storage.semantic_workspace != null) return error.InvalidCloneStorage;
                    copy.active = .detecting;
                },
                .zlib => |*decoder| {
                    var child: Codec.ZlibDecoder = undefined;
                    try decoder.cloneInto(&child, storage);
                    copy.active = .{ .zlib = child };
                },
                .gzip => |*decoder| {
                    var child: Codec.GzipDecoder = undefined;
                    try decoder.cloneInto(&child, storage);
                    copy.active = .{ .gzip = child };
                },
            }
            destination.* = copy;
            switch (destination.active) {
                .detecting => {},
                .zlib => |*decoder| clone_storage.rebindRaw(&decoder.raw),
                .gzip => |*decoder| clone_storage.rebindRaw(&decoder.raw),
            }
        }

        pub fn selectedFormat(self: *const Self) ?Format {
            return switch (self.active) {
                .detecting => null,
                .zlib => .zlib,
                .gzip => .gzip,
            };
        }

        pub fn requiredDictionaryId(self: *const Self) ?u32 {
            return switch (self.active) {
                .zlib => |*decoder| decoder.requiredDictionaryId(),
                else => null,
            };
        }

        pub fn provideDictionary(self: *Self, dictionary: []const u8) Error!void {
            return switch (self.active) {
                .zlib => |*decoder| blk: {
                    // The child's seed must preserve outer facade metadata too.
                    // Temporary sources may still borrow any receiver bytes.
                    if (decoder.requiredDictionaryId() != null and !decoder.input_finished)
                        try dictionary_borrows.validateSeed(std.mem.asBytes(self), decoder.raw.history, dictionary);
                    break :blk decoder.provideDictionary(dictionary);
                },
                else => error.InvalidStreamState,
            };
        }

        pub fn memberEndOffset(self: *const Self) ?Count {
            return switch (self.active) {
                .detecting => null,
                .zlib => |*decoder| decoder.memberEndOffset(),
                .gzip => |*decoder| decoder.memberEndOffset(),
            };
        }

        pub fn trailingPrefix(self: *const Self) []const u8 {
            return switch (self.active) {
                .detecting => &.{},
                .zlib => |*decoder| decoder.trailingPrefix(),
                .gzip => |*decoder| decoder.trailingPrefix(),
            };
        }

        pub fn atBlockBoundary(self: *const Self) bool {
            return switch (self.active) {
                .detecting => false,
                .zlib => |*decoder| decoder.atBlockBoundary(),
                .gzip => |*decoder| decoder.atBlockBoundary(),
            };
        }

        pub fn finish(self: *Self) Error!void {
            self.last_step_progress = .{};
            return switch (self.active) {
                .detecting => self.failDetection(error.TruncatedFrame),
                .zlib => |*decoder| decoder.finish(),
                .gzip => |*decoder| decoder.finish(),
            };
        }

        pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            return self.stepInternal(input, output, false);
        }

        pub fn stepToBlockBoundary(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            return self.stepInternal(input, output, true);
        }

        fn stepInternal(self: *Self, input: []const u8, output: []u8, block_boundary: bool) Error!core.StepResult {
            const semantic_admitted = try self.admitStep(input, output);
            const workspace = switch (self.active) {
                .detecting => null,
                .zlib => |*decoder| decoder.raw.semantic_decoder,
                .gzip => |*decoder| decoder.raw.semantic_decoder,
            };
            if (!semantic_admitted) switch (self.active) {
                .detecting => unreachable,
                .zlib => |*decoder| decoder.raw.semantic_decoder = null,
                .gzip => |*decoder| decoder.raw.semantic_decoder = null,
            };
            defer if (!semantic_admitted) switch (self.active) {
                .detecting => unreachable,
                .zlib => |*decoder| decoder.raw.semantic_decoder = workspace,
                .gzip => |*decoder| decoder.raw.semantic_decoder = workspace,
            };
            self.last_step_progress = .{};
            var detected_input: usize = 0;
            if (self.active == .detecting) {
                const needed: usize = 2 - self.prefix_received;
                const accepted = @min(needed, input.len);
                if (accepted != 0) {
                    @memcpy(self.prefix[self.prefix_received..][0..accepted], input[0..accepted]);
                    self.prefix_received += @intCast(accepted);
                    detected_input = accepted;
                }
                if (self.prefix_received != 2) {
                    self.last_step_progress = .{ .input_read = detected_input };
                    return .{ .progress = self.last_step_progress, .status = .need_input };
                }
                self.select() catch |err| {
                    self.last_step_progress = .{ .input_read = detected_input };
                    return self.failDetection(err);
                };
                self.bootstrapSelected() catch |err| {
                    self.last_step_progress = .{ .input_read = detected_input };
                    return err;
                };
            }

            const remaining = input[detected_input..];
            const child_result = switch (self.active) {
                .detecting => unreachable,
                .zlib => |*decoder| if (block_boundary) decoder.stepToBlockBoundary(remaining, output) else decoder.step(remaining, output),
                .gzip => |*decoder| if (block_boundary) decoder.stepToBlockBoundary(remaining, output) else decoder.step(remaining, output),
            };
            const stepped = child_result catch |err| {
                const child_progress = self.childLastProgress();
                self.last_step_progress = .{
                    .input_read = std.math.add(usize, detected_input, child_progress.input_read) catch return error.IntegerOverflow,
                    .output_written = child_progress.output_written,
                };
                return err;
            };
            self.last_step_progress = .{
                .input_read = std.math.add(usize, detected_input, stepped.progress.input_read) catch return error.IntegerOverflow,
                .output_written = stepped.progress.output_written,
            };
            var result = stepped;
            result.progress = self.last_step_progress;
            return result;
        }

        fn admitStep(self: *const Self, input: []const u8, output: []u8) Error!bool {
            const receiver = std.mem.asBytes(self);
            switch (self.active) {
                .detecting => {
                    const writers = step_borrows.outputPrefix(self.options, 0, output);
                    const history = self.history[0..@TypeOf(@as(Codec.ZlibDecoder, undefined).raw).required_history_len];
                    try step_borrows.validate(receiver, input, writers, history);
                    switch (self.configured_dictionary) {
                        .none => {},
                        .single => |dictionary| try step_borrows.validateDictionary(receiver, history, writers, dictionary),
                        .set => |dictionaries| try step_borrows.validateSet(receiver, history, writers, dictionaries),
                    }
                    return true;
                },
                .zlib => |*decoder| return self.admitSelected(receiver, decoder, input, output),
                .gzip => |*decoder| return self.admitSelected(receiver, decoder, input, output),
            }
        }

        fn admitSelected(self: *const Self, receiver: []const u8, decoder: anytype, input: []const u8, output: []u8) Error!bool {
            const writers = if (decoder.input_finished or decoder.phase == .done)
                output[0..0]
            else
                step_borrows.outputPrefix(self.options, decoder.total_output, output);
            var admitted = try step_borrows.rawAdmission(receiver, &decoder.raw, input, writers);
            const configured_admitted = switch (self.configured_dictionary) {
                .none => true,
                .single => |dictionary| try step_borrows.dictionaryAdmission(receiver, &decoder.raw, writers, dictionary),
                .set => |dictionaries| try step_borrows.setAdmission(receiver, &decoder.raw, writers, dictionaries),
            };
            admitted = admitted and configured_admitted;
            return admitted;
        }

        fn select(self: *Self) Error!void {
            if (self.prefix[0] == 0x1f and self.prefix[1] == 0x8b) {
                self.active = .{ .gzip = try Codec.GzipDecoder.init(gzipOptions(self.options), self.history) };
                return;
            }
            const cmf = self.prefix[0];
            const flg = self.prefix[1];
            const combined = (@as(u16, cmf) << 8) | flg;
            if (cmf & 0x0f != 8 or cmf >> 4 > 7 or combined % 31 != 0)
                return error.InvalidMagic;
            const decoder = switch (self.configured_dictionary) {
                .none => try Codec.ZlibDecoder.init(zlibOptions(self.options), self.history),
                .single => |dictionary| try Codec.ZlibDecoder.initWithDictionary(zlibOptions(self.options), self.history, dictionary),
                .set => |dictionaries| try Codec.ZlibDecoder.initWithDictionarySet(zlibOptions(self.options), self.history, dictionaries),
            };
            self.active = .{ .zlib = decoder };
        }

        fn bootstrapSelected(self: *Self) Error!void {
            var no_output: [0]u8 = .{};
            const boot = switch (self.active) {
                .detecting => unreachable,
                .zlib => |*decoder| try decoder.step(&self.prefix, &no_output),
                .gzip => |*decoder| try decoder.step(&self.prefix, &no_output),
            };
            if (boot.progress.input_read != self.prefix.len or boot.progress.output_written != 0)
                return error.InvalidStreamState;
        }

        pub fn snapshot(self: *const Self) Snapshot {
            return switch (self.active) {
                .detecting => .{
                    .phase = .detecting,
                    .format = null,
                    .total_input = self.prefix_received,
                    .total_output = 0,
                    .member_end_offset = null,
                    .trailing_prefix_len = 0,
                    .required_dictionary_id = null,
                    .last_error_name = self.detection_error_name,
                    .last_error_input_offset = self.detection_error_input_offset,
                    .last_error_output_offset = null,
                    .last_step_progress = self.last_step_progress,
                    .done = false,
                    .detail = .detecting,
                },
                .zlib => |*decoder| blk: {
                    const child = decoder.snapshot();
                    var observed = childSnapshot(.zlib, child, decoder.requiredDictionaryId(), self.last_step_progress);
                    observed.detail = .{ .zlib = child };
                    break :blk observed;
                },
                .gzip => |*decoder| blk: {
                    const child = decoder.snapshot();
                    var observed = childSnapshot(.gzip, child, null, self.last_step_progress);
                    observed.detail = .{ .gzip = child };
                    break :blk observed;
                },
            };
        }

        pub fn diagnostics(self: *const Self) core.StreamingDiagnostics {
            return switch (self.active) {
                .detecting => .{
                    .phase_name = "detecting",
                    .input_read = self.prefix_received,
                    .header_received = self.prefix_received,
                    .frame_input_read = self.prefix_received,
                    .last_error_name = self.detection_error_name,
                    .last_error_phase_name = if (self.detection_error_name.len == 0) "" else "detecting",
                    .error_input_offset = self.detection_error_input_offset,
                    .last_step_progress = self.last_step_progress,
                    .recoverability_hint_name = if (std.mem.eql(u8, self.detection_error_name, @errorName(error.TruncatedFrame))) "truncated_input" else if (self.detection_error_name.len == 0) "none" else "corrupt_header",
                },
                .zlib => |*decoder| blk: {
                    var observed = decoder.diagnostics();
                    observed.last_step_progress = self.last_step_progress;
                    break :blk observed;
                },
                .gzip => |*decoder| blk: {
                    var observed = decoder.diagnostics();
                    observed.last_step_progress = self.last_step_progress;
                    break :blk observed;
                },
            };
        }

        fn childLastProgress(self: *const Self) core.Progress {
            return switch (self.active) {
                .detecting => .{},
                .zlib => |*decoder| decoder.snapshot().last_step_progress,
                .gzip => |*decoder| decoder.snapshot().last_step_progress,
            };
        }

        fn failDetection(self: *Self, err: Error) Error {
            self.detection_error_name = @errorName(err);
            self.detection_error_input_offset = self.prefix_received;
            return err;
        }

        fn childSnapshot(format: Format, child: anytype, dictionary_id: ?u32, last_progress: core.Progress) Snapshot {
            return .{
                .phase = if (format == .zlib) .zlib else .gzip,
                .format = format,
                .total_input = child.total_input,
                .total_output = child.total_output,
                .member_end_offset = child.member_end_offset,
                .trailing_prefix_len = child.trailing_prefix_len,
                .required_dictionary_id = dictionary_id,
                .last_error_name = child.last_error_name,
                .last_error_input_offset = child.last_error_input_offset,
                .last_error_output_offset = child.last_error_output_offset,
                .last_step_progress = last_progress,
                .done = child.done,
                .detail = .detecting,
            };
        }

        fn zlibOptions(options: Options) Codec.ZlibDecoder.Options {
            return .{
                .max_output_len = options.max_output_len,
                .expected_output_len = options.expected_output_len,
                .allow_concatenated = options.allow_concatenated,
                .ignore_adler = options.ignore_zlib_adler,
                .allow_trailing_data = options.allow_trailing_data,
            };
        }

        fn gzipOptions(options: Options) Codec.GzipDecoder.Options {
            return .{
                .max_output_len = options.max_output_len,
                .expected_output_len = options.expected_output_len,
                .max_header_metadata_len = options.max_gzip_header_metadata_len,
                .ignore_crc32 = options.ignore_gzip_crc32,
                .ignore_isize = options.ignore_gzip_isize,
                .allow_concatenated = options.allow_concatenated,
                .allow_trailing_data = options.allow_trailing_data,
            };
        }
    };
}
