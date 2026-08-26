const std = @import("std");
const core = @import("../../core.zig");
const progressive_bits = @import("bit_reader.zig");

/// Progressive decoder for final, single-block-type compressed streams with
/// explicit distances. History is caller-owned, which makes memory use visible
/// and lets overlapping copies resume across arbitrarily small output buffers.
pub fn Decoder(comptime Codec: type) type {
    return struct {
        options: Options,
        history: []u8,
        phase: Phase = .header,
        header_bytes: [Codec.max_stream_header_bytes]u8 = undefined,
        header_len: usize = 0,
        header: Codec.Header = undefined,
        staged_bits: u128 = 0,
        staged_bit_count: u8 = 0,
        stream_bits: usize = 0,
        decoded_len: usize = 0,
        final_meta_block: bool = true,
        next_header_state: NextHeaderState = .is_last,
        next_length_width: u6 = 0,
        stored_remaining: usize = 0,
        metadata: bool = false,
        metadata_remaining: usize = 0,
        metadata_output: []u8 = &.{},
        metadata_written: usize = 0,
        metadata_total: usize = 0,
        current_metadata_len: usize = 0,
        metadata_block_lengths: []usize = &.{},
        metadata_block_count: usize = 0,
        pending_literals: usize = 0,
        pending_copy: usize = 0,
        copy_distance: usize = 0,
        implicit_last_distance: bool = false,
        dictionary_scratch: [64]u8 = undefined,
        dictionary_offset: usize = 0,
        dictionary_len: usize = 0,
        last_distances: [4]usize = .{ 16, 15, 11, 4 },
        previous: [2]u8 = .{ 0, 0 },
        total_input: usize = 0,
        total_output: usize = 0,
        finished: bool = false,
        last_error_name: []const u8 = "",
        last_error_phase: Phase = .header,

        const Self = @This();
        pub const Error = Codec.Error;
        pub const Options = struct {
            max_output_len: usize = std.math.maxInt(usize),
            expected_output_len: ?usize = null,
            metadata_output: []u8 = &.{},
            metadata_block_lengths: []usize = &.{},
        };
        pub const Phase = enum { header, command, literals, distance, copy, dictionary, trailer, stored, metadata, padding, done };
        const NextHeaderState = enum { is_last, last_empty, nibbles, metadata_reserved, metadata_count, metadata_len, block_len, uncompressed, alignment };
        pub const Snapshot = struct {
            phase: Phase,
            input_read: usize,
            output_written: usize,
            payload_remaining: usize,
            pending_literals: usize,
            pending_copy: usize,
            retained_input_bytes: usize,
            history_bytes: usize,
            metadata_written: usize,
            metadata_total: usize,
            metadata_truncated: bool,
            metadata_block_count: usize,
            metadata_blocks_captured: usize,
            metadata_blocks_truncated: bool,
            last_error_name: []const u8,
            last_error_phase: Phase,
        };

        pub fn init(history: []u8) Self {
            return initWithOptions(history, .{});
        }
        pub fn initWithOptions(history: []u8, options: Options) Self {
            return .{
                .options = options,
                .history = history,
                .metadata_output = options.metadata_output,
                .metadata_block_lengths = options.metadata_block_lengths,
            };
        }
        pub fn reset(self: *Self) void {
            const history = self.history;
            const options = self.options;
            self.* = .{
                .options = options,
                .history = history,
                .metadata_output = options.metadata_output,
                .metadata_block_lengths = options.metadata_block_lengths,
            };
        }
        pub fn snapshot(self: *const Self) Snapshot {
            return .{
                .phase = self.phase,
                .input_read = self.total_input,
                .output_written = self.total_output,
                .payload_remaining = self.decoded_len -| self.total_output,
                .pending_literals = self.pending_literals,
                .pending_copy = self.pending_copy,
                .retained_input_bytes = self.header_len,
                .history_bytes = @min(self.total_output, self.history.len),
                .metadata_written = self.metadata_written,
                .metadata_total = self.metadata_total,
                .metadata_truncated = self.metadata_written != self.metadata_total,
                .metadata_block_count = self.metadata_block_count,
                .metadata_blocks_captured = @min(self.metadata_block_count, self.metadata_block_lengths.len),
                .metadata_blocks_truncated = self.metadata_block_count > self.metadata_block_lengths.len,
                .last_error_name = self.last_error_name,
                .last_error_phase = self.last_error_phase,
            };
        }
        pub fn diagnostics(self: *const Self) core.StreamingDiagnostics {
            const snap = self.snapshot();
            return .{
                .phase_name = @tagName(snap.phase),
                .frame_input_read = snap.input_read,
                .output_written = snap.output_written,
                .expected_output_len = self.options.expected_output_len,
                .payload_remaining = snap.payload_remaining,
                .last_error_name = snap.last_error_name,
                .last_error_phase_name = if (snap.last_error_name.len == 0) "" else @tagName(snap.last_error_phase),
                .recoverability_hint_name = if (std.mem.eql(u8, snap.last_error_name, @errorName(error.TruncatedFrame))) "truncated_input" else if (std.mem.eql(u8, snap.last_error_name, @errorName(error.UnsupportedBrotliFeature))) "unsupported_feature" else if (snap.last_error_name.len == 0) "none" else "payload_corrupt",
            };
        }
        pub fn finish(self: *Self) Error!void {
            if (self.phase != .done) return self.fail(self.phase, error.TruncatedFrame);
            self.finished = true;
        }

        pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            if (self.finished) {
                if (input.len != 0) return self.fail(.done, error.TrailingData);
                return result(0, 0, .done);
            }
            var input_read: usize = 0;
            var output_written: usize = 0;
            defer self.total_input += input_read;
            while (true) switch (self.phase) {
                .header => {
                    while (input_read < input.len) {
                        if (self.header_len == self.header_bytes.len) return self.fail(.header, error.UnsupportedBrotliFeature);
                        self.header_bytes[self.header_len] = input[input_read];
                        self.header_len += 1;
                        input_read += 1;
                        const parsed = Codec.parseHeader(self.header_bytes[0..self.header_len]) catch |err| switch (err) {
                            error.TruncatedFrame => continue,
                            else => return self.fail(.header, err),
                        };
                        if (parsed.header.decoded_len > self.options.max_output_len) return self.fail(.header, error.OutputLimitExceeded);
                        if (self.options.expected_output_len) |expected| {
                            if (parsed.header.final) {
                                if (parsed.header.decoded_len != expected) return self.fail(.header, error.SizeMismatch);
                            } else if (parsed.header.decoded_len > expected) return self.fail(.header, error.SizeMismatch);
                        }
                        if (self.history.len == 0) return self.fail(.header, error.OutputTooSmall);
                        const byte_index = parsed.bits_read / 8;
                        const bit_index: u3 = @intCast(parsed.bits_read % 8);
                        const available_bits = self.header_len * 8 - parsed.bits_read;
                        if (available_bits > 127) return self.fail(.header, error.CorruptFrame);
                        self.staged_bits = if (available_bits == 0) 0 else @as(u128, self.header_bytes[byte_index]) >> bit_index;
                        self.staged_bit_count = @intCast(available_bits);
                        self.stream_bits = parsed.bits_read;
                        self.header = parsed.header;
                        self.decoded_len = parsed.header.decoded_len;
                        self.final_meta_block = parsed.header.final;
                        self.phase = .command;
                        break;
                    }
                    if (self.phase == .header) return result(input_read, output_written, .need_input);
                },
                .command => {
                    if (self.total_output == self.decoded_len) {
                        self.phase = if (self.final_meta_block) .padding else .trailer;
                        continue;
                    }
                    var reader = progressive_bits.Reader.init(input, &input_read, &self.staged_bits, &self.staged_bit_count, &self.stream_bits);
                    const saved = reader.checkpoint();
                    const saved_header = self.header;
                    const command = Codec.readCommand(&self.header, &reader) catch |err| switch (err) {
                        error.TruncatedFrame => {
                            self.header = saved_header;
                            try reader.restoreKeepingInput(saved);
                            return result(input_read, output_written, .need_input);
                        },
                        else => return self.fail(.command, err),
                    };
                    const remaining = self.decoded_len - self.total_output;
                    if (command.insert_len > remaining) return self.fail(.command, error.CorruptFrame);
                    // RFC 7932 ignores the copy half of the final command when
                    // its insert reaches MLEN exactly. Otherwise both spans
                    // must fit before any caller output is mutated.
                    self.pending_literals = command.insert_len;
                    self.pending_copy = command.copy_len;
                    self.implicit_last_distance = command.implicit_last_distance;
                    self.phase = if (self.pending_literals == 0) .distance else .literals;
                },
                .literals => {
                    while (self.pending_literals != 0 and output_written < output.len) {
                        var reader = progressive_bits.Reader.init(input, &input_read, &self.staged_bits, &self.staged_bit_count, &self.stream_bits);
                        const saved = reader.checkpoint();
                        const saved_header = self.header;
                        const literal = Codec.readLiteral(&self.header, &reader, self.previous[1], self.previous[0]) catch |err| switch (err) {
                            error.TruncatedFrame => {
                                self.header = saved_header;
                                try reader.restoreKeepingInput(saved);
                                return result(input_read, output_written, .need_input);
                            },
                            else => return self.fail(.literals, err),
                        };
                        self.emit(output, &output_written, literal);
                        self.pending_literals -= 1;
                    }
                    if (self.pending_literals != 0) return result(input_read, output_written, .need_output);
                    if (self.total_output == self.decoded_len) {
                        self.pending_copy = 0;
                        self.phase = if (self.final_meta_block) .padding else .trailer;
                    } else {
                        self.phase = .distance;
                    }
                },
                .distance => {
                    if (self.implicit_last_distance) {
                        self.copy_distance = self.last_distances[3];
                        try self.beginCopy();
                        continue;
                    }
                    var reader = progressive_bits.Reader.init(input, &input_read, &self.staged_bits, &self.staged_bit_count, &self.stream_bits);
                    const saved = reader.checkpoint();
                    const saved_header = self.header;
                    const decoded = Codec.readDistance(&self.header, &reader, self.pending_copy, &self.last_distances) catch |err| switch (err) {
                        error.TruncatedFrame => {
                            self.header = saved_header;
                            try reader.restoreKeepingInput(saved);
                            return result(input_read, output_written, .need_input);
                        },
                        else => return self.fail(.distance, err),
                    };
                    self.copy_distance = decoded.distance;
                    if (decoded.distance <= self.total_output and decoded.update_ring) pushLastDistance(&self.last_distances, decoded.distance);
                    try self.beginCopy();
                },
                .copy => {
                    while (self.pending_copy != 0 and output_written < output.len) {
                        const source = self.total_output - self.copy_distance;
                        const value = self.history[source % self.history.len];
                        self.emit(output, &output_written, value);
                        self.pending_copy -= 1;
                    }
                    if (self.pending_copy != 0) return result(input_read, output_written, .need_output);
                    self.phase = .command;
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
                            self.stored_remaining = std.math.add(usize, len_minus_one, 1) catch return self.fail(.trailer, error.IntegerOverflow);
                            if (self.total_output > self.options.max_output_len or self.stored_remaining > self.options.max_output_len - self.total_output) return self.fail(.trailer, error.OutputLimitExceeded);
                            if (self.options.expected_output_len) |expected|
                                if (self.total_output > expected or self.stored_remaining > expected - self.total_output) return self.fail(.trailer, error.SizeMismatch);
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
                                self.recordMetadataBlock();
                                self.phase = .trailer;
                            } else self.phase = if (self.metadata) .metadata else .stored;
                            self.next_header_state = .is_last;
                            break;
                        },
                    };
                },
                .stored => {
                    const n = @min(self.stored_remaining, @min(input.len - input_read, output.len - output_written));
                    for (input[input_read..][0..n]) |value| self.emit(output, &output_written, value);
                    input_read += n;
                    self.stored_remaining -= n;
                    if (self.stored_remaining != 0) return result(input_read, output_written, if (output_written == output.len) .need_output else .need_input);
                    if (self.options.expected_output_len) |expected| if (self.total_output > expected) return self.fail(.stored, error.SizeMismatch);
                    self.phase = .trailer;
                },
                .metadata => {
                    const n = @min(self.metadata_remaining, input.len - input_read);
                    const capture = @min(n, self.metadata_output.len -| self.metadata_written);
                    if (capture != 0) @memcpy(self.metadata_output[self.metadata_written..][0..capture], input[input_read..][0..capture]);
                    self.metadata_written += capture;
                    self.metadata_total += n;
                    self.current_metadata_len += n;
                    input_read += n;
                    self.metadata_remaining -= n;
                    if (self.metadata_remaining != 0) return result(input_read, output_written, .need_input);
                    self.recordMetadataBlock();
                    self.phase = .trailer;
                },
                .dictionary => {
                    const remaining = self.dictionary_scratch[self.dictionary_offset..self.dictionary_len];
                    const n = @min(output.len - output_written, remaining.len);
                    for (remaining[0..n]) |value| self.emit(output, &output_written, value);
                    self.dictionary_offset += n;
                    if (self.dictionary_offset != self.dictionary_len) return result(input_read, output_written, .need_output);
                    self.dictionary_offset = 0;
                    self.dictionary_len = 0;
                    self.pending_copy = 0;
                    self.phase = .command;
                },
                .padding => {
                    const padding_bits: u8 = @intCast((8 - self.stream_bits % 8) % 8);
                    if (self.staged_bit_count < padding_bits) return result(input_read, output_written, .need_input);
                    if (padding_bits != 0) {
                        const mask = (@as(u128, 1) << @intCast(padding_bits)) - 1;
                        if ((self.staged_bits & mask) != 0) return self.fail(.padding, error.CorruptFrame);
                        self.staged_bits >>= @intCast(padding_bits);
                        self.staged_bit_count -= padding_bits;
                    }
                    if (self.staged_bit_count != 0 or input_read != input.len) return self.fail(.padding, error.TrailingData);
                    self.phase = .done;
                },
                .done => {
                    if (input_read != input.len) return self.fail(.done, error.TrailingData);
                    return result(input_read, output_written, .done);
                },
            };
        }

        fn emit(self: *Self, output: []u8, output_written: *usize, value: u8) void {
            output[output_written.*] = value;
            output_written.* += 1;
            self.history[self.total_output % self.history.len] = value;
            self.previous[0] = self.previous[1];
            self.previous[1] = value;
            self.total_output += 1;
        }
        fn beginCopy(self: *Self) Error!void {
            if (self.copy_distance == 0) return self.fail(.copy, error.InvalidMatch);
            const remaining = self.decoded_len - self.total_output;
            if (self.copy_distance <= self.total_output) {
                if (self.copy_distance > self.history.len) return self.fail(.copy, error.InvalidMatch);
                if (self.pending_copy > remaining) return self.fail(.copy, error.CorruptFrame);
                self.phase = .copy;
                return;
            }

            // Dictionary references are encoded as distances beyond the
            // produced history. Materialize only the transformed word (at most
            // 64 bytes) and stream that scratch through the normal output and
            // history accounting. Dictionary references never update repcodes.
            const word = try Codec.dictionaryWord(self.copy_distance, self.pending_copy, self.total_output, &self.dictionary_scratch);
            if (word.len > remaining or word.len > self.dictionary_scratch.len) return self.fail(.dictionary, error.CorruptFrame);
            if (word.ptr != self.dictionary_scratch[0..].ptr) @memcpy(self.dictionary_scratch[0..word.len], word);
            self.dictionary_offset = 0;
            self.dictionary_len = word.len;
            self.phase = .dictionary;
        }
        fn pushLastDistance(last_distances: *[4]usize, distance: usize) void {
            last_distances[0] = last_distances[1];
            last_distances[1] = last_distances[2];
            last_distances[2] = last_distances[3];
            last_distances[3] = distance;
        }
        fn fail(self: *Self, phase: Phase, err: Error) Error {
            self.last_error_name = @errorName(err);
            self.last_error_phase = phase;
            return err;
        }
        fn validateFinalOutputSize(self: *Self) Error!void {
            if (self.options.expected_output_len) |expected|
                if (self.total_output != expected) return self.fail(.trailer, error.SizeMismatch);
        }
        fn recordMetadataBlock(self: *Self) void {
            if (self.metadata_block_count < self.metadata_block_lengths.len)
                self.metadata_block_lengths[self.metadata_block_count] = self.current_metadata_len;
            self.metadata_block_count += 1;
            self.current_metadata_len = 0;
            self.metadata = false;
        }
        fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
            return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
        }
    };
}
