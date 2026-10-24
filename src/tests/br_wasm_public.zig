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

export fn brWasmTotalMemorySmoke() callconv(.c) u32 {
    const allocator = std.heap.page_allocator;
    const input = "Brotli total memory wasm public roundtrip\n" ** 3;
    inline for (.{ @as(u4, 0), @as(u4, 11) }) |quality| {
        var memory: vort.BrotliEncodeMemoryProfile = .{};
        var options: vort.BrotliPlannedEncodeOptions = .{
            .quality = quality,
            .window_bits = 16,
            .memory_profile = &memory,
        };
        const measured = vort.brEncodePlannedStreamWithOptionsAlloc(allocator, input, options) catch return 4;
        defer allocator.free(measured);
        if (!memory.available or memory.peak_requested_bytes == 0 or memory.live_requested_bytes != 0) return 5;
        const peak = memory.peak_requested_bytes;
        options.max_total_working_memory = peak;
        memory.reset();
        const exact = vort.brEncodePlannedStreamWithOptionsAlloc(allocator, input, options) catch return 6;
        defer allocator.free(exact);
        if (!std.mem.eql(u8, measured, exact) or memory.live_requested_bytes != 0 or memory.peak_requested_bytes != peak) return 7;
        const decoded = vort.brDecodeStreamAllocExactSize(allocator, exact, input.len) catch return 8;
        defer allocator.free(decoded);
        if (!std.mem.eql(u8, input, decoded)) return 9;
        options.max_total_working_memory = peak - 1;
        if (vort.brEncodePlannedStreamWithOptionsAlloc(allocator, input, options)) |unexpected| {
            allocator.free(unexpected);
            return 10;
        } else |err| if (err != error.WorkingMemoryLimitExceeded) return 11;
    }
    return 0;
}

export fn brWasmWholeBlockSmoke() callconv(.c) u32 {
    const allocator = std.heap.page_allocator;
    var bytes: [4098]u8 = undefined;
    var random: u64 = 0x4098;
    for (&bytes) |*byte| {
        random = random *% 6364136223846793005 +% 1442695040888963407;
        byte.* = @truncate(random >> 32);
    }
    @memcpy(bytes[4094..], bytes[0..4]);
    inline for (.{ @as(u4, 10), @as(u4, 11) }) |quality| {
        const large = quality == 11;
        const input: []const u8 = if (large) bytes[0..64] else &bytes;
        var profile: vort.BrotliHqProfile = .{};
        var memory: vort.BrotliEncodeMemoryProfile = .{};
        var options: vort.BrotliPlannedEncodeOptions = .{
            .quality = quality,
            .window_bits = if (large) 25 else 16,
            .large_window = large,
            .memory_profile = &memory,
            .hq = .{ .block_len = input.len, .beam_width = 1, .search_depth = 1, .iterations = 1, .profile = &profile },
        };
        const baseline = vort.brEncodePlannedStreamWithOptionsAlloc(allocator, input, options) catch return 12;
        defer allocator.free(baseline);
        profile.reset();
        memory.reset();
        options.hq.?.parse_mode = .whole_block;
        const whole = vort.brEncodePlannedStreamWithOptionsAlloc(allocator, input, options) catch return 13;
        defer allocator.free(whole);
        if (whole.len > baseline.len or profile.whole_block_passes == 0 or profile.bounded_passes == 0 or profile.max_parse_positions != input.len) return 14;
        if (profile.effective.?.parse_mode != .whole_block or memory.live_requested_bytes != 0) return 15;
        const decoded = vort.brDecodeStreamAllocExactSizeWithOptions(allocator, whole, input.len, .{ .allow_large_window = large }) catch return 16;
        defer allocator.free(decoded);
        if (!std.mem.eql(u8, input, decoded)) return 17;
    }
    return 0;
}

test "Brotli wasm public consumer instantiates both HQ qualities and decode" {
    try std.testing.expectEqual(@as(u32, 0), brWasmHqSmoke());
}
