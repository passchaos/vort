const std = @import("std");
const lz4 = @import("../lz4.zig");
const h = @import("lz4_fast_controls_helpers.zig");
const a = std.testing.allocator;

test "LZ4 fast controls invalid chain depth rejects before raw output allocation or frame input" {
    var tracked = h.TrackingAllocator.init(a);
    tracked.fail_alloc_after = 0;
    var profile: lz4.FastEncodeProfile = .{};
    try std.testing.expectError(error.InvalidBlockPlan, lz4.encodeBlockWithOptionsAlloc(tracked.allocator(), h.plain, .{ .acceleration = 8, .chain_depth = 17, .profile = &profile }));
    try std.testing.expectEqual(@as(usize, 0), tracked.alloc_attempts);
    try std.testing.expectEqual(@as(u64, 0), profile.blocks_attempted);
    try std.testing.expectError(error.InvalidBlockPlan, lz4.NativeIncrementalFrameEncoder.initExactSize(tracked.allocator(), .{ .chain_depth = 17 }, h.plain.len));
    try std.testing.expectEqual(@as(usize, 0), tracked.alloc_attempts);
}

const FailureGraph = struct {
    pub fn run(backing: std.mem.Allocator) !void {
        var tracked = h.TrackingAllocator.init(backing);
        tracked.force_copy_reallocation = true;
        var profile: lz4.FastEncodeProfile = .{};
        const bytes = lz4.encodeBlockWithPrefixAndOptionsAlloc(tracked.allocator(), h.plain[0..128], h.prefix, .{ .acceleration = 8, .profile = &profile }) catch |err| {
            try std.testing.expectEqual(@as(usize, 0), tracked.live);
            return err;
        };
        tracked.allocator().free(bytes);
        try std.testing.expectEqual(@as(usize, 0), tracked.live);
        try std.testing.expectEqual(tracked.allocated_bytes, tracked.freed_bytes);
    }
};

test "LZ4 fast controls tiny prefix allocation failures release all owned search and result memory" {
    try std.testing.checkAllAllocationFailures(a, FailureGraph.run, .{});
}

test "LZ4 fast controls frame bounds use overflow safe RFC field accounting across every block size" {
    const variants = [_]struct { id: lz4.BlockSizeId, bytes: usize }{
        .{ .id = .max64kb, .bytes = 64 * 1024 },
        .{ .id = .max256kb, .bytes = 256 * 1024 },
        .{ .id = .max1mb, .bytes = 1024 * 1024 },
        .{ .id = .max4mb, .bytes = 4 * 1024 * 1024 },
    };
    for (variants) |variant| {
        for ([_]lz4.NativeFrameOptions{
            .{},
            .{ .include_content_size = false, .content_checksum = false },
            .{ .block_checksum = true, .content_checksum = false },
            .{ .dictionary_id = 42, .block_checksum = true },
        }) |flags| {
            var options = flags;
            options.acceleration = 8;
            options.block_size_id = variant.id;
            for ([_]usize{ 0, 1, variant.bytes - 1, variant.bytes, variant.bytes + 1, std.math.maxInt(usize) - 1, std.math.maxInt(usize) }) |size| {
                const n: u128 = size;
                const block: u128 = variant.bytes;
                const count = n / block + @intFromBool(n % block != 0);
                // Frame format: magic4, FLG/BD2, descriptor checksum1,
                // optional content size8/dictionary ID4, each data block's
                // length4/checksum4, footer end marker4/content checksum4.
                const header: u128 = 7 + @as(u128, if (options.include_content_size) 8 else 0) + @as(u128, if (options.dictionary_id != null) 4 else 0);
                const per_block: u128 = 4 + @as(u128, if (options.block_checksum) 4 else 0);
                const footer: u128 = 4 + @as(u128, if (options.content_checksum) 4 else 0);
                const expected = header + n + count * per_block + footer;
                if (expected > std.math.maxInt(usize)) {
                    try std.testing.expectError(error.IntegerOverflow, lz4.encodedNativeFrameBoundWithOptions(size, options));
                } else {
                    try std.testing.expectEqual(@as(usize, @intCast(expected)), try lz4.encodedNativeFrameBoundWithOptions(size, options));
                }
            }
        }
    }
}
