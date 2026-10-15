const std = @import("std");
const core = @import("../../core.zig");
const dcl = @import("../dcl_implode.zig");

const hash_count = 1 << 16;
const max_window_size = 4096;
const lookahead_capacity = dcl.max_match_length + 2;
const pending_capacity = 16;
const no_position = std.math.maxInt(u64);

/// Caller-output DCL Implode encoder. The rolling matcher retains at most the
/// selected dictionary plus 518-byte match lookahead rather than a member.
pub const Encoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    expected_input_len: ?usize = null,
    heads: []u64,
    previous: []u64,
    history: [max_window_size]u8 = undefined,
    history_len: usize = 0,
    input: [lookahead_capacity]u8 = undefined,
    input_head: usize = 0,
    input_len: usize = 0,
    position: usize = 0,
    reservoir: u64 = 0,
    bit_count: u8 = 0,
    pending: [pending_capacity]u8 = undefined,
    pending_len: usize = 0,
    pending_offset: usize = 0,
    header_written: bool = false,
    finishing: bool = false,
    final_written: bool = false,
    done: bool = false,
    total_input: usize = 0,
    total_output: usize = 0,

    const Self = @This();

    pub const Options = struct {
        literal_coded: bool = true,
        dictionary: dcl.Dictionary = .size_4k,
        max_chain: u16 = 64,
        max_input_len: usize = std.math.maxInt(usize),
    };

    pub const Snapshot = struct {
        input_read: usize,
        output_written: usize,
        buffered_input: usize,
        pending_output: usize,
        history_len: usize,
        window_size: usize,
        finishing: bool,
        done: bool,
    };

    const Match = struct {
        length: usize = 0,
        distance: usize = 0,
    };

    pub fn init(allocator: std.mem.Allocator) dcl.Error!Self {
        return initWithOptions(allocator, .{});
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) dcl.Error!Self {
        if (options.max_chain == 0) return error.InvalidDclOptions;
        const heads = try allocator.alloc(u64, hash_count);
        errdefer allocator.free(heads);
        const previous = try allocator.alloc(u64, windowSize(options));
        errdefer allocator.free(previous);
        @memset(heads, no_position);
        @memset(previous, no_position);
        return .{
            .allocator = allocator,
            .options = options,
            .heads = heads,
            .previous = previous,
        };
    }

    pub fn initExactSize(
        allocator: std.mem.Allocator,
        options: Options,
        expected_input_len: usize,
    ) dcl.Error!Self {
        if (expected_input_len > options.max_input_len)
            return error.OutputLimitExceeded;
        var encoder = try initWithOptions(allocator, options);
        encoder.expected_input_len = expected_input_len;
        return encoder;
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
        self.reservoir = 0;
        self.bit_count = 0;
        self.pending_len = 0;
        self.pending_offset = 0;
        self.header_written = false;
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
            .input_read = self.total_input,
            .output_written = self.total_output,
            .buffered_input = self.input_len,
            .pending_output = self.pending_len - self.pending_offset,
            .history_len = self.history_len,
            .window_size = windowSize(self.options),
            .finishing = self.finishing,
            .done = self.done,
        };
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) dcl.Error!core.StepResult {
        if (self.done) {
            if (input.len != 0) return error.DclTrailingData;
            return .{ .status = .done };
        }
        if (self.finishing and input.len != 0) return error.DclTrailingData;
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

            if (!self.header_written) {
                self.appendPending(@intFromBool(self.options.literal_coded));
                self.appendPending(@intFromEnum(self.options.dictionary));
                self.header_written = true;
                continue;
            }

            if (input_read < input.len and self.input_len < lookahead_capacity) {
                try self.acceptInput(input, &input_read);
                continue;
            }

            if (self.input_len == lookahead_capacity or
                (self.finishing and self.input_len != 0))
            {
                try self.encodeNextToken();
                continue;
            }

            if (self.finishing and !self.final_written) {
                if (self.expected_input_len) |expected|
                    if (self.total_input != expected) return error.DclSizeMismatch;
                try self.write(1, 1);
                try self.writeSymbol(16, &dcl.fixed_length_table, 15);
                try self.write(255, 8);
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

    fn acceptInput(self: *Self, input: []const u8, input_read: *usize) dcl.Error!void {
        if (self.expected_input_len) |expected|
            if (self.total_input == expected) return error.DclSizeMismatch;
        if (self.total_input == self.options.max_input_len)
            return error.OutputLimitExceeded;

        var take = @min(input.len - input_read.*, lookahead_capacity - self.input_len);
        take = @min(take, self.options.max_input_len - self.total_input);
        if (self.expected_input_len) |expected|
            take = @min(take, expected - self.total_input);
        if (take == 0) return error.OutputLimitExceeded;

        const tail = (self.input_head + self.input_len) % lookahead_capacity;
        const first = @min(take, lookahead_capacity - tail);
        @memcpy(self.input[tail..][0..first], input[input_read.*..][0..first]);
        if (first != take)
            @memcpy(self.input[0 .. take - first], input[input_read.* + first ..][0 .. take - first]);
        self.input_len += take;
        input_read.* += take;
        self.total_input = std.math.add(usize, self.total_input, take) catch
            return error.IntegerOverflow;
    }

    fn encodeNextToken(self: *Self) dcl.Error!void {
        const match = self.findMatch();
        if (match.length < 2) {
            try self.write(0, 1);
            const byte = self.inputByte(0);
            if (self.options.literal_coded)
                try self.writeSymbol(256, &dcl.fixed_literal_table, byte)
            else
                try self.write(byte, 8);
            self.commitInput(1);
            return;
        }

        const length_symbol = dcl.lengthSymbol(match.length) orelse
            return error.InvalidDclStream;
        try self.write(1, 1);
        try self.writeSymbol(16, &dcl.fixed_length_table, length_symbol);
        try self.write(
            @intCast(match.length - dcl.length_base[length_symbol]),
            dcl.length_extra[length_symbol],
        );
        const dictionary_bits = dictionaryBits(self.options);
        const low_bits: u4 = if (match.length == 2) 2 else dictionary_bits;
        const stored_distance = match.distance - 1;
        try self.writeSymbol(
            64,
            &dcl.fixed_distance_table,
            @intCast(stored_distance >> low_bits),
        );
        try self.write(
            @intCast(stored_distance & ((@as(usize, 1) << low_bits) - 1)),
            low_bits,
        );
        self.commitInput(match.length);
    }

    fn findMatch(self: *const Self) Match {
        if (self.input_len < 3 or self.options.max_chain == 0) return .{};
        var candidate = self.heads[self.hashAtInput(0)];
        var remaining = @as(usize, self.options.max_chain);
        var best = Match{};
        const limit = @min(dcl.max_match_length, self.input_len);
        const window_size = windowSize(self.options);
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
            if (length > best.length and length >= 2 and
                (length != 2 or distance <= 256))
            {
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
        return self.history[absolute % windowSize(self.options)];
    }

    fn commitInput(self: *Self, count: usize) void {
        const window_size = windowSize(self.options);
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
        self.input_head = (self.input_head + count) % lookahead_capacity;
        self.input_len -= count;
    }

    fn hashAtInput(self: *const Self, offset: usize) usize {
        return ((@as(usize, self.inputByte(offset)) * 251 +
            self.inputByte(offset + 1)) * 251 + self.inputByte(offset + 2)) & 0xffff;
    }

    fn inputByte(self: *const Self, offset: usize) u8 {
        std.debug.assert(offset < self.input_len);
        return self.input[(self.input_head + offset) % lookahead_capacity];
    }

    fn write(self: *Self, value: u16, count: u4) dcl.Error!void {
        if (count == 0) return;
        std.debug.assert(value < @as(u32, 1) << count);
        self.reservoir |= @as(u64, value) << @intCast(self.bit_count);
        self.bit_count += count;
        while (self.bit_count >= 8) {
            self.appendPending(@truncate(self.reservoir));
            self.reservoir >>= 8;
            self.bit_count -= 8;
        }
    }

    fn writeSymbol(
        self: *Self,
        comptime symbol_count: usize,
        table: *const dcl.Table(symbol_count),
        symbol: u16,
    ) dcl.Error!void {
        var sink = BitSink{ .encoder = self };
        try table.encode(&sink, symbol);
    }

    const BitSink = struct {
        encoder: *Self,

        pub fn write(self: *BitSink, value: u16, count: u4) dcl.Error!void {
            try self.encoder.write(value, count);
        }
    };

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

    fn drainPending(self: *Self, output: []u8, output_written: *usize) dcl.Error!void {
        const remaining = self.pending[self.pending_offset..self.pending_len];
        const take = @min(output.len - output_written.*, remaining.len);
        @memcpy(output[output_written.*..][0..take], remaining[0..take]);
        self.pending_offset += take;
        output_written.* += take;
        self.total_output = std.math.add(usize, self.total_output, take) catch
            return error.IntegerOverflow;
    }

    fn dictionaryBits(options: Options) u4 {
        return @intCast(@intFromEnum(options.dictionary));
    }

    fn windowSize(options: Options) usize {
        return @as(usize, 1) << @intCast(dictionaryBits(options) + 6);
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
