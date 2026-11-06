//! Real bounded fixtures and a lawful repeated-prefix model. The model proves
//! one repeat's wire/statistics, checks repeated quiescent states, then scales
//! only additive counters. It is not evidence from an actual 4GiB tool run.
const std = @import("std");
pub const core = @import("../core.zig");
pub const Count = core.StreamCount;
pub const counts = core.stream_count;
pub const allocator = std.testing.allocator;
pub const boundary: Count = @as(Count, 1) << 32;
pub const max_count: Count = std.math.maxInt(Count);
pub const prefix = "R" ** 16;
pub const inspect = @import("test_wire.zig").inspect;
pub const Flush = enum { block, partial, sync, full };

pub fn requestFlush(encoder: anytype, mode: Flush) void {
    switch (mode) {
        .block => encoder.blockFlush(),
        .partial => encoder.partialFlush(),
        .sync => encoder.flush(),
        .full => encoder.fullFlush(),
    }
}

pub const fields = .{ "total_input", "total_output", "block_count", "fixed_block_count", "dynamic_block_count", "stored_block_count", "match_count" };
pub const Ledger = [fields.len]Count;

pub fn ledger(encoder: anytype) Ledger {
    var result: Ledger = undefined;
    inline for (fields, 0..) |field, index| result[index] = @field(encoder, field);
    return result;
}

pub fn delta(before: Ledger, after: Ledger) Ledger {
    var result: Ledger = undefined;
    for (&result, before, after) |*value, first, last| value.* = last - first;
    return result;
}

pub fn oracleDelta(wire: []const u8, input: []const u8, actual: Ledger) !void {
    var parsed = try inspect(wire, input.len);
    defer parsed.deinit();
    try std.testing.expectEqualSlices(u8, input, parsed.output);
    try std.testing.expectEqualDeep(@as(Ledger, .{
        input.len,             wire.len,             parsed.blocks.items.len,  parsed.fixed_blocks,
        parsed.dynamic_blocks, parsed.stored_blocks, parsed.matches.items.len,
    }), actual);
}

pub fn guard(bytes: []const u8) !void {
    for (bytes) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

pub fn step(encoder: anytype, input: []const u8, output: []u8) !core.StepResult {
    const before = encoder.snapshot();
    const result = encoder.step(input, output) catch |err| {
        const after = encoder.snapshot();
        const failure = encoder.failedProgress() orelse return error.TestUnexpectedResult;
        try std.testing.expectEqual(failure.input_read, try counts.toLocal(after.input_read - before.input_read));
        try std.testing.expectEqual(failure.output_written, try counts.toLocal(after.output_written - before.output_written));
        try std.testing.expect(failure.input_read <= input.len and failure.output_written <= output.len);
        try std.testing.expectEqualDeep(failure, after.last_step_progress);
        try guard(output[failure.output_written..]);
        return err;
    };
    const after = encoder.snapshot();
    try std.testing.expectEqual(result.progress.input_read, try counts.toLocal(after.input_read - before.input_read));
    try std.testing.expectEqual(result.progress.output_written, try counts.toLocal(after.output_written - before.output_written));
    try std.testing.expectEqualDeep(result.progress, after.last_step_progress);
    try std.testing.expect(result.progress.input_read <= input.len and result.progress.output_written <= output.len);
    try guard(output[result.progress.output_written..]);
    return result;
}

pub fn feed(encoder: anytype, input: []const u8, wire: *std.ArrayList(u8), input_quota: usize, output_quota: usize) !void {
    var output: [128]u8 = undefined;
    var offset: usize = 0;
    for (0..input.len * 4 + 4096) |call| {
        @memset(&output, 0xa5);
        const offered = input[offset..@min(input.len, offset + input_quota)];
        const result = try step(encoder, offered, output[0..if (call % 7 == 0) 0 else output_quota]);
        offset += result.progress.input_read;
        try wire.appendSlice(allocator, output[0..result.progress.output_written]);
        if (offset == input.len and result.status == .need_input) return;
    }
    return error.TestUnexpectedResult;
}

pub fn drain(encoder: anytype, wire: *std.ArrayList(u8), output_quota: usize, finishing: bool) !void {
    var output: [128]u8 = undefined;
    for (0..4096) |call| {
        @memset(&output, 0xa5);
        const result = try step(encoder, "", output[0..if (call % 7 == 0) 0 else output_quota]);
        try wire.appendSlice(allocator, output[0..result.progress.output_written]);
        if (result.status == (if (finishing) core.StepResult.Status.done else .need_input)) return;
        try std.testing.expectEqual(core.StepResult.Status.need_output, result.status);
    }
    return error.TestUnexpectedResult;
}

pub fn finish(encoder: anytype, wire: *std.ArrayList(u8), output_quota: usize) !void {
    encoder.finish();
    try drain(encoder, wire, output_quota, true);
}

pub fn fullPrefix(encoder: anytype, wire: *std.ArrayList(u8)) !void {
    try feed(encoder, prefix, wire, 3, 5);
    encoder.fullFlush();
    try drain(encoder, wire, 5, false);
    const snapshot = encoder.snapshot();
    try std.testing.expectEqual(@as(usize, 0), snapshot.buffered_input);
    try std.testing.expectEqual(@as(usize, 0), snapshot.pending_output);
    try std.testing.expectEqual(@as(usize, 0), snapshot.history_len);
    try std.testing.expectEqual(@as(u3, 0), snapshot.pending_bits);
    try std.testing.expectEqual(@as(u32, 0), encoder.state.scratch);
    try std.testing.expectEqual(@as(usize, 0), encoder.pending_offset);
    try std.testing.expectEqual(@as(usize, 0), encoder.matcher.history.len);
    try std.testing.expectEqual(@as(usize, 0), encoder.matcher.block.len);
    try std.testing.expect(!snapshot.flushing and !snapshot.finishing and !snapshot.done and !snapshot.failed);
}

pub const Evidence = struct {
    increment: Ledger,
    wire: []u8,

    pub fn deinit(self: *Evidence) void {
        allocator.free(self.wire);
    }
};

pub fn provePrefix(comptime Encoder: type, options: Encoder.Options) !Evidence {
    var first = Encoder.initWithOptions(allocator, options);
    defer first.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(allocator);
    try fullPrefix(&first, &wire);
    const increment = ledger(first);
    const prefix_wire = try allocator.dupe(u8, wire.items);
    errdefer allocator.free(prefix_wire);
    const quiescent = first.snapshot();
    try finish(&first, &wire, 5);
    var parsed = try inspect(wire.items, prefix.len);
    defer parsed.deinit();
    try std.testing.expectEqualSlices(u8, prefix, parsed.output);
    // Inspect a real finalized stream, then count only the non-final prefix
    // blocks. The final empty block is deliberately excluded from evidence.
    var oracle: Ledger = .{ prefix.len, prefix_wire.len, 0, 0, 0, 0, 0 };
    var maximum_length: usize = 0;
    var maximum_distance: usize = 0;
    for (parsed.blocks.items) |block| {
        if (block.final) continue;
        oracle[2] += 1;
        switch (block.kind) {
            0 => oracle[5] += 1,
            1 => oracle[3] += 1,
            2 => oracle[4] += 1,
            else => return error.TestUnexpectedResult,
        }
    }
    for (parsed.matches.items) |match| if (!parsed.blocks.items[match.block].final) {
        oracle[6] += 1;
        maximum_length = @max(maximum_length, match.length);
        maximum_distance = @max(maximum_distance, match.distance);
    };
    try std.testing.expectEqualDeep(oracle, increment);
    try std.testing.expectEqual(maximum_length, quiescent.max_match_length);
    try std.testing.expectEqual(maximum_distance, quiescent.max_match_distance);
    try std.testing.expectEqual(prefix_wire.len * 8, parsed.blocks.items[try counts.toLocal(increment[2]) - 1].bit_end);

    var repeated = Encoder.initWithOptions(allocator, options);
    defer repeated.deinit();
    for (0..17) |repeat| {
        wire.clearRetainingCapacity();
        const before = ledger(repeated);
        try fullPrefix(&repeated, &wire);
        try std.testing.expectEqualSlices(u8, prefix_wire, wire.items);
        try std.testing.expectEqualDeep(increment, delta(before, ledger(repeated)));
        inline for (fields, 0..) |field, index|
            try std.testing.expectEqual(increment[index] * (repeat + 1), @field(repeated, field));
        try std.testing.expectEqual(first.flush_boundary, repeated.flush_boundary);
        try std.testing.expectEqualDeep(@as(@TypeOf(repeated.state), .{}), repeated.state);
        try std.testing.expectEqual(maximum_length, repeated.snapshot().max_match_length);
        try std.testing.expectEqual(maximum_distance, repeated.snapshot().max_match_distance);
    }
    return .{ .increment = increment, .wire = prefix_wire };
}

/// Caller first reaches this quiescent state using fullPrefix. All remaining
/// history/index state is local and is rebuilt for the next block. Only the
/// measured additive totals differ after another identical full-flush cycle.
pub fn repeatModel(encoder: anytype, evidence: Evidence, repeat: Count) !void {
    try std.testing.expectEqualDeep(evidence.increment, ledger(encoder.*));
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().history_len);
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().pending_output);
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().buffered_input);
    try std.testing.expectEqualDeep(@as(@TypeOf(encoder.state), .{}), encoder.state);
    inline for (fields, 0..) |field, index| @field(encoder, field) = evidence.increment[index] * repeat;
}

pub fn sticky(encoder: anytype, expected_error: anyerror) !void {
    const snapshot = encoder.snapshot();
    const progress = encoder.failedProgress();
    var output: [128]u8 = @splat(0xa5);
    try std.testing.expectError(expected_error, encoder.step("unaccepted after failure", &output));
    try std.testing.expectEqualDeep(snapshot, encoder.snapshot());
    try std.testing.expectEqualDeep(progress, encoder.failedProgress());
    try guard(&output);
}

pub fn atomicFailure(encoder: anytype, expected_error: anyerror, input: []const u8) !void {
    var expected = encoder.snapshot();
    const state = encoder.state;
    const contents = .{
        std.hash.Wyhash.hash(0, encoder.plain.items),
        std.hash.Wyhash.hash(0, encoder.pending.items),
        std.hash.Wyhash.hash(0, encoder.history.items),
    };
    const offset = encoder.pending_offset;
    var output: [128]u8 = @splat(0xa5);
    try std.testing.expectError(expected_error, step(encoder, input, &output));
    expected.failed = true;
    expected.last_error_name = @errorName(expected_error);
    expected.last_step_progress = .{};
    try std.testing.expectEqualDeep(expected, encoder.snapshot());
    try std.testing.expectEqualDeep(@as(?core.Progress, .{}), encoder.failedProgress());
    try std.testing.expectEqualDeep(state, encoder.state);
    try std.testing.expectEqualDeep(contents, .{
        std.hash.Wyhash.hash(0, encoder.plain.items),
        std.hash.Wyhash.hash(0, encoder.pending.items),
        std.hash.Wyhash.hash(0, encoder.history.items),
    });
    try std.testing.expectEqual(offset, encoder.pending_offset);
    try guard(&output);
    try sticky(encoder, expected_error);
}
