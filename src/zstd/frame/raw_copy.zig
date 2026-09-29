const std = @import("std");
const builtin = @import("builtin");

const block_size_max: usize = 128 * 1024;
const vector_copy_min_len: usize = 4 * 1024;
const non_temporal_min_len: usize = 64 * 1024;
const has_non_temporal_copy = builtin.cpu.arch == .aarch64 and
    std.Target.aarch64.featureSetHas(builtin.cpu.features, .neon) and
    std.mem.eql(u8, builtin.cpu.model.name, "apple_m1");

/// A complete frame of this size exceeds the working set where cached copies
/// win on Apple M1. Keep short blocks cached even when the frame is large.
pub const streaming_frame_min_len: usize = 256 * 1024;

pub inline fn copy(destination: []u8, source: []const u8, large_frame: bool) void {
    if (comptime has_non_temporal_copy) {
        if (large_frame and source.len >= non_temporal_min_len) {
            return copyNonTemporal(destination, source);
        }
    }
    copyCached(destination, source);
}

noinline fn copyCached(destination: []u8, source: []const u8) align(256) void {
    std.debug.assert(destination.len == source.len);
    if (comptime builtin.cpu.arch == .aarch64) {
        if (source.len >= vector_copy_min_len) {
            const Vector = @Vector(32, u8);
            const vectors_per_loop = 4;
            const loop_bytes = @sizeOf(Vector) * vectors_per_loop;
            var offset: usize = 0;
            while (source.len - offset >= loop_bytes) : (offset += loop_bytes) {
                const first: Vector = source[offset..][0..@sizeOf(Vector)].*;
                const second: Vector = source[offset + 32 ..][0..@sizeOf(Vector)].*;
                const third: Vector = source[offset + 64 ..][0..@sizeOf(Vector)].*;
                const fourth: Vector = source[offset + 96 ..][0..@sizeOf(Vector)].*;
                destination[offset..][0..@sizeOf(Vector)].* = first;
                destination[offset + 32 ..][0..@sizeOf(Vector)].* = second;
                destination[offset + 64 ..][0..@sizeOf(Vector)].* = third;
                destination[offset + 96 ..][0..@sizeOf(Vector)].* = fourth;
            }
            if (offset != source.len) {
                @memcpy(destination[offset..], source[offset..]);
            }
            return;
        }
    }
    @memcpy(destination, source);
}

// Complete groups are bounded by source.len before entering assembly. The
// remainder uses the same exact copy as the cached path; no readable or writable
// padding is required. Register and condition-code clobbers are explicit.
noinline fn copyNonTemporal(destination: []u8, source: []const u8) align(256) void {
    std.debug.assert(destination.len == source.len);
    std.debug.assert(source.len >= non_temporal_min_len);
    // A partial first cache line makes every subsequent paired store
    // unaligned. Cover that prefix once, then keep all main-loop stores aligned.
    const skip = (0 -% @intFromPtr(destination.ptr)) & 127;
    if (skip != 0) destination[0..128].* = source[0..128].*;
    const aligned_destination = destination[skip..];
    const adjusted_source = source[skip..];
    const count = adjusted_source.len / 128;
    asm volatile (
        \\ mov x9, %[source]
        \\ mov x10, %[destination]
        \\ mov x11, %[count]
        \\ 0:
        \\ ldnp q0, q1, [x9, #0]
        \\ ldnp q2, q3, [x9, #32]
        \\ ldnp q4, q5, [x9, #64]
        \\ ldnp q6, q7, [x9, #96]
        \\ stnp q0, q1, [x10, #0]
        \\ stnp q2, q3, [x10, #32]
        \\ stnp q4, q5, [x10, #64]
        \\ stnp q6, q7, [x10, #96]
        \\ add x9, x9, #128
        \\ add x10, x10, #128
        \\ subs x11, x11, #1
        \\ b.ne 0b
        :
        : [source] "r" (adjusted_source.ptr),
          [destination] "r" (aligned_destination.ptr),
          [count] "r" (count),
        : .{ .memory = true, .nzcv = true, .x9 = true, .x10 = true, .x11 = true, .v0 = true, .v1 = true, .v2 = true, .v3 = true, .v4 = true, .v5 = true, .v6 = true, .v7 = true });
    const offset = count * 128;
    if (offset < adjusted_source.len) @memcpy(aligned_destination[offset..], adjusted_source[offset..]);
}

test "Zstd raw frame vector copy preserves guards across alignments and tails" {
    const source = try std.testing.allocator.alloc(u8, block_size_max + 16);
    defer std.testing.allocator.free(source);
    const destination = try std.testing.allocator.alloc(u8, block_size_max + 32);
    defer std.testing.allocator.free(destination);
    for (source, 0..) |*byte, index| byte.* = @truncate(index *% 131 +% (index >> 8));

    for (0..16) |source_offset| {
        for (0..16) |destination_offset| {
            // Every possible tail of a vector loop, with independently
            // misaligned input and output and a guard on each output side.
            for (0..128) |tail| {
                try expectGuardedCopy(source, destination, source_offset, destination_offset, vector_copy_min_len + tail, false);
                try expectGuardedCopy(source, destination, source_offset, destination_offset, non_temporal_min_len + tail, true);
            }
            for ([_]usize{ 0, 1, 127, 128, 129, vector_copy_min_len - 1, non_temporal_min_len - 1, non_temporal_min_len, block_size_max - 1, block_size_max }) |len| {
                try expectGuardedCopy(source, destination, source_offset, destination_offset, len, false);
                try expectGuardedCopy(source, destination, source_offset, destination_offset, len, true);
            }
        }
    }
}

fn expectGuardedCopy(source: []const u8, destination: []u8, source_offset: usize, destination_offset: usize, len: usize, large_frame: bool) !void {
    const output_start = destination_offset + 1;
    const guarded = destination[0 .. output_start + len + 16];
    @memset(guarded, 0xa5);
    const input = source[source_offset..][0..len];
    copy(guarded[output_start..][0..len], input, large_frame);
    try std.testing.expectEqualSlices(u8, input, guarded[output_start..][0..len]);
    for (guarded[0..output_start]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    for (guarded[output_start + len ..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}
