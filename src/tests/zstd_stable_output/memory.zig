const std = @import("std");
const h = @import("helpers.zig");
const f = @import("fixtures.zig");

pub fn contracts(comptime Z: type) !void {
    const plain = try h.a.alloc(u8, 17 * 8192);
    defer h.a.free(plain);
    @memset(plain, 'R');
    inline for (.{ false, true }) |known| {
        const frame = try f.rleBlocks(plain, known, false, 8192);
        defer h.a.free(frame);
        inline for (.{ .block_stream, .prevalidated_frame }) |policy| {
            const stable_peak = try measured(Z, frame, plain, policy, true, null, false);
            const owned_peak = try measured(Z, frame, plain, policy, false, null, false);
            try std.testing.expect(owned_peak >= stable_peak + 64 * 1024);
            try std.testing.expectEqual(stable_peak, try measured(Z, frame, plain, policy, true, stable_peak, false));
            _ = try measured(Z, frame, plain, policy, false, stable_peak, true);
        }
    }
}

fn measured(comptime Z: type, frame: []const u8, plain: []const u8, policy: anytype, stable: bool, quota: ?usize, denied: bool) !usize {
    errdefer std.debug.print("stable output memory policy={s} stable={} quota={any} denied={}\n", .{ @tagName(policy), stable, quota, denied });
    var tracker = h.memory.Tracker.init(h.a);
    var decoder = Z.NativeIncrementalFrameDecoder.initWithOptions(tracker.allocator(), .{ .input_policy = policy, .max_working_memory = quota orelse std.math.maxInt(usize), .max_output_len = plain.len });
    var live = true;
    defer if (live) decoder.deinit();
    if (stable) {
        const buffer = try h.a.alloc(u8, plain.len + 17);
        defer h.a.free(buffer);
        @memset(buffer, 0xa5);
        const before = tracker.attempts;
        try decoder.bindStableOutput(buffer);
        try std.testing.expectEqual(before, tracker.attempts);
        var count: usize = 0;
        _ = try h.drive(&decoder, frame, buffer, &count, plain, 7);
        try std.testing.expectEqual(plain.len, count);
        try h.memory.untouched(buffer[plain.len..]);
    } else if (denied) {
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, h.ordinary(&decoder, frame, plain, 7));
    } else try h.ordinary(&decoder, frame, plain, 7);
    const peak = tracker.peak;
    try std.testing.expectEqual(peak, decoder.snapshot().peak_working_bytes);
    decoder.deinit();
    live = false;
    try std.testing.expectEqual(@as(usize, 0), tracker.live);
    return peak;
}
