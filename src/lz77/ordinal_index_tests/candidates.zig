const std = @import("std");
const Harness = @import("fixture.zig").Harness;

pub fn check(comptime Codec: type) !void {
    const H = Harness(Codec);
    const Fixture = H.Fixture;
    const Mode = H.Mode;
    const allocator = H.allocator;
    const records = H.records;
    const compareCandidates = H.compareCandidates;
    const oldCandidates = H.oldCandidates;
    const physicallyCappedFour = H.physicallyCappedFour;
    // empty chains short scratch and zero quotas
    {
        for ([_][]const u8{ "", "a", "ab", "abc" }) |input| {
            var fixture = try Fixture.init(input, .exact);
            defer fixture.deinit();
            try fixture.expectImmutable();
        }
        var fixture = try Fixture.init("ABCD", .exact);
        defer fixture.deinit();
        for ([_]usize{ 0, 1, 128 }) |quota| {
            for ([_]usize{ 0, 1, 128 }) |window| {
                const stats = try compareCandidates(&fixture, 0, quota, window);
                try std.testing.expectEqual(@as(usize, 0), stats.returned);
            }
        }
    }

    // no full prefix match and old quota limit boundaries
    {
        var missing = try Fixture.init("ABC1ABC2ABC3ABC4", .exact);
        defer missing.deinit();
        try std.testing.expectEqual(@as(usize, 0), (try compareCandidates(&missing, 12, 128, 128)).returned);

        const input = try records(&.{ "AAAQ".*, "AAAR".*, "AAAQ".*, "AAAS".*, "AAAQ".*, "AAAQ".* });
        defer allocator.free(input);
        var fixture = try Fixture.init(input, .foreign_four);
        defer fixture.deinit();
        const position = 40;
        try std.testing.expectEqual(@as(u32, 1), fixture.scratch.ordinals.items[position] - fixture.scratch.ordinals.items[32]);
        try std.testing.expectEqual(@as(u32, 3), fixture.scratch.ordinals.items[position] - fixture.scratch.ordinals.items[16]);
        try std.testing.expectEqual(@as(u32, 5), fixture.scratch.ordinals.items[position] - fixture.scratch.ordinals.items[0]);
        for ([_]usize{ 0, 1, 2, 3, 4, 5, 6, 127, 128, 129 }) |quota| {
            _ = try compareCandidates(&fixture, position, quota, input.len);
        }
        var expected = try oldCandidates(&fixture, position, 3, input.len);
        defer expected.deinit(allocator);
        try std.testing.expectEqualSlices(u32, &.{ 32, 16 }, expected.items);
    }

    // foreign ordinal ties are rejected before membership subtraction
    {
        const input = try records(&.{ "AAAQ".*, "BBBQ".*, "BBBQ".*, "BBBQ".*, "AAAQ".* });
        defer allocator.free(input);
        var fixture = try Fixture.init(input, .foreign_four);
        defer fixture.deinit();
        try std.testing.expectEqual(fixture.scratch.ordinals.items[32], fixture.scratch.ordinals.items[16]);
        try std.testing.expect(fixture.scratch.ordinals.items[24] > fixture.scratch.ordinals.items[32]);
        try std.testing.expectEqual(@as(u32, 1), fixture.scratch.ordinals.items[32] - fixture.scratch.ordinals.items[0]);
        const stats = try compareCandidates(&fixture, 32, 1, 32);
        try std.testing.expectEqual(@as(usize, 1), stats.returned);
        try std.testing.expectEqual(@as(usize, 1), stats.switches);
        try std.testing.expect(stats.rejections != 0);
    }

    // fallback frontier at valid or foreign node preserves order without duplicates
    {
        for ([_][5][4]u8{
            .{ "AAAQ".*, "BBBQ".*, "AAAQ".*, "BBBQ".*, "AAAQ".* },
            .{ "AAAQ".*, "BBBQ".*, "BBBQ".*, "AAAQ".*, "AAAQ".* },
        }, 0..) |prefixes, variant| {
            const input = try records(&prefixes);
            defer allocator.free(input);
            var fixture = try Fixture.init(input, .foreign_four);
            defer fixture.deinit();
            const recent: u32 = if (variant == 0) 16 else 24;
            var expected = try oldCandidates(&fixture, 32, 2, 32);
            defer expected.deinit(allocator);
            try std.testing.expectEqualSlices(u32, &.{ recent, 0 }, expected.items);
            var naive = try physicallyCappedFour(&fixture, 32, 2, 32);
            defer naive.deinit(allocator);
            try std.testing.expectEqualSlices(u32, &.{recent}, naive.items);
            const stats = try compareCandidates(&fixture, 32, 2, 32);
            try std.testing.expectEqual(@as(usize, 1), stats.switches);
            try std.testing.expectEqual(@as(usize, 2), stats.physical);
            try std.testing.expectEqual(@as(usize, 16), stats.frontier);
            try std.testing.expectEqual(@as(usize, 2), stats.returned);
            try std.testing.expectEqual(@as(usize, 1), stats.skipped(2));
            for ([_]usize{ 15, 16, 17, 31, 32, 33 }) |window| {
                _ = try compareCandidates(&fixture, 32, 2, window);
            }
        }
    }

    // replay consumes invalid old nodes within the original quota
    {
        const input = try records(&.{ "AAAQ".*, "AAAR".*, "AAAS".*, "BBBQ".*, "AAAQ".*, "AAAQ".* });
        defer allocator.free(input);
        var fixture = try Fixture.init(input, .foreign_four);
        defer fixture.deinit();
        var expected = try oldCandidates(&fixture, 40, 2, 40);
        defer expected.deinit(allocator);
        try std.testing.expectEqualSlices(u32, &.{32}, expected.items);
        const stats = try compareCandidates(&fixture, 40, 2, 40);
        try std.testing.expectEqual(@as(usize, 1), stats.switches);
        try std.testing.expectEqual(@as(usize, 1), stats.returned);
        try std.testing.expect(stats.skipped(2) != 0);
        for ([_]usize{ 1, 2, 3, 4, 5 }) |quota| {
            _ = try compareCandidates(&fixture, 40, quota, 40);
        }
    }

    // two KiB foreign collision control saves old-valid candidate beyond physical cap
    {
        var prefixes: [258][4]u8 = undefined;
        @memset(&prefixes, "BBBQ".*);
        prefixes[0] = "AAAQ".*;
        prefixes[prefixes.len - 1] = "AAAQ".*;
        const input = try records(&prefixes);
        defer allocator.free(input);
        try std.testing.expect(input.len > 2 * 1024);
        var fixture = try Fixture.init(input, .foreign_four);
        defer fixture.deinit();
        const position = (prefixes.len - 1) * 8;
        var expected = try oldCandidates(&fixture, position, 128, position);
        defer expected.deinit(allocator);
        try std.testing.expectEqualSlices(u32, &.{0}, expected.items);
        var naive = try physicallyCappedFour(&fixture, position, 128, position);
        defer naive.deinit(allocator);
        try std.testing.expectEqual(@as(usize, 0), naive.items.len);
        const stats = try compareCandidates(&fixture, position, 128, position);
        try std.testing.expectEqual(@as(usize, 1), stats.switches);
        try std.testing.expectEqual(@as(usize, 128), stats.physical);
        try std.testing.expectEqual(@as(usize, 1), stats.returned);
        for ([_]usize{ position - 1, position, position + 1 }) |window| {
            _ = try compareCandidates(&fixture, position, 128, window);
        }
    }

    // long same-prefix chains preserve exact quota and window edges
    {
        var input: [4096]u8 = @splat('A');
        var fixture = try Fixture.init(&input, .exact);
        defer fixture.deinit();
        const position = input.len - 4;
        for ([_]usize{ 0, 1, 127, 128, 129 }) |quota| {
            for ([_]usize{ 0, 1, 127, 128, 129, position - 1, position, position + 1 }) |window| {
                const stats = try compareCandidates(&fixture, position, quota, window);
                try std.testing.expectEqual(@min(quota, @min(window, position)), stats.returned);
            }
        }
    }

    // bounded randomized candidate ID oracle
    {
        var prng = std.Random.DefaultPrng.init(0x0d1a_1c0a_5e77_2026);
        const random = prng.random();
        const quotas = [_]usize{ 0, 1, 2, 3, 7, 16, 127, 128, 129 };
        for (0..128) |case_index| {
            var storage: [256]u8 = undefined;
            const len = 4 + random.uintLessThan(usize, storage.len - 3);
            const input = storage[0..len];
            random.bytes(input);
            if (case_index % 3 != 0) {
                for (input) |*byte| byte.* &= if (case_index % 3 == 1) @as(u8, 1) else @as(u8, 7);
            }
            if (len >= 12 and case_index % 4 == 0)
                @memcpy(input[len - 4 ..][0..4], input[0..4]);
            const mode: Mode = switch (case_index % 3) {
                0 => .exact,
                1 => .foreign_four,
                else => .tiny,
            };
            var fixture = try Fixture.init(input, mode);
            defer fixture.deinit();
            const position = if (case_index & 1 == 0) len - 4 else random.uintLessThan(usize, len - 3);
            const quota = quotas[random.uintLessThan(usize, quotas.len)];
            const windows = [_]usize{ 0, 1, position -| 1, position, position + 1, random.uintLessThan(usize, position + 1) };
            for (windows) |window| {
                _ = try compareCandidates(&fixture, position, quota, window);
            }
        }
    }
}
