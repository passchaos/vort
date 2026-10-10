const std = @import("std");
const core = @import("../core.zig");
const fse = @import("fse.zig");

pub const Error = core.Error || fse.Error || error{
    InvalidLzfseStream,
};

pub const end_of_stream_magic: u32 = 0x2478_7662;
pub const uncompressed_magic: u32 = 0x2d78_7662;
pub const compressed_v1_magic: u32 = 0x3178_7662;
pub const compressed_v2_magic: u32 = 0x3278_7662;
pub const compressed_lzvn_magic: u32 = 0x6e78_7662;

pub const max_match_count: usize = 10_000;
pub const max_literal_count: usize = 4 * max_match_count;
pub const literal_state_count: usize = 1024;
pub const l_state_count: usize = 64;
pub const m_state_count: usize = 64;
pub const d_state_count: usize = 256;
pub const l_symbol_count: usize = 20;
pub const m_symbol_count: usize = 20;
pub const d_symbol_count: usize = 64;
pub const literal_symbol_count: usize = 256;
pub const frequency_count: usize = l_symbol_count + m_symbol_count +
    d_symbol_count + literal_symbol_count;
pub const v1_header_size: usize = 772;
pub const v2_fixed_header_size: usize = 32;
pub const v2_max_header_size: usize = v2_fixed_header_size + 2 * frequency_count;

pub const l_extra_bits = [l_symbol_count]u8{
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 3, 5, 8,
};
pub const l_base_value = [l_symbol_count]i32{
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 20, 28, 60,
};
pub const m_extra_bits = [m_symbol_count]u8{
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 5, 8, 11,
};
pub const m_base_value = [m_symbol_count]i32{
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 24, 56, 312,
};
pub const d_extra_bits = [d_symbol_count]u8{
    0,  0,  0,  0,  1,  1,  1,  1,  2,  2,  2,  2,  3,  3,  3,  3,
    4,  4,  4,  4,  5,  5,  5,  5,  6,  6,  6,  6,  7,  7,  7,  7,
    8,  8,  8,  8,  9,  9,  9,  9,  10, 10, 10, 10, 11, 11, 11, 11,
    12, 12, 12, 12, 13, 13, 13, 13, 14, 14, 14, 14, 15, 15, 15, 15,
};
pub const d_base_value = [d_symbol_count]i32{
    0,     1,     2,     3,      4,      6,      8,      10,
    12,    16,    20,    24,     28,     36,     44,     52,
    60,    76,    92,    108,    124,    156,    188,    220,
    252,   316,   380,   444,    508,    636,    764,    892,
    1020,  1276,  1532,  1788,   2044,   2556,   3068,   3580,
    4092,  5116,  6140,  7164,   8188,   10236,  12284,  14332,
    16380, 20476, 24572, 28668,  32764,  40956,  49148,  57340,
    65532, 81916, 98300, 114684, 131068, 163836, 196604, 229372,
};

pub const CompressedHeader = struct {
    header_size: usize,
    raw_size: usize,
    literal_count: usize,
    match_count: usize,
    literal_payload_size: usize,
    lmd_payload_size: usize,
    literal_bits: i8,
    literal_states: [4]u16,
    lmd_bits: i8,
    l_state: u16,
    m_state: u16,
    d_state: u16,
    l_frequencies: [l_symbol_count]u16,
    m_frequencies: [m_symbol_count]u16,
    d_frequencies: [d_symbol_count]u16,
    literal_frequencies: [literal_symbol_count]u16,

    pub fn payloadSize(self: CompressedHeader) Error!usize {
        return std.math.add(usize, self.literal_payload_size, self.lmd_payload_size) catch
            return error.IntegerOverflow;
    }
};

pub fn parseCompressedHeader(input: []const u8) Error!CompressedHeader {
    if (input.len < 4) return error.TruncatedFrame;
    return switch (std.mem.readInt(u32, input[0..4], .little)) {
        compressed_v1_magic => parseV1(input),
        compressed_v2_magic => parseV2(input),
        else => error.InvalidLzfseStream,
    };
}

fn parseV1(input: []const u8) Error!CompressedHeader {
    if (input.len < v1_header_size) return error.TruncatedFrame;
    const payload_size: usize = readU32(input, 8);
    var header = CompressedHeader{
        .header_size = v1_header_size,
        .raw_size = readU32(input, 4),
        .literal_count = readU32(input, 12),
        .match_count = readU32(input, 16),
        .literal_payload_size = readU32(input, 20),
        .lmd_payload_size = readU32(input, 24),
        .literal_bits = std.math.cast(i8, readI32(input, 28)) orelse
            return error.InvalidLzfseStream,
        .literal_states = .{
            readU16(input, 32),
            readU16(input, 34),
            readU16(input, 36),
            readU16(input, 38),
        },
        .lmd_bits = std.math.cast(i8, readI32(input, 40)) orelse
            return error.InvalidLzfseStream,
        .l_state = readU16(input, 44),
        .m_state = readU16(input, 46),
        .d_state = readU16(input, 48),
        .l_frequencies = undefined,
        .m_frequencies = undefined,
        .d_frequencies = undefined,
        .literal_frequencies = undefined,
    };
    var offset: usize = 50;
    readFrequencyArray(l_symbol_count, input, &offset, &header.l_frequencies);
    readFrequencyArray(m_symbol_count, input, &offset, &header.m_frequencies);
    readFrequencyArray(d_symbol_count, input, &offset, &header.d_frequencies);
    readFrequencyArray(literal_symbol_count, input, &offset, &header.literal_frequencies);
    if (payload_size != try header.payloadSize()) return error.InvalidLzfseStream;
    try validateHeader(header);
    return header;
}

fn parseV2(input: []const u8) Error!CompressedHeader {
    if (input.len < v2_fixed_header_size) return error.TruncatedFrame;
    const packed0 = readU64(input, 8);
    const packed1 = readU64(input, 16);
    const packed2 = readU64(input, 24);
    const header_size: usize = @intCast(field(packed2, 0, 32));
    if (header_size < v2_fixed_header_size or header_size > v2_max_header_size)
        return error.InvalidLzfseStream;
    if (input.len < header_size) return error.TruncatedFrame;
    var frequencies: [frequency_count]u16 = @splat(0);
    try decodeFrequencies(input[v2_fixed_header_size..header_size], &frequencies);

    var header = CompressedHeader{
        .header_size = header_size,
        .raw_size = readU32(input, 4),
        .literal_count = @intCast(field(packed0, 0, 20)),
        .match_count = @intCast(field(packed0, 40, 20)),
        .literal_payload_size = @intCast(field(packed0, 20, 20)),
        .lmd_payload_size = @intCast(field(packed1, 40, 20)),
        .literal_bits = @as(i8, @intCast(field(packed0, 60, 3))) - 7,
        .literal_states = .{
            @intCast(field(packed1, 0, 10)),
            @intCast(field(packed1, 10, 10)),
            @intCast(field(packed1, 20, 10)),
            @intCast(field(packed1, 30, 10)),
        },
        .lmd_bits = @as(i8, @intCast(field(packed1, 60, 3))) - 7,
        .l_state = @intCast(field(packed2, 32, 10)),
        .m_state = @intCast(field(packed2, 42, 10)),
        .d_state = @intCast(field(packed2, 52, 10)),
        .l_frequencies = undefined,
        .m_frequencies = undefined,
        .d_frequencies = undefined,
        .literal_frequencies = undefined,
    };
    var frequency_offset: usize = 0;
    takeFrequencies(l_symbol_count, &frequencies, &frequency_offset, &header.l_frequencies);
    takeFrequencies(m_symbol_count, &frequencies, &frequency_offset, &header.m_frequencies);
    takeFrequencies(d_symbol_count, &frequencies, &frequency_offset, &header.d_frequencies);
    takeFrequencies(literal_symbol_count, &frequencies, &frequency_offset, &header.literal_frequencies);
    try validateHeader(header);
    return header;
}

fn validateHeader(header: CompressedHeader) Error!void {
    if (header.literal_count > max_literal_count or header.literal_count % 4 != 0 or
        header.match_count > max_match_count or
        header.literal_bits < -7 or header.literal_bits > 0 or
        header.lmd_bits < -7 or header.lmd_bits > 0)
        return error.InvalidLzfseStream;
    for (header.literal_states) |state|
        if (state >= literal_state_count) return error.InvalidLzfseStream;
    if (header.l_state >= l_state_count or header.m_state >= m_state_count or
        header.d_state >= d_state_count)
        return error.InvalidLzfseStream;
    if (header.literal_count != 0)
        try fse.validateFrequencies(&header.literal_frequencies, literal_state_count);
    if (header.match_count != 0) {
        try fse.validateFrequencies(&header.l_frequencies, l_state_count);
        try fse.validateFrequencies(&header.m_frequencies, m_state_count);
        try fse.validateFrequencies(&header.d_frequencies, d_state_count);
    }
}

fn decodeFrequencies(input: []const u8, output: *[frequency_count]u16) Error!void {
    if (input.len == 0) return;
    const bit_len = std.math.mul(usize, input.len, 8) catch return error.IntegerOverflow;
    var bit_offset: usize = 0;
    for (output) |*frequency| {
        const bits = peekBits(input, bit_offset, 14);
        const selector = bits & 31;
        const bit_count: usize = frequency_bit_count[selector];
        if (bit_count > bit_len -| bit_offset) return error.InvalidLzfseStream;
        frequency.* = @intCast(if (bit_count == 8)
            8 + ((bits >> 4) & 0x0f)
        else if (bit_count == 14)
            24 + ((bits >> 4) & 0x03ff)
        else
            frequency_value[selector]);
        bit_offset += bit_count;
    }
    if ((bit_offset + 7) / 8 != input.len) return error.InvalidLzfseStream;
}

const frequency_bit_count = [32]u8{
    2, 3, 2, 5, 2, 3, 2, 8, 2, 3, 2, 5, 2, 3, 2, 14,
    2, 3, 2, 5, 2, 3, 2, 8, 2, 3, 2, 5, 2, 3, 2, 14,
};
const frequency_value = [32]u16{
    0, 2, 1, 4, 0, 3, 1, 0, 0, 2, 1, 5, 0, 3, 1, 0,
    0, 2, 1, 6, 0, 3, 1, 0, 0, 2, 1, 7, 0, 3, 1, 0,
};

fn peekBits(input: []const u8, start: usize, count: usize) u32 {
    var value: u32 = 0;
    for (0..count) |index| {
        const bit = start + index;
        if (bit >= input.len * 8) break;
        value |= @as(u32, (input[bit / 8] >> @intCast(bit & 7)) & 1) <<
            @intCast(index);
    }
    return value;
}

fn field(value: u64, offset: u6, width: u6) u64 {
    return (value >> offset) & ((@as(u64, 1) << width) - 1);
}

fn readFrequencyArray(
    comptime len: usize,
    input: []const u8,
    offset: *usize,
    output: *[len]u16,
) void {
    for (output) |*frequency| {
        frequency.* = readU16(input, offset.*);
        offset.* += 2;
    }
}

fn takeFrequencies(
    comptime len: usize,
    input: *const [frequency_count]u16,
    offset: *usize,
    output: *[len]u16,
) void {
    @memcpy(output, input[offset.*..][0..len]);
    offset.* += len;
}

fn readU16(input: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, input[offset..][0..2], .little);
}

fn readU32(input: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, input[offset..][0..4], .little);
}

fn readI32(input: []const u8, offset: usize) i32 {
    return @bitCast(readU32(input, offset));
}

fn readU64(input: []const u8, offset: usize) u64 {
    return std.mem.readInt(u64, input[offset..][0..8], .little);
}

test "LZFSE compressed V2 frequency value codes" {
    var output: [frequency_count]u16 = @splat(0);
    // Four zero-frequency symbols fit in each zero byte.
    var encoded: [frequency_count / 4]u8 = @splat(0);
    try decodeFrequencies(&encoded, &output);
    for (output) |frequency| try std.testing.expectEqual(@as(u16, 0), frequency);
}
