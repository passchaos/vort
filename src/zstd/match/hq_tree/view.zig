const std = @import("std");
const Source = @import("../controlled_source.zig").Source;

pub const max_prefix_len: usize = 64 * 1024 * 1024;
pub const max_block_len: usize = 128 * 1024;

pub const Metadata = struct { prefix: usize, total: usize };

pub fn validate(source: Source) !Metadata {
    // Checked slice arithmetic precedes all pointer access and heap requests.
    const prefix = try source.checkedPrefixLen();
    const total = try source.checkedTotalLen();
    if (source.window_len == 0 or source.window_len > max_prefix_len or prefix > max_prefix_len or source.block.len > max_block_len or total >= std.math.maxInt(u32))
        return error.InvalidBlockPlan;
    return .{ .prefix = prefix, .total = total };
}

fn spanAt(source: Source, position: usize) []const u8 {
    if (position < source.dictionary.len) return source.dictionary[position..];
    const after_dictionary = position - source.dictionary.len;
    if (after_dictionary < source.history.len) return source.history[after_dictionary..];
    return source.block[after_dictionary - source.history.len ..];
}

/// Exact source comparison with a proven prefix. SIMD lane selection uses the
/// standard library's portable firstTrue; word comparisons explicitly use LE.
/// Count every compared byte in a tested vector/word, including a mismatch.
pub fn extend(source: Source, candidate: usize, current: usize, start: usize, limit: usize, compared: *usize) usize {
    var length = start;
    while (length < limit) {
        const left = spanAt(source, candidate + length);
        const right = spanAt(source, current + length);
        const n = @min(limit - length, @min(left.len, right.len));
        var offset: usize = 0;
        while (n - offset >= 32) : (offset += 32) {
            const a: @Vector(32, u8) = left[offset..][0..32].*;
            const b: @Vector(32, u8) = right[offset..][0..32].*;
            compared.* += 32;
            if (std.simd.firstTrue(a != b)) |different| return length + offset + different;
        }
        while (n - offset >= 8) : (offset += 8) {
            const a = std.mem.readInt(u64, left[offset..][0..8], .little);
            const b = std.mem.readInt(u64, right[offset..][0..8], .little);
            compared.* += 8;
            if (a != b) return length + offset + @ctz(a ^ b) / 8;
        }
        while (offset < n) : (offset += 1) {
            compared.* += 1;
            if (left[offset] != right[offset]) return length + offset;
        }
        length += n;
    }
    return length;
}
