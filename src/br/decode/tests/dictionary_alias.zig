const std = @import("std");
const h = @import("helpers.zig");
const f = @import("fixtures.zig");
const Kind = enum { raw_bytes, raw_descriptors, raw_both, serialized_bytes, serialized_view, serialized_both };

pub fn contracts(comptime B: type, serialized_wire: []const u8) !void {
    inline for (std.enums.values(Kind)) |kind| {
        inline for (.{ false, true }) |spare| {
            inline for (.{ false, true }) |exact| {
                const peak = try invoke(B, kind, spare, exact, serialized_wire, null, true, false);
                _ = try invoke(B, kind, spare, exact, serialized_wire, null, false, false);
                try std.testing.expectEqual(peak, try invoke(B, kind, spare, exact, serialized_wire, peak, true, false));
                try std.testing.expectEqual(peak, try invoke(B, kind, spare, exact, serialized_wire, peak, false, false));
                _ = try invoke(B, kind, spare, exact, serialized_wire, peak - 1, true, true);
                _ = try invoke(B, kind, spare, exact, serialized_wire, peak - 1, false, true);
            }
        }
    }
}

noinline fn invoke(comptime B: type, comptime kind: Kind, comptime spare: bool, comptime exact: bool, serialized_wire: []const u8, limit: ?usize, comptime profiled: bool, denied: bool) !usize {
    errdefer std.debug.print("Brotli dictionary alias {s}, spare={any}, exact={any}, cap={any}\n", .{ @tagName(kind), spare, exact, limit });
    const raw = kind == .raw_bytes or kind == .raw_descriptors or kind == .raw_both;
    const bytes_alias = kind == .raw_bytes or kind == .raw_both or kind == .serialized_bytes or kind == .serialized_both;
    const view_alias = kind == .raw_descriptors or kind == .raw_both or kind == .serialized_view or kind == .serialized_both;
    const payload = if (raw) f.raw_plain else "hello";
    const frame: []const u8 = if (raw) &f.raw else serialized_wire;
    var tracker = h.CountingAllocator.init(h.a);
    const heap = tracker.allocator();
    const marker = "prefix";
    const capacity = marker.len + f.serialized.len + @sizeOf(B.SerializedSharedDictionary) + 64;
    var out = std.ArrayList(u8).fromOwnedSlice(try heap.alloc(u8, capacity));
    @memset(out.allocatedSlice(), 0xa5);
    out.items.len = if (spare) marker.len else capacity;
    @memcpy(out.items[0..marker.len], marker);
    defer out.deinit(heap);
    const pointer = out.items.ptr;
    var prefixes = [_][]const u8{ f.raw_plain[0..13], f.raw_plain[13..] };
    var parsed: B.SerializedSharedDictionary = undefined;
    var dictionary: B.SharedDictionary = .{};
    if (raw) {
        if (bytes_alias) {
            const storage = out.allocatedSlice()[marker.len + 3 ..][0..f.raw_plain.len];
            @memcpy(storage, f.raw_plain);
            prefixes = .{ storage[0..13], storage[13..] };
        }
        if (view_alias) {
            const start = std.mem.alignForward(usize, @intFromPtr(pointer) + marker.len + f.serialized.len, @alignOf([]const u8));
            const descriptors: *[2][]const u8 = @ptrFromInt(start);
            descriptors.* = prefixes;
            dictionary.raw_prefixes = descriptors;
        } else dictionary.raw_prefixes = &prefixes;
    } else {
        const bytes = if (bytes_alias) blk: {
            const storage = out.allocatedSlice()[marker.len + 3 ..][0..f.serialized.len];
            @memcpy(storage, &f.serialized);
            break :blk storage;
        } else &f.serialized;
        parsed = try B.parseSerializedSharedDictionary(bytes);
        if (view_alias) {
            const start = std.mem.alignForward(usize, @intFromPtr(pointer) + marker.len + f.serialized.len + 16, @alignOf(B.SerializedSharedDictionary));
            const view: *B.SerializedSharedDictionary = @ptrFromInt(start);
            view.* = parsed;
            dictionary.serialized = view;
        } else dictionary.serialized = &parsed;
    }
    const initial_len = out.items.len;
    const before = try h.a.dupe(u8, out.allocatedSlice());
    defer h.a.free(before);
    var profile: B.DecodeMemoryProfile = .{};
    const options: B.DecodeOptions = .{
        .shared_dictionary = dictionary,
        .max_total_working_memory = limit,
        .memory_profile = if (profiled) &profile else null,
    };
    tracker.begin();
    const result = if (exact)
        B.decodeStreamAppendExactSizeWithOptions(heap, &out, frame, payload.len, options)
    else
        B.decodeStreamAppendLimitedWithOptions(heap, &out, frame, payload.len, options);
    if (denied) {
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, result);
        try std.testing.expectEqual(pointer, out.items.ptr);
        try std.testing.expectEqual(capacity, out.capacity);
        try std.testing.expectEqual(initial_len, out.items.len);
        try std.testing.expectEqualSlices(u8, before, out.allocatedSlice());
    } else {
        try std.testing.expectEqual(payload.len, try result);
        try std.testing.expectEqualSlices(u8, before[0..initial_len], out.items[0..initial_len]);
        try std.testing.expectEqualSlices(u8, payload, out.items[initial_len..]);
        if (spare) try std.testing.expectEqual(pointer, out.items.ptr) else try std.testing.expect(pointer != out.items.ptr);
        if (bytes_alias) {
            const snapshot_bytes = if (raw) f.raw_plain.len else f.serialized.len;
            const publication = if (spare) capacity else capacity + out.capacity;
            try std.testing.expect(tracker.peak >= publication + snapshot_bytes);
        }
    }
    try std.testing.expectEqual(out.capacity, tracker.live);
    try std.testing.expectEqual(@as(usize, 0), tracker.failures);
    if (profiled) try h.profileMatches(profile, &tracker) else try std.testing.expect(!profile.available);
    if (limit) |cap| try std.testing.expect(tracker.peak <= cap);
    return tracker.peak;
}
