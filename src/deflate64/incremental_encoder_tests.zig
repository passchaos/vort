const std = @import("std");
const deflate64 = @import("../deflate64.zig");

test "Deflate64 incremental stored encoder is split independent" {
    const allocator = std.testing.allocator;
    const input = try allocator.alloc(u8, std.math.maxInt(u16) + 17);
    defer allocator.free(input);
    for (input, 0..) |*byte, index| byte.* = @truncate(index *% 73 +% index / 251);

    const expected = try deflate64.encodeStoredAlloc(allocator, input);
    defer allocator.free(expected);
    var encoder = deflate64.IncrementalStoredEncoder.initExactSize(
        allocator,
        .{},
        input.len,
    );
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    var scratch: [7]u8 = undefined;
    var offset: usize = 0;
    while (offset < input.len) {
        const end = @min(input.len, offset + 13);
        const stepped = try encoder.step(input[offset..end], &scratch);
        offset += stepped.progress.input_read;
        try encoded.appendSlice(allocator, scratch[0..stepped.progress.output_written]);
    }
    encoder.finish();
    while (true) {
        const stepped = try encoder.step("", &scratch);
        try encoded.appendSlice(allocator, scratch[0..stepped.progress.output_written]);
        if (stepped.status == .done) break;
    }
    try std.testing.expectEqualSlices(u8, expected, encoded.items);
    const decoded = try deflate64.decodeAlloc(allocator, encoded.items);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "Deflate64 incremental stored encoder handles empty backpressure and limits" {
    const allocator = std.testing.allocator;
    var encoder = deflate64.IncrementalStoredEncoder.init(allocator);
    defer encoder.deinit();
    encoder.finish();
    const blocked = try encoder.step("", &.{});
    try std.testing.expectEqual(.need_output, blocked.status);
    var output: [5]u8 = undefined;
    const drained = try encoder.step("", &output);
    try std.testing.expectEqual(.need_output, drained.status);
    try std.testing.expectEqualSlices(u8, &.{ 1, 0, 0, 0xff, 0xff }, &output);
    const done = try encoder.step("", &.{});
    try std.testing.expectEqual(.done, done.status);

    var limited = deflate64.IncrementalStoredEncoder.initWithOptions(allocator, .{
        .max_input_len = 3,
    });
    defer limited.deinit();
    var scratch: [16]u8 = undefined;
    try std.testing.expectError(error.OutputLimitExceeded, limited.step("four", &scratch));

    var pledged = deflate64.IncrementalStoredEncoder.initExactSize(allocator, .{}, 4);
    defer pledged.deinit();
    _ = try pledged.step("abc", &scratch);
    pledged.finish();
    try std.testing.expectError(error.SizeMismatch, pledged.step("", &scratch));
}

const BorrowEncoder = deflate64.IncrementalStoredEncoder;
const borrow_prefix = "accepted prefix publishes a real stored block before future input";
const borrow_suffix = " disjoint retry preserves caller bytes";

/// This codec keeps only bit_index inline; its shared stored core must not
/// assume the State owns a bytes list when checking borrows or cloning.
const BorrowSaved = struct {
    receiver: [@sizeOf(BorrowEncoder)]u8,
    plain: []u8,
    pending: []u8,

    fn init(encoder: *BorrowEncoder) !BorrowSaved {
        const allocator = std.testing.allocator;
        const plain = try allocator.dupe(u8, encoder.plain.allocatedSlice());
        errdefer allocator.free(plain);
        const pending = try allocator.dupe(u8, encoder.pending.allocatedSlice());
        var saved = BorrowSaved{ .receiver = undefined, .plain = plain, .pending = pending };
        @memcpy(&saved.receiver, std.mem.asBytes(encoder));
        return saved;
    }

    fn deinit(self: *BorrowSaved) void {
        std.testing.allocator.free(self.plain);
        std.testing.allocator.free(self.pending);
    }

    fn expectUnchanged(self: *const BorrowSaved, encoder: *BorrowEncoder) !void {
        try std.testing.expectEqualSlices(u8, &self.receiver, std.mem.asBytes(encoder));
        try std.testing.expectEqualSlices(u8, self.plain, encoder.plain.allocatedSlice());
        try std.testing.expectEqualSlices(u8, self.pending, encoder.pending.allocatedSlice());
    }
};

fn borrowReject(encoder: *BorrowEncoder, input: []const u8, output: []u8, caller: []const u8) !void {
    const allocator = std.testing.allocator;
    var saved = try BorrowSaved.init(encoder);
    defer saved.deinit();
    const input_before = try allocator.dupe(u8, input);
    defer allocator.free(input_before);
    const output_before = try allocator.dupe(u8, output);
    defer allocator.free(output_before);
    const caller_before = try allocator.dupe(u8, caller);
    defer allocator.free(caller_before);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.step(input, output));
    try saved.expectUnchanged(encoder);
    try std.testing.expectEqualSlices(u8, input_before, input);
    try std.testing.expectEqualSlices(u8, output_before, output);
    try std.testing.expectEqualSlices(u8, caller_before, caller);
}

fn borrowReserveSpare(encoder: *BorrowEncoder) !void {
    inline for (.{ "plain", "pending" }) |field| {
        const list = &@field(encoder, field);
        try list.ensureTotalCapacity(std.testing.allocator, list.items.len + 16);
        @memset(list.allocatedSlice()[list.items.len..], 0xa5);
    }
}

fn borrowFeed(encoder: *BorrowEncoder, input: []const u8, encoded: *std.ArrayList(u8)) !void {
    var output: [7]u8 = undefined;
    var consumed: usize = 0;
    for (0..256) |_| {
        if (consumed == input.len) return;
        const result = try encoder.step(input[consumed..], &output);
        consumed += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, output[0..result.progress.output_written]);
        try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
    return error.TestUnexpectedResult;
}

fn borrowFinish(encoder: *BorrowEncoder, encoded: *std.ArrayList(u8)) !void {
    encoder.finish();
    var output: [7]u8 = undefined;
    for (0..256) |_| {
        const result = try encoder.step("", &output);
        try encoded.appendSlice(std.testing.allocator, output[0..result.progress.output_written]);
        if (result.status == .done) return;
        try std.testing.expect(result.progress.output_written != 0);
    }
    return error.TestUnexpectedResult;
}

/// Oracle is cloned before the rejected calls, with independent allocations.
fn borrowRetry(encoder: *BorrowEncoder, oracle: *BorrowEncoder, previous_wire: []const u8, input: []const u8, expected_plain: []const u8) !void {
    const allocator = std.testing.allocator;
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(allocator);
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);
    try actual.appendSlice(allocator, previous_wire);
    try expected.appendSlice(allocator, previous_wire);
    try borrowFeed(encoder, input, &actual);
    try borrowFeed(oracle, input, &expected);
    try borrowFinish(encoder, &actual);
    try borrowFinish(oracle, &expected);
    try std.testing.expectEqualSlices(u8, expected.items, actual.items);
    const decoded = try deflate64.decodeAlloc(allocator, actual.items);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected_plain, decoded);
}

test "Deflate64 incremental stored encoder borrows reject caller and inline receiver overlaps" {
    try std.testing.expect(!@hasField(@TypeOf(@as(BorrowEncoder, undefined).state), "bytes"));
    var encoder = BorrowEncoder.initWithOptions(std.testing.allocator, .{ .block_len = 16 });
    defer encoder.deinit();
    var oracle = try encoder.clone(std.testing.allocator);
    defer oracle.deinit();
    var caller: [192]u8 = @splat(0xa5);
    const start = 32;
    const end = start + borrow_suffix.len;
    @memcpy(caller[start..end], borrow_suffix);
    const input = caller[start..end];
    const overlaps = [_][]u8{
        caller[start..],
        caller[start + 1 ..],
        caller[start - 1 ..],
        caller[start - 8 .. end + 8],
        caller[start .. start + 1],
        caller[end - 1 .. end],
    };
    for (overlaps) |output| try borrowReject(&encoder, input, output, &caller);
    const receiver = std.mem.asBytes(&encoder);
    const inline_state = std.mem.asBytes(&encoder.state);
    try borrowReject(&encoder, receiver[0..1], &caller, &caller);
    try borrowReject(&encoder, receiver[receiver.len - 1 ..], &caller, &caller);
    try borrowReject(&encoder, input, receiver[0..1], &caller);
    try borrowReject(&encoder, input, receiver[receiver.len - 1 ..], &caller);
    try borrowReject(&encoder, inline_state, caller[0..0], &caller);
    try borrowReject(&encoder, "", inline_state, &caller);
    try borrowRetry(&encoder, &oracle, "", input, borrow_suffix);
}

test "Deflate64 incremental stored encoder borrows protect live and reset capacities" {
    inline for (.{ false, true }) |after_reset| {
        const allocator = std.testing.allocator;
        var encoder = BorrowEncoder.initWithOptions(allocator, .{ .block_len = 16 });
        defer encoder.deinit();
        var encoded: std.ArrayList(u8) = .empty;
        defer encoded.deinit(allocator);
        try borrowFeed(&encoder, borrow_prefix, &encoded);
        if (after_reset) {
            try borrowFinish(&encoder, &encoded);
            encoder.reset();
            encoded.clearRetainingCapacity();
            try std.testing.expectEqual(@as(usize, 0), encoder.plain.items.len);
            try std.testing.expectEqual(@as(usize, 0), encoder.pending.items.len);
            try std.testing.expectEqual(@as(u3, 0), encoder.state.bit_index);
        }
        try borrowReserveSpare(&encoder);
        var oracle = try encoder.clone(allocator);
        defer oracle.deinit();
        var caller: [128]u8 = @splat(0xa5);
        inline for (.{ "plain", "pending" }) |field| {
            const list = &@field(encoder, field);
            const full = list.allocatedSlice();
            const spare = full[list.items.len..];
            try std.testing.expect(spare.len != 0);
            try borrowReject(&encoder, full, &caller, &caller);
            try borrowReject(&encoder, spare, &caller, &caller);
            try borrowReject(&encoder, full[full.len - 1 ..], caller[0..0], &caller);
            try borrowReject(&encoder, borrow_suffix, full, &caller);
            try borrowReject(&encoder, borrow_suffix, spare, &caller);
            try borrowReject(&encoder, "", full[full.len - 1 ..], &caller);
        }
        try borrowRetry(&encoder, &oracle, encoded.items, borrow_suffix, if (after_reset) borrow_suffix else borrow_prefix ++ borrow_suffix);
    }
}

test "Deflate64 incremental stored encoder borrows protect unread future input during pending drain" {
    const allocator = std.testing.allocator;
    var encoder = BorrowEncoder.initWithOptions(allocator, .{ .block_len = 16 });
    defer encoder.deinit();
    const accepted = try encoder.step(borrow_prefix, &.{});
    try std.testing.expectEqual(.need_output, accepted.status);
    try std.testing.expectEqual(@as(usize, 0), accepted.progress.output_written);
    try std.testing.expect(accepted.progress.input_read != 0 and accepted.progress.input_read < borrow_prefix.len);
    try std.testing.expect(encoder.pending.items.len - encoder.pending_offset != 0);
    try borrowReserveSpare(&encoder);
    var oracle = try encoder.clone(allocator);
    defer oracle.deinit();
    var caller: [192]u8 = @splat(0xa5);
    const future = borrow_prefix[accepted.progress.input_read..];
    @memcpy(caller[32..][0..future.len], future);
    const input = caller[32..][0..future.len];
    try borrowReject(&encoder, input, caller[32..], &caller);
    try borrowReject(&encoder, input, caller[31..33], &caller);
    try borrowReject(&encoder, input, input[input.len - 1 ..], &caller);
    try borrowRetry(&encoder, &oracle, "", input, borrow_prefix);
}

test "Deflate64 incremental stored encoder borrows allow empty adjacent and done output" {
    const allocator = std.testing.allocator;
    var encoder = BorrowEncoder.initWithOptions(allocator, .{ .block_len = 16 });
    defer encoder.deinit();
    var caller: [192]u8 = @splat(0xa5);
    const start = 32;
    const end = start + borrow_suffix.len;
    @memcpy(caller[start..end], borrow_suffix);
    const input = caller[start..end];
    const before = caller;
    const accepted = try encoder.step(input, input[0..0]);
    try std.testing.expectEqual(@as(usize, 0), accepted.progress.output_written);
    try std.testing.expectEqualSlices(u8, &before, &caller);
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    var consumed = accepted.progress.input_read;
    for (0..256) |_| {
        if (consumed == input.len) break;
        const output = caller[end..][0..7];
        const result = try encoder.step(input[consumed..], output);
        consumed += result.progress.input_read;
        try encoded.appendSlice(allocator, output[0..result.progress.output_written]);
        try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
    try std.testing.expectEqual(input.len, consumed);
    try std.testing.expectEqualSlices(u8, borrow_suffix, input);
    try borrowFinish(&encoder, &encoded);
    const decoded = try deflate64.decodeAlloc(allocator, encoded.items);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, borrow_suffix, decoded);
    try borrowReserveSpare(&encoder);
    var saved = try BorrowSaved.init(&encoder);
    defer saved.deinit();
    const receiver = std.mem.asBytes(&encoder);
    const outputs = [_][]u8{ receiver, encoder.plain.allocatedSlice(), encoder.pending.allocatedSlice() };
    for (outputs) |output| {
        const done = try encoder.step(receiver[0..0], output);
        try std.testing.expectEqual(.done, done.status);
        try std.testing.expectEqual(@as(usize, 0), done.progress.input_read);
        try std.testing.expectEqual(@as(usize, 0), done.progress.output_written);
    }
    try saved.expectUnchanged(&encoder);
}
