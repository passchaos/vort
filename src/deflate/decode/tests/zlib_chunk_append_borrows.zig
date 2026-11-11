//! Concatenated wrapper staging must consume borrowed reads before publishing.
const std = @import("std");
const t = std.testing;
const List = std.ArrayList(u8);
const S = @import("wrapper_chunk_borrows_support.zig");
const preset = "abcdefghijklmnop";
const capacity = 512;
const Family = enum { plain, dictionary, options, dictionary_options, exact, dictionary_exact, options_exact, dictionary_options_exact, limited, dictionary_limited, options_limited, dictionary_options_limited };

fn hasDictionary(comptime family: Family) bool {
    return @intFromEnum(family) % 2 == 1;
}

fn append(comptime D: type, comptime family: Family, allocator: std.mem.Allocator, list: *List, chunks: []const []const u8, scratch: []u8, dict: []const u8, plain_len: usize) !usize {
    return switch (family) {
        .plain => D.decodeZlibConcatenatedChunksAppend(allocator, list, chunks, scratch),
        .dictionary => D.decodeZlibConcatenatedChunksAppendWithDictionary(allocator, list, chunks, scratch, dict),
        .options => D.decodeZlibConcatenatedChunksAppendWithOptions(allocator, list, chunks, scratch, .{}),
        .dictionary_options => D.decodeZlibConcatenatedChunksAppendWithDictionaryAndOptions(allocator, list, chunks, scratch, dict, .{}),
        .exact => D.decodeZlibConcatenatedChunksAppendExactSize(allocator, list, chunks, scratch, plain_len),
        .dictionary_exact => D.decodeZlibConcatenatedChunksAppendWithDictionaryExactSize(allocator, list, chunks, scratch, dict, plain_len),
        .options_exact => D.decodeZlibConcatenatedChunksAppendWithOptionsExactSize(allocator, list, chunks, scratch, .{}, plain_len),
        .dictionary_options_exact => D.decodeZlibConcatenatedChunksAppendWithDictionaryAndOptionsExactSize(allocator, list, chunks, scratch, dict, .{}, plain_len),
        .limited => D.decodeZlibConcatenatedChunksAppendLimited(allocator, list, chunks, scratch, plain_len),
        .dictionary_limited => D.decodeZlibConcatenatedChunksAppendWithDictionaryLimited(allocator, list, chunks, scratch, dict, plain_len),
        .options_limited => D.decodeZlibConcatenatedChunksAppendWithOptionsLimited(allocator, list, chunks, scratch, .{}, plain_len),
        .dictionary_options_limited => D.decodeZlibConcatenatedChunksAppendWithDictionaryAndOptionsLimited(allocator, list, chunks, scratch, dict, .{}, plain_len),
    };
}

const Fixture = struct {
    wire: []u8,
    plain: []u8,
    fn deinit(self: Fixture) void {
        t.allocator.free(self.wire);
        t.allocator.free(self.plain);
    }
};

fn fixture(comptime D: type, dict: ?[]const u8) !Fixture {
    const plain = if (dict) |bytes| blk: {
        const result = try t.allocator.alloc(u8, (bytes.len + 1) * 2);
        result[0] = 'X';
        @memcpy(result[1..][0..bytes.len], bytes);
        result[bytes.len + 1] = 'Y';
        @memcpy(result[bytes.len + 2 ..], bytes);
        break :blk result;
    } else try t.allocator.dupe(u8, "hello world");
    errdefer t.allocator.free(plain);
    const boundary = if (dict) |bytes| bytes.len + 1 else 6;
    const first = if (dict) |bytes|
        try D.encodeZlibFixedWithDictionaryAlloc(t.allocator, plain[0..boundary], bytes, D.optionsForLevel(.fast))
    else
        try D.encodeZlibStoredAlloc(t.allocator, plain[0..boundary]);
    defer t.allocator.free(first);
    const second = if (dict) |bytes|
        try D.encodeZlibFixedWithDictionaryAlloc(t.allocator, plain[boundary..], bytes, D.optionsForLevel(.fast))
    else
        try D.encodeZlibStoredAlloc(t.allocator, plain[boundary..]);
    defer t.allocator.free(second);
    const wire = try t.allocator.alloc(u8, first.len + second.len);
    @memcpy(wire[0..first.len], first);
    @memcpy(wire[first.len..], second);
    errdefer t.allocator.free(wire);
    // A separate caller output exercises strict member and dictionary checks.
    var oracle: [128]u8 = undefined;
    const written = if (dict) |bytes| try D.decodeZlibConcatenatedWithDictionary(wire, &oracle, bytes) else try D.decodeZlibConcatenated(wire, &oracle);
    try t.expectEqualSlices(u8, plain, oracle[0..written]);
    if (dict != null) try t.expectError(error.ChecksumMismatch, D.decodeZlibConcatenatedWithDictionary(wire, &oracle, "wrong preset"));
    return .{ .wire = wire, .plain = plain };
}

fn initList() !List {
    var list = try List.initCapacity(t.allocator, capacity);
    @memset(list.allocatedSlice(), 0xa5);
    @memcpy(list.allocatedSlice()[0..3], "pre");
    list.items.len = 3;
    return list;
}

fn expectAppended(fixture_value: Fixture, list: *const List, written: usize) !void {
    try t.expectEqual(fixture_value.plain.len, written);
    try t.expectEqualSlices(u8, "pre", list.items[0..3]);
    try t.expectEqualSlices(u8, fixture_value.plain, list.items[3..]);
}

fn expectUnchanged(before: List, bytes: *const [capacity]u8, list: *const List) !void {
    try t.expectEqual(before.items.ptr, list.items.ptr);
    try t.expectEqual(before.items.len, list.items.len);
    try t.expectEqual(before.capacity, list.capacity);
    try t.expectEqualSlices(u8, bytes, list.allocatedSlice());
}

// Count failed callbacks too; join admission must precede the allocator.
const NoCalls = struct {
    calls: usize = 0,
    fn touch(ctx: *anyopaque) void {
        const self: *NoCalls = @ptrCast(@alignCast(ctx));
        self.calls += 1;
    }
    fn alloc(ctx: *anyopaque, _: usize, _: std.mem.Alignment, _: usize) ?[*]u8 {
        touch(ctx);
        return null;
    }
    fn resize(ctx: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) bool {
        touch(ctx);
        return false;
    }
    fn remap(ctx: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) ?[*]u8 {
        touch(ctx);
        return null;
    }
    fn free(ctx: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize) void {
        touch(ctx);
    }
    fn allocator(self: *NoCalls) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
};

fn independent(comptime D: type, comptime family: Family) !void {
    const value = try fixture(D, if (hasDictionary(family)) preset else null);
    defer value.deinit();
    var list = try initList();
    defer list.deinit(t.allocator);
    const chunks = S.split(value.wire);
    var scratch: [128]u8 = undefined;
    try expectAppended(value, &list, try append(D, family, t.allocator, &list, &chunks, &scratch, preset, value.plain.len));
}

const Site = enum { input_spare, dictionary_spare, dictionary_object };

fn readAliases(comptime D: type, comptime family: Family, comptime site: Site) !void {
    var list = try initList();
    defer list.deinit(t.allocator);
    if (site == .dictionary_spare) @memcpy(list.allocatedSlice()[3..][0..preset.len], preset);
    const dict: []const u8 = switch (site) {
        .input_spare => preset,
        .dictionary_spare => list.allocatedSlice()[3..][0..preset.len],
        .dictionary_object => std.mem.asBytes(&list),
    };
    const value = try fixture(D, if (hasDictionary(family)) dict else null);
    defer value.deinit();
    var chunks = S.split(value.wire);
    var scratch: [128]u8 = undefined;
    var join_scratch: []u8 = &scratch;
    if (site == .input_spare) {
        @memcpy(list.allocatedSlice()[128..][0..value.wire.len], value.wire);
        chunks = .{ "", list.allocatedSlice()[128..][0..value.wire.len], "" };
        join_scratch = list.allocatedSlice(); // Unused on the borrowed single path.
    }
    const before = list;
    var allocation_before: [capacity]u8 = undefined;
    @memcpy(&allocation_before, list.allocatedSlice());
    const object_before = S.copyBytes(List, &list);
    // Count all reached staging requests, forcing reallocations to allocate.
    var count = t.FailingAllocator.init(t.allocator, .{ .resize_fail_index = 0 });
    try expectAppended(value, &list, try append(D, family, count.allocator(), &list, &chunks, join_scratch, dict, value.plain.len));
    try t.expect(count.allocations > 0);
    try t.expectEqual(count.allocated_bytes, count.freed_bytes);
    list = before;
    @memcpy(list.allocatedSlice(), &allocation_before);
    for (0..count.allocations) |fail_index| {
        var failing = t.FailingAllocator.init(t.allocator, .{ .fail_index = fail_index, .resize_fail_index = 0 });
        try t.expectError(error.OutOfMemory, append(D, family, failing.allocator(), &list, &chunks, join_scratch, dict, value.plain.len));
        try t.expect(failing.has_induced_failure);
        try t.expectEqual(failing.allocated_bytes, failing.freed_bytes);
        try expectUnchanged(before, &allocation_before, &list);
        try t.expectEqualSlices(u8, &object_before, std.mem.asBytes(&list));
    }
    try expectAppended(value, &list, try append(D, family, t.allocator, &list, &chunks, join_scratch, dict, value.plain.len));
    if (site == .input_spare) {
        try t.expectEqualSlices(u8, value.wire, list.allocatedSlice()[128..][0..value.wire.len]);
        list = before;
        @memcpy(list.allocatedSlice(), &allocation_before);
        const identity = S.split(list.allocatedSlice()[128..][0..value.wire.len]);
        try expectAppended(value, &list, try append(D, family, t.allocator, &list, &identity, list.allocatedSlice()[128..], dict, value.plain.len));
    }
}

const Conflict = enum { allocation, object, dictionary };

fn writes(comptime D: type, comptime family: Family, comptime conflict: Conflict) !void {
    const value = try fixture(D, if (hasDictionary(family)) preset else null);
    defer value.deinit();
    const Holder = struct { list: List, tail: [128]u8 };
    var holder: Holder = undefined;
    @memset(std.mem.asBytes(&holder), 0xa5);
    holder.list = try initList();
    defer holder.list.deinit(t.allocator);
    const before = holder.list;
    const holder_before = S.copyBytes(Holder, &holder);
    var allocation_before: [capacity]u8 = undefined;
    @memcpy(&allocation_before, holder.list.allocatedSlice());
    var dict_scratch: [128]u8 = @splat(0xa5);
    @memcpy(dict_scratch[0..preset.len], preset);
    const dict_before = dict_scratch;
    const dict: []const u8 = if (conflict == .dictionary) dict_scratch[0..preset.len] else preset;
    const scratch: []u8 = switch (conflict) {
        .allocation => holder.list.allocatedSlice()[32..],
        .object => std.mem.asBytes(&holder),
        .dictionary => &dict_scratch,
    };
    const chunks = S.split(value.wire);
    var spy: NoCalls = .{};
    try t.expectError(error.InvalidBlockPlan, append(D, family, spy.allocator(), &holder.list, &chunks, scratch, dict, 0));
    try t.expectEqual(@as(usize, 0), spy.calls);
    try expectUnchanged(before, &allocation_before, &holder.list);
    try t.expectEqualSlices(u8, &holder_before, std.mem.asBytes(&holder));
    try t.expectEqualSlices(u8, &dict_before, &dict_scratch);
    var independent_scratch: [128]u8 = undefined;
    try expectAppended(value, &holder.list, try append(D, family, t.allocator, &holder.list, &chunks, &independent_scratch, dict, value.plain.len));
}

pub fn contracts(comptime D: type) !void {
    inline for (comptime std.meta.tags(Family)) |family| {
        errdefer std.debug.print("zlib concat chunk append family: {s}\n", .{@tagName(family)});
        try independent(D, family);
        inline for (comptime std.meta.tags(Site)) |site| {
            if (comptime site != .input_spare and !hasDictionary(family)) continue;
            try readAliases(D, family, site);
        }
        inline for (comptime std.meta.tags(Conflict)) |conflict| {
            if (comptime conflict == .dictionary and !hasDictionary(family)) continue;
            try writes(D, family, conflict);
        }
    }
}
