//! Independent requested-byte accounting and bounded LZ4 fixtures.
const std = @import("std");

pub const plain = "LZ4 acceleration abcdefghabcdefghXabcdefgh\n" ** 24;
pub const prefix = "LZ4 acceleration abcdefghabcdefghXabcdefgh\n" ** 3;

pub fn drive(collector: std.mem.Allocator, encoder: anytype, input: []const u8, input_quota: usize, output_quota: usize) ![]u8 {
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(collector);
    var offset = encoder.snapshot().frame_input;
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

/// Unique neighboring pairs ensure no accidental four-byte LZ match. The
/// fixture remains within a small fixed scratch buffer and is deterministic.
pub fn unmatched(a: std.mem.Allocator, len: usize) ![]u8 {
    const output = try a.alloc(u8, len);
    var symbols: [3]u8 = @splat(0);
    var written: usize = 0;
    deBruijn(output, &written, &symbols, 1, 1);
    try std.testing.expectEqual(len, written);
    return output;
}

fn deBruijn(output: []u8, written: *usize, symbols: *[3]u8, position: usize, period: usize) void {
    if (written.* == output.len) return;
    if (position > 2) {
        if (2 % period == 0) for (symbols[1..][0..period]) |byte| {
            if (written.* == output.len) return;
            output[written.*] = byte;
            written.* += 1;
        };
        return;
    }
    symbols[position] = symbols[position - period];
    deBruijn(output, written, symbols, position + 1, period);
    var next: usize = @as(usize, symbols[position - period]) + 1;
    while (next < 256 and written.* != output.len) : (next += 1) {
        symbols[position] = @intCast(next);
        deBruijn(output, written, symbols, position + 1, position);
    }
}

pub const MissResult = struct { inspected: u64, skipped: u64, maximum_step: usize };

pub fn misses(input_len: usize, acceleration: u32) MissResult {
    if (input_len < 12) return .{ .inspected = 0, .skipped = 0, .maximum_step = 0 };
    const eligible = input_len - 11;
    var result: MissResult = .{ .inspected = 0, .skipped = 0, .maximum_step = 0 };
    var position: usize = 0;
    while (position < eligible) {
        // Use the previous step before updating the search counter: the
        // second through sixty-fifth misses use acceleration, the sixty-sixth
        // is the first miss to use acceleration+1.
        const requested: u64 = if (acceleration == 1 or result.inspected == 0) 1 else acceleration + (result.inspected - 1) / 64;
        const step: usize = @intCast(@min(requested, eligible - position));
        result.inspected += 1;
        result.skipped += step - 1;
        result.maximum_step = @max(result.maximum_step, step);
        position += step;
    }
    return result;
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

test "LZ4 fast controls independent tracker observes in place growth shrink and overlapping live requests" {
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

test "LZ4 fast controls independent tracker charges old and new buffers during moving fallback growth" {
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

test "LZ4 fast controls independent failed allocation resize and remap preserve live bytes and old content" {
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

test "LZ4 fast controls independent tracker excludes one borrowed identity but counts its moving replacement" {
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

// Independently captured from archived fef87a82 before acceleration changes.
pub const Api = enum { raw, prefix, frame, frame_linked, dictionary, reusable_raw, reusable_prefix, reusable_frame, incremental_chunks, incremental_dictionary };
pub const FrozenWire = struct { api: Api, hex: []const u8 };
pub const frozen_wires = [_]FrozenWire{
    .{ .api = .raw, .hex = "f40a4c5a3420616363656c65726174696f6e2061626364656667680800145809001f0a2b00ffffffc850656667680a" },
    .{ .api = .prefix, .hex = "0f2b00fffffff350656667680a" },
    .{ .api = .frame, .hex = "04224d186c700804000000000000092f000000f40a4c5a3420616363656c65726174696f6e2061626364656667680800145809001f0a2b00ffffffc850656667680a0000000034194a5a" },
    .{ .api = .frame_linked, .hex = "04224d184c400804000000000000112f000000f40a4c5a3420616363656c65726174696f6e2061626364656667680800145809001f0a2b00ffffffc850656667680a0000000034194a5a" },
    .{ .api = .dictionary, .hex = "04224d186d7008040000000000002a000000bc0d0000000f2b00fffffff350656667680a0000000034194a5a" },
    .{ .api = .reusable_raw, .hex = "f40a4c5a3420616363656c65726174696f6e2061626364656667680800145809001f0a2b00ffffffc850656667680a" },
    .{ .api = .reusable_prefix, .hex = "0f2b00fffffff350656667680a" },
    .{ .api = .reusable_frame, .hex = "04224d186c700804000000000000092f000000f40a4c5a3420616363656c65726174696f6e2061626364656667680800145809001f0a2b00ffffffc850656667680a0000000034194a5a" },
    .{ .api = .incremental_chunks, .hex = "04224d186c700804000000000000092f000000f40a4c5a3420616363656c65726174696f6e2061626364656667680800145809001f0a2b00ffffffc850656667680a0000000034194a5a" },
    .{ .api = .incremental_dictionary, .hex = "04224d186d7008040000000000002a000000bc0d0000000f2b00fffffff350656667680a0000000034194a5a" },
};

pub fn frozenAlloc(a: std.mem.Allocator, sample: FrozenWire) ![]u8 {
    const bytes = try a.alloc(u8, sample.hex.len / 2);
    errdefer a.free(bytes);
    _ = try std.fmt.hexToBytes(bytes, sample.hex);
    return bytes;
}
