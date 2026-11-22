const std = @import("std");
const bits = @import("../bitstream.zig");
const t = std.testing;
const run_limit = (1 << 16) + 127;
const Kind = enum { stored, fixed };
const Fixture = struct {
    raw: []u8,
    puff: []u8,
    exact_bits: u64,
    fn deinit(self: *Fixture) void {
        t.allocator.free(self.raw);
        t.allocator.free(self.puff);
    }
};

fn make(comptime kind: Kind, length: usize, offset: u3) !Fixture {
    var writer: bits.BitWriter = .{};
    defer writer.deinit(t.allocator);
    try writer.writeBits(t.allocator, 0, offset);
    const start: u64 = @as(u64, @intCast(writer.bytes.items.len)) * 8 + writer.bit_index;
    try writer.writeBits(t.allocator, if (kind == .stored) 1 else 3, 3);
    if (kind == .stored) {
        try t.expect(length <= 65535);
        try writer.alignToByte(t.allocator);
        try writer.writeBits(t.allocator, @intCast(length), 16);
        try writer.writeBits(t.allocator, ~@as(u16, @intCast(length)), 16);
    }
    for (0..length) |_| try writer.writeBits(t.allocator, if (kind == .stored) 'A' else 0x8e, 8);
    if (kind == .fixed) try writer.writeBits(t.allocator, 0, 7);
    const exact_bits: u64 = @as(u64, @intCast(writer.bytes.items.len)) * 8 + writer.bit_index - start;
    var puff: std.ArrayList(u8) = .empty;
    errdefer puff.deinit(t.allocator);
    try puff.appendSlice(t.allocator, &.{ 0, 0, if (kind == .stored) 0x80 else 0xa0 });
    var remaining = length;
    while (remaining != 0) {
        const run = @min(remaining, run_limit);
        if (run <= 127) try puff.append(t.allocator, @intCast(run - 1)) else {
            try puff.append(t.allocator, 0x7f);
            var extra: [2]u8 = undefined;
            std.mem.writeInt(u16, &extra, @intCast(run - 128), .big);
            try puff.appendSlice(t.allocator, &extra);
        }
        try puff.appendNTimes(t.allocator, 'A', run);
        remaining -= run;
    }
    try puff.appendSlice(t.allocator, &.{ 0xff, 0x81 });
    return .{ .raw = try writer.toOwnedSlice(t.allocator), .puff = try puff.toOwnedSlice(t.allocator), .exact_bits = exact_bits };
}

fn match(length: u16) !Fixture {
    try t.expect(length == 129 or length == 130);
    var writer: bits.BitWriter = .{};
    defer writer.deinit(t.allocator);
    try writer.writeBits(t.allocator, 3, 3);
    try writer.writeBits(t.allocator, 3, 8); // reversed fixed symbol280
    try writer.writeBits(t.allocator, length - 115, 4);
    try writer.writeBits(t.allocator, 0, 5); // distance1
    try writer.writeBits(t.allocator, 0, 7); // EOB
    var puff: std.ArrayList(u8) = .empty;
    errdefer puff.deinit(t.allocator);
    try puff.appendSlice(t.allocator, &.{ 0, 0, 0xa0 });
    if (length == 129) try puff.append(t.allocator, 0xfe) else try puff.appendSlice(t.allocator, &.{ 0xff, 0 });
    try puff.appendSlice(t.allocator, &.{ 0, 0, 0xff, 0x81 });
    return .{ .raw = try writer.toOwnedSlice(t.allocator), .puff = try puff.toOwnedSlice(t.allocator), .exact_bits = 27 };
}

fn exact(comptime C: type, fixture: *const Fixture, offset: u3) !void {
    const before = try t.allocator.dupe(u8, fixture.raw);
    defer t.allocator.free(before);
    const result = try C.puffDeflatePaddedAlloc(t.allocator, fixture.raw, offset, fixture.raw.len * 8 - offset, fixture.puff.len);
    defer t.allocator.free(result.bytes);
    try t.expectEqual(fixture.exact_bits, result.consumed_bits);
    try t.expectEqualSlices(u8, fixture.puff, result.bytes);
    const restored = try C.huffDeflateAlloc(t.allocator, result.bytes, offset, result.consumed_bits);
    defer t.allocator.free(restored);
    try t.expectEqualSlices(u8, fixture.raw, restored);
    try t.expectError(error.OutputLimitExceeded, C.puffDeflatePaddedAlloc(t.allocator, fixture.raw, offset, fixture.raw.len * 8 - offset, fixture.puff.len - 1));
    try t.expectEqualSlices(u8, before, fixture.raw);
}

fn early(comptime C: type) !void {
    inline for (.{ Kind.stored, Kind.fixed }) |kind| {
        var fixture = try make(kind, 65535, 0);
        defer fixture.deinit();
        const before = try t.allocator.dupe(u8, fixture.raw);
        defer t.allocator.free(before);
        var arena_bytes: [1024]u8 = @splat(0xa5);
        var arena = std.heap.FixedBufferAllocator.init(&arena_bytes);
        var heap = t.FailingAllocator.init(arena.allocator(), .{});
        try t.expectError(error.OutputLimitExceeded, C.puffDeflatePaddedAlloc(heap.allocator(), fixture.raw, 0, fixture.raw.len * 8, 16));
        try t.expectEqual(heap.allocated_bytes, heap.freed_bytes);
        try t.expectEqualSlices(u8, before, fixture.raw);
    }
}

fn precedence(comptime C: type) !void {
    var stored = try make(.stored, 1, 0);
    defer stored.deinit();
    stored.raw[3] ^= 1; // already parsed invalid LEN/NLEN wins over cap0
    try t.expectError(error.InvalidPuffinStream, C.puffDeflatePaddedAlloc(t.allocator, stored.raw, 0, stored.raw.len * 8, 0));

    var literal = try make(.fixed, 128, 0);
    defer literal.deinit();
    // 127 literals use one header byte; the 128th switches to three.
    // At cap133, that known literal is denied before the missing EOB.
    try t.expectError(error.OutputLimitExceeded, C.puffDeflatePaddedAlloc(t.allocator, literal.raw, 0, 3 + 128 * 8, 133));
    try t.expectError(error.TruncatedFrame, C.puffDeflatePaddedAlloc(t.allocator, literal.raw, 0, 3 + 128 * 8, 134));
    inline for (.{ @as(u16, 129), @as(u16, 130) }) |length| {
        var fixture = try match(length);
        defer fixture.deinit();
        // Token129 needs3 bytes, token130 needs4; budget excludes future EOB.
        const expected = if (length == 129) error.TruncatedFrame else error.OutputLimitExceeded;
        try t.expectError(expected, C.puffDeflatePaddedAlloc(t.allocator, fixture.raw, 0, 20, 6));
    }

    var small = try make(.fixed, 4, 0);
    defer small.deinit();
    const trailing = try t.allocator.alloc(u8, small.raw.len + 1);
    defer t.allocator.free(trailing);
    @memcpy(trailing[0..small.raw.len], small.raw);
    trailing[small.raw.len] = 0xff;
    try t.expectError(error.OutputLimitExceeded, C.puffDeflatePaddedAlloc(t.allocator, trailing, 0, trailing.len * 8, small.puff.len - 1));
    try t.expectError(error.TrailingData, C.puffDeflatePaddedAlloc(t.allocator, trailing, 0, trailing.len * 8, small.puff.len));
}

fn allocationFailures(comptime C: type) !void {
    var fixture = try make(.fixed, 128, 0);
    defer fixture.deinit();
    var baseline = t.FailingAllocator.init(t.allocator, .{ .resize_fail_index = 0 });
    const result = try C.puffDeflatePaddedAlloc(baseline.allocator(), fixture.raw, 0, fixture.raw.len * 8, fixture.puff.len);
    baseline.allocator().free(result.bytes);
    try t.expectEqual(baseline.allocated_bytes, baseline.freed_bytes);
    for (0..baseline.alloc_index) |failure| {
        var heap = t.FailingAllocator.init(t.allocator, .{ .fail_index = failure, .resize_fail_index = 0 });
        try t.expectError(error.OutOfMemory, C.puffDeflatePaddedAlloc(heap.allocator(), fixture.raw, 0, fixture.raw.len * 8, fixture.puff.len));
        try t.expectEqual(heap.allocated_bytes, heap.freed_bytes);
        const retry = try C.puffDeflatePaddedAlloc(t.allocator, fixture.raw, 0, fixture.raw.len * 8, fixture.puff.len);
        defer t.allocator.free(retry.bytes);
        try t.expectEqualSlices(u8, fixture.puff, retry.bytes);
    }
}

pub fn contracts(comptime C: type) !void {
    inline for (.{ Kind.stored, Kind.fixed }) |kind| {
        inline for (.{ @as(usize, 0), 1, 126, 127, 128, 129 }) |length| {
            for (0..8) |offset| {
                var fixture = try make(kind, length, @intCast(offset));
                defer fixture.deinit();
                try exact(C, &fixture, @intCast(offset));
            }
        }
    }
    inline for (.{ @as(u16, 129), @as(u16, 130) }) |length| {
        var fixture = try match(length);
        defer fixture.deinit();
        try exact(C, &fixture, 0);
    }
    try early(C);
    try precedence(C);
    try allocationFailures(C);
}
