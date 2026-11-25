const std = @import("std");
const core = @import("../../core.zig");
const metadata = @import("metadata_events.zig");
const expect = std.testing.expect;
const equal = std.testing.expectEqual;
const slicesEqual = std.testing.expectEqualSlices;
const Count = core.StreamCount;
const unlimited = std.math.maxInt(Count);
const byte_canary: u8 = 0xa5;
const length_canary: usize = 0xaaaa;
const Flavor = enum { owned, copy, literal, stored };

pub fn contracts(comptime Br: type) !void {
    inline for (std.enums.values(Flavor)) |flavor| {
        const S = Suite(Br, flavor);
        try S.aggregate();
        try S.emptyBlocks();
        try S.headerAdmission();
    }
}

// Pack metadata independently of the encoder. The 105-bit compressed prefix
// from metadata_event_tests.zig is needed only by the literal-only decoder.
const Wire = struct {
    bytes: [64]u8 = @splat(0),
    bits: usize = 0,

    fn init(literal: bool) Wire {
        var wire: Wire = .{};
        if (literal) {
            const hello = "\x40\x00\x00\x00\x34\x5a\x19\xdb\x9b\x40\x21\x00\xa9\x01";
            @memcpy(wire.bytes[0..hello.len], hello);
            wire.bits = 105;
        } else wire.put(0, 1); // WBITS = 16.
        return wire;
    }

    fn setBit(self: *Wire, bit: usize) void {
        self.bytes[bit / 8] |= @as(u8, 1) << @intCast(bit % 8);
    }

    fn put(self: *Wire, value: usize, width: usize) void {
        for (0..width) |bit| {
            if ((value >> @intCast(bit)) & 1 != 0) self.setBit(self.bits);
            self.bits += 1;
        }
    }

    fn len(self: *const Wire) usize {
        return (self.bits + 7) / 8;
    }

    fn body(self: *Wire, bytes: []const u8) void {
        const start = self.len();
        @memcpy(self.bytes[start..][0..bytes.len], bytes);
        self.bits = (start + bytes.len) * 8;
    }

    fn header(self: *Wire, body_len: usize, final: bool, count: usize) void {
        self.put(@intFromBool(final), 1);
        if (final) self.put(0, 1); // ISLASTEMPTY.
        self.put(3, 2); // Metadata MNIBBLES code.
        self.put(0, 1); // Reserved.
        self.put(count, 2);
        self.put(body_len -| 1, count * 8);
    }

    fn block(self: *Wire, bytes: []const u8, final: bool) void {
        self.header(bytes.len, final, @intFromBool(bytes.len != 0));
        self.body(bytes);
    }

    fn stored(self: *Wire, bytes: []const u8) void {
        self.put(0, 1); // Nonfinal.
        self.put(0, 2); // Four length nibbles.
        self.put(bytes.len - 1, 16);
        self.put(1, 1); // Uncompressed.
        self.body(bytes);
    }
};

const Log = struct {
    expected: []const []const u8,
    starts: usize = 0,
    offset: usize = 0,
    failure: ?anyerror = null,

    fn observer(self: *Log) metadata.Observer {
        return .{ .context = self, .on_event = onEvent };
    }

    fn onEvent(context: ?*anyopaque, event: metadata.Event) void {
        const self: *Log = @ptrCast(@alignCast(context.?));
        if (self.failure == null) self.record(event) catch |err| {
            self.failure = err;
        };
    }

    fn record(self: *Log, event: metadata.Event) !void {
        switch (event) {
            .start => |start| {
                try expect(self.starts < self.expected.len);
                try self.check(self.starts);
                try equal(@as(Count, self.starts), start.block_index);
                try equal(self.expected[self.starts].len, start.len);
                try equal(self.starts + 1 == self.expected.len, start.final);
                self.starts += 1;
                self.offset = 0;
            },
            .chunk => |chunk| {
                try expect(self.starts != 0);
                const bytes = self.expected[self.starts - 1];
                try equal(@as(Count, self.starts - 1), chunk.block_index);
                try equal(self.offset, chunk.offset);
                try expect(chunk.bytes.len != 0 and chunk.bytes.len <= bytes.len - self.offset);
                try slicesEqual(u8, bytes[self.offset..][0..chunk.bytes.len], chunk.bytes);
                self.offset += chunk.bytes.len;
            },
        }
    }

    fn check(self: *const Log, complete: usize) !void {
        if (self.failure) |err| return err;
        try equal(complete, self.starts);
        try equal(if (complete == 0) 0 else self.expected[complete - 1].len, self.offset);
    }
};

const Capture = struct {
    bytes: [7]u8 = @splat(byte_canary),
    lengths: [5]usize = @splat(length_canary),

    fn check(self: *const Capture, bytes: []const u8, lengths: []const usize) !void {
        var expected: Capture = .{};
        @memcpy(expected.bytes[1..][0..bytes.len], bytes);
        @memcpy(expected.lengths[1..][0..lengths.len], lengths);
        try slicesEqual(u8, &expected.bytes, &self.bytes);
        try slicesEqual(usize, &expected.lengths, &self.lengths);
    }
};

const Limits = struct { bytes: Count, blocks: Count };

fn Suite(comptime Br: type, comptime flavor: Flavor) type {
    const Decoder = switch (flavor) {
        .owned => Br.IncrementalStreamDecoder,
        .copy => Br.IncrementalCopyStreamDecoder,
        .literal => Br.IncrementalLiteralStreamDecoder,
        .stored => Br.IncrementalStoredStreamDecoder,
    };
    const prologue = if (flavor == .literal) "hello" else "";

    return struct {
        fn options(plain_len: usize, limits: ?Limits, log: ?*Log, captures: ?*Capture) Decoder.Options {
            var opts: Decoder.Options = .{ .max_output_len = plain_len };
            if (flavor != .stored) opts.expected_output_len = plain_len;
            if (flavor == .owned or flavor == .copy) opts.max_total_output_len = plain_len * 2;
            if (flavor == .owned) opts.max_working_memory = plain_len;
            if (limits) |cap| {
                opts.max_metadata_bytes = cap.bytes;
                opts.max_metadata_blocks = cap.blocks;
            }
            if (log) |events| opts.metadata_observer = events.observer();
            if (captures) |fixed| {
                opts.metadata_output = fixed.bytes[1..6];
                opts.metadata_block_lengths = fixed.lengths[1..4];
            }
            return opts;
        }

        fn init(opts: Decoder.Options, history: []u8, allocator: std.mem.Allocator) Decoder {
            return switch (flavor) {
                .owned => Decoder.initWithOptions(allocator, opts),
                .copy => Decoder.initWithOptions(history, opts),
                .literal, .stored => Decoder.initWithOptions(opts),
            };
        }

        fn feed(decoder: *Decoder, input: []const u8, stride: usize, output: []u8, end: core.StepResult.Status) !void {
            var read: usize = 0;
            var written: usize = 0;
            while (true) {
                const offered = input[read..][0..@min(stride, input.len - read)];
                const result = try decoder.step(offered, output[written..]);
                try expect(result.progress.input_read <= offered.len);
                try expect(result.progress.output_written <= output.len - written);
                read += result.progress.input_read;
                written += result.progress.output_written;
                if (result.status == .done or (read == input.len and result.status == .need_input)) {
                    try equal(end, result.status);
                    try equal(input.len, read);
                    try equal(output.len, written);
                    return;
                }
                try expect(result.progress.input_read != 0 or result.progress.output_written != 0);
            }
        }

        fn checkCapture(decoder: *const Decoder, fixed: *const Capture, bytes: []const u8, lengths: []const usize) !void {
            const snap = if (flavor == .owned) decoder.progressive.?.snapshot() else decoder.snapshot();
            try equal(@as(Count, bytes.len), snap.metadata_total);
            try equal(@as(Count, lengths.len), snap.metadata_block_count);
            try equal(bytes.len, snap.metadata_written);
            try equal(lengths.len, snap.metadata_blocks_captured);
            try expect(!snap.metadata_truncated and !snap.metadata_blocks_truncated);
            try fixed.check(bytes, lengths);
        }

        fn reject(decoder: *Decoder, err: anyerror, input: []const u8, header_bytes: usize, plain_len: usize) !void {
            const before = decoder.diagnostics();
            var output: [4]u8 = @splat(byte_canary);
            try std.testing.expectError(err, decoder.step(input, output[1..3]));
            const after = decoder.diagnostics();
            try equal(before.frame_input_read.? + header_bytes, after.frame_input_read);
            try equal(@as(Count, plain_len), after.output_written);
            try equal(core.Progress{ .input_read = header_bytes }, after.last_step_progress);
            try slicesEqual(u8, @errorName(err), after.last_error_name);
            try expect(std.mem.allEqual(u8, &output, byte_canary));
        }

        fn aggregate() !void {
            const defaults: Decoder.Options = .{};
            try equal(Count, @TypeOf(defaults.max_metadata_bytes));
            try equal(Count, @TypeOf(defaults.max_metadata_blocks));
            try equal(unlimited, defaults.max_metadata_bytes);
            try equal(unlimited, defaults.max_metadata_blocks);

            const plain = prologue ++ "tail";
            var wire = Wire.init(flavor == .literal);
            wire.block("abc", false);
            wire.block("", false);
            wire.stored("tail");
            const last_start = wire.len();
            wire.block("de", true);
            const data = wire.bytes[0..wire.len()];
            const blocks = &.{ "abc", "", "de" };

            for ([_]?Limits{ null, .{ .bytes = 5, .blocks = 3 }, .{ .bytes = 4, .blocks = 3 }, .{ .bytes = 5, .blocks = 2 } }) |limits| {
                var log: Log = .{ .expected = blocks };
                var fixed: Capture = .{};
                var history: [plain.len + 2]u8 = @splat(byte_canary);
                const opts = options(plain.len, limits, &log, &fixed);
                var decoder = init(opts, history[1..][0..plain.len], std.testing.allocator);
                defer if (flavor == .owned) decoder.deinit();
                var output: [plain.len + 2]u8 = @splat(byte_canary);
                const dest = output[1..][0..plain.len];
                try feed(&decoder, data[0..last_start], 1, dest, .need_input);
                try slicesEqual(u8, plain, dest);
                try log.check(2);
                try checkCapture(&decoder, &fixed, "abc", &.{ 3, 0 });
                if (limits != null and (limits.?.bytes == 4 or limits.?.blocks == 2)) {
                    // Give the decoder the entire final block. Only its header
                    // may be consumed, and the remaining byte/length slots
                    // must not be filled or published.
                    const old_history = history;
                    try reject(&decoder, error.OutputLimitExceeded, data[last_start..], data.len - last_start - 2, plain.len);
                    try log.check(2);
                    try checkCapture(&decoder, &fixed, "abc", &.{ 3, 0 });
                    try slicesEqual(u8, &old_history, &history);
                } else {
                    try feed(&decoder, data[last_start..], 1, &.{}, .done);
                    try decoder.finish();
                    try log.check(3);
                    try checkCapture(&decoder, &fixed, "abcde", &.{ 3, 0, 2 });
                    if (limits != null) try lifecycle(&decoder, opts, &log, &fixed, data, dest, plain);
                }
                try equal(byte_canary, output[0]);
                try equal(byte_canary, output[output.len - 1]);
                try equal(byte_canary, history[0]);
                try equal(byte_canary, history[history.len - 1]);
            }
        }

        fn lifecycle(decoder: *Decoder, opts: Decoder.Options, log: *Log, fixed: *Capture, data: []const u8, dest: []u8, plain: []const u8) !void {
            // Retained options and capture storage, but fresh per-stream quotas.
            decoder.reset();
            log.* = .{ .expected = log.expected };
            fixed.* = .{};
            @memset(dest, byte_canary);
            try feed(decoder, data, data.len, dest, .done);
            try decoder.finish();
            try slicesEqual(u8, plain, dest);
            try log.check(3);
            try checkCapture(decoder, fixed, "abcde", &.{ 3, 0, 2 });

            if (flavor == .literal) return; // This API exposes only reset.
            if (flavor == .stored) try decoder.nextStream(opts) else try decoder.nextFrame(opts);
            log.* = .{ .expected = log.expected };
            fixed.* = .{};
            @memset(dest, byte_canary);
            try feed(decoder, data, 1, dest, .done);
            try decoder.finish();
            try slicesEqual(u8, plain, dest);
            try log.check(3);
            try checkCapture(decoder, fixed, "abcde", &.{ 3, 0, 2 });
        }

        fn emptyBlocks() !void {
            var wire = Wire.init(flavor == .literal);
            wire.block("", false);
            const split = wire.len();
            wire.block("", true);
            const data = wire.bytes[0..wire.len()];
            const Cases = enum { exact, short, short_unselected };
            for (std.enums.values(Cases)) |case| {
                var log: Log = .{ .expected = &.{ "", "" } };
                var fixed: Capture = .{};
                var history: [prologue.len]u8 = undefined;
                // Quotas also apply when metadata is neither observed nor captured.
                const selected = case != .short_unselected;
                const limits: Limits = .{ .bytes = 0, .blocks = if (case == .exact) 2 else 1 };
                const opts = options(prologue.len, limits, if (selected) &log else null, if (selected) &fixed else null);
                var decoder = init(opts, &history, std.testing.failing_allocator);
                defer if (flavor == .owned) decoder.deinit();
                var output: [prologue.len]u8 = undefined;
                try feed(&decoder, data[0..split], 1, &output, .need_input);
                try slicesEqual(u8, prologue, &output);
                if (selected) {
                    try log.check(1);
                    try checkCapture(&decoder, &fixed, "", &.{0});
                }
                switch (case) {
                    .exact => {
                        try feed(&decoder, data[split..], 1, &.{}, .done);
                        try decoder.finish();
                        try log.check(2);
                        try checkCapture(&decoder, &fixed, "", &.{ 0, 0 });
                    },
                    .short, .short_unselected => {
                        try reject(&decoder, error.OutputLimitExceeded, data[split..], data.len - split, prologue.len);
                        if (selected) {
                            try log.check(1);
                            try checkCapture(&decoder, &fixed, "", &.{0});
                        } else {
                            const snap = if (flavor == .owned) decoder.progressive.?.snapshot() else decoder.snapshot();
                            try equal(@as(Count, 0), snap.metadata_total);
                            try equal(@as(Count, 1), snap.metadata_block_count);
                            try equal(@as(usize, 0), snap.metadata_blocks_captured);
                        }
                    },
                }
            }
        }

        fn headerAdmission() !void {
            const Case = enum { header_only, offered_body, reserved, overlong, padding };
            for (std.enums.values(Case)) |case| {
                var wire = Wire.init(flavor == .literal);
                const start_bit = wire.bits;
                const max_len = Br.max_metadata_meta_block_len;
                wire.header(if (case == .overlong) 3 else max_len, false, if (case == .overlong) 2 else 3);
                const header_end = wire.len();
                if (case == .reserved) wire.setBit(start_bit + 3);
                if (case == .padding) {
                    try expect(wire.bits % 8 != 0);
                    wire.setBit(wire.bits);
                }
                if (case != .header_only) wire.body("unread");
                const data = wire.bytes[0..wire.len()];
                var log: Log = .{ .expected = &.{} };
                var fixed: Capture = .{};
                const valid = case == .header_only or case == .offered_body;
                var history: [prologue.len]u8 = undefined;
                const opts = options(prologue.len, .{ .bytes = if (valid) max_len - 1 else 0, .blocks = if (valid) 1 else 0 }, &log, &fixed);
                var decoder = init(opts, &history, std.testing.failing_allocator);
                defer if (flavor == .owned) decoder.deinit();
                var output: [prologue.len]u8 = undefined;
                if (case == .reserved) {
                    try std.testing.expectError(error.CorruptFrame, decoder.step(data, &output));
                } else {
                    // Withhold the final length/alignment byte: even zero
                    // block credit must not fail a still-incomplete header.
                    const split = header_end - 1;
                    try feed(&decoder, data[0..split], 1, &output, .need_input);
                    try slicesEqual(u8, prologue, &output);
                    try feed(&decoder, "", 1, &.{}, .need_input);
                    try log.check(0);
                    try checkCapture(&decoder, &fixed, "", &.{});
                    try reject(&decoder, if (valid) error.OutputLimitExceeded else error.CorruptFrame, data[split..], 1, prologue.len);
                }
                try log.check(0);
                try checkCapture(&decoder, &fixed, "", &.{});
                if (flavor == .owned) try equal(@as(usize, 0), decoder.peakWorkingMemoryBytes());
            }
        }
    };
}
