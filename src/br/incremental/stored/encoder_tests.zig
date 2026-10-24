const std = @import("std");
const core = @import("../../../core.zig");
const incremental = @import("encoder.zig");

// A small transactional codec makes the bridge's state transitions observable
// without depending on compression choices. Each block shares a mutable header
// byte with its predecessor, just as a non-aligned Brotli meta-block does.
pub const TransactionCodec = struct {
    pub const Error = error{ OutOfMemory, InvalidBlockPlan, TrailingData, IntegerOverflow, OutputLimitExceeded };
    pub const StreamOptions = struct { deferred: bool = true };
    pub const max_block_len = 4;
    pub const default_block_len = 4;
    // The dynamic policy must take precedence over this legacy static policy.
    pub const defer_full_block_until_more_input = true;
    pub const State = struct {
        bit_index: u3 = 0,
        blocks: usize = 0,
        final_blocks: usize = 0,
        metadata_blocks: usize = 0,
        history: [16]u8 = undefined,
        history_len: usize = 0,
        distance_cache: u8 = 0,
    };

    pub fn deferFullBlock(options: StreamOptions) bool {
        return options.deferred;
    }

    pub fn readyOutputLen(state: *const State, pending_len: usize, final_written: bool) usize {
        return pending_len - @intFromBool(!final_written and state.bit_index != 0);
    }

    pub fn writePrefix(allocator: std.mem.Allocator, out: *std.ArrayList(u8), state: *State, _: StreamOptions) Error!void {
        try out.append(allocator, 0x01);
        state.bit_index = 1;
    }

    pub fn writeBlock(allocator: std.mem.Allocator, out: *std.ArrayList(u8), state: *State, input: []const u8) Error!void {
        try publish(allocator, out, 0x21, input, 0x01);
        commitInput(state, input);
    }

    pub fn writeFinalBlock(allocator: std.mem.Allocator, out: *std.ArrayList(u8), state: *State, input: []const u8) Error!void {
        try publish(allocator, out, 0x61, input, 0xff);
        commitInput(state, input);
        state.final_blocks += 1;
        state.bit_index = 0;
    }

    pub fn writeMetadata(allocator: std.mem.Allocator, out: *std.ArrayList(u8), state: *State, metadata: []const u8) Error!void {
        try publish(allocator, out, 0xa1, metadata, 0x01);
        state.metadata_blocks += 1;
    }

    pub fn writeFinal(allocator: std.mem.Allocator, out: *std.ArrayList(u8), state: *State) Error!void {
        try publish(allocator, out, 0xe1, &.{}, 0xff);
        state.bit_index = 0;
    }

    fn publish(allocator: std.mem.Allocator, out: *std.ArrayList(u8), header: u8, bytes: []const u8, tail: u8) Error!void {
        std.debug.assert(out.items.len != 0);
        try out.ensureUnusedCapacity(allocator, bytes.len + 1);
        out.items[out.items.len - 1] = header;
        out.appendSliceAssumeCapacity(bytes);
        out.appendAssumeCapacity(tail);
    }

    fn commitInput(state: *State, input: []const u8) void {
        @memcpy(state.history[state.history_len..][0..input.len], input);
        state.history_len += input.len;
        state.distance_cache = input[input.len - 1];
        state.blocks += 1;
    }
};

const Encoder = incremental.Encoder(TransactionCodec);

const LegacyDeferredCodec = struct {
    pub const Error = TransactionCodec.Error;
    pub const StreamOptions = TransactionCodec.StreamOptions;
    pub const State = TransactionCodec.State;
    pub const max_block_len = TransactionCodec.max_block_len;
    pub const default_block_len = TransactionCodec.default_block_len;
    pub const defer_full_block_until_more_input = true;
    pub const readyOutputLen = TransactionCodec.readyOutputLen;
    pub const writePrefix = TransactionCodec.writePrefix;
    pub const writeBlock = TransactionCodec.writeBlock;
    pub const writeMetadata = TransactionCodec.writeMetadata;
    pub const writeFinal = TransactionCodec.writeFinal;
};

test "Brotli HQ generic bridge preserves legacy static deferral and empty-final wire" {
    var encoder = incremental.Encoder(LegacyDeferredCodec).init(std.testing.allocator);
    defer encoder.deinit();
    try std.testing.expectEqual(.need_input, (try encoder.step("abcd", &.{})).status);
    try std.testing.expectEqual(@as(usize, 0), encoder.codec_state.blocks);
    try encoder.finish();
    var output: [16]u8 = undefined;
    const result = try encoder.step(&.{}, &output);
    try std.testing.expectEqual(.done, result.status);
    try std.testing.expectEqualSlices(u8, &.{ 0x21, 'a', 'b', 'c', 'd', 0xe1, 0xff }, output[0..result.progress.output_written]);
    try std.testing.expectEqual(@as(usize, 1), encoder.codec_state.blocks);
    try std.testing.expectEqual(@as(usize, 0), encoder.codec_state.final_blocks);
}

test "Brotli HQ generic bridge delays only opted-in full blocks" {
    for ([_]bool{ false, true }) |deferred| {
        var encoder = Encoder.initWithOptions(std.testing.allocator, .{ .stream = .{ .deferred = deferred } });
        defer encoder.deinit();
        const accepted = try encoder.step("abcd", &.{});
        try std.testing.expectEqual(@as(usize, 4), accepted.progress.input_read);
        try std.testing.expectEqual(@as(usize, 0), accepted.progress.output_written);
        try std.testing.expectEqual(if (deferred) core.StepResult.Status.need_input else .need_output, accepted.status);
        try std.testing.expectEqual(@as(usize, @intFromBool(!deferred)), encoder.codec_state.blocks);
        try std.testing.expectEqual(@as(usize, if (deferred) 4 else 0), encoder.snapshot().buffered_input);
        try encoder.finish();
        var encoded: std.ArrayList(u8) = .empty;
        defer encoded.deinit(std.testing.allocator);
        try drain(&encoder, &encoded, .done);
        try std.testing.expectEqualSlices(u8, if (deferred) &.{ 0x61, 'a', 'b', 'c', 'd', 0xff } else &.{ 0x21, 'a', 'b', 'c', 'd', 0xe1, 0xff }, encoded.items);
        try std.testing.expectEqual(@as(usize, @intFromBool(deferred)), encoder.codec_state.final_blocks);
    }
}

test "Brotli HQ generic bridge chooses non-final blocks before more input and metadata" {
    var encoder = Encoder.init(std.testing.allocator);
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    try std.testing.expectEqual(.need_input, (try encoder.step("abcd", &.{})).status);
    var output: [1]u8 = undefined;
    var input_read: usize = 0;
    while (input_read != 1) {
        const result = try encoder.step("e"[input_read..], &output);
        input_read += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, output[0..result.progress.output_written]);
    }
    try std.testing.expectEqual(@as(usize, 1), encoder.codec_state.blocks);
    try std.testing.expectEqualSlices(u8, "e", encoder.plain.items);
    try encoder.writeMetadata("m");
    try drain(&encoder, &encoded, .need_input);
    try std.testing.expectEqual(@as(usize, 2), encoder.codec_state.blocks);
    try std.testing.expectEqual(@as(usize, 1), encoder.codec_state.metadata_blocks);
    try std.testing.expect(!encoder.snapshot().flush_requested);
    try std.testing.expect(!encoder.snapshot().metadata_pending);
    try encoder.finish();
    try drain(&encoder, &encoded, .done);
    try std.testing.expectEqualSlices(u8, &.{ 0x21, 'a', 'b', 'c', 'd', 0x21, 'e', 0xa1, 'm', 0xe1, 0xff }, encoded.items);
    try std.testing.expectEqualSlices(u8, "abcde", encoder.codec_state.history[0..encoder.codec_state.history_len]);
}

test "Brotli HQ generic bridge final publication failure retains buffered input and reservoir" {
    var encoder = Encoder.init(std.testing.allocator);
    defer encoder.deinit();
    try std.testing.expectEqual(.need_input, (try encoder.step("abcd", &.{})).status);
    // Force publication to grow, even on allocators that initially overallocate.
    try restrictPendingCapacity(&encoder);
    const before = encoder.snapshot();
    try encoder.finish();
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    encoder.allocator = failing.allocator();
    try std.testing.expectError(error.OutOfMemory, encoder.step(&.{}, &.{}));
    encoder.allocator = std.testing.allocator;
    try std.testing.expectEqualSlices(u8, "abcd", encoder.plain.items);
    try std.testing.expectEqualSlices(u8, &.{0x01}, encoder.pending.items);
    try std.testing.expectEqual(@as(u3, 1), encoder.codec_state.bit_index);
    try std.testing.expectEqual(@as(usize, 0), encoder.codec_state.blocks);
    try std.testing.expectEqual(@as(usize, 0), encoder.codec_state.history_len);
    try std.testing.expectEqual(@as(u8, 0), encoder.codec_state.distance_cache);
    try std.testing.expectEqual(before.input_read, encoder.snapshot().input_read);
    try std.testing.expectEqual(before.output_written, encoder.snapshot().output_written);
    try std.testing.expect(!encoder.final_written);
    try std.testing.expect(!encoder.done);
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    try drain(&encoder, &encoded, .done);
    try std.testing.expectEqualSlices(u8, &.{ 0x61, 'a', 'b', 'c', 'd', 0xff }, encoded.items);
    try std.testing.expectEqual(@as(usize, 1), encoder.codec_state.blocks);
    try std.testing.expectEqual(@as(usize, 1), encoder.codec_state.final_blocks);
    try std.testing.expectEqual(@as(u8, 'd'), encoder.codec_state.distance_cache);
}

test "Brotli HQ generic bridge failed flush retries one non-final publication" {
    var encoder = Encoder.init(std.testing.allocator);
    defer encoder.deinit();
    _ = try encoder.step("abcd", &.{});
    try restrictPendingCapacity(&encoder);
    encoder.flush();
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    encoder.allocator = failing.allocator();
    try std.testing.expectError(error.OutOfMemory, encoder.step(&.{}, &.{}));
    encoder.allocator = std.testing.allocator;
    try std.testing.expect(encoder.flush_requested);
    try std.testing.expectEqualSlices(u8, "abcd", encoder.plain.items);
    try std.testing.expectEqualSlices(u8, &.{0x01}, encoder.pending.items);
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    try drain(&encoder, &encoded, .need_input);
    try std.testing.expectEqual(@as(usize, 1), encoder.codec_state.blocks);
    try std.testing.expectEqual(@as(usize, 0), encoder.codec_state.final_blocks);
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().buffered_input);
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().pending_output);
    try std.testing.expectEqualSlices(u8, &.{0x01}, encoder.pending.items[encoder.pending_offset..]);
    try encoder.finish();
    try drain(&encoder, &encoded, .done);
    try std.testing.expectEqualSlices(u8, &.{ 0x21, 'a', 'b', 'c', 'd', 0xe1, 0xff }, encoded.items);
}

test "Brotli HQ generic bridge retains progress when metadata fails after draining output" {
    var encoder = Encoder.init(std.testing.allocator);
    defer encoder.deinit();
    _ = try encoder.step("abcd", &.{});
    encoder.flush();
    try std.testing.expectEqual(.need_output, (try encoder.step(&.{}, &.{})).status);
    try encoder.writeMetadata("m");
    try restrictPendingCapacity(&encoder);
    var output: [6]u8 = @splat(0xaa);
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    encoder.allocator = failing.allocator();
    try std.testing.expectError(error.OutOfMemory, encoder.step(&.{}, &output));
    encoder.allocator = std.testing.allocator;
    // An error has no StepResult. The snapshot still records bytes already
    // returned, so the caller can keep that prefix and retry with empty input.
    try std.testing.expectEqual(@as(usize, 5), encoder.snapshot().output_written);
    try std.testing.expectEqualSlices(u8, &.{ 0x21, 'a', 'b', 'c', 'd', 0xaa }, &output);
    try std.testing.expectEqual(@as(usize, 4), encoder.snapshot().input_read);
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().buffered_input);
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().pending_output);
    try std.testing.expect(encoder.snapshot().metadata_pending);
    try std.testing.expectEqual(@as(usize, 0), encoder.codec_state.metadata_blocks);
    try std.testing.expectEqualSlices(u8, &.{0x01}, encoder.pending.items[encoder.pending_offset..]);
    try std.testing.expectEqualSlices(u8, "abcd", encoder.codec_state.history[0..encoder.codec_state.history_len]);
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    try encoded.appendSlice(std.testing.allocator, output[0..@intCast(encoder.snapshot().output_written)]);
    try drain(&encoder, &encoded, .need_input);
    try std.testing.expectEqual(@as(usize, 1), encoder.codec_state.metadata_blocks);
    try std.testing.expectEqual(@as(usize, 1), encoder.codec_state.blocks);
    try encoder.finish();
    try drain(&encoder, &encoded, .done);
    try std.testing.expectEqualSlices(u8, &.{ 0x21, 'a', 'b', 'c', 'd', 0xa1, 'm', 0xe1, 0xff }, encoded.items);
}

fn restrictPendingCapacity(encoder: *Encoder) !void {
    const pending = try std.testing.allocator.dupe(u8, encoder.pending.items);
    encoder.pending.deinit(std.testing.allocator);
    encoder.pending = .{ .items = pending, .capacity = pending.len };
}

fn drain(encoder: *Encoder, encoded: *std.ArrayList(u8), expected: core.StepResult.Status) !void {
    var output: [1]u8 = undefined;
    while (true) {
        const result = try encoder.step(&.{}, &output);
        try encoded.appendSlice(std.testing.allocator, output[0..result.progress.output_written]);
        try std.testing.expectEqual(encoded.items.len, encoder.snapshot().output_written);
        if (result.status == expected) return;
        try std.testing.expectEqual(.need_output, result.status);
        try std.testing.expect(result.progress.output_written != 0);
    }
}
