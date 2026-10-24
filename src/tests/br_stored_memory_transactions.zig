const std = @import("std");
const br = @import("../br.zig");
const h = @import("br_stored_memory_helpers.zig");

test "Brotli stored memory reusable adoption charges full retained capacity exactly once across calls" {
    var tracked = h.TrackingAllocator.init(std.testing.allocator);
    const a = tracked.allocator();
    var encoder = br.StoredStreamEncoder.init(a);
    _ = try encoder.encodeScratch(h.plain);
    const capacity = encoder.scratch.capacity;
    const attempts = tracked.alloc_attempts;
    tracked.beginMeasurement();
    var profile: br.EncodeMemoryProfile = .{};
    const options: br.StoredStreamOptions = .{ .max_total_working_memory = capacity + h.total.control_bytes, .memory_profile = &profile };
    _ = try encoder.encodeScratchWithOptions("tiny", options);
    try h.expectProfile(profile, &tracked, tracked.live);
    try std.testing.expectEqual(capacity + h.total.control_bytes, tracked.live);
    try std.testing.expectEqual(attempts + 1, tracked.alloc_attempts);
    _ = try encoder.encodeScratchWithOptions("", options);
    try std.testing.expectEqual(capacity, encoder.scratch.capacity);
    try std.testing.expectEqual(attempts + 1, tracked.alloc_attempts);
    try std.testing.expectEqual(capacity + h.total.control_bytes, tracked.live);
    try std.testing.expectEqual(tracked.live, encoder.memorySnapshot().live_requested_bytes);
    try std.testing.expectEqual(tracked.live, encoder.retainedCapacity());
    const owned_len = try br.encodedStoredStreamBoundWithOptions(h.plain.len, .{});
    const retained = tracked.live;
    tracked.beginMeasurement();
    profile.reset();
    const owned = try encoder.encodeWithOptionsAlloc(h.plain, .{ .max_total_working_memory = retained + owned_len, .memory_profile = &profile });
    try std.testing.expectEqual(retained + owned_len, tracked.peak);
    try h.expectProfile(profile, &tracked, retained);
    try h.decode(owned, h.plain, false);
    a.free(owned);
    try std.testing.expectEqual(retained, tracked.live);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.encodeWithOptionsAlloc(h.plain, .{ .max_total_working_memory = retained + owned_len - 1, .memory_profile = &profile }));
    try std.testing.expectEqual(retained, tracked.live);
    encoder.deinit();
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
    // A reusable call detaches the borrowed profile before returning.
    try std.testing.expectEqual(capacity + h.total.control_bytes, profile.live_requested_bytes);
}

test "Brotli stored memory reusable failed activation preserves bytes capacity and original ownership" {
    for ([_]bool{ false, true }) |oom| {
        var tracked = h.TrackingAllocator.init(std.testing.allocator);
        const a = tracked.allocator();
        var encoder = br.StoredStreamEncoder.init(a);
        const old = try std.testing.allocator.dupe(u8, try encoder.encodeScratch(h.plain));
        defer std.testing.allocator.free(old);
        const capacity = encoder.scratch.capacity;
        const pointer = encoder.scratch.items.ptr;
        const attempts = tracked.alloc_attempts;
        if (oom) tracked.fail_alloc_after = attempts;
        var profile: br.EncodeMemoryProfile = .{};
        const options: br.StoredStreamOptions = .{ .max_total_working_memory = if (oom) null else capacity + h.total.control_bytes - 1, .memory_profile = &profile };
        const operation = encoder.encodeScratchWithOptions("replacement", options);
        if (oom) try std.testing.expectError(error.OutOfMemory, operation) else try std.testing.expectError(error.WorkingMemoryLimitExceeded, operation);
        try std.testing.expectEqual(pointer, encoder.scratch.items.ptr);
        try std.testing.expectEqual(capacity, encoder.scratch.capacity);
        try std.testing.expectEqualSlices(u8, old, encoder.scratch.items);
        try std.testing.expectEqual(capacity, tracked.live);
        if (!oom) try std.testing.expectEqual(attempts, tracked.alloc_attempts);
        tracked.clearFailures();
        const recovered = try encoder.encodeScratchWithOptions("recovered", .{ .memory_profile = &profile });
        try h.decode(recovered, "recovered", false);
        encoder.deinit();
        try std.testing.expectEqual(@as(usize, 0), tracked.live);
        try std.testing.expectEqual(tracked.allocated_bytes, tracked.freed_bytes);
    }
}

test "Brotli stored memory reusable moving growth charges old new capacities and refuses transactionally" {
    var peak: usize = 0;
    var larger: [2048]u8 = undefined;
    for (&larger, 0..) |*b, i| b.* = @truncate(i *% 29);
    for ([_]?usize{ null, 0, 1 }) |delta| {
        var tracked = h.TrackingAllocator.init(std.testing.allocator);
        tracked.force_moving_growth = true;
        const a = tracked.allocator();
        var encoder = br.StoredStreamEncoder.init(a);
        const old = try std.testing.allocator.dupe(u8, try encoder.encodeScratch("tiny"));
        defer std.testing.allocator.free(old);
        const capacity = encoder.scratch.capacity;
        const pointer = encoder.scratch.items.ptr;
        tracked.beginMeasurement();
        var profile: br.EncodeMemoryProfile = .{};
        const options: br.StoredStreamOptions = .{ .memory_profile = &profile, .max_total_working_memory = if (delta) |n| peak - n else null };
        if (delta == 1) {
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.encodeScratchWithOptions(&larger, options));
            try std.testing.expectEqual(pointer, encoder.scratch.items.ptr);
            try std.testing.expectEqual(capacity, encoder.scratch.capacity);
            try std.testing.expectEqualSlices(u8, old, encoder.scratch.items);
            try std.testing.expectEqual(capacity, tracked.live);
        } else {
            const actual = try encoder.encodeScratchWithOptions(&larger, options);
            try h.decode(actual, &larger, false);
            try std.testing.expect(pointer != encoder.scratch.items.ptr);
            try std.testing.expectEqual(tracked.peak, profile.peak_requested_bytes);
            try std.testing.expect(profile.peak_requested_bytes >= h.total.control_bytes + capacity + encoder.scratch.capacity);
            if (delta == null) peak = tracked.peak else try std.testing.expectEqual(peak, tracked.peak);
        }
        encoder.deinit();
        try std.testing.expectEqual(@as(usize, 0), tracked.live);
    }
}

test "Brotli stored memory reusable lease survives moves and call profile storage detaches" {
    var tracked = h.TrackingAllocator.init(std.testing.allocator);
    const a = tracked.allocator();
    var encoder = br.StoredStreamEncoder.init(a);
    var profile: br.EncodeMemoryProfile = .{};
    _ = try encoder.encodeScratchWithOptions(h.plain, .{ .memory_profile = &profile });
    const saved = profile;
    var moved = encoder;
    encoder = undefined;
    _ = try moved.encodeScratchWithOptions("next", .{});
    try std.testing.expectEqualDeep(saved, profile);
    var second: br.EncodeMemoryProfile = .{};
    _ = try moved.encodeScratchWithOptions("third", .{ .memory_profile = &second });
    try std.testing.expectEqual(tracked.live, second.live_requested_bytes);
    const saved_second = second;
    moved.deinit();
    try std.testing.expectEqualDeep(saved, profile);
    try std.testing.expectEqualDeep(saved_second, second);
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
}

test "Brotli stored memory reusable aliased scratch Into snapshots input chunks and metadata before overwrite" {
    var peak: usize = 0;
    for ([_]?usize{ null, 0, 1 }) |delta| {
        var tracked = h.TrackingAllocator.init(std.testing.allocator);
        const a = tracked.allocator();
        var encoder = br.StoredStreamEncoder.init(a);
        try encoder.scratch.ensureTotalCapacity(a, 1024);
        try encoder.scratch.resize(a, 512);
        @memset(encoder.scratch.items, 0xa5);
        @memcpy(encoder.scratch.items[128..][0..h.plain.len], h.plain);
        @memcpy(encoder.scratch.items[300..][0..h.metadata.len], h.metadata);
        const descriptors: *[4][]const u8 = @ptrCast(@alignCast(encoder.scratch.items.ptr));
        descriptors.* = .{ encoder.scratch.items[128..145], "", encoder.scratch.items[145..185], encoder.scratch.items[185..][0 .. h.plain.len - 57] };
        const before = try std.testing.allocator.dupe(u8, encoder.scratch.items);
        defer std.testing.allocator.free(before);
        tracked.beginMeasurement();
        var profile: br.EncodeMemoryProfile = .{};
        const options: br.StoredStreamOptions = .{ .metadata = encoder.scratch.items[300..][0..h.metadata.len], .memory_profile = &profile, .max_total_working_memory = if (delta) |n| peak - n else null };
        if (delta == 1) {
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.encodeChunksWithOptionsIntoSlice(descriptors, options, encoder.scratch.items));
            try std.testing.expectEqualSlices(u8, before, encoder.scratch.items);
        } else {
            const len = try encoder.encodeChunksWithOptionsIntoSlice(descriptors, options, encoder.scratch.items);
            try h.expectWire(encoder.scratch.items[0..len], .standard16, .chunks);
            try std.testing.expectEqualSlices(u8, before[len..], encoder.scratch.items[len..]);
            try std.testing.expectEqual(tracked.peak, profile.peak_requested_bytes);
            if (delta == null) peak = tracked.peak else try std.testing.expectEqual(peak, tracked.peak);
        }
        encoder.deinit();
        try std.testing.expectEqual(@as(usize, 0), tracked.live);
    }
}

test "Brotli stored memory incremental exact quota matches independent retained IO and one shared control" {
    for ([_]usize{ 16, 128 }) |block_len| {
        var peak: usize = 0;
        for ([_]?usize{ null, 0, 1 }) |delta| {
            var tracked = h.TrackingAllocator.init(std.testing.allocator);
            tracked.force_moving_growth = true;
            var profile: br.EncodeMemoryProfile = .{};
            var encoder = br.IncrementalStoredStreamEncoder.initWithOptions(tracked.allocator(), .{ .block_len = block_len, .stream = .{ .metadata = h.metadata, .memory_profile = &profile, .max_total_working_memory = if (delta) |n| peak - n else null } });
            const operation = h.drive(std.testing.allocator, &encoder, h.plain, 7, 3);
            if (delta == 1) {
                try std.testing.expectError(error.WorkingMemoryLimitExceeded, operation);
                try std.testing.expect(tracked.peak <= peak - 1);
                try std.testing.expect(encoder.memorySnapshot().hit_limit);
            } else {
                const actual = try operation;
                defer std.testing.allocator.free(actual);
                try h.decode(actual, h.plain, false);
                const snapshot = encoder.memorySnapshot();
                try std.testing.expectEqual(tracked.live, snapshot.live_requested_bytes);
                try std.testing.expectEqual(tracked.peak, snapshot.peak_requested_bytes);
                try std.testing.expectEqual(h.total.control_bytes + encoder.plain.capacity + encoder.pending.capacity, tracked.live);
                try std.testing.expectEqual(tracked.live, encoder.retainedCapacity());
                try std.testing.expectEqual(snapshot.control_bytes, h.total.control_bytes);
                if (delta == null) peak = tracked.peak else try std.testing.expectEqual(peak, tracked.peak);
            }
            encoder.deinit();
            try std.testing.expectEqual(@as(usize, 0), tracked.live);
            try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
            try std.testing.expectEqual(tracked.allocated_bytes, tracked.freed_bytes);
        }
    }
}

test "Brotli stored memory incremental reset nextStream and move preserve persistent quota and full capacities" {
    var tracked = h.TrackingAllocator.init(std.testing.allocator);
    var profile: br.EncodeMemoryProfile = .{};
    const options: br.IncrementalStoredStreamEncoder.Options = .{ .block_len = 32, .stream = .{ .max_total_working_memory = 4096, .memory_profile = &profile } };
    var encoder = br.IncrementalStoredStreamEncoder.initWithOptions(tracked.allocator(), options);
    const first = try h.drive(std.testing.allocator, &encoder, h.plain, 7, 3);
    defer std.testing.allocator.free(first);
    const retained = tracked.live;
    const attempts = tracked.alloc_attempts;
    const before = encoder.snapshot();
    var low = options;
    low.stream.max_total_working_memory = retained - 1;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.nextStream(low));
    try std.testing.expectEqualDeep(before, encoder.snapshot());
    try std.testing.expectEqual(@as(?usize, 4096), encoder.memorySnapshot().limit);
    try encoder.nextStream(options);
    try std.testing.expectEqual(before.input_read, encoder.snapshot().input_read);
    try std.testing.expectEqual(@as(br.IncrementalStoredStreamEncoder.Counter, 0), encoder.snapshot().stream_input);
    const second = try h.drive(std.testing.allocator, &encoder, "tiny", 2, 1);
    defer std.testing.allocator.free(second);
    try h.decode(second, "tiny", false);
    try std.testing.expectEqual(attempts, tracked.alloc_attempts);
    try std.testing.expectEqual(retained, tracked.live);
    encoder.reset();
    try std.testing.expectEqual(@as(br.IncrementalStoredStreamEncoder.Counter, 0), encoder.snapshot().input_read);
    try std.testing.expectEqual(@as(?usize, 4096), encoder.memorySnapshot().limit);
    try std.testing.expectEqual(retained, encoder.memorySnapshot().live_requested_bytes);
    var moved = encoder;
    encoder = undefined;
    const third = try h.drive(std.testing.allocator, &moved, "reset", 2, 1);
    defer std.testing.allocator.free(third);
    try h.decode(third, "reset", false);
    try std.testing.expectEqual(attempts, tracked.alloc_attempts);
    moved.deinit();
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
}

test "Brotli stored memory incremental borrowed metadata flush and bounded output share the retained ledger" {
    var tracked = h.TrackingAllocator.init(std.testing.allocator);
    var profile: br.EncodeMemoryProfile = .{};
    var encoder = br.IncrementalStoredStreamEncoder.initWithOptions(tracked.allocator(), .{ .block_len = 32, .stream = .{ .memory_profile = &profile, .large_window = true, .window_bits = 25 } });
    var collected: std.ArrayList(u8) = .empty;
    defer collected.deinit(std.testing.allocator);
    var output: [17]u8 = undefined;
    const initial = try encoder.step("alpha", &output);
    try std.testing.expectEqual(@as(usize, 5), initial.progress.input_read);
    try collected.appendSlice(std.testing.allocator, output[0..initial.progress.output_written]);
    try encoder.writeMetadata(h.metadata);
    try std.testing.expect(encoder.snapshot().metadata_pending);
    try std.testing.expectEqual(h.metadata.len, encoder.snapshot().metadata_bytes);
    try h.drainFlush(std.testing.allocator, &encoder, &collected);
    try std.testing.expect(!encoder.snapshot().metadata_pending);
    const second = try encoder.step("beta", &output);
    try std.testing.expectEqual(@as(usize, 4), second.progress.input_read);
    try collected.appendSlice(std.testing.allocator, output[0..second.progress.output_written]);
    encoder.flush();
    try h.drainFlush(std.testing.allocator, &encoder, &collected);
    const rest = try h.drive(std.testing.allocator, &encoder, "alphabeta", 3, 2);
    defer std.testing.allocator.free(rest);
    try collected.appendSlice(std.testing.allocator, rest);
    try h.decode(collected.items, "alphabeta", true);
    try std.testing.expectEqual(h.total.control_bytes + encoder.plain.capacity + encoder.pending.capacity, tracked.live);
    try h.expectProfile(profile, &tracked, tracked.live);
    encoder.deinit();
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
}

test "Brotli stored memory incremental quota zero and invalid policy fail before accepting input or output" {
    var tracked = h.TrackingAllocator.init(std.testing.allocator);
    tracked.fail_alloc_after = 0;
    var profile: br.EncodeMemoryProfile = .{};
    var encoder = br.IncrementalStoredStreamEncoder.initWithOptions(tracked.allocator(), .{ .stream = .{ .max_total_working_memory = 0, .memory_profile = &profile } });
    var output: [32]u8 = @splat(0xa5);
    const before = encoder.snapshot();
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.step(h.plain, &output));
    try std.testing.expectEqualDeep(before, encoder.snapshot());
    try h.untouched(&output);
    try std.testing.expectEqual(@as(usize, 0), tracked.alloc_attempts);
    encoder.deinit();
    var invalid = br.IncrementalStoredStreamEncoder.initWithOptions(tracked.allocator(), .{ .stream = .{ .window_bits = 9, .max_total_working_memory = 0 } });
    try std.testing.expectError(error.InvalidBlockPlan, invalid.step(h.plain, &output));
    try std.testing.expectEqual(@as(usize, 0), tracked.alloc_attempts);
    try h.untouched(&output);
    invalid.deinit();
}

test "Brotli stored memory incremental late quota refusal and OOM keep accepted progress and retry without duplicate blocks" {
    for ([_]bool{ false, true }) |quota| {
        var tracked = h.TrackingAllocator.init(std.testing.allocator);
        tracked.force_moving_growth = true;
        var profile: br.EncodeMemoryProfile = .{};
        var encoder = br.IncrementalStoredStreamEncoder.initWithOptions(tracked.allocator(), .{ .block_len = 256, .stream = .{ .memory_profile = &profile } });
        errdefer encoder.deinit();
        // Adopt ordinary capacity so source can be accepted before pending wire
        // growth fails. Failed step counters include these accepted bytes.
        try encoder.plain.ensureTotalCapacityPrecise(tracked.allocator(), 256);
        var input: [256]u8 = undefined;
        for (&input, 0..) |*b, i| b.* = @truncate(i *% 37);
        const first = try encoder.step(input[0..7], &.{});
        try std.testing.expectEqual(@as(usize, 7), first.progress.input_read);
        const before = encoder.snapshot();
        if (quota) encoder.options.stream.max_total_working_memory = tracked.live else tracked.fail_alloc_after = tracked.alloc_attempts;
        var output: [3]u8 = @splat(0xa5);
        const operation = encoder.step(input[7..], &output);
        if (quota) try std.testing.expectError(error.WorkingMemoryLimitExceeded, operation) else try std.testing.expectError(error.OutOfMemory, operation);
        const after = encoder.snapshot();
        const accepted: usize = @intCast(after.stream_input - before.stream_input);
        const copied: usize = @intCast(after.stream_output - before.stream_output);
        try std.testing.expectEqual(@as(usize, 249), accepted);
        try std.testing.expect(copied <= output.len);
        try h.untouched(output[copied..]);
        try std.testing.expectEqual(@as(usize, 256), after.buffered_input);
        try std.testing.expectEqual(quota, encoder.memorySnapshot().last_failure_was_limit);
        tracked.clearFailures();
        encoder.options.stream.max_total_working_memory = null;
        var collected: std.ArrayList(u8) = .empty;
        defer collected.deinit(std.testing.allocator);
        try collected.appendSlice(std.testing.allocator, output[0..copied]);
        const rest = try h.drive(std.testing.allocator, &encoder, &input, 3, 2);
        defer std.testing.allocator.free(rest);
        try collected.appendSlice(std.testing.allocator, rest);
        try h.decode(collected.items, &input, false);
        try h.expectProfile(profile, &tracked, tracked.live);
        encoder.deinit();
        try std.testing.expectEqual(@as(usize, 0), tracked.live);
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    }
}
