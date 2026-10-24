const std = @import("std");
const core = @import("../../core.zig");

/// Byte-progressive decoder for the single-command compressed RLE streams
/// emitted by Vort. Only the bounded encoded header is retained. Once it has
/// been validated, decoded bytes are produced directly into caller buffers,
/// so neither compressed payload nor decompressed output scales with run size.
pub fn Decoder(comptime Codec: type) type {
    return struct {
        options: Options,
        phase: Phase = .header,
        header_bytes: [Codec.max_stream_header_bytes]u8 = undefined,
        header_len: usize = 0,
        staged_bits: u64 = 0,
        staged_bit_count: u6 = 0,
        repeated_byte: u8 = 0,
        output_remaining: usize = 0,
        stream_bits: usize = 0,
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
        };
        pub const Phase = enum { header, payload, padding, done };
        pub const Snapshot = struct {
            phase: Phase,
            input_read: Counter,
            output_written: Counter,
            payload_remaining: usize,
            retained_input_bytes: usize,
            expected_output_len: ?Counter,
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
            return .{ .options = options };
        }
        pub fn reset(self: *Self) void {
            self.* = .{ .options = self.options };
        }
        pub fn snapshot(self: *const Self) Snapshot {
            return .{
                .phase = self.phase,
                .input_read = self.total_input,
                .output_written = self.total_output,
                .payload_remaining = self.output_remaining,
                .retained_input_bytes = self.header_len,
                .expected_output_len = self.options.expected_output_len,
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
            while (true) switch (self.phase) {
                .header => {
                    while (input_read < input.len) {
                        if (self.header_len == self.header_bytes.len)
                            return self.fail(.header, error.UnsupportedBrotliFeature);
                        const next_input = core.stream_count.addLocal(self.total_input, 1) catch return self.fail(.header, error.IntegerOverflow);
                        self.header_bytes[self.header_len] = input[input_read];
                        self.header_len += 1;
                        input_read += 1;
                        self.total_input = next_input;

                        const parsed = Codec.parseHeader(self.header_bytes[0..self.header_len]) catch |err| switch (err) {
                            error.TruncatedFrame => continue,
                            else => return self.fail(.header, err),
                        };
                        const decoded_end = try self.checkOutput(parsed.header.decoded_len);
                        if (self.options.expected_output_len) |expected|
                            if (decoded_end != expected) return self.fail(.header, error.SizeMismatch);

                        const byte_index = parsed.bits_read / 8;
                        const bit_index: u3 = @intCast(parsed.bits_read % 8);
                        const available_bits = self.header_len * 8 - parsed.bits_read;
                        if (available_bits > 63) return self.fail(.header, error.CorruptFrame);
                        self.staged_bits = if (available_bits == 0) 0 else @as(u64, self.header_bytes[byte_index]) >> bit_index;
                        self.staged_bit_count = @intCast(available_bits);
                        self.repeated_byte = parsed.header.repeated_byte;
                        self.output_remaining = parsed.header.decoded_len;
                        self.stream_bits = parsed.bits_read;
                        self.phase = .payload;
                        break;
                    }
                    if (self.phase == .header) return result(input_read, output_written, .need_input);
                },
                .payload => {
                    const n = @min(output.len - output_written, self.output_remaining);
                    const next_output = try self.checkOutput(n);
                    @memset(output[output_written..][0..n], self.repeated_byte);
                    output_written += n;
                    self.total_output = next_output;
                    self.output_remaining -= n;
                    if (self.output_remaining != 0) return result(input_read, output_written, .need_output);
                    self.phase = .padding;
                },
                .padding => {
                    const expected_padding_bits: u3 = @intCast((8 - self.stream_bits % 8) % 8);
                    if (self.staged_bit_count < expected_padding_bits) return result(input_read, output_written, .need_input);
                    if (expected_padding_bits != 0) {
                        const mask = (@as(u64, 1) << expected_padding_bits) - 1;
                        if ((self.staged_bits & mask) != 0) return self.fail(.padding, error.CorruptFrame);
                        self.staged_bits >>= expected_padding_bits;
                        self.staged_bit_count -= expected_padding_bits;
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
        fn checkOutput(self: *Self, n: usize) Error!Counter {
            const next_output = core.stream_count.addLocal(self.total_output, n) catch return self.fail(self.phase, error.IntegerOverflow);
            if (next_output > self.options.max_output_len) return self.fail(self.phase, error.OutputLimitExceeded);
            return next_output;
        }
        fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
            return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
        }
    };
}

test "Brotli subset counters RLE crosses 4 GiB with local output slices" {
    const br = @import("../../br.zig");
    const Counter = br.IncrementalRleStreamDecoder.Counter;
    const base: Counter = (@as(Counter, 1) << 32) - 1;
    const wire = try br.encodeRleStreamAlloc(std.testing.allocator, "zzzzz");
    defer std.testing.allocator.free(wire);
    var decoder = br.IncrementalRleStreamDecoder.initWithOptions(.{ .max_output_len = base + 5 });
    decoder.total_input = base;
    _ = try decoder.step(wire, &.{});
    decoder.total_output = base;
    decoder.options.expected_output_len = base + 5;
    var output: [5]u8 = undefined;
    const completed = try decoder.step("", &output);
    try decoder.finish();
    try std.testing.expectEqual(.done, completed.status);
    try std.testing.expectEqual(@as(usize, 5), completed.progress.output_written);
    try std.testing.expectEqualSlices(u8, "zzzzz", &output);
    try std.testing.expectEqual(base + core.stream_count.fromLocal(wire.len), decoder.snapshot().input_read);
    try std.testing.expectEqual(base + 5, decoder.snapshot().output_written);
    try std.testing.expectEqual(@as(?Counter, base + 5), decoder.diagnostics().expected_output_len);
    decoder.reset();
    try std.testing.expectEqual(@as(Counter, 0), decoder.total_output);
    try std.testing.expectEqual(@as(?Counter, base + 5), decoder.options.expected_output_len);
}

test "Brotli subset counters RLE rejects offered input and output overflow before writes" {
    const br = @import("../../br.zig");
    const Counter = br.IncrementalRleStreamDecoder.Counter;
    const wire = try br.encodeRleStreamAlloc(std.testing.allocator, "zzzzz");
    defer std.testing.allocator.free(wire);
    var decoder = br.IncrementalRleStreamDecoder.init();
    decoder.total_input = std.math.maxInt(Counter) - 1;
    var output: [5]u8 = @splat(0xaa);
    try std.testing.expectError(error.IntegerOverflow, decoder.step(wire[0..2], &output));
    try std.testing.expectEqual(@as(usize, 0), decoder.header_len);
    try std.testing.expectEqual(std.math.maxInt(Counter) - 1, decoder.total_input);
    try std.testing.expectEqual(core.Progress{}, decoder.diagnostics().last_step_progress.?);
    try std.testing.expectEqual(@as(?Counter, std.math.maxInt(Counter) - 1), decoder.diagnostics().error_input_offset);
    decoder.reset();
    _ = try decoder.step(wire, &.{});
    decoder.total_output = std.math.maxInt(Counter) - 4;
    const input_before = decoder.total_input;
    try std.testing.expectError(error.IntegerOverflow, decoder.step("", &output));
    try std.testing.expectEqual(std.math.maxInt(Counter) - 4, decoder.total_output);
    try std.testing.expectEqual(input_before, decoder.total_input);
    try std.testing.expectEqual(@as(usize, 5), decoder.output_remaining);
    try std.testing.expectEqualSlices(u8, &.{ 0xaa, 0xaa, 0xaa, 0xaa, 0xaa }, &output);
}

test "Brotli subset counters format failures retain consumed bytes and completed output" {
    const br = @import("../../br.zig");
    const base: core.StreamCount = (@as(core.StreamCount, 1) << 32) - 1;
    inline for (.{ br.IncrementalRleStreamDecoder, br.IncrementalLiteralStreamDecoder, br.IncrementalStoredStreamDecoder }) |D| {
        const wire = if (D == br.IncrementalRleStreamDecoder)
            try br.encodeRleStreamAlloc(std.testing.allocator, "zzzzz")
        else if (D == br.IncrementalLiteralStreamDecoder)
            try br.IncrementalTestSupport.encodeCompressedHello(std.testing.allocator)
        else
            try br.encodeStoredStreamWithOptionsAlloc(std.testing.allocator, "hello", .{});
        defer std.testing.allocator.free(wire);
        var trailing: [128]u8 = undefined;
        try std.testing.expect(wire.len < trailing.len);
        @memcpy(trailing[0..wire.len], wire);
        trailing[wire.len] = 0xff;
        var decoder = D.init();
        decoder.total_input = base;
        decoder.total_output = base;
        var output: [5]u8 = undefined;
        try std.testing.expectError(error.TrailingData, decoder.step(trailing[0 .. wire.len + 1], &output));
        try std.testing.expectEqualSlices(u8, if (D == br.IncrementalRleStreamDecoder) "zzzzz" else "hello", &output);
        try std.testing.expectEqual(base + core.stream_count.fromLocal(wire.len), decoder.snapshot().input_read);
        try std.testing.expectEqual(base + 5, decoder.snapshot().output_written);
        try std.testing.expectEqualStrings("TrailingData", decoder.snapshot().last_error_name);
        const diagnostic = decoder.diagnostics();
        try std.testing.expectEqual(core.Progress{ .input_read = wire.len, .output_written = 5 }, diagnostic.last_step_progress.?);
        try std.testing.expectEqual(@as(?core.StreamCount, base + core.stream_count.fromLocal(wire.len)), diagnostic.error_input_offset);
        try std.testing.expectEqual(@as(?core.StreamCount, base + 5), diagnostic.error_output_offset);
        decoder.reset();
        try std.testing.expectEqual(@as(?core.StreamCount, null), decoder.diagnostics().error_input_offset);
        try std.testing.expectEqual(@as(?core.StreamCount, null), decoder.diagnostics().error_output_offset);
        try std.testing.expectEqual(core.Progress{}, decoder.diagnostics().last_step_progress.?);
    }
}

test "Brotli subset counters diagnostics preserve header rejection and continued stream offsets" {
    const br = @import("../../br.zig");
    const Counter = core.StreamCount;
    const rle_wire = try br.encodeRleStreamAlloc(std.testing.allocator, "a" ** 257);
    defer std.testing.allocator.free(rle_wire);
    for ([_]bool{ false, true }) |cap| {
        var decoder = br.IncrementalRleStreamDecoder.initWithOptions(if (cap)
            .{ .max_output_len = 256 }
        else
            .{ .expected_output_len = 258 });
        var output: [7]u8 = @splat(0xaa);
        try std.testing.expectError(if (cap) error.OutputLimitExceeded else error.SizeMismatch, decoder.step(rle_wire, &output));
        const diagnostic = decoder.diagnostics();
        try std.testing.expectEqual(core.Progress{ .input_read = rle_wire.len }, diagnostic.last_step_progress.?);
        try std.testing.expectEqual(@as(?Counter, core.stream_count.fromLocal(rle_wire.len)), diagnostic.error_input_offset);
        try std.testing.expectEqual(@as(?Counter, 0), diagnostic.error_output_offset);
        try std.testing.expectEqualSlices(u8, &.{ 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa }, &output);
    }
    const base: Counter = (@as(Counter, 1) << 32) - 1;
    const stored_wire = try br.encodeStoredStreamWithOptionsAlloc(std.testing.allocator, "x", .{ .window_bits = 16 });
    defer std.testing.allocator.free(stored_wire);
    var stored = br.IncrementalStoredStreamDecoder.init();
    stored.total_input = base;
    stored.total_output = base;
    var output: [1]u8 = undefined;
    const completed = try stored.step(stored_wire, &output);
    try std.testing.expectEqual(completed.progress, stored.diagnostics().last_step_progress.?);
    try stored.finish();
    try stored.nextStream(.{ .max_output_len = 0 });
    try std.testing.expectEqual(@as(?Counter, null), stored.diagnostics().error_input_offset);
    output[0] = 0xaa;
    try std.testing.expectError(error.OutputLimitExceeded, stored.step(stored_wire, &output));
    const diagnostic = stored.diagnostics();
    try std.testing.expectEqual(core.Progress{ .input_read = 3 }, diagnostic.last_step_progress.?);
    try std.testing.expectEqual(@as(?Counter, base + core.stream_count.fromLocal(stored_wire.len) + 3), diagnostic.error_input_offset);
    try std.testing.expectEqual(@as(?Counter, base + 1), diagnostic.error_output_offset);
    try std.testing.expectEqualSlices(u8, &.{0xaa}, &output);
}
