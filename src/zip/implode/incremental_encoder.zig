const std = @import("std");
const core = @import("../../core.zig");
const implode = @import("../implode.zig");

const hash_count = 1 << 16;
const max_window_size = 8192;
const literal_symbols: usize = 256;
const length_symbols: usize = 64;
const distance_symbols: usize = 64;
const length_direct_bits: u5 = 8;
const max_lookahead_len = 323;
const max_header_len = 27;
const pending_capacity = 16;
const no_position = std.math.maxInt(u64);

/// Caller-output Traditional Implode encoder for every 4/8 KiB × raw/tree
/// literal mode. Fixed tree headers are known before input, so the encoder
/// retains only bounded lookahead, history, matcher state and pending bits.
pub const Encoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    expected_input_len: ?usize = null,
    heads: []u64,
    previous: []u64,
    history: [max_window_size]u8 = undefined,
    history_len: usize = 0,
    input: [max_lookahead_len]u8 = undefined,
    input_head: usize = 0,
    input_len: usize = 0,
    position: usize = 0,
    header: [max_header_len]u8 = undefined,
    header_len: usize = 0,
    header_offset: usize = 0,
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
        dictionary: implode.Dictionary = .large_8k,
        literal_tree: bool = true,
        max_chain: u16 = 64,
        max_input_len: usize = std.math.maxInt(usize),

        pub fn flags(self: Options) u16 {
            return (@as(u16, @intFromBool(self.dictionary == .large_8k)) << 1) |
                (@as(u16, @intFromBool(self.literal_tree)) << 2);
        }
    };

    pub const Snapshot = struct {
        input_read: usize,
        output_written: usize,
        buffered_input: usize,
        pending_output: usize,
        header_remaining: usize,
        history_len: usize,
        window_size: usize,
        finishing: bool,
        done: bool,
    };

    const Match = struct {
        length: usize = 0,
        distance: usize = 0,
    };

    pub fn init(allocator: std.mem.Allocator) implode.Error!Self {
        return initWithOptions(allocator, .{});
    }

    pub fn initWithOptions(
        allocator: std.mem.Allocator,
        options: Options,
    ) implode.Error!Self {
        if (options.max_chain == 0) return error.InvalidImplodeOptions;
        const heads = try allocator.alloc(u64, hash_count);
        errdefer allocator.free(heads);
        const previous = try allocator.alloc(u64, windowSize(options));
        errdefer allocator.free(previous);
        @memset(heads, no_position);
        @memset(previous, no_position);
        var encoder: Self = .{
            .allocator = allocator,
            .options = options,
            .heads = heads,
            .previous = previous,
        };
        encoder.buildHeader();
        return encoder;
    }

    pub fn initExactSize(
        allocator: std.mem.Allocator,
        options: Options,
        expected_input_len: usize,
    ) implode.Error!Self {
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
        self.header_offset = 0;
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

    pub fn flags(self: *const Self) u16 {
        return self.options.flags();
    }

    pub fn snapshot(self: *const Self) Snapshot {
        return .{
            .input_read = self.total_input,
            .output_written = self.total_output,
            .buffered_input = self.input_len,
            .pending_output = self.pending_len - self.pending_offset,
            .header_remaining = self.header_len - self.header_offset,
            .history_len = self.history_len,
            .window_size = windowSize(self.options),
            .finishing = self.finishing,
            .done = self.done,
        };
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) implode.Error!core.StepResult {
        if (self.done) {
            if (input.len != 0) return error.ImplodeTrailingData;
            return .{ .status = .done };
        }
        if (self.finishing and input.len != 0) return error.ImplodeTrailingData;
        if (output.len == 0) return .{ .status = .need_output };

        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) {
            try self.drainHeader(output, &output_written);
            if (self.header_offset != self.header_len)
                return result(input_read, output_written, .need_output);
            if (output_written == output.len)
                return result(input_read, output_written, .need_output);

            try self.drainPending(output, &output_written);
            if (self.pending_offset != self.pending_len)
                return result(input_read, output_written, .need_output);
            self.pending_len = 0;
            self.pending_offset = 0;
            if (output_written == output.len)
                return result(input_read, output_written, .need_output);

            const lookahead_len = lookaheadLen(self.options);
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
                    if (self.total_input != expected) return error.ImplodeSizeMismatch;
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

    fn buildHeader(self: *Self) void {
        self.header_len = 0;
        if (self.options.literal_tree) self.appendFixedTree(literal_symbols, 8);
        self.appendFixedTree(length_symbols, 6);
        self.appendFixedTree(distance_symbols, 6);
    }

    fn appendFixedTree(self: *Self, symbol_count: usize, bit_length: u8) void {
        const records = symbol_count / 16;
        self.header[self.header_len] = @intCast(records - 1);
        self.header_len += 1;
        const descriptor: u8 = 0xf0 | (bit_length - 1);
        @memset(self.header[self.header_len .. self.header_len + records], descriptor);
        self.header_len += records;
    }

    fn acceptInput(
        self: *Self,
        input: []const u8,
        input_read: *usize,
        lookahead_len: usize,
    ) implode.Error!void {
        if (self.expected_input_len) |expected|
            if (self.total_input == expected) return error.ImplodeSizeMismatch;
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

    fn encodeNextToken(self: *Self) implode.Error!void {
        const match = self.findMatch();
        const minimum_length = minimumLength(self.options);
        if (match.length < minimum_length) {
            try self.write(1, 1);
            const byte = self.inputByte(0);
            if (self.options.literal_tree)
                try self.writeFixedSymbol(byte, literal_symbols, 8)
            else
                try self.write(byte, 8);
            self.commitInput(1);
            return;
        }

        try self.write(0, 1);
        const distance_bits: u5 = if (self.options.dictionary == .large_8k) 7 else 6;
        const stored_distance = match.distance - 1;
        try self.write(
            @intCast(stored_distance & ((@as(usize, 1) << distance_bits) - 1)),
            distance_bits,
        );
        try self.writeFixedSymbol(
            @intCast(stored_distance >> distance_bits),
            distance_symbols,
            6,
        );
        const stored_length = match.length - minimum_length;
        const length_symbol: u16 = @intCast(@min(stored_length, length_symbols - 1));
        try self.writeFixedSymbol(length_symbol, length_symbols, 6);
        if (length_symbol == length_symbols - 1)
            try self.write(@intCast(stored_length - (length_symbols - 1)), length_direct_bits);
        self.commitInput(match.length);
    }

    fn findMatch(self: *const Self) Match {
        const minimum_length = minimumLength(self.options);
        if (self.input_len < minimum_length or self.options.max_chain == 0) return .{};
        var candidate = self.heads[self.hashAtInput(0)];
        var remaining = @as(usize, self.options.max_chain);
        var best = Match{};
        const limit = @min(maximumLength(self.options), self.input_len);
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
            if (length > best.length and length >= minimum_length) {
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
        const minimum_length = minimumLength(self.options);
        for (0..count) |offset| {
            const absolute = self.position + offset;
            if (self.input_len - offset >= minimum_length) {
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
        if (minimumLength(self.options) == 2)
            return (@as(usize, self.inputByte(offset)) << 8) | self.inputByte(offset + 1);
        return ((@as(usize, self.inputByte(offset)) * 251 +
            self.inputByte(offset + 1)) * 251 + self.inputByte(offset + 2)) & 0xffff;
    }

    fn inputByte(self: *const Self, offset: usize) u8 {
        std.debug.assert(offset < self.input_len);
        return self.input[(self.input_head + offset) % self.input.len];
    }

    fn writeFixedSymbol(
        self: *Self,
        symbol: u16,
        symbol_count: u16,
        bits: u5,
    ) implode.Error!void {
        const code = symbol_count - 1 - symbol;
        try self.write(reverseBits(code, bits), bits);
    }

    fn write(self: *Self, value: u16, count: u5) implode.Error!void {
        std.debug.assert(value < @as(u32, 1) << @intCast(count));
        self.reservoir |= @as(u64, value) << @intCast(self.bit_count);
        self.bit_count += @intCast(count);
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

    fn drainHeader(self: *Self, output: []u8, output_written: *usize) implode.Error!void {
        const remaining = self.header[self.header_offset..self.header_len];
        const take = @min(output.len - output_written.*, remaining.len);
        @memcpy(output[output_written.*..][0..take], remaining[0..take]);
        self.header_offset += take;
        output_written.* += take;
        self.total_output = std.math.add(usize, self.total_output, take) catch
            return error.IntegerOverflow;
    }

    fn drainPending(self: *Self, output: []u8, output_written: *usize) implode.Error!void {
        const remaining = self.pending[self.pending_offset..self.pending_len];
        const take = @min(output.len - output_written.*, remaining.len);
        @memcpy(output[output_written.*..][0..take], remaining[0..take]);
        self.pending_offset += take;
        output_written.* += take;
        self.total_output = std.math.add(usize, self.total_output, take) catch
            return error.IntegerOverflow;
    }

    fn minimumLength(options: Options) usize {
        return if (options.literal_tree) 3 else 2;
    }

    fn maximumLength(options: Options) usize {
        return minimumLength(options) + 63 + 255;
    }

    fn lookaheadLen(options: Options) usize {
        return maximumLength(options) + minimumLength(options) - 1;
    }

    fn windowSize(options: Options) usize {
        return if (options.dictionary == .large_8k) 8192 else 4096;
    }

    fn reverseBits(value: u16, count: u5) u16 {
        var source = value;
        var reversed: u16 = 0;
        for (0..count) |_| {
            reversed = (reversed << 1) | (source & 1);
            source >>= 1;
        }
        return reversed;
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
