const std = @import("std");
const core = @import("core.zig");

pub const Error = core.Error || error{InvalidLzoStream};

const m2_max_offset: usize = 0x0800;
const m3_max_offset: usize = 0x4000;
const min_zero_run_length: usize = 4;

/// Decode one complete LZO1X byte stream into caller-owned storage.
pub fn decodeInto(input: []const u8, output: []u8) Error!usize {
    if (input.len < 3) return error.TruncatedFrame;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    var state: u3 = 0;
    var bitstream_version: u8 = 0;

    if (input.len >= 5 and input[0] == 17) {
        bitstream_version = input[1];
        input_offset = 2;
    }

    if (input[input_offset] > 17) {
        const literal_len = @as(usize, input[input_offset]) - 17;
        input_offset += 1;
        try copyLiterals(input, &input_offset, output, &output_offset, literal_len);
        state = @intCast(@min(literal_len, 4));
    }

    while (true) {
        const token = try takeByte(input, &input_offset);
        var match_len: usize = undefined;
        var distance: usize = undefined;
        var trailing: usize = undefined;

        if (token < 16) {
            if (state == 0) {
                const literal_base = if (token == 0)
                    try extendedLength(input, &input_offset, 15)
                else
                    @as(usize, token);
                const literal_len = std.math.add(usize, literal_base, 3) catch
                    return error.IntegerOverflow;
                try copyLiterals(input, &input_offset, output, &output_offset, literal_len);
                state = 4;
                continue;
            }

            const offset_byte = try takeByte(input, &input_offset);
            trailing = token & 3;
            if (state != 4) {
                distance = 1 + @as(usize, token >> 2) + (@as(usize, offset_byte) << 2);
                match_len = 2;
            } else {
                distance = 1 + m2_max_offset + @as(usize, token >> 2) + (@as(usize, offset_byte) << 2);
                match_len = 3;
            }
        } else if (token >= 64) {
            const offset_byte = try takeByte(input, &input_offset);
            trailing = token & 3;
            distance = 1 + @as(usize, (token >> 2) & 7) + (@as(usize, offset_byte) << 3);
            match_len = @as(usize, token >> 5) + 1;
        } else if (token >= 32) {
            const length_base = if (token & 31 == 0)
                try extendedLength(input, &input_offset, 31)
            else
                @as(usize, token & 31);
            match_len = std.math.add(usize, length_base, 2) catch
                return error.IntegerOverflow;
            const encoded_offset = try takeLe16(input, &input_offset);
            trailing = encoded_offset & 3;
            distance = 1 + @as(usize, encoded_offset >> 2);
        } else {
            const encoded_offset = try peekLe16(input, input_offset);
            if (bitstream_version != 0 and
                encoded_offset & 0xfffc == 0xfffc and
                token & 0xf8 == 0x18)
            {
                if (input.len - input_offset < 3) return error.TruncatedFrame;
                const zero_len = @as(usize, token & 7) |
                    (@as(usize, input[input_offset + 2]) << 3);
                try appendZeros(output, &output_offset, zero_len + min_zero_run_length);
                trailing = encoded_offset & 3;
                input_offset += 3;
                try copyTrailing(input, &input_offset, output, &output_offset, trailing, &state);
                continue;
            }

            const length_base = if (token & 7 == 0)
                try extendedLength(input, &input_offset, 7)
            else
                @as(usize, token & 7);
            match_len = std.math.add(usize, length_base, 2) catch
                return error.IntegerOverflow;
            const offset = try takeLe16(input, &input_offset);
            trailing = offset & 3;
            const high_offset = @as(usize, token & 8) << 11;
            const low_offset = @as(usize, offset >> 2);
            if (high_offset == 0 and low_offset == 0) {
                if (match_len != 3) return error.InvalidLzoStream;
                if (input_offset != input.len) return error.TrailingData;
                return output_offset;
            }
            distance = high_offset + low_offset + m3_max_offset;
        }

        try copyMatch(output, &output_offset, distance, match_len);
        try copyTrailing(input, &input_offset, output, &output_offset, trailing, &state);
    }
}

fn takeByte(input: []const u8, offset: *usize) Error!u8 {
    if (offset.* >= input.len) return error.TruncatedFrame;
    const byte = input[offset.*];
    offset.* += 1;
    return byte;
}

fn peekLe16(input: []const u8, offset: usize) Error!u16 {
    if (input.len -| offset < 2) return error.TruncatedFrame;
    return std.mem.readInt(u16, input[offset..][0..2], .little);
}

fn takeLe16(input: []const u8, offset: *usize) Error!u16 {
    const value = try peekLe16(input, offset.*);
    offset.* += 2;
    return value;
}

fn extendedLength(input: []const u8, offset: *usize, base: usize) Error!usize {
    var length = base;
    while (true) {
        const byte = try takeByte(input, offset);
        if (byte != 0)
            return std.math.add(usize, length, byte) catch error.IntegerOverflow;
        length = std.math.add(usize, length, 255) catch return error.IntegerOverflow;
    }
}

fn copyLiterals(
    input: []const u8,
    input_offset: *usize,
    output: []u8,
    output_offset: *usize,
    count: usize,
) Error!void {
    const input_end = std.math.add(usize, input_offset.*, count) catch
        return error.IntegerOverflow;
    if (input_end > input.len) return error.TruncatedFrame;
    const output_end = std.math.add(usize, output_offset.*, count) catch
        return error.IntegerOverflow;
    if (output_end > output.len) return error.OutputTooSmall;
    @memcpy(output[output_offset.*..output_end], input[input_offset.*..input_end]);
    input_offset.* = input_end;
    output_offset.* = output_end;
}

fn copyTrailing(
    input: []const u8,
    input_offset: *usize,
    output: []u8,
    output_offset: *usize,
    count: usize,
    state: *u3,
) Error!void {
    if (count > 3) return error.InvalidLzoStream;
    try copyLiterals(input, input_offset, output, output_offset, count);
    state.* = @intCast(count);
}

fn copyMatch(output: []u8, output_offset: *usize, distance: usize, count: usize) Error!void {
    if (distance == 0 or distance > output_offset.*) return error.InvalidLzoStream;
    const end = std.math.add(usize, output_offset.*, count) catch
        return error.IntegerOverflow;
    if (end > output.len) return error.OutputTooSmall;
    while (output_offset.* < end) {
        output[output_offset.*] = output[output_offset.* - distance];
        output_offset.* += 1;
    }
}

fn appendZeros(output: []u8, output_offset: *usize, count: usize) Error!void {
    const end = std.math.add(usize, output_offset.*, count) catch
        return error.IntegerOverflow;
    if (end > output.len) return error.OutputTooSmall;
    @memset(output[output_offset.*..end], 0);
    output_offset.* = end;
}

test "LZO1X decoder accepts empty and literal streams" {
    var empty: [0]u8 = .{};
    try std.testing.expectEqual(@as(usize, 0), try decodeInto(&.{ 17, 0, 0 }, &empty));

    var output: [5]u8 = undefined;
    try std.testing.expectEqual(
        @as(usize, 5),
        try decodeInto(&.{ 22, 'h', 'e', 'l', 'l', 'o', 17, 0, 0 }, &output),
    );
    try std.testing.expectEqualSlices(u8, "hello", &output);
}

test "LZO1X decoder accepts a liblzo match stream" {
    const encoded_hex = "0361626361626320f314000f616263616263616263616263616263616263110000";
    var encoded: [encoded_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&encoded, encoded_hex);
    var output: [300]u8 = undefined;
    try std.testing.expectEqual(output.len, try decodeInto(&encoded, &output));
    for (0..100) |index|
        try std.testing.expectEqualSlices(u8, "abc", output[index * 3 ..][0..3]);
}

test "LZO1X decoder rejects truncation lookbehind and trailing bytes" {
    var output: [16]u8 = undefined;
    try std.testing.expectError(error.TruncatedFrame, decodeInto(&.{ 22, 'h' }, &output));
    try std.testing.expectError(error.InvalidLzoStream, decodeInto(&.{ 18, 'a', 4, 0, 17, 0, 0 }, &output));
    try std.testing.expectError(error.TrailingData, decodeInto(&.{ 17, 0, 0, 1 }, &output));
}
