//! Public literal-entropy regression inputs with no repeated LZ anchors.
const std = @import("std");
const memory = @import("br_total_memory_helpers.zig");
const Mode = enum { generic, text, font };
const Surface = enum { one, chunks, incremental };
const Config = struct { quality: u4, input: []const u8, mode: Mode = .generic, window: u5 = 16 };
const binary = @embedFile("literal_entropy_fixtures/b32-3.bin");
const text = @embedFile("literal_entropy_fixtures/b32-3-text.bin");
const font = @embedFile("literal_entropy_fixtures/b64-2-font.bin");
const opaque_input = @embedFile("literal_entropy_fixtures/opaque.bin");
const random_no3 = @embedFile("literal_entropy_fixtures/random-no3-4096.bin");
const small = @embedFile("literal_entropy_fixtures/b16-2.bin");

pub fn contracts(comptime C: type) !void {
    try uniqueAnchors();
    try publicSurfaces(C);
    try modesAndTiny(C);
    try uniformLiteralFallback(C);
    try reusableAndLegacy(C);
    try dictionaryAndFixedScratch(C);
    try requestedMemory(C);
    try allocationFailures(C);
}

fn oneOptions(comptime C: type, config: Config) C.PlannedEncodeOptions {
    return .{ .quality = config.quality, .window_bits = config.window, .mode = switch (config.mode) {
        .generic => .generic,
        .text => .text,
        .font => .font,
    } };
}

fn streamOptions(comptime C: type, config: Config) C.PlannedStreamChunksOptions {
    return .{ .quality = config.quality, .window_bits = config.window, .mode = switch (config.mode) {
        .generic => .generic,
        .text => .text,
        .font => .font,
    }, .block_len = @max(1, @min(config.input.len / 2, 8192)), .adaptive_blocks = false };
}

fn encode(comptime C: type, allocator: std.mem.Allocator, config: Config, surface: Surface) ![]u8 {
    switch (surface) {
        .one => return C.encodePlannedStreamWithOptionsAlloc(allocator, config.input, oneOptions(C, config)),
        .chunks => {
            const input = config.input;
            const chunks = [_][]const u8{ input[0 .. input.len / 4], input[input.len / 4 .. input.len / 2], input[input.len / 2 .. input.len * 3 / 4], input[input.len * 3 / 4 ..] };
            return C.encodePlannedStreamChunksWithOptionsAlloc(allocator, &chunks, streamOptions(C, config));
        },
        .incremental => {
            const stream = streamOptions(C, config);
            var encoder = C.IncrementalPlannedStreamEncoder.initWithOptions(allocator, .{ .stream = stream, .block_len = stream.block_len });
            defer encoder.deinit();
            return memory.drive(allocator, &encoder, config.input, 257, 13);
        },
    }
}

fn checkDecode(comptime C: type, wire: []const u8, input: []const u8) !void {
    const decoded = try C.decodeStreamAllocExactSize(std.testing.allocator, wire, input.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

fn entropyBound(input: []const u8, wire: []const u8) !void {
    // These fixtures have a small alphabet but no usable repeated LZ anchor.
    // A stored-only shortcut loses more than one quarter of their input size.
    try std.testing.expect(wire.len * 4 < input.len * 3);
}

fn uniqueAnchors() !void {
    inline for (.{ .{ .input = binary, .order = 3 }, .{ .input = text, .order = 3 }, .{ .input = font, .order = 2 }, .{ .input = opaque_input, .order = 3 }, .{ .input = small, .order = 2 }, .{ .input = random_no3, .order = 3 } }) |fixture| {
        var seen: std.AutoHashMap(u32, void) = .init(std.testing.allocator);
        defer seen.deinit();
        for (0..fixture.input.len - fixture.order + 1) |position| {
            var anchor: u32 = 0;
            for (0..fixture.order) |byte| anchor |= @as(u32, fixture.input[position + byte]) << @intCast(byte * 8);
            try std.testing.expect(!seen.contains(anchor));
            try seen.put(anchor, {});
        }
        try std.testing.expectEqual(fixture.input.len - fixture.order + 1, seen.count());
    }
}

fn publicSurfaces(comptime C: type) !void {
    const configs = [_]Config{
        .{ .quality = 2, .input = small, .window = 10 },
        .{ .quality = 3, .input = small },
        .{ .quality = 4, .input = font },
        .{ .quality = 8, .input = binary },
        .{ .quality = 10, .input = binary },
        .{ .quality = 11, .input = binary },
    };
    var q10_sizes: [3]usize = undefined;
    for (configs) |config| {
        for ([_]Surface{ .one, .chunks, .incremental }, 0..) |surface, index| {
            errdefer std.debug.print("literal entropy quality={d} surface={s}\n", .{ config.quality, @tagName(surface) });
            const wire = try encode(C, std.testing.allocator, config, surface);
            defer std.testing.allocator.free(wire);
            try checkDecode(C, wire, config.input);
            const summary = try C.summarizeStream(wire);
            try std.testing.expectEqual(@as(usize, config.window), @as(usize, summary.window_bits));
            if (config.quality >= 4) {
                if (config.quality >= 8)
                    try entropyBound(config.input, wire)
                else
                    try std.testing.expect(wire.len * 8 < config.input.len * 7);
                try std.testing.expect(summary.compressed_meta_block_count != 0);
            }
            if (config.quality == 10) q10_sizes[index] = wire.len;
            if (config.quality == 11) try std.testing.expect(wire.len <= q10_sizes[index]);
        }
    }
}

fn modesAndTiny(comptime C: type) !void {
    for ([_]Config{
        .{ .quality = 4, .input = opaque_input },
        .{ .quality = 10, .input = text, .mode = .text, .window = 10 },
        .{ .quality = 8, .input = font, .mode = .font, .window = 10 },
        .{ .quality = 11, .input = font, .mode = .font },
    }, 0..) |config, index| {
        const wire = try encode(C, std.testing.allocator, config, .one);
        defer std.testing.allocator.free(wire);
        try checkDecode(C, wire, config.input);
        if (index == 0) {
            try std.testing.expect(wire.len <= try C.encodedStoredStreamBoundWithOptions(config.input.len, .{ .window_bits = config.window }));
        } else try entropyBound(config.input, wire);
    }
    for ([_]u4{ 2, 3, 4, 8, 10, 11 }) |quality| {
        for ([_][]const u8{ "", "a", "ab", "abc", "vort" }) |input| {
            const stored = try C.encodeStoredStreamWithOptionsAlloc(std.testing.allocator, input, .{ .window_bits = 16 });
            defer std.testing.allocator.free(stored);
            const actual = try encode(C, std.testing.allocator, .{ .quality = quality, .input = input }, .one);
            defer std.testing.allocator.free(actual);
            try std.testing.expectEqualSlices(u8, stored, actual);
            try checkDecode(C, actual, input);
        }
    }
}

fn uniformLiteralFallback(comptime C: type) !void {
    // Admission is intentionally based on the frozen global one-tree model;
    // rejection preserves the established no-copy stored path for this input.
    const config: Config = .{ .quality = 10, .input = random_no3 };
    const stored = try C.encodeStoredStreamWithOptionsAlloc(std.testing.allocator, random_no3, .{ .window_bits = 16 });
    defer std.testing.allocator.free(stored);
    const ordinary = try encode(C, std.testing.allocator, config, .one);
    defer std.testing.allocator.free(ordinary);
    try std.testing.expectEqualSlices(u8, stored, ordinary);
    var reusable = C.PlannedStreamEncoder.init(std.testing.allocator);
    defer reusable.deinit();
    const owned = try reusable.encodeWithOptionsAlloc(std.testing.allocator, random_no3, oneOptions(C, config));
    defer std.testing.allocator.free(owned);
    try std.testing.expectEqualSlices(u8, stored, owned);
    for ([_]Surface{ .chunks, .incremental }) |surface| {
        const wire = try encode(C, std.testing.allocator, config, surface);
        defer std.testing.allocator.free(wire);
        try checkDecode(C, wire, random_no3);
        const summary = try C.summarizeStream(wire);
        try std.testing.expectEqual(@as(usize, 0), summary.compressed_meta_block_count);
    }
}

fn reusableAndLegacy(comptime C: type) !void {
    for ([_]C.PlannedCompressionLevel{ .fast, .balanced, .ratio }) |level| {
        const wire = try C.encodePlannedStreamWithOptionsAlloc(std.testing.allocator, binary, .{ .level = level });
        defer std.testing.allocator.free(wire);
        try entropyBound(binary, wire);
        try checkDecode(C, wire, binary);
    }
    const expected = try C.encodePlannedStreamWithOptionsAlloc(std.testing.allocator, binary, .{});
    defer std.testing.allocator.free(expected);
    var reusable = C.PlannedStreamEncoder.init(std.testing.allocator);
    defer reusable.deinit();
    const owned = try reusable.encodeWithOptionsAlloc(std.testing.allocator, binary, .{});
    defer std.testing.allocator.free(owned);
    try std.testing.expectEqualSlices(u8, expected, owned);
    const borrowed = try reusable.encodeScratchWithOptions(binary, .{});
    try std.testing.expectEqualSlices(u8, expected, borrowed);
    const bound = try C.encodedPlannedStreamBoundWithOptions(binary.len, .{});
    const guarded = try std.testing.allocator.alloc(u8, bound + 32);
    defer std.testing.allocator.free(guarded);
    @memset(guarded, 0xa5);
    const written = try reusable.encodeIntoWithOptions(binary, guarded[16 .. 16 + bound], .{});
    try std.testing.expectEqualSlices(u8, expected, guarded[16 .. 16 + written]);
    for (guarded[0..16]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    for (guarded[16 + bound ..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    var profile: C.RatioEncodeProfile = .{};
    const profiled = try C.profilePlannedRatioBlockAlloc(std.testing.allocator, binary, std.testing.io, &profile);
    defer std.testing.allocator.free(profiled);
    const ratio = try C.encodePlannedStreamRatioAlloc(std.testing.allocator, binary);
    defer std.testing.allocator.free(ratio);
    try std.testing.expectEqualSlices(u8, ratio, profiled);
    try entropyBound(binary, profiled);
}

fn dictionaryAndFixedScratch(comptime C: type) !void {
    const prefix = [_]u8{0xff} ** 64;
    const prefixes = [_][]const u8{&prefix};
    const dictionary: C.SharedDictionary = .{ .raw_prefixes = &prefixes };
    const wire = try C.encodePlannedStreamWithOptionsAlloc(std.testing.allocator, binary, .{ .quality = 10, .window_bits = 16, .shared_dictionary = dictionary });
    defer std.testing.allocator.free(wire);
    try entropyBound(binary, wire);
    const decoded = try C.decodeStreamAllocExactSizeWithOptions(std.testing.allocator, wire, binary.len, .{ .shared_dictionary = dictionary });
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, binary, decoded);
    const scratch = try std.testing.allocator.alloc(u8, 2 * 1024 * 1024);
    defer std.testing.allocator.free(scratch);
    const fixed = try C.encodePlannedStreamWithScratchAlloc(std.testing.allocator, scratch, binary);
    defer std.testing.allocator.free(fixed);
    try entropyBound(binary, fixed);
    try checkDecode(C, fixed, binary);
    var tiny_scratch: [1]u8 = undefined;
    try std.testing.expectError(error.OutOfMemory, C.encodePlannedStreamWithScratchAlloc(std.testing.allocator, &tiny_scratch, binary));
}

fn peakContract(comptime C: type, config: Config) !void {
    var tracked = memory.TrackingAllocator.init(std.testing.allocator);
    tracked.force_moving_growth = true;
    const allocator = tracked.allocator();
    var profile: C.EncodeMemoryProfile = .{};
    var options = oneOptions(C, config);
    options.memory_profile = &profile;
    const expected = measured: {
        const wire = try C.encodePlannedStreamWithOptionsAlloc(allocator, config.input, options);
        defer allocator.free(wire);
        try std.testing.expect(profile.available);
        try std.testing.expectEqual(tracked.peak, profile.peak_requested_bytes);
        try std.testing.expectEqual(wire.len, tracked.live);
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
        break :measured try std.testing.allocator.dupe(u8, wire);
    };
    defer std.testing.allocator.free(expected);
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
    try std.testing.expectEqual(tracked.allocated_bytes, tracked.freed_bytes);
    const peak = tracked.peak;
    profile.reset();
    tracked.beginMeasurement();
    options.max_total_working_memory = peak;
    {
        const exact = try C.encodePlannedStreamWithOptionsAlloc(allocator, config.input, options);
        defer allocator.free(exact);
        try std.testing.expectEqualSlices(u8, expected, exact);
        try std.testing.expectEqual(peak, tracked.peak);
        try std.testing.expectEqual(peak, profile.peak_requested_bytes);
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    }
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
    profile.reset();
    tracked.beginMeasurement();
    options.max_total_working_memory = peak - 1;
    if (C.encodePlannedStreamWithOptionsAlloc(allocator, config.input, options)) |unexpected| {
        allocator.free(unexpected);
        return error.TestExpectedError;
    } else |err| try std.testing.expectEqual(error.WorkingMemoryLimitExceeded, err);
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    try std.testing.expect(tracked.peak <= peak - 1);
    try std.testing.expectEqual(tracked.peak, profile.peak_requested_bytes);
    try std.testing.expectEqual(tracked.allocated_bytes, tracked.freed_bytes);
}

fn requestedMemory(comptime C: type) !void {
    for ([_]Config{ .{ .quality = 3, .input = small, .window = 10 }, .{ .quality = 10, .input = binary }, .{ .quality = 11, .input = font, .mode = .font } }) |config|
        try peakContract(C, config);
}

fn allocationFailures(comptime C: type) !void {
    const Run = struct {
        fn run(allocator: std.mem.Allocator, surface: Surface) !void {
            const wire = try encode(C, allocator, .{ .quality = 4, .input = small }, surface);
            defer allocator.free(wire);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Run.run, .{Surface.one});
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Run.run, .{Surface.incremental});
}
