const std = @import("std");
const samples = @import("encode_samples.zig");
const t = std.testing;

const lengths: samples.WireLengths = .{ .vort_bytes = 11, .zlib_bytes = 13, .libdeflate_bytes = 17 };

fn fill(rounds: []samples.Round, base_ns: u64, iterations: usize) void {
    for (rounds, 0..) |*round, index| {
        round.* = .init(index);
        for (round.order) |encoder| {
            const bytes = switch (encoder) {
                .vort => lengths.vort_bytes,
                .zlib => lengths.zlib_bytes,
                .libdeflate => lengths.libdeflate_bytes,
            };
            round.record(encoder, .{ .elapsed_ns = base_ns + index, .mix = samples.expectedMix(bytes, iterations) });
        }
    }
}

test "Deflate summaries use all measured medians and preserve raw chronology" {
    var rounds: [6]samples.Round = undefined;
    fill(&rounds, 0, 1);
    const vort = [_]u64{ 90, 1, 20, 80, 30, 40 };
    const zlib = [_]u64{ 4, 100, 8, 2, 12, 16 };
    const libdeflate = [_]u64{ 700, 300, 500, 100, 600, 400 };
    for (&rounds, 0..) |*round, index| {
        round.vort_ns = vort[index];
        round.zlib_ns = zlib[index];
        round.libdeflate_ns = libdeflate[index];
    }
    const original = rounds;
    const summary = try samples.summarize(t.allocator, &rounds);
    try t.expectEqualDeep(samples.Summary{
        .vort_min_ns = 1,
        .zlib_min_ns = 2,
        .libdeflate_min_ns = 100,
        .vort_median_ns = 35,
        .zlib_median_ns = 10,
        .libdeflate_median_ns = 450,
    }, summary);
    try t.expectEqualDeep(original, rounds);
    try t.expect(summary.vort_median_ns != summary.vort_min_ns);
    try t.expectError(error.InvalidOptions, samples.summarize(t.allocator, &.{}));

    const maximum = std.math.maxInt(u64);
    for (&rounds, 0..) |*round, index| round.vort_ns = maximum - 5 + index;
    const high = try samples.summarize(t.allocator, &rounds);
    try t.expectEqual(maximum - 3, high.vort_median_ns);
}

test "Deflate six permutations balance every encoder position and repeat whole cycles" {
    var positions: [3][3]usize = @splat(@splat(0));
    for (0..samples.permutation_count) |index| {
        const order = samples.orderForRound(index);
        for (order, 0..) |encoder, position| positions[@intFromEnum(encoder)][position] += 1;
        for (0..index) |previous|
            try t.expect(!std.meta.eql(order, samples.orderForRound(previous)));
        try t.expectEqualDeep(order, samples.orderForRound(index + samples.permutation_count));
        try t.expect(order[0] != order[1] and order[0] != order[2] and order[1] != order[2]);
    }
    for (positions) |encoder_positions| for (encoder_positions) |count| try t.expectEqual(@as(usize, 2), count);
}

test "Deflate warmup is retained separately and excluded from measured summaries" {
    const measurement = try samples.Measurements.init(t.allocator, 12, 6);
    defer measurement.deinit(t.allocator);
    fill(measurement.warmup_rounds, 1, 2);
    fill(measurement.rounds, 100, 2);
    try measurement.validate(2, lengths);
    const summary = try measurement.summary(t.allocator);
    try t.expectEqual(@as(u64, 100), summary.vort_min_ns);
    try t.expectEqual(@as(u64, 105), summary.vort_median_ns);
    try t.expectEqual(@as(usize, 12), measurement.rounds.len);
    try t.expectEqual(@as(usize, 6), measurement.warmup_rounds.len);
    try t.expectEqual(@as(u64, 111), measurement.rounds[11].vort_ns);

    measurement.warmup_rounds[4].zlib_mix += 1;
    try t.expectError(error.SampleWireMismatch, measurement.validate(2, lengths));
    measurement.warmup_rounds[4].zlib_mix -= 1;
    measurement.rounds[9].order = measurement.rounds[8].order;
    try t.expectError(error.InvalidSampleOrder, measurement.validate(2, lengths));

    const without_warmup = try samples.Measurements.init(t.allocator, 6, 0);
    defer without_warmup.deinit(t.allocator);
    fill(without_warmup.rounds, 10, 1);
    try without_warmup.validate(1, lengths);
    try t.expectEqual(@as(usize, 0), without_warmup.warmup_rounds.len);
}

test "Deflate sample counts reject biased or empty cycles before measurement" {
    try t.expectEqual(@as(usize, 6), samples.default_rounds);
    try t.expectEqual(@as(usize, 6), samples.default_warmup);
    try samples.validateCounts(1, 6, 6);
    try samples.validateCounts(7, 12, 0);
    try samples.validateCounts(1, 18, 12);
    for ([_]usize{ 0, 1, 3, 5, 7 }) |rounds|
        try t.expectError(error.InvalidOptions, samples.validateCounts(1, rounds, 6));
    for ([_]usize{ 1, 3, 5, 7 }) |warmup|
        try t.expectError(error.InvalidOptions, samples.validateCounts(1, 6, warmup));
    try t.expectError(error.InvalidOptions, samples.validateCounts(0, 6, 0));
    try t.expectError(error.InvalidOptions, samples.Measurements.init(t.allocator, 5, 0));
}

test "Deflate JSON retains every paired round, warmup, wire hashes and lifecycle scope" {
    const measurement = try samples.Measurements.init(t.allocator, 12, 6);
    defer measurement.deinit(t.allocator);
    fill(measurement.rounds, 100, 3);
    fill(measurement.warmup_rounds, 1, 3);
    const summary = try measurement.summary(t.allocator);
    var output: std.Io.Writer.Allocating = .init(t.allocator);
    defer output.deinit();
    try samples.write(&output.writer, .{
        .case = "test-case",
        .input_bytes = 1000,
        .input_sha256 = @splat('a'),
        .iterations = 3,
        .measurements = measurement,
        .summary = summary,
        .level = 9,
        .libdeflate_level = 12,
        .wires = .{
            .vort_bytes = lengths.vort_bytes,
            .zlib_bytes = lengths.zlib_bytes,
            .libdeflate_bytes = lengths.libdeflate_bytes,
            .vort_sha256 = @splat('b'),
            .zlib_sha256 = @splat('c'),
            .libdeflate_sha256 = @splat('d'),
        },
    }, .{
        .{ .role = "zlib", .version = "test-zlib", .version_scope = "runtime_api" },
        .{ .role = "libdeflate", .version = "test-libdeflate", .version_scope = "compile_time_header" },
    }, .{ .optimize = "ReleaseFast", .command = "test-command" });
    const parsed = try std.json.parseFromSlice(std.json.Value, t.allocator, output.written(), .{});
    defer parsed.deinit();
    const root = parsed.value.object;
    try t.expectEqualStrings(samples.schema, root.get("schema").?.string);
    try t.expectEqualStrings("median", root.get("csv_aggregation").?.string);
    try t.expectEqualStrings("cold_per_call", root.get("lifecycle").?.object.get("state").?.string);
    const validation = root.get("validation").?.object;
    try t.expectEqualStrings("initial_wire_only", validation.get("wire_decode_scope").?.string);
    try t.expect(!validation.get("timed_wire_full_decode").?.bool);
    const row = root.get("rows").?.array.items[0].object;
    const rounds = row.get("rounds").?.array.items;
    try t.expectEqual(@as(usize, 12), rounds.len);
    try t.expectEqual(@as(usize, 6), row.get("warmup_rounds").?.array.items.len);
    for (rounds, 0..) |round, index| {
        const raw = round.object;
        try t.expectEqual(@as(i64, @intCast(index)), raw.get("index").?.integer);
        for ([_][]const u8{ "vort_ns", "zlib_ns", "libdeflate_ns" }) |field|
            try t.expectEqual(@as(i64, @intCast(100 + index)), raw.get(field).?.integer);
        try t.expectEqual(@as(i64, 33), raw.get("vort_mix").?.integer);
        try t.expectEqual(@as(i64, 39), raw.get("zlib_mix").?.integer);
        try t.expectEqual(@as(i64, 51), raw.get("libdeflate_mix").?.integer);
        for (raw.get("order").?.array.items, samples.orderForRound(index)) |encoder, expected|
            try t.expectEqualStrings(@tagName(expected), encoder.string);
    }
    try t.expectEqual(@as(i64, 105), row.get("summary").?.object.get("vort_median_ns").?.integer);
    try t.expect(!row.get("settings").?.object.get("equal_quality_claim").?.bool);
    try t.expectEqual(@as(i64, 9), row.get("settings").?.object.get("vort_level").?.integer);
    try t.expectEqual(@as(i64, 9), row.get("settings").?.object.get("zlib_level").?.integer);
    try t.expectEqual(@as(i64, 12), row.get("settings").?.object.get("libdeflate_level").?.integer);
    try t.expectEqualStrings(&(@as([64]u8, @splat('b'))), row.get("wires").?.object.get("vort_sha256").?.string);
    try t.expectEqualStrings("test-libdeflate", root.get("references").?.array.items[1].object.get("version").?.string);
    try t.expectEqualStrings("test-command", root.get("provenance").?.object.get("command").?.string);
}
