const std = @import("std");
const builtin = @import("builtin");

/// Largest portable input chunk before reducing the two Adler sums.
/// This is zlib's NMAX bound for keeping the scalar recurrence within u32.
pub const nmax: usize = 5_552;
pub const modulus: u32 = 65_521;

const portable_vector_len: usize = 64;
const PortableBytes = @Vector(portable_vector_len, u8);
const PortableWide = @Vector(portable_vector_len, u32);
const portable_weights: PortableWide = .{
    64, 63, 62, 61, 60, 59, 58, 57, 56, 55, 54, 53, 52, 51, 50, 49,
    48, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35, 34, 33,
    32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17,
    16, 15, 14, 13, 12, 11, 10, 9,  8,  7,  6,  5,  4,  3,  2,  1,
};

const PortableFold = struct {
    sum: u32,
    weighted: u32,
};

inline fn foldPortable(bytes: [portable_vector_len]u8) PortableFold {
    const bytes_u8: PortableBytes = bytes;
    const values: PortableWide = bytes_u8;
    return .{
        .sum = @reduce(.Add, values),
        .weighted = @reduce(.Add, values * portable_weights),
    };
}

const avx2_block_len: usize = 32;
const avx2_chunk_len: usize = nmax / avx2_block_len * avx2_block_len;
const Avx2Bytes = @Vector(avx2_block_len, u8);
const Avx2SignedBytes = @Vector(avx2_block_len, i8);
const Avx2HalfWords = @Vector(avx2_block_len / 2, i16);
const Avx2Groups = @Vector(avx2_block_len / 4, u32);
const avx2_weights: Avx2SignedBytes = @bitCast(@as(Avx2Bytes, .{
    32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17,
    16, 15, 14, 13, 12, 11, 10, 9,  8,  7,  6,  5,  4,  3,  2,  1,
}));
const avx2_halfword_ones: Avx2HalfWords = @splat(1);

pub const Backend = enum {
    portable,
    avx2,
};

/// Report the implementation compiled for this target.
///
/// Vort keeps the portable vector kernel as the semantic fallback. The AVX2
/// path is selected only when the target feature set guarantees that its small
/// inline-assembly primitives are legal; there is no unchecked runtime jump.
pub fn bestBackend() Backend {
    if (comptime hasAvx2()) return .avx2;
    return .portable;
}

fn hasAvx2() bool {
    return switch (builtin.cpu.arch) {
        .x86, .x86_64 => std.Target.x86.featureSetHas(builtin.cpu.features, .avx2),
        else => false,
    };
}

/// Streaming Adler-32 state compatible with zlib's checksum definition.
pub const Adler32 = struct {
    a: u32 = 1,
    b: u32 = 0,

    pub fn init() Adler32 {
        return .{};
    }

    pub fn update(self: *Adler32, input: []const u8) void {
        if (comptime hasAvx2()) {
            updateAvx2(&self.a, &self.b, input);
        } else {
            updatePortable(&self.a, &self.b, input);
        }
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

pub fn hash(input: []const u8) u32 {
    return Adler32.hash(input);
}

fn updatePortable(state_a: *u32, state_b: *u32, input: []const u8) void {
    var index: usize = 0;
    var a = state_a.*;
    var b = state_b.*;
    while (index < input.len) {
        const chunk_len = @min(nmax, input.len - index);
        const chunk = input[index..][0..chunk_len];
        var chunk_index: usize = 0;
        while (chunk_index + portable_vector_len * 2 <= chunk.len) : (chunk_index += portable_vector_len * 2) {
            const first = foldPortable(
                chunk[chunk_index..][0..portable_vector_len].*,
            );
            const second = foldPortable(
                chunk[chunk_index + portable_vector_len ..][0..portable_vector_len].*,
            );
            // Preserve two consecutive 64-byte recurrences while exposing the
            // independent dot products to portable LLVM vector lowering.
            b += a * @as(u32, portable_vector_len * 2) +
                first.weighted +
                second.weighted +
                first.sum * @as(u32, portable_vector_len);
            a += first.sum + second.sum;
        }
        while (chunk_index + portable_vector_len <= chunk.len) : (chunk_index += portable_vector_len) {
            const folded = foldPortable(
                chunk[chunk_index..][0..portable_vector_len].*,
            );
            b += a * @as(u32, portable_vector_len) + folded.weighted;
            a += folded.sum;
        }
        while (chunk_index < chunk.len) : (chunk_index += 1) {
            a += chunk[chunk_index];
            b += a;
        }
        a %= modulus;
        b %= modulus;
        index += chunk_len;
    }
    state_a.* = a;
    state_b.* = b;
}

noinline fn updateAvx2(state_a: *u32, state_b: *u32, input: []const u8) void {
    var index: usize = 0;
    var a = state_a.*;
    var b = state_b.*;

    while (index < input.len) {
        // simd-adler32 uses the same floor(NMAX / 32) boundary. Making every
        // non-final chunk a whole number of blocks keeps the vector loop free
        // of a per-block bounds/remainder branch.
        const chunk_len = @min(avx2_chunk_len, input.len - index);
        const chunk = input[index..][0..chunk_len];
        const block_count = chunk.len / avx2_block_len;

        // These accumulators stay in YMM registers for the complete NMAX
        // chunk. In particular, do not horizontally reduce each 32/64-byte
        // fold: that was the main throughput loss in the older portable shape.
        var a_lanes: Avx2Groups = @splat(0);
        var b_lanes: Avx2Groups = .{ b, 0, 0, 0, 0, 0, 0, 0 };
        var prefix_lanes: Avx2Groups = .{
            a * @as(u32, @intCast(block_count)),
            0,
            0,
            0,
            0,
            0,
            0,
            0,
        };

        var chunk_index: usize = 0;
        while (chunk_index + avx2_block_len * 8 <= chunk.len) : (chunk_index += avx2_block_len * 8) {
            // Eight blocks amortize the loop branch and match the wide shape
            // LLVM produces for simd-adler32's standalone AVX2 function. Keep
            // the function itself out of line so this 256-byte kernel does not
            // bloat every DEFLATE/PNG caller that updates a checksum.
            inline for (0..8) |block| {
                const offset = chunk_index + block * avx2_block_len;
                const bytes: Avx2Bytes = chunk[offset..][0..avx2_block_len].*;
                prefix_lanes +%= a_lanes;
                a_lanes +%= sumByteGroupsAvx2(bytes);
                b_lanes +%= weightedByteGroupsAvx2(bytes);
            }
        }
        while (chunk_index + avx2_block_len <= chunk.len) : (chunk_index += avx2_block_len) {
            const bytes: Avx2Bytes = chunk[chunk_index..][0..avx2_block_len].*;
            prefix_lanes +%= a_lanes;
            a_lanes +%= sumByteGroupsAvx2(bytes);
            b_lanes +%= weightedByteGroupsAvx2(bytes);
        }
        b_lanes +%= prefix_lanes << @splat(5);

        a +%= @reduce(.Add, a_lanes);
        b = @reduce(.Add, b_lanes);
        while (chunk_index < chunk.len) : (chunk_index += 1) {
            a +%= chunk[chunk_index];
            b +%= a;
        }
        a %= modulus;
        b %= modulus;
        index += chunk_len;
    }

    state_a.* = a;
    state_b.* = b;
}

inline fn sumByteGroupsAvx2(bytes: Avx2Bytes) Avx2Groups {
    const zero: Avx2Bytes = @splat(0);
    var sums: Avx2Groups = undefined;
    // VPSADBW writes four u64 sums. Viewed as eight u32 lanes, every odd lane
    // is zero, so VPADDD and the final horizontal u32 reduction are exact.
    asm ("vpsadbw %[zero], %[bytes], %[sums]"
        : [sums] "=x" (sums),
        : [bytes] "x" (bytes),
          [zero] "x" (zero),
    );
    return sums;
}

inline fn weightedByteGroupsAvx2(bytes: Avx2Bytes) Avx2Groups {
    var pairs: Avx2HalfWords = undefined;
    asm ("vpmaddubsw %[weights], %[bytes], %[pairs]"
        : [pairs] "=x" (pairs),
        : [bytes] "x" (bytes),
          [weights] "x" (avx2_weights),
    );
    var groups: Avx2Groups = undefined;
    asm ("vpmaddwd %[ones], %[pairs], %[groups]"
        : [groups] "=x" (groups),
        : [pairs] "x" (pairs),
          [ones] "x" (avx2_halfword_ones),
    );
    return groups;
}

fn referenceHash(input: []const u8) u32 {
    var a: u32 = 1;
    var b: u32 = 0;
    var index: usize = 0;
    while (index < input.len) {
        const chunk_len = @min(nmax, input.len - index);
        for (input[index..][0..chunk_len]) |byte| {
            a += byte;
            b += a;
        }
        a %= modulus;
        b %= modulus;
        index += chunk_len;
    }
    return (b << 16) | a;
}

test "known zlib vectors" {
    try std.testing.expectEqual(@as(u32, 0x0000_0001), hash(""));
    try std.testing.expectEqual(@as(u32, 0x0062_0062), hash("a"));
    try std.testing.expectEqual(@as(u32, 0x024d_0127), hash("abc"));
    try std.testing.expectEqual(@as(u32, 0x058c_01f5), hash("Hello"));
    try std.testing.expectEqual(@as(u32, 0x11e6_0398), hash("Wikipedia"));
    try std.testing.expectEqual(@as(u32, 0x5bdc_0fda), hash("The quick brown fox jumps over the lazy dog"));
}

test "streaming matches one-shot across reduction boundary" {
    var input: [nmax * 2 + 137]u8 = undefined;
    for (&input, 0..) |*byte, i| {
        byte.* = @truncate((i * 131 + 17) & 0xff);
    }

    var state = Adler32.init();
    state.update(input[0..1]);
    state.update(input[1..5553]);
    state.update(input[5553..]);
    try std.testing.expectEqual(hash(&input), state.digest());
}

test "fragmented streaming updates match scalar oracle" {
    var input: [nmax * 3 + 193]u8 = undefined;
    for (&input, 0..) |*byte, i| {
        byte.* = @truncate(i * 197 + i / 11 + 29);
    }

    // Exercise empty/scalar-tail updates, complete AVX2 blocks, and NMAX
    // boundaries. Real streaming decoders mix scalar literals with wider
    // match/output spans, so transitions across unlike fragments are part of
    // the contract.
    const fragments = [_]usize{ 0, 1, 7, 31, 32, 33, 63, 64, 255, 256, nmax - 1, nmax, nmax + 1 };
    var state = Adler32.init();
    var offset: usize = 0;
    var fragment_index: usize = 0;
    while (offset < input.len) {
        const requested = fragments[fragment_index % fragments.len];
        fragment_index += 1;
        const len = @min(requested, input.len - offset);
        state.update(input[offset..][0..len]);
        offset += len;
    }
    try std.testing.expectEqual(referenceHash(&input), state.digest());
}

test "optimized and portable folds match scalar oracle at boundaries" {
    var input: [nmax * 2 + 257]u8 = undefined;
    for (&input, 0..) |*byte, i| {
        byte.* = @truncate(i * 131 + i / 7 + 17);
    }
    const lengths = [_]usize{
        0,
        1,
        avx2_block_len - 1,
        avx2_block_len,
        avx2_block_len + 1,
        portable_vector_len - 1,
        portable_vector_len,
        portable_vector_len + 1,
        portable_vector_len * 2 - 1,
        portable_vector_len * 2,
        portable_vector_len * 2 + 1,
        avx2_chunk_len - 1,
        avx2_chunk_len,
        avx2_chunk_len + 1,
        nmax - 1,
        nmax,
        nmax + 1,
        input.len - 31,
    };
    for ([_]usize{ 0, 1, 7, 31 }) |offset| {
        for (lengths) |requested_len| {
            const length = @min(requested_len, input.len - offset);
            const slice = input[offset..][0..length];
            const expected = referenceHash(slice);
            try std.testing.expectEqual(expected, hash(slice));

            var portable_a: u32 = 1;
            var portable_b: u32 = 0;
            updatePortable(&portable_a, &portable_b, slice);
            try std.testing.expectEqual(expected, (portable_b << 16) | portable_a);
        }
    }

    const maximum = [_]u8{255} ** nmax;
    try std.testing.expectEqual(referenceHash(&maximum), hash(&maximum));
}
