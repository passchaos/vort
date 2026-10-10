const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || std.mem.Allocator.Error || error{
    InvalidArcRleStream,
};

pub const marker: u8 = 0x90;

pub const Decoder = struct {
    last: u8 = 0,
    have_last: bool = false,
    need_count: bool = false,
    output_offset: usize = 0,

    pub fn feed(self: *Decoder, byte: u8, output: []u8) Error!void {
        if (!self.need_count) {
            if (byte == marker) {
                self.need_count = true;
                return;
            }
            try self.appendByte(output, byte);
            self.last = byte;
            self.have_last = true;
            return;
        }

        self.need_count = false;
        if (byte == 0) {
            try self.appendByte(output, marker);
            self.last = marker;
            self.have_last = true;
            return;
        }
        if (!self.have_last) return error.InvalidArcRleStream;
        const repeats = @as(usize, byte) - 1;
        if (repeats > output.len - self.output_offset) return error.OutputTooSmall;
        @memset(output[self.output_offset .. self.output_offset + repeats], self.last);
        self.output_offset += repeats;
    }

    pub fn finish(self: *const Decoder, expected_len: usize) Error!void {
        if (self.need_count) return error.TruncatedFrame;
        if (self.output_offset != expected_len) return error.SizeMismatch;
    }

    fn appendByte(self: *Decoder, output: []u8, byte: u8) Error!void {
        if (self.output_offset == output.len) return error.OutputTooSmall;
        output[self.output_offset] = byte;
        self.output_offset += 1;
    }
};

pub fn decodeInto(input: []const u8, output: []u8) Error!void {
    var decoder = Decoder{};
    for (input) |byte| try decoder.feed(byte, output);
    try decoder.finish(output.len);
}

pub fn encodeAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, input);
    return output.toOwnedSlice(allocator);
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
) Error!usize {
    const start = output.items.len;
    errdefer output.items.len = start;
    var offset: usize = 0;
    while (offset < input.len) {
        const byte = input[offset];
        var run: usize = 1;
        while (offset + run < input.len and input[offset + run] == byte)
            run += 1;

        if (byte == marker) {
            try output.appendSlice(allocator, &.{ marker, 0 });
            run -= 1;
            offset += 1;
        } else {
            try output.append(allocator, byte);
            run -= 1;
            offset += 1;
        }

        while (run != 0) {
            if (run < 2) {
                try output.append(allocator, byte);
                run -= 1;
                offset += 1;
                continue;
            }
            const total_count = @min(run + 1, @as(usize, 255));
            try output.appendSlice(allocator, &.{ marker, @intCast(total_count) });
            const consumed = total_count - 1;
            run -= consumed;
            offset += consumed;
        }
    }
    return output.items.len - start;
}

test "ARC RLE90 round trips literals markers and long runs" {
    const allocator = std.testing.allocator;
    const input = ([_]u8{ 1, marker, 2, marker } ** 16) ++ ("A" ** 600) ++ "BBCC";
    const encoded = try encodeAlloc(allocator, input);
    defer allocator.free(encoded);
    var decoded: [input.len]u8 = undefined;
    try decodeInto(encoded, &decoded);
    try std.testing.expectEqualSlices(u8, input, &decoded);
    try std.testing.expect(encoded.len < input.len);
}

test "ARC RLE90 rejects dangling counts and output mismatches" {
    var output: [1]u8 = undefined;
    try std.testing.expectError(error.TruncatedFrame, decodeInto(&.{marker}, &output));
    try std.testing.expectError(error.InvalidArcRleStream, decodeInto(&.{ marker, 2 }, &output));
    try std.testing.expectError(error.OutputTooSmall, decodeInto("ab", &output));
}
