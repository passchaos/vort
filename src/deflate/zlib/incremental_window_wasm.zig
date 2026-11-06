//! Actual incremental RFC 1950 contracts for wasm32-wasi. Caller I/O is at
//! most 31/3 bytes per step; retained codec state uses the explicit allocator.
const std = @import("std");
const D = @import("codec");
const oracle = D.ZlibWindowTestOracle;
const allocator = std.heap.wasm_allocator;
const Count = @FieldType(D.ZlibIncrementalBestEncoder, "total_input");
var report: [16]u64 = @splat(0);

// 0 usize bits, 1 StreamCount bits, 2 window bitmask, 3 audited frames,
// 4/5/6 maximum distances for windows 9/12/15, 7 audited input bytes,
// 8 audited wire bytes, 9 successful step calls, 10 dictionary match tokens,
// 11 cross-block match tokens, 12 InvalidZlibWindow refusals,
// 13 behavior mask, 14 preserved rejection states, 15 failure error code.
// Behavior bits 0..13: fixed, best, dictionary, runtime params, block flush,
// partial flush, sync flush, full flush, reset, nextStream, raw option changes,
// invalid range, published-window changes, zero-length output.
pub export fn zlibWindowIncrementalReport(index: u32) u64 {
    return if (index < report.len) report[index] else 0;
}

fn require(ok: bool) error{ZlibIncrementalWindowWasmMismatch}!void {
    if (!ok) return error.ZlibIncrementalWindowWasmMismatch;
}

fn reject(expected: anyerror, result: anytype) !void {
    if (result) |_| return error.ExpectedIncrementalWindowFailure else |err| try require(err == expected);
}

fn cap(bits: u8) usize {
    return @as(usize, 1) << @as(std.math.Log2Int(usize), @intCast(bits));
}

fn guards(bytes: []const u8) !void {
    for (bytes) |byte| try require(byte == 0xa5);
}

fn compression() D.CompressionOptions {
    return .{
        .parser = .hash,
        .lz77_options = .{ .window_len = 65535, .max_chain = 128, .nice_len = 258, .min_match = 3, .max_match = 258, .min_savings_bits = 0 },
    };
}

fn noise(bytes: []u8, seed: u64) void {
    var random = std.Random.DefaultPrng.init(seed);
    random.random().bytes(bytes);
}

const Advance = struct {
    input: usize,
    output: usize,
    status: enum { need_input, need_output, done },
};

fn step(encoder: anytype, input: []const u8, wire: *std.ArrayList(u8), force_zero: bool) !Advance {
    const width: usize = if (force_zero or report[9] % 7 == 0) 0 else 3;
    var guard: [15]u8 = @splat(0xa5);
    const before_input = encoder.total_input;
    const before_output = encoder.total_output;
    const result = try encoder.step(input, guard[4..][0..width]);
    try require(result.progress.input_read <= input.len and result.progress.output_written <= width);
    try require(encoder.total_input == before_input + result.progress.input_read);
    try require(encoder.total_output == before_output + result.progress.output_written);
    try guards(guard[0..4]);
    try guards(guard[4 + result.progress.output_written ..]);
    try wire.appendSlice(allocator, guard[4..][0..result.progress.output_written]);
    try require(encoder.raw.window_limit == cap(encoder.options.window_bits));
    try require(encoder.raw.history.items.len <= cap(encoder.options.window_bits));
    try require(encoder.raw.plain.items.len <= encoder.raw.options.block_len);
    report[9] += 1;
    if (width == 0) report[13] |= 1 << 13;
    return .{
        .input = result.progress.input_read,
        .output = result.progress.output_written,
        .status = switch (result.status) {
            .need_input => .need_input,
            .need_output => .need_output,
            .done => .done,
        },
    };
}

fn feed(encoder: anytype, input: []const u8, wire: *std.ArrayList(u8)) !void {
    var offset: usize = 0;
    var calls: usize = 0;
    while (offset != input.len) : (calls += 1) {
        try require(calls < 8 * (input.len + 8192));
        const end = offset + @min(@as(usize, 31), input.len - offset);
        const advanced = try step(encoder, input[offset..end], wire, false);
        offset += advanced.input;
        try require(advanced.status != .done);
    }
}

fn drain(encoder: anytype, wire: *std.ArrayList(u8), finishing: bool) !void {
    var calls: usize = 0;
    while (true) : (calls += 1) {
        try require(calls < 100000);
        const advanced = try step(encoder, "", wire, false);
        if (advanced.status == .done) {
            try require(finishing);
            return;
        }
        if (advanced.status == .need_input) {
            try require(!finishing);
            return;
        }
    }
}

fn finish(encoder: anytype, wire: *std.ArrayList(u8)) !void {
    encoder.finish();
    try drain(encoder, wire, true);
}

fn audit(encoder: anytype, wire: []const u8, input: []const u8, dictionary: []const u8, target: usize) !oracle.Stats {
    try require(encoder.done and encoder.total_input == input.len and encoder.total_output == wire.len);
    const bits = encoder.options.window_bits;
    // Incremental empty dictionaries preserve the established no-FDICT wire.
    const stats = try oracle.frame(wire, input, if (dictionary.len == 0) null else dictionary, bits, target);
    report[2] |= @as(u64, 1) << @as(u6, @intCast(bits));
    report[3] += 1;
    const slot: usize = switch (bits) {
        9 => 4,
        12 => 5,
        15 => 6,
        else => unreachable,
    };
    report[slot] = @max(report[slot], stats.max_distance);
    report[7] += input.len;
    report[8] += wire.len;
    report[10] += stats.dictionary_matches;
    report[11] += stats.cross_block_matches;
    return stats;
}

fn Saved(comptime Encoder: type) type {
    const Raw = @FieldType(Encoder, "raw");
    return struct {
        snapshot: Encoder.Snapshot,
        raw_snapshot: Raw.Snapshot,
        matcher: Raw.MatchFinderSnapshot,
        epoch: u32,
        options: Encoder.Options,
        raw_compression: D.CompressionOptions,
        active: ?D.ResolvedDeflateParams,
        requested: ?D.ResolvedDeflateParams,
        window_limit: usize,
        retained_window_limit: usize,
        published_window_bits: ?u8,
        dictionary_available: bool,
        adler: u32,
        hashes: [5]u64,
        shapes: [8]usize,
    };
}

fn save(encoder: anytype) Saved(@TypeOf(encoder.*)) {
    return .{
        .snapshot = encoder.snapshot(),
        .raw_snapshot = encoder.raw.snapshot(),
        .matcher = encoder.raw.matchFinderSnapshot(),
        .epoch = encoder.raw.match_finder.epoch,
        .options = encoder.options,
        .raw_compression = encoder.raw.options.compression,
        .active = encoder.raw.active_params,
        .requested = encoder.raw.requested_params,
        .window_limit = encoder.raw.window_limit,
        .retained_window_limit = encoder.raw.retained_window_limit,
        .published_window_bits = encoder.published_window_bits,
        .dictionary_available = encoder.raw.dictionary_available,
        .adler = encoder.adler.digest(),
        .hashes = .{
            std.hash.Wyhash.hash(0, encoder.pending.items),
            std.hash.Wyhash.hash(0, encoder.raw.pending.items),
            std.hash.Wyhash.hash(0, encoder.raw.plain.items),
            std.hash.Wyhash.hash(0, encoder.raw.history.items),
            std.hash.Wyhash.hash(0, encoder.raw.state.bytes.items),
        },
        .shapes = .{
            @intFromPtr(encoder.pending.items.ptr),     encoder.pending.capacity,
            @intFromPtr(encoder.raw.pending.items.ptr), encoder.raw.pending.capacity,
            @intFromPtr(encoder.raw.plain.items.ptr),   encoder.raw.plain.capacity,
            @intFromPtr(encoder.raw.history.items.ptr), encoder.raw.history.capacity,
        },
    };
}

fn refusal(encoder: anytype) !void {
    const before = save(encoder);
    var guard: [16]u8 = @splat(0xa5);
    try reject(error.InvalidZlibWindow, encoder.step("offered", guard[4..12]));
    try require(std.meta.eql(before, save(encoder)));
    try guards(&guard);
    report[12] += 1;
    report[14] += 1;
    try reject(error.InvalidZlibWindow, encoder.requestParams(.{ .level = 1 }));
    try require(std.meta.eql(before, save(encoder)));
    try guards(&guard);
    report[12] += 1;
    report[14] += 1;
}

fn locked(encoder: anytype) !void {
    const bits = encoder.options.window_bits;
    for ([_]u8{ 0, 8, 16, 255, if (bits == 9) 12 else 9 }) |replacement| {
        encoder.options.window_bits = replacement;
        try refusal(encoder);
    }
    encoder.options.window_bits = bits;
    report[13] |= 1 << 12;
}

fn invalidRange(comptime Encoder: type) !void {
    var empty: [0]u8 = .{};
    var denied = std.heap.FixedBufferAllocator.init(&empty);
    for ([_]u8{ 0, 8, 16, 255 }) |bits| {
        inline for (0..4) |constructor| {
            const options: Encoder.Options = .{ .window_bits = bits };
            var encoder = switch (constructor) {
                0 => Encoder.initWithOptions(denied.allocator(), options),
                1 => Encoder.initExactSize(denied.allocator(), options, 7),
                2 => Encoder.initWithDictionary(denied.allocator(), options, "full dictionary"),
                3 => Encoder.initExactSizeWithDictionary(denied.allocator(), options, 7, "full dictionary"),
                else => unreachable,
            };
            defer encoder.deinit();
            try refusal(&encoder);
            const before = save(&encoder);
            try reject(error.InvalidZlibWindow, encoder.nextStream(options, "replacement"));
            try require(std.meta.eql(before, save(&encoder)));
            report[12] += 1;
            report[14] += 1;
            try reject(error.InvalidZlibWindow, encoder.nextStreamExactSize(options, "replacement", 3));
            try require(std.meta.eql(before, save(&encoder)));
            report[12] += 1;
            report[14] += 1;
            try require(denied.end_index == 0 and !encoder.header_written);
        }
    }
    report[13] |= 1 << 11;
}

fn params(encoder: anytype, level: u4) !void {
    try require(encoder.snapshot().active_params.?.level == level);
    try require(encoder.snapshot().requested_params == null);
    try require(std.meta.eql(encoder.raw.active_params.?.compression, encoder.raw.options.compression));
}

fn lifecycle(comptime Encoder: type, bits: u8, dictionary: []const u8, input: []const u8) !void {
    const options: Encoder.Options = .{ .window_bits = bits, .raw = .{ .block_len = 256, .compression = compression() } };
    var encoder = Encoder.initWithDictionary(allocator, options, dictionary);
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(allocator);
    if (Encoder.supports_runtime_params) {
        try encoder.requestParams(.{ .level = 6 });
        try params(&encoder, 6);
        try require(encoder.raw.options.compression.lz77_options.window_len == 32768);
    }
    // Zero output can still publish a complete pending header.
    const header = try step(&encoder, "", &wire, true);
    try require(header.output == 0 and encoder.header_written and encoder.published_window_bits == bits);
    try locked(&encoder);
    try feed(&encoder, input, &wire);
    if (Encoder.supports_runtime_params) {
        try encoder.requestParams(.{ .level = 1 });
        try require(encoder.snapshot().active_params.?.level == 6 and encoder.snapshot().requested_params.?.level == 1);
    }
    try locked(&encoder);
    try drain(&encoder, &wire, false);
    if (Encoder.supports_runtime_params) try params(&encoder, 1);
    try finish(&encoder, &wire);
    const stats = try audit(&encoder, wire.items, input, dictionary, cap(bits));
    try require(stats.dictionary_matches != 0 and stats.target_matches != 0 and stats.cross_block_matches != 0);
    report[13] |= 1 << 2;
    report[13] |= if (Encoder.supports_runtime_params) @as(u64, 1) << 1 else 1;

    const replacement: u8 = if (bits == 15) 9 else if (bits == 9) 12 else 15;
    encoder.options.window_bits = replacement;
    encoder.reset();
    try require(encoder.published_window_bits == null and !encoder.header_written);
    if (Encoder.supports_runtime_params) try params(&encoder, 1);
    wire.clearRetainingCapacity();
    try feed(&encoder, input, &wire);
    try finish(&encoder, &wire);
    _ = try audit(&encoder, wire.items, input, dictionary, 0);
    report[13] |= 1 << 8;

    try encoder.nextStream(options, dictionary);
    try require(encoder.published_window_bits == null and encoder.raw.active_params == null);
    wire.clearRetainingCapacity();
    try feed(&encoder, input, &wire);
    try finish(&encoder, &wire);
    _ = try audit(&encoder, wire.items, input, dictionary, 0);
    try require(encoder.stream_count == 2);
    var exact_options = options;
    exact_options.window_bits = replacement;
    try encoder.nextStreamExactSize(exact_options, "", input.len);
    wire.clearRetainingCapacity();
    try feed(&encoder, input, &wire);
    try finish(&encoder, &wire);
    _ = try audit(&encoder, wire.items, input, "", 0);
    try require(encoder.stream_count == 3);
    report[13] |= 1 << 9;
}

fn schedule(comptime Encoder: type, bits: u8, dictionary: []const u8, first: []const u8) !void {
    var encoder = Encoder.initWithDictionary(allocator, .{ .window_bits = bits, .raw = .{ .block_len = 512, .compression = compression() } }, dictionary);
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(allocator);
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);
    if (Encoder.supports_runtime_params) {
        try encoder.requestParams(.{ .level = 6 });
        try feed(&encoder, first, &wire);
        try expected.appendSlice(allocator, first);
        try encoder.requestParams(.{ .level = 1 });
        try drain(&encoder, &wire, false);
        try params(&encoder, 1);
        try encoder.requestParams(.{ .level = 2 });
        try params(&encoder, 2);
        try encoder.requestParams(.{ .level = 0 });
        try drain(&encoder, &wire, false);
        try params(&encoder, 0);
        try feed(&encoder, first, &wire);
        try expected.appendSlice(allocator, first);
        try encoder.requestParams(.{ .level = 6 });
        try drain(&encoder, &wire, false);
        try params(&encoder, 6);
        report[13] |= 1 << 3;
    }
    inline for (0..4) |mode| {
        try feed(&encoder, first, &wire);
        try expected.appendSlice(allocator, first);
        switch (mode) {
            0 => encoder.blockFlush(),
            1 => encoder.partialFlush(),
            2 => encoder.flush(),
            3 => encoder.fullFlush(),
            else => unreachable,
        }
        try drain(&encoder, &wire, false);
        try require(encoder.raw.window_limit == cap(bits));
        if (mode == 3) try require(!encoder.raw.dictionary_available and encoder.raw.history.items.len == 0);
        report[13] |= @as(u64, 1) << (4 + mode);
    }
    const full_flush_offset = wire.items.len;
    const distance = cap(bits) + 1;
    const suffix = try allocator.alloc(u8, distance + first.len);
    defer allocator.free(suffix);
    noise(suffix[0..distance], 0x1848970 + distance);
    @memcpy(suffix[0..first.len], first);
    @memcpy(suffix[distance..], first);
    encoder.raw.options.compression = compression();
    encoder.raw.options.block_len = suffix.len + 1;
    encoder.raw.window_limit = 65535;
    try feed(&encoder, suffix, &wire);
    try expected.appendSlice(allocator, suffix);
    try finish(&encoder, &wire);
    try require(encoder.raw.window_limit == cap(bits) and !encoder.raw.dictionary_available);
    _ = try audit(&encoder, wire.items, expected.items, dictionary, distance);
    const tail = try oracle.raw(wire.items[full_flush_offset .. wire.items.len - 4], suffix, "", cap(bits), distance);
    try require(tail.target_matches == 0);
    report[13] |= 1 << 10;
}

fn run() !void {
    report = @splat(0);
    report[0] = @bitSizeOf(usize);
    report[1] = @bitSizeOf(Count);
    try require(report[0] == 32 and report[1] == 64);
    inline for (.{ D.ZlibIncrementalFixedEncoder, D.ZlibIncrementalBestEncoder }) |Encoder|
        try invalidRange(Encoder);
    for ([_]u8{ 9, 12, 15 }) |bits| {
        const dictionary = try allocator.alloc(u8, cap(bits) + 777);
        defer allocator.free(dictionary);
        noise(dictionary, 0x31498768 + cap(bits));
        var input: [1152]u8 = undefined;
        const first = dictionary[dictionary.len - cap(bits) ..][0..384];
        @memcpy(input[0..384], first);
        @memcpy(input[384..768], first);
        @memcpy(input[768..], first);
        inline for (.{ D.ZlibIncrementalFixedEncoder, D.ZlibIncrementalBestEncoder }) |Encoder| {
            try lifecycle(Encoder, bits, dictionary, &input);
            try schedule(Encoder, bits, dictionary, first);
        }
    }
    try require(report[2] == 37376 and report[3] == 30);
    try require(report[4] == 512 and report[5] == 4096 and report[6] == 32768);
    try require(report[10] != 0 and report[11] != 0);
    try require(report[12] == 248 and report[14] == report[12] and report[13] == 16383);
}

pub export fn zlibWindowIncrementalContracts() u32 {
    run() catch |err| {
        report[15] = @intFromError(err);
        return 1;
    };
    return 0;
}
