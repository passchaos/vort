const std = @import("std");
const h = @import("helpers.zig");
const a = h.a;
const Mode = enum { alloc, into, into_alias, append_spare, append_growth, append_alias };

pub fn contracts(comptime Z: type) !void {
    const raw_magicless = try h.rawAlloc(a, h.plain, true);
    defer a.free(raw_magicless);
    const raw = try h.standardAlloc(a, raw_magicless);
    defer a.free(raw);
    const compressed = try h.compressedAlloc();
    defer a.free(compressed);
    const compressed_plain = try h.compressedPlainAlloc();
    defer a.free(compressed_plain);
    const repeated = [_]u8{'r'} ** 4096;
    const rle = try h.rleAlloc(&repeated, false);
    defer a.free(rle);
    const rle_magicless = try h.rleAlloc(&repeated, true);
    defer a.free(rle_magicless);
    for ([_]struct { frame: []const u8, payload: []const u8, options: Z.FrameDecodeOptions }{
        .{ .frame = raw, .payload = h.plain, .options = .{} },
        .{ .frame = raw_magicless, .payload = h.plain, .options = .{ .format = .magicless } },
        .{ .frame = rle, .payload = &repeated, .options = .{} },
        .{ .frame = rle_magicless, .payload = &repeated, .options = .{ .format = .magicless } },
        .{ .frame = compressed, .payload = compressed_plain, .options = .{} },
        .{ .frame = compressed[4..], .payload = compressed_plain, .options = .{ .format = .magicless } },
    }) |sample| {
        inline for (std.enums.values(Mode)) |mode| {
            const peak = try invoke(Z, mode, true, sample.frame, sample.payload, sample.options, null, false);
            try std.testing.expect(peak >= sample.payload.len);
            try std.testing.expectEqual(peak, try invoke(Z, mode, true, sample.frame, sample.payload, sample.options, peak, false));
            _ = try invoke(Z, mode, true, sample.frame, sample.payload, sample.options, peak - 1, true);
            try std.testing.expectEqual(peak, try invoke(Z, mode, false, sample.frame, sample.payload, sample.options, peak, false));
            _ = try invoke(Z, mode, false, sample.frame, sample.payload, sample.options, peak - 1, true);
        }
    }
    try checksumFailure(Z, raw, h.plain);
    try checksumFailure(Z, compressed, compressed_plain);
}

fn invoke(comptime Z: type, comptime mode: Mode, comptime profiled: bool, frame: []const u8, payload: []const u8, base: Z.FrameDecodeOptions, limit: ?usize, denied: bool) !usize {
    errdefer std.debug.print("decode quota publication {s} payload={d} limit={any}\n", .{ @tagName(mode), payload.len, limit });
    var tracker = h.Tracker.init(a);
    const heap = tracker.allocator();
    var profile: Z.DecodeMemoryProfile = .{};
    var options = base;
    options.memory_profile = if (profiled) &profile else null;
    options.max_total_working_memory = limit;
    options.expected_output_len = payload.len;
    options.max_output_len = payload.len;

    if (mode == .alloc) {
        tracker.begin();
        if (denied) {
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, Z.decodeFrameAllocWithOptions(heap, frame, options));
            try std.testing.expectEqual(@as(usize, 0), tracker.live);
            profile.reset();
            tracker.begin();
            options.max_total_working_memory = limit.? + 1;
        }
        const decoded = try Z.decodeFrameAllocWithOptions(heap, frame, options);
        try std.testing.expectEqualSlices(u8, payload, decoded);
        if (profiled) try h.profileMatches(profile, &tracker, 0) else try std.testing.expect(!profile.available);
        const peak = tracker.peak;
        heap.free(decoded);
        try std.testing.expectEqual(@as(usize, 0), tracker.live);
        return peak;
    }
    if (mode == .into or mode == .into_alias) {
        const storage = try a.alloc(u8, @max(payload.len + 17, frame.len + 8));
        defer a.free(storage);
        @memset(storage, 0xa5);
        const input = if (mode == .into_alias) blk: {
            @memcpy(storage[8..][0..frame.len], frame);
            break :blk storage[8..][0..frame.len];
        } else frame;
        const before = try a.dupe(u8, storage);
        defer a.free(before);
        tracker.begin();
        if (denied) {
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, Z.decodeFrameIntoWithOptions(heap, input, storage[0..payload.len], options));
            try std.testing.expectEqualSlices(u8, before, storage);
            try std.testing.expectEqual(@as(usize, 0), tracker.live);
            profile.reset();
            tracker.begin();
            options.max_total_working_memory = limit.? + 1;
        }
        try std.testing.expectEqual(payload.len, try Z.decodeFrameIntoWithOptions(heap, input, storage[0..payload.len], options));
        try std.testing.expectEqualSlices(u8, payload, storage[0..payload.len]);
        try std.testing.expectEqualSlices(u8, before[payload.len..], storage[payload.len..]);
        try std.testing.expectEqual(@as(usize, 0), tracker.live);
        if (profiled) try h.profileMatches(profile, &tracker, 0) else try std.testing.expect(!profile.available);
        return tracker.peak;
    }

    const initial = if (mode == .append_alias) try std.mem.concat(a, u8, &.{ "caller-prefix", frame }) else try a.dupe(u8, "caller-prefix");
    defer a.free(initial);
    const capacity = if (mode == .append_spare) initial.len + payload.len + 4096 else initial.len;
    const allocation = try heap.alloc(u8, capacity);
    var out = std.ArrayList(u8).fromOwnedSlice(allocation);
    out.items.len = initial.len;
    @memcpy(out.items, initial);
    defer out.deinit(heap);
    const pointer = out.items.ptr;
    const input = if (mode == .append_alias) out.items[13..] else frame;
    tracker.begin();
    if (denied) {
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, Z.decodeFrameAppendWithOptions(heap, &out, input, options));
        try std.testing.expectEqual(pointer, out.items.ptr);
        try std.testing.expectEqual(capacity, out.capacity);
        try std.testing.expectEqualSlices(u8, initial, out.items);
        try std.testing.expectEqual(capacity, tracker.live);
        profile.reset();
        tracker.begin();
        options.max_total_working_memory = limit.? + 1;
    }
    try std.testing.expectEqual(payload.len, try Z.decodeFrameAppendWithOptions(heap, &out, input, options));
    try std.testing.expectEqualSlices(u8, initial, out.items[0..initial.len]);
    try std.testing.expectEqualSlices(u8, payload, out.items[initial.len..]);
    if (mode == .append_spare) try std.testing.expectEqual(pointer, out.items.ptr) else try std.testing.expect(pointer != out.items.ptr);
    try std.testing.expectEqual(out.capacity, tracker.live);
    if (profiled) try h.profileMatches(profile, &tracker, 0) else try std.testing.expect(!profile.available);
    return tracker.peak;
}

fn checksumFailure(comptime Z: type, frame: []const u8, payload: []const u8) !void {
    const corrupt = try a.dupe(u8, frame);
    defer a.free(corrupt);
    corrupt[corrupt.len - 1] ^= 1;
    const saved = try a.dupe(u8, corrupt);
    defer a.free(saved);
    var tracker = h.Tracker.init(a);
    const heap = tracker.allocator();
    var profile: Z.DecodeMemoryProfile = .{};
    const options: Z.FrameDecodeOptions = .{ .memory_profile = &profile };
    const output = try a.alloc(u8, payload.len + 17);
    defer a.free(output);
    @memset(output, 0xa5);
    try std.testing.expectError(error.ChecksumMismatch, Z.decodeFrameIntoWithOptions(heap, corrupt, output, options));
    try h.untouched(output);
    var out = std.ArrayList(u8).fromOwnedSlice(try heap.dupe(u8, "caller-prefix"));
    defer out.deinit(heap);
    const pointer = out.items.ptr;
    const capacity = out.capacity;
    tracker.begin();
    profile.reset();
    try std.testing.expectError(error.ChecksumMismatch, Z.decodeFrameAppendWithOptions(heap, &out, corrupt, options));
    try std.testing.expectEqual(pointer, out.items.ptr);
    try std.testing.expectEqual(capacity, out.capacity);
    try std.testing.expectEqualStrings("caller-prefix", out.items);
    try std.testing.expectEqualSlices(u8, saved, corrupt);
    try std.testing.expectEqual(capacity, tracker.live);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    try std.testing.expectEqual(payload.len, try Z.decodeFrameAppendWithOptions(heap, &out, frame, options));
}
