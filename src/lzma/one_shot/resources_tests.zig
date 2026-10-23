const std = @import("std");
const decoder = @import("../decoder.zig");
const fixtures = @import("test_helpers.zig");
const allocator = fixtures.allocator;
const Workspace = decoder.DecodeWorkspace;

fn expectBudget(workspace: *const Workspace) !void {
    const snap = workspace.snapshot();
    try std.testing.expectEqual(@as(usize, 0), snap.retained_decoded_capacity);
    try std.testing.expectEqual(snap.probability_capacity + snap.dictionary_capacity + snap.input_copy_capacity, snap.working_bytes);
    try std.testing.expectEqual(snap.working_bytes, workspace.workingMemoryBytes());
    try std.testing.expectEqual(snap.peak_working_bytes, workspace.peakWorkingMemoryBytes());
    try std.testing.expect(snap.working_bytes <= snap.peak_working_bytes);
    try std.testing.expect(snap.peak_working_bytes <= workspace.options.max_working_memory);
}

test "LZMA one shot resources multiple MiB dictionary wrap needs no plaintext allocation" {
    const encoded = fixtures.largeEos();
    var workspace = try Workspace.initWithOptions(allocator, .{
        .max_dictionary_size = 4096,
        .max_output_len = fixtures.large_len,
        .max_working_memory = 64 * 1024,
    });
    defer workspace.deinit();
    try std.testing.expectEqual(@as(usize, 0), workspace.workingMemoryBytes());
    try std.testing.expectEqual(fixtures.large_len, try workspace.decodedSize(&encoded));
    try expectBudget(&workspace);
    try std.testing.expectEqual(@as(usize, 4096), workspace.snapshot().dictionary_capacity);
    try std.testing.expectEqual(@as(usize, 1536 << 3), workspace.snapshot().probability_capacity);
    try std.testing.expectEqual(@as(usize, 0), workspace.snapshot().input_copy_capacity);
    const output = try allocator.alloc(u8, fixtures.large_len);
    defer allocator.free(output);
    @memset(output, 0xa5);
    try std.testing.expectEqual(output.len, try workspace.decodeInto(&encoded, output));
    try fixtures.expectLarge(output);
    try expectBudget(&workspace);
    try std.testing.expect(workspace.peakWorkingMemoryBytes() < fixtures.large_len / 16);
    try std.testing.expectEqual(fixtures.large_len, try decoder.decodedSizeWithOptions(allocator, &encoded, .{ .max_dictionary_size = 4096, .max_working_memory = 64 * 1024 }));
    // Allocating APIs charge their returned plaintext to the working budget.
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, decoder.decodeAllocWithOptions(allocator, &encoded, .{ .max_working_memory = 64 * 1024 }));
    @memset(output, 0xa5);
    try std.testing.expectError(error.OutputTooSmall, workspace.decodeInto(&encoded, output[0 .. output.len - 1]));
    try fixtures.sentinel(output);
    try std.testing.expectError(error.OutputLimitExceeded, workspace.decodedSizeLimited(&encoded, fixtures.large_len - 1));
}

test "LZMA one shot resources cold peak exact below and reconfiguration release owned capacities" {
    const encoded = fixtures.known();
    var baseline = Workspace.init(allocator);
    defer baseline.deinit();
    var output: [fixtures.known_plain.len]u8 = @splat(0xa5);
    try std.testing.expectEqual(output.len, try baseline.decodeInto(&encoded, &output));
    const peak = baseline.peakWorkingMemoryBytes();
    const live = baseline.workingMemoryBytes();
    try expectBudget(&baseline);
    inline for (.{ false, true }) |below| {
        var workspace = try Workspace.initWithOptions(allocator, .{ .max_working_memory = peak - @intFromBool(below) });
        defer workspace.deinit();
        @memset(&output, 0xa5);
        if (below) {
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, workspace.decodeInto(&encoded, &output));
            try fixtures.sentinel(&output);
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, decoder.decodeIntoWithOptions(allocator, &encoded, &output, .{ .max_working_memory = peak - 1 }));
            try fixtures.sentinel(&output);
        } else {
            try std.testing.expectEqual(output.len, try workspace.decodeInto(&encoded, &output));
            try std.testing.expectEqualSlices(u8, fixtures.known_plain, &output);
            try std.testing.expectEqual(peak, workspace.peakWorkingMemoryBytes());
            @memset(&output, 0xa5);
            try std.testing.expectEqual(output.len, try decoder.decodeIntoWithOptions(allocator, &encoded, &output, .{ .max_working_memory = peak }));
            try std.testing.expectEqualSlices(u8, fixtures.known_plain, &output);
        }
        try expectBudget(&workspace);
    }
    baseline.resetRetaining();
    try std.testing.expectEqual(live, baseline.workingMemoryBytes());
    try std.testing.expectEqual(live, baseline.peakWorkingMemoryBytes());
    try std.testing.expectEqual(@as(usize, 0), baseline.snapshot().last_decoded_len);
    @memset(&output, 0xa5);
    try std.testing.expectEqual(output.len, try baseline.decodeInto(&encoded, &output));
    try std.testing.expectEqual(live, baseline.peakWorkingMemoryBytes());
    try baseline.resetWithOptions(.{ .max_working_memory = 0 });
    try std.testing.expectEqual(@as(usize, 0), baseline.workingMemoryBytes());
    try std.testing.expectEqual(@as(usize, 0), baseline.peakWorkingMemoryBytes());
    @memset(&output, 0xa5);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, baseline.decodeInto(&encoded, &output));
    try fixtures.sentinel(&output);
    try baseline.resetWithOptions(.{ .max_working_memory = peak });
    try std.testing.expectEqual(output.len, try baseline.decodeInto(&encoded, &output));
    try std.testing.expectEqualSlices(u8, fixtures.known_plain, &output);
}

const Operation = enum { alone, micro, zip, alias, legacy_alone, legacy_micro, legacy_zip, legacy_alias };
fn AllocationGraph(comptime operation: Operation) type {
    return struct {
        pub fn run(backing: std.mem.Allocator, input: []const u8, expected: []const u8) !void {
            var workspace = Workspace.init(backing);
            defer workspace.deinit();
            var output: [fixtures.small_plain.len]u8 = @splat(0xa5);
            if (operation == .alias or operation == .legacy_alias) @memcpy(output[0..input.len], input);
            const original = output;
            const result: anyerror!void = switch (operation) {
                .alone => blk: {
                    _ = workspace.decodeInto(input, output[0..expected.len]) catch |err| break :blk err;
                    break :blk {};
                },
                .micro => workspace.decodeMicroInto(input, output[0..expected.len], 32 * 1024),
                .zip => blk: {
                    _ = workspace.decodeZipPayloadInto(input, expected.len, output[0..expected.len], 4096, false) catch |err| break :blk err;
                    break :blk {};
                },
                .alias => blk: {
                    _ = workspace.decodeInto(output[0..input.len], output[0..expected.len]) catch |err| break :blk err;
                    break :blk {};
                },
                .legacy_alone => blk: {
                    _ = decoder.decodeInto(backing, input, output[0..expected.len]) catch |err| break :blk err;
                    break :blk {};
                },
                .legacy_micro => decoder.decodeMicroInto(backing, input, output[0..expected.len], 32 * 1024),
                .legacy_zip => blk: {
                    _ = decoder.decodeZipPayloadInto(backing, input, expected.len, output[0..expected.len], 4096, false) catch |err| break :blk err;
                    break :blk {};
                },
                .legacy_alias => blk: {
                    _ = decoder.decodeInto(backing, output[0..input.len], output[0..expected.len]) catch |err| break :blk err;
                    break :blk {};
                },
            };
            result catch |err| {
                try std.testing.expectEqualSlices(u8, &original, &output);
                try expectBudget(&workspace);
                const ledger: *std.testing.FailingAllocator = @ptrCast(@alignCast(backing.ptr));
                try std.testing.expectEqual(ledger.allocated_bytes - ledger.freed_bytes, workspace.workingMemoryBytes());
                return err;
            };
            try std.testing.expectEqualSlices(u8, expected, output[0..expected.len]);
            try fixtures.sentinel(output[expected.len..]);
            try expectBudget(&workspace);
        }
    };
}

test "LZMA one shot resources every allocation failure preserves caller bytes including alias scratch" {
    const known = fixtures.known();
    const micro = fixtures.micro();
    const zip = try fixtures.zipFromAlone(&known);
    defer allocator.free(zip);
    try std.testing.checkAllAllocationFailures(allocator, AllocationGraph(.alone).run, .{ known[0..], fixtures.known_plain[0..] });
    try std.testing.checkAllAllocationFailures(allocator, AllocationGraph(.micro).run, .{ micro[0..], fixtures.micro_plain[0..] });
    try std.testing.checkAllAllocationFailures(allocator, AllocationGraph(.zip).run, .{ zip, fixtures.known_plain[0..] });
    try std.testing.checkAllAllocationFailures(allocator, AllocationGraph(.alias).run, .{ known[0..], fixtures.known_plain[0..] });
    try std.testing.checkAllAllocationFailures(allocator, AllocationGraph(.legacy_alone).run, .{ known[0..], fixtures.known_plain[0..] });
    try std.testing.checkAllAllocationFailures(allocator, AllocationGraph(.legacy_micro).run, .{ micro[0..], fixtures.micro_plain[0..] });
    try std.testing.checkAllAllocationFailures(allocator, AllocationGraph(.legacy_zip).run, .{ zip, fixtures.known_plain[0..] });
    try std.testing.checkAllAllocationFailures(allocator, AllocationGraph(.legacy_alias).run, .{ known[0..], fixtures.known_plain[0..] });
}

test "LZMA one shot resources warm workspace survives failed property growth reset and poisoned value move" {
    const known = fixtures.known();
    const wider = fixtures.knownWide();
    const lp = fixtures.lpEos();
    var failing = std.testing.FailingAllocator.init(allocator, .{});
    {
        var original = try Workspace.initWithOptions(failing.allocator(), .{ .max_working_memory = 64 * 1024 });
        try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
        try std.testing.expectEqual(fixtures.known_plain.len, try original.decodedSize(&known));
        const first = original.snapshot();
        try std.testing.expectEqual(@as(usize, 1536 << 3), first.probability_capacity);
        const allocation_count = failing.alloc_index;
        const resize_count = failing.resize_index;
        failing.fail_index = allocation_count;
        failing.resize_fail_index = resize_count;
        var output: [fixtures.small_plain.len]u8 = @splat(0xa5);
        try std.testing.expectError(error.OutOfMemory, original.decodeInto(&wider, output[0..fixtures.known_plain.len]));
        try fixtures.sentinel(&output);
        try std.testing.expectEqual(first.probability_capacity, original.snapshot().probability_capacity);
        try std.testing.expectEqual(first.working_bytes, original.workingMemoryBytes());
        original.reset();
        try std.testing.expectEqual(first.working_bytes, original.peakWorkingMemoryBytes());
        try std.testing.expectEqual(fixtures.known_plain.len, try original.decodeInto(&known, output[0..fixtures.known_plain.len]));
        try std.testing.expectEqualSlices(u8, fixtures.known_plain, output[0..fixtures.known_plain.len]);
        try std.testing.expectEqual(allocation_count, failing.alloc_index);
        try std.testing.expectEqual(resize_count, failing.resize_index);
        var workspace = original;
        @memset(std.mem.asBytes(&original), 0xa5);
        defer workspace.deinit();
        @memset(&output, 0xa5);
        try std.testing.expectEqual(fixtures.known_plain.len, try workspace.decodeInto(&known, output[0..fixtures.known_plain.len]));
        try std.testing.expectEqual(allocation_count, failing.alloc_index);
        try expectBudget(&workspace);
        failing.fail_index = std.math.maxInt(usize);
        failing.resize_fail_index = std.math.maxInt(usize);
        try std.testing.expectEqual(fixtures.known_plain.len, try workspace.decodeInto(&wider, output[0..fixtures.known_plain.len]));
        const wide = workspace.snapshot();
        try std.testing.expectEqual(@as(usize, 1536 << 4), wide.probability_capacity);
        try std.testing.expect(wide.peak_working_bytes >= wide.working_bytes + first.probability_capacity);
        try std.testing.expectEqual(fixtures.small_plain.len, try workspace.decodeInto(&lp, &output));
        try std.testing.expectEqualSlices(u8, fixtures.small_plain, &output);
        const warmed = failing.alloc_index;
        failing.fail_index = warmed;
        failing.resize_fail_index = failing.resize_index;
        try std.testing.expectEqual(fixtures.small_plain.len, try workspace.decodedSize(&lp));
        @memset(&output, 0xa5);
        try std.testing.expectEqual(output.len, try workspace.decodeInto(&lp, &output));
        try std.testing.expectEqualSlices(u8, fixtures.small_plain, &output);
        try std.testing.expectEqual(warmed, failing.alloc_index);
        try expectBudget(&workspace);
        try std.testing.expectEqual(failing.allocated_bytes - failing.freed_bytes, workspace.workingMemoryBytes());
    }
    try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
}

test "LZMA one shot resources alias copy budget denial is atomic and reusable" {
    const known = fixtures.known();
    var baseline = Workspace.init(allocator);
    defer baseline.deinit();
    try std.testing.expectEqual(fixtures.known_plain.len, try baseline.decodedSize(&known));
    const retained = baseline.workingMemoryBytes();
    var workspace = try Workspace.initWithOptions(allocator, .{ .max_working_memory = retained });
    defer workspace.deinit();
    try std.testing.expectEqual(fixtures.known_plain.len, try workspace.decodedSize(&known));
    var output: [fixtures.known_plain.len]u8 = @splat(0xa5);
    @memcpy(output[0..known.len], &known);
    const original = output;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, workspace.decodeInto(output[0..known.len], &output));
    try std.testing.expectEqualSlices(u8, &original, &output);
    @memset(&output, 0xa5);
    try std.testing.expectEqual(output.len, try workspace.decodeInto(&known, &output));
    try std.testing.expectEqualSlices(u8, fixtures.known_plain, &output);
    try expectBudget(&workspace);
}
