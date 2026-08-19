const std = @import("std");
const core = @import("../../../core.zig");

/// Byte-progressive raw-DEFLATE decoder for fixed-Huffman literal-only blocks.
/// Huffman code state survives arbitrary input splits; literals stream directly
/// to caller output. Length/distance symbols are rejected explicitly until the
/// match/history continuation slice is enabled.
pub const Decoder = struct {
    options: Options,
    phase: Phase = .block_header,
    bit_buffer: u64 = 0,
    bit_count: u6 = 0,
    code: u16 = 0,
    code_bits: u4 = 0,
    final_block: bool = false,
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
    pub const Phase = enum { block_header, symbols, done };

    pub fn init() Decoder {
        return initWithOptions(.{});
    }
    pub fn initWithOptions(options: Options) Decoder {
        return .{ .options = options };
    }
    pub fn reset(self: *Decoder) void {
        self.* = .{ .options = self.options };
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
                    self.total_output += 1;
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
                return self.fail(.symbols, error.UnsupportedDeflateFeature);
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
