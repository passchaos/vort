//! Caller alias publication, refusal and borrowed full-input decode checks.
const std = @import("std");
const h = @import("zstd_magicless_helpers.zig");
const a = std.testing.allocator;

pub fn contracts(comptime Z: type) !void {
    const Cases = Suite(Z);
    try Cases.aliases();
    try Cases.invalidAndCorruptPublication();
    try Cases.noInputClone();
}
fn Suite(comptime Z: type) type {
    return struct {
        fn aliases() !void {
            const wire = try h.rawAlloc(a, h.plain, false);
            defer a.free(wire);
            const opts: Z.FrameDecodeOptions = .{ .format = .magicless, .expected_output_len = h.plain.len };
            var storage: [256]u8 = @splat(0xa5);
            @memcpy(storage[16..][0..wire.len], wire);
            const before = storage;
            var denied = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
            try std.testing.expectError(error.OutOfMemory, Z.decodeFrameIntoWithOptions(denied.allocator(), storage[16..][0..wire.len], storage[0..h.plain.len], opts));
            try std.testing.expectEqualSlices(u8, &before, &storage);
            try std.testing.expectEqual(h.plain.len, try Z.decodeFrameIntoWithOptions(a, storage[16..][0..wire.len], storage[0..h.plain.len], opts));
            try std.testing.expectEqualSlices(u8, h.plain, storage[0..h.plain.len]);
            try std.testing.expectEqualSlices(u8, before[h.plain.len..], storage[h.plain.len..]);

            const initial = try std.mem.concat(a, u8, &.{ "caller-prefix", wire });
            defer a.free(initial);
            var heap = std.testing.FailingAllocator.init(a, .{ .resize_fail_index = 0 });
            var appended = std.ArrayList(u8).fromOwnedSlice(try heap.allocator().dupe(u8, initial));
            var alive = true;
            defer if (alive) appended.deinit(heap.allocator());
            const pointer = appended.items.ptr;
            const capacity = appended.capacity;
            for (0..2) |fail_after| {
                heap.fail_index = heap.alloc_index + fail_after;
                try std.testing.expectError(error.OutOfMemory, Z.decodeFrameAppendWithOptions(heap.allocator(), &appended, appended.items[13..], opts));
                try std.testing.expectEqual(pointer, appended.items.ptr);
                try std.testing.expectEqual(capacity, appended.capacity);
                try std.testing.expectEqualSlices(u8, initial, appended.items);
            }
            heap.fail_index = std.math.maxInt(usize);
            try std.testing.expectEqual(h.plain.len, try Z.decodeFrameAppendWithOptions(heap.allocator(), &appended, appended.items[13..], opts));
            try std.testing.expectEqualSlices(u8, initial, appended.items[0..initial.len]);
            try std.testing.expectEqualSlices(u8, h.plain, appended.items[initial.len..]);
            appended.deinit(heap.allocator());
            alive = false;
            try std.testing.expectEqual(heap.allocated_bytes, heap.freed_bytes);
        }

        fn invalidAndCorruptPublication() !void {
            const wire = try h.rawAlloc(a, h.plain, true);
            defer a.free(wire);
            const dictionary = Z.NativeDictionary.init(1, h.plain);
            const entries = [_]Z.NativeDictionary{dictionary};
            const catalog = Z.NativeDictionarySet.init(&entries);
            var heap = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
            const invalid: Z.FrameDecodeOptions = .{ .format = .magicless, .dictionary = dictionary, .dictionary_set = catalog };
            try std.testing.expectError(error.InvalidBlockPlan, Z.decodeFrameAllocWithOptions(heap.allocator(), wire, invalid));
            try std.testing.expectError(error.InvalidBlockPlan, Z.decodedFrameSizeWithOptions(wire, invalid));
            var output: [h.plain.len + 17]u8 = @splat(0xa5);
            try std.testing.expectError(error.InvalidBlockPlan, Z.decodeFrameIntoWithOptions(heap.allocator(), wire, &output, invalid));
            try h.untouched(&output);
            try std.testing.expectError(error.InvalidBlockPlan, Z.decodeFrameAllocWithOptions(heap.allocator(), wire, .{ .format = .magicless, .expected_output_len = 1, .max_output_len = 0 }));
            try std.testing.expectEqual(@as(usize, 0), heap.alloc_index);
            try std.testing.expect(!heap.has_induced_failure);
            const corrupt = try a.dupe(u8, wire);
            defer a.free(corrupt);
            corrupt[corrupt.len - 1] ^= 1;
            try std.testing.expectError(error.ChecksumMismatch, Z.decodeFrameIntoWithOptions(a, corrupt, &output, .{ .format = .magicless }));
            try h.untouched(&output);
            var appended = std.ArrayList(u8).fromOwnedSlice(try a.dupe(u8, "caller-prefix"));
            defer appended.deinit(a);
            const pointer = appended.items.ptr;
            const capacity = appended.capacity;
            try std.testing.expectError(error.ChecksumMismatch, Z.decodeFrameAppendWithOptions(a, &appended, corrupt, .{ .format = .magicless }));
            try std.testing.expectEqualStrings("caller-prefix", appended.items);
            try std.testing.expectEqual(pointer, appended.items.ptr);
            try std.testing.expectEqual(capacity, appended.capacity);
        }

        fn noInputClone() !void {
            // Real zero-length raw blocks enlarge the wire without inventing a
            // huge plaintext size. The complete frame still regenerates "x".
            var wire: std.ArrayList(u8) = .empty;
            defer wire.deinit(a);
            try wire.appendSlice(a, &.{ 0x20, 1 });
            for (0..512) |_| try wire.appendSlice(a, &.{ 0, 0, 0 });
            try wire.appendSlice(a, &.{ 9, 0, 0, 'x' });
            const scanned = try h.scan(wire.items, true);
            try std.testing.expectEqual(@as(usize, 513), scanned.blocks);
            try std.testing.expectEqual(wire.items.len, scanned.end);
            var probe: BorrowedInputProbe = .{ .backing = a, .forbidden_min = wire.items.len };
            const allocator = probe.allocator();
            const opts: Z.FrameDecodeOptions = .{ .format = .magicless, .expected_output_len = 1, .max_output_len = 1 };
            const decoded = try Z.decodeFrameAllocWithOptions(allocator, wire.items, opts);
            defer allocator.free(decoded);
            try std.testing.expectEqualStrings("x", decoded);
            var output: [17]u8 = @splat(0xa5);
            try std.testing.expectEqual(@as(usize, 1), try Z.decodeFrameIntoWithOptions(allocator, wire.items, output[0..1], opts));
            try std.testing.expectEqual(@as(u8, 'x'), output[0]);
            try h.untouched(output[1..]);
            try std.testing.expectEqual(@as(usize, 0), probe.rejected);
            try std.testing.expect(probe.largest_request < wire.items.len);
        }
    };
}

/// Refuse full-wire-sized requests, while allowing arbitrary smaller decoder
/// output/work allocations. This is not a tiny total-memory-budget assumption.
const BorrowedInputProbe = struct {
    backing: std.mem.Allocator,
    forbidden_min: usize,
    largest_request: usize = 0,
    rejected: usize = 0,
    fn allocator(self: *@This()) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn allowed(self: *@This(), len: usize) bool {
        self.largest_request = @max(self.largest_request, len);
        if (len >= self.forbidden_min) {
            self.rejected += 1;
            return false;
        }
        return true;
    }
    fn alloc(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, address: usize) ?[*]u8 {
        const self: *@This() = @ptrCast(@alignCast(raw));
        if (!self.allowed(len)) return null;
        return self.backing.rawAlloc(len, alignment, address);
    }
    fn resize(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, address: usize) bool {
        const self: *@This() = @ptrCast(@alignCast(raw));
        if (!self.allowed(len)) return false;
        return self.backing.rawResize(memory, alignment, len, address);
    }
    fn remap(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, address: usize) ?[*]u8 {
        const self: *@This() = @ptrCast(@alignCast(raw));
        if (!self.allowed(len)) return null;
        return self.backing.rawRemap(memory, alignment, len, address);
    }
    fn free(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, address: usize) void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        self.backing.rawFree(memory, alignment, address);
    }
};
