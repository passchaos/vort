//! In-memory restart data for a trusted Deflate block boundary.
const std = @import("std");
const core = @import("../../core.zig");
const count = core.stream_count;
const position = @import("block_boundary_position.zig");
const borrows = @import("decoder/step_borrows.zig");
const overlaps = @import("../decoder/output_alias.zig").overlaps;

pub const Point = struct {
    position: position.Position,
    /// Distinguishes the public 32 KiB Deflate and 64 KiB Deflate64 decoders.
    window_size: usize,
    max_distance: usize,
    /// Caller-owned history, oldest byte first.
    history: []const u8,
};

pub fn captureRaw(raw: anytype, output: []u8) core.Error!Point {
    const at = raw.blockBoundaryPosition() orelse return error.InvalidStreamState;
    const saved = try prepareCapture(raw, std.mem.asBytes(raw), output);
    return capturePrepared(raw, at, saved);
}

pub fn captureWrapper(wrapper: anytype, receiver: []const u8, output: []u8) core.Error!Point {
    if (wrapper.phase != .raw) return error.InvalidStreamState;
    const at = wrapper.blockBoundaryPosition() orelse return error.InvalidStreamState;
    const raw = &wrapper.raw;
    const saved = try prepareCapture(raw, receiver, output);
    // The zlib decoder retains dictionary bindings across member transitions.
    if (comptime @hasField(@TypeOf(wrapper.*), "dictionary_available")) {
        if (wrapper.dictionary_available)
            try borrows.validateDictionary(receiver, raw.history, saved, wrapper.dictionary);
        if (wrapper.dictionaries) |set|
            try borrows.validateSet(receiver, raw.history, saved, set);
    }
    return capturePrepared(raw, at, saved);
}

fn distanceLimit(raw: anytype) usize {
    return @min(raw.options.max_distance, @TypeOf(raw.*).required_history_len);
}

fn prepareCapture(raw: anytype, receiver: []const u8, output: []u8) core.Error![]u8 {
    if (raw.phase != .block_header) return error.InvalidStreamState;
    const len = @min(raw.history_len, distanceLimit(raw));
    if (output.len < len) return error.OutputTooSmall;
    const saved = output[0..len];
    if (!try borrows.rawAdmission(receiver, raw, &.{}, saved) or overlaps(saved, raw.semantic_scratch))
        return error.InvalidBlockPlan;
    return saved;
}

fn capturePrepared(raw: anytype, at: position.Position, saved: []u8) Point {
    if (saved.len != 0) {
        const start = if (raw.history_pos >= saved.len)
            raw.history_pos - saved.len
        else
            raw.history.len - (saved.len - raw.history_pos);
        const first = @min(saved.len, raw.history.len - start);
        @memcpy(saved[0..first], raw.history[start..][0..first]);
        @memcpy(saved[first..], raw.history[0 .. saved.len - first]);
    }
    return .{
        .position = at,
        .window_size = @TypeOf(raw.*).required_history_len,
        .max_distance = distanceLimit(raw),
        .history = saved,
    };
}

pub fn restore(raw: anytype, point: Point, initial_byte: ?u8, options: @TypeOf(raw.*).Options) core.Error!core.StreamCount {
    const at = point.position;
    const aligned = at.compressed_bit_offset == 0;
    if (point.window_size != @TypeOf(raw.*).required_history_len or
        point.max_distance > point.window_size or point.history.len > point.max_distance or
        aligned != (initial_byte == null)) return error.InvalidBlockPlan;
    const accepted = try count.addLocal(at.compressed_byte_offset, @intFromBool(initial_byte != null));
    if (at.decoded_offset > options.max_output_len) return error.OutputLimitExceeded;
    if (options.expected_output_len) |expected| {
        if (at.decoded_offset > expected) return error.SizeMismatch;
    }
    const max_distance = @min(options.max_distance, point.max_distance);
    const keep = @min(point.history.len, max_distance);
    if (raw.history.len < keep) return error.OutputTooSmall;
    if (!try borrows.rawAdmission(std.mem.asBytes(raw), raw, point.history, &.{}) or
        overlaps(point.history, raw.semantic_scratch)) return error.InvalidBlockPlan;

    // Everything fallible is checked before resetting state or writing history.
    raw.reset();
    raw.options = options;
    raw.options.max_distance = max_distance;
    @memcpy(raw.history[0..keep], point.history[point.history.len - keep ..]);
    raw.history_len = keep;
    raw.history_pos = if (keep == raw.history.len) 0 else keep;
    raw.total_input = accepted;
    raw.total_output = at.decoded_offset;
    if (initial_byte) |byte| {
        raw.bit_buffer = byte >> at.compressed_bit_offset;
        raw.bit_count = 8 - @as(u6, at.compressed_bit_offset);
    }
    return accepted;
}
