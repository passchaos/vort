const std = @import("std");
const core = @import("../../core.zig");
const counts = core.stream_count;
const owned = @import("owned_copy_decoder.zig");

// A tiny resumable codec isolates the facade's accounting from Brotli parsing:
// two prefix bytes, byte payload, then a zero terminator. 0xff is corrupt.
const Codec = struct {
    pub const Error = core.Error || error{ OutOfMemory, WorkingMemoryLimitExceeded };
    pub const DecodeOptions = struct {};
    pub const HistoryPlan = struct { allocation_len: usize, capped: bool };

    pub fn validateDecodeOptions(_: DecodeOptions) Error!void {}

    pub fn historyPlanFromPrefix(prefix: []const u8, output_bound: core.StreamCount, max_history_len: usize, _: DecodeOptions) Error!?HistoryPlan {
        if (prefix.len < 2) return null;
        return .{ .allocation_len = counts.bounded(output_bound, @min(max_history_len, 4)), .capped = false };
    }

    pub const ProgressiveDecoder = struct {
        pub const embedded_compressed_header_capacity: usize = 16;
        pub const Options = struct {
            max_output_len: core.StreamCount,
            max_total_output_len: core.StreamCount,
            expected_output_len: ?core.StreamCount,
            decode: DecodeOptions,
            compressed_header_scratch: []u8,
            metadata_output: []u8,
            metadata_block_lengths: []usize,
            allow_trailing_data: bool,
        };
        pub const Phase = enum { prefix, payload, compressed_header, done };
        pub const Snapshot = struct {
            phase: Phase,
            input_read: core.StreamCount,
            output_written: core.StreamCount,
            payload_remaining: usize = 0,
            retained_input_bytes: usize = 0,
            compressed_header_capacity: usize = embedded_compressed_header_capacity,
            history_bytes: usize = 0,
        };

        phase: Phase = .prefix,
        prefix_remaining: u2 = 2,
        input_read: core.StreamCount = 0,
        output_written: core.StreamCount = 0,

        pub fn initWithOptions(_: []u8, _: Options) @This() {
            return .{};
        }

        pub fn snapshot(self: *const @This()) Snapshot {
            return .{ .phase = self.phase, .input_read = self.input_read, .output_written = self.output_written };
        }

        pub fn step(self: *@This(), input: []const u8, output: []u8) Error!core.StepResult {
            var progress: core.Progress = .{};
            while (progress.input_read < input.len) {
                if (self.prefix_remaining != 0) {
                    self.prefix_remaining -= 1;
                    progress.input_read += 1;
                    try counts.advance(&self.input_read, 1);
                    if (self.prefix_remaining == 0) self.phase = .payload;
                    continue;
                }
                const byte = input[progress.input_read];
                if (byte == 0xff) return error.CorruptFrame;
                if (byte == 0) {
                    try counts.advance(&self.input_read, 1);
                    progress.input_read += 1;
                    self.phase = .done;
                    return .{ .progress = progress, .status = .done };
                }
                if (progress.output_written == output.len)
                    return .{ .progress = progress, .status = .need_output };
                try counts.advance(&self.input_read, 1);
                try counts.advance(&self.output_written, 1);
                output[progress.output_written] = byte;
                progress.input_read += 1;
                progress.output_written += 1;
            }
            return .{ .progress = progress, .status = .need_input };
        }

        pub fn finish(self: *@This()) Error!void {
            if (self.phase != .done) return error.TruncatedFrame;
        }

        pub fn trailingInput(_: *const @This()) []const u8 {
            return &.{};
        }

        pub fn replaceCompressedHeaderScratch(_: *@This(), _: []u8) Error!void {}
    };
};

const Decoder = owned.Decoder(Codec);
const Counter = Decoder.Counter;
const wire = "\x01\x02ab\x00";

fn expectFailure(decoder: *const Decoder, input_read: usize, output_written: usize) !void {
    const snap = decoder.snapshot();
    try std.testing.expectEqualDeep(core.Progress{ .input_read = input_read, .output_written = output_written }, snap.last_step_progress);
    try std.testing.expectEqual(@as(?Counter, snap.total_compressed), snap.error_input_offset);
    try std.testing.expectEqual(@as(?Counter, snap.total_output), snap.error_output_offset);
    const diagnostic = decoder.diagnostics();
    try std.testing.expectEqual(snap.error_input_offset, diagnostic.error_input_offset);
    try std.testing.expectEqual(snap.error_output_offset, diagnostic.error_output_offset);
}

test "Brotli owned counters cross 4 GiB with bounded buffers and preserve frame totals" {
    try std.testing.expectEqual(if (@bitSizeOf(usize) < 64) u64 else usize, Counter);
    try std.testing.expectEqual(std.math.maxInt(Counter), (Decoder.Options{}).max_compressed_len);
    const base: Counter = (@as(Counter, 1) << 32) - 1;
    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    decoder.frame_input_read = base;
    decoder.frame_output_written = base;
    decoder.frame_count = base;
    var output: [8]u8 = @splat(0xa5);
    const first = try decoder.step(wire, &output);
    try std.testing.expectEqual(.done, first.status);
    try std.testing.expectEqualDeep(core.Progress{ .input_read = wire.len, .output_written = 2 }, first.progress);
    try std.testing.expectEqual(base + wire.len, decoder.snapshot().total_compressed);
    try std.testing.expectEqual(base + 2, decoder.snapshot().total_output);
    try std.testing.expectEqual(base + 1, decoder.snapshot().frame_count);
    try std.testing.expectEqual(base, decoder.snapshot().frame_index);
    try decoder.nextFrame(.{});
    try std.testing.expectEqual(@as(Counter, 0), decoder.snapshot().compressed_bytes);
    _ = try decoder.step(wire, &output);
    try std.testing.expectEqual(base + 2 * wire.len, decoder.snapshot().total_compressed);
    try std.testing.expectEqual(base + 4, decoder.snapshot().total_output);
    decoder.reset();
    try std.testing.expectEqual(@as(Counter, 0), decoder.snapshot().total_compressed);
    try std.testing.expectEqual(@as(Counter, 0), decoder.snapshot().total_output);
    try std.testing.expectEqual(@as(Counter, 0), decoder.snapshot().frame_count);
}

test "Brotli owned counters retain wide pledges without narrowing payload remaining" {
    const expected: Counter = (@as(Counter, 1) << 32) + 17;
    var decoder = Decoder.initExactCompressedSize(std.testing.allocator, .{ .expected_output_len = expected }, expected);
    defer decoder.deinit();
    try std.testing.expectEqual(@as(?Counter, expected), decoder.snapshot().expected_compressed_len);
    try std.testing.expectEqual(@as(?Counter, expected), decoder.snapshot().expected_output_len);
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().payload_remaining);
    try std.testing.expectEqual(@as(?core.StreamCount, expected), decoder.diagnostics().expected_output_len);
}

test "Brotli owned counters reject offered input and completion overflow before accepting bytes" {
    inline for (.{ 0, 1, 2 }) |which| {
        var decoder = Decoder.init(std.testing.allocator);
        defer decoder.deinit();
        switch (which) {
            0 => decoder.frame_input_read = std.math.maxInt(Counter),
            1 => decoder.total_compressed = std.math.maxInt(Counter),
            2 => decoder.frame_count = std.math.maxInt(Counter),
            else => unreachable,
        }
        var output: [8]u8 = @splat(0xa5);
        const before = decoder.snapshot();
        try std.testing.expectError(error.IntegerOverflow, decoder.step(wire, &output));
        try expectFailure(&decoder, 0, 0);
        try std.testing.expectEqual(before.total_compressed, decoder.snapshot().total_compressed);
        try std.testing.expectEqual(before.total_output, decoder.snapshot().total_output);
        try std.testing.expectEqual(before.frame_count, decoder.snapshot().frame_count);
        try std.testing.expectEqual(@as(u2, 0), decoder.window_prefix_len);
        try std.testing.expect(!decoder.decode_options_validated);
        try std.testing.expectEqual(@as(usize, 0), decoder.workingMemoryBytes());
        try std.testing.expectEqual([_]u8{0xa5} ** output.len, output);
    }
}

test "Brotli owned counters clip large output capacity and permit final bits at the limit" {
    inline for (.{ false, true }) |cumulative| {
        var decoder = Decoder.init(std.testing.allocator);
        defer decoder.deinit();
        if (cumulative) decoder.total_output = std.math.maxInt(Counter) - 1 else decoder.frame_output_written = std.math.maxInt(Counter) - 1;
        var output: [8]u8 = @splat(0xa5);
        const step = try decoder.step("\x01\x02a\x00", &output);
        try std.testing.expectEqual(.done, step.status);
        try std.testing.expectEqual(@as(usize, 1), step.progress.output_written);
        try std.testing.expectEqual(std.math.maxInt(Counter), decoder.snapshot().total_output);
        try std.testing.expectEqualSlices(u8, &.{ 'a', 0xa5, 0xa5, 0xa5, 0xa5, 0xa5, 0xa5, 0xa5 }, &output);
        try decoder.nextFrame(.{});
        const empty = try decoder.step("\x01\x02\x00", &output);
        try std.testing.expectEqual(.done, empty.status);
        try std.testing.expectEqual(@as(usize, 0), empty.progress.output_written);
        try std.testing.expectEqual(std.math.maxInt(Counter), decoder.snapshot().total_output);
    }
}

test "Brotli owned counters keep accepted prefix on output exhaustion and publish partial failures" {
    var output: [8]u8 = @splat(0xa5);
    inline for (.{ false, true }) |cumulative| {
        var exhausted = Decoder.init(std.testing.allocator);
        defer exhausted.deinit();
        if (cumulative) exhausted.total_output = std.math.maxInt(Counter) else exhausted.frame_output_written = std.math.maxInt(Counter);
        try std.testing.expectError(error.IntegerOverflow, exhausted.step(wire, &output));
        try expectFailure(&exhausted, 2, 0);
        try std.testing.expectEqual(@as(Counter, 2), exhausted.snapshot().total_compressed);
        try std.testing.expectEqual([_]u8{0xa5} ** output.len, output);
    }

    var malformed = Decoder.init(std.testing.allocator);
    defer malformed.deinit();
    const base: Counter = (@as(Counter, 1) << 32) - 1;
    malformed.total_compressed = base;
    malformed.total_output = base;
    try std.testing.expectError(error.CorruptFrame, malformed.step("\x01\x02ab\xff", &output));
    try expectFailure(&malformed, 4, 2);
    try std.testing.expectEqual(base + 4, malformed.snapshot().total_compressed);
    try std.testing.expectEqual(base + 2, malformed.snapshot().total_output);
    try std.testing.expectEqualSlices(u8, "ab", output[0..2]);
}

test "Brotli owned counters check finish and admit the last representable frame" {
    var exhausted = Decoder.init(std.testing.allocator);
    defer exhausted.deinit();
    exhausted.frame_count = std.math.maxInt(Counter);
    try std.testing.expectError(error.IntegerOverflow, exhausted.finish());
    try std.testing.expect(!exhausted.input_finished);
    try std.testing.expectEqual(.input, exhausted.snapshot().phase);
    try expectFailure(&exhausted, 0, 0);

    var last = Decoder.init(std.testing.allocator);
    defer last.deinit();
    last.frame_count = std.math.maxInt(Counter) - 1;
    try std.testing.expectEqual(.done, (try last.step("\x01\x02\x00", &.{})).status);
    try std.testing.expectEqual(std.math.maxInt(Counter), last.snapshot().frame_count);
    try std.testing.expectEqual(std.math.maxInt(Counter) - 1, last.snapshot().frame_index);
    try last.nextFrame(.{});
    try std.testing.expectError(error.IntegerOverflow, last.step(wire, &.{}));
    try expectFailure(&last, 0, 0);
    try std.testing.expectEqual(@as(u2, 0), last.window_prefix_len);
}

test "Brotli owned counters compare full offered input against wide caps and pledges" {
    const base: Counter = (@as(Counter, 1) << 32) - 1;
    inline for (.{ false, true }) |pledged| {
        var decoder = Decoder.initWithOptions(std.testing.allocator, if (pledged)
            .{ .expected_compressed_len = base + 2 }
        else
            .{ .max_compressed_len = base + 2 });
        defer decoder.deinit();
        decoder.frame_input_read = base;
        const err = if (pledged) error.SizeMismatch else error.OutputLimitExceeded;
        try std.testing.expectError(err, decoder.step(wire, &.{}));
        try expectFailure(&decoder, 0, 0);
        try std.testing.expectEqual(base, decoder.snapshot().compressed_bytes);
        try std.testing.expectEqual(@as(u2, 0), decoder.window_prefix_len);
    }
}

test "Brotli owned counters preserve next-frame operation caps transactionally" {
    var decoder = Decoder.initWithOptions(std.testing.allocator, .{ .max_total_output_len = 3 });
    defer decoder.deinit();
    var output: [8]u8 = undefined;
    _ = try decoder.step(wire, &output);
    const before = decoder.snapshot();
    try std.testing.expectError(error.OutputLimitExceeded, decoder.nextFrame(.{ .max_total_output_len = 1 }));
    try std.testing.expectEqual(before, decoder.snapshot());
    try decoder.nextFrame(.{ .expected_output_len = 2 });
    try std.testing.expectEqual(@as(Counter, 3), decoder.options.max_total_output_len);
    try std.testing.expectError(error.OutputLimitExceeded, decoder.step(wire, &output));
    try expectFailure(&decoder, 0, 0);
    try std.testing.expectEqual(@as(Counter, 2), decoder.snapshot().total_output);
}
