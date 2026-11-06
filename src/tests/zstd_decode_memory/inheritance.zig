const std = @import("std");
const shared = @import("../../io/requested_heap_budget.zig");
const WorkingAllocator = @import("../../io/working_allocator.zig").WorkingAllocator;
const h = @import("helpers.zig");
const a = h.a;

pub fn contracts(comptime Z: type) !void {
    const magicless = try h.rawAlloc(a, h.plain, true);
    defer a.free(magicless);
    const frame = try h.standardAlloc(a, magicless);
    defer a.free(frame);
    try defaultPath(Z, frame);
    try inheritedShared(Z, frame);
    try inheritedWorking(Z, frame);
    try sizeOnly(Z, frame, magicless);
    try nestedIncremental(Z, frame);
}

fn defaultPath(comptime Z: type, frame: []const u8) !void {
    var tracker = h.Tracker.init(a);
    const heap = tracker.allocator();
    var output: [h.plain.len + 17]u8 = @splat(0xa5);
    try std.testing.expectEqual(h.plain.len, try Z.decodeFrameIntoWithOptions(heap, frame, output[0..h.plain.len], .{}));
    try std.testing.expectEqual(@as(usize, 1), tracker.attempts);
    try std.testing.expectEqual(h.plain.len, tracker.peak);
    try std.testing.expectEqual(@as(usize, 0), tracker.live);
    try h.untouched(output[h.plain.len..]);
    tracker.begin();
    const decoded = try Z.decodeFrameAllocWithOptions(heap, frame, .{});
    try std.testing.expectEqualSlices(u8, h.plain, decoded);
    try std.testing.expectEqual(@as(usize, 1), tracker.attempts);
    try std.testing.expectEqual(h.plain.len, tracker.peak);
    heap.free(decoded);
    var decoder = Z.NativeFrameDecoder.init(heap);
    defer decoder.deinit();
    tracker.begin();
    try std.testing.expectEqual(h.plain.len, try decoder.decodeIntoSlice(frame, output[0..h.plain.len]));
    try std.testing.expectEqual(@as(usize, 0), tracker.attempts);
    try std.testing.expect(!decoder.memorySnapshot().available);
}

fn inheritedShared(comptime Z: type, frame: []const u8) !void {
    var tracker = h.Tracker.init(a);
    const heap = tracker.allocator();
    var profile: Z.DecodeMemoryProfile = .{};
    var lease = try shared.Lease.init(heap, null, &profile, 0);
    var live_lease = true;
    defer if (live_lease) lease.deinit();
    const parent = lease.allocator();
    const control = tracker.live;
    var output: [h.plain.len]u8 = @splat(0xa5);
    tracker.begin();
    try std.testing.expectEqual(h.plain.len, try Z.decodeFrameIntoWithOptions(parent, frame, &output, .{}));
    try std.testing.expectEqualSlices(u8, h.plain, &output);
    try std.testing.expectEqual(@as(usize, 1), tracker.attempts);
    try std.testing.expectEqual(control + h.plain.len, tracker.peak);
    try h.profileMatches(profile, &tracker, control);
    try std.testing.expectEqual(control, lease.snapshot().live_requested_bytes);

    var out = std.ArrayList(u8).fromOwnedSlice(try parent.dupe(u8, "caller-prefix"));
    var live_out = true;
    defer if (live_out) out.deinit(parent);
    tracker.begin();
    profile.reset();
    try std.testing.expectEqual(h.plain.len, try Z.decodeFrameAppendWithOptions(parent, &out, frame, .{}));
    try std.testing.expectEqualStrings("caller-prefix", out.items[0..13]);
    try std.testing.expectEqualSlices(u8, h.plain, out.items[13..]);
    try h.profileMatches(profile, &tracker, control + out.capacity);
    try std.testing.expectEqual(tracker.live, lease.snapshot().live_requested_bytes);
    out.deinit(parent);
    live_out = false;

    try lease.setLimit(control + h.plain.len - 1);
    @memset(&output, 0xa5);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, Z.decodeFrameIntoWithOptions(parent, frame, &output, .{}));
    try h.untouched(&output);
    try std.testing.expect(lease.snapshot().last_failure_was_limit);
    try std.testing.expectEqual(control, tracker.live);
    // Size queries must preserve the outer operation's failure interval.
    try std.testing.expectEqual(h.plain.len, try Z.decodedFrameSizeWithOptions(frame, .{}));
    try std.testing.expect(lease.snapshot().last_failure_was_limit);
    try lease.setLimit(control + h.plain.len);
    lease.beginOperation();
    try std.testing.expectEqual(h.plain.len, try Z.decodeFrameIntoWithOptions(parent, frame, &output, .{}));
    try std.testing.expect(!lease.snapshot().last_failure_was_limit);
    // The parent profile remains bound after the nested operation returns.
    const extra = try parent.alloc(u8, 7);
    try std.testing.expectEqual(control + 7, profile.live_requested_bytes);
    parent.free(extra);
    lease.deinit();
    live_lease = false;
    try std.testing.expectEqual(@as(usize, 0), tracker.live);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
}

fn inheritedWorking(comptime Z: type, frame: []const u8) !void {
    var tracker = h.Tracker.init(a);
    var parent = WorkingAllocator.init(tracker.allocator(), h.plain.len - 1);
    var output: [h.plain.len]u8 = @splat(0xa5);
    try std.testing.expectError(error.OutOfMemory, Z.decodeFrameIntoWithOptions(parent.allocator(), frame, &output, .{}));
    try std.testing.expect(parent.last_failure_was_limit);
    try h.untouched(&output);
    try std.testing.expectEqual(@as(usize, 0), tracker.attempts);
    parent.limit = h.plain.len;
    try std.testing.expectEqual(h.plain.len, try Z.decodeFrameIntoWithOptions(parent.allocator(), frame, &output, .{}));
    try std.testing.expectEqual(h.plain.len, parent.peak);
    try std.testing.expectEqual(tracker.peak, parent.peak);
    try std.testing.expectEqual(@as(usize, 0), parent.live);
    try std.testing.expect(!parent.last_failure_was_limit);
    // A later physical refusal remains backing OOM after an earlier quota
    // refusal; default decode introduces no extra classification interval.
    tracker.fail_at = tracker.attempts;
    @memset(&output, 0xa5);
    try std.testing.expectError(error.OutOfMemory, Z.decodeFrameIntoWithOptions(parent.allocator(), frame, &output, .{}));
    try std.testing.expect(!parent.last_failure_was_limit);
    try h.untouched(&output);
    tracker.fail_at = null;
    try std.testing.expectEqual(h.plain.len, try Z.decodeFrameIntoWithOptions(parent.allocator(), frame, &output, .{}));
}

fn sizeOnly(comptime Z: type, frame: []const u8, magicless: []const u8) !void {
    var denied = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
    var profile: Z.DecodeMemoryProfile = .{};
    for ([_]struct { frame: []const u8, format: Z.FrameFormat }{
        .{ .frame = frame, .format = .standard },
        .{ .frame = magicless, .format = .magicless },
    }) |sample| {
        const options: Z.FrameDecodeOptions = .{ .format = sample.format, .expected_output_len = h.plain.len, .max_total_working_memory = 0, .memory_profile = &profile };
        var decoder = Z.NativeFrameDecoder.initWithOptions(denied.allocator(), options);
        defer decoder.deinit();
        try std.testing.expectEqual(h.plain.len, try Z.decodedFrameSizeWithOptions(sample.frame, options));
        try std.testing.expectEqual(h.plain.len, try decoder.decodedSizeWithOptions(sample.frame, options));
        try std.testing.expectEqual(h.plain.len, try decoder.decodedSize(sample.frame));
        try std.testing.expectEqual(h.plain.len, try decoder.decodedSizeLimited(sample.frame, h.plain.len));
        try std.testing.expect(!decoder.memorySnapshot().available);
        try std.testing.expect(!profile.available);
        try std.testing.expectEqual(@as(usize, 0), denied.alloc_index);
        try std.testing.expect(!denied.has_induced_failure);
    }
}

fn nestedIncremental(comptime Z: type, frame: []const u8) !void {
    var tracker = h.Tracker.init(a);
    var decoder = Z.NativeIncrementalFrameDecoder.initWithOptions(tracker.allocator(), .{ .input_policy = .prevalidated_frame, .expected_output_len = h.plain.len });
    var live_decoder = true;
    defer if (live_decoder) decoder.deinit();
    var output: [h.plain.len]u8 = undefined;
    const step = try decoder.step(frame, &output);
    try std.testing.expectEqual(frame.len, step.progress.input_read);
    try std.testing.expectEqual(h.plain.len, step.progress.output_written);
    try std.testing.expectEqualSlices(u8, h.plain, &output);
    try decoder.finish();
    try std.testing.expectEqual(tracker.peak, decoder.budget.peak);
    try std.testing.expectEqual(tracker.live, decoder.budget.live);
    decoder.deinit();
    live_decoder = false;
    try std.testing.expectEqual(@as(usize, 0), tracker.live);
}
