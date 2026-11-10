//! Public append contracts use stable plaintext and original run boundaries as
//! their oracle. Retired output is poisoned, so dangling reads cannot pass by
//! depending on an allocator leaving freed bytes unchanged.
const std = @import("std");
const allocator = std.testing.allocator;
const prefix = "pre!";
const final_empty = [_]u8{ 0x03, 0x00 };
const frozen_whole_sha = "7fa2d0aad775da84181dbe95ece8b14a120c776e47d76d59b1845959291bb1fc";

const CountingAllocator = struct {
    backing: std.mem.Allocator = allocator,
    live: usize = 0,
    peak: usize = 0,
    allocations: usize = 0,
    rejected: usize = 0,
    remaining: ?usize = null,
    target: ?[*]u8 = null,
    target_freed: bool = false,
    retired: [256]struct { bytes: []u8, alignment: std.mem.Alignment } = undefined,
    retired_count: usize = 0,

    fn get(self: *@This()) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &vtable };
    }
    fn deinit(self: *@This()) void {
        // Quarantine is an observer implementation detail, excluded from the
        // live requested-capacity ledger once the caller has freed a block.
        for (self.retired[0..self.retired_count]) |item|
            self.backing.rawFree(item.bytes, item.alignment, @returnAddress());
    }
    const vtable: std.mem.Allocator.VTable = .{ .alloc = alloc, .resize = resize, .remap = remap, .free = free };
    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        if (self.remaining) |remaining| {
            if (remaining == 0) {
                self.rejected += 1;
                return null;
            }
            self.remaining = remaining - 1;
        }
        const result = self.backing.rawAlloc(len, alignment, ra) orelse return null;
        self.allocations += 1;
        self.live += len;
        self.peak = @max(self.peak, self.live);
        return result;
    }
    fn resize(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) bool {
        return false;
    }
    fn remap(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) ?[*]u8 {
        return null;
    }
    fn free(ctx: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, _: usize) void {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        if (self.target) |target| if (bytes.ptr == target) {
            self.target_freed = true;
        };
        @memset(bytes, 0xdd);
        self.live -= bytes.len;
        std.debug.assert(self.retired_count < self.retired.len);
        self.retired[self.retired_count] = .{ .bytes = bytes, .alignment = alignment };
        self.retired_count += 1;
    }
};

const Fixture = struct {
    // Preserve the exact counterexample's nonadjacent input addresses. The
    // separate boundary fixture also makes changed run grouping visible in wire.
    separated: [8256]u8 = undefined,
    boundary: [129]u8 = undefined,
    joined_boundary: [128]u8 = undefined,
    third: [512]u8 = undefined,

    fn init(self: *@This()) void {
        var seed: u32 = 0x5831ac9f;
        for (self.separated[0..4096]) |*byte| {
            seed ^= seed << 13;
            seed ^= seed >> 17;
            seed ^= seed << 5;
            byte.* = @truncate(seed >> 13);
        }
        self.separated[4095] = 0x41;
        @memset(self.separated[4096..4160], 0x6b);
        @memset(self.separated[4160..], 0xdd);
        @memset(&self.boundary, 'a');
        @memset(&self.joined_boundary, 'a');
        for (&self.third, 0..) |*byte, index| byte.* = @truncate(index * 29 + index / 7);
    }
    fn first(self: *const @This()) []const u8 {
        return self.separated[0..4096];
    }
    fn second(self: *const @This()) []const u8 {
        return self.separated[4160..8256];
    }
};

const Shape = enum { first_spare, first_prefix, future_spare, future_prefix, separated, contiguous, mixed, descriptors };
const Scenario = struct { shape: Shape, growth: bool = false, single: bool = false };
const scenarios = [_]Scenario{
    .{ .shape = .first_spare, .growth = true },
    .{ .shape = .first_spare },
    .{ .shape = .first_prefix, .growth = true },
    .{ .shape = .first_prefix },
    .{ .shape = .future_spare, .growth = true },
    .{ .shape = .future_spare },
    .{ .shape = .future_prefix, .growth = true },
    .{ .shape = .future_prefix },
    .{ .shape = .separated },
    .{ .shape = .contiguous },
    .{ .shape = .mixed },
    .{ .shape = .descriptors, .growth = true },
    .{ .shape = .descriptors },
    .{ .shape = .first_spare, .growth = true, .single = true },
    .{ .shape = .first_spare, .single = true },
    .{ .shape = .first_prefix, .growth = true, .single = true },
    .{ .shape = .first_prefix, .single = true },
};

const Message = union(enum) { bytes: []const u8, chunks: []const []const u8 };
const Prepared = struct {
    output: std.ArrayList(u8) = .empty,
    chunks: [6][]const u8 = undefined,
    chunk_count: usize = 0,
    descriptors: ?[]const []const u8 = null,
    start: usize = 0,

    fn message(self: *const @This(), scenario: Scenario) Message {
        if (scenario.single) return .{ .bytes = self.chunks[0] };
        return .{ .chunks = self.descriptors orelse self.chunks[0..self.chunk_count] };
    }
};

fn stableChunks(fixture: *const Fixture, shape: Shape, chunks: *[6][]const u8) usize {
    switch (shape) {
        .contiguous => {
            chunks.* = .{ fixture.joined_boundary[0..32], "", fixture.joined_boundary[32..64], fixture.joined_boundary[64..], "", "" };
            return 4;
        },
        .mixed => {
            chunks.* = .{ fixture.boundary[0..32], fixture.boundary[32..64], &fixture.third, "", fixture.boundary[65..97], fixture.boundary[97..129] };
            return 6;
        },
        .separated => {
            chunks.* = .{ fixture.boundary[0..64], "", fixture.boundary[65..129], "", "", "" };
            return 3;
        },
        else => {
            chunks.* = .{ fixture.first(), "", fixture.second(), "", "", "" };
            return 3;
        },
    }
}

fn prepare(fixture: *const Fixture, scenario: Scenario, count: *CountingAllocator, prepared: *Prepared) !void {
    const a = count.get();
    const required: usize = switch (scenario.shape) {
        .separated, .mixed => prefix.len + fixture.boundary.len,
        .contiguous => prefix.len + fixture.joined_boundary.len,
        else => prefix.len + fixture.first().len,
    };
    try prepared.output.ensureTotalCapacityPrecise(a, if (scenario.growth) required else 32 * 1024);
    try prepared.output.appendSlice(a, prefix);
    if (scenario.shape == .first_prefix) try prepared.output.appendSlice(a, fixture.first());
    if (scenario.shape == .future_prefix) try prepared.output.appendSlice(a, fixture.second());
    prepared.start = prepared.output.items.len;
    prepared.chunk_count = stableChunks(fixture, scenario.shape, &prepared.chunks);
    const spare = prepared.output.allocatedSlice()[prefix.len..];
    switch (scenario.shape) {
        .first_spare, .first_prefix => {
            @memcpy(spare[0..4096], fixture.first());
            prepared.chunks[0] = spare[0..4096];
        },
        .future_spare, .future_prefix => {
            @memcpy(spare[0..4096], fixture.second());
            prepared.chunks[2] = spare[0..4096];
        },
        .separated => {
            @memcpy(spare[0..129], &fixture.boundary);
            prepared.chunks[0] = spare[0..64];
            prepared.chunks[2] = spare[65..129];
        },
        .contiguous => {
            @memcpy(spare[0..128], &fixture.joined_boundary);
            prepared.chunks[0] = spare[0..32];
            prepared.chunks[2] = spare[32..64];
            prepared.chunks[3] = spare[64..128];
        },
        .mixed => {
            @memcpy(spare[0..129], &fixture.boundary);
            prepared.chunks[0] = spare[0..32];
            prepared.chunks[1] = spare[32..64];
            prepared.chunks[4] = spare[65..97];
            prepared.chunks[5] = spare[97..129];
        },
        .descriptors => {
            const address = std.mem.alignForward(usize, @intFromPtr(spare.ptr), @alignOf([]const u8));
            const descriptors: [*][]const u8 = @ptrFromInt(address);
            @memcpy(descriptors[0..prepared.chunk_count], prepared.chunks[0..prepared.chunk_count]);
            prepared.descriptors = descriptors[0..prepared.chunk_count];
        },
    }
    count.target = prepared.output.allocatedSlice().ptr;
    count.peak = count.live;
}

fn append(comptime C: type, owner: *C.RawFixedSyncFlushEncoder, a: std.mem.Allocator, output: *std.ArrayList(u8), message: Message, options: C.CompressionOptions, reusable: bool) !usize {
    return switch (message) {
        .bytes => |bytes| if (reusable) owner.encodeAppend(output, bytes, options) else C.encodeRawFixedSyncFlushAppend(a, output, bytes, options),
        .chunks => |chunks| if (reusable) owner.encodeChunksAppend(output, chunks, options) else C.encodeRawFixedSyncFlushChunksAppend(a, output, chunks, options),
    };
}

fn oracle(comptime C: type, fixture: *const Fixture, scenario: Scenario, expected: *std.ArrayList(u8), plain: *std.ArrayList(u8)) !void {
    try expected.appendSlice(allocator, prefix);
    if (scenario.shape == .first_prefix) try expected.appendSlice(allocator, fixture.first());
    if (scenario.shape == .future_prefix) try expected.appendSlice(allocator, fixture.second());
    var chunks: [6][]const u8 = undefined;
    const n = stableChunks(fixture, scenario.shape, &chunks);
    if (scenario.single) {
        try plain.appendSlice(allocator, fixture.first());
        _ = try C.encodeRawFixedSyncFlushAppend(allocator, expected, fixture.first(), .{});
    } else {
        for (chunks[0..n]) |chunk| try plain.appendSlice(allocator, chunk);
        _ = try C.encodeRawFixedSyncFlushChunksAppend(allocator, expected, chunks[0..n], .{});
    }
}

fn strictDecode(comptime C: type, output: []const u8, start: usize, plain: []const u8) !void {
    var terminated: std.ArrayList(u8) = .empty;
    defer terminated.deinit(allocator);
    try terminated.appendSlice(allocator, output[start..]);
    try terminated.appendSlice(allocator, &final_empty);
    const decoded = try C.decodeRawAutoAlloc(allocator, terminated.items);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, plain, decoded);
}

fn freeze(comptime C: type, fixture: *const Fixture) !void {
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);
    var plain: std.ArrayList(u8) = .empty;
    defer plain.deinit(allocator);
    try oracle(C, fixture, .{ .shape = .first_spare }, &expected, &plain);
    try strictDecode(C, expected.items, prefix.len, plain.items);
    try expected.appendSlice(allocator, &final_empty);
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(expected.items, &hash, .{});
    try std.testing.expectEqual(@as(usize, 4360), expected.items.len);
    try std.testing.expectEqualStrings(frozen_whole_sha, &std.fmt.bytesToHex(hash, .lower));
    // A separate boundary fixture makes the topology oracle discriminating:
    // a match crossing the original gap may not become a new joined run.
    var separate: std.ArrayList(u8) = .empty;
    defer separate.deinit(allocator);
    _ = try C.encodeRawFixedSyncFlushChunksAppend(allocator, &separate, &.{ fixture.boundary[0..64], fixture.boundary[65..129] }, .{});
    var joined: std.ArrayList(u8) = .empty;
    defer joined.deinit(allocator);
    _ = try C.encodeRawFixedSyncFlushChunksAppend(allocator, &joined, &.{ fixture.joined_boundary[0..64], fixture.joined_boundary[64..128] }, .{});
    try std.testing.expect(!std.mem.eql(u8, separate.items, joined.items));
}

fn verifySuccess(comptime C: type, fixture: *const Fixture, scenario: Scenario, reusable: bool, expected: []const u8, plain: []const u8, tracked: bool, cap: ?usize) !usize {
    var count: CountingAllocator = .{};
    defer count.deinit();
    var required: usize = 0;
    {
        var prepared: Prepared = .{};
        defer prepared.output.deinit(count.get());
        try prepare(fixture, scenario, &count, &prepared);
        var owner = C.RawFixedSyncFlushEncoder.init(count.get());
        defer owner.deinit();
        var profile: C.EncodeMemoryProfile = .{};
        const options: C.CompressionOptions = .{ .memory_profile = if (tracked) &profile else null, .max_total_working_memory = cap };
        const written = try append(C, &owner, count.get(), &prepared.output, prepared.message(scenario), options, reusable);
        try std.testing.expectEqual(expected.len - prepared.start, written);
        try std.testing.expectEqualSlices(u8, expected, prepared.output.items);
        try strictDecode(C, prepared.output.items, prepared.start, plain);
        try std.testing.expectEqual(scenario.growth, count.target_freed);
        if (tracked) {
            try std.testing.expect(profile.available);
            try std.testing.expectEqual(count.peak, profile.peak_requested_bytes);
            try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
        }
        required = count.peak;
        if (cap) |limit| try std.testing.expect(required <= limit);
    }
    try std.testing.expectEqual(@as(usize, 0), count.live);
    return required;
}

fn refusal(comptime C: type, fixture: *const Fixture, scenario: Scenario, reusable: bool, expected: []const u8, plain: []const u8, limit: ?usize, fail_after: ?usize) !void {
    var count: CountingAllocator = .{};
    defer count.deinit();
    {
        var prepared: Prepared = .{};
        defer prepared.output.deinit(count.get());
        try prepare(fixture, scenario, &count, &prepared);
        var owner = C.RawFixedSyncFlushEncoder.init(count.get());
        defer owner.deinit();
        var profile: C.EncodeMemoryProfile = .{};
        count.remaining = fail_after;
        const options: C.CompressionOptions = .{ .memory_profile = &profile, .max_total_working_memory = limit };
        const result = append(C, &owner, count.get(), &prepared.output, prepared.message(scenario), options, reusable);
        if (limit != null) {
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, result);
            try std.testing.expect(count.peak <= limit.?);
            try std.testing.expect(profile.peak_requested_bytes <= limit.?);
        } else {
            try std.testing.expectError(error.OutOfMemory, result);
            try std.testing.expect(count.rejected > 0);
        }
        try std.testing.expectEqualSlices(u8, expected[0..prepared.start], prepared.output.items);
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
        // Retry with independent stable inputs. This checks that a failed
        // operation did not leave an inherited quota, allocator or arena lease.
        count.remaining = null;
        var chunks: [6][]const u8 = undefined;
        const n = stableChunks(fixture, scenario.shape, &chunks);
        const stable: Message = if (scenario.single) .{ .bytes = fixture.first() } else .{ .chunks = chunks[0..n] };
        _ = try append(C, &owner, count.get(), &prepared.output, stable, .{}, reusable);
        try std.testing.expectEqualSlices(u8, expected, prepared.output.items);
        try strictDecode(C, prepared.output.items, prepared.start, plain);
    }
    try std.testing.expectEqual(@as(usize, 0), count.live);
}

fn matrix(comptime C: type, fixture: *const Fixture) !void {
    for (scenarios) |scenario| {
        var expected: std.ArrayList(u8) = .empty;
        defer expected.deinit(allocator);
        var plain: std.ArrayList(u8) = .empty;
        defer plain.deinit(allocator);
        try oracle(C, fixture, scenario, &expected, &plain);
        inline for (.{ false, true }) |reusable| {
            _ = try verifySuccess(C, fixture, scenario, reusable, expected.items, plain.items, false, null);
            const required = try verifySuccess(C, fixture, scenario, reusable, expected.items, plain.items, true, null);
            // Forced moving allocation and fresh owner state preserve request
            // shapes, so independent observed D is an exact admission boundary.
            try std.testing.expectEqual(required, try verifySuccess(C, fixture, scenario, reusable, expected.items, plain.items, true, required));
            try refusal(C, fixture, scenario, reusable, expected.items, plain.items, required - 1, null);
        }
    }
}

fn realOom(comptime C: type, fixture: *const Fixture) !void {
    for ([_]Scenario{ .{ .shape = .future_spare, .growth = true }, .{ .shape = .descriptors } }) |scenario| {
        var expected: std.ArrayList(u8) = .empty;
        defer expected.deinit(allocator);
        var plain: std.ArrayList(u8) = .empty;
        defer plain.deinit(allocator);
        try oracle(C, fixture, scenario, &expected, &plain);
        inline for (.{ false, true }) |reusable| {
            var count: CountingAllocator = .{};
            defer count.deinit();
            var operation_allocations: usize = 0;
            {
                var prepared: Prepared = .{};
                defer prepared.output.deinit(count.get());
                try prepare(fixture, scenario, &count, &prepared);
                var owner = C.RawFixedSyncFlushEncoder.init(count.get());
                defer owner.deinit();
                var profile: C.EncodeMemoryProfile = .{};
                const before = count.allocations;
                _ = try append(C, &owner, count.get(), &prepared.output, prepared.message(scenario), .{ .memory_profile = &profile }, reusable);
                operation_allocations = count.allocations - before;
            }
            try std.testing.expectEqual(@as(usize, 0), count.live);
            try std.testing.expect(operation_allocations > 0);
            for (0..operation_allocations) |fail_after|
                try refusal(C, fixture, scenario, reusable, expected.items, plain.items, null, fail_after);
        }
    }
}

fn nonalias(comptime C: type, fixture: *const Fixture) !void {
    var count: CountingAllocator = .{};
    defer count.deinit();
    {
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(count.get());
        try output.ensureTotalCapacityPrecise(count.get(), 32 * 1024);
        try output.appendSlice(count.get(), prefix);
        const before = count.allocations;
        _ = try C.encodeRawFixedSyncFlushChunksAppend(count.get(), &output, &.{ "", "" }, .{});
        try std.testing.expectEqual(before, count.allocations);
        try strictDecode(C, output.items, prefix.len, "");
        var owner = C.RawFixedSyncFlushEncoder.init(count.get());
        defer owner.deinit();
        const chunks = [_][]const u8{ fixture.first(), "", fixture.second() };
        var expected: std.ArrayList(u8) = .empty;
        defer expected.deinit(allocator);
        var plain: std.ArrayList(u8) = .empty;
        defer plain.deinit(allocator);
        try oracle(C, fixture, .{ .shape = .first_spare }, &expected, &plain);
        output.shrinkRetainingCapacity(prefix.len);
        const cold = count.allocations;
        _ = try C.encodeRawFixedSyncFlushChunksAppend(count.get(), &output, &chunks, .{});
        // Independently observed at frozen base 3cd09805: this nonalias
        // operation made six physical parser/history allocations. Alias
        // preparation must add no new heap request to the ordinary path.
        try std.testing.expectEqual(@as(usize, 6), count.allocations - cold);
        try std.testing.expectEqualSlices(u8, expected.items, output.items);
        try strictDecode(C, output.items, prefix.len, plain.items);
        // Arena reset can consolidate early nodes. Check a settled workspace
        // with nonempty caller chunks, rather than attributing parser heap to
        // alias handling or accepting a test that only covers empty messages.
        for (0..6) |_| {
            output.shrinkRetainingCapacity(prefix.len);
            _ = try owner.encodeChunksAppend(&output, &chunks, .{});
        }
        output.shrinkRetainingCapacity(prefix.len);
        const warmed = count.allocations;
        count.peak = count.live;
        _ = try owner.encodeChunksAppend(&output, &chunks, .{});
        try std.testing.expectEqual(warmed, count.allocations);
        try std.testing.expectEqual(count.live, count.peak);
        try std.testing.expectEqualSlices(u8, expected.items, output.items);
        try strictDecode(C, output.items, prefix.len, plain.items);
    }
    try std.testing.expectEqual(@as(usize, 0), count.live);
}

pub fn contracts(comptime C: type) !void {
    var fixture: Fixture = undefined;
    fixture.init();
    try freeze(C, &fixture);
    try nonalias(C, &fixture);
    try matrix(C, &fixture);
    try realOom(C, &fixture);
}
