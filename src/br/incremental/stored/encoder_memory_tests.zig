const std = @import("std");
const core = @import("../../../core.zig");
const generic = @import("encoder.zig");
const adapter = @import("allocator_adapter.zig");
const total = @import("../../encoder/total_budget.zig");
const tracking = @import("../../../tests/br_total_memory_helpers.zig");
const br = @import("../../../br.zig");

// The wire is deliberately small. These tests exercise Generic ownership and
// progress through the real total Lease and an independent backing-byte ledger.
const Codec = struct {
    pub const Error = total.Error || error{ TrailingData, OutputLimitExceeded };
    pub const StreamOptions = struct {
        max_total_working_memory: ?usize = null,
        memory_profile: ?*total.EncodeMemoryProfile = null,
    };
    pub const State = struct {
        payload: std.ArrayList(u8) = .empty,
        payload_allocator: ?std.mem.Allocator = null,
        bit_index: u3 = 0,
        blocks: usize = 0,
        resets: usize = 0,
    };
    pub const max_block_len = 4;
    pub const default_block_len = 4;
    pub const defer_full_block_until_more_input = true;

    pub fn extractMemoryConfig(options: StreamOptions) adapter.Config {
        return .{ .limit = options.max_total_working_memory, .profile = options.memory_profile };
    }
    pub fn requiredTotalRetainedBytes(state: *const State) Error!usize {
        return state.payload.capacity;
    }
    pub fn stateRetainedCapacity(state: *const State) usize {
        return state.payload.capacity;
    }
    pub fn rebindStateAllocator(state: *State, a: std.mem.Allocator) void {
        state.payload_allocator = a;
    }
    pub fn deinitState(state: *State, a: std.mem.Allocator) void {
        state.payload.deinit(state.payload_allocator orelse a);
    }
    pub fn resetState(state: *State) void {
        state.payload.clearRetainingCapacity();
        state.bit_index = 0;
        state.blocks = 0;
        state.resets += 1;
    }
    pub fn readyOutputLen(state: *const State, pending_len: usize, final: bool) usize {
        return pending_len - @intFromBool(!final and state.bit_index != 0);
    }
    pub fn writePrefix(a: std.mem.Allocator, out: *std.ArrayList(u8), state: *State, _: StreamOptions) Error!void {
        try out.append(a, 0x01);
        state.bit_index = 1;
    }
    pub fn writeBlock(a: std.mem.Allocator, out: *std.ArrayList(u8), state: *State, input: []const u8) Error!void {
        try writeData(a, out, state, input, false);
    }
    pub fn writeFinalBlock(a: std.mem.Allocator, out: *std.ArrayList(u8), state: *State, input: []const u8) Error!void {
        try writeData(a, out, state, input, true);
    }
    fn writeData(a: std.mem.Allocator, out: *std.ArrayList(u8), state: *State, input: []const u8, final: bool) Error!void {
        try state.payload.ensureUnusedCapacity(state.payload_allocator orelse a, input.len);
        state.payload_allocator = state.payload_allocator orelse a;
        try out.ensureUnusedCapacity(a, input.len + 1);
        out.items[out.items.len - 1] = if (final) 0x61 else 0x21;
        out.appendSliceAssumeCapacity(input);
        out.appendAssumeCapacity(if (final) 0xff else 0x01);
        state.payload.appendSliceAssumeCapacity(input);
        state.blocks += 1;
        if (final) state.bit_index = 0;
    }
    pub fn writeMetadata(a: std.mem.Allocator, out: *std.ArrayList(u8), _: *State, metadata: []const u8) Error!void {
        try out.ensureUnusedCapacity(a, metadata.len + 1);
        out.items[out.items.len - 1] = 0xa1;
        out.appendSliceAssumeCapacity(metadata);
        out.appendAssumeCapacity(0x01);
    }
    pub fn writeFinal(a: std.mem.Allocator, out: *std.ArrayList(u8), state: *State) Error!void {
        try out.ensureUnusedCapacity(a, 1);
        out.items[out.items.len - 1] = 0xe1;
        out.appendAssumeCapacity(0xff);
        state.bit_index = 0;
    }
};
const Encoder = generic.Encoder(Codec);

test "Brotli total memory generic rejects control and IO capacity overflow before allocation" {
    var ledger = tracking.TrackingAllocator.init(std.testing.allocator);
    var profile: total.EncodeMemoryProfile = .{};
    var encoder = Encoder.initWithOptions(ledger.allocator(), .{ .stream = .{ .max_total_working_memory = 0, .memory_profile = &profile } });
    defer encoder.deinit();
    const before = encoder.snapshot();
    var output: [1]u8 = .{0xa5};
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.step("x", &output));
    try std.testing.expectEqual(before, encoder.snapshot());
    try std.testing.expectEqualSlices(u8, &.{0xa5}, &output);
    try std.testing.expectEqual(@as(usize, 0), ledger.alloc_attempts);
    try std.testing.expect(encoder.memory_binding.lease == null);
    try std.testing.expectError(error.IntegerOverflow, encoder.memory_binding.activate(Codec, ledger.allocator(), &encoder.codec_state, .{ .memory_profile = &profile }, std.math.maxInt(usize), 1));
    try std.testing.expectEqual(@as(usize, 0), ledger.alloc_attempts);
}

test "Brotli total memory generic activates only configured tracking and charges all owned buffers" {
    for ([_]u8{ 0, 1, 2 }) |mode| {
        var ledger = tracking.TrackingAllocator.init(std.testing.allocator);
        var profile: total.EncodeMemoryProfile = .{};
        var encoder = Encoder.initWithOptions(ledger.allocator(), .{ .stream = .{
            .max_total_working_memory = if (mode == 2) total.control_bytes + 1024 else null,
            .memory_profile = if (mode == 0) null else &profile,
        } });
        var encoder_alive = true;
        defer if (encoder_alive) encoder.deinit();
        try std.testing.expectEqual(@as(usize, 0), ledger.live);
        _ = try encoder.step("abcd", &.{});
        if (mode == 0) {
            try std.testing.expect(encoder.memory_binding.lease == null);
            try std.testing.expect(!profile.available);
            try std.testing.expectEqual(encoder.plain.capacity + encoder.pending.capacity, ledger.live);
        } else {
            try std.testing.expect(profile.available);
            try std.testing.expectEqual(ledger.live, profile.live_requested_bytes);
            try std.testing.expectEqual(ledger.peak, profile.peak_requested_bytes);
            try std.testing.expectEqual(total.control_bytes + encoder.plain.capacity + encoder.pending.capacity, ledger.live);
        }
        try std.testing.expectEqual(ledger.live, encoder.retainedCapacity());
        try encoder.finish();
        var wire: std.ArrayList(u8) = .empty;
        defer wire.deinit(std.testing.allocator);
        try drain(&encoder, &wire, .done);
        try std.testing.expectEqualSlices(u8, &.{ 0x61, 'a', 'b', 'c', 'd', 0xff }, wire.items);
        if (mode != 0) {
            try std.testing.expectEqual(ledger.live, profile.live_requested_bytes);
            try std.testing.expectEqual(ledger.peak, profile.peak_requested_bytes);
            try std.testing.expectEqual(total.control_bytes + encoder.plain.capacity + encoder.pending.capacity + encoder.codec_state.payload.capacity, ledger.live);
        }
        try std.testing.expectEqual(ledger.live, encoder.retainedCapacity());
        encoder.deinit();
        encoder_alive = false;
        try std.testing.expectEqual(@as(usize, 0), ledger.live);
        if (mode != 0) try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    }
}

test "Brotli total memory generic seeds retained bytes once and rejects reconfiguration before reset" {
    var ledger = tracking.TrackingAllocator.init(std.testing.allocator);
    var encoder = Encoder.init(ledger.allocator());
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(std.testing.allocator);
    _ = try encoder.step("abcd", &.{});
    try encoder.finish();
    try drain(&encoder, &wire, .done);
    const retained = ledger.live;
    const before = encoder.snapshot();
    const allocations = ledger.alloc_attempts;
    var profile: total.EncodeMemoryProfile = .{};
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.nextStream(.{ .stream = .{ .max_total_working_memory = total.control_bytes + retained - 1, .memory_profile = &profile } }));
    try std.testing.expectEqual(before, encoder.snapshot());
    try std.testing.expectEqual(@as(usize, 0), encoder.codec_state.resets);
    try std.testing.expectEqual(allocations, ledger.alloc_attempts);
    try std.testing.expectEqual(retained, ledger.live);
    const cap = total.control_bytes + retained + 128;
    try encoder.nextStream(.{ .stream = .{ .max_total_working_memory = cap, .memory_profile = &profile } });
    const stable = encoder.memory_binding.lease.?.state;
    try std.testing.expectEqual(total.control_bytes + retained, ledger.live);
    try std.testing.expectEqual(ledger.live, profile.live_requested_bytes);
    try std.testing.expectEqual(@as(usize, 1), encoder.codec_state.resets);
    wire.clearRetainingCapacity();
    _ = try encoder.step("abcd", &.{});
    try encoder.finish();
    try drain(&encoder, &wire, .done);
    const configured = encoder.snapshot();
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.nextStream(.{ .stream = .{ .max_total_working_memory = ledger.live - 1, .memory_profile = &profile } }));
    try std.testing.expectEqual(configured, encoder.snapshot());
    try std.testing.expectEqual(cap, encoder.memory_binding.lease.?.snapshot().limit.?);
    try std.testing.expectEqual(@as(usize, 1), encoder.codec_state.resets);
    encoder.reset();
    try std.testing.expect(encoder.memory_binding.lease.?.state == stable);
    try std.testing.expectEqual(total.control_bytes + retained, ledger.live);
}

test "Brotli total memory generic moves with a shared lease and frees through its original owner" {
    var ledger = tracking.TrackingAllocator.init(std.testing.allocator);
    var profile: total.EncodeMemoryProfile = .{};
    var outer = try total.Lease.init(ledger.allocator(), total.control_bytes + 1024, &profile, 0);
    var outer_alive = true;
    defer if (outer_alive) outer.deinit();
    const a = outer.allocator();
    var encoder = try Encoder.initWithSharedLease(a, .{}, outer);
    var encoder_alive = true;
    defer if (encoder_alive) encoder.deinit();
    _ = try encoder.step("abcd", &.{});
    const stable = encoder.memory_binding.lease.?.state;
    var moved = encoder;
    encoder = undefined;
    encoder_alive = false;
    var moved_alive = true;
    defer if (moved_alive) moved.deinit();
    var moved_outer = outer;
    outer = undefined;
    outer_alive = false;
    var moved_outer_alive = true;
    defer if (moved_outer_alive) moved_outer.deinit();
    const winner = try a.dupe(u8, "q10 winner");
    var winner_alive = true;
    defer if (winner_alive) a.free(winner);
    try moved.finish();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(std.testing.allocator);
    try drain(&moved, &wire, .done);
    try std.testing.expect(moved.memory_binding.lease.?.state == stable);
    try std.testing.expectEqual(ledger.live, profile.live_requested_bytes);
    try std.testing.expectEqual(ledger.live - total.control_bytes - winner.len, moved.retainedCapacity());
    // Cleanup must use the stored active allocator, not a changed public base.
    moved.allocator = std.testing.allocator;
    moved.deinit();
    moved_alive = false;
    try std.testing.expectEqual(total.control_bytes + winner.len, ledger.live);
    a.free(winner);
    winner_alive = false;
    moved_outer.deinit();
    moved_outer_alive = false;
    try std.testing.expectEqual(@as(usize, 0), ledger.live);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
}

test "Brotli total memory generic preserves backing OOM and retries accepted final input" {
    var ledger = tracking.TrackingAllocator.init(std.testing.allocator);
    var profile: total.EncodeMemoryProfile = .{};
    var encoder = Encoder.initWithOptions(ledger.allocator(), .{ .stream = .{ .memory_profile = &profile } });
    defer encoder.deinit();
    _ = try encoder.step("abcd", &.{});
    try encoder.finish();
    const before = encoder.snapshot();
    ledger.fail_alloc_after = ledger.alloc_attempts;
    try std.testing.expectError(error.OutOfMemory, encoder.step(&.{}, &.{}));
    try std.testing.expectEqual(before, encoder.snapshot());
    try std.testing.expectEqualSlices(u8, "abcd", encoder.plain.items);
    try std.testing.expectEqualSlices(u8, &.{0x01}, encoder.pending.items);
    try std.testing.expectEqual(@as(usize, 0), encoder.codec_state.blocks);
    try std.testing.expectEqual(ledger.live, profile.live_requested_bytes);
    ledger.clearFailures();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(std.testing.allocator);
    try drain(&encoder, &wire, .done);
    try std.testing.expectEqualSlices(u8, &.{ 0x61, 'a', 'b', 'c', 'd', 0xff }, wire.items);
    try std.testing.expectEqual(@as(usize, 1), encoder.codec_state.blocks);
}

test "Brotli total memory generic maps total denial without discarding earlier output progress" {
    var ledger = tracking.TrackingAllocator.init(std.testing.allocator);
    ledger.force_moving_growth = true;
    var profile: total.EncodeMemoryProfile = .{};
    var encoder = Encoder.initWithOptions(ledger.allocator(), .{ .stream = .{ .memory_profile = &profile } });
    defer encoder.deinit();
    _ = try encoder.step("abcd", &.{});
    encoder.flush();
    try std.testing.expectEqual(.need_output, (try encoder.step(&.{}, &.{})).status);
    const metadata = "m" ** 256;
    try encoder.writeMetadata(metadata);
    encoder.options.stream.max_total_working_memory = ledger.live;
    var output: [6]u8 = @splat(0xa5);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.step(&.{}, &output));
    try std.testing.expectEqualSlices(u8, &.{ 0x21, 'a', 'b', 'c', 'd', 0xa5 }, &output);
    try std.testing.expectEqual(@as(usize, 5), encoder.snapshot().output_written);
    try std.testing.expectEqual(@as(usize, 4), encoder.snapshot().input_read);
    try std.testing.expect(encoder.snapshot().metadata_pending);
    try std.testing.expectEqualSlices(u8, &.{0x01}, encoder.pending.items[encoder.pending_offset..]);
    try std.testing.expectEqual(ledger.live, profile.live_requested_bytes);
    try std.testing.expect(profile.peak_requested_bytes <= encoder.options.stream.max_total_working_memory.?);
    encoder.options.stream.max_total_working_memory = ledger.live + 1024;
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(std.testing.allocator);
    try wire.appendSlice(std.testing.allocator, output[0..5]);
    try drain(&encoder, &wire, .need_input);
    try encoder.finish();
    try drain(&encoder, &wire, .done);
    const expected = [_]u8{ 0x21, 'a', 'b', 'c', 'd', 0xa1 } ++ metadata.* ++ [_]u8{ 0xe1, 0xff };
    try std.testing.expectEqualSlices(u8, &expected, wire.items);
    try std.testing.expectEqual(@as(usize, 1), encoder.codec_state.blocks);
    try std.testing.expectEqual(ledger.live, profile.live_requested_bytes);
}

test "Brotli total memory public tiny caps reject before input and preserve backing accounting" {
    for ([_]bool{ false, true }) |hq| {
        for ([_]usize{ 0, total.control_bytes }) |limit| {
            var ledger = tracking.TrackingAllocator.init(std.testing.allocator);
            var profile: br.EncodeMemoryProfile = .{};
            var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(ledger.allocator(), .{ .stream = .{
                .quality = if (hq) 10 else 0,
                .hq = if (hq) .{} else null,
                .max_total_working_memory = limit,
                .memory_profile = &profile,
            } });
            var alive = true;
            defer if (alive) encoder.deinit();
            var output: [8]u8 = @splat(0xa5);
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.step("tiny", &output));
            try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().input_read);
            try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().output_written);
            try tracking.untouched(&output);
            try std.testing.expect(profile.available);
            try std.testing.expectEqual(ledger.live, profile.live_requested_bytes);
            try std.testing.expectEqual(ledger.peak, profile.peak_requested_bytes);
            try std.testing.expect(profile.peak_requested_bytes <= limit);
            try std.testing.expectEqual(@as(usize, if (limit == 0) 0 else 1), ledger.alloc_attempts);
            encoder.deinit();
            alive = false;
            try std.testing.expectEqual(@as(usize, 0), ledger.live);
            try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
        }
    }
}

test "Brotli total memory public tiny profile-only encoding tracks real buffers and round trips" {
    var ledger = tracking.TrackingAllocator.init(std.testing.allocator);
    var profile: br.EncodeMemoryProfile = .{};
    var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(ledger.allocator(), .{ .stream = .{ .quality = 0, .memory_profile = &profile } });
    var alive = true;
    defer if (alive) encoder.deinit();
    const wire = try tracking.drive(std.testing.allocator, &encoder, "tiny", 2, 3);
    defer std.testing.allocator.free(wire);
    try std.testing.expect(profile.available);
    try std.testing.expectEqual(@as(?usize, null), profile.limit);
    try std.testing.expect(profile.peak_requested_bytes > total.control_bytes);
    try std.testing.expectEqual(ledger.live, profile.live_requested_bytes);
    try std.testing.expectEqual(ledger.peak, profile.peak_requested_bytes);
    const decoded = try br.decodeStreamAllocExactSize(std.testing.allocator, wire, 4);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualStrings("tiny", decoded);
    encoder.deinit();
    alive = false;
    try std.testing.expectEqual(@as(usize, 0), ledger.live);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
}

fn drain(encoder: *Encoder, bytes: *std.ArrayList(u8), expected: core.StepResult.Status) !void {
    var output: [1]u8 = undefined;
    while (true) {
        const result = try encoder.step(&.{}, &output);
        try bytes.appendSlice(std.testing.allocator, output[0..result.progress.output_written]);
        try std.testing.expectEqual(bytes.items.len, encoder.snapshot().stream_output);
        if (result.status == expected) return;
        try std.testing.expectEqual(.need_output, result.status);
        try std.testing.expectEqual(@as(usize, 1), result.progress.output_written);
    }
}
