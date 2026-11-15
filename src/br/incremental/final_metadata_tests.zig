//! RFC 7932 final metadata keeps ISLAST even when MNIBBLES = 3.
//! Upstream tests/testdata/empty.compressed.15 (1a) and .16 (81160058),
//! and independently packed lengths through 65537, were checked with
//! libbrotlidec 1.0.9: SUCCESS, no unused input, empty decoded content.
const std = @import("std");
const a = std.testing.allocator;

pub fn contracts(comptime B: type) !void {
    const S = Suite(B);
    try S.upstreamAndCompressed();
    try S.lengthsAndTransitions();
    try S.trailingAndLimits();
    try S.malformed();
    try S.literalTrailer();
    try S.nextFrames();
}

// Independent LSB writer: no production Brotli encoder or size helper.
const Wire = struct {
    bytes: std.ArrayList(u8) = .empty,
    bits: usize = 0,

    fn put(self: *Wire, value: usize, width: usize) !void {
        for (0..width) |bit| {
            if (self.bits % 8 == 0) try self.bytes.append(a, 0);
            self.bytes.items[self.bits / 8] |= @as(u8, @intCast((value >> @intCast(bit)) & 1)) << @intCast(self.bits % 8);
            self.bits += 1;
        }
    }
    fn alignByte(self: *Wire) void {
        self.bits = self.bytes.items.len * 8;
    }
    fn body(self: *Wire, bytes: []const u8) !void {
        self.alignByte();
        try self.bytes.appendSlice(a, bytes);
        self.bits += bytes.len * 8;
    }
    fn metadata(self: *Wire, bytes: []const u8, final: bool) !void {
        try self.put(@intFromBool(final), 1);
        if (final) try self.put(0, 1); // ISLASTEMPTY.
        try self.put(3, 2); // MNIBBLES.
        try self.put(0, 1); // Reserved.
        const width: usize = if (bytes.len == 0) 0 else if (bytes.len <= 256) 1 else if (bytes.len <= 65536) 2 else 3;
        try self.put(width, 2);
        try self.put(bytes.len -| 1, width * 8);
        try self.body(bytes);
    }
    fn stored(self: *Wire, bytes: []const u8) !void {
        try self.put(0, 1);
        try self.put(0, 2);
        try self.put(bytes.len - 1, 16);
        try self.put(1, 1);
        try self.body(bytes);
    }
    fn stream(bytes: []const u8, final: bool, plain: []const u8) ![]u8 {
        var wire: Wire = .{};
        errdefer wire.bytes.deinit(a);
        try wire.put(0, 1); // WBITS = 16.
        if (plain.len != 0) try wire.stored(plain);
        try wire.metadata(bytes, final);
        if (!final) {
            try wire.put(1, 1);
            try wire.put(1, 1);
        }
        return wire.bytes.toOwnedSlice(a);
    }
};

fn Suite(comptime B: type) type {
    return struct {
        fn decoderType(comptime owned: bool) type {
            return if (owned) B.IncrementalStreamDecoder else B.IncrementalCopyStreamDecoder;
        }

        noinline fn incremental(comptime owned: bool, wire: []const u8, plain: []const u8, metadata: []const u8, blocks: usize, split: usize, stride: usize, known: bool, capture_limit: usize) !void {
            const output = try a.alloc(u8, plain.len + 2);
            defer a.free(output);
            @memset(output, 0xa5);
            const history = try a.alloc(u8, plain.len);
            defer a.free(history);
            const captured = try a.alloc(u8, @min(capture_limit, metadata.len) + 2);
            defer a.free(captured);
            @memset(captured, 0x9b);
            var lengths: [2]usize = @splat(0xaaaa);
            var opts: decoderType(owned).Options = .{
                .expected_output_len = plain.len,
                .max_output_len = plain.len,
                .max_total_output_len = plain.len,
                .metadata_output = captured[1 .. captured.len - 1],
                .metadata_block_lengths = lengths[0..1],
            };
            if (owned) opts.expected_compressed_len = if (known) wire.len else null;
            var decoder = if (owned) blk: {
                var bounded = opts;
                bounded.max_working_memory = plain.len;
                break :blk decoderType(owned).initWithOptions(a, bounded);
            } else decoderType(owned).initWithOptions(history, opts);
            defer if (owned) decoder.deinit();
            const empty = try decoder.step("", &.{});
            try std.testing.expectEqual(@as(usize, 0), empty.progress.input_read);
            var read: usize = 0;
            var written: usize = 0;
            var end = @min(wire.len, split);
            for (0..wire.len * 3 + plain.len * 3 + 16) |_| {
                const step = try decoder.step(wire[read..end], output[1 + written .. @min(output.len - 1, written + 2)]);
                read += step.progress.input_read;
                written += step.progress.output_written;
                if (step.status == .done) break;
                try std.testing.expect(step.progress.input_read != 0 or step.progress.output_written != 0 or end == 0);
                end = @min(wire.len, read + stride);
            } else return error.TestUnexpectedResult;
            try decoder.finish();
            try std.testing.expectEqual(wire.len, read);
            try std.testing.expectEqual(plain.len, written);
            try std.testing.expectEqualSlices(u8, plain, output[1 .. output.len - 1]);
            try std.testing.expectEqual(@as(u8, 0xa5), output[0]);
            try std.testing.expectEqual(@as(u8, 0xa5), output[output.len - 1]);
            const snap = if (owned) decoder.progressive.?.snapshot() else decoder.snapshot();
            try std.testing.expectEqual(@as(B.Counter, metadata.len), snap.metadata_total);
            try std.testing.expectEqual(@as(B.Counter, blocks), snap.metadata_block_count);
            try std.testing.expectEqual(metadata.len > captured.len - 2, snap.metadata_truncated);
            try std.testing.expectEqual(blocks > 1, snap.metadata_blocks_truncated);
            try std.testing.expectEqualSlices(u8, metadata[0 .. captured.len - 2], captured[1 .. captured.len - 1]);
            try std.testing.expectEqual(@as(u8, 0x9b), captured[0]);
            try std.testing.expectEqual(@as(u8, 0x9b), captured[captured.len - 1]);
            if (blocks == 1) try std.testing.expectEqual(metadata.len, lengths[0]);
            if (owned) try std.testing.expect(decoder.peakWorkingMemoryBytes() <= plain.len);
        }

        fn oneShot(wire: []const u8, plain: []const u8, metadata_len: usize, blocks: usize, empty_blocks: usize) !void {
            const decoded = try B.decodeStreamAllocLimited(a, wire, plain.len);
            defer a.free(decoded);
            try std.testing.expectEqualSlices(u8, plain, decoded);
            const exact = try B.decodeStreamAllocExactSize(a, wire, plain.len);
            defer a.free(exact);
            try std.testing.expectEqualSlices(u8, plain, exact);
            const configured = try B.decodeStreamAllocExactSizeWithOptions(a, wire, plain.len, .{ .allow_large_window = true });
            defer a.free(configured);
            try std.testing.expectEqualSlices(u8, plain, configured);
            const output = try a.alloc(u8, plain.len + 2);
            defer a.free(output);
            @memset(output, 0xa5);
            try std.testing.expectEqual(plain.len, try B.decodeStreamInto(wire, output[1 .. output.len - 1]));
            try std.testing.expectEqual(plain.len, try B.decodeStreamIntoExactSizeWithOptions(wire, output[1 .. output.len - 1], plain.len, .{ .allow_large_window = true }));
            try std.testing.expectEqual(@as(u8, 0xa5), output[0]);
            try std.testing.expectEqual(@as(u8, 0xa5), output[output.len - 1]);
            var append: std.ArrayList(u8) = .empty;
            defer append.deinit(a);
            try append.append(a, 0x9b);
            try std.testing.expectEqual(plain.len, try B.decodeStreamAppendExactSize(a, &append, wire, plain.len));
            try std.testing.expectEqualSlices(u8, plain, append.items[1..]);
            try std.testing.expectEqual(@as(B.Counter, plain.len), try B.decodedStreamSizeLimited(wire, plain.len));
            var diagnostics: B.StreamSummaryDiagnostics = undefined;
            const summary = try B.summarizeStreamLimitedWithDiagnostics(wire, plain.len, &diagnostics);
            try std.testing.expectEqual(wire.len, summary.input_bytes);
            try std.testing.expectEqual(@as(B.Counter, blocks), summary.metadata_meta_block_count);
            try std.testing.expectEqual(@as(B.Counter, metadata_len), summary.metadata_bytes);
            try std.testing.expectEqual(@as(B.Counter, empty_blocks), summary.empty_meta_block_count);
            const history_summary = try B.summarizeStreamLimitedWithHistory(wire, output[1 .. output.len - 1], plain.len);
            try std.testing.expectEqualDeep(summary, history_summary);
            const allocated_summary = try B.summarizeStreamAllocLimited(a, wire, plain.len);
            try std.testing.expectEqualDeep(summary, allocated_summary);
            var report = try B.diagnoseMetaBlocksAlloc(std.testing.io, a, wire, .{ .max_output_len = plain.len });
            defer report.deinit(a);
            try std.testing.expectEqualSlices(u8, plain, report.output);
            try std.testing.expectEqual(.metadata, report.records[report.records.len - 1].kind);
            try std.testing.expectEqual(@as(B.BitCount, wire.len - @intFromBool(empty_blocks != 0)) * 8, report.records[report.records.len - 1].payload_end);
            if (plain.len == 0) {
                const budgeted = try B.decodeStreamAllocExactSizeWithOptions(std.testing.failing_allocator, wire, 0, .{ .max_total_working_memory = 0 });
                defer std.testing.failing_allocator.free(budgeted);
                try std.testing.expectEqual(@as(usize, 0), budgeted.len);
                const budget_summary = try B.summarizeStreamAllocLimitedWithOptions(a, wire, 0, .{ .max_total_working_memory = 0 });
                try std.testing.expectEqualDeep(summary, budget_summary);
                const inspected = try B.IncrementalTestSupport.inspectHqLegacyWire(a, wire, .{ .quality = 10, .hq = .{}, .window_bits = summary.window_bits }, 0);
                try std.testing.expect(inspected != null);
            }
        }

        fn upstreamAndCompressed() !void {
            const cases = [_]struct { wire: []const u8, plain: []const u8, metadata: []const u8 }{
                .{ .wire = "\x1a", .plain = "", .metadata = "" },
                .{ .wire = "\x81\x16\x00\x58", .plain = "", .metadata = "X" },
                .{ .wire = "\x5a\x00\x58", .plain = "", .metadata = "X" },
                .{ .wire = "\x10\x01\x00\x80\x80\x87\x2c\x55\xb9\x7e\x13\x6d\x54\x75\x88\x40\x71\x02\x81\x10\x8d\xa7\xd8\x00\x0d", .plain = "functional payload", .metadata = "" },
                .{ .wire = "\x10\x01\x00\x80\x80\x87\x2c\x55\xb9\x7e\x13\x6d\x54\x75\x88\x40\x71\x02\x81\x10\x8d\xa7\xd8\x00\x2d\x00\x58", .plain = "functional payload", .metadata = "X" },
            };
            for (cases) |case| {
                const blocks: usize = if (case.plain.len == 0) 1 else 2;
                try oneShot(case.wire, case.plain, case.metadata.len, blocks, 0);
                for (0..case.wire.len + 1) |split| {
                    inline for (.{ false, true }) |owned| {
                        try incremental(owned, case.wire, case.plain, case.metadata, blocks, split, 1, false, case.metadata.len);
                        try incremental(owned, case.wire, case.plain, case.metadata, blocks, split, 7, true, case.metadata.len);
                    }
                }
            }
        }

        fn lengthsAndTransitions() !void {
            const metadata = try a.alloc(u8, 65537);
            defer a.free(metadata);
            for (metadata, 0..) |*byte, i| byte.* = @truncate(i * 13 + 5);
            for ([_]usize{ 0, 1, 255, 256, 257, 65535, 65536, 65537 }) |len| {
                for ([_]bool{ false, true }) |final| {
                    const wire = try Wire.stream(metadata[0..len], final, "");
                    defer a.free(wire);
                    try oneShot(wire, "", len, 1, @intFromBool(!final));
                    inline for (.{ false, true }) |owned| {
                        for ([_]usize{ 0, 1, 2, wire.len - 1, wire.len }) |split|
                            try incremental(owned, wire, "", metadata[0..len], 1, split, 31, true, @min(7, len));
                        try incremental(owned, wire, "", metadata[0..len], 1, 0, 1, false, len);
                    }
                    if (final) try storedCapture(wire, metadata[0..len]);
                }
            }
            // Keep the reference compressed payload, then enlarge only final
            // opaque metadata so both default and optioned large decode run.
            const compressed = "\x10\x01\x00\x80\x80\x87\x2c\x55\xb9\x7e\x13\x6d\x54\x75\x88\x40\x71\x02\x81\x10\x8d\xa7\xd8\x00\x0d";
            var compressed_report = try B.diagnoseMetaBlocksAlloc(std.testing.io, a, compressed, .{});
            defer compressed_report.deinit(a);
            const final_start: usize = @intCast(compressed_report.records[compressed_report.records.len - 1].header_start);
            var large: Wire = .{};
            defer large.bytes.deinit(a);
            for (0..final_start) |bit| try large.put((compressed[bit / 8] >> @intCast(bit % 8)) & 1, 1);
            try large.metadata(metadata[0..16384], true);
            try oneShot(large.bytes.items, "functional payload", 16384, 2, 0);
            inline for (.{ false, true }) |owned|
                try incremental(owned, large.bytes.items, "functional payload", metadata[0..16384], 2, 1, 31, true, 7);

            var wire: Wire = .{};
            defer wire.bytes.deinit(a);
            try wire.put(0, 1);
            try wire.metadata("first", false);
            try wire.stored("payload");
            try wire.metadata("", false);
            try wire.metadata("last", true);
            try oneShot(wire.bytes.items, "payload", 9, 3, 0);
            inline for (.{ false, true }) |owned|
                try incremental(owned, wire.bytes.items, "payload", "firstlast", 3, 0, 1, false, 7);
        }

        fn storedCapture(wire: []const u8, metadata: []const u8) !void {
            const capture = try a.alloc(u8, metadata.len);
            defer a.free(capture);
            var lengths: [1]usize = undefined;
            var decoder = B.IncrementalStoredStreamDecoder.initWithOptions(.{ .max_output_len = 0, .metadata_output = capture, .metadata_block_lengths = &lengths });
            var read: usize = 0;
            while (read < wire.len) {
                const step = try decoder.step(wire[read..@min(wire.len, read + 1)], &.{});
                read += step.progress.input_read;
                try std.testing.expect(step.progress.input_read != 0 or step.status == .done);
            }
            try decoder.finish();
            try std.testing.expectEqualSlices(u8, metadata, capture);
            try std.testing.expectEqual(metadata.len, lengths[0]);
            try std.testing.expectEqual(@as(B.Counter, 1), decoder.snapshot().metadata_block_count);
        }

        noinline fn failure(comptime owned: bool, wire: []const u8, err: B.Error, options: decoderType(owned).Options, finish_error: bool) !void {
            var history: [32]u8 = undefined;
            var decoder = if (owned) decoderType(owned).initWithOptions(a, options) else decoderType(owned).initWithOptions(&history, options);
            defer if (owned) decoder.deinit();
            var output: [32]u8 = undefined;
            if (finish_error) {
                _ = try decoder.step(wire, &output);
                try std.testing.expectError(err, decoder.finish());
            } else try std.testing.expectError(err, decoder.step(wire, &output));
            try std.testing.expectError(err, decoder.step(wire, &output));
            try std.testing.expectError(err, decoder.finish());
        }

        noinline fn trailing(comptime owned: bool, wire: []const u8) !void {
            var history: [1]u8 = undefined;
            var decoder = if (owned) decoderType(owned).initWithOptions(a, .{ .allow_trailing_data = true, .expected_output_len = 0, .max_working_memory = 0 }) else decoderType(owned).initWithOptions(&history, .{ .allow_trailing_data = true, .expected_output_len = 0 });
            defer if (owned) decoder.deinit();
            const step = try decoder.step(wire, &.{});
            try std.testing.expectEqual(.done, step.status);
            try std.testing.expectEqual(@as(usize, 1), step.progress.input_read);
            try decoder.finish();
        }

        fn trailingAndLimits() !void {
            for ([_][]const u8{ "\x1a\x03", "\x1a\xa5" }) |wire| {
                try std.testing.expectError(error.TrailingData, B.decodeStreamAlloc(a, wire));
                try std.testing.expectError(error.TrailingData, B.decodeStreamInto(wire, &.{}));
                try std.testing.expectError(error.TrailingData, B.decodeStreamIntoExactSize(wire, &.{}, 0));
                try std.testing.expectError(error.TrailingData, B.summarizeStream(wire));
                try std.testing.expectError(error.TrailingData, B.diagnoseMetaBlocksAlloc(std.testing.io, a, wire, .{ .max_output_len = 0 }));
                const prefix = try B.decodeStreamPrefixAllocExactSize(a, wire, 0);
                defer a.free(prefix.bytes);
                try std.testing.expectEqual(@as(usize, 1), prefix.input_read);
                try std.testing.expectEqual(@as(usize, 1), (try B.decodeStreamPrefixIntoExactSize(wire, &.{}, 0)).input_read);
                try std.testing.expectEqual(@as(usize, 1), (try B.decodedStreamPrefixSize(wire)).input_read);
                var scratch: [2]u8 = undefined;
                const chunks = [_][]const u8{ wire[0..1], "", wire[1..] };
                try std.testing.expectEqual(@as(usize, 1), (try B.decodeStreamPrefixChunksIntoExactSize(&chunks, &scratch, &.{}, 0)).input_read);
                inline for (.{ false, true }) |owned| {
                    try failure(owned, wire, error.TrailingData, .{ .expected_output_len = 0 }, false);
                    try trailing(owned, wire);
                }
            }
            try std.testing.expectError(error.SizeMismatch, B.decodeStreamAllocExactSize(a, "\x1a", 1));
            inline for (.{ false, true }) |owned| {
                try failure(owned, "\x1a", error.SizeMismatch, .{ .expected_output_len = 1 }, false);
                if (owned) {
                    try failure(owned, "\x5a\x00X", error.OutputLimitExceeded, .{ .max_compressed_len = 2 }, false);
                    try failure(owned, "\x5a\x00X", error.SizeMismatch, .{ .expected_compressed_len = 2 }, false);
                }
            }
        }

        fn malformed() !void {
            const cases = [_]struct { wire: []const u8, err: B.Error, truncated: bool }{
                .{ .wire = "\x3a", .err = error.CorruptFrame, .truncated = false }, // Reserved.
                .{ .wire = "\x5a", .err = error.TruncatedFrame, .truncated = true }, // Length.
                .{ .wire = "\x5a\x00", .err = error.TruncatedFrame, .truncated = true }, // Body.
                .{ .wire = "\x9a\x00\x00X", .err = error.CorruptFrame, .truncated = false }, // Overlong length.
                .{ .wire = "\x81\x16\x40X", .err = error.CorruptFrame, .truncated = false }, // Padding.
            };
            for (cases) |case| {
                try std.testing.expectError(case.err, B.decodeStreamAlloc(a, case.wire));
                var diagnostic: B.StreamSummaryDiagnostics = undefined;
                try std.testing.expectError(case.err, B.summarizeStreamWithDiagnostics(case.wire, &diagnostic));
                try std.testing.expectEqual(.metadata_meta_block, diagnostic.phase);
                inline for (.{ false, true }) |owned|
                    try failure(owned, case.wire, case.err, .{ .expected_output_len = 0 }, case.truncated);
            }
            const nonfinal = "\x2c\x00X";
            try std.testing.expectError(error.TruncatedFrame, B.decodeStreamAlloc(a, nonfinal));
            inline for (.{ false, true }) |owned|
                try failure(owned, nonfinal, error.TruncatedFrame, .{ .expected_output_len = 0 }, true);
        }

        fn literalTrailer() !void {
            // Existing independent compressed-literal fixture supplies a
            // nonfinal hello block. Replace its metadata header bit by bit.
            const legacy = try B.IncrementalTestSupport.encodeCompressedHelloThenMetadataAndStoredBlocks(a, "X", &.{"tail"});
            defer a.free(legacy);
            var report = try B.diagnoseMetaBlocksAlloc(std.testing.io, a, legacy, .{});
            defer report.deinit(a);
            const start: usize = @intCast(report.records[1].header_start);
            for ([_][]const u8{ "", "X" }) |metadata| {
                var wire: Wire = .{};
                defer wire.bytes.deinit(a);
                for (0..start) |bit| try wire.put((legacy[bit / 8] >> @intCast(bit % 8)) & 1, 1);
                try wire.metadata(metadata, true);
                var decoder = B.IncrementalLiteralStreamDecoder.initWithOptions(.{ .expected_output_len = 5 });
                var capture: [1]u8 = undefined;
                decoder.metadata_output = capture[0..metadata.len];
                var output: [5]u8 = undefined;
                var read: usize = 0;
                var written: usize = 0;
                for (0..wire.bytes.items.len * 3) |_| {
                    const step = try decoder.step(wire.bytes.items[read..@min(wire.bytes.items.len, read + 1)], output[written..@min(output.len, written + 1)]);
                    read += step.progress.input_read;
                    written += step.progress.output_written;
                    if (step.status == .done) break;
                } else return error.TestUnexpectedResult;
                try decoder.finish();
                try std.testing.expectEqualSlices(u8, "hello", &output);
                try std.testing.expectEqualSlices(u8, metadata, capture[0..metadata.len]);
                try std.testing.expectEqual(@as(B.Counter, 1), decoder.snapshot().metadata_block_count);
            }
        }

        noinline fn nextFrame(comptime owned: bool) !void {
            var history: [1]u8 = undefined;
            var decoder = if (owned) decoderType(owned).initWithOptions(a, .{ .expected_output_len = 0, .max_working_memory = 0 }) else decoderType(owned).initWithOptions(&history, .{ .expected_output_len = 0 });
            defer if (owned) decoder.deinit();
            _ = try decoder.step("\x1a", &.{});
            try decoder.finish();
            try decoder.nextFrame(.{ .expected_output_len = 0 });
            _ = try decoder.step("\x5a\x00X", &.{});
            try decoder.finish();
            const snap = decoder.snapshot();
            try std.testing.expectEqual(@as(B.Counter, 2), snap.frame_count);
            try std.testing.expectEqual(@as(B.Counter, 4), snap.total_compressed);
            decoder.reset();
            _ = try decoder.step("\x1a", &.{});
            try decoder.finish();
            try std.testing.expectEqual(@as(B.Counter, 1), decoder.snapshot().frame_count);
        }
        fn nextFrames() !void {
            inline for (.{ false, true }) |owned| try nextFrame(owned);
        }
    };
}
