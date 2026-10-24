const std = @import("std");
const Source = @import("../hq_types.zig").Source;
const types = @import("types.zig");
pub const Metadata = struct {
    begin: u64,
    input_begin: u64,
    end: u64,
    history_len: usize,
    input_len: usize,
    total_len: usize,
    window_len: usize,
};

pub fn validate(source: Source) !Metadata {
    const total = try source.checkedTotalLen();
    const end = try source.absolutePosition(source.input.len);
    if (source.history.len > source.frame_offset or source.history.len > source.window_len or source.window_len == 0 or source.window_len > types.max_window_len or source.input.len > types.max_input_len or total > types.max_source_len) return error.InvalidBlockPlan;
    return .{ .begin = source.frame_offset - source.history.len, .input_begin = source.frame_offset, .end = end, .history_len = source.history.len, .input_len = source.input.len, .total_len = total, .window_len = source.window_len };
}
pub fn spanAt(source: Source, metadata: Metadata, absolute: u64) []const u8 {
    const position: usize = @intCast(absolute - metadata.begin);
    return if (position < source.history.len) source.history[position..] else source.input[position - source.history.len ..];
}
pub fn byteAt(source: Source, metadata: Metadata, absolute: u64) u8 {
    return spanAt(source, metadata, absolute)[0];
}
pub fn hash(source: Source, metadata: Metadata, absolute: u64, width: usize) usize {
    var word: u32 = 0;
    for (0..width) |index| word |= @as(u32, byteAt(source, metadata, absolute + index)) << @intCast(index * 8);
    return (word *% 2654435761) >> 16;
}
pub fn hash2(source: Source, metadata: Metadata, absolute: u64) usize {
    return @as(usize, byteAt(source, metadata, absolute)) | (@as(usize, byteAt(source, metadata, absolute + 1)) << 8);
}
pub fn extend(source: Source, metadata: Metadata, candidate: u64, current: u64, start: usize, limit: usize, compared: *usize) usize {
    var length = start;
    while (length < limit) {
        const left = spanAt(source, metadata, candidate + length);
        const right = spanAt(source, metadata, current + length);
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
