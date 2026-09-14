const std = @import("std");

/// Smooth a byte-symbol histogram so the resulting Huffman code lengths form
/// longer RLE-friendly runs. The caller must compare the exact tree+payload
/// bit cost with the unsmoothed tree before selecting this approximation.
pub fn optimize(counts: *[256]u32) void {
    var length = counts.len;
    var nonzero_count: usize = 0;
    for (counts) |count| nonzero_count += @intFromBool(count != 0);
    if (nonzero_count < 16) return;
    while (length != 0 and counts[length - 1] == 0) length -= 1;
    if (length == 0) return;

    var smallest_nonzero: u32 = std.math.maxInt(u32);
    for (counts[0..length]) |count| {
        if (count != 0) smallest_nonzero = @min(smallest_nonzero, count);
    }
    if (smallest_nonzero < 4 and length - nonzero_count < 6) {
        for (1..length - 1) |i| {
            if (counts[i - 1] != 0 and counts[i] == 0 and counts[i + 1] != 0) counts[i] = 1;
        }
    }
    if (nonzero_count < 28) return;

    var good_for_rle: [256]bool = @splat(false);
    var symbol = counts[0];
    var step: usize = 0;
    for (0..length + 1) |i| {
        if (i == length or counts[i] != symbol) {
            if ((symbol == 0 and step >= 5) or (symbol != 0 and step >= 7)) {
                for (i - step..i) |j| good_for_rle[j] = true;
            }
            step = 1;
            if (i != length) symbol = counts[i];
        } else step += 1;
    }

    var stride: usize = 0;
    var limit = (256 * (@as(usize, counts[0]) + counts[1] + counts[2])) / 3 + 420;
    var sum: usize = 0;
    for (0..length + 1) |i| {
        const outside = if (i == length) true else blk: {
            const value = 256 * @as(usize, counts[i]);
            break :blk value + 1240 < limit or value >= limit + 1240;
        };
        if (i == length or good_for_rle[i] or (i != 0 and good_for_rle[i - 1]) or outside) {
            if (stride >= 4 or (stride >= 3 and sum == 0)) {
                var count = (sum + stride / 2) / stride;
                if (count == 0) count = 1;
                if (sum == 0) count = 0;
                for (i - stride..i) |j| counts[j] = @intCast(count);
            }
            stride = 0;
            sum = 0;
            if (i + 2 < length)
                limit = (256 * (@as(usize, counts[i]) + counts[i + 1] + counts[i + 2])) / 3 + 420
            else if (i < length)
                limit = 256 * @as(usize, counts[i])
            else
                limit = 0;
        }
        stride += 1;
        if (i != length) {
            sum += counts[i];
            if (stride >= 4) limit = (256 * sum + stride / 2) / stride;
            if (stride == 4) limit += 120;
        }
    }
}

test "smoothing is deterministic and preserves active symbols" {
    var counts: [256]u32 = @splat(0);
    for (32..128) |i| counts[i] = @intCast(10 + i % 3);
    var first = counts;
    var second = counts;
    optimize(&first);
    optimize(&second);
    try std.testing.expectEqual(first, second);
    for (counts, first) |before, after| {
        if (before != 0) try std.testing.expect(after != 0);
    }
    try std.testing.expect(!std.mem.eql(u32, &counts, &first));
}

test "small alphabets remain exact" {
    var counts: [256]u32 = @splat(0);
    counts[3] = 7;
    counts[19] = 2;
    counts[127] = 11;
    const original = counts;
    optimize(&counts);
    try std.testing.expectEqual(original, counts);
}
