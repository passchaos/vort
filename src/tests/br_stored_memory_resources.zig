const std = @import("std");
const br = @import("../br.zig");
const h = @import("br_stored_memory_helpers.zig");

test "Brotli stored memory owned contiguous and chunks exact quota equals independent requested peak" {
    const chunks = h.chunks();
    for ([_]bool{ false, true }) |chunked| {
        var peak: usize = 0;
        for ([_]?usize{ null, 0, 1 }) |delta| {
            var tracked = h.TrackingAllocator.init(std.testing.allocator);
            tracked.force_moving_growth = true;
            const a = tracked.allocator();
            var profile: br.EncodeMemoryProfile = .{};
            var options = h.options(.large30);
            options.memory_profile = &profile;
            options.max_total_working_memory = if (delta) |n| peak - n else null;
            if (delta == 1) {
                const operation = if (chunked) br.encodeStoredStreamChunksWithOptionsAlloc(a, &chunks, options) else br.encodeStoredStreamWithOptionsAlloc(a, h.plain, options);
                try std.testing.expectError(error.WorkingMemoryLimitExceeded, operation);
                try std.testing.expect(tracked.peak <= peak - 1);
                try std.testing.expectEqual(@as(usize, 0), tracked.live);
            } else {
                const actual = if (chunked) try br.encodeStoredStreamChunksWithOptionsAlloc(a, &chunks, options) else try br.encodeStoredStreamWithOptionsAlloc(a, h.plain, options);
                try h.expectWire(actual, .large30, if (chunked) .chunks else .contiguous);
                try h.expectProfile(profile, &tracked, 0);
                try std.testing.expectEqual(actual.len, tracked.live);
                if (delta == null) peak = tracked.peak else try std.testing.expectEqual(peak, tracked.peak);
                a.free(actual);
            }
            try h.expectProfile(profile, &tracked, 0);
            try std.testing.expectEqual(@as(usize, 0), tracked.live);
            try std.testing.expectEqual(tracked.allocated_bytes, tracked.freed_bytes);
        }
    }
}

test "Brotli stored memory owned zero quota and backing OOM remain distinct and leak free" {
    const chunks = h.chunks();
    for ([_]bool{ false, true }) |chunked| {
        for ([_][]const u8{ "", h.plain }) |input| {
            var tracked = h.TrackingAllocator.init(std.testing.allocator);
            tracked.fail_alloc_after = 0;
            var profile: br.EncodeMemoryProfile = .{};
            const options: br.StoredStreamOptions = .{ .max_total_working_memory = 0, .memory_profile = &profile };
            const zero = if (chunked) br.encodeStoredStreamChunksWithOptionsAlloc(tracked.allocator(), &.{input}, options) else br.encodeStoredStreamWithOptionsAlloc(tracked.allocator(), input, options);
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, zero);
            try std.testing.expectEqual(@as(usize, 0), tracked.alloc_attempts);
            try h.expectProfile(profile, &tracked, 0);
        }
        // The successful call tells QA which actual requests exist. Replay
        // each stored request once, preserving backing OOM classification.
        var baseline = h.TrackingAllocator.init(std.testing.allocator);
        var profile: br.EncodeMemoryProfile = .{};
        const options: br.StoredStreamOptions = .{ .memory_profile = &profile };
        const actual = if (chunked) try br.encodeStoredStreamChunksWithOptionsAlloc(baseline.allocator(), &chunks, options) else try br.encodeStoredStreamWithOptionsAlloc(baseline.allocator(), h.plain, options);
        baseline.allocator().free(actual);
        try std.testing.expect(baseline.alloc_attempts <= 8);
        for (0..baseline.alloc_attempts) |failure| {
            var tracked = h.TrackingAllocator.init(std.testing.allocator);
            tracked.fail_alloc_after = failure;
            profile.reset();
            const operation = if (chunked) br.encodeStoredStreamChunksWithOptionsAlloc(tracked.allocator(), &chunks, options) else br.encodeStoredStreamWithOptionsAlloc(tracked.allocator(), h.plain, options);
            try std.testing.expectError(error.OutOfMemory, operation);
            try std.testing.expectEqual(@as(usize, 0), tracked.live);
            try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
            try std.testing.expectEqual(tracked.allocated_bytes, tracked.freed_bytes);
        }
    }
}

test "Brotli stored memory spare caller append capacity is borrowed and nonalias cap zero succeeds" {
    var tracked = h.TrackingAllocator.init(std.testing.allocator);
    const a = tracked.allocator();
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(a);
    try output.ensureTotalCapacity(a, 1024);
    try output.appendSlice(a, "prefix|");
    tracked.excludeInitialAllocation(output.allocatedSlice());
    const attempts = tracked.alloc_attempts;
    tracked.fail_alloc_after = attempts;
    var profile: br.EncodeMemoryProfile = .{};
    var options = h.options(.standard10);
    options.max_total_working_memory = 0;
    options.memory_profile = &profile;
    try br.encodeStoredStreamWithOptionsAppend(a, &output, h.plain, options);
    try std.testing.expectEqualSlices(u8, "prefix|", output.items[0..7]);
    try h.expectWire(output.items[7..], .standard10, .contiguous);
    try std.testing.expectEqual(attempts, tracked.alloc_attempts);
    try std.testing.expectEqual(@as(usize, 0), profile.peak_requested_bytes);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    try std.testing.expect(profile.available);
    output.shrinkRetainingCapacity(7);
    var fresh = br.StoredStreamEncoder.init(a);
    defer fresh.deinit();
    const chunks = h.chunks();
    profile.reset();
    try fresh.encodeChunksWithOptionsAppend(&output, &chunks, options);
    try std.testing.expectEqualSlices(u8, "prefix|", output.items[0..7]);
    try h.expectWire(output.items[7..], .standard10, .chunks);
    try std.testing.expectEqual(attempts, tracked.alloc_attempts);
    try std.testing.expect(profile.available);
    try std.testing.expectEqual(@as(usize, 0), profile.peak_requested_bytes);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
}

test "Brotli stored memory append moving replacement remains charged until handoff and below cap is atomic" {
    var peak: usize = 0;
    const chunks = h.chunks();
    for ([_]?usize{ null, 0, 1 }) |delta| {
        var tracked = h.TrackingAllocator.init(std.testing.allocator);
        tracked.force_moving_growth = true;
        const a = tracked.allocator();
        var output = std.ArrayList(u8).fromOwnedSlice(try a.dupe(u8, "prefix|"));
        defer output.deinit(a);
        tracked.excludeInitialAllocation(output.allocatedSlice());
        tracked.beginMeasurement();
        const pointer = output.items.ptr;
        var profile: br.EncodeMemoryProfile = .{};
        var options = h.options(.large25);
        options.memory_profile = &profile;
        options.max_total_working_memory = if (delta) |n| peak - n else null;
        if (delta == 1) {
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, br.encodeStoredStreamChunksWithOptionsAppend(a, &output, &chunks, options));
            try std.testing.expectEqual(pointer, output.items.ptr);
            try std.testing.expectEqual(@as(usize, 7), output.capacity);
            try std.testing.expectEqualSlices(u8, "prefix|", output.items);
        } else {
            try br.encodeStoredStreamChunksWithOptionsAppend(a, &output, &chunks, options);
            try std.testing.expect(pointer != output.items.ptr);
            try std.testing.expectEqualSlices(u8, "prefix|", output.items[0..7]);
            try h.expectWire(output.items[7..], .large25, .chunks);
            try std.testing.expectEqual(tracked.owned_peak, profile.peak_requested_bytes);
            try std.testing.expect(profile.peak_requested_bytes >= output.capacity);
            if (delta == null) peak = profile.peak_requested_bytes else try std.testing.expectEqual(peak, profile.peak_requested_bytes);
        }
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    }
}

test "Brotli stored memory append input and metadata aliases in retained tail snapshot before writes" {
    const payload = h.plain[0..32];
    var peak: usize = 0;
    for ([_]?usize{ null, 0, 1 }) |delta| {
        var tracked = h.TrackingAllocator.init(std.testing.allocator);
        const a = tracked.allocator();
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(a);
        try output.ensureTotalCapacity(a, 1024);
        try output.appendSlice(a, "prefix|");
        // Both retained-tail borrows intersect the actual appended wire, while
        // their bytes and the existing logical prefix begin intact.
        @memcpy(output.allocatedSlice()[16..48], payload);
        @memcpy(output.allocatedSlice()[48..][0..h.metadata.len], h.metadata);
        var profile: br.EncodeMemoryProfile = .{};
        const active: br.StoredStreamOptions = .{ .metadata = output.allocatedSlice()[48..][0..h.metadata.len], .max_total_working_memory = if (delta) |n| peak - n else null, .memory_profile = &profile };
        const input = output.allocatedSlice()[16..48];
        tracked.excludeInitialAllocation(output.allocatedSlice());
        tracked.beginMeasurement();
        if (delta == 1) {
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, br.encodeStoredStreamWithOptionsAppend(a, &output, input, active));
            try std.testing.expectEqualSlices(u8, "prefix|", output.items);
            try std.testing.expectEqualSlices(u8, payload, output.allocatedSlice()[16..48]);
            try std.testing.expectEqualSlices(u8, h.metadata, output.allocatedSlice()[48..][0..h.metadata.len]);
        } else {
            try br.encodeStoredStreamWithOptionsAppend(a, &output, input, active);
            try std.testing.expectEqualSlices(u8, "prefix|", output.items[0..7]);
            try h.decode(output.items[7..], payload, false);
            try std.testing.expectEqual(tracked.owned_peak, profile.peak_requested_bytes);
            try std.testing.expect(profile.peak_requested_bytes >= h.total.control_bytes + payload.len + h.metadata.len);
            if (delta == null) peak = profile.peak_requested_bytes else try std.testing.expectEqual(peak, profile.peak_requested_bytes);
        }
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    }
    for (0..3) |failure| {
        var tracked = h.TrackingAllocator.init(std.testing.allocator);
        const a = tracked.allocator();
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(a);
        try output.ensureTotalCapacity(a, 1024);
        try output.appendSlice(a, "prefix|");
        @memcpy(output.allocatedSlice()[16..48], payload);
        @memcpy(output.allocatedSlice()[48..][0..h.metadata.len], h.metadata);
        const before = try std.testing.allocator.dupe(u8, output.allocatedSlice());
        defer std.testing.allocator.free(before);
        tracked.fail_alloc_after = tracked.alloc_attempts + failure;
        var profile: br.EncodeMemoryProfile = .{};
        const options: br.StoredStreamOptions = .{ .metadata = output.allocatedSlice()[48..][0..h.metadata.len], .memory_profile = &profile };
        try std.testing.expectError(error.OutOfMemory, br.encodeStoredStreamWithOptionsAppend(a, &output, output.allocatedSlice()[16..48], options));
        try std.testing.expectEqual(@as(usize, 7), output.items.len);
        try std.testing.expectEqualSlices(u8, before, output.allocatedSlice());
        try std.testing.expectEqual(output.capacity, tracked.live);
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    }
}

test "Brotli stored memory aliased outer chunk descriptors and payload are charged with atomic refusal" {
    var peak: usize = 0;
    for ([_]?usize{ null, 0, 1 }) |delta| {
        var tracked = h.TrackingAllocator.init(std.testing.allocator);
        const a = tracked.allocator();
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(a);
        try output.ensureTotalCapacity(a, 1024);
        try output.appendSlice(a, "prefix|");
        @memset(output.allocatedSlice()[7..], 0xa5);
        @memcpy(output.allocatedSlice()[48..][0..h.plain.len], h.plain);
        const descriptors: *[2][]const u8 = @ptrCast(@alignCast(output.allocatedSlice()[16..].ptr));
        descriptors.* = .{ output.allocatedSlice()[48..65], output.allocatedSlice()[65..][0 .. h.plain.len - 17] };
        const before = try std.testing.allocator.dupe(u8, output.allocatedSlice());
        defer std.testing.allocator.free(before);
        tracked.excludeInitialAllocation(output.allocatedSlice());
        tracked.beginMeasurement();
        var profile: br.EncodeMemoryProfile = .{};
        const options: br.StoredStreamOptions = .{ .memory_profile = &profile, .max_total_working_memory = if (delta) |n| peak - n else null };
        if (delta == 1) {
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, br.encodeStoredStreamChunksWithOptionsAppend(a, &output, descriptors, options));
            try std.testing.expectEqualSlices(u8, before, output.allocatedSlice());
        } else {
            try br.encodeStoredStreamChunksWithOptionsAppend(a, &output, descriptors, options);
            try std.testing.expectEqualSlices(u8, "prefix|", output.items[0..7]);
            try h.decode(output.items[7..], h.plain, false);
            try std.testing.expectEqual(tracked.owned_peak, profile.peak_requested_bytes);
            try std.testing.expect(profile.peak_requested_bytes >= h.total.control_bytes + h.plain.len + @sizeOf([2][]const u8));
            if (delta == null) peak = profile.peak_requested_bytes else try std.testing.expectEqual(peak, profile.peak_requested_bytes);
        }
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    }
}

test "Brotli stored memory direct Into aliases charge snapshots and quota zero leaves allocation untouched" {
    const expected = try h.frozenAlloc(std.testing.allocator, h.frozen(.standard16, .chunks));
    defer std.testing.allocator.free(expected);
    var peak: usize = 0;
    for ([_]?usize{ null, 0, 1 }) |delta| {
        var output: [512]u8 align(@alignOf([]const u8)) = @splat(0xa5);
        @memcpy(output[128..][0..h.plain.len], h.plain);
        @memcpy(output[300..][0..h.metadata.len], h.metadata);
        const descriptors: *[4][]const u8 = @ptrCast(&output);
        descriptors.* = .{ output[128..145], "", output[145..185], output[185..][0 .. h.plain.len - 57] };
        const before = output;
        var profile: br.EncodeMemoryProfile = .{};
        const options: br.StoredStreamOptions = .{ .metadata = output[300..][0..h.metadata.len], .memory_profile = &profile, .max_total_working_memory = if (delta) |n| peak - n else null };
        if (delta == 1) {
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, br.encodeStoredStreamChunksWithOptionsInto(descriptors, &output, options));
            try std.testing.expectEqualSlices(u8, &before, &output);
        } else {
            const len = try br.encodeStoredStreamChunksWithOptionsInto(descriptors, &output, options);
            try std.testing.expectEqualSlices(u8, expected, output[0..len]);
            try std.testing.expectEqualSlices(u8, before[len..], output[len..]);
            try std.testing.expect(profile.peak_requested_bytes >= h.total.control_bytes + @sizeOf([4][]const u8));
            if (delta == null) peak = profile.peak_requested_bytes else try std.testing.expectEqual(peak, profile.peak_requested_bytes);
        }
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    }
    var output: [512]u8 = @splat(0xa5);
    @memcpy(output[32..][0..h.plain.len], h.plain);
    const before = output;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, br.encodeStoredStreamWithOptionsInto(output[32..][0..h.plain.len], &output, .{ .max_total_working_memory = 0 }));
    try std.testing.expectEqualSlices(u8, &before, &output);
    peak = 0;
    for ([_]?usize{ null, 0, 1 }) |delta| {
        @memset(&output, 0xa5);
        @memcpy(output[32..][0..h.plain.len], h.plain);
        @memcpy(output[16..][0..h.metadata.len], h.metadata);
        const saved = output;
        var profile: br.EncodeMemoryProfile = .{};
        const options: br.StoredStreamOptions = .{ .metadata = output[16..][0..h.metadata.len], .memory_profile = &profile, .max_total_working_memory = if (delta) |n| peak - n else null };
        if (delta == 1) {
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, br.encodeStoredStreamWithOptionsInto(output[32..][0..h.plain.len], &output, options));
            try std.testing.expectEqualSlices(u8, &saved, &output);
        } else {
            const len = try br.encodeStoredStreamWithOptionsInto(output[32..][0..h.plain.len], &output, options);
            try h.expectWire(output[0..len], .standard16, .contiguous);
            try std.testing.expectEqualSlices(u8, saved[len..], output[len..]);
            try std.testing.expectEqual(h.total.control_bytes + h.plain.len + h.metadata.len, profile.peak_requested_bytes);
            if (delta == null) peak = profile.peak_requested_bytes else try std.testing.expectEqual(peak, profile.peak_requested_bytes);
        }
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    }
}

test "Brotli stored memory inherited authority rejects conflicting cap and profile on zero heap routes" {
    var tracked = h.TrackingAllocator.init(std.testing.allocator);
    var profile: br.EncodeMemoryProfile = .{};
    var other: br.EncodeMemoryProfile = .{};
    var lease = try h.total.Lease.init(tracked.allocator(), 4096, &profile, 0);
    const a = lease.allocator();
    var output = std.ArrayList(u8).fromOwnedSlice(try a.alloc(u8, 512));
    output.items.len = 0;
    const attempts = tracked.alloc_attempts;
    try std.testing.expectError(error.InvalidBlockPlan, br.encodeStoredStreamWithOptionsAppend(a, &output, h.plain, .{ .max_total_working_memory = 0 }));
    try std.testing.expectError(error.InvalidBlockPlan, br.encodeStoredStreamWithOptionsAppend(a, &output, h.plain, .{ .memory_profile = &other }));
    try std.testing.expectEqual(@as(usize, 0), output.items.len);
    var encoder = br.StoredStreamEncoder.init(a);
    var destination: [256]u8 = @splat(0xa5);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeWithOptionsIntoSlice(h.plain, .{ .max_total_working_memory = 0 }, &destination));
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeWithOptionsIntoSlice(h.plain, .{ .memory_profile = &other }, &destination));
    try h.untouched(&destination);
    try std.testing.expectEqual(attempts, tracked.alloc_attempts);
    const written = try encoder.encodeWithOptionsIntoSlice(h.plain, .{ .max_total_working_memory = 4096, .memory_profile = &profile }, &destination);
    try h.decode(destination[0..written], h.plain, false);
    try std.testing.expectEqual(attempts, tracked.alloc_attempts);
    encoder.deinit();
    output.deinit(a);
    // A handed-off wire retains its charge in the inherited allocator. Closing
    // the last lease keeps frees safe while refusing new owners and requests.
    const handed_off = try br.encodeStoredStreamWithOptionsAlloc(a, h.plain, .{});
    lease.deinit();
    try std.testing.expectError(error.InvalidBlockPlan, h.total.Lease.fromAllocator(a));
    try std.testing.expectError(error.InvalidBlockPlan, br.encodeStoredStreamWithOptionsAlloc(a, h.plain, .{}));
    a.free(handed_off);
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
}
