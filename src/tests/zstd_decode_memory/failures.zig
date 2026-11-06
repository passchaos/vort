const std = @import("std");
const h = @import("helpers.zig");
const a = h.a;
const Mode = enum { into_alias, append_alias, scratch_cold, scratch_growth };

pub fn contracts(comptime Z: type) !void {
    const compressed = try h.compressedAlloc();
    defer a.free(compressed);
    const payload = try h.compressedPlainAlloc();
    defer a.free(payload);
    const raw_magicless = try h.rawAlloc(a, h.plain, true);
    defer a.free(raw_magicless);
    const raw = try h.standardAlloc(a, raw_magicless);
    defer a.free(raw);
    inline for (std.enums.values(Mode)) |mode| {
        const attempts = try attempt(Z, mode, compressed, payload, null);
        try std.testing.expect(attempts > 0);
        for (0..attempts) |index| _ = try attempt(Z, mode, compressed, payload, index);
        // Raw blocks exercise staging, caller alias copies and final scratch
        // publication without requiring compressed sequence allocations.
        const raw_attempts = try attempt(Z, mode, raw, h.plain, null);
        for (0..raw_attempts) |index| _ = try attempt(Z, mode, raw, h.plain, index);
    }
}

fn attempt(comptime Z: type, comptime mode: Mode, frame: []const u8, payload: []const u8, fail_at: ?usize) !usize {
    errdefer std.debug.print("decode quota OOM {s} at={any}\n", .{ @tagName(mode), fail_at });
    var tracker = h.Tracker.init(a);
    const heap = tracker.allocator();
    var profile: Z.DecodeMemoryProfile = .{};
    const options: Z.FrameDecodeOptions = .{ .memory_profile = &profile, .max_total_working_memory = std.math.maxInt(usize) };
    var decoder = Z.NativeFrameDecoder.init(heap);
    var live_decoder = true;
    defer if (live_decoder) decoder.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(heap);
    if (mode == .append_alias) {
        out = .fromOwnedSlice(try heap.alloc(u8, 13 + frame.len));
        @memcpy(out.items[0..13], "caller-prefix");
        @memcpy(out.items[13..], frame);
    }
    if (mode == .scratch_growth) {
        const little_magicless = try h.rawAlloc(a, "old publication", true);
        defer a.free(little_magicless);
        const little = try h.standardAlloc(a, little_magicless);
        defer a.free(little);
        try std.testing.expectEqualStrings("old publication", try decoder.decodeScratch(little));
    }
    const storage = try a.alloc(u8, @max(payload.len + 17, frame.len + 8));
    defer a.free(storage);
    @memset(storage, 0xa5);
    @memcpy(storage[8..][0..frame.len], frame);
    const saved = try a.dupe(u8, storage);
    defer a.free(saved);
    const old_items = try a.dupe(u8, if (mode == .append_alias) out.items else decoder.scratch.items);
    defer a.free(old_items);
    const old_pointer = if (mode == .append_alias) out.items.ptr else decoder.scratch.items.ptr;
    const old_capacity = if (mode == .append_alias) out.capacity else decoder.scratch.capacity;
    const previous_live = tracker.live;
    tracker.begin();
    profile.reset();
    tracker.fail_at = fail_at;
    const result = run(mode, Z, &decoder, heap, &out, storage, frame, payload.len, options);
    const calls = tracker.attempts;
    if (result) |decoded| {
        try std.testing.expectEqualSlices(u8, payload, decoded);
        if (fail_at != null) try std.testing.expect(tracker.failures > 0);
    } else |err| {
        try std.testing.expect(err == error.OutOfMemory);
        try std.testing.expect(fail_at != null and tracker.failures > 0);
        try std.testing.expectEqualSlices(u8, saved, storage);
        const current = if (mode == .append_alias) out else decoder.scratch;
        try std.testing.expectEqual(old_pointer, current.items.ptr);
        try std.testing.expectEqual(old_capacity, current.capacity);
        try std.testing.expectEqualSlices(u8, old_items, current.items);
        // Any successfully created reusable owner may remain available for
        // retry. The ledger must describe precisely that retained allocation.
        if (mode == .into_alias or mode == .append_alias) {
            try std.testing.expectEqual(previous_live, tracker.live);
            try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
        } else if (decoder.memorySnapshot().available) {
            try std.testing.expectEqual(tracker.live, decoder.memorySnapshot().live_requested_bytes);
        }
        tracker.fail_at = null;
        try std.testing.expectEqualSlices(u8, payload, try run(mode, Z, &decoder, heap, &out, storage, frame, payload.len, options));
    }
    tracker.fail_at = null;
    decoder.deinit();
    live_decoder = false;
    try std.testing.expectEqual(out.capacity, tracker.live);
    return calls;
}

fn run(comptime mode: Mode, comptime Z: type, decoder: anytype, heap: std.mem.Allocator, out: *std.ArrayList(u8), storage: []u8, frame: []const u8, payload_len: usize, options: Z.FrameDecodeOptions) ![]const u8 {
    switch (mode) {
        .into_alias => {
            const written = try Z.decodeFrameIntoWithOptions(heap, storage[8..][0..frame.len], storage[0..payload_len], options);
            return storage[0..written];
        },
        .append_alias => {
            const previous = out.items.len;
            _ = try Z.decodeFrameAppendWithOptions(heap, out, out.items[13..], options);
            return out.items[previous..];
        },
        .scratch_cold, .scratch_growth => return decoder.decodeScratchWithOptions(frame, options),
    }
}
