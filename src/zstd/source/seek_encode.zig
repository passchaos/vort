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

pub fn requirements(comptime Codec: type, input_len: u64, options: Codec.Options) Codec.Error!Requirements {
    var validation = options;
    validation.frame_options.control_profile = null;
    try Codec.validateOptions(validation);
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
    try validateBorrows(Codec, frame_input, std.mem.sliceAsBytes(entries), options, dictionary);
    if (sink.max_write_size == 0) return error.SinkWriteFailed;
    if (dictionary) |dict| try Codec.validateDictionary(dict);

    const emission = encode_controls.EmissionTransaction.init(options.frame_options.control_profile);
    errdefer emission.rollback();
    var memory = try total_budget.Entry.init(allocator, options.frame_options);
    defer memory.deinit();
    const frame_options = memory.forward(options.frame_options);
    var encoder = Codec.FrameEncoder.init(memory.allocator());
    defer encoder.deinit();
    var read: u64 = 0;
    var written: u64 = 0;
    for (entries, 0..) |*entry, frame_index| {
        const plain = frame_input[0..count.bounded(source.len - read, frame_input.len)];
        if (plain.len != 0) try source.readExact(read, plain);
        const selected = if (frame_options.dictionary_usage == .prefix and frame_index != 0) null else dictionary;
        const frame = (if (selected) |dict|
            encoder.encodeScratchWithDictionary(plain, frame_options, dict)
        else
            encoder.encodeScratch(plain, frame_options)) catch |err| return @errorCast(memory.mapError(err));
        const value = try Codec.frameSize(frame.frame.len, plain, options.seek_checksums);
        const next = try count.addLocal(written, frame.frame.len);
        try sink.writeExact(written, frame.frame);
        entry.* = value;
        written = next;
        read = try count.addLocal(read, plain.len);
    }
    std.debug.assert(read == source.len);
    written = try seekable.encodeTableTo(sink, written, entries, options.seek_checksums);
    try sink.finish(written);
    return .{ .input_read = read, .output_written = written, .frame_count = entries.len };
}

fn validateBorrows(
    comptime Codec: type,
    frame_input: []const u8,
    table_entries: []const u8,
    options: Codec.Options,
    dictionary: ?Codec.Dictionary,
) Codec.Error!void {
    const control: []const u8 = if (options.frame_options.control_profile) |profile| std.mem.asBytes(profile) else &.{};
    const memory: []const u8 = if (options.frame_options.memory_profile) |profile| std.mem.asBytes(profile) else &.{};
    const mutable = [_][]const u8{ frame_input, table_entries, control, memory };
    for (mutable, 0..) |left, i| {
        for (mutable[i + 1 ..]) |right| try stable.validateAlias(left, right);
        if (dictionary) |dict| {
            try stable.validateAlias(left, dict.content);
            if (dict.standard_bytes) |bytes| try stable.validateAlias(left, bytes);
            if (dict.prepared) |prepared| try stable.validateAlias(left, std.mem.asBytes(prepared));
        }
    }
}
