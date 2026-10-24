const std = @import("std");
const bound = @import("stored_bit_bound.zig");
const bit_count = @import("../../io/bit_count.zig");
const BitCount = bit_count.BitCount;

// Deliberately walk every block and spell out the original scalar geometry.
// This oracle never uses the production repeated-block calculation.
fn sequential(start: BitCount, input_len: usize, block_len: usize) BitCount {
    var bits = start;
    var remaining = input_len;
    while (remaining != 0) {
        const len = @min(remaining, block_len);
        const length_nibbles: BitCount = if (len - 1 <= 0xffff) 4 else if (len - 1 <= 0xfffff) 5 else 6;
        bits += 4 + length_nibbles * 4;
        bits = ((bits + 7) / 8) * 8;
        bits += @as(BitCount, len) * 8;
        remaining -= len;
    }
    return bits;
}

test "Brotli wide bit addressing repeated stored blocks match scalar geometry" {
    for ([_]usize{ 1, 2, 32768, 65536, 1048576, bound.max_block_len }) |block_len| {
        for ([_]usize{ 0, 1, block_len - 1, block_len, block_len + 1, block_len * 3 - 1, block_len * 3, block_len * 3 + 1 }) |len| {
            for ([_]BitCount{ 0, 1, 7, 14, 31, (@as(BitCount, 1) << 32) - 3 }) |start| {
                try std.testing.expectEqual(sequential(start, len, block_len), try bound.blocks(start, len, block_len));
            }
        }
    }
}

test "Brotli wide bit addressing stored bounds cross 512 MiB and reject unrepresentable geometry" {
    const boundary: usize = 1 << 29;
    for ([_]usize{ boundary - 1, boundary, boundary + 1, boundary + bound.max_block_len }) |len| {
        const bits = try bound.blocks(1, len, bound.max_block_len);
        try std.testing.expectEqual(sequential(1, len, bound.max_block_len), bits);
        try std.testing.expect((try bit_count.ceilBytes(bits + 2)) > len);
    }
    try std.testing.expectError(error.InvalidBlockPlan, bound.blocks(0, 1, 0));
    try std.testing.expectError(error.InvalidBlockPlan, bound.uncompressed(std.math.maxInt(BitCount), 0));
    try std.testing.expectError(error.InvalidBlockPlan, bound.metadata(std.math.maxInt(BitCount), 0x1_0001));
    try std.testing.expectError(error.IntegerOverflow, bound.uncompressed(std.math.maxInt(BitCount) - 7, 1));
    try std.testing.expectError(error.IntegerOverflow, bound.metadata(std.math.maxInt(BitCount) - 7, 1));
    if (@bitSizeOf(usize) >= 64) {
        try std.testing.expectError(error.IntegerOverflow, bound.blocks(1, std.math.maxInt(usize), bound.max_block_len));
        try std.testing.expectError(error.IntegerOverflow, bound.blocks(1, bit_count.max_addressable_bytes, bound.max_block_len));
    } else {
        const bits = try bound.blocks(1, std.math.maxInt(usize), bound.max_block_len);
        try std.testing.expectError(error.IntegerOverflow, bit_count.ceilBytes(bits + 2));
    }
}
