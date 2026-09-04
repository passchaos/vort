const std = @import("std");

pub const Error = error{
    TruncatedFrame,
    InvalidMatch,
    IntegerOverflow,
    SizeMismatch,
};

pub const StepResult = struct {
    output_written: usize,
    done: bool,
};

/// Resumable decoder for one complete LZ4 compressed block.
///
/// `history` contains all bytes emitted by earlier calls for this block. Bytes
/// emitted during the current call are read back from `output`, preserving LZ4
/// overlap semantics without retaining a decoded-block-sized scratch buffer.
pub const Cursor = struct {
    input_offset: usize = 0,
    literal_remaining: usize = 0,
    match_remaining: usize = 0,
    match_offset: usize = 0,
    decoded_len: usize = 0,
    expected_decoded_len: usize,
    stage: Stage = .token,

    const Stage = enum { token, literals, match, done };

    pub fn init(expected_decoded_len: usize) Cursor {
        return .{ .expected_decoded_len = expected_decoded_len };
    }

    pub fn step(
        self: *Cursor,
        block: []const u8,
        history: []const u8,
        output: []u8,
    ) Error!StepResult {
        if (history.len != self.decoded_len) return error.InvalidMatch;
        var written: usize = 0;
        while (true) {
            switch (self.stage) {
                .token => {
                    if (self.input_offset == block.len) {
                        try self.finish();
                        return .{ .output_written = written, .done = true };
                    }
                    const token = block[self.input_offset];
                    self.input_offset += 1;
                    self.literal_remaining = token >> 4;
                    if (self.literal_remaining == 15) {
                        self.literal_remaining = try checkedAdd(
                            self.literal_remaining,
                            try readLengthExtension(block, &self.input_offset),
                        );
                    }
                    if (block.len - self.input_offset < self.literal_remaining) return error.TruncatedFrame;
                    self.match_remaining = (token & 0x0f) + 4;
                    self.stage = .literals;
                },
                .literals => {
                    const n = @min(self.literal_remaining, output.len - written);
                    @memcpy(
                        output[written..][0..n],
                        block[self.input_offset..][0..n],
                    );
                    self.input_offset += n;
                    self.literal_remaining -= n;
                    self.decoded_len = try checkedAdd(self.decoded_len, n);
                    written += n;
                    if (self.literal_remaining != 0) return .{ .output_written = written, .done = false };
                    if (self.input_offset == block.len) {
                        try self.finish();
                        return .{ .output_written = written, .done = true };
                    }
                    if (block.len - self.input_offset < 2) return error.TruncatedFrame;
                    self.match_offset = std.mem.readInt(u16, block[self.input_offset..][0..2], .little);
                    self.input_offset += 2;
                    if (self.match_offset == 0 or self.match_offset > self.decoded_len) return error.InvalidMatch;
                    if (self.match_remaining == 19) {
                        self.match_remaining = try checkedAdd(
                            self.match_remaining,
                            try readLengthExtension(block, &self.input_offset),
                        );
                    }
                    self.stage = .match;
                },
                .match => {
                    while (self.match_remaining != 0 and written < output.len) {
                        const source = self.decoded_len - self.match_offset;
                        output[written] = if (source < history.len)
                            history[source]
                        else
                            output[source - history.len];
                        written += 1;
                        self.decoded_len += 1;
                        self.match_remaining -= 1;
                    }
                    if (self.match_remaining != 0) return .{ .output_written = written, .done = false };
                    self.stage = .token;
                },
                .done => return .{ .output_written = written, .done = true },
            }
        }
    }

    fn finish(self: *Cursor) Error!void {
        if (self.decoded_len != self.expected_decoded_len) return error.SizeMismatch;
        self.stage = .done;
    }
};

fn checkedAdd(a: usize, b: usize) Error!usize {
    return std.math.add(usize, a, b) catch error.IntegerOverflow;
}

fn readLengthExtension(input: []const u8, offset: *usize) Error!usize {
    var len: usize = 0;
    while (true) {
        if (offset.* >= input.len) return error.TruncatedFrame;
        const byte = input[offset.*];
        offset.* += 1;
        len = try checkedAdd(len, byte);
        if (byte != 255) return len;
    }
}

test "LZ4 compressed block cursor drains through every output chunk size" {
    const block = [_]u8{ 0x35, 'a', 'b', 'c', 0x03, 0x00, 0x50, 'x', 'y', 'z', '1', '2' };
    const expected = "abcabcabcabcxyz12";
    for (1..expected.len + 1) |chunk_len| {
        var cursor = Cursor.init(expected.len);
        var decoded: [expected.len]u8 = undefined;
        var written: usize = 0;
        while (true) {
            const end = @min(decoded.len, written + chunk_len);
            const result = try cursor.step(&block, decoded[0..written], decoded[written..end]);
            written += result.output_written;
            if (result.done) break;
            try std.testing.expect(result.output_written != 0);
        }
        try std.testing.expectEqual(expected.len, written);
        try std.testing.expectEqualSlices(u8, expected, &decoded);
    }
}

test "LZ4 compressed block cursor rejects invalid input and history" {
    var cursor = Cursor.init(4);
    try std.testing.expectError(error.TruncatedFrame, cursor.step(&.{0x10}, &.{}, &.{}));

    cursor = Cursor.init(4);
    var output: [4]u8 = undefined;
    try std.testing.expectError(error.InvalidMatch, cursor.step(&.{ 0x00, 0x00, 0x00 }, &.{}, &output));

    cursor = Cursor.init(5);
    try std.testing.expectError(error.SizeMismatch, cursor.step(&.{ 0x40, 't', 'e', 's', 't' }, &.{}, &output));
}

test "LZ4 compressed block cursor resumes extended literals and matches" {
    const literals = "abcdefghijklmnopqrst";
    const tail = "uvwxy";
    const block = [_]u8{0xff} ++ [_]u8{5} ++ literals.* ++
        [_]u8{ 20, 0, 1, 0x50 } ++ tail.*;
    const expected = literals.* ++ literals.* ++ tail.*;

    var cursor = Cursor.init(expected.len);
    var decoded: [expected.len]u8 = undefined;
    var written: usize = 0;
    while (true) {
        const end = @min(decoded.len, written + 3);
        const result = try cursor.step(&block, decoded[0..written], decoded[written..end]);
        written += result.output_written;
        if (result.done) break;
        try std.testing.expect(result.output_written != 0);
    }
    try std.testing.expectEqualSlices(u8, &expected, &decoded);
}
