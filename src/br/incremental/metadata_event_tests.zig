const std = @import("std");
const core = @import("../../core.zig");
const expect = std.testing.expect;
const eql = std.testing.expectEqual;
const bytesEqual = std.testing.expectEqualSlices;
const allocator = std.testing.allocator;

const Flavor = enum { owned, copy, literal, stored };

pub fn contracts(comptime Br: type) !void {
    inline for (std.enums.values(Flavor)) |flavor| {
        const S = Suite(Br, flavor);
        try S.mixed();
        try S.maximum();
        try S.truncated();
        try S.malformed();
        try S.lifecycle();
    }
    try Suite(Br, .owned).compressedHistory();
    try Suite(Br, .copy).compressedHistory();
}

// Independent RFC 7932 bit packing. The frozen 105-bit prefix encodes a
// WBITS=16 stream with a nonfinal, insert-only compressed block for "hello".
const Wire = struct {
    const hello = "\x40\x00\x00\x00\x34\x5a\x19\xdb\x9b\x40\x21\x00\xa9\x01";
    bytes: std.ArrayList(u8) = .empty,
    bits: usize = 0,

    fn init(literal: bool) !Wire {
        var wire: Wire = .{};
        errdefer wire.deinit();
        if (literal) {
            try wire.bytes.appendSlice(allocator, hello);
            wire.bits = 105;
        } else try wire.put(0, 1); // WBITS = 16.
        return wire;
    }

    fn deinit(self: *Wire) void {
        self.bytes.deinit(allocator);
    }

    fn put(self: *Wire, value: usize, width: usize) !void {
        for (0..width) |bit| {
            if (self.bits % 8 == 0) try self.bytes.append(allocator, 0);
            if ((value >> @intCast(bit)) & 1 != 0) self.setBit(self.bits);
            self.bits += 1;
        }
    }

    fn setBit(self: *Wire, bit: usize) void {
        self.bytes.items[bit / 8] |= @as(u8, 1) << @intCast(bit % 8);
    }

    fn body(self: *Wire, bytes: []const u8) !void {
        // The unused high bits of the last header byte are zero padding.
        try self.bytes.appendSlice(allocator, bytes);
        self.bits = self.bytes.items.len * 8;
    }

    fn metadataHeader(self: *Wire, len: usize, final: bool, count: usize) !void {
        try self.put(@intFromBool(final), 1);
        if (final) try self.put(0, 1); // ISLASTEMPTY.
        try self.put(3, 2); // Metadata MNIBBLES code.
        try self.put(0, 1); // Reserved.
        try self.put(count, 2);
        try self.put(len -| 1, count * 8);
    }

    fn metadata(self: *Wire, bytes: []const u8, final: bool) !void {
        const count: usize = if (bytes.len == 0) 0 else if (bytes.len <= 256) 1 else 2;
        try self.metadataHeader(bytes.len, final, count);
        try self.body(bytes);
    }

    fn stored(self: *Wire, bytes: []const u8) !void {
        try self.put(0, 1); // Nonfinal.
        try self.put(0, 2); // Four length nibbles.
        try self.put(bytes.len - 1, 16);
        try self.put(1, 1); // Uncompressed.
        try self.body(bytes);
    }
};

const Block = struct {
    bytes: []const u8,
    final: bool = false,
    // For a truncated valid block, bytes is only the accepted prefix.
    declared_len: ?usize = null,
};

fn Recorder(comptime Decoder: type) type {
    return struct {
        expected: []const Block,
        starts: usize = 0,
        chunks: usize = 0,
        offset: usize = 0,
        failure: ?anyerror = null,

        const Self = @This();

        fn observer(self: *Self) Decoder.MetadataObserver {
            return .{ .context = self, .on_event = onEvent };
        }

        fn onEvent(context: ?*anyopaque, event: Decoder.MetadataEvent) void {
            const self: *Self = @ptrCast(@alignCast(context.?));
            if (self.failure == null) self.record(event) catch |err| {
                self.failure = err;
            };
        }

        fn record(self: *Self, event: Decoder.MetadataEvent) !void {
            switch (event) {
                .start => |start| {
                    try expect(self.starts < self.expected.len);
                    if (self.starts != 0)
                        try eql(self.expected[self.starts - 1].bytes.len, self.offset);
                    const block = self.expected[self.starts];
                    try eql(@as(core.StreamCount, self.starts), start.block_index);
                    try eql(block.declared_len orelse block.bytes.len, start.len);
                    try eql(block.final, start.final);
                    self.starts += 1;
                    self.offset = 0;
                },
                .chunk => |chunk| {
                    try expect(self.starts != 0);
                    try eql(@as(core.StreamCount, self.starts - 1), chunk.block_index);
                    try eql(self.offset, chunk.offset);
                    const body = self.expected[self.starts - 1].bytes;
                    try expect(chunk.bytes.len != 0 and chunk.bytes.len <= body.len - self.offset);
                    // Compare in the callback; the borrowed slice is never retained.
                    try bytesEqual(u8, body[self.offset..][0..chunk.bytes.len], chunk.bytes);
                    self.offset += chunk.bytes.len;
                    self.chunks += 1;
                },
            }
        }

        fn seen(self: *const Self, starts: usize, offset: usize) !void {
            if (self.failure) |err| return err;
            try eql(starts, self.starts);
            try eql(offset, self.offset);
        }
    };
}

fn Suite(comptime Br: type, comptime flavor: Flavor) type {
    const Decoder = switch (flavor) {
        .owned => Br.IncrementalStreamDecoder,
        .copy => Br.IncrementalCopyStreamDecoder,
        .literal => Br.IncrementalLiteralStreamDecoder,
        .stored => Br.IncrementalStoredStreamDecoder,
    };
    const Log = Recorder(Decoder);
    const prologue = if (flavor == .literal) "hello" else "";

    return struct {
        fn options(log: *Log, plain_len: usize) Decoder.Options {
            var opts: Decoder.Options = .{ .metadata_observer = log.observer(), .max_output_len = plain_len };
            if (flavor != .stored) opts.expected_output_len = plain_len;
            if (flavor == .owned or flavor == .copy) opts.max_total_output_len = plain_len;
            return opts;
        }

        fn init(opts: Decoder.Options, history: []u8) Decoder {
            return switch (flavor) {
                .owned => Decoder.initWithOptions(allocator, opts),
                .copy => Decoder.initWithOptions(history, opts),
                .literal, .stored => Decoder.initWithOptions(opts),
            };
        }

        fn step(decoder: *Decoder, input: []const u8, output: []u8) !core.StepResult {
            const result = try decoder.step(input, output);
            try expect(result.progress.input_read <= input.len);
            try expect(result.progress.output_written <= output.len);
            try eql(result.progress, decoder.diagnostics().last_step_progress);
            return result;
        }

        // Reoffer only unconsumed input and use one-byte plaintext buffers,
        // or zero-byte buffers for metadata-only segments.
        fn feed(decoder: *Decoder, input: []const u8, stride: usize, output: []u8, end_status: core.StepResult.Status) !void {
            var read: usize = 0;
            var written: usize = 0;
            for (0..input.len + output.len + 2) |_| {
                const result = try step(decoder, input[read..][0..@min(stride, input.len - read)], output[written..][0..@min(1, output.len - written)]);
                read += result.progress.input_read;
                written += result.progress.output_written;
                if (result.status == .done or (read == input.len and result.status == .need_input)) {
                    try eql(end_status, result.status);
                    try eql(input.len, read);
                    try eql(output.len, written);
                    return;
                }
                try expect(result.progress.input_read != 0 or result.progress.output_written != 0);
            }
            return error.TestUnexpectedResult;
        }

        fn idle(decoder: *Decoder, log: *const Log, status: core.StepResult.Status) !void {
            const seen = log.*;
            for (0..3) |_| {
                const result = try step(decoder, "", &.{});
                try eql(status, result.status);
                try eql(core.Progress{}, result.progress);
                try log.seen(seen.starts, seen.offset);
                try eql(seen.chunks, log.chunks);
            }
        }

        fn capture(decoder: *const Decoder, total: usize, blocks: usize, written: usize, lengths: usize) !void {
            const snap = if (flavor == .owned) decoder.progressive.?.snapshot() else decoder.snapshot();
            try eql(@as(core.StreamCount, total), snap.metadata_total);
            try eql(@as(core.StreamCount, blocks), snap.metadata_block_count);
            try eql(written, snap.metadata_written);
            try eql(lengths, snap.metadata_blocks_captured);
            try eql(total > written, snap.metadata_truncated);
            try eql(blocks > lengths, snap.metadata_blocks_truncated);
        }

        fn mixed() !void {
            // Deliberately larger than the capture and the owned facade's
            // input subdivisions. Do not require a particular chunk sizing.
            var long: [5003]u8 = undefined;
            for (&long, 0..) |*byte, i| byte.* = @truncate(i * 13 + i / 251);
            for ([_]usize{ 1, 29, long.len }) |stride| {
                const last = if (stride == 29) "" else "end";
                var wire = try Wire.init(flavor == .literal);
                defer wire.deinit();
                try wire.metadata(&long, false);
                const body_start = wire.bytes.items.len - long.len;
                try wire.metadata("", false);
                const stored_start = wire.bytes.items.len;
                try wire.stored("tail");
                const final_start = wire.bytes.items.len;
                try wire.metadata(last, true);
                const data = wire.bytes.items;

                var log: Log = .{ .expected = &.{ .{ .bytes = &long }, .{ .bytes = "" }, .{ .bytes = last, .final = true } } };
                var fixed: [5]u8 = @splat(0xa5);
                var lengths: [4]usize = @splat(0xaaaa);
                const plain_len = prologue.len + 4;
                var opts = options(&log, plain_len);
                if (flavor == .owned) {
                    opts.expected_compressed_len = data.len;
                    opts.max_working_memory = plain_len;
                }
                opts.metadata_output = fixed[1..4];
                opts.metadata_block_lengths = lengths[1..3];
                var history: [plain_len]u8 = undefined;
                var decoder = init(opts, &history);
                defer if (flavor == .owned) decoder.deinit();

                var head: [prologue.len]u8 = undefined;
                try idle(&decoder, &log, .need_input);
                try feed(&decoder, data[0 .. body_start - 1], stride, &head, .need_input);
                try bytesEqual(u8, prologue, &head);
                try log.seen(0, 0);
                try idle(&decoder, &log, .need_input);
                try feed(&decoder, data[body_start - 1 .. body_start], stride, &.{}, .need_input);
                try log.seen(1, 0);
                try capture(&decoder, 0, 0, 0, 0);
                try idle(&decoder, &log, .need_input);
                try feed(&decoder, data[body_start .. body_start + 7], stride, &.{}, .need_input);
                try log.seen(1, 7);
                try capture(&decoder, 7, 0, 3, 0);
                try idle(&decoder, &log, .need_input);
                try feed(&decoder, data[body_start + 7 .. stored_start], stride, &.{}, .need_input);
                try log.seen(2, 0);

                var tail: [4]u8 = undefined;
                try feed(&decoder, data[stored_start..final_start], stride, &tail, .need_input);
                try bytesEqual(u8, "tail", &tail);
                try feed(&decoder, data[final_start..], stride, &.{}, .done);
                try decoder.finish();
                try log.seen(3, last.len);
                try idle(&decoder, &log, .done);
                try capture(&decoder, long.len + last.len, 3, 3, 2);
                try bytesEqual(u8, &.{ 0xa5, long[0], long[1], long[2], 0xa5 }, &fixed);
                try std.testing.expectEqualSlices(usize, &.{ 0xaaaa, long.len, 0, 0xaaaa }, &lengths);
                const progress = decoder.diagnostics();
                try eql(@as(core.StreamCount, data.len), progress.frame_input_read);
                try eql(@as(core.StreamCount, plain_len), progress.output_written);
                if (flavor == .owned or flavor == .copy) try eql(plain_len, decoder.snapshot().history_bytes);
            }
        }

        fn maximum() !void {
            const max_len = Br.max_metadata_meta_block_len;
            const byte = 0x5a;
            const Sink = struct {
                started: bool = false,
                seen: usize = 0,
                valid: bool = true,

                fn onEvent(context: ?*anyopaque, event: Decoder.MetadataEvent) void {
                    const sink: *@This() = @ptrCast(@alignCast(context.?));
                    switch (event) {
                        .start => |start| {
                            sink.valid = sink.valid and !sink.started and start.block_index == 0 and start.final and start.len == max_len;
                            sink.started = true;
                        },
                        .chunk => |chunk| {
                            sink.valid = sink.valid and sink.started and chunk.block_index == 0 and chunk.offset == sink.seen and
                                chunk.bytes.len != 0 and std.mem.allEqual(u8, chunk.bytes, byte);
                            sink.seen += chunk.bytes.len;
                        },
                    }
                }
            };
            var header = try Wire.init(flavor == .literal);
            defer header.deinit();
            try header.metadataHeader(max_len, true, 3);
            var sink: Sink = .{};
            var opts: Decoder.Options = .{
                .metadata_observer = .{ .context = &sink, .on_event = Sink.onEvent },
                .max_output_len = prologue.len,
            };
            if (flavor != .stored) opts.expected_output_len = prologue.len;
            if (flavor == .owned) opts.max_working_memory = 0;
            var history: [prologue.len]u8 = undefined;
            var decoder = init(opts, &history);
            defer if (flavor == .owned) decoder.deinit();

            var output: [prologue.len]u8 = undefined;
            try feed(&decoder, header.bytes.items, 1, &output, .need_input);
            try bytesEqual(u8, prologue, &output);
            try expect(sink.started and sink.seen == 0);
            // Reuse one small slice rather than allocating the announced size.
            const chunk: [8192]u8 = @splat(byte);
            var sent: usize = 0;
            while (sent < max_len) {
                const n = @min(chunk.len, max_len - sent);
                sent += n;
                try feed(&decoder, chunk[0..n], n, &.{}, if (sent == max_len) .done else .need_input);
            }
            try decoder.finish();
            try expect(sink.valid);
            try eql(max_len, sink.seen);
            try capture(&decoder, max_len, 1, 0, 0);
            if (flavor == .owned) try eql(@as(usize, 0), decoder.peakWorkingMemoryBytes());
        }

        fn truncated() !void {
            for ([_][]const u8{ "", "abc" }) |prefix| {
                var wire = try Wire.init(flavor == .literal);
                defer wire.deinit();
                try wire.metadataHeader(9, true, 1);
                try wire.body(prefix);
                var log: Log = .{ .expected = &.{.{ .bytes = prefix, .declared_len = 9, .final = true }} };
                var fixed: [2]u8 = @splat(0xa5);
                var lengths: [1]usize = .{0xaaaa};
                var opts = options(&log, prologue.len);
                opts.metadata_output = &fixed;
                opts.metadata_block_lengths = &lengths;
                var history: [prologue.len]u8 = undefined;
                var decoder = init(opts, &history);
                defer if (flavor == .owned) decoder.deinit();
                var output: [prologue.len]u8 = undefined;
                try feed(&decoder, wire.bytes.items, 1, &output, .need_input);
                try bytesEqual(u8, prologue, &output);
                try log.seen(1, prefix.len);
                try idle(&decoder, &log, .need_input);
                try std.testing.expectError(error.TruncatedFrame, decoder.finish());
                try log.seen(1, prefix.len);
                const written = @min(prefix.len, fixed.len);
                try capture(&decoder, prefix.len, 0, written, 0);
                try bytesEqual(u8, prefix[0..written], fixed[0..written]);
                if (written == 0) try bytesEqual(u8, &.{ 0xa5, 0xa5 }, &fixed);
                try eql(@as(usize, 0xaaaa), lengths[0]);
            }
        }

        fn malformed() !void {
            const Invalid = enum { reserved, overlong, padding, truncated_length };
            for (std.enums.values(Invalid)) |invalid| {
                var wire = try Wire.init(flavor == .literal);
                defer wire.deinit();
                const start = wire.bits;
                // Nonfinal headers at this bit position have one alignment bit.
                try wire.metadataHeader(if (invalid == .truncated_length) 257 else 3, false, if (invalid == .overlong or invalid == .truncated_length) 2 else 1);
                const padding = wire.bits;
                try wire.body("xyz");
                if (invalid == .reserved) wire.setBit(start + 3);
                if (invalid == .padding) wire.setBit(padding);
                const end = (padding + 7) / 8;

                var log: Log = .{ .expected = &.{} };
                var fixed: [2]u8 = @splat(0xa5);
                var lengths: [1]usize = .{0xaaaa};
                var opts = options(&log, prologue.len);
                opts.metadata_output = &fixed;
                opts.metadata_block_lengths = &lengths;
                var history: [prologue.len]u8 = undefined;
                var decoder = init(opts, &history);
                defer if (flavor == .owned) decoder.deinit();
                var output: [prologue.len]u8 = undefined;
                // For reserved-bit corruption the first header bits already
                // fail. Otherwise withhold the last (length/alignment) byte.
                const split = if (invalid == .reserved) start / 8 else end - 1;
                if (invalid != .reserved) {
                    try feed(&decoder, wire.bytes.items[0..split], 1, &output, .need_input);
                    try bytesEqual(u8, prologue, &output);
                    try log.seen(0, 0);
                    try idle(&decoder, &log, .need_input);
                }
                if (invalid == .truncated_length) {
                    try std.testing.expectError(error.TruncatedFrame, decoder.finish());
                } else if (invalid == .reserved) {
                    try std.testing.expectError(error.CorruptFrame, decoder.step(wire.bytes.items, &output));
                } else {
                    try std.testing.expectError(error.CorruptFrame, decoder.step(wire.bytes.items[split..], &.{}));
                }
                try log.seen(0, 0);
                try capture(&decoder, 0, 0, 0, 0);
                try bytesEqual(u8, &.{ 0xa5, 0xa5 }, &fixed);
                try eql(@as(usize, 0xaaaa), lengths[0]);
            }
        }

        fn lifecycle() !void {
            var wire = try Wire.init(flavor == .literal);
            defer wire.deinit();
            const plain = if (flavor == .literal) prologue else "prior";
            if (flavor != .literal) try wire.stored(plain);
            try wire.metadata("A", false);
            try wire.metadata("", true);
            const data = wire.bytes.items;
            const first: []const Block = &.{ .{ .bytes = "A" }, .{ .bytes = "", .final = true } };
            var log: Log = .{ .expected = first };
            var history: [plain.len]u8 = undefined;
            var decoder = init(options(&log, plain.len), &history);
            defer if (flavor == .owned) decoder.deinit();
            var output: [plain.len]u8 = undefined;
            for (0..2) |_| {
                try feed(&decoder, data, 1, &output, .done);
                try decoder.finish();
                try bytesEqual(u8, plain, &output);
                try log.seen(2, 0);
                try capture(&decoder, 1, 2, 0, 0);
                decoder.reset();
                try log.seen(2, 0); // Reset is not an event and retains the observer.
                log = .{ .expected = first };
            }
            if (flavor != .literal) {
                try feed(&decoder, data, data.len, &output, .done);
                try decoder.finish();
                var second: Log = .{ .expected = &.{.{ .bytes = "X", .final = true }} };
                // Only metadata in the next frame, with no plaintext space or
                // quota left. RFC upstream fixture empty.compressed.16.
                const next = "\x81\x16\x00X";
                var next_options = options(&second, 0);
                if (flavor == .owned or flavor == .copy) {
                    next_options.max_total_output_len = plain.len;
                    try decoder.nextFrame(next_options);
                } else try decoder.nextStream(next_options);
                try feed(&decoder, next, 1, &.{}, .done);
                try decoder.finish();
                try log.seen(2, 0); // The previous observer was replaced.
                try second.seen(1, 1); // Block index and byte offset restarted at zero.
                try capture(&decoder, 1, 1, 0, 0);
                const snap = decoder.snapshot();
                try eql(@as(core.StreamCount, 2), if (flavor == .stored) snap.stream_count else snap.frame_count);
                try eql(@as(core.StreamCount, data.len + next.len), if (flavor == .stored) snap.stream_input else snap.total_compressed);
                try eql(@as(core.StreamCount, plain.len), if (flavor == .stored) snap.stream_output else snap.total_output);
            }
        }

        fn compressedHistory() !void {
            // Cross-checked with libbrotlidec: compressed block inserts 'a'
            // and copies at distance 1; after metadata, a second compressed
            // block copies at recent distance + 1. Ends with empty metadata.
            const wire = "\x20\x00\x00\x04\x44\x58\x21\x02\x48\x41\x0a\x5b\x00M\x08\x00\x00\x02\x22\xac\x10\x01\xa4\x20\x05\x1a";
            var log: Log = .{ .expected = &.{ .{ .bytes = "M" }, .{ .bytes = "", .final = true } } };
            var history: [5]u8 = undefined;
            var decoder = init(options(&log, 5), &history);
            defer if (flavor == .owned) decoder.deinit();
            var output: [5]u8 = undefined;
            try feed(&decoder, wire, 1, &output, .done);
            try decoder.finish();
            try bytesEqual(u8, "aaaaa", &output);
            try log.seen(2, 0);
            try capture(&decoder, 1, 2, 0, 0);
        }
    };
}
