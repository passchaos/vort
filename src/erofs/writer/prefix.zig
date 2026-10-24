const lz4 = @import("../../lz4.zig");
const core = @import("../../core.zig");

pub const Result = struct {
    bytes: []const u8,
    consumed: usize,
};

pub fn selectLz4(input: []const u8, output: []u8, alignment: usize) (core.Error || lz4.Error)!Result {
    if (alignment == 0) return error.InvalidBlockPlan;
    if (input.len == 0) return .{ .bytes = &.{}, .consumed = 0 };
    var target = input.len;
    while (target != 0) {
        const result = try lz4.encodeBlockDestSize(input[0..target], output);
        if (result.consumed == target)
            return .{ .bytes = output[0..result.written], .consumed = target };
        target = result.consumed / alignment * alignment;
    }
    return .{ .bytes = &.{}, .consumed = 0 };
}

/// Portable complete-frame reference path. Check aligned candidates in
/// descending order: encoded size need not be monotonic when the parser and
/// entropy tables are rebuilt for a shorter input. The first fitting candidate
/// is therefore the longest prefix under this encoder's complete-frame policy.
pub fn selectFrames(encoder: anytype, input: []const u8, capacity: usize, alignment: usize) !Result {
    if (alignment == 0) return error.InvalidBlockPlan;
    if (input.len == 0) return Result{ .bytes = &.{}, .consumed = 0 };
    var target = input.len;
    while (target != 0) {
        const encoded = try encoder.encodeScratch(input[0..target]);
        if (encoded.len != 0 and encoded.len <= capacity and encoded.len < target)
            return Result{ .bytes = encoded, .consumed = target };
        if (target == input.len and target % alignment != 0) {
            target = target / alignment * alignment;
        } else if (target >= alignment) {
            target -= alignment;
        } else {
            target = 0;
        }
    }
    return Result{ .bytes = &.{}, .consumed = 0 };
}
