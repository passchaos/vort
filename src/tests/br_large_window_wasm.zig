const std = @import("std");
const vort = @import("vort");

var encoded_sizes: [2]usize = .{ 0, 0 };
var memory_peaks: [2]usize = .{ 0, 0 };
var encoded_bounds: [2]usize = .{ 0, 0 };
var encoded_crcs: [2]u32 = .{ 0, 0 };

fn verify(comptime quality: u4, input: []const u8) u32 {
    const allocator = std.heap.page_allocator;
    var hq: vort.BrotliHqProfile = .{};
    var memory: vort.BrotliEncodeMemoryProfile = .{};
    const options: vort.BrotliPlannedEncodeOptions = .{
        .quality = quality,
        .window_bits = 30,
        .large_window = true,
        .hq = .{
            .block_len = 8192,
            .distance_parameters = vort.BrotliHqDistanceParameters.init(3, 15),
            .profile = &hq,
        },
        .memory_profile = &memory,
    };
    const bound = vort.brEncodedPlannedStreamBoundWithOptions(input.len, options) catch return 1;
    const encoded = vort.brEncodePlannedStreamWithOptionsAlloc(allocator, input, options) catch return 2;
    defer allocator.free(encoded);
    if (encoded.len > bound or encoded.len < 2) return 3;
    const header = @as(u16, encoded[0]) | (@as(u16, encoded[1]) << 8);
    if ((header & 0x3fff) != ((@as(u16, 30) << 8) | 0x11)) return 4;
    if (vort.brDecodeStreamAllocExactSize(allocator, encoded, input.len)) |unexpected| {
        allocator.free(unexpected);
        return 5;
    } else |err| if (err != error.CorruptFrame) return 6;
    const decoded = vort.brDecodeStreamAllocExactSizeWithOptions(allocator, encoded, input.len, .{ .allow_large_window = true }) catch return 7;
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, input, decoded)) return 8;
    const summary = vort.brSummarizeStreamWithOptions(encoded, .{ .allow_large_window = true }) catch return 9;
    if (!summary.large_window or summary.window_bits != 30) return 10;
    const effective = hq.effective orelse return 11;
    if (effective.format != .large_window or effective.quality != quality or effective.block_len != 8192) return 12;
    if (effective.distance_parameters.npostfix != 3 or effective.distance_parameters.ndirect_high != 15) return 13;
    if (!memory.available or memory.peak_requested_bytes == 0 or memory.live_requested_bytes != 0) return 14;
    const index: usize = quality - 10;
    encoded_sizes[index] = encoded.len;
    encoded_bounds[index] = bound;
    encoded_crcs[index] = vort.crc32(encoded);
    memory_peaks[index] = memory.peak_requested_bytes;
    return 0;
}

export fn largeHq10(input: [*]const u8, length: usize) callconv(.c) u32 {
    return verify(10, input[0..length]);
}
export fn largeHq11(input: [*]const u8, length: usize) callconv(.c) u32 {
    return verify(11, input[0..length]);
}
export fn largeHqSmoke() callconv(.c) u32 {
    var input: [4097]u8 = undefined;
    const pattern = "large wasm HQ fixed shape 3/15\n";
    for (&input, 0..) |*byte, position| byte.* = pattern[position % pattern.len];
    const first = verify(10, &input);
    if (first != 0) return first;
    const second = verify(11, &input);
    if (second != 0) return 100 + second;
    if (encoded_sizes[1] > encoded_sizes[0]) return 201;
    return 0;
}
export fn largeHqEncodedSize(index: u32) callconv(.c) usize {
    return encoded_sizes[index & 1];
}
export fn largeHqMemoryPeak(index: u32) callconv(.c) usize {
    return memory_peaks[index & 1];
}
export fn largeHqBound(index: u32) callconv(.c) usize {
    return encoded_bounds[index & 1];
}
export fn largeHqCrc(index: u32) callconv(.c) u32 {
    return encoded_crcs[index & 1];
}
