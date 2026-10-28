//! Bounded byte-column accumulation; horizontal reductions occur per chunk.
const std = @import("std");
const builtin = @import("builtin");
const Bytes = @Vector(16, u8);
const Columns = @Vector(8, u16);
const Sums = @Vector(4, u32);
const low8: @Vector(8, i32) = .{ 0, 1, 2, 3, 4, 5, 6, 7 };
const high8: @Vector(8, i32) = .{ 8, 9, 10, 11, 12, 13, 14, 15 };
const even8: @Vector(8, i32) = .{ 0, 2, 4, 6, 8, 10, 12, 14 };
const odd8: @Vector(8, i32) = .{ 1, 3, 5, 7, 9, 11, 13, 15 };
const even4: @Vector(4, i32) = .{ 0, 2, 4, 6 };
const odd4: @Vector(4, i32) = .{ 1, 3, 5, 7 };
const low4: @Vector(4, i32) = .{ 0, 1, 2, 3 };
const high4: @Vector(4, i32) = .{ 4, 5, 6, 7 };

inline fn pairs(bytes: Bytes) Columns {
    if (comptime supported()) return asm ("uaddlp %[result].8h, %[bytes].16b"
        : [result] "=w" (-> Columns),
        : [bytes] "w" (bytes),
    );
    return @as(Columns, @as(@Vector(8, u8), @shuffle(u8, bytes, undefined, even8))) +
        @as(Columns, @as(@Vector(8, u8), @shuffle(u8, bytes, undefined, odd8)));
}

pub fn supported() bool {
    return switch (builtin.cpu.arch) {
        .aarch64 => std.Target.aarch64.featureSetHas(builtin.cpu.features, .neon),
        else => false,
    };
}

test "Adler column kernel preserves every byte lane weight" {
    const K = Kernel(5552, 65521);
    var input: [32]u8 = undefined;
    for (0..32) |lane| {
        for (0..256) |value| {
            @memset(&input, 0);
            input[lane] = @intCast(value);
            for ([_][2]u32{ .{ 1, 0 }, .{ 65520, 65520 } }) |seed| {
                var a = seed[0];
                var b = seed[1];
                K.update(&a, &b, &input);
                try std.testing.expectEqual((seed[0] + @as(u32, @intCast(value))) % 65521, a);
                try std.testing.expectEqual((seed[1] + 32 * seed[0] + @as(u32, @intCast((32 - lane) * value))) % 65521, b);
            }
        }
    }
}

inline fn groups(values: Columns) Sums {
    if (comptime supported()) return asm ("uaddlp %[result].4s, %[values].8h"
        : [result] "=w" (-> Sums),
        : [values] "w" (values),
    );
    return @as(Sums, @as(@Vector(4, u16), @shuffle(u16, values, undefined, even4))) +
        @as(Sums, @as(@Vector(4, u16), @shuffle(u16, values, undefined, odd4)));
}

inline fn addPairs(sums: Columns, bytes: Bytes) Columns {
    if (comptime supported()) return asm ("uadalp %[result].8h, %[bytes].16b"
        : [result] "=w" (-> Columns),
        : [initial] "0" (sums),
          [bytes] "w" (bytes),
    );
    return sums + pairs(bytes);
}

inline fn addGroups(sums: Sums, values: Columns) Sums {
    if (comptime supported()) return asm ("uadalp %[result].4s, %[values].8h"
        : [result] "=w" (-> Sums),
        : [initial] "0" (sums),
          [values] "w" (values),
    );
    return sums + groups(values);
}

inline fn addColumn(comptime upper: bool, columns: Columns, bytes: Bytes) Columns {
    if (comptime supported()) return asm (if (upper) "uaddw2 %[result].8h, %[columns].8h, %[bytes].16b" else "uaddw %[result].8h, %[columns].8h, %[bytes].8b"
        : [result] "=w" (-> Columns),
        : [columns] "w" (columns),
          [bytes] "w" (bytes),
    );
    return columns + @as(Columns, @as(@Vector(8, u8), @shuffle(u8, bytes, undefined, if (upper) high8 else low8)));
}

inline fn weighted(comptime upper: bool, sums: Sums, column: Columns, weights: Columns) Sums {
    if (comptime supported()) return asm (if (upper) "umlal2 %[result].4s, %[column].8h, %[weights].8h" else "umlal %[result].4s, %[column].4h, %[weights].4h"
        : [result] "=w" (-> Sums),
        : [initial] "0" (sums),
          [column] "w" (column),
          [weights] "w" (weights),
    );
    const mask = if (upper) high4 else low4;
    return sums + @as(Sums, @as(@Vector(4, u16), @shuffle(u16, column, undefined, mask))) *
        @as(Sums, @as(@Vector(4, u16), @shuffle(u16, weights, undefined, mask)));
}

pub fn Kernel(comptime nmax: usize, comptime modulus: u32) type {
    return struct {
        pub const block_len = 32;
        pub const chunk_len = nmax / block_len * block_len;
        comptime {
            std.debug.assert(chunk_len > 0);
            std.debug.assert(chunk_len / block_len * 255 <= std.math.maxInt(u16));
        }

        pub noinline fn update(state_a: *u32, state_b: *u32, input: []const u8) void {
            var a = state_a.*;
            var b = state_b.*;
            var offset: usize = 0;
            while (offset < input.len) {
                const chunk = input[offset..][0..@min(chunk_len, input.len - offset)];
                var column: [4]Columns = .{ @splat(0), @splat(0), @splat(0), @splat(0) };
                var a_lanes: Sums = @splat(0);
                var prefix: Sums = .{ a * @as(u32, @intCast(chunk.len / block_len)), 0, 0, 0 };
                var position: usize = 0;
                while (position + block_len <= chunk.len) : (position += block_len) {
                    const first: Bytes = chunk[position..][0..16].*;
                    const second: Bytes = chunk[position + 16 ..][0..16].*;
                    prefix += a_lanes;
                    const pair_sums = addPairs(pairs(first), second);
                    a_lanes = addGroups(a_lanes, pair_sums);
                    column[0] = addColumn(false, column[0], first);
                    column[1] = addColumn(true, column[1], first);
                    column[2] = addColumn(false, column[2], second);
                    column[3] = addColumn(true, column[3], second);
                }
                var b_lanes = prefix << @splat(5);
                inline for (0..4) |i| {
                    const first: u16 = 32 - i * 8;
                    const weights: Columns = .{ first, first - 1, first - 2, first - 3, first - 4, first - 5, first - 6, first - 7 };
                    b_lanes = weighted(false, b_lanes, column[i], weights);
                    b_lanes = weighted(true, b_lanes, column[i], weights);
                }
                a += @reduce(.Add, a_lanes);
                b += @reduce(.Add, b_lanes);
                while (position < chunk.len) : (position += 1) {
                    a += chunk[position];
                    b += a;
                }
                a %= modulus;
                b %= modulus;
                offset += chunk.len;
            }
            state_a.* = a;
            state_b.* = b;
        }
    };
}

test "Adler column kernel retains scalar state across maximum values offsets and fragments" {
    const K = Kernel(5552, 65521);
    var input: [K.chunk_len * 3 + 137]u8 = undefined;
    for (0..4) |pattern| {
        for (&input, 0..) |*value, i| value.* = switch (pattern) {
            0 => 0,
            1 => 255,
            2 => @truncate(i *% 7919),
            else => @truncate(i / 7 + i *% 37),
        };
        for ([_]usize{ 0, 1, 7, 15 }) |offset| {
            for ([_]usize{ 0, 1, 15, 16, 31, 32, 33, 63, 64, 65, 127, 128, K.chunk_len - 1, K.chunk_len, K.chunk_len + 1, 5552, 5553, input.len - 15 }) |requested| {
                const bytes = input[offset..][0..@min(requested, input.len - offset)];
                for ([_][2]u32{ .{ 1, 0 }, .{ 65520, 65520 } }) |seed| {
                    var a = seed[0];
                    var b = seed[1];
                    var expected_a = a;
                    var expected_b = b;
                    for (bytes) |byte| {
                        expected_a = (expected_a + byte) % 65521;
                        expected_b = (expected_b + expected_a) % 65521;
                    }
                    K.update(&a, &b, bytes);
                    try std.testing.expectEqual(expected_a, a);
                    try std.testing.expectEqual(expected_b, b);
                }
            }
        }
        var a: u32 = 1;
        var b: u32 = 0;
        var expected_a: u32 = 1;
        var expected_b: u32 = 0;
        var offset: usize = 0;
        var fragment: usize = 0;
        const fragments = [_]usize{ 0, 1, 7, 31, 32, 33, 65, K.chunk_len - 1, K.chunk_len + 1 };
        while (offset < input.len) {
            const count = @min(fragments[fragment % fragments.len], input.len - offset);
            fragment += 1;
            const bytes = input[offset..][0..count];
            for (bytes) |byte| {
                expected_a = (expected_a + byte) % 65521;
                expected_b = (expected_b + expected_a) % 65521;
            }
            K.update(&a, &b, bytes);
            try std.testing.expectEqual(expected_a, a);
            try std.testing.expectEqual(expected_b, b);
            offset += count;
        }
    }
}
