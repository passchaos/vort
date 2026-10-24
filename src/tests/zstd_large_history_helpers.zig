//! Independent requested-byte accounting and small Zstd window fixtures.
const std = @import("std");

pub const plain = "Zstd requested history abcdefghabcdefghXabcdefgh\n" ** 20;
pub const prefix = "Zstd requested history abcdefghabcdefghXabcdefgh\n" ** 3;

pub const Header = struct { single_segment: bool, window_size: u64, content_size: ?u64, dictionary_id: u32 };

pub fn header(bytes: []const u8) !Header {
    try std.testing.expect(bytes.len >= 6);
    try std.testing.expectEqualSlices(u8, &.{ 0x28, 0xb5, 0x2f, 0xfd }, bytes[0..4]);
    const descriptor = bytes[4];
    const single = descriptor & 0x20 != 0;
    var offset: usize = 5;
    var window: u64 = 0;
    if (!single) {
        const coded = bytes[offset];
        const base = @as(u64, 1) << @as(u6, @intCast(10 + (coded >> 3)));
        window = base + base / 8 * (coded & 7);
        offset += 1;
    }
    const id_len: usize = switch (descriptor & 3) {
        0 => 0,
        1 => 1,
        2 => 2,
        3 => 4,
        else => unreachable,
    };
    var dictionary_id: u32 = 0;
    for (0..id_len) |i| dictionary_id |= @as(u32, bytes[offset + i]) << @intCast(8 * i);
    offset += id_len;
    const size_len: usize = switch (descriptor >> 6) {
        0 => if (single) 1 else 0,
        1 => 2,
        2 => 4,
        3 => 8,
        else => unreachable,
    };
    var content: ?u64 = null;
    if (size_len != 0) {
        var n: u64 = 0;
        for (0..size_len) |i| n |= @as(u64, bytes[offset + i]) << @intCast(8 * i);
        if (size_len == 2) n += 256;
        content = n;
    }
    if (single) window = content.?;
    return .{ .single_segment = single, .window_size = window, .content_size = content, .dictionary_id = dictionary_id };
}

pub fn drive(collector: std.mem.Allocator, encoder: anytype, input: []const u8, input_quota: usize, output_quota: usize) ![]u8 {
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(collector);
    var offset = try @import("../core.zig").stream_count.toLocal(encoder.snapshot().frame_input);
    var finishing = encoder.snapshot().finishing;
    var output: [257]u8 = undefined;
    for (0..input.len * 16 + 4096) |call| {
        if (offset == input.len and !finishing) {
            encoder.finish();
            finishing = true;
        }
        @memset(&output, 0xa5);
        const end = @min(input.len, offset + input_quota);
        const before = encoder.snapshot();
        const result = try encoder.step(input[offset..end], output[0..if (call % 7 == 0) 0 else output_quota]);
        const after = encoder.snapshot();
        try std.testing.expectEqual(result.progress.input_read, after.frame_input - before.frame_input);
        try std.testing.expectEqual(result.progress.output_written, after.frame_output - before.frame_output);
        try untouched(output[result.progress.output_written..]);
        offset += result.progress.input_read;
        try bytes.appendSlice(collector, output[0..result.progress.output_written]);
        if (result.status == .done) {
            try std.testing.expectEqual(input.len, offset);
            return bytes.toOwnedSlice(collector);
        }
    }
    return error.TestUnexpectedResult;
}

pub const JointLedger = struct {
    live: usize = 0,
    peak: usize = 0,

    pub fn beginMeasurement(self: *JointLedger) void {
        self.peak = self.live;
    }
};

pub const TrackingAllocator = struct {
    backing: std.mem.Allocator,
    joint: ?*JointLedger = null,
    live: usize = 0,
    peak: usize = 0,
    allocated_bytes: usize = 0,
    freed_bytes: usize = 0,
    alloc_attempts: usize = 0,
    resize_attempts: usize = 0,
    remap_attempts: usize = 0,
    free_calls: usize = 0,
    successful_resizes: usize = 0,
    successful_remaps: usize = 0,
    fail_alloc_after: ?usize = null,
    fail_resize_after: ?usize = null,
    fail_remap_after: ?usize = null,
    forced_failures: usize = 0,
    force_moving_growth: bool = false,
    force_copy_reallocation: bool = false,
    poison_before_free: bool = false,
    peak_operation: Operation = .allocate,
    peak_before: usize = 0,
    peak_request: usize = 0,
    owned_peak: usize = 0,
    slots: [1024]Slot = @splat(.{}),

    pub const Operation = enum { allocate, resize, remap };
    const Slot = struct { pointer: ?[*]u8 = null, len: usize = 0, excluded_bytes: usize = 0 };

    pub fn init(backing: std.mem.Allocator) TrackingAllocator {
        return .{ .backing = backing };
    }

    pub fn allocator(self: *TrackingAllocator) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = allocate, .resize = resize, .remap = remap, .free = free } };
    }

    pub fn clearFailures(self: *TrackingAllocator) void {
        self.fail_alloc_after = null;
        self.fail_resize_after = null;
        self.fail_remap_after = null;
    }

    pub fn beginMeasurement(self: *TrackingAllocator) void {
        self.peak = self.live;
        self.peak_before = self.live;
        self.peak_request = 0;
        self.owned_peak = self.ownedLive();
    }

    /// Exclude only this pre-existing caller allocation. A moving replacement
    /// is a new request and stays counted until the caller explicitly takes it.
    pub fn excludeInitialAllocation(self: *TrackingAllocator, memory: []u8) void {
        self.slot(memory).excluded_bytes = memory.len;
        self.owned_peak = self.ownedLive();
    }

    pub fn ownedLive(self: *const TrackingAllocator) usize {
        var borrowed: usize = 0;
        for (self.slots) |record| borrowed += record.excluded_bytes;
        return self.live - borrowed;
    }

    fn recordOwnedPeak(self: *TrackingAllocator) void {
        self.owned_peak = @max(self.owned_peak, self.ownedLive());
    }

    fn slot(self: *TrackingAllocator, memory: []u8) *Slot {
        for (&self.slots) |*record| if (record.pointer == memory.ptr) {
            std.debug.assert(record.len == memory.len);
            return record;
        };
        @panic("untracked allocator pointer");
    }

    fn increase(self: *TrackingAllocator, amount: usize, operation: Operation, requested: usize) void {
        const previous = self.live;
        self.live += amount;
        self.allocated_bytes += amount;
        if (self.joint) |joint| {
            joint.live += amount;
            joint.peak = @max(joint.peak, joint.live);
        }
        if (self.live > self.peak) {
            self.peak = self.live;
            self.peak_operation = operation;
            self.peak_before = previous;
            self.peak_request = requested;
        }
    }

    fn decrease(self: *TrackingAllocator, amount: usize) void {
        std.debug.assert(amount <= self.live);
        self.live -= amount;
        self.freed_bytes += amount;
        if (self.joint) |joint| joint.live -= amount;
    }

    fn failure(self: *TrackingAllocator, after: ?usize, index: usize) bool {
        if (after) |limit| if (index >= limit) {
            self.forced_failures += 1;
            return true;
        };
        return false;
    }

    fn allocate(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, address: usize) ?[*]u8 {
        const self: *TrackingAllocator = @ptrCast(@alignCast(raw));
        const call = self.alloc_attempts;
        self.alloc_attempts += 1;
        if (self.failure(self.fail_alloc_after, call)) return null;
        const memory = self.backing.rawAlloc(len, alignment, address) orelse return null;
        for (&self.slots) |*record| if (record.pointer == null) {
            record.* = .{ .pointer = memory, .len = len };
            self.increase(len, .allocate, len);
            self.recordOwnedPeak();
            return memory;
        };
        @panic("tracking allocation table exhausted");
    }

    fn resize(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, address: usize) bool {
        const self: *TrackingAllocator = @ptrCast(@alignCast(raw));
        const call = self.resize_attempts;
        self.resize_attempts += 1;
        const record = self.slot(memory);
        if (self.failure(self.fail_resize_after, call) or
            (self.force_moving_growth and len > memory.len) or
            (self.force_copy_reallocation and len != memory.len)) return false;
        if (!self.backing.rawResize(memory, alignment, len, address)) return false;
        self.successful_resizes += 1;
        if (len > memory.len) self.increase(len - memory.len, .resize, len) else self.decrease(memory.len - len);
        record.len = len;
        record.excluded_bytes = @min(record.excluded_bytes, len);
        self.recordOwnedPeak();
        return true;
    }

    fn remap(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, address: usize) ?[*]u8 {
        const self: *TrackingAllocator = @ptrCast(@alignCast(raw));
        const call = self.remap_attempts;
        self.remap_attempts += 1;
        const record = self.slot(memory);
        if (self.failure(self.fail_remap_after, call) or
            (self.force_moving_growth and len > memory.len) or
            (self.force_copy_reallocation and len != memory.len)) return null;
        const result = self.backing.rawRemap(memory, alignment, len, address) orelse return null;
        self.successful_remaps += 1;
        if (len > memory.len) self.increase(len - memory.len, .remap, len) else self.decrease(memory.len - len);
        record.* = .{ .pointer = result, .len = len, .excluded_bytes = @min(record.excluded_bytes, len) };
        self.recordOwnedPeak();
        return result;
    }

    fn free(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, address: usize) void {
        const self: *TrackingAllocator = @ptrCast(@alignCast(raw));
        const record = self.slot(memory);
        if (self.poison_before_free) @memset(memory, 0xdd);
        self.backing.rawFree(memory, alignment, address);
        record.* = .{};
        self.free_calls += 1;
        self.decrease(memory.len);
        self.recordOwnedPeak();
    }
};

pub fn untouched(bytes: []const u8) !void {
    for (bytes) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

test "Zstd large history independent tracker observes in place growth shrink and overlapping live requests" {
    var storage: [256]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    var tracked = TrackingAllocator.init(fixed.allocator());
    const a = tracked.allocator();
    var bytes = try a.alloc(u8, 16);
    try std.testing.expect(a.resize(bytes, 64));
    bytes = bytes.ptr[0..64];
    bytes = a.remap(bytes, 8) orelse return error.TestUnexpectedResult;
    const other = try a.alloc(u8, 24);
    try std.testing.expectEqual(@as(usize, 32), tracked.live);
    try std.testing.expectEqual(@as(usize, 64), tracked.peak);
    a.free(other);
    a.free(bytes);
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
    try std.testing.expectEqual(tracked.allocated_bytes, tracked.freed_bytes);
}

test "Zstd large history independent tracker charges old and new buffers during moving fallback growth" {
    var tracked = TrackingAllocator.init(std.testing.allocator);
    tracked.force_moving_growth = true;
    const a = tracked.allocator();
    var bytes = try a.dupe(u8, "12345678");
    bytes = try a.realloc(bytes, 16);
    try std.testing.expectEqualSlices(u8, "12345678", bytes[0..8]);
    try std.testing.expectEqual(@as(usize, 24), tracked.peak);
    try std.testing.expectEqual(@as(usize, 8), tracked.peak_before);
    try std.testing.expectEqual(@as(usize, 16), tracked.peak_request);
    try std.testing.expectEqual(TrackingAllocator.Operation.allocate, tracked.peak_operation);
    a.free(bytes);
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
    tracked.force_copy_reallocation = true;
    bytes = try a.dupe(u8, "12345678");
    tracked.beginMeasurement();
    bytes = try a.realloc(bytes, 4);
    try std.testing.expectEqualSlices(u8, "1234", bytes);
    try std.testing.expectEqual(@as(usize, 12), tracked.peak);
    try std.testing.expectEqual(@as(usize, 4), tracked.live);
    a.free(bytes);
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
}

test "Zstd large history independent failed allocation resize and remap preserve live bytes and old content" {
    var storage: [256]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    var tracked = TrackingAllocator.init(fixed.allocator());
    const a = tracked.allocator();
    var bytes = try a.dupe(u8, "12345678");
    tracked.fail_resize_after = tracked.resize_attempts;
    try std.testing.expect(!a.resize(bytes, 16));
    tracked.fail_remap_after = tracked.remap_attempts;
    try std.testing.expect(a.remap(bytes, 16) == null);
    tracked.fail_alloc_after = tracked.alloc_attempts;
    try std.testing.expectError(error.OutOfMemory, a.realloc(bytes, 16));
    try std.testing.expectEqualSlices(u8, "12345678", bytes);
    try std.testing.expectEqual(@as(usize, 8), tracked.live);
    try std.testing.expectEqual(@as(usize, 8), tracked.peak);
    tracked.clearFailures();
    bytes = a.remap(bytes, 16) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 16), tracked.live);
    a.free(bytes);
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
    try std.testing.expect(tracked.forced_failures >= 3);
}

test "Zstd large history independent tracker excludes one borrowed identity but counts its moving replacement" {
    var tracked = TrackingAllocator.init(std.testing.allocator);
    tracked.force_moving_growth = true;
    const a = tracked.allocator();
    var bytes = try a.dupe(u8, "12345678");
    tracked.excludeInitialAllocation(bytes);
    tracked.beginMeasurement();
    try std.testing.expectEqual(@as(usize, 0), tracked.ownedLive());
    bytes = try a.realloc(bytes, 16);
    try std.testing.expectEqual(@as(usize, 24), tracked.peak);
    try std.testing.expectEqual(@as(usize, 16), tracked.owned_peak);
    try std.testing.expectEqual(@as(usize, 16), tracked.ownedLive());
    a.free(bytes);
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
    var storage: [256]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    var shrinking = TrackingAllocator.init(fixed.allocator());
    const shrink_a = shrinking.allocator();
    var borrowed = try shrink_a.alloc(u8, 16);
    shrinking.excludeInitialAllocation(borrowed);
    try std.testing.expect(shrink_a.resize(borrowed, 8));
    borrowed = borrowed.ptr[0..8];
    try std.testing.expectEqual(@as(usize, 0), shrinking.ownedLive());
    try std.testing.expectEqual(@as(usize, 0), shrinking.owned_peak);
    shrink_a.free(borrowed);
    try std.testing.expectEqual(@as(usize, 0), shrinking.live);
}

// Independently captured from archivedfa35a843 before window/quota changes.
pub const Api = enum { native_default, native_legacy_window, native_explicit_default, native_explicit_sixty_four, level_fast, level_default, level_lazy, level_hq, native_dictionary, reusable_explicit, incremental_explicit, incremental_dictionary };
pub const FrozenWire = struct { api: Api, hex: []const u8 };
pub const frozen_wires = [_]FrozenWire{
    .{ .api = .native_default, .hex = "28b52ffd64d402c5010014025a7374642072657175657374656420686973746f7279206162636465666768580a06001aaa28f85345c19f2a0afe54d16321ec11250f420a2720" },
    .{ .api = .native_legacy_window, .hex = "28b52ffd0400c5010014025a7374642072657175657374656420686973746f7279206162636465666768580a06001aaa28f85345c19f2a0afe54d16321ec11250f420a2720" },
    .{ .api = .native_explicit_default, .hex = "28b52ffd0488c5010014025a7374642072657175657374656420686973746f7279206162636465666768580a06001aaa28f85345c19f2a0afe54d16321ec11250f420a2720" },
    .{ .api = .native_explicit_sixty_four, .hex = "28b52ffd0488c5010014025a7374642072657175657374656420686973746f7279206162636465666768580a06001aaa28f85345c19f2a0afe54d16321ec11250f420a2720" },
    .{ .api = .level_fast, .hex = "28b52ffd60d40255020084035a7374642072657175657374656420686973746f7279206162636465666768580a5a7374642072657175657374656420686973746f727920050079a9aab042004391c142c4238a13" },
    .{ .api = .level_default, .hex = "28b52ffd60d402c5010014025a7374642072657175657374656420686973746f7279206162636465666768580a06001aaa28f85345c19f2a0afe54d16321ec11250f" },
    .{ .api = .level_lazy, .hex = "28b52ffd60d402c5010014025a7374642072657175657374656420686973746f7279206162636465666768580a06001aaa28f85345c19f2a0afe54d16321ec11250f" },
    .{ .api = .level_hq, .hex = "28b52ffd60d402c5010014025a7374642072657175657374656420686973746f7279206162636465666768580a06001aaa28f85345c19f2a0afe54d16321ec11250f" },
    .{ .api = .native_dictionary, .hex = "28b52ffd652ad402dd0000000740008f409e20750505112728c813a120bc4b41529682582813420a2720" },
    .{ .api = .reusable_explicit, .hex = "28b52ffd0488c5010014025a7374642072657175657374656420686973746f7279206162636465666768580a06001aaa28f85345c19f2a0afe54d16321ec11250f420a2720" },
    .{ .api = .incremental_explicit, .hex = "28b52ffd0488c5010014025a7374642072657175657374656420686973746f7279206162636465666768580a06001aaa28f85345c19f2a0afe54d16321ec11250f420a2720" },
    .{ .api = .incremental_dictionary, .hex = "28b52ffd652ad402dd0000000740008f409e20750505112728c813a120bc4b41529682582813420a2720" },
};

pub fn frozenAlloc(a: std.mem.Allocator, sample: FrozenWire) ![]u8 {
    const output = try a.alloc(u8, sample.hex.len / 2);
    errdefer a.free(output);
    _ = try std.fmt.hexToBytes(output, sample.hex);
    return output;
}
