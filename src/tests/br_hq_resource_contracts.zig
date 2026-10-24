const std = @import("std");
const br = @import("../br.zig");
const h = @import("br_hq_helpers.zig");
const allocator = std.testing.allocator;

test "Brotli HQ exact matcher parser budget succeeds and one byte below preserves caller output" {
    var profile: br.HqProfile = .{};
    const options: br.PlannedEncodeOptions = .{ .quality = 10, .hq = .{ .profile = &profile } };
    const baseline = try br.encodePlannedStreamWithOptionsAlloc(allocator, h.legacy_plain, options);
    defer allocator.free(baseline);
    const peak = profile.peak_working_memory;
    try std.testing.expect(peak > 0);
    var exact_options = options;
    exact_options.hq.?.max_working_memory = peak;
    profile.reset();
    const exact = try br.encodePlannedStreamWithOptionsAlloc(allocator, h.legacy_plain, exact_options);
    defer allocator.free(exact);
    try std.testing.expectEqualSlices(u8, baseline, exact);
    try std.testing.expectEqual(peak, profile.peak_working_memory);
    exact_options.hq.?.max_working_memory = peak - 1;
    var output: [1024]u8 = @splat(0xa5);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, br.encodePlannedStreamWithOptionsInto(h.legacy_plain, &output, exact_options));
    try h.sentinel(&output);
}

test "Brotli HQ invalid quality combinations reject before allocation or destination writes" {
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    var output: [128]u8 = @splat(0xa5);
    for ([_]br.PlannedEncodeOptions{
        .{ .hq = .{} },
        .{ .quality = 9, .hq = .{} },
        .{ .quality = 12, .hq = .{} },
        .{ .quality = 10, .level = .balanced, .hq = .{} },
        .{ .quality = 10, .hq = .{ .search_depth = 0 } },
        .{ .quality = 10, .window_bits = 9, .hq = .{} },
        .{ .quality = 10, .hq = .{ .block_len = 0 } },
    }) |options| {
        try std.testing.expectError(error.InvalidBlockPlan, br.encodePlannedStreamWithOptionsAlloc(failing.allocator(), "HQ", options));
        try std.testing.expectError(error.InvalidBlockPlan, br.encodePlannedStreamWithOptionsInto("HQ", &output, options));
        try h.sentinel(&output);
    }
    try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
    try std.testing.expect(!failing.has_induced_failure);
}

const AllocationGraph = struct {
    pub fn run(backing: std.mem.Allocator, input: []const u8) !void {
        var output = std.ArrayList(u8).fromOwnedSlice(try backing.dupe(u8, input));
        defer output.deinit(backing);
        var profile: br.HqProfile = .{};
        const before = profile.emitted();
        const chunks = [_][]const u8{output.items};
        br.encodePlannedStreamChunksWithOptionsAppend(backing, &output, &chunks, .{ .quality = 10, .hq = .{ .profile = &profile } }) catch |err| {
            try std.testing.expectEqualSlices(u8, input, output.items);
            try std.testing.expectEqualDeep(before, profile.emitted());
            return err;
        };
        try std.testing.expectEqualSlices(u8, input, output.items[0..input.len]);
        const decoded = try br.decodeStreamAlloc(allocator, output.items[input.len..]);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }
};

test "Brotli HQ short allocation failures preserve caller alias and emitted profile counters" {
    try std.testing.checkAllAllocationFailures(allocator, AllocationGraph.run, .{h.legacy_plain[0..64]});
}

test "Brotli HQ moving scratch output preserves aliased outer input and dictionary descriptors" {
    var ledger = h.HeapLedger.init(allocator, std.math.maxInt(usize));
    ledger.force_moving_growth = true;
    const backing = ledger.allocator();
    {
        var reusable = br.PlannedStreamEncoder.init(backing);
        defer reusable.deinit();
        try reusable.output.resize(backing, 320);
        @memset(reusable.output.items, 0);
        var expected: [64]u8 = undefined;
        for (&expected, 0..) |*byte, index| byte.* = @intCast(index);
        @memcpy(reusable.output.items[128..192], &expected);
        @memcpy(reusable.output.items[256..320], &expected);
        const chunks: *[2][]const u8 = @ptrCast(@alignCast(reusable.output.items.ptr));
        chunks.* = .{ reusable.output.items[128..160], reusable.output.items[160..192] };
        const prefixes: *[2][]const u8 = @ptrCast(@alignCast(reusable.output.items.ptr + 32));
        prefixes.* = .{ reusable.output.items[256..288], reusable.output.items[288..320] };
        var profile: br.HqProfile = .{};
        const bytes = try reusable.encodeChunksScratchWithOptions(chunks, .{
            .quality = 10,
            .shared_dictionary = .{ .raw_prefixes = prefixes },
            .hq = .{ .profile = &profile },
        });
        const decoded = try br.decodeStreamAllocWithOptions(allocator, bytes, .{
            .shared_dictionary = .{ .raw_prefixes = &.{ expected[0..32], expected[32..] } },
        });
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, &expected, decoded);
        try std.testing.expect(profile.compound_probes > 0);
    }
    try std.testing.expectEqual(@as(usize, 0), ledger.live);
    try std.testing.expect(ledger.peak > 0);
}
