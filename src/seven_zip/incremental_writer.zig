const std = @import("std");
const checksum = @import("../checksum.zig");
const core = @import("../core.zig");
const coders = @import("coders.zig");
const types = @import("types.zig");
const wire = @import("writer_wire.zig");
const codecs = @import("incremental_writer/codecs.zig");

pub const Compression = coders.Compression;
pub const EncodeOptions = coders.Options;

pub const Error = core.Error || coders.Error || codecs.Error || std.mem.Allocator.Error || error{
    Invalid7zEntry,
    Invalid7zIncrementalOptions,
    Invalid7zWriterState,
    SevenZipWriterPoisoned,
    StartHeaderPatchUnavailable,
};

pub const Options = struct {
    encode: EncodeOptions = .{},
    max_entries: u64 = std.math.maxInt(u64),
    max_metadata_size: usize = 64 * 1024 * 1024,
};

pub const EntryOptions = struct {
    name: []const u8,
    kind: types.Kind = .file,
    expected_size: ?u64 = null,
    creation_time: ?u64 = null,
    access_time: ?u64 = null,
    modification_time: ?u64 = null,
    attributes: ?u32 = null,
};

pub const Phase = enum {
    start_header,
    ready,
    entry_data,
    solid_finish,
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
    expected_size: ?u64,
    creation_time: ?u64,
    access_time: ?u64,
    modification_time: ?u64,
    attributes: ?u32,
    codec: ?codecs.Encoder = null,
    encode_options: EncodeOptions,
    crc: checksum.Crc32Best = .{},
    uncompressed_size: u64 = 0,
    compressed_size: u64 = 0,
    finish_requested: bool = false,
    has_stream: bool = false,

    fn deinit(self: *CurrentEntry, allocator: std.mem.Allocator) void {
        if (self.codec) |*codec| codec.deinit();
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
    next_header: std.ArrayList(u8) = .empty,
    next_header_offset: usize = 0,
    next_header_crc32: u32 = 0,
    packed_output: u64 = 0,
    archive_output: u64 = 0,
    total_input: u64 = 0,
    next_encryption_stream_index: u64,
    solid_codec: ?codecs.Encoder = null,
    solid_options: EncodeOptions,
    solid_crc: checksum.Crc32Best = .{},
    solid_uncompressed_size: u64 = 0,
    solid_packed_size: u64 = 0,
    solid_substream_count: usize = 0,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, options: Options) Error!Self {
        try coders.validate(options.encode);
        try codecs.State.validate(options.encode);
        if (options.max_entries == 0 or options.max_metadata_size == 0 or
            options.encode.header_compression != null or
            options.encode.external_names != null or options.encode.external_metadata != null or
            options.encode.encrypt_header or options.encode.bcj2)
        {
            return error.Invalid7zIncrementalOptions;
        }
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
        for (self.entries.items) |entry| self.allocator.free(@constCast(entry.name));
        self.entries.deinit(self.allocator);
        self.folders.deinit(self.allocator);
        self.folder_options.deinit(self.allocator);
        self.substreams.deinit(self.allocator);
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
            .expected_size = entry_options.expected_size,
            .creation_time = entry_options.creation_time,
            .access_time = entry_options.access_time,
            .modification_time = entry_options.modification_time,
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
            codec.finish();
            return;
        }
        try self.finalizeCurrent(false);
    }

    pub fn finishArchive(self: *Self) Error!void {
        if (self.phase == .poisoned) return error.SevenZipWriterPoisoned;
        if (self.phase != .ready or self.current != null) return error.Invalid7zWriterState;
        if (self.options.encode.solid and self.solid_codec != null) {
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
        var header: std.ArrayList(u8) = .empty;
        errdefer header.deinit(self.allocator);
        const external_streams = wire.EncodedExternalStreams{};
        try wire.writeNextHeader(
            self.allocator,
            &header,
            self.entries.items,
            self.folders.items,
            self.folder_options.items,
            self.substreams.items,
            self.options.encode,
            names.items,
            &external_streams,
        );
        if (header.items.len > self.options.max_metadata_size) return error.OutputLimitExceeded;

        self.next_header.deinit(self.allocator);
        self.next_header = header;
        self.next_header_offset = 0;
        self.next_header_crc32 = checksum.crc32Best(self.next_header.items);
        self.phase = .next_header;
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
                    if (current.kind != .file) return error.Invalid7zEntry;
                    if (output_written == output.len)
                        return result(input_read, output_written, .need_output);
                    try self.checkExpectedOffer(current, input.len - input_read);
                    if (solid) {
                        if (self.solid_codec == null) {
                            self.solid_options = self.options.encode;
                            if (self.solid_options.encryption != null) {
                                self.solid_options.encryption_stream_index = self.next_encryption_stream_index;
                                self.next_encryption_stream_index = std.math.add(
                                    u64,
                                    self.next_encryption_stream_index,
                                    1,
                                ) catch return error.IntegerOverflow;
                            }
                            self.solid_codec = try codecs.Encoder.init(
                                self.allocator,
                                self.solid_options,
                                null,
                            );
                        }
                        current.encode_options = self.solid_options;
                    } else {
                        current.encode_options = self.options.encode;
                        if (current.encode_options.encryption != null) {
                            current.encode_options.encryption_stream_index = self.next_encryption_stream_index;
                            self.next_encryption_stream_index = std.math.add(
                                u64,
                                self.next_encryption_stream_index,
                                1,
                            ) catch return error.IntegerOverflow;
                        }
                        current.codec = try codecs.Encoder.init(
                            self.allocator,
                            current.encode_options,
                            current.expected_size,
                        );
                    }
                    current.has_stream = true;
                }
                if (current.finish_requested and input_read != input.len)
                    return error.TrailingData;
                if (!current.finish_requested)
                    try self.checkExpectedOffer(current, input.len - input_read);
                if (output_written == output.len)
                    return result(input_read, output_written, .need_output);

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
                    try self.finalizeSolidFolder();
                    try self.prepareNextHeader();
                    if (output_written == output.len)
                        return result(input_read, output_written, .need_output);
                    continue;
                }
                if (encoded.status != .need_output) return error.InvalidBlockPlan;
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
            .creation_time = current.creation_time,
            .access_time = current.access_time,
            .modification_time = current.modification_time,
            .attributes = current.attributes,
        };
        if (has_stream) {
            const substream_index = self.substreams.items.len;
            const digest = current.crc.digest();
            if (self.options.encode.solid) {
                self.solid_substream_count += 1;
            } else {
                self.folders.appendAssumeCapacity(.{
                    .packed_sizes = .{ current.compressed_size, 0, 0, 0 },
                    .unpacked_size = current.uncompressed_size,
                    .aes_unpack_sizes = .{
                        current.codec.?.aesUnpackSize(),
                        null,
                        null,
                        null,
                    },
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
        self.entries.appendAssumeCapacity(entry);
        self.current = null;
        self.phase = if (self.start_header_offset == wire.start_header_len) .ready else .start_header;
    }

    fn finalizeSolidFolder(self: *Self) Error!void {
        std.debug.assert(self.solid_codec != null and self.solid_substream_count != 0);
        try self.folders.ensureUnusedCapacity(self.allocator, 1);
        try self.folder_options.ensureUnusedCapacity(self.allocator, 1);
        self.folders.appendAssumeCapacity(.{
            .packed_sizes = .{ self.solid_packed_size, 0, 0, 0 },
            .unpacked_size = self.solid_uncompressed_size,
            .aes_unpack_sizes = .{
                self.solid_codec.?.aesUnpackSize(),
                null,
                null,
                null,
            },
            .crc32 = self.solid_crc.digest(),
            .first_substream = 0,
            .substream_count = self.solid_substream_count,
        });
        self.folder_options.appendAssumeCapacity(self.solid_options);
        self.solid_codec.?.deinit();
        self.solid_codec = null;
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

    fn metadataSize(self: *const Self) usize {
        var size = self.next_header.capacity;
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

test "7z incremental writer streams copy entries and exposes a final patch" {
    const archive = @import("archive.zig");
    const expected = [_]struct { EntryOptions, []const u8 }{
        .{ .{ .name = "hello.txt", .expected_size = "hello seven zip\n".len }, "hello seven zip\n" },
        .{ .{ .name = "empty.txt", .expected_size = 0 }, "" },
        .{ .{ .name = "folder", .kind = .directory }, "" },
        .{ .{ .name = "utf8-数据.txt", .expected_size = 7 }, "payload" },
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
        if (item[1].len != 0) {
            const decoded = try parsed.extractEntryAlloc(std.testing.allocator, entry);
            defer std.testing.allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, item[1], decoded);
        } else {
            try std.testing.expectEqual(@as(?usize, null), entry.folder_index);
        }
    }
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

test "7z incremental writer enforces lifecycle and metadata limits" {
    try std.testing.expectError(
        error.Invalid7zIncrementalOptions,
        Writer.init(std.testing.allocator, .{ .encode = .{ .header_compression = .copy } }),
    );
    try std.testing.expectError(
        error.Invalid7zIncrementalOptions,
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
    while (limited.snapshot().phase == .start_header) {
        var output: [7]u8 = undefined;
        _ = try limited.step(&.{}, &output);
    }
    try limited.finishArchive();
    try std.testing.expectError(error.StartHeaderPatchUnavailable, limited.startHeaderPatch());
}

test "7z incremental writer releases every allocation failure" {
    const FailureTest = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const payload = "allocation-safe incremental 7z payload\n" ** 17;
            const expected = [_]struct { EntryOptions, []const u8 }{
                .{ .{ .name = "payload.txt", .expected_size = payload.len }, payload },
                .{ .{ .name = "empty.txt", .expected_size = 0 }, "" },
            };
            const encoded = try encodeTestArchive(
                allocator,
                .{ .encode = .{ .compression = .deflate } },
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
