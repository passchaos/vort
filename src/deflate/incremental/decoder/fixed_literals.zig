const std = @import("std");
const core = @import("../../../core.zig");
const huffman = @import("../../../huffman.zig");

pub const Format = struct {
    window_len: usize = 32 * 1024,
    distance_symbol_count: usize = 30,
    extended_length_285: bool = false,
};

pub const Decoder = DecoderWithFormat(.{});

/// Byte-progressive raw-DEFLATE/Deflate64 decoder.
/// Huffman code state survives arbitrary input splits; literals stream directly
/// to caller output. A caller-owned format-sized history ring backs length/distance
/// copies, including overlapping matches across arbitrary output boundaries.
pub fn DecoderWithFormat(comptime format: Format) type {
    return struct {
        const Self = @This();
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
        stored_lengths: [4]u8 = undefined,
        stored_length_received: usize = 0,
        stored_remaining: usize = 0,
        dynamic_hlit: usize = 0,
        dynamic_hdist: usize = 0,
        dynamic_hclen: usize = 0,
        dynamic_code_length_index: usize = 0,
        dynamic_code_lengths: [19]u4 = @splat(0),
        dynamic_code_lookup: [1 << 7]u16 = @splat(0),
        dynamic_literal_lengths: [286]u4 = @splat(0),
        dynamic_literal_lookup: [1 << 11]u16 = @splat(0),
        dynamic_distance_lengths: [format.distance_symbol_count]u4 = @splat(0),
        dynamic_distance_lookup: [1 << 10]u16 = @splat(0),
        /// Precomputed canonical tables for the long-code fallback. The
        /// incremental reader accumulates bits itself, so it scans the
        /// per-length entry groups directly instead of rebuilding canonical
        /// codes per miss.
        dynamic_literal_table: huffman.HuffmanTable(286) = .{},
        dynamic_distance_table: huffman.HuffmanTable(format.distance_symbol_count) = .{},
        dynamic_length_pos: usize = 0,
        dynamic_previous_length: u4 = 0,
        dynamic_repeat_symbol: u5 = 0,
        dynamic_code: u16 = 0,
        dynamic_code_bits: u4 = 0,
        dynamic_block: bool = false,
        input_finished: bool = false,
        total_input: usize = 0,
        total_output: usize = 0,
        last_error_name: []const u8 = "",
        last_error_phase: Phase = .block_header,

        pub const Error = core.Error;
        pub const required_history_len: usize = format.window_len;
        pub const Options = struct {
            max_output_len: usize = std.math.maxInt(usize),
            expected_output_len: ?usize = null,
            /// Stop at the first final block and leave any suffix unconsumed.
            /// Format wrappers use this to retain ownership of their footer.
            allow_trailing_data: bool = false,
            /// Return need_output at max_output_len, retaining a valid prefix
            /// even when its final stored chunk or match continues beyond it.
            stop_at_output_limit: bool = false,
            /// Optional surrounding-format distance cap within the history ring.
            max_distance: usize = format.window_len,
        };
        pub const Phase = enum { block_header, stored_lengths, stored_payload, dynamic_counts, dynamic_code_lengths, dynamic_lengths, dynamic_repeat, symbols, length_extra, distance_symbol, distance_extra, match_copy, done };

        pub fn init() Self {
            return initWithOptions(.{});
        }
        pub fn initWithHistory(options: Options, history: []u8) Error!Self {
            if (history.len < format.window_len) return error.OutputTooSmall;
            return .{ .options = options, .history = history[0..format.window_len] };
        }
        pub fn initWithDictionary(options: Options, history: []u8, dictionary: []const u8) Error!Self {
            var decoder = try initWithHistory(options, history);
            decoder.seedDictionary(dictionary);
            return decoder;
        }
        pub fn initWithOptions(options: Options) Self {
            return .{ .options = options };
        }
        pub fn reset(self: *Self) void {
            // Lookup tables are rebuilt before their next dynamic block is decoded.
            // Preserve their backing storage instead of clearing the largest part
            // of the reusable decoder on every independent stream.
            self.phase = .block_header;
            self.bit_buffer = 0;
            self.bit_count = 0;
            self.code = 0;
            self.code_bits = 0;
            self.final_block = false;
            self.history_pos = 0;
            self.history_len = 0;
            self.length_base = 0;
            self.length_extra_bits = 0;
            self.distance_code = 0;
            self.distance_code_bits = 0;
            self.match_len = 0;
            self.match_remaining = 0;
            self.match_distance = 0;
            self.stored_length_received = 0;
            self.stored_remaining = 0;
            self.dynamic_hlit = 0;
            self.dynamic_hdist = 0;
            self.dynamic_hclen = 0;
            self.dynamic_code_length_index = 0;
            self.dynamic_length_pos = 0;
            self.dynamic_previous_length = 0;
            self.dynamic_repeat_symbol = 0;
            self.dynamic_code = 0;
            self.dynamic_code_bits = 0;
            self.dynamic_block = false;
            self.input_finished = false;
            self.total_input = 0;
            self.total_output = 0;
            self.last_error_name = "";
            self.last_error_phase = .block_header;
        }
        /// Reset raw-DEFLATE block/history state after an external sync-marker
        /// scanner consumed `skipped_input` bytes. Cumulative input/output counters
        /// and output limits remain attached to this logical recovery session.
        pub fn resumeAfterSync(self: *Self, skipped_input: usize) Error!void {
            const resumed_input = std.math.add(usize, self.total_input, skipped_input) catch
                return error.IntegerOverflow;
            const produced = self.total_output;
            self.reset();
            self.total_input = resumed_input;
            self.total_output = produced;
        }
        pub fn seedDictionary(self: *Self, dictionary: []const u8) void {
            if (self.history.len == 0) return;
            const keep = @min(dictionary.len, self.history.len);
            const source = dictionary[dictionary.len - keep ..];
            @memcpy(self.history[0..keep], source);
            self.history_len = keep;
            self.history_pos = if (keep == self.history.len) 0 else keep;
        }
        pub fn diagnostics(self: *const Self) core.StreamingDiagnostics {
            return .{
                .phase_name = @tagName(self.phase),
                .frame_input_read = self.total_input,
                .output_written = self.total_output,
                .expected_output_len = core.stream_count.fromOptionalLocal(self.options.expected_output_len),
                .last_error_name = self.last_error_name,
                .last_error_phase_name = if (self.last_error_name.len == 0) "" else @tagName(self.last_error_phase),
                .recoverability_hint_name = if (std.mem.eql(u8, self.last_error_name, @errorName(error.TruncatedFrame))) "truncated_input" else if (std.mem.eql(u8, self.last_error_name, @errorName(error.UnsupportedDeflateFeature))) "unsupported_feature" else if (self.last_error_name.len == 0) "none" else "payload_corrupt",
            };
        }
        pub fn finish(self: *Self) Error!void {
            self.input_finished = true;
            if (self.phase != .done) return self.fail(self.phase, error.TruncatedFrame);
        }

        pub fn step(self: *Self, input: []const u8, provided_output: []u8) Error!core.StepResult {
            const output = if (self.options.stop_at_output_limit)
                provided_output[0..@min(provided_output.len, self.options.max_output_len -| self.total_output)]
            else
                provided_output;
            if (self.input_finished) {
                if (input.len != 0 and !self.options.allow_trailing_data)
                    return self.fail(self.phase, error.TrailingData);
                return .{ .status = if (self.phase == .done) .done else .need_input };
            }
            var input_read: usize = 0;
            var output_written: usize = 0;
            while (!self.options.stop_at_output_limit or self.total_output < self.options.max_output_len) switch (self.phase) {
                .block_header => {
                    const header = self.readBits(input, &input_read, 3) orelse return result(input_read, output_written, .need_input);
                    self.final_block = (header & 1) != 0;
                    const block_type = (header >> 1) & 0x3;
                    switch (block_type) {
                        0 => {
                            self.alignStoredHeader();
                            self.phase = .stored_lengths;
                        },
                        1 => {
                            self.dynamic_block = false;
                            self.phase = .symbols;
                        },
                        2 => {
                            self.dynamic_block = true;
                            self.phase = .dynamic_counts;
                        },
                        else => return self.fail(.block_header, error.InvalidDeflateBlockType),
                    }
                },
                .stored_lengths => {
                    while (self.stored_length_received < self.stored_lengths.len) {
                        const byte = self.readBits(input, &input_read, 8) orelse return result(input_read, output_written, .need_input);
                        self.stored_lengths[self.stored_length_received] = @intCast(byte);
                        self.stored_length_received += 1;
                    }
                    const len = std.mem.readInt(u16, self.stored_lengths[0..2], .little);
                    const nlen = std.mem.readInt(u16, self.stored_lengths[2..4], .little);
                    if (nlen != ~len) return self.fail(.stored_lengths, error.StoredLengthMismatch);
                    if (!self.options.stop_at_output_limit and (self.total_output > self.options.max_output_len or len > self.options.max_output_len - self.total_output)) return self.fail(.stored_lengths, error.OutputLimitExceeded);
                    if (self.options.expected_output_len) |expected| {
                        if (self.total_output > expected or len > expected - self.total_output) return self.fail(.stored_lengths, error.SizeMismatch);
                    }
                    self.stored_remaining = len;
                    self.stored_length_received = 0;
                    self.phase = .stored_payload;
                    if (self.stored_remaining == 0) self.completeBlock();
                },
                .stored_payload => {
                    if (output_written == output.len) return result(input_read, output_written, .need_output);
                    if (input_read == input.len and self.bit_count == 0) return result(input_read, output_written, .need_input);
                    while (self.stored_remaining != 0 and
                        output_written < output.len and
                        self.bit_count >= 8)
                    {
                        const byte = self.readBits(input, &input_read, 8) orelse return result(input_read, output_written, .need_input);
                        output[output_written] = @intCast(byte);
                        output_written += 1;
                        try self.recordByte(@intCast(byte));
                        self.stored_remaining -= 1;
                    }
                    if (self.stored_remaining != 0 and
                        output_written < output.len and
                        self.bit_count == 0)
                    {
                        const n = @min(
                            self.stored_remaining,
                            @min(input.len - input_read, output.len - output_written),
                        );
                        if (n != 0) {
                            const produced = output[output_written..][0..n];
                            @memcpy(produced, input[input_read..][0..n]);
                            self.recordSpan(produced);
                            input_read += n;
                            self.total_input += n;
                            output_written += n;
                            self.stored_remaining -= n;
                        }
                    }
                    if (self.stored_remaining == 0) self.completeBlock();
                },
                .dynamic_counts => {
                    const counts = self.readBits(input, &input_read, 14) orelse return result(input_read, output_written, .need_input);
                    self.dynamic_hlit = (counts & 0x1f) + 257;
                    self.dynamic_hdist = ((counts >> 5) & 0x1f) + 1;
                    self.dynamic_hclen = ((counts >> 10) & 0x0f) + 4;
                    if (self.dynamic_hlit > 286 or self.dynamic_hdist > format.distance_symbol_count) return self.fail(.dynamic_counts, error.InvalidDynamicBlockHeader);
                    self.dynamic_code_lengths = @splat(0);
                    self.dynamic_code_length_index = 0;
                    self.phase = .dynamic_code_lengths;
                },
                .dynamic_code_lengths => {
                    while (self.dynamic_code_length_index < self.dynamic_hclen) {
                        const length = self.readBits(input, &input_read, 3) orelse return result(input_read, output_written, .need_input);
                        self.dynamic_code_lengths[code_length_order[self.dynamic_code_length_index]] = @intCast(length);
                        self.dynamic_code_length_index += 1;
                    }
                    if (!validCodeLengthAlphabet(self.dynamic_code_lengths)) return self.fail(.dynamic_code_lengths, error.InvalidDynamicBlockHeader);
                    buildCanonicalLookup(7, &self.dynamic_code_lookup, &self.dynamic_code_lengths);
                    self.dynamic_literal_lengths = @splat(0);
                    self.dynamic_distance_lengths = @splat(0);
                    self.dynamic_length_pos = 0;
                    self.dynamic_previous_length = 0;
                    self.phase = .dynamic_lengths;
                },
                .dynamic_lengths => {
                    const total = self.dynamic_hlit + self.dynamic_hdist;
                    if (self.dynamic_length_pos == total) {
                        if (self.dynamic_literal_lengths[256] == 0) return self.fail(.dynamic_lengths, error.InvalidDynamicBlockHeader);
                        if (!validDynamicAlphabet(self.dynamic_literal_lengths[0..self.dynamic_hlit]) or
                            !validDynamicAlphabet(self.dynamic_distance_lengths[0..self.dynamic_hdist]))
                            return self.fail(.dynamic_lengths, error.InvalidDynamicBlockHeader);
                        buildCanonicalLookup(11, &self.dynamic_literal_lookup, self.dynamic_literal_lengths[0..self.dynamic_hlit]);
                        buildCanonicalLookup(10, &self.dynamic_distance_lookup, self.dynamic_distance_lengths[0..self.dynamic_hdist]);
                        self.dynamic_literal_table = huffman.HuffmanTable(286).init(self.dynamic_literal_lengths[0..self.dynamic_hlit]) catch |err| return self.fail(.dynamic_lengths, err);
                        self.dynamic_distance_table = huffman.HuffmanTable(format.distance_symbol_count).init(self.dynamic_distance_lengths[0..self.dynamic_hdist]) catch |err| return self.fail(.dynamic_lengths, err);
                        self.phase = .symbols;
                        continue;
                    }
                    const symbol = (try self.readCodeLengthSymbol(input, &input_read)) orelse return result(input_read, output_written, .need_input);
                    switch (symbol) {
                        0...15 => {
                            self.setDynamicLength(@intCast(symbol));
                            self.dynamic_previous_length = @intCast(symbol);
                            self.dynamic_length_pos += 1;
                        },
                        16...18 => {
                            if (symbol == 16 and self.dynamic_length_pos == 0) return self.fail(.dynamic_lengths, error.InvalidDynamicBlockHeader);
                            self.dynamic_repeat_symbol = @intCast(symbol);
                            self.phase = .dynamic_repeat;
                        },
                        else => return self.fail(.dynamic_lengths, error.InvalidDynamicBlockHeader),
                    }
                },
                .dynamic_repeat => {
                    const extra_bits: u6 = switch (self.dynamic_repeat_symbol) {
                        16 => 2,
                        17 => 3,
                        18 => 7,
                        else => unreachable,
                    };
                    const extra = self.readBits(input, &input_read, extra_bits) orelse return result(input_read, output_written, .need_input);
                    const repeat_base: usize = switch (self.dynamic_repeat_symbol) {
                        16, 17 => 3,
                        18 => 11,
                        else => unreachable,
                    };
                    const count: usize = extra + repeat_base;
                    const total = self.dynamic_hlit + self.dynamic_hdist;
                    if (count > total - self.dynamic_length_pos) return self.fail(.dynamic_repeat, error.InvalidDynamicBlockHeader);
                    const value: u4 = if (self.dynamic_repeat_symbol == 16) self.dynamic_previous_length else 0;
                    for (0..count) |_| {
                        self.setDynamicLength(value);
                        self.dynamic_length_pos += 1;
                    }
                    self.dynamic_previous_length = value;
                    self.phase = .dynamic_lengths;
                },
                .symbols => {
                    switch (try self.decodeSymbolRun(input, output, &input_read, &output_written)) {
                        .need_input => return result(input_read, output_written, .need_input),
                        .need_output => return result(input_read, output_written, .need_output),
                        .block_end, .done => continue,
                    }
                },
                .length_extra => {
                    const extra = self.readBits(input, &input_read, self.length_extra_bits) orelse return result(input_read, output_written, .need_input);
                    self.match_len = self.length_base + extra;
                    self.phase = .distance_symbol;
                },
                .distance_symbol => {
                    if (self.match_len == 0) self.match_len = self.length_base;
                    const symbol = (try self.readDistanceSymbol(input, &input_read)) orelse return result(input_read, output_written, .need_input);
                    const distance = distanceBaseAndBitsForFormat(format, symbol) orelse return self.fail(.distance_symbol, error.InvalidHuffmanCode);
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
                    // A previous call may have filled the caller's output exactly
                    // while copying the final match byte. Advance to the symbol
                    // phase before checking output space so a zero-length drain can
                    // still consume an already-buffered EOB.
                    if (self.match_remaining == 0) {
                        self.match_len = 0;
                        self.phase = .symbols;
                        continue;
                    }
                    if (output_written == output.len) return result(input_read, output_written, .need_output);
                    const n = @min(self.match_remaining, output.len - output_written);
                    self.copyMatchSpan(output[output_written..][0..n]);
                    output_written += n;
                    self.match_remaining -= n;
                    if (self.match_remaining == 0) {
                        self.match_len = 0;
                        self.phase = .symbols;
                    }
                },
                .done => {
                    // A partial final byte belongs to the stream as padding; bytes
                    // staged by the same input call have already been accounted for.
                    if (input_read != input.len and !self.options.allow_trailing_data)
                        return self.fail(.done, error.TrailingData);
                    return result(input_read, output_written, .done);
                },
            };
            return result(input_read, output_written, .need_output);
        }

        const RunStatus = enum { need_input, need_output, block_end, done };

        /// Decode a run of dynamic/fixed-block symbols with the bit reservoir,
        /// partial-code state and cursors held in locals. The resumable phase
        /// cases above still own every pause (input exhaustion, output full,
        /// partial match copy); this loop only runs while both input and output
        /// can make progress, and writes all shared state back on return.
        fn decodeSymbolRun(
            self: *Self,
            input: []const u8,
            output: []u8,
            input_read: *usize,
            output_written: *usize,
        ) Error!RunStatus {
            var bit_buffer = self.bit_buffer;
            var bit_count = self.bit_count;
            var code = self.code;
            var code_bits = self.code_bits;
            var dynamic_code = self.dynamic_code;
            var dynamic_code_bits = self.dynamic_code_bits;
            var distance_code = self.distance_code;
            var distance_code_bits = self.distance_code_bits;
            const start_input = input_read.*;
            defer {
                self.bit_buffer = bit_buffer;
                self.bit_count = bit_count;
                self.code = code;
                self.code_bits = code_bits;
                self.dynamic_code = dynamic_code;
                self.dynamic_code_bits = dynamic_code_bits;
                self.distance_code = distance_code;
                self.distance_code_bits = distance_code_bits;
                self.total_input += input_read.* - start_input;
            }

            while (true) {
                if (output_written.* == output.len and output.len != 0) return .need_output;
                const symbol = (try self.readLiteralSymbolRun(
                    input,
                    input_read,
                    &bit_buffer,
                    &bit_count,
                    &code,
                    &code_bits,
                )) orelse return .need_input;
                if (symbol < 256) {
                    if (output_written.* == output.len) {
                        // A decoded literal cannot be committed without caller
                        // space. Preserve it as a one-symbol continuation.
                        code = @intCast(symbol);
                        code_bits = 15;
                        return .need_output;
                    }
                    if (self.total_output >= self.options.max_output_len) return self.fail(.symbols, error.OutputLimitExceeded);
                    if (self.options.expected_output_len) |expected| {
                        if (self.total_output >= expected) return self.fail(.symbols, error.SizeMismatch);
                    }
                    output[output_written.*] = @intCast(symbol);
                    output_written.* += 1;
                    try self.recordByte(@intCast(symbol));
                    continue;
                }
                if (symbol == 256) {
                    self.phase = if (self.final_block) .done else .block_header;
                    if (self.phase == .done) {
                        if (self.options.expected_output_len) |expected| {
                            if (self.total_output != expected) return self.fail(.done, error.SizeMismatch);
                        }
                        return .done;
                    }
                    return .block_end;
                }
                const length = lengthBaseAndBitsForFormat(format, symbol) orelse return self.fail(.symbols, error.InvalidHuffmanCode);
                self.length_base = length.base;
                self.length_extra_bits = length.bits;
                self.match_len = length.base;
                if (length.bits != 0) {
                    const extra = readBitsLocal(input, input_read, &bit_buffer, &bit_count, length.bits) orelse {
                        self.phase = .length_extra;
                        return .need_input;
                    };
                    self.match_len = length.base + extra;
                }
                const distance_symbol = (try self.readDistanceSymbolRun(
                    input,
                    input_read,
                    &bit_buffer,
                    &bit_count,
                    &dynamic_code,
                    &dynamic_code_bits,
                    &distance_code,
                    &distance_code_bits,
                )) orelse {
                    self.phase = .distance_symbol;
                    return .need_input;
                };
                const distance = distanceBaseAndBitsForFormat(format, distance_symbol) orelse return self.fail(.distance_symbol, error.InvalidHuffmanCode);
                self.match_distance = distance.base;
                self.length_extra_bits = distance.bits;
                if (distance.bits != 0) {
                    const extra = readBitsLocal(input, input_read, &bit_buffer, &bit_count, distance.bits) orelse {
                        self.phase = .distance_extra;
                        return .need_input;
                    };
                    self.match_distance += extra;
                }
                try self.beginMatch();
                self.phase = .match_copy;
                if (output_written.* == output.len) return .need_output;
                const n = @min(self.match_remaining, output.len - output_written.*);
                self.copyMatchSpan(output[output_written.*..][0..n]);
                output_written.* += n;
                self.match_remaining -= n;
                if (self.match_remaining != 0) return .need_output;
                self.match_len = 0;
                self.phase = .symbols;
            }
        }

        fn readLiteralSymbolRun(
            self: *Self,
            input: []const u8,
            input_read: *usize,
            bit_buffer: *u64,
            bit_count: *u6,
            code: *u16,
            code_bits: *u4,
        ) Error!?u16 {
            if (code_bits.* == 15) {
                const symbol = code.*;
                code.* = 0;
                code_bits.* = 0;
                return symbol;
            }
            if (!self.dynamic_block) {
                return lookupSymbolLocal(input, input_read, 9, &fixed_lookup, bit_buffer, bit_count);
            }
            if (code_bits.* == 0) {
                if (lookupSymbolLocal(input, input_read, 11, &self.dynamic_literal_lookup, bit_buffer, bit_count)) |symbol|
                    return symbol;
                if (bit_count.* < 11 and input_read.* == input.len) return null;
            }
            while (code_bits.* < 15) {
                const bit = readBitsLocal(input, input_read, bit_buffer, bit_count, 1) orelse return null;
                code.* |= @as(u16, @intCast(bit)) << code_bits.*;
                code_bits.* += 1;
                if (tableSymbol(286, &self.dynamic_literal_table, code.*, code_bits.*)) |symbol| {
                    code.* = 0;
                    code_bits.* = 0;
                    return symbol;
                }
            }
            return self.fail(.symbols, error.InvalidHuffmanCode);
        }

        fn readDistanceSymbolRun(
            self: *Self,
            input: []const u8,
            input_read: *usize,
            bit_buffer: *u64,
            bit_count: *u6,
            dynamic_code: *u16,
            dynamic_code_bits: *u4,
            distance_code: *u16,
            distance_code_bits: *u3,
        ) Error!?usize {
            if (!self.dynamic_block) {
                while (distance_code_bits.* < 5) {
                    const bit = readBitsLocal(input, input_read, bit_buffer, bit_count, 1) orelse return null;
                    distance_code.* |= @as(u16, @intCast(bit)) << distance_code_bits.*;
                    distance_code_bits.* += 1;
                }
                const symbol: usize = @bitReverse(@as(u5, @truncate(distance_code.*)));
                distance_code.* = 0;
                distance_code_bits.* = 0;
                return symbol;
            }
            if (dynamic_code_bits.* == 0) {
                if (lookupSymbolLocal(input, input_read, 10, &self.dynamic_distance_lookup, bit_buffer, bit_count)) |symbol|
                    return symbol;
                if (bit_count.* < 10 and input_read.* == input.len) return null;
            }
            while (dynamic_code_bits.* < 15) {
                const bit = readBitsLocal(input, input_read, bit_buffer, bit_count, 1) orelse return null;
                dynamic_code.* |= @as(u16, @intCast(bit)) << dynamic_code_bits.*;
                dynamic_code_bits.* += 1;
                if (tableSymbol(format.distance_symbol_count, &self.dynamic_distance_table, dynamic_code.*, dynamic_code_bits.*)) |symbol| {
                    dynamic_code.* = 0;
                    dynamic_code_bits.* = 0;
                    return symbol;
                }
            }
            return self.fail(.distance_symbol, error.InvalidHuffmanCode);
        }

        fn readFixedSymbol(self: *Self, input: []const u8, input_read: *usize) Error!?u16 {
            if (self.code_bits == 15) {
                const symbol = self.code;
                self.code = 0;
                self.code_bits = 0;
                return symbol;
            }
            return self.readLookupSymbol(input, input_read, 9, &fixed_lookup);
        }
        fn readLiteralSymbol(self: *Self, input: []const u8, input_read: *usize) Error!?u16 {
            if (!self.dynamic_block) return self.readFixedSymbol(input, input_read);
            if (self.code_bits == 15) {
                const symbol = self.code;
                self.code = 0;
                self.code_bits = 0;
                return symbol;
            }
            if (self.code_bits == 0) {
                if (self.readLookupSymbol(input, input_read, 11, &self.dynamic_literal_lookup)) |symbol|
                    return symbol;
                if (self.bit_count < 11 and input_read.* == input.len) return null;
            }
            while (self.code_bits < 15) {
                const bit = self.readBits(input, input_read, 1) orelse return null;
                self.code |= @as(u16, @intCast(bit)) << self.code_bits;
                self.code_bits += 1;
                if (tableSymbol(286, &self.dynamic_literal_table, self.code, self.code_bits)) |symbol| {
                    self.code = 0;
                    self.code_bits = 0;
                    return symbol;
                }
            }
            return self.fail(.symbols, error.InvalidHuffmanCode);
        }
        fn beginMatch(self: *Self) Error!void {
            if (self.history.len == 0) return self.fail(.match_copy, error.OutputTooSmall);
            if (self.match_distance == 0 or self.match_distance > self.history_len) return self.fail(.match_copy, error.InvalidMatch);
            if (self.match_distance > self.options.max_distance) return self.fail(.match_copy, error.InvalidMatch);
            if (!self.options.stop_at_output_limit and (self.total_output > self.options.max_output_len or self.match_len > self.options.max_output_len - self.total_output)) return self.fail(.match_copy, error.OutputLimitExceeded);
            if (self.options.expected_output_len) |expected| {
                if (self.total_output > expected or self.match_len > expected - self.total_output) return self.fail(.match_copy, error.SizeMismatch);
            }
            self.match_remaining = self.match_len;
        }
        fn alignStoredHeader(self: *Self) void {
            const drop: u6 = self.bit_count % 8;
            self.bit_buffer >>= drop;
            self.bit_count -= drop;
        }
        fn completeBlock(self: *Self) void {
            self.phase = if (self.final_block) .done else .block_header;
        }
        fn readFixedDistanceSymbol(self: *Self, input: []const u8, input_read: *usize) ?usize {
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
        fn readDistanceSymbol(self: *Self, input: []const u8, input_read: *usize) Error!?usize {
            if (!self.dynamic_block) return self.readFixedDistanceSymbol(input, input_read);
            if (self.dynamic_code_bits == 0) {
                if (self.readLookupSymbol(input, input_read, 10, &self.dynamic_distance_lookup)) |symbol|
                    return symbol;
                if (self.bit_count < 10 and input_read.* == input.len) return null;
            }
            while (self.dynamic_code_bits < 15) {
                const bit = self.readBits(input, input_read, 1) orelse return null;
                self.dynamic_code |= @as(u16, @intCast(bit)) << self.dynamic_code_bits;
                self.dynamic_code_bits += 1;
                if (tableSymbol(format.distance_symbol_count, &self.dynamic_distance_table, self.dynamic_code, self.dynamic_code_bits)) |symbol| {
                    self.dynamic_code = 0;
                    self.dynamic_code_bits = 0;
                    return symbol;
                }
            }
            return self.fail(.distance_symbol, error.InvalidHuffmanCode);
        }
        fn readCodeLengthSymbol(self: *Self, input: []const u8, input_read: *usize) Error!?u16 {
            if (self.dynamic_code_bits == 0) {
                if (self.readLookupSymbol(input, input_read, 7, &self.dynamic_code_lookup)) |symbol|
                    return symbol;
                if (self.bit_count < 7 and input_read.* == input.len) return null;
            }
            while (self.dynamic_code_bits < 7) {
                const bit = self.readBits(input, input_read, 1) orelse return null;
                self.dynamic_code |= @as(u16, @intCast(bit)) << self.dynamic_code_bits;
                self.dynamic_code_bits += 1;
                if (canonicalSymbol(self.dynamic_code_lengths[0..], self.dynamic_code, self.dynamic_code_bits)) |symbol| {
                    self.dynamic_code = 0;
                    self.dynamic_code_bits = 0;
                    return symbol;
                }
            }
            return self.fail(.dynamic_lengths, error.InvalidHuffmanCode);
        }
        fn readLookupSymbol(
            self: *Self,
            input: []const u8,
            input_read: *usize,
            comptime lookup_bits: u6,
            lookup: *const [@as(usize, 1) << lookup_bits]u16,
        ) ?u16 {
            const mask = (@as(u64, 1) << lookup_bits) - 1;
            while (true) {
                const lookup_entry = lookup[@intCast(self.bit_buffer & mask)];
                if (lookup_entry != 0) {
                    const bits: u6 = @intCast(lookup_entry & 0x0f);
                    if (self.bit_count >= bits) {
                        self.bit_buffer >>= bits;
                        self.bit_count -= bits;
                        return (lookup_entry >> 4) - 1;
                    }
                }
                if (self.bit_count >= lookup_bits or input_read.* == input.len)
                    return null;
                self.bit_buffer |= @as(u64, input[input_read.*]) << self.bit_count;
                self.bit_count += 8;
                input_read.* += 1;
                self.total_input += 1;
            }
        }
        fn setDynamicLength(self: *Self, value: u4) void {
            if (self.dynamic_length_pos < self.dynamic_hlit) {
                self.dynamic_literal_lengths[self.dynamic_length_pos] = value;
            } else {
                self.dynamic_distance_lengths[self.dynamic_length_pos - self.dynamic_hlit] = value;
            }
        }
        fn recordByte(self: *Self, byte: u8) Error!void {
            if (self.history.len != 0) {
                self.history[self.history_pos] = byte;
                // `history_pos` is always below `history.len`, so advancing by
                // one needs at most a single wrap instead of a modulo.
                const next = self.history_pos + 1;
                self.history_pos = if (next == self.history.len) 0 else next;
                self.history_len = @min(self.history_len + 1, self.history.len);
            }
            self.total_output += 1;
        }

        inline fn copyMatchSpan(self: *Self, output: []u8) void {
            std.debug.assert(output.len != 0);
            std.debug.assert(self.match_distance != 0);
            std.debug.assert(self.match_distance <= self.history_len);

            const seed_len = @min(output.len, self.match_distance);
            // `match_distance <= history_len <= history.len` and
            // `history_pos < history.len`, so the sum stays below two
            // window lengths and needs at most one wrap correction.
            var source = self.history_pos + self.history.len - self.match_distance;
            if (source >= self.history.len) source -= self.history.len;
            if (self.match_distance == 1) {
                @memset(output, self.history[source]);
            } else {
                const first_source_len = @min(seed_len, self.history.len - source);
                @memcpy(output[0..first_source_len], self.history[source..][0..first_source_len]);
                if (first_source_len != seed_len)
                    @memcpy(output[first_source_len..seed_len], self.history[0 .. seed_len - first_source_len]);

                var produced = seed_len;
                while (produced < output.len) {
                    const n = @min(produced, output.len - produced);
                    std.mem.copyForwards(u8, output[produced..][0..n], output[0..n]);
                    produced += n;
                }
            }

            self.recordSpan(output);
        }

        fn recordSpan(self: *Self, bytes: []const u8) void {
            std.debug.assert(bytes.len != 0);
            if (self.history.len == 0) {
                self.total_output += bytes.len;
                return;
            }
            if (bytes.len <= self.history.len) {
                // Fast path for match spans and small stored chunks: everything
                // fits in one ring revolution, so the destination is the
                // current write position and the advance needs one wrap check.
                const destination = self.history_pos;
                const first_destination_len = @min(bytes.len, self.history.len - destination);
                @memcpy(self.history[destination..][0..first_destination_len], bytes[0..first_destination_len]);
                if (first_destination_len != bytes.len)
                    @memcpy(self.history[0 .. bytes.len - first_destination_len], bytes[first_destination_len..]);
                const next = destination + bytes.len;
                self.history_pos = if (next >= self.history.len) next - self.history.len else next;
                self.history_len = @min(self.history_len + bytes.len, self.history.len);
                self.total_output += bytes.len;
                return;
            }
            const retained_len = self.history.len;
            const retained = bytes[bytes.len - retained_len ..];
            const destination = (self.history_pos + bytes.len - retained_len) % self.history.len;
            const first_destination_len = @min(retained.len, self.history.len - destination);
            @memcpy(self.history[destination..][0..first_destination_len], retained[0..first_destination_len]);
            if (first_destination_len != retained.len)
                @memcpy(self.history[0 .. retained.len - first_destination_len], retained[first_destination_len..]);
            self.history_pos = (self.history_pos + bytes.len) % self.history.len;
            self.history_len = self.history.len;
            self.total_output += bytes.len;
        }

        fn readBits(self: *Self, input: []const u8, input_read: *usize, count: u6) ?usize {
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
        fn fail(self: *Self, phase: Phase, err: Error) Error {
            self.last_error_name = @errorName(err);
            self.last_error_phase = phase;
            return err;
        }
        fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
            return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
        }
    };
}

const fixed_table = blk: {
    @setEvalBranchQuota(20_000);
    break :blk buildFixedTable(fixedLengths());
};

const fixed_lookup = blk: {
    var lookup: [1 << 9]u16 = @splat(0);
    for (fixed_table) |entry| {
        const lookup_entry = ((entry.symbol + 1) << 4) | entry.bits;
        const fill = @as(usize, 1) << @intCast(9 - entry.bits);
        for (0..fill) |suffix|
            lookup[entry.code | (suffix << entry.bits)] = lookup_entry;
    }
    break :blk lookup;
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

fn buildCanonicalLookup(
    comptime lookup_bits: u4,
    lookup: *[@as(usize, 1) << lookup_bits]u16,
    lengths: []const u4,
) void {
    @memset(lookup, 0);
    var counts: [16]u16 = @splat(0);
    for (lengths) |bits| if (bits != 0) {
        counts[bits] += 1;
    };
    var next: [16]u16 = @splat(0);
    var code: u16 = 0;
    for (1..16) |bits| {
        code = (code + counts[bits - 1]) << 1;
        next[bits] = code;
    }
    for (lengths, 0..) |bits, symbol| {
        if (bits == 0) continue;
        const canonical = next[bits];
        next[bits] += 1;
        if (bits > lookup_bits) continue;
        const shift: u4 = @intCast(@as(u5, 16) - @as(u5, bits));
        const reversed = @bitReverse(canonical) >> shift;
        const lookup_entry: u16 = ((@as(u16, @intCast(symbol)) + 1) << 4) | bits;
        const fill = @as(usize, 1) << @intCast(lookup_bits - bits);
        for (0..fill) |suffix|
            lookup[reversed | (suffix << bits)] = lookup_entry;
    }
}

const BaseBits = struct { base: usize, bits: u6 };

fn lengthBaseAndBitsForFormat(comptime format: Format, symbol: u16) ?BaseBits {
    if (symbol < 257 or symbol > 285) return null;
    if (symbol <= 264) return .{ .base = symbol - 254, .bits = 0 };
    if (symbol == 285) return if (format.extended_length_285)
        .{ .base = 3, .bits = 16 }
    else
        .{ .base = 258, .bits = 0 };
    const bases = [_]usize{ 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227 };
    const bits = [_]u6{ 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5 };
    const index: usize = symbol - 265;
    return .{ .base = bases[index], .bits = bits[index] };
}

fn distanceBaseAndBitsForFormat(comptime format: Format, symbol: usize) ?BaseBits {
    if (symbol >= format.distance_symbol_count) return null;
    if (symbol < 4) return .{ .base = symbol + 1, .bits = 0 };
    const extra_bits: u6 = @intCast(symbol / 2 - 1);
    const base = ((@as(usize, 2) + (symbol & 1)) << @intCast(extra_bits)) + 1;
    return .{ .base = base, .bits = extra_bits };
}

const code_length_order = [_]u8{ 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 };

fn validCodeLengthAlphabet(lengths: [19]u4) bool {
    var counts: [8]usize = @splat(0);
    var active: usize = 0;
    for (lengths) |length| {
        if (length > 7) return false;
        if (length != 0) {
            counts[length] += 1;
            active += 1;
        }
    }
    if (active == 0) return false;
    var available: isize = 1;
    for (1..8) |bits| {
        available = available * 2 - @as(isize, @intCast(counts[bits]));
        if (available < 0) return false;
    }
    return true;
}

fn validDynamicAlphabet(lengths: []const u4) bool {
    var counts: [16]usize = @splat(0);
    var active: usize = 0;
    for (lengths) |length| {
        if (length > 15) return false;
        if (length != 0) {
            counts[length] += 1;
            active += 1;
        }
    }
    if (active == 0) return false;
    if (active == 1) return true; // RFC permits one-bit incomplete singleton.
    var available: isize = 1;
    for (1..16) |bits| {
        available = available * 2 - @as(isize, @intCast(counts[bits]));
        if (available < 0) return false;
    }
    return available == 0;
}

/// Scan the precomputed canonical entries at one code width. Entries are
/// grouped by width, so this touches only the symbols that can match.
inline fn tableSymbol(
    comptime max_symbols: usize,
    table: *const huffman.HuffmanTable(max_symbols),
    wanted_code: u16,
    wanted_bits: u4,
) ?u16 {
    const first = table.first_by_bits[wanted_bits];
    const end = first + table.count_by_bits[wanted_bits];
    var index: usize = first;
    while (index < end) : (index += 1) {
        const entry = table.entries[index];
        if (entry.code == wanted_code) return entry.symbol;
    }
    return null;
}

/// Local-reservoir bit read used by the fused symbol loop. The caller keeps
/// the reservoir in registers and only writes it back at pause boundaries.
inline fn readBitsLocal(
    input: []const u8,
    input_read: *usize,
    bit_buffer: *u64,
    bit_count: *u6,
    count: u6,
) ?usize {
    while (bit_count.* < count) {
        if (input_read.* == input.len) return null;
        bit_buffer.* |= @as(u64, input[input_read.*]) << bit_count.*;
        bit_count.* += 8;
        input_read.* += 1;
    }
    const mask = (@as(u64, 1) << count) - 1;
    const value = bit_buffer.* & mask;
    bit_buffer.* >>= count;
    bit_count.* -= count;
    return @intCast(value);
}

/// Local-reservoir variant of `readLookupSymbol`.
inline fn lookupSymbolLocal(
    input: []const u8,
    input_read: *usize,
    comptime lookup_bits: u6,
    lookup: *const [@as(usize, 1) << lookup_bits]u16,
    bit_buffer: *u64,
    bit_count: *u6,
) ?u16 {
    const mask = (@as(u64, 1) << lookup_bits) - 1;
    while (true) {
        const lookup_entry = lookup[@intCast(bit_buffer.* & mask)];
        if (lookup_entry != 0) {
            const bits: u6 = @intCast(lookup_entry & 0x0f);
            if (bit_count.* >= bits) {
                bit_buffer.* >>= bits;
                bit_count.* -= bits;
                return (lookup_entry >> 4) - 1;
            }
        }
        if (bit_count.* >= lookup_bits or input_read.* == input.len) return null;
        bit_buffer.* |= @as(u64, input[input_read.*]) << bit_count.*;
        bit_count.* += 8;
        input_read.* += 1;
    }
}

fn canonicalSymbol(lengths: []const u4, wanted_code: u16, wanted_bits: u4) ?u16 {
    var counts: [16]u16 = @splat(0);
    for (lengths) |length| if (length != 0) {
        counts[length] += 1;
    };
    var next: [16]u16 = @splat(0);
    var code: u16 = 0;
    for (1..16) |bits| {
        code = (code + counts[bits - 1]) << 1;
        next[bits] = code;
    }
    for (lengths, 0..) |bits, symbol| {
        if (bits == 0) continue;
        const shift: u4 = @intCast(@as(u5, 16) - @as(u5, bits));
        const reversed = @bitReverse(next[bits]) >> shift;
        next[bits] += 1;
        if (bits == wanted_bits and reversed == wanted_code) return @intCast(symbol);
    }
    return null;
}
