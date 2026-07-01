const std = @import("std");
const builtin = @import("builtin");

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

pub fn adler32(input: []const u8) u32 {
    return Adler32.hash(input);
}

pub fn crc32(input: []const u8) u32 {
    return Crc32.hash(input);
}

pub const Crc32Dispatch = enum { scalar, slice4, slice8, slice16 };
pub const Crc32CDispatch = enum { scalar, slice8, slice16, hardware };

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
        // SSE4.2 CRC32 is CRC32C/Castagnoli, not IEEE CRC-32 used by gzip.
        // PCLMUL may accelerate IEEE CRC-32 folding once an implementation is validated.
        report.ieee_crc32_pclmul_candidate = report.x86_pclmul;
        report.crc32c_hardware_candidate = report.x86_sse42;
        report.ieee_crc32_uses_hardware = false;
    } else if (builtin.cpu.arch == .aarch64) {
        const aarch64 = std.Target.aarch64;
        report.arm_crc32 = aarch64.featureSetHas(builtin.cpu.features, .crc);
        // ARM CRC32 instructions can accelerate IEEE CRC-32 after validation.
        report.ieee_crc32_uses_hardware = false;
    }
    return report;
}

pub fn bestCrc32Dispatch() Crc32Dispatch {
    return .slice16;
}

pub fn crc32Best(input: []const u8) u32 {
    return switch (bestCrc32Dispatch()) {
        .scalar => crc32(input),
        .slice4 => crc32Slice4(input),
        .slice8 => crc32Slice8(input),
        .slice16 => crc32Slice16(input),
    };
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
        .hardware => crc32cHardwareX86(input),
    };
}

pub fn bestCrc32CDispatch() Crc32CDispatch {
    return if (cpuFeatureReport().crc32c_hardware_candidate) .hardware else .slice16;
}

pub fn crc32c(input: []const u8) u32 {
    return Crc32C.hash(input);
}

pub fn crc32cSlice8(input: []const u8) u32 {
    return Crc32CSlice8.hash(input);
}

pub fn crc32cSlice16(input: []const u8) u32 {
    return Crc32CSlice16.hash(input);
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
    @setEvalBranchQuota(50000);
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

test "CRC-32C slice-by-8 and slice-by-16 match scalar" {
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

test "CRC-32 slice-by-4 slice-by-8 and slice-by-16 match scalar" {
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
    }
}

test "CRC-32 best dispatch matches scalar" {
    const input = "dispatch checksum" ** 31;
    try std.testing.expectEqual(crc32(input), crc32Best(input));
    try std.testing.expectEqual(Crc32Dispatch.slice16, bestCrc32Dispatch());
}

test "CPU feature report keeps IEEE CRC32 dispatch conservative" {
    const report = cpuFeatureReport();
    try std.testing.expect(!report.ieee_crc32_uses_hardware);
    if (report.ieee_crc32_pclmul_candidate) try std.testing.expect(report.x86_pclmul);
    if (builtin.cpu.arch == .aarch64 and report.arm_crc32) try std.testing.expect(!report.ieee_crc32_uses_hardware);
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
        try std.testing.expectEqual(Crc32CDispatch.slice16, bestCrc32CDispatch());
    }
}
