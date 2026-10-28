const std = @import("std");
const bwt = @import("bwt.zig");
const full = @import("test_support/bwt_full_doubling.zig");
const unique_reference = @import("test_support/bwt_unique_classes.zig");
const a = std.testing.allocator;

fn leastPeriod(input: []const u8) usize {
    for (1..input.len + 1) |period| {
        if (input.len % period != 0) continue;
        var equal = true;
        for (input, 0..) |byte, index| {
            if (byte != input[index % period]) {
                equal = false;
                break;
            }
        }
        if (equal) return period;
    }
    unreachable;
}

fn inverse(input: []const u8, transformed: anytype) !void {
    try std.testing.expectEqual(input.len, transformed.bytes.len);
    try std.testing.expect(transformed.original_pointer < input.len);
    var counts: [256]usize = @splat(0);
    for (transformed.bytes) |byte| counts[byte] += 1;
    var starts: [256]usize = undefined;
    var offset: usize = 0;
    for (&starts, counts) |*start, count| {
        start.* = offset;
        offset += count;
    }
    const lf = try a.alloc(usize, input.len);
    defer a.free(lf);
    var seen: [256]usize = @splat(0);
    for (transformed.bytes, 0..) |byte, row| {
        lf[row] = starts[byte] + seen[byte];
        seen[byte] += 1;
    }
    var row: usize = transformed.original_pointer;
    var remaining = input.len;
    while (remaining > 0) {
        remaining -= 1;
        try std.testing.expectEqual(input[remaining], transformed.bytes[row]);
        row = lf[row];
    }
}

fn check(input: []const u8) !void {
    const expected = try full.transformAlloc(a, input);
    defer expected.deinit(a);
    const actual = try bwt.transformAlloc(a, input);
    defer actual.deinit(a);
    try std.testing.expectEqualSlices(u8, expected.bytes, actual.bytes);
    try std.testing.expectEqual(expected.original_pointer, actual.original_pointer);
    try inverse(input, actual);
}

fn random(input: []u8) void {
    var seed: u64 = 0x8b273d64f1239abe;
    for (input) |*byte| {
        seed ^= seed >> 12;
        seed ^= seed << 25;
        seed ^= seed >> 27;
        byte.* = @truncate((seed *% 0x2545f4914f6cdd1d) >> 56);
    }
}

const Tracker = struct {
    live: usize = 0,
    peak: usize = 0,
    sizes: [16]usize = undefined,
    used: usize = 0,

    fn allocator(self: *@This()) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn alloc(raw: *anyopaque, length: usize, alignment: std.mem.Alignment, ret: usize) ?[*]u8 {
        const self: *Tracker = @ptrCast(@alignCast(raw));
        const memory = a.rawAlloc(length, alignment, ret) orelse return null;
        self.sizes[self.used] = length;
        self.used += 1;
        self.live += length;
        self.peak = @max(self.peak, self.live);
        return memory;
    }
    fn resize(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) bool {
        return false;
    }
    fn remap(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) ?[*]u8 {
        return null;
    }
    fn free(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret: usize) void {
        const self: *Tracker = @ptrCast(@alignCast(raw));
        self.live -= memory.len;
        a.rawFree(memory, alignment, ret);
    }
};

fn geometry(input: []const u8, period: usize) !void {
    var generic: Tracker = .{};
    const before = try unique_reference.transformAlloc(generic.allocator(), input);
    defer before.deinit(generic.allocator());
    var variant: Tracker = .{};
    const after = try bwt.transformAlloc(variant.allocator(), input);
    defer after.deinit(variant.allocator());
    const expected_generic = [_]usize{ 4 * input.len, 4 * input.len, 4 * input.len, 4 * input.len, @sizeOf(usize) * @max(input.len, 256), input.len };
    try std.testing.expectEqualSlices(usize, &expected_generic, generic.sizes[0..generic.used]);
    try std.testing.expectEqualSlices(u8, before.bytes, after.bytes);
    try std.testing.expectEqual(before.original_pointer, after.original_pointer);
    if (period == input.len) {
        try std.testing.expectEqualSlices(usize, generic.sizes[0..generic.used], variant.sizes[0..variant.used]);
        try std.testing.expectEqual(generic.peak, variant.peak);
    } else {
        const expected_variant = [_]usize{ 4 * input.len, 4 * period, 4 * period, 4 * period, 4 * period, @sizeOf(usize) * @max(period, 256), period, input.len };
        try std.testing.expectEqualSlices(usize, &expected_variant, variant.sizes[0..variant.used]);
        const base_peak = 16 * period + @sizeOf(usize) * @max(period, 256) + period;
        try std.testing.expectEqual(@max(4 * input.len + base_peak, 5 * input.len + period), variant.peak);
    }
    defer {
        // Only returned output allocations survive until the deferred deinit.
        std.testing.expectEqual(input.len, generic.live) catch @panic("generic scratch leaked");
        std.testing.expectEqual(input.len, variant.live) catch @panic("period scratch leaked");
    }
}

fn failures() !void {
    var unique: [256]u8 = undefined;
    for (&unique, 0..) |*byte, index| byte.* = @intCast(index);
    const inputs = [_][]const u8{ &unique, "ababa", "abcabcab", "A" ** 64, "abac" ** 16, "baa" ** 7 };
    for (inputs) |input| {
        const period = leastPeriod(input);
        const count: usize = if (period < input.len) 8 else 6;
        for (0..count) |failure| {
            var allocator = std.testing.FailingAllocator.init(a, .{ .fail_index = failure });
            try std.testing.expectError(error.OutOfMemory, bwt.transformAlloc(allocator.allocator(), input));
            try std.testing.expectEqual(allocator.allocated_bytes, allocator.freed_bytes);
        }
        const Run = struct {
            fn run(allocator: std.mem.Allocator, bytes: []const u8) !void {
                const block = try bwt.transformAlloc(allocator, bytes);
                defer block.deinit(allocator);
            }
        };
        try std.testing.checkAllAllocationFailures(a, Run.run, .{input});
        try geometry(input, period);
    }
    var zero = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
    try std.testing.expectError(error.InvalidBzip2Stream, bwt.transformAlloc(zero.allocator(), ""));
    const too_large = try a.alloc(u8, 900001);
    defer a.free(too_large);
    try std.testing.expectError(error.InvalidBzip2Stream, bwt.transformAlloc(zero.allocator(), too_large));
    try std.testing.expectEqual(@as(usize, 0), zero.alloc_index);
}

fn exhaustive() !void {
    var input: [8]u8 = undefined;
    var total: usize = 0;
    for (1..9) |length| {
        var combinations: usize = 1;
        for (0..length) |_| combinations *= 3;
        for (0..combinations) |value| {
            var digits = value;
            for (input[0..length]) |*byte| {
                byte.* = @intCast('a' + digits % 3);
                digits /= 3;
            }
            try check(input[0..length]);
            total += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 9840), total);
}

fn periodsAndControls() !void {
    const fixtures = [_][]const u8{ "a" ** 5, "ba" ** 5, "baa" ** 3, "ababa", "abcabcab", "baabaaab", "abac" ** 17, "cbaa" ** 31 };
    for (fixtures) |input| {
        try check(input);
        try geometry(input, leastPeriod(input));
    }
    const pointers = .{ .{ "a" ** 5, @as(u32, 2) }, .{ "ba" ** 5, @as(u32, 7) }, .{ "baa" ** 3, @as(u32, 8) } };
    inline for (pointers) |item| {
        const block = try bwt.transformAlloc(a, item[0]);
        defer block.deinit(a);
        try std.testing.expectEqual(item[1], block.original_pointer);
    }
    for ([_]usize{ 31, 65, 127, 257, 513 }) |period| {
        const input = try a.alloc(u8, period * 3);
        defer a.free(input);
        @memset(input, 'a');
        for (0..3) |repeat| input[(repeat + 1) * period - 1] = 'Z';
        try check(input);
        try geometry(input, period);
    }
    for ([_]usize{ 2, 7, 31, 255, 257, 1025 }) |length| {
        const input = try a.alloc(u8, length);
        defer a.free(input);
        random(input);
        try check(input);
        try geometry(input, leastPeriod(input));
    }
}

fn large() !void {
    for ([_]usize{ 65536, 900000 }) |length| {
        const input = try a.alloc(u8, length);
        defer a.free(input);
        @memset(input, 'a');
        try check(input);
        try geometry(input, 1);
        for (input, 0..) |*byte, index| byte.* = "abac"[index % 4];
        try check(input);
        try geometry(input, 4);
    }
}

test "Bzip2 periodic BWT exhaustive ternary rotations preserve full doubling" {
    try exhaustive();
}
test "Bzip2 periodic BWT rejects non-dividing prefix periods and preserves origin ties" {
    try periodsAndControls();
}
test "Bzip2 periodic BWT maximum blocks preserve exact output and requested heap" {
    try large();
}
test "Bzip2 periodic BWT allocation paths unwind and invalid lengths allocate nothing" {
    try failures();
}
