const std = @import("std");

/// Copy one validated LZ4 literal span into its decoded output.
///
/// The decoder has already established that source and destination do not
/// overlap. Large final literals are common for incompressible data, so keep
/// their bulk copy in a simple, explicitly unrolled vector loop rather than
/// relying on the generic compiler-rt memcpy selected for unknown targets.
/// This stays out of line so the uncommon stored-like path does not inflate the
/// token/match loop used by ordinary compressed blocks.
pub const bulk_min_len = 512;

pub noinline fn copyBulk(destination: []u8, source: []const u8) void {
    std.debug.assert(destination.len == source.len);
    std.debug.assert(source.len >= bulk_min_len);
    const vector_bytes = 32;
    const vectors_per_loop = 4;
    const loop_bytes = vector_bytes * vectors_per_loop;
    const Vector = @Vector(vector_bytes, u8);
    var offset: usize = 0;
    while (source.len - offset >= loop_bytes) : (offset += loop_bytes) {
        inline for (0..vectors_per_loop) |vector_index| {
            const vector_offset = offset + vector_index * vector_bytes;
            const value: Vector = source[vector_offset..][0..vector_bytes].*;
            destination[vector_offset..][0..vector_bytes].* = value;
        }
    }
    while (source.len - offset >= vector_bytes) : (offset += vector_bytes) {
        const value: Vector = source[offset..][0..vector_bytes].*;
        destination[offset..][0..vector_bytes].* = value;
    }
    while (offset < source.len) : (offset += 1) {
        destination[offset] = source[offset];
    }
}

test "LZ4 literal copy covers vector boundaries" {
    var source: [641]u8 = undefined;
    for (&source, 0..) |*byte, index| byte.* = @truncate(index *% 37);

    var destination: [source.len]u8 = undefined;
    for ([_]usize{ 512, 513, 640, source.len }) |len| {
        @memset(&destination, 0);
        copyBulk(destination[0..len], source[0..len]);
        try std.testing.expectEqualSlices(u8, source[0..len], destination[0..len]);
    }
}
