const std = @import("std");
const cursor_mod = @import("fse_cursor.zig");
const history = @import("history.zig");
const format = @import("../format.zig");
const decoder = @import("../decoder.zig");
const encoder = @import("../encoder/block_encoder.zig");
const plan_mod = @import("../encoder/block_plan.zig");
const encode_options = @import("../encode_options.zig");
const allocator = std.testing.allocator;

fn headerForOneSymbol(l: usize, m: usize, d: usize, literals: usize, records: usize, raw: usize) format.CompressedHeader {
    var header = format.CompressedHeader{
        .header_size = 772,
        .raw_size = raw,
        .literal_count = literals,
        .match_count = records,
        .literal_payload_size = 0,
        .lmd_payload_size = 0,
        .literal_bits = 0,
        .literal_states = @splat(0),
        .lmd_bits = 0,
        .l_state = 0,
        .m_state = 0,
        .d_state = 0,
        .l_frequencies = @splat(0),
        .m_frequencies = @splat(0),
        .d_frequencies = @splat(0),
        .literal_frequencies = @splat(0),
    };
    header.l_frequencies[l] = 64;
    header.m_frequencies[m] = 64;
    header.d_frequencies[d] = 256;
    header.literal_frequencies['z'] = 1024;
    return header;
}

fn runCursor(header: format.CompressedHeader, literal_tail: []const u8, lmd_tail: []const u8, prefix: []const u8, chunk: usize, history_limit: usize) ![]u8 {
    // Moving a cursor invalidates any accidental pointers into its old tables.
    var source = try cursor_mod.Cursor.init(header, literal_tail, lmd_tail, prefix.len);
    var cursor = source;
    source = undefined;
    if (header.raw_size != 0) {
        const waiting = try cursor.step(.{ .bytes = "" }, &.{});
        try std.testing.expect(waiting.status == .need_output);
        try std.testing.expectEqual(@as(usize, 0), waiting.progress.output_written);
        try std.testing.expectEqual(@as(usize, 0), cursor.decoded_len);
    }
    var ring = history.Ring.init(history_limit);
    defer ring.deinit(allocator);
    try ring.reserve(allocator, prefix.len);
    ring.recordAssumeCapacity(prefix);
    var actual: std.ArrayList(u8) = .empty;
    errdefer actual.deinit(allocator);
    const output = try allocator.alloc(u8, chunk);
    defer allocator.free(output);
    var done = false;
    while (!done) {
        try ring.reserve(allocator, chunk);
        const before = cursor.decoded_len;
        const result = try cursor.step(ring.view(), output);
        try std.testing.expectEqual(@as(usize, 0), result.progress.input_read);
        try std.testing.expectEqual(result.progress.output_written, cursor.decoded_len - before);
        try std.testing.expect(result.status != .need_input);
        try std.testing.expect(result.progress.output_written != 0 or result.status == .done);
        try actual.appendSlice(allocator, output[0..result.progress.output_written]);
        ring.recordAssumeCapacity(output[0..result.progress.output_written]);
        done = result.status == .done;
    }
    try std.testing.expectEqual(header.raw_size, cursor.decoded_len);
    try std.testing.expectEqual(header.match_count, cursor.records_done);
    try std.testing.expectEqual(header.literal_count, cursor.literal_decoded);
    const terminal = try cursor.step(ring.view(), &.{});
    try std.testing.expectEqual(@as(usize, 0), terminal.progress.output_written);
    try std.testing.expectEqual(@TypeOf(terminal.status).done, terminal.status);
    return actual.toOwnedSlice(allocator);
}

fn expectPayload(header: format.CompressedHeader, literal_payload: []const u8, lmd_payload: []const u8, prefix: []const u8, chunk: usize) !void {
    const expected = try allocator.alloc(u8, prefix.len + header.raw_size);
    defer allocator.free(expected);
    @memcpy(expected[0..prefix.len], prefix);
    _ = try decoder.decodePayloadInto(header, literal_payload, lmd_payload, expected, prefix.len);
    const retained = try cursor_mod.retainedSizes(header);
    var history_limit: usize = 0;
    for (header.d_frequencies, format.d_base_value, format.d_extra_bits) |frequency, base, width| {
        if (frequency != 0) history_limit = @max(history_limit, @as(usize, @intCast(base)) + (@as(usize, 1) << @intCast(width)) - 1);
    }
    const actual = try runCursor(header, literal_payload[literal_payload.len - retained.literal ..], lmd_payload[lmd_payload.len - retained.lmd ..], prefix, chunk, history_limit);
    defer allocator.free(actual);
    try std.testing.expectEqualSlices(u8, expected[prefix.len..], actual);
}

fn expectPlan(plan: *const plan_mod.Plan, prefix: []const u8) !void {
    for ([_]encode_options.FseVersion{ .v1, .v2 }) |version| {
        var block = try encoder.encodePlanAlloc(allocator, plan, version);
        defer block.deinit(allocator);
        const header = try format.parseCompressedHeader(block.bytes);
        const literal_end = header.header_size + header.literal_payload_size;
        for ([_]usize{ 1, 3, 17, 257 }) |chunk|
            try expectPayload(header, block.bytes[header.header_size..literal_end], block.bytes[literal_end..], prefix, chunk);
    }
}

test "LZFSE FSE cursor decodes four literal lanes across every small output size" {
    for (1..9) |size| {
        var plan = plan_mod.Plan.init(0);
        defer plan.deinit(allocator);
        try plan.appendLiterals(allocator, "abcdefgh"[0..size]);
        try expectPlan(&plan, "");
    }
    var plan = plan_mod.Plan.init(0);
    defer plan.deinit(allocator);
    try plan.append(allocator, "abcd", 9000, 4);
    try expectPlan(&plan, "");
}

test "LZFSE FSE cursor covers prototype maximum match literal entropy and empty literal payload" {
    var zeros = plan_mod.Plan.init(0);
    defer zeros.deinit(allocator);
    try zeros.append(allocator, &.{0}, 99999, 1);
    try expectPlan(&zeros, "");
    var entropy = plan_mod.Plan.init(0);
    defer entropy.deinit(allocator);
    try entropy.appendLiterals(allocator, "abcdefghijklmnopqrst" ** 500);
    try expectPlan(&entropy, "");
    var no_literals = plan_mod.Plan.init(1);
    defer no_literals.deinit(allocator);
    try no_literals.append(allocator, "", 7077, 1);
    try expectPlan(&no_literals, "q");
}

test "LZFSE FSE cursor covers every value width and cross-block maximum distance" {
    const prefix = try allocator.alloc(u8, 262400);
    defer allocator.free(prefix);
    for (prefix, 0..) |*byte, index| byte.* = @truncate(index);
    var plan = plan_mod.Plan.init(prefix.len);
    defer plan.deinit(allocator);
    var literals: [315]u8 = undefined;
    for (0..64) |index| {
        const symbol = index % 20;
        var l: usize = @as(usize, @intCast(format.l_base_value[symbol])) + (@as(usize, 1) << @intCast(format.l_extra_bits[symbol])) - 1;
        const m: usize = @as(usize, @intCast(format.m_base_value[symbol])) + (@as(usize, 1) << @intCast(format.m_extra_bits[symbol])) - 1;
        const d: u32 = if (m == 0 or index < 2) 1 else @as(u32, @intCast(format.d_base_value[index])) + (@as(u32, 1) << @intCast(format.d_extra_bits[index])) - 1;
        if (l == 0 and m == 0) l = 1;
        for (literals[0..l], 0..) |*byte, offset| byte.* = @truncate(offset * 73 + index);
        try plan.append(allocator, literals[0..l], m, d);
    }
    try expectPlan(&plan, prefix);
}

fn decodeHex(text: []const u8) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    var high: ?u8 = null;
    for (text) |byte| {
        if (std.ascii.isWhitespace(byte)) continue;
        const digit = try std.fmt.charToDigit(byte, 16);
        if (high) |value| {
            try output.append(allocator, value * 16 + digit);
            high = null;
        } else high = digit;
    }
    if (high != null) return error.InvalidCharacter;
    return output.toOwnedSlice(allocator);
}

test "LZFSE FSE cursor decodes pinned Apple V1 and V2 streams without full literal staging" {
    for ([_][]const u8{
        @embedFile("../testdata/apple-zero-100k-v1.lzfse.hex"),
        @embedFile("../testdata/apple-zero-100k-v2.lzfse.hex"),
    }) |text| {
        const bytes = try decodeHex(text);
        defer allocator.free(bytes);
        const header = try format.parseCompressedHeader(bytes);
        const literal_end = header.header_size + header.literal_payload_size;
        try expectPayload(header, bytes[header.header_size..literal_end], bytes[literal_end .. literal_end + header.lmd_payload_size], "", 19);
    }
    try std.testing.expect(@sizeOf(cursor_mod.Cursor) < 40000);
}

test "LZFSE FSE cursor retention bound uses frequencies extras and ignores unused alphabets" {
    var header = headerForOneSymbol(0, 0, 1, 40000, 10000, 0);
    header.literal_payload_size = 10000000;
    header.lmd_payload_size = 10000000;
    header.literal_bits = -7;
    header.lmd_bits = -7;
    try std.testing.expectEqualDeep(cursor_mod.Retained{ .literal = 1, .lmd = 1 }, try cursor_mod.retainedSizes(header));
    header.literal_frequencies = @splat(0);
    header.literal_frequencies[0] = 1;
    header.literal_frequencies[1] = 1023;
    header.l_frequencies = @splat(0);
    header.l_frequencies[0] = 63;
    header.l_frequencies[19] = 1;
    header.m_frequencies = header.l_frequencies;
    header.d_frequencies = @splat(0);
    header.d_frequencies[0] = 255;
    header.d_frequencies[63] = 1;
    const retained = try cursor_mod.retainedSizes(header);
    try std.testing.expectEqual(@as(usize, 50001), retained.literal);
    try std.testing.expectEqual(@as(usize, 67501), retained.lmd);
    header.literal_payload_size = 2;
    header.lmd_payload_size = 3;
    try std.testing.expectEqualDeep(cursor_mod.Retained{ .literal = 2, .lmd = 3 }, try cursor_mod.retainedSizes(header));
    header.literal_count = 0;
    header.match_count = 0;
    header.literal_bits = -128;
    header.lmd_bits = 127;
    header.literal_frequencies = @splat(0);
    header.l_frequencies = @splat(0);
    try std.testing.expectEqualDeep(cursor_mod.Retained{ .literal = 0, .lmd = 0 }, try cursor_mod.retainedSizes(header));
    var cursor = try cursor_mod.Cursor.init(header, &.{}, &.{}, 0);
    const done = try cursor.step(.{ .bytes = "" }, &.{});
    try std.testing.expect(done.status == .done);
}

test "LZFSE FSE cursor accepts zero-progress records nonzero final states and nonzero unused padding" {
    var empty = headerForOneSymbol(0, 0, 1, 0, 10000, 0);
    empty.l_state = 31;
    empty.m_state = 45;
    empty.d_state = 201;
    empty.lmd_payload_size = 1000000000;
    var cursor = try cursor_mod.Cursor.init(empty, &.{}, &.{}, 0);
    const done = try cursor.step(.{ .bytes = "" }, &.{});
    try std.testing.expectEqual(@TypeOf(done.status).done, done.status);
    try std.testing.expectEqual(@as(usize, 10000), cursor.records_done);
    var header = headerForOneSymbol(1, 0, 1, 4, 1, 1);
    header.literal_states = .{ 1, 31, 512, 1023 };
    header.l_state = 63;
    header.m_state = 45;
    header.d_state = 201;
    header.literal_payload_size = 2;
    header.lmd_payload_size = 3;
    try expectPayload(header, &.{ 0xff, 0xe7 }, &.{ 0xa4, 0xbc, 0xfa }, "", 1);
}

test "LZFSE FSE cursor discards enlarged payload prefixes while retained tails stay bounded" {
    var plan = plan_mod.Plan.init(0);
    defer plan.deinit(allocator);
    try plan.append(allocator, "abcd", 12000, 4);
    var block = try encoder.encodePlanAlloc(allocator, &plan, .v2);
    defer block.deinit(allocator);
    const original = try format.parseCompressedHeader(block.bytes);
    var inflated = original;
    inflated.literal_payload_size = 1000000000;
    inflated.lmd_payload_size = 1000000000;
    const retained = try cursor_mod.retainedSizes(inflated);
    try std.testing.expect(retained.literal + retained.lmd <= 117502);
    const literal = try allocator.alloc(u8, retained.literal);
    defer allocator.free(literal);
    const lmd = try allocator.alloc(u8, retained.lmd);
    defer allocator.free(lmd);
    @memset(literal, 0xe7);
    @memset(lmd, 0xba);
    const literal_end = original.header_size + original.literal_payload_size;
    const old_literal = block.bytes[original.header_size..literal_end];
    const old_lmd = block.bytes[literal_end..];
    const literal_copy = @min(literal.len, old_literal.len);
    const lmd_copy = @min(lmd.len, old_lmd.len);
    @memcpy(literal[literal.len - literal_copy ..], old_literal[old_literal.len - literal_copy ..]);
    @memcpy(lmd[lmd.len - lmd_copy ..], old_lmd[old_lmd.len - lmd_copy ..]);
    const actual = try runCursor(inflated, literal, lmd, "", 7, 4);
    defer allocator.free(actual);
    for (actual, 0..) |byte, index| try std.testing.expectEqual("abcd"[index % 4], byte);
}

test "LZFSE FSE cursor distinguishes invalid global reach from insufficient caller history" {
    var header = headerForOneSymbol(0, 6, 3, 0, 1, 6);
    var cursor = try cursor_mod.Cursor.init(header, &.{}, &.{}, 2);
    var output: [8]u8 = undefined;
    try std.testing.expectError(error.InvalidLzfseStream, cursor.step(.{ .bytes = "xy" }, &output));
    try std.testing.expectEqual(@as(usize, 0), cursor.decoded_len);
    cursor = try cursor_mod.Cursor.init(header, &.{}, &.{}, 3);
    try std.testing.expectError(error.HistoryLimitExceeded, cursor.step(.{ .bytes = "xy" }, &output));
    try std.testing.expectEqual(@as(usize, 0), cursor.decoded_len);
    const result = try cursor.step(.{ .bytes = "abc" }, &output);
    try std.testing.expectEqual(@TypeOf(result.status).done, result.status);
    try std.testing.expectEqualStrings("abcabc", output[0..6]);
    header.d_frequencies = @splat(0);
    header.d_frequencies[0] = 256;
    cursor = try cursor_mod.Cursor.init(header, &.{}, &.{}, 3);
    try std.testing.expectError(error.InvalidLzfseStream, cursor.step(.{ .bytes = "abc" }, &output));
}

test "LZFSE FSE cursor validates unused literal padding and preserves error output accounting" {
    var plan = plan_mod.Plan.init(0);
    defer plan.deinit(allocator);
    try plan.appendLiterals(allocator, "abc");
    var block = try encoder.encodePlanAlloc(allocator, &plan, .v2);
    defer block.deinit(allocator);
    var header = try format.parseCompressedHeader(block.bytes);
    const literal_end = header.header_size + header.literal_payload_size;
    header.literal_bits = -2;
    const retained = try cursor_mod.retainedSizes(header);
    var cursor = try cursor_mod.Cursor.init(header, block.bytes[literal_end - retained.literal .. literal_end], block.bytes[block.bytes.len - retained.lmd ..], 0);
    var output: [8]u8 = @splat(0xcc);
    try std.testing.expectError(error.InvalidLzfseStream, cursor.step(.{ .bytes = "" }, &output));
    try std.testing.expectEqual(@as(usize, 3), cursor.decoded_len);
    try std.testing.expectEqualStrings("abc", output[0..3]);
    var full_literal = headerForOneSymbol(1, 0, 1, 4, 1, 2);
    cursor = try cursor_mod.Cursor.init(full_literal, &.{}, &.{}, 0);
    try std.testing.expectError(error.SizeMismatch, cursor.step(.{ .bytes = "" }, &output));
    try std.testing.expectEqual(@as(usize, 1), cursor.decoded_len);
    full_literal.literal_count = 8;
    full_literal.raw_size = 1;
    cursor = try cursor_mod.Cursor.init(full_literal, &.{}, &.{}, 0);
    try std.testing.expectError(error.SizeMismatch, cursor.step(.{ .bytes = "" }, &output));
    try std.testing.expectEqual(@as(usize, 8), cursor.literal_decoded);
}

test "LZFSE FSE cursor rejects invalid tails frequencies states and count bounds" {
    var header = headerForOneSymbol(1, 0, 1, 4, 1, 1);
    try std.testing.expectError(error.InvalidLzfseStream, cursor_mod.Cursor.init(header, &.{0}, &.{}, 0));
    header.literal_bits = -1;
    try std.testing.expectError(error.InvalidLzfseStream, cursor_mod.Cursor.init(header, &.{}, &.{}, 0));
    header.literal_bits = 0;
    header.literal_states[2] = 1024;
    try std.testing.expectError(error.InvalidLzfseStream, cursor_mod.Cursor.init(header, &.{}, &.{}, 0));
    header.literal_states[2] = 0;
    header.l_frequencies[1] -= 1;
    try std.testing.expectError(error.InvalidLzfseStream, cursor_mod.retainedSizes(header));
    header.l_frequencies[1] += 1;
    header.match_count = 10001;
    try std.testing.expectError(error.InvalidLzfseStream, cursor_mod.retainedSizes(header));
    header.match_count = 1;
    header.literal_count = 40004;
    try std.testing.expectError(error.InvalidLzfseStream, cursor_mod.retainedSizes(header));
    header.literal_count = 3;
    try std.testing.expectError(error.InvalidLzfseStream, cursor_mod.retainedSizes(header));
    header.literal_count = 4;
    try std.testing.expectError(error.IntegerOverflow, cursor_mod.Cursor.init(header, &.{}, &.{}, std.math.maxInt(usize)));
}
