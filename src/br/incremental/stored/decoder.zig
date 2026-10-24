const std = @import("std");
const core = @import("../../../core.zig");

/// Byte-progressive decoder for the Brotli stored/uncompressed subset emitted
/// by Vort. Only a bounded header prefix is retained; aligned meta-block bytes
/// stream directly from caller input to caller output. Metadata is skipped
/// without buffering. Compressed meta-blocks return UnsupportedBrotliFeature so
/// callers can choose the general incremental facade instead.
pub const Decoder = struct {
    options: Options,
    phase: Phase = .window,
    window_state: WindowState = .first,
    header_state: HeaderState = .is_last,
    length_width: u6 = 0,
    staged: u64 = 0,
    staged_bits: u6 = 0,
    payload_remaining: usize = 0,
    metadata: bool = false,
    total_input: Counter = 0,
    total_output: Counter = 0,
    stream_input: Counter = 0,
    stream_output: Counter = 0,
    stream_count: Counter = 0,
    metadata_output: []u8 = &.{},
    metadata_written: usize = 0,
    metadata_total: Counter = 0,
    metadata_block_lengths: []usize = &.{},
    metadata_block_count: Counter = 0,
    current_metadata_len: usize = 0,
    finished: bool = false,
    last_error_name: []const u8 = "",
    last_error_phase: Phase = .window,
    error_input_offset: ?Counter = null,
    error_output_offset: ?Counter = null,
    last_step_progress: core.Progress = .{},

    pub const Counter = core.StreamCount;
    pub const Error = core.Error;
    pub const Options = struct {
        max_output_len: Counter = std.math.maxInt(Counter),
        metadata_output: []u8 = &.{},
        metadata_block_lengths: []usize = &.{},
    };
    pub const Phase = enum { window, header, payload, done };
    const WindowState = enum { first, low3, tail };
    const HeaderState = enum { is_last, last_empty, nibbles, metadata_reserved, metadata_count, metadata_len, block_len, uncompressed, padding };
    pub const Snapshot = struct {
        phase: Phase,
        input_read: Counter,
        output_written: Counter,
        payload_remaining: usize,
        stream_input: Counter,
        stream_output: Counter,
        stream_count: Counter,
        stream_index: Counter,
        metadata_written: usize,
        metadata_total: Counter,
        metadata_truncated: bool,
        metadata_block_count: Counter,
        metadata_blocks_captured: usize,
        metadata_blocks_truncated: bool,
        metadata: bool,
        last_error_name: []const u8,
        last_error_phase: Phase,
        error_input_offset: ?Counter = null,
        error_output_offset: ?Counter = null,
        last_step_progress: core.Progress = .{},
    };

    pub fn init() Decoder {
        return initWithOptions(.{});
    }
    pub fn initWithOptions(options: Options) Decoder {
        return .{
            .options = options,
            .metadata_output = options.metadata_output,
            .metadata_block_lengths = options.metadata_block_lengths,
        };
    }
    pub fn reset(self: *Decoder) void {
        self.* = .{
            .options = self.options,
            .metadata_output = self.options.metadata_output,
            .metadata_block_lengths = self.options.metadata_block_lengths,
        };
    }
    pub fn nextStream(self: *Decoder, options: Options) Error!void {
        if (self.phase != .done or !self.finished) return error.InvalidBlockPlan;
        const stream_input = core.stream_count.add(self.stream_input, self.total_input) catch return self.fail(.done, error.IntegerOverflow);
        const stream_output = core.stream_count.add(self.stream_output, self.total_output) catch return self.fail(.done, error.IntegerOverflow);
        const stream_count = core.stream_count.add(self.stream_count, 1) catch return self.fail(.done, error.IntegerOverflow);
        self.* = .{
            .options = options,
            .metadata_output = options.metadata_output,
            .metadata_block_lengths = options.metadata_block_lengths,
            .stream_input = stream_input,
            .stream_output = stream_output,
            .stream_count = stream_count,
        };
    }
    pub fn snapshot(self: *const Decoder) Snapshot {
        return .{
            .phase = self.phase,
            .input_read = self.total_input,
            .output_written = self.total_output,
            .payload_remaining = self.payload_remaining,
            .stream_input = core.stream_count.add(self.stream_input, self.total_input) catch unreachable,
            .stream_output = core.stream_count.add(self.stream_output, self.total_output) catch unreachable,
            .stream_count = core.stream_count.add(self.stream_count, @intFromBool(self.phase == .done and self.finished)) catch unreachable,
            .stream_index = self.stream_count,
            .metadata_written = self.metadata_written,
            .metadata_total = self.metadata_total,
            .metadata_truncated = core.stream_count.fromLocal(self.metadata_written) != self.metadata_total,
            .metadata_block_count = self.metadata_block_count,
            .metadata_blocks_captured = core.stream_count.bounded(self.metadata_block_count, self.metadata_block_lengths.len),
            .metadata_blocks_truncated = self.metadata_block_count > core.stream_count.fromLocal(self.metadata_block_lengths.len),
            .metadata = self.metadata,
            .last_error_name = self.last_error_name,
            .last_error_phase = self.last_error_phase,
            .error_input_offset = self.error_input_offset,
            .error_output_offset = self.error_output_offset,
            .last_step_progress = self.last_step_progress,
        };
    }
    pub fn diagnostics(self: *const Decoder) core.StreamingDiagnostics {
        const snap = self.snapshot();
        return .{
            .phase_name = @tagName(snap.phase),
            .frame_input_read = snap.input_read,
            .output_written = snap.output_written,
            .payload_remaining = snap.payload_remaining,
            .last_error_name = snap.last_error_name,
            .error_input_offset = snap.error_input_offset,
            .error_output_offset = snap.error_output_offset,
            .last_step_progress = snap.last_step_progress,
            .last_error_phase_name = if (snap.last_error_name.len == 0) "" else @tagName(snap.last_error_phase),
            .recoverability_hint_name = if (std.mem.eql(u8, snap.last_error_name, @errorName(error.TruncatedFrame))) "truncated_input" else if (std.mem.eql(u8, snap.last_error_name, @errorName(error.UnsupportedBrotliFeature))) "unsupported_feature" else if (snap.last_error_name.len == 0) "none" else "payload_corrupt",
        };
    }

    pub fn finish(self: *Decoder) Error!void {
        if (self.phase != .done) return self.fail(self.phase, error.TruncatedFrame);
        _ = core.stream_count.add(self.stream_count, 1) catch return self.fail(.done, error.IntegerOverflow);
        self.finished = true;
    }

    pub fn step(self: *Decoder, input: []const u8, output: []u8) Error!core.StepResult {
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

    fn stepImpl(self: *Decoder, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.finished) {
            if (input.len != 0) return self.fail(.done, error.TrailingData);
            return .{ .status = .done };
        }
        _ = try self.checkInput(input.len);
        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) {
            if (self.phase == .payload) {
                const available_output = if (self.metadata) self.payload_remaining else output.len - output_written;
                const n = @min(self.payload_remaining, @min(input.len - input_read, available_output));
                const next_input = try self.checkInput(n);
                if (self.metadata) {
                    const next_metadata = core.stream_count.addLocal(self.metadata_total, n) catch return self.fail(.payload, error.IntegerOverflow);
                    if (n == self.payload_remaining) _ = try self.nextMetadataBlockCount();
                    const capture_len = @min(n, self.metadata_output.len -| self.metadata_written);
                    if (capture_len != 0)
                        @memcpy(self.metadata_output[self.metadata_written..][0..capture_len], input[input_read..][0..capture_len]);
                    self.metadata_written += capture_len;
                    self.metadata_total = next_metadata;
                } else {
                    const next_output = try self.checkOutput(n);
                    @memcpy(output[output_written..][0..n], input[input_read..][0..n]);
                    output_written += n;
                    self.total_output = next_output;
                }
                input_read += n;
                self.total_input = next_input;
                self.payload_remaining -= n;
                if (self.payload_remaining != 0) {
                    return result(input_read, output_written, if (!self.metadata and output_written == output.len) .need_output else .need_input);
                }
                if (self.metadata) try self.recordMetadataBlock();
                self.metadata = false;
                self.phase = .header;
            }

            if (self.phase == .done) {
                if (input_read != input.len) return self.fail(.done, error.TrailingData);
                return result(input_read, output_written, .done);
            }

            if (self.phase == .window) {
                switch (self.window_state) {
                    .first => {
                        const first = try self.readBits(input, &input_read, 1) orelse return result(input_read, output_written, .need_input);
                        if (first == 0) {
                            self.phase = .header;
                        } else {
                            self.window_state = .low3;
                            continue;
                        }
                    },
                    .low3 => {
                        const low3 = try self.readBits(input, &input_read, 3) orelse return result(input_read, output_written, .need_input);
                        if (low3 == 0) {
                            self.window_state = .tail;
                            continue;
                        }
                        self.phase = .header;
                    },
                    .tail => {
                        const tail = try self.readBits(input, &input_read, 3) orelse return result(input_read, output_written, .need_input);
                        if (tail == 1) return self.fail(.window, error.CorruptFrame);
                        self.phase = .header;
                    },
                }
            }

            if (self.phase == .header) {
                switch (self.header_state) {
                    .is_last => {
                        const is_last = try self.readBits(input, &input_read, 1) orelse return result(input_read, output_written, .need_input);
                        self.header_state = if (is_last != 0) .last_empty else .nibbles;
                        continue;
                    },
                    .last_empty => {
                        const empty = try self.readBits(input, &input_read, 1) orelse return result(input_read, output_written, .need_input);
                        if (empty == 0) return self.fail(.header, error.UnsupportedBrotliFeature);
                        self.header_state = .padding;
                        self.metadata = false;
                        self.payload_remaining = 0;
                    },
                    .nibbles => {
                        const code = try self.readBits(input, &input_read, 2) orelse return result(input_read, output_written, .need_input);
                        if (code == 3) {
                            self.metadata = true;
                            self.header_state = .metadata_reserved;
                        } else {
                            self.metadata = false;
                            self.length_width = @intCast((4 + code) * 4);
                            self.header_state = .block_len;
                        }
                        continue;
                    },
                    .metadata_reserved => {
                        const reserved = try self.readBits(input, &input_read, 1) orelse return result(input_read, output_written, .need_input);
                        if (reserved != 0) return self.fail(.header, error.CorruptFrame);
                        self.header_state = .metadata_count;
                        continue;
                    },
                    .metadata_count => {
                        const count_bytes = try self.readBits(input, &input_read, 2) orelse return result(input_read, output_written, .need_input);
                        self.length_width = @intCast(count_bytes * 8);
                        if (count_bytes == 0) {
                            self.payload_remaining = 0;
                            self.current_metadata_len = 0;
                            self.header_state = .padding;
                        } else {
                            self.header_state = .metadata_len;
                        }
                        continue;
                    },
                    .metadata_len => {
                        const len_minus_one = try self.readBits(input, &input_read, self.length_width) orelse return result(input_read, output_written, .need_input);
                        const count_bytes = self.length_width / 8;
                        if (count_bytes > 1 and ((len_minus_one >> @intCast((count_bytes - 1) * 8)) & 0xff) == 0) return self.fail(.header, error.CorruptFrame);
                        self.payload_remaining = len_minus_one + 1;
                        self.current_metadata_len = self.payload_remaining;
                        self.header_state = .padding;
                    },
                    .block_len => {
                        const len_minus_one = try self.readBits(input, &input_read, self.length_width) orelse return result(input_read, output_written, .need_input);
                        const nibbles = self.length_width / 4;
                        if (nibbles > 4 and ((len_minus_one >> @intCast((nibbles - 1) * 4)) & 0xf) == 0) return self.fail(.header, error.CorruptFrame);
                        self.payload_remaining = len_minus_one + 1;
                        self.header_state = .uncompressed;
                        continue;
                    },
                    .uncompressed => {
                        const uncompressed = try self.readBits(input, &input_read, 1) orelse return result(input_read, output_written, .need_input);
                        if (uncompressed == 0) return self.fail(.header, error.UnsupportedBrotliFeature);
                        _ = try self.checkOutput(self.payload_remaining);
                        self.header_state = .padding;
                    },
                    .padding => {
                        if (!self.zeroPadding()) return self.fail(.header, error.CorruptFrame);
                        if (!self.metadata and self.payload_remaining == 0) {
                            self.phase = .done;
                            continue;
                        }
                        if (self.metadata and self.payload_remaining == 0) try self.recordMetadataBlock();
                        self.normalizeAlignedPayload(&input_read);
                        self.phase = if (self.payload_remaining == 0) .header else .payload;
                        self.header_state = .is_last;
                        continue;
                    },
                }
            }
        }
    }

    /// Rewind input bytes staged past the byte-aligned header boundary so they
    /// are consumed exactly once by the direct payload path. Headers are small,
    /// making this bounded reservoir rewind cheap even at arbitrary split points.
    fn normalizeAlignedPayload(self: *Decoder, input_read: *usize) void {
        if (self.staged_bits == 0) return;
        const staged_bytes = (@as(usize, self.staged_bits) + 7) / 8;
        input_read.* -= staged_bytes;
        self.total_input -= core.stream_count.fromLocal(staged_bytes);
        self.staged = 0;
        self.staged_bits = 0;
    }
    fn nextMetadataBlockCount(self: *Decoder) Error!Counter {
        return core.stream_count.add(self.metadata_block_count, 1) catch return self.fail(self.phase, error.IntegerOverflow);
    }
    fn recordMetadataBlock(self: *Decoder) Error!void {
        const next_count = try self.nextMetadataBlockCount();
        if (self.metadata_block_count < core.stream_count.fromLocal(self.metadata_block_lengths.len))
            self.metadata_block_lengths[core.stream_count.toLocal(self.metadata_block_count) catch unreachable] = self.current_metadata_len;
        self.metadata_block_count = next_count;
        self.current_metadata_len = 0;
    }
    fn checkInput(self: *Decoder, n: usize) Error!Counter {
        const next_input = core.stream_count.addLocal(self.total_input, n) catch return self.fail(self.phase, error.IntegerOverflow);
        _ = core.stream_count.add(self.stream_input, next_input) catch return self.fail(self.phase, error.IntegerOverflow);
        return next_input;
    }
    fn checkOutput(self: *Decoder, n: usize) Error!Counter {
        const next_output = core.stream_count.addLocal(self.total_output, n) catch return self.fail(self.phase, error.IntegerOverflow);
        _ = core.stream_count.add(self.stream_output, next_output) catch return self.fail(self.phase, error.IntegerOverflow);
        if (next_output > self.options.max_output_len) return self.fail(self.phase, error.OutputLimitExceeded);
        return next_output;
    }

    fn readBits(self: *Decoder, input: []const u8, input_read: *usize, count: u6) Error!?usize {
        while (self.staged_bits < count) {
            if (input_read.* == input.len) return null;
            const next_input = try self.checkInput(1);
            self.staged |= @as(u64, input[input_read.*]) << self.staged_bits;
            self.staged_bits += 8;
            input_read.* += 1;
            self.total_input = next_input;
        }
        const mask = (@as(u64, 1) << count) - 1;
        const value: usize = @intCast(self.staged & mask);
        self.staged >>= count;
        self.staged_bits -= count;
        return value;
    }
    fn zeroPadding(self: *Decoder) bool {
        const drop: u6 = self.staged_bits % 8;
        if (drop == 0) return true;
        const mask = (@as(u64, 1) << drop) - 1;
        if ((self.staged & mask) != 0) return false;
        self.staged >>= drop;
        self.staged_bits -= drop;
        return true;
    }
    fn localDelta(after: Counter, before: Counter, limit: usize) usize {
        std.debug.assert(after >= before);
        const delta = after - before;
        std.debug.assert(delta <= core.stream_count.fromLocal(limit));
        return core.stream_count.toLocal(delta) catch unreachable;
    }
    fn fail(self: *Decoder, phase: Phase, err: Error) Error {
        self.last_error_name = @errorName(err);
        self.last_error_phase = phase;
        self.error_input_offset = core.stream_count.add(self.stream_input, self.total_input) catch unreachable;
        self.error_output_offset = core.stream_count.add(self.stream_output, self.total_output) catch unreachable;
        return err;
    }
    fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
        return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
    }
};

test "Brotli subset counters stored crosses 4 GiB and continues legal streams" {
    const br = @import("../../../br.zig");
    const Counter = Decoder.Counter;
    const base: Counter = (@as(Counter, 1) << 32) - 1;
    const wire = try br.encodeStoredStreamWithOptionsAlloc(std.testing.allocator, "x", .{ .metadata = "m" });
    defer std.testing.allocator.free(wire);
    var captured: [1]u8 = .{0xaa};
    var lengths: [1]usize = .{999};
    const options: Decoder.Options = .{
        .max_output_len = base + 1,
        .metadata_output = &captured,
        .metadata_block_lengths = &lengths,
    };
    var decoder = Decoder.initWithOptions(options);
    decoder.total_input = base;
    decoder.total_output = base;
    decoder.stream_count = base;
    decoder.metadata_total = base;
    decoder.metadata_block_count = base;
    var output: [1]u8 = undefined;
    const first = try decoder.step(wire, &output);
    try decoder.finish();
    try std.testing.expectEqual(.done, first.status);
    try std.testing.expectEqual(@as(usize, 1), first.progress.output_written);
    try std.testing.expectEqualSlices(u8, "x", &output);
    try std.testing.expectEqualSlices(u8, "m", &captured);
    const first_snapshot = decoder.snapshot();
    try std.testing.expectEqual(base + core.stream_count.fromLocal(wire.len), first_snapshot.input_read);
    try std.testing.expectEqual(base + 1, first_snapshot.output_written);
    try std.testing.expectEqual(base + 1, first_snapshot.stream_count);
    try std.testing.expectEqual(base + 1, first_snapshot.metadata_total);
    try std.testing.expectEqual(base + 1, first_snapshot.metadata_block_count);
    try std.testing.expectEqual(@as(usize, 999), lengths[0]);
    try decoder.nextStream(options);
    _ = try decoder.step(wire, &output);
    try decoder.finish();
    const second_snapshot = decoder.snapshot();
    try std.testing.expectEqual(base + 2 * core.stream_count.fromLocal(wire.len), second_snapshot.stream_input);
    try std.testing.expectEqual(base + 2, second_snapshot.stream_output);
    try std.testing.expectEqual(base + 2, second_snapshot.stream_count);
    try std.testing.expectEqual(@as(usize, 1), lengths[0]);
    decoder.reset();
    try std.testing.expectEqual(Decoder.Phase.window, decoder.snapshot().phase);
    try std.testing.expectEqual(@as(Counter, 0), decoder.snapshot().stream_input);
    try std.testing.expectEqual(base + 1, decoder.options.max_output_len);
    try std.testing.expectEqual(captured[0..].ptr, decoder.metadata_output.ptr);
}

test "Brotli subset counters stored rejects overflow before input and output writes" {
    const br = @import("../../../br.zig");
    const Counter = Decoder.Counter;
    const wire = try br.encodeStoredStreamWithOptionsAlloc(std.testing.allocator, "x", .{});
    defer std.testing.allocator.free(wire);
    for ([_]bool{ false, true }) |cumulative| {
        var decoder = Decoder.init();
        if (cumulative) decoder.stream_input = std.math.maxInt(Counter) else decoder.total_input = std.math.maxInt(Counter);
        var output: [1]u8 = .{0xaa};
        try std.testing.expectError(error.IntegerOverflow, decoder.step(wire, &output));
        try std.testing.expectEqual(Decoder.Phase.window, decoder.phase);
        try std.testing.expectEqual(@as(u6, 0), decoder.staged_bits);
        try std.testing.expectEqualSlices(u8, &.{0xaa}, &output);
        try std.testing.expectEqual(core.Progress{}, decoder.diagnostics().last_step_progress.?);
        try std.testing.expectEqual(@as(?Counter, std.math.maxInt(Counter)), decoder.diagnostics().error_input_offset);
        decoder.reset();
        const header = try decoder.step(wire, &.{});
        try std.testing.expectEqual(.need_output, header.status);
        if (cumulative) decoder.stream_output = std.math.maxInt(Counter) else decoder.total_output = std.math.maxInt(Counter);
        const input_before = decoder.total_input;
        try std.testing.expectError(error.IntegerOverflow, decoder.step(wire[header.progress.input_read..], &output));
        try std.testing.expectEqual(input_before, decoder.total_input);
        try std.testing.expectEqual(@as(usize, 1), decoder.payload_remaining);
        try std.testing.expectEqual(Decoder.Phase.payload, decoder.phase);
        try std.testing.expectEqualSlices(u8, &.{0xaa}, &output);
    }
    var offered = Decoder.init();
    offered.total_input = std.math.maxInt(Counter) - 1;
    try std.testing.expectError(error.IntegerOverflow, offered.step(wire[0..2], &.{}));
    try std.testing.expectEqual(@as(u6, 0), offered.staged_bits);
}

test "Brotli subset counters stored checks metadata and stream completion before commit" {
    const br = @import("../../../br.zig");
    const Counter = Decoder.Counter;
    const wire = try br.encodeStoredStreamWithOptionsAlloc(std.testing.allocator, "", .{ .metadata = "m" });
    defer std.testing.allocator.free(wire);
    for ([_]bool{ false, true }) |blocks| {
        var captured: [1]u8 = .{0xaa};
        var decoder = Decoder.initWithOptions(.{ .metadata_output = &captured });
        var offset: usize = 0;
        while (decoder.phase != .payload) {
            const step_result = try decoder.step(wire[offset .. offset + 1], &.{});
            offset += step_result.progress.input_read;
        }
        if (blocks) decoder.metadata_block_count = std.math.maxInt(Counter) else decoder.metadata_total = std.math.maxInt(Counter);
        const input_before = decoder.total_input;
        try std.testing.expectError(error.IntegerOverflow, decoder.step(wire[offset..], &.{}));
        try std.testing.expectEqual(input_before, decoder.total_input);
        try std.testing.expectEqual(@as(usize, 1), decoder.payload_remaining);
        try std.testing.expectEqual(@as(usize, 0), decoder.metadata_written);
        try std.testing.expectEqualSlices(u8, &.{0xaa}, &captured);
        try std.testing.expectEqual(core.Progress{}, decoder.diagnostics().last_step_progress.?);
        try std.testing.expectEqual(@as(?Counter, input_before), decoder.diagnostics().error_input_offset);
    }
    var decoder = Decoder.init();
    _ = try decoder.step(wire, &.{});
    decoder.stream_count = std.math.maxInt(Counter);
    try std.testing.expectError(error.IntegerOverflow, decoder.finish());
    try std.testing.expect(!decoder.finished);
    try std.testing.expectEqual(std.math.maxInt(Counter), decoder.snapshot().stream_count);
    decoder.stream_count -= 1;
    try decoder.finish();
    try std.testing.expectEqual(std.math.maxInt(Counter), decoder.snapshot().stream_count);
    try decoder.nextStream(.{});
    try std.testing.expectEqual(Decoder.Phase.window, decoder.phase);
}
