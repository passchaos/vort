const std = @import("std");
const core = @import("../../core.zig");
const history_mod = @import("history.zig");

pub const Error = core.Error || error{ InvalidLzvnStream, HistoryLimitExceeded };

/// Byte-progressive LZVN payload cursor. Input is accepted only within the
/// declared payload; history contains output from before the current step.
/// No input, output, or history slice is retained and no allocation occurs.
pub const Cursor = struct {
    compressed_len: usize,
    raw_size: usize,
    prefix_len: usize,
    input_consumed: usize = 0,
    decoded_len: usize = 0,
    stage: Stage = .opcode,
    header: [8]u8 = undefined,
    header_received: usize = 0,
    header_needed: usize = 0,
    pending_literals: usize = 0,
    pending_match: usize = 0,
    match_distance: usize = 0,
    previous_distance: ?usize = null,
    failed: ?Error = null,

    pub const Stage = enum { opcode, header, literal, match, terminal, done };

    pub fn init(compressed_len: usize, raw_size: usize, prefix_len: usize) Cursor {
        return .{ .compressed_len = compressed_len, .raw_size = raw_size, .prefix_len = prefix_len };
    }

    pub fn step(self: *Cursor, input: []const u8, history: history_mod.View, output: []u8) Error!core.StepResult {
        if (self.failed) |err| return err;
        return self.stepInternal(input, history, output) catch |err| {
            self.failed = err;
            return err;
        };
    }

    fn stepInternal(self: *Cursor, input: []const u8, history: history_mod.View, output: []u8) Error!core.StepResult {
        var input_read: usize = 0;
        var written: usize = 0;
        while (true) switch (self.stage) {
            .opcode => {
                const opcode = (try self.readByte(input, &input_read)) orelse return result(input_read, written, .need_input);
                self.header[0] = opcode;
                self.header_received = 1;
                if (opcode == 0x06) {
                    self.header_needed = 8;
                    self.stage = .terminal;
                    continue;
                }
                if (opcode == 0x0e or opcode == 0x16) continue;
                self.header_needed = if (opcode == 0xe0 or opcode == 0xf0)
                    2
                else if (opcode >= 0xe1)
                    1
                else if (opcode >= 0xa0 and opcode <= 0xbf)
                    3
                else if (isCombinedOpcode(opcode)) switch (opcode & 7) {
                    0...5 => 2,
                    6 => 1,
                    7 => 3,
                    else => unreachable,
                } else return error.InvalidLzvnStream;
                self.stage = .header;
            },
            .header => {
                while (self.header_received < self.header_needed) {
                    self.header[self.header_received] = (try self.readByte(input, &input_read)) orelse return result(input_read, written, .need_input);
                    self.header_received += 1;
                }
                try self.beginItem();
            },
            .literal => {
                while (self.pending_literals != 0) {
                    if (written == output.len) return result(input_read, written, .need_output);
                    const byte = (try self.readByte(input, &input_read)) orelse return result(input_read, written, .need_input);
                    output[written] = byte;
                    written += 1;
                    self.decoded_len += 1;
                    self.pending_literals -= 1;
                }
                self.stage = if (self.pending_match == 0) .opcode else .match;
            },
            .match => {
                while (self.pending_match != 0) {
                    if (written == output.len) return result(input_read, written, .need_output);
                    output[written] = if (self.match_distance <= written)
                        output[written - self.match_distance]
                    else
                        history_mod.byteFromEnd(history, self.match_distance - written) catch |err| switch (err) {
                            error.HistoryLimitExceeded => return error.HistoryLimitExceeded,
                            error.IntegerOverflow => return error.IntegerOverflow,
                            else => return error.InvalidLzvnStream,
                        };
                    written += 1;
                    self.decoded_len += 1;
                    self.pending_match -= 1;
                }
                self.stage = .opcode;
            },
            .terminal => {
                // The legacy decoder accepts arbitrary values in the seven
                // EOS continuation bytes; only their length is significant.
                while (self.header_received < 8) {
                    self.header[self.header_received] = (try self.readByte(input, &input_read)) orelse return result(input_read, written, .need_input);
                    self.header_received += 1;
                }
                if (self.input_consumed != self.compressed_len) return error.TrailingData;
                if (self.decoded_len != self.raw_size) return error.SizeMismatch;
                self.stage = .done;
                return result(input_read, written, .done);
            },
            .done => return result(input_read, written, .done),
        };
    }

    fn readByte(self: *Cursor, input: []const u8, offset: *usize) Error!?u8 {
        if (self.input_consumed == self.compressed_len) return error.TruncatedFrame;
        if (offset.* == input.len) return null;
        const byte = input[offset.*];
        offset.* += 1;
        self.input_consumed += 1;
        return byte;
    }

    fn beginItem(self: *Cursor) Error!void {
        const opcode = self.header[0];
        var literal_len: usize = 0;
        var match_len: usize = 0;
        var distance: usize = 0;
        if (opcode == 0xe0) {
            literal_len = @as(usize, self.header[1]) + 16;
        } else if (opcode <= 0xef and opcode >= 0xe1) {
            literal_len = opcode & 15;
        } else if (opcode >= 0xf0) {
            match_len = if (opcode == 0xf0) @as(usize, self.header[1]) + 16 else opcode & 15;
            distance = self.previous_distance orelse return error.InvalidLzvnStream;
        } else if (opcode >= 0xa0 and opcode <= 0xbf) {
            literal_len = (opcode >> 3) & 3;
            const tail = std.mem.readInt(u16, self.header[1..3], .little);
            match_len = (@as(usize, opcode & 7) << 2 | tail & 3) + 3;
            distance = tail >> 2;
        } else {
            literal_len = opcode >> 6;
            match_len = @as(usize, (opcode >> 3) & 7) + 3;
            distance = switch (opcode & 7) {
                0...5 => @as(usize, opcode & 7) << 8 | self.header[1],
                6 => self.previous_distance orelse return error.InvalidLzvnStream,
                7 => std.mem.readInt(u16, self.header[1..3], .little),
                else => unreachable,
            };
        }
        // Validate the item's entire logical reach before publishing its
        // literals. Subtraction avoids overflowing a very large prefix_len.
        if (literal_len > self.compressed_len - self.input_consumed) return error.TruncatedFrame;
        if (literal_len > self.raw_size - self.decoded_len) return error.OutputLimitExceeded;
        if (match_len != 0) {
            const after_literals = self.decoded_len + literal_len;
            if (distance == 0 or (distance > after_literals and distance - after_literals > self.prefix_len))
                return error.InvalidLzvnStream;
            if (match_len > self.raw_size - after_literals) return error.OutputLimitExceeded;
            self.previous_distance = distance;
        }
        self.pending_literals = literal_len;
        self.pending_match = match_len;
        self.match_distance = distance;
        self.stage = if (literal_len != 0) .literal else .match;
    }
};

fn isCombinedOpcode(opcode: u8) bool {
    const high = opcode >> 4;
    if (!(high <= 6 or high == 8 or high == 9 or high == 12)) return false;
    return opcode & 7 != 6 or high == 4 or high == 5 or high == 6 or high == 8 or high == 9 or high == 12;
}

fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
    return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
}

test {
    _ = @import("lzvn_cursor_tests.zig");
}
