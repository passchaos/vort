//! Public decode contracts use a physical requested-byte observer, independent
//! of the codec's quota implementation and its control/workspace layout.
const std = @import("std");
const wire = @import("../zstd_magicless_helpers.zig");
pub const a = std.testing.allocator;
pub const plain = "decode quota publication abcdefghabcdefghXabcdefgh literal tail\n" ** 3;
pub const rawAlloc = wire.rawAlloc;
pub const standardAlloc = wire.standardAlloc;
pub const untouched = wire.untouched;

pub const Tracker = struct {
    backing: std.mem.Allocator,
    live: usize = 0,
    peak: usize = 0,
    attempts: usize = 0,
    failures: usize = 0,
    fail_at: ?usize = null,
    move_growth: bool = true,

    pub fn init(backing: std.mem.Allocator) Tracker {
        return .{ .backing = backing };
    }
    pub fn allocator(self: *Tracker) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    pub fn begin(self: *Tracker) void {
        self.peak = self.live;
        self.attempts = 0;
        self.failures = 0;
    }
    fn change(self: *Tracker, old: usize, new: usize) void {
        std.debug.assert(self.live >= old);
        self.live = self.live - old + new;
        self.peak = @max(self.peak, self.live);
    }
    fn alloc(ptr: *anyopaque, len: usize, alignment: std.mem.Alignment, ret: usize) ?[*]u8 {
        const self: *Tracker = @ptrCast(@alignCast(ptr));
        const index = self.attempts;
        self.attempts += 1;
        if (self.fail_at) |at| if (index >= at) {
            self.failures += 1;
            return null;
        };
        const result = self.backing.rawAlloc(len, alignment, ret) orelse return null;
        self.change(0, len);
        return result;
    }
    fn resize(ptr: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) bool {
        const self: *Tracker = @ptrCast(@alignCast(ptr));
        if (self.move_growth and len > memory.len) return false;
        if (!self.backing.rawResize(memory, alignment, len, ret)) return false;
        self.change(memory.len, len);
        return true;
    }
    fn remap(ptr: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) ?[*]u8 {
        const self: *Tracker = @ptrCast(@alignCast(ptr));
        if (self.move_growth and len > memory.len) return null;
        const result = self.backing.rawRemap(memory, alignment, len, ret) orelse return null;
        self.change(memory.len, len);
        return result;
    }
    fn free(ptr: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret: usize) void {
        const self: *Tracker = @ptrCast(@alignCast(ptr));
        self.backing.rawFree(memory, alignment, ret);
        self.change(memory.len, 0);
    }
};

pub fn profileMatches(profile: anytype, tracker: *const Tracker, live: usize) !void {
    try std.testing.expect(profile.available);
    try std.testing.expectEqual(tracker.peak, profile.peak_requested_bytes);
    try std.testing.expectEqual(live, profile.live_requested_bytes);
}

pub fn hexAlloc(comptime bytes: []const u8) ![]u8 {
    const hex = std.mem.trim(u8, bytes, " \t\r\n");
    const result = try a.alloc(u8, hex.len / 2);
    errdefer a.free(result);
    _ = try std.fmt.hexToBytes(result, hex);
    return result;
}

pub fn compressedAlloc() ![]u8 {
    const original = try hexAlloc(@embedFile("../../zstd/testdata/libzstd-numbered-json.frame.hex"));
    defer a.free(original);
    const payload = try compressedPlainAlloc();
    defer a.free(payload);
    const result = try a.alloc(u8, original.len + 4);
    @memcpy(result[0..original.len], original);
    result[4] |= 4;
    std.mem.writeInt(u32, result[original.len..][0..4], @truncate(std.hash.XxHash64.hash(0, payload)), .little);
    return result;
}
pub fn compressedPlainAlloc() ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(a);
    for (0..20) |i| {
        var line: [128]u8 = undefined;
        const formatted = try std.fmt.bufPrint(&line, "{{\"k\":\"{d:0>4}\",\"n\":{d},\"txt\":\"abcdefghijklmnopqrstuvwxyz0123456789\"}}\n", .{ i, i });
        try result.appendSlice(a, formatted);
    }
    return result.toOwnedSlice(a);
}

/// Build a real single-block RLE frame, using only wire-format arithmetic.
pub fn rleAlloc(payload: []const u8, magicless: bool) ![]u8 {
    std.debug.assert(payload.len >= 256 and payload.len <= 65791);
    const prefix: usize = if (magicless) 0 else 4;
    const result = try a.alloc(u8, prefix + 3 + 3 + 1 + 4);
    if (!magicless) @memcpy(result[0..4], &wire.magic);
    result[prefix] = 0x64;
    std.mem.writeInt(u16, result[prefix + 1 ..][0..2], @intCast(payload.len - 256), .little);
    std.mem.writeInt(u24, result[prefix + 3 ..][0..3], (@as(u24, @intCast(payload.len)) << 3) | 3, .little);
    result[prefix + 6] = payload[0];
    std.mem.writeInt(u32, result[prefix + 7 ..][0..4], @truncate(std.hash.XxHash64.hash(0, payload)), .little);
    return result;
}

test "Zstd decode quota observer counts moving growth overlap" {
    var tracker = Tracker.init(a);
    const heap = tracker.allocator();
    var list = std.ArrayList(u8).fromOwnedSlice(try heap.dupe(u8, "old"));
    const old_capacity = list.capacity;
    try list.appendSlice(heap, "a larger new allocation");
    try std.testing.expectEqual(old_capacity + list.capacity, tracker.peak);
    list.deinit(heap);
    try std.testing.expectEqual(@as(usize, 0), tracker.live);
}
