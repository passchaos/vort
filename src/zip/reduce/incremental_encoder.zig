const std = @import("std");
const core = @import("../../core.zig");
const reduce = @import("../reduce.zig");

const hash_count = 1 << 16;
const max_window_size = 1 << 12;
const max_match_length = 385;
const lookahead_storage_len = max_match_length + 2;
const pending_capacity = 16;
const no_position = std.math.maxInt(u64);

/// Caller-output ZIP Reduce encoder shared by factors 1...4.
///
/// The format places its complete follower table before the payload. The
/// default empty table permits a bounded single pass. Callers with replayable
/// input can supply `reduce.trainFollowerTable` output to retain the exact
/// one-shot follower coding without buffering the member in this encoder.
pub const Encoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    factor: reduce.Factor,
    expected_input_len: ?usize = null,
    heads: []u64,
    previous: []u64,
    history: [max_window_size]u8 = undefined,
    history_len: usize = 0,
    input: [lookahead_storage_len]u8 = undefined,
    input_head: usize = 0,
    input_len: usize = 0,
    position: usize = 0,
    header_contexts_remaining: usize = 256,
    header_count_written: bool = false,
    header_symbol_index: usize = 0,
    last_reduced_byte: u8 = 0,
    reservoir: u64 = 0,
    bit_count: u8 = 0,
    pending: [pending_capacity]u8 = undefined,
    pending_len: usize = 0,
    pending_offset: usize = 0,
    finishing: bool = false,
    final_written: bool = false,
    done: bool = false,
    total_input: usize = 0,
    total_output: usize = 0,

    const Self = @This();

    pub const Options = struct {
        max_chain: u16 = 64,
        max_input_len: usize = std.math.maxInt(usize),
        followers: reduce.FollowerTable = .{},
    };

    pub const Snapshot = struct {
        factor: reduce.Factor,
        input_read: usize,
        output_written: usize,
        buffered_input: usize,
        pending_output: usize,
        header_contexts_remaining: usize,
        history_len: usize,
        window_size: usize,
        finishing: bool,
        done: bool,
    };

    const Match = struct {
        length: usize = 0,
        distance: usize = 0,
    };

    pub fn init(
        allocator: std.mem.Allocator,
        factor: reduce.Factor,
    ) reduce.Error!Self {
        return initWithOptions(allocator, factor, .{});
    }

    pub fn initWithOptions(
        allocator: std.mem.Allocator,
        factor: reduce.Factor,
        options: Options,
    ) reduce.Error!Self {
        try validateOptions(options);
        const heads = try allocator.alloc(u64, hash_count);
        errdefer allocator.free(heads);
        const previous = try allocator.alloc(u64, windowSize(factor));
        errdefer allocator.free(previous);
        @memset(heads, no_position);
        @memset(previous, no_position);
        return .{
            .allocator = allocator,
            .options = options,
            .factor = factor,
            .heads = heads,
            .previous = previous,
        };
    }

    pub fn initExactSize(
        allocator: std.mem.Allocator,
        factor: reduce.Factor,
        options: Options,
        expected_input_len: usize,
    ) reduce.Error!Self {
        if (expected_input_len > options.max_input_len)
            return error.OutputLimitExceeded;
        var encoder = try initWithOptions(allocator, factor, options);
        encoder.expected_input_len = expected_input_len;
        return encoder;
    }

    pub fn validateOptions(options: Options) reduce.Error!void {
        if (options.max_chain == 0) return error.InvalidReduceOptions;
        for (options.followers.counts) |count|
            if (count > 32) return error.InvalidReduceStream;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.previous);
        self.allocator.free(self.heads);
        self.* = undefined;
    }

    pub fn reset(self: *Self) void {
        @memset(self.heads, no_position);
        @memset(self.previous, no_position);
        self.history_len = 0;
        self.input_head = 0;
        self.input_len = 0;
        self.position = 0;
        self.header_contexts_remaining = 256;
        self.header_count_written = false;
        self.header_symbol_index = 0;
        self.last_reduced_byte = 0;
        self.reservoir = 0;
        self.bit_count = 0;
        self.pending_len = 0;
        self.pending_offset = 0;
        self.finishing = false;
        self.final_written = false;
        self.done = false;
        self.total_input = 0;
        self.total_output = 0;
    }

    pub fn finish(self: *Self) void {
        if (!self.done) self.finishing = true;
    }

    pub fn snapshot(self: *const Self) Snapshot {
        return .{
            .factor = self.factor,
            .input_read = self.total_input,
            .output_written = self.total_output,
            .buffered_input = self.input_len,
            .pending_output = self.pending_len - self.pending_offset,
            .header_contexts_remaining = self.header_contexts_remaining,
            .history_len = self.history_len,
            .window_size = windowSize(self.factor),
            .finishing = self.finishing,
            .done = self.done,
        };
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) reduce.Error!core.StepResult {
        if (self.done) {
            if (input.len != 0) return error.ReduceTrailingData;
            return .{ .status = .done };
        }
        if (self.finishing and input.len != 0) return error.ReduceTrailingData;
        if (output.len == 0) return .{ .status = .need_output };

        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) {
            try self.drainPending(output, &output_written);
            if (self.pending_offset != self.pending_len)
                return result(input_read, output_written, .need_output);
            self.pending_len = 0;
            self.pending_offset = 0;
            if (output_written == output.len)
                return result(input_read, output_written, .need_output);

            if (self.header_contexts_remaining != 0) {
                try self.emitHeaderPart();
                continue;
            }

            const lookahead_len = lookaheadLen(self.factor);
            if (input_read < input.len and self.input_len < lookahead_len) {
                try self.acceptInput(input, &input_read, lookahead_len);
                continue;
            }

            if (self.input_len == lookahead_len or
                (self.finishing and self.input_len != 0))
            {
                try self.encodeNextToken();
                continue;
            }

            if (self.finishing and !self.final_written) {
                if (self.expected_input_len) |expected|
                    if (self.total_input != expected) return error.ReduceSizeMismatch;
                self.flushBits();
                self.final_written = true;
                continue;
            }
            if (self.finishing) {
                self.done = true;
                return result(input_read, output_written, .done);
            }
            return result(input_read, output_written, .need_input);
        }
    }

    fn emitHeaderPart(self: *Self) reduce.Error!void {
        const context = self.header_contexts_remaining - 1;
        const count = self.options.followers.counts[context];
        if (!self.header_count_written) {
            try self.write(count, 6);
            self.header_count_written = true;
            self.header_symbol_index = 0;
            if (count == 0) self.advanceHeader();
            return;
        }
        try self.write(
            self.options.followers.symbols[context][self.header_symbol_index],
            8,
        );
        self.header_symbol_index += 1;
        if (self.header_symbol_index == count) self.advanceHeader();
    }

    fn advanceHeader(self: *Self) void {
        self.header_contexts_remaining -= 1;
        self.header_count_written = false;
        self.header_symbol_index = 0;
    }

    fn acceptInput(
        self: *Self,
        input: []const u8,
        input_read: *usize,
        lookahead_len: usize,
    ) reduce.Error!void {
        if (self.expected_input_len) |expected|
            if (self.total_input == expected) return error.ReduceSizeMismatch;
        if (self.total_input == self.options.max_input_len)
            return error.OutputLimitExceeded;

        var take = @min(input.len - input_read.*, lookahead_len - self.input_len);
        take = @min(take, self.options.max_input_len - self.total_input);
        if (self.expected_input_len) |expected|
            take = @min(take, expected - self.total_input);
        if (take == 0) return error.OutputLimitExceeded;

        const tail = (self.input_head + self.input_len) % self.input.len;
        const first = @min(take, self.input.len - tail);
        @memcpy(self.input[tail..][0..first], input[input_read.*..][0..first]);
        if (first != take)
            @memcpy(self.input[0 .. take - first], input[input_read.* + first ..][0 .. take - first]);
        self.input_len += take;
        input_read.* += take;
        self.total_input = std.math.add(usize, self.total_input, take) catch
            return error.IntegerOverflow;
    }

    fn encodeNextToken(self: *Self) reduce.Error!void {
        const match = self.findMatch();
        if (match.length < 4) {
            const byte = self.inputByte(0);
            try self.writeReducedByte(byte);
            if (byte == reduce.dle) try self.writeReducedByte(0);
            self.commitInput(1);
            return;
        }

        const factor_bits: u4 = @intFromEnum(self.factor);
        const length_bits: u4 = 8 - factor_bits;
        const length_mask: usize = (@as(usize, 1) << length_bits) - 1;
        const stored_length = match.length - 3;
        const stored_distance = match.distance - 1;
        const low_length = @min(stored_length, length_mask);
        const control: u8 = @intCast(
            ((stored_distance >> 8) << length_bits) | low_length,
        );
        try self.writeReducedByte(reduce.dle);
        try self.writeReducedByte(control);
        if (low_length == length_mask)
            try self.writeReducedByte(@intCast(stored_length - length_mask));
        try self.writeReducedByte(@truncate(stored_distance));
        self.commitInput(match.length);
    }

    fn writeReducedByte(self: *Self, byte: u8) reduce.Error!void {
        const count = self.options.followers.counts[self.last_reduced_byte];
        if (count == 0) {
            try self.write(byte, 8);
        } else if (self.followerIndex(self.last_reduced_byte, byte)) |index| {
            try self.write(0, 1);
            try self.write(index, reduce.followerBits(count));
        } else {
            try self.write(1, 1);
            try self.write(byte, 8);
        }
        self.last_reduced_byte = byte;
    }

    fn followerIndex(self: *const Self, previous_byte: u8, byte: u8) ?u8 {
        for (
            self.options.followers.symbols[previous_byte][0..self.options.followers.counts[previous_byte]],
            0..,
        ) |candidate, index| {
            if (candidate == byte) return @intCast(index);
        }
        return null;
    }

    fn findMatch(self: *const Self) Match {
        if (self.input_len < 4 or self.options.max_chain == 0) return .{};
        var candidate = self.heads[self.hashAtInput(0)];
        var remaining = @as(usize, self.options.max_chain);
        var best = Match{};
        const limit = @min(maximumMatchLength(self.factor), self.input_len);
        const window_size = windowSize(self.factor);
        while (candidate != no_position and remaining != 0) : (remaining -= 1) {
            const source: usize = @intCast(candidate);
            const distance = self.position - source;
            if (distance == 0 or distance > window_size) break;
            var length: usize = 0;
            while (length < limit and
                self.sourceByte(source, length) == self.inputByte(length))
            {
                length += 1;
            }
            if (length > best.length and length >= 4) {
                best = .{ .length = length, .distance = distance };
                if (length == limit) break;
            }
            candidate = self.previous[source % window_size];
        }
        return best;
    }

    fn sourceByte(self: *const Self, source: usize, offset: usize) u8 {
        const absolute = source + offset;
        if (absolute >= self.position)
            return self.inputByte(absolute - self.position);
        return self.history[absolute % windowSize(self.factor)];
    }

    fn commitInput(self: *Self, count: usize) void {
        const window_size = windowSize(self.factor);
        for (0..count) |offset| {
            const absolute = self.position + offset;
            if (self.input_len - offset >= 3) {
                const hash = self.hashAtInput(offset);
                self.previous[absolute % window_size] = self.heads[hash];
                self.heads[hash] = @intCast(absolute);
            }
            self.history[absolute % window_size] = self.inputByte(offset);
        }
        self.position += count;
        self.history_len = @min(self.history_len + count, window_size);
        self.input_head = (self.input_head + count) % self.input.len;
        self.input_len -= count;
    }

    fn hashAtInput(self: *const Self, offset: usize) usize {
        return ((@as(usize, self.inputByte(offset)) * 251 +
            self.inputByte(offset + 1)) * 251 + self.inputByte(offset + 2)) & 0xffff;
    }

    fn inputByte(self: *const Self, offset: usize) u8 {
        std.debug.assert(offset < self.input_len);
        return self.input[(self.input_head + offset) % self.input.len];
    }

    fn write(self: *Self, value: u8, count: u4) reduce.Error!void {
        if (count == 0) return;
        std.debug.assert(value < @as(u16, 1) << count);
        self.reservoir |= @as(u64, value) << @intCast(self.bit_count);
        self.bit_count += count;
        while (self.bit_count >= 8) {
            self.appendPending(@truncate(self.reservoir));
            self.reservoir >>= 8;
            self.bit_count -= 8;
        }
    }

    fn flushBits(self: *Self) void {
        if (self.bit_count != 0) self.appendPending(@truncate(self.reservoir));
        self.reservoir = 0;
        self.bit_count = 0;
    }

    fn appendPending(self: *Self, byte: u8) void {
        std.debug.assert(self.pending_len < self.pending.len);
        self.pending[self.pending_len] = byte;
        self.pending_len += 1;
    }

    fn drainPending(self: *Self, output: []u8, output_written: *usize) reduce.Error!void {
        const remaining = self.pending[self.pending_offset..self.pending_len];
        const take = @min(output.len - output_written.*, remaining.len);
        @memcpy(output[output_written.*..][0..take], remaining[0..take]);
        self.pending_offset += take;
        output_written.* += take;
        self.total_output = std.math.add(usize, self.total_output, take) catch
            return error.IntegerOverflow;
    }

    fn maximumMatchLength(factor: reduce.Factor) usize {
        const factor_bits: u4 = @intFromEnum(factor);
        const length_bits: u4 = 8 - factor_bits;
        return ((@as(usize, 1) << length_bits) - 1) + 255 + 3;
    }

    fn lookaheadLen(factor: reduce.Factor) usize {
        return maximumMatchLength(factor) + 2;
    }

    fn windowSize(factor: reduce.Factor) usize {
        const factor_bits: u4 = @intFromEnum(factor);
        return @as(usize, 1) << @intCast(@as(u4, 8) + factor_bits);
    }

    fn result(
        input_read: usize,
        output_written: usize,
        status: core.StepResult.Status,
    ) core.StepResult {
        return .{
            .progress = .{
                .input_read = input_read,
                .output_written = output_written,
            },
            .status = status,
        };
    }
};
