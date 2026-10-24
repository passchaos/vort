//! Compile consumers for the real public HQ encode and general decode routes.
//! The pointer-taking exports keep arbitrary inputs reachable in wasm builds.
const std = @import("std");
const vort = @import("vort");

fn roundtrip(comptime quality: u4, input: []const u8) u32 {
    const allocator = std.heap.page_allocator;
    const encoded = vort.brEncodePlannedStreamWithOptionsAlloc(allocator, input, .{
        .quality = quality,
        .hq = .{ .block_len = 8192 },
        .window_bits = 16,
    }) catch return 1;
    defer allocator.free(encoded);
    const decoded = vort.brDecodeStreamAllocExactSize(allocator, encoded, input.len) catch return 2;
    defer allocator.free(decoded);
    return if (std.mem.eql(u8, input, decoded)) 0 else 3;
}

export fn brWasmHq10(input: [*]const u8, length: usize) callconv(.c) u32 {
    return roundtrip(10, input[0..length]);
}

export fn brWasmHq11(input: [*]const u8, length: usize) callconv(.c) u32 {
    return roundtrip(11, input[0..length]);
}

export fn brWasmHqSmoke() callconv(.c) u32 {
    var input: [4097]u8 = undefined;
    const pattern = "Brotli wasm HQ roundtrip\n";
    for (&input, 0..) |*byte, position| byte.* = pattern[position % pattern.len];
    const q10 = roundtrip(10, &input);
    if (q10 != 0) return q10;
    return roundtrip(11, &input);
}

test "Brotli wasm public consumer instantiates both HQ qualities and decode" {
    try std.testing.expectEqual(@as(u32, 0), brWasmHqSmoke());
}
