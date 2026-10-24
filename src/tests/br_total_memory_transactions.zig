const std = @import("std");
const br = @import("../br.zig");
const h = @import("br_total_memory_helpers.zig");

test "Brotli total memory Into rejects an impossible budget without touching caller destination" {
    for ([_]h.Setting{ .fast, .balanced, .ratio, .q0, .q11, .hq11 }) |setting| {
        var profile: br.EncodeMemoryProfile = .{};
        var options = h.options(br.PlannedEncodeOptions, setting);
        options.max_total_working_memory = 0;
        options.memory_profile = &profile;
        var output: [1024]u8 = @splat(0xa5);
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, br.encodePlannedStreamWithOptionsInto(h.plain, &output, options));
        try h.untouched(&output);
        try std.testing.expect(profile.available);
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    }
}

test "Brotli total memory append constant borrowed output is excluded and exact cap preserves aliased input" {
    for ([_]h.Setting{ .fast, .q0, .hq11 }) |setting| {
        var tracked = h.TrackingAllocator.init(std.testing.allocator);
        tracked.force_moving_growth = true;
        const a = tracked.allocator();
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(a);
        try output.ensureTotalCapacity(a, 1024);
        try output.appendSlice(a, h.plain);
        const borrowed_capacity = output.capacity;
        var profile: br.EncodeMemoryProfile = .{};
        var options = h.options(br.PlannedStreamChunksOptions, setting);
        options.memory_profile = &profile;
        const chunks = [_][]const u8{output.items};
        tracked.beginMeasurement();
        try br.encodePlannedStreamChunksWithOptionsAppend(a, &output, &chunks, options);
        const expected = try std.testing.allocator.dupe(u8, output.items);
        defer std.testing.allocator.free(expected);
        const peak = profile.peak_requested_bytes;
        try std.testing.expectEqual(tracked.peak - borrowed_capacity, peak);
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
        try std.testing.expectEqualSlices(u8, h.plain, output.items[0..h.plain.len]);

        output.shrinkRetainingCapacity(h.plain.len);
        profile.reset();
        tracked.beginMeasurement();
        options.max_total_working_memory = peak;
        try br.encodePlannedStreamChunksWithOptionsAppend(a, &output, &chunks, options);
        try std.testing.expectEqualSlices(u8, expected, output.items);
        try std.testing.expectEqual(tracked.peak - borrowed_capacity, profile.peak_requested_bytes);
        output.shrinkRetainingCapacity(h.plain.len);
        profile.reset();
        options.max_total_working_memory = peak - 1;
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, br.encodePlannedStreamChunksWithOptionsAppend(a, &output, &chunks, options));
        try std.testing.expectEqualSlices(u8, h.plain, output.items);
        try std.testing.expectEqual(borrowed_capacity, output.capacity);
        try std.testing.expectEqual(borrowed_capacity, tracked.live);
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    }
}

test "Brotli total memory append moving destination growth is charged until publication and refuses atomically" {
    var peak: usize = 0;
    for ([_]?usize{ null, 0, 1 }) |variant| {
        var tracked = h.TrackingAllocator.init(std.testing.allocator);
        tracked.force_moving_growth = true;
        const a = tracked.allocator();
        var output = std.ArrayList(u8).fromOwnedSlice(try a.alloc(u8, 8192));
        @memset(output.items, 0xa5);
        tracked.excludeInitialAllocation(output.items.ptr[0..output.capacity]);
        tracked.beginMeasurement();
        var profile: br.EncodeMemoryProfile = .{};
        const cap: ?usize = if (variant) |delta| peak - delta else null;
        const options: br.PlannedStreamChunksOptions = .{ .max_total_working_memory = cap, .memory_profile = &profile };
        if (variant == 1) {
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, br.encodePlannedStreamChunksWithOptionsAppend(a, &output, &.{""}, options));
            try std.testing.expectEqual(@as(usize, 8192), output.items.len);
            try std.testing.expectEqual(@as(usize, 8192), output.capacity);
            try h.untouched(output.items);
        } else {
            try br.encodePlannedStreamChunksWithOptionsAppend(a, &output, &.{""}, options);
            try std.testing.expect(output.capacity > 8192);
            try std.testing.expectEqual(tracked.owned_peak, profile.peak_requested_bytes);
            try std.testing.expect(tracked.peak_request > 8192);
            try h.untouched(output.items[0..8192]);
            const decoded = try br.decodeStreamAlloc(std.testing.allocator, output.items[8192..]);
            defer std.testing.allocator.free(decoded);
            try std.testing.expectEqual(@as(usize, 0), decoded.len);
            if (variant == null) peak = profile.peak_requested_bytes else try std.testing.expectEqual(peak, profile.peak_requested_bytes);
        }
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
        output.deinit(a);
        try std.testing.expectEqual(@as(usize, 0), tracked.live);
    }
}

test "Brotli total memory append to encoder owned output preserves old prefix and aliased outer chunks" {
    for ([_]h.Setting{ .fast, .q0 }) |setting| {
        errdefer std.debug.print("total-memory owned-append failed-setting={s}\n", .{@tagName(setting)});
        const payload = h.plain[0..32];
        const expected_chunks = [_][]const u8{ payload[0..17], payload[17..] };
        const expected_wire = try br.encodePlannedStreamChunksWithOptionsAlloc(std.testing.allocator, &expected_chunks, h.options(br.PlannedStreamChunksOptions, setting));
        defer std.testing.allocator.free(expected_wire);
        var peak: usize = 0;
        for ([_]?usize{ null, 0, 1 }) |variant| {
            var tracked = h.TrackingAllocator.init(std.testing.allocator);
            tracked.force_moving_growth = true;
            const a = tracked.allocator();
            var encoder = br.PlannedStreamEncoder.init(a);
            defer encoder.deinit();
            try encoder.output.resize(a, 256);
            @memset(encoder.output.items, 0xa5);
            @memcpy(encoder.output.items[128..160], payload);
            const descriptors: *[2][]const u8 = @ptrCast(@alignCast(encoder.output.items.ptr));
            descriptors.* = .{ encoder.output.items[128..145], encoder.output.items[145..160] };
            const prefix = try std.testing.allocator.dupe(u8, encoder.output.items);
            defer std.testing.allocator.free(prefix);
            var profile: br.EncodeMemoryProfile = .{};
            var options = h.options(br.PlannedStreamChunksOptions, setting);
            options.memory_profile = &profile;
            options.max_total_working_memory = if (variant) |delta| peak - delta else null;
            tracked.beginMeasurement();
            if (variant == 1) {
                try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.encodeChunksWithOptionsAppend(&encoder.output, descriptors, options));
                try std.testing.expectEqualSlices(u8, prefix, encoder.output.items);
            } else {
                try encoder.encodeChunksWithOptionsAppend(&encoder.output, descriptors, options);
                try std.testing.expectEqual(prefix.len + expected_wire.len, encoder.output.items.len);
                try std.testing.expectEqualSlices(u8, prefix, encoder.output.items[0..prefix.len]);
                try std.testing.expectEqualSlices(u8, expected_wire, encoder.output.items[prefix.len..]);
                try std.testing.expectEqual(tracked.peak, profile.peak_requested_bytes);
                try std.testing.expectEqual(tracked.live, profile.live_requested_bytes);
                if (variant == null) peak = tracked.peak else try std.testing.expectEqual(peak, tracked.peak);
            }
        }
    }
}

const FailureGraph = struct {
    pub fn run(backing: std.mem.Allocator, setting: h.Setting) !void {
        var tracked = h.TrackingAllocator.init(backing);
        tracked.force_moving_growth = true;
        const a = tracked.allocator();
        var profile: br.EncodeMemoryProfile = .{};
        var workspace: br.HqProfile = .{};
        var options = h.options(br.PlannedEncodeOptions, setting);
        options.memory_profile = &profile;
        if (options.hq) |*hq| hq.profile = &workspace;
        const bytes = br.encodePlannedStreamWithOptionsAlloc(a, h.plain[0..32], options) catch |err| {
            try std.testing.expectEqual(@as(usize, 0), tracked.live);
            try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
            try std.testing.expectEqual(@as(u64, 0), workspace.emitted_metablocks);
            return err;
        };
        a.free(bytes);
        try std.testing.expectEqual(@as(usize, 0), tracked.live);
        try std.testing.expectEqual(tracked.allocated_bytes, tracked.freed_bytes);
    }
};

test "Brotli total memory bounded tiny allocation graph releases all failed nested HQ guard and legacy work" {
    for ([_]h.Setting{ .fast, .q0, .hq11 }) |setting|
        try std.testing.checkAllAllocationFailures(std.testing.allocator, FailureGraph.run, .{setting});
}

test "Brotli total memory warm legacy capacity seeds the cap and refusal preserves reusable wire and allocator" {
    var tracked = h.TrackingAllocator.init(std.testing.allocator);
    tracked.force_moving_growth = true;
    const a = tracked.allocator();
    var encoder = br.PlannedStreamEncoder.init(a);
    defer encoder.deinit();
    const warm = try encoder.encodeScratchWithOptions(h.plain, .{});
    const expected = try std.testing.allocator.dupe(u8, warm);
    defer std.testing.allocator.free(expected);
    const retained = tracked.live;
    try std.testing.expect(retained > 0);
    // The public retainedCapacity includes inline state arrays; the heap cap
    // oracle comes only from allocations observed by this backing allocator.
    const before_allocator = encoder.allocator;
    const before_capacity = encoder.retainedCapacity();
    const before_allocations = tracked.alloc_attempts;
    var profile: br.EncodeMemoryProfile = .{};
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.encodeScratchWithOptions(h.plain, .{
        .max_total_working_memory = retained - 1,
        .memory_profile = &profile,
    }));
    try std.testing.expectEqual(retained, tracked.live);
    try std.testing.expectEqual(before_capacity, encoder.retainedCapacity());
    try std.testing.expectEqual(before_allocations, tracked.alloc_attempts);
    try std.testing.expect(before_allocator.ptr == encoder.allocator.ptr and before_allocator.vtable == encoder.allocator.vtable);
    try std.testing.expectEqualSlices(u8, expected, encoder.output.items);
    profile.reset();
    tracked.beginMeasurement();
    const recovered = try encoder.encodeScratchWithOptions(h.plain, .{ .memory_profile = &profile });
    try std.testing.expectEqualSlices(u8, expected, recovered);
    try std.testing.expectEqual(tracked.peak, profile.peak_requested_bytes);
    try std.testing.expectEqual(tracked.live, profile.live_requested_bytes);
}

test "Brotli total memory returned owned wire remains valid and freeable after reusable handle destruction" {
    for ([_]h.Setting{ .fast, .q0, .hq11 }) |setting| {
        var tracked = h.TrackingAllocator.init(std.testing.allocator);
        tracked.force_moving_growth = true;
        const a = tracked.allocator();
        var profile: br.EncodeMemoryProfile = .{};
        var options = h.options(br.PlannedEncodeOptions, setting);
        options.memory_profile = &profile;
        var original = br.PlannedStreamEncoder.init(a);
        _ = try original.encodeScratchWithOptions(h.plain, options);
        var moved = original;
        original = undefined;
        const bytes = try moved.encodeWithOptionsAlloc(a, h.plain, options);
        try std.testing.expectEqual(tracked.peak, profile.peak_requested_bytes);
        try std.testing.expectEqual(tracked.live - bytes.len, profile.live_requested_bytes);
        moved.deinit();
        try std.testing.expectEqual(bytes.len, tracked.live);
        const decoded = try br.decodeStreamAlloc(std.testing.allocator, bytes);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, h.plain, decoded);
        a.free(bytes);
        try std.testing.expectEqual(@as(usize, 0), tracked.live);
    }
}

test "Brotli total memory an OOM after draining metadata accounts copied progress and resumes without duplication" {
    for ([_]h.Setting{ .q0, .hq10 }) |setting| {
        var tracked = h.TrackingAllocator.init(std.testing.allocator);
        tracked.force_moving_growth = true;
        var profile: br.EncodeMemoryProfile = .{};
        var options = h.options(br.PlannedStreamChunksOptions, setting);
        options.metadata = "budget-prefix";
        options.memory_profile = &profile;
        var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(tracked.allocator(), .{ .stream = options, .block_len = 0 });
        defer encoder.deinit();
        _ = try encoder.step("", &.{});
        const before = encoder.snapshot();
        try std.testing.expect(before.pending_output > 0);
        tracked.fail_alloc_after = tracked.alloc_attempts;
        var destination: [128]u8 = @splat(0xa5);
        try std.testing.expectError(error.OutOfMemory, encoder.step(h.plain, &destination));
        const after = encoder.snapshot();
        const copied: usize = @intCast(after.stream_output - before.stream_output);
        try std.testing.expect(copied > 0 and copied <= destination.len);
        try std.testing.expectEqual(before.stream_input, after.stream_input);
        try h.untouched(destination[copied..]);
        tracked.clearFailures();
        const tail = try h.drive(std.testing.allocator, &encoder, h.plain, 31, 17);
        defer std.testing.allocator.free(tail);
        const bytes = try std.mem.concat(std.testing.allocator, u8, &.{ destination[0..copied], tail });
        defer std.testing.allocator.free(bytes);
        const decoded = try br.decodeStreamAlloc(std.testing.allocator, bytes);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, h.plain, decoded);
    }
}

test "Brotli total memory next stream lower cap refuses before reset and moved handles retain one owner" {
    for ([_]h.Setting{ .fast, .hq11 }) |setting| {
        var tracked = h.TrackingAllocator.init(std.testing.allocator);
        tracked.force_moving_growth = true;
        var profile: br.EncodeMemoryProfile = .{};
        var stream = h.options(br.PlannedStreamChunksOptions, setting);
        stream.block_len = 32;
        stream.memory_profile = &profile;
        const options: br.IncrementalPlannedStreamEncoder.Options = .{ .stream = stream, .block_len = 0 };
        {
            var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(tracked.allocator(), options);
            var moved_owner = false;
            defer if (!moved_owner) encoder.deinit();
            const expected = try h.drive(std.testing.allocator, &encoder, h.plain, 31, 17);
            defer std.testing.allocator.free(expected);
            const before = encoder.snapshot();
            const retained = tracked.live;
            try std.testing.expect(retained > 0);
            var lower = options;
            lower.stream.max_total_working_memory = retained - 1;
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.nextStream(lower));
            try std.testing.expectEqualDeep(before, encoder.snapshot());
            try std.testing.expectEqualDeep(options, encoder.options);
            try std.testing.expectEqual(retained, tracked.live);
            try encoder.nextStream(options);
            var moved = encoder;
            encoder = undefined;
            moved_owner = true;
            defer moved.deinit();
            const next = try h.drive(std.testing.allocator, &moved, h.plain, 1, 1);
            defer std.testing.allocator.free(next);
            try std.testing.expectEqualSlices(u8, expected, next);
            try std.testing.expectEqual(tracked.live, profile.live_requested_bytes);
            moved.reset();
            const empty = moved.snapshot();
            try std.testing.expectEqual(@as(usize, 0), empty.stream_input);
            try std.testing.expectEqual(@as(usize, 0), empty.stream_output);
            try std.testing.expectEqual(@as(usize, 0), empty.buffered_input);
            try std.testing.expectEqual(@as(usize, 0), empty.pending_output);
            try std.testing.expectEqual(tracked.live, profile.live_requested_bytes);
            const repeated = try h.drive(std.testing.allocator, &moved, h.plain, 17, 1);
            defer std.testing.allocator.free(repeated);
            try std.testing.expectEqualSlices(u8, expected, repeated);
        }
        try std.testing.expectEqual(@as(usize, 0), tracked.live);
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
        try std.testing.expectEqual(tracked.allocated_bytes, tracked.freed_bytes);
    }
}

test "Brotli total memory distinct caller allocator transfer counts simultaneous bytes and changed owner identity rejects" {
    for ([_]h.Setting{ .fast, .q0, .hq11 }) |setting| {
        const input = if (setting == .fast) "" else h.plain;
        var joint: h.JointLedger = .{};
        var first = h.TrackingAllocator.init(std.testing.allocator);
        first.force_moving_growth = true;
        first.joint = &joint;
        var second = h.TrackingAllocator.init(std.testing.allocator);
        second.force_moving_growth = true;
        second.joint = &joint;
        const a = first.allocator();
        const b = second.allocator();
        var profile: br.EncodeMemoryProfile = .{};
        var options = h.options(br.PlannedEncodeOptions, setting);
        options.memory_profile = &profile;
        var encoder = br.PlannedStreamEncoder.init(a);
        var destroyed = false;
        defer if (!destroyed) encoder.deinit();
        // A retained large prefix and an empty fast wire make the external
        // two-byte replacement itself establish the final simultaneous peak.
        if (setting == .fast) try encoder.output.resize(a, 8192);
        _ = try encoder.encodeScratchWithOptions(input, options);
        profile.reset();
        joint.beginMeasurement();
        const bytes = try encoder.encodeWithOptionsAlloc(b, input, options);
        defer b.free(bytes);
        try std.testing.expectEqual(joint.peak, profile.peak_requested_bytes);
        try std.testing.expectEqual(joint.live - bytes.len, profile.live_requested_bytes);
        const prefix = try std.testing.allocator.dupe(u8, encoder.output.items);
        defer std.testing.allocator.free(prefix);
        const capacity = encoder.retainedCapacity();
        const allocations_a = first.alloc_attempts;
        const allocations_b = second.alloc_attempts;
        const live = joint.live;
        encoder.allocator = b;
        try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeScratchWithOptions(input, options));
        try std.testing.expectEqualSlices(u8, prefix, encoder.output.items);
        try std.testing.expectEqual(capacity, encoder.retainedCapacity());
        try std.testing.expectEqual(allocations_a, first.alloc_attempts);
        try std.testing.expectEqual(allocations_b, second.alloc_attempts);
        try std.testing.expectEqual(live, joint.live);
        encoder.deinit();
        destroyed = true;
        try std.testing.expectEqual(@as(usize, 0), first.live);
        try std.testing.expectEqual(bytes.len, second.live);
        const decoded = try br.decodeStreamAlloc(std.testing.allocator, bytes);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }
}

test "Brotli total memory Into aliased encoder output subslice survives moving allocation and zero cap refusal" {
    for ([_]h.Setting{ .fast, .q0 }) |setting| {
        var tracked = h.TrackingAllocator.init(std.testing.allocator);
        tracked.force_moving_growth = true;
        const a = tracked.allocator();
        var encoder = br.PlannedStreamEncoder.init(a);
        defer encoder.deinit();
        try encoder.output.resize(a, 1024);
        @memset(encoder.output.items, 0xa5);
        @memcpy(encoder.output.items[64..][0..h.plain.len], h.plain);
        const before = try std.testing.allocator.dupe(u8, encoder.output.items);
        defer std.testing.allocator.free(before);
        var profile: br.EncodeMemoryProfile = .{};
        var options = h.options(br.PlannedEncodeOptions, setting);
        options.memory_profile = &profile;
        options.max_total_working_memory = 0;
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.encodeIntoWithOptions(encoder.output.items[64..][0..h.plain.len], encoder.output.items[512..], options));
        try std.testing.expectEqualSlices(u8, before, encoder.output.items);
        const expected = try h.frozenAlloc(std.testing.allocator, h.frozenOne(setting));
        defer std.testing.allocator.free(expected);
        profile.reset();
        options.max_total_working_memory = null;
        tracked.beginMeasurement();
        const destination = encoder.output.items[512..];
        const pointer = encoder.output.items.ptr;
        const size = try encoder.encodeIntoWithOptions(encoder.output.items[64..][0..h.plain.len], destination, options);
        try std.testing.expectEqual(expected.len, size);
        try std.testing.expectEqualSlices(u8, expected, destination[0..size]);
        try h.untouched(destination[size..]);
        try std.testing.expectEqualSlices(u8, before[0..512], encoder.output.items[0..512]);
        try std.testing.expect(pointer == encoder.output.items.ptr);
        try std.testing.expectEqual(tracked.peak, profile.peak_requested_bytes);
        try std.testing.expectEqual(tracked.live, profile.live_requested_bytes);
    }
}
