const std = @import("std");
const buffer = @import("rle_buffer.zig");

/// Force moving growth so the checks cover allocation, copy and old-buffer
/// release. Remap records only metadata and never dereferences its argument.
const Ledger = struct {
    limit: usize,
    reject: bool = false,
    allocations: usize = 0,
    remaps: usize = 0,
    frees: usize = 0,
    last_request: usize = 0,
    largest_request: usize = 0,
    live: usize = 0,
    peak: usize = 0,

    fn allocator(self: *Ledger) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }

    fn alloc(raw: *anyopaque, length: usize, alignment: std.mem.Alignment, address: usize) ?[*]u8 {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        self.allocations += 1;
        self.last_request = length;
        self.largest_request = @max(self.largest_request, length);
        std.debug.assert(length <= self.limit);
        if (self.reject) return null;
        const memory = std.testing.allocator.rawAlloc(length, alignment, address) orelse return null;
        self.live += length;
        self.peak = @max(self.peak, self.live);
        return memory;
    }

    fn resize(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) bool {
        return false;
    }

    fn remap(raw: *anyopaque, _: []u8, _: std.mem.Alignment, length: usize, _: usize) ?[*]u8 {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        self.remaps += 1;
        std.debug.assert(length <= self.limit);
        return null;
    }

    fn free(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, address: usize) void {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        self.frees += 1;
        self.live -= memory.len;
        std.testing.allocator.rawFree(memory, alignment, address);
    }
};

fn expectContents(block: *const std.ArrayList(u8)) !void {
    for (block.items, 0..) |byte, index|
        try std.testing.expectEqual(@as(u8, @intCast(index % 251)), byte);
}

fn growTo(limit: usize) !void {
    var ledger: Ledger = .{ .limit = limit };
    var block: std.ArrayList(u8) = .empty;
    const allocator = ledger.allocator();
    defer block.deinit(allocator);
    try buffer.ensure(allocator, &block, 0, limit);
    try std.testing.expectEqual(@as(usize, 0), ledger.allocations);
    try std.testing.expectEqual(@as(usize, 0), block.capacity);
    const steps = [_]usize{ 1, 3, 5, 17, 259 };
    var step: usize = 0;
    while (block.items.len < limit) : (step += 1) {
        const additional = @min(steps[step % steps.len], limit - block.items.len);
        const before_len = block.items.len;
        const before_capacity = block.capacity;
        const before_allocations = ledger.allocations;
        try buffer.ensure(allocator, &block, additional, limit);
        try std.testing.expectEqual(before_len, block.items.len);
        try std.testing.expect(block.capacity >= before_len + additional and block.capacity <= limit);
        if (before_len + additional <= before_capacity) {
            try std.testing.expectEqual(before_allocations, ledger.allocations);
        } else {
            try std.testing.expectEqual(before_allocations + 1, ledger.allocations);
            try expectContents(&block);
        }
        for (0..additional) |index| block.appendAssumeCapacity(@intCast((before_len + index) % 251));
    }
    try expectContents(&block);
    try std.testing.expectEqual(limit, block.items.len);
    try std.testing.expectEqual(limit, block.capacity);
    // A useful resource contract: incremental appends must not allocate once
    // per run. This bound is independent of the exact capacity recurrence.
    try std.testing.expect(ledger.allocations <= 32);
    try std.testing.expectEqual(block.capacity, ledger.live);
    if (limit != 0) {
        const before_pointer = block.items.ptr;
        const before_allocations = ledger.allocations;
        try std.testing.expectError(error.InvalidBzip2Stream, buffer.ensure(allocator, &block, 1, limit));
        try std.testing.expectEqual(before_pointer, block.items.ptr);
        try std.testing.expectEqual(before_allocations, ledger.allocations);
        try expectContents(&block);
    }
}

test "Bzip2 RLE buffer empty and exact limits avoid unnecessary allocation" {
    var ledger: Ledger = .{ .limit = 64, .reject = true };
    var block: std.ArrayList(u8) = .empty;
    try buffer.ensure(ledger.allocator(), &block, 0, 0);
    try buffer.ensure(ledger.allocator(), &block, 0, 900_000);
    try std.testing.expectEqual(@as(usize, 0), ledger.allocations);
    try std.testing.expectEqual(@as(usize, 0), ledger.remaps);
    try std.testing.expectEqual(@as(usize, 0), block.capacity);
    try std.testing.expectError(error.InvalidBzip2Stream, buffer.ensure(ledger.allocator(), &block, 1, 0));
    try std.testing.expectEqual(@as(usize, 0), ledger.allocations);

    ledger.reject = false;
    try buffer.ensure(ledger.allocator(), &block, 1, 64);
    defer block.deinit(ledger.allocator());
    try std.testing.expectEqual(@as(usize, 64), block.capacity);
    block.appendSliceAssumeCapacity("data");
    const pointer = block.items.ptr;
    const allocations = ledger.allocations;
    ledger.reject = true;
    try buffer.ensure(ledger.allocator(), &block, 60, 64);
    try buffer.ensure(ledger.allocator(), &block, 0, 4);
    try std.testing.expectEqual(pointer, block.items.ptr);
    try std.testing.expectEqual(allocations, ledger.allocations);
    try std.testing.expectEqualStrings("data", block.items);
}

test "Bzip2 RLE buffer invalid length or additional rejects before allocator and preserves data" {
    var ledger: Ledger = .{ .limit = 64 };
    var block: std.ArrayList(u8) = .empty;
    try buffer.ensure(ledger.allocator(), &block, 4, 64);
    defer block.deinit(ledger.allocator());
    block.appendSliceAssumeCapacity("safe");
    const pointer = block.items.ptr;
    const capacity = block.capacity;
    const allocations = ledger.allocations;
    const remaps = ledger.remaps;
    ledger.reject = true;
    try std.testing.expectError(error.InvalidBzip2Stream, buffer.ensure(ledger.allocator(), &block, 0, 3));
    try std.testing.expectError(error.InvalidBzip2Stream, buffer.ensure(ledger.allocator(), &block, 61, 64));
    try std.testing.expectError(error.InvalidBzip2Stream, buffer.ensure(ledger.allocator(), &block, std.math.maxInt(usize), std.math.maxInt(usize)));
    try std.testing.expectEqual(pointer, block.items.ptr);
    try std.testing.expectEqual(capacity, block.capacity);
    try std.testing.expectEqualStrings("safe", block.items);
    try std.testing.expectEqual(allocations, ledger.allocations);
    try std.testing.expectEqual(remaps, ledger.remaps);
}

test "Bzip2 RLE buffer moving geometric growth stays within small and format bounds" {
    for (0..513) |limit| try growTo(limit);
    for ([_]usize{ 1024, 4097, 100_000, 200_000, 899_999, 900_000 }) |limit| try growTo(limit);
}

test "Bzip2 RLE buffer retained larger capacity remains usable after lower limits" {
    var ledger: Ledger = .{ .limit = 900_000 };
    var block: std.ArrayList(u8) = .empty;
    try buffer.ensure(ledger.allocator(), &block, 900_000, 900_000);
    defer block.deinit(ledger.allocator());
    block.appendSliceAssumeCapacity("old block");
    block.clearRetainingCapacity();
    const pointer = block.items.ptr;
    const allocations = ledger.allocations;
    ledger.limit = 100_000;
    ledger.reject = true;
    try buffer.ensure(ledger.allocator(), &block, 100_000, 100_000);
    try buffer.ensure(ledger.allocator(), &block, 0, 0);
    try std.testing.expectEqual(pointer, block.items.ptr);
    try std.testing.expectEqual(@as(usize, 900_000), block.capacity);
    try std.testing.expectEqual(allocations, ledger.allocations);
    try std.testing.expectEqual(@as(usize, 0), ledger.remaps);
}

test "Bzip2 RLE buffer growth OOM leaves existing and empty buffers unchanged" {
    var ledger: Ledger = .{ .limit = 100 };
    var block: std.ArrayList(u8) = .empty;
    try buffer.ensure(ledger.allocator(), &block, 4, 100);
    defer block.deinit(ledger.allocator());
    block.appendSliceAssumeCapacity("keep");
    const pointer = block.items.ptr;
    const capacity = block.capacity;
    const live = ledger.live;
    ledger.reject = true;
    try std.testing.expectError(error.OutOfMemory, buffer.ensure(ledger.allocator(), &block, capacity - block.items.len + 1, 100));
    try std.testing.expectEqual(@as(usize, 100), ledger.last_request);
    try std.testing.expectEqual(pointer, block.items.ptr);
    try std.testing.expectEqual(capacity, block.capacity);
    try std.testing.expectEqualStrings("keep", block.items);
    try std.testing.expectEqual(live, ledger.live);
    try std.testing.expectEqual(@as(usize, 0), ledger.frees);

    var empty: std.ArrayList(u8) = .empty;
    try std.testing.expectError(error.OutOfMemory, buffer.ensure(ledger.allocator(), &empty, 1, 7));
    try std.testing.expectEqual(@as(usize, 7), ledger.last_request);
    try std.testing.expectEqual(@as(usize, 0), empty.capacity);
    try std.testing.expectEqual(@as(usize, 0), empty.items.len);
}

test "Bzip2 RLE buffer saturated growth requests cap without giant allocations" {
    const maximum = std.math.maxInt(usize);
    var sentinel: [1]u8 = .{0x91};
    // Synthetic capacities are used only with a rejecting allocator, which
    // observes requested sizes without reading/remapping/freeing this storage.
    for ([_]usize{ maximum - 1, maximum }) |limit| {
        var ledger: Ledger = .{ .limit = limit, .reject = true };
        var block: std.ArrayList(u8) = .{ .items = &sentinel, .capacity = maximum - 2 };
        const pointer = block.items.ptr;
        try std.testing.expectError(error.OutOfMemory, buffer.ensure(ledger.allocator(), &block, maximum - 2, limit));
        try std.testing.expectEqual(limit, ledger.last_request);
        try std.testing.expectEqual(@as(usize, 1), ledger.allocations);
        try std.testing.expectEqual(@as(usize, 1), ledger.remaps);
        try std.testing.expectEqual(pointer, block.items.ptr);
        try std.testing.expectEqual(@as(usize, maximum - 2), block.capacity);
        try std.testing.expectEqual(@as(usize, 1), block.items.len);
        try std.testing.expectEqual(@as(u8, 0x91), sentinel[0]);
        try std.testing.expectEqual(@as(usize, 0), ledger.frees);
    }
}

test "Bzip2 RLE buffer all allocation failures unwind caller-owned storage" {
    const Run = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var block: std.ArrayList(u8) = .empty;
            defer block.deinit(allocator);
            while (block.items.len < 4097) {
                const additional = @min(@as(usize, 5), 4097 - block.items.len);
                try buffer.ensure(allocator, &block, additional, 4097);
                for (0..additional) |_| block.appendAssumeCapacity('r');
            }
            try std.testing.expectEqual(@as(usize, 4097), block.items.len);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Run.run, .{});
}
