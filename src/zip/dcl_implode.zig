const std = @import("std");
const core = @import("../core.zig");

pub const Error = std.mem.Allocator.Error || error{
    InvalidDclStream,
    TruncatedDclInput,
    DclSizeMismatch,
    DclTrailingData,
    InvalidDclOptions,
    OutputLimitExceeded,
    IntegerOverflow,
};

pub const Dictionary = enum(u3) {
    size_1k = 4,
    size_2k = 5,
    size_4k = 6,
};

pub const Options = struct {
    literal_coded: bool = true,
    dictionary: Dictionary = .size_4k,
    max_chain: u16 = 64,
};

const max_bits: usize = 13;
const max_match_length: usize = 518;
const length_base = [16]u16{ 3, 2, 4, 5, 6, 7, 8, 9, 10, 12, 16, 24, 40, 72, 136, 264 };
const length_extra = [16]u4{ 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8 };

const literal_repetitions = [_]u8{
    11, 124, 8,   7,  28, 7,   188, 13,  76,  4,   10,  8,  12, 10, 12, 10, 8,  23, 8,
    9,  7,   6,   7,  8,  7,   6,   55,  8,   23,  24,  12, 11, 7,  9,  11, 12, 6,  7,
    22, 5,   7,   24, 6,  11,  9,   6,   7,   22,  7,   11, 38, 7,  9,  8,  25, 11, 8,
    11, 9,   12,  8,  12, 5,   38,  5,   38,  5,   11,  7,  5,  6,  21, 6,  10, 53, 8,
    7,  24,  10,  27, 44, 253, 253, 253, 252, 252, 252, 13, 12, 45, 12, 45, 12, 61, 12,
    45, 44,  173,
};
const length_repetitions = [_]u8{ 2, 35, 36, 53, 38, 23 };
const distance_repetitions = [_]u8{ 2, 20, 53, 230, 247, 151, 248 };

const BitReader = struct {
    input: []const u8,
    byte_offset: usize = 0,
    reservoir: u64 = 0,
    bit_count: u8 = 0,

    fn read(self: *BitReader, count: u4) Error!u16 {
        if (count == 0) return 0;
        while (self.bit_count < count) {
            if (self.byte_offset == self.input.len) return error.TruncatedDclInput;
            self.reservoir |= @as(u64, self.input[self.byte_offset]) << @intCast(self.bit_count);
            self.byte_offset += 1;
            self.bit_count += 8;
        }
        const result: u16 = @truncate(self.reservoir & ((@as(u64, 1) << count) - 1));
        self.reservoir >>= count;
        self.bit_count -= count;
        return result;
    }

    fn finish(self: *const BitReader) Error!void {
        if (self.byte_offset != self.input.len) return error.DclTrailingData;
    }
};

const BitWriter = struct {
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    reservoir: u64 = 0,
    bit_count: u8 = 0,

    fn write(self: *BitWriter, value: u16, count: u4) Error!void {
        if (count == 0) return;
        std.debug.assert(value < @as(u32, 1) << count);
        self.reservoir |= @as(u64, value) << @intCast(self.bit_count);
        self.bit_count += count;
        while (self.bit_count >= 8) {
            try self.output.append(self.allocator, @truncate(self.reservoir));
            self.reservoir >>= 8;
            self.bit_count -= 8;
        }
    }

    fn finish(self: *BitWriter) Error!void {
        if (self.bit_count != 0)
            try self.output.append(self.allocator, @truncate(self.reservoir));
        self.reservoir = 0;
        self.bit_count = 0;
    }
};

fn Table(comptime symbol_count: usize) type {
    return struct {
        counts: [max_bits + 1]u16 = @splat(0),
        symbols: [symbol_count]u16 = @splat(0),
        lengths: [symbol_count]u4 = @splat(0),
        codes: [symbol_count]u16 = @splat(0),

        const Self = @This();

        fn init(repetitions: []const u8) Error!Self {
            var table = Self{};
            var symbol: usize = 0;
            for (repetitions) |descriptor| {
                const repeat_count = @as(usize, descriptor >> 4) + 1;
                const length = descriptor & 0x0f;
                if (length > max_bits or symbol + repeat_count > symbol_count)
                    return error.InvalidDclStream;
                @memset(table.lengths[symbol .. symbol + repeat_count], @intCast(length));
                symbol += repeat_count;
            }
            if (symbol != symbol_count) return error.InvalidDclStream;
            for (table.lengths) |length| table.counts[length] += 1;
            var left: i32 = 1;
            for (1..max_bits + 1) |length| {
                left = (left << 1) - table.counts[length];
                if (left < 0) return error.InvalidDclStream;
            }

            var offsets: [max_bits + 1]u16 = @splat(0);
            for (1..max_bits) |length|
                offsets[length + 1] = offsets[length] + table.counts[length];
            var write_offsets = offsets;
            for (table.lengths, 0..) |length, value| {
                if (length != 0) {
                    table.symbols[write_offsets[length]] = @intCast(value);
                    write_offsets[length] += 1;
                }
            }

            var first_code: u16 = 0;
            var previous_count: u16 = 0;
            for (1..max_bits + 1) |length| {
                first_code = (first_code + previous_count) << 1;
                var ordinal: u16 = 0;
                for (0..symbol_count) |value| {
                    if (table.lengths[value] == length) {
                        table.codes[value] = first_code + ordinal;
                        ordinal += 1;
                    }
                }
                previous_count = table.counts[length];
            }
            return table;
        }

        fn decode(self: *const Self, reader: *BitReader) Error!u16 {
            var code: u16 = 0;
            var first: u16 = 0;
            var index: u16 = 0;
            for (1..max_bits + 1) |length| {
                code = (code << 1) | ((try reader.read(1)) ^ 1);
                const count = self.counts[length];
                if (code >= first and code - first < count)
                    return self.symbols[index + code - first];
                index += count;
                first = (first + count) << 1;
            }
            return error.InvalidDclStream;
        }

        fn encode(self: *const Self, writer: *BitWriter, symbol: u16) Error!void {
            if (symbol >= symbol_count) return error.InvalidDclStream;
            const length = self.lengths[symbol];
            if (length == 0) return error.InvalidDclStream;
            const mask: u16 = (@as(u16, 1) << @intCast(length)) - 1;
            try writer.write(reverseBits((self.codes[symbol] ^ mask) & mask, length), length);
        }
    };
}

fn reverseBits(value: u16, count: u4) u16 {
    var source = value;
    var result: u16 = 0;
    for (0..count) |_| {
        result = (result << 1) | (source & 1);
        source >>= 1;
    }
    return result;
}

const fixed_literal_table = blk: {
    @setEvalBranchQuota(20_000);
    break :blk Table(256).init(&literal_repetitions) catch unreachable;
};
const fixed_length_table = blk: {
    @setEvalBranchQuota(5_000);
    break :blk Table(16).init(&length_repetitions) catch unreachable;
};
const fixed_distance_table = blk: {
    @setEvalBranchQuota(10_000);
    break :blk Table(64).init(&distance_repetitions) catch unreachable;
};

/// Caller-output, byte-progressive DCL Implode decoder.
pub const IncrementalDecoder = struct {
    options: DecodeOptions,
    phase: Phase = .header,
    header: [2]u8 = undefined,
    header_len: usize = 0,
    literal_coded: bool = false,
    dictionary_bits: u4 = 0,
    window_size: usize = 0,
    reservoir: u64 = 0,
    bit_count: u8 = 0,
    huffman: HuffmanState = .{},
    match_length: usize = 0,
    match_remaining: usize = 0,
    match_distance: usize = 0,
    history: [4096]u8 = undefined,
    history_pos: usize = 0,
    history_len: usize = 0,
    input_finished: bool = false,
    total_input: usize = 0,
    total_output: usize = 0,
    last_error_name: []const u8 = "",
    last_error_phase: Phase = .header,

    const Self = @This();

    pub const DecodeOptions = struct {
        max_output_len: usize = std.math.maxInt(usize),
        expected_output_len: ?usize = null,
        allow_trailing_data: bool = false,
    };
    pub const Phase = enum {
        header,
        token,
        literal_raw,
        literal_coded,
        length_symbol,
        length_extra,
        distance_symbol,
        distance_low,
        match_copy,
        done,
        failed,
    };
    pub const Snapshot = struct {
        phase: Phase,
        input_read: usize,
        output_written: usize,
        history_len: usize,
        window_size: usize,
        pending_match_bytes: usize,
        last_error_name: []const u8,
        last_error_phase: Phase,
    };

    const HuffmanState = struct {
        code: u16 = 0,
        first: u16 = 0,
        index: u16 = 0,
        length: u4 = 1,

        fn reset(self: *HuffmanState) void {
            self.* = .{};
        }
    };

    pub fn init() Self {
        return initWithOptions(.{});
    }

    pub fn initWithOptions(options: DecodeOptions) Self {
        return .{ .options = options };
    }

    pub fn reset(self: *Self) void {
        const options = self.options;
        self.* = initWithOptions(options);
    }

    pub fn finish(self: *Self) Error!void {
        self.input_finished = true;
        if (self.phase != .done) return self.fail(error.TruncatedDclInput);
    }

    pub fn snapshot(self: *const Self) Snapshot {
        return .{
            .phase = self.phase,
            .input_read = self.total_input,
            .output_written = self.total_output,
            .history_len = self.history_len,
            .window_size = self.window_size,
            .pending_match_bytes = self.match_remaining,
            .last_error_name = self.last_error_name,
            .last_error_phase = self.last_error_phase,
        };
    }

    pub fn diagnostics(self: *const Self) core.StreamingDiagnostics {
        return .{
            .phase_name = @tagName(self.phase),
            .header_received = self.header_len,
            .frame_input_read = self.total_input,
            .output_written = self.total_output,
            .expected_output_len = self.options.expected_output_len,
            .payload_remaining = self.match_remaining,
            .last_error_name = self.last_error_name,
            .last_error_phase_name = if (self.last_error_name.len == 0) "" else @tagName(self.last_error_phase),
            .recoverability_hint_name = if (self.phase == .failed) "payload_corrupt" else "none",
        };
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.phase == .failed) return error.InvalidDclStream;
        return self.stepInner(input, output) catch |err| {
            return self.fail(err);
        };
    }

    fn stepInner(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) switch (self.phase) {
            .header => {
                while (self.header_len < self.header.len and input_read < input.len) {
                    self.header[self.header_len] = input[input_read];
                    self.header_len += 1;
                    input_read += 1;
                    self.total_input += 1;
                }
                if (self.header_len != self.header.len)
                    return self.needInputOrTruncated(input_read, output_written);
                if (self.header[0] > 1 or self.header[1] < 4 or self.header[1] > 6)
                    return self.fail(error.InvalidDclStream);
                self.literal_coded = self.header[0] != 0;
                self.dictionary_bits = @intCast(self.header[1]);
                self.window_size = @as(usize, 1) << @intCast(self.dictionary_bits + 6);
                self.phase = .token;
            },
            .token => {
                const token = self.readBits(input, &input_read, 1) orelse
                    return self.needInputOrTruncated(input_read, output_written);
                self.phase = if (token == 0)
                    if (self.literal_coded) .literal_coded else .literal_raw
                else
                    .length_symbol;
            },
            .literal_raw => {
                if (output_written == output.len)
                    return result(input_read, output_written, .need_output);
                const byte = self.readBits(input, &input_read, 8) orelse
                    return self.needInputOrTruncated(input_read, output_written);
                try self.emitByte(@truncate(byte), output, &output_written);
                self.phase = .token;
            },
            .literal_coded => {
                if (output_written == output.len)
                    return result(input_read, output_written, .need_output);
                const symbol = (try self.decodeTable(256, &fixed_literal_table, input, &input_read)) orelse
                    return self.needInputOrTruncated(input_read, output_written);
                try self.emitByte(@intCast(symbol), output, &output_written);
                self.phase = .token;
            },
            .length_symbol => {
                const symbol = (try self.decodeTable(16, &fixed_length_table, input, &input_read)) orelse
                    return self.needInputOrTruncated(input_read, output_written);
                self.match_length = length_base[symbol];
                self.match_distance = symbol;
                self.phase = .length_extra;
            },
            .length_extra => {
                const symbol = self.match_distance;
                const extra = self.readBits(input, &input_read, length_extra[symbol]) orelse
                    return self.needInputOrTruncated(input_read, output_written);
                self.match_length += extra;
                if (self.match_length == 519) {
                    if (self.options.expected_output_len) |expected|
                        if (self.total_output != expected) return self.fail(error.DclSizeMismatch);
                    self.phase = .done;
                    continue;
                }
                self.phase = .distance_symbol;
            },
            .distance_symbol => {
                const symbol = (try self.decodeTable(64, &fixed_distance_table, input, &input_read)) orelse
                    return self.needInputOrTruncated(input_read, output_written);
                self.match_distance = @as(usize, symbol) <<
                    (if (self.match_length == 2) 2 else self.dictionary_bits);
                self.phase = .distance_low;
            },
            .distance_low => {
                const low_bits: u4 = if (self.match_length == 2) 2 else self.dictionary_bits;
                const low = self.readBits(input, &input_read, low_bits) orelse
                    return self.needInputOrTruncated(input_read, output_written);
                self.match_distance += low + 1;
                if (self.match_distance > self.history_len) return self.fail(error.InvalidDclStream);
                if (self.match_length > self.options.max_output_len -| self.total_output)
                    return self.fail(error.OutputLimitExceeded);
                if (self.options.expected_output_len) |expected|
                    if (self.match_length > expected -| self.total_output)
                        return self.fail(error.DclSizeMismatch);
                self.match_remaining = self.match_length;
                self.phase = .match_copy;
            },
            .match_copy => {
                if (self.match_remaining == 0) {
                    self.phase = .token;
                    continue;
                }
                if (output_written == output.len)
                    return result(input_read, output_written, .need_output);
                const source = (self.history_pos + self.window_size - self.match_distance) % self.window_size;
                const byte = self.history[source];
                try self.emitByte(byte, output, &output_written);
                self.match_remaining -= 1;
            },
            .done => {
                if (input_read != input.len and !self.options.allow_trailing_data)
                    return self.fail(error.DclTrailingData);
                return result(input_read, output_written, .done);
            },
            .failed => return error.InvalidDclStream,
        };
    }

    fn decodeTable(
        self: *Self,
        comptime symbol_count: usize,
        table: *const Table(symbol_count),
        input: []const u8,
        input_read: *usize,
    ) Error!?u16 {
        while (self.huffman.length <= max_bits) {
            const bit = self.readBits(input, input_read, 1) orelse return null;
            self.huffman.code = (self.huffman.code << 1) | (bit ^ 1);
            const count = table.counts[self.huffman.length];
            if (self.huffman.code >= self.huffman.first and
                self.huffman.code - self.huffman.first < count)
            {
                const symbol = table.symbols[self.huffman.index + self.huffman.code - self.huffman.first];
                self.huffman.reset();
                return symbol;
            }
            self.huffman.index += count;
            self.huffman.first = (self.huffman.first + count) << 1;
            self.huffman.length += 1;
        }
        return self.fail(error.InvalidDclStream);
    }

    fn readBits(self: *Self, input: []const u8, input_read: *usize, count: u4) ?u16 {
        if (count == 0) return 0;
        while (self.bit_count < count) {
            if (input_read.* == input.len) return null;
            self.reservoir |= @as(u64, input[input_read.*]) << @intCast(self.bit_count);
            self.bit_count += 8;
            input_read.* += 1;
            self.total_input += 1;
        }
        const value: u16 = @truncate(self.reservoir & ((@as(u64, 1) << count) - 1));
        self.reservoir >>= count;
        self.bit_count -= count;
        return value;
    }

    fn emitByte(self: *Self, byte: u8, output: []u8, output_written: *usize) Error!void {
        if (self.total_output >= self.options.max_output_len)
            return self.fail(error.OutputLimitExceeded);
        if (self.options.expected_output_len) |expected|
            if (self.total_output >= expected) return self.fail(error.DclSizeMismatch);
        output[output_written.*] = byte;
        output_written.* += 1;
        self.history[self.history_pos] = byte;
        self.history_pos = (self.history_pos + 1) % self.window_size;
        self.history_len = @min(self.history_len + 1, self.window_size);
        self.total_output += 1;
    }

    fn needInputOrTruncated(self: *Self, input_read: usize, output_written: usize) Error!core.StepResult {
        if (self.input_finished) return self.fail(error.TruncatedDclInput);
        return result(input_read, output_written, .need_input);
    }

    fn fail(self: *Self, err: Error) Error {
        if (self.phase != .failed) {
            self.last_error_name = @errorName(err);
            self.last_error_phase = self.phase;
            self.phase = .failed;
        }
        return err;
    }

    fn result(
        input_read: usize,
        output_written: usize,
        status: core.StepResult.Status,
    ) core.StepResult {
        return .{
            .progress = .{ .input_read = input_read, .output_written = output_written },
            .status = status,
        };
    }
};

pub fn decodeInto(input: []const u8, output: []u8) Error!void {
    var reader = BitReader{ .input = input };
    const literal_mode = try reader.read(8);
    if (literal_mode > 1) return error.InvalidDclStream;
    const dictionary_bits = try reader.read(8);
    if (dictionary_bits < 4 or dictionary_bits > 6) return error.InvalidDclStream;
    const literal_table = try Table(256).init(&literal_repetitions);
    const length_table = try Table(16).init(&length_repetitions);
    const distance_table = try Table(64).init(&distance_repetitions);
    var output_offset: usize = 0;

    while (true) {
        if (try reader.read(1) == 0) {
            if (output_offset == output.len) return error.DclSizeMismatch;
            output[output_offset] = if (literal_mode != 0)
                @intCast(try literal_table.decode(&reader))
            else
                @truncate(try reader.read(8));
            output_offset += 1;
            continue;
        }

        const length_symbol = try length_table.decode(&reader);
        const length = @as(usize, length_base[length_symbol]) +
            try reader.read(length_extra[length_symbol]);
        if (length == 519) break;
        const low_bits: u4 = if (length == 2) 2 else @intCast(dictionary_bits);
        const distance = (@as(usize, try distance_table.decode(&reader)) << low_bits) +
            try reader.read(low_bits) + 1;
        if (distance > output_offset) return error.InvalidDclStream;
        if (length > output.len - output_offset) return error.DclSizeMismatch;
        for (0..length) |_| {
            output[output_offset] = output[output_offset - distance];
            output_offset += 1;
        }
    }
    if (output_offset != output.len) return error.DclSizeMismatch;
    try reader.finish();
}

fn hashAt(input: []const u8, position: usize) usize {
    return ((@as(usize, input[position]) * 251 + input[position + 1]) * 251 +
        input[position + 2]) & 0xffff;
}

fn insertPosition(input: []const u8, position: usize, heads: []i32, previous: []i32) void {
    if (input.len - position < 3) return;
    const hash = hashAt(input, position);
    previous[position % previous.len] = heads[hash];
    heads[hash] = @intCast(position);
}

const Match = struct { length: usize = 0, distance: usize = 0 };

fn findMatch(
    input: []const u8,
    position: usize,
    window_size: usize,
    max_chain: usize,
    heads: []const i32,
    previous: []const i32,
) Match {
    if (input.len - position < 2 or max_chain == 0) return .{};
    var candidate: i32 = if (input.len - position >= 3)
        heads[hashAt(input, position)]
    else
        -1;
    var remaining = max_chain;
    var best = Match{};
    while (candidate >= 0 and remaining != 0) : (remaining -= 1) {
        const source: usize = @intCast(candidate);
        const distance = position - source;
        if (distance == 0 or distance > window_size) break;
        var length: usize = 0;
        const limit = @min(max_match_length, input.len - position);
        while (length < limit and input[source + length] == input[position + length])
            length += 1;
        if (length > best.length and length >= 2 and (length != 2 or distance <= 256)) {
            best = .{ .length = length, .distance = distance };
            if (length == limit) break;
        }
        candidate = previous[source % previous.len];
    }
    return best;
}

fn lengthSymbol(length: usize) ?u16 {
    if (length > max_match_length) return null;
    for (0..length_base.len) |symbol| {
        const base = length_base[symbol];
        const range = @as(usize, 1) << length_extra[symbol];
        if (length >= base and length < base + range) return @intCast(symbol);
    }
    return null;
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    options: Options,
) Error!usize {
    if (options.max_chain == 0) return error.InvalidDclOptions;
    const start = output.items.len;
    errdefer output.items.len = start;
    const literal_table = try Table(256).init(&literal_repetitions);
    const length_table = try Table(16).init(&length_repetitions);
    const distance_table = try Table(64).init(&distance_repetitions);
    var writer = BitWriter{ .allocator = allocator, .output = output };
    try writer.write(@intFromBool(options.literal_coded), 8);
    const dictionary_bits: u4 = @intCast(@intFromEnum(options.dictionary));
    try writer.write(dictionary_bits, 8);
    const window_size: usize = @as(usize, 1) << @intCast(dictionary_bits + 6);
    const heads = try allocator.alloc(i32, 1 << 16);
    defer allocator.free(heads);
    @memset(heads, -1);
    const previous = try allocator.alloc(i32, window_size);
    defer allocator.free(previous);
    @memset(previous, -1);

    var position: usize = 0;
    while (position < input.len) {
        const match = findMatch(
            input,
            position,
            window_size,
            options.max_chain,
            heads,
            previous,
        );
        if (match.length < 2) {
            try writer.write(0, 1);
            if (options.literal_coded)
                try literal_table.encode(&writer, input[position])
            else
                try writer.write(input[position], 8);
            insertPosition(input, position, heads, previous);
            position += 1;
            continue;
        }

        const length_symbol = lengthSymbol(match.length) orelse return error.InvalidDclStream;
        try writer.write(1, 1);
        try length_table.encode(&writer, length_symbol);
        try writer.write(
            @intCast(match.length - length_base[length_symbol]),
            length_extra[length_symbol],
        );
        const low_bits: u4 = if (match.length == 2) 2 else dictionary_bits;
        const stored_distance = match.distance - 1;
        try distance_table.encode(&writer, @intCast(stored_distance >> low_bits));
        try writer.write(@intCast(stored_distance & ((@as(usize, 1) << low_bits) - 1)), low_bits);
        for (0..match.length) |offset|
            insertPosition(input, position + offset, heads, previous);
        position += match.length;
    }

    try writer.write(1, 1);
    try length_table.encode(&writer, 15);
    try writer.write(255, 8);
    try writer.finish();
    return output.items.len - start;
}

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: Options,
) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, input, options);
    return output.toOwnedSlice(allocator);
}

test "DCL Implode decodes the blast reference vector" {
    const encoded = [_]u8{ 0x00, 0x04, 0x82, 0x24, 0x25, 0x8f, 0x80, 0x7f };
    var output: [13]u8 = undefined;
    try decodeInto(&encoded, &output);
    try std.testing.expectEqualSlices(u8, "AIAIAIAIAIAIA", &output);
}

test "DCL Implode round trips literal and dictionary modes" {
    const input = ("DCL Implode payload\n" ** 256) ++ ([_]u8{ 0, 1, 2, 3, 4, 5 } ** 128);
    var random: [4096]u8 = undefined;
    var state: u32 = 0xdca1_0010;
    for (&random) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    const cases = [_][]const u8{ "", "x", &random, input };
    inline for (.{ false, true }) |literal_coded| {
        inline for (std.meta.tags(Dictionary)) |dictionary| {
            const options = Options{ .literal_coded = literal_coded, .dictionary = dictionary };
            for (cases) |case| {
                const encoded = try encodeAlloc(std.testing.allocator, case, options);
                defer std.testing.allocator.free(encoded);
                const decoded = try std.testing.allocator.alloc(u8, case.len);
                defer std.testing.allocator.free(decoded);
                try decodeInto(encoded, decoded);
                try std.testing.expectEqualSlices(u8, case, decoded);
                if (case.ptr == input.ptr) try std.testing.expect(encoded.len < case.len);
            }
        }
    }
}

test "DCL Implode rejects invalid headers distance truncation and trailing data" {
    var output: [1]u8 = undefined;
    try std.testing.expectError(error.InvalidDclStream, decodeInto(&.{ 2, 4 }, &output));
    try std.testing.expectError(error.InvalidDclStream, decodeInto(&.{ 0, 3 }, &output));
    try std.testing.expectError(error.TruncatedDclInput, decodeInto(&.{0}, &output));
    try std.testing.expectError(error.TruncatedDclInput, decodeInto(&.{ 0, 4 }, &output));

    var invalid_distance: std.ArrayList(u8) = .empty;
    defer invalid_distance.deinit(std.testing.allocator);
    var writer = BitWriter{ .allocator = std.testing.allocator, .output = &invalid_distance };
    try writer.write(0, 8);
    try writer.write(4, 8);
    try writer.write(1, 1);
    const length_table = try Table(16).init(&length_repetitions);
    try length_table.encode(&writer, 1);
    const distance_table = try Table(64).init(&distance_repetitions);
    try distance_table.encode(&writer, 0);
    try writer.write(0, 2);
    try writer.finish();
    try std.testing.expectError(error.InvalidDclStream, decodeInto(invalid_distance.items, &output));

    const encoded = try encodeAlloc(std.testing.allocator, "dcl payload", .{});
    defer std.testing.allocator.free(encoded);
    var exact_output: ["dcl payload".len]u8 = undefined;
    try std.testing.expectError(
        error.TruncatedDclInput,
        decodeInto(encoded[0 .. encoded.len - 1], &exact_output),
    );
    var trailing = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(trailing);
    trailing = try std.testing.allocator.realloc(trailing, trailing.len + 1);
    trailing[trailing.len - 1] = 0;
    try std.testing.expectError(error.DclTrailingData, decodeInto(trailing, &exact_output));

    const empty = try encodeAlloc(std.testing.allocator, "", .{});
    defer std.testing.allocator.free(empty);
    try std.testing.expectError(error.DclSizeMismatch, decodeInto(empty, &output));
    try std.testing.expectError(error.DclSizeMismatch, decodeInto(encoded, &.{}));
    try std.testing.expectError(
        error.InvalidDclOptions,
        encodeAppend(std.testing.allocator, &invalid_distance, "payload", .{ .max_chain = 0 }),
    );
}
