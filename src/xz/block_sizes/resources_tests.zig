const std = @import("std");
const xz = @import("../../xz.zig");
const h = @import("test_helpers.zig");
const a = std.testing.allocator;

fn append(api: h.Api, allocator: std.mem.Allocator, output: *std.ArrayList(u8), input: []const u8, opts: xz.EncodeOptions) !usize {
    return switch (api) {
        .compressed => xz.encodeAppend(allocator, output, input, opts),
        .stored => xz.encodeStoredAppend(allocator, output, input, opts),
        .lazy => xz.encodeLazyAppend(allocator, output, input, opts),
    };
}
fn into(api: h.Api, allocator: std.mem.Allocator, input: []const u8, output: []u8, opts: xz.EncodeOptions) !usize {
    return switch (api) {
        .compressed => xz.encodeInto(allocator, input, output, opts),
        .stored => xz.encodeStoredInto(allocator, input, output, opts),
        .lazy => xz.encodeLazyInto(allocator, input, output, opts),
    };
}

test "XZ block sizes Into alias and OOM preserve complete caller spans" {
    for ([_]h.Api{ .compressed, .stored, .lazy }) |api| {
        const input = h.plain;
        const opts = h.options();
        const expected = try h.encode(api, a, input, opts);
        defer a.free(expected);
        const storage = try a.alloc(u8, input.len + expected.len + 33);
        defer a.free(storage);
        @memset(storage, 0xa5);
        @memcpy(storage[16..][0..input.len], input);
        const original = try a.dupe(u8, storage);
        defer a.free(original);
        var denied = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
        try std.testing.expectError(error.OutOfMemory, into(api, denied.allocator(), storage[16..][0..input.len], storage[0..expected.len], opts));
        try std.testing.expectEqualSlices(u8, original, storage);
        try std.testing.expectEqual(expected.len, try into(api, a, storage[16..][0..input.len], storage[0..expected.len], opts));
        try std.testing.expectEqualSlices(u8, expected, storage[0..expected.len]);
        try std.testing.expectEqualSlices(u8, original[expected.len..], storage[expected.len..]);
    }
}

fn allocationGraph(allocator: std.mem.Allocator, api: h.Api, parallel: bool, expected: []const u8) !void {
    var opts = h.options();
    if (parallel) opts.parallel = .{ .io = std.testing.io, .worker_count = 1 };
    var output = std.ArrayList(u8).fromOwnedSlice(try allocator.dupe(u8, h.plain));
    defer output.deinit(allocator);
    _ = append(api, allocator, &output, output.items, opts) catch |err| {
        try std.testing.expectEqualSlices(u8, h.plain, output.items);
        return err;
    };
    try std.testing.expectEqualSlices(u8, h.plain, output.items[0..h.plain.len]);
    try std.testing.expectEqualSlices(u8, expected, output.items[h.plain.len..]);
}

test "XZ block sizes bounded allocation graphs preserve alias append in serial and parallel fallback" {
    for ([_]h.Api{ .compressed, .stored, .lazy }) |api| {
        const expected = try h.encode(api, a, h.plain, h.options());
        defer a.free(expected);
        try std.testing.checkAllAllocationFailures(a, allocationGraph, .{ api, false, expected });
        try std.testing.checkAllAllocationFailures(a, allocationGraph, .{ api, true, expected });
    }
}

test "XZ block sizes parallel direct Into accounts staged payload and exact deterministic budget" {
    const input = try h.fixture(128);
    defer a.free(input);
    const filters = [_]xz.Filter{try xz.Filter.delta(4)};
    var opts = h.options();
    opts.filters = &filters;
    opts.check = .crc32;
    var measured = h.Tracker.init(a);
    var profile: xz.ParallelProfile = .{};
    opts.parallel = .{ .io = std.testing.io, .worker_count = 1, .profile = &profile };
    var storage: [2048]u8 = @splat(0xa5);
    const length = try xz.encodeStoredInto(measured.allocator(), input, &storage, opts);
    const expected = try a.dupe(u8, storage[0..length]);
    defer a.free(expected);
    const peak = profile.peak_requested_bytes;
    try std.testing.expect(peak > 0);
    try std.testing.expectEqual(measured.peak, peak);
    try std.testing.expectEqual(@as(usize, 0), measured.live);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    for ([_]bool{ true, false }) |exact| {
        var ledger = h.Tracker.init(a);
        var current: xz.ParallelProfile = .{};
        var bounded = opts;
        bounded.parallel.?.profile = &current;
        bounded.parallel.?.max_working_memory = if (exact) peak else peak - 1;
        @memset(&storage, 0xa5);
        if (exact) {
            try std.testing.expectEqual(length, try xz.encodeStoredInto(ledger.allocator(), input, &storage, bounded));
            try std.testing.expectEqualSlices(u8, expected, storage[0..length]);
            try h.untouched(storage[length..]);
            try std.testing.expectEqual(peak, current.peak_requested_bytes);
        } else {
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, xz.encodeStoredInto(ledger.allocator(), input, &storage, bounded));
            try h.untouched(&storage);
            try std.testing.expect(current.peak_requested_bytes <= peak - 1);
        }
        try std.testing.expectEqual(@as(usize, 0), ledger.live);
        try std.testing.expectEqual(@as(usize, 0), current.live_requested_bytes);
    }
}
