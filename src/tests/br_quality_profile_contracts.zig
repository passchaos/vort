const std = @import("std");
const TrackingAllocator = @import("br_total_memory_helpers.zig").TrackingAllocator;

fn q8Options(comptime Codec: type) Codec.PlannedEncodeOptions {
    return .{ .quality = 8, .mode = .generic };
}

fn checkMemory(left: *const std.testing.FailingAllocator, right: *const std.testing.FailingAllocator) !void {
    try std.testing.expectEqual(left.alloc_index, right.alloc_index);
    try std.testing.expectEqual(left.resize_index, right.resize_index);
    try std.testing.expectEqual(left.allocated_bytes, right.allocated_bytes);
    try std.testing.expectEqual(left.freed_bytes, right.freed_bytes);
    try std.testing.expectEqual(left.allocations, right.allocations);
    try std.testing.expectEqual(left.deallocations, right.deallocations);
}

fn profileShape(profile: anytype, input_len: usize, output_len: usize) !void {
    try std.testing.expect(profile.event_count <= profile.events.len);
    try std.testing.expect(profile.event_count <= profile.request.event_limit);
    try std.testing.expect(profile.events_total >= profile.event_count);
    try std.testing.expectEqual(@as(?usize, output_len), profile.returned_wire_bytes);
    try std.testing.expect(profile.timing_complete);
    try std.testing.expectEqualStrings("", profile.error_name);
    try std.testing.expect(profile.exclusive_ns.total() <= profile.outer_elapsed_ns);
    try std.testing.expectEqual(profile.outer_elapsed_ns - profile.exclusive_ns.total(), profile.unaccounted_ns);
    var outer: usize = 0;
    for (profile.events[0..profile.event_count], 0..) |event, index| {
        try std.testing.expect(event.exclusive_ns <= event.inclusive_ns);
        for (profile.events[0..index]) |earlier| try std.testing.expect(earlier.id != event.id);
        if (event.parent_id) |parent_id| {
            var found = false;
            for (profile.events[0..index]) |earlier| {
                if (earlier.id == parent_id) {
                    found = true;
                    try std.testing.expect(event.inclusive_ns <= earlier.inclusive_ns);
                    break;
                }
            }
            try std.testing.expect(found);
        }
        if (event.stage == .outer) {
            outer += 1;
            try std.testing.expectEqual(input_len, event.input_bytes);
        }
    }
    try std.testing.expectEqual(@as(usize, 1), outer);
    if (profile.events_truncated or !profile.wire_attempt_coverage_complete) {
        try std.testing.expectEqual(@as(?usize, null), profile.returned_wire_event_id);
    } else {
        const returned_id = profile.returned_wire_event_id orelse return error.TestUnexpectedResult;
        var linked = false;
        for (profile.events[0..profile.event_count]) |event| {
            if (event.id == returned_id) {
                try std.testing.expectEqual(@TypeOf(event.stage).wire, event.stage);
                try std.testing.expectEqualStrings("", event.error_name);
                try std.testing.expectEqual(@as(?usize, output_len), event.wire_bytes);
                linked = true;
            }
        }
        try std.testing.expect(linked);
    }
}

/// Compare stable diagnostic semantics; timing values depend on the clock and
/// are deliberately excluded from correctness assertions.
fn deterministicShape(first: anytype, second: anytype) !void {
    try std.testing.expectEqual(first.events_total, second.events_total);
    try std.testing.expectEqual(first.event_count, second.event_count);
    try std.testing.expectEqual(first.events_truncated, second.events_truncated);
    try std.testing.expectEqual(first.wire_attempt_coverage_complete, second.wire_attempt_coverage_complete);
    try std.testing.expectEqual(first.wire_attempts, second.wire_attempts);
    try std.testing.expectEqualDeep(first.returned_wire_event_id, second.returned_wire_event_id);
    for (first.events[0..first.event_count], second.events[0..second.event_count]) |left, right| {
        try std.testing.expectEqual(left.id, right.id);
        try std.testing.expectEqualDeep(left.parent_id, right.parent_id);
        try std.testing.expectEqual(left.stage, right.stage);
        try std.testing.expectEqual(left.origin, right.origin);
        try std.testing.expectEqualDeep(left.variant, right.variant);
        try std.testing.expectEqual(left.input_bytes, right.input_bytes);
        try std.testing.expectEqual(left.command_count, right.command_count);
        try std.testing.expectEqualDeep(left.wire_bytes, right.wire_bytes);
        try std.testing.expectEqualStrings(left.error_name, right.error_name);
        try std.testing.expectEqualDeep(left.accepted, right.accepted);
        try std.testing.expectEqualDeep(left.gain_bytes, right.gain_bytes);
        try std.testing.expectEqualDeep(left.incumbent_bytes, right.incumbent_bytes);
        try std.testing.expectEqualDeep(left.candidate_event_id, right.candidate_event_id);
        try std.testing.expectEqualDeep(left.incumbent_event_id, right.incumbent_event_id);
        try std.testing.expectEqualDeep(left.config, right.config);
    }
}

fn wireCase(comptime Codec: type, input: []const u8) !void {
    var regular_heap = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var profiled_heap = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    const ordinary = try Codec.encodePlannedStreamWithOptionsAlloc(regular_heap.allocator(), input, q8Options(Codec));
    defer regular_heap.allocator().free(ordinary);
    var profile: Codec.QualityQ8Profile = .{};
    const profiled = try Codec.benchmarkQualityQ8ProfileAlloc(profiled_heap.allocator(), input, std.testing.io, &profile);
    defer profiled_heap.allocator().free(profiled);
    try std.testing.expectEqualSlices(u8, ordinary, profiled);
    try std.testing.expectEqual(ordinary.len, regular_heap.allocated_bytes - regular_heap.freed_bytes);
    try std.testing.expectEqual(profiled.len, profiled_heap.allocated_bytes - profiled_heap.freed_bytes);
    try checkMemory(&regular_heap, &profiled_heap);
    try profileShape(profile, input.len, profiled.len);
    const decoded = try Codec.decodeStreamAlloc(std.testing.allocator, profiled);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);

    var repeated_heap = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var second: Codec.QualityQ8Profile = .{};
    const repeated = try Codec.benchmarkQualityQ8ProfileAlloc(repeated_heap.allocator(), input, std.testing.io, &second);
    defer repeated_heap.allocator().free(repeated);
    try std.testing.expectEqualSlices(u8, ordinary, repeated);
    try checkMemory(&regular_heap, &repeated_heap);
    try deterministicShape(profile, second);
}

fn eventCapacity(comptime Codec: type, input: []const u8) !void {
    var expected_heap = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var expected_profile: Codec.QualityQ8Profile = .{};
    const expected = try Codec.benchmarkQualityQ8ProfileAlloc(expected_heap.allocator(), input, std.testing.io, &expected_profile);
    defer expected_heap.allocator().free(expected);
    try std.testing.expect(expected_profile.events_total > 1);
    try std.testing.expect(expected_profile.wire_attempt_coverage_complete);
    try std.testing.expect(!expected_profile.events_truncated);
    try std.testing.expect(expected_profile.returned_wire_event_id != null);
    for ([_]usize{ 0, 1 }) |limit| {
        var heap = std.testing.FailingAllocator.init(std.testing.allocator, .{});
        var profile: Codec.QualityQ8Profile = .{};
        profile.request.event_limit = limit;
        const actual = try Codec.benchmarkQualityQ8ProfileAlloc(heap.allocator(), input, std.testing.io, &profile);
        defer heap.allocator().free(actual);
        try std.testing.expectEqualSlices(u8, expected, actual);
        try checkMemory(&expected_heap, &heap);
        try std.testing.expect(profile.events_truncated);
        try std.testing.expect(profile.event_count <= limit);
        try std.testing.expectEqual(expected_profile.events_total, profile.events_total);
        try std.testing.expectEqual(@as(?usize, expected.len), profile.returned_wire_bytes);
        try std.testing.expectEqual(limit, profile.request.event_limit);
        try std.testing.expectEqual(@as(?usize, null), profile.returned_wire_event_id);
        if (limit == 0) try std.testing.expectEqual(@as(usize, 0), profile.recordedEvents().len);
    }
}

fn checkTracked(left: *const TrackingAllocator, right: *const TrackingAllocator) !void {
    try std.testing.expectEqual(left.alloc_attempts, right.alloc_attempts);
    try std.testing.expectEqual(left.resize_attempts, right.resize_attempts);
    try std.testing.expectEqual(left.remap_attempts, right.remap_attempts);
    try std.testing.expectEqual(left.allocated_bytes, right.allocated_bytes);
    try std.testing.expectEqual(left.freed_bytes, right.freed_bytes);
    try std.testing.expectEqual(left.live, right.live);
    try std.testing.expectEqual(left.peak, right.peak);
}

fn finiteMemory(comptime Codec: type, input: []const u8) !void {
    // This input reaches the complete candidate path with wire linkage. The
    // collector allocator is separate from the two measured encoder heaps.
    try std.testing.expect(input.len > 4096);
    const expected = try Codec.encodePlannedStreamWithOptionsAlloc(std.testing.allocator, input, q8Options(Codec));
    defer std.testing.allocator.free(expected);
    var measured_peak: usize = 0;
    for (0..3) |phase| {
        const limit: usize = switch (phase) {
            0 => 32 * 1024 * 1024,
            1 => measured_peak,
            2 => measured_peak - 1,
            else => unreachable,
        };
        var regular_heap = TrackingAllocator.init(std.testing.allocator);
        var profiled_heap = TrackingAllocator.init(std.testing.allocator);
        regular_heap.force_moving_growth = true;
        profiled_heap.force_moving_growth = true;
        var regular_memory: Codec.EncodeMemoryProfile = .{};
        var profiled_memory: Codec.EncodeMemoryProfile = .{};
        const options: Codec.PlannedEncodeOptions = .{
            .quality = 8,
            .mode = .generic,
            .max_total_working_memory = limit,
            .memory_profile = &regular_memory,
        };
        var profile: Codec.QualityQ8Profile = .{};
        profile.request.max_total_working_memory = limit;
        profile.request.memory_profile = &profiled_memory;
        const regular = Codec.encodePlannedStreamWithOptionsAlloc(regular_heap.allocator(), input, options);
        const diagnostic = Codec.benchmarkQualityQ8ProfileAlloc(profiled_heap.allocator(), input, std.testing.io, &profile);
        if (phase == 2) {
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, regular);
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, diagnostic);
            try std.testing.expectEqualStrings("WorkingMemoryLimitExceeded", profile.error_name);
            try std.testing.expectEqual(@as(?usize, null), profile.returned_wire_bytes);
            try std.testing.expectEqual(@as(?usize, null), profile.returned_wire_event_id);
        } else {
            const ordinary = try regular;
            errdefer regular_heap.allocator().free(ordinary);
            const profiled = try diagnostic;
            errdefer profiled_heap.allocator().free(profiled);
            try std.testing.expectEqualSlices(u8, expected, ordinary);
            try std.testing.expectEqualSlices(u8, expected, profiled);
            try std.testing.expectEqual(ordinary.len, regular_heap.live);
            try std.testing.expectEqual(profiled.len, profiled_heap.live);
            try checkTracked(&regular_heap, &profiled_heap);
            try profileShape(profile, input.len, profiled.len);
            // The owned output is still physically live on the caller heap,
            // while its allocation has left the ended encoder budget lease.
            try std.testing.expectEqual(@as(usize, 0), regular_memory.live_requested_bytes);
            try std.testing.expectEqual(@as(usize, 0), profiled_memory.live_requested_bytes);
            if (phase == 0) {
                measured_peak = regular_heap.peak;
                try std.testing.expect(measured_peak > ordinary.len);
                try std.testing.expect(measured_peak < limit);
            } else {
                try std.testing.expectEqual(measured_peak, regular_heap.peak);
                try std.testing.expectEqual(measured_peak, profiled_heap.peak);
            }
            regular_heap.allocator().free(ordinary);
            profiled_heap.allocator().free(profiled);
        }
        try checkTracked(&regular_heap, &profiled_heap);
        try std.testing.expect(regular_memory.available and profiled_memory.available);
        try std.testing.expectEqual(@as(?usize, limit), regular_memory.limit);
        try std.testing.expectEqual(@as(?usize, limit), profiled_memory.limit);
        try std.testing.expectEqual(regular_heap.peak, regular_memory.peak_requested_bytes);
        try std.testing.expectEqual(profiled_heap.peak, profiled_memory.peak_requested_bytes);
        try std.testing.expect(regular_heap.peak <= limit and profiled_heap.peak <= limit);
        try std.testing.expectEqual(@as(usize, 0), regular_memory.live_requested_bytes);
        try std.testing.expectEqual(@as(usize, 0), profiled_memory.live_requested_bytes);
        try std.testing.expectEqual(@as(usize, 0), regular_heap.live);
        try std.testing.expectEqual(@as(usize, 0), profiled_heap.live);
        try std.testing.expectEqual(regular_heap.allocated_bytes, regular_heap.freed_bytes);
        try std.testing.expectEqual(profiled_heap.allocated_bytes, profiled_heap.freed_bytes);
    }
}

fn resourceFailures(comptime Codec: type, input: []const u8) !void {
    var baseline = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var profile: Codec.QualityQ8Profile = .{};
    const wire = try Codec.benchmarkQualityQ8ProfileAlloc(baseline.allocator(), input, std.testing.io, &profile);
    baseline.allocator().free(wire);
    try std.testing.expectEqual(baseline.allocated_bytes, baseline.freed_bytes);
    try std.testing.expect(baseline.alloc_index >= 3);
    // Replay bounded selected real requests, not a Cartesian allocation sweep.
    for ([_]usize{ 0, 1, 2, baseline.alloc_index - 1 }) |failure| {
        var ordinary_heap = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = failure });
        var profiled_heap = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = failure });
        var failed: Codec.QualityQ8Profile = .{};
        const regular = Codec.encodePlannedStreamWithOptionsAlloc(ordinary_heap.allocator(), input, q8Options(Codec));
        const diagnostic = Codec.benchmarkQualityQ8ProfileAlloc(profiled_heap.allocator(), input, std.testing.io, &failed);
        if (regular) |result| {
            const profiled = try diagnostic;
            try std.testing.expectEqualSlices(u8, result, profiled);
            ordinary_heap.allocator().free(result);
            profiled_heap.allocator().free(profiled);
        } else |err| {
            try std.testing.expectError(err, diagnostic);
            if (failure == 0) try std.testing.expectEqual(error.OutOfMemory, err);
        }
        try checkMemory(&ordinary_heap, &profiled_heap);
        try std.testing.expectEqual(ordinary_heap.allocated_bytes, ordinary_heap.freed_bytes);
        try std.testing.expectEqual(profiled_heap.allocated_bytes, profiled_heap.freed_bytes);
    }
    var no_backing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    var memory: Codec.EncodeMemoryProfile = .{};
    var capped: Codec.QualityQ8Profile = .{};
    capped.request.max_total_working_memory = 0;
    capped.request.memory_profile = &memory;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, Codec.benchmarkQualityQ8ProfileAlloc(no_backing.allocator(), input, std.testing.io, &capped));
    try std.testing.expectEqual(@as(usize, 0), no_backing.alloc_index);
    try std.testing.expect(!no_backing.has_induced_failure);
    try std.testing.expectEqual(@as(usize, 0), memory.live_requested_bytes);
    try std.testing.expect(memory.available);
    try std.testing.expectEqual(@as(?usize, 0), memory.limit);
}

pub fn contracts(comptime Codec: type) !void {
    for ([_][]const u8{ "", "x", "tiny", "abcabcabc | patterned Brotli quality eight\n" ** 32, "bounded q8 fixed profile preserves writer ownership\n" ** 64 }) |input|
        try wireCase(Codec, input);
    var random: [65536]u8 = undefined;
    var seed: u32 = 0x243f6a88;
    for (&random) |*byte| {
        seed = seed *% 1664525 +% 1013904223;
        byte.* = @truncate(seed >> 24);
    }
    try wireCase(Codec, &random);
    const structured = "{\"quality\":8,\"mode\":\"generic\",\"message\":\"abcdefghabcdefghXabcdefgh\"}\n" ** 100;
    try wireCase(Codec, structured);
    try eventCapacity(Codec, structured);
    try resourceFailures(Codec, structured);
    try finiteMemory(Codec, structured);
    var oversized: [65537]u8 = undefined;
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    var profile: Codec.QualityQ8Profile = .{};
    try std.testing.expectError(error.InvalidBlockPlan, Codec.benchmarkQualityQ8ProfileAlloc(failing.allocator(), &oversized, std.testing.io, &profile));
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
    try std.testing.expect(!failing.has_induced_failure);
}
