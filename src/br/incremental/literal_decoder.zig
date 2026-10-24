const std = @import("std");
const core = @import("../../core.zig");
const progressive_bits = @import("bit_reader.zig");

/// Byte-progressive decoder for final Brotli compressed meta-blocks containing
/// one insert-only command. The bounded prefix buffer is discarded logically
/// once parsed; subsequent Huffman bits are held in a fixed-size reservoir
/// and decoded bytes are written directly to caller-owned output.
pub fn Decoder(comptime Codec: type) type {
    return struct {
        options: Options,
        phase: Phase = .header,
        header_bytes: [Codec.max_stream_header_bytes]u8 = undefined,
        header_len: usize = 0,
        header: Codec.Header = undefined,
        staged_bits: u128 = 0,
        staged_bit_count: u8 = 0,
        stream_bits: usize = 0,
        output_remaining: usize = 0,
        final_meta_block: bool = true,
        next_header_state: NextHeaderState = .is_last,
        next_length_width: u6 = 0,
        stored_remaining: usize = 0,
        metadata: bool = false,
        metadata_remaining: usize = 0,
        metadata_output: []u8 = &.{},
        metadata_written: usize = 0,
        metadata_total: Counter = 0,
        current_metadata_len: usize = 0,
        metadata_block_lengths: []usize = &.{},
        metadata_block_count: Counter = 0,
        total_input: Counter = 0,
        total_output: Counter = 0,
        finished: bool = false,
        last_error_name: []const u8 = "",
        last_error_phase: Phase = .header,
        error_input_offset: ?Counter = null,
        error_output_offset: ?Counter = null,
        last_step_progress: core.Progress = .{},

        const Self = @This();
        pub const Counter = core.StreamCount;
        pub const Error = Codec.Error;
        pub const Options = struct {
            max_output_len: Counter = std.math.maxInt(Counter),
            expected_output_len: ?Counter = null,
            metadata_output: []u8 = &.{},
            metadata_block_lengths: []usize = &.{},
        };
        pub const Phase = enum { header, literals, trailer, stored, metadata, padding, done };
        const NextHeaderState = enum { is_last, last_empty, nibbles, metadata_reserved, metadata_count, metadata_len, block_len, uncompressed, alignment };
        pub const Snapshot = struct {
            phase: Phase,
            input_read: Counter,
            output_written: Counter,
            payload_remaining: usize,
            retained_input_bytes: usize,
            staged_bits: usize,
            expected_output_len: ?Counter,
            metadata_written: usize,
            metadata_total: Counter,
            metadata_truncated: bool,
            metadata_block_count: Counter,
            metadata_blocks_captured: usize,
            metadata_blocks_truncated: bool,
            last_error_name: []const u8,
            last_error_phase: Phase,
            error_input_offset: ?Counter = null,
            error_output_offset: ?Counter = null,
            last_step_progress: core.Progress = .{},
        };

        pub fn init() Self {
            return initWithOptions(.{});
        }
        pub fn initWithOptions(options: Options) Self {
            return .{ .options = options, .metadata_output = options.metadata_output, .metadata_block_lengths = options.metadata_block_lengths };
        }
        pub fn reset(self: *Self) void {
            self.* = .{
                .options = self.options,
                .metadata_output = self.options.metadata_output,
                .metadata_block_lengths = self.options.metadata_block_lengths,
            };
        }
        pub fn snapshot(self: *const Self) Snapshot {
            return .{
                .phase = self.phase,
                .input_read = self.total_input,
                .output_written = self.total_output,
                .payload_remaining = self.output_remaining,
                .retained_input_bytes = self.header_len,
                .staged_bits = self.staged_bit_count,
                .expected_output_len = self.options.expected_output_len,
                .metadata_written = self.metadata_written,
                .metadata_total = self.metadata_total,
                .metadata_truncated = core.stream_count.fromLocal(self.metadata_written) != self.metadata_total,
                .metadata_block_count = self.metadata_block_count,
                .metadata_blocks_captured = core.stream_count.bounded(self.metadata_block_count, self.metadata_block_lengths.len),
                .metadata_blocks_truncated = self.metadata_block_count > core.stream_count.fromLocal(self.metadata_block_lengths.len),
                .last_error_name = self.last_error_name,
                .last_error_phase = self.last_error_phase,
                .error_input_offset = self.error_input_offset,
                .error_output_offset = self.error_output_offset,
                .last_step_progress = self.last_step_progress,
            };
        }
        pub fn diagnostics(self: *const Self) core.StreamingDiagnostics {
            const snap = self.snapshot();
            return .{
                .phase_name = @tagName(snap.phase),
                .frame_input_read = snap.input_read,
                .output_written = snap.output_written,
                .expected_output_len = snap.expected_output_len,
                .payload_remaining = snap.payload_remaining,
                .last_error_name = snap.last_error_name,
                .error_input_offset = snap.error_input_offset,
                .error_output_offset = snap.error_output_offset,
                .last_step_progress = snap.last_step_progress,
                .last_error_phase_name = if (snap.last_error_name.len == 0) "" else @tagName(snap.last_error_phase),
                .recoverability_hint_name = if (std.mem.eql(u8, snap.last_error_name, @errorName(error.TruncatedFrame))) "truncated_input" else if (std.mem.eql(u8, snap.last_error_name, @errorName(error.UnsupportedBrotliFeature))) "unsupported_feature" else if (snap.last_error_name.len == 0) "none" else "payload_corrupt",
            };
        }
        pub fn finish(self: *Self) Error!void {
            if (self.phase != .done) return self.fail(self.phase, error.TruncatedFrame);
            self.finished = true;
        }

        pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            self.last_step_progress = .{};
            const before_input = self.total_input;
            const before_output = self.total_output;
            const stepped = self.stepImpl(input, output) catch |err| {
                // Count only completed bytes, after stepImpl has committed any
                // retained Huffman input even when its later operation failed.
                self.last_step_progress = .{
                    .input_read = localDelta(self.total_input, before_input, input.len),
                    .output_written = localDelta(self.total_output, before_output, output.len),
                };
                return self.fail(self.phase, err);
            };
            self.last_step_progress = stepped.progress;
            return stepped;
        }

        fn stepImpl(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            if (self.finished) {
                if (input.len != 0) return self.fail(.done, error.TrailingData);
                return result(0, 0, .done);
            }
            _ = core.stream_count.addLocal(self.total_input, input.len) catch return self.fail(self.phase, error.IntegerOverflow);
            var input_read: usize = 0;
            var output_written: usize = 0;
            // Preflight the offered input before touching parser state. Only
            // bytes retained or consumed by the reader count on return, including
            // progress made before a later format or output-counter failure.
            defer self.total_input = core.stream_count.addLocal(self.total_input, input_read) catch unreachable;
            while (true) switch (self.phase) {
                .header => {
                    while (input_read < input.len) {
                        if (self.header_len == self.header_bytes.len)
                            return self.fail(.header, error.UnsupportedBrotliFeature);
                        self.header_bytes[self.header_len] = input[input_read];
                        self.header_len += 1;
                        input_read += 1;
                        const parsed = Codec.parseHeader(self.header_bytes[0..self.header_len]) catch |err| switch (err) {
                            error.TruncatedFrame => continue,
                            else => return self.fail(.header, err),
                        };
                        const decoded_end = try self.checkOutput(parsed.header.decoded_len);
                        if (self.options.expected_output_len) |expected| {
                            if (parsed.header.final) {
                                if (decoded_end != expected) return self.fail(.header, error.SizeMismatch);
                            } else if (decoded_end > expected) return self.fail(.header, error.SizeMismatch);
                        }

                        const byte_index = parsed.bits_read / 8;
                        const bit_index: u3 = @intCast(parsed.bits_read % 8);
                        const available_bits = self.header_len * 8 - parsed.bits_read;
                        if (available_bits > 127) return self.fail(.header, error.CorruptFrame);
                        self.staged_bits = if (available_bits == 0) 0 else @as(u128, self.header_bytes[byte_index]) >> bit_index;
                        self.staged_bit_count = @intCast(available_bits);
                        self.stream_bits = parsed.bits_read;
                        self.header = parsed.header;
                        self.output_remaining = parsed.header.decoded_len;
                        self.final_meta_block = parsed.header.final;
                        self.phase = .literals;
                        break;
                    }
                    if (self.phase == .header) return result(input_read, output_written, .need_input);
                },
                .literals => {
                    while (self.output_remaining != 0 and output_written < output.len) {
                        const next_output = try self.checkOutput(1);
                        var reader = progressive_bits.Reader.init(input, &input_read, &self.staged_bits, &self.staged_bit_count, &self.stream_bits);
                        const saved = reader.checkpoint();
                        const literal = Codec.readLiteral(&self.header, &reader) catch |err| switch (err) {
                            error.TruncatedFrame => {
                                // A Huffman symbol is atomic while input bytes
                                // already supplied by the caller are retained
                                // in the bounded reservoir for the next retry.
                                try reader.restoreKeepingInput(saved);
                                return result(input_read, output_written, .need_input);
                            },
                            else => return self.fail(.literals, err),
                        };
                        output[output_written] = literal;
                        output_written += 1;
                        self.total_output = next_output;
                        self.output_remaining -= 1;
                    }
                    if (self.output_remaining != 0) {
                        return result(input_read, output_written, .need_output);
                    }
                    self.phase = if (self.final_meta_block) .padding else .trailer;
                },
                .trailer => {
                    var reader = progressive_bits.Reader.init(input, &input_read, &self.staged_bits, &self.staged_bit_count, &self.stream_bits);
                    while (true) switch (self.next_header_state) {
                        .is_last => {
                            const value = reader.readBits(u1, 1) catch |err| switch (err) {
                                error.TruncatedFrame => return result(input_read, output_written, .need_input),
                                else => return self.fail(.trailer, err),
                            };
                            self.next_header_state = if (value != 0) .last_empty else .nibbles;
                        },
                        .last_empty => {
                            const value = reader.readBits(u1, 1) catch |err| switch (err) {
                                error.TruncatedFrame => return result(input_read, output_written, .need_input),
                                else => return self.fail(.trailer, err),
                            };
                            if (value != 1) return self.fail(.trailer, error.UnsupportedBrotliFeature);
                            try self.validateFinalOutputSize();
                            self.phase = .padding;
                            break;
                        },
                        .nibbles => {
                            const code = reader.readBits(u2, 2) catch |err| switch (err) {
                                error.TruncatedFrame => return result(input_read, output_written, .need_input),
                                else => return self.fail(.trailer, err),
                            };
                            if (code == 3) {
                                self.metadata = true;
                                self.next_header_state = .metadata_reserved;
                                continue;
                            }
                            self.next_length_width = @intCast((4 + @as(usize, code)) * 4);
                            self.next_header_state = .block_len;
                        },
                        .metadata_reserved => {
                            const value = reader.readBits(u1, 1) catch |err| switch (err) {
                                error.TruncatedFrame => return result(input_read, output_written, .need_input),
                                else => return self.fail(.trailer, err),
                            };
                            if (value != 0) return self.fail(.trailer, error.CorruptFrame);
                            self.next_header_state = .metadata_count;
                        },
                        .metadata_count => {
                            const count = reader.readBits(u2, 2) catch |err| switch (err) {
                                error.TruncatedFrame => return result(input_read, output_written, .need_input),
                                else => return self.fail(.trailer, err),
                            };
                            self.next_length_width = @intCast(@as(usize, count) * 8);
                            if (count == 0) {
                                self.metadata_remaining = 0;
                                self.next_header_state = .alignment;
                            } else self.next_header_state = .metadata_len;
                        },
                        .metadata_len => {
                            const len_minus_one = reader.readBits(usize, self.next_length_width) catch |err| switch (err) {
                                error.TruncatedFrame => return result(input_read, output_written, .need_input),
                                else => return self.fail(.trailer, err),
                            };
                            const bytes = self.next_length_width / 8;
                            if (bytes > 1 and ((len_minus_one >> @intCast((bytes - 1) * 8)) & 0xff) == 0) return self.fail(.trailer, error.CorruptFrame);
                            self.metadata_remaining = std.math.add(usize, len_minus_one, 1) catch return self.fail(.trailer, error.IntegerOverflow);
                            self.next_header_state = .alignment;
                        },
                        .block_len => {
                            const len_minus_one = reader.readBits(usize, self.next_length_width) catch |err| switch (err) {
                                error.TruncatedFrame => return result(input_read, output_written, .need_input),
                                else => return self.fail(.trailer, err),
                            };
                            const nibbles = self.next_length_width / 4;
                            if (nibbles > 4 and ((len_minus_one >> @intCast((nibbles - 1) * 4)) & 0xf) == 0) return self.fail(.trailer, error.CorruptFrame);
                            const remaining = std.math.add(usize, len_minus_one, 1) catch return self.fail(.trailer, error.IntegerOverflow);
                            const decoded_end = try self.checkOutput(remaining);
                            if (self.options.expected_output_len) |expected|
                                if (decoded_end > expected) return self.fail(.trailer, error.SizeMismatch);
                            self.stored_remaining = remaining;
                            self.next_header_state = .uncompressed;
                        },
                        .uncompressed => {
                            const value = reader.readBits(u1, 1) catch |err| switch (err) {
                                error.TruncatedFrame => return result(input_read, output_written, .need_input),
                                else => return self.fail(.trailer, err),
                            };
                            if (value != 1) return self.fail(.trailer, error.UnsupportedBrotliFeature);
                            self.next_header_state = .alignment;
                        },
                        .alignment => {
                            const padding: u6 = @intCast((8 - self.stream_bits % 8) % 8);
                            const value = reader.readBits(u8, padding) catch |err| switch (err) {
                                error.TruncatedFrame => return result(input_read, output_written, .need_input),
                                else => return self.fail(.trailer, err),
                            };
                            if (value != 0 or self.staged_bit_count != 0) return self.fail(.trailer, error.CorruptFrame);
                            if (self.metadata and self.metadata_remaining == 0) {
                                try self.recordMetadataBlock();
                                self.phase = .trailer;
                            } else self.phase = if (self.metadata) .metadata else .stored;
                            self.next_header_state = .is_last;
                            break;
                        },
                    };
                },
                .stored => {
                    const n = @min(self.stored_remaining, @min(input.len - input_read, output.len - output_written));
                    const next_output = try self.checkOutput(n);
                    @memcpy(output[output_written..][0..n], input[input_read..][0..n]);
                    input_read += n;
                    output_written += n;
                    self.total_output = next_output;
                    self.stored_remaining -= n;
                    if (self.stored_remaining != 0) return result(input_read, output_written, if (output_written == output.len) .need_output else .need_input);
                    if (self.options.expected_output_len) |expected| if (self.total_output > expected) return self.fail(.stored, error.SizeMismatch);
                    self.phase = .trailer;
                },
                .metadata => {
                    const n = @min(self.metadata_remaining, input.len - input_read);
                    const next_metadata = core.stream_count.addLocal(self.metadata_total, n) catch return self.fail(.metadata, error.IntegerOverflow);
                    const next_len = std.math.add(usize, self.current_metadata_len, n) catch return self.fail(.metadata, error.IntegerOverflow);
                    if (n == self.metadata_remaining) _ = try self.nextMetadataBlockCount();
                    const capture = @min(n, self.metadata_output.len -| self.metadata_written);
                    if (capture != 0) @memcpy(self.metadata_output[self.metadata_written..][0..capture], input[input_read..][0..capture]);
                    self.metadata_written += capture;
                    self.metadata_total = next_metadata;
                    self.current_metadata_len = next_len;
                    input_read += n;
                    self.metadata_remaining -= n;
                    if (self.metadata_remaining != 0) return result(input_read, output_written, .need_input);
                    try self.recordMetadataBlock();
                    self.phase = .trailer;
                },
                .padding => {
                    const padding_bits: u8 = @intCast((8 - self.stream_bits % 8) % 8);
                    while (self.staged_bit_count < padding_bits and input_read < input.len) {
                        self.staged_bits |= @as(u128, input[input_read]) << @intCast(self.staged_bit_count);
                        self.staged_bit_count += 8;
                        input_read += 1;
                    }
                    if (self.staged_bit_count < padding_bits) {
                        return result(input_read, output_written, .need_input);
                    }
                    if (padding_bits != 0) {
                        const mask = (@as(u128, 1) << @intCast(padding_bits)) - 1;
                        if ((self.staged_bits & mask) != 0) return self.fail(.padding, error.CorruptFrame);
                        self.staged_bits >>= @intCast(padding_bits);
                        self.staged_bit_count -= padding_bits;
                    }
                    if (self.staged_bit_count != 0 or input_read != input.len)
                        return self.fail(.padding, error.TrailingData);
                    self.phase = .done;
                },
                .done => {
                    if (input_read != input.len) return self.fail(.done, error.TrailingData);
                    return result(input_read, output_written, .done);
                },
            };
        }

        fn localDelta(after: Counter, before: Counter, limit: usize) usize {
            std.debug.assert(after >= before);
            const delta = after - before;
            std.debug.assert(delta <= core.stream_count.fromLocal(limit));
            return core.stream_count.toLocal(delta) catch unreachable;
        }
        fn fail(self: *Self, phase: Phase, err: Error) Error {
            self.last_error_name = @errorName(err);
            self.last_error_phase = phase;
            self.error_input_offset = self.total_input;
            self.error_output_offset = self.total_output;
            return err;
        }
        fn validateFinalOutputSize(self: *Self) Error!void {
            if (self.options.expected_output_len) |expected|
                if (self.total_output != expected) return self.fail(.trailer, error.SizeMismatch);
        }
        fn checkOutput(self: *Self, n: usize) Error!Counter {
            const next_output = core.stream_count.addLocal(self.total_output, n) catch return self.fail(self.phase, error.IntegerOverflow);
            if (next_output > self.options.max_output_len) return self.fail(self.phase, error.OutputLimitExceeded);
            return next_output;
        }
        fn nextMetadataBlockCount(self: *Self) Error!Counter {
            return core.stream_count.add(self.metadata_block_count, 1) catch return self.fail(self.phase, error.IntegerOverflow);
        }
        fn recordMetadataBlock(self: *Self) Error!void {
            const next_count = try self.nextMetadataBlockCount();
            if (self.metadata_block_count < core.stream_count.fromLocal(self.metadata_block_lengths.len))
                self.metadata_block_lengths[core.stream_count.toLocal(self.metadata_block_count) catch unreachable] = self.current_metadata_len;
            self.metadata_block_count = next_count;
            self.current_metadata_len = 0;
            self.metadata = false;
        }
        fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
            return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
        }
    };
}

test "Brotli subset counters literal crosses 4 GiB with bounded metadata and bit phase" {
    const br = @import("../../br.zig");
    const Counter = br.IncrementalLiteralStreamDecoder.Counter;
    const base: Counter = (@as(Counter, 1) << 32) - 1;
    const wire = try br.IncrementalTestSupport.encodeCompressedHelloThenMetadataAndStoredBlocks(std.testing.allocator, "m", &.{"!"});
    defer std.testing.allocator.free(wire);
    var captured: [1]u8 = .{0xaa};
    var lengths: [1]usize = .{999};
    var decoder = br.IncrementalLiteralStreamDecoder.initWithOptions(.{
        .max_output_len = base + 6,
        .metadata_output = &captured,
        .metadata_block_lengths = &lengths,
    });
    decoder.total_input = base;
    const header = try decoder.step(wire, &.{});
    decoder.total_output = base;
    decoder.metadata_total = base;
    decoder.metadata_block_count = base;
    decoder.options.expected_output_len = base + 6;
    decoder.stream_bits = (std.math.maxInt(usize) & ~@as(usize, 7)) | (decoder.stream_bits & 7);
    var output: [6]u8 = undefined;
    const completed = try decoder.step(wire[header.progress.input_read..], &output);
    try decoder.finish();
    try std.testing.expectEqual(.done, completed.status);
    try std.testing.expectEqualSlices(u8, "hello!", &output);
    try std.testing.expectEqualSlices(u8, "m", &captured);
    const snap = decoder.snapshot();
    try std.testing.expectEqual(base + core.stream_count.fromLocal(wire.len), snap.input_read);
    try std.testing.expectEqual(base + 6, snap.output_written);
    try std.testing.expectEqual(base + 1, snap.metadata_total);
    try std.testing.expectEqual(base + 1, snap.metadata_block_count);
    try std.testing.expectEqual(@as(usize, 1), snap.metadata_blocks_captured);
    try std.testing.expect(snap.metadata_blocks_truncated);
    try std.testing.expectEqual(@as(usize, 999), lengths[0]);
    try std.testing.expectEqual(@as(?Counter, base + 6), decoder.diagnostics().expected_output_len);
    decoder.reset();
    try std.testing.expectEqual(br.IncrementalLiteralStreamDecoder.Phase.header, decoder.phase);
    try std.testing.expectEqual(@as(Counter, 0), decoder.total_input);
    try std.testing.expectEqual(@as(?Counter, base + 6), decoder.options.expected_output_len);
    try std.testing.expectEqual(captured[0..].ptr, decoder.metadata_output.ptr);
}

test "Brotli subset counters literal preflights offered input and preserves earlier output" {
    const br = @import("../../br.zig");
    const Counter = br.IncrementalLiteralStreamDecoder.Counter;
    const wire = try br.IncrementalTestSupport.encodeCompressedHello(std.testing.allocator);
    defer std.testing.allocator.free(wire);
    var decoder = br.IncrementalLiteralStreamDecoder.init();
    decoder.total_input = std.math.maxInt(Counter) - 1;
    var output: [5]u8 = @splat(0xaa);
    try std.testing.expectError(error.IntegerOverflow, decoder.step(wire[0..2], &output));
    try std.testing.expectEqual(@as(usize, 0), decoder.header_len);
    try std.testing.expectEqual(std.math.maxInt(Counter) - 1, decoder.total_input);
    try std.testing.expectEqualSlices(u8, &.{ 0xaa, 0xaa, 0xaa, 0xaa, 0xaa }, &output);
    try std.testing.expectEqual(core.Progress{}, decoder.diagnostics().last_step_progress.?);
    try std.testing.expectEqual(@as(?Counter, std.math.maxInt(Counter) - 1), decoder.diagnostics().error_input_offset);
    decoder.reset();
    const header = try decoder.step(wire, &.{});
    decoder.total_output = std.math.maxInt(Counter) - 1;
    try std.testing.expectError(error.IntegerOverflow, decoder.step(wire[header.progress.input_read..], &output));
    try std.testing.expectEqual(std.math.maxInt(Counter), decoder.total_output);
    try std.testing.expectEqual(@as(usize, 4), decoder.output_remaining);
    try std.testing.expectEqualSlices(u8, &.{ 'h', 0xaa, 0xaa, 0xaa, 0xaa }, &output);
    try std.testing.expectEqual(@as(usize, 1), decoder.diagnostics().last_step_progress.?.output_written);
    try std.testing.expectEqual(@as(?Counter, std.math.maxInt(Counter)), decoder.diagnostics().error_output_offset);
}

test "Brotli subset counters literal metadata failure retains consumed input and literals" {
    const br = @import("../../br.zig");
    const Counter = br.IncrementalLiteralStreamDecoder.Counter;
    const wire = try br.IncrementalTestSupport.encodeCompressedHelloThenMetadataAndStoredBlocks(std.testing.allocator, "m", &.{"!"});
    defer std.testing.allocator.free(wire);
    for ([_]bool{ false, true }) |blocks| {
        var captured: [1]u8 = .{0xaa};
        var decoder = br.IncrementalLiteralStreamDecoder.initWithOptions(.{ .metadata_output = &captured });
        const header = try decoder.step(wire, &.{});
        if (blocks) decoder.metadata_block_count = std.math.maxInt(Counter) else decoder.metadata_total = std.math.maxInt(Counter);
        var output: [6]u8 = @splat(0xaa);
        try std.testing.expectError(error.IntegerOverflow, decoder.step(wire[header.progress.input_read..], &output));
        try std.testing.expectEqualSlices(u8, &.{ 'h', 'e', 'l', 'l', 'o', 0xaa }, &output);
        try std.testing.expectEqual(@as(Counter, 5), decoder.total_output);
        try std.testing.expect(decoder.total_input > core.stream_count.fromLocal(header.progress.input_read));
        try std.testing.expectEqual(@as(usize, 1), decoder.metadata_remaining);
        try std.testing.expectEqual(@as(usize, 0), decoder.metadata_written);
        try std.testing.expectEqualSlices(u8, &.{0xaa}, &captured);
        const diagnostic = decoder.diagnostics();
        try std.testing.expectEqual(@as(usize, 5), diagnostic.last_step_progress.?.output_written);
        try std.testing.expectEqual(core.stream_count.toLocal(decoder.total_input) catch unreachable, header.progress.input_read + diagnostic.last_step_progress.?.input_read);
        try std.testing.expectEqual(@as(?Counter, decoder.total_input), diagnostic.error_input_offset);
    }
}
