const std = @import("std");
const deflate = @import("../../deflate.zig");
const checksum = @import("../../checksum.zig");
const lz77 = @import("../../lz77.zig");
const hint = @import("alloc_hint.zig");
const a = std.testing.allocator;

const TrackingAllocator = struct {
    backing: std.mem.Allocator,
    max_request: usize = 0,
    denied_large_requests: usize = 0,
    allocations: usize = 0,
    live: usize = 0,
    limit: usize = 64 * 1024,

    fn allocator(self: *@This()) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn admit(self: *@This(), n: usize) bool {
        self.max_request = @max(self.max_request, n);
        if (n <= self.limit) return true;
        self.denied_large_requests += 1;
        return false;
    }
    fn alloc(ctx: *anyopaque, n: usize, alignment: std.mem.Alignment, ret: usize) ?[*]u8 {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        if (!self.admit(n)) return null;
        const pointer = self.backing.rawAlloc(n, alignment, ret) orelse return null;
        self.allocations += 1;
        self.live += n;
        return pointer;
    }
    fn resize(ctx: *anyopaque, old: []u8, alignment: std.mem.Alignment, n: usize, ret: usize) bool {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        if (!self.admit(n) or !self.backing.rawResize(old, alignment, n, ret)) return false;
        self.live = self.live - old.len + n;
        return true;
    }
    fn remap(ctx: *anyopaque, old: []u8, alignment: std.mem.Alignment, n: usize, ret: usize) ?[*]u8 {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        if (!self.admit(n)) return null;
        const pointer = self.backing.rawRemap(old, alignment, n, ret) orelse return null;
        self.live = self.live - old.len + n;
        return pointer;
    }
    fn free(ctx: *anyopaque, old: []u8, alignment: std.mem.Alignment, ret: usize) void {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        self.live -= old.len;
        self.backing.rawFree(old, alignment, ret);
    }
};

test "gzip allocation hint rejects impossible ISIZE before requesting huge output" {
    const wire = try deflate.encodeGzipFixedAlloc(a, "gzip allocation hint payload");
    defer a.free(wire);
    std.mem.writeInt(u32, wire[wire.len - 4 ..][0..4], std.math.maxInt(u32), .little);
    var tracked: TrackingAllocator = .{ .backing = a };
    try std.testing.expectError(error.SizeMismatch, deflate.decodeGzipAlloc(tracked.allocator(), wire));
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
    try std.testing.expectEqual(@as(usize, 0), tracked.denied_large_requests);
    try std.testing.expect(tracked.max_request <= tracked.limit);
}

test "gzip allocation hint missing dynamic footer returns truncation without speculative giant output" {
    const raw = try deflate.encodeRawDynamicLiteralAlloc(a, "wrapped dynamic truncated tail");
    defer a.free(raw);
    raw[0] &= 0xfe;
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(a);
    try frame.appendSlice(a, &.{ 0x1f, 0x8b, 8, 0, 0, 0, 0, 0, 0, 3 });
    try frame.appendSlice(a, raw);
    var tracked: TrackingAllocator = .{ .backing = a };
    try std.testing.expectError(error.TruncatedFrame, deflate.decodeGzipAlloc(tracked.allocator(), frame.items));
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
    try std.testing.expectEqual(@as(usize, 0), tracked.denied_large_requests);
}

test "gzip allocation hint undersized output is released before raw fallback and quota refusal" {
    const plain = "small allocation hint has a larger actual payload";
    const wire = try deflate.encodeGzipFixedAlloc(a, plain);
    defer a.free(wire);
    for ([_]u32{ 1, 7 }) |claimed| {
        std.mem.writeInt(u32, wire[wire.len - 4 ..][0..4], claimed, .little);
        var tracked: TrackingAllocator = .{ .backing = a };
        try std.testing.expectError(error.SizeMismatch, deflate.decodeGzipAlloc(tracked.allocator(), wire));
        try std.testing.expect(tracked.allocations >= 2);
        try std.testing.expectEqual(@as(usize, 0), tracked.live);
        try std.testing.expectEqual(@as(usize, 0), tracked.denied_large_requests);
    }
    std.mem.writeInt(u32, wire[wire.len - 4 ..][0..4], 1, .little);
    var limited: TrackingAllocator = .{ .backing = a };
    try std.testing.expectError(error.OutputLimitExceeded, deflate.decodeGzipAllocLimited(limited.allocator(), wire, 3));
    try std.testing.expectEqual(@as(usize, 0), limited.live);
}

test "gzip allocation hint retains legal longest matches and propagates actual allocator refusal" {
    var tokens: [33]lz77.Token = undefined;
    tokens[0] = .{ .literal = 'A' };
    for (tokens[1..]) |*token| token.* = .{ .match = .{ .length = lz77.max_match_len, .distance = 1 } };
    const plain: [1 + 32 * lz77.max_match_len]u8 = @splat('A');
    for ([_]bool{ false, true }) |dynamic| {
        const raw = if (dynamic) try deflate.encodeRawDynamicTokensAlloc(a, &tokens) else try deflate.encodeRawFixedTokensAlloc(a, &tokens);
        defer a.free(raw);
        try std.testing.expect(hint.allows(raw.len, plain.len));
        var frame: std.ArrayList(u8) = .empty;
        defer frame.deinit(a);
        try frame.appendSlice(a, &.{ 0x1f, 0x8b, 8, 0, 0, 0, 0, 0, 0, 3 });
        try frame.appendSlice(a, raw);
        var footer: [8]u8 = undefined;
        std.mem.writeInt(u32, footer[0..4], checksum.crc32(&plain), .little);
        std.mem.writeInt(u32, footer[4..8], plain.len, .little);
        try frame.appendSlice(a, &footer);
        var tracked: TrackingAllocator = .{ .backing = a };
        const decoded = try deflate.decodeGzipAlloc(tracked.allocator(), frame.items);
        try std.testing.expectEqualSlices(u8, &plain, decoded);
        try std.testing.expectEqual(plain.len, tracked.max_request);
        tracked.allocator().free(decoded);
        try std.testing.expectEqual(@as(usize, 0), tracked.live);
        var denied = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
        try std.testing.expectError(error.OutOfMemory, deflate.decodeGzipAlloc(denied.allocator(), frame.items));
    }
}

test "gzip allocation hint fallback releases every injected allocation failure" {
    const Test = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const wire = try deflate.encodeGzipFixedAlloc(allocator, "allocation hint fallback graph");
            defer allocator.free(wire);
            std.mem.writeInt(u32, wire[wire.len - 4 ..][0..4], 1, .little);
            const decoded = deflate.decodeGzipAlloc(allocator, wire) catch |err| {
                if (err == error.SizeMismatch) return;
                return err;
            };
            defer allocator.free(decoded);
            return error.TestExpectedError;
        }
    };
    try std.testing.checkAllAllocationFailures(a, Test.run, .{});
}
