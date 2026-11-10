const std = @import("std");
const h = @import("helpers.zig");
const budget = @import("../budget.zig");
const ForwardedMode = enum { owned, owned_limited, owned_exact, prefix, prefix_limited, prefix_exact, append, append_limited, append_exact, prefix_append, prefix_append_limited, prefix_append_exact };

pub fn contracts(comptime B: type, sample: h.Sample(B)) !void {
    var tracker = h.CountingAllocator.init(h.a);
    var profile: B.DecodeMemoryProfile = .{};
    const heap = tracker.allocator();
    var lease = try budget.Lease.init(heap, std.math.maxInt(usize), &profile, 0);
    defer lease.deinit();
    const parent = lease.allocator();
    const control = tracker.live;
    try std.testing.expect(control != 0);
    const options: B.DecodeOptions = .{ .max_total_working_memory = std.math.maxInt(usize), .memory_profile = &profile };
    const inner = budget.forward(options);
    try std.testing.expectEqual(@as(?usize, null), inner.max_total_working_memory);
    try std.testing.expect(inner.memory_profile == null);
    const decoded = try B.decodeStreamAllocWithOptions(parent, sample.wire, options);
    try std.testing.expectEqualSlices(u8, sample.plain, decoded);
    try std.testing.expectEqual(control + decoded.len, tracker.live);
    try std.testing.expectEqual(tracker.live, lease.snapshot().live_requested_bytes);
    try std.testing.expectEqual(tracker.live, profile.live_requested_bytes);
    // Child ownership remains with the inherited parent allocator on return.
    parent.free(decoded);
    try std.testing.expectEqual(control, profile.live_requested_bytes);
    const forwarded = try B.decodeStreamAllocWithOptions(parent, sample.wire, inner);
    try std.testing.expectEqualSlices(u8, sample.plain, forwarded);
    try std.testing.expectEqual(control + forwarded.len, tracker.live);
    try std.testing.expectEqual(tracker.live, profile.live_requested_bytes);
    parent.free(forwarded);
    const empty = try B.encodeStoredStreamAlloc(h.a, "");
    defer h.a.free(empty);
    const attempts = tracker.attempts;
    const zero = try B.decodeStreamAllocWithOptions(parent, empty, options);
    parent.free(zero);
    const exact_zero = try B.decodeStreamAllocExactSizeWithOptions(parent, empty, 0, options);
    parent.free(exact_zero);
    _ = try B.summarizeStreamAllocWithOptions(parent, sample.wire, options);
    try std.testing.expectEqual(control, profile.live_requested_bytes);
    try std.testing.expectEqual(attempts, tracker.attempts);

    var other: B.DecodeMemoryProfile = .{};
    var bad = options;
    bad.memory_profile = &other;
    try std.testing.expectError(error.InvalidBlockPlan, B.decodeStreamAllocWithOptions(parent, sample.wire, bad));
    try std.testing.expectError(error.InvalidBlockPlan, B.decodeStreamAllocWithOptions(parent, empty, bad));
    try std.testing.expectError(error.InvalidBlockPlan, B.decodeStreamAllocExactSizeWithOptions(parent, empty, 0, bad));
    try std.testing.expectError(error.InvalidBlockPlan, B.summarizeStreamAllocWithOptions(parent, sample.wire, bad));
    try std.testing.expect(!other.available);
    bad = options;
    bad.max_total_working_memory = std.math.maxInt(usize) - 1;
    try std.testing.expectError(error.InvalidBlockPlan, B.decodeStreamAllocWithOptions(parent, sample.wire, bad));
    try std.testing.expectError(error.InvalidBlockPlan, B.decodeStreamAllocWithOptions(parent, empty, bad));
    try std.testing.expectError(error.InvalidBlockPlan, B.summarizeStreamAllocWithOptions(parent, sample.wire, bad));
    try std.testing.expectEqual(control, tracker.live);
    try std.testing.expectEqual(control, profile.live_requested_bytes);

    // Children preserve the owning operation's refusal interval. The parent
    // explicitly begins the next operation before testing backing OOM.
    const inherited: B.DecodeOptions = .{ .memory_profile = &profile };
    try lease.setLimit(control + sample.plain.len - 1);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, B.decodeStreamAllocExactSizeWithOptions(parent, sample.wire, sample.plain.len, inherited));
    try std.testing.expect(lease.snapshot().last_failure_was_limit);
    try std.testing.expectEqual(control, tracker.live);
    _ = try B.decodedStreamSize(sample.wire);
    const empty_child = try B.decodeStreamAllocWithOptions(parent, empty, inherited);
    parent.free(empty_child);
    const empty_exact_child = try B.decodeStreamAllocExactSizeWithOptions(parent, empty, 0, inherited);
    parent.free(empty_exact_child);
    _ = try B.summarizeStreamAllocWithOptions(parent, sample.wire, inherited);
    try std.testing.expect(lease.snapshot().last_failure_was_limit);
    try lease.setLimit(control + sample.plain.len);
    lease.beginOperation();
    try std.testing.expect(!lease.snapshot().last_failure_was_limit);
    tracker.fail_at = tracker.attempts;
    try std.testing.expectError(error.OutOfMemory, B.decodeStreamAllocExactSizeWithOptions(parent, sample.wire, sample.plain.len, inherited));
    try std.testing.expect(!lease.snapshot().last_failure_was_limit);
    try std.testing.expectEqual(control, tracker.live);
    tracker.fail_at = null;
    lease.beginOperation();
    const recovered = try B.decodeStreamAllocExactSizeWithOptions(parent, sample.wire, sample.plain.len, inherited);
    try std.testing.expectEqualSlices(u8, sample.plain, recovered);
    try std.testing.expectEqual(control + recovered.len, tracker.live);
    parent.free(recovered);
    try lease.setLimit(std.math.maxInt(usize));

    var out = std.ArrayList(u8).fromOwnedSlice(try parent.dupe(u8, "prefix"));
    defer out.deinit(parent);
    _ = try B.decodeStreamPrefixAppendWithOptions(parent, &out, sample.wire, options);
    try std.testing.expectEqualStrings("prefix", out.items[0..6]);
    try std.testing.expectEqualSlices(u8, sample.plain, out.items[6..]);
    try std.testing.expectEqual(control + out.capacity, tracker.live);
    try std.testing.expectEqual(tracker.live, profile.live_requested_bytes);
    try std.testing.expectEqual(tracker.peak, profile.peak_requested_bytes);
    try forwardedNull(B, sample, empty);
}

/// Concrete public entry points must inherit policy even when forwarding has
/// removed both policy fields. Cover convenience dispatch and bounded/exact
/// dispatch separately, with the caller owning each classification interval.
fn forwardedNull(comptime B: type, sample: h.Sample(B), empty: []const u8) !void {
    const joined = try std.mem.concat(h.a, u8, &.{ sample.wire, "\xfftail" });
    defer h.a.free(joined);
    inline for (std.enums.values(ForwardedMode)) |mode| {
        inline for (.{ false, true }) |forwarded| {
            errdefer std.debug.print("Brotli inherited null-options {s}, forwarded={any}\n", .{ @tagName(mode), forwarded });
            var tracker = h.CountingAllocator.init(h.a);
            defer std.debug.assert(tracker.live == 0);
            var profile: B.DecodeMemoryProfile = .{};
            var lease = try budget.Lease.init(tracker.allocator(), null, &profile, 0);
            defer lease.deinit();
            const parent = lease.allocator();
            const control = tracker.live;
            var out = std.ArrayList(u8).fromOwnedSlice(try parent.dupe(u8, "prefix"));
            defer out.deinit(parent);
            const original_pointer = out.items.ptr;
            const original_capacity = out.capacity;
            const occupied = tracker.live;
            const outer: B.DecodeOptions = .{ .memory_profile = &profile };
            const options: B.DecodeOptions = if (forwarded) budget.forward(outer) else .{};
            try std.testing.expect(options.max_total_working_memory == null and options.memory_profile == null);
            try lease.setLimit(occupied);
            lease.beginOperation();
            const attempts = tracker.attempts;
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, forwardedCall(B, mode, parent, &out, sample, joined, options));
            try std.testing.expectEqual(attempts, tracker.attempts);
            try std.testing.expect(lease.snapshot().last_failure_was_limit);
            try std.testing.expectEqual(occupied, tracker.live);
            try std.testing.expectEqual(original_pointer, out.items.ptr);
            try std.testing.expectEqual(original_capacity, out.capacity);
            try std.testing.expectEqualStrings("prefix", out.items);
            const before = profile;
            const zero = try B.decodeStreamAllocWithOptions(parent, empty, options);
            parent.free(zero);
            const exact_zero = try B.decodeStreamAllocExactSizeWithOptions(parent, empty, 0, options);
            parent.free(exact_zero);
            const prefix_zero = try B.decodeStreamPrefixAllocExactSizeWithOptions(parent, empty, 0, options);
            prefix_zero.deinit(parent);
            _ = try B.summarizeStreamAllocWithOptions(parent, sample.wire, options);
            try std.testing.expectEqual(before, profile);
            try std.testing.expect(lease.snapshot().last_failure_was_limit);
            try std.testing.expectEqual(attempts, tracker.attempts);

            try lease.setLimit(std.math.maxInt(usize));
            lease.beginOperation();
            tracker.fail_at = tracker.attempts;
            try std.testing.expectError(error.OutOfMemory, forwardedCall(B, mode, parent, &out, sample, joined, options));
            // A second physical refusal in the same owner interval is OOM too.
            try std.testing.expectError(error.OutOfMemory, forwardedCall(B, mode, parent, &out, sample, joined, options));
            try std.testing.expect(!lease.snapshot().last_failure_was_limit);
            lease.beginOperation();
            try std.testing.expectError(error.OutOfMemory, forwardedCall(B, mode, parent, &out, sample, joined, options));
            try std.testing.expect(!lease.snapshot().last_failure_was_limit);
            try std.testing.expectEqual(occupied, tracker.live);
            try std.testing.expectEqual(occupied, profile.live_requested_bytes);
            try std.testing.expectEqual(original_pointer, out.items.ptr);
            try std.testing.expectEqual(original_capacity, out.capacity);
            try std.testing.expectEqualStrings("prefix", out.items);
            tracker.fail_at = null;
            lease.beginOperation();
            try forwardedCall(B, mode, parent, &out, sample, joined, options);
            try std.testing.expectEqual(control + out.capacity, tracker.live);
            try std.testing.expectEqual(tracker.live, profile.live_requested_bytes);
            try std.testing.expectEqual(tracker.peak, profile.peak_requested_bytes);
        }
    }
}

fn forwardedCall(comptime B: type, comptime mode: ForwardedMode, parent: std.mem.Allocator, out: *std.ArrayList(u8), sample: h.Sample(B), joined: []const u8, options: B.DecodeOptions) !void {
    if (comptime mode == .owned or mode == .owned_limited or mode == .owned_exact) {
        const result = try switch (mode) {
            .owned => B.decodeStreamAllocWithOptions(parent, sample.wire, options),
            .owned_limited => B.decodeStreamAllocLimitedWithOptions(parent, sample.wire, sample.plain.len, options),
            .owned_exact => B.decodeStreamAllocExactSizeWithOptions(parent, sample.wire, sample.plain.len, options),
            else => unreachable,
        };
        defer parent.free(result);
        try std.testing.expectEqualSlices(u8, sample.plain, result);
    } else if (comptime mode == .prefix or mode == .prefix_limited or mode == .prefix_exact) {
        const result = try switch (mode) {
            .prefix => B.decodeStreamPrefixAllocWithOptions(parent, joined, options),
            .prefix_limited => B.decodeStreamPrefixAllocLimitedWithOptions(parent, joined, sample.plain.len, options),
            .prefix_exact => B.decodeStreamPrefixAllocExactSizeWithOptions(parent, joined, sample.plain.len, options),
            else => unreachable,
        };
        defer result.deinit(parent);
        try std.testing.expectEqual(sample.wire.len, result.input_read);
        try std.testing.expectEqualSlices(u8, sample.plain, result.bytes);
    } else {
        if (comptime mode == .append or mode == .append_limited or mode == .append_exact) {
            const written = try switch (mode) {
                .append => B.decodeStreamAppendWithOptions(parent, out, sample.wire, options),
                .append_limited => B.decodeStreamAppendLimitedWithOptions(parent, out, sample.wire, sample.plain.len, options),
                .append_exact => B.decodeStreamAppendExactSizeWithOptions(parent, out, sample.wire, sample.plain.len, options),
                else => unreachable,
            };
            try std.testing.expectEqual(sample.plain.len, written);
        } else {
            const result = try switch (mode) {
                .prefix_append => B.decodeStreamPrefixAppendWithOptions(parent, out, joined, options),
                .prefix_append_limited => B.decodeStreamPrefixAppendLimitedWithOptions(parent, out, joined, sample.plain.len, options),
                .prefix_append_exact => B.decodeStreamPrefixAppendExactSizeWithOptions(parent, out, joined, sample.plain.len, options),
                else => unreachable,
            };
            try std.testing.expectEqual(sample.wire.len, result.input_read);
            try std.testing.expectEqual(sample.plain.len, result.output_written);
        }
        try std.testing.expectEqualStrings("prefix", out.items[0..6]);
        try std.testing.expectEqualSlices(u8, sample.plain, out.items[6..]);
    }
}
