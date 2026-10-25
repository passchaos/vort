//! Public serial/parallel drivers and a thread-safe requested-byte oracle.
const std = @import("std");
const xz = @import("../../xz.zig");
pub const a = std.testing.allocator;
pub const plain = "ordered XZ blocks preserve caller bytes and native matching history\n" ** 2;
pub const Api = enum { compressed, stored, lazy };

pub fn threadedTarget() bool {
    return @import("types.zig").target_supports_parallel;
}
fn threadId() usize {
    if (comptime !threadedTarget()) return 0;
    return @intCast(std.Thread.getCurrentId());
}
pub fn parallel(profile: *xz.ParallelProfile) xz.ParallelOptions {
    return .{ .io = std.testing.io, .profile = profile };
}
pub fn options() xz.EncodeOptions {
    return .{ .block_size = 512, .chunk_size = 256, .dictionary_size = 4096, .parser = .fast, .match_options = .{ .finder = .hc4, .nice_len = 32, .depth = 8 } };
}
pub fn encodeAlloc(api: Api, allocator: std.mem.Allocator, input: []const u8, opts: xz.EncodeOptions) ![]u8 {
    return switch (api) {
        .compressed => xz.encodeAlloc(allocator, input, opts),
        .stored => xz.encodeStoredAlloc(allocator, input, opts),
        .lazy => xz.encodeLazyAlloc(allocator, input, opts),
    };
}
pub fn encodeAppend(api: Api, allocator: std.mem.Allocator, output: *std.ArrayList(u8), input: []const u8, opts: xz.EncodeOptions) !usize {
    return switch (api) {
        .compressed => xz.encodeAppend(allocator, output, input, opts),
        .stored => xz.encodeStoredAppend(allocator, output, input, opts),
        .lazy => xz.encodeLazyAppend(allocator, output, input, opts),
    };
}
pub fn encodeInto(api: Api, allocator: std.mem.Allocator, input: []const u8, output: []u8, opts: xz.EncodeOptions) !usize {
    return switch (api) {
        .compressed => xz.encodeInto(allocator, input, output, opts),
        .stored => xz.encodeStoredInto(allocator, input, output, opts),
        .lazy => xz.encodeLazyInto(allocator, input, output, opts),
    };
}
pub fn blockCount(length: usize, block_size: usize) usize {
    return if (length == 0) 0 else 1 + (length - 1) / block_size;
}
pub fn fixtureAlloc(allocator: std.mem.Allocator, block_size: usize, blocks: usize) ![]u8 {
    const bytes = try allocator.alloc(u8, block_size * blocks + 17);
    var random: u32 = 0x549ef831;
    for (bytes, 0..) |*byte, index| {
        random = random *% 1664525 +% 1013904223;
        const block = index / block_size;
        byte.* = if (block % 3 == 1) @truncate(random >> 24) else plain[index % plain.len];
        if (index % block_size < 4) byte.* = @truncate(block >> @as(std.math.Log2Int(usize), @intCast((index % block_size) * 8)));
    }
    return bytes;
}
pub fn untouched(bytes: []const u8) !void {
    for (bytes) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}
pub fn checkWire(wire: []const u8, input: []const u8, opts: xz.EncodeOptions) !void {
    const decoded = try xz.decodeAlloc(a, wire);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
    const info = try xz.inspect(a, wire);
    try std.testing.expectEqual(blockCount(input.len, opts.block_size), info.block_count);
    try std.testing.expectEqual(opts.check, info.check);
    try std.testing.expectEqual(@as(u64, opts.dictionary_size), info.max_dictionary_size);
}
pub fn complete(profile: xz.ParallelProfile, count: usize, opts: xz.ParallelOptions) !void {
    try std.testing.expectEqual(count, profile.completed_blocks);
    try std.testing.expectEqual(count, profile.published_blocks);
    try std.testing.expect(profile.peak_active_workers <= opts.worker_count);
    try std.testing.expect(profile.peak_inflight_blocks <= opts.max_inflight_blocks);
    try std.testing.expect(profile.peak_inflight_bytes <= opts.max_inflight_bytes);
    try std.testing.expect(profile.peak_requested_bytes <= opts.max_working_memory);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
}

pub const TrackingAllocator = struct {
    backing: std.mem.Allocator,
    mutex: std.Io.Mutex = .init,
    slots: [1024]Slot = @splat(.{}),
    main_id: usize,
    attempts: usize = 0,
    worker_attempts: usize = 0,
    worker_refusals: usize = 0,
    fail_after: ?usize = null,
    fail_worker: bool = false,
    force_moving_growth: bool = true,
    live: usize = 0,
    peak: usize = 0,
    const Slot = struct { pointer: ?[*]u8 = null, length: usize = 0 };

    pub fn init(backing: std.mem.Allocator) @This() {
        return .{ .backing = backing, .main_id = threadId() };
    }
    pub fn allocator(self: *@This()) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn slot(self: *@This(), memory: []u8) *Slot {
        for (&self.slots) |*entry| if (entry.pointer == memory.ptr) {
            std.debug.assert(entry.length == memory.len);
            return entry;
        };
        @panic("XZ parallel untracked allocation");
    }
    fn change(self: *@This(), old: usize, new: usize) void {
        self.live = self.live - old + new;
        self.peak = @max(self.peak, self.live);
    }
    fn alloc(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, address: usize) ?[*]u8 {
        const self: *@This() = @ptrCast(@alignCast(raw));
        self.mutex.lockUncancelable(std.testing.io);
        defer self.mutex.unlock(std.testing.io);
        const attempt = self.attempts;
        self.attempts += 1;
        const worker = threadId() != self.main_id;
        if (worker) self.worker_attempts += 1;
        if (self.fail_worker and worker) {
            self.worker_refusals += 1;
            return null;
        }
        if (self.fail_after) |after| if (attempt >= after) return null;
        const pointer = self.backing.rawAlloc(len, alignment, address) orelse return null;
        for (&self.slots) |*entry| if (entry.pointer == null) {
            entry.* = .{ .pointer = pointer, .length = len };
            self.change(0, len);
            return pointer;
        };
        @panic("XZ parallel allocation table exhausted");
    }
    fn resize(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, address: usize) bool {
        const self: *@This() = @ptrCast(@alignCast(raw));
        self.mutex.lockUncancelable(std.testing.io);
        defer self.mutex.unlock(std.testing.io);
        if (self.force_moving_growth and len > memory.len) return false;
        const entry = self.slot(memory);
        if (!self.backing.rawResize(memory, alignment, len, address)) return false;
        entry.length = len;
        self.change(memory.len, len);
        return true;
    }
    fn remap(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, address: usize) ?[*]u8 {
        const self: *@This() = @ptrCast(@alignCast(raw));
        self.mutex.lockUncancelable(std.testing.io);
        defer self.mutex.unlock(std.testing.io);
        if (self.force_moving_growth and len > memory.len) return null;
        const entry = self.slot(memory);
        const pointer = self.backing.rawRemap(memory, alignment, len, address) orelse return null;
        entry.* = .{ .pointer = pointer, .length = len };
        self.change(memory.len, len);
        return pointer;
    }
    fn free(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, address: usize) void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        self.mutex.lockUncancelable(std.testing.io);
        defer self.mutex.unlock(std.testing.io);
        const entry = self.slot(memory);
        self.backing.rawFree(memory, alignment, address);
        entry.* = .{};
        self.change(memory.len, 0);
    }
};
