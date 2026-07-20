const std = @import("std");
const builtin = @import("builtin");

/// Largest input chunk used by the Adler-32 reference loop before reducing.
/// This is the zlib-compatible NMAX bound that keeps the running sums within u32.
pub const adler32_nmax = 5552;
pub const adler32_modulus = 65521;
const adler32_vector_len = 64;
const adler32_vector_weights: @Vector(adler32_vector_len, u32) = .{ 64, 63, 62, 61, 60, 59, 58, 57, 56, 55, 54, 53, 52, 51, 50, 49, 48, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35, 34, 33, 32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1 };

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
            var chunk_index: usize = 0;
            while (chunk_index + adler32_vector_len <= chunk.len) : (chunk_index += adler32_vector_len) {
                const bytes = chunk[chunk_index..][0..adler32_vector_len].*;
                const bytes_u8: @Vector(adler32_vector_len, u8) = bytes;
                const values: @Vector(adler32_vector_len, u32) = bytes_u8;
                const sum = @reduce(.Add, values);
                const weighted = @reduce(.Add, values * adler32_vector_weights);
                // Adler-32's second sum is a weighted prefix sum. Folding
                // sixty-four bytes at a time preserves the scalar recurrence:
                //   b' = b + 64*a + 64*x0 + 63*x1 + ... + 1*x63
                //   a' = a + x0 + x1 + ... + x63
                // NMAX still bounds a/b before reduction, so the vectorized
                // arithmetic remains within u32 just like zlib's scalar loop.
                b += a * adler32_vector_len + weighted;
                a += sum;
            }
            while (chunk_index < chunk.len) : (chunk_index += 1) {
                a += chunk[chunk_index];
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

/// Table-driven CRC-32C/Castagnoli state used by iSCSI, SCTP, SSE4.2 CRC
/// instructions, filesystems, and modern storage/network formats.
pub const Crc32C = struct {
    value: u32 = 0xffff_ffff,

    pub const polynomial_reflected: u32 = 0x82f6_3b78;
    pub const table = makeCrc32Table(polynomial_reflected);

    pub fn init() Crc32C {
        return .{};
    }

    pub fn update(self: *Crc32C, input: []const u8) void {
        var crc = self.value;
        for (input) |byte| {
            const index: u8 = @truncate(crc ^ byte);
            crc = table[index] ^ (crc >> 8);
        }
        self.value = crc;
    }

    pub fn digest(self: Crc32C) u32 {
        return ~self.value;
    }

    pub fn hash(input: []const u8) u32 {
        var state = Crc32C.init();
        state.update(input);
        return state.digest();
    }
};

pub const Crc32Slice4 = struct {
    value: u32 = 0xffff_ffff,

    pub const tables = makeCrc32Slice4Tables(Crc32.polynomial_reflected);

    pub fn init() Crc32Slice4 {
        return .{};
    }

    pub fn update(self: *Crc32Slice4, input: []const u8) void {
        var crc = self.value;
        var index: usize = 0;
        while (index + 4 <= input.len) : (index += 4) {
            crc ^= std.mem.readInt(u32, input[index..][0..4], .little);
            crc = tables[3][crc & 0xff] ^
                tables[2][(crc >> 8) & 0xff] ^
                tables[1][(crc >> 16) & 0xff] ^
                tables[0][(crc >> 24) & 0xff];
        }
        while (index < input.len) : (index += 1) {
            const table_index: u8 = @truncate(crc ^ input[index]);
            crc = Crc32.table[table_index] ^ (crc >> 8);
        }
        self.value = crc;
    }

    pub fn digest(self: Crc32Slice4) u32 {
        return ~self.value;
    }

    pub fn hash(input: []const u8) u32 {
        var state = Crc32Slice4.init();
        state.update(input);
        return state.digest();
    }
};

pub const Crc32Slice8 = struct {
    value: u32 = 0xffff_ffff,

    pub const tables = makeCrc32SliceTables(8, Crc32.polynomial_reflected);

    pub fn init() Crc32Slice8 {
        return .{};
    }

    pub fn update(self: *Crc32Slice8, input: []const u8) void {
        var crc = self.value;
        var index: usize = 0;
        while (index + 8 <= input.len) : (index += 8) {
            crc ^= std.mem.readInt(u32, input[index..][0..4], .little);
            const high = std.mem.readInt(u32, input[index + 4 ..][0..4], .little);
            crc = tables[7][crc & 0xff] ^
                tables[6][(crc >> 8) & 0xff] ^
                tables[5][(crc >> 16) & 0xff] ^
                tables[4][(crc >> 24) & 0xff] ^
                tables[3][high & 0xff] ^
                tables[2][(high >> 8) & 0xff] ^
                tables[1][(high >> 16) & 0xff] ^
                tables[0][(high >> 24) & 0xff];
        }
        while (index < input.len) : (index += 1) {
            const table_index: u8 = @truncate(crc ^ input[index]);
            crc = Crc32.table[table_index] ^ (crc >> 8);
        }
        self.value = crc;
    }

    pub fn digest(self: Crc32Slice8) u32 {
        return ~self.value;
    }

    pub fn hash(input: []const u8) u32 {
        var state = Crc32Slice8.init();
        state.update(input);
        return state.digest();
    }
};

pub const Crc32Slice16 = struct {
    value: u32 = 0xffff_ffff,

    pub const tables = makeCrc32SliceTables(16, Crc32.polynomial_reflected);

    pub fn init() Crc32Slice16 {
        return .{};
    }

    pub fn update(self: *Crc32Slice16, input: []const u8) void {
        var crc = self.value;
        var index: usize = 0;
        while (index + 16 <= input.len) : (index += 16) {
            crc ^= std.mem.readInt(u32, input[index..][0..4], .little);
            const word1 = std.mem.readInt(u32, input[index + 4 ..][0..4], .little);
            const word2 = std.mem.readInt(u32, input[index + 8 ..][0..4], .little);
            const word3 = std.mem.readInt(u32, input[index + 12 ..][0..4], .little);
            crc = tables[15][crc & 0xff] ^
                tables[14][(crc >> 8) & 0xff] ^
                tables[13][(crc >> 16) & 0xff] ^
                tables[12][(crc >> 24) & 0xff] ^
                tables[11][word1 & 0xff] ^
                tables[10][(word1 >> 8) & 0xff] ^
                tables[9][(word1 >> 16) & 0xff] ^
                tables[8][(word1 >> 24) & 0xff] ^
                tables[7][word2 & 0xff] ^
                tables[6][(word2 >> 8) & 0xff] ^
                tables[5][(word2 >> 16) & 0xff] ^
                tables[4][(word2 >> 24) & 0xff] ^
                tables[3][word3 & 0xff] ^
                tables[2][(word3 >> 8) & 0xff] ^
                tables[1][(word3 >> 16) & 0xff] ^
                tables[0][(word3 >> 24) & 0xff];
        }
        while (index < input.len) : (index += 1) {
            const table_index: u8 = @truncate(crc ^ input[index]);
            crc = Crc32.table[table_index] ^ (crc >> 8);
        }
        self.value = crc;
    }

    pub fn digest(self: Crc32Slice16) u32 {
        return ~self.value;
    }

    pub fn hash(input: []const u8) u32 {
        var state = Crc32Slice16.init();
        state.update(input);
        return state.digest();
    }
};

pub const Crc32Slice32 = struct {
    value: u32 = 0xffff_ffff,

    pub const tables = makeCrc32SliceTables(32, Crc32.polynomial_reflected);

    pub fn init() Crc32Slice32 {
        return .{};
    }

    pub fn update(self: *Crc32Slice32, input: []const u8) void {
        var crc = self.value;
        var index: usize = 0;
        while (index + 32 <= input.len) : (index += 32) {
            // The first word is XORed with the incoming CRC state; the slicing
            // tables then advance the reflected polynomial across the remaining
            // 28 bytes. This keeps the scalar byte order identical to the
            // table-driven reference while reducing loop overhead on large
            // gzip payloads where CRC-32 is currently a visible wrapper cost.
            crc ^= std.mem.readInt(u32, input[index..][0..4], .little);
            const word1 = std.mem.readInt(u32, input[index + 4 ..][0..4], .little);
            const word2 = std.mem.readInt(u32, input[index + 8 ..][0..4], .little);
            const word3 = std.mem.readInt(u32, input[index + 12 ..][0..4], .little);
            const word4 = std.mem.readInt(u32, input[index + 16 ..][0..4], .little);
            const word5 = std.mem.readInt(u32, input[index + 20 ..][0..4], .little);
            const word6 = std.mem.readInt(u32, input[index + 24 ..][0..4], .little);
            const word7 = std.mem.readInt(u32, input[index + 28 ..][0..4], .little);
            crc = tables[31][crc & 0xff] ^
                tables[30][(crc >> 8) & 0xff] ^
                tables[29][(crc >> 16) & 0xff] ^
                tables[28][(crc >> 24) & 0xff] ^
                tables[27][word1 & 0xff] ^
                tables[26][(word1 >> 8) & 0xff] ^
                tables[25][(word1 >> 16) & 0xff] ^
                tables[24][(word1 >> 24) & 0xff] ^
                tables[23][word2 & 0xff] ^
                tables[22][(word2 >> 8) & 0xff] ^
                tables[21][(word2 >> 16) & 0xff] ^
                tables[20][(word2 >> 24) & 0xff] ^
                tables[19][word3 & 0xff] ^
                tables[18][(word3 >> 8) & 0xff] ^
                tables[17][(word3 >> 16) & 0xff] ^
                tables[16][(word3 >> 24) & 0xff] ^
                tables[15][word4 & 0xff] ^
                tables[14][(word4 >> 8) & 0xff] ^
                tables[13][(word4 >> 16) & 0xff] ^
                tables[12][(word4 >> 24) & 0xff] ^
                tables[11][word5 & 0xff] ^
                tables[10][(word5 >> 8) & 0xff] ^
                tables[9][(word5 >> 16) & 0xff] ^
                tables[8][(word5 >> 24) & 0xff] ^
                tables[7][word6 & 0xff] ^
                tables[6][(word6 >> 8) & 0xff] ^
                tables[5][(word6 >> 16) & 0xff] ^
                tables[4][(word6 >> 24) & 0xff] ^
                tables[3][word7 & 0xff] ^
                tables[2][(word7 >> 8) & 0xff] ^
                tables[1][(word7 >> 16) & 0xff] ^
                tables[0][(word7 >> 24) & 0xff];
        }
        if (index + 16 <= input.len) {
            crc ^= std.mem.readInt(u32, input[index..][0..4], .little);
            const word1 = std.mem.readInt(u32, input[index + 4 ..][0..4], .little);
            const word2 = std.mem.readInt(u32, input[index + 8 ..][0..4], .little);
            const word3 = std.mem.readInt(u32, input[index + 12 ..][0..4], .little);
            crc = tables[15][crc & 0xff] ^
                tables[14][(crc >> 8) & 0xff] ^
                tables[13][(crc >> 16) & 0xff] ^
                tables[12][(crc >> 24) & 0xff] ^
                tables[11][word1 & 0xff] ^
                tables[10][(word1 >> 8) & 0xff] ^
                tables[9][(word1 >> 16) & 0xff] ^
                tables[8][(word1 >> 24) & 0xff] ^
                tables[7][word2 & 0xff] ^
                tables[6][(word2 >> 8) & 0xff] ^
                tables[5][(word2 >> 16) & 0xff] ^
                tables[4][(word2 >> 24) & 0xff] ^
                tables[3][word3 & 0xff] ^
                tables[2][(word3 >> 8) & 0xff] ^
                tables[1][(word3 >> 16) & 0xff] ^
                tables[0][(word3 >> 24) & 0xff];
            index += 16;
        }
        while (index < input.len) : (index += 1) {
            const table_index: u8 = @truncate(crc ^ input[index]);
            crc = Crc32.table[table_index] ^ (crc >> 8);
        }
        self.value = crc;
    }

    pub fn digest(self: Crc32Slice32) u32 {
        return ~self.value;
    }

    pub fn hash(input: []const u8) u32 {
        var state = Crc32Slice32.init();
        state.update(input);
        return state.digest();
    }
};

pub const Crc32CSlice8 = struct {
    value: u32 = 0xffff_ffff,

    pub const tables = makeCrc32SliceTables(8, Crc32C.polynomial_reflected);

    pub fn init() Crc32CSlice8 {
        return .{};
    }

    pub fn update(self: *Crc32CSlice8, input: []const u8) void {
        var crc = self.value;
        var index: usize = 0;
        while (index + 8 <= input.len) : (index += 8) {
            crc ^= std.mem.readInt(u32, input[index..][0..4], .little);
            const high = std.mem.readInt(u32, input[index + 4 ..][0..4], .little);
            crc = tables[7][crc & 0xff] ^
                tables[6][(crc >> 8) & 0xff] ^
                tables[5][(crc >> 16) & 0xff] ^
                tables[4][(crc >> 24) & 0xff] ^
                tables[3][high & 0xff] ^
                tables[2][(high >> 8) & 0xff] ^
                tables[1][(high >> 16) & 0xff] ^
                tables[0][(high >> 24) & 0xff];
        }
        while (index < input.len) : (index += 1) {
            const table_index: u8 = @truncate(crc ^ input[index]);
            crc = Crc32C.table[table_index] ^ (crc >> 8);
        }
        self.value = crc;
    }

    pub fn digest(self: Crc32CSlice8) u32 {
        return ~self.value;
    }

    pub fn hash(input: []const u8) u32 {
        var state = Crc32CSlice8.init();
        state.update(input);
        return state.digest();
    }
};

pub const Crc32CSlice16 = struct {
    value: u32 = 0xffff_ffff,

    pub const tables = makeCrc32SliceTables(16, Crc32C.polynomial_reflected);

    pub fn init() Crc32CSlice16 {
        return .{};
    }

    pub fn update(self: *Crc32CSlice16, input: []const u8) void {
        var crc = self.value;
        var index: usize = 0;
        while (index + 16 <= input.len) : (index += 16) {
            crc ^= std.mem.readInt(u32, input[index..][0..4], .little);
            const word1 = std.mem.readInt(u32, input[index + 4 ..][0..4], .little);
            const word2 = std.mem.readInt(u32, input[index + 8 ..][0..4], .little);
            const word3 = std.mem.readInt(u32, input[index + 12 ..][0..4], .little);
            crc = tables[15][crc & 0xff] ^
                tables[14][(crc >> 8) & 0xff] ^
                tables[13][(crc >> 16) & 0xff] ^
                tables[12][(crc >> 24) & 0xff] ^
                tables[11][word1 & 0xff] ^
                tables[10][(word1 >> 8) & 0xff] ^
                tables[9][(word1 >> 16) & 0xff] ^
                tables[8][(word1 >> 24) & 0xff] ^
                tables[7][word2 & 0xff] ^
                tables[6][(word2 >> 8) & 0xff] ^
                tables[5][(word2 >> 16) & 0xff] ^
                tables[4][(word2 >> 24) & 0xff] ^
                tables[3][word3 & 0xff] ^
                tables[2][(word3 >> 8) & 0xff] ^
                tables[1][(word3 >> 16) & 0xff] ^
                tables[0][(word3 >> 24) & 0xff];
        }
        while (index < input.len) : (index += 1) {
            const table_index: u8 = @truncate(crc ^ input[index]);
            crc = Crc32C.table[table_index] ^ (crc >> 8);
        }
        self.value = crc;
    }

    pub fn digest(self: Crc32CSlice16) u32 {
        return ~self.value;
    }

    pub fn hash(input: []const u8) u32 {
        var state = Crc32CSlice16.init();
        state.update(input);
        return state.digest();
    }
};

pub const Crc32CSlice32 = struct {
    value: u32 = 0xffff_ffff,

    pub const tables = makeCrc32SliceTables(32, Crc32C.polynomial_reflected);

    pub fn init() Crc32CSlice32 {
        return .{};
    }

    pub fn update(self: *Crc32CSlice32, input: []const u8) void {
        var crc = self.value;
        var index: usize = 0;
        while (index + 32 <= input.len) : (index += 32) {
            // Castagnoli CRC-32C uses the same reflected slicing-by-N layout as
            // IEEE CRC-32; only the polynomial tables differ. The 32-byte block
            // halves loop overhead for portable CRC-32C consumers while the
            // dispatch below still prefers hardware SSE4.2 when available.
            crc ^= std.mem.readInt(u32, input[index..][0..4], .little);
            const word1 = std.mem.readInt(u32, input[index + 4 ..][0..4], .little);
            const word2 = std.mem.readInt(u32, input[index + 8 ..][0..4], .little);
            const word3 = std.mem.readInt(u32, input[index + 12 ..][0..4], .little);
            const word4 = std.mem.readInt(u32, input[index + 16 ..][0..4], .little);
            const word5 = std.mem.readInt(u32, input[index + 20 ..][0..4], .little);
            const word6 = std.mem.readInt(u32, input[index + 24 ..][0..4], .little);
            const word7 = std.mem.readInt(u32, input[index + 28 ..][0..4], .little);
            crc = tables[31][crc & 0xff] ^
                tables[30][(crc >> 8) & 0xff] ^
                tables[29][(crc >> 16) & 0xff] ^
                tables[28][(crc >> 24) & 0xff] ^
                tables[27][word1 & 0xff] ^
                tables[26][(word1 >> 8) & 0xff] ^
                tables[25][(word1 >> 16) & 0xff] ^
                tables[24][(word1 >> 24) & 0xff] ^
                tables[23][word2 & 0xff] ^
                tables[22][(word2 >> 8) & 0xff] ^
                tables[21][(word2 >> 16) & 0xff] ^
                tables[20][(word2 >> 24) & 0xff] ^
                tables[19][word3 & 0xff] ^
                tables[18][(word3 >> 8) & 0xff] ^
                tables[17][(word3 >> 16) & 0xff] ^
                tables[16][(word3 >> 24) & 0xff] ^
                tables[15][word4 & 0xff] ^
                tables[14][(word4 >> 8) & 0xff] ^
                tables[13][(word4 >> 16) & 0xff] ^
                tables[12][(word4 >> 24) & 0xff] ^
                tables[11][word5 & 0xff] ^
                tables[10][(word5 >> 8) & 0xff] ^
                tables[9][(word5 >> 16) & 0xff] ^
                tables[8][(word5 >> 24) & 0xff] ^
                tables[7][word6 & 0xff] ^
                tables[6][(word6 >> 8) & 0xff] ^
                tables[5][(word6 >> 16) & 0xff] ^
                tables[4][(word6 >> 24) & 0xff] ^
                tables[3][word7 & 0xff] ^
                tables[2][(word7 >> 8) & 0xff] ^
                tables[1][(word7 >> 16) & 0xff] ^
                tables[0][(word7 >> 24) & 0xff];
        }
        if (index + 16 <= input.len) {
            crc ^= std.mem.readInt(u32, input[index..][0..4], .little);
            const word1 = std.mem.readInt(u32, input[index + 4 ..][0..4], .little);
            const word2 = std.mem.readInt(u32, input[index + 8 ..][0..4], .little);
            const word3 = std.mem.readInt(u32, input[index + 12 ..][0..4], .little);
            crc = tables[15][crc & 0xff] ^
                tables[14][(crc >> 8) & 0xff] ^
                tables[13][(crc >> 16) & 0xff] ^
                tables[12][(crc >> 24) & 0xff] ^
                tables[11][word1 & 0xff] ^
                tables[10][(word1 >> 8) & 0xff] ^
                tables[9][(word1 >> 16) & 0xff] ^
                tables[8][(word1 >> 24) & 0xff] ^
                tables[7][word2 & 0xff] ^
                tables[6][(word2 >> 8) & 0xff] ^
                tables[5][(word2 >> 16) & 0xff] ^
                tables[4][(word2 >> 24) & 0xff] ^
                tables[3][word3 & 0xff] ^
                tables[2][(word3 >> 8) & 0xff] ^
                tables[1][(word3 >> 16) & 0xff] ^
                tables[0][(word3 >> 24) & 0xff];
            index += 16;
        }
        while (index < input.len) : (index += 1) {
            const table_index: u8 = @truncate(crc ^ input[index]);
            crc = Crc32C.table[table_index] ^ (crc >> 8);
        }
        self.value = crc;
    }

    pub fn digest(self: Crc32CSlice32) u32 {
        return ~self.value;
    }

    pub fn hash(input: []const u8) u32 {
        var state = Crc32CSlice32.init();
        state.update(input);
        return state.digest();
    }
};

pub fn adler32(input: []const u8) u32 {
    return Adler32.hash(input);
}

/// Combine two already-finalized Adler-32 digests.
///
/// `right_len` is the byte length of the payload that produced `right_adler`.
/// The returned digest is exactly `adler32(left_payload ++ right_payload)`.
/// This follows zlib's `adler32_combine` arithmetic and lets callers compose
/// independently checksummed blocks without replaying their bytes.
pub fn adler32Combine(left_adler: u32, right_adler: u32, right_len: u64) u32 {
    if (right_len == 0) return left_adler;

    const rem: u32 = @intCast(right_len % adler32_modulus);
    const left_a = left_adler & 0xffff;
    const left_b = left_adler >> 16;
    const right_a = right_adler & 0xffff;
    const right_b = right_adler >> 16;

    const combined_a = addMod(left_a, right_a + adler32_modulus - 1);
    // For Adler-32, b is the sum of every intermediate a value. Concatenating
    // the right block adds right_b, then shifts every byte in the right block by
    // the left block's final a value. `right_len * (left_a - 1)` accounts for
    // that constant offset, while the final `-1` removes the duplicated initial
    // Adler a=1 term from the right digest.
    const combined_b = addMod(addMod(left_b, right_b), (rem * left_a) % adler32_modulus + adler32_modulus - rem);
    return (combined_b << 16) | combined_a;
}

fn addMod(left: u32, right: u32) u32 {
    return @intCast((@as(u64, left) + right) % adler32_modulus);
}

pub fn crc32(input: []const u8) u32 {
    return Crc32.hash(input);
}

pub const Crc32Dispatch = enum { scalar, slice4, slice8, slice16, slice32, hardware };
pub const Crc32CDispatch = enum { scalar, slice8, slice16, slice32, hardware };

pub const CpuFeatureReport = struct {
    x86_sse42: bool = false,
    x86_pclmul: bool = false,
    arm_crc32: bool = false,
    ieee_crc32_uses_hardware: bool = false,
    ieee_crc32_pclmul_candidate: bool = false,
    crc32c_hardware_candidate: bool = false,
};

pub fn cpuFeatureReport() CpuFeatureReport {
    var report = CpuFeatureReport{};
    if (builtin.cpu.arch == .x86_64 or builtin.cpu.arch == .x86) {
        const x86 = std.Target.x86;
        report.x86_sse42 = x86.featureSetHas(builtin.cpu.features, .sse4_2);
        report.x86_pclmul = x86.featureSetHas(builtin.cpu.features, .pclmul);
        // PCLMULQDQ can accelerate IEEE CRC-32 folding (implementation present, not yet validated for dispatch).
        report.ieee_crc32_pclmul_candidate = report.x86_pclmul;
        report.crc32c_hardware_candidate = report.x86_sse42;
        report.ieee_crc32_uses_hardware = false;
    } else if (builtin.cpu.arch == .aarch64) {
        const aarch64 = std.Target.aarch64;
        report.arm_crc32 = aarch64.featureSetHas(builtin.cpu.features, .crc);
        // ARM CRC32 instructions compute IEEE CRC-32 natively.
        report.ieee_crc32_uses_hardware = report.arm_crc32;
    }
    return report;
}

pub fn bestCrc32Dispatch() Crc32Dispatch {
    if (builtin.cpu.arch == .aarch64) {
        if (cpuFeatureReport().arm_crc32) return .hardware;
    }
    // PCLMUL x86 path is implemented but not yet validated for dispatch;
    // it must pass differential tests against scalar/slice paths before enabling.
    // if (builtin.cpu.arch == .x86_64 or builtin.cpu.arch == .x86) {
    //     if (cpuFeatureReport().x86_pclmul) return .hardware;
    // }
    return .slice32;
}

pub fn crc32Best(input: []const u8) u32 {
    return switch (bestCrc32Dispatch()) {
        .scalar => crc32(input),
        .slice4 => crc32Slice4(input),
        .slice8 => crc32Slice8(input),
        .slice16 => crc32Slice16(input),
        .slice32 => crc32Slice32(input),
        .hardware => crc32Hardware(input),
    };
}

/// Combine two already-finalized IEEE CRC-32 digests.
///
/// `right_len` is the byte length of the payload that produced `right_crc`.
/// The returned digest is exactly `crc32(left_payload ++ right_payload)`.
/// This is useful for parallel/block encoders that already validated each block
/// independently but need a whole-stream checksum without rereading bytes.
pub fn crc32Combine(left_crc: u32, right_crc: u32, right_len: u64) u32 {
    return crcCombineReflected(Crc32.polynomial_reflected, left_crc, right_crc, right_len);
}

pub fn crc32Slice4(input: []const u8) u32 {
    return Crc32Slice4.hash(input);
}

pub fn crc32Slice8(input: []const u8) u32 {
    return Crc32Slice8.hash(input);
}

pub fn crc32Slice16(input: []const u8) u32 {
    return Crc32Slice16.hash(input);
}

pub fn crc32Slice32(input: []const u8) u32 {
    return Crc32Slice32.hash(input);
}

// ARMv8 CRC32 hardware path for IEEE CRC-32.
// ARM CRC32 instructions compute the IEEE polynomial natively, unlike x86.
pub fn crc32HardwareArm(input: []const u8) u32 {
    if (!(builtin.cpu.arch == .aarch64)) return crc32Slice16(input);
    if (!cpuFeatureReport().arm_crc32) return crc32Slice16(input);
    var crc: u32 = 0xffff_ffff;
    var index: usize = 0;
    // Process 8-byte chunks with crc32x (64-bit) instruction.
    while (index + 8 <= input.len) : (index += 8) {
        const value = std.mem.readInt(u64, input[index..][0..8], .little);
        crc = crc32IeeeArm64(crc, value);
    }
    // Process 4-byte chunks with crc32w (32-bit) instruction.
    if (index + 4 <= input.len) {
        const value = std.mem.readInt(u32, input[index..][0..4], .little);
        crc = crc32IeeeArm32(crc, value);
        index += 4;
    }
    // Process remaining bytes with crc32h (16-bit) and crc32b (8-bit).
    while (index + 2 <= input.len) : (index += 2) {
        const value = std.mem.readInt(u16, input[index..][0..2], .little);
        crc = crc32IeeeArm16(crc, value);
    }
    if (index < input.len) {
        crc = crc32IeeeArm8(crc, input[index]);
    }
    return ~crc;
}

fn crc32IeeeArm64(acc: u32, value: u64) u32 {
    var result = acc;
    asm volatile ("crc32cx %w[result], %w[result], %[value]"
        : [result] "+r" (result),
        : [value] "r" (value),
    );
    return result;
}

fn crc32IeeeArm32(acc: u32, value: u32) u32 {
    var result = acc;
    asm volatile ("crc32cw %w[result], %w[result], %w[value]"
        : [result] "+r" (result),
        : [value] "r" (value),
    );
    return result;
}

fn crc32IeeeArm16(acc: u32, value: u16) u32 {
    var result = acc;
    asm volatile ("crc32ch %w[result], %w[result], %w[value]"
        : [result] "+r" (result),
        : [value] "r" (value),
    );
    return result;
}

fn crc32IeeeArm8(acc: u32, value: u8) u32 {
    var result = acc;
    asm volatile ("crc32cb %w[result], %w[result], %w[value]"
        : [result] "+r" (result),
        : [value] "r" (value),
    );
    return result;
}

// x86 PCLMULQDQ folding for IEEE CRC-32.
// Uses carry-less multiplication to fold the CRC state by 16-byte blocks.
// For each 16-byte block: fold = PCLMULQDQ(state, K_FOLD_128, 0x01)
//   new_state = state XOR fold XOR data

const K_FOLD_128: u64 = 0x5bd7f464; // x^(128+32) mod P_reflected

pub fn crc32HardwareX86(input: []const u8) u32 {
    if (!(builtin.cpu.arch == .x86_64 or builtin.cpu.arch == .x86)) return crc32Slice16(input);
    if (!cpuFeatureReport().x86_pclmul) return crc32Slice16(input);

    if (input.len < 64) return crc32Slice16(input);

    var crc: u32 = 0xffff_ffff;
    var index: usize = 0;

    while (index + 64 <= input.len) : (index += 64) {
        const d0 = std.mem.readInt(u128, input[index..][0..16], .little);
        const d1 = std.mem.readInt(u128, input[index + 16 ..][0..16], .little);
        const d2 = std.mem.readInt(u128, input[index + 32 ..][0..16], .little);
        const d3 = std.mem.readInt(u128, input[index + 48 ..][0..16], .little);

        var state: u128 = d0 ^ @as(u128, crc);
        state = pclmulFold(state, d1);
        state = pclmulFold(state, d2);
        state = pclmulFold(state, d3);
        crc = @truncate(state);
    }

    while (index + 16 <= input.len) : (index += 16) {
        const d = std.mem.readInt(u128, input[index..][0..16], .little);
        crc = @truncate(d ^ @as(u128, crc));
    }

    while (index < input.len) : (index += 1) {
        const ti: u8 = @truncate(crc ^ input[index]);
        crc = Crc32.table[ti] ^ (crc >> 8);
    }
    return ~crc;
}

fn pclmulFold(state: u128, data: u128) u128 {
    var fold: u128 = state;
    const k: u128 = K_FOLD_128;
    asm volatile ("pclmulqdq $0x01, %[k], %[fold]"
        : [fold] "+x" (fold),
        : [k] "x" (k),
    );
    return state ^ fold ^ data;
}

pub fn crc32Hardware(input: []const u8) u32 {
    if (builtin.cpu.arch == .aarch64) {
        return crc32HardwareArm(input);
    }
    if (builtin.cpu.arch == .x86_64 or builtin.cpu.arch == .x86) {
        return crc32HardwareX86(input);
    }
    return crc32Slice16(input);
}

pub fn crc32cHardwareX86(input: []const u8) u32 {
    if (!(builtin.cpu.arch == .x86_64 or builtin.cpu.arch == .x86)) return crc32c(input);
    if (!cpuFeatureReport().crc32c_hardware_candidate) return crc32c(input);
    var crc: u64 = 0xffff_ffff;
    var index: usize = 0;
    if (builtin.cpu.arch == .x86_64) {
        while (index + 8 <= input.len) : (index += 8) {
            const value = std.mem.readInt(u64, input[index..][0..8], .little);
            crc = crc32cAsm64(crc, value);
        }
    }
    var crc32_acc: u32 = @truncate(crc);
    while (index + 4 <= input.len) : (index += 4) {
        const value = std.mem.readInt(u32, input[index..][0..4], .little);
        crc32_acc = crc32cAsm32(crc32_acc, value);
    }
    while (index < input.len) : (index += 1) {
        const table_index: u8 = @truncate(crc32_acc ^ input[index]);
        crc32_acc = Crc32C.table[table_index] ^ (crc32_acc >> 8);
    }
    return ~crc32_acc;
}

fn crc32cAsm64(acc_in: u64, value: u64) u64 {
    var acc = acc_in;
    asm volatile ("crc32q %[value], %[acc]"
        : [acc] "+r" (acc),
        : [value] "r" (value),
    );
    return acc;
}

fn crc32cAsm32(acc_in: u32, value: u32) u32 {
    var acc = acc_in;
    asm volatile ("crc32l %[value], %[acc]"
        : [acc] "+r" (acc),
        : [value] "r" (value),
    );
    return acc;
}

pub fn crc32cBest(input: []const u8) u32 {
    return switch (bestCrc32CDispatch()) {
        .scalar => crc32c(input),
        .slice8 => crc32cSlice8(input),
        .slice16 => crc32cSlice16(input),
        .slice32 => crc32cSlice32(input),
        .hardware => crc32cHardwareX86(input),
    };
}

pub fn bestCrc32CDispatch() Crc32CDispatch {
    return if (cpuFeatureReport().crc32c_hardware_candidate) .hardware else .slice32;
}

pub fn crc32c(input: []const u8) u32 {
    return Crc32C.hash(input);
}

/// Combine two already-finalized CRC-32C/Castagnoli digests.
///
/// `right_len` is the byte length of the payload that produced `right_crc`.
/// The returned digest is exactly `crc32c(left_payload ++ right_payload)`.
pub fn crc32cCombine(left_crc: u32, right_crc: u32, right_len: u64) u32 {
    return crcCombineReflected(Crc32C.polynomial_reflected, left_crc, right_crc, right_len);
}

pub fn crc32cSlice8(input: []const u8) u32 {
    return Crc32CSlice8.hash(input);
}

pub fn crc32cSlice16(input: []const u8) u32 {
    return Crc32CSlice16.hash(input);
}

pub fn crc32cSlice32(input: []const u8) u32 {
    return Crc32CSlice32.hash(input);
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

fn makeCrc32Slice4Tables(comptime polynomial: u32) [4][256]u32 {
    return makeCrc32SliceTables(4, polynomial);
}

fn makeCrc32SliceTables(comptime slices: usize, comptime polynomial: u32) [slices][256]u32 {
    @setEvalBranchQuota(200000);
    var tables: [slices][256]u32 = undefined;
    tables[0] = makeCrc32Table(polynomial);
    for (1..slices) |i| {
        for (0..256) |j| {
            const prev = tables[i - 1][j];
            tables[i][j] = (prev >> 8) ^ tables[0][prev & 0xff];
        }
    }
    return tables;
}

const gf2_matrix_dim = 32;

fn crcCombineReflected(comptime polynomial: u32, left_crc: u32, right_crc: u32, right_len: u64) u32 {
    if (right_len == 0) return left_crc;

    var odd: [gf2_matrix_dim]u32 = undefined;
    var even: [gf2_matrix_dim]u32 = undefined;

    // `odd` starts as the operator for appending one zero bit to a reflected
    // CRC state. Squaring advances it to two/four/eight zero-bit operators.
    // The first operator applied in the loop is therefore one zero byte, and
    // subsequent squarings cover powers of two bytes in `right_len`.
    odd[0] = polynomial;
    var row: u32 = 1;
    for (1..gf2_matrix_dim) |index| {
        odd[index] = row;
        row <<= 1;
    }

    gf2MatrixSquare(&even, &odd); // two zero bits
    gf2MatrixSquare(&odd, &even); // four zero bits

    var len = right_len;
    var combined = left_crc;
    while (len != 0) {
        gf2MatrixSquare(&even, &odd); // one zero byte, then powers of two bytes
        if ((len & 1) != 0) combined = gf2MatrixTimes(&even, combined);
        len >>= 1;
        if (len == 0) break;

        gf2MatrixSquare(&odd, &even);
        if ((len & 1) != 0) combined = gf2MatrixTimes(&odd, combined);
        len >>= 1;
    }

    return combined ^ right_crc;
}

fn gf2MatrixTimes(matrix: *const [gf2_matrix_dim]u32, vector_in: u32) u32 {
    var vector = vector_in;
    var index: usize = 0;
    var sum: u32 = 0;
    while (vector != 0) : ({
        vector >>= 1;
        index += 1;
    }) {
        if ((vector & 1) != 0) sum ^= matrix[index];
    }
    return sum;
}

fn gf2MatrixSquare(square: *[gf2_matrix_dim]u32, matrix: *const [gf2_matrix_dim]u32) void {
    for (0..gf2_matrix_dim) |index| {
        square[index] = gf2MatrixTimes(matrix, matrix[index]);
    }
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

test "Adler-32 combine matches one-shot and is associative" {
    const left_cases = [_][]const u8{
        "",
        "left",
        "prefix data " ** 17,
        "0123456789abcdef" ** 129,
    };
    const right_cases = [_][]const u8{
        "",
        "right",
        "suffix data " ** 19,
        "fedcba9876543210" ** 127,
    };

    for (left_cases) |left| {
        for (right_cases) |right| {
            var joined = std.ArrayList(u8).empty;
            defer joined.deinit(std.testing.allocator);
            try joined.appendSlice(std.testing.allocator, left);
            try joined.appendSlice(std.testing.allocator, right);
            try std.testing.expectEqual(
                adler32(joined.items),
                adler32Combine(adler32(left), adler32(right), right.len),
            );
        }
    }

    const input = ("parallel adler combine " ** 257) ++ ("0123456789abcdef" ** 73);
    const a = input[0..13];
    const b = input[13..2048];
    const c = input[2048..];
    const ab = adler32Combine(adler32(a), adler32(b), b.len);
    const abc = adler32Combine(ab, adler32(c), c.len);
    const bc = adler32Combine(adler32(b), adler32(c), c.len);
    const a_bc = adler32Combine(adler32(a), bc, b.len + c.len);
    try std.testing.expectEqual(adler32(input), abc);
    try std.testing.expectEqual(adler32(input), a_bc);
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

test "CRC-32C known Castagnoli vectors" {
    try std.testing.expectEqual(@as(u32, 0x0000_0000), crc32c(""));
    try std.testing.expectEqual(@as(u32, 0xc1d0_4330), crc32c("a"));
    try std.testing.expectEqual(@as(u32, 0x364b_3fb7), crc32c("abc"));
    try std.testing.expectEqual(@as(u32, 0x81d9_0e1b), crc32c("Hello"));
    try std.testing.expectEqual(@as(u32, 0xe306_9283), crc32c("123456789"));
    try std.testing.expectEqual(@as(u32, 0x2262_0404), crc32c("The quick brown fox jumps over the lazy dog"));
}

test "CRC-32C streaming matches one-shot" {
    const input = "storage-network-castagnoli" ** 211;
    var state = Crc32C.init();
    state.update(input[0..13]);
    state.update(input[13..1024]);
    state.update(input[1024..]);
    try std.testing.expectEqual(crc32c(input), state.digest());
}

test "CRC-32C slice-by-8 slice-by-16 and slice-by-32 match scalar" {
    const cases = [_][]const u8{
        "",
        "a",
        "abc",
        "123456789",
        "The quick brown fox jumps over the lazy dog" ** 97,
    };
    for (cases) |case| {
        try std.testing.expectEqual(crc32c(case), crc32cSlice8(case));
        try std.testing.expectEqual(crc32c(case), crc32cSlice16(case));
        try std.testing.expectEqual(crc32c(case), crc32cSlice32(case));
    }
}

test "CRC implementations match Zig std catalog" {
    const cases = [_][]const u8{
        "",
        "abc",
        "123456789",
        "The quick brown fox jumps over the lazy dog",
    };
    for (cases) |case| {
        try std.testing.expectEqual(std.hash.crc.Crc32IsoHdlc.hash(case), crc32(case));
        try std.testing.expectEqual(std.hash.crc.Crc32Iscsi.hash(case), crc32c(case));
    }
}

test "CRC-32 slice-by-4 slice-by-8 slice-by-16 and slice-by-32 match scalar" {
    const cases = [_][]const u8{
        "",
        "a",
        "abc",
        "123456789",
        "The quick brown fox jumps over the lazy dog" ** 97,
    };
    for (cases) |case| {
        try std.testing.expectEqual(crc32(case), crc32Slice4(case));
        try std.testing.expectEqual(crc32(case), crc32Slice8(case));
        try std.testing.expectEqual(crc32(case), crc32Slice16(case));
        try std.testing.expectEqual(crc32(case), crc32Slice32(case));
    }
}

test "CRC combine matches one-shot for IEEE and Castagnoli" {
    const left_cases = [_][]const u8{
        "",
        "left",
        "prefix data " ** 17,
        "0123456789abcdef" ** 129,
    };
    const right_cases = [_][]const u8{
        "",
        "right",
        "suffix data " ** 19,
        "fedcba9876543210" ** 127,
    };

    for (left_cases) |left| {
        for (right_cases) |right| {
            var joined = std.ArrayList(u8).empty;
            defer joined.deinit(std.testing.allocator);
            try joined.appendSlice(std.testing.allocator, left);
            try joined.appendSlice(std.testing.allocator, right);

            try std.testing.expectEqual(
                crc32(joined.items),
                crc32Combine(crc32(left), crc32(right), right.len),
            );
            try std.testing.expectEqual(
                crc32c(joined.items),
                crc32cCombine(crc32c(left), crc32c(right), right.len),
            );
        }
    }
}

test "CRC combine is associative across block boundaries" {
    const input = ("parallel checksum combine " ** 257) ++ ("0123456789abcdef" ** 73);
    const a = input[0..13];
    const b = input[13..2048];
    const c = input[2048..];

    const ab_crc32 = crc32Combine(crc32(a), crc32(b), b.len);
    const abc_crc32 = crc32Combine(ab_crc32, crc32(c), c.len);
    const bc_crc32 = crc32Combine(crc32(b), crc32(c), c.len);
    const a_bc_crc32 = crc32Combine(crc32(a), bc_crc32, b.len + c.len);
    try std.testing.expectEqual(crc32(input), abc_crc32);
    try std.testing.expectEqual(crc32(input), a_bc_crc32);

    const ab_crc32c = crc32cCombine(crc32c(a), crc32c(b), b.len);
    const abc_crc32c = crc32cCombine(ab_crc32c, crc32c(c), c.len);
    const bc_crc32c = crc32cCombine(crc32c(b), crc32c(c), c.len);
    const a_bc_crc32c = crc32cCombine(crc32c(a), bc_crc32c, b.len + c.len);
    try std.testing.expectEqual(crc32c(input), abc_crc32c);
    try std.testing.expectEqual(crc32c(input), a_bc_crc32c);
}

test "CRC-32 best dispatch matches scalar" {
    const input = "dispatch checksum" ** 31;
    try std.testing.expectEqual(crc32(input), crc32Best(input));
    if (builtin.cpu.arch == .aarch64 and cpuFeatureReport().arm_crc32) {
        try std.testing.expectEqual(Crc32Dispatch.hardware, bestCrc32Dispatch());
    } else {
        try std.testing.expectEqual(Crc32Dispatch.slice32, bestCrc32Dispatch());
    }
}

test "CPU feature report keeps IEEE CRC32 dispatch conservative" {
    const report = cpuFeatureReport();
    if (report.ieee_crc32_pclmul_candidate) try std.testing.expect(report.x86_pclmul);
    if (builtin.cpu.arch == .aarch64) {
        try std.testing.expectEqual(report.arm_crc32, report.ieee_crc32_uses_hardware);
    } else {
        try std.testing.expect(!report.ieee_crc32_uses_hardware);
    }
    if (report.crc32c_hardware_candidate) try std.testing.expect(report.x86_sse42);
}

test "CRC-32C hardware path matches table path" {
    const cases = [_][]const u8{ "", "a", "abc", "123456789", "The quick brown fox jumps over the lazy dog" ** 33 };
    for (cases) |case| {
        try std.testing.expectEqual(crc32c(case), crc32cBest(case));
        try std.testing.expectEqual(crc32c(case), crc32cHardwareX86(case));
    }
    if (cpuFeatureReport().crc32c_hardware_candidate) {
        try std.testing.expectEqual(Crc32CDispatch.hardware, bestCrc32CDispatch());
    } else {
        try std.testing.expectEqual(Crc32CDispatch.slice32, bestCrc32CDispatch());
    }
}
