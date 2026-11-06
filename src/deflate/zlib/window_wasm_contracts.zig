//! Public RFC 1950 window contracts for wasm32-wasi. The RFC token oracle is
//! allocation-free; codec and caller buffers use the explicit wasm allocator.
const std = @import("std");
const D = @import("codec");
const oracle = D.ZlibWindowTestOracle;
const allocator = std.heap.wasm_allocator;
const prefix = "wasm caller prefix";
var report: [16]u64 = @splat(0);

// Report: 0 usize bits, 1 audited frames, 2 output-form calls, 3 match tokens,
// 4/5/6 maximum distances at windows 9/12/15, 7 cross-block match tokens,
// 8 dictionary match tokens, 9 invalid-window refusals, 10 scatter cases,
// 11 rejected setOptions calls, 12 encoded bytes, 13 failure error code,
// 14 covered mode mask, 15 distance-boundary cases.
pub export fn zlibWindowFrameReport(index: u32) u64 {
    return if (index < report.len) report[index] else 0;
}

fn require(ok: bool) error{ZlibWindowWasmMismatch}!void {
    if (!ok) return error.ZlibWindowWasmMismatch;
}

fn reject(expected: anyerror, result: anytype) !void {
    if (result) |_| return error.ExpectedWindowFailure else |err| try require(err == expected);
}

fn windowLen(bits: u8) usize {
    return @as(usize, 1) << @as(std.math.Log2Int(usize), @intCast(bits));
}

fn options() D.CompressionOptions {
    var result = D.optionsForLevel(.fast);
    result.lz77_options.window_len = 65535;
    result.lz77_options.max_chain = 64;
    result.lz77_options.max_candidates = 4;
    result.lz77_options.min_match = 3;
    result.lz77_options.max_match = 258;
    result.lz77_options.min_savings_bits = 0;
    return result;
}

fn record(stats: oracle.Stats, bits: u8, size: usize) void {
    report[1] += 1;
    report[3] += stats.matches;
    const slot: usize = switch (bits) {
        9 => 4,
        12 => 5,
        15 => 6,
        else => unreachable,
    };
    report[slot] = @max(report[slot], stats.max_distance);
    report[7] += stats.cross_block_matches;
    report[8] += stats.dictionary_matches;
    report[12] += size;
}

fn guards(bytes: []const u8) !void {
    for (bytes) |byte| try require(byte == 0xa5);
}

fn forms(input: []const u8, settings: D.ZlibEncodeOptions, target: usize) !oracle.Stats {
    const encoded = try D.encodeZlibFrameAlloc(allocator, input, settings);
    defer allocator.free(encoded);
    const stats = try oracle.frame(encoded, input, settings.dictionary, settings.window_bits, target);
    record(stats, settings.window_bits, encoded.len);
    report[14] |= @as(u64, 1) << @as(u6, @intCast(@intFromEnum(settings.mode)));
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try out.appendSlice(allocator, prefix);
    try require(try D.encodeZlibFrameAppend(allocator, &out, input, settings) == encoded.len);
    try require(std.mem.eql(u8, out.items[0..prefix.len], prefix));
    try require(std.mem.eql(u8, out.items[prefix.len..], encoded));
    const buffer = try allocator.alloc(u8, encoded.len + 32);
    defer allocator.free(buffer);
    @memset(buffer, 0xa5);
    try require(try D.encodeZlibFrameInto(allocator, input, buffer[16 .. buffer.len - 16], settings) == encoded.len);
    try require(std.mem.eql(u8, buffer[16 .. buffer.len - 16], encoded));
    try guards(buffer[0..16]);
    try guards(buffer[buffer.len - 16 ..]);
    var encoder = try D.ZlibFrameEncoder.init(allocator, settings);
    defer encoder.deinit();
    const owned = try encoder.encodeAlloc(input);
    defer allocator.free(owned);
    try require(std.mem.eql(u8, owned, encoded));
    out.items.len = prefix.len;
    try require(try encoder.encodeAppend(&out, input) == encoded.len);
    try require(std.mem.eql(u8, out.items[0..prefix.len], prefix));
    try require(std.mem.eql(u8, out.items[prefix.len..], encoded));
    @memset(buffer, 0xa5);
    try require(try encoder.encodeInto(input, buffer[16 .. buffer.len - 16]) == encoded.len);
    try require(std.mem.eql(u8, buffer[16 .. buffer.len - 16], encoded));
    try guards(buffer[0..16]);
    try guards(buffer[buffer.len - 16 ..]);
    try require(std.mem.eql(u8, try encoder.encodeScratch(input), encoded));
    report[2] += 7;
    return stats;
}

fn matrix(input: []const u8) !void {
    for ([_]u8{ 9, 12, 15 }) |bits| {
        for (std.meta.tags(D.ZlibEncodeMode)) |mode| {
            for ([_]?[]const u8{ null, "", "full dictionary bytes for wasm frame" }) |dictionary| {
                const stats = try forms(input, .{
                    .window_bits = bits,
                    .mode = mode,
                    .dictionary = dictionary,
                    .compression = options(),
                    .split_options = .{ .min_block_len = 256, .max_block_len = 1024, .sample_len = 128, .search_step = 256 },
                }, 513);
                if (mode == .stored or mode == .dynamic_literal) try require(stats.matches == 0);
                if (mode == .png_ultrafast) try require(stats.max_distance <= 1);
            }
        }
        for ([_]D.ZlibEncodeMode{ .stored, .fixed, .dynamic, .dynamic_literal, .best }) |mode| {
            for ([_]?[]const u8{ null, "" }) |dictionary| {
                const stats = try forms(input, .{
                    .window_bits = bits,
                    .mode = mode,
                    .dictionary = dictionary,
                    .block_len = 256,
                    .compression = options(),
                }, 513);
                try require(stats.blockCount() == (input.len + 255) / 256);
            }
        }
    }
}

fn distances() !void {
    for ([_]u8{ 9, 12, 15 }) |bits| {
        const cap = windowLen(bits);
        for ([_]usize{ cap - 1, cap, cap + 1 }) |distance| {
            const input = try allocator.alloc(u8, distance + 384);
            defer allocator.free(input);
            var random = std.Random.DefaultPrng.init(0x18c4f707 + distance);
            random.random().bytes(input[0..distance]);
            for (input[0..distance]) |*byte| byte.* &= 0x7f;
            @memcpy(input[distance..], input[0..384]);
            const stats = try forms(input, .{ .mode = .fixed, .window_bits = bits, .compression = options() }, distance);
            try require((stats.target_matches != 0) == (distance <= cap));
            report[15] += 1;
        }
        const dictionary = try allocator.alloc(u8, cap + 777);
        defer allocator.free(dictionary);
        var random = std.Random.DefaultPrng.init(0x6873ac90 + cap);
        random.random().bytes(dictionary);
        const stats = try forms(dictionary[dictionary.len - cap ..][0..384], .{
            .window_bits = bits,
            .mode = .dynamic,
            .dictionary = dictionary,
            .compression = options(),
        }, cap);
        try require(stats.dictionary_matches != 0 and stats.target_matches != 0);
    }
}

fn scatter(input: []const u8) !void {
    const chunks = [_][]const u8{ "", input[0..1], input[1..513], "", input[513..], "" };
    for ([_]u8{ 9, 12, 15 }) |bits| {
        for ([_]?[]const u8{ null, "", "scatter full dictionary" }) |dictionary| {
            var encoder = try D.ZlibFrameEncoder.init(allocator, .{
                .window_bits = bits,
                .mode = .stored,
                .dictionary = dictionary,
                .block_len = 257,
            });
            defer encoder.deinit();
            const encoded = try encoder.encodeStoredChunksAlloc(&chunks);
            defer allocator.free(encoded);
            const stats = try oracle.frame(encoded, input, dictionary, bits, 0);
            record(stats, bits, encoded.len);
            try require(stats.blockCount() == (input.len + 256) / 257);
            var out: std.ArrayList(u8) = .empty;
            defer out.deinit(allocator);
            try out.appendSlice(allocator, prefix);
            try require(try encoder.encodeStoredChunksAppend(&out, &chunks) == encoded.len);
            try require(std.mem.eql(u8, out.items[0..prefix.len], prefix));
            try require(std.mem.eql(u8, out.items[prefix.len..], encoded));
            const output = try allocator.alloc(u8, encoded.len + 32);
            defer allocator.free(output);
            @memset(output, 0xa5);
            try require(try encoder.encodeStoredChunksInto(&chunks, output[16 .. output.len - 16]) == encoded.len);
            try require(std.mem.eql(u8, output[16 .. output.len - 16], encoded));
            try guards(output[0..16]);
            try guards(output[output.len - 16 ..]);
            try require(std.mem.eql(u8, try encoder.encodeStoredChunksScratch(&chunks), encoded));
            report[2] += 4;
            report[10] += 1;
        }
    }
}

fn invalid(input: []const u8) !void {
    var empty: [0]u8 = .{};
    var denied = std.heap.FixedBufferAllocator.init(&empty);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try out.appendSlice(allocator, prefix);
    const pointer = out.items.ptr;
    const capacity = out.capacity;
    var output: [64]u8 = @splat(0xa5);
    for ([_]u8{ 0, 8, 16, 255 }) |bits| {
        for (std.meta.tags(D.ZlibEncodeMode)) |mode| {
            for ([_]?[]const u8{ null, "" }) |dictionary| {
                const settings: D.ZlibEncodeOptions = .{ .window_bits = bits, .mode = mode, .dictionary = dictionary };
                try reject(error.InvalidZlibWindow, D.encodeZlibFrameAlloc(denied.allocator(), input, settings));
                try reject(error.InvalidZlibWindow, D.encodeZlibFrameAppend(denied.allocator(), &out, input, settings));
                try reject(error.InvalidZlibWindow, D.encodeZlibFrameInto(denied.allocator(), input, output[16..48], settings));
                try reject(error.InvalidZlibWindow, D.ZlibFrameEncoder.init(denied.allocator(), settings));
                try require(std.mem.eql(u8, out.items, prefix) and out.items.ptr == pointer and out.capacity == capacity);
                try guards(&output);
                try require(denied.end_index == 0);
                report[9] += 4;
            }
        }
    }
    const settings: D.ZlibEncodeOptions = .{ .window_bits = 12, .mode = .fixed, .dictionary = "", .compression = options() };
    var encoder = try D.ZlibFrameEncoder.init(allocator, settings);
    defer encoder.deinit();
    const retained = try encoder.encodeScratch(input);
    const saved = try allocator.dupe(u8, retained);
    defer allocator.free(saved);
    for ([_]u8{ 0, 8, 16, 255 }) |bits| {
        var replacement = settings;
        replacement.window_bits = bits;
        replacement.mode = .dynamic;
        replacement.dictionary = "replacement dictionary";
        try reject(error.InvalidZlibWindow, encoder.setOptions(replacement));
        try require(std.mem.eql(u8, retained, saved) and std.meta.eql(encoder.options, settings));
        report[11] += 1;
    }
    const retried = try encoder.encodeAlloc(input);
    defer allocator.free(retried);
    try require(std.mem.eql(u8, retried, saved));
    _ = try oracle.frame(retried, input, "", 12, 513);
}

fn run() !void {
    report = @splat(0);
    report[0] = @bitSizeOf(usize);
    try require(@bitSizeOf(usize) == 32);
    var input: [2048]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0x73f7c809c41a);
    random.random().bytes(input[0..513]);
    for (513..1536) |i| input[i] = input[i % 513];
    for (1536..input.len) |i| input[i] = if (i % 127 < 96) 0 else @intCast(i % 7);
    try matrix(&input);
    try distances();
    try scatter(&input);
    try invalid(&input);
    try require(report[14] == 127 and report[7] != 0 and report[8] != 0 and report[15] == 9);
}

pub export fn zlibWindowFrameContracts() u32 {
    run() catch |err| {
        report[13] = @intFromError(err);
        return 1;
    };
    return 0;
}
