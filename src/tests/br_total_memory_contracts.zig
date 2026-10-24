const std = @import("std");
const br = @import("../br.zig");
const h = @import("br_total_memory_helpers.zig");

test {
    _ = h;
}

test "Brotli total memory null policy and profile preserve representative complete base wires" {
    const a = std.testing.allocator;
    const chunks = [_][]const u8{ h.plain[0..17], h.plain[17..57], h.plain[57..] };
    for (h.frozen_wires) |sample| {
        const expected = try h.frozenAlloc(a, sample);
        defer a.free(expected);
        for ([_]bool{ false, true }) |instrumented| {
            var profile: br.EncodeMemoryProfile = .{};
            var one_options = h.options(br.PlannedEncodeOptions, sample.setting);
            var stream_options = h.options(br.PlannedStreamChunksOptions, sample.setting);
            if (instrumented) {
                one_options.memory_profile = &profile;
                stream_options.memory_profile = &profile;
            }
            const actual = switch (sample.api) {
                .one_shot => try br.encodePlannedStreamWithOptionsAlloc(a, h.plain, one_options),
                .reusable => block: {
                    var encoder = br.PlannedStreamEncoder.init(a);
                    defer encoder.deinit();
                    break :block try encoder.encodeWithOptionsAlloc(a, h.plain, one_options);
                },
                .chunks => try br.encodePlannedStreamChunksWithOptionsAlloc(a, &chunks, stream_options),
                .incremental => block: {
                    var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(a, .{ .stream = stream_options, .block_len = 0 });
                    defer encoder.deinit();
                    break :block try h.drive(a, &encoder, h.plain, 31, 17);
                },
            };
            defer a.free(actual);
            try std.testing.expectEqualSlices(u8, expected, actual);
            if (instrumented) try std.testing.expect(profile.available);
        }
    }
}

test "Brotli total memory profile and exact cap match independent requested peak for every legacy quality and HQ" {
    for (h.settings) |setting| {
        errdefer std.debug.print("total-memory failed-setting={s}\n", .{@tagName(setting)});
        var tracked = h.TrackingAllocator.init(std.testing.allocator);
        tracked.force_moving_growth = true;
        const a = tracked.allocator();
        var profile: br.EncodeMemoryProfile = .{};
        var options = h.options(br.PlannedEncodeOptions, setting);
        options.memory_profile = &profile;
        const expected = try h.frozenAlloc(std.testing.allocator, h.frozenOne(setting));
        defer std.testing.allocator.free(expected);
        const peak = measured: {
            const baseline = try br.encodePlannedStreamWithOptionsAlloc(a, h.plain, options);
            defer a.free(baseline);
            try std.testing.expectEqualSlices(u8, expected, baseline);
            try std.testing.expect(profile.available);
            try std.testing.expectEqual(@as(?usize, null), profile.limit);
            try std.testing.expectEqual(tracked.peak, profile.peak_requested_bytes);
            try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
            try std.testing.expectEqual(baseline.len, tracked.live);
            break :measured tracked.peak;
        };
        try std.testing.expectEqual(@as(usize, 0), tracked.live);
        try std.testing.expect(peak > 0);

        profile.reset();
        tracked.beginMeasurement();
        options.max_total_working_memory = peak;
        {
            const exact = try br.encodePlannedStreamWithOptionsAlloc(a, h.plain, options);
            defer a.free(exact);
            try std.testing.expectEqualSlices(u8, expected, exact);
            try std.testing.expectEqual(peak, tracked.peak);
            try std.testing.expectEqual(tracked.peak, profile.peak_requested_bytes);
            try std.testing.expectEqual(@as(?usize, peak), profile.limit);
        }

        profile.reset();
        tracked.beginMeasurement();
        options.max_total_working_memory = peak - 1;
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, br.encodePlannedStreamWithOptionsAlloc(a, h.plain, options));
        try std.testing.expectEqual(@as(usize, 0), tracked.live);
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
        try std.testing.expect(tracked.peak <= peak - 1);
        try std.testing.expectEqual(tracked.peak, profile.peak_requested_bytes);
        try std.testing.expectEqual(tracked.allocated_bytes, tracked.freed_bytes);
        std.debug.print("total-memory setting={s} requested-peak={d} exact=pass below=WorkingMemoryLimitExceeded final-live=0\n", .{ @tagName(setting), peak });
    }
}

test "Brotli total memory zero rejects before backing allocation and empty operations expose real overhead" {
    for (h.settings) |setting| {
        errdefer std.debug.print("total-memory zero failed-setting={s}\n", .{@tagName(setting)});
        var tracked = h.TrackingAllocator.init(std.testing.allocator);
        tracked.fail_alloc_after = 0;
        var profile: br.EncodeMemoryProfile = .{};
        var options = h.options(br.PlannedEncodeOptions, setting);
        options.max_total_working_memory = 0;
        options.memory_profile = &profile;
        for ([_][]const u8{ h.plain, "" }) |input| {
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, br.encodePlannedStreamWithOptionsAlloc(tracked.allocator(), input, options));
            try std.testing.expectEqual(@as(usize, 0), tracked.alloc_attempts);
            try std.testing.expectEqual(@as(usize, 0), tracked.live);
            try std.testing.expect(profile.available);
            try std.testing.expectEqual(@as(?usize, 0), profile.limit);
            try std.testing.expectEqual(@as(usize, 0), profile.peak_requested_bytes);
        }
    }
    for ([_]h.Setting{ .fast, .q0, .q11, .hq11 }) |setting| {
        var tracked = h.TrackingAllocator.init(std.testing.allocator);
        var profile: br.EncodeMemoryProfile = .{};
        var options = h.options(br.PlannedEncodeOptions, setting);
        options.memory_profile = &profile;
        const encoded = try br.encodePlannedStreamWithOptionsAlloc(tracked.allocator(), "", options);
        defer tracked.allocator().free(encoded);
        try std.testing.expect(profile.peak_requested_bytes > 0);
        try std.testing.expectEqual(tracked.peak, profile.peak_requested_bytes);
        const decoded = try br.decodeStreamAlloc(std.testing.allocator, encoded);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqual(@as(usize, 0), decoded.len);
    }
}

test "Brotli total memory HQ workspace and total caps remain independent and dual profiling preserves wire" {
    var tracked = h.TrackingAllocator.init(std.testing.allocator);
    tracked.force_moving_growth = true;
    const a = tracked.allocator();
    var total: br.EncodeMemoryProfile = .{};
    var workspace: br.HqProfile = .{};
    var options: br.PlannedEncodeOptions = .{ .quality = 11, .hq = .{ .profile = &workspace }, .memory_profile = &total };
    const bytes = try br.encodePlannedStreamWithOptionsAlloc(a, h.plain, options);
    const expected = try std.testing.allocator.dupe(u8, bytes);
    defer std.testing.allocator.free(expected);
    const total_peak = tracked.peak;
    const workspace_peak = workspace.peak_working_memory;
    try std.testing.expectEqual(total_peak, total.peak_requested_bytes);
    try std.testing.expect(total_peak > workspace_peak and workspace_peak > 0);
    a.free(bytes);
    total.reset();
    workspace.reset();
    tracked.beginMeasurement();
    options.max_total_working_memory = total_peak;
    options.hq.?.max_working_memory = workspace_peak;
    const exact = try br.encodePlannedStreamWithOptionsAlloc(a, h.plain, options);
    try std.testing.expectEqualSlices(u8, expected, exact);
    try std.testing.expectEqual(tracked.peak, total.peak_requested_bytes);
    a.free(exact);
    options.max_total_working_memory = null;
    options.hq.?.max_working_memory = 0;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, br.encodePlannedStreamWithOptionsAlloc(a, h.plain, options));
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
    options.max_total_working_memory = 0;
    options.hq.?.max_working_memory = std.math.maxInt(usize);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, br.encodePlannedStreamWithOptionsAlloc(a, h.plain, options));
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
}

test "Brotli total memory incremental plain pending history and HQ full candidates share one measured cap" {
    for ([_]h.Setting{ .fast, .q0, .q11, .hq11 }) |setting| {
        var tracked = h.TrackingAllocator.init(std.testing.allocator);
        tracked.force_moving_growth = true;
        var profile: br.EncodeMemoryProfile = .{};
        var stream_options = h.options(br.PlannedStreamChunksOptions, setting);
        stream_options.block_len = 32;
        stream_options.memory_profile = &profile;
        var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(tracked.allocator(), .{ .stream = stream_options, .block_len = 0 });
        const expected = try h.drive(std.testing.allocator, &encoder, h.plain, 1, 1);
        defer std.testing.allocator.free(expected);
        try std.testing.expect(profile.available);
        try std.testing.expectEqual(tracked.peak, profile.peak_requested_bytes);
        try std.testing.expectEqual(tracked.live, profile.live_requested_bytes);
        const peak = tracked.peak;
        encoder.deinit();
        try std.testing.expectEqual(@as(usize, 0), tracked.live);
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
        profile.reset();
        tracked.beginMeasurement();
        stream_options.max_total_working_memory = peak;
        var exact_encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(tracked.allocator(), .{ .stream = stream_options, .block_len = 0 });
        const exact = try h.drive(std.testing.allocator, &exact_encoder, h.plain, 1, 1);
        defer std.testing.allocator.free(exact);
        try std.testing.expectEqualSlices(u8, expected, exact);
        try std.testing.expectEqual(peak, tracked.peak);
        try std.testing.expectEqual(tracked.peak, profile.peak_requested_bytes);
        exact_encoder.deinit();
        try std.testing.expectEqual(@as(usize, 0), tracked.live);
    }
}

test "Brotli total memory real in place allocator growth and remap preserve independently measured profile" {
    const storage = try std.testing.allocator.alloc(u8, 2 * 1024 * 1024);
    defer std.testing.allocator.free(storage);
    var observed_resize_or_remap = false;
    for ([_]h.Setting{ .fast, .q0 }) |setting| {
        errdefer std.debug.print("total-memory in-place failed-setting={s}\n", .{@tagName(setting)});
        var fixed = std.heap.FixedBufferAllocator.init(storage);
        var tracked = h.TrackingAllocator.init(fixed.allocator());
        const a = tracked.allocator();
        var profile: br.EncodeMemoryProfile = .{};
        var options = h.options(br.PlannedEncodeOptions, setting);
        options.memory_profile = &profile;
        const bytes = try br.encodePlannedStreamWithOptionsAlloc(a, h.plain, options);
        const expected = try h.frozenAlloc(std.testing.allocator, h.frozenOne(setting));
        defer std.testing.allocator.free(expected);
        try std.testing.expectEqualSlices(u8, expected, bytes);
        try std.testing.expectEqual(tracked.peak, profile.peak_requested_bytes);
        observed_resize_or_remap = observed_resize_or_remap or tracked.successful_resizes + tracked.successful_remaps > 0;
        a.free(bytes);
        try std.testing.expectEqual(@as(usize, 0), tracked.live);
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
        try std.testing.expectEqual(tracked.allocated_bytes, tracked.freed_bytes);
    }
    try std.testing.expect(observed_resize_or_remap);
}
