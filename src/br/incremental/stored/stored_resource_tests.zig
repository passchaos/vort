const std = @import("std");
const br = @import("../../../br.zig");
const core = @import("../../../core.zig");
const total = @import("../../encoder/total_budget.zig");
const h = @import("../../../tests/br_total_memory_helpers.zig");
const Encoder = br.IncrementalStoredStreamEncoder;
const a = std.testing.allocator;
const payload = "stored-resource-abcdefghXabcdefghYabcdefgh-tail";

fn tracked(ledger: *h.TrackingAllocator, profile: ?*br.EncodeMemoryProfile, cap: ?usize) Encoder {
    return Encoder.initWithOptions(ledger.allocator(), .{ .block_len = 64, .stream = .{ .memory_profile = profile, .max_total_working_memory = cap } });
}

fn exactAccounting(encoder: *const Encoder, ledger: *const h.TrackingAllocator) !void {
    const snapshot = encoder.memorySnapshot();
    const control: usize = if (snapshot.available) total.control_bytes else 0;
    try std.testing.expectEqual(control + encoder.plain.capacity + encoder.pending.capacity, ledger.live);
    try std.testing.expectEqual(ledger.live - if (encoder.memory_binding.shared) control else 0, encoder.retainedCapacity());
    if (snapshot.available) try std.testing.expectEqual(ledger.live, snapshot.live_requested_bytes);
}

fn drain(encoder: *Encoder, wire: *std.ArrayList(u8), status: core.StepResult.Status) !void {
    var output: [3]u8 = undefined;
    for (0..4096) |_| {
        @memset(&output, 0xa5);
        const before = encoder.snapshot();
        const step = try encoder.step("", &output);
        const after = encoder.snapshot();
        try std.testing.expectEqual(@as(core.StreamCount, step.progress.input_read), after.input_read - before.input_read);
        try std.testing.expectEqual(@as(core.StreamCount, step.progress.output_written), after.output_written - before.output_written);
        try h.untouched(output[step.progress.output_written..]);
        try wire.appendSlice(a, output[0..step.progress.output_written]);
        if (step.status == status) return;
        try std.testing.expectEqual(.need_output, step.status);
    }
    return error.TestUnexpectedResult;
}

fn restrictPending(encoder: *Encoder) !void {
    const owner = encoder.memory_binding.current(encoder.allocator);
    const exact = try owner.dupe(u8, encoder.pending.items);
    encoder.pending.deinit(owner);
    encoder.pending = std.ArrayList(u8).fromOwnedSlice(exact);
}

fn decode(wire: []const u8, expected: []const u8) !void {
    const plain = try br.decodeStreamAllocExactSize(a, wire, expected.len);
    defer a.free(plain);
    try std.testing.expectEqualSlices(u8, expected, plain);
}

test "Brotli stored resources default profile and exact quota charge real retained buffers" {
    var measured = h.TrackingAllocator.init(a);
    measured.force_moving_growth = true;
    var profile: br.EncodeMemoryProfile = .{};
    var encoder = tracked(&measured, &profile, null);
    const expected = try h.drive(a, &encoder, payload, 5, 3);
    defer a.free(expected);
    try decode(expected, payload);
    try exactAccounting(&encoder, &measured);
    try std.testing.expectEqual(measured.peak, profile.peak_requested_bytes);
    const peak = profile.peak_requested_bytes;
    encoder.deinit();
    try std.testing.expectEqual(@as(usize, 0), measured.live);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);

    for ([_]u8{ 0, 1, 2 }) |mode| {
        var ledger = h.TrackingAllocator.init(a);
        ledger.force_moving_growth = true;
        var memory: br.EncodeMemoryProfile = .{};
        var stream = tracked(&ledger, if (mode == 0) null else &memory, if (mode == 2) peak else null);
        const wire = try h.drive(a, &stream, payload, 5, 3);
        defer a.free(wire);
        try std.testing.expectEqualSlices(u8, expected, wire);
        try exactAccounting(&stream, &ledger);
        try std.testing.expectEqual(mode != 0, stream.memorySnapshot().available);
        if (mode != 0) try std.testing.expectEqual(peak, memory.peak_requested_bytes);
        stream.deinit();
        try std.testing.expectEqual(@as(usize, 0), ledger.live);
        if (mode != 0) try std.testing.expectEqual(@as(usize, 0), memory.live_requested_bytes);
    }
    var below = h.TrackingAllocator.init(a);
    below.force_moving_growth = true;
    var below_profile: br.EncodeMemoryProfile = .{};
    var limited = tracked(&below, &below_profile, peak - 1);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, h.drive(a, &limited, payload, 5, 3));
    try exactAccounting(&limited, &below);
    try std.testing.expect(below_profile.peak_requested_bytes <= peak - 1);
    limited.deinit();
    try std.testing.expectEqual(@as(usize, 0), below.live);
    try std.testing.expectEqual(@as(usize, 0), below_profile.live_requested_bytes);
}

test "Brotli stored resources validate before control admission and preserve backing OOM" {
    var ledger = h.TrackingAllocator.init(a);
    var profile: br.EncodeMemoryProfile = .{};
    var zero = tracked(&ledger, &profile, 0);
    defer zero.deinit();
    var output: [8]u8 = @splat(0xa5);
    const before = zero.snapshot();
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, zero.step("x", &output));
    try std.testing.expectEqual(before, zero.snapshot());
    try h.untouched(&output);
    try std.testing.expectEqual(@as(usize, 0), ledger.alloc_attempts);
    try std.testing.expect(!zero.memorySnapshot().available);
    zero.options.stream.window_bits = 9;
    try std.testing.expectError(error.InvalidBlockPlan, zero.step("x", &output));
    try std.testing.expectEqual(@as(usize, 0), ledger.alloc_attempts);
    try h.untouched(&output);

    var failures = h.TrackingAllocator.init(a);
    failures.fail_alloc_after = 0;
    var oom = tracked(&failures, null, null);
    defer oom.deinit();
    try std.testing.expectError(error.OutOfMemory, oom.step("x", &output));
    try std.testing.expect(!oom.memorySnapshot().available);
    try std.testing.expectEqual(@as(core.StreamCount, 0), oom.snapshot().input_read);
    try h.untouched(&output);
}

test "Brotli stored resources prefix metadata allocation failure restores partial header before retry" {
    const metadata = "prefix metadata" ** 24;
    for ([_]bool{ false, true }) |instrumented| {
        var ledger = h.TrackingAllocator.init(a);
        ledger.force_moving_growth = true;
        var memory: br.EncodeMemoryProfile = .{};
        var encoder = Encoder.initWithOptions(ledger.allocator(), .{ .block_len = 64, .stream = .{ .metadata = metadata, .memory_profile = if (instrumented) &memory else null } });
        defer encoder.deinit();
        // Window/header storage succeeds; later metadata growth is the first
        // backing failure. Control storage adds one call when instrumented.
        ledger.fail_alloc_after = if (instrumented) 2 else 1;
        var output: [8]u8 = @splat(0xa5);
        try std.testing.expectError(error.OutOfMemory, encoder.step("tiny", &output));
        try h.untouched(&output);
        try std.testing.expectEqual(@as(usize, 0), encoder.pending.items.len);
        try std.testing.expectEqual(@as(u3, 0), encoder.codec_state.bit_index);
        try std.testing.expect(!encoder.prefix_written);
        try std.testing.expectEqual(@as(core.StreamCount, 0), encoder.snapshot().input_read);
        try std.testing.expectEqual(@as(core.StreamCount, 0), encoder.snapshot().output_written);
        try exactAccounting(&encoder, &ledger);
        ledger.clearFailures();
        const wire = try h.drive(a, &encoder, "tiny", 2, 3);
        defer a.free(wire);
        const reference = try br.encodeStoredStreamWithOptionsAlloc(a, "tiny", .{ .metadata = metadata });
        defer a.free(reference);
        try std.testing.expectEqualSlices(u8, reference, wire);
        try decode(wire, "tiny");
    }
}

test "Brotli stored resources failed flush preserves mutable tail and accepted input for empty retry" {
    var ledger = h.TrackingAllocator.init(a);
    ledger.force_moving_growth = true;
    var profile: br.EncodeMemoryProfile = .{};
    var encoder = tracked(&ledger, &profile, null);
    defer encoder.deinit();
    _ = try encoder.step("tiny", &.{});
    try restrictPending(&encoder);
    const pending = try a.dupe(u8, encoder.pending.items);
    defer a.free(pending);
    const state = encoder.codec_state;
    encoder.flush();
    encoder.options.stream.max_total_working_memory = ledger.live;
    var output: [16]u8 = @splat(0xa5);
    const before = encoder.snapshot();
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.step("", &output));
    try h.untouched(&output);
    try std.testing.expectEqualSlices(u8, pending, encoder.pending.items);
    try std.testing.expectEqual(state, encoder.codec_state);
    try std.testing.expectEqual(before, encoder.snapshot());
    try std.testing.expectEqualStrings("tiny", encoder.plain.items);
    try exactAccounting(&encoder, &ledger);
    encoder.options.stream.max_total_working_memory = null;
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    try drain(&encoder, &wire, .need_input);
    try encoder.finish();
    try drain(&encoder, &wire, .done);
    try decode(wire.items, "tiny");
    const expected = try br.encodeStoredStreamAlloc(a, "tiny");
    defer a.free(expected);
    try std.testing.expectEqualSlices(u8, expected, wire.items);
}

test "Brotli stored resources metadata failure retains sent prefix and retries with exact durable progress" {
    const metadata = "M" ** 256;
    var ledger = h.TrackingAllocator.init(a);
    ledger.force_moving_growth = true;
    var profile: br.EncodeMemoryProfile = .{};
    var encoder = tracked(&ledger, &profile, null);
    defer encoder.deinit();
    _ = try encoder.step("tiny", &.{});
    encoder.flush();
    _ = try encoder.step("", &.{});
    try encoder.writeMetadata(metadata);
    try restrictPending(&encoder);
    encoder.options.stream.max_total_working_memory = ledger.live;
    var output: [32]u8 = @splat(0xa5);
    const before = encoder.snapshot();
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.step("", &output));
    const sent = try core.stream_count.toLocal(encoder.snapshot().output_written - before.output_written);
    try std.testing.expect(sent != 0);
    try h.untouched(output[sent..]);
    try std.testing.expectEqual(before.input_read, encoder.snapshot().input_read);
    try std.testing.expect(encoder.metadata_requested and encoder.flush_requested);
    try std.testing.expectEqual(@as(usize, 0), encoder.pending.items.len);
    try std.testing.expectEqual(@as(u3, 0), encoder.codec_state.bit_index);
    encoder.options.stream.max_total_working_memory = null;
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    try wire.appendSlice(a, output[0..sent]);
    try drain(&encoder, &wire, .need_input);
    try encoder.finish();
    try drain(&encoder, &wire, .done);
    try decode(wire.items, "tiny");
    try exactAccounting(&encoder, &ledger);
}

test "Brotli stored resources final marker quota failure preserves completed content before retry" {
    var ledger = h.TrackingAllocator.init(a);
    var profile: br.EncodeMemoryProfile = .{};
    var encoder = tracked(&ledger, &profile, null);
    defer encoder.deinit();
    _ = try encoder.step("tiny", &.{});
    encoder.flush();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    try drain(&encoder, &wire, .need_input);
    try std.testing.expectEqual(@as(u3, 0), encoder.codec_state.bit_index);
    try std.testing.expectEqual(@as(usize, 0), encoder.pending.items.len);
    // Release the physically drained allocation, leaving a valid empty writer
    // and forcing the final marker to perform its own first byte allocation.
    encoder.pending.deinit(encoder.memory_binding.current(encoder.allocator));
    encoder.pending = .empty;
    encoder.options.stream.max_total_working_memory = ledger.live;
    try encoder.finish();
    const before = encoder.snapshot();
    var output: [3]u8 = @splat(0xa5);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.step("", &output));
    try std.testing.expectEqual(before, encoder.snapshot());
    try std.testing.expect(!encoder.final_written and !encoder.done);
    try h.untouched(&output);
    try exactAccounting(&encoder, &ledger);
    encoder.options.stream.max_total_working_memory = null;
    try drain(&encoder, &wire, .done);
    try decode(wire.items, "tiny");
    const expected = try br.encodeStoredStreamAlloc(a, "tiny");
    defer a.free(expected);
    try std.testing.expectEqualSlices(u8, expected, wire.items);
}

test "Brotli stored resources reset and next stream retain quota and switch profile only after validation" {
    var ledger = h.TrackingAllocator.init(a);
    var first_profile: br.EncodeMemoryProfile = .{};
    var second_profile: br.EncodeMemoryProfile = .{};
    var encoder = tracked(&ledger, &first_profile, null);
    defer encoder.deinit();
    const first = try h.drive(a, &encoder, payload, 7, 3);
    defer a.free(first);
    const retained = ledger.live;
    const before = encoder.snapshot();
    const lease = encoder.memory_binding.lease.?.state;
    var next = encoder.options;
    next.stream.max_total_working_memory = retained - 1;
    next.stream.memory_profile = &second_profile;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.nextStream(next));
    try std.testing.expectEqual(before, encoder.snapshot());
    try std.testing.expect(encoder.options.stream.memory_profile == &first_profile);
    try std.testing.expectEqual(@as(?usize, null), encoder.memorySnapshot().limit);
    next.stream.window_bits = 9;
    try std.testing.expectError(error.InvalidBlockPlan, encoder.nextStream(next));
    try std.testing.expect(encoder.options.stream.memory_profile == &first_profile);
    next.stream.window_bits = br.default_window_bits;
    next.stream.max_total_working_memory = retained + 128;
    try encoder.nextStream(next);
    try std.testing.expect(encoder.memory_binding.lease.?.state == lease);
    try std.testing.expect(encoder.options.stream.memory_profile == &second_profile);
    const detached_first_live = first_profile.live_requested_bytes;
    const second = try h.drive(a, &encoder, payload, 7, 3);
    defer a.free(second);
    try std.testing.expectEqualSlices(u8, first, second);
    try std.testing.expectEqual(detached_first_live, first_profile.live_requested_bytes);
    try std.testing.expectEqual(ledger.live, second_profile.live_requested_bytes);
    encoder.reset();
    try std.testing.expect(encoder.memory_binding.lease.?.state == lease);
    try std.testing.expectEqual(next.stream.max_total_working_memory, encoder.memorySnapshot().limit);
    try std.testing.expectEqual(retained, ledger.live);
    try std.testing.expectEqual(@as(core.StreamCount, 0), encoder.snapshot().input_read);
    try std.testing.expectEqual(@as(core.StreamCount, 0), encoder.snapshot().stream_count);
}

test "Brotli stored resources moving shared encoder preserves one lease and original ownership" {
    var ledger = h.TrackingAllocator.init(a);
    var profile: br.EncodeMemoryProfile = .{};
    var lease = try total.Lease.init(ledger.allocator(), total.control_bytes + 2048, &profile, 0);
    var encoder = try Encoder.initWithSharedLease(lease.allocator(), .{ .block_len = 64 }, lease);
    const first = try encoder.step("tiny", &.{});
    try std.testing.expectEqual(@as(usize, 4), first.progress.input_read);
    const control = encoder.memory_binding.lease.?.state;
    var moved = encoder;
    encoder = undefined;
    lease.deinit();
    try moved.finish();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    try drain(&moved, &wire, .done);
    try decode(wire.items, "tiny");
    try std.testing.expect(moved.memory_binding.lease.?.state == control);
    try exactAccounting(&moved, &ledger);
    moved.deinit();
    try std.testing.expectEqual(@as(usize, 0), ledger.live);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    try std.testing.expectEqual(ledger.allocated_bytes, ledger.freed_bytes);
}

test "Brotli stored resources first budget activation seeds existing IO capacities exactly once" {
    var ledger = h.TrackingAllocator.init(a);
    var encoder = tracked(&ledger, null, null);
    defer encoder.deinit();
    const expected = try h.drive(a, &encoder, payload, 5, 3);
    defer a.free(expected);
    const retained = ledger.live;
    try std.testing.expect(!encoder.memorySnapshot().available);
    const original = encoder.snapshot();
    const allocation_count = ledger.alloc_attempts;
    var profile: br.EncodeMemoryProfile = .{};
    var next = encoder.options;
    next.stream.memory_profile = &profile;
    next.stream.max_total_working_memory = total.control_bytes + retained - 1;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.nextStream(next));
    try std.testing.expectEqual(original, encoder.snapshot());
    try std.testing.expect(!encoder.memorySnapshot().available);
    try std.testing.expectEqual(allocation_count, ledger.alloc_attempts);
    try std.testing.expectEqual(retained, ledger.live);
    next.stream.max_total_working_memory = total.control_bytes + retained;
    try encoder.nextStream(next);
    try std.testing.expectEqual(total.control_bytes + retained, ledger.live);
    const stable = encoder.memory_binding.lease.?.state;
    const second = try h.drive(a, &encoder, payload, 5, 3);
    defer a.free(second);
    try std.testing.expectEqualSlices(u8, expected, second);
    try exactAccounting(&encoder, &ledger);
    try std.testing.expectEqual(total.control_bytes + retained, ledger.live);
    encoder.reset();
    try std.testing.expect(encoder.memory_binding.lease.?.state == stable);
    try std.testing.expectEqual(total.control_bytes + retained, ledger.live);
}

test "Brotli stored resources shared child keeps outer refusal classification through real output" {
    var ledger = h.TrackingAllocator.init(a);
    var profile: br.EncodeMemoryProfile = .{};
    var outer = try total.Lease.init(ledger.allocator(), total.control_bytes + 1024, &profile, 0);
    defer outer.deinit();
    var encoder = try Encoder.initWithSharedLease(outer.allocator(), .{ .block_len = 64 }, outer);
    defer encoder.deinit();
    try std.testing.expectError(error.OutOfMemory, outer.allocator().alloc(u8, 2048));
    try std.testing.expect(outer.snapshot().last_failure_was_limit);
    const encoded = try h.drive(a, &encoder, "tiny", 2, 3);
    defer a.free(encoded);
    try decode(encoded, "tiny");
    try std.testing.expect(encoder.memorySnapshot().last_failure_was_limit);
    try std.testing.expect(outer.snapshot().last_failure_was_limit);
    try exactAccounting(&encoder, &ledger);
    const before = encoder.snapshot();
    var conflicting = encoder.options;
    conflicting.stream.max_total_working_memory = total.control_bytes + 1023;
    try std.testing.expectError(error.InvalidBlockPlan, encoder.nextStream(conflicting));
    try std.testing.expectEqual(before, encoder.snapshot());
    try std.testing.expect(outer.snapshot().last_failure_was_limit);
    outer.beginOperation();
    try std.testing.expect(!outer.snapshot().last_failure_was_limit);
}
