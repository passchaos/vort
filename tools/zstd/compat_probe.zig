const std = @import("std");
const vort = @import("vort");
const libzstd = @import("libzstd_runtime.zig");

const levels = [_]c_int{ 1, 3, 9, 19, 22 };
const sizes = [_]usize{ 0, 1, 15, 64, 255, 1024, 8192, 65536, 131073, 524288 };
const optional_golden_root = "../../Work/zstd/tests/golden-decompression";

const Shape = enum { text, structured, binary, random };
const Coverage = struct {
    max_sequence_count: usize = 0,
    max_block_count: usize = 0,
    sequence_count_tiers: u3 = 0,
    sequence_mode_combinations: u64 = 0,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    var decodecorpus_frames: ?[]const u8 = null;
    var decodecorpus_plain: ?[]const u8 = null;
    var decodecorpus_count: usize = 0;
    var decodecorpus_dictionary_path: ?[]const u8 = null;
    var prior_mode_mask: u64 = 0;
    var require_complete_mode_mask = false;
    var reference_library_path: ?[]const u8 = null;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--decodecorpus")) {
            decodecorpus_frames = args.next() orelse return error.MissingCorpusPath;
            decodecorpus_plain = args.next() orelse return error.MissingCorpusPath;
        } else if (std.mem.eql(u8, arg, "--decodecorpus-count")) {
            decodecorpus_count = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10);
        } else if (std.mem.eql(u8, arg, "--decodecorpus-dictionary")) {
            decodecorpus_dictionary_path = args.next() orelse return error.MissingCorpusPath;
        } else if (std.mem.eql(u8, arg, "--prior-mode-mask")) {
            prior_mode_mask = try std.fmt.parseInt(u64, args.next() orelse return error.MissingLimit, 0);
        } else if (std.mem.eql(u8, arg, "--require-complete-mode-mask")) {
            require_complete_mode_mask = true;
        } else if (std.mem.eql(u8, arg, "--libzstd")) {
            reference_library_path = args.next() orelse return error.MissingCorpusPath;
        } else return error.UnknownArgument;
    }
    if ((decodecorpus_frames == null) != (decodecorpus_plain == null)) return error.MissingCorpusPath;

    var runtime = if (reference_library_path) |path|
        try libzstd.Runtime.openPath(path)
    else
        try libzstd.Runtime.open();
    defer runtime.deinit();
    var checked: usize = 0;
    var unsupported: usize = 0;
    var corpus_cases: usize = 0;
    var golden_cases: usize = 0;
    var golden_error_cases: usize = 0;
    var advanced_cases: usize = 0;
    var explicit_sequence_cases: usize = 0;
    var streaming_cases: usize = 0;
    var trained_dictionary_cases: usize = 0;
    var decodecorpus_cases: usize = 0;
    var decodecorpus_incremental_cases: usize = 0;
    var decodecorpus_block_stream_cases: usize = 0;
    var decodecorpus_max_compressed_buffered: usize = 0;
    var decodecorpus_max_compressed_capacity: usize = 0;
    var decodecorpus_streamed_literal_blocks: usize = 0;
    var decodecorpus_streamed_sequence_blocks: usize = 0;
    var decodecorpus_max_block_stream_decoded_buffered: usize = 0;
    var decodecorpus_max_block_stream_decoded_capacity: usize = 0;
    var coverage = Coverage{};
    var decodecorpus_coverage = Coverage{};
    for (std.meta.tags(Shape)) |shape| {
        for (sizes) |size| {
            const payload = try init.gpa.alloc(u8, size);
            defer init.gpa.free(payload);
            fill(shape, payload);
            for (levels) |level| {
                const encoded = try runtime.encodeAlloc(init.gpa, payload, level);
                defer init.gpa.free(encoded);
                try observeFrame(encoded, &coverage);
                const decoded = vort.zstdDecodeFrameAlloc(init.gpa, encoded) catch |err| {
                    unsupported += 1;
                    std.debug.print(
                        "zstd_compat_unsupported shape={s} size={d} level={d} encoded={d} error={s}\n",
                        .{ @tagName(shape), size, level, encoded.len, @errorName(err) },
                    );
                    continue;
                };
                defer init.gpa.free(decoded);
                if (!std.mem.eql(u8, payload, decoded)) return error.SizeMismatch;
                checked += 1;
            }
        }
    }
    const advanced_payload = try init.gpa.alloc(u8, 2 * 1024 * 1024);
    defer init.gpa.free(advanced_payload);
    fillAdvanced(advanced_payload);
    const advanced_options = [_]libzstd.Runtime.AdvancedOptions{
        .{ .level = 1, .content_size = false },
        .{ .level = 9, .checksum = true },
        .{ .level = 19, .content_size = false, .checksum = true },
        .{ .level = 3, .window_log = 10 },
        .{ .level = 19, .window_log = 21 },
        .{ .level = 19, .long_distance_matching = true },
        .{ .level = 3, .strategy = 1 },
        .{ .level = 3, .strategy = 2 },
        .{ .level = 3, .strategy = 3 },
        .{ .level = 3, .strategy = 4 },
        .{ .level = 3, .strategy = 5 },
        .{ .level = 3, .strategy = 6 },
        .{ .level = 3, .strategy = 7 },
        .{ .level = 3, .strategy = 8 },
        .{ .level = 3, .strategy = 9 },
    };
    for (advanced_options) |options| {
        const encoded = try runtime.encodeAdvancedAlloc(init.gpa, advanced_payload, options);
        defer init.gpa.free(encoded);
        try observeFrame(encoded, &coverage);
        const decoded = vort.zstdDecodeFrameAlloc(init.gpa, encoded) catch |err| {
            std.debug.print("zstd_compat_unsupported advanced level={d} content_size={} checksum={} window_log={any} strategy={any} ldm={} encoded={d} error={s}\n", .{ options.level, options.content_size, options.checksum, options.window_log, options.strategy, options.long_distance_matching, encoded.len, @errorName(err) });
            return err;
        };
        defer init.gpa.free(decoded);
        if (!std.mem.eql(u8, advanced_payload, decoded)) return error.SizeMismatch;
        checked += 1;
        advanced_cases += 1;
    }
    const random_sequence_counts = [_]usize{ 127, 128, 129, 1024, 8192 };
    for (random_sequence_counts, 0..) |sequence_count, case_index| {
        var payload: std.ArrayList(u8) = .empty;
        defer payload.deinit(init.gpa);
        try payload.ensureTotalCapacity(init.gpa, sequence_count * 40);
        const sequences = try init.gpa.alloc(libzstd.Sequence, sequence_count);
        defer init.gpa.free(sequences);
        var state: u32 = 0x9e37_79b9 ^ @as(u32, @intCast(case_index * 0x1021));
        for (sequences, 0..) |*sequence, sequence_index| {
            const literal_len: usize = if (sequence_index == 0) 32 else state & 3;
            for (0..literal_len) |_| {
                state = state *% 1_664_525 +% 1_013_904_223;
                try payload.append(init.gpa, @truncate(state >> 16));
            }
            state = state *% 1_664_525 +% 1_013_904_223;
            const offset = 1 + @as(usize, state) % @min(payload.items.len, 2048);
            state = state *% 1_664_525 +% 1_013_904_223;
            const match_len = 3 + @as(usize, state) % 30;
            sequence.* = .{ .offset = @intCast(offset), .literal_length = @intCast(literal_len), .match_length = @intCast(match_len) };
            for (0..match_len) |_| try payload.append(init.gpa, payload.items[payload.items.len - offset]);
        }
        const frame = try runtime.encodeSequencesAlloc(init.gpa, payload.items, sequences, @intCast(1 + case_index * 4));
        defer init.gpa.free(frame);
        try observeFrame(frame, &coverage);
        const decoded = vort.zstdDecodeFrameAlloc(init.gpa, frame) catch |err| {
            std.debug.print("zstd_compat_unsupported random_explicit_sequences={d} input={d} encoded={d} error={s}\n", .{ sequence_count, payload.items.len, frame.len, @errorName(err) });
            return err;
        };
        defer init.gpa.free(decoded);
        if (!std.mem.eql(u8, payload.items, decoded)) return error.SizeMismatch;
        checked += 1;
        explicit_sequence_cases += 1;
    }
    const sequence_boundary_alphabet = 181;
    var sequence_boundary_payload: [sequence_boundary_alphabet * (sequence_boundary_alphabet + 1) * 3]u8 = undefined;
    fillSequenceBoundary(&sequence_boundary_payload, sequence_boundary_alphabet);
    const sequence_boundary_frame = try runtime.encodeAdvancedAlloc(init.gpa, &sequence_boundary_payload, .{
        .level = 1,
        .min_match = 3,
        .target_length = 1,
        .strategy = 1,
    });
    defer init.gpa.free(sequence_boundary_frame);
    try observeFrame(sequence_boundary_frame, &coverage);
    const sequence_boundary_decoded = try vort.zstdDecodeFrameAlloc(init.gpa, sequence_boundary_frame);
    defer init.gpa.free(sequence_boundary_decoded);
    if (!std.mem.eql(u8, &sequence_boundary_payload, sequence_boundary_decoded)) return error.SizeMismatch;
    checked += 1;
    advanced_cases += 1;
    // 43,690 is the largest count possible in a 128 KiB block when every
    // sequence has the minimum three-byte match and only the first has a
    // literal. Keep both wire-tier boundaries and the practical block maximum.
    inline for (.{ 0x7eff, 0x7f00, 43_690 }) |sequence_count| {
        const explicit_payload = try init.gpa.alloc(u8, 1 + sequence_count * 3);
        defer init.gpa.free(explicit_payload);
        @memset(explicit_payload, 'a');
        const explicit_sequences = try init.gpa.alloc(libzstd.Sequence, sequence_count);
        defer init.gpa.free(explicit_sequences);
        @memset(explicit_sequences, .{ .offset = 1, .literal_length = 0, .match_length = 3 });
        explicit_sequences[0].literal_length = 1;
        const frame = try runtime.encodeSequencesAlloc(init.gpa, explicit_payload, explicit_sequences, 19);
        defer init.gpa.free(frame);
        try observeFrame(frame, &coverage);
        const decoded = vort.zstdDecodeFrameAlloc(init.gpa, frame) catch |err| {
            std.debug.print("zstd_compat_unsupported explicit_sequences={d} input={d} encoded={d} error={s}\n", .{ sequence_count, explicit_payload.len, frame.len, @errorName(err) });
            return err;
        };
        defer init.gpa.free(decoded);
        if (!std.mem.eql(u8, explicit_payload, decoded)) return error.SizeMismatch;
        checked += 1;
        explicit_sequence_cases += 1;
    }
    const streaming_options = [_]struct {
        options: libzstd.Runtime.AdvancedOptions,
        chunk_len: usize,
        flush_each_chunk: bool,
    }{
        .{ .options = .{ .level = 1, .content_size = false }, .chunk_len = 7777, .flush_each_chunk = false },
        .{ .options = .{ .level = 3, .content_size = false, .checksum = true }, .chunk_len = 32 * 1024, .flush_each_chunk = true },
        .{ .options = .{ .level = 9, .content_size = false }, .chunk_len = 96 * 1024, .flush_each_chunk = true },
        .{ .options = .{ .level = 19, .content_size = false, .checksum = true, .strategy = 9 }, .chunk_len = 128 * 1024, .flush_each_chunk = true },
    };
    for (streaming_options) |case| {
        const encoded = try runtime.encodeStreamingAlloc(init.gpa, advanced_payload, case.options, case.chunk_len, case.flush_each_chunk);
        defer init.gpa.free(encoded);
        try observeFrame(encoded, &coverage);
        const decoded = vort.zstdDecodeFrameAlloc(init.gpa, encoded) catch |err| {
            std.debug.print("zstd_compat_unsupported streaming level={d} checksum={} strategy={any} chunk={d} flush={} encoded={d} error={s}\n", .{ case.options.level, case.options.checksum, case.options.strategy, case.chunk_len, case.flush_each_chunk, encoded.len, @errorName(err) });
            return err;
        };
        defer init.gpa.free(decoded);
        if (!std.mem.eql(u8, advanced_payload, decoded)) return error.SizeMismatch;
        checked += 1;
        streaming_cases += 1;
    }
    var dictionary_storage: [64][768]u8 = undefined;
    var dictionary_samples: [dictionary_storage.len][]const u8 = undefined;
    const dictionary_unit = "trained-zstd-service-event-field-value-payload-dictionary-history/";
    for (&dictionary_storage, &dictionary_samples, 0..) |*storage, *sample, sample_index| {
        var state: u32 = 0x5eed_1234 ^ @as(u32, @intCast(sample_index * 0x9e37));
        for (storage, 0..) |*byte, index| {
            state = state *% 1_664_525 +% 1_013_904_223;
            byte.* = if (index % 96 < 72)
                dictionary_unit[(index + sample_index * 7) % dictionary_unit.len]
            else
                @truncate(state >> 16);
        }
        sample.* = storage;
    }
    var dictionary_payload: [3 * 768]u8 = undefined;
    @memcpy(dictionary_payload[0..768], &dictionary_storage[7]);
    @memcpy(dictionary_payload[768..1536], &dictionary_storage[19]);
    @memcpy(dictionary_payload[1536..], &dictionary_storage[42]);
    const large_dictionary_payload = try init.gpa.alloc(u8, dictionary_payload.len * 224);
    defer init.gpa.free(large_dictionary_payload);
    for (0..224) |index| @memcpy(large_dictionary_payload[index * dictionary_payload.len ..][0..dictionary_payload.len], &dictionary_payload);
    const dictionary_payloads = [_][]const u8{ &dictionary_payload, large_dictionary_payload };
    inline for (.{ 256, 1024, 4096 }) |dictionary_capacity| {
        const trained_dictionary = try runtime.trainDictionaryAlloc(init.gpa, &dictionary_samples, dictionary_capacity);
        defer init.gpa.free(trained_dictionary);
        const standard = vort.ZstdDictionary.initFromStandardDictionary(trained_dictionary) catch |err| {
            std.debug.print("zstd_compat_unsupported trained_dictionary_parse capacity={d} dict={d} id={any} error={s}\n", .{ dictionary_capacity, trained_dictionary.len, runtime.dictionaryId(trained_dictionary), @errorName(err) });
            return err;
        };
        const dictionary_summary = try vort.zstdSummarizeStandardDictionary(trained_dictionary);
        if (runtime.dictionaryId(trained_dictionary) != standard.dictionary.id or dictionary_summary.id != standard.dictionary.id)
            return error.InvalidDictionaryMetadata;
        for (dictionary_payloads) |payload| {
            inline for (.{ 1, 9, 19 }) |level| {
                const frame = try runtime.encodeUsingDictAlloc(init.gpa, payload, trained_dictionary, level);
                defer init.gpa.free(frame);
                const frame_header = try vort.zstdInspectNativeFrameHeader(frame);
                if (frame_header.dictionary_id != standard.dictionary.id) return error.NeedDictionary;
                var block_iterator = try vort.zstdIterateNativeFrameBlocks(frame);
                const set = try vort.ZstdDictionarySet.initChecked(&.{standard.dictionary});
                while (try block_iterator.next()) |block| {
                    if (block.block_type != .compressed) continue;
                    const modes = try vort.zstdInspectNativeFrameBlockSequenceModesWithDictionary(frame, block, standard.dictionary);
                    const set_modes = try vort.zstdInspectNativeFrameBlockSequenceModesWithDictionarySet(frame, block, set);
                    if (!std.meta.eql(modes, set_modes)) return error.CorruptFrame;
                    coverage.max_sequence_count = @max(coverage.max_sequence_count, modes.sequence_count);
                }
                const decoded_size = vort.zstdDecodedFrameSizeWithDictionary(frame, standard.dictionary) catch |err| {
                    std.debug.print("zstd_compat_unsupported trained_dictionary_size level={d} dict={d} input={d} encoded={d} error={s}\n", .{ level, trained_dictionary.len, payload.len, frame.len, @errorName(err) });
                    return err;
                };
                if (decoded_size != payload.len) return error.SizeMismatch;
                const decoded = vort.zstdDecodeFrameAllocWithDictionary(init.gpa, frame, standard.dictionary) catch |err| {
                    std.debug.print("zstd_compat_unsupported trained_dictionary level={d} dict={d} input={d} encoded={d} error={s}\n", .{ level, trained_dictionary.len, payload.len, frame.len, @errorName(err) });
                    return err;
                };
                defer init.gpa.free(decoded);
                if (!std.mem.eql(u8, payload, decoded)) return error.SizeMismatch;
                const into = try init.gpa.alloc(u8, payload.len);
                defer init.gpa.free(into);
                const written = try vort.zstdDecodeFrameIntoWithDictionary(frame, into, standard.dictionary);
                if (written != payload.len or !std.mem.eql(u8, payload, into[0..written])) return error.SizeMismatch;
                checked += 1;
                trained_dictionary_cases += 1;
            }
        }
    }
    const corpus_paths = [_][]const u8{
        "README.md",
        "docs/roadmap.md",
        "../../Work/zstd/tests/fuzzer.c",
        "../../Work/zstd/tests/zstreamtest.c",
    };
    for (corpus_paths) |path| {
        const payload = std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(2 * 1024 * 1024)) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        };
        defer init.gpa.free(payload);
        for (levels) |level| {
            const encoded = try runtime.encodeAlloc(init.gpa, payload, level);
            defer init.gpa.free(encoded);
            try observeFrame(encoded, &coverage);
            const decoded = vort.zstdDecodeFrameAlloc(init.gpa, encoded) catch |err| {
                std.debug.print("zstd_compat_unsupported path={s} size={d} level={d} encoded={d} error={s}\n", .{ path, payload.len, level, encoded.len, @errorName(err) });
                return err;
            };
            defer init.gpa.free(decoded);
            if (!std.mem.eql(u8, payload, decoded)) return error.SizeMismatch;
            checked += 1;
            corpus_cases += 1;
        }
    }
    const GoldenCase = struct { name: []const u8, expected: enum { empty, zeros_128k, zeros_1m, hello } };
    const golden_cases_to_try = [_]GoldenCase{
        .{ .name = "block-128k.zst", .expected = .zeros_128k },
        .{ .name = "empty-block.zst", .expected = .empty },
        .{ .name = "rle-first-block.zst", .expected = .zeros_1m },
        .{ .name = "zeroSeq_2B.zst", .expected = .hello },
    };
    for (golden_cases_to_try) |case| {
        var path_buffer: [256]u8 = undefined;
        const path = try std.fmt.bufPrint(&path_buffer, "{s}/{s}", .{ optional_golden_root, case.name });
        const encoded = std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(2 * 1024 * 1024)) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        };
        defer init.gpa.free(encoded);
        try observeFrame(encoded, &coverage);
        const expected_size = try vort.zstdDecodedFrameSize(encoded);
        const decoded = vort.zstdDecodeFrameAlloc(init.gpa, encoded) catch |err| {
            std.debug.print("zstd_compat_unsupported golden={s} decoded={d} encoded={d} error={s}\n", .{ path, expected_size, encoded.len, @errorName(err) });
            return err;
        };
        defer init.gpa.free(decoded);
        switch (case.expected) {
            .empty => if (decoded.len != 0) return error.SizeMismatch,
            .zeros_128k => if (decoded.len != 131068 or !allBytesEqual(decoded, 0)) return error.SizeMismatch,
            .zeros_1m => if (decoded.len != 1024 * 1024 or !allBytesEqual(decoded, 0)) return error.SizeMismatch,
            .hello => if (!std.mem.eql(u8, decoded, "Hello World!\n")) return error.SizeMismatch,
        }
        checked += 1;
        golden_cases += 1;
    }
    const golden_error_names = [_][]const u8{
        "off0.bin.zst",
        "truncated_huff_state.zst",
        "zeroSeq_extraneous.zst",
    };
    for (golden_error_names) |name| {
        var path_buffer: [256]u8 = undefined;
        const path = try std.fmt.bufPrint(&path_buffer, "../../Work/zstd/tests/golden-decompression-errors/{s}", .{name});
        const encoded = std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(2 * 1024 * 1024)) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        };
        defer init.gpa.free(encoded);
        if (vort.zstdDecodedFrameSize(encoded)) |decoded_size| {
            std.debug.print("zstd_compat_invalid_accepted golden={s} decoded={d} encoded={d}\n", .{ path, decoded_size, encoded.len });
            return error.CorruptFrame;
        } else |_| {}
        if (vort.zstdDecodeFrameAlloc(init.gpa, encoded)) |decoded| {
            defer init.gpa.free(decoded);
            std.debug.print("zstd_compat_invalid_decoded golden={s} decoded={d} encoded={d}\n", .{ path, decoded.len, encoded.len });
            return error.CorruptFrame;
        } else |_| {}
        checked += 1;
        golden_error_cases += 1;
    }
    if (decodecorpus_frames) |frames_dir| {
        const plain_dir = decodecorpus_plain.?;
        const decodecorpus_dictionary_bytes = if (decodecorpus_dictionary_path) |path|
            try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(16 * 1024 * 1024))
        else
            null;
        defer if (decodecorpus_dictionary_bytes) |bytes| init.gpa.free(bytes);
        const decodecorpus_dictionary = if (decodecorpus_dictionary_bytes) |bytes|
            (try vort.ZstdDictionary.initFromStandardDictionary(bytes)).dictionary
        else
            null;
        const case_count = if (decodecorpus_count == 0) 1 else decodecorpus_count;
        for (0..case_count) |index| {
            var frame_path_buffer: [512]u8 = undefined;
            const frame_path = try std.fmt.bufPrint(&frame_path_buffer, "{s}/z{d:0>6}.zst", .{ frames_dir, index });
            var plain_path_buffer: [512]u8 = undefined;
            const plain_path = try std.fmt.bufPrint(&plain_path_buffer, "{s}/z{d:0>6}", .{ plain_dir, index });
            const encoded = try std.Io.Dir.cwd().readFileAlloc(init.io, frame_path, init.gpa, .limited(2 * 1024 * 1024));
            defer init.gpa.free(encoded);
            const expected = try std.Io.Dir.cwd().readFileAlloc(init.io, plain_path, init.gpa, .limited(2 * 1024 * 1024));
            defer init.gpa.free(expected);
            observeFrameWithDictionary(encoded, decodecorpus_dictionary, &decodecorpus_coverage) catch |err| {
                std.debug.print("zstd_decodecorpus_inspect_fail case={d} input={d} encoded={d} error={s}\n", .{ index, expected.len, encoded.len, @errorName(err) });
                return err;
            };
            const decoded = if (decodecorpus_dictionary) |dictionary|
                vort.zstdDecodeFrameAllocWithDictionary(init.gpa, encoded, dictionary)
            else
                vort.zstdDecodeFrameAlloc(init.gpa, encoded);
            const resolved = decoded catch |err| {
                std.debug.print("zstd_decodecorpus_decode_fail case={d} input={d} encoded={d} error={s}\n", .{ index, expected.len, encoded.len, @errorName(err) });
                return err;
            };
            defer init.gpa.free(resolved);
            if (!std.mem.eql(u8, expected, resolved)) {
                std.debug.print("zstd_decodecorpus_mismatch case={d} input={d} encoded={d} decoded={d}\n", .{ index, expected.len, encoded.len, resolved.len });
                return error.SizeMismatch;
            }
            const incremental = incrementalDecodeCorpusCase(
                init.gpa,
                encoded,
                expected,
                decodecorpus_dictionary,
            ) catch |err| {
                std.debug.print("zstd_decodecorpus_incremental_fail case={d} input={d} encoded={d} error={s}\n", .{ index, expected.len, encoded.len, @errorName(err) });
                return err;
            };
            decodecorpus_incremental_cases += 1;
            decodecorpus_block_stream_cases += @intFromBool(incremental.used_block_stream);
            decodecorpus_max_compressed_buffered = @max(decodecorpus_max_compressed_buffered, incremental.max_compressed_buffered);
            decodecorpus_max_compressed_capacity = @max(decodecorpus_max_compressed_capacity, incremental.max_compressed_capacity);
            decodecorpus_streamed_literal_blocks += incremental.streamed_literal_blocks;
            decodecorpus_streamed_sequence_blocks += incremental.streamed_sequence_blocks;
            decodecorpus_max_block_stream_decoded_buffered = @max(decodecorpus_max_block_stream_decoded_buffered, incremental.max_block_stream_decoded_buffered);
            decodecorpus_max_block_stream_decoded_capacity = @max(decodecorpus_max_block_stream_decoded_capacity, incremental.max_block_stream_decoded_capacity);
            checked += 1;
            decodecorpus_cases += 1;
        }
    }
    mergeCoverage(&coverage, decodecorpus_coverage);
    if (unsupported != 0) return error.UnsupportedZstdFeature;
    if (coverage.max_sequence_count < 43_690 or coverage.sequence_count_tiers != 0b111)
        return error.ReferenceEncodeFailed;
    const decodecorpus_combined_mode_mask = decodecorpus_coverage.sequence_mode_combinations | prior_mode_mask;
    if (require_complete_mode_mask and decodecorpus_combined_mode_mask != std.math.maxInt(u64))
        return error.ReferenceEncodeFailed;
    const combined_mode_mask = coverage.sequence_mode_combinations | prior_mode_mask;
    std.debug.print(
        "zstd_compat_probe checked={d} unsupported={d} advanced_cases={d} explicit_sequence_cases={d} streaming_cases={d} trained_dictionary_cases={d} corpus_cases={d} golden_cases={d} golden_error_cases={d} decodecorpus_cases={d} decodecorpus_incremental_cases={d} decodecorpus_block_stream_cases={d} decodecorpus_streamed_literal_blocks={d} decodecorpus_streamed_sequence_blocks={d} decodecorpus_max_compressed_buffered={d} decodecorpus_max_compressed_capacity={d} decodecorpus_max_block_stream_decoded_buffered={d} decodecorpus_max_block_stream_decoded_capacity={d} ",
        .{ checked, unsupported, advanced_cases, explicit_sequence_cases, streaming_cases, trained_dictionary_cases, corpus_cases, golden_cases, golden_error_cases, decodecorpus_cases, decodecorpus_incremental_cases, decodecorpus_block_stream_cases, decodecorpus_streamed_literal_blocks, decodecorpus_streamed_sequence_blocks, decodecorpus_max_compressed_buffered, decodecorpus_max_compressed_capacity, decodecorpus_max_block_stream_decoded_buffered, decodecorpus_max_block_stream_decoded_capacity },
    );
    std.debug.print(
        "decodecorpus_max_sequence_count={d} decodecorpus_max_block_count={d} decodecorpus_sequence_count_tiers=0x{x} decodecorpus_sequence_mode_combinations={d} decodecorpus_sequence_mode_mask=0x{x} decodecorpus_combined_mode_combinations={d} decodecorpus_combined_mode_mask=0x{x} max_sequence_count={d} max_block_count={d} sequence_count_tiers=0x{x} sequence_mode_combinations={d} sequence_mode_mask=0x{x} combined_mode_combinations={d} combined_mode_mask=0x{x} version={s}\n",
        .{ decodecorpus_coverage.max_sequence_count, decodecorpus_coverage.max_block_count, decodecorpus_coverage.sequence_count_tiers, @popCount(decodecorpus_coverage.sequence_mode_combinations), decodecorpus_coverage.sequence_mode_combinations, @popCount(decodecorpus_combined_mode_mask), decodecorpus_combined_mode_mask, coverage.max_sequence_count, coverage.max_block_count, coverage.sequence_count_tiers, @popCount(coverage.sequence_mode_combinations), coverage.sequence_mode_combinations, @popCount(combined_mode_mask), combined_mode_mask, runtime.version() },
    );
}

fn mergeCoverage(target: *Coverage, source: Coverage) void {
    target.max_sequence_count = @max(target.max_sequence_count, source.max_sequence_count);
    target.max_block_count = @max(target.max_block_count, source.max_block_count);
    target.sequence_count_tiers |= source.sequence_count_tiers;
    target.sequence_mode_combinations |= source.sequence_mode_combinations;
}

const IncrementalCorpusResult = struct {
    used_block_stream: bool,
    max_compressed_buffered: usize,
    max_compressed_capacity: usize,
    streamed_literal_blocks: usize,
    streamed_sequence_blocks: usize,
    max_block_stream_decoded_buffered: usize,
    max_block_stream_decoded_capacity: usize,
};

fn incrementalDecodeCorpusCase(allocator: std.mem.Allocator, encoded: []const u8, expected: []const u8, dictionary: ?vort.ZstdDictionary) !IncrementalCorpusResult {
    const compressed_limit = std.compress.zstd.block_size_max + 32;
    var decoder = if (dictionary) |dict|
        vort.ZstdNativeIncrementalFrameDecoder.initWithDictionaryAndOptions(allocator, dict, .{
            .expected_output_len = expected.len,
            .max_compressed_buffer_len = compressed_limit,
            .max_decoded_buffer_len = expected.len,
        })
    else
        vort.ZstdNativeIncrementalFrameDecoder.initWithOptions(allocator, .{
            .expected_output_len = expected.len,
            .max_compressed_buffer_len = compressed_limit,
            .max_decoded_buffer_len = expected.len,
        });
    defer decoder.deinit();
    const output = try allocator.alloc(u8, expected.len);
    defer allocator.free(output);
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    var used_block_stream = false;
    var max_compressed_buffered: usize = 0;
    var max_compressed_capacity: usize = 0;
    var max_block_stream_decoded_buffered: usize = 0;
    var max_block_stream_decoded_capacity: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const input_end = @min(encoded.len, input_offset + 4093);
        const output_end = @min(expected.len, output_offset + 2039);
        const result = try decoder.step(encoded[input_offset..input_end], output[output_offset..output_end]);
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
        used_block_stream = used_block_stream or decoder.isBlockStreaming();
        if (decoder.isBlockStreaming() or decoder.streamedSequenceBlockCount() != 0) {
            max_block_stream_decoded_buffered = @max(max_block_stream_decoded_buffered, decoder.decodedBufferedBytes());
            max_block_stream_decoded_capacity = @max(max_block_stream_decoded_capacity, decoder.decodedBufferCapacity());
        }
        max_compressed_buffered = @max(max_compressed_buffered, decoder.compressedBufferedBytes());
        max_compressed_capacity = @max(max_compressed_capacity, decoder.compressedBufferCapacity());
        if (max_compressed_buffered > compressed_limit) return error.OutputLimitExceeded;
        if (max_compressed_capacity > compressed_limit) return error.OutputLimitExceeded;
        if (result.status == .need_input and input_offset == encoded.len) return error.TruncatedFrame;
        if (result.status == .need_output and output_offset == expected.len) return error.OutputTooSmall;
    }
    try decoder.finish();
    if (input_offset != encoded.len or output_offset != expected.len or !std.mem.eql(u8, expected, output))
        return error.SizeMismatch;
    return .{
        .used_block_stream = used_block_stream,
        .max_compressed_buffered = max_compressed_buffered,
        .max_compressed_capacity = max_compressed_capacity,
        .streamed_literal_blocks = decoder.streamedLiteralBlockCount(),
        .streamed_sequence_blocks = decoder.streamedSequenceBlockCount(),
        .max_block_stream_decoded_buffered = max_block_stream_decoded_buffered,
        .max_block_stream_decoded_capacity = max_block_stream_decoded_capacity,
    };
}

fn observeFrame(frame: []const u8, coverage: *Coverage) !void {
    return observeFrameWithDictionary(frame, null, coverage);
}

fn observeFrameWithDictionary(frame: []const u8, dictionary: ?vort.ZstdDictionary, coverage: *Coverage) !void {
    var iterator = try vort.zstdIterateNativeFrameBlocks(frame);
    var block_count: usize = 0;
    while (try iterator.next()) |block| {
        block_count += 1;
        if (block.block_type != .compressed) continue;
        const modes = if (dictionary) |dict|
            try vort.zstdInspectNativeFrameBlockSequenceModesWithDictionary(frame, block, dict)
        else
            try vort.zstdInspectNativeFrameBlockSequenceModes(frame, block);
        coverage.max_sequence_count = @max(coverage.max_sequence_count, modes.sequence_count);
        const tier: u2 = if (modes.sequence_count < 128) 0 else if (modes.sequence_count < 0x7f00) 1 else 2;
        coverage.sequence_count_tiers |= @as(u3, 1) << tier;
        const combination: u6 = @intCast(@as(usize, @intFromEnum(modes.literal_length_mode)) * 16 + @as(usize, @intFromEnum(modes.offset_mode)) * 4 + @intFromEnum(modes.match_length_mode));
        coverage.sequence_mode_combinations |= @as(u64, 1) << combination;
    }
    coverage.max_block_count = @max(coverage.max_block_count, block_count);
}

fn fillAdvanced(payload: []u8) void {
    var state: u32 = 0x71c3_95ad;
    for (payload, 0..) |*byte, index| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = if (index % 32_768 < 24_576)
            @truncate((index * 17 + index / 97) % 251)
        else
            @truncate(state >> 16);
    }
    // Repeat two distant regions so the high levels/LDM case has a real
    // opportunity to emit offsets across ordinary block boundaries.
    @memcpy(payload[1024 * 1024 ..][0 .. 256 * 1024], payload[0 .. 256 * 1024]);
    @memcpy(payload[1536 * 1024 ..][0 .. 256 * 1024], payload[384 * 1024 ..][0 .. 256 * 1024]);
}

fn fillSequenceBoundary(output: []u8, comptime alphabet_size: usize) void {
    std.debug.assert(output.len == alphabet_size * (alphabet_size + 1) * 3);
    var written: usize = 0;
    for (0..alphabet_size) |symbol| writeBoundaryToken(output, &written, @intCast(symbol));

    const Generator = struct {
        fn run(t: usize, period: usize, state: *[3]u8, out: []u8, cursor: *usize) void {
            if (t > 2) {
                if (2 % period == 0) {
                    for (state[1 .. period + 1]) |symbol| {
                        writeBoundaryToken(out, cursor, symbol);
                    }
                }
                return;
            }
            state[t] = state[t - period];
            run(t + 1, period, state, out, cursor);
            var symbol = state[t - period] + 1;
            while (symbol < alphabet_size) : (symbol += 1) {
                state[t] = symbol;
                run(t + 1, t, state, out, cursor);
            }
        }
    };
    var state: [3]u8 = @splat(0);
    Generator.run(1, 1, &state, output, &written);
    std.debug.assert(written == output.len);
}

fn writeBoundaryToken(output: []u8, written: *usize, symbol: u8) void {
    output[written.*..][0..3].* = .{ symbol, symbol ^ 0xa5, symbol ^ 0x5a };
    written.* += 3;
}

fn allBytesEqual(bytes: []const u8, expected: u8) bool {
    for (bytes) |byte| if (byte != expected) return false;
    return true;
}

fn fill(shape: Shape, payload: []u8) void {
    switch (shape) {
        .text => {
            const unit = "Zstandard compatibility corpus with repeated words and punctuation.\n";
            for (payload, 0..) |*byte, index| byte.* = unit[index % unit.len];
        },
        .structured => {
            const unit = "{\"service\":\"vort\",\"value\":12345,\"ok\":true}\n";
            for (payload, 0..) |*byte, index| byte.* = unit[index % unit.len];
        },
        .binary => for (payload, 0..) |*byte, index| {
            byte.* = if (index % 64 < 48) @truncate(index * 17) else @truncate(index * 73 + index / 31);
        },
        .random => {
            var state: u32 = 0x7a57_1b5d;
            for (payload) |*byte| {
                state = state *% 1_664_525 +% 1_013_904_223;
                byte.* = @truncate(state >> 16);
            }
        },
    }
}
