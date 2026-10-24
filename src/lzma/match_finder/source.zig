const std = @import("std");

/// Borrowed immutable dictionary suffix followed by input. Matches may cross
/// the boundary and overlap their current position; immutable lookahead proves
/// the earlier-byte recurrence without constructing a combined byte buffer.
pub const Source = struct {
    dictionary: []const u8,
    input: []const u8,
    window_len: usize,

    pub fn init(dictionary: []const u8, input: []const u8, window_len: usize) Source {
        return .{ .dictionary = dictionary[dictionary.len - @min(dictionary.len, window_len) ..], .input = input, .window_len = window_len };
    }

    pub fn prefixLen(self: Source) usize {
        return self.dictionary.len;
    }

    pub fn totalLen(self: Source) usize {
        return self.checkedTotalLen() catch 0;
    }

    /// Invalid borrowed slice metadata is rejected before sample access.
    pub fn checkedTotalLen(self: Source) error{InvalidBlockPlan}!usize {
        return std.math.add(usize, self.dictionary.len, self.input.len) catch error.InvalidBlockPlan;
    }

    pub fn byteAt(self: Source, position: usize) u8 {
        return if (position < self.dictionary.len) self.dictionary[position] else self.input[position - self.dictionary.len];
    }

    pub fn spanAt(self: Source, position: usize) []const u8 {
        return if (position < self.dictionary.len) self.dictionary[position..] else self.input[position - self.dictionary.len ..];
    }

    pub fn matchLength(self: Source, candidate: usize, current: usize, limit: usize) usize {
        const total = self.checkedTotalLen() catch return 0;
        if (candidate >= current or current > total or current - candidate > self.window_len) return 0;
        const maximum = @min(limit, total - current);
        var length: usize = 0;
        while (length < maximum and self.byteAt(candidate + length) == self.byteAt(current + length)) : (length += 1) {}
        return length;
    }

    /// Exact word-at-a-time extension. The counter records compared bytes,
    /// including all bytes in a tested word even when its first byte differs.
    pub fn extend(self: Source, candidate: usize, current: usize, start: usize, maximum: usize, compared: *usize) usize {
        const total = self.checkedTotalLen() catch return 0;
        if (candidate >= current or current > total or current - candidate > self.window_len) return 0;
        const bounded_maximum = @min(maximum, total - current);
        if (start > bounded_maximum) return 0;
        var length = start;
        while (length < bounded_maximum) {
            const left = self.spanAt(candidate + length);
            const right = self.spanAt(current + length);
            const span_len = @min(bounded_maximum - length, @min(left.len, right.len));
            var offset: usize = 0;
            while (span_len - offset >= 32) : (offset += 32) {
                const a: @Vector(32, u8) = left[offset..][0..32].*;
                const b: @Vector(32, u8) = right[offset..][0..32].*;
                compared.* +|= 32;
                if (std.simd.firstTrue(a != b)) |different| return length + offset + different;
            }
            while (span_len - offset >= 8) : (offset += 8) {
                const a = std.mem.readInt(u64, left[offset..][0..8], .little);
                const b = std.mem.readInt(u64, right[offset..][0..8], .little);
                compared.* +|= 8;
                if (a != b) return length + offset + @ctz(a ^ b) / 8;
            }
            while (offset < span_len) : (offset += 1) {
                compared.* +|= 1;
                if (left[offset] != right[offset]) return length + offset;
            }
            length += span_len;
        }
        return length;
    }
};
