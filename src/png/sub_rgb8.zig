//! RGB Sub reconstruction batches four pixels with exact byte prefix sums.
//! Twelve-byte stores keep aliased input and all row boundaries intact.
const std = @import("std");
const builtin = @import("builtin");
const Vector = @Vector(16, u8);

pub fn supported() bool {
    // aarch64_be retains the scalar path: lane-to-word stores below are little endian.
    return builtin.cpu.arch == .aarch64 and
        std.Target.aarch64.featureSetHas(builtin.cpu.features, .neon);
}

fn shiftMask(comptime distance: usize) @Vector(16, i32) {
    var mask: @Vector(16, i32) = undefined;
    for (0..16) |i| mask[i] = if (i >= distance) @intCast(i - distance) else -1;
    return mask;
}

const carry_mask: @Vector(16, i32) = .{ 9, 10, 11, 9, 10, 11, 9, 10, 11, 9, 10, 11, 9, 10, 11, 9 };

inline fn shift(comptime bytes: usize, values: Vector) Vector {
    if (comptime supported()) {
        return asm ("ext %[result].16b, %[zero].16b, %[values].16b, #" ++ if (bytes == 3) "13" else "10"
            : [result] "=w" (-> Vector),
            : [zero] "w" (@as(Vector, @splat(0))),
              [values] "w" (values),
        );
    }
    return @shuffle(u8, values, @as(Vector, @splat(0)), shiftMask(bytes));
}

inline fn thirdWord(values: Vector) u32 {
    if (comptime supported()) return asm ("umov %[result:w], %[values].s[2]"
        : [result] "=r" (-> u32),
        : [values] "w" (values),
    );
    const bytes: [16]u8 = values;
    return std.mem.readInt(u32, bytes[8..12], .little);
}

pub fn run(filtered: []const u8, output: []u8) void {
    std.debug.assert(filtered.len == output.len);
    if (comptime !supported()) return reference(filtered, output);
    var carry: Vector = @splat(0);
    var i: usize = 0;
    while (filtered.len - i >= 16) : (i += 12) {
        var values: Vector = filtered[i..][0..16].*;
        values +%= shift(3, values);
        values +%= shift(6, values);
        values +%= carry;
        const words: @Vector(2, u64) = @bitCast(values);
        std.mem.writeInt(u64, output[i..][0..8], words[0], .little);
        std.mem.writeInt(u32, output[i + 8 ..][0..4], thirdWord(values), .little);
        carry = @shuffle(u8, values, undefined, carry_mask);
    }
    var left: [3]u8 = .{ carry[0], carry[1], carry[2] };
    while (i < filtered.len) : (i += 1) {
        const channel = i % 3;
        left[channel] +%= filtered[i];
        output[i] = left[channel];
    }
}

fn reference(filtered: []const u8, output: []u8) void {
    for (filtered, 0..) |value, i|
        output[i] = value +% (if (i >= 3) output[i - 3] else @as(u8, 0));
}

test "RGB Sub four-pixel prefix retains scalar bytes across tails and aliases" {
    var random = std.Random.DefaultPrng.init(0x504e475f53554233);
    var input: [300]u8 = undefined;
    var expected: [300]u8 = undefined;
    var output: [332]u8 = undefined;
    var aliased: [332]u8 = undefined;
    for (0..301) |length| {
        for (0..4) |pattern| {
            random.random().bytes(&input);
            if (pattern == 1) @memset(&input, 255);
            if (pattern == 2) @memset(&input, 0);
            if (pattern == 3) for (&input, 0..) |*v, i| {
                v.* = @truncate(i * 31);
            };
            reference(input[0..length], expected[0..length]);
            for (0..16) |offset| {
                @memset(&output, 0xa5);
                @memset(&aliased, 0xa5);
                @memcpy(aliased[offset..][0..length], input[0..length]);
                run(input[0..length], output[offset..][0..length]);
                run(aliased[offset..][0..length], aliased[offset..][0..length]);
                try std.testing.expectEqualSlices(u8, expected[0..length], output[offset..][0..length]);
                try std.testing.expectEqualSlices(u8, expected[0..length], aliased[offset..][0..length]);
                for (output[0..offset]) |v| try std.testing.expectEqual(@as(u8, 0xa5), v);
                for (aliased[0..offset]) |v| try std.testing.expectEqual(@as(u8, 0xa5), v);
                for (output[offset + length ..]) |v| try std.testing.expectEqual(@as(u8, 0xa5), v);
                for (aliased[offset + length ..]) |v| try std.testing.expectEqual(@as(u8, 0xa5), v);
            }
        }
    }
}
