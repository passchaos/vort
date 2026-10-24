//! Frozen 69e1218 scalar state machine for optimized-path comparison.
const std = @import("std");
const core = @import("../../../../core.zig");
const syntax = @import("../../../../png_ultrafast.zig").incremental_syntax;
const Adler32 = @import("../../../../checksum.zig").Adler32;

/// PNG-trained dynamic Huffman coding with distance-one zero runs. No heap
/// allocations or input-sized buffers. Eight-byte source grouping is carried
/// across calls, preserving the old full-slice fdeflate token decisions.
///
/// The dynamic block is non-final so sync flush can finish it, emit an empty
/// non-final stored block, and reopen the same trained tree. Finish instead
/// appends an empty final stored block and Adler. No-flush output is independent
/// of input/output partitioning; the old final-block one-shot stream remains
/// unchanged and differs only in container block framing. No FDICT or CRC.
pub const Encoder = struct {
    options: Options,
    expected_input_len: ?usize = null,
    adler: Adler32 = Adler32.init(),
    total_input: usize = 0,
    total_output: usize = 0,
    pending: [pending_capacity]u8 = undefined,
    pending_len: usize = 0,
    pending_offset: usize = 0,
    bits: u64 = 0,
    bit_count: u6 = 0,
    carry: [input_carry_bytes]u8 = undefined,
    carry_len: usize = 0,
    word_ready: bool = false,
    literal_offset: usize = 0,
    literal_end: usize = 0,
    suffix_run: usize = 0,
    zero_run: usize = 0,
    closing_run: usize = 0,
    run_literal_written: bool = false,
    tail_offset: usize = 0,
    stage: enum { header, input, closing, eob, block_end, footer, restart, done } = .header,
    flush_requested: bool = false,
    finishing: bool = false,
    done: bool = false,

    pub const Error = core.Error;
    pub const Options = struct { max_input_len: usize = std.math.maxInt(usize) };
    pub const pending_capacity: usize = 128;
    pub const input_carry_bytes: usize = 8;
    pub const heap_workspace_bytes: usize = 0;
    pub const stack_scratch_bytes: usize = 0;
    pub const Snapshot = struct {
        input_read: usize,
        output_written: usize,
        buffered_input: usize,
        pending_output: usize,
        pending_bits: u6,
        zero_run: usize,
        flushing: bool,
        finishing: bool,
        done: bool,
    };

    pub fn init(allocator: std.mem.Allocator) Encoder {
        return initWithOptions(allocator, .{});
    }
    pub fn initWithOptions(_: std.mem.Allocator, options: Options) Encoder {
        return .{ .options = options };
    }
    pub fn initExactSize(allocator: std.mem.Allocator, options: Options, expected: usize) Encoder {
        var encoder = initWithOptions(allocator, options);
        encoder.expected_input_len = expected;
        return encoder;
    }
    pub fn deinit(self: *Encoder) void {
        self.* = undefined;
    }
    pub fn reset(self: *Encoder) void {
        self.* = .{ .options = self.options, .expected_input_len = self.expected_input_len };
    }
    pub fn snapshot(self: *const Encoder) Snapshot {
        return .{ .input_read = self.total_input, .output_written = self.total_output, .buffered_input = self.carry_len, .pending_output = self.pending_len - self.pending_offset, .pending_bits = self.bit_count, .zero_run = self.zero_run + self.closing_run, .flushing = self.flush_requested, .finishing = self.finishing, .done = self.done };
    }
    /// RFC sync flush: finish accepted data at a byte boundary, keep zlib open.
    /// Call step with empty input until need_input before offering more input.
    pub fn flush(self: *Encoder) void {
        if (!self.finishing and !self.done) self.flush_requested = true;
    }
    pub fn finish(self: *Encoder) void {
        self.finishing = true;
        self.flush_requested = false;
    }

    pub fn step(self: *Encoder, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.done) {
            if (input.len != 0) return error.TrailingData;
            return .{ .status = .done };
        }
        if ((self.finishing or self.flush_requested) and input.len != 0) return error.TrailingData;
        const offered = std.math.add(usize, self.total_input, input.len) catch return error.IntegerOverflow;
        if (offered > self.options.max_input_len) return error.OutputLimitExceeded;
        if (self.expected_input_len) |expected| {
            if (expected > self.options.max_input_len) return error.OutputLimitExceeded;
            if (offered > expected or (self.finishing and offered != expected)) return error.SizeMismatch;
        }
        var accepted: usize = 0;
        var produced: usize = 0;
        while (true) {
            if (self.pending_offset < self.pending_len) {
                const n = @min(self.pending_len - self.pending_offset, output.len - produced);
                @memcpy(output[produced..][0..n], self.pending[self.pending_offset..][0..n]);
                self.pending_offset += n;
                produced += n;
                if (self.pending_offset != self.pending_len) return self.result(accepted, produced, .need_output);
                self.pending_len = 0;
                self.pending_offset = 0;
                if (produced == output.len and produced != 0) return self.result(accepted, produced, .need_output);
            }
            switch (self.stage) {
                .header => {
                    self.byte(0x78);
                    self.byte(0x01);
                    self.dynamicHeader();
                    self.stage = .input;
                },
                .input => {
                    if (self.closing_run != 0) {
                        self.runToken();
                        continue;
                    }
                    if (self.word_ready) {
                        if (self.literal_offset < self.literal_end) {
                            self.symbol(self.carry[self.literal_offset]);
                            self.literal_offset += 1;
                            continue;
                        }
                        self.zero_run = self.suffix_run;
                        self.carry_len = 0;
                        self.word_ready = false;
                    }
                    if (accepted != input.len) {
                        const n = @min(8 - self.carry_len, input.len - accepted);
                        const bytes = input[accepted..][0..n];
                        @memcpy(self.carry[self.carry_len..][0..n], bytes);
                        self.adler.update(bytes);
                        self.carry_len += n;
                        accepted += n;
                        self.total_input += n;
                        if (self.carry_len == 8) self.prepareWord();
                        continue;
                    }
                    if (!self.finishing and !self.flush_requested) return self.result(accepted, produced, .need_input);
                    self.closing_run = self.zero_run;
                    self.run_literal_written = false;
                    self.zero_run = 0;
                    self.tail_offset = 0;
                    self.stage = .closing;
                },
                .closing => {
                    if (self.closing_run != 0) {
                        self.runToken();
                        continue;
                    }
                    if (self.tail_offset < self.carry_len) {
                        self.symbol(self.carry[self.tail_offset]);
                        self.tail_offset += 1;
                        continue;
                    }
                    self.carry_len = 0;
                    self.stage = .eob;
                },
                .eob => {
                    self.symbol(256);
                    self.stage = .block_end;
                },
                .block_end => {
                    self.writeBits(@intFromBool(self.finishing), 3); // BTYPE=stored.
                    if (self.bit_count != 0) self.writeBits(0, @intCast(8 - @as(u7, self.bit_count)));
                    self.byte(0);
                    self.byte(0);
                    self.byte(255);
                    self.byte(255);
                    self.stage = if (self.finishing) .footer else .restart;
                },
                .footer => {
                    const digest = self.adler.digest();
                    self.byte(@truncate(digest >> 24));
                    self.byte(@truncate(digest >> 16));
                    self.byte(@truncate(digest >> 8));
                    self.byte(@truncate(digest));
                    self.stage = .done;
                },
                .restart => {
                    self.dynamicHeader();
                    self.flush_requested = false;
                    self.stage = .input;
                },
                .done => {
                    self.done = true;
                    return self.result(accepted, produced, .done);
                },
            }
        }
    }

    fn prepareWord(self: *Encoder) void {
        const word = std.mem.readInt(u64, &self.carry, .little);
        if (word == 0) {
            self.zero_run += 8;
            self.carry_len = 0;
            return;
        }
        const prefix = if (self.zero_run != 0) @ctz(word) / 8 else 0;
        self.suffix_run = @clz(word) / 8;
        self.closing_run = self.zero_run + prefix;
        self.run_literal_written = false;
        self.zero_run = 0;
        self.literal_offset = prefix;
        self.literal_end = 8 - self.suffix_run;
        self.word_ready = true;
    }
    fn runToken(self: *Encoder) void {
        if (!self.run_literal_written) {
            self.symbol(0);
            self.closing_run -= 1;
            self.run_literal_written = true;
        } else if (self.closing_run >= 258) {
            self.writeBits(syntax.codes[285], @as(u6, syntax.lengths[285]) + 1);
            self.closing_run -= 258;
        } else if (self.closing_run > 4) {
            const length = syntax.length(self.closing_run);
            self.symbol(length.symbol);
            self.writeBits(length.extra, @as(u6, length.extra_bits) + 1);
            self.closing_run = 0;
        } else {
            self.symbol(0);
            self.closing_run -= 1;
        }
    }
    fn dynamicHeader(self: *Encoder) void {
        self.writeBits(syntax.header[2] & 0xfe, 8);
        for (syntax.header[3..53]) |value| self.writeBits(value, 8);
        self.writeBits(syntax.header[53] & 0x1f, 5);
    }
    fn symbol(self: *Encoder, value: usize) void {
        self.writeBits(syntax.codes[value], syntax.lengths[value]);
    }
    fn byte(self: *Encoder, value: u8) void {
        std.debug.assert(self.pending_len < self.pending.len);
        self.pending[self.pending_len] = value;
        self.pending_len += 1;
    }
    fn writeBits(self: *Encoder, value: u64, count: u6) void {
        self.bits |= value << self.bit_count;
        var total: u7 = @as(u7, self.bit_count) + count;
        while (total >= 8) {
            self.byte(@truncate(self.bits));
            self.bits >>= 8;
            total -= 8;
        }
        self.bit_count = @intCast(total);
    }
    fn result(self: *Encoder, accepted: usize, produced: usize, status: core.StepResult.Status) Error!core.StepResult {
        self.total_output = std.math.add(usize, self.total_output, produced) catch return error.IntegerOverflow;
        return .{ .progress = .{ .input_read = accepted, .output_written = produced }, .status = status };
    }
};
