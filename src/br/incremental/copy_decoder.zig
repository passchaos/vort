const std = @import("std");
const core = @import("../../core.zig");
const stream_count = core.stream_count;
const progressive_bits = @import("bit_reader.zig");
const shared_dictionary = @import("../shared_dictionary.zig");

/// Progressive decoder for compressed Brotli streams with explicit distances.
/// History is caller-owned, which makes memory use visible and lets overlapping
/// copies and persistent RFC distance/context state resume across meta-blocks
/// and arbitrarily small output buffers.
pub fn Decoder(comptime Codec: type) type {
    return struct {
        options: Options,
        history: []u8,
        phase: Phase = .window,
        window_state: WindowState = .first,
        window_bits: u5 = 16,
        large_window: bool = false,
        header_bytes: [Codec.max_stream_header_bytes]u8 = undefined,
        header_len: usize = 0,
        header_bit_count: usize = 0,
        header: Codec.Header = undefined,
        staged_bits: u128 = 0,
        staged_bit_count: u8 = 0,
        trailing_bytes: [16]u8 = undefined,
        trailing_len: u5 = 0,
        /// Wrapping consumed-bit phase for alignment, not an absolute offset.
        /// Stored/metadata bytes do not affect it; diagnostics count bytes.
        stream_bits: usize = 0,
        decoded_len: Counter = 0,
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
        pending_literals: usize = 0,
        pending_copy: usize = 0,
        copy_distance: usize = 0,
        implicit_last_distance: bool = false,
        update_distance_ring: bool = false,
        shared_dictionary_validated: bool = false,
        shared_dictionary_size: usize = 0,
        dictionary_source: DictionarySource = .static,
        compound_cursor: shared_dictionary.Cursor = undefined,
        dictionary_scratch: [shared_dictionary.max_static_output_len]u8 = undefined,
        dictionary_offset: usize = 0,
        dictionary_len: usize = 0,
        last_distances: [4]usize = .{ 16, 15, 11, 4 },
        previous: [2]u8 = .{ 0, 0 },
        total_input: Counter = 0,
        total_output: Counter = 0,
        finished: bool = false,
        operation_input: Counter = 0,
        operation_output: Counter = 0,
        frame_count: Counter = 0,
        fatal_error: ?Error = null,
        header_storage_exhausted: bool = false,
        error_input_offset: ?Counter = null,
        error_output_offset: ?Counter = null,
        last_step_progress: core.Progress = .{},
        last_error_name: []const u8 = "",
        last_error_phase: Phase = .window,

        const Self = @This();
        pub const Error = Codec.Error;
        pub const Counter = core.StreamCount;
        pub const embedded_compressed_header_capacity: usize = Codec.max_stream_header_bytes;
        pub const Options = struct {
            max_output_len: Counter = std.math.maxInt(Counter),
            /// Output cap across frames until reset or resetWithOptions.
            max_total_output_len: Counter = std.math.maxInt(Counter),
            expected_output_len: ?Counter = null,
            decode: Codec.DecodeOptions = .{},
            /// Optional caller-owned storage for compressed meta-block headers.
            /// The decoder uses it only when it is larger than the built-in
            /// bounded buffer. It must remain valid and must not alias input,
            /// output, or history for the lifetime of the decoder.
            compressed_header_scratch: []u8 = &.{},
            metadata_output: []u8 = &.{},
            metadata_block_lengths: []usize = &.{},
            /// Complete one Brotli stream and retain whole-byte lookahead for
            /// an outer member dispatcher instead of rejecting trailing data.
            allow_trailing_data: bool = false,
        };
        pub const Phase = enum { window, compressed_header, command, literals, distance, copy, dictionary, trailer, stored, metadata, padding, done };
        const WindowState = enum { first, low3, tail, large_marker, large_bits };
        const NextHeaderState = enum { is_last, last_empty, nibbles, metadata_reserved, metadata_count, metadata_len, block_len, uncompressed, alignment };
        const DictionarySource = enum { static, compound };
        pub const Snapshot = struct {
            phase: Phase,
            window_bits: u5,
            input_read: Counter,
            output_written: Counter,
            payload_remaining: usize,
            pending_literals: usize,
            pending_copy: usize,
            copy_distance: usize,
            last_distances: [4]usize,
            retained_input_bytes: usize,
            compressed_header_capacity: usize,
            history_bytes: usize,
            metadata_written: usize,
            metadata_total: Counter,
            metadata_truncated: bool,
            metadata_block_count: Counter,
            metadata_blocks_captured: usize,
            metadata_blocks_truncated: bool,
            trailing_input_bytes: usize,
            last_error_name: []const u8,
            last_error_phase: Phase,
            total_compressed: Counter,
            total_output: Counter,
            frame_count: Counter,
            error_input_offset: ?Counter,
            error_output_offset: ?Counter,
            last_step_progress: core.Progress,
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
            self.resetWithOptions(self.options);
        }
        /// Caller storage is retained; a reset begins a new operation.
        pub fn resetWithOptions(self: *Self, options: Options) void {
            self.* = initWithOptions(self.history, options);
        }
        /// Continue an operation without relaxing its total output cap.
        pub fn nextFrame(self: *Self, options: Options) Error!void {
            if (self.fatal_error) |err| return err;
            if (self.phase != .done) return error.InvalidBlockPlan;
            var next = options;
            next.max_total_output_len = @min(self.options.max_total_output_len, next.max_total_output_len);
            const read = try stream_count.add(self.operation_input, self.total_input);
            const written = try stream_count.add(self.operation_output, self.total_output);
            if (written > next.max_total_output_len) return error.OutputLimitExceeded;
            const count = try stream_count.add(self.frame_count, 1);
            self.resetWithOptions(next);
            self.operation_input = read;
            self.operation_output = written;
            self.frame_count = count;
        }
        pub fn snapshot(self: *const Self) Snapshot {
            return .{
                .phase = self.phase,
                .window_bits = self.window_bits,
                .input_read = self.total_input,
                .output_written = self.total_output,
                .payload_remaining = @intCast(self.decoded_len -| self.total_output),
                .pending_literals = self.pending_literals,
                .pending_copy = self.pending_copy,
                .copy_distance = self.copy_distance,
                .last_distances = self.last_distances,
                .retained_input_bytes = self.header_len,
                .compressed_header_capacity = self.headerStorageConst().len,
                .history_bytes = stream_count.bounded(self.total_output, self.history.len),
                .metadata_written = self.metadata_written,
                .metadata_total = self.metadata_total,
                .metadata_truncated = self.metadata_written != self.metadata_total,
                .metadata_block_count = self.metadata_block_count,
                .metadata_blocks_captured = stream_count.bounded(self.metadata_block_count, self.metadata_block_lengths.len),
                .metadata_blocks_truncated = self.metadata_block_count > self.metadata_block_lengths.len,
                .trailing_input_bytes = self.trailing_len,
                .last_error_name = self.last_error_name,
                .last_error_phase = self.last_error_phase,
                .total_compressed = self.operation_input + self.total_input,
                .total_output = self.operation_output + self.total_output,
                .frame_count = self.frame_count + @intFromBool(self.phase == .done),
                .error_input_offset = self.error_input_offset,
                .error_output_offset = self.error_output_offset,
                .last_step_progress = self.last_step_progress,
            };
        }
        pub fn diagnostics(self: *const Self) core.StreamingDiagnostics {
            const snap = self.snapshot();
            return .{
                .phase_name = @tagName(snap.phase),
                .input_read = snap.input_read,
                .error_input_offset = snap.error_input_offset,
                .error_output_offset = snap.error_output_offset,
                .last_step_progress = snap.last_step_progress,
                .frame_input_read = snap.input_read,
                .output_written = snap.output_written,
                .expected_output_len = self.options.expected_output_len,
                .payload_remaining = snap.payload_remaining,
                .last_error_name = snap.last_error_name,
                .last_error_phase_name = if (snap.last_error_name.len == 0) "" else @tagName(snap.last_error_phase),
                .recoverability_hint_name = if (self.header_storage_exhausted) "grow_compressed_header" else if (std.mem.eql(u8, snap.last_error_name, @errorName(error.TruncatedFrame))) "truncated_input" else if (std.mem.eql(u8, snap.last_error_name, @errorName(error.UnsupportedBrotliFeature))) "unsupported_feature" else if (snap.last_error_name.len == 0) "none" else "payload_corrupt",
            };
        }
        pub fn finish(self: *Self) Error!void {
            self.last_step_progress = .{};
            if (self.fatal_error) |err| return err;
            if (self.phase != .done) {
                const err = self.fail(self.phase, error.TruncatedFrame);
                self.publishFailure(err);
                return err;
            }
            self.finished = true;
        }

        pub fn trailingInput(self: *const Self) []const u8 {
            if (self.phase != .done or !self.options.allow_trailing_data)
                return &.{};
            return self.trailing_bytes[0..self.trailing_len];
        }

        /// Replace compressed-header storage without resetting the progressive
        /// state. The new slice must not alias decoder input, output, history,
        /// or the previous scratch and must remain valid for the decoder's
        /// lifetime (or until another successful replacement).
        pub fn replaceCompressedHeaderScratch(self: *Self, scratch: []u8) Error!void {
            if (self.fatal_error) |err| return err;
            const current = self.headerStorageConst();
            if (scratch.len <= current.len or scratch.len < self.header_len)
                return error.OutputTooSmall;
            @memcpy(scratch[0..self.header_len], current[0..self.header_len]);
            self.options.compressed_header_scratch = scratch;
            if (self.header_storage_exhausted) {
                self.header_storage_exhausted = false;
                self.last_error_name = "";
                self.error_input_offset = null;
                self.error_output_offset = null;
            }
        }

        pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            self.last_step_progress = .{};
            if (self.fatal_error) |err| return err;
            self.header_storage_exhausted = false;
            const before_input = self.total_input;
            const before_output = self.total_output;
            var accepted_input: usize = 0;
            const outcome = self.stepImpl(input, output, &accepted_input);
            // stepImpl preflights the full offered input before parsing. Its
            // accepted prefix therefore fits, including when parsing failed.
            self.total_input = stream_count.addLocal(self.total_input, accepted_input) catch unreachable;
            const stepped = outcome catch |err| {
                self.last_step_progress = .{
                    .input_read = @intCast(self.total_input - before_input),
                    .output_written = @intCast(self.total_output - before_output),
                };
                self.publishFailure(err);
                return err;
            };
            self.last_step_progress = stepped.progress;
            return stepped;
        }

        fn stepImpl(self: *Self, input: []const u8, output: []u8, accepted_input: *usize) Error!core.StepResult {
            if (self.options.expected_output_len) |expected| {
                if (expected > self.outputLimit()) return self.fail(self.phase, error.OutputLimitExceeded);
            }
            const cumulative_input = stream_count.add(self.operation_input, self.total_input) catch
                return self.fail(self.phase, error.IntegerOverflow);
            _ = stream_count.addLocal(cumulative_input, input.len) catch
                return self.fail(self.phase, error.IntegerOverflow);
            if (self.finished) {
                if (input.len != 0 and !self.options.allow_trailing_data)
                    return self.fail(.done, error.TrailingData);
                return result(0, 0, .done);
            }
            var input_read: usize = 0;
            var output_written: usize = 0;
            defer accepted_input.* = input_read;
            if (!self.shared_dictionary_validated) {
                self.shared_dictionary_size = self.options.decode.shared_dictionary.totalSize() catch |err| switch (err) {
                    error.IntegerOverflow => return self.fail(self.phase, error.IntegerOverflow),
                    error.TooManyRawPrefixes, error.RawDictionaryTooLarge => return self.fail(self.phase, error.CorruptFrame),
                };
                self.shared_dictionary_validated = true;
            }
            while (true) switch (self.phase) {
                .window => {
                    var reader = progressive_bits.Reader.init(input, &input_read, &self.staged_bits, &self.staged_bit_count, &self.stream_bits);
                    while (self.phase == .window) switch (self.window_state) {
                        .first => {
                            const first = reader.readBits(u1, 1) catch |err| switch (err) {
                                error.TruncatedFrame => return result(input_read, output_written, .need_input),
                                else => return self.fail(.window, err),
                            };
                            if (first == 0) {
                                self.window_bits = 16;
                                self.phase = .trailer;
                            } else {
                                self.window_state = .low3;
                            }
                        },
                        .low3 => {
                            const low3 = reader.readBits(u3, 3) catch |err| switch (err) {
                                error.TruncatedFrame => return result(input_read, output_written, .need_input),
                                else => return self.fail(.window, err),
                            };
                            if (low3 == 0) {
                                self.window_state = .tail;
                            } else {
                                self.window_bits = @as(u5, low3) + 17;
                                self.phase = .trailer;
                            }
                        },
                        .tail => {
                            const tail = reader.readBits(u3, 3) catch |err| switch (err) {
                                error.TruncatedFrame => return result(input_read, output_written, .need_input),
                                else => return self.fail(.window, err),
                            };
                            if (tail == 1) {
                                if (!self.options.decode.allow_large_window) return self.fail(.window, error.CorruptFrame);
                                self.window_state = .large_marker;
                            } else {
                                self.window_bits = if (tail == 0) 17 else @as(u5, tail) + 8;
                                self.phase = .trailer;
                            }
                        },
                        .large_marker => {
                            const marker = reader.readBits(u1, 1) catch |err| switch (err) {
                                error.TruncatedFrame => return result(input_read, output_written, .need_input),
                                else => return self.fail(.window, err),
                            };
                            if (marker != 0) return self.fail(.window, error.CorruptFrame);
                            self.window_state = .large_bits;
                        },
                        .large_bits => {
                            const bits = reader.readBits(u6, 6) catch |err| switch (err) {
                                error.TruncatedFrame => return result(input_read, output_written, .need_input),
                                else => return self.fail(.window, err),
                            };
                            if (bits < 10 or bits > 30) return self.fail(.window, error.CorruptFrame);
                            self.window_bits = @intCast(bits);
                            self.large_window = true;
                            self.phase = .trailer;
                        },
                    };
                },
                .compressed_header => {
                    while (true) {
                        // The normalized header may start and end partway
                        // through bytes. Pass its exact logical bit length so
                        // the ordinary parser can inspect the final retained
                        // byte without treating synthetic high padding as input.
                        if (self.header_len != 0) {
                            const parsed = Codec.parseMetaBlockHeader(
                                self.headerStorage()[0..self.header_len],
                                self.header_bit_count,
                                self.decoded_len,
                                self.final_meta_block,
                                self.large_window,
                            ) catch |err| switch (err) {
                                error.TruncatedFrame => null,
                                else => return self.fail(.compressed_header, err),
                            };
                            if (parsed) |ready| {
                                // Batched probing may include complete bytes
                                // after the compressed header. Return those to
                                // this call's input cursor; only a sub-byte tail
                                // belongs in the cross-phase bit reservoir.
                                const unread_bytes = (self.header_bit_count - ready.bits_read) / 8;
                                std.debug.assert(unread_bytes <= input_read);
                                input_read -= unread_bytes;
                                self.header_bit_count -= unread_bytes * 8;
                                self.header_len = (self.header_bit_count + 7) / 8;
                                try self.installCompressedHeader(ready);
                                break;
                            }
                        }
                        if (input_read == input.len) return result(input_read, output_written, .need_input);
                        // Parse bounded batches rather than restarting the
                        // complete header parser after every byte. On success,
                        // whole over-read bytes are returned to the caller input
                        // cursor below and only the sub-byte suffix enters the
                        // u128 reservoir.
                        const available = self.headerStorage().len - self.header_len;
                        if (available == 0) {
                            // The full buffer was parsed above and still needs
                            // input. Publishing storage exhaustion here leaves
                            // no complete payload bytes to rewind across calls.
                            self.header_storage_exhausted = true;
                            return self.fail(.compressed_header, error.UnsupportedBrotliFeature);
                        }
                        const append_end = input_read + @min(available, @min(@as(usize, 4096), input.len - input_read));
                        while (input_read < append_end) : (input_read += 1)
                            try self.appendHeaderByte(input[input_read]);
                    }
                },
                .command => {
                    if (self.total_output == self.decoded_len) {
                        self.phase = if (self.final_meta_block) .padding else .trailer;
                        continue;
                    }
                    var reader = progressive_bits.Reader.init(input, &input_read, &self.staged_bits, &self.staged_bit_count, &self.stream_bits);
                    const saved = reader.checkpoint();
                    const saved_command = Codec.commandState(&self.header);
                    const command = Codec.readCommand(&self.header, &reader) catch |err| switch (err) {
                        error.TruncatedFrame => {
                            Codec.restoreCommandState(&self.header, saved_command);
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
                        const saved_literal = Codec.literalState(&self.header);
                        const literal = Codec.readLiteral(&self.header, &reader, self.previous[1], self.previous[0]) catch |err| switch (err) {
                            error.TruncatedFrame => {
                                Codec.restoreLiteralState(&self.header, saved_literal);
                                try reader.restoreKeepingInput(saved);
                                return result(input_read, output_written, .need_input);
                            },
                            else => return self.fail(.literals, err),
                        };
                        try self.emit(output, &output_written, literal);
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
                        self.update_distance_ring = false;
                        try self.beginCopy();
                        continue;
                    }
                    var reader = progressive_bits.Reader.init(input, &input_read, &self.staged_bits, &self.staged_bit_count, &self.stream_bits);
                    const saved = reader.checkpoint();
                    const saved_distance = Codec.distanceState(&self.header);
                    const decoded = Codec.readDistance(&self.header, &reader, self.pending_copy, &self.last_distances) catch |err| switch (err) {
                        error.TruncatedFrame => {
                            Codec.restoreDistanceState(&self.header, saved_distance);
                            try reader.restoreKeepingInput(saved);
                            return result(input_read, output_written, .need_input);
                        },
                        else => return self.fail(.distance, err),
                    };
                    self.copy_distance = decoded.distance;
                    self.update_distance_ring = decoded.update_ring;
                    try self.beginCopy();
                },
                .copy => {
                    const copy_len = @min(self.pending_copy, output.len - output_written);
                    if (copy_len == 0) return result(input_read, output_written, .need_output);
                    const next_output = try self.outputEnd(copy_len);
                    const target = output[output_written..][0..copy_len];
                    self.copySpan(target);
                    output_written += copy_len;
                    self.total_output = next_output;
                    self.pending_copy -= copy_len;
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
                            self.final_meta_block = value != 0;
                            self.next_header_state = if (self.final_meta_block) .last_empty else .nibbles;
                        },
                        .last_empty => {
                            const value = reader.readBits(u1, 1) catch |err| switch (err) {
                                error.TruncatedFrame => return result(input_read, output_written, .need_input),
                                else => return self.fail(.trailer, err),
                            };
                            if (value != 0) {
                                try self.validateFinalOutputSize();
                                self.phase = .padding;
                                break;
                            }
                            self.next_header_state = .nibbles;
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
                            if (self.total_output > self.outputLimit() or self.stored_remaining > self.outputLimit() - self.total_output) return self.fail(.trailer, error.OutputLimitExceeded);
                            if (self.options.expected_output_len) |expected|
                                if (self.total_output > expected or self.stored_remaining > expected - self.total_output) return self.fail(.trailer, error.SizeMismatch);
                            if (self.history.len == 0) return self.fail(.trailer, error.OutputTooSmall);
                            if (self.final_meta_block) {
                                try self.beginCompressedHeader();
                                break;
                            }
                            self.next_header_state = .uncompressed;
                        },
                        .uncompressed => {
                            const value = reader.readBits(u1, 1) catch |err| switch (err) {
                                error.TruncatedFrame => return result(input_read, output_written, .need_input),
                                else => return self.fail(.trailer, err),
                            };
                            if (value == 0) {
                                try self.beginCompressedHeader();
                                break;
                            }
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
                    for (input[input_read..][0..n]) |value| {
                        try self.emit(output, &output_written, value);
                        input_read += 1;
                        self.stored_remaining -= 1;
                    }
                    if (self.stored_remaining != 0) return result(input_read, output_written, if (output_written == output.len) .need_output else .need_input);
                    if (self.options.expected_output_len) |expected| if (self.total_output > expected) return self.fail(.stored, error.SizeMismatch);
                    self.phase = .trailer;
                },
                .metadata => {
                    const n = @min(self.metadata_remaining, input.len - input_read);
                    const next_metadata_total = stream_count.addLocal(self.metadata_total, n) catch
                        return self.fail(.metadata, error.IntegerOverflow);
                    if (n == self.metadata_remaining)
                        _ = stream_count.add(self.metadata_block_count, 1) catch return self.fail(.metadata, error.IntegerOverflow);
                    const capture = @min(n, self.metadata_output.len -| self.metadata_written);
                    if (capture != 0) @memcpy(self.metadata_output[self.metadata_written..][0..capture], input[input_read..][0..capture]);
                    self.metadata_written += capture;
                    self.metadata_total = next_metadata_total;
                    self.current_metadata_len += n;
                    input_read += n;
                    self.metadata_remaining -= n;
                    if (self.metadata_remaining != 0) return result(input_read, output_written, .need_input);
                    try self.recordMetadataBlock();
                    self.phase = .trailer;
                },
                .dictionary => {
                    if (self.dictionary_source == .compound) {
                        // The cursor writes directly to caller output, so check
                        // its bounded span before advancing dictionary state.
                        const n_bound = @min(self.pending_copy, output.len - output_written);
                        _ = try self.outputEnd(n_bound);
                        const n = self.compound_cursor.copyInto(output[output_written..][0..n_bound]);
                        if (n != 0) {
                            try self.commitDictionarySpan(output[output_written..][0..n]);
                            output_written += n;
                            self.pending_copy -= n;
                        }
                        if (!self.compound_cursor.isDone()) return result(input_read, output_written, .need_output);
                        self.pending_copy = 0;
                        self.dictionary_source = .static;
                        self.phase = .command;
                        continue;
                    }
                    const remaining = self.dictionary_scratch[self.dictionary_offset..self.dictionary_len];
                    const n = @min(output.len - output_written, remaining.len);
                    for (remaining[0..n]) |value| {
                        try self.emit(output, &output_written, value);
                        self.dictionary_offset += 1;
                    }
                    if (self.dictionary_offset != self.dictionary_len) return result(input_read, output_written, .need_output);
                    self.dictionary_offset = 0;
                    self.dictionary_len = 0;
                    self.pending_copy = 0;
                    self.phase = .command;
                },
                .padding => {
                    _ = stream_count.add(self.frame_count, 1) catch return self.fail(.padding, error.IntegerOverflow);
                    const padding_bits: u8 = @intCast((8 - self.stream_bits % 8) % 8);
                    if (self.staged_bit_count < padding_bits) return result(input_read, output_written, .need_input);
                    if (padding_bits != 0) {
                        const mask = (@as(u128, 1) << @intCast(padding_bits)) - 1;
                        if ((self.staged_bits & mask) != 0) return self.fail(.padding, error.CorruptFrame);
                        self.staged_bits >>= @intCast(padding_bits);
                        self.staged_bit_count -= padding_bits;
                    }
                    if (self.staged_bit_count % 8 != 0)
                        return self.fail(.padding, error.CorruptFrame);
                    const trailing_len: u5 = @intCast(self.staged_bit_count / 8);
                    if ((trailing_len != 0 or input_read != input.len) and
                        !self.options.allow_trailing_data)
                    {
                        return self.fail(.padding, error.TrailingData);
                    }
                    for (0..trailing_len) |index|
                        self.trailing_bytes[index] = @truncate(
                            self.staged_bits >> @intCast(index * 8),
                        );
                    self.trailing_len = trailing_len;
                    self.staged_bits = 0;
                    self.staged_bit_count = 0;
                    self.phase = .done;
                },
                .done => {
                    if (input_read != input.len and !self.options.allow_trailing_data)
                        return self.fail(.done, error.TrailingData);
                    return result(input_read, output_written, .done);
                },
            };
        }

        fn emit(self: *Self, output: []u8, output_written: *usize, value: u8) Error!void {
            const next_output = try self.outputEnd(1);
            output[output_written.*] = value;
            output_written.* += 1;
            self.history[stream_count.ringIndex(self.total_output, self.history.len)] = value;
            self.previous[0] = self.previous[1];
            self.previous[1] = value;
            self.total_output = next_output;
        }
        fn copySpan(self: *Self, output: []u8) void {
            std.debug.assert(output.len != 0 and self.copy_distance <= self.history.len);
            if (output.len < 16) return self.copySpanScalar(output);
            const seed_len = @min(output.len, self.copy_distance);
            const source = stream_count.ringIndex(self.total_output - self.copy_distance, self.history.len);
            const first_source_len = @min(seed_len, self.history.len - source);
            @memcpy(output[0..first_source_len], self.history[source..][0..first_source_len]);
            if (first_source_len != seed_len)
                @memcpy(output[first_source_len..seed_len], self.history[0 .. seed_len - first_source_len]);

            // Once one complete distance period is materialized, the output
            // buffer itself is the cheapest source for the RFC forward-copy
            // recurrence. Doubling preserves arbitrary overlap patterns.
            var produced = seed_len;
            while (produced < output.len) {
                const n = @min(produced, output.len - produced);
                std.mem.copyForwards(u8, output[produced..][0..n], output[0..n]);
                produced += n;
            }

            // Only the newest history-sized suffix survives after a long copy.
            // Commit that suffix once instead of repeatedly round-tripping each
            // full ring through history while the output already contains the
            // complete forward-copy recurrence.
            const retained_len = @min(output.len, self.history.len);
            const retained = output[output.len - retained_len ..];
            const destination = stream_count.ringIndex(self.total_output + stream_count.fromLocal(output.len - retained_len), self.history.len);
            const first_destination_len = @min(retained.len, self.history.len - destination);
            @memcpy(self.history[destination..][0..first_destination_len], retained[0..first_destination_len]);
            if (first_destination_len != retained.len)
                @memcpy(self.history[0 .. retained.len - first_destination_len], retained[first_destination_len..]);
            self.updatePreviousFromSpan(output);
        }
        fn copySpanScalar(self: *Self, output: []u8) void {
            var source = stream_count.ringIndex(self.total_output - self.copy_distance, self.history.len);
            var destination = stream_count.ringIndex(self.total_output, self.history.len);
            var previous = self.previous;
            for (output) |*out| {
                const value = self.history[source];
                out.* = value;
                self.history[destination] = value;
                source += 1;
                if (source == self.history.len) source = 0;
                destination += 1;
                if (destination == self.history.len) destination = 0;
                previous[0] = previous[1];
                previous[1] = value;
            }
            self.previous = previous;
        }
        fn updatePreviousFromSpan(self: *Self, output: []const u8) void {
            if (output.len == 1) {
                self.previous = .{ self.previous[1], output[0] };
            } else {
                self.previous = .{ output[output.len - 2], output[output.len - 1] };
            }
        }
        fn commitDictionarySpan(self: *Self, output: []const u8) Error!void {
            std.debug.assert(output.len != 0);
            const next_output = try self.outputEnd(output.len);
            const retained_len = @min(output.len, self.history.len);
            const retained = output[output.len - retained_len ..];
            const destination = stream_count.ringIndex(self.total_output + stream_count.fromLocal(output.len - retained_len), self.history.len);
            const first_destination_len = @min(retained.len, self.history.len - destination);
            @memcpy(self.history[destination..][0..first_destination_len], retained[0..first_destination_len]);
            if (first_destination_len != retained.len)
                @memcpy(self.history[0 .. retained.len - first_destination_len], retained[first_destination_len..]);
            self.updatePreviousFromSpan(output);
            self.total_output = next_output;
        }
        fn beginCopy(self: *Self) Error!void {
            const remaining = self.decoded_len - self.total_output;
            const max_backward_distance = self.maxBackwardDistance();
            const target = shared_dictionary.classifyDistance(
                self.copy_distance,
                max_backward_distance,
                self.shared_dictionary_size,
            ) catch return self.fail(.copy, error.InvalidMatch);
            switch (target) {
                .history => |distance| {
                    // A caller may intentionally provide a history ring smaller
                    // than the protocol window. Such a reference is still a
                    // history match, not a compound-dictionary distance.
                    if (distance > self.history.len) return self.fail(.copy, error.InvalidMatch);
                    if (self.pending_copy > remaining) return self.fail(.copy, error.CorruptFrame);
                    if (self.update_distance_ring) pushLastDistance(&self.last_distances, distance);
                    self.update_distance_ring = false;
                    self.phase = .copy;
                },
                .compound => |address| {
                    const cursor = self.options.decode.shared_dictionary.cursor(address, self.pending_copy) catch |err| switch (err) {
                        error.CompoundDictionaryOutOfBounds, error.IntegerOverflow => return self.fail(.copy, error.InvalidMatch),
                        error.TooManyRawPrefixes, error.RawDictionaryTooLarge => return self.fail(.copy, error.CorruptFrame),
                    };
                    if (self.pending_copy > remaining) return self.fail(.copy, error.CorruptFrame);
                    if (self.update_distance_ring) pushLastDistance(&self.last_distances, self.copy_distance);
                    self.update_distance_ring = false;
                    self.compound_cursor = cursor;
                    self.dictionary_source = .compound;
                    self.phase = .dictionary;
                },
                .static_dictionary => |address| {
                    // Static words, including contextual serialized choices,
                    // never update the RFC recent-distance ring.
                    const context = try Codec.dictionaryContext(
                        &self.header,
                        self.previous[1],
                        self.previous[0],
                    );
                    const word = self.options.decode.shared_dictionary.staticWord(
                        context,
                        address,
                        self.pending_copy,
                        &self.dictionary_scratch,
                    ) catch |err| switch (err) {
                        error.IntegerOverflow => return self.fail(.dictionary, error.IntegerOverflow),
                        else => return self.fail(.dictionary, error.InvalidMatch),
                    };
                    if (word.len > remaining or word.len > self.dictionary_scratch.len) return self.fail(.dictionary, error.CorruptFrame);
                    if (word.ptr != self.dictionary_scratch[0..].ptr) @memcpy(self.dictionary_scratch[0..word.len], word);
                    self.update_distance_ring = false;
                    self.dictionary_offset = 0;
                    self.dictionary_len = word.len;
                    self.dictionary_source = .static;
                    self.phase = .dictionary;
                },
            }
        }
        fn maxBackwardDistance(self: *const Self) usize {
            return Codec.maxBackwardDistance(self.window_bits, self.total_output);
        }
        fn beginCompressedHeader(self: *Self) Error!void {
            const block_end = stream_count.addLocal(self.total_output, self.stored_remaining) catch
                return self.fail(.trailer, error.IntegerOverflow);
            if (self.final_meta_block) {
                if (self.options.expected_output_len) |expected|
                    if (block_end != expected) return self.fail(.trailer, error.SizeMismatch);
            }
            self.decoded_len = block_end;
            self.stored_remaining = 0;
            self.next_header_state = .is_last;

            // Normalize the already-prefetched low bits so the regular bounded
            // header parser can start at bit zero. Later caller bytes are packed
            // behind this prefix without retaining the original input slices.
            self.header_bit_count = self.staged_bit_count;
            self.header_len = (@as(usize, self.staged_bit_count) + 7) / 8;
            var bits = self.staged_bits;
            for (self.headerStorage()[0..self.header_len]) |*byte| {
                byte.* = @truncate(bits);
                bits >>= 8;
            }
            self.staged_bits = 0;
            self.staged_bit_count = 0;
            self.phase = .compressed_header;
        }
        fn appendHeaderByte(self: *Self, value: u8) Error!void {
            const storage = self.headerStorage();
            const byte_index = self.header_bit_count / 8;
            const bit_index: u3 = @intCast(self.header_bit_count % 8);
            if (byte_index >= storage.len or (bit_index != 0 and byte_index + 1 >= storage.len)) {
                // Storage exhaustion preserves the parser state for explicit
                // grow/retry. Other unsupported-feature errors remain fatal.
                self.header_storage_exhausted = true;
                return self.fail(.compressed_header, error.UnsupportedBrotliFeature);
            }
            if (bit_index == 0) {
                storage[byte_index] = value;
            } else {
                storage[byte_index] |= value << bit_index;
                storage[byte_index + 1] = value >> @intCast(8 - @as(usize, bit_index));
            }
            self.header_bit_count += 8;
            self.header_len = (self.header_bit_count + 7) / 8;
        }
        fn installCompressedHeader(self: *Self, parsed: Codec.ParsedHeader) Error!void {
            if (parsed.bits_read > self.header_bit_count) return self.fail(.compressed_header, error.CorruptFrame);
            const remaining = self.header_bit_count - parsed.bits_read;
            if (remaining > 127) return self.fail(.compressed_header, error.CorruptFrame);
            var staged: u128 = 0;
            const storage = self.headerStorage();
            for (0..remaining) |bit| {
                const source = parsed.bits_read + bit;
                const value = (storage[source / 8] >> @intCast(source % 8)) & 1;
                staged |= @as(u128, value) << @intCast(bit);
            }
            self.staged_bits = staged;
            self.staged_bit_count = @intCast(remaining);
            self.stream_bits +%= parsed.bits_read;
            self.header = parsed.header;
            self.header_len = 0;
            self.header_bit_count = 0;
            self.phase = .command;
        }
        fn headerStorage(self: *Self) []u8 {
            if (self.options.compressed_header_scratch.len > self.header_bytes.len)
                return self.options.compressed_header_scratch;
            return &self.header_bytes;
        }
        fn headerStorageConst(self: *const Self) []const u8 {
            if (self.options.compressed_header_scratch.len > self.header_bytes.len)
                return self.options.compressed_header_scratch;
            return &self.header_bytes;
        }
        fn pushLastDistance(last_distances: *[4]usize, distance: usize) void {
            last_distances[0] = last_distances[1];
            last_distances[1] = last_distances[2];
            last_distances[2] = last_distances[3];
            last_distances[3] = distance;
        }
        fn outputLimit(self: *const Self) Counter {
            return @min(self.options.max_output_len, self.options.max_total_output_len -| self.operation_output);
        }
        fn outputEnd(self: *Self, len: usize) Error!Counter {
            const end = stream_count.addLocal(self.total_output, len) catch
                return self.fail(self.phase, error.IntegerOverflow);
            _ = stream_count.add(self.operation_output, end) catch
                return self.fail(self.phase, error.IntegerOverflow);
            if (end > self.outputLimit()) return self.fail(self.phase, error.OutputLimitExceeded);
            return end;
        }
        fn publishFailure(self: *Self, err: Error) void {
            if (err != error.UnsupportedBrotliFeature or !self.header_storage_exhausted) {
                self.header_storage_exhausted = false;
                self.fatal_error = err;
            }
            if (self.last_error_name.len == 0) {
                self.last_error_name = @errorName(err);
                self.last_error_phase = self.phase;
            }
            self.error_input_offset = self.operation_input + self.total_input;
            self.error_output_offset = self.operation_output + self.total_output;
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
        fn recordMetadataBlock(self: *Self) Error!void {
            const count = stream_count.add(self.metadata_block_count, 1) catch
                return self.fail(self.phase, error.IntegerOverflow);
            if (self.metadata_block_count < self.metadata_block_lengths.len)
                self.metadata_block_lengths[@intCast(self.metadata_block_count)] = self.current_metadata_len;
            self.metadata_block_count = count;
            self.current_metadata_len = 0;
            self.metadata = false;
        }
        fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
            return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
        }
    };
}

test {
    _ = @import("copy_counter_tests.zig");
}
