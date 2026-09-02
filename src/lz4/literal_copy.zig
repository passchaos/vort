const std = @import("std");
const builtin = @import("builtin");

/// Copy one validated LZ4 literal span into its decoded output.
///
/// The decoder has already established that source and destination do not
/// overlap. Large final literals are common for incompressible data, so keep
/// their bulk copy in a simple, explicitly unrolled vector loop rather than
/// relying on the generic compiler-rt memcpy selected for unknown targets.
/// This stays out of line so the uncommon stored-like path does not inflate the
/// token/match loop used by ordinary compressed blocks.
pub const bulk_min_len = 512;
const rep_movsb_min_len = 192 * 1024;

pub noinline fn copyBulk(destination: []u8, source: []const u8) void {
    std.debug.assert(destination.len == source.len);
    std.debug.assert(source.len >= bulk_min_len);
    if (source.len >= rep_movsb_min_len and comptime builtin.cpu.arch == .x86_64) {
        var destination_ptr = destination.ptr;
        var source_ptr = source.ptr;
        var len = source.len;
        asm volatile ("rep movsb"
            : [destination] "={di}" (destination_ptr),
              [source] "={si}" (source_ptr),
              [len] "={cx}" (len),
            : [destination_input] "0" (destination_ptr),
              [source_input] "1" (source_ptr),
              [len_input] "2" (len),
            : .{ .memory = true });
        return;
    }
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

test "LZ4 literal copy covers large architecture path" {
    const len = rep_movsb_min_len + 37;
    const source = try std.testing.allocator.alloc(u8, len);
    defer std.testing.allocator.free(source);
    const destination = try std.testing.allocator.alloc(u8, len);
    defer std.testing.allocator.free(destination);
    for (source, 0..) |*byte, index| byte.* = @truncate(index *% 131);
    @memset(destination, 0);
    copyBulk(destination, source);
    try std.testing.expectEqualSlices(u8, source, destination);
}
