const std = @import("std");

pub fn contracts(comptime C: type) !void {
    try selectorTies(C);
    try storedBoundaries(C);
    try writerOracle(C);
}

fn selectorTies(comptime C: type) !void {
    const fixed_over_dynamic = try C.select(
        0,
        100,
        10,
        9,
        .stored_fixed_dynamic,
    );
    try std.testing.expectEqual(C.Kind.fixed, fixed_over_dynamic.block_type);

    const stored_over_fixed = try C.select(
        0,
        0,
        40,
        48,
        .stored_fixed_dynamic,
    );
    try std.testing.expectEqual(C.Kind.stored, stored_over_fixed.block_type);

    const stored_over_dynamic = try C.select(
        0,
        0,
        48,
        40,
        .stored_fixed_dynamic,
    );
    try std.testing.expectEqual(C.Kind.stored, stored_over_dynamic.block_type);

    const stored_over_all = try C.select(
        0,
        0,
        40,
        40,
        .stored_fixed_dynamic,
    );
    try std.testing.expectEqual(C.Kind.stored, stored_over_all.block_type);

    const offset_stored_tie = try C.select(
        7,
        0,
        41,
        null,
        .stored_fixed,
    );
    try std.testing.expectEqual(C.Kind.stored, offset_stored_tie.block_type);
    try std.testing.expectEqual(@as(u3, 0), offset_stored_tie.end_bit_index);

    try std.testing.expectError(
        error.InvalidBlockPlan,
        C.select(0, 0, 10, null, .stored_fixed_dynamic),
    );
    try std.testing.expectError(
        error.InvalidBlockPlan,
        C.select(0, 0, 10, 9, .stored_fixed),
    );
}

fn storedBoundaries(comptime C: type) !void {
    const lengths = [_]usize{
        0,
        1,
        65_534,
        65_535,
        65_536,
        131_069,
        131_070,
        131_071,
    };
    for (lengths) |length| {
        const plain = try std.testing.allocator.alloc(u8, length);
        defer std.testing.allocator.free(plain);
        @memset(plain, 0);
        for (0..8) |raw_start| {
            const start: u3 = @intCast(raw_start);
            const blocks = if (length == 0) 1 else (length - 1) / 65_535 + 1;
            const header_bytes = (@as(usize, start) + 3 + 7) / 8;
            const expected_bytes = length + 4 + header_bytes + (blocks - 1) * 5;
            const selected = try C.select(
                start,
                length,
                expected_bytes * 8 + 8,
                null,
                .stored_fixed,
            );
            try std.testing.expectEqual(C.Kind.stored, selected.block_type);
            try std.testing.expectEqual(expected_bytes, selected.closed_bytes);
            try std.testing.expectEqual(@as(u3, 0), selected.end_bit_index);

            const actual = try C.actualStored(
                std.testing.allocator,
                start,
                plain,
            );
            try std.testing.expectEqual(expected_bytes, actual.complete_bytes);
            try std.testing.expectEqual(@as(u3, 0), actual.bit_index);
            try std.testing.expectEqual(selected.added_bits, actual.added_bits);
        }
    }
}

fn writerOracle(comptime C: type) !void {
    var stored_plain: [256]u8 = undefined;
    var stored_tokens: [stored_plain.len]C.Token = undefined;
    for (&stored_plain, &stored_tokens, 0..) |*byte, *token, index| {
        byte.* = @intCast(index);
        token.* = .{ .literal = byte.* };
    }

    var dynamic_plain: [1024]u8 = @splat('a');
    var dynamic_tokens: [dynamic_plain.len]C.Token = undefined;
    for (&dynamic_tokens) |*token| token.* = .{ .literal = 'a' };

    const no_tokens = [_]C.Token{};
    const options = C.options(.default);
    const Fixture = struct {
        plain: []const u8,
        tokens: []const C.Token,
        expected: C.Kind,
    };
    const fixtures = [_]Fixture{
        .{ .plain = "", .tokens = &no_tokens, .expected = .fixed },
        .{ .plain = &stored_plain, .tokens = &stored_tokens, .expected = .stored },
        .{ .plain = &dynamic_plain, .tokens = &dynamic_tokens, .expected = .dynamic },
    };

    for (0..8) |raw_start| {
        const start: u3 = @intCast(raw_start);
        for (fixtures) |fixture| {
            const predicted = try C.predict(
                fixture.plain.len,
                fixture.tokens,
                options,
                .{ .bit_index = start },
            );
            try std.testing.expectEqual(fixture.expected, predicted.cost.block_type);
            inline for (.{ false, true }) |final| {
                const actual = try C.actual(
                    std.testing.allocator,
                    start,
                    fixture.plain,
                    fixture.tokens,
                    options,
                    final,
                );
                try expectState(C, predicted.state, actual.state);
                try std.testing.expectEqual(
                    predicted.cost.block_type,
                    actual.block_type,
                );
                try std.testing.expectEqual(
                    predicted.cost.closed_bytes,
                    actual.state.complete_bytes +
                        @intFromBool(actual.state.bit_index != 0),
                );
            }
        }

        for (fixtures) |first_fixture| {
            for (fixtures) |second_fixture| {
                const first = try C.predict(
                    first_fixture.plain.len,
                    first_fixture.tokens,
                    options,
                    .{ .bit_index = start },
                );
                const second = try C.predict(
                    second_fixture.plain.len,
                    second_fixture.tokens,
                    options,
                    first.state,
                );
                const actual = try C.actualPair(
                    std.testing.allocator,
                    start,
                    first_fixture.plain,
                    first_fixture.tokens,
                    options,
                    second_fixture.plain,
                    second_fixture.tokens,
                    options,
                );
                try expectState(C, first.state, actual.first_state);
                try expectState(C, second.state, actual.state);
                try std.testing.expectEqual(
                    first.cost.block_type,
                    actual.first_type,
                );
                try std.testing.expectEqual(
                    second.cost.block_type,
                    actual.second_type,
                );
            }
        }
    }
}

fn expectState(comptime C: type, expected: C.State, actual: C.State) !void {
    try std.testing.expectEqual(expected.complete_bytes, actual.complete_bytes);
    try std.testing.expectEqual(expected.bit_index, actual.bit_index);
    try std.testing.expectEqual(expected.added_bits, actual.added_bits);
}
