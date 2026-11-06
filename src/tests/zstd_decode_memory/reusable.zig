const std = @import("std");
const h = @import("helpers.zig");
const a = h.a;
const Mode = enum { alloc, into, append, scratch };

pub fn contracts(comptime Z: type) !void {
    const frame = try h.compressedAlloc();
    defer a.free(frame);
    const payload = try h.compressedPlainAlloc();
    defer a.free(payload);
    inline for (std.enums.values(Mode)) |mode| {
        inline for (.{ false, true }) |legacy| {
            const peak = try cold(Z, mode, legacy, true, frame, payload, null, false);
            try std.testing.expectEqual(peak, try cold(Z, mode, legacy, true, frame, payload, peak, false));
            _ = try cold(Z, mode, legacy, true, frame, payload, peak - 1, true);
            try std.testing.expectEqual(peak, try cold(Z, mode, legacy, false, frame, payload, peak, false));
            _ = try cold(Z, mode, legacy, false, frame, payload, peak - 1, true);
        }
    }
    try retained(Z, frame, payload);
}

fn call(comptime mode: Mode, comptime legacy: bool, decoder: anytype, out: *std.ArrayList(u8), output: []u8, frame: []const u8, options: anytype) ![]const u8 {
    switch (mode) {
        .alloc => return if (legacy) decoder.decodeAlloc(frame) else decoder.decodeAllocWithOptions(frame, options),
        .into => {
            const count = if (legacy) try decoder.decodeIntoSlice(frame, output) else try decoder.decodeIntoSliceWithOptions(frame, output, options);
            return output[0..count];
        },
        .append => {
            const previous = out.items.len;
            _ = if (legacy) try decoder.decodeAppend(out, frame) else try decoder.decodeAppendWithOptions(out, frame, options);
            return out.items[previous..];
        },
        .scratch => return if (legacy) decoder.decodeScratch(frame) else decoder.decodeScratchWithOptions(frame, options),
    }
}

fn cold(comptime Z: type, comptime mode: Mode, comptime legacy: bool, comptime profiled: bool, frame: []const u8, payload: []const u8, limit: ?usize, denied: bool) !usize {
    errdefer std.debug.print("decode quota reusable cold {s} legacy={} limit={any}\n", .{ @tagName(mode), legacy, limit });
    var tracker = h.Tracker.init(a);
    const heap = tracker.allocator();
    var profile: Z.DecodeMemoryProfile = .{};
    var options: Z.FrameDecodeOptions = .{ .max_total_working_memory = limit, .memory_profile = if (profiled) &profile else null, .expected_output_len = payload.len };
    var decoder = Z.NativeFrameDecoder.initWithOptions(heap, if (legacy) options else .{});
    var live_decoder = true;
    defer if (live_decoder) decoder.deinit();
    try std.testing.expectEqual(@as(usize, 0), tracker.attempts);
    try std.testing.expect(!decoder.memorySnapshot().available);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(heap);
    if (mode == .append) out = .fromOwnedSlice(try heap.dupe(u8, "caller-prefix"));
    const output = try a.alloc(u8, payload.len + 17);
    defer a.free(output);
    @memset(output, 0xa5);
    const pointer = out.items.ptr;
    const capacity = out.capacity;
    tracker.begin();
    if (denied) {
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, call(mode, legacy, &decoder, &out, output[0..payload.len], frame, options));
        try h.untouched(output);
        try std.testing.expectEqual(pointer, out.items.ptr);
        try std.testing.expectEqual(capacity, out.capacity);
        if (mode == .append) try std.testing.expectEqualStrings("caller-prefix", out.items);
        profile.reset();
        tracker.begin();
        options.max_total_working_memory = limit.? + 1;
        decoder.options = if (legacy) options else .{};
    }
    const decoded = try call(mode, legacy, &decoder, &out, output[0..payload.len], frame, options);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try h.untouched(output[payload.len..]);
    const transferred = if (mode == .alloc) decoded.len else if (mode == .append) out.capacity else 0;
    const retained_bytes = tracker.live - transferred;
    if (profiled) try h.profileMatches(profile, &tracker, retained_bytes) else try std.testing.expect(!profile.available);
    const snapshot = decoder.memorySnapshot();
    try std.testing.expect(snapshot.available);
    try std.testing.expectEqual(retained_bytes, snapshot.live_requested_bytes);
    try std.testing.expectEqual(tracker.peak, snapshot.peak_requested_bytes);
    try std.testing.expectEqual(options.max_total_working_memory, snapshot.limit);
    if (mode == .alloc) heap.free(@constCast(decoded));
    const peak = tracker.peak;
    decoder.deinit();
    live_decoder = false;
    try std.testing.expectEqual(out.capacity, tracker.live);
    return peak;
}

fn retained(comptime Z: type, frame: []const u8, payload: []const u8) !void {
    var tracker = h.Tracker.init(a);
    const heap = tracker.allocator();
    var decoder = Z.NativeFrameDecoder.init(heap);
    var live_decoder = true;
    defer if (live_decoder) decoder.deinit();
    const output = try a.alloc(u8, payload.len + 17);
    defer a.free(output);
    @memset(output, 0xa5);
    // Exercise the legacy reusable entropy cache before any quota exists.
    try std.testing.expectEqual(payload.len, try decoder.decodeIntoSlice(frame, output[0..payload.len]));
    const workspace_live = tracker.live;
    try std.testing.expect(workspace_live > 0);
    try std.testing.expect(!decoder.memorySnapshot().available);
    const previous = try decoder.decodeScratch(frame);
    try std.testing.expectEqualSlices(u8, payload, previous);
    const pointer = previous.ptr;
    const capacity = decoder.scratch.capacity;
    const untracked_live = tracker.live;
    try std.testing.expect(untracked_live >= workspace_live + capacity);

    var profile: Z.DecodeMemoryProfile = .{};
    var options: Z.FrameDecodeOptions = .{ .memory_profile = &profile, .max_total_working_memory = untracked_live - 1 };
    tracker.begin();
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, decoder.decodeScratchWithOptions(frame, options));
    try std.testing.expectEqual(pointer, decoder.scratch.items.ptr);
    try std.testing.expectEqual(capacity, decoder.scratch.capacity);
    try std.testing.expectEqualSlices(u8, payload, decoder.scratch.items);
    try std.testing.expectEqual(untracked_live, tracker.live);
    options.max_total_working_memory = null;
    profile.reset();
    tracker.begin();
    try std.testing.expectEqualSlices(u8, payload, try decoder.decodeScratchWithOptions(frame, options));
    try std.testing.expectEqual(pointer, decoder.scratch.items.ptr);
    try h.profileMatches(profile, &tracker, tracker.live);
    try std.testing.expectEqual(tracker.live, decoder.memorySnapshot().live_requested_bytes);
    try std.testing.expect(tracker.live > untracked_live); // Count control allocations too.
    const live = tracker.live;
    const hot_peak = tracker.peak;

    options.max_total_working_memory = live - 1;
    profile.reset();
    tracker.begin();
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, decoder.decodeScratchWithOptions(frame, options));
    try std.testing.expectEqual(pointer, decoder.scratch.items.ptr);
    try std.testing.expectEqual(capacity, decoder.scratch.capacity);
    try std.testing.expectEqualSlices(u8, payload, decoder.scratch.items);
    try std.testing.expectEqual(live, tracker.live);
    options.max_total_working_memory = hot_peak;
    profile.reset();
    tracker.begin();
    try std.testing.expectEqualSlices(u8, payload, try decoder.decodeScratchWithOptions(frame, options));
    try h.profileMatches(profile, &tracker, live);
    try std.testing.expect(tracker.peak <= hot_peak);
    // Budget refusal and checksum refusal both preserve the last publication.
    options.max_total_working_memory = tracker.peak - 1;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, decoder.decodeScratchWithOptions(frame, options));
    try std.testing.expectEqualSlices(u8, payload, decoder.scratch.items);
    const corrupt = try a.dupe(u8, frame);
    defer a.free(corrupt);
    corrupt[corrupt.len - 1] ^= 1;
    options.max_total_working_memory = hot_peak;
    try std.testing.expectError(error.ChecksumMismatch, decoder.decodeScratchWithOptions(corrupt, options));
    try std.testing.expectEqual(pointer, decoder.scratch.items.ptr);
    try std.testing.expectEqual(capacity, decoder.scratch.capacity);
    try std.testing.expectEqualSlices(u8, payload, decoder.scratch.items);
    try std.testing.expectEqualSlices(u8, payload, try decoder.decodeScratchWithOptions(frame, options));
    decoder.deinit();
    live_decoder = false;
    try std.testing.expectEqual(@as(usize, 0), tracker.live);
}
