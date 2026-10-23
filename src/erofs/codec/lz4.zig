const std = @import("std");
const core = @import("../../core.zig");
pub const Error = core.Error || error{InvalidErofs};

pub fn decode(
    input: []const u8,
    output: []u8,
    zero_padding: bool,
    partial: bool,
) Error!usize {
    var input_offset: usize = 0;
    if (zero_padding)
        while (input_offset < input.len and input[input_offset] == 0) : (input_offset += 1) {};
    if (input_offset == input.len) return error.InvalidErofs;
    var output_offset: usize = 0;
    while (input_offset < input.len) {
        const token = input[input_offset];
        input_offset += 1;
        var literal_len: usize = token >> 4;
        if (literal_len == 15)
            literal_len = std.math.add(
                usize,
                literal_len,
                try readLength(input, &input_offset),
            ) catch return error.IntegerOverflow;
        const literal_end = try checkedInputEnd(input_offset, literal_len, input.len);
        if (partial) literal_len = @min(literal_len, output.len - output_offset);
        const output_literal_end = try checkedOutputEnd(output_offset, literal_len, output.len);
        @memcpy(output[output_offset..output_literal_end], input[input_offset..][0..literal_len]);
        input_offset = literal_end;
        output_offset = output_literal_end;
        if (output_offset == output.len) return output_offset;
        if (input.len - input_offset < 2) return error.TruncatedFrame;
        const distance: usize = std.mem.readInt(
            u16,
            input[input_offset..][0..2],
            .little,
        );
        input_offset += 2;
        if (distance == 0 or distance > output_offset) return error.InvalidMatch;
        var match_len: usize = (token & 0x0f) + 4;
        if (token & 0x0f == 15)
            match_len = std.math.add(
                usize,
                match_len,
                try readLength(input, &input_offset),
            ) catch return error.IntegerOverflow;
        if (partial) match_len = @min(match_len, output.len - output_offset);
        const match_end = try checkedOutputEnd(output_offset, match_len, output.len);
        while (output_offset < match_end) : (output_offset += 1)
            output[output_offset] = output[output_offset - distance];
        if (output_offset == output.len) return output_offset;
    }
    return error.SizeMismatch;
}

fn readLength(input: []const u8, offset: *usize) Error!usize {
    var length: usize = 0;
    while (true) {
        if (offset.* >= input.len) return error.TruncatedFrame;
        const byte = input[offset.*];
        offset.* += 1;
        length = std.math.add(usize, length, byte) catch return error.IntegerOverflow;
        if (byte != 255) return length;
    }
}

fn checkedInputEnd(start: usize, length: usize, limit: usize) Error!usize {
    const end = std.math.add(usize, start, length) catch return error.IntegerOverflow;
    if (end > limit) return error.TruncatedFrame;
    return end;
}

fn checkedOutputEnd(start: usize, length: usize, limit: usize) Error!usize {
    const end = std.math.add(usize, start, length) catch return error.IntegerOverflow;
    if (end > limit) return error.OutputTooSmall;
    return end;
}
