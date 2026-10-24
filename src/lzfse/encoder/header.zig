const std = @import("std");
const format = @import("../format.zig");
const decoder = @import("../fse.zig");
const options = @import("../encode_options.zig");
const bit_writer = @import("bit_writer.zig");

pub fn frequencyCode(frequency: u16) !struct { value: u32, width: u8 } {
    if (frequency > format.literal_state_count) return error.InvalidLzfseStream;
    return if (frequency < 2)
        .{ .value = @as(u32, frequency) * 2, .width = 2 }
    else if (frequency < 4)
        .{ .value = 1 + @as(u32, frequency - 2) * 4, .width = 3 }
    else if (frequency < 8)
        .{ .value = 3 + @as(u32, frequency - 4) * 8, .width = 5 }
    else if (frequency < 24)
        .{ .value = 7 + @as(u32, frequency - 8) * 16, .width = 8 }
    else
        .{ .value = 15 + @as(u32, frequency - 24) * 16, .width = 14 };
}

pub fn encodeAlloc(allocator: std.mem.Allocator, value: format.CompressedHeader, version: options.FseVersion) ![]u8 {
    try validate(value, version);
    const payload_size = try value.payloadSize();
    if (version == .v1) {
        const output = try allocator.alloc(u8, format.v1_header_size);
        @memset(output, 0);
        write32(output, 0, format.compressed_v1_magic);
        write32(output, 4, @intCast(value.raw_size));
        write32(output, 8, @intCast(payload_size));
        write32(output, 12, @intCast(value.literal_count));
        write32(output, 16, @intCast(value.match_count));
        write32(output, 20, @intCast(value.literal_payload_size));
        write32(output, 24, @intCast(value.lmd_payload_size));
        write32(output, 28, @bitCast(@as(i32, value.literal_bits)));
        for (value.literal_states, 0..) |state, index| write16(output, 32 + 2 * index, state);
        write32(output, 40, @bitCast(@as(i32, value.lmd_bits)));
        write16(output, 44, value.l_state);
        write16(output, 46, value.m_state);
        write16(output, 48, value.d_state);
        var offset: usize = 50;
        for (frequencySlices(&value)) |frequencies| for (frequencies) |frequency| {
            write16(output, offset, frequency);
            offset += 2;
        };
        return output;
    }

    var frequencies = bit_writer.Writer{};
    defer frequencies.deinit(allocator);
    for (frequencySlices(&value)) |slice| for (slice) |frequency| {
        const code = try frequencyCode(frequency);
        try frequencies.push(allocator, code.value, code.width);
    };
    _ = try frequencies.finish(allocator);
    const header_size = format.v2_fixed_header_size + frequencies.bytes.items.len;
    if (header_size > format.v2_max_header_size) return error.InvalidLzfseStream;
    const output = try allocator.alloc(u8, header_size);
    @memset(output, 0);
    write32(output, 0, format.compressed_v2_magic);
    write32(output, 4, @intCast(value.raw_size));
    const p0 = @as(u64, @intCast(value.literal_count)) |
        (@as(u64, @intCast(value.literal_payload_size)) << 20) |
        (@as(u64, @intCast(value.match_count)) << 40) |
        (@as(u64, @intCast(@as(i16, value.literal_bits) + 7)) << 60);
    var p1 = (@as(u64, @intCast(value.lmd_payload_size)) << 40) |
        (@as(u64, @intCast(@as(i16, value.lmd_bits) + 7)) << 60);
    for (value.literal_states, 0..) |state, index| p1 |= @as(u64, state) << @intCast(index * 10);
    const p2 = @as(u64, @intCast(header_size)) | (@as(u64, value.l_state) << 32) |
        (@as(u64, value.m_state) << 42) | (@as(u64, value.d_state) << 52);
    std.mem.writeInt(u64, output[8..16], p0, .little);
    std.mem.writeInt(u64, output[16..24], p1, .little);
    std.mem.writeInt(u64, output[24..32], p2, .little);
    @memcpy(output[format.v2_fixed_header_size..], frequencies.bytes.items);
    return output;
}

fn validate(value: format.CompressedHeader, version: options.FseVersion) !void {
    const payload_size = try value.payloadSize();
    if (value.raw_size > std.math.maxInt(u32) or payload_size > std.math.maxInt(u32) or
        value.literal_count > format.max_literal_count or value.literal_count % 4 != 0 or
        value.match_count > format.max_match_count or value.literal_bits < -7 or value.literal_bits > 0 or
        value.lmd_bits < -7 or value.lmd_bits > 0 or
        (value.literal_payload_size == 0 and value.literal_bits != 0) or
        (value.lmd_payload_size == 0 and value.lmd_bits != 0)) return error.InvalidLzfseStream;
    if (version == .v2 and (value.literal_payload_size >= @as(usize, 1) << 20 or
        value.lmd_payload_size >= @as(usize, 1) << 20)) return error.InvalidLzfseStream;
    for (value.literal_states) |state| if (state >= format.literal_state_count) return error.InvalidLzfseStream;
    if (value.l_state >= format.l_state_count or value.m_state >= format.m_state_count or
        value.d_state >= format.d_state_count) return error.InvalidLzfseStream;
    try decoder.validateFrequencies(&value.l_frequencies, format.l_state_count);
    try decoder.validateFrequencies(&value.m_frequencies, format.m_state_count);
    try decoder.validateFrequencies(&value.d_frequencies, format.d_state_count);
    try decoder.validateFrequencies(&value.literal_frequencies, format.literal_state_count);
}

fn frequencySlices(value: *const format.CompressedHeader) [4][]const u16 {
    return .{ &value.l_frequencies, &value.m_frequencies, &value.d_frequencies, &value.literal_frequencies };
}

fn write16(output: []u8, offset: usize, value: u16) void {
    std.mem.writeInt(u16, output[offset..][0..2], value, .little);
}
fn write32(output: []u8, offset: usize, value: u32) void {
    std.mem.writeInt(u32, output[offset..][0..4], value, .little);
}

test {
    _ = @import("header_tests.zig");
}
