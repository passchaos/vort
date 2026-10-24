//! Independent window-header parsing, requested-byte tracking, and frozen old wires.
const std = @import("std");

pub const plain = "total-memory alias prefix | abcdefghabcdefghXabcdefgh | tail\n" ** 2;

pub fn extensionWindow(bytes: []const u8) !u5 {
    try std.testing.expect(bytes.len >= 2);
    // LSB stream bits: 1,000,001,0, then the six-bit window value.
    const first: u16 = @as(u16, bytes[0]) | (@as(u16, bytes[1]) << 8);
    try std.testing.expectEqual(@as(u16, 0x11), first & 0xff);
    const window = (first >> 8) & 63;
    try std.testing.expect(window >= 10 and window <= 30);
    return @intCast(window);
}

pub fn ordinaryWindow(bytes: []const u8) !u5 {
    try std.testing.expect(bytes.len > 0);
    const value = bytes[0];
    if (value & 1 == 0) return 16;
    const upper = (value >> 1) & 7;
    if (upper != 0) return @intCast(17 + upper);
    const lower = (value >> 4) & 7;
    if (lower == 0) return 17;
    try std.testing.expect(lower >= 2);
    return @intCast(8 + lower);
}

pub const Setting = enum { fast, balanced, ratio, q0, q1, q2, q3, q4, q5, q6, q7, q8, q9, q10, q11, hq10, hq11 };
pub const settings = std.enums.values(Setting);

pub const JointLedger = struct {
    live: usize = 0,
    peak: usize = 0,

    pub fn beginMeasurement(self: *JointLedger) void {
        self.peak = self.live;
    }
};

pub fn options(comptime Options: type, setting: Setting) Options {
    return switch (setting) {
        .fast => .{},
        .balanced => .{ .level = .balanced },
        .ratio => .{ .level = .ratio },
        .hq10 => .{ .quality = 10, .hq = .{} },
        .hq11 => .{ .quality = 11, .hq = .{} },
        else => .{ .quality = @intCast(@intFromEnum(setting) - @intFromEnum(Setting.q0)) },
    };
}

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
        if (self.failure(self.fail_resize_after, call) or (self.force_moving_growth and len > memory.len)) return false;
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
        if (self.failure(self.fail_remap_after, call) or (self.force_moving_growth and len > memory.len)) return null;
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

pub fn drive(collector: std.mem.Allocator, encoder: anytype, input: []const u8, input_quota: usize, output_quota: usize) ![]u8 {
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(collector);
    const initial = encoder.snapshot();
    var offset: usize = @intCast(initial.stream_input);
    var finishing = initial.finishing;
    var output: [257]u8 = undefined;
    for (0..input.len * 16 + 4096) |call| {
        if (offset == input.len and !finishing) {
            try encoder.finish();
            finishing = true;
        }
        const end = @min(input.len, offset + input_quota);
        @memset(&output, 0xa5);
        const before = encoder.snapshot();
        const result = try encoder.step(input[offset..end], output[0..if (call % 7 == 0) 0 else output_quota]);
        const after = encoder.snapshot();
        try std.testing.expectEqual(result.progress.input_read, after.stream_input - before.stream_input);
        try std.testing.expectEqual(result.progress.output_written, after.stream_output - before.stream_output);
        try untouched(output[result.progress.output_written..]);
        offset += result.progress.input_read;
        try bytes.appendSlice(collector, output[0..result.progress.output_written]);
        if (result.status == .done) return bytes.toOwnedSlice(collector);
    }
    return error.TestUnexpectedResult;
}

test "Brotli large window independent tracker observes in place growth shrink and overlapping live requests" {
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

test "Brotli large window independent tracker charges old and new buffers during moving fallback growth" {
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
}

test "Brotli large window independent failed allocation resize and remap preserve live bytes and old content" {
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

test "Brotli large window independent tracker excludes one borrowed identity but counts its moving replacement" {
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

// Frozen once from archived b20af85d, before LargeWindow encoder changes.
pub const Api = enum { one_shot, reusable, chunks, incremental };
pub const FrozenWire = struct { api: Api, setting: Setting, hex: []const u8 };
pub const frozen_wires = [_]FrozenWire{
    .{ .api = .one_shot, .setting = .fast, .hex = "220f003c00d9ad2b69a1685d7d0cbb9be366813b1d8823ef98a42f9891c9e2cba171f25cf6082a38b48d9b5cfa845c2ab73e3049e81ca2e100" },
    .{ .api = .one_shot, .setting = .balanced, .hex = "220f003c00d9ad2b69a1685d7d0cbb9be366813b1d8823ef98a42f9891c9e2cba171f25cf6082a38b48d9b5cfa845c2ab73e3049e81ca2e100" },
    .{ .api = .one_shot, .setting = .ratio, .hex = "220f003c00d9ad2b69a1685d7d0cbb9be366813b1d8823ef98a42f9891c9e2cba171f25cf6082a38b48d9b5cfa845c2ab73e3049e81ca2e100" },
    .{ .api = .one_shot, .setting = .q0, .hex = "9007000000a89b1ea32a0cce637b5ed2656454b06400ffddbfffaebde79c4435c9fd31ec2f6e1c1c1c3c7870e67c12d5e0c58b0f8bc5621d937e558bc562b1582c1620d419918ad2281c16da49f69ee0bbe9d958f7d031d706acc40fdea5963f1c406251f3c0e3e4cfc56106071ab3ae083e6a" },
    .{ .api = .one_shot, .setting = .q1, .hex = "9007000000aa9bc7a80a83f3d8023b2cd9b3679ff893c1061c3cfbace18683e14d0112e6939eb4b34bf7d8a029274648d38502efe795f6fd7471450f0a49b563901a" },
    .{ .api = .one_shot, .setting = .q2, .hex = "9007003c00cead5b12a1d8baf52ae83712231000871c30b7b4e59c5864070f5989741b59bd27320fccc209a980a1c69216ec73d5de579715fc12f4d118" },
    .{ .api = .one_shot, .setting = .q3, .hex = "90070000004ea7bf510873e76ffb1f3612080b436cc93a1047de3149174e85592a0a763b7be4269862d248165d7408eff7b3b4ae0ff4aea0760d06" },
    .{ .api = .one_shot, .setting = .q4, .hex = "220f000000d9ad2b69a1685d7d0cbb9be366813b1d8823ef98a40ba7c22cbe1c1a27cf658fa08243dbb8c9a54fc8a572eb4313f4ce211a06" },
    .{ .api = .one_shot, .setting = .q5, .hex = "220f000000d9ad2b69a1685d7d0cbb9be366813b1d8823ef98a40ba7c22cbe1c1a27cf658fa08243dbb8c9a54fc8a572eb4313f4ce211a06" },
    .{ .api = .one_shot, .setting = .q6, .hex = "220f000000d9ad2b69a1685d7d0cbb9be366813b1d8823ef98a40ba7c22cbe1c1a27cf658fa08243dbb8c9a54fc8a572eb4313f4ce211a06" },
    .{ .api = .one_shot, .setting = .q7, .hex = "220f000000d9ad2b69a1685d7d0cbb9be366813b1d8823ef98a40ba7c22cbe1c1a27cf658fa08243dbb8c9a54fc8a572eb4313f4ce211a06" },
    .{ .api = .one_shot, .setting = .q8, .hex = "220f000000d9ad2b69a1685d7d0cbb9be366813b1d8823ef98a40ba7c22cbe1c1a27cf658fa08243dbb8c9a54fc8a572eb4313f4ce211a06" },
    .{ .api = .one_shot, .setting = .q9, .hex = "220f000000d9ad2b69a1685d7d0cbb9be366813b1d8823ef98a40ba7c22cbe1c1a27cf658fa08243dbb8c9a54fc8a572eb4313f4ce211a06" },
    .{ .api = .one_shot, .setting = .q10, .hex = "220f000000d9ad2b69a1685d7d0cbb9be366813b1d8823ef98a40ba7c22cbe1c1a27cf658fa08243dbb8c9a54fc8a572eb4313f4ce211a06" },
    .{ .api = .one_shot, .setting = .q11, .hex = "220f000000d9ad2b69a1685d7d0cbb9be366813b1d8823ef98a40ba7c22cbe1c1a27cf658fa08243dbb8c9a54fc8a572eb4313f4ce211a06" },
    .{ .api = .one_shot, .setting = .hq10, .hex = "220f00000053ce4f7ef3b8da4a207093859c9d0f064764d406708c9552c651b6c326fef7192eebd944de10ca702a81e3f355dcbb00" },
    .{ .api = .one_shot, .setting = .hq11, .hex = "220f00000053ce4f7ef3b8da4a207093859c9d0f064764d406708c9552c651b6c326fef7192eebd944de10ca702a81e3f355dcbb00" },
    .{ .api = .reusable, .setting = .fast, .hex = "220f003c00d9ad2b69a1685d7d0cbb9be366813b1d8823ef98a42f9891c9e2cba171f25cf6082a38b48d9b5cfa845c2ab73e3049e81ca2e100" },
    .{ .api = .chunks, .setting = .fast, .hex = "000110746f74616c2d6d656d6f727920616c69613801001e80df7b44fa15a7db3aad5741500782882316c90b66740a912c3e58dcf789454d27860d2000e0a115c2d2d8c439613a9b18" },
    .{ .api = .incremental, .setting = .fast, .hex = "9007003c00d9ad2b69a1685d7d0cbb9be366813b1d8823ef98a42f9891c9e2cba171f25cf6082a38b48d9b5cfa845c2ab73e3049e81ca2e118" },
    .{ .api = .reusable, .setting = .q0, .hex = "9007000000a89b1ea32a0cce637b5ed2656454b06400ffddbfffaebde79c4435c9fd31ec2f6e1c1c1c3c7870e67c12d5e0c58b0f8bc5621d937e558bc562b1582c1620d419918ad2281c16da49f69ee0bbe9d958f7d031d706acc40fdea5963f1c406251f3c0e3e4cfc56106071ab3ae083e6a" },
    .{ .api = .chunks, .setting = .q0, .hex = "000110746f74616c2d6d656d6f727920616c69613801087320707265666978207c2061626364656667686162636465666768586162636465666768207c207400020861696c0a746f74616c2d6d656d6f727920616c69617320707265666978207c2061626364656667686162636465666768586162636465666768207c207461696c0a03" },
    .{ .api = .incremental, .setting = .q0, .hex = "9007000000a89b1ea32a0cce637b5ed2656454b06400ffddbfffaebde79c4435c9fd31ec2f6e1c1c1c3c7870e67c12d5e0c58b0f8bc5621d937e558bc562b1582c1620d419918ad2281c16da49f69ee0bbe9d958f7d031d706acc40fdea5963f1c406251f3c0e3e4cfc56106071ab3ae083e6a" },
    .{ .api = .reusable, .setting = .hq11, .hex = "220f00000053ce4f7ef3b8da4a207093859c9d0f064764d406708c9552c651b6c326fef7192eebd944de10ca702a81e3f355dcbb00" },
    .{ .api = .chunks, .setting = .hq11, .hex = "220f00000053ce4f7ef3b8da4a207093859c9d0f064764d406708c9552c651b6c326fef7192eebd944de10ca702a81e3f355dcbb00" },
    .{ .api = .incremental, .setting = .hq11, .hex = "220f00000053ce4f7ef3b8da4a207093859c9d0f064764d406708c9552c651b6c326fef7192eebd944de10ca702a81e3f355dcbb00" },
};

pub fn frozenAlloc(a: std.mem.Allocator, sample: FrozenWire) ![]u8 {
    const output = try a.alloc(u8, sample.hex.len / 2);
    errdefer a.free(output);
    _ = try std.fmt.hexToBytes(output, sample.hex);
    return output;
}

pub const insert_bases = [_]u32{ 0, 1, 2, 3, 4, 5, 6, 8, 10, 14, 18, 26, 34, 50, 66, 98, 130, 194, 322, 578, 1090, 2114, 6210, 22594 };
pub const insert_bits = [_]u8{ 0, 0, 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 7, 8, 9, 10, 12, 14, 24 };
pub const copy_bases = [_]u32{ 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 14, 18, 22, 30, 38, 54, 70, 102, 134, 198, 326, 582, 1094, 2118 };
pub const copy_bits = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 7, 8, 9, 10, 24 };

pub const Command = struct { insert_code: u8, copy_code: u8, implicit_last_distance: bool };
const explicit_groups = [3][3]u16{ .{ 128, 192, 384 }, .{ 256, 320, 512 }, .{ 448, 576, 640 } };

pub fn command(symbol: u16) Command {
    std.debug.assert(symbol < 704);
    if (symbol < 128) return .{ .insert_code = @intCast((symbol & 63) >> 3), .copy_code = @intCast((symbol & 7) + if (symbol >= 64) @as(u16, 8) else 0), .implicit_last_distance = true };
    for (explicit_groups, 0..) |row, insert_group| {
        for (row, 0..) |base, copy_group| {
            if (symbol >= base and symbol < base + 64) return .{ .insert_code = @intCast(insert_group * 8 + (symbol - base) / 8), .copy_code = @intCast(copy_group * 8 + (symbol - base) % 8), .implicit_last_distance = false };
        }
    }
    unreachable;
}

/// Semantic cache order is newest to oldest, independent of decoder rings.
pub fn shortDistance(cache: [4]usize, code: u4) ?usize {
    if (code < 4) return cache[code];
    const slot: usize = if (code < 10) 0 else 1;
    const local: usize = if (code < 10) code - 4 else code - 10;
    const magnitude = local / 2 + 1;
    if (local % 2 == 0) return if (cache[slot] > magnitude) cache[slot] - magnitude else null;
    return std.math.add(usize, cache[slot], magnitude) catch null;
}

pub fn afterDistance(cache: [4]usize, code: usize, distance: usize, static_dictionary: bool) [4]usize {
    if (code == 0 or static_dictionary) return cache;
    return .{ distance, cache[0], cache[1], cache[2] };
}

pub const Distance = struct { symbol: u16, extra_bits: u8, extra: usize };

pub fn alphabetSize(postfix: u2, direct: u16) usize {
    return 16 + @as(usize, direct) + (@as(usize, 48) << postfix);
}

pub fn distanceEncoding(distance: usize, postfix: u2, direct: u16) Distance {
    std.debug.assert(distance > 0);
    if (distance <= direct) return .{ .symbol = @intCast(15 + distance), .extra_bits = 0, .extra = 0 };
    const low_mask = (@as(usize, 1) << postfix) - 1;
    const value = distance - direct - 1;
    const low = value & low_mask;
    const high = (value >> postfix) + 4;
    const bits: usize = std.math.log2_int(usize, high) - 1;
    const prefix = (high >> @intCast(bits)) & 1;
    const extra = high - ((2 + prefix) << @intCast(bits));
    const symbol = 16 + @as(usize, direct) + ((2 * (bits - 1) + prefix) << postfix) + low;
    return .{ .symbol = @intCast(symbol), .extra_bits = @intCast(bits), .extra = extra };
}

pub fn distanceDecoding(encoded: Distance, postfix: u2, direct: u16) usize {
    if (encoded.symbol < 16 + direct) return encoded.symbol - 15;
    const value = encoded.symbol - 16 - direct;
    const low = value & ((@as(u16, 1) << postfix) - 1);
    const group = value >> postfix;
    const bits = (group >> 1) + 1;
    const prefix = group & 1;
    return (((@as(usize, 2 + prefix) << @intCast(bits)) - 4 + encoded.extra) << postfix) + low + direct + 1;
}

pub const Bits = struct {
    bytes: []const u8,
    position: usize = 0,

    pub fn read(self: *Bits, width: u8) !usize {
        if (width > @bitSizeOf(usize) or self.position + width > self.bytes.len * 8) return error.TestUnexpectedResult;
        var value: usize = 0;
        for (0..width) |index| {
            const bit = self.position + index;
            value |= @as(usize, (self.bytes[bit / 8] >> @as(u3, @intCast(bit % 8))) & 1) << @intCast(index);
        }
        self.position += width;
        return value;
    }

    fn varUint8(self: *Bits) !usize {
        if (try self.read(1) == 0) return 0;
        const width = try self.read(3);
        if (width == 0) return 1;
        return (@as(usize, 1) << @intCast(width)) + try self.read(@intCast(width));
    }
};

const SimpleTree = struct {
    symbols: [4]usize = @splat(0),
    lengths: [4]u8 = @splat(0),
    count: usize,

    fn read(reader: *Bits, alphabet: usize) !SimpleTree {
        if (try reader.read(2) != 1) return error.UnsupportedTestFixture;
        var result: SimpleTree = .{ .count = 1 + try reader.read(2) };
        const symbol_bits = std.math.log2_int_ceil(usize, alphabet);
        for (result.symbols[0..result.count]) |*symbol| {
            symbol.* = try reader.read(@intCast(symbol_bits));
            if (symbol.* >= alphabet) return error.TestUnexpectedResult;
        }
        result.lengths = switch (result.count) {
            1 => .{ 0, 0, 0, 0 },
            2 => .{ 1, 1, 0, 0 },
            3 => .{ 1, 2, 2, 0 },
            4 => if (try reader.read(1) == 0) .{ 2, 2, 2, 2 } else .{ 1, 2, 3, 3 },
            else => unreachable,
        };
        return result;
    }

    fn decode(self: SimpleTree, reader: *Bits) !usize {
        if (self.count == 1) return self.symbols[0];
        var counts: [4]usize = @splat(0);
        for (self.lengths[0..self.count]) |length| counts[length] += 1;
        var code: usize = 0;
        var first: usize = 0;
        for (1..4) |length| {
            code = (code << 1) | try reader.read(1);
            if (code >= first and code - first < counts[length]) {
                var candidates: [4]usize = undefined;
                var used: usize = 0;
                for (0..self.count) |index| if (self.lengths[index] == length) {
                    candidates[used] = self.symbols[index];
                    used += 1;
                };
                std.mem.sort(usize, candidates[0..used], {}, std.sort.asc(usize));
                return candidates[code - first];
            }
            first = (first + counts[length]) << 1;
        }
        return error.TestUnexpectedResult;
    }
};

pub const SingleCommandWire = struct {
    window_bits: usize,
    large_window: bool,
    meta_len: usize,
    command_symbol: usize,
    insert_len: usize,
    raw_copy_len: usize,
    distance_symbol: ?usize,
    distance: usize,
    npostfix: u2,
    ndirect: u16,
};

/// Independent limited RFC reader for deliberately simple one-command fixtures.
/// It reads real tree symbols and extra bits, never producer-selected metadata.
pub fn singleCommandWire(bytes: []const u8, semantic_cache: [4]usize) !SingleCommandWire {
    var reader: Bits = .{ .bytes = bytes };
    var window: usize = 16;
    var large_window = false;
    if (try reader.read(1) != 0) {
        const middle = try reader.read(3);
        if (middle != 0) window = 17 + middle else {
            const lower = try reader.read(3);
            if (lower == 1) {
                if (try reader.read(1) != 0) return error.TestUnexpectedResult;
                window = try reader.read(6);
                large_window = true;
            } else window = if (lower == 0) 17 else 8 + lower;
        }
    }
    const last = try reader.read(1) != 0;
    if (last and try reader.read(1) != 0) return error.UnsupportedTestFixture;
    const nibbles = 4 + try reader.read(2);
    if (nibbles == 7) return error.UnsupportedTestFixture;
    const meta_len = 1 + try reader.read(@intCast(nibbles * 4));
    if (!last and try reader.read(1) != 0) return error.UnsupportedTestFixture;
    for (0..3) |_| if (try reader.varUint8() != 0) return error.UnsupportedTestFixture;
    const postfix: u2 = @intCast(try reader.read(2));
    const direct: u16 = @intCast((try reader.read(4)) << postfix);
    _ = try reader.read(2);
    if (try reader.varUint8() != 0) return error.UnsupportedTestFixture;
    if (try reader.varUint8() != 0) return error.UnsupportedTestFixture;
    const literals = try SimpleTree.read(&reader, 256);
    const commands = try SimpleTree.read(&reader, 704);
    const distances = try SimpleTree.read(&reader, 16 + @as(usize, direct) + ((if (large_window) @as(usize, 124) else 48) << postfix));
    const symbol = try commands.decode(&reader);
    const entry = command(@intCast(symbol));
    const insert_len = insert_bases[entry.insert_code] + try reader.read(insert_bits[entry.insert_code]);
    const raw_copy_len = copy_bases[entry.copy_code] + try reader.read(copy_bits[entry.copy_code]);
    for (0..insert_len) |_| _ = try literals.decode(&reader);
    var distance_symbol: ?usize = null;
    var distance = semantic_cache[0];
    if (!entry.implicit_last_distance) {
        const dcode = try distances.decode(&reader);
        distance_symbol = dcode;
        if (dcode < 16) distance = shortDistance(semantic_cache, @intCast(dcode)) orelse return error.TestUnexpectedResult else {
            const bits: u8 = if (dcode < 16 + direct) 0 else @intCast((((dcode - 16 - direct) >> postfix) >> 1) + 1);
            const extra = try reader.read(bits);
            distance = distanceDecoding(.{ .symbol = @intCast(dcode), .extra_bits = bits, .extra = extra }, postfix, direct);
        }
    }
    return .{ .window_bits = window, .large_window = large_window, .meta_len = meta_len, .command_symbol = symbol, .insert_len = insert_len, .raw_copy_len = raw_copy_len, .distance_symbol = distance_symbol, .distance = distance, .npostfix = postfix, .ndirect = direct };
}
