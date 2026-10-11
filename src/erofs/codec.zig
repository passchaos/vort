const std = @import("std");
const core = @import("../core.zig");
const deflate = @import("../deflate.zig");
const lzma = @import("../lzma.zig");
const zstd = @import("../zstd.zig");
const format = @import("format.zig");

pub const Error = core.Error || deflate.Error || lzma.Error || zstd.Error ||
    std.mem.Allocator.Error || error{
    InvalidErofs,
    UnsupportedErofsCompression,
};

pub fn decodeExtentAlloc(
    allocator: std.mem.Allocator,
    algorithm: format.Compression,
    input: []const u8,
    expected_size: usize,
    zero_padding: bool,
) Error![]u8 {
    var input_offset: usize = 0;
    if (zero_padding or algorithm != .lz4)
        while (input_offset < input.len and input[input_offset] == 0) : (input_offset += 1) {};
    if (input_offset == input.len) return error.InvalidErofs;
    const payload = input[input_offset..];
    return switch (algorithm) {
        .lz4 => blk: {
            const output = try allocator.alloc(u8, expected_size);
            errdefer allocator.free(output);
            _ = try decodeLz4Into(payload, output, false);
            break :blk output;
        },
        .deflate => blk: {
            const result = try deflate.decodeRawAutoAllocPartialLimited(
                allocator,
                payload,
                expected_size,
            );
            errdefer result.deinit(allocator);
            if (result.bytes.len != expected_size) return error.SizeMismatch;
            break :blk result.bytes;
        },
        .zstandard => blk: {
            var iterator = try zstd.NativeFrameBlockIterator.init(payload);
            while (try iterator.next()) |_| {}
            const output = try zstd.decodeFrameAllocExactSize(
                allocator,
                payload[0..iterator.next_header_offset],
                expected_size,
            );
            break :blk output;
        },
        .lzma => lzma.decodeMicroAllocLimited(
            allocator,
            payload,
            expected_size,
            8 * 1024 * 1024,
            expected_size,
        ),
    };
}

pub fn decodeLz4Into(
    input: []const u8,
    output: []u8,
    zero_padding: bool,
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
        const output_literal_end = try checkedOutputEnd(output_offset, literal_len, output.len);
        @memcpy(output[output_offset..output_literal_end], input[input_offset..literal_end]);
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

test "EROFS decodes zero-padded MicroLZMA extents" {
    const allocator = std.testing.allocator;
    const encoded_text = @embedFile("../lzma/testdata/microlzma-small.bin.b64");
    const base64 = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const encoded_bound = base64.calcSizeUpperBound(encoded_text.len);
    const padded = try allocator.alloc(u8, encoded_bound + 3);
    defer allocator.free(padded);
    @memset(padded[0..3], 0);
    const encoded_len = try base64.decode(padded[3..], encoded_text);
    const expected = @embedFile("../lzms/testdata/lzms-small.txt");
    const decoded = try decodeExtentAlloc(
        allocator,
        .lzma,
        padded[0 .. encoded_len + 3],
        expected.len,
        false,
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings(expected, decoded);
}
