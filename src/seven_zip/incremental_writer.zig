const std = @import("std");
const checksum = @import("../checksum.zig");
const core = @import("../core.zig");
const coders = @import("coders.zig");
const file_properties = @import("file_properties.zig");
const types = @import("types.zig");
const writer_metadata = @import("writer_metadata.zig");
const wire = @import("writer_wire.zig");
const bcj2_spool = @import("incremental_writer/bcj2_spool.zig");
const codecs = @import("incremental_writer/codecs.zig");

pub const Compression = coders.Compression;
pub const EncodeOptions = coders.Options;
pub const SecondarySpool = bcj2_spool.Spool;

pub const Error = core.Error || coders.Error || codecs.Error || bcj2_spool.Error ||
    std.mem.Allocator.Error || error{
    Invalid7zEntry,
    Invalid7zIncrementalOptions,
    Invalid7zWriterState,
    SevenZipWriterPoisoned,
    StartHeaderPatchUnavailable,
    SecondarySpoolRequired,
};

pub const Options = struct {
    encode: EncodeOptions = .{},
    max_entries: u64 = std.math.maxInt(u64),
    max_metadata_size: usize = 64 * 1024 * 1024,
    bcj2_spool: ?SecondarySpool = null,
    max_bcj2_spool_size: u64 = 64 * 1024 * 1024,
    bcj2_spool_read_buffer_size: usize = 64 * 1024,
};

pub const EntryOptions = struct {
    name: []const u8,
    kind: types.Kind = .file,
    /// Anti-items describe removals in differential archives and accept no data.
    is_anti: bool = false,
    expected_size: ?u64 = null,
    creation_time: ?u64 = null,
    access_time: ?u64 = null,
    modification_time: ?u64 = null,
    start_position: ?u64 = null,
    attributes: ?u32 = null,
};

pub const Phase = enum {
    start_header,
    ready,
    entry_data,
    solid_finish,
    bcj2_replay,
    terminal_packed,
    next_header,
    done,
    poisoned,
};

pub const Snapshot = struct {
    phase: Phase,
    input_read: u64,
    output_written: u64,
    packed_output_written: u64,
    current_uncompressed_size: u64,
    current_compressed_size: u64,
    entry_count: u64,
    finish_entry_requested: bool,
    patch_ready: bool,
    metadata_size: usize,
};

const stream_marker = [_]u8{0};

const CurrentEntry = struct {
    name: []u8,
    kind: types.Kind,
    is_anti: bool,
    expected_size: ?u64,
    creation_time: ?u64,
    access_time: ?u64,
    modification_time: ?u64,
    start_position: ?u64,
    attributes: ?u32,
    codec: ?codecs.Encoder = null,
    bcj2: ?bcj2_spool.Stream = null,
    encode_options: EncodeOptions,
    crc: checksum.Crc32Best = .{},
    uncompressed_size: u64 = 0,
    compressed_size: u64 = 0,
    finish_requested: bool = false,
    has_stream: bool = false,

    fn deinit(self: *CurrentEntry, allocator: std.mem.Allocator) void {
        if (self.codec) |*codec| codec.deinit();
        if (self.bcj2) |*state| state.deinit();
        allocator.free(self.name);
        self.* = undefined;
    }
};

pub const Writer = struct {
    allocator: std.mem.Allocator,
    options: Options,
    owned_filters: []coders.Filter,
    owned_password: []u8,
    phase: Phase = .start_header,
    start_header_offset: usize = 0,
    entries: std.ArrayList(types.EncodeEntry) = .empty,
    folders: std.ArrayList(wire.EncodedFolder) = .empty,
    folder_options: std.ArrayList(EncodeOptions) = .empty,
    substreams: std.ArrayList(wire.EncodedSubstream) = .empty,
    current: ?CurrentEntry = null,
    terminal_packed: std.ArrayList(u8) = .empty,
    terminal_packed_offset: usize = 0,
    next_header: std.ArrayList(u8) = .empty,
    next_header_offset: usize = 0,
    next_header_crc32: u32 = 0,
    packed_output: u64 = 0,
    archive_output: u64 = 0,
    total_input: u64 = 0,
    next_encryption_stream_index: u64,
    solid_codec: ?codecs.Encoder = null,
    solid_bcj2: ?bcj2_spool.Stream = null,
    solid_options: EncodeOptions,
    solid_crc: checksum.Crc32Best = .{},
    solid_uncompressed_size: u64 = 0,
    solid_packed_size: u64 = 0,
    solid_substream_count: usize = 0,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, options: Options) Error!Self {
        try coders.validate(options.encode);
        try codecs.State.validate(options.encode);
        if (options.max_entries == 0 or options.max_metadata_size == 0) {
            return error.Invalid7zIncrementalOptions;
        }
        if (options.encode.bcj2 and options.bcj2_spool == null)
            return error.SecondarySpoolRequired;
        if (options.encode.bcj2 and
            (options.max_bcj2_spool_size < 5 or options.bcj2_spool_read_buffer_size == 0))
            return error.Invalid7zIncrementalOptions;
        const owned_filters = try allocator.dupe(coders.Filter, options.encode.filters);
        errdefer allocator.free(owned_filters);
        const owned_password = try allocator.dupe(
            u8,
            if (options.encode.encryption) |encryption| encryption.password else "",
        );
        errdefer allocator.free(owned_password);
        var stored_options = options;
        stored_options.encode.filters = owned_filters;
        if (stored_options.encode.encryption) |*encryption|
            encryption.password = owned_password;
        return .{
            .allocator = allocator,
            .options = stored_options,
            .owned_filters = owned_filters,
            .owned_password = owned_password,
            .next_encryption_stream_index = stored_options.encode.encryption_stream_index,
            .solid_options = stored_options.encode,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.current) |*current| current.deinit(self.allocator);
        if (self.solid_codec) |*codec| codec.deinit();
        if (self.solid_bcj2) |*state| state.deinit();
        for (self.entries.items) |entry| self.allocator.free(@constCast(entry.name));
        self.entries.deinit(self.allocator);
        self.folders.deinit(self.allocator);
        self.folder_options.deinit(self.allocator);
        self.substreams.deinit(self.allocator);
        self.terminal_packed.deinit(self.allocator);
        self.next_header.deinit(self.allocator);
        self.allocator.free(self.owned_filters);
        self.allocator.free(self.owned_password);
        self.* = undefined;
    }

    pub fn snapshot(self: *const Self) Snapshot {
        const current_uncompressed = if (self.current) |current| current.uncompressed_size else 0;
        const current_compressed = if (self.current) |current| current.compressed_size else 0;
        return .{
            .phase = self.phase,
            .input_read = self.total_input,
            .output_written = self.archive_output,
            .packed_output_written = self.packed_output,
            .current_uncompressed_size = current_uncompressed,
            .current_compressed_size = current_compressed,
            .entry_count = self.entries.items.len,
            .finish_entry_requested = if (self.current) |current| current.finish_requested else false,
            .patch_ready = self.phase == .done,
            .metadata_size = self.metadataSize(),
        };
    }

    pub fn beginEntry(self: *Self, entry_options: EntryOptions) Error!void {
        if (self.phase == .poisoned) return error.SevenZipWriterPoisoned;
        if ((self.phase != .start_header and self.phase != .ready) or self.current != null)
            return error.Invalid7zWriterState;
        try validateEntry(entry_options);
        const next_count = std.math.add(u64, @intCast(self.entries.items.len), 1) catch
            return error.IntegerOverflow;
        if (next_count > self.options.max_entries) return error.OutputLimitExceeded;
        if (entry_options.name.len > self.options.max_metadata_size -| self.metadataSize())
            return error.OutputLimitExceeded;

        const name = try self.allocator.dupe(u8, entry_options.name);
        self.current = .{
            .name = name,
            .kind = entry_options.kind,
            .is_anti = entry_options.is_anti,
            .expected_size = entry_options.expected_size,
            .creation_time = entry_options.creation_time,
            .access_time = entry_options.access_time,
            .modification_time = entry_options.modification_time,
            .start_position = entry_options.start_position,
            .attributes = entry_options.attributes,
            .encode_options = self.options.encode,
        };
        if (self.phase == .ready) self.phase = .entry_data;
    }

    pub fn finishEntry(self: *Self) Error!void {
        if (self.phase == .poisoned) return error.SevenZipWriterPoisoned;
        if ((self.phase != .start_header and self.phase != .entry_data) or self.current == null)
            return error.Invalid7zWriterState;
        var current = &self.current.?;
        if (current.finish_requested) return error.Invalid7zWriterState;
        if (current.expected_size) |expected|
            if (current.uncompressed_size != expected) return error.SizeMismatch;
        if (self.options.encode.solid) {
            try self.finalizeCurrent(current.has_stream);
            return;
        }
        current.finish_requested = true;
        if (current.codec) |*codec| {
            if (current.encode_options.bcj2) return;
            codec.finish();
            return;
        }
        try self.finalizeCurrent(false);
    }

    pub fn finishArchive(self: *Self) Error!void {
        if (self.phase == .poisoned) return error.SevenZipWriterPoisoned;
        if (self.phase != .ready or self.current != null) return error.Invalid7zWriterState;
        if (self.options.encode.solid and self.solid_codec != null) {
            if (self.solid_options.bcj2)
                try self.solid_bcj2.?.finishInput()
            else
                self.solid_codec.?.finish();
            self.phase = .solid_finish;
            return;
        }
        try self.prepareNextHeader();
    }

    fn prepareNextHeader(self: *Self) Error!void {
        var names: std.ArrayList(u8) = .empty;
        defer names.deinit(self.allocator);
        try wire.appendNames(self.allocator, &names, self.entries.items);
        try self.checkMetadataExtra(&.{names.capacity});

        var terminal_packed: std.ArrayList(u8) = .empty;
        defer terminal_packed.deinit(self.allocator);
        var external_streams = wire.EncodedExternalStreams{};
        var next_encryption_stream_index = self.next_encryption_stream_index;
        if (self.options.encode.external_names) |compression| {
            external_streams.name_index = try writer_metadata.appendExternalPayload(
                self.allocator,
                &terminal_packed,
                &external_streams,
                names.items,
                self.options.encode,
                compression,
                &next_encryption_stream_index,
                self.packed_output,
            );
            try self.checkMetadataExtra(&.{ names.capacity, terminal_packed.capacity });
        }
        if (self.options.encode.external_metadata) |compression| {
            var metadata_values: std.ArrayList(u8) = .empty;
            defer metadata_values.deinit(self.allocator);
            inline for (std.meta.tags(file_properties.Kind)) |kind| {
                metadata_values.clearRetainingCapacity();
                try file_properties.appendValues(
                    self.allocator,
                    &metadata_values,
                    self.entries.items,
                    kind,
                );
                if (metadata_values.items.len != 0)
                    external_streams.metadata_indices[@intFromEnum(kind)] = try writer_metadata.appendExternalPayload(
                        self.allocator,
                        &terminal_packed,
                        &external_streams,
                        metadata_values.items,
                        self.options.encode,
                        compression,
                        &next_encryption_stream_index,
                        self.packed_output,
                    );
                try self.checkMetadataExtra(&.{
                    names.capacity,
                    terminal_packed.capacity,
                    metadata_values.capacity,
                });
            }
        }

        var ordinary_header: std.ArrayList(u8) = .empty;
        defer ordinary_header.deinit(self.allocator);
        try wire.writeNextHeader(
            self.allocator,
            &ordinary_header,
            self.entries.items,
            self.folders.items,
            self.folder_options.items,
            self.substreams.items,
            self.options.encode,
            names.items,
            &external_streams,
        );
        try self.checkMetadataExtra(&.{
            names.capacity,
            terminal_packed.capacity,
            ordinary_header.capacity,
        });

        var next_header: std.ArrayList(u8) = .empty;
        defer next_header.deinit(self.allocator);
        const header_pack_position = std.math.add(
            u64,
            self.packed_output,
            std.math.cast(u64, terminal_packed.items.len) orelse return error.IntegerOverflow,
        ) catch return error.IntegerOverflow;
        try writer_metadata.appendFinalHeader(
            self.allocator,
            &terminal_packed,
            &next_header,
            ordinary_header.items,
            self.options.encode,
            &next_encryption_stream_index,
            header_pack_position,
        );
        try self.checkMetadataExtra(&.{ terminal_packed.capacity, next_header.capacity });

        self.terminal_packed.deinit(self.allocator);
        self.terminal_packed = terminal_packed;
        terminal_packed = .empty;
        self.terminal_packed_offset = 0;
        self.next_header.deinit(self.allocator);
        self.next_header = next_header;
        next_header = .empty;
        self.next_header_offset = 0;
        self.next_header_crc32 = checksum.crc32Best(self.next_header.items);
        self.next_encryption_stream_index = next_encryption_stream_index;
        self.phase = if (self.terminal_packed.items.len == 0) .next_header else .terminal_packed;
    }

    pub fn startHeaderPatch(self: *const Self) Error![wire.start_header_len]u8 {
        if (self.phase == .poisoned) return error.SevenZipWriterPoisoned;
        if (self.phase != .done) return error.StartHeaderPatchUnavailable;
        return wire.makeStartHeaderPatch(
            self.packed_output,
            std.math.cast(u64, self.next_header.items.len) orelse return error.IntegerOverflow,
            self.next_header_crc32,
        );
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.phase == .poisoned) return error.SevenZipWriterPoisoned;
        return self.stepInner(input, output) catch |err| {
            self.phase = .poisoned;
            return err;
        };
    }

    fn stepInner(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.phase == .done) {
            if (input.len != 0) return error.TrailingData;
            return .{ .status = .done };
        }
        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) switch (self.phase) {
            .start_header => {
                const remaining = wire.start_header_len - self.start_header_offset;
                const take = @min(remaining, output.len - output_written);
                @memset(output[output_written..][0..take], 0);
                self.start_header_offset += take;
                output_written += take;
                try self.addArchiveOutput(take);
                if (self.start_header_offset != wire.start_header_len)
                    return result(input_read, output_written, .need_output);
                self.phase = if (self.current == null) .ready else .entry_data;
                if (output_written == output.len)
                    return result(input_read, output_written, .need_output);
            },
            .ready => {
                if (input_read != input.len) return error.Invalid7zWriterState;
                return result(input_read, output_written, .need_input);
            },
            .entry_data => {
                var current = &self.current.?;
                const solid = self.options.encode.solid;
                if (!current.has_stream) {
                    if (current.finish_requested) return error.InvalidBlockPlan;
                    if (input_read == input.len)
                        return result(input_read, output_written, .need_input);
                    if (current.is_anti) return error.Invalid7zEntry;
                    if (current.kind != .file) return error.Invalid7zEntry;
                    if (output_written == output.len)
                        return result(input_read, output_written, .need_output);
                    try self.checkExpectedOffer(current, input.len - input_read);
                    if (solid) {
                        if (self.solid_codec == null) {
                            self.solid_options = try writer_metadata.optionsForNextEncryptedStream(
                                self.options.encode,
                                &self.next_encryption_stream_index,
                            );
                            self.solid_codec = try codecs.Encoder.init(
                                self.allocator,
                                primaryCodecOptions(self.solid_options),
                                null,
                            );
                            if (self.solid_options.bcj2)
                                self.solid_bcj2 = try self.initBcj2Stream(self.solid_options);
                        }
                        current.encode_options = self.solid_options;
                    } else {
                        current.encode_options = try writer_metadata.optionsForNextEncryptedStream(
                            self.options.encode,
                            &self.next_encryption_stream_index,
                        );
                        current.codec = try codecs.Encoder.init(
                            self.allocator,
                            primaryCodecOptions(current.encode_options),
                            if (current.encode_options.bcj2) null else current.expected_size,
                        );
                        if (current.encode_options.bcj2)
                            current.bcj2 = try self.initBcj2Stream(current.encode_options);
                    }
                    current.has_stream = true;
                }
                if (current.finish_requested and input_read != input.len)
                    return error.TrailingData;
                if (!current.finish_requested)
                    try self.checkExpectedOffer(current, input.len - input_read);
                if (output_written == output.len)
                    return result(input_read, output_written, .need_output);

                if (current.encode_options.bcj2) {
                    if (try self.stepBcj2Entry(
                        input,
                        output,
                        &input_read,
                        &output_written,
                    )) |stepped| return stepped;
                    continue;
                }

                const encoded = if (solid)
                    try self.solid_codec.?.step(input[input_read..], output[output_written..])
                else
                    try current.codec.?.step(input[input_read..], output[output_written..]);
                if (encoded.progress.input_read > input.len - input_read or
                    encoded.progress.output_written > output.len - output_written)
                    return error.InvalidBlockPlan;
                const consumed = input[input_read..][0..encoded.progress.input_read];
                current.crc.update(consumed);
                if (solid) self.solid_crc.update(consumed);
                current.uncompressed_size = std.math.add(
                    u64,
                    current.uncompressed_size,
                    @intCast(consumed.len),
                ) catch return error.IntegerOverflow;
                current.compressed_size = std.math.add(
                    u64,
                    current.compressed_size,
                    @intCast(encoded.progress.output_written),
                ) catch return error.IntegerOverflow;
                if (solid) {
                    self.solid_uncompressed_size = std.math.add(
                        u64,
                        self.solid_uncompressed_size,
                        @intCast(consumed.len),
                    ) catch return error.IntegerOverflow;
                    self.solid_packed_size = std.math.add(
                        u64,
                        self.solid_packed_size,
                        @intCast(encoded.progress.output_written),
                    ) catch return error.IntegerOverflow;
                }
                self.total_input = std.math.add(u64, self.total_input, @intCast(consumed.len)) catch
                    return error.IntegerOverflow;
                self.packed_output = std.math.add(
                    u64,
                    self.packed_output,
                    @intCast(encoded.progress.output_written),
                ) catch return error.IntegerOverflow;
                try self.addArchiveOutput(encoded.progress.output_written);
                input_read += encoded.progress.input_read;
                output_written += encoded.progress.output_written;

                if (encoded.status == .done) {
                    if (solid) return error.InvalidBlockPlan;
                    if (!current.finish_requested) return error.InvalidBlockPlan;
                    try self.finalizeCurrent(true);
                    if (output_written == output.len)
                        return result(input_read, output_written, .need_output);
                    continue;
                }
                if (encoded.status == .need_output)
                    return result(input_read, output_written, .need_output);
                if (current.finish_requested) return error.InvalidBlockPlan;
                if (input_read == input.len)
                    return result(input_read, output_written, .need_input);
                if (encoded.progress.input_read == 0 and encoded.progress.output_written == 0)
                    return error.InvalidBlockPlan;
            },
            .solid_finish => {
                if (input_read != input.len) return error.TrailingData;
                if (self.solid_options.bcj2) {
                    if (try self.stepSolidBcj2Finish(
                        output,
                        input_read,
                        &output_written,
                    )) |stepped| return stepped;
                    continue;
                }
                const encoded = try self.solid_codec.?.step(&.{}, output[output_written..]);
                if (encoded.progress.input_read != 0 or
                    encoded.progress.output_written > output.len - output_written)
                    return error.InvalidBlockPlan;
                self.solid_packed_size = std.math.add(
                    u64,
                    self.solid_packed_size,
                    @intCast(encoded.progress.output_written),
                ) catch return error.IntegerOverflow;
                self.packed_output = std.math.add(
                    u64,
                    self.packed_output,
                    @intCast(encoded.progress.output_written),
                ) catch return error.IntegerOverflow;
                try self.addArchiveOutput(encoded.progress.output_written);
                output_written += encoded.progress.output_written;
                if (encoded.status == .done) {
                    if (self.solid_options.bcj2) {
                        try self.solid_bcj2.?.finishInput();
                        self.phase = .bcj2_replay;
                        if (output_written == output.len)
                            return result(input_read, output_written, .need_output);
                        continue;
                    }
                    try self.finalizeSolidFolder();
                    try self.prepareNextHeader();
                    if (output_written == output.len)
                        return result(input_read, output_written, .need_output);
                    continue;
                }
                if (encoded.status != .need_output) return error.InvalidBlockPlan;
                return result(input_read, output_written, .need_output);
            },
            .bcj2_replay => {
                if (input_read != input.len) return error.TrailingData;
                const solid = self.options.encode.solid;
                const replayed = if (solid)
                    try self.solid_bcj2.?.stepReplay(output[output_written..])
                else
                    try self.current.?.bcj2.?.stepReplay(output[output_written..]);
                if (replayed.progress.input_read != 0 or
                    replayed.progress.output_written > output.len - output_written)
                    return error.InvalidBlockPlan;
                self.packed_output = std.math.add(
                    u64,
                    self.packed_output,
                    @intCast(replayed.progress.output_written),
                ) catch return error.IntegerOverflow;
                try self.addArchiveOutput(replayed.progress.output_written);
                output_written += replayed.progress.output_written;
                if (replayed.status == .done) {
                    if (solid) {
                        try self.finalizeSolidFolder();
                        try self.prepareNextHeader();
                    } else {
                        try self.finalizeCurrent(true);
                    }
                    if (output_written == output.len)
                        return result(input_read, output_written, .need_output);
                    continue;
                }
                if (replayed.status != .need_output) return error.InvalidBlockPlan;
                return result(input_read, output_written, .need_output);
            },
            .terminal_packed => {
                if (input_read != input.len) return error.TrailingData;
                const remaining = self.terminal_packed.items[self.terminal_packed_offset..];
                const take = @min(remaining.len, output.len - output_written);
                @memcpy(output[output_written..][0..take], remaining[0..take]);
                self.terminal_packed_offset += take;
                output_written += take;
                self.packed_output = std.math.add(u64, self.packed_output, @intCast(take)) catch
                    return error.IntegerOverflow;
                try self.addArchiveOutput(take);
                if (self.terminal_packed_offset != self.terminal_packed.items.len)
                    return result(input_read, output_written, .need_output);
                self.phase = .next_header;
                if (output_written == output.len)
                    return result(input_read, output_written, .need_output);
            },
            .next_header => {
                if (input_read != input.len) return error.TrailingData;
                const remaining = self.next_header.items[self.next_header_offset..];
                const take = @min(remaining.len, output.len - output_written);
                @memcpy(output[output_written..][0..take], remaining[0..take]);
                self.next_header_offset += take;
                output_written += take;
                try self.addArchiveOutput(take);
                if (self.next_header_offset != self.next_header.items.len)
                    return result(input_read, output_written, .need_output);
                self.phase = .done;
                return result(input_read, output_written, .done);
            },
            .done, .poisoned => unreachable,
        };
    }

    fn stepBcj2Entry(
        self: *Self,
        input: []const u8,
        output: []u8,
        input_read: *usize,
        output_written: *usize,
    ) Error!?core.StepResult {
        while (true) {
            var current = &self.current.?;
            const solid = self.options.encode.solid;
            var state = if (solid) &self.solid_bcj2.? else &current.bcj2.?;
            var codec = if (solid) &self.solid_codec.? else &current.codec.?;

            if (state.hasMain()) {
                const main = state.mainBytes();
                const encoded = try codec.step(main, output[output_written.*..]);
                if (encoded.progress.input_read > main.len or
                    encoded.progress.output_written > output.len - output_written.*)
                    return error.InvalidBlockPlan;
                try state.consumeMain(encoded.progress.input_read);
                current.compressed_size = std.math.add(
                    u64,
                    current.compressed_size,
                    @intCast(encoded.progress.output_written),
                ) catch return error.IntegerOverflow;
                if (solid)
                    self.solid_packed_size = std.math.add(
                        u64,
                        self.solid_packed_size,
                        @intCast(encoded.progress.output_written),
                    ) catch return error.IntegerOverflow;
                self.packed_output = std.math.add(
                    u64,
                    self.packed_output,
                    @intCast(encoded.progress.output_written),
                ) catch return error.IntegerOverflow;
                try self.addArchiveOutput(encoded.progress.output_written);
                output_written.* += encoded.progress.output_written;
                if (encoded.status == .done) return error.InvalidBlockPlan;
                if (state.hasMain()) {
                    if (encoded.status != .need_output) return error.InvalidBlockPlan;
                    return result(input_read.*, output_written.*, .need_output);
                }
                if (output_written.* == output.len)
                    return result(input_read.*, output_written.*, .need_output);
                continue;
            }

            if (current.finish_requested) {
                if (!state.inputFinished()) {
                    try state.finishInput();
                    continue;
                }
                if (!state.mainFinishSent()) {
                    codec.finish();
                    state.markMainFinishSent();
                }
                const encoded = try codec.step(&.{}, output[output_written.*..]);
                if (encoded.progress.input_read != 0 or
                    encoded.progress.output_written > output.len - output_written.*)
                    return error.InvalidBlockPlan;
                current.compressed_size = std.math.add(
                    u64,
                    current.compressed_size,
                    @intCast(encoded.progress.output_written),
                ) catch return error.IntegerOverflow;
                self.packed_output = std.math.add(
                    u64,
                    self.packed_output,
                    @intCast(encoded.progress.output_written),
                ) catch return error.IntegerOverflow;
                try self.addArchiveOutput(encoded.progress.output_written);
                output_written.* += encoded.progress.output_written;
                if (encoded.status == .done) {
                    self.phase = .bcj2_replay;
                    return null;
                }
                if (encoded.status != .need_output) return error.InvalidBlockPlan;
                return result(input_read.*, output_written.*, .need_output);
            }

            if (input_read.* == input.len)
                return result(input_read.*, output_written.*, .need_input);
            const input_end = @min(input.len, input_read.* + 64 * 1024);
            const consumed = input[input_read.*..input_end];
            try state.accept(consumed);
            current.crc.update(consumed);
            if (solid) self.solid_crc.update(consumed);
            current.uncompressed_size = std.math.add(
                u64,
                current.uncompressed_size,
                @intCast(consumed.len),
            ) catch return error.IntegerOverflow;
            if (solid)
                self.solid_uncompressed_size = std.math.add(
                    u64,
                    self.solid_uncompressed_size,
                    @intCast(consumed.len),
                ) catch return error.IntegerOverflow;
            self.total_input = std.math.add(u64, self.total_input, @intCast(consumed.len)) catch
                return error.IntegerOverflow;
            input_read.* = input_end;
        }
    }

    fn stepSolidBcj2Finish(
        self: *Self,
        output: []u8,
        input_read: usize,
        output_written: *usize,
    ) Error!?core.StepResult {
        var state = &self.solid_bcj2.?;
        var codec = &self.solid_codec.?;
        while (true) {
            if (state.hasMain()) {
                const main = state.mainBytes();
                const encoded = try codec.step(main, output[output_written.*..]);
                if (encoded.progress.input_read > main.len or
                    encoded.progress.output_written > output.len - output_written.*)
                    return error.InvalidBlockPlan;
                try state.consumeMain(encoded.progress.input_read);
                self.solid_packed_size = std.math.add(
                    u64,
                    self.solid_packed_size,
                    @intCast(encoded.progress.output_written),
                ) catch return error.IntegerOverflow;
                self.packed_output = std.math.add(
                    u64,
                    self.packed_output,
                    @intCast(encoded.progress.output_written),
                ) catch return error.IntegerOverflow;
                try self.addArchiveOutput(encoded.progress.output_written);
                output_written.* += encoded.progress.output_written;
                if (encoded.status == .done) return error.InvalidBlockPlan;
                if (state.hasMain()) {
                    if (encoded.status != .need_output) return error.InvalidBlockPlan;
                    return result(input_read, output_written.*, .need_output);
                }
                if (output_written.* == output.len)
                    return result(input_read, output_written.*, .need_output);
                continue;
            }
            if (!state.mainFinishSent()) {
                codec.finish();
                state.markMainFinishSent();
            }
            const encoded = try codec.step(&.{}, output[output_written.*..]);
            if (encoded.progress.input_read != 0 or
                encoded.progress.output_written > output.len - output_written.*)
                return error.InvalidBlockPlan;
            self.solid_packed_size = std.math.add(
                u64,
                self.solid_packed_size,
                @intCast(encoded.progress.output_written),
            ) catch return error.IntegerOverflow;
            self.packed_output = std.math.add(
                u64,
                self.packed_output,
                @intCast(encoded.progress.output_written),
            ) catch return error.IntegerOverflow;
            try self.addArchiveOutput(encoded.progress.output_written);
            output_written.* += encoded.progress.output_written;
            if (encoded.status == .done) {
                self.phase = .bcj2_replay;
                return null;
            }
            if (encoded.status != .need_output) return error.InvalidBlockPlan;
            return result(input_read, output_written.*, .need_output);
        }
    }

    fn finalizeCurrent(self: *Self, has_stream: bool) Error!void {
        var current = &self.current.?;
        try self.entries.ensureUnusedCapacity(self.allocator, 1);
        if (has_stream) {
            try self.substreams.ensureUnusedCapacity(self.allocator, 1);
            if (!self.options.encode.solid) {
                try self.folders.ensureUnusedCapacity(self.allocator, 1);
                try self.folder_options.ensureUnusedCapacity(self.allocator, 1);
            }
        }
        const name = current.name;
        const entry = types.EncodeEntry{
            .name = name,
            .data = if (has_stream) &stream_marker else "",
            .kind = current.kind,
            .is_anti = current.is_anti,
            .creation_time = current.creation_time,
            .access_time = current.access_time,
            .modification_time = current.modification_time,
            .start_position = current.start_position,
            .attributes = current.attributes,
        };
        if (has_stream) {
            const substream_index = self.substreams.items.len;
            const digest = current.crc.digest();
            if (self.options.encode.solid) {
                self.solid_substream_count += 1;
            } else {
                const is_bcj2 = current.encode_options.bcj2;
                const packed_sizes: [4]u64 = if (is_bcj2)
                    .{
                        current.compressed_size,
                        current.bcj2.?.branchPackedSize(0),
                        current.bcj2.?.branchPackedSize(1),
                        current.bcj2.?.branchPackedSize(2),
                    }
                else
                    .{ current.compressed_size, 0, 0, 0 };
                const aes_unpack_sizes: [4]?u64 = if (is_bcj2 and
                    current.encode_options.encryption != null)
                    .{
                        current.codec.?.aesUnpackSize() orelse return error.InvalidBlockPlan,
                        current.bcj2.?.branchPlainSize(0),
                        current.bcj2.?.branchPlainSize(1),
                        current.bcj2.?.branchPlainSize(2),
                    }
                else
                    .{ current.codec.?.aesUnpackSize(), null, null, null };
                self.folders.appendAssumeCapacity(.{
                    .packed_sizes = packed_sizes,
                    .pack_stream_count = if (is_bcj2) 4 else 1,
                    .unpacked_size = current.uncompressed_size,
                    .bcj2_main_size = if (is_bcj2) current.bcj2.?.mainSize() else null,
                    .aes_unpack_sizes = aes_unpack_sizes,
                    .crc32 = digest,
                    .first_substream = substream_index,
                    .substream_count = 1,
                });
                self.folder_options.appendAssumeCapacity(current.encode_options);
            }
            self.substreams.appendAssumeCapacity(.{
                .unpacked_size = current.uncompressed_size,
                .crc32 = digest,
            });
        }
        if (current.codec) |*codec| codec.deinit();
        if (current.bcj2) |*state| state.deinit();
        self.entries.appendAssumeCapacity(entry);
        self.current = null;
        self.phase = if (self.start_header_offset == wire.start_header_len) .ready else .start_header;
    }

    fn finalizeSolidFolder(self: *Self) Error!void {
        std.debug.assert(self.solid_codec != null and self.solid_substream_count != 0);
        try self.folders.ensureUnusedCapacity(self.allocator, 1);
        try self.folder_options.ensureUnusedCapacity(self.allocator, 1);
        const is_bcj2 = self.solid_options.bcj2;
        const packed_sizes: [4]u64 = if (is_bcj2)
            .{
                self.solid_packed_size,
                self.solid_bcj2.?.branchPackedSize(0),
                self.solid_bcj2.?.branchPackedSize(1),
                self.solid_bcj2.?.branchPackedSize(2),
            }
        else
            .{ self.solid_packed_size, 0, 0, 0 };
        const aes_unpack_sizes: [4]?u64 = if (is_bcj2 and
            self.solid_options.encryption != null)
            .{
                self.solid_codec.?.aesUnpackSize() orelse return error.InvalidBlockPlan,
                self.solid_bcj2.?.branchPlainSize(0),
                self.solid_bcj2.?.branchPlainSize(1),
                self.solid_bcj2.?.branchPlainSize(2),
            }
        else
            .{ self.solid_codec.?.aesUnpackSize(), null, null, null };
        self.folders.appendAssumeCapacity(.{
            .packed_sizes = packed_sizes,
            .pack_stream_count = if (is_bcj2) 4 else 1,
            .unpacked_size = self.solid_uncompressed_size,
            .bcj2_main_size = if (is_bcj2) self.solid_bcj2.?.mainSize() else null,
            .aes_unpack_sizes = aes_unpack_sizes,
            .crc32 = self.solid_crc.digest(),
            .first_substream = 0,
            .substream_count = self.solid_substream_count,
        });
        self.folder_options.appendAssumeCapacity(self.solid_options);
        self.solid_codec.?.deinit();
        self.solid_codec = null;
        if (self.solid_bcj2) |*state| state.deinit();
        self.solid_bcj2 = null;
    }

    fn initBcj2Stream(self: *Self, options: EncodeOptions) Error!bcj2_spool.Stream {
        return bcj2_spool.Stream.init(
            self.allocator,
            self.options.bcj2_spool orelse return error.SecondarySpoolRequired,
            options.encryption,
            options.encryption_stream_index,
            options.bcj2_start_ip,
            self.options.max_bcj2_spool_size,
            self.options.bcj2_spool_read_buffer_size,
        );
    }

    fn checkExpectedOffer(self: *const Self, current: *const CurrentEntry, offered: usize) Error!void {
        _ = self;
        if (current.expected_size) |expected| {
            if (current.uncompressed_size > expected) return error.SizeMismatch;
            const remaining = expected - current.uncompressed_size;
            if (offered > remaining) return error.SizeMismatch;
        }
    }

    fn addArchiveOutput(self: *Self, count: usize) Error!void {
        self.archive_output = std.math.add(u64, self.archive_output, @intCast(count)) catch
            return error.IntegerOverflow;
    }

    fn checkMetadataExtra(self: *const Self, extras: []const usize) Error!void {
        var size = self.metadataSize();
        for (extras) |extra|
            size = std.math.add(usize, size, extra) catch return error.OutputLimitExceeded;
        if (size > self.options.max_metadata_size) return error.OutputLimitExceeded;
    }

    fn metadataSize(self: *const Self) usize {
        var size = self.terminal_packed.capacity +| self.next_header.capacity;
        size +|= self.owned_filters.len *| @sizeOf(coders.Filter);
        size +|= self.owned_password.len;
        for (self.entries.items) |entry| size +|= entry.name.len;
        if (self.current) |current| size +|= current.name.len;
        size +|= self.entries.capacity *| @sizeOf(types.EncodeEntry);
        size +|= self.folders.capacity *| @sizeOf(wire.EncodedFolder);
        size +|= self.folder_options.capacity *| @sizeOf(EncodeOptions);
        size +|= self.substreams.capacity *| @sizeOf(wire.EncodedSubstream);
        return size;
    }
};

fn validateEntry(entry: EntryOptions) Error!void {
    if (entry.name.len == 0 or std.mem.indexOfScalar(u8, entry.name, 0) != null or
        !std.unicode.utf8ValidateSlice(entry.name))
        return error.Invalid7zEntry;
    if (entry.kind == .directory and (entry.expected_size orelse 0) != 0)
        return error.Invalid7zEntry;
    if (entry.is_anti and (entry.expected_size orelse 0) != 0)
        return error.Invalid7zEntry;
}

fn primaryCodecOptions(folder_options: EncodeOptions) EncodeOptions {
    if (!folder_options.bcj2) return folder_options;
    var options = folder_options;
    options.solid = false;
    options.header_compression = null;
    options.external_names = null;
    options.external_metadata = null;
    options.encrypt_header = false;
    options.bcj2 = false;
    options.bcj2_start_ip = 0;
    options.filters = &.{};
    return options;
}

fn result(
    input_read: usize,
    output_written: usize,
    status: core.StepResult.Status,
) core.StepResult {
    return .{
        .progress = .{ .input_read = input_read, .output_written = output_written },
        .status = status,
    };
}

const TestSecondarySpool = struct {
    allocator: std.mem.Allocator,
    bytes: std.ArrayList(u8) = .empty,
    fail_write: bool = false,
    truncate_reads: bool = false,

    fn init(allocator: std.mem.Allocator) TestSecondarySpool {
        return .{ .allocator = allocator };
    }

    fn deinit(self: *TestSecondarySpool) void {
        self.bytes.deinit(self.allocator);
        self.* = undefined;
    }

    fn descriptor(self: *TestSecondarySpool) SecondarySpool {
        return .{
            .context = self,
            .reset = reset,
            .write = write,
            .read_at = readAt,
        };
    }

    fn reset(context: *anyopaque) !void {
        const self: *TestSecondarySpool = @ptrCast(@alignCast(context));
        self.bytes.clearRetainingCapacity();
    }

    fn write(context: *anyopaque, bytes: []const u8) !void {
        const self: *TestSecondarySpool = @ptrCast(@alignCast(context));
        if (self.fail_write) return error.InjectedSpoolFailure;
        try self.bytes.appendSlice(self.allocator, bytes);
    }

    fn readAt(context: *anyopaque, offset: u64, output: []u8) !usize {
        const self: *TestSecondarySpool = @ptrCast(@alignCast(context));
        const start = std.math.cast(usize, offset) orelse return error.InjectedSpoolFailure;
        if (self.truncate_reads or start >= self.bytes.items.len) return 0;
        const amount = @min(output.len, self.bytes.items.len - start);
        @memcpy(output[0..amount], self.bytes.items[start..][0..amount]);
        return amount;
    }
};

test "7z incremental writer streams copy entries and exposes a final patch" {
    const archive = @import("archive.zig");
    const expected = [_]struct { EntryOptions, []const u8 }{
        .{ .{ .name = "hello.txt", .expected_size = "hello seven zip\n".len }, "hello seven zip\n" },
        .{ .{ .name = "empty.txt", .expected_size = 0 }, "" },
        .{ .{ .name = "folder", .kind = .directory }, "" },
        .{ .{ .name = "utf8-数据.txt", .expected_size = 7 }, "payload" },
        .{ .{ .name = "deleted.txt", .is_anti = true, .expected_size = 0 }, "" },
        .{ .{ .name = "deleted-folder", .kind = .directory, .is_anti = true }, "" },
    };
    const encoded = try encodeTestArchive(std.testing.allocator, .{}, &expected, 3, 1);
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqualSlices(u8, &wire.signature, encoded[0..wire.signature.len]);
    const parsed = try archive.parseAlloc(std.testing.allocator, encoded);
    defer parsed.deinit();
    try std.testing.expectEqual(expected.len, parsed.entries.len);
    for (expected, parsed.entries) |item, entry| {
        try std.testing.expectEqualStrings(item[0].name, entry.name);
        try std.testing.expectEqual(item[0].kind, entry.kind);
        try std.testing.expectEqual(item[0].is_anti, entry.is_anti);
        if (item[1].len != 0) {
            const decoded = try parsed.extractEntryAlloc(std.testing.allocator, entry);
            defer std.testing.allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, item[1], decoded);
        } else {
            try std.testing.expectEqual(@as(?usize, null), entry.folder_index);
        }
    }
    const deleted = parsed.find("deleted.txt") orelse return error.EntryNotFound;
    try std.testing.expectError(
        error.EntryHasNoStream,
        parsed.extractEntryAlloc(std.testing.allocator, deleted),
    );
}

test "7z incremental writer streams common compression methods" {
    const archive = @import("archive.zig");
    const payload = "incremental 7z codec payload\n" ** 193;
    const expected = [_]struct { EntryOptions, []const u8 }{
        .{ .{ .name = "payload.txt", .expected_size = payload.len }, payload },
    };
    inline for (.{
        Compression.deflate,
        Compression.bzip2,
        Compression.lzma,
        Compression.lzma2,
        Compression.lzma2_stored,
        Compression.ppmd7,
    }) |compression| {
        const encoded = try encodeTestArchive(
            std.testing.allocator,
            .{ .encode = .{ .compression = compression } },
            &expected,
            11,
            2,
        );
        defer std.testing.allocator.free(encoded);
        const parsed = try archive.parseAlloc(std.testing.allocator, encoded);
        defer parsed.deinit();
        const decoded = try parsed.extractByNameAlloc(std.testing.allocator, "payload.txt");
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, payload, decoded);
    }
}

test "7z incremental writer streams compound forward filters" {
    const archive = @import("archive.zig");
    const payload = "\x90\xe8\x10\x00\x00\x00\xe9\xf0\xff\xff\xff\x90" ** 257;
    const filters = [_]coders.Filter{
        coders.Filter.x86(0x1000),
        try coders.Filter.delta(4),
    };
    const expected = [_]struct { EntryOptions, []const u8 }{
        .{ .{ .name = "filtered.bin", .expected_size = payload.len }, payload },
    };
    const encoded = try encodeTestArchive(
        std.testing.allocator,
        .{ .encode = .{ .compression = .lzma2, .filters = &filters } },
        &expected,
        5,
        3,
    );
    defer std.testing.allocator.free(encoded);
    const parsed = try archive.parseAlloc(std.testing.allocator, encoded);
    defer parsed.deinit();
    const decoded = try parsed.extractByNameAlloc(std.testing.allocator, "filtered.bin");
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "7z incremental writer streams independently encrypted folders" {
    const archive = @import("archive.zig");
    const aes = @import("aes.zig");
    const encryption = coders.EncryptionOptions{
        .password = "incremental 密码",
        .iv = [_]u8{0x42} ** 16,
        .salt = [_]u8{0x24} ** 16,
        .salt_len = 8,
        .num_cycles_power = aes.direct_key_power,
    };
    const expected = [_]struct { EntryOptions, []const u8 }{
        .{ .{ .name = "first.txt", .expected_size = 71 }, "A" ** 71 },
        .{ .{ .name = "second.txt", .expected_size = 53 }, "B" ** 53 },
    };
    const encoded = try encodeTestArchive(
        std.testing.allocator,
        .{ .encode = .{ .compression = .lzma2, .encryption = encryption } },
        &expected,
        7,
        1,
    );
    defer std.testing.allocator.free(encoded);
    const parsed = try archive.parseAlloc(std.testing.allocator, encoded);
    defer parsed.deinit();
    for (expected, parsed.entries) |item, entry| {
        const decoded = try parsed.decodeEntryAllocWithOptions(
            std.testing.allocator,
            entry,
            .{ .password = encryption.password },
        );
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, item[1], decoded);
    }
}

test "7z incremental writer retains one solid codec across entries" {
    const archive = @import("archive.zig");
    const aes = @import("aes.zig");
    const encryption = coders.EncryptionOptions{
        .password = "solid 密码",
        .iv = [_]u8{0x18} ** 16,
        .num_cycles_power = aes.direct_key_power,
    };
    const filters = [_]coders.Filter{coders.Filter.x86(0x2000)};
    const expected = [_]struct { EntryOptions, []const u8 }{
        .{ .{ .name = "first.bin", .expected_size = 12 * 73 }, "\x90\xe8\x10\x00\x00\x00tail!!" ** 73 },
        .{ .{ .name = "empty.txt", .expected_size = 0 }, "" },
        .{ .{ .name = "folder", .kind = .directory }, "" },
        .{ .{ .name = "second.bin", .expected_size = 12 * 41 }, "\x90\xe9\xf0\xff\xff\xffmore!!" ** 41 },
        .{ .{ .name = "third.txt", .expected_size = 107 }, "C" ** 107 },
    };
    const encoded = try encodeTestArchive(
        std.testing.allocator,
        .{
            .encode = .{
                .compression = .lzma2,
                .solid = true,
                .filters = &filters,
                .encryption = encryption,
            },
        },
        &expected,
        9,
        2,
    );
    defer std.testing.allocator.free(encoded);
    const parsed = try archive.parseAlloc(std.testing.allocator, encoded);
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 1), parsed.streams.folders.len);
    try std.testing.expectEqual(@as(usize, 3), parsed.streams.folders[0].substream_count);
    for (expected, parsed.entries) |item, entry| {
        if (item[1].len == 0) continue;
        const decoded = try parsed.decodeEntryAllocWithOptions(
            std.testing.allocator,
            entry,
            .{ .password = encryption.password },
        );
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, item[1], decoded);
    }
}

test "7z incremental writer replays BCJ2 range spools for every main codec" {
    const archive = @import("archive.zig");
    const payload = ("\x90\xe8\x10\x00\x00\x00\xe9\xf0\xff\xff\xff" ++
        "\x0f\x85\x08\x00\x00\x00tail") ** 97;
    const expected = [_]struct { EntryOptions, []const u8 }{
        .{ .{ .name = "branch-heavy.bin", .expected_size = payload.len }, payload },
    };
    inline for (.{
        Compression.copy,
        Compression.deflate,
        Compression.bzip2,
        Compression.lzma,
        Compression.lzma2,
        Compression.lzma2_stored,
        Compression.ppmd7,
    }) |compression| {
        var spool = TestSecondarySpool.init(std.testing.allocator);
        defer spool.deinit();
        const encoded = try encodeTestArchive(
            std.testing.allocator,
            .{
                .encode = .{
                    .compression = compression,
                    .bcj2 = true,
                    .bcj2_start_ip = 0,
                },
                .bcj2_spool = spool.descriptor(),
                .bcj2_spool_read_buffer_size = 3,
            },
            &expected,
            5,
            1,
        );
        defer std.testing.allocator.free(encoded);
        const parsed = try archive.parseAlloc(std.testing.allocator, encoded);
        defer parsed.deinit();
        const folder = parsed.streams.folders[0];
        try std.testing.expect(folder.bcj2_coder_index != null);
        try std.testing.expect(
            parsed.streams.pack_sizes[folder.pack_index + folder.bcj2_branches[1].pack_stream_offset] != 0,
        );
        try std.testing.expect(
            parsed.streams.pack_sizes[folder.pack_index + folder.bcj2_branches[2].pack_stream_offset] != 0,
        );
        const decoded = try parsed.extractByNameAlloc(
            std.testing.allocator,
            "branch-heavy.bin",
        );
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, payload, decoded);
    }
}

test "7z incremental writer composes solid BCJ2 AES and hidden metadata" {
    const archive = @import("archive.zig");
    const aes = @import("aes.zig");
    const password = "BCJ2 spool 密码";
    const encryption = coders.EncryptionOptions{
        .password = password,
        .iv = [_]u8{0x63} ** 16,
        .salt = [_]u8{0x36} ** 16,
        .salt_len = 8,
        .num_cycles_power = aes.direct_key_power,
    };
    const first = "\x90\xe8\x10\x00\x00\x00first" ** 53;
    const second = "\x0f\x85\x08\x00\x00\x00second" ** 47;
    const expected = [_]struct { EntryOptions, []const u8 }{
        .{ .{ .name = "first.bin", .expected_size = first.len }, first },
        .{ .{ .name = "empty.txt", .expected_size = 0 }, "" },
        .{ .{
            .name = "目录/second.bin",
            .expected_size = second.len,
            .modification_time = 116_444_736_080_000_000,
        }, second },
    };
    var spool = TestSecondarySpool.init(std.testing.allocator);
    defer spool.deinit();
    const encoded = try encodeTestArchive(
        std.testing.allocator,
        .{
            .encode = .{
                .compression = .lzma2,
                .solid = true,
                .header_compression = .lzma2,
                .external_names = .deflate,
                .external_metadata = .copy,
                .encryption = encryption,
                .encrypt_header = true,
                .bcj2 = true,
            },
            .bcj2_spool = spool.descriptor(),
            .bcj2_spool_read_buffer_size = 2,
        },
        &expected,
        7,
        1,
    );
    defer std.testing.allocator.free(encoded);
    const parsed = try archive.parseAllocWithOptions(
        std.testing.allocator,
        encoded,
        .{ .password = password },
    );
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 1), parsed.streams.folders.len);
    try std.testing.expectEqual(@as(usize, 2), parsed.streams.folders[0].substream_count);
    for (expected, parsed.entries) |item, entry| {
        if (item[1].len == 0) continue;
        const decoded = try parsed.decodeEntryAllocWithOptions(
            std.testing.allocator,
            entry,
            .{ .password = password },
        );
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, item[1], decoded);
    }
}

test "7z incremental writer bounds and validates BCJ2 secondary spools" {
    const payload = "\xe8\x00\x00\x00\x00" ** 4096;
    const expected = [_]struct { EntryOptions, []const u8 }{
        .{ .{ .name = "markers.bin", .expected_size = payload.len }, payload },
    };

    var limited_spool = TestSecondarySpool.init(std.testing.allocator);
    defer limited_spool.deinit();
    try std.testing.expectError(
        error.OutputLimitExceeded,
        encodeTestArchive(
            std.testing.allocator,
            .{
                .encode = .{ .compression = .copy, .bcj2 = true },
                .bcj2_spool = limited_spool.descriptor(),
                .max_bcj2_spool_size = 5,
            },
            &expected,
            127,
            17,
        ),
    );

    var failing_spool = TestSecondarySpool.init(std.testing.allocator);
    defer failing_spool.deinit();
    failing_spool.fail_write = true;
    try std.testing.expectError(
        error.SecondarySpoolFailure,
        encodeTestArchive(
            std.testing.allocator,
            .{
                .encode = .{ .compression = .copy, .bcj2 = true },
                .bcj2_spool = failing_spool.descriptor(),
            },
            &expected,
            127,
            17,
        ),
    );

    var truncated_spool = TestSecondarySpool.init(std.testing.allocator);
    defer truncated_spool.deinit();
    truncated_spool.truncate_reads = true;
    try std.testing.expectError(
        error.TruncatedSecondarySpool,
        encodeTestArchive(
            std.testing.allocator,
            .{
                .encode = .{ .compression = .copy, .bcj2 = true },
                .bcj2_spool = truncated_spool.descriptor(),
                .bcj2_spool_read_buffer_size = 3,
            },
            &expected,
            127,
            17,
        ),
    );
}

test "7z incremental writer emits external metadata and encoded headers" {
    const archive = @import("archive.zig");
    const filetime_epoch: u64 = 116_444_736_000_000_000;
    const payload = "terminal metadata payload\n" ** 37;
    const expected = [_]struct { EntryOptions, []const u8 }{
        .{ .{
            .name = "目录/payload.txt",
            .expected_size = payload.len,
            .creation_time = filetime_epoch + 10_000_000,
            .access_time = filetime_epoch + 20_000_000,
            .modification_time = filetime_epoch + 30_000_000,
            .start_position = 0x1_0000_0001,
            .attributes = 0x81a4_0020,
        }, payload },
        .{ .{
            .name = "empty.txt",
            .expected_size = 0,
            .modification_time = filetime_epoch + 40_000_000,
            .start_position = 0,
        }, "" },
    };
    inline for (.{
        Compression.copy,
        Compression.deflate,
        Compression.bzip2,
        Compression.lzma,
        Compression.lzma2,
        Compression.lzma2_stored,
        Compression.ppmd7,
    }) |metadata_compression| {
        const encoded = try encodeTestArchive(
            std.testing.allocator,
            .{
                .encode = .{
                    .compression = .lzma2,
                    .solid = true,
                    .header_compression = metadata_compression,
                    .external_names = metadata_compression,
                    .external_metadata = metadata_compression,
                },
            },
            &expected,
            7,
            2,
        );
        defer std.testing.allocator.free(encoded);
        const parsed = try archive.parseAlloc(std.testing.allocator, encoded);
        defer parsed.deinit();
        const entry = parsed.find("目录/payload.txt") orelse return error.EntryNotFound;
        try std.testing.expectEqual(expected[0][0].creation_time, entry.creation_time);
        try std.testing.expectEqual(expected[0][0].access_time, entry.access_time);
        try std.testing.expectEqual(expected[0][0].modification_time, entry.modification_time);
        try std.testing.expectEqual(expected[0][0].start_position, entry.start_position);
        try std.testing.expectEqual(expected[0][0].attributes, entry.attributes);
        const decoded = try parsed.extractEntryAlloc(std.testing.allocator, entry);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, payload, decoded);
    }
}

test "7z incremental writer encrypts terminal metadata with distinct IVs" {
    const archive = @import("archive.zig");
    const aes = @import("aes.zig");
    const password = "terminal metadata 密码";
    const encryption = coders.EncryptionOptions{
        .password = password,
        .iv = [_]u8{0x52} ** 16,
        .salt = [_]u8{0x25} ** 16,
        .salt_len = 8,
        .num_cycles_power = aes.direct_key_power,
    };
    const payload = "encrypted terminal metadata\n" ** 29;
    const expected = [_]struct { EntryOptions, []const u8 }{
        .{ .{
            .name = "secret/数据.txt",
            .expected_size = payload.len,
            .modification_time = 116_444_736_050_000_000,
            .attributes = 0x81a4_0020,
        }, payload },
    };
    const encoded = try encodeTestArchive(
        std.testing.allocator,
        .{
            .encode = .{
                .compression = .ppmd7,
                .solid = true,
                .header_compression = .lzma2,
                .external_names = .deflate,
                .external_metadata = .copy,
                .encryption = encryption,
                .encrypt_header = true,
            },
        },
        &expected,
        11,
        1,
    );
    defer std.testing.allocator.free(encoded);
    try std.testing.expectError(
        error.PasswordRequired,
        archive.parseAlloc(std.testing.allocator, encoded),
    );
    const parsed = try archive.parseAllocWithOptions(
        std.testing.allocator,
        encoded,
        .{ .password = password },
    );
    defer parsed.deinit();
    const entry = parsed.find("secret/数据.txt") orelse return error.EntryNotFound;
    const decoded = try parsed.decodeEntryAllocWithOptions(
        std.testing.allocator,
        entry,
        .{ .password = password },
    );
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "7z incremental writer enforces lifecycle and metadata limits" {
    try std.testing.expectError(
        error.SecondarySpoolRequired,
        Writer.init(std.testing.allocator, .{ .encode = .{ .bcj2 = true } }),
    );
    var tiny_metadata = try Writer.init(std.testing.allocator, .{ .max_metadata_size = 8 });
    defer tiny_metadata.deinit();
    try std.testing.expectError(
        error.OutputLimitExceeded,
        tiny_metadata.beginEntry(.{ .name = "name-too-long" }),
    );
    var limited = try Writer.init(std.testing.allocator, .{ .max_entries = 1 });
    defer limited.deinit();
    try limited.beginEntry(.{ .name = "a", .expected_size = 0 });
    try limited.finishEntry();
    try std.testing.expectError(
        error.OutputLimitExceeded,
        limited.beginEntry(.{ .name = "b", .expected_size = 0 }),
    );
    try std.testing.expectError(error.Invalid7zWriterState, limited.finishArchive());
    try std.testing.expectError(
        error.Invalid7zEntry,
        limited.beginEntry(.{
            .name = "invalid-anti",
            .is_anti = true,
            .expected_size = 1,
        }),
    );
    while (limited.snapshot().phase == .start_header) {
        var output: [7]u8 = undefined;
        _ = try limited.step(&.{}, &output);
    }
    try limited.finishArchive();
    try std.testing.expectError(error.StartHeaderPatchUnavailable, limited.startHeaderPatch());

    const long_name = "n" ** 400;
    var terminal_limited = try Writer.init(std.testing.allocator, .{
        .encode = .{ .external_names = .copy, .header_compression = .copy },
        .max_metadata_size = 1024,
    });
    defer terminal_limited.deinit();
    try terminal_limited.beginEntry(.{ .name = long_name, .expected_size = 0 });
    try terminal_limited.finishEntry();
    while (terminal_limited.snapshot().phase == .start_header) {
        var output: [32]u8 = undefined;
        _ = try terminal_limited.step(&.{}, &output);
    }
    try std.testing.expectError(error.OutputLimitExceeded, terminal_limited.finishArchive());
    try std.testing.expectEqual(Phase.ready, terminal_limited.snapshot().phase);
}

test "7z incremental writer releases every allocation failure" {
    const FailureTest = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const payload = "allocation-safe incremental 7z payload\n" ** 17;
            const expected = [_]struct { EntryOptions, []const u8 }{
                .{ .{
                    .name = "payload.txt",
                    .expected_size = payload.len,
                    .modification_time = 116_444_736_010_000_000,
                    .attributes = 0x81a4_0020,
                }, payload },
                .{ .{ .name = "empty.txt", .expected_size = 0 }, "" },
            };
            const encoded = try encodeTestArchive(
                allocator,
                .{
                    .encode = .{
                        .compression = .deflate,
                        .header_compression = .lzma2_stored,
                        .external_names = .copy,
                        .external_metadata = .copy,
                    },
                },
                &expected,
                13,
                5,
            );
            defer allocator.free(encoded);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        FailureTest.run,
        .{},
    );

    const Bcj2FailureTest = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const payload = "\x90\xe8\x10\x00\x00\x00branch" ** 41;
            const expected = [_]struct { EntryOptions, []const u8 }{
                .{ .{ .name = "branch.bin", .expected_size = payload.len }, payload },
            };
            var spool = TestSecondarySpool.init(std.heap.page_allocator);
            defer spool.deinit();
            const encoded = try encodeTestArchive(
                allocator,
                .{
                    .encode = .{ .compression = .copy, .bcj2 = true },
                    .bcj2_spool = spool.descriptor(),
                    .bcj2_spool_read_buffer_size = 3,
                },
                &expected,
                11,
                2,
            );
            defer allocator.free(encoded);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        Bcj2FailureTest.run,
        .{},
    );
}

fn encodeTestArchive(
    allocator: std.mem.Allocator,
    options: Options,
    expected: []const struct { EntryOptions, []const u8 },
    input_chunk_len: usize,
    output_chunk_len: usize,
) ![]u8 {
    var writer = try Writer.init(allocator, options);
    defer writer.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(allocator);
    try std.testing.expectError(error.StartHeaderPatchUnavailable, writer.startHeaderPatch());

    for (expected) |item| {
        try writer.beginEntry(item[0]);
        var input_offset: usize = 0;
        while (input_offset < item[1].len) {
            const end = @min(item[1].len, input_offset + input_chunk_len);
            var output_storage: [32]u8 = undefined;
            const stepped = try writer.step(
                item[1][input_offset..end],
                output_storage[0..output_chunk_len],
            );
            input_offset += stepped.progress.input_read;
            try encoded.appendSlice(allocator, output_storage[0..stepped.progress.output_written]);
        }
        try writer.finishEntry();
        while (writer.snapshot().phase != .ready and writer.snapshot().phase != .start_header) {
            var output_storage: [32]u8 = undefined;
            const stepped = try writer.step(&.{}, output_storage[0..output_chunk_len]);
            try encoded.appendSlice(allocator, output_storage[0..stepped.progress.output_written]);
        }
    }
    while (writer.snapshot().phase == .start_header) {
        var output_storage: [32]u8 = undefined;
        const stepped = try writer.step(&.{}, output_storage[0..output_chunk_len]);
        try encoded.appendSlice(allocator, output_storage[0..stepped.progress.output_written]);
    }
    try writer.finishArchive();
    while (true) {
        var output_storage: [32]u8 = undefined;
        const stepped = try writer.step(&.{}, output_storage[0..output_chunk_len]);
        try encoded.appendSlice(allocator, output_storage[0..stepped.progress.output_written]);
        if (stepped.status == .done) break;
    }
    const patch = try writer.startHeaderPatch();
    try std.testing.expect(encoded.items.len >= patch.len);
    @memcpy(encoded.items[0..patch.len], &patch);
    return encoded.toOwnedSlice(allocator);
}
