const std = @import("std");

/// Largest input chunk used by the Adler-32 reference loop before reducing.
/// This is the zlib-compatible NMAX bound that keeps the running sums within u32.
pub const adler32_nmax = 5552;
pub const adler32_modulus = 65521;

/// Streaming Adler-32 state compatible with zlib's checksum definition.
pub const Adler32 = struct {
    a: u32 = 1,
    b: u32 = 0,

    pub fn init() Adler32 {
        return .{};
    }

    pub fn update(self: *Adler32, input: []const u8) void {
        var index: usize = 0;
        var a = self.a;
        var b = self.b;
        while (index < input.len) {
            const chunk_len = @min(adler32_nmax, input.len - index);
            const chunk = input[index..][0..chunk_len];
            for (chunk) |byte| {
                a += byte;
                b += a;
            }
            a %= adler32_modulus;
            b %= adler32_modulus;
            index += chunk_len;
        }
        self.a = a;
        self.b = b;
    }

    pub fn digest(self: Adler32) u32 {
        return (self.b << 16) | self.a;
    }

    pub fn hash(input: []const u8) u32 {
        var state = Adler32.init();
        state.update(input);
        return state.digest();
    }
};

/// Table-driven IEEE CRC-32 state used by gzip, zip, and zlib-family tooling.
pub const Crc32 = struct {
    value: u32 = 0xffff_ffff,

    pub const polynomial_reflected: u32 = 0xedb8_8320;
    pub const table = makeCrc32Table(polynomial_reflected);

    pub fn init() Crc32 {
        return .{};
    }

    pub fn update(self: *Crc32, input: []const u8) void {
        var crc = self.value;
        for (input) |byte| {
            const index: u8 = @truncate(crc ^ byte);
            crc = table[index] ^ (crc >> 8);
        }
        self.value = crc;
    }

    pub fn digest(self: Crc32) u32 {
        return ~self.value;
    }

    pub fn hash(input: []const u8) u32 {
        var state = Crc32.init();
        state.update(input);
        return state.digest();
    }
};

pub fn adler32(input: []const u8) u32 {
    return Adler32.hash(input);
}

pub fn crc32(input: []const u8) u32 {
    return Crc32.hash(input);
}

fn makeCrc32Table(comptime polynomial: u32) [256]u32 {
    @setEvalBranchQuota(4096);
    var table: [256]u32 = undefined;
    for (&table, 0..) |*entry, i| {
        var crc: u32 = @intCast(i);
        for (0..8) |_| {
            crc = if ((crc & 1) != 0) (crc >> 1) ^ polynomial else crc >> 1;
        }
        entry.* = crc;
    }
    return table;
}

test "Adler-32 known zlib vectors" {
    try std.testing.expectEqual(@as(u32, 0x0000_0001), adler32(""));
    try std.testing.expectEqual(@as(u32, 0x0062_0062), adler32("a"));
    try std.testing.expectEqual(@as(u32, 0x024d_0127), adler32("abc"));
    try std.testing.expectEqual(@as(u32, 0x058c_01f5), adler32("Hello"));
    try std.testing.expectEqual(@as(u32, 0x11e6_0398), adler32("Wikipedia"));
    try std.testing.expectEqual(@as(u32, 0x5bdc_0fda), adler32("The quick brown fox jumps over the lazy dog"));
}

test "Adler-32 streaming matches one-shot across reduction boundary" {
    var input: [adler32_nmax * 2 + 137]u8 = undefined;
    for (&input, 0..) |*byte, i| {
        byte.* = @truncate((i * 131 + 17) & 0xff);
    }

    var state = Adler32.init();
    state.update(input[0..1]);
    state.update(input[1..5553]);
    state.update(input[5553..]);
    try std.testing.expectEqual(adler32(&input), state.digest());
}

test "CRC-32 known IEEE vectors" {
    try std.testing.expectEqual(@as(u32, 0x0000_0000), crc32(""));
    try std.testing.expectEqual(@as(u32, 0xe8b7_be43), crc32("a"));
    try std.testing.expectEqual(@as(u32, 0x3524_41c2), crc32("abc"));
    try std.testing.expectEqual(@as(u32, 0xf7d1_8982), crc32("Hello"));
    try std.testing.expectEqual(@as(u32, 0xadaa_c02e), crc32("Wikipedia"));
    try std.testing.expectEqual(@as(u32, 0xcbf4_3926), crc32("123456789"));
    try std.testing.expectEqual(@as(u32, 0x414f_a339), crc32("The quick brown fox jumps over the lazy dog"));
}

test "CRC-32 streaming matches one-shot" {
    const input = "The quick brown fox jumps over the lazy dog" ** 97;
    var state = Crc32.init();
    state.update(input[0..7]);
    state.update(input[7..511]);
    state.update(input[511..]);
    try std.testing.expectEqual(crc32(input), state.digest());
}
