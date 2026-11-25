//! Diagnostic binding regressions. The byte oracle always requests window16;
//! the default-window profile convenience API is never an oracle here.
const std = @import("std");
const br = @import("vort_br");
const provenance = @import("benchmark_provenance");

pub fn configuration(options: br.PlannedEncodeOptions, write_configuration: anytype) !void {
    try std.testing.expectEqual(@as(?u4, 8), options.quality);
    try std.testing.expectEqual(br.PlannedMode.generic, options.mode);
    try std.testing.expectEqual(@as(?u5, 16), options.window_bits);
    try std.testing.expect(!options.large_window);

    var json = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer json.deinit();
    try json.writer.writeByte('{');
    try write_configuration(&json.writer);
    try json.writer.writeByte('}');
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json.written(), .{});
    defer parsed.deinit();
    const fields = parsed.value.object;
    try std.testing.expectEqual(@as(i64, options.quality.?), fields.get("quality").?.integer);
    try std.testing.expectEqualStrings(@tagName(options.mode), fields.get("mode").?.string);
    try std.testing.expectEqual(@as(i64, options.window_bits.?), fields.get("window_bits").?.integer);
    try std.testing.expectEqual(@as(i64, @sizeOf(br.QualityQ8Profile)), fields.get("profile_state_bytes").?.integer);
}

pub fn profileJson(write_profile: anytype) !void {
    const profile = try std.testing.allocator.create(br.QualityQ8Profile);
    defer std.testing.allocator.destroy(profile);
    profile.* = .{
        .parameter_pairs = 7,
        .parameter_counted_candidates = 14,
        .parameter_physical_emits = 8,
        .parameter_skipped_pair_emits = 6,
        .events_truncated = true,
        .wire_attempt_coverage_complete = false,
        .timing_complete = false,
        .context_details_truncated = true,
    };
    var json = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer json.deinit();
    try write_profile(&json.writer, profile);
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json.written(), .{});
    defer parsed.deinit();
    const fields = parsed.value.object;
    try std.testing.expectEqual(@as(i64, 7), fields.get("parameter_pairs").?.integer);
    try std.testing.expectEqual(@as(i64, 14), fields.get("parameter_counted_candidates").?.integer);
    try std.testing.expectEqual(@as(i64, 8), fields.get("parameter_physical_emits").?.integer);
    try std.testing.expectEqual(@as(i64, 6), fields.get("parameter_skipped_pair_emits").?.integer);
    try std.testing.expect(fields.get("events_truncated").?.bool);
    try std.testing.expect(!fields.get("wire_attempt_coverage_complete").?.bool);
    try std.testing.expect(!fields.get("timing_complete").?.bool);
    try std.testing.expect(fields.get("context_details_truncated").?.bool);
    try std.testing.expect(fields.get("exclusive_ns").?.object.contains("evaluate"));
    try std.testing.expectEqual(@as(usize, 0), fields.get("events").?.array.items.len);
}

pub fn wireBinding(options: br.PlannedEncodeOptions, normal_pass: anytype, profile_pass: anytype) !void {
    const allocator = std.testing.allocator;
    const input = try allocator.alloc(u8, 64 * 1024);
    defer allocator.free(input);
    // Freeze the whole 64KiB fixture, including its distant 16KiB copy.
    var state: u32 = 0x243f_6a88;
    for (input) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @as(u8, 97) + @as(u8, @intCast((state >> 24) % 26));
    }
    @memcpy(input[48 * 1024 ..], input[0 .. 16 * 1024]);

    const expected = try br.encodePlannedStreamWithOptionsAlloc(allocator, input, .{
        .quality = 8,
        .mode = .generic,
        .window_bits = 16,
    });
    defer allocator.free(expected);
    const summary = try br.summarizeStreamAlloc(allocator, expected);
    try std.testing.expectEqual(@as(u5, 16), summary.window_bits);
    try std.testing.expect(!summary.large_window);
    const decoded = try br.decodeStreamAlloc(allocator, expected);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);

    const profile = try allocator.create(br.QualityQ8Profile);
    defer allocator.destroy(profile);
    profile.* = .{};
    _ = try normal_pass(std.testing.io, allocator, input, expected);
    _ = try profile_pass(std.testing.io, allocator, input, expected, profile);
    // Byte comparisons inside both measured passes bind the reported SHA256
    // to their actual outputs. Also verify the configured trace directly.
    const traced = try br.benchmarkQualityProfileAlloc(allocator, input, std.testing.io, options, profile);
    defer allocator.free(traced);
    try std.testing.expectEqualSlices(u8, expected, traced);
    const expected_sha = provenance.sha256Hex(expected);
    const traced_sha = provenance.sha256Hex(traced);
    try std.testing.expectEqualSlices(u8, &expected_sha, &traced_sha);
    try std.testing.expect(profile.wire_attempt_coverage_complete);
    try std.testing.expect(profile.timing_complete);
    try std.testing.expect(!profile.events_truncated);
    // The eight-record context-detail prefix may truncate independently of
    // complete wire events. Wire-count-only validation labels that coverage.
    try std.testing.expectEqual(profile.event_count, profile.events_total);
    try std.testing.expectEqual(@as(?usize, expected.len), profile.returned_wire_bytes);
    for (profile.recordedEvents()) |event| {
        if (event.stage != .wire and event.stage != .evaluate) continue;
        try std.testing.expectEqual(options.window_bits.?, event.config.window_bits);
        try std.testing.expect(!event.config.large_window);
    }
}
