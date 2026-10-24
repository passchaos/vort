const std = @import("std");
const br = @import("../br.zig");
const h = @import("br_hq_helpers.zig");
const allocator = std.testing.allocator;
const command_lut = @import("../br/command_lut.zig");
const command_encoding = @import("../br/encoder/command_encoding.zig");
const distance_encoding = @import("../br/encoder/distance.zig");
const exact_types = @import("../br/encoder/hq_types.zig");
const hq_parser = @import("../br/encoder/hq_parser.zig");

test "Brotli HQ independent RFC mapping covers all seven hundred four commands" {
    try std.testing.expectEqual(@as(usize, 704), command_lut.entries.len);
    var seen_explicit: [24][24]bool = @splat(@splat(false));
    for (command_lut.entries, 0..) |actual, index| {
        const expected = h.command(@intCast(index));
        try std.testing.expectEqual(h.insert_bases[expected.insert_code], actual.insert_base);
        try std.testing.expectEqual(h.copy_bases[expected.copy_code], actual.copy_base);
        try std.testing.expectEqual(@as(u5, @intCast(h.insert_bits[expected.insert_code])), actual.insert_extra_bits);
        try std.testing.expectEqual(@as(u5, @intCast(h.copy_bits[expected.copy_code])), actual.copy_extra_bits);
        try std.testing.expectEqual(if (expected.implicit_last_distance) @as(i2, 0) else -1, actual.distance_code);
        try std.testing.expectEqual(@as(u2, @intCast(@min(expected.copy_code, 3))), actual.context);
        if (!expected.implicit_last_distance) seen_explicit[expected.insert_code][expected.copy_code] = true;
        const selected = command_encoding.forCodes(@intCast(expected.insert_code), @intCast(expected.copy_code), expected.implicit_last_distance) orelse return error.TestUnexpectedResult;
        try std.testing.expectEqual(@as(u16, @intCast(index)), selected.symbol);
    }
    for (seen_explicit) |row| for (row) |seen| try std.testing.expect(seen);
}

test "Brotli HQ independent semantic short selectors preserve every code zero without push" {
    const semantic: [4]usize = .{ 4, 11, 15, 16 };
    const decoder_ring: [4]usize = .{ 16, 15, 11, 4 };
    for (0..16) |index| {
        const expected = h.shortDistance(semantic, @intCast(index)) orelse return error.TestUnexpectedResult;
        try std.testing.expectEqual(expected, try exact_types.resolveDistanceCode(index, &decoder_ring));
        const after = h.afterDistance(semantic, index, expected, false);
        const actual_ring = exact_types.recentAfter(.lz77, index, expected, decoder_ring);
        for (after, 0..) |distance, slot| try std.testing.expectEqual(distance, actual_ring[3 - slot]);
        try std.testing.expectEqual(decoder_ring, exact_types.recentAfter(.static, index, expected, decoder_ring));
    }
    const duplicate: [4]usize = .{ 4, 4, 15, 16 };
    try std.testing.expectEqual(h.shortDistance(duplicate, 0), h.shortDistance(duplicate, 1));
    try std.testing.expectEqual(duplicate, h.afterDistance(duplicate, 0, 4, false));
    try std.testing.expectEqual([4]usize{ 4, 4, 4, 15 }, h.afterDistance(duplicate, 1, 4, false));
}

test "Brotli HQ independent sixty four distance shapes reach complete five hundred twenty alphabet" {
    var maximum_alphabet: usize = 0;
    for (0..4) |postfix| {
        for (0..16) |direct_high| {
            const parameters = distance_encoding.Parameters.init(@intCast(postfix), @intCast(direct_high));
            const direct: u16 = @intCast(direct_high << @intCast(postfix));
            const alphabet = h.alphabetSize(@intCast(postfix), direct);
            maximum_alphabet = @max(maximum_alphabet, alphabet);
            try std.testing.expectEqual(alphabet, parameters.alphabetSize());
            const largest = h.distanceDecoding(.{ .symbol = @intCast(alphabet - 1), .extra_bits = 24, .extra = (1 << 24) - 1 }, @intCast(postfix), direct);
            try std.testing.expectEqual(largest, parameters.maximumDistance());
            for ([_]usize{ 1, 2, 3, 4, 15, 16, 17, 63, 64, 65, 1023, 65535, 65536, (1 << 24) - 16, largest }) |distance| {
                const expected = h.distanceEncoding(distance, @intCast(postfix), direct);
                const actual = distance_encoding.encodeWithParameters(distance, parameters) orelse return error.TestUnexpectedResult;
                try std.testing.expectEqual(expected.symbol, actual.symbol);
                try std.testing.expectEqual(expected.extra_bits, actual.extra_bits);
                try std.testing.expectEqual(expected.extra, actual.extra);
                try std.testing.expectEqual(distance, h.distanceDecoding(expected, @intCast(postfix), direct));
                try std.testing.expectEqual(@as(?usize, distance), distance_encoding.decodeWithParameters(actual, parameters));
            }
            try std.testing.expectEqual(@as(?distance_encoding.Encoding, null), distance_encoding.encodeWithParameters(largest + 1, parameters));
        }
    }
    try std.testing.expectEqual(@as(usize, 520), maximum_alphabet);
}

test "Brotli HQ actual writer preserves implicit explicit and aliased semantic distance selectors" {
    const input = "aaaaaaaa";
    const normal: [4]usize = .{ 16, 15, 11, 4 };
    const duplicate: [4]usize = .{ 16, 15, 4, 4 };
    for ([_]struct { command: u16, code: usize, symbol: ?u16, extra: u32 = 0, bits: u5 = 0, starting: [4]usize, postfix: u2 = 0, direct_high: u4 = 0 }{
        .{ .command = 34, .code = 0, .symbol = null, .starting = normal },
        .{ .command = 162, .code = 0, .symbol = 0, .starting = normal },
        .{ .command = 162, .code = 19, .symbol = 17, .extra = 1, .bits = 1, .starting = normal },
        .{ .command = 162, .code = 1, .symbol = 1, .starting = duplicate },
        .{ .command = 162, .code = 19, .symbol = 19, .starting = normal, .postfix = 3, .direct_high = 15 },
    }) |sample| {
        const encoded = try br.IncrementalTestSupport.encodeHqCommandPlan(allocator, input, &.{.{
            .insert_start = 0,
            .insert_len = 4,
            .copy_len = 4,
            .distance = 4,
            .has_copy = true,
            .hq_encoding = .{ .command_symbol = sample.command, .distance_code = sample.code, .distance_encoding = if (sample.symbol) |symbol| .{ .symbol = symbol, .extra = sample.extra, .extra_bits = sample.bits } else null, .distance_parameters = distance_encoding.Parameters.init(sample.postfix, sample.direct_high) },
        }}, .{ .starting_last_distances = sample.starting, .distance_parameters = distance_encoding.Parameters.init(sample.postfix, sample.direct_high) });
        defer allocator.free(encoded.bytes);
        const semantic = [4]usize{ sample.starting[3], sample.starting[2], sample.starting[1], sample.starting[0] };
        const wire = try h.singleCommandWire(encoded.bytes, semantic);
        try std.testing.expectEqual(@as(usize, sample.command), wire.command_symbol);
        try std.testing.expectEqual(if (sample.symbol) |symbol| @as(?usize, symbol) else null, wire.distance_symbol);
        try std.testing.expectEqual(@as(usize, 4), wire.insert_len);
        try std.testing.expectEqual(@as(usize, 4), wire.raw_copy_len);
        try std.testing.expectEqual(@as(usize, 4), wire.distance);
        try std.testing.expectEqual(@as(usize, input.len), wire.meta_len);
        try std.testing.expectEqual(sample.postfix, wire.npostfix);
        try std.testing.expectEqual(@as(u16, sample.direct_high) << sample.postfix, wire.ndirect);
        const expected_cache = h.afterDistance(semantic, sample.code, 4, false);
        for (expected_cache, 0..) |distance, index| try std.testing.expectEqual(distance, encoded.last_distances[3 - index]);
    }
}

test "Brotli HQ actual static dictionary wire keeps raw copy length separate from output length and cache" {
    // RFC dictionary word index0 at raw length4 is 'time'; transform1 appends
    // one space. Its address is 1*1024 and its transformed output has length5.
    const input = "time ";
    const expected_distance: usize = 1025;
    const selected = h.distanceEncoding(expected_distance, 0, 0);
    const encoded = try br.IncrementalTestSupport.encodeHqCommandPlan(allocator, input, &.{.{
        .insert_start = 0,
        .insert_len = 0,
        .copy_len = 4,
        .has_copy = true,
        .source = .static,
        .dictionary_address = 1024,
        .dictionary_output_len = 5,
        .hq_encoding = .{ .command_symbol = 130, .distance_code = expected_distance + 15, .distance_encoding = .{ .symbol = selected.symbol, .extra = @intCast(selected.extra), .extra_bits = @intCast(selected.extra_bits) } },
    }}, .{});
    defer allocator.free(encoded.bytes);
    const wire = try h.singleCommandWire(encoded.bytes, .{ 4, 11, 15, 16 });
    try std.testing.expectEqual(@as(usize, 4), wire.raw_copy_len);
    try std.testing.expectEqual(@as(usize, 5), wire.meta_len);
    try std.testing.expectEqual(expected_distance, wire.distance);
    try std.testing.expectEqual([4]usize{ 16, 15, 11, 4 }, encoded.last_distances);
}

test "Brotli HQ actual static shortened transforms emit raw four output one two three and preserve cache" {
    // Independently fixed RFC omit-last transforms of dictionary word0 'time'.
    for ([_]struct { transform: usize, output: []const u8 }{
        .{ .transform = 23, .output = "t" },
        .{ .transform = 27, .output = "ti" },
        .{ .transform = 12, .output = "tim" },
    }) |sample| {
        const address = sample.transform * 1024;
        const distance = address + 1;
        const selected = h.distanceEncoding(distance, 0, 0);
        const encoded = try br.IncrementalTestSupport.encodeHqCommandPlan(allocator, sample.output, &.{.{
            .insert_start = 0,
            .insert_len = 0,
            .copy_len = 4,
            .has_copy = true,
            .source = .static,
            .dictionary_address = address,
            .dictionary_output_len = sample.output.len,
            .hq_encoding = .{ .command_symbol = 130, .distance_code = distance + 15, .distance_encoding = .{ .symbol = selected.symbol, .extra = @intCast(selected.extra), .extra_bits = @intCast(selected.extra_bits) } },
        }}, .{});
        defer allocator.free(encoded.bytes);
        const wire = try h.singleCommandWire(encoded.bytes, .{ 4, 11, 15, 16 });
        try std.testing.expectEqual(@as(usize, 130), wire.command_symbol);
        try std.testing.expectEqual(@as(usize, 4), wire.raw_copy_len);
        try std.testing.expectEqual(sample.output.len, wire.meta_len);
        try std.testing.expectEqual(distance, wire.distance);
        try std.testing.expectEqual([4]usize{ 16, 15, 11, 4 }, encoded.last_distances);
        try roundTrip(encoded.bytes, sample.output);
    }
}

test "Brotli HQ actual exact writer emits ordinary distance beyond unsigned sixteen without narrowing" {
    const distance: usize = 65537;
    const input = try allocator.alloc(u8, distance + 4);
    defer allocator.free(input);
    @memset(input, 'a');
    for ([_]distance_encoding.Parameters{ distance_encoding.Parameters.init(0, 0), distance_encoding.Parameters.init(3, 15) }) |parameters| {
        const selected = h.distanceEncoding(distance, parameters.npostfix, parameters.ndirect());
        const encoded = try br.IncrementalTestSupport.encodeHqCommandPlan(allocator, input, &.{.{
            .insert_start = 0,
            .insert_len = distance,
            .copy_len = 4,
            .distance = distance,
            .has_copy = true,
            .hq_encoding = .{ .command_symbol = 506, .distance_code = distance + 15, .distance_encoding = .{ .symbol = selected.symbol, .extra = @intCast(selected.extra), .extra_bits = @intCast(selected.extra_bits) }, .distance_parameters = parameters },
        }}, .{ .window_bits = 17, .distance_parameters = parameters });
        defer allocator.free(encoded.bytes);
        const wire = try h.singleCommandWire(encoded.bytes, .{ 4, 11, 15, 16 });
        try std.testing.expectEqual(@as(usize, 506), wire.command_symbol);
        try std.testing.expectEqual(@as(usize, 17), wire.window_bits);
        try std.testing.expectEqual(distance, wire.insert_len);
        try std.testing.expectEqual(distance, wire.distance);
        try std.testing.expectEqual(@as(?usize, selected.symbol), wire.distance_symbol);
        try std.testing.expectEqual([4]usize{ 15, 11, 4, distance }, encoded.last_distances);
        try roundTrip(encoded.bytes, input);
    }
}

test "Brotli HQ public raw prefix dictionary publishes real compound copies and requires the same borrowed content" {
    var prefix: [64]u8 = undefined;
    for (&prefix, 0..) |*byte, index| byte.* = @intCast(index);
    const shared: br.SharedDictionary = .{ .raw_prefixes = &.{&prefix} };
    for ([_]u4{ 10, 11 }) |quality| {
        var profile: br.HqProfile = .{};
        const bytes = try br.encodePlannedStreamWithOptionsAlloc(allocator, &prefix, .{
            .quality = quality,
            .shared_dictionary = shared,
            .hq = .{ .profile = &profile },
        });
        defer allocator.free(bytes);
        try std.testing.expect(profile.compound_probes > 0 and profile.compound_candidates > 0);
        try std.testing.expect(profile.emitted_compound_commands > 0);
        const decoded = try br.decodeStreamAllocWithOptions(allocator, bytes, .{ .shared_dictionary = shared });
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, &prefix, decoded);
    }
}

test "Brotli HQ null quality mode and API wires match the complete pre HQ binary baseline" {
    const chunks = [_][]const u8{ h.legacy_plain[0..17], h.legacy_plain[17..93], h.legacy_plain[93..] };
    var reusable = br.PlannedStreamEncoder.init(allocator);
    defer reusable.deinit();
    for (h.legacy_wires) |sample| {
        const mode = std.meta.stringToEnum(br.PlannedMode, sample.mode) orelse unreachable;
        const expected = try h.decodeHex(allocator, sample.hex);
        defer allocator.free(expected);
        const actual = switch (sample.api) {
            .one_shot => try br.encodePlannedStreamWithOptionsAlloc(allocator, h.legacy_plain, .{ .quality = sample.quality, .mode = mode }),
            .reusable => try reusable.encodeWithOptionsAlloc(allocator, h.legacy_plain, .{ .quality = sample.quality, .mode = mode }),
            .chunks => try br.encodePlannedStreamChunksWithOptionsAlloc(allocator, &chunks, .{ .quality = sample.quality, .mode = mode }),
            .incremental => block: {
                var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(allocator, .{ .stream = .{ .quality = sample.quality, .mode = mode } });
                defer encoder.deinit();
                break :block try h.drive(allocator, &encoder, h.legacy_plain, 31, 17);
            },
        };
        defer allocator.free(actual);
        try std.testing.expectEqualSlices(u8, expected, actual);
    }
}

fn roundTrip(bytes: []const u8, expected: []const u8) !void {
    const decoded = try br.decodeStreamAlloc(allocator, bytes);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "Brotli HQ q10 q11 generic text font publish real work and preserve profiled wire" {
    for ([_]br.PlannedMode{ .generic, .text, .font }) |mode| {
        var profile: br.HqProfile = .{};
        const options: br.PlannedEncodeOptions = .{ .quality = 10, .mode = mode, .hq = .{ .profile = &profile } };
        const q10 = try br.encodePlannedStreamWithOptionsAlloc(allocator, h.legacy_plain, options);
        defer allocator.free(q10);
        try roundTrip(q10, h.legacy_plain);
        try std.testing.expect(profile.tree_nodes > 0 and profile.price_evaluations > 0);
        try std.testing.expect(profile.transitions > 0 and profile.states > 0);
        try std.testing.expect(profile.passes > 0 and profile.emitted_metablocks > 0);
        try std.testing.expectEqual(@as(u8, 10), profile.effective.?.quality);
        var unprofiled = options;
        unprofiled.hq.?.profile = null;
        const same = try br.encodePlannedStreamWithOptionsAlloc(allocator, h.legacy_plain, unprofiled);
        defer allocator.free(same);
        try std.testing.expectEqualSlices(u8, q10, same);
        profile.reset();
        var higher = options;
        higher.quality = 11;
        const q11 = try br.encodePlannedStreamWithOptionsAlloc(allocator, h.legacy_plain, higher);
        defer allocator.free(q11);
        try roundTrip(q11, h.legacy_plain);
        try std.testing.expect(q11.len <= q10.len);
        try std.testing.expectEqual(@as(u8, 11), profile.effective.?.quality);
        try std.testing.expect(profile.passes >= 2);
    }
}

test "Brotli HQ all standard windows and short tails are valid without large allocation" {
    for (10..25) |window| {
        const input = "window window window tail!";
        const bytes = try br.encodePlannedStreamWithOptionsAlloc(allocator, input, .{ .quality = 10, .window_bits = @intCast(window), .hq = .{} });
        defer allocator.free(bytes);
        try roundTrip(bytes, input);
    }
    for ([_][]const u8{ "", "x", "xy", "xyz", "abababab" }) |input| {
        const bytes = try br.encodePlannedStreamWithOptionsAlloc(allocator, input, .{ .quality = 11, .hq = .{} });
        defer allocator.free(bytes);
        try roundTrip(bytes, input);
    }
}

test "Brotli HQ whole meta block chunks reusable and fragmented streams preserve requested boundaries" {
    const input = h.legacy_plain;
    const chunks = [_][]const u8{ input[0..31], input[31..93], input[93..] };
    const options: br.PlannedStreamChunksOptions = .{ .quality = 10, .hq = .{ .block_len = 512 } };
    const expected = try br.encodePlannedStreamChunksWithOptionsAlloc(allocator, &chunks, options);
    defer allocator.free(expected);
    try roundTrip(expected, input);
    var reusable = br.PlannedStreamEncoder.init(allocator);
    defer reusable.deinit();
    const owned = try reusable.encodeChunksWithOptionsAlloc(allocator, &chunks, options);
    defer allocator.free(owned);
    try std.testing.expectEqualSlices(u8, expected, owned);
    var incremental = br.IncrementalPlannedStreamEncoder.initWithOptions(allocator, .{ .stream = options });
    defer incremental.deinit();
    const fragmented = try h.drive(allocator, &incremental, input, 1, 1);
    defer allocator.free(fragmented);
    try std.testing.expectEqualSlices(u8, expected, fragmented);
}

test "Brotli HQ complete command tail cost rejects unconditional match extension across parser horizon" {
    const input = try h.boundaryInput(allocator);
    defer allocator.free(input);
    var model: hq_parser.Model = .{};
    for (&model.literal_prices) |*row| @memset(row, 8 * 256);
    @memset(&model.command_prices, 64 * 256);
    model.command_prices[488] = 256;
    model.command_prices[144] = 256;
    @memset(&model.distance_prices, 64 * 256);
    model.distance_prices[36] = 0;
    const source = try hq_parser.Source.init("", input, 13, 0);
    const parameters = try hq_parser.Parameters.init(.{ .nice_len = 128 }, 10, br.PlannedMode.generic);
    const plan = try hq_parser.planAlloc(allocator, source, parameters, &model, null);
    defer plan.deinit(allocator);
    const global_minimum = h.boundaryMinimumCost(input) * 256;
    const literal_cost: u64 = input.len * 8 + h.commandCost(input.len, 2, false, 0);
    const legal_short_cost: u64 = (4094 + 2) * 8 + h.commandCost(4094, 2, true, 4094) + h.commandCost(2, 2, false, 0);
    const extended_cost: u64 = 4094 * 8 + h.commandCost(4094, 4, true, 4094);
    // The fixed 4096 horizon is not a global optimum guarantee. This input's
    // independent suffix oracle is 32792 bits; the bounded result currently
    // takes the legal 32793-bit early copy2 path, a known one-bit quality gap.
    try std.testing.expectEqual(@as(u64, 32792 * 256), global_minimum);
    try std.testing.expectEqual(@as(u64, 32793), legal_short_cost);
    try std.testing.expect(extended_cost > literal_cost);
    try std.testing.expect(plan.estimated_cost >= global_minimum);
    try std.testing.expect(plan.estimated_cost <= legal_short_cost * 256);
    try std.testing.expectEqual(input.len, plan.consumed);
    var saw_short = false;
    for (plan.commands) |command| if (command.has_copy) {
        try std.testing.expectEqual(@as(usize, 2), command.copy_len);
        saw_short = true;
    };
    try std.testing.expect(saw_short);
    try h.replayLzPlan(allocator, input, plan);
}
