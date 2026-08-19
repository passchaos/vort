const std = @import("std");
const core = @import("../../../core.zig");

/// Byte-progressive raw-DEFLATE decoder for fixed-Huffman blocks.
/// Huffman code state survives arbitrary input splits; literals stream directly
/// to caller output. A caller-owned 32 KiB history ring backs length/distance
/// copies, including overlapping matches across arbitrary output boundaries.
pub const Decoder = struct {
    options: Options,
    phase: Phase = .block_header,
    bit_buffer: u64 = 0,
    bit_count: u6 = 0,
    code: u16 = 0,
    code_bits: u4 = 0,
    final_block: bool = false,
    history: []u8 = &.{},
    history_pos: usize = 0,
    history_len: usize = 0,
    length_base: usize = 0,
    length_extra_bits: u6 = 0,
    distance_code: u16 = 0,
    distance_code_bits: u3 = 0,
    match_len: usize = 0,
    match_remaining: usize = 0,
    match_distance: usize = 0,
    input_finished: bool = false,
    total_input: usize = 0,
    total_output: usize = 0,
    last_error_name: []const u8 = "",
    last_error_phase: Phase = .block_header,

    pub const Error = core.Error;
    pub const Options = struct {
        max_output_len: usize = std.math.maxInt(usize),
        expected_output_len: ?usize = null,
    };
    pub const Phase = enum { block_header, symbols, length_extra, distance_symbol, distance_extra, match_copy, done };

    pub fn init() Decoder {
        return initWithOptions(.{});
    }
    pub fn initWithHistory(options: Options, history: []u8) Error!Decoder {
        if (history.len < 32 * 1024) return error.OutputTooSmall;
        return .{ .options = options, .history = history[0 .. 32 * 1024] };
    }
    pub fn initWithOptions(options: Options) Decoder {
        return .{ .options = options };
    }
    pub fn reset(self: *Decoder) void {
        self.* = .{ .options = self.options, .history = self.history };
    }
    pub fn diagnostics(self: *const Decoder) core.StreamingDiagnostics {
        return .{
            .phase_name = @tagName(self.phase),
            .frame_input_read = self.total_input,
            .output_written = self.total_output,
            .expected_output_len = self.options.expected_output_len,
            .last_error_name = self.last_error_name,
            .last_error_phase_name = if (self.last_error_name.len == 0) "" else @tagName(self.last_error_phase),
            .recoverability_hint_name = if (std.mem.eql(u8, self.last_error_name, @errorName(error.TruncatedFrame))) "truncated_input" else if (std.mem.eql(u8, self.last_error_name, @errorName(error.UnsupportedDeflateFeature))) "unsupported_feature" else if (self.last_error_name.len == 0) "none" else "payload_corrupt",
        };
    }
    pub fn finish(self: *Decoder) Error!void {
        self.input_finished = true;
        if (self.phase != .done) return self.fail(self.phase, error.TruncatedFrame);
    }

    pub fn step(self: *Decoder, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.input_finished) {
            if (input.len != 0) return self.fail(self.phase, error.TrailingData);
            return .{ .status = if (self.phase == .done) .done else .need_input };
        }
        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) switch (self.phase) {
            .block_header => {
                const header = self.readBits(input, &input_read, 3) orelse return result(input_read, output_written, .need_input);
                self.final_block = (header & 1) != 0;
                const block_type = (header >> 1) & 0x3;
                if (block_type != 1) return self.fail(.block_header, if (block_type == 3) error.InvalidDeflateBlockType else error.UnsupportedDeflateFeature);
                self.phase = .symbols;
            },
            .symbols => {
                if (output_written == output.len and output.len != 0) return result(input_read, output_written, .need_output);
                const symbol = (try self.readFixedSymbol(input, &input_read)) orelse return result(input_read, output_written, .need_input);
                if (symbol < 256) {
                    if (output_written == output.len) {
                        // A decoded literal cannot be committed without caller
                        // space. Preserve it as a one-symbol continuation rather
                        // than losing input progress or spinning.
                        self.code = @intCast(symbol);
                        self.code_bits = 15;
                        return result(input_read, output_written, .need_output);
                    }
                    if (self.total_output >= self.options.max_output_len) return self.fail(.symbols, error.OutputLimitExceeded);
                    if (self.options.expected_output_len) |expected| {
                        if (self.total_output >= expected) return self.fail(.symbols, error.SizeMismatch);
                    }
                    output[output_written] = @intCast(symbol);
                    output_written += 1;
                    try self.recordByte(@intCast(symbol));
                    continue;
                }
                if (symbol == 256) {
                    self.phase = if (self.final_block) .done else .block_header;
                    if (self.phase == .done) {
                        if (self.options.expected_output_len) |expected| {
                            if (self.total_output != expected) return self.fail(.done, error.SizeMismatch);
                        }
                    }
                    continue;
                }
                const length = lengthBaseAndBits(symbol) orelse return self.fail(.symbols, error.InvalidHuffmanCode);
                self.length_base = length.base;
                self.length_extra_bits = length.bits;
                self.phase = if (length.bits == 0) .distance_symbol else .length_extra;
            },
            .length_extra => {
                const extra = self.readBits(input, &input_read, self.length_extra_bits) orelse return result(input_read, output_written, .need_input);
                self.match_len = self.length_base + extra;
                self.phase = .distance_symbol;
            },
            .distance_symbol => {
                if (self.match_len == 0) self.match_len = self.length_base;
                const symbol = self.readFixedDistanceSymbol(input, &input_read) orelse return result(input_read, output_written, .need_input);
                const distance = distanceBaseAndBits(symbol) orelse return self.fail(.distance_symbol, error.InvalidHuffmanCode);
                self.match_distance = distance.base;
                self.length_extra_bits = distance.bits;
                self.phase = if (distance.bits == 0) .match_copy else .distance_extra;
                if (self.phase == .match_copy) try self.beginMatch();
            },
            .distance_extra => {
                const extra = self.readBits(input, &input_read, self.length_extra_bits) orelse return result(input_read, output_written, .need_input);
                self.match_distance += extra;
                try self.beginMatch();
                self.phase = .match_copy;
            },
            .match_copy => {
                if (output_written == output.len) return result(input_read, output_written, .need_output);
                while (self.match_remaining != 0 and output_written < output.len) {
                    const source = (self.history_pos + self.history.len - self.match_distance) % self.history.len;
                    const byte = self.history[source];
                    output[output_written] = byte;
                    output_written += 1;
                    try self.recordByte(byte);
                    self.match_remaining -= 1;
                }
                if (self.match_remaining == 0) {
                    self.match_len = 0;
                    self.phase = .symbols;
                }
            },
            .done => {
                // A partial final byte belongs to the stream as padding; bytes
                // staged by the same input call have already been accounted for.
                if (input_read != input.len) return self.fail(.done, error.TrailingData);
                return result(input_read, output_written, .done);
            },
        };
    }

    fn readFixedSymbol(self: *Decoder, input: []const u8, input_read: *usize) Error!?u16 {
        if (self.code_bits == 15) {
            const symbol = self.code;
            self.code = 0;
            self.code_bits = 0;
            return symbol;
        }
        while (self.code_bits < 9) {
            const bit = self.readBits(input, input_read, 1) orelse return null;
            self.code |= @as(u16, @intCast(bit)) << self.code_bits;
            self.code_bits += 1;
            if (fixedSymbol(self.code, self.code_bits)) |symbol| {
                self.code = 0;
                self.code_bits = 0;
                return symbol;
            }
        }
        return self.fail(.symbols, error.InvalidHuffmanCode);
    }
    fn beginMatch(self: *Decoder) Error!void {
        if (self.history.len == 0) return self.fail(.match_copy, error.OutputTooSmall);
        if (self.match_distance == 0 or self.match_distance > self.history_len) return self.fail(.match_copy, error.InvalidMatch);
        if (self.total_output > self.options.max_output_len or self.match_len > self.options.max_output_len - self.total_output) return self.fail(.match_copy, error.OutputLimitExceeded);
        if (self.options.expected_output_len) |expected| {
            if (self.total_output > expected or self.match_len > expected - self.total_output) return self.fail(.match_copy, error.SizeMismatch);
        }
        self.match_remaining = self.match_len;
    }
    fn readFixedDistanceSymbol(self: *Decoder, input: []const u8, input_read: *usize) ?usize {
        while (self.distance_code_bits < 5) {
            const bit = self.readBits(input, input_read, 1) orelse return null;
            self.distance_code |= @as(u16, @intCast(bit)) << self.distance_code_bits;
            self.distance_code_bits += 1;
        }
        const symbol: usize = @bitReverse(@as(u5, @truncate(self.distance_code)));
        self.distance_code = 0;
        self.distance_code_bits = 0;
        return symbol;
    }
    fn recordByte(self: *Decoder, byte: u8) Error!void {
        if (self.history.len != 0) {
            self.history[self.history_pos] = byte;
            self.history_pos = (self.history_pos + 1) % self.history.len;
            self.history_len = @min(self.history_len + 1, self.history.len);
        }
        self.total_output += 1;
    }

    fn readBits(self: *Decoder, input: []const u8, input_read: *usize, count: u6) ?usize {
        while (self.bit_count < count) {
            if (input_read.* == input.len) return null;
            self.bit_buffer |= @as(u64, input[input_read.*]) << self.bit_count;
            self.bit_count += 8;
            input_read.* += 1;
            self.total_input += 1;
        }
        const mask = (@as(u64, 1) << count) - 1;
        const value: usize = @intCast(self.bit_buffer & mask);
        self.bit_buffer >>= count;
        self.bit_count -= count;
        return value;
    }
    fn fail(self: *Decoder, phase: Phase, err: Error) Error {
        self.last_error_name = @errorName(err);
        self.last_error_phase = phase;
        return err;
    }
    fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
        return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
    }
};

fn fixedSymbol(code: u16, bits: u4) ?u16 {
    for (fixed_table) |entry| {
        if (entry.bits == bits and entry.code == code) return entry.symbol;
    }
    return null;
}

const fixed_table = blk: {
    @setEvalBranchQuota(20_000);
    break :blk buildFixedTable(fixedLengths());
};

const FixedEntry = struct { symbol: u16, code: u16, bits: u4 };

fn fixedLengths() [288]u4 {
    var lengths: [288]u4 = undefined;
    for (0..144) |i| lengths[i] = 8;
    for (144..256) |i| lengths[i] = 9;
    for (256..280) |i| lengths[i] = 7;
    for (280..288) |i| lengths[i] = 8;
    return lengths;
}

fn buildFixedTable(lengths: [288]u4) [288]FixedEntry {
    var counts: [16]u16 = @splat(0);
    for (lengths) |bits| counts[bits] += 1;
    var next: [16]u16 = @splat(0);
    var code: u16 = 0;
    for (1..16) |bits| {
        code = (code + counts[bits - 1]) << 1;
        next[bits] = code;
    }
    var out: [288]FixedEntry = undefined;
    for (lengths, 0..) |bits, symbol| {
        const shift: u4 = @intCast(@as(u5, 16) - @as(u5, bits));
        out[symbol] = .{ .symbol = @intCast(symbol), .code = @bitReverse(next[bits]) >> shift, .bits = bits };
        next[bits] += 1;
    }
    return out;
}

const BaseBits = struct { base: usize, bits: u6 };

fn lengthBaseAndBits(symbol: u16) ?BaseBits {
    if (symbol < 257 or symbol > 285) return null;
    if (symbol <= 264) return .{ .base = symbol - 254, .bits = 0 };
    if (symbol == 285) return .{ .base = 258, .bits = 0 };
    const bases = [_]usize{ 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227 };
    const bits = [_]u6{ 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5 };
    const index: usize = symbol - 265;
    return .{ .base = bases[index], .bits = bits[index] };
}

const distance_bases = [_]usize{ 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577 };

fn distanceBaseAndBits(symbol: usize) ?BaseBits {
    if (symbol >= distance_bases.len) return null;
    return .{ .base = distance_bases[symbol], .bits = if (symbol < 4) 0 else @intCast(symbol / 2 - 1) };
}
