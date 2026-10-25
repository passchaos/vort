const std = @import("std");
const xz = @import("../../xz.zig");
const h = @import("test_helpers.zig");
const a = std.testing.allocator;

test "XZ parallel invalid options reject before allocator or caller mutation" {
    const invalids = [_]struct { workers: usize = 2, blocks: usize = 4, bytes: usize = 4096 }{
        .{ .workers = 0 }, .{ .workers = 65 }, .{ .blocks = 0 }, .{ .bytes = 0 },
    };
    for (invalids) |invalid| {
        var ledger = h.TrackingAllocator.init(a);
        ledger.fail_after = 0;
        var profile: xz.ParallelProfile = .{};
        var opts = h.options();
        opts.parallel = h.parallel(&profile);
        opts.parallel.?.worker_count = invalid.workers;
        opts.parallel.?.max_inflight_blocks = invalid.blocks;
        opts.parallel.?.max_inflight_bytes = invalid.bytes;
        var output: [1024]u8 = @splat(0xa5);
        try std.testing.expectError(error.InvalidBlockPlan, xz.encodeInto(ledger.allocator(), h.plain, &output, opts));
        try h.untouched(&output);
        var appended = std.ArrayList(u8).fromOwnedSlice(try a.dupe(u8, "caller-prefix"));
        defer appended.deinit(a);
        try std.testing.expectError(error.InvalidBlockPlan, xz.encodeAppend(ledger.allocator(), &appended, h.plain, opts));
        try std.testing.expectEqualStrings("caller-prefix", appended.items);
        try std.testing.expectEqual(@as(usize, 0), ledger.attempts);
        try std.testing.expectEqual(@as(usize, 0), ledger.live);
    }
}

test "XZ parallel effective longest block cannot shrink to fit inflight bytes" {
    var opts = h.options();
    opts.block_size = 64;
    var profile: xz.ParallelProfile = .{};
    opts.parallel = h.parallel(&profile);
    opts.parallel.?.max_inflight_bytes = 63;
    var output: [1024]u8 = @splat(0xa5);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, xz.encodeInto(a, h.plain, &output, opts));
    try h.untouched(&output);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    // A short single block uses its actual length, not configured capacity.
    opts.block_size = 1024 * 1024;
    opts.parallel.?.max_inflight_bytes = 5;
    profile = .{};
    const wire = try xz.encodeAlloc(a, "short", opts);
    defer a.free(wire);
    try std.testing.expect(profile.serial_fallback);
    try h.checkWire(wire, "short", opts);
}

test "XZ parallel deterministic worker one exact total budget and below preserve output" {
    const chain = [_]xz.Filter{ xz.Filter.x86(3), try xz.Filter.delta(4) };
    for ([_]xz.Parser{ .fast, .normal }) |parser| {
        var opts = h.options();
        opts.block_size = 512;
        opts.parser = parser;
        opts.filters = &chain;
        opts.match_options.?.finder = if (parser == .normal) .bt4 else .hc4;
        var measured = h.TrackingAllocator.init(a);
        var profile: xz.ParallelProfile = .{};
        opts.parallel = h.parallel(&profile);
        opts.parallel.?.worker_count = 1;
        const expected = try xz.encodeAlloc(measured.allocator(), h.plain, opts);
        defer measured.allocator().free(expected);
        const peak = profile.peak_requested_bytes;
        try std.testing.expect(peak > 0);
        try std.testing.expect(profile.serial_fallback);
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
        for ([_]bool{ true, false }) |exact| {
            var ledger = h.TrackingAllocator.init(a);
            var current: xz.ParallelProfile = .{};
            var bounded = opts;
            bounded.parallel.?.profile = &current;
            bounded.parallel.?.max_working_memory = if (exact) peak else peak - 1;
            if (exact) {
                const wire = try xz.encodeAlloc(ledger.allocator(), h.plain, bounded);
                try std.testing.expectEqualSlices(u8, expected, wire);
                try std.testing.expectEqual(peak, current.peak_requested_bytes);
                ledger.allocator().free(wire);
            } else {
                var output: [1024]u8 = @splat(0xa5);
                try std.testing.expectError(error.WorkingMemoryLimitExceeded, xz.encodeInto(ledger.allocator(), h.plain, &output, bounded));
                try h.untouched(&output);
                var appended = std.ArrayList(u8).fromOwnedSlice(try a.dupe(u8, "caller-prefix"));
                defer appended.deinit(a);
                current = .{};
                try std.testing.expectError(error.WorkingMemoryLimitExceeded, xz.encodeAppend(ledger.allocator(), &appended, h.plain, bounded));
                try std.testing.expectEqualStrings("caller-prefix", appended.items);
                try std.testing.expect(current.peak_requested_bytes <= peak - 1);
            }
            try std.testing.expectEqual(@as(usize, 0), current.live_requested_bytes);
            try std.testing.expectEqual(@as(usize, 0), ledger.live);
        }
    }
}

test "XZ parallel alias publication and worker OOM join preserve caller allocation" {
    if (!h.threadedTarget()) return error.SkipZigTest;
    const input = try h.fixtureAlloc(a, 512, 4);
    defer a.free(input);
    for ([_]h.Api{ .compressed, .stored, .lazy }) |api| {
        var opts = h.options();
        const expected = try h.encodeAlloc(api, a, input, opts);
        defer a.free(expected);
        var profile: xz.ParallelProfile = .{};
        opts.parallel = h.parallel(&profile);
        var ledger = h.TrackingAllocator.init(a);
        var appended = std.ArrayList(u8).fromOwnedSlice(try ledger.allocator().dupe(u8, input));
        var alive = true;
        defer if (alive) appended.deinit(ledger.allocator());
        const pointer = appended.items.ptr;
        const capacity = appended.capacity;
        ledger.fail_worker = true;
        try std.testing.expectError(error.OutOfMemory, h.encodeAppend(api, ledger.allocator(), &appended, appended.items, opts));
        try std.testing.expect(ledger.worker_refusals != 0);
        try std.testing.expectEqual(pointer, appended.items.ptr);
        try std.testing.expectEqual(capacity, appended.capacity);
        try std.testing.expectEqualSlices(u8, input, appended.items);
        try std.testing.expectEqual(capacity, ledger.live);
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
        ledger.fail_worker = false;
        profile = .{};
        try std.testing.expectEqual(expected.len, try h.encodeAppend(api, ledger.allocator(), &appended, appended.items, opts));
        try std.testing.expectEqualSlices(u8, input, appended.items[0..input.len]);
        try std.testing.expectEqualSlices(u8, expected, appended.items[input.len..]);
        appended.deinit(ledger.allocator());
        alive = false;
        try std.testing.expectEqual(@as(usize, 0), ledger.live);
        const storage = try a.alloc(u8, input.len + expected.len + 33);
        defer a.free(storage);
        @memset(storage, 0xa5);
        @memcpy(storage[16..][0..input.len], input);
        const old = try a.dupe(u8, storage);
        defer a.free(old);
        ledger.fail_worker = true;
        profile = .{};
        try std.testing.expectError(error.OutOfMemory, h.encodeInto(api, ledger.allocator(), storage[16..][0..input.len], storage[0..expected.len], opts));
        try std.testing.expectEqualSlices(u8, old, storage);
        try std.testing.expectEqual(@as(usize, 0), ledger.live);
        ledger.fail_worker = false;
        profile = .{};
        try std.testing.expectEqual(expected.len, try h.encodeInto(api, ledger.allocator(), storage[16..][0..input.len], storage[0..expected.len], opts));
        try std.testing.expectEqualSlices(u8, expected, storage[0..expected.len]);
        try std.testing.expectEqualSlices(u8, old[expected.len..], storage[expected.len..]);
        try std.testing.expectEqual(@as(usize, 0), ledger.live);
    }
}

test "XZ parallel worker match budget errors preserve staged publication and clean pool" {
    var profile: xz.ParallelProfile = .{};
    var opts = h.options();
    opts.block_size = 64;
    opts.parallel = h.parallel(&profile);
    opts.match_options.?.max_working_memory = 0;
    var ledger = h.TrackingAllocator.init(a);
    var output: [1024]u8 = @splat(0xa5);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, xz.encodeInto(ledger.allocator(), h.plain, &output, opts));
    try h.untouched(&output);
    try std.testing.expectEqual(@as(usize, 0), ledger.live);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    if (h.threadedTarget()) try std.testing.expect(profile.workers_started != 0);
    var appended = std.ArrayList(u8).fromOwnedSlice(try a.dupe(u8, "caller-prefix"));
    defer appended.deinit(a);
    profile = .{};
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, xz.encodeAppend(ledger.allocator(), &appended, h.plain, opts));
    try std.testing.expectEqualStrings("caller-prefix", appended.items);
    try std.testing.expectEqual(@as(usize, 0), ledger.live);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
}

fn allocationCampaign(api: h.Api, worker_count: usize) !void {
    const input = "bounded allocation graph keeps worker cleanup deterministic" ** 2;
    var opts = h.options();
    opts.block_size = if (worker_count == 1) input.len else 32;
    const chain = [_]xz.Filter{try xz.Filter.delta(4)};
    opts.filters = &chain;
    var baseline = h.TrackingAllocator.init(a);
    var base_profile: xz.ParallelProfile = .{};
    opts.parallel = h.parallel(&base_profile);
    opts.parallel.?.worker_count = worker_count;
    opts.parallel.?.max_inflight_blocks = 2;
    const expected = try h.encodeAlloc(api, baseline.allocator(), input, opts);
    const attempts = baseline.attempts;
    const oracle = try a.dupe(u8, expected);
    defer a.free(oracle);
    baseline.allocator().free(expected);
    try std.testing.expectEqual(@as(usize, 0), baseline.live);
    for (0..attempts + 1) |fail_after| {
        var ledger = h.TrackingAllocator.init(a);
        ledger.fail_after = fail_after;
        var profile: xz.ParallelProfile = .{};
        opts.parallel.?.profile = &profile;
        if (h.encodeAlloc(api, ledger.allocator(), input, opts)) |wire| {
            try std.testing.expectEqualSlices(u8, oracle, wire);
            ledger.allocator().free(wire);
        } else |err| try std.testing.expectEqual(error.OutOfMemory, err);
        try std.testing.expectEqual(@as(usize, 0), ledger.live);
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    }
}

test "XZ parallel bounded full allocation graphs clean real pool and compressed fallback" {
    try allocationCampaign(.stored, 2);
    try allocationCampaign(.compressed, 1);
}
