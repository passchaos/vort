//! Count decoded output without materializing its logical history or output.
const std = @import("std");
const core = @import("../../core.zig");
const Count = core.StreamCount;
const count = core.stream_count;
const format = @import("format.zig");

pub fn addWithinLimit(current: Count, additional: Count, limit: Count) error{ IntegerOverflow, OutputLimitExceeded }!Count {
    const next = try count.add(current, additional);
    if (next > limit) return error.OutputLimitExceeded;
    return next;
}

/// Only the visible suffix can satisfy a match. Bound logical frame history
/// by the window before reducing it to the local offset address space. This
/// avoids overflowing produced + dictionary length near the counter maximum.
pub fn visibleHistory(produced: Count, dictionary_len: usize, window: u64) usize {
    const window_count: Count = @intCast(window);
    if (produced >= window_count) return count.bounded(window_count, std.math.maxInt(usize));
    // External dictionaries can satisfy offsets larger than a small frame's
    // window before its output fills that window. Afterward only frame history
    // remains visible. Clamp to the local offset range without adding a wide
    // frame position to a physical dictionary length.
    const frame_history = count.bounded(produced, std.math.maxInt(usize));
    return frame_history + @min(dictionary_len, std.math.maxInt(usize) - frame_history);
}

pub fn decodedSize(comptime Codec: type, frame: []const u8, options: Codec.Options) Codec.Error!Count {
    var offset: usize = 0;
    var total: Count = 0;
    while (offset < frame.len) {
        const prefix = try format.consumePrefix(frame, &offset, options.format);
        if (prefix == .data) {
            const header = try Codec.parseHeader(frame, &offset, true);
            const dictionary = try Codec.resolveDictionary(header, options);
            const history = try Codec.validateDictionary(header, dictionary);
            const frame_start = total;
            var state = try Codec.initialState(dictionary);
            while (true) {
                if (frame.len - offset < 3) return error.TruncatedFrame;
                const block_header = std.mem.readInt(u24, frame[offset..][0..3], .little);
                offset += 3;
                const last = (block_header & 1) != 0;
                const block_type = (block_header >> 1) & 3;
                const block_len: usize = @intCast(block_header >> 3);
                try Codec.validateBlockSize(header, block_type, block_len);
                const decoded_len = switch (block_type) {
                    0 => decoded: {
                        if (frame.len - offset < block_len) return error.TruncatedFrame;
                        offset += block_len;
                        break :decoded block_len;
                    },
                    1 => decoded: {
                        if (frame.len - offset < 1) return error.TruncatedFrame;
                        offset += 1;
                        break :decoded block_len;
                    },
                    2 => decoded: {
                        if (frame.len - offset < block_len) return error.TruncatedFrame;
                        const initial_history = visibleHistory(total - frame_start, history.len, header.window_size);
                        const decoded = try Codec.compressedBlockSize(frame[offset..][0..block_len], header.block_size_max, initial_history, &state, header.window_size, total - frame_start);
                        offset += block_len;
                        break :decoded decoded;
                    },
                    else => return error.CorruptFrame,
                };
                total = try addWithinLimit(total, count.fromLocal(decoded_len), options.max_output_len);
                if (last) break;
            }
            if (header.content_size) |expected| {
                if (total - frame_start != expected) return error.SizeMismatch;
            }
            if (header.has_checksum) {
                if (frame.len - offset < 4) return error.TruncatedFrame;
                offset += 4;
            }
        } else {
            if (frame.len - offset < 4) return error.TruncatedFrame;
            const skip_len: usize = @intCast(std.mem.readInt(u32, frame[offset..][0..4], .little));
            offset += 4;
            if (frame.len - offset < skip_len) return error.TruncatedFrame;
            offset += skip_len;
        }
    }
    return total;
}

test "Zstd decoded counts overflow and window bounds precede local narrowing" {
    const boundary: Count = @as(Count, 1) << 32;
    try std.testing.expectEqual(boundary + 3, try addWithinLimit(boundary - 1, 4, boundary + 3));
    try std.testing.expectError(error.OutputLimitExceeded, addWithinLimit(boundary - 1, 4, boundary + 2));
    try std.testing.expectError(error.IntegerOverflow, addWithinLimit(std.math.maxInt(Count), 1, std.math.maxInt(Count)));
    try std.testing.expectEqual(@as(usize, 1024), visibleHistory(boundary + 3, 17, 1024));
    try std.testing.expectEqual(@as(usize, 20), visibleHistory(3, 17, 1024));
    try std.testing.expectEqual(@as(usize, 4), visibleHistory(0, 4, 3));
    try std.testing.expectEqual(@as(usize, 0), visibleHistory(std.math.maxInt(Count), 17, 0));
    try std.testing.expectEqual(std.math.maxInt(usize), visibleHistory(std.math.maxInt(Count), std.math.maxInt(usize), std.math.maxInt(u64)));
}
