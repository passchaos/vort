const std = @import("std");
const core = @import("../core.zig");
const bit_stream = @import("bit_stream.zig");

pub const Error = core.Error || bit_stream.Error || error{
    InvalidLegacyLhStream,
};

pub const Method = enum { lzs, lz5 };

pub fn decodeInto(
    input: []const u8,
    output: []u8,
    method: Method,
) Error!void {
    return switch (method) {
        .lzs => decodeLzsInto(input, output),
        .lz5 => decodeLz5Into(input, output),
    };
}

pub fn decodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    output_len: usize,
    method: Method,
) Error![]u8 {
    return decodeAllocLimited(allocator, input, output_len, method, std.math.maxInt(usize));
}

pub fn decodeAllocLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    output_len: usize,
    method: Method,
    max_output_len: usize,
) Error![]u8 {
    if (output_len > max_output_len) return error.OutputLimitExceeded;
    const output = try allocator.alloc(u8, output_len);
    errdefer allocator.free(output);
    try decodeInto(input, output, method);
    return output;
}

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    method: Method,
) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, input, method);
    return output.toOwnedSlice(allocator);
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    method: Method,
) Error!usize {
    const start = output.items.len;
    errdefer output.items.len = start;
    switch (method) {
        .lzs => {
            var writer = bit_stream.Writer{ .allocator = allocator, .output = output };
            for (input) |literal| {
                try writer.write(1, 1);
                try writer.write(literal, 8);
            }
            try writer.finish();
        },
        .lz5 => {
            var offset: usize = 0;
            while (offset < input.len) {
                const count = @min(@as(usize, 8), input.len - offset);
                try output.append(
                    allocator,
                    @intCast((@as(u16, 1) << @intCast(count)) - 1),
                );
                try output.appendSlice(allocator, input[offset .. offset + count]);
                offset += count;
            }
        },
    }
    return output.items.len - start;
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
    method: Method,
) Error!usize {
    const encoded = try encodeAlloc(allocator, input, method);
    defer allocator.free(encoded);
    if (encoded.len > output.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

fn decodeLzsInto(input: []const u8, output: []u8) Error!void {
    if (output.len == 0) {
        if (input.len != 0) return error.TrailingData;
        return;
    }
    var history: [2048]u8 = @splat(' ');
    var history_offset: usize = history.len - 17;
    var output_offset: usize = 0;
    var reader = bit_stream.Reader{ .input = input };
    while (output_offset < output.len) {
        if (try reader.read(1) != 0) {
            outputByte(
                output,
                &output_offset,
                &history,
                &history_offset,
                @truncate(try reader.read(8)),
            );
        } else {
            const start = try reader.read(11);
            const count = @as(usize, try reader.read(4)) + 2;
            if (count > output.len - output_offset) return error.SizeMismatch;
            copyAbsolute(output, &output_offset, &history, &history_offset, start, count);
        }
    }
    try reader.finish();
}

fn decodeLz5Into(input: []const u8, output: []u8) Error!void {
    if (output.len == 0) {
        if (input.len != 0) return error.TrailingData;
        return;
    }
    var history: [4096]u8 = undefined;
    initLz5History(&history);
    var history_offset: usize = history.len - 18;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (output_offset < output.len) {
        if (input_offset == input.len) return error.TruncatedFrame;
        const bitmap = input[input_offset];
        input_offset += 1;
        for (0..8) |bit| {
            if (output_offset == output.len) break;
            if (bitmap & (@as(u8, 1) << @intCast(bit)) != 0) {
                if (input_offset == input.len) return error.TruncatedFrame;
                outputByte(
                    output,
                    &output_offset,
                    &history,
                    &history_offset,
                    input[input_offset],
                );
                input_offset += 1;
            } else {
                if (input.len - input_offset < 2) return error.TruncatedFrame;
                const start = (@as(usize, input[input_offset + 1] & 0xf0) << 4) |
                    input[input_offset];
                const count = @as(usize, input[input_offset + 1] & 0x0f) + 3;
                input_offset += 2;
                if (count > output.len - output_offset) return error.SizeMismatch;
                copyAbsolute(output, &output_offset, &history, &history_offset, start, count);
            }
        }
    }
    if (input_offset != input.len) return error.TrailingData;
}

fn initLz5History(history: *[4096]u8) void {
    var offset: usize = 0;
    for (0..256) |value| {
        @memset(history[offset .. offset + 13], @intCast(value));
        offset += 13;
    }
    for (0..256) |value| {
        history[offset] = @intCast(value);
        offset += 1;
    }
    for (0..256) |value| {
        history[offset] = @intCast(255 - value);
        offset += 1;
    }
    @memset(history[offset .. offset + 128], 0);
    offset += 128;
    @memset(history[offset .. offset + 110], ' ');
    offset += 110;
    @memset(history[offset .. offset + 18], 0);
    offset += 18;
    std.debug.assert(offset == history.len);
}

fn outputByte(
    output: []u8,
    output_offset: *usize,
    history: []u8,
    history_offset: *usize,
    byte: u8,
) void {
    output[output_offset.*] = byte;
    output_offset.* += 1;
    history[history_offset.*] = byte;
    history_offset.* = (history_offset.* + 1) % history.len;
}

fn copyAbsolute(
    output: []u8,
    output_offset: *usize,
    history: []u8,
    history_offset: *usize,
    start: usize,
    count: usize,
) void {
    for (0..count) |index| {
        const byte = history[(start + index) % history.len];
        outputByte(output, output_offset, history, history_offset, byte);
    }
}

test "LZS and LZ5 literal writers round trip edge payloads" {
    const allocator = std.testing.allocator;
    var random: [4097]u8 = undefined;
    var state: u32 = 0x1a2c_5001;
    for (&random) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    const cases = [_][]const u8{ "", "x", "legacy LArc payload" ** 128, &random };
    inline for (std.meta.tags(Method)) |method| {
        for (cases) |input| {
            const encoded = try encodeAlloc(allocator, input, method);
            defer allocator.free(encoded);
            const caller_encoded = try allocator.alloc(u8, encoded.len);
            defer allocator.free(caller_encoded);
            try std.testing.expectEqual(
                encoded.len,
                try encodeInto(allocator, input, caller_encoded, method),
            );
            try std.testing.expectEqualSlices(u8, encoded, caller_encoded);
            const decoded = try decodeAlloc(allocator, encoded, input.len, method);
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, input, decoded);
            if (input.len != 0) {
                try std.testing.expectError(
                    error.OutputLimitExceeded,
                    decodeAllocLimited(allocator, encoded, input.len, method, input.len - 1),
                );
            }
        }
    }
}

test "LZS and LZ5 decoders accept initialized-history matches" {
    // LZS copy from the initial space-filled history.
    const lzs = [_]u8{ 0, 0 };
    var spaces: [2]u8 = undefined;
    try decodeInto(&lzs, &spaces, .lzs);
    try std.testing.expectEqualSlices(u8, "  ", &spaces);

    // LZ5 copy of three zeroes from the first prefilled run.
    const lz5 = [_]u8{ 0, 0, 0 };
    var zeroes: [3]u8 = undefined;
    try decodeInto(&lz5, &zeroes, .lz5);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0 }, &zeroes);
}

test "legacy LArc decoders reject truncation size mismatch and trailing data" {
    var output: [1]u8 = undefined;
    try std.testing.expectError(error.TruncatedFrame, decodeInto(&.{}, &output, .lzs));
    try std.testing.expectError(error.TruncatedFrame, decodeInto(&.{0xff}, &output, .lz5));
    try std.testing.expectError(error.SizeMismatch, decodeInto(&.{ 0, 0, 0 }, &output, .lz5));

    const encoded = try encodeAlloc(std.testing.allocator, "x", .lz5);
    defer std.testing.allocator.free(encoded);
    var trailing = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(trailing);
    trailing = try std.testing.allocator.realloc(trailing, trailing.len + 1);
    trailing[trailing.len - 1] = 0;
    try std.testing.expectError(error.TrailingData, decodeInto(trailing, &output, .lz5));
}
