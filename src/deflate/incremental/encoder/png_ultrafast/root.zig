const std = @import("std");
const core = @import("../../../../core.zig");
const Count = core.StreamCount;
const counts = core.stream_count;
const max_count = std.math.maxInt(Count);
const syntax = @import("../../../../png_ultrafast.zig").incremental_syntax;
const Adler32 = @import("../../../../checksum.zig").Adler32;
const literals = @import("literals.zig");
const zero_scan = @import("zero_scan.zig");
const reservoir = @import("reservoir.zig");
const checksum_batch = @import("checksum_batch.zig");

test {
    _ = @import("tests.zig");
}

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
    expected_input_len: ?Count = null,
    adler: Adler32 = Adler32.init(),
    total_input: Count = 0,
    total_output: Count = 0,
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
    zero_run: Count = 0,
    closing_run: Count = 0,
    run_literal_written: bool = false,
    tail_offset: usize = 0,
    stage: enum { header, input, closing, eob, block_end, footer, restart, done } = .header,
    flush_requested: bool = false,
    finishing: bool = false,
    done: bool = false,

    pub const Error = core.Error;
    pub const Options = struct {
        /// Cumulative input cap, independent of any one caller slice. Defaults
        /// to the full stream-counter range on both 32-bit and 64-bit targets.
        max_input_len: Count = max_count,
        /// Emit the one-shot container framing (single final dynamic block and
        /// no trailing stored block) instead of the flushable framing. Sync
        /// flush is rejected in this mode.
        oneshot_framing: bool = false,
    };
    pub const pending_capacity: usize = 128;
    pub const input_carry_bytes: usize = 8;
    pub const heap_workspace_bytes: usize = 0;
    pub const stack_scratch_bytes: usize = 0;
    pub const Snapshot = struct {
        input_read: Count,
        output_written: Count,
        buffered_input: usize,
        pending_output: usize,
        pending_bits: u6,
        zero_run: Count,
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
    pub fn initExactSize(allocator: std.mem.Allocator, options: Options, expected: Count) Encoder {
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
        // A pending closing run and an accumulating zero run are mutually
        // exclusive; reporting the active run avoids adding stream quantities.
        return .{ .input_read = self.total_input, .output_written = self.total_output, .buffered_input = self.carry_len, .pending_output = self.pending_len - self.pending_offset, .pending_bits = self.bit_count, .zero_run = if (self.closing_run != 0) self.closing_run else self.zero_run, .flushing = self.flush_requested, .finishing = self.finishing, .done = self.done };
    }
    /// RFC sync flush: finish accepted data at a byte boundary, keep zlib open.
    /// Call step with empty input until need_input before offering more input.
    pub fn flush(self: *Encoder) void {
        if (self.options.oneshot_framing) return;
        if (!self.finishing and !self.done) self.flush_requested = true;
    }
    pub fn finish(self: *Encoder) void {
        self.finishing = true;
        self.flush_requested = false;
    }

    pub fn step(self: *Encoder, input: []const u8, output_buffer: []u8) Error!core.StepResult {
        if (self.done) {
            if (input.len != 0) return error.TrailingData;
            return .{ .status = .done };
        }
        if ((self.finishing or self.flush_requested) and input.len != 0) return error.TrailingData;
        const offered = try counts.addLocal(self.total_input, input.len);
        if (offered > self.options.max_input_len) return error.OutputLimitExceeded;
        if (self.expected_input_len) |expected| {
            if (expected > self.options.max_input_len) return error.OutputLimitExceeded;
            if (offered > expected or (self.finishing and offered != expected)) return error.SizeMismatch;
        }
        const output = output_buffer[0..counts.bounded(max_count - self.total_output, output_buffer.len)];
        var accepted: usize = 0;
        var produced: usize = 0;
        const direct_output = disjoint(input, output);
        while (true) {
            if (self.pending_offset < self.pending_len) {
                const available = @min(self.pending_len - self.pending_offset, output.len - produced);
                const n = counts.bounded(max_count - self.total_output, available);
                // Publish any prefix still representable by the stream count.
                // Empty caller output remains resumable even at the count cap.
                if (n == 0 and produced != output_buffer.len) return error.IntegerOverflow;
                const next_output = try counts.addLocal(self.total_output, n);
                @memcpy(output[produced..][0..n], self.pending[self.pending_offset..][0..n]);
                self.total_output = next_output;
                self.pending_offset += n;
                produced += n;
                if (self.pending_offset != self.pending_len) return self.result(accepted, produced, .need_output);
                self.pending_len = 0;
                self.pending_offset = 0;
                if (produced == output.len and produced != 0) return self.result(accepted, produced, .need_output);
            }
            // At the count cap, reject work that needs new wire before any
            // source acceptance, checksum update or parser/reservoir mutation.
            // A prefix already published by this call still needs its receipt.
            if (self.total_output == max_count and self.needsWire(accepted != input.len)) {
                if (produced != 0 or accepted != 0 or output_buffer.len == 0)
                    return self.result(accepted, produced, .need_output);
                return error.IntegerOverflow;
            }
            switch (self.stage) {
                .header => {
                    self.checkOutputBytes(2 + (@as(usize, self.bit_count) + dynamic_header_bits) / 8) catch |err| return self.outputError(accepted, produced, err);
                    self.byte(0x78);
                    self.byte(0x01);
                    self.dynamicHeader();
                    self.stage = .input;
                },
                .input => {
                    if (self.closing_run != 0) {
                        self.runBatch() catch |err| return self.outputError(accepted, produced, err);
                        continue;
                    }
                    if (self.word_ready) {
                        if (self.literal_offset < self.literal_end) {
                            const word = std.mem.readInt(u64, &self.carry, .little);
                            const count = self.literal_end - self.literal_offset;
                            const prefix_word = word >> @intCast(self.literal_offset * 8);
                            self.checkOutputBits(literalBits(prefix_word, count)) catch |err| return self.outputError(accepted, produced, err);
                            literals.prefix(self, prefix_word, @intCast(count));
                            self.literal_offset = self.literal_end;
                            continue;
                        }
                        self.zero_run = self.suffix_run;
                        self.carry_len = 0;
                        self.word_ready = false;
                    }
                    if (self.carry_len == 0 and input.len - accepted >= 8 and try self.outputRoom() >= 24) {
                        if (direct_output and output.len - produced >= pending_capacity) {
                            const batch = self.consumeInto(input[accepted..], output[produced..], 0) catch |err| return self.outputError(accepted, produced, err);
                            accepted += batch.input_read;
                            produced += batch.output_written;
                            try counts.advance(&self.total_output, batch.output_written);
                        } else {
                            const batch = self.consumeInto(input[accepted..], &self.pending, self.pending_len) catch |err| return self.outputError(accepted, produced, err);
                            accepted += batch.input_read;
                            self.pending_len += batch.output_written;
                        }
                        continue;
                    }
                    if (accepted != input.len) {
                        const n = @min(8 - self.carry_len, input.len - accepted);
                        const bytes = input[accepted..][0..n];
                        const next_input = try counts.addLocal(self.total_input, n);
                        const plan: ?WordPlan = if (self.carry_len + n == 8) blk: {
                            var word: u64 = 0;
                            for (self.carry[0..self.carry_len], 0..) |value, at|
                                word |= @as(u64, value) << @intCast(at * 8);
                            for (bytes, self.carry_len..) |value, at|
                                word |= @as(u64, value) << @intCast(at * 8);
                            const word_plan = self.planWord(word) catch |err| return self.outputError(accepted, produced, err);
                            self.checkWordOutput(word_plan, word) catch |err| return self.outputError(accepted, produced, err);
                            break :blk word_plan;
                        } else null;
                        @memcpy(self.carry[self.carry_len..][0..n], bytes);
                        self.adler.update(bytes);
                        self.carry_len += n;
                        accepted += n;
                        self.total_input = next_input;
                        if (plan) |word_plan| self.prepareWord(word_plan);
                        continue;
                    }
                    if (!self.finishing and !self.flush_requested) return self.result(accepted, produced, .need_input);
                    self.checkClosingOutput() catch |err| return self.outputError(accepted, produced, err);
                    self.closing_run = self.zero_run;
                    self.run_literal_written = false;
                    self.zero_run = 0;
                    self.tail_offset = 0;
                    self.stage = .closing;
                },
                .closing => {
                    if (self.closing_run != 0) {
                        self.runBatch() catch |err| return self.outputError(accepted, produced, err);
                        continue;
                    }
                    if (self.tail_offset < self.carry_len) {
                        self.checkOutputBits(syntax.lengths[self.carry[self.tail_offset]]) catch |err| return self.outputError(accepted, produced, err);
                        self.symbol(self.carry[self.tail_offset]);
                        self.tail_offset += 1;
                        continue;
                    }
                    self.carry_len = 0;
                    self.stage = .eob;
                },
                .eob => {
                    self.checkOutputBits(syntax.lengths[256]) catch |err| return self.outputError(accepted, produced, err);
                    self.symbol(256);
                    self.stage = .block_end;
                },
                .block_end => {
                    if (self.options.oneshot_framing) {
                        self.checkOutputBytes(@intFromBool(self.bit_count != 0)) catch |err| return self.outputError(accepted, produced, err);
                        if (self.bit_count != 0)
                            self.writeBits(0, @intCast(8 - @as(u7, self.bit_count)));
                        self.stage = .footer;
                        continue;
                    }
                    self.checkOutputBytes((@as(usize, self.bit_count) + 3 + 7) / 8 + 4) catch |err| return self.outputError(accepted, produced, err);
                    self.writeBits(@intFromBool(self.finishing), 3); // BTYPE=stored.
                    if (self.bit_count != 0) self.writeBits(0, @intCast(8 - @as(u7, self.bit_count)));
                    self.byte(0);
                    self.byte(0);
                    self.byte(255);
                    self.byte(255);
                    self.stage = if (self.finishing) .footer else .restart;
                },
                .footer => {
                    self.checkOutputBytes(4) catch |err| return self.outputError(accepted, produced, err);
                    const digest = self.adler.digest();
                    self.byte(@truncate(digest >> 24));
                    self.byte(@truncate(digest >> 16));
                    self.byte(@truncate(digest >> 8));
                    self.byte(@truncate(digest));
                    self.stage = .done;
                },
                .restart => {
                    self.checkOutputBits(dynamic_header_bits) catch |err| return self.outputError(accepted, produced, err);
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

    fn needsWire(self: *const Encoder, new_input: bool) bool {
        return switch (self.stage) {
            .done => false,
            .input => new_input or self.finishing or self.flush_requested or self.closing_run != 0 or
                (self.word_ready and self.literal_offset < self.literal_end),
            else => true,
        };
    }

    const WordPlan = struct { run: Count, prefix: usize = 0, suffix: usize = 0, all_zero: bool = false };

    /// Validate carried-run growth before accepting the completing source bytes.
    fn planWord(self: *const Encoder, word: u64) Error!WordPlan {
        return planRunWord(self.zero_run, word);
    }
    fn planRunWord(run: Count, word: u64) Error!WordPlan {
        if (word == 0) return .{ .run = try counts.addLocal(run, 8), .all_zero = true };
        const prefix: usize = if (run != 0) @ctz(word) / 8 else 0;
        return .{ .run = try counts.addLocal(run, prefix), .prefix = prefix, .suffix = @clz(word) / 8 };
    }

    fn prepareWord(self: *Encoder, plan: WordPlan) void {
        if (plan.all_zero) {
            self.zero_run = plan.run;
            self.carry_len = 0;
            return;
        }
        self.suffix_run = plan.suffix;
        self.closing_run = plan.run;
        self.run_literal_written = false;
        self.zero_run = 0;
        self.literal_offset = plan.prefix;
        self.literal_end = 8 - plan.suffix;
        self.word_ready = true;
    }

    /// Consume complete stream words without copying each one into carry.
    /// Adler updates once for the accepted contiguous batch, before any caller
    /// output write can alias that accepted source. Pending storage remains 128B.
    fn consumeInto(self: *Encoder, input: []const u8, output: []u8, already_used: usize) Error!core.Progress {
        // This scan is needed only at the counter boundary; the ordinary batch
        // retains its single pass. Any rejection precedes source acceptance,
        // checksum changes and writes into caller/pending storage.
        try self.preflightRunBatch(input);
        const output_limit = already_used + counts.bounded(try self.outputRoom(), output.len - already_used);
        var offset: usize = 0;
        var next_input = self.total_input;
        var adler = checksum_batch.Accumulator{ .a = self.adler.a, .b = self.adler.b };
        var run = self.zero_run;
        var writer = reservoir.Writer{ .output = output[0..output_limit], .used = already_used, .bits = self.bits, .bit_count = self.bit_count };
        var held_plan: ?WordPlan = null;
        while (input.len - offset >= 8 and offset < 4096 and writer.output.len - writer.used >= 24) {
            const word = std.mem.readInt(u64, input[offset..][0..8], .little);
            if (word == 0) {
                const zeros = zero_scan.leadingZeroWords(input[offset..@min(input.len, 4096)]);
                const next_run = try counts.addLocal(run, zeros);
                next_input = try counts.addLocal(next_input, zeros);
                adler.zero(zeros);
                run = next_run;
                offset += zeros;
                continue;
            }
            if (run > 512) {
                const plan = try planRunWord(run, word);
                const required = try wordOutputBytes(plan, word, writer.bit_count);
                const count_room = (try self.outputRoom()) - counts.fromLocal(writer.used - already_used);
                if (required > count_room) {
                    // Commit any earlier accepted words before yielding; the
                    // unaccepted closing word fails atomically on its retry.
                    if (offset == 0) return error.IntegerOverflow;
                    break;
                }
                next_input = try counts.addLocal(next_input, 8);
                adler.word(word);
                self.carry = input[offset..][0..8].*;
                self.carry_len = 8;
                held_plan = plan;
                offset += 8;
                break;
            }
            next_input = try counts.addLocal(next_input, 8);
            adler.word(word);
            const prefix: usize = if (run != 0) @ctz(word) / 8 else 0;
            const suffix: usize = @clz(word) / 8;
            const complete_run = try counts.addLocal(run, prefix);
            // The fast path proves this run is at most 519 bytes before
            // converting it to a batch-local serializer length.
            writer.zeroRun(try counts.toLocal(complete_run));
            literals.prefix(&writer, word >> @intCast(prefix * 8), @intCast(8 - prefix - suffix));
            run = suffix;
            offset += 8;
        }
        self.zero_run = run;
        self.bits = writer.bits;
        self.bit_count = writer.bit_count;
        if (held_plan) |plan| self.prepareWord(plan);
        adler.commit(&self.adler);
        self.total_input = next_input;
        return .{ .input_read = offset, .output_written = writer.used - already_used };
    }

    fn disjoint(input: []const u8, output: []u8) bool {
        const input_start = @intFromPtr(input.ptr);
        const output_start = @intFromPtr(output.ptr);
        const input_end = std.math.add(usize, input_start, input.len) catch return false;
        const output_end = std.math.add(usize, output_start, output.len) catch return false;
        return input_end <= output_start or output_end <= input_start;
    }

    fn runBatch(self: *Encoder) Error!void {
        // Reserve the remaining run before changing its literal/token state.
        try self.checkOutputWideBits(try runBits(self.closing_run, self.run_literal_written));
        while (self.closing_run != 0 and self.pending.len - self.pending_len >= 16) try self.runTokenBulk();
    }

    fn runTokenBulk(self: *Encoder) Error!void {
        if (!self.run_literal_written) {
            try self.checkOutputBits(syntax.lengths[0]);
            self.writeBitsBulk(syntax.codes[0], syntax.lengths[0]);
            self.closing_run -= 1;
            self.run_literal_written = true;
        } else if (self.closing_run >= 258) {
            try self.checkOutputBits(@as(u6, syntax.lengths[285]) + 1);
            self.writeBitsBulk(syntax.codes[285], @as(u6, syntax.lengths[285]) + 1);
            self.closing_run -= 258;
        } else if (self.closing_run > 4) {
            // Bound by the RFC length-code limit before narrowing a long run.
            const remaining = try counts.toLocal(@min(self.closing_run, 258));
            const length = syntax.length(remaining);
            try self.checkOutputBits(@as(usize, syntax.lengths[length.symbol]) + length.extra_bits + 1);
            self.writeBitsBulk(syntax.codes[length.symbol], syntax.lengths[length.symbol]);
            self.writeBitsBulk(length.extra, @as(u6, length.extra_bits) + 1);
            self.closing_run = 0;
        } else {
            try self.checkOutputBits(syntax.lengths[0]);
            self.writeBitsBulk(syntax.codes[0], syntax.lengths[0]);
            self.closing_run -= 1;
        }
    }

    fn preflightRunBatch(self: *const Encoder, input: []const u8) Error!void {
        const end = @min(input.len, 4096);
        if (self.zero_run <= max_count - counts.fromLocal(end)) return;
        var offset: usize = 0;
        var run = self.zero_run;
        while (end - offset >= 8) {
            const word = std.mem.readInt(u64, input[offset..][0..8], .little);
            if (word == 0) {
                const zeros = zero_scan.leadingZeroWords(input[offset..end]);
                run = try counts.addLocal(run, zeros);
                offset += zeros;
            } else {
                // Such a large carried run always leaves the first nonzero
                // word held for the resumable token path.
                _ = try counts.addLocal(run, @ctz(word) / 8);
                return;
            }
        }
    }

    /// Reserve only complete bytes, including bytes already queued. Caller
    /// output counters advance when published, before the corresponding copy.
    fn outputRoom(self: *const Encoder) Error!Count {
        const committed = try counts.addLocal(self.total_output, self.pending_len - self.pending_offset);
        return max_count - committed;
    }
    fn checkOutputWideBytes(self: *const Encoder, bytes: Count) Error!void {
        if (bytes > try self.outputRoom()) return error.IntegerOverflow;
    }
    fn checkOutputBytes(self: *const Encoder, bytes: usize) Error!void {
        try self.checkOutputWideBytes(counts.fromLocal(bytes));
    }
    fn checkOutputWideBits(self: *const Encoder, bits: Count) Error!void {
        try self.checkOutputWideBytes((try counts.addLocal(bits, self.bit_count)) / 8);
    }
    fn checkOutputBits(self: *const Encoder, bits: usize) Error!void {
        try self.checkOutputWideBits(counts.fromLocal(bits));
    }

    /// Count the canonical resumable serializer without expanding a long run.
    fn runBits(length: Count, literal_written: bool) Error!Count {
        if (length == 0) return 0;
        var remaining = length;
        var bits: Count = 0;
        if (!literal_written) {
            bits = syntax.lengths[0];
            remaining -= 1;
        }
        const repeated = std.math.mul(Count, remaining / 258, @as(Count, syntax.lengths[285]) + 1) catch return error.IntegerOverflow;
        bits = try counts.add(bits, repeated);
        remaining %= 258;
        if (remaining > 4) {
            const selected = syntax.length(try counts.toLocal(@min(remaining, 258)));
            bits = try counts.addLocal(bits, @as(usize, syntax.lengths[selected.symbol]) + selected.extra_bits + 1);
        } else {
            const tail = std.math.mul(Count, remaining, syntax.lengths[0]) catch return error.IntegerOverflow;
            bits = try counts.add(bits, tail);
        }
        return bits;
    }

    /// A completing nonzero word publishes its prior run and literal prefix.
    /// Check those bytes before accepting the word or changing Adler/carry.
    fn wordOutputBytes(plan: WordPlan, word: u64, bit_count: u6) Error!Count {
        if (plan.all_zero) return 0;
        const literals_bits = literalBits(word >> @intCast(plan.prefix * 8), 8 - plan.prefix - plan.suffix);
        const bits = try counts.addLocal(try runBits(plan.run, false), literals_bits);
        return (try counts.addLocal(bits, bit_count)) / 8;
    }
    fn checkWordOutput(self: *const Encoder, plan: WordPlan, word: u64) Error!void {
        try self.checkOutputWideBytes(try wordOutputBytes(plan, word, self.bit_count));
    }

    /// Closing a partial word also adds EOB, alignment, container framing and
    /// either Adler or a reopened tree. Validate before moving zero_run/stage.
    fn checkClosingOutput(self: *const Encoder) Error!void {
        var bits = try counts.addLocal(try runBits(self.zero_run, false), self.bit_count);
        for (self.carry[0..self.carry_len]) |literal|
            bits = try counts.addLocal(bits, syntax.lengths[literal]);
        bits = try counts.addLocal(bits, syntax.lengths[256]);
        if (!self.options.oneshot_framing) bits = try counts.addLocal(bits, 3);
        var bytes = try counts.addLocal(bits / 8, @intFromBool(bits % 8 != 0));
        if (!self.options.oneshot_framing) bytes = try counts.addLocal(bytes, 4);
        bytes = try counts.addLocal(bytes, if (self.finishing) 4 else dynamic_header_bits / 8);
        try self.checkOutputWideBytes(bytes);
    }

    fn outputError(self: *Encoder, accepted: usize, produced: usize, err: Error) Error!core.StepResult {
        if (err == error.IntegerOverflow and (accepted != 0 or produced != 0))
            return self.result(accepted, produced, .need_output);
        return err;
    }
    fn literalBits(initial_word: u64, count: usize) usize {
        var word = initial_word;
        var bits: usize = 0;
        for (0..count) |_| {
            bits += syntax.lengths[@as(u8, @truncate(word))];
            word >>= 8;
        }
        return bits;
    }
    const dynamic_header_bits: usize = 8 + (53 - 3) * 8 + 5;

    /// Store a reservoir word into valid queue capacity, advancing only its
    /// complete bytes. Subsequent stores may overlap unused queue bytes; those
    /// bytes are never published. This removes per-byte branches and scratch.
    pub fn writeBitsBulk(self: *Encoder, value: u64, count: u6) void {
        std.debug.assert(count <= 48 and self.pending.len - self.pending_len >= 8);
        const joined = self.bits | (value << self.bit_count);
        const total: u7 = @as(u7, self.bit_count) + count;
        const bytes: usize = total / 8;
        std.mem.writeInt(u64, self.pending[self.pending_len..][0..8], joined, .little);
        self.pending_len += bytes;
        self.bits = joined >> @intCast(bytes * 8);
        self.bit_count = @intCast(total % 8);
    }
    fn dynamicHeader(self: *Encoder) void {
        // The flushable stream clears BFINAL and closes the block with a
        // stored block; the one-shot framing keeps BFINAL set.
        const first = if (self.options.oneshot_framing)
            syntax.header[2]
        else
            syntax.header[2] & 0xfe;
        self.writeBits(first, 8);
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
    fn result(_: *Encoder, accepted: usize, produced: usize, status: core.StepResult.Status) Error!core.StepResult {
        return .{ .progress = .{ .input_read = accepted, .output_written = produced }, .status = status };
    }
};
