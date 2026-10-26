const std = @import("std");
const core = @import("../../../core.zig");
const h = @import("helpers.zig");

pub fn run(comptime Z: type) type {
    return struct {
        const E = Z.NativeIncrementalParallelFrameEncoder;

        test "Zstd parallel incremental header drains before input ownership or worker startup" {
            for ([_]Z.FrameFormat{ .standard, .magicless }) |format| {
                var opts = h.options(Z);
                opts.frame.format = format;
                opts.frame.selection = .raw_or_rle;
                var encoder = try E.init(h.a, opts);
                defer encoder.deinit();
                const zero = try h.checked(Z, &encoder, opts, "abc", &.{});
                try std.testing.expectEqual(core.Progress{}, zero.progress);
                try std.testing.expectEqual(core.StepResult.Status.need_output, zero.status);
                try std.testing.expectEqual(@as(h.Count, 0), encoder.snapshot().input_read);
                try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().parallel.profile.workers_started);
                var encoded: std.ArrayList(u8) = .empty;
                defer encoded.deinit(h.a);
                const header_len = h.headerLen(opts.frame, null, 0);
                const input = "abc";
                var input_read: usize = 0;
                for (0..header_len) |i| {
                    var output: [1]u8 = undefined;
                    const before = encoder.snapshot();
                    const step = try h.checked(Z, &encoder, opts, input[input_read..], &output);
                    const after = encoder.snapshot();
                    try std.testing.expectEqual(core.stream_count.fromLocal(i), before.output_written);
                    try std.testing.expectEqual(core.stream_count.fromLocal(i + 1), after.output_written);
                    try std.testing.expectEqual(@as(usize, 1), step.progress.output_written);
                    try encoded.appendSlice(h.a, &output);
                    if (after.output_written < core.stream_count.fromLocal(header_len)) {
                        try std.testing.expectEqual(@as(usize, 0), step.progress.input_read);
                        try std.testing.expectEqual(@as(h.Count, 0), after.input_read);
                        try std.testing.expectEqual(@as(usize, 0), after.parallel.profile.workers_started);
                        try std.testing.expectEqual(@as(usize, 0), after.parallel.owned_input_bytes);
                    }
                    // Delivery of the final Header byte opens admission in the
                    // same call; advance that accepted prefix exactly once.
                    if (step.progress.input_read != 0) try std.testing.expect(after.output_written >= core.stream_count.fromLocal(header_len));
                    input_read += step.progress.input_read;
                }
                const accepted = try h.checked(Z, &encoder, opts, input[input_read..], &.{});
                input_read += accepted.progress.input_read;
                try std.testing.expectEqual(input.len, input_read);
                encoder.finish();
                try h.drain(Z, &encoder, opts, &encoded, .done, 1);
                const wire = try h.verify(Z, encoded.items, "abc", opts.frame, null);
                try h.complete(encoder.snapshot(), opts, 3, wire.blocks);
            }
        }

        test "Zstd parallel incremental all native selections preserve one frame under tiny owned IO" {
            const structured = h.fixture(513);
            const inputs = [_][]const u8{ "", "x", structured[0..31], &structured };
            for ([_]Z.FrameFormat{ .standard, .magicless }) |format| {
                for ([_]Z.NativeFrameSelection{ .auto, .raw_or_rle, .literal_only, .fast_compressed }) |selection| {
                    for (inputs) |input| {
                        var opts = h.options(Z);
                        opts.frame.format = format;
                        opts.frame.selection = selection;
                        var encoder = try E.init(h.a, opts);
                        defer encoder.deinit();
                        const bytes = try h.drive(Z, &encoder, opts, input, 13, 1);
                        defer h.a.free(bytes);
                        const wire = try h.verify(Z, bytes, input, opts.frame, null);
                        try h.complete(encoder.snapshot(), opts, input.len, wire.blocks);
                        try std.testing.expectEqual(@as(h.Count, 1), encoder.snapshot().frame_count);
                        const done = try h.checked(Z, &encoder, opts, "", &.{});
                        try std.testing.expectEqual(core.StepResult.Status.done, done.status);
                    }
                }
            }
        }

        test "Zstd parallel incremental ten explicit strategies preserve unknown and exact size frames" {
            const input = h.fixture(513);
            const strategies = [_]Z.Strategy{ .fast, .double_fast, .greedy, .lazy, .optimal, .lazy2, .btlazy2, .btopt, .btultra, .btultra2 };
            for (strategies) |strategy| {
                for ([_]bool{ false, true }) |known| {
                    var opts = h.options(Z);
                    opts.frame.selection = .auto;
                    opts.frame.strategy = strategy;
                    opts.frame.include_content_size = known;
                    var encoder = if (known) try E.initExactSize(h.a, opts, input.len) else try E.init(h.a, opts);
                    defer encoder.deinit();
                    const bytes = try h.drive(Z, &encoder, opts, &input, 257, 3);
                    defer h.a.free(bytes);
                    const wire = try h.verify(Z, bytes, &input, opts.frame, null);
                    try h.complete(encoder.snapshot(), opts, input.len, wire.blocks);
                }
            }
        }

        test "Zstd parallel incremental legacy beam and complete HQ keep their actual settings" {
            const input = ("b" ++ "a" ** 64 ++ "c" ++ "a" ** 64) ** 4;
            var beam = h.options(Z);
            beam.frame.rep_beam_search = true;
            var legacy = try E.init(h.a, beam);
            defer legacy.deinit();
            const legacy_bytes = try h.drive(Z, &legacy, beam, input, 23, 3);
            defer h.a.free(legacy_bytes);
            _ = try h.verify(Z, legacy_bytes, input, beam.frame, null);
            for ([_]Z.Strategy{ .btopt, .btultra, .btultra2 }) |strategy| {
                var opts = h.options(Z);
                opts.frame.strategy = strategy;
                opts.frame.selection = .auto;
                opts.frame.hq = .{ .parse_mode = .whole_block, .match_lengths = .complete };
                var encoder = try E.init(h.a, opts);
                defer encoder.deinit();
                const bytes = try h.drive(Z, &encoder, opts, input, 29, 1);
                defer h.a.free(bytes);
                const wire = try h.verify(Z, bytes, input, opts.frame, null);
                try h.complete(encoder.snapshot(), opts, input.len, wire.blocks);
            }
        }

        test "Zstd parallel incremental full job waits for a valid seal and finish adds no empty block" {
            var opts = h.options(Z);
            opts.frame.selection = .raw_or_rle;
            var input: [256]u8 = undefined;
            h.noise(&input, 0x51ac);
            var encoder = try E.init(h.a, opts);
            defer encoder.deinit();
            var bytes: std.ArrayList(u8) = .empty;
            defer bytes.deinit(h.a);
            try h.header(Z, &encoder, opts, null, &bytes);
            const accepted = try h.checked(Z, &encoder, opts, &input, &.{});
            try std.testing.expectEqual(input.len, accepted.progress.input_read);
            try std.testing.expectEqual(@as(h.Count, 1), encoder.snapshot().parallel.profile.accepted_jobs);
            var output: [64]u8 = undefined;
            const waiting = try h.checked(Z, &encoder, opts, "", &output);
            try std.testing.expectEqual(core.Progress{}, waiting.progress);
            try std.testing.expectEqual(core.StepResult.Status.need_input, waiting.status);
            try std.testing.expectEqual(@as(h.Count, 0), encoder.snapshot().parallel.profile.encoded_jobs);
            try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().parallel.active_jobs);
            encoder.finish();
            try h.drain(Z, &encoder, opts, &bytes, .done, 1);
            const wire = try h.verify(Z, bytes.items, &input, opts.frame, null);
            try std.testing.expectEqual(@as(usize, 2), wire.blocks);
            try std.testing.expectEqual(@as(usize, 128), wire.last_payload_size);
            try std.testing.expectEqual(@as(h.Count, 1), encoder.snapshot().parallel.profile.delivered_jobs);
        }

        test "Zstd parallel incremental raw RLE fragments share one terminal job and checksum" {
            var input: [256]u8 = undefined;
            h.noise(&input, 0xc44a);
            @memset(input[33..81], 'q');
            var opts = h.options(Z);
            opts.frame.selection = .raw_or_rle;
            var encoder = try E.init(h.a, opts);
            defer encoder.deinit();
            const bytes = try h.drive(Z, &encoder, opts, &input, 257, 1);
            defer h.a.free(bytes);
            const wire = try h.verify(Z, bytes, &input, opts.frame, null);
            try std.testing.expect(wire.raw != 0 and wire.rle != 0 and wire.blocks > 2);
            try std.testing.expect(wire.last_payload_size != 0);
            try std.testing.expectEqual(@as(h.Count, 1), encoder.snapshot().parallel.profile.delivered_jobs);
        }

        test "Zstd parallel incremental one job credit seals from unaccepted valid lookahead" {
            const input = h.fixture(513);
            var opts = h.options(Z);
            opts.frame.selection = .raw_or_rle;
            opts.parallel.max_inflight_jobs = 1;
            opts.parallel.max_inflight_bytes = 256;
            var encoder = try E.init(h.a, opts);
            defer encoder.deinit();
            const bytes = try h.drive(Z, &encoder, opts, &input, 257, 1);
            defer h.a.free(bytes);
            const wire = try h.verify(Z, bytes, &input, opts.frame, null);
            try std.testing.expectEqual(@as(usize, 5), wire.blocks);
            try std.testing.expectEqual(@as(usize, 1), wire.last_payload_size);
            try std.testing.expectEqual(@as(h.Count, 3), encoder.snapshot().parallel.profile.delivered_jobs);
            try std.testing.expectEqual(@as(usize, 1), encoder.snapshot().parallel.profile.peak_inflight_jobs);
        }

        test "Zstd parallel incremental flush is idempotent and finish after flush emits one empty final" {
            var opts = h.options(Z);
            opts.frame.selection = .raw_or_rle;
            var encoder = try E.init(h.a, opts);
            defer encoder.deinit();
            var bytes: std.ArrayList(u8) = .empty;
            defer bytes.deinit(h.a);
            try h.feed(Z, &encoder, opts, &bytes, "flush-boundary", 7, 3);
            encoder.flush();
            encoder.flush();
            try h.drain(Z, &encoder, opts, &bytes, .need_input, 1);
            const flushed_len = bytes.items.len;
            const flushed_jobs = encoder.snapshot().parallel.profile.delivered_jobs;
            encoder.flush();
            try h.drain(Z, &encoder, opts, &bytes, .need_input, 3);
            try std.testing.expectEqual(flushed_len, bytes.items.len);
            try std.testing.expectEqual(flushed_jobs, encoder.snapshot().parallel.profile.delivered_jobs);
            encoder.finish();
            encoder.finish();
            try h.drain(Z, &encoder, opts, &bytes, .done, 1);
            const wire = try h.verify(Z, bytes.items, "flush-boundary", opts.frame, null);
            try std.testing.expectEqual(@as(usize, 2), wire.blocks);
            try std.testing.expectEqual(@as(usize, 0), wire.last_payload_size);
            try std.testing.expectEqual(flushed_jobs + 1, encoder.snapshot().parallel.profile.delivered_jobs);
        }

        test "Zstd parallel incremental queued predecessors remain matching history after caller overwrite" {
            var input: [1025]u8 = undefined;
            h.noise(input[0..256], 0x95164);
            for (1..4) |i| @memcpy(input[i * 256 ..][0..256], input[0..256]);
            input[1024] = '!';
            var work: Z.EncoderControlProfile = .{};
            var opts = h.options(Z);
            opts.frame.strategy = .greedy;
            opts.frame.selection = .auto;
            opts.frame.control_profile = &work;
            var encoder = try E.init(h.a, opts);
            defer encoder.deinit();
            var bytes: std.ArrayList(u8) = .empty;
            defer bytes.deinit(h.a);
            try h.header(Z, &encoder, opts, null, &bytes);
            var borrowed: [1024]u8 = input[0..1024].*;
            const accepted = try h.checked(Z, &encoder, opts, &borrowed, &.{});
            try std.testing.expectEqual(borrowed.len, accepted.progress.input_read);
            @memset(&borrowed, 0xdd);
            const waiting = encoder.snapshot();
            try std.testing.expect(waiting.parallel.inflight_jobs >= 3);
            try std.testing.expectEqualDeep(Z.EncoderControlProfile.Emitted{}, work.emitted());
            try h.feed(Z, &encoder, opts, &bytes, input[1024..], 1, 1);
            encoder.finish();
            try h.drain(Z, &encoder, opts, &bytes, .done, 3);
            const wire = try h.verify(Z, bytes.items, &input, opts.frame, null);
            try h.complete(encoder.snapshot(), opts, input.len, wire.blocks);
            try std.testing.expect(work.history_sequences != 0);
        }

        test "Zstd parallel incremental raw ID zero full dictionary and catalog routes preserve seams" {
            var dictionary_bytes: [256]u8 = undefined;
            h.noise(&dictionary_bytes, 0x73214);
            var input: [513]u8 = undefined;
            @memcpy(input[0..256], &dictionary_bytes);
            @memcpy(input[256..512], &dictionary_bytes);
            input[512] = 'z';
            const full_bytes = try h.full_dictionary(h.a);
            defer h.a.free(full_bytes);
            const dictionaries = [_]Z.NativeDictionary{ Z.NativeDictionary.init(0x1234, &dictionary_bytes), Z.NativeDictionary.initRawContent(&dictionary_bytes), (try Z.NativeDictionary.initFromStandardDictionary(full_bytes)).dictionary };
            const inputs = [_][]const u8{ &input, &input, ("b" ++ "a" ** 64 ++ "c" ++ "a" ** 64) ** 4 };
            for (dictionaries, inputs) |dictionary, plain| {
                var work: Z.EncoderControlProfile = .{};
                var opts = h.options(Z);
                opts.frame.selection = .auto;
                opts.frame.strategy = .btultra2;
                opts.frame.dictionary_id = dictionary.id;
                opts.frame.control_profile = &work;
                var encoder = try E.initWithPresetDictionary(h.a, opts, dictionary);
                defer encoder.deinit();
                const bytes = try h.drive(Z, &encoder, opts, plain, 17, 1);
                defer h.a.free(bytes);
                _ = try h.verify(Z, bytes, plain, opts.frame, dictionary);
                try std.testing.expect(work.dictionary_sequences != 0);
                if (dictionary.id == 0) {
                    try std.testing.expectError(error.NeedDictionary, Z.NativeDictionarySet.initChecked(&.{dictionary}));
                    const unchecked = Z.NativeDictionarySet.init(&.{dictionary});
                    try std.testing.expectError(error.NeedDictionary, E.initWithDictionarySet(h.a, opts, unchecked, 0));
                    var exact_opts = opts;
                    exact_opts.frame.include_content_size = true;
                    try std.testing.expectError(error.NeedDictionary, E.initExactSizeWithDictionarySet(h.a, exact_opts, plain.len, unchecked, 0));
                    const before = encoder.snapshot();
                    try std.testing.expectError(error.NeedDictionary, encoder.nextFrameWithDictionarySet(opts, unchecked, 0));
                    try std.testing.expectEqualDeep(before, encoder.snapshot());
                    try std.testing.expectError(error.NeedDictionary, encoder.nextFrameExactSizeWithDictionarySet(exact_opts, plain.len, unchecked, 0));
                    try std.testing.expectEqualDeep(before, encoder.snapshot());
                    try std.testing.expectEqual(opts.frame.include_content_size, encoder.options.frame.include_content_size);
                    try std.testing.expectEqual(opts.frame.dictionary_id, encoder.options.frame.dictionary_id);
                    try std.testing.expectEqual(opts.parallel.job_size, encoder.options.parallel.job_size);
                    continue;
                }
                const set = try Z.NativeDictionarySet.initChecked(&.{dictionary});
                var catalog = try E.initWithDictionarySet(h.a, opts, set, dictionary.id);
                defer catalog.deinit();
                const selected = try h.drive(Z, &catalog, opts, plain, 257, 3);
                defer h.a.free(selected);
                try std.testing.expectEqualSlices(u8, bytes, selected);
            }
        }

        test "Zstd parallel incremental exact single segment window constrains dictionary matching" {
            var dictionary_bytes: [256]u8 = undefined;
            h.noise(&dictionary_bytes, 0x54876);
            const dictionary = Z.NativeDictionary.init(0x2143, &dictionary_bytes);
            const plain = dictionary_bytes[192..256];
            for ([_]Z.NativeFrameSelection{ .auto, .raw_or_rle, .literal_only, .fast_compressed }) |selection| {
                var opts = h.options(Z);
                opts.frame.include_content_size = true;
                opts.frame.dictionary_id = dictionary.id;
                opts.frame.selection = selection;
                opts.frame.block_size_max = 32;
                opts.parallel.job_size = 32;
                var encoder = try E.initExactSizeWithPresetDictionary(h.a, opts, plain.len, dictionary);
                defer encoder.deinit();
                const bytes = try h.drive(Z, &encoder, opts, plain, 13, 1);
                defer h.a.free(bytes);
                const wire = try h.verify(Z, bytes, plain, opts.frame, dictionary);
                try std.testing.expectEqual(@as(u64, plain.len), wire.window_size);
            }
        }

        test "Zstd parallel incremental format block geometry is independent of a smaller matching history cap" {
            // One byte above an explicit 1 MiB window forces the same
            // non-Single-Segment header boundary without making every Debug
            // suite process thousands of otherwise identical raw Jobs.
            const large_len = 1024 * 1024 + 1;
            const input = try h.a.alloc(u8, large_len);
            defer h.a.free(input);
            // A byte cycle contains no adjacent repeats, so raw/RLE selection
            // exposes the physical raw block lengths without incidental splits.
            for (input, 0..) |*byte, i| byte.* = @truncate(i);
            const Row = struct { len: usize, known: bool };
            for ([_]Row{ .{ .len = 8193, .known = false }, .{ .len = large_len, .known = true }, .{ .len = 100, .known = true } }) |row| {
                var opts = h.options(Z);
                opts.frame.window_log = 20;
                opts.frame.max_match_history_len = 1024;
                opts.frame.block_size_max = 8192;
                opts.frame.selection = .raw_or_rle;
                opts.frame.include_content_size = row.known;
                opts.parallel.job_size = 8192;
                opts.parallel.max_inflight_bytes = 4 * 8192;
                const plain = input[0..row.len];
                var encoder = if (row.known) try E.initExactSize(h.a, opts, row.len) else try E.init(h.a, opts);
                defer encoder.deinit();
                const bytes = try h.drive(Z, &encoder, opts, plain, 257, 257);
                defer h.a.free(bytes);
                const wire = try h.envelope(Z, bytes, plain, opts.frame, 0);
                try std.testing.expectEqual(@as(usize, @min(8192, row.len)), wire.max_payload_size);
                try std.testing.expectEqual(@as(usize, 0), wire.rle);
                try std.testing.expectEqual(@as(usize, 0), wire.compressed);
                try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().parallel.history_window_len);
                try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().parallel.logical_history_bytes);
                const small_single = row.len == 100;
                try std.testing.expectEqual(small_single, bytes[4] & 0x20 != 0);
                try std.testing.expectEqual(@as(u64, if (small_single) 100 else 1024 * 1024), wire.window_size);
                if (!small_single) try std.testing.expectEqual(@as(usize, 8192), encoder.snapshot().parallel.profile.effective_job_size);
                try h.complete(encoder.snapshot(), opts, plain.len, wire.blocks);

                const native_decoded = try Z.decodeFrameAllocWithOptions(h.a, bytes, .{});
                defer h.a.free(native_decoded);
                try std.testing.expectEqualSlices(u8, plain, native_decoded);
                // The independent standard-library decoder must be given the
                // advertised window, even for these entirely raw block rows.
                var source: std.Io.Reader = .fixed(bytes);
                var output: std.Io.Writer.Allocating = .init(h.a);
                defer output.deinit();
                var decoder: std.compress.zstd.Decompress = .init(&source, &.{}, .{ .window_len = @intCast(wire.window_size) });
                _ = try decoder.reader.streamRemaining(&output.writer);
                try std.testing.expectEqualSlices(u8, plain, output.written());
            }
        }
    };
}
