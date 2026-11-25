//! Write independent Zstandard frames and a terminal seek table to a sink.
const std = @import("std");
const byte_source = @import("../../io/source.zig");
const byte_sink = @import("../../io/sink.zig");
const count = @import("../../core.zig").stream_count;
const seekable = @import("../seekable.zig");
const stable = @import("../decode/stable_output.zig");
const encode_controls = @import("../encode/controls.zig");
const total_budget = @import("../encode/total_budget.zig");

pub const Requirements = struct {
    frame_input_len: usize,
    frame_count: usize,
    table_bytes: usize,
};

pub const Workspace = struct {
    frame_input: []u8,
    entries: []seekable.FrameSize,
};

pub const Result = struct {
    input_read: u64,
    output_written: u64,
    frame_count: usize,
};

pub fn Error(comptime Codec: type) type {
    return Codec.Error || byte_source.Error || byte_sink.Error;
}

pub fn ReaderError(comptime Codec: type) type {
    return Codec.Error || std.Io.Reader.ShortError || std.Io.Writer.Error;
}

fn validateOptions(comptime Codec: type, options: Codec.Options) Codec.Error!void {
    var validation = options;
    validation.frame_options.control_profile = null;
    try Codec.validateOptions(validation);
}

pub fn requirements(comptime Codec: type, input_len: u64, options: Codec.Options) Codec.Error!Requirements {
    try validateOptions(Codec, options);
    const frame_size: u64 = options.frame_size;
    const frame_count = if (input_len == 0) 1 else 1 + (input_len - 1) / frame_size;
    if (frame_count > seekable.max_frames) return error.InvalidBlockPlan;
    const local_count: usize = @intCast(frame_count);
    return .{
        .frame_input_len = @intCast(@min(frame_size, input_len)),
        .frame_count = local_count,
        .table_bytes = try seekable.encodedTableBound(local_count, options.seek_checksums),
    };
}

pub fn encode(
    comptime Codec: type,
    allocator: std.mem.Allocator,
    source: byte_source.Source,
    sink: byte_sink.Sink,
    workspace: Workspace,
    options: Codec.Options,
    dictionary: ?Codec.Dictionary,
) Error(Codec)!Result {
    const required = try requirements(Codec, source.len, options);
    if (workspace.frame_input.len < required.frame_input_len or workspace.entries.len < required.frame_count)
        return error.OutputTooSmall;
    const frame_input = workspace.frame_input[0..required.frame_input_len];
    const entries = workspace.entries[0..required.frame_count];
    try validateBorrows(Codec, frame_input, std.mem.sliceAsBytes(entries), options, dictionary, &.{});
    if (sink.max_write_size == 0) return error.SinkWriteFailed;
    const config: ArchiveConfig(Codec) = .{ .sink = sink, .options = options, .dictionary = dictionary };
    var archive: ArchiveWriter(Codec) = undefined;
    try archive.init(allocator, &config);
    defer archive.deinit();
    errdefer archive.emission.rollback();
    for (entries) |*entry| {
        const plain = frame_input[0..count.bounded(source.len - archive.read, frame_input.len)];
        if (plain.len != 0) try source.readExact(archive.read, plain);
        try archive.writeFrame(plain, entry);
    }
    std.debug.assert(archive.read == source.len);
    return archive.finish(entries);
}

pub fn encodeReader(
    comptime Codec: type,
    allocator: std.mem.Allocator,
    reader: *std.Io.Reader,
    writer: *std.Io.Writer,
    workspace: Workspace,
    options: Codec.Options,
    dictionary: ?Codec.Dictionary,
) ReaderError(Codec)!Result {
    try validateOptions(Codec, options);
    if (workspace.frame_input.len < options.frame_size or workspace.entries.len == 0)
        return error.OutputTooSmall;
    const frame_input = workspace.frame_input[0..options.frame_size];
    const entries = workspace.entries[0..@min(workspace.entries.len, seekable.max_frames)];
    try validateBorrows(Codec, frame_input, std.mem.sliceAsBytes(entries), options, dictionary, &.{
        std.mem.asBytes(reader), reader.buffer, std.mem.asBytes(writer), writer.buffer,
    });
    const config: ArchiveConfig(Codec) = .{ .sink = writerSink(writer), .options = options, .dictionary = dictionary };
    var archive: ArchiveWriter(Codec) = undefined;
    try archive.init(allocator, &config);
    defer archive.deinit();
    errdefer archive.emission.rollback();
    while (true) {
        if (archive.frames == entries.len) {
            // Check exact frame multiples without consuming a full extra frame.
            var probe: [1]u8 = undefined;
            if (try reader.readSliceShort(&probe) != 0) return error.OutputLimitExceeded;
            break;
        }
        const len = try reader.readSliceShort(frame_input);
        if (len == 0 and archive.frames != 0) break;
        archive.writeFrame(frame_input[0..len], &entries[archive.frames]) catch |err| return readerWriteError(Codec, err);
        if (len != frame_input.len) break;
    }
    return archive.finish(entries[0..archive.frames]) catch |err| readerWriteError(Codec, err);
}

fn readerWriteError(comptime Codec: type, err: (Codec.Error || byte_sink.Error)) ReaderError(Codec) {
    return switch (err) {
        error.SinkWriteFailed => error.WriteFailed,
        else => @errorCast(err),
    };
}

fn ArchiveConfig(comptime Codec: type) type {
    return struct {
        sink: byte_sink.Sink,
        options: Codec.Options,
        dictionary: ?Codec.Dictionary,
    };
}

fn ArchiveWriter(comptime Codec: type) type {
    return struct {
        const Self = @This();
        const WriteError = Codec.Error || byte_sink.Error;

        sink: byte_sink.Sink,
        memory: total_budget.Entry,
        encoder: Codec.FrameEncoder,
        emission: encode_controls.EmissionTransaction,
        frame_options: @FieldType(Codec.Options, "frame_options"),
        dictionary: ?Codec.Dictionary,
        seek_checksums: bool,
        read: u64,
        written: u64,
        frames: usize,

        fn init(self: *Self, allocator: std.mem.Allocator, config: *const ArchiveConfig(Codec)) Codec.Error!void {
            if (config.dictionary) |dict| try Codec.validateDictionary(dict);
            self.memory = try total_budget.Entry.init(allocator, config.options.frame_options);
            self.encoder = Codec.FrameEncoder.init(self.memory.allocator());
            self.emission = encode_controls.EmissionTransaction.init(config.options.frame_options.control_profile);
            self.frame_options = self.memory.forward(config.options.frame_options);
            self.sink = config.sink;
            self.dictionary = config.dictionary;
            self.seek_checksums = config.options.seek_checksums;
            self.read = 0;
            self.written = 0;
            self.frames = 0;
        }

        fn deinit(self: *Self) void {
            self.encoder.deinit();
            self.memory.deinit();
        }

        fn writeFrame(self: *Self, plain: []const u8, entry: *seekable.FrameSize) WriteError!void {
            const next_read = try count.addLocal(self.read, plain.len);
            const selected = if (self.frame_options.dictionary_usage == .prefix and self.frames != 0) null else self.dictionary;
            const frame = (if (selected) |dict|
                self.encoder.encodeScratchWithDictionary(plain, self.frame_options, dict)
            else
                self.encoder.encodeScratch(plain, self.frame_options)) catch |err| return @errorCast(self.memory.mapError(err));
            const value = try Codec.frameSize(frame.frame.len, plain, self.seek_checksums);
            const next_written = try count.addLocal(self.written, frame.frame.len);
            try self.sink.writeExact(self.written, frame.frame);
            entry.* = value;
            self.frames += 1;
            self.written = next_written;
            self.read = next_read;
        }

        fn finish(self: *Self, entries: []const seekable.FrameSize) WriteError!Result {
            const end = try seekable.encodeTableTo(self.sink, self.written, entries, self.seek_checksums);
            try self.sink.finish(end);
            return .{ .input_read = self.read, .output_written = end, .frame_count = self.frames };
        }
    };
}

fn writerSink(writer: *std.Io.Writer) byte_sink.Sink {
    const Adapter = struct {
        fn writeAt(context: *anyopaque, _: u64, bytes: []const u8) error{SinkWriteFailed}!usize {
            const out: *std.Io.Writer = @ptrCast(@alignCast(context));
            out.writeAll(bytes) catch return error.SinkWriteFailed;
            return bytes.len;
        }

        // The caller owns the writer, including its final flush.
        fn finish(_: *anyopaque, _: u64) error{SinkWriteFailed}!void {}
    };
    return .{ .context = writer, .write_at = Adapter.writeAt, .set_len = Adapter.finish, .max_write_size = std.math.maxInt(usize) };
}

fn validateBorrows(
    comptime Codec: type,
    frame_input: []const u8,
    table_entries: []const u8,
    options: Codec.Options,
    dictionary: ?Codec.Dictionary,
    io_regions: []const []const u8,
) Codec.Error!void {
    const control: []const u8 = if (options.frame_options.control_profile) |profile| std.mem.asBytes(profile) else &.{};
    const memory: []const u8 = if (options.frame_options.memory_profile) |profile| std.mem.asBytes(profile) else &.{};
    const base = [_][]const u8{ frame_input, table_entries, control, memory };
    if (io_regions.len == 0) return validateRegions(Codec, &base, dictionary);
    std.debug.assert(io_regions.len == 4);
    const extended = [_][]const u8{ frame_input, table_entries, control, memory, io_regions[0], io_regions[1], io_regions[2], io_regions[3] };
    return validateRegions(Codec, &extended, dictionary);
}

fn validateRegions(comptime Codec: type, regions: []const []const u8, dictionary: ?Codec.Dictionary) Codec.Error!void {
    for (regions, 0..) |left, i| {
        for (regions[i + 1 ..]) |right| try stable.validateAlias(left, right);
        if (dictionary) |dict| {
            try stable.validateAlias(left, dict.content);
            if (dict.standard_bytes) |bytes| try stable.validateAlias(left, bytes);
            if (dict.prepared) |prepared| try stable.validateAlias(left, std.mem.asBytes(prepared));
        }
    }
}
