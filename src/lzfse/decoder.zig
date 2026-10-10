const std = @import("std");
const core = @import("../core.zig");
const format = @import("format.zig");
const fse = @import("fse.zig");

pub const Error = core.Error || format.Error || fse.Error || error{
    InvalidLzfseStream,
};

pub fn decodePayloadInto(
    header: format.CompressedHeader,
    literal_payload: []const u8,
    lmd_payload: []const u8,
    output: []u8,
    block_output_offset: usize,
) Error!usize {
    if (literal_payload.len != header.literal_payload_size or
        lmd_payload.len != header.lmd_payload_size)
        return error.InvalidLzfseStream;
    const block_output_end = std.math.add(usize, block_output_offset, header.raw_size) catch
        return error.IntegerOverflow;
    if (output.len < block_output_end) return error.OutputTooSmall;

    var literals: [format.max_literal_count]u8 = undefined;
    if (header.literal_count != 0) {
        var table: [format.literal_state_count]fse.DecoderEntry = undefined;
        try fse.initDecoderTable(
            format.literal_state_count,
            &header.literal_frequencies,
            &table,
        );
        var reader = try fse.BitReader.init(literal_payload, header.literal_bits);
        var states = header.literal_states;
        var index: usize = 0;
        while (index < header.literal_count) : (index += 4) {
            literals[index] = try fse.decodeSymbol(&states[0], &table, &reader);
            literals[index + 1] = try fse.decodeSymbol(&states[1], &table, &reader);
            literals[index + 2] = try fse.decodeSymbol(&states[2], &table, &reader);
            literals[index + 3] = try fse.decodeSymbol(&states[3], &table, &reader);
        }
    }

    if (header.match_count == 0) {
        if (header.raw_size != 0 or header.literal_count != 0)
            return error.InvalidLzfseStream;
        return 0;
    }

    var l_table: [format.l_state_count]fse.ValueDecoderEntry = undefined;
    var m_table: [format.m_state_count]fse.ValueDecoderEntry = undefined;
    var d_table: [format.d_state_count]fse.ValueDecoderEntry = undefined;
    try fse.initValueDecoderTable(
        format.l_state_count,
        &header.l_frequencies,
        &format.l_extra_bits,
        &format.l_base_value,
        &l_table,
    );
    try fse.initValueDecoderTable(
        format.m_state_count,
        &header.m_frequencies,
        &format.m_extra_bits,
        &format.m_base_value,
        &m_table,
    );
    try fse.initValueDecoderTable(
        format.d_state_count,
        &header.d_frequencies,
        &format.d_extra_bits,
        &format.d_base_value,
        &d_table,
    );

    var reader = try fse.BitReader.init(lmd_payload, header.lmd_bits);
    var l_state = header.l_state;
    var m_state = header.m_state;
    var d_state = header.d_state;
    var previous_distance: ?usize = null;
    var literal_offset: usize = 0;
    var output_offset = block_output_offset;
    for (0..header.match_count) |_| {
        const literal_len = try positiveValue(try fse.decodeValue(&l_state, &l_table, &reader));
        const match_len = try positiveValue(try fse.decodeValue(&m_state, &m_table, &reader));
        const decoded_distance = try positiveValue(try fse.decodeValue(&d_state, &d_table, &reader));
        if (decoded_distance != 0) previous_distance = decoded_distance;
        const distance = previous_distance orelse return error.InvalidLzfseStream;

        const literal_end = try checkedEnd(literal_offset, literal_len, header.literal_count);
        const after_literals = try checkedEnd(output_offset, literal_len, block_output_end);
        @memcpy(output[output_offset..after_literals], literals[literal_offset..literal_end]);
        literal_offset = literal_end;
        output_offset = after_literals;

        if (match_len != 0) {
            if (distance == 0 or distance > output_offset) return error.InvalidLzfseStream;
            const match_end = try checkedEnd(output_offset, match_len, block_output_end);
            var index = output_offset;
            while (index < match_end) : (index += 1) output[index] = output[index - distance];
            output_offset = match_end;
        }
    }
    // Literal streams are interleaved four ways, so the encoder pads the
    // decoded literal buffer to a multiple of four. Up to three terminal
    // bytes are intentionally not referenced by any L/M/D record.
    if (header.literal_count - literal_offset > 3 or output_offset != block_output_end)
        return error.SizeMismatch;
    return header.raw_size;
}

fn positiveValue(value: i32) Error!usize {
    if (value < 0) return error.InvalidLzfseStream;
    return @intCast(value);
}

fn checkedEnd(start: usize, size: usize, limit: usize) Error!usize {
    const end = std.math.add(usize, start, size) catch return error.IntegerOverflow;
    if (end > limit) return error.InvalidLzfseStream;
    return end;
}
