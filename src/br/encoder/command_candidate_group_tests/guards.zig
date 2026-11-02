//! Public support boundaries and shared-budget ownership. The root injects
//! actual codec entry points; no encoder internals or ignored data are read.
const std = @import("std");

/// Same 128-byte row, eight mutation columns and seeds as public q8 records.
/// Partial final rows keep tiny and the 65,537-byte upper-bound control safe.
fn fillRecords(input: []u8) void {
    var row: [128]u8 = undefined;
    var row_state: u32 = 0x243f_6a88;
    for (&row, 0..) |*byte, index| {
        row_state = row_state *% 1_664_525 +% 1_013_904_223;
        byte.* = if (index + 1 == row.len) '\n' else 32 + @as(u8, @truncate((row_state >> 16) % 95));
    }
    var mutation_state: u32 = 0x9e37_79b9;
    var position: usize = 0;
    while (position < input.len) {
        const count = @min(row.len, input.len - position);
        @memcpy(input[position..][0..count], row[0..count]);
        for (0..8) |mutation| {
            mutation_state = mutation_state *% 1_664_525 +% 1_013_904_223;
            const column = (mutation * 11 + 4) % (row.len - 1);
            if (column < count) input[position + column] = 32 + @as(u8, @truncate((mutation_state >> 16) % 95));
        }
        position += count;
    }
}

fn compare(comptime Codec: type, input: []const u8, options: Codec.Options, require_unsupported: bool) !void {
    const saved = try std.testing.allocator.dupe(u8, input);
    defer std.testing.allocator.free(saved);
    const original = try Codec.encodeOptions(std.testing.allocator, input, true, options);
    defer std.testing.allocator.free(original);
    try std.testing.expectEqual(@as(usize, 0), Codec.counts().groups);
    const current = try Codec.encodeOptions(std.testing.allocator, input, false, options);
    defer std.testing.allocator.free(current);
    const counts = Codec.counts();
    if (require_unsupported) {
        try std.testing.expectEqual(@as(usize, 0), counts.groups);
        try std.testing.expectEqual(@as(usize, 0), counts.literal_models);
        try std.testing.expectEqual(@as(usize, 0), counts.distance_models);
    }
    try std.testing.expectEqualSlices(u8, original, current);
    const summary = try Codec.summarize(std.testing.allocator, current);
    try std.testing.expectEqualDeep(try Codec.summarize(std.testing.allocator, original), summary);
    const decoded = try Codec.decode(std.testing.allocator, current, input.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
    try std.testing.expectEqualSlices(u8, saved, input);
    if (!require_unsupported) {
        // Random data is not an admission oracle. Only an observed no-copy
        // output establishes this control's absence of recent-distance work.
        if (summary.lz77_copy_count == 0) {
            try std.testing.expectEqual(@as(usize, 0), counts.literal_models);
            try std.testing.expectEqual(@as(usize, 0), counts.distance_models);
        }
        std.debug.print("command_group random bytes={d} groups={d} lz_copies={d} literal_models={d} distance_models={d}\n", .{
            input.len, counts.groups, summary.lz77_copy_count, counts.literal_models, counts.distance_models,
        });
    }
}

fn supportGuards(comptime Codec: type) !void {
    for ([_]usize{ 0, 1, 17, 4096, 65537 }) |length| {
        const input = try std.testing.allocator.alloc(u8, length);
        defer std.testing.allocator.free(input);
        fillRecords(input);
        try compare(Codec, input, .{ .quality = 8, .window_bits = 16 }, true);
    }
    var input: [8192]u8 = undefined;
    fillRecords(&input);
    try compare(Codec, &input, .{ .quality = 8, .window_bits = 16, .metadata = "borrowed metadata guard" }, true);
    try compare(Codec, &input, .{ .quality = 8, .window_bits = 16, .large_window = true }, true);
    for ([_]u4{ 0, 1, 4 }) |quality| try compare(Codec, &input, .{ .quality = quality, .window_bits = 16 }, true);
    try compare(Codec, &input, .{ .level = .fast, .window_bits = 16 }, true);
    var random = std.Random.DefaultPrng.init(0x6367_7261_6e64_0101);
    random.random().bytes(&input);
    try compare(Codec, &input, .{ .quality = 8, .window_bits = 16 }, false);
}

fn memoryGuard(comptime Codec: type) !void {
    var input: [8192]u8 = undefined;
    fillRecords(&input);
    const before = input;
    var original_profile: Codec.Profile = .{};
    var current_profile: Codec.Profile = .{};
    const original = try Codec.encodeOptions(std.testing.allocator, &input, true, .{
        .quality = 8,
        .window_bits = 16,
        .memory_profile = &original_profile,
    });
    defer std.testing.allocator.free(original);
    try std.testing.expectEqual(@as(usize, 0), Codec.counts().groups);
    const current = try Codec.encodeOptions(std.testing.allocator, &input, false, .{
        .quality = 8,
        .window_bits = 16,
        .memory_profile = &current_profile,
    });
    defer std.testing.allocator.free(current);
    const counts = Codec.counts();
    try std.testing.expect(counts.groups != 0);
    try std.testing.expectEqualSlices(u8, original, current);
    try std.testing.expect(original_profile.available and current_profile.available);
    try std.testing.expectEqual(@as(usize, 0), original_profile.live_requested_bytes);
    try std.testing.expectEqual(@as(usize, 0), current_profile.live_requested_bytes);
    try std.testing.expect(original_profile.limit == null and current_profile.limit == null);
    const peak = current_profile.peak_requested_bytes;
    try std.testing.expect(peak != 0);
    // Ownership can legitimately change a peak. Report both actual snapshots
    // for audit; do not invent equivalence or a guessed budget from formulas.
    std.debug.print("command_group memory bytes={d} groups={d} original_peak={d} current_peak={d} equal={}\n", .{
        input.len, counts.groups, original_profile.peak_requested_bytes, peak, original_profile.peak_requested_bytes == peak,
    });

    var exact_profile: Codec.Profile = .{};
    const exact = try Codec.encodeOptions(std.testing.allocator, &input, false, .{
        .quality = 8,
        .window_bits = 16,
        .memory_profile = &exact_profile,
        .max_total_working_memory = peak,
    });
    defer std.testing.allocator.free(exact);
    try std.testing.expectEqualSlices(u8, current, exact);
    try std.testing.expectEqual(@as(?usize, peak), exact_profile.limit);
    try std.testing.expectEqual(peak, exact_profile.peak_requested_bytes);
    try std.testing.expectEqual(@as(usize, 0), exact_profile.live_requested_bytes);
    try std.testing.expect(Codec.counts().groups != 0);

    var tight_profile: Codec.Profile = .{};
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, Codec.encodeOptions(std.testing.allocator, &input, false, .{
        .quality = 8,
        .window_bits = 16,
        .memory_profile = &tight_profile,
        .max_total_working_memory = peak - 1,
    }));
    try std.testing.expect(tight_profile.available);
    try std.testing.expectEqual(@as(?usize, peak - 1), tight_profile.limit);
    try std.testing.expect(tight_profile.peak_requested_bytes <= peak - 1);
    try std.testing.expectEqual(@as(usize, 0), tight_profile.live_requested_bytes);
    try std.testing.expectEqualSlices(u8, &before, &input);
    try std.testing.expectEqualDeep(try Codec.summarize(std.testing.allocator, current), try Codec.summarize(std.testing.allocator, exact));
    const decoded = try Codec.decode(std.testing.allocator, exact, input.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
}

pub fn check(comptime Codec: type) !void {
    try supportGuards(Codec);
    try memoryGuard(Codec);
}
