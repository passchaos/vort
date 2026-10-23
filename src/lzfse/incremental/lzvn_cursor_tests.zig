const std = @import("std");
const cursors = @import("lzvn_cursor.zig");
const history_mod = @import("history.zig");
const reference = @import("../lzvn.zig");
const allocator = std.testing.allocator;
const eos = [_]u8{ 0x06, 0, 0, 0, 0, 0, 0, 0 };

fn decodeCursor(payload: []const u8, prefix: []const u8, raw_size: usize, input_chunk: usize, output_chunk: usize, history_limit: usize) ![]u8 {
    var cursor = cursors.Cursor.init(payload.len, raw_size, prefix.len);
    var history = history_mod.Ring.init(history_limit);
    defer history.deinit(allocator);
    try history.reserve(allocator, prefix.len);
    history.recordAssumeCapacity(prefix);
    const scratch = try allocator.alloc(u8, output_chunk);
    defer allocator.free(scratch);
    var actual: std.ArrayList(u8) = .empty;
    errdefer actual.deinit(allocator);
    var offset: usize = 0;
    var calls: usize = 0;
    while (cursor.stage != .done) : (calls += 1) {
        try std.testing.expect(calls < payload.len * 4 + raw_size * 4 + 32);
        const offered = payload[offset..][0..@min(input_chunk, payload.len - offset)];
        const output = if (calls % 4 == 0) scratch[0..0] else scratch;
        try history.reserve(allocator, output.len);
        const before_input = cursor.input_consumed;
        const before_decoded = cursor.decoded_len;
        const step = try cursor.step(offered, history.view(), output);
        try std.testing.expectEqual(cursor.input_consumed - before_input, step.progress.input_read);
        try std.testing.expectEqual(cursor.decoded_len - before_decoded, step.progress.output_written);
        try std.testing.expect(step.progress.input_read <= offered.len);
        try std.testing.expect(step.progress.output_written <= output.len);
        offset += step.progress.input_read;
        try actual.appendSlice(allocator, output[0..step.progress.output_written]);
        history.recordAssumeCapacity(output[0..step.progress.output_written]);
    }
    try std.testing.expectEqual(payload.len, offset);
    try std.testing.expectEqual(payload.len, cursor.input_consumed);
    try std.testing.expectEqual(raw_size, cursor.decoded_len);
    const completed = try cursor.step("next block", history.view(), scratch);
    try std.testing.expectEqual(@as(usize, 0), completed.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), completed.progress.output_written);
    return actual.toOwnedSlice(allocator);
}

fn expectReference(payload: []const u8, prefix: []const u8, history_limit: usize) !void {
    const raw_size = try reference.decodedSizeWithPrefixLimited(payload, prefix.len, 1024 * 1024);
    const expected = try allocator.alloc(u8, prefix.len + raw_size);
    defer allocator.free(expected);
    @memcpy(expected[0..prefix.len], prefix);
    try std.testing.expectEqual(raw_size, try reference.decodeIntoWithPrefix(payload, expected, prefix.len, raw_size));
    for ([_]struct { input: usize, output: usize }{
        .{ .input = 1, .output = 1 },
        .{ .input = 2, .output = 3 },
        .{ .input = 3, .output = 17 },
        .{ .input = payload.len, .output = @max(raw_size, 1) },
    }) |chunks| {
        const actual = try decodeCursor(payload, prefix, raw_size, chunks.input, chunks.output, history_limit);
        defer allocator.free(actual);
        try std.testing.expectEqualSlices(u8, expected[prefix.len..], actual);
    }
}

fn combined(opcode: u8) bool {
    const high = opcode >> 4;
    return switch (high) {
        0...3 => opcode & 7 != 6,
        4...6, 8, 9, 12 => true,
        else => false,
    };
}

fn appendOpcode(payload: *std.ArrayList(u8), opcode: u8) !bool {
    try payload.append(allocator, opcode);
    var literals: usize = 0;
    if (opcode == 0x06) {
        try payload.appendSlice(allocator, &.{ 1, 2, 3, 4, 5, 6, 7 });
        return true;
    } else if (opcode == 0x0e or opcode == 0x16) {
        // NOPs preserve the distance established by the preceding seed match.
    } else if (opcode == 0xe0) {
        try payload.append(allocator, 255);
        literals = 271;
    } else if (opcode >= 0xe1 and opcode <= 0xef) {
        literals = opcode & 15;
    } else if (opcode == 0xf0) {
        try payload.append(allocator, 255);
    } else if (opcode >= 0xf1) {
        // Match-only extensions use the seed's previous distance.
    } else if (opcode >= 0xa0 and opcode <= 0xbf) {
        try payload.appendSlice(allocator, &.{ 7, 4 }); // D=257, low M bits=3.
        literals = (opcode >> 3) & 3;
    } else if (combined(opcode)) {
        literals = opcode >> 6;
        switch (opcode & 7) {
            0...5 => try payload.append(allocator, 123),
            6 => {},
            7 => try payload.appendSlice(allocator, &.{ 0xff, 0xff }),
            else => unreachable,
        }
    } else return false;
    for (0..literals) |index| try payload.append(allocator, @truncate(index * 73 + opcode));
    try payload.appendSlice(allocator, &eos);
    return true;
}

test "LZVN cursor covers every defined opcode and rejects every reserved byte against one shot" {
    const prefix = try allocator.alloc(u8, 65535);
    defer allocator.free(prefix);
    for (prefix, 0..) |*byte, index| byte.* = @truncate(index * 73 + index / 11);
    var defined_count: usize = 0;
    var reserved_count: usize = 0;
    for (0..256) |value| {
        var payload: std.ArrayList(u8) = .empty;
        defer payload.deinit(allocator);
        try payload.appendSlice(allocator, &.{ 0x07, 1, 0 }); // L=0, M=3, D=1.
        const defined = try appendOpcode(&payload, @intCast(value));
        if (defined) {
            defined_count += 1;
            try expectReference(payload.items, prefix, prefix.len);
        } else {
            reserved_count += 1;
            try payload.appendSlice(allocator, &eos);
            try std.testing.expectError(error.InvalidLzvnStream, reference.decodedSizeWithPrefixLimited(payload.items, prefix.len, 1024));
            var cursor = cursors.Cursor.init(payload.items.len, 1024, prefix.len);
            var output: [1024]u8 = undefined;
            try std.testing.expectError(error.InvalidLzvnStream, cursor.step(payload.items, .{ .bytes = prefix }, &output));
            try std.testing.expectEqual(@as(usize, 4), cursor.input_consumed);
            try std.testing.expectEqual(@as(usize, 3), cursor.decoded_len);
        }
    }
    // Pin the classification independently checked against Apple's low-level
    // opcode dispatch, including EOS, both NOPs and every previous-D form.
    try std.testing.expectEqual(@as(usize, 219), defined_count);
    try std.testing.expectEqual(@as(usize, 37), reserved_count);
}

test "LZVN cursor consumes arbitrary EOS continuation bytes with zero output" {
    const bytes = [_]u8{ 0x0e, 0x16, 0x06, 1, 2, 3, 4, 5, 6, 7 };
    var cursor = cursors.Cursor.init(bytes.len, 0, 0);
    for (bytes, 0..) |_, offset| {
        const progress = try cursor.step(bytes[offset..][0..1], .{ .bytes = &.{} }, &.{});
        try std.testing.expectEqual(@as(usize, 1), progress.progress.input_read);
        try std.testing.expectEqual(@as(usize, 0), progress.progress.output_written);
        try std.testing.expectEqual(if (offset + 1 == bytes.len) @as(@import("../../core.zig").StepResult.Status, .done) else .need_input, progress.status);
    }
    try std.testing.expectEqual(cursors.Cursor.Stage.done, cursor.stage);
    try std.testing.expectEqual(bytes.len, cursor.input_consumed);
}

test "LZVN cursor decodes the pinned Apple LZVN reference with literal and repeated matches" {
    const payload = [_]u8{ 0xc8, 3, 'a', 'b', 'c', 0xf0, 0x18, 0xe1, 'c', 0x06, 0, 0, 0, 0, 0, 0, 0 };
    const expected = "abc" ** 16;
    const actual = try decodeCursor(&payload, "", expected.len, 1, 1, 3);
    defer allocator.free(actual);
    try std.testing.expectEqualStrings(expected, actual);
    try expectReference(&payload, "", 3);
}

test "LZVN cursor handles minimum and maximum extended literal and match lengths" {
    for ([_]u8{ 0, 1, 15, 16, 254, 255 }) |extra| {
        var payload: std.ArrayList(u8) = .empty;
        defer payload.deinit(allocator);
        try payload.appendSlice(allocator, &.{ 0xe0, extra });
        for (0..@as(usize, extra) + 16) |index| try payload.append(allocator, @truncate(index * 17));
        try payload.appendSlice(allocator, &.{ 0x07, 1, 0, 0xf0, extra });
        try payload.appendSlice(allocator, &eos);
        try expectReference(payload.items, "", 65535);
    }
}

test "LZVN cursor uses cross block history including distance 65535 and ring wrap" {
    const prefix = try allocator.alloc(u8, 65535);
    defer allocator.free(prefix);
    for (prefix, 0..) |*byte, index| byte.* = @truncate(index * 73 + index / 11);
    const maximum = [_]u8{ 0x07, 0xff, 0xff, 0x06, 0, 0, 0, 0, 0, 0, 0 };
    try expectReference(&maximum, prefix, 65535);
    const overlap = [_]u8{ 0x07, 3, 0, 0xf0, 255, 0x06, 0, 0, 0, 0, 0, 0, 0 };
    try expectReference(&overlap, "ABCDEFG", 5);
}

test "LZVN cursor can copy within one call without allocating history" {
    const payload = [_]u8{ 0xc7, 3, 0, 'a', 'b', 'c', 0xf0, 255, 0x06, 0, 0, 0, 0, 0, 0, 0 };
    var output: [277]u8 = undefined;
    var cursor = cursors.Cursor.init(payload.len, output.len, 0);
    const progress = try cursor.step(&payload, .{ .bytes = &.{} }, &output);
    try std.testing.expectEqual(output.len, progress.progress.output_written);
    try std.testing.expectEqual(payload.len, progress.progress.input_read);
    try std.testing.expectEqual(@as(usize, 277), cursor.decoded_len);
    for (output, 0..) |byte, index| try std.testing.expectEqual("abc"[index % 3], byte);
}

test "LZVN cursor distinguishes semantic reach from insufficient retained history" {
    const payload = [_]u8{ 0x07, 4, 0, 0x06, 0, 0, 0, 0, 0, 0, 0 };
    var output: [3]u8 = @splat(0xa5);
    var invalid = cursors.Cursor.init(payload.len, 3, 3);
    try std.testing.expectError(error.InvalidLzvnStream, invalid.step(&payload, .{ .bytes = "ABCD" }, &output));
    try std.testing.expectEqual(@as(usize, 3), invalid.input_consumed);
    try std.testing.expectEqual(@as(usize, 0), invalid.decoded_len);
    var limited = cursors.Cursor.init(payload.len, 3, 4);
    try std.testing.expectError(error.HistoryLimitExceeded, limited.step(&payload, .{ .bytes = "BCD" }, &output));
    try std.testing.expectEqual(@as(usize, 3), limited.input_consumed);
    try std.testing.expectEqual(@as(usize, 0), limited.decoded_len);
    try std.testing.expectEqual(@as([3]u8, @splat(0xa5)), output);
    var huge_prefix = cursors.Cursor.init(payload.len, 3, std.math.maxInt(usize));
    const valid = try huge_prefix.step(&payload, .{ .bytes = "ABCD" }, &output);
    try std.testing.expectEqualStrings("ABC", &output);
    try std.testing.expectEqual(@as(usize, 3), valid.progress.output_written);
}

test "LZVN cursor preserves accepted input and output prefix when a later opcode fails" {
    const invalid = [_]u8{ 0xe2, 'A', 'B', 0xf1, 0x06, 0, 0, 0, 0, 0, 0, 0 };
    var output: [16]u8 = @splat(0xa5);
    var cursor = cursors.Cursor.init(invalid.len, 10, 0);
    try std.testing.expectError(error.InvalidLzvnStream, cursor.step(&invalid, .{ .bytes = &.{} }, &output));
    try std.testing.expectEqual(@as(usize, 4), cursor.input_consumed);
    try std.testing.expectEqual(@as(usize, 2), cursor.decoded_len);
    try std.testing.expectEqualStrings("AB", output[0..2]);
    try std.testing.expectEqual(@as(u8, 0xa5), output[2]);
    try std.testing.expectError(error.InvalidLzvnStream, cursor.step("unused", .{ .bytes = "AB" }, &output));
    try std.testing.expectEqual(@as(usize, 4), cursor.input_consumed);
    try std.testing.expectEqual(@as(usize, 2), cursor.decoded_len);

    const limited = [_]u8{ 0xe2, 'A', 'B', 0x07, 4, 0, 0x06, 0, 0, 0, 0, 0, 0, 0 };
    cursor = cursors.Cursor.init(limited.len, 5, 2);
    try std.testing.expectError(error.HistoryLimitExceeded, cursor.step(&limited, .{ .bytes = "X" }, &output));
    try std.testing.expectEqual(@as(usize, 6), cursor.input_consumed);
    try std.testing.expectEqual(@as(usize, 2), cursor.decoded_len);
    try std.testing.expectEqualStrings("AB", output[0..2]);
}

test "LZVN cursor validates combined reach and declared raw size before consuming literals" {
    const invalid = [_]u8{ 0xc7, 0, 0, 'A', 'B', 'C', 0x06, 0, 0, 0, 0, 0, 0, 0 };
    var output: [6]u8 = @splat(0xa5);
    var cursor = cursors.Cursor.init(invalid.len, 6, 0);
    try std.testing.expectError(error.InvalidLzvnStream, cursor.step(&invalid, .{ .bytes = &.{} }, &output));
    try std.testing.expectEqual(@as(usize, 3), cursor.input_consumed);
    try std.testing.expectEqual(@as(usize, 0), cursor.decoded_len);
    try std.testing.expectEqual(@as([6]u8, @splat(0xa5)), output);
    const overflow = [_]u8{ 0xc7, 3, 0, 'A', 'B', 'C', 0x06, 0, 0, 0, 0, 0, 0, 0 };
    cursor = cursors.Cursor.init(overflow.len, 5, 0);
    try std.testing.expectError(error.OutputLimitExceeded, cursor.step(&overflow, .{ .bytes = &.{} }, &output));
    try std.testing.expectEqual(@as(usize, 3), cursor.input_consumed);
    try std.testing.expectEqual(@as(usize, 0), cursor.decoded_len);
}

test "LZVN cursor resets previous distance for each block despite available prefix history" {
    for ([_][]const u8{ &.{0xf1}, &.{ 0xf0, 0 }, &.{0x46} }) |header| {
        var payload: std.ArrayList(u8) = .empty;
        defer payload.deinit(allocator);
        try payload.appendSlice(allocator, header);
        try payload.appendSlice(allocator, "A");
        try payload.appendSlice(allocator, &eos);
        var cursor = cursors.Cursor.init(payload.items.len, 64, 4);
        var output: [64]u8 = undefined;
        try std.testing.expectError(error.InvalidLzvnStream, cursor.step(payload.items, .{ .bytes = "ABCD" }, &output));
        try std.testing.expectEqual(header.len, cursor.input_consumed);
        try std.testing.expectEqual(@as(usize, 0), cursor.decoded_len);
    }
}

test "LZVN cursor terminal does not consume the next LZFSE header and detects trailing payload" {
    const stream = eos ++ "bvx-";
    var cursor = cursors.Cursor.init(eos.len, 0, 0);
    const progress = try cursor.step(stream, .{ .bytes = &.{} }, &.{});
    try std.testing.expectEqual(eos.len, progress.progress.input_read);
    try std.testing.expectEqual(@as(usize, 8), cursor.input_consumed);
    const done = try cursor.step(stream[eos.len..], .{ .bytes = &.{} }, &.{});
    try std.testing.expectEqual(@as(usize, 0), done.progress.input_read);
    cursor = cursors.Cursor.init(9, 0, 0);
    try std.testing.expectError(error.TrailingData, cursor.step(stream, .{ .bytes = &.{} }, &.{}));
    try std.testing.expectEqual(@as(usize, 8), cursor.input_consumed);
    try std.testing.expectEqual(@as(usize, 0), cursor.decoded_len);
}

test "LZVN cursor reports truncation declared size mismatch and real partial counters" {
    const payload = [_]u8{ 0xe1, 'z', 0x06, 0, 0, 0, 0, 0, 0, 0 };
    for (0..payload.len) |size| {
        var cursor = cursors.Cursor.init(size, 1, 0);
        var output: [2]u8 = @splat(0xa5);
        try std.testing.expectError(error.TruncatedFrame, cursor.step(payload[0..size], .{ .bytes = &.{} }, &output));
        try std.testing.expectEqual(size, cursor.input_consumed);
        try std.testing.expectEqual(@as(usize, if (size >= 2) 1 else 0), cursor.decoded_len);
    }
    var cursor = cursors.Cursor.init(payload.len, 2, 0);
    var output: [2]u8 = undefined;
    try std.testing.expectError(error.SizeMismatch, cursor.step(&payload, .{ .bytes = &.{} }, &output));
    try std.testing.expectEqual(payload.len, cursor.input_consumed);
    try std.testing.expectEqual(@as(usize, 1), cursor.decoded_len);
    cursor = cursors.Cursor.init(payload.len, 0, 0);
    try std.testing.expectError(error.OutputLimitExceeded, cursor.step(&payload, .{ .bytes = &.{} }, &output));
    try std.testing.expectEqual(@as(usize, 1), cursor.input_consumed);
    try std.testing.expectEqual(@as(usize, 0), cursor.decoded_len);
    cursor = cursors.Cursor.init(2, 271, 0);
    try std.testing.expectError(error.TruncatedFrame, cursor.step(&.{ 0xe0, 255 }, .{ .bytes = &.{} }, &.{}));
    try std.testing.expectEqual(@as(usize, 2), cursor.input_consumed);
}

test "LZVN cursor distinguishes supplied input exhaustion from declared payload EOF" {
    var cursor = cursors.Cursor.init(8, 0, 0);
    const waiting = try cursor.step(eos[0..7], .{ .bytes = &.{} }, &.{});
    try std.testing.expectEqual(@as(usize, 7), waiting.progress.input_read);
    try std.testing.expectEqual(@as(usize, 7), cursor.input_consumed);
    try std.testing.expectEqual(cursors.Cursor.Stage.terminal, cursor.stage);
    try std.testing.expectEqual(@as(usize, 7), cursor.header_received);
    const still_waiting = try cursor.step("", .{ .bytes = &.{} }, &.{});
    try std.testing.expectEqual(@as(usize, 0), still_waiting.progress.input_read);
    const done = try cursor.step(eos[7..], .{ .bytes = &.{} }, &.{});
    try std.testing.expectEqual(@as(usize, 1), done.progress.input_read);
    try std.testing.expectEqual(cursors.Cursor.Stage.done, cursor.stage);
}

test "LZVN cursor zero output advances metadata but leaves literal payload unconsumed" {
    const payload = [_]u8{ 0x0e, 0x16, 0xe2, 'A', 'B', 0x06, 0, 0, 0, 0, 0, 0, 0 };
    var cursor = cursors.Cursor.init(payload.len, 2, 0);
    const blocked = try cursor.step(&payload, .{ .bytes = &.{} }, &.{});
    try std.testing.expectEqual(@as(@import("../../core.zig").StepResult.Status, .need_output), blocked.status);
    try std.testing.expectEqual(@as(usize, 3), blocked.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), blocked.progress.output_written);
    try std.testing.expectEqual(@as(usize, 2), cursor.pending_literals);
    var output: [2]u8 = undefined;
    const done = try cursor.step(payload[3..], .{ .bytes = &.{} }, &output);
    try std.testing.expectEqual(@as(@import("../../core.zig").StepResult.Status, .done), done.status);
    try std.testing.expectEqual(payload.len - 3, done.progress.input_read);
    try std.testing.expectEqualStrings("AB", &output);
}

test "LZVN cursor pending match does not consume EOS while output is blocked" {
    const payload = [_]u8{ 0x07, 1, 0, 0x06, 0, 0, 0, 0, 0, 0, 0 };
    var cursor = cursors.Cursor.init(payload.len, 3, 1);
    const blocked = try cursor.step(&payload, .{ .bytes = "A" }, &.{});
    try std.testing.expectEqual(@as(usize, 3), blocked.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), blocked.progress.output_written);
    try std.testing.expectEqual(@as(@import("../../core.zig").StepResult.Status, .need_output), blocked.status);
    const repeated = try cursor.step(payload[3..], .{ .bytes = "A" }, &.{});
    try std.testing.expectEqual(@as(usize, 0), repeated.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), repeated.progress.output_written);
    try std.testing.expectEqual(@as(usize, 3), cursor.input_consumed);
    var output: [3]u8 = undefined;
    const partial = try cursor.step(payload[3..], .{ .bytes = "A" }, output[0..1]);
    try std.testing.expectEqual(@as(usize, 0), partial.progress.input_read);
    try std.testing.expectEqual(@as(usize, 1), partial.progress.output_written);
    const done = try cursor.step(payload[3..], .{ .bytes = "A" }, output[1..]);
    try std.testing.expectEqual(@as(usize, 8), done.progress.input_read);
    try std.testing.expectEqual(@as(usize, 2), done.progress.output_written);
    try std.testing.expectEqual(@as(@import("../../core.zig").StepResult.Status, .done), done.status);
    try std.testing.expectEqualStrings("AAA", &output);
}

test "LZVN cursor independently matches one shot writer across empty tiny random repetitive and large input" {
    for ([_]usize{ 0, 1, 2, 7, 300, 65536, 100000 }) |size| {
        const input = try allocator.alloc(u8, size);
        defer allocator.free(input);
        for ([_]bool{ false, true }) |random_data| {
            if (random_data) {
                var random = std.Random.DefaultPrng.init(size + 0xabcd);
                random.random().bytes(input);
            } else {
                for (input, 0..) |*byte, index|
                    byte.* = "LZVN incremental payload corpus\n"[index % 32];
            }
            const payload = try reference.encodeAlloc(allocator, input);
            defer allocator.free(payload);
            const actual = try decodeCursor(payload, "", size, 1, 3, 65535);
            defer allocator.free(actual);
            try std.testing.expectEqualSlices(u8, input, actual);
        }
    }
}
