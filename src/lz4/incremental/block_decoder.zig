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
/// `history` contains the available rolling prefix before this call, including
/// dictionary/linked-block bytes and bytes emitted by earlier calls for this
/// block. Bytes emitted during the current call are read back from `output`,
/// preserving LZ4 overlap semantics without decoded-block-sized scratch.
pub const Cursor = struct {
    input_offset: usize = 0,
    literal_remaining: usize = 0,
    match_remaining: usize = 0,
    match_offset: usize = 0,
    decoded_len: usize = 0,
    history_prefix_len: usize,
    expected_decoded_len: usize,
    stage: Stage = .token,

    const Stage = enum { token, literals, match, done };

    pub fn init(expected_decoded_len: usize, history_prefix_len: usize) Cursor {
        return .{
            .expected_decoded_len = expected_decoded_len,
            .history_prefix_len = history_prefix_len,
        };
    }

    pub fn step(
        self: *Cursor,
        block: []const u8,
        history: []const u8,
        output: []u8,
    ) Error!StepResult {
        const prefix_len = self.history_prefix_len;
        const expected_history_len = @min(
            max_history_len,
            try checkedAdd(prefix_len, self.decoded_len),
        );
        if (history.len != expected_history_len)
            return error.InvalidMatch;
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
                    const available = try checkedAdd(history.len, written);
                    if (self.match_offset == 0 or self.match_offset > available) return error.InvalidMatch;
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
                        output[written] = if (self.match_offset > written)
                            history[history.len - (self.match_offset - written)]
                        else
                            output[written - self.match_offset];
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
        var cursor = Cursor.init(expected.len, 0);
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
    var cursor = Cursor.init(4, 0);
    try std.testing.expectError(error.TruncatedFrame, cursor.step(&.{0x10}, &.{}, &.{}));

    cursor = Cursor.init(4, 0);
    var output: [4]u8 = undefined;
    try std.testing.expectError(error.InvalidMatch, cursor.step(&.{ 0x00, 0x00, 0x00 }, &.{}, &output));

    cursor = Cursor.init(5, 0);
    try std.testing.expectError(error.SizeMismatch, cursor.step(&.{ 0x40, 't', 'e', 's', 't' }, &.{}, &output));

    cursor = Cursor.init(5, 0);
    const first = try cursor.step(&.{ 0x50, 'h', 'e', 'l', 'l', 'o' }, &.{}, output[0..2]);
    try std.testing.expectEqual(@as(usize, 2), first.output_written);
    try std.testing.expectError(error.InvalidMatch, cursor.step(&.{ 0x50, 'h', 'e', 'l', 'l', 'o' }, &.{}, output[2..]));
}

test "LZ4 compressed block cursor resumes extended literals and matches" {
    const literals = "abcdefghijklmnopqrst";
    const tail = "uvwxy";
    const block = [_]u8{0xff} ++ [_]u8{5} ++ literals.* ++
        [_]u8{ 20, 0, 1, 0x50 } ++ tail.*;
    const expected = literals.* ++ literals.* ++ tail.*;

    var cursor = Cursor.init(expected.len, 0);
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

test "LZ4 compressed block cursor reads dictionary and linked prefixes" {
    const prefix = "abcdefghijklmnop";
    const block = [_]u8{ 0x0c, 0x10, 0x00, 0x50, '-', 't', 'a', 'i', 'l' };
    const expected = "abcdefghijklmnop-tail";

    for (1..expected.len + 1) |chunk_len| {
        var cursor = Cursor.init(expected.len, prefix.len);
        var history: [max_history_len + expected.len]u8 = undefined;
        @memcpy(history[0..prefix.len], prefix);
        var history_len = prefix.len;
        var decoded_len: usize = 0;
        while (true) {
            var output: [expected.len]u8 = undefined;
            const result = try cursor.step(&block, history[0..history_len], output[0..@min(chunk_len, output.len)]);
            @memcpy(history[history_len..][0..result.output_written], output[0..result.output_written]);
            history_len += result.output_written;
            decoded_len += result.output_written;
            if (result.done) break;
            try std.testing.expect(result.output_written != 0);
        }
        try std.testing.expectEqual(expected.len, decoded_len);
        try std.testing.expectEqualSlices(u8, expected, history[prefix.len..history_len]);
    }
}

const max_history_len = 64 * 1024;
