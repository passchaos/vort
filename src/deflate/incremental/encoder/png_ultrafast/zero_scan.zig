const std = @import("std");

/// Inspect seven additional complete words after an already-known zero word.
/// Loads stay inside the caller's proven 64-byte span and use scalar registers;
/// no carry, heap or separate scratch array is added to the encoder.
pub inline fn followingWordsAreZero(bytes: *const [64]u8) bool {
    var combined: u64 = 0;
    inline for (1..8) |word| combined |= std.mem.readInt(u64, bytes[word * 8 ..][0..8], .little);
    return combined == 0;
}

/// Scan a complete zero-word prefix with a known-zero first word. The caller
/// caps the slice at its Adler batch boundary; no trailing partial word is
/// accepted. Zero words do not produce bits, so their recurrence can be folded
/// once after this scan instead of returning to the token loop every 64 bytes.
pub inline fn leadingZeroWords(bytes: []const u8) usize {
    std.debug.assert(bytes.len >= 8);
    var count: usize = 8;
    while (bytes.len - count >= 64) : (count += 64) {
        const words: @Vector(8, u64) = @bitCast(bytes[count..][0..64].*);
        if (@reduce(.Or, words) != 0) break;
    }
    while (bytes.len - count >= 8) : (count += 8) {
        if (std.mem.readInt(u64, bytes[count..][0..8], .little) != 0) break;
    }
    return count;
}

test "PNG zero word prefix matches scalar for every dirty word and byte at all alignments" {
    var storage: [4096 + 63]u8 = undefined;
    for (0..64) |alignment| {
        const bytes = storage[alignment..][0..4096];
        @memset(bytes, 0);
        for ([_]usize{ 8, 9, 15, 16, 63, 64, 65, 71, 72, 127, 128, 129, 511, 512, 513, 4095, 4096 }) |length| {
            try std.testing.expectEqual(length / 8 * 8, leadingZeroWords(bytes[0..length]));
        }
        for (8..4096) |at| {
            bytes[at] = @as(u8, 1) << @intCast(at % 8);
            try std.testing.expectEqual(at / 8 * 8, leadingZeroWords(bytes));
            bytes[at] = 0;
        }
    }
}
