const std = @import("std");
const item_encoder = @import("item_encoder.zig");
const item_stream = @import("item_stream.zig");
const literal_encoder = @import("literal_encoder.zig");
const decoder = @import("decoder.zig");
const arithmetic = @import("arithmetic.zig");
const bit_stream = @import("bit_stream.zig");
const model = @import("model.zig");
const tables = @import("tables.zig");

const Item = item_encoder.Item;
const allocator = std.testing.allocator;

fn appendItem(plan: *std.ArrayList(Item), expected: *std.ArrayList(u8), item: Item) !void {
    try plan.append(allocator, item);
    try appendExpected(expected, item);
}

fn appendExpected(expected: *std.ArrayList(u8), item: Item) !void {
    switch (item) {
        .literal => |byte| try expected.append(allocator, byte),
        .match => |match| for (0..match.length) |_| {
            const byte = expected.items[expected.items.len - match.offset];
            try expected.append(allocator, byte);
        },
    }
}

fn expectFrameDecode(frame: item_encoder.Frame, expected: []const u8, window_bits: u5) !void {
    const actual = try decoder.decodeAlloc(allocator, frame.bytes, expected.len, window_bits);
    defer allocator.free(actual);
    try std.testing.expectEqual(expected.len, frame.input_len);
    try std.testing.expectEqualSlices(u8, expected, actual);
}

fn decoderModels(value: decoder.Decoder) model.State {
    return .{
        value.literal_models[0], value.literal_models[1], value.literal_models[2], value.literal_models[3],
        value.match3_model,      value.match4_model,      value.match_model,       value.length_model,
        value.selector_model,
    };
}

fn appendFullFrame(plan: *std.ArrayList(Item), expected: *std.ArrayList(u8)) !void {
    const start = expected.items.len;
    for ("Quantum!") |byte| try appendItem(plan, expected, .{ .literal = byte });
    while (expected.items.len - start + 259 <= tables.frame_size)
        try appendItem(plan, expected, .{ .match = .{ .length = 259, .offset = 8 } });
    const remaining = tables.frame_size - (expected.items.len - start);
    try std.testing.expect(remaining >= 3);
    try appendItem(plan, expected, .{ .match = .{ .length = @intCast(remaining), .offset = 8 } });
}

test "Quantum item literals preserve reference bytes across tiny and full frames" {
    const input = try allocator.alloc(u8, tables.frame_size);
    defer allocator.free(input);
    const plan = try allocator.alloc(Item, input.len);
    defer allocator.free(plan);
    for (input, plan, 0..) |*byte, *item, index| {
        byte.* = @truncate(index *% 73 +% index / 11);
        item.* = .{ .literal = byte.* };
    }

    for ([_]u5{ 10, 15, 21 }) |window_bits| {
        for ([_]usize{ 1, 2, 17, 256, tables.frame_size }) |size| {
            var reference = literal_encoder.LiteralEncoder.init();
            const reference_bytes = try reference.encodeFrameAlloc(allocator, input[0..size]);
            defer allocator.free(reference_bytes);
            var encoder = try item_encoder.Encoder.init(window_bits);
            const actual = try encoder.encodeFrameAlloc(allocator, plan[0..size]);
            defer allocator.free(actual.bytes);
            try std.testing.expectEqualSlices(u8, reference_bytes, actual.bytes);
            try std.testing.expectEqual(size, actual.summary.literals);
            try std.testing.expectEqual(@as(usize, 0), actual.summary.matched_bytes);
            try std.testing.expectEqual(@as(usize, 0), actual.summary.extra_bits);
            try std.testing.expectEqual(size, encoder.input_read);
            try std.testing.expectEqualDeep(reference.literal_models, actual.models[0..4].*);
            try std.testing.expectEqualDeep(reference.selector_model, actual.models[model.selector_index]);
        }
    }
}

test "Quantum item encoder handles selectors 4 5 6 with nonzero position and length extras" {
    var plan: std.ArrayList(Item) = .empty;
    defer plan.deinit(allocator);
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);
    for ("abcdefgh") |byte| try appendItem(&plan, &expected, .{ .literal = byte });
    try appendItem(&plan, &expected, .{ .match = .{ .length = 3, .offset = 6 } });
    try appendItem(&plan, &expected, .{ .match = .{ .length = 4, .offset = 8 } });
    try appendItem(&plan, &expected, .{ .match = .{ .length = 18, .offset = 12 } });
    const frame = try item_encoder.encode(allocator, plan.items, 0, 18, model.initialState(18));
    defer allocator.free(frame.bytes);
    try expectFrameDecode(frame, expected.items, 18);
    try std.testing.expectEqual(@as(usize, 8), frame.summary.literals);
    try std.testing.expectEqual(@as(usize, 1), frame.summary.fixed3_matches);
    try std.testing.expectEqual(@as(usize, 1), frame.summary.fixed4_matches);
    try std.testing.expectEqual(@as(usize, 1), frame.summary.variable_matches);
    try std.testing.expectEqual(@as(usize, 25), frame.summary.matched_bytes);
    try std.testing.expectEqual(@as(usize, 12), frame.summary.max_offset);
    try std.testing.expectEqual(@as(usize, 5), frame.summary.extra_bits);
}

test "Quantum item encoder round trips every match length from 3 through 259" {
    for (3..260) |length| {
        const plan = [_]Item{
            .{ .literal = 'z' },
            .{ .match = .{ .length = @intCast(length), .offset = 1 } },
        };
        const frame = try item_encoder.encode(allocator, &plan, 0, 10, model.initialState(10));
        defer allocator.free(frame.bytes);
        var expected: [260]u8 = @splat('z');
        try expectFrameDecode(frame, expected[0 .. length + 1], 10);
        const expected_extra: usize = if (length < 5) 0 else tables.length_extra[try tables.lengthSlot(@intCast(length))];
        try std.testing.expectEqual(expected_extra, frame.summary.extra_bits);
        try std.testing.expectEqual(length, frame.summary.matched_bytes);
    }
}

test "Quantum item encoder covers every offset slot endpoint for windows 10 through 21" {
    for (10..22) |raw_window_bits| {
        const window_bits: u5 = @intCast(raw_window_bits);
        const history_len = @max(tables.frame_size, @as(usize, 1) << window_bits);
        var plan: std.ArrayList(Item) = .empty;
        defer plan.deinit(allocator);
        var expected: std.ArrayList(u8) = .empty;
        defer expected.deinit(allocator);
        try expected.resize(allocator, history_len);
        for (expected.items, 0..) |*byte, index| byte.* = @truncate(index *% 73 +% index / 11);
        var expected_extra: usize = 0;
        for ([_]u16{ 3, 4, 18 }) |length| {
            const entries = item_stream.positionEntries(window_bits, length);
            for (tables.position_base[0..entries], tables.position_extra[0..entries]) |base, bits| {
                const first: u32 = @intCast(base + 1);
                const last: u32 = @intCast(base + (@as(usize, 1) << bits));
                try appendItem(&plan, &expected, .{ .match = .{ .length = length, .offset = first } });
                expected_extra += bits + @as(usize, if (length == 18) 1 else 0);
                if (first != last) {
                    try appendItem(&plan, &expected, .{ .match = .{ .length = length, .offset = last } });
                    expected_extra += bits + @as(usize, if (length == 18) 1 else 0);
                }
            }
        }
        const frame = try item_encoder.encode(allocator, plan.items, history_len, window_bits, model.initialState(window_bits));
        defer allocator.free(frame.bytes);
        try std.testing.expectEqual(expected_extra, frame.summary.extra_bits);
        try std.testing.expectEqual(@as(usize, 1) << window_bits, frame.summary.max_offset);
        const actual = try allocator.alloc(u8, expected.items.len);
        defer allocator.free(actual);
        @memcpy(actual[0..history_len], expected.items[0..history_len]);
        var verifier = decoder.Decoder.init(frame.bytes, actual, window_bits);
        verifier.written = history_len;
        try verifier.arithmetic.startFrame();
        while (verifier.written < actual.len) try verifier.decodeItem(actual.len);
        try std.testing.expectEqualSlices(u8, expected.items, actual);
        try std.testing.expectEqualDeep(frame.models, decoderModels(verifier));
    }
}

test "Quantum item encoder retains models and history across complete and final frames" {
    var first_plan: std.ArrayList(Item) = .empty;
    defer first_plan.deinit(allocator);
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);
    try appendFullFrame(&first_plan, &expected);
    var encoder = try item_encoder.Encoder.init(15);
    const first = try encoder.encodeFrameAlloc(allocator, first_plan.items);
    defer allocator.free(first.bytes);
    try std.testing.expectEqual(tables.frame_size, first.input_len);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0 }, first.bytes[first.bytes.len - 4 ..]);

    var final_plan: std.ArrayList(Item) = .empty;
    defer final_plan.deinit(allocator);
    try appendItem(&final_plan, &expected, .{ .match = .{ .length = 259, .offset = tables.frame_size } });
    try appendItem(&final_plan, &expected, .{ .match = .{ .length = 3, .offset = 4096 } });
    try appendItem(&final_plan, &expected, .{ .match = .{ .length = 4, .offset = 32768 } });
    try appendItem(&final_plan, &expected, .{ .literal = '?' });
    const second = try encoder.encodeFrameAlloc(allocator, final_plan.items);
    defer allocator.free(second.bytes);
    const direct_second = try item_encoder.encode(allocator, final_plan.items, tables.frame_size, 15, first.models);
    defer allocator.free(direct_second.bytes);
    try std.testing.expectEqualSlices(u8, direct_second.bytes, second.bytes);
    try std.testing.expectEqualDeep(direct_second.models, second.models);
    try std.testing.expectEqual(expected.items.len, encoder.input_read);

    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(allocator);
    try wire.appendSlice(allocator, first.bytes);
    try wire.append(allocator, 0xff);
    try wire.appendSlice(allocator, second.bytes);
    const actual = try allocator.alloc(u8, expected.items.len);
    defer allocator.free(actual);
    var verifier = decoder.Decoder.init(wire.items, actual, 15);
    try verifier.decode();
    try std.testing.expectEqualSlices(u8, expected.items, actual);
    try std.testing.expectEqualDeep(second.models, decoderModels(verifier));
}

test "Quantum item full frame literal reference preserves adaptive state for the next frame" {
    const input = try allocator.alloc(u8, tables.frame_size + 257);
    defer allocator.free(input);
    const plan = try allocator.alloc(Item, input.len);
    defer allocator.free(plan);
    for (input, plan, 0..) |*byte, *item, index| {
        byte.* = @truncate(index *% 73 +% index / 11);
        item.* = .{ .literal = byte.* };
    }
    var encoder = try item_encoder.Encoder.init(21);
    var reference = literal_encoder.LiteralEncoder.init();
    for ([_]struct { start: usize, end: usize }{
        .{ .start = 0, .end = tables.frame_size },
        .{ .start = tables.frame_size, .end = input.len },
    }) |range| {
        const frame = try encoder.encodeFrameAlloc(allocator, plan[range.start..range.end]);
        defer allocator.free(frame.bytes);
        const reference_bytes = try reference.encodeFrameAlloc(allocator, input[range.start..range.end]);
        defer allocator.free(reference_bytes);
        try std.testing.expectEqualSlices(u8, reference_bytes, frame.bytes);
        try std.testing.expectEqualDeep(reference.literal_models, frame.models[0..4].*);
        try std.testing.expectEqualDeep(reference.selector_model, frame.models[model.selector_index]);
    }
}

fn repeatedExtraCursor(plan: []const Item) !bool {
    var writer = bit_stream.Writer{};
    defer writer.bytes.deinit(allocator);
    var state = model.initialState(10);
    var encoder = arithmetic.Encoder{ .writer = &writer };
    encoder.startFrame();
    var iterator = item_stream.Iterator{ .items = plan, .window_bits = 10 };
    while (try iterator.next()) |token| try encoder.encodeSymbol(allocator, &state[token.alphabet], token.symbol);
    try encoder.finishFrame(allocator);
    try writer.alignToByte(allocator);
    try writer.bytes.appendNTimes(allocator, 0, 4);
    state = model.initialState(10);
    var verifier = arithmetic.Decoder{ .reader = .{ .input = writer.bytes.items } };
    try verifier.startFrame();
    iterator = .{ .items = plan, .window_bits = 10 };
    var last_extra_cursor: ?usize = null;
    while (try iterator.next()) |token| {
        try std.testing.expectEqual(token.symbol, try verifier.decodeSymbol(&state[token.alphabet]));
        if (token.bits != 0) {
            const cursor = verifier.reader.byte_offset * 8 + verifier.reader.bit_offset;
            if (last_extra_cursor == cursor) return true;
            last_extra_cursor = cursor;
        }
    }
    return false;
}

test "Quantum item extra fields retain order when arithmetic decisions share one bit cursor" {
    var plan: std.ArrayList(Item) = .empty;
    defer plan.deinit(allocator);
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);
    for ("abcdefgh") |byte| try appendItem(&plan, &expected, .{ .literal = byte });
    for (0..100) |_| try appendItem(&plan, &expected, .{ .match = .{ .length = 257, .offset = 8 } });
    try std.testing.expect(try repeatedExtraCursor(plan.items));
    const frame = try item_encoder.encode(allocator, plan.items, 0, 10, model.initialState(10));
    defer allocator.free(frame.bytes);
    try expectFrameDecode(frame, expected.items, 10);
    try std.testing.expectEqual(@as(usize, 600), frame.summary.extra_bits);
}

test "Quantum item encoder rejects invalid lengths offsets and history without changing state" {
    for ([_]Item{
        .{ .match = .{ .length = 0, .offset = 1 } },
        .{ .match = .{ .length = 2, .offset = 1 } },
        .{ .match = .{ .length = 260, .offset = 1 } },
        .{ .match = .{ .length = 65535, .offset = 1 } },
        .{ .match = .{ .length = 3, .offset = 0 } },
        .{ .match = .{ .length = 3, .offset = 2 } },
        .{ .match = .{ .length = 5, .offset = 1025 } },
        .{ .match = .{ .length = 5, .offset = std.math.maxInt(u32) } },
    }) |invalid| {
        var encoder = try item_encoder.Encoder.init(10);
        const before = encoder;
        const plan = [_]Item{ .{ .literal = 'a' }, invalid };
        try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeFrameAlloc(allocator, &plan));
        try std.testing.expectEqualDeep(before, encoder);
    }
    var encoder = try item_encoder.Encoder.init(10);
    const before = encoder;
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeFrameAlloc(allocator, &.{}));
    try std.testing.expectEqualDeep(before, encoder);
    try std.testing.expectError(error.InvalidBlockPlan, item_encoder.Encoder.init(9));
    try std.testing.expectError(error.InvalidBlockPlan, item_encoder.Encoder.init(22));
    const literal = [_]Item{.{ .literal = 'a' }};
    try std.testing.expectError(error.InvalidBlockPlan, item_encoder.encode(allocator, &literal, 1, 10, model.initialState(10)));
    try std.testing.expectError(error.InvalidBlockPlan, item_encoder.encode(allocator, &literal, 0, 9, model.initialState(10)));
    try std.testing.expectError(error.InvalidBlockPlan, item_encoder.encode(allocator, &literal, 0, 22, model.initialState(21)));
}

test "Quantum item fixed selectors reject offsets beyond their smaller alphabets" {
    for ([_]Item{
        .{ .match = .{ .length = 3, .offset = 4097 } },
        .{ .match = .{ .length = 4, .offset = 262145 } },
    }) |invalid| {
        var encoder = try item_encoder.Encoder.init(21);
        encoder.input_read = @as(usize, 1) << 21;
        const before = encoder;
        try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeFrameAlloc(allocator, &.{invalid}));
        try std.testing.expectEqualDeep(before, encoder);
    }
    var encoder = try item_encoder.Encoder.init(21);
    encoder.input_read = tables.frame_size;
    const before = encoder;
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeFrameAlloc(allocator, &.{
        .{ .match = .{ .length = 5, .offset = tables.frame_size + 1 } },
    }));
    try std.testing.expectEqualDeep(before, encoder);
}

test "Quantum item frame limits and a final short frame leave failures recoverable" {
    var plan: std.ArrayList(Item) = .empty;
    defer plan.deinit(allocator);
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);
    try appendFullFrame(&plan, &expected);
    try plan.append(allocator, .{ .literal = 'x' });
    var encoder = try item_encoder.Encoder.init(15);
    const before = encoder;
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeFrameAlloc(allocator, plan.items));
    try std.testing.expectEqualDeep(before, encoder);
    plan.items[plan.items.len - 2] = .{ .match = .{ .length = 127, .offset = 8 } };
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeFrameAlloc(allocator, plan.items[0 .. plan.items.len - 1]));
    try std.testing.expectEqualDeep(before, encoder);
    const final = try encoder.encodeFrameAlloc(allocator, &.{.{ .literal = 'x' }});
    defer allocator.free(final.bytes);
    const after_final = encoder;
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeFrameAlloc(allocator, &.{.{ .literal = 'y' }}));
    try std.testing.expectEqualDeep(after_final, encoder);
}

test "Quantum item encoder detects cumulative input overflow without committing models" {
    var plan: std.ArrayList(Item) = .empty;
    defer plan.deinit(allocator);
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);
    try appendFullFrame(&plan, &expected);
    var encoder = try item_encoder.Encoder.init(15);
    encoder.input_read = std.math.maxInt(usize) - std.math.maxInt(usize) % tables.frame_size;
    const before = encoder;
    try std.testing.expectError(error.IntegerOverflow, encoder.encodeFrameAlloc(allocator, plan.items));
    try std.testing.expectEqualDeep(before, encoder);
}

test "Quantum item streams report exact errors for truncation invalid reach and output length" {
    const plan = [_]Item{ .{ .literal = 'a' }, .{ .match = .{ .length = 3, .offset = 1 } } };
    const frame = try item_encoder.encode(allocator, &plan, 0, 10, model.initialState(10));
    defer allocator.free(frame.bytes);
    try std.testing.expectError(error.TruncatedFrame, decoder.decodeAlloc(allocator, frame.bytes[0..0], 4, 10));
    try std.testing.expectError(error.TruncatedFrame, decoder.decodeAlloc(allocator, frame.bytes[0..1], 4, 10));
    try std.testing.expectError(error.InvalidQuantumStream, decoder.decodeAlloc(allocator, frame.bytes, 3, 10));
    const invalid_reach = try item_encoder.encode(allocator, &.{.{ .match = .{ .length = 3, .offset = 1 } }}, tables.frame_size, 10, model.initialState(10));
    defer allocator.free(invalid_reach.bytes);
    try std.testing.expectError(error.InvalidMatch, decoder.decodeAlloc(allocator, invalid_reach.bytes, 3, 10));
}

test "Quantum item full frame payload requires a sentinel and rejects damaged trailers" {
    var plan: std.ArrayList(Item) = .empty;
    defer plan.deinit(allocator);
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);
    try appendFullFrame(&plan, &expected);
    const frame = try item_encoder.encode(allocator, plan.items, 0, 15, model.initialState(15));
    defer allocator.free(frame.bytes);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0 }, frame.bytes[frame.bytes.len - 4 ..]);
    try std.testing.expectError(error.TruncatedFrame, decoder.decodeAlloc(allocator, frame.bytes, tables.frame_size, 15));
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(allocator);
    try wire.appendSlice(allocator, frame.bytes);
    try wire.append(allocator, 0xff);
    const actual = try decoder.decodeAlloc(allocator, wire.items, tables.frame_size, 15);
    defer allocator.free(actual);
    try std.testing.expectEqualSlices(u8, expected.items, actual);
    wire.items[wire.items.len - 1] = 0xfe;
    try std.testing.expectError(error.InvalidQuantumStream, decoder.decodeAlloc(allocator, wire.items, tables.frame_size, 15));
    wire.items[wire.items.len - 1] = 0;
    try wire.append(allocator, 0xff);
    try std.testing.expectError(error.InvalidQuantumStream, decoder.decodeAlloc(allocator, wire.items, tables.frame_size, 15));
}

test "Quantum item allocation failures preserve initial and adapted models with extras and full frames" {
    try std.testing.checkAllAllocationFailures(allocator, allocationFailure, .{AllocationCase.literal});
    try std.testing.checkAllAllocationFailures(allocator, allocationFailure, .{AllocationCase.matches});
    try std.testing.checkAllAllocationFailures(allocator, allocationFailure, .{AllocationCase.full_frame});
}

const AllocationCase = enum { literal, matches, full_frame };

fn allocationFailure(failing_allocator: std.mem.Allocator, case: AllocationCase) !void {
    var encoder = try item_encoder.Encoder.init(15);
    // Establish adapted models with the normal allocator so every injected
    // failure belongs to the frame under test, including its final ownership.
    var warm_plan: std.ArrayList(Item) = .empty;
    defer warm_plan.deinit(allocator);
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);
    var warm: ?item_encoder.Frame = null;
    defer if (warm) |frame| allocator.free(frame.bytes);
    if (case != .literal) {
        try appendFullFrame(&warm_plan, &expected);
        warm = try encoder.encodeFrameAlloc(allocator, warm_plan.items);
    }
    const before = encoder;
    var literal_plan: [1024]Item = undefined;
    for (&literal_plan, 0..) |*item, index| item.* = .{ .literal = @truncate(index *% 73 +% index / 11) };
    const short_plan = [_]Item{
        .{ .match = .{ .length = 257, .offset = 32768 } },
        .{ .match = .{ .length = 3, .offset = 4096 } },
        .{ .match = .{ .length = 4, .offset = 32768 } },
        .{ .literal = '!' },
    };
    const plan: []const Item = switch (case) {
        .literal => &literal_plan,
        .matches => &short_plan,
        .full_frame => warm_plan.items,
    };
    const frame = encoder.encodeFrameAlloc(failing_allocator, plan) catch |err| {
        try std.testing.expectEqualDeep(before, encoder);
        const recovered = try encoder.encodeFrameAlloc(allocator, plan);
        defer allocator.free(recovered.bytes);
        for (plan) |item| try appendExpected(&expected, item);
        var wire: std.ArrayList(u8) = .empty;
        defer wire.deinit(allocator);
        if (warm) |previous| {
            try wire.appendSlice(allocator, previous.bytes);
            try wire.append(allocator, 0xff);
        }
        try wire.appendSlice(allocator, recovered.bytes);
        if (case == .full_frame) try wire.append(allocator, 0xff);
        const actual = try decoder.decodeAlloc(allocator, wire.items, expected.items.len, 15);
        defer allocator.free(actual);
        try std.testing.expectEqualSlices(u8, expected.items, actual);
        try std.testing.expectEqual(expected.items.len, encoder.input_read);
        return err;
    };
    defer failing_allocator.free(frame.bytes);
    try std.testing.expectEqual(before.input_read + frame.input_len, encoder.input_read);
    try std.testing.expectEqualDeep(frame.models, encoder.models);
}
