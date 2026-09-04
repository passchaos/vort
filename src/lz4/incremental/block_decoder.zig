const std = @import("std");

pub const Error = error{
    TruncatedFrame,
    InvalidMatch,
    IntegerOverflow,
    OutputLimitExceeded,
    SizeMismatch,
};

pub const StepResult = struct {
    output_written: usize,
    done: bool,
};

pub const History = struct {
    bytes: []const u8,
    start: usize = 0,
};

pub const StreamStatus = enum { need_input, need_output, done };

pub const StreamStepResult = struct {
    input_read: usize = 0,
    output_written: usize = 0,
    status: StreamStatus,
};

/// Resumable decoder for one complete LZ4 compressed block.
///
/// `history` contains the available rolling prefix before this call, including
/// dictionary/linked-block bytes and bytes emitted by earlier calls for this
/// block. A full 64 KiB prefix may wrap at `history.start`. Bytes emitted during
/// the current call are read back from `output`, preserving LZ4 overlap
/// semantics without decoded-block-sized scratch.
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
        history: History,
        output: []u8,
    ) Error!StepResult {
        const prefix_len = self.history_prefix_len;
        const expected_history_len = @min(
            max_history_len,
            try checkedAdd(prefix_len, self.decoded_len),
        );
        if (history.bytes.len != expected_history_len or
            (history.bytes.len == 0 and history.start != 0) or
            (history.bytes.len != 0 and history.start >= history.bytes.len))
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
                    const available = try checkedAdd(history.bytes.len, written);
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
                    const output_remaining = output.len - written;
                    if (self.match_remaining != 0 and output_remaining != 0) {
                        var copy_len = @min(self.match_remaining, output_remaining);
                        if (copy_len == 1) {
                            output[written] = if (self.match_offset > written)
                                historyByteFromEnd(history, self.match_offset - written)
                            else
                                output[written - self.match_offset];
                            written += 1;
                            self.decoded_len += 1;
                            self.match_remaining -= 1;
                            if (self.match_remaining != 0)
                                return .{ .output_written = written, .done = false };
                            self.stage = .token;
                            continue;
                        }
                        if (self.match_offset > written) {
                            const history_len = @min(copy_len, self.match_offset - written);
                            copyHistoryFromEnd(history, self.match_offset - written, output[written..][0..history_len]);
                            written += history_len;
                            self.decoded_len += history_len;
                            self.match_remaining -= history_len;
                            copy_len -= history_len;
                        }
                        if (copy_len != 0) {
                            copyMatchFromOutput(output, &written, self.match_offset, copy_len);
                            self.decoded_len += copy_len;
                            self.match_remaining -= copy_len;
                        }
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

/// Resumable decoder for one LZ4 block whose compressed payload itself arrives
/// incrementally. The caller supplies exactly `compressed_len` bytes across
/// calls and retains only the 64 KiB rolling output history.
pub const StreamingCursor = struct {
    compressed_remaining: usize,
    literal_remaining: usize = 0,
    match_remaining: usize = 0,
    match_offset: usize = 0,
    decoded_len: usize = 0,
    history_prefix_len: usize,
    max_decoded_len: usize,
    decoded_limit_error: Error,
    offset_low: u8 = 0,
    stage: Stage = .token,

    const Stage = enum { token, literal_length, literals, offset_low, offset_high, match_length, match, done };

    pub fn init(
        compressed_len: usize,
        history_prefix_len: usize,
        max_decoded_len: usize,
        decoded_limit_error: Error,
    ) StreamingCursor {
        return .{
            .compressed_remaining = compressed_len,
            .history_prefix_len = history_prefix_len,
            .max_decoded_len = max_decoded_len,
            .decoded_limit_error = decoded_limit_error,
        };
    }

    pub fn step(self: *StreamingCursor, input: []const u8, history: History, output: []u8) Error!StreamStepResult {
        const expected_history_len = @min(max_history_len, try checkedAdd(self.history_prefix_len, self.decoded_len));
        if (history.bytes.len != expected_history_len or
            (history.bytes.len == 0 and history.start != 0) or
            (history.bytes.len != 0 and history.start >= history.bytes.len))
            return error.InvalidMatch;

        var read: usize = 0;
        var written: usize = 0;
        while (true) {
            switch (self.stage) {
                .token => {
                    if (self.compressed_remaining == 0) {
                        self.stage = .done;
                        return result(read, written, .done);
                    }
                    const token = self.readByte(input, &read) orelse return result(read, written, .need_input);
                    self.literal_remaining = token >> 4;
                    self.match_remaining = (token & 0x0f) + 4;
                    self.stage = if (self.literal_remaining == 15) .literal_length else .literals;
                    if (self.stage == .literals) try self.checkDecodedAddition(self.literal_remaining);
                },
                .literal_length => {
                    const byte = self.readByte(input, &read) orelse {
                        if (self.compressed_remaining == 0) return error.TruncatedFrame;
                        return result(read, written, .need_input);
                    };
                    self.literal_remaining = try checkedAdd(self.literal_remaining, byte);
                    if (byte != 255) {
                        try self.checkDecodedAddition(self.literal_remaining);
                        self.stage = .literals;
                    }
                },
                .literals => {
                    if (self.literal_remaining > self.compressed_remaining) return error.TruncatedFrame;
                    const n = @min(self.literal_remaining, @min(input.len - read, output.len - written));
                    @memcpy(output[written..][0..n], input[read..][0..n]);
                    read += n;
                    self.compressed_remaining -= n;
                    self.literal_remaining -= n;
                    self.decoded_len += n;
                    written += n;
                    if (self.literal_remaining != 0) {
                        return result(read, written, if (written == output.len) .need_output else .need_input);
                    }
                    if (self.compressed_remaining == 0) {
                        self.stage = .done;
                        return result(read, written, .done);
                    }
                    if (self.compressed_remaining < 2) return error.TruncatedFrame;
                    self.stage = .offset_low;
                },
                .offset_low => {
                    self.offset_low = self.readByte(input, &read) orelse return result(read, written, .need_input);
                    self.stage = .offset_high;
                },
                .offset_high => {
                    const high = self.readByte(input, &read) orelse return result(read, written, .need_input);
                    self.match_offset = @as(usize, self.offset_low) | (@as(usize, high) << 8);
                    const available = try checkedAdd(history.bytes.len, written);
                    if (self.match_offset == 0 or self.match_offset > available) return error.InvalidMatch;
                    self.stage = if (self.match_remaining == 19) .match_length else .match;
                    if (self.stage == .match) try self.checkDecodedAddition(self.match_remaining);
                },
                .match_length => {
                    const byte = self.readByte(input, &read) orelse {
                        if (self.compressed_remaining == 0) return error.TruncatedFrame;
                        return result(read, written, .need_input);
                    };
                    self.match_remaining = try checkedAdd(self.match_remaining, byte);
                    if (byte != 255) {
                        try self.checkDecodedAddition(self.match_remaining);
                        self.stage = .match;
                    }
                },
                .match => {
                    const n = @min(self.match_remaining, output.len - written);
                    if (n != 0) {
                        if (n == 1) {
                            output[written] = if (self.match_offset > written)
                                historyByteFromEnd(history, self.match_offset - written)
                            else
                                output[written - self.match_offset];
                            written += 1;
                        } else {
                            var copy_len = n;
                            if (self.match_offset > written) {
                                const history_len = @min(copy_len, self.match_offset - written);
                                copyHistoryFromEnd(history, self.match_offset - written, output[written..][0..history_len]);
                                written += history_len;
                                copy_len -= history_len;
                            }
                            if (copy_len != 0) copyMatchFromOutput(output, &written, self.match_offset, copy_len);
                        }
                        self.decoded_len += n;
                        self.match_remaining -= n;
                    }
                    if (self.match_remaining != 0) return result(read, written, .need_output);
                    self.stage = .token;
                },
                .done => return result(read, written, .done),
            }
        }
    }

    fn readByte(self: *StreamingCursor, input: []const u8, read: *usize) ?u8 {
        if (read.* == input.len or self.compressed_remaining == 0) return null;
        const byte = input[read.*];
        read.* += 1;
        self.compressed_remaining -= 1;
        return byte;
    }

    fn checkDecodedAddition(self: *const StreamingCursor, additional: usize) Error!void {
        const total = try checkedAdd(self.decoded_len, additional);
        if (total > self.max_decoded_len) return self.decoded_limit_error;
    }

    fn result(input_read: usize, output_written: usize, status: StreamStatus) StreamStepResult {
        return .{ .input_read = input_read, .output_written = output_written, .status = status };
    }

    pub fn compressedInputComplete(self: *const StreamingCursor) bool {
        return self.compressed_remaining == 0;
    }
};

fn historyByteFromEnd(history: History, distance: usize) u8 {
    std.debug.assert(distance != 0 and distance <= history.bytes.len);
    const logical_index = history.bytes.len - distance;
    return history.bytes[(history.start + logical_index) % history.bytes.len];
}

fn copyHistoryFromEnd(history: History, distance: usize, output: []u8) void {
    std.debug.assert(distance != 0 and distance <= history.bytes.len);
    const logical_index = history.bytes.len - distance;
    const physical_index = (history.start + logical_index) % history.bytes.len;
    const first_len = @min(output.len, history.bytes.len - physical_index);
    @memcpy(output[0..first_len], history.bytes[physical_index..][0..first_len]);
    @memcpy(output[first_len..], history.bytes[0 .. output.len - first_len]);
}

fn copyMatchFromOutput(output: []u8, written: *usize, distance: usize, len: usize) void {
    std.debug.assert(distance != 0 and distance <= written.*);
    const repeat_start = written.* - distance;
    const destination_start = written.*;
    written.* += len;

    var copied: usize = 0;
    while (copied < len) {
        const available = if (copied == 0) distance else copied;
        const copy_len = @min(available, len - copied);
        const source_start = if (copied == 0) repeat_start else destination_start;
        @memcpy(
            output[destination_start + copied ..][0..copy_len],
            output[source_start..][0..copy_len],
        );
        copied += copy_len;
    }
}

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
            const result = try cursor.step(&block, .{ .bytes = decoded[0..written] }, decoded[written..end]);
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
    try std.testing.expectError(error.TruncatedFrame, cursor.step(&.{0x10}, .{ .bytes = &.{} }, &.{}));

    cursor = Cursor.init(4, 0);
    var output: [4]u8 = undefined;
    try std.testing.expectError(error.InvalidMatch, cursor.step(&.{ 0x00, 0x00, 0x00 }, .{ .bytes = &.{} }, &output));

    cursor = Cursor.init(5, 0);
    try std.testing.expectError(error.SizeMismatch, cursor.step(&.{ 0x40, 't', 'e', 's', 't' }, .{ .bytes = &.{} }, &output));

    cursor = Cursor.init(5, 0);
    const first = try cursor.step(&.{ 0x50, 'h', 'e', 'l', 'l', 'o' }, .{ .bytes = &.{} }, output[0..2]);
    try std.testing.expectEqual(@as(usize, 2), first.output_written);
    try std.testing.expectError(error.InvalidMatch, cursor.step(&.{ 0x50, 'h', 'e', 'l', 'l', 'o' }, .{ .bytes = &.{} }, output[2..]));
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
        const result = try cursor.step(&block, .{ .bytes = decoded[0..written] }, decoded[written..end]);
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
            const result = try cursor.step(&block, .{ .bytes = history[0..history_len] }, output[0..@min(chunk_len, output.len)]);
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

test "LZ4 streaming cursor accepts every input and output chunk size" {
    const block = [_]u8{ 0x35, 'a', 'b', 'c', 0x03, 0x00, 0x50, 'x', 'y', 'z', '1', '2' };
    const expected = "abcabcabcabcxyz12";
    for (1..block.len + 1) |input_chunk_len| {
        for (1..expected.len + 1) |output_chunk_len| {
            var cursor = StreamingCursor.init(block.len, 0, expected.len, error.OutputLimitExceeded);
            var history: [expected.len]u8 = undefined;
            var input_offset: usize = 0;
            var output_offset: usize = 0;
            while (true) {
                const input_end = @min(block.len, input_offset + input_chunk_len);
                const output_end = @min(expected.len, output_offset + output_chunk_len);
                const result = try cursor.step(
                    block[input_offset..input_end],
                    .{ .bytes = history[0..output_offset] },
                    history[output_offset..output_end],
                );
                input_offset += result.input_read;
                output_offset += result.output_written;
                if (result.status == .done) break;
                try std.testing.expect(result.input_read != 0 or result.output_written != 0);
            }
            try std.testing.expectEqual(block.len, input_offset);
            try std.testing.expectEqual(expected.len, output_offset);
            try std.testing.expectEqualSlices(u8, expected, &history);
        }
    }
}

test "LZ4 streaming cursor resumes length extensions across single bytes" {
    const literals = "abcdefghijklmnopqrst";
    const tail = "uvwxy";
    const block = [_]u8{0xff} ++ [_]u8{5} ++ literals.* ++
        [_]u8{ 20, 0, 1, 0x50 } ++ tail.*;
    const expected = literals.* ++ literals.* ++ tail.*;
    var cursor = StreamingCursor.init(block.len, 0, expected.len, error.OutputLimitExceeded);
    var history: [expected.len]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (true) {
        const input_end = @min(block.len, input_offset + 1);
        const output_end = @min(expected.len, output_offset + 3);
        const result = try cursor.step(
            block[input_offset..input_end],
            .{ .bytes = history[0..output_offset] },
            history[output_offset..output_end],
        );
        input_offset += result.input_read;
        output_offset += result.output_written;
        if (result.status == .done) break;
        try std.testing.expect(result.input_read != 0 or result.output_written != 0);
    }
    try std.testing.expectEqual(block.len, input_offset);
    try std.testing.expectEqual(expected.len, output_offset);
    try std.testing.expectEqualSlices(u8, &expected, &history);
}

test "LZ4 streaming cursor distinguishes input truncation and output backpressure" {
    var cursor = StreamingCursor.init(2, 0, 16, error.OutputLimitExceeded);
    try std.testing.expectError(error.TruncatedFrame, cursor.step(&.{ 0x20, 'a' }, .{ .bytes = &.{} }, &.{}));

    cursor = StreamingCursor.init(3, 0, 16, error.OutputLimitExceeded);
    var output: [8]u8 = undefined;
    const first = try cursor.step(&.{0x00}, .{ .bytes = &.{} }, &output);
    try std.testing.expectEqual(StreamStatus.need_input, first.status);
    const second = try cursor.step(&.{0x00}, .{ .bytes = &.{} }, &output);
    try std.testing.expectEqual(StreamStatus.need_input, second.status);
    try std.testing.expectError(error.InvalidMatch, cursor.step(&.{0x00}, .{ .bytes = &.{} }, &output));

    cursor = StreamingCursor.init(3, 0, 3, error.OutputLimitExceeded);
    try std.testing.expectError(error.OutputLimitExceeded, cursor.step(&.{0x40}, .{ .bytes = &.{} }, &output));

    cursor = StreamingCursor.init(6, 0, 5, error.OutputLimitExceeded);
    const partial = try cursor.step(&.{ 0x50, 'h', 'e', 'l', 'l', 'o' }, .{ .bytes = &.{} }, output[0..2]);
    try std.testing.expectEqual(StreamStatus.need_output, partial.status);
    try std.testing.expect(cursor.compressedInputComplete() == false);
}
