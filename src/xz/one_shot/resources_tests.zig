const std = @import("std");
const xz = @import("../../xz.zig");
const h = @import("test_helpers.zig");
const allocator = std.testing.allocator;

test "XZ one-shot resources size only inspect and Into do not materialize a multi MiB plaintext workspace" {
    const frame = try h.decodeHex(allocator, h.large_hex);
    defer allocator.free(frame);
    const plain = try h.patternAlloc(allocator, h.plain_pattern, h.large_len);
    defer allocator.free(plain);
    const output = try allocator.alloc(u8, plain.len);
    defer allocator.free(output);
    var tracking = std.testing.FailingAllocator.init(allocator, .{});
    var workspace = try xz.DecodeWorkspace.initWithOptions(tracking.allocator(), .{ .max_working_memory = 256 * 1024 });
    defer workspace.deinit();
    try std.testing.expectEqual(@as(usize, 0), tracking.allocated_bytes);
    try std.testing.expectEqual(plain.len, try workspace.decodedSize(frame));
    try std.testing.expect(workspace.workingMemoryBytes() < 256 * 1024);
    try std.testing.expect(workspace.snapshot().retained_dictionary_capacity <= 4096);
    try std.testing.expectEqual(plain.len, (try workspace.inspect(frame)).uncompressed_size);
    try std.testing.expectEqual(plain.len, try workspace.decodeInto(frame, output));
    try std.testing.expectEqualSlices(u8, plain, output);
    try h.expectLedger(&workspace, tracking.allocator());
    var storage: [256 * 1024]u8 = undefined;
    var bounded = std.heap.FixedBufferAllocator.init(&storage);
    try std.testing.expectEqual(plain.len, try xz.decodedSize(bounded.allocator(), frame));
    bounded.reset();
    try std.testing.expectEqual(plain.len, (try xz.inspect(bounded.allocator(), frame)).uncompressed_size);
    bounded.reset();
    try std.testing.expectEqual(plain.len, try xz.decodeInto(bounded.allocator(), frame, output));
    try std.testing.expectEqualSlices(u8, plain, output);
}

test "XZ one-shot resources variable models dictionaries and filters replay and reprepare without allocation after warmup" {
    const frame = try h.decodeHex(allocator, h.variable_hex);
    defer allocator.free(frame);
    const plain = try h.variablePlainAlloc(allocator);
    defer allocator.free(plain);
    const output = try allocator.alloc(u8, plain.len);
    defer allocator.free(output);
    var tracking = std.testing.FailingAllocator.init(allocator, .{});
    var workspace = xz.DecodeWorkspace.init(tracking.allocator());
    defer workspace.deinit();
    try std.testing.expectEqual(plain.len, try workspace.prepare(frame, .single));
    try std.testing.expect(workspace.snapshot().retained_probability_bytes >= 0x300 * 31 * @sizeOf(u16));
    const allocations = tracking.alloc_index;
    const resizes = tracking.resize_index;
    tracking.fail_index = allocations;
    tracking.resize_fail_index = resizes;
    @memset(output, 0xa5);
    try std.testing.expectEqual(plain.len, try workspace.replayInto(output));
    try std.testing.expectEqualSlices(u8, plain, output);
    try std.testing.expectEqual(allocations, tracking.alloc_index);
    try std.testing.expect(!tracking.has_induced_failure);
    const live = workspace.workingMemoryBytes();
    workspace.reset();
    try std.testing.expectEqual(live, workspace.workingMemoryBytes());
    try std.testing.expectEqual(live, workspace.peakWorkingMemoryBytes());
    try std.testing.expectError(error.InvalidBlockPlan, workspace.replayInto(output));
    try std.testing.expectEqual(plain.len, try workspace.prepare(frame, .single));
    try std.testing.expectEqual(plain.len, try workspace.replayInto(output));
    try std.testing.expectEqual(allocations, tracking.alloc_index);
    try h.expectLedger(&workspace, tracking.allocator());
}

test "XZ one-shot resources exact and below working budget follow the same deterministic allocator schedule" {
    const frame = try h.decodeHex(allocator, h.variable_hex);
    defer allocator.free(frame);
    const plain = try h.variablePlainAlloc(allocator);
    defer allocator.free(plain);
    const output = try allocator.alloc(u8, plain.len);
    defer allocator.free(output);
    var backing_storage: [512 * 1024]u8 = undefined;
    var backing = std.heap.FixedBufferAllocator.init(&backing_storage);
    var baseline = xz.DecodeWorkspace.init(backing.allocator());
    try std.testing.expectEqual(plain.len, try baseline.decodeInto(frame, output));
    const peak = baseline.peakWorkingMemoryBytes();
    baseline.deinit();
    for ([_]bool{ true, false }) |exact| {
        backing.reset();
        var workspace = try xz.DecodeWorkspace.initWithOptions(backing.allocator(), .{ .max_working_memory = peak - @intFromBool(!exact) });
        defer workspace.deinit();
        @memset(output, 0xa5);
        if (exact) {
            try std.testing.expectEqual(plain.len, try workspace.decodeInto(frame, output));
            try std.testing.expectEqualSlices(u8, plain, output);
        } else {
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, workspace.decodeInto(frame, output));
            try h.expectSentinel(output);
        }
        try h.expectLedger(&workspace, null);
    }
}

fn allocationGraph(wrapped: std.mem.Allocator, frame: []const u8, plain: []const u8) !void {
    var workspace = xz.DecodeWorkspace.init(wrapped);
    var transferred = false;
    defer if (!transferred) workspace.deinit();
    const output = try allocator.alloc(u8, plain.len);
    defer allocator.free(output);
    @memset(output, 0xa5);
    const decoded = workspace.decodeInto(frame, output) catch |err| {
        try h.expectSentinel(output);
        try h.expectLedger(&workspace, wrapped);
        return err;
    };
    try std.testing.expectEqual(plain.len, decoded);
    try std.testing.expectEqualSlices(u8, plain, output);
    const live = workspace.workingMemoryBytes();
    workspace.reset();
    try std.testing.expectEqual(live, workspace.workingMemoryBytes());
    @memset(output, 0xa5);
    _ = workspace.prepare(frame, .single) catch |err| {
        try h.expectSentinel(output);
        return err;
    };
    var moved = workspace;
    transferred = true;
    workspace = undefined;
    defer moved.deinit();
    _ = moved.replayInto(output) catch |err| {
        try h.expectSentinel(output);
        return err;
    };
    try std.testing.expectEqualSlices(u8, plain, output);
    try h.expectLedger(&moved, wrapped);
    try moved.resetWithOptions(.{ .max_working_memory = 256 * 1024 });
    try std.testing.expectEqual(@as(usize, 0), moved.workingMemoryBytes());
    try std.testing.expectEqual(@as(usize, 0), moved.peakWorkingMemoryBytes());
}

test "XZ one-shot resources every allocation failure leaves caller bytes intact and teardown balances moved ownership" {
    const frame = try h.decodeHex(allocator, h.variable_hex);
    defer allocator.free(frame);
    const plain = try h.variablePlainAlloc(allocator);
    defer allocator.free(plain);
    try std.testing.checkAllAllocationFailures(allocator, allocationGraph, .{ frame, plain });
}

test "XZ one-shot resources overlap copy OOM is prepublication and warm replay needs no later allocation" {
    const frame = try h.decodeHex(allocator, h.fixtures[2].hex);
    defer allocator.free(frame);
    const plain = try h.patternAlloc(allocator, h.fixtures[2].pattern, h.fixtures[2].raw_len);
    defer allocator.free(plain);
    const shared = try allocator.alloc(u8, plain.len + 17);
    defer allocator.free(shared);
    @memset(shared, 0xa5);
    @memcpy(shared[0..frame.len], frame);
    const before = try allocator.dupe(u8, shared);
    defer allocator.free(before);
    var tracking = std.testing.FailingAllocator.init(allocator, .{});
    {
        var workspace = xz.DecodeWorkspace.init(tracking.allocator());
        defer workspace.deinit();
        _ = try workspace.prepare(frame, .single);
        try std.testing.expectEqual(@as(usize, 0), workspace.snapshot().retained_input_capacity);
        tracking.fail_index = tracking.alloc_index;
        try std.testing.expectError(error.OutOfMemory, workspace.decodeInto(shared[0..frame.len], shared));
        try std.testing.expectEqualSlices(u8, before, shared);
        try std.testing.expect(!workspace.snapshot().prepared);
        try h.expectLedger(&workspace, tracking.allocator());
        tracking.fail_index = std.math.maxInt(usize);
        _ = try workspace.prepareInto(shared[0..frame.len], shared, .single);
        const allocations = tracking.alloc_index;
        tracking.fail_index = allocations;
        try std.testing.expectEqual(plain.len, try workspace.replayInto(shared));
        try std.testing.expectEqual(allocations, tracking.alloc_index);
        try std.testing.expectEqualSlices(u8, plain, shared[0..plain.len]);
        try h.expectSentinel(shared[plain.len..]);
    }
    try std.testing.expectEqual(tracking.allocated_bytes, tracking.freed_bytes);
}

test "XZ one-shot resources empty streams and concatenated padding need no heap under zero limits" {
    const empty = try h.decodeHex(allocator, h.empty_hex);
    defer allocator.free(empty);
    const joined = try std.mem.concat(allocator, u8, &.{ empty, &.{ 0, 0, 0, 0 }, empty });
    defer allocator.free(joined);
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    var workspace = try xz.DecodeWorkspace.initWithOptions(failing.allocator(), .{
        .max_output_len = 0,
        .max_dictionary_size = 0,
        .max_working_memory = 0,
    });
    defer workspace.deinit();
    try std.testing.expectEqual(@as(usize, 0), try workspace.decodeInto(empty, &.{}));
    try std.testing.expectEqual(@as(usize, 0), try workspace.decodedSizeConcatenated(joined));
    try std.testing.expectEqual(@as(usize, 0), try workspace.replayInto(&.{}));
    try std.testing.expectEqual(@as(usize, 2), workspace.snapshot().stream_count);
    try std.testing.expectEqual(@as(usize, 0), workspace.workingMemoryBytes());
    try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
    try std.testing.expect(!failing.has_induced_failure);
}
