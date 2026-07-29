const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var stdout_buffer: [2048]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    const command = args.next() orelse {
        try printHelp(stdout);
        try stdout.flush();
        return;
    };

    if (std.mem.eql(u8, command, "--help") or std.mem.eql(u8, command, "help")) {
        try printHelp(stdout);
    } else if (std.mem.eql(u8, command, "checksum")) {
        const payload = args.next() orelse "";
        try stdout.print("input_bytes={d} adler32={d} crc32={d} crc32c={d}\n", .{
            payload.len,
            vort.adler32(payload),
            vort.crc32(payload),
            vort.crc32c(payload),
        });
    } else if (std.mem.eql(u8, command, "checksum-file")) {
        const path = args.next() orelse return error.MissingCorpusPath;
        const payload = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(payload);
        try stdout.print("input_bytes={d} adler32={d} crc32={d} crc32c={d}\n", .{
            payload.len,
            vort.adler32(payload),
            vort.crc32(payload),
            vort.crc32c(payload),
        });
    } else if (std.mem.eql(u8, command, "store-roundtrip")) {
        const payload = args.next() orelse "";
        const encoded = try vort.storeEncodeAlloc(init.gpa, payload);
        defer init.gpa.free(encoded);
        const decoded = try vort.storeDecodeAlloc(init.gpa, encoded);
        defer init.gpa.free(decoded);
        try stdout.print("input_bytes={d} encoded_bytes={d} decoded_ok={} crc32={d}\n", .{
            payload.len,
            encoded.len,
            std.mem.eql(u8, payload, decoded),
            vort.crc32(decoded),
        });
    } else if (std.mem.eql(u8, command, "zlib-store-roundtrip")) {
        const payload = args.next() orelse "";
        const encoded = try vort.encodeZlibStoredAlloc(init.gpa, payload);
        defer init.gpa.free(encoded);
        const decoded = try vort.decodeZlibStoredAlloc(init.gpa, encoded);
        defer init.gpa.free(decoded);
        try stdout.print("input_bytes={d} zlib_bytes={d} decoded_ok={} adler32={d}\n", .{
            payload.len,
            encoded.len,
            std.mem.eql(u8, payload, decoded),
            vort.adler32(decoded),
        });
    } else if (std.mem.eql(u8, command, "gzip-store-roundtrip")) {
        const payload = args.next() orelse "";
        const encoded = try vort.encodeGzipStoredAlloc(init.gpa, payload);
        defer init.gpa.free(encoded);
        const decoded = try vort.decodeGzipStoredAlloc(init.gpa, encoded);
        defer init.gpa.free(decoded);
        try stdout.print("input_bytes={d} gzip_bytes={d} decoded_ok={} crc32={d}\n", .{
            payload.len,
            encoded.len,
            std.mem.eql(u8, payload, decoded),
            vort.crc32(decoded),
        });
    } else if (std.mem.eql(u8, command, "zlib-fixed-roundtrip")) {
        const payload = args.next() orelse "";
        const encoded = try vort.encodeZlibFixedAlloc(init.gpa, payload);
        defer init.gpa.free(encoded);
        const decoded = try vort.decodeZlibAlloc(init.gpa, encoded);
        defer init.gpa.free(decoded);
        try stdout.print("input_bytes={d} zlib_fixed_bytes={d} decoded_ok={} adler32={d}\n", .{
            payload.len,
            encoded.len,
            std.mem.eql(u8, payload, decoded),
            vort.adler32(decoded),
        });
    } else if (std.mem.eql(u8, command, "gzip-fixed-roundtrip")) {
        const payload = args.next() orelse "";
        const encoded = try vort.encodeGzipFixedAlloc(init.gpa, payload);
        defer init.gpa.free(encoded);
        const decoded = try vort.decodeGzipAlloc(init.gpa, encoded);
        defer init.gpa.free(decoded);
        try stdout.print("input_bytes={d} gzip_fixed_bytes={d} decoded_ok={} crc32={d}\n", .{
            payload.len,
            encoded.len,
            std.mem.eql(u8, payload, decoded),
            vort.crc32(decoded),
        });
    } else if (std.mem.eql(u8, command, "encode-raw-fixed-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawFixedWithOptionsAlloc(init.gpa, payload, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-raw-dict-fixed-hex")) {
        const payload = args.next() orelse "";
        const dictionary = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawFixedWithDictionaryAlloc(init.gpa, payload, dictionary, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-zlib-fixed-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibFixedWithOptionsAlloc(init.gpa, payload, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-zlib-dict-stored-hex")) {
        const payload = args.next() orelse "";
        const dictionary = args.next() orelse "";
        const encoded = try vort.encodeZlibStoredWithDictionaryAlloc(init.gpa, payload, dictionary);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-zlib-dict-fixed-hex")) {
        const payload = args.next() orelse "";
        const dictionary = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibFixedWithDictionaryAlloc(init.gpa, payload, dictionary, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-gzip-fixed-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeGzipFixedWithOptionsAlloc(init.gpa, payload, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "vort-best-roundtrip")) {
        const payload = args.next() orelse "";
        const frame = try vort.storeEncodeBestAlloc(init.gpa, payload);
        defer init.gpa.free(frame);
        const decoded = try vort.storeDecodeAnyAlloc(init.gpa, frame);
        defer init.gpa.free(decoded);
        try stdout.print("input_bytes={d} frame_bytes={d} decoded_ok={} crc32={d}\n", .{
            payload.len,
            frame.len,
            std.mem.eql(u8, payload, decoded),
            vort.crc32(decoded),
        });
    } else if (std.mem.eql(u8, command, "vort-rle-roundtrip")) {
        const payload = args.next() orelse "";
        const frame = try vort.storeEncodeRleAlloc(init.gpa, payload);
        defer init.gpa.free(frame);
        const decoded = try vort.storeDecodeAnyAlloc(init.gpa, frame);
        defer init.gpa.free(decoded);
        try stdout.print("input_bytes={d} frame_bytes={d} decoded_ok={} crc32={d}\n", .{
            payload.len,
            frame.len,
            std.mem.eql(u8, payload, decoded),
            vort.crc32(decoded),
        });
    } else if (std.mem.eql(u8, command, "vort-deflate-roundtrip")) {
        const payload = args.next() orelse "";
        const frame = try vort.storeEncodeDeflateAlloc(init.gpa, payload);
        defer init.gpa.free(frame);
        const decoded = try vort.storeDecodeAnyAlloc(init.gpa, frame);
        defer init.gpa.free(decoded);
        try stdout.print("input_bytes={d} frame_bytes={d} decoded_ok={} crc32={d}\n", .{
            payload.len,
            frame.len,
            std.mem.eql(u8, payload, decoded),
            vort.crc32(decoded),
        });
    } else if (std.mem.eql(u8, command, "vort-workqueue-demo")) {
        const input = "abcdefghijklmnopqrstuvwxyz" ** 4;
        const stream = try vort.storeEncodeWorkStealingDeflateStreamAlloc(init.gpa, input, 13, 3);
        defer init.gpa.free(stream);
        const range = try vort.storeDecodeIndexedRangeAlloc(init.gpa, stream, 10, 20);
        defer init.gpa.free(range);
        try stdout.print("range={s} workqueue_stream_bytes={d}\n", .{ range, stream.len });
    } else if (std.mem.eql(u8, command, "vort-threadpool-demo")) {
        const input = "abcdefghijklmnopqrstuvwxyz" ** 4;
        const stream = try vort.storeEncodeThreadPoolDeflateStreamAlloc(init.gpa, input, 13, 3);
        defer init.gpa.free(stream);
        const range = try vort.storeDecodeIndexedRangeAlloc(init.gpa, stream, 10, 20);
        defer init.gpa.free(range);
        try stdout.print("range={s} threadpool_stream_bytes={d}\n", .{ range, stream.len });
    } else if (std.mem.eql(u8, command, "vort-parallel-demo")) {
        const input = "abcdefghijklmnopqrstuvwxyz" ** 4;
        const stream = try vort.storeEncodeParallelDeflateStreamAlloc(init.gpa, input, 13, 3);
        defer init.gpa.free(stream);
        const range = try vort.storeDecodeIndexedRangeAlloc(init.gpa, stream, 10, 20);
        defer init.gpa.free(range);
        try stdout.print("range={s} parallel_stream_bytes={d}\n", .{ range, stream.len });
    } else if (std.mem.eql(u8, command, "vort-blocked-range-demo")) {
        const input = "abcdefghijklmnopqrstuvwxyz";
        const stream = try vort.storeEncodeBlockedDeflateStreamAlloc(init.gpa, input, 7);
        defer init.gpa.free(stream);
        const range = try vort.storeDecodeIndexedRangeAlloc(init.gpa, stream, 5, 12);
        defer init.gpa.free(range);
        try stdout.print("range={s} blocked_stream_bytes={d}\n", .{ range, stream.len });
    } else if (std.mem.eql(u8, command, "vort-blocked-best-range-demo")) {
        const input = "abcdefghijklmnopqrstuvwxyz" ++ ("aaaaaaaaaaaaaaaa" ** 2) ++ ("abcabcabcabc" ** 2);
        const stream = try vort.storeEncodeBlockedBestStreamAlloc(init.gpa, input, 16);
        defer init.gpa.free(stream);
        const range = try vort.storeDecodeIndexedRangeAlloc(init.gpa, stream, 10, 32);
        defer init.gpa.free(range);
        const modes = try vort.storeSummarizeModes(stream);
        try stdout.print("range={s} blocked_best_stream_bytes={d} modes={d}/{d}/{d}\n", .{ range, stream.len, modes.store, modes.deflate, modes.rle });
    } else if (std.mem.eql(u8, command, "vort-dict-blocked-range-demo")) {
        const dict = "dictionary-only phrase with enough length to beat stored framing";
        const input = (dict ++ "!") ** 3;
        const stream = try vort.storeEncodeBlockedBestWithDictionaryStreamAlloc(init.gpa, dict, input, dict.len + 1, 8);
        defer init.gpa.free(stream);
        const range = try vort.storeDecodeIndexedRangeWithDictionaryAlloc(init.gpa, dict, stream, 5, 40);
        defer init.gpa.free(range);
        const modes = try vort.storeSummarizeModes(stream);
        try stdout.print("range={s} dict_blocked_stream_bytes={d} modes={d}/{d}/{d}/{d}\n", .{ range, stream.len, modes.store, modes.deflate, modes.rle, modes.dictionary_patch + modes.dictionary_deflate });
    } else if (std.mem.eql(u8, command, "vort-self-dict-range-demo")) {
        const phrase = "self-contained dictionary phrase for native streams";
        const input = (phrase ++ "!") ** 4;
        const stream = try vort.storeEncodeSelfContainedDictionaryStreamAlloc(init.gpa, input, phrase.len + 1, 256, 8);
        defer init.gpa.free(stream);
        const range = try vort.storeDecodeSelfContainedDictionaryRangeAlloc(init.gpa, stream, 7, 64);
        defer init.gpa.free(range);
        const dict = try vort.storeParseEmbeddedDictionaryAlloc(init.gpa, stream);
        defer init.gpa.free(dict);
        const modes = try vort.storeSummarizeModes(stream);
        try stdout.print("range={s} self_dict_stream_bytes={d} dict_bytes={d} modes={d}/{d}/{d}/{d}\n", .{ range, stream.len, dict.len, modes.store, modes.deflate, modes.rle, modes.dictionary_patch + modes.dictionary_deflate });
    } else if (std.mem.eql(u8, command, "vort-trained-dict-range-demo")) {
        const phrase = "self-contained dictionary phrase for native streams";
        const input = (phrase ++ "!") ** 4;
        const stream = try vort.storeEncodeBestTrainedDictionaryStreamAlloc(init.gpa, input, phrase.len + 1, 256, 8);
        defer init.gpa.free(stream);
        const range = try vort.storeDecodeIndexedRangeAutoAlloc(init.gpa, stream, 7, 64);
        defer init.gpa.free(range);
        const modes = try vort.storeSummarizeModes(stream);
        try stdout.print("range={s} trained_dict_stream_bytes={d} modes={d}/{d}/{d}/{d}\n", .{ range, stream.len, modes.store, modes.deflate, modes.rle, modes.dictionary_patch + modes.dictionary_deflate });
    } else if (std.mem.eql(u8, command, "vort-seekable-native-range-demo")) {
        const phrase = "seekable native trained dictionary phrase";
        const dict_input = (phrase ++ "!") ** 4;
        const dict_stream = try vort.storeEncodeSeekableNativeStreamAlloc(init.gpa, dict_input, .{
            .block_len = phrase.len + 1,
            .dictionary = .{ .enable = true, .target_size = 256, .min_match_len = 8 },
        });
        defer init.gpa.free(dict_stream);
        const dict_range = try vort.storeDecodeIndexedRangeAutoAlloc(init.gpa, dict_stream, 7, 48);
        defer init.gpa.free(dict_range);
        const dict_modes = try vort.storeSummarizeModes(dict_stream);

        const prefix = makeDemoLdmPrefix();
        const ldm_input = prefix ++ "----" ++ prefix[0..1024].*;
        const ldm_stream = try vort.storeEncodeSeekableNativeStreamAlloc(init.gpa, ldm_input, .{
            .block_len = ldm_input.len,
            .long_distance = .{ .enable = true, .options = .{ .min_distance = 32769, .min_length = 16 }, .align_blocks = false },
        });
        defer init.gpa.free(ldm_stream);
        const ldm_range = try vort.storeDecodeIndexedRangeAutoAlloc(init.gpa, ldm_stream, prefix.len + 4, 24);
        defer init.gpa.free(ldm_range);
        const ldm_modes = try vort.storeSummarizeModes(ldm_stream);
        const ldm_summary = try vort.storeParseEmbeddedLdmSummary(ldm_stream);
        try stdout.print("dict_crc32={d} dict_stream_bytes={d} dict_modes={d}/{d}/{d}/{d} ldm_crc32={d} ldm_stream_bytes={d} ldm_modes={d}/{d}/{d}/{d}/{d} ldm_candidates={d}\n", .{ vort.crc32(dict_range), dict_stream.len, dict_modes.store, dict_modes.deflate, dict_modes.rle, dict_modes.dictionary_patch + dict_modes.dictionary_deflate, vort.crc32(ldm_range), ldm_stream.len, ldm_modes.store, ldm_modes.deflate, ldm_modes.rle, ldm_modes.dictionary_patch + ldm_modes.dictionary_deflate, ldm_modes.ldm, ldm_summary.candidates });
    } else if (std.mem.eql(u8, command, "vort-ldm-summary-demo")) {
        const prefix = "abcd" ** 9000;
        const input = prefix ++ "----" ++ prefix[0..64].*;
        const stream = try vort.storeEncodeBlockedBestStreamWithLdmSummaryAlloc(init.gpa, input, 8192, .{}, .{ .min_distance = 32769, .min_length = 16 });
        defer init.gpa.free(stream);
        const summary = try vort.storeParseEmbeddedLdmSummary(stream);
        try stdout.print("ldm_stream_bytes={d} candidates={d} longest={d} max_distance={d}\n", .{ stream.len, summary.candidates, summary.longest, summary.max_distance });
    } else if (std.mem.eql(u8, command, "vort-ldm-blocked-range-demo")) {
        const prefix = makeDemoLdmPrefix();
        const input = prefix ++ "----" ++ prefix[0..1024].*;
        const stream = try vort.storeEncodeBlockedBestStreamWithLdmAlloc(init.gpa, input, input.len, .{}, .{ .min_distance = 32769, .min_length = 16 });
        defer init.gpa.free(stream);
        const range = try vort.storeDecodeIndexedRangeAlloc(init.gpa, stream, prefix.len + 4, 24);
        defer init.gpa.free(range);
        const modes = try vort.storeSummarizeModes(stream);
        try stdout.print("range_crc32={d} ldm_blocked_stream_bytes={d} modes={d}/{d}/{d}/{d}/{d}\n", .{ vort.crc32(range), stream.len, modes.store, modes.deflate, modes.rle, modes.dictionary_patch + modes.dictionary_deflate, modes.ldm });
    } else if (std.mem.eql(u8, command, "vort-sidecar-ldm-range-demo")) {
        const prefix = makeDemoLdmPrefix();
        const input = prefix ++ "----" ++ prefix[0..1024].*;
        const sidecar = try vort.storeEncodeSidecarBlockedBestStreamWithLdmAlloc(init.gpa, input, input.len, .{}, .{ .min_distance = 32769, .min_length = 16 });
        defer sidecar.deinit(init.gpa);
        const range = try vort.storeDecodeSidecarIndexedRangeAlloc(init.gpa, sidecar.stream, sidecar.sidecar_index, prefix.len + 4, 24);
        defer init.gpa.free(range);
        const modes = try vort.storeSummarizeModes(sidecar.stream);
        try stdout.print("range_crc32={d} sidecar_ldm_stream_bytes={d} sidecar_bytes={d} modes={d}/{d}/{d}/{d}/{d}\n", .{ vort.crc32(range), sidecar.stream.len, sidecar.sidecar_index.len, modes.store, modes.deflate, modes.rle, modes.dictionary_patch + modes.dictionary_deflate, modes.ldm });
    } else if (std.mem.eql(u8, command, "vort-ldm-indexed-range-demo")) {
        const prefix = makeDemoLdmPrefix();
        const payloads = [_][]const u8{
            prefix ++ "----" ++ prefix[0..1024].*,
            "tail",
        };
        const stream = try vort.storeEncodeIndexedLongDistanceStreamAlloc(init.gpa, &payloads, .{ .min_distance = 32769, .min_length = 16 });
        defer init.gpa.free(stream);
        const range = try vort.storeDecodeIndexedRangeAlloc(init.gpa, stream, prefix.len + 4, 24);
        defer init.gpa.free(range);
        const modes = try vort.storeSummarizeModes(stream);
        try stdout.print("range_crc32={d} ldm_indexed_stream_bytes={d} modes={d}/{d}/{d}/{d}/{d}\n", .{ vort.crc32(range), stream.len, modes.store, modes.deflate, modes.rle, modes.dictionary_patch + modes.dictionary_deflate, modes.ldm });
    } else if (std.mem.eql(u8, command, "store-range-demo")) {
        const payloads = [_][]const u8{ "alpha", "beta", "gamma" };
        const stream = try vort.storeEncodeIndexedStreamAlloc(init.gpa, &payloads);
        defer init.gpa.free(stream);
        const range = try vort.storeDecodeIndexedRangeAlloc(init.gpa, stream, 3, 8);
        defer init.gpa.free(range);
        const modes = try vort.storeSummarizeModes(stream);
        try stdout.print("range={s} indexed_stream_bytes={d} modes={d}/{d}/{d}\n", .{ range, stream.len, modes.store, modes.deflate, modes.rle });
    } else if (std.mem.eql(u8, command, "vort-sidecar-blocked-best-range-demo")) {
        const input = "abcdefghijklmnopqrstuvwxyz" ++ ("aaaaaaaaaaaaaaaa" ** 2) ++ ("abcabcabcabc" ** 2);
        const sidecar = try vort.storeEncodeSidecarBlockedBestStreamAlloc(init.gpa, input, 16);
        defer sidecar.deinit(init.gpa);
        const range = try vort.storeDecodeSidecarIndexedRangeAlloc(init.gpa, sidecar.stream, sidecar.sidecar_index, 10, 32);
        defer init.gpa.free(range);
        const modes = try vort.storeSummarizeModes(sidecar.stream);
        try stdout.print("range={s} stream_bytes={d} sidecar_bytes={d} modes={d}/{d}/{d}\n", .{ range, sidecar.stream.len, sidecar.sidecar_index.len, modes.store, modes.deflate, modes.rle });
    } else if (std.mem.eql(u8, command, "store-sidecar-range-demo")) {
        const first = try vort.storeEncodeAlloc(init.gpa, "alpha");
        defer init.gpa.free(first);
        const second = try vort.storeEncodeAlloc(init.gpa, "beta");
        defer init.gpa.free(second);
        var stream: std.ArrayList(u8) = .empty;
        defer stream.deinit(init.gpa);
        try stream.appendSlice(init.gpa, first);
        try stream.appendSlice(init.gpa, second);
        const index = try vort.storeBuildFrameIndexAlloc(init.gpa, stream.items);
        defer init.gpa.free(index);
        const sidecar = try vort.storeEncodeFrameIndexAlloc(init.gpa, index);
        defer init.gpa.free(sidecar);
        const range = try vort.storeDecodeSidecarIndexedRangeAlloc(init.gpa, stream.items, sidecar, 3, 5);
        defer init.gpa.free(range);
        try stdout.print("range={s} stream_bytes={d} sidecar_bytes={d}\n", .{ range, stream.items.len, sidecar.len });
    } else if (std.mem.eql(u8, command, "store-sidecar-dict-range-demo")) {
        const phrase = "self-contained dictionary phrase for native streams";
        const input = (phrase ++ "!") ** 3;
        const stream = try vort.storeEncodeSelfContainedDictionaryStreamAlloc(init.gpa, input, phrase.len + 1, 256, 8);
        defer init.gpa.free(stream);
        const embedded = try vort.store.parseEmbeddedIndexAlloc(init.gpa, stream);
        defer embedded.deinit(init.gpa);
        const sidecar = try vort.storeEncodeFrameIndexAlloc(init.gpa, embedded.entries);
        defer init.gpa.free(sidecar);
        const range = try vort.storeDecodeSidecarIndexedRangeAutoAlloc(init.gpa, stream, sidecar, 7, 64);
        defer init.gpa.free(range);
        try stdout.print("range={s} stream_bytes={d} sidecar_bytes={d}\n", .{ range, stream.len, sidecar.len });
    } else if (std.mem.eql(u8, command, "encode-raw-fixed-split-hex")) {
        const payload = args.next() orelse "";
        const encoded = try vort.encodeRawFixedSplitAlloc(init.gpa, payload, 7, vort.optionsForCompressionLevel(.fast));
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-raw-best-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawBestAlloc(init.gpa, payload, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-raw-dict-best-hex")) {
        const payload = args.next() orelse "";
        const dictionary = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawBestWithDictionaryAlloc(init.gpa, payload, dictionary, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-raw-dict-best-split-hex")) {
        const payload = args.next() orelse "";
        const dictionary = args.next() orelse "";
        const block_len = try parseBlockLen(args.next(), 7);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawBestSplitWithDictionaryAlloc(init.gpa, payload, dictionary, block_len, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-raw-dict-best-adaptive-hex")) {
        const payload = args.next() orelse "";
        const dictionary = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawBestAdaptiveSplitWithDictionaryAlloc(init.gpa, payload, dictionary, options, options.split_options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-raw-best-split-hex")) {
        const payload = args.next() orelse "";
        const block_len = try parseBlockLen(args.next(), 7);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawBestSplitAlloc(init.gpa, payload, block_len, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-raw-best-adaptive-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawBestAdaptiveSplitAlloc(init.gpa, payload, options, options.split_options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-zlib-best-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibBestAlloc(init.gpa, payload, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-zlib-dict-best-hex")) {
        const payload = args.next() orelse "";
        const dictionary = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibBestWithDictionaryAlloc(init.gpa, payload, dictionary, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-zlib-dict-best-split-hex")) {
        const payload = args.next() orelse "";
        const dictionary = args.next() orelse "";
        const block_len = try parseBlockLen(args.next(), 7);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibBestSplitWithDictionaryAlloc(init.gpa, payload, dictionary, block_len, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-zlib-dict-best-adaptive-hex")) {
        const payload = args.next() orelse "";
        const dictionary = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibBestAdaptiveSplitWithDictionaryAlloc(init.gpa, payload, dictionary, options, options.split_options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-zlib-best-split-hex")) {
        const payload = args.next() orelse "";
        const block_len = try parseBlockLen(args.next(), 7);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibBestSplitAlloc(init.gpa, payload, block_len, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-zlib-best-adaptive-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibBestAdaptiveSplitAlloc(init.gpa, payload, options, options.split_options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-gzip-best-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeGzipBestAlloc(init.gpa, payload, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-gzip-best-split-hex")) {
        const payload = args.next() orelse "";
        const block_len = try parseBlockLen(args.next(), 7);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeGzipBestSplitAlloc(init.gpa, payload, block_len, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-gzip-best-adaptive-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeGzipBestAdaptiveSplitAlloc(init.gpa, payload, options, options.split_options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-raw-dynamic-split-hex")) {
        const payload = args.next() orelse "";
        const encoded = try vort.encodeRawDynamicSplitAlloc(init.gpa, payload, 7, vort.optionsForCompressionLevel(.fast));
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-raw-dynamic-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawDynamicWithOptionsAlloc(init.gpa, payload, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-raw-dict-dynamic-hex")) {
        const payload = args.next() orelse "";
        const dictionary = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawDynamicWithDictionaryAlloc(init.gpa, payload, dictionary, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-zlib-dynamic-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibDynamicWithOptionsAlloc(init.gpa, payload, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-zlib-dict-dynamic-hex")) {
        const payload = args.next() orelse "";
        const dictionary = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibDynamicWithDictionaryAlloc(init.gpa, payload, dictionary, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-gzip-dynamic-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeGzipDynamicWithOptionsAlloc(init.gpa, payload, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-zstd-native-hex")) {
        const payload = args.next() orelse "";
        const selection = try parseZstdNativeSelection(args.next());
        const checksum = try parseOptionalBool(args.next(), true);
        const content_size = try parseOptionalBool(args.next(), true);
        const result = try vort.zstdEncodeNativeFrameWithOptionsAlloc(init.gpa, payload, .{
            .selection = selection,
            .content_checksum = checksum,
            .include_content_size = content_size,
        });
        defer init.gpa.free(result.frame);
        try printHex(stdout, result.frame);
    } else if (std.mem.eql(u8, command, "encode-zstd-native-bytes-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const payload = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(payload);
        const selection = try parseZstdNativeSelection(args.next());
        const checksum = try parseOptionalBool(args.next(), true);
        const content_size = try parseOptionalBool(args.next(), true);
        const result = try vort.zstdEncodeNativeFrameWithOptionsAlloc(init.gpa, payload, .{
            .selection = selection,
            .content_checksum = checksum,
            .include_content_size = content_size,
        });
        defer init.gpa.free(result.frame);
        try printHex(stdout, result.frame);
    } else if (std.mem.eql(u8, command, "decode-zstd-native-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const decoded = if (max_output_len) |limit|
            try vort.zstdDecodeNativeFrameAllocLimited(init.gpa, compressed, limit)
        else
            try vort.zstdDecodeNativeFrameAlloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try printDecoded(stdout, "zstd_native", compressed.len, decoded);
    } else if (std.mem.eql(u8, command, "size-zstd-native-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const decoded_len = if (max_output_len) |limit|
            try vort.zstdDecodedNativeFrameSizeLimited(compressed, limit)
        else
            try vort.zstdDecodedNativeFrameSize(compressed);
        try stdout.print("zstd_native_compressed_bytes={d} decoded_bytes={d}\n", .{ compressed.len, decoded_len });
    } else if (std.mem.eql(u8, command, "size-lz4-block-prefix-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const prefix_hex = args.next() orelse return error.MissingHexInput;
        const max_output_len = try parseOptionalLimit(args.next());
        const block = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(block);
        const prefix = try hexToOwnedBytes(init.gpa, prefix_hex);
        defer init.gpa.free(prefix);
        const decoded_len = if (max_output_len) |limit|
            try vort.lz4DecodedBlockSizeWithPrefixLimited(block, prefix, limit)
        else
            try vort.lz4DecodedBlockSizeWithPrefix(block, prefix);
        try stdout.print("lz4_block_prefix_compressed_bytes={d} prefix_bytes={d} decoded_bytes={d}\n", .{ block.len, prefix.len, decoded_len });
    } else if (std.mem.eql(u8, command, "encode-lz4-block-prefix-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const prefix_hex = args.next() orelse return error.MissingHexInput;
        const payload = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(payload);
        const prefix = try hexToOwnedBytes(init.gpa, prefix_hex);
        defer init.gpa.free(prefix);
        const encoded = try vort.lz4EncodeBlockWithPrefixAlloc(init.gpa, payload, prefix);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "decode-lz4-block-prefix-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const prefix_hex = args.next() orelse return error.MissingHexInput;
        const max_output_len = try parseOptionalLimit(args.next());
        const block = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(block);
        const prefix = try hexToOwnedBytes(init.gpa, prefix_hex);
        defer init.gpa.free(prefix);
        const decoded_len = if (max_output_len) |limit|
            try vort.lz4DecodedBlockSizeWithPrefixLimited(block, prefix, limit)
        else
            try vort.lz4DecodedBlockSizeWithPrefix(block, prefix);
        const decoded = try init.gpa.alloc(u8, decoded_len);
        defer init.gpa.free(decoded);
        const written = try vort.lz4DecodeBlockWithPrefixIntoSliceNoAlloc(block, decoded, decoded_len, prefix);
        if (written != decoded_len) return error.SizeMismatch;
        try printDecoded(stdout, "lz4_block_prefix", block.len, decoded);
    } else if (std.mem.eql(u8, command, "encode-zlib-best-file-hex")) {
        const path = args.next() orelse return error.MissingCorpusPath;
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibBestAlloc(init.gpa, data, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-vort-best-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const encoded = try vort.storeEncodeBestAlloc(init.gpa, data);
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        try stdout.print("input_bytes={d} output_bytes={d} path={s}\n", .{ data.len, encoded.len, output_path });
    } else if (std.mem.eql(u8, command, "encode-raw-fixed-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawFixedWithOptionsAlloc(init.gpa, data, options);
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        try stdout.print("input_bytes={d} output_bytes={d} path={s}\n", .{ data.len, encoded.len, output_path });
    } else if (std.mem.eql(u8, command, "encode-zlib-best-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibBestAlloc(init.gpa, data, options);
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        try stdout.print("input_bytes={d} output_bytes={d} path={s}\n", .{ data.len, encoded.len, output_path });
    } else if (std.mem.eql(u8, command, "encode-raw-best-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawBestAlloc(init.gpa, data, options);
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        try stdout.print("input_bytes={d} output_bytes={d} path={s}\n", .{ data.len, encoded.len, output_path });
    } else if (std.mem.eql(u8, command, "encode-gzip-best-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeGzipBestAlloc(init.gpa, data, options);
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        try stdout.print("input_bytes={d} output_bytes={d} path={s}\n", .{ data.len, encoded.len, output_path });
    } else if (std.mem.eql(u8, command, "encode-raw-dict-best-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const dictionary_path = args.next() orelse return error.MissingCorpusPath;
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const dictionary = try std.Io.Dir.cwd().readFileAlloc(init.io, dictionary_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(dictionary);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawBestWithDictionaryAlloc(init.gpa, data, dictionary, options);
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        try stdout.print("input_bytes={d} dictionary_bytes={d} output_bytes={d} path={s}\n", .{ data.len, dictionary.len, encoded.len, output_path });
    } else if (std.mem.eql(u8, command, "encode-raw-dict-best-split-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const dictionary_path = args.next() orelse return error.MissingCorpusPath;
        const block_len = try parseBlockLen(args.next(), 7);
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const dictionary = try std.Io.Dir.cwd().readFileAlloc(init.io, dictionary_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(dictionary);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawBestSplitWithDictionaryAlloc(init.gpa, data, dictionary, block_len, options);
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        try stdout.print("input_bytes={d} dictionary_bytes={d} block_len={d} output_bytes={d} path={s}\n", .{ data.len, dictionary.len, block_len, encoded.len, output_path });
    } else if (std.mem.eql(u8, command, "encode-raw-dict-best-adaptive-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const dictionary_path = args.next() orelse return error.MissingCorpusPath;
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const dictionary = try std.Io.Dir.cwd().readFileAlloc(init.io, dictionary_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(dictionary);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawBestAdaptiveSplitWithDictionaryAlloc(init.gpa, data, dictionary, options, options.split_options);
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        try stdout.print("input_bytes={d} dictionary_bytes={d} output_bytes={d} path={s}\n", .{ data.len, dictionary.len, encoded.len, output_path });
    } else if (std.mem.eql(u8, command, "encode-zlib-dict-best-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const dictionary_path = args.next() orelse return error.MissingCorpusPath;
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const dictionary = try std.Io.Dir.cwd().readFileAlloc(init.io, dictionary_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(dictionary);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibBestWithDictionaryAlloc(init.gpa, data, dictionary, options);
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        try stdout.print("input_bytes={d} dictionary_bytes={d} output_bytes={d} path={s}\n", .{ data.len, dictionary.len, encoded.len, output_path });
    } else if (std.mem.eql(u8, command, "encode-zlib-dict-best-split-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const dictionary_path = args.next() orelse return error.MissingCorpusPath;
        const block_len = try parseBlockLen(args.next(), 7);
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const dictionary = try std.Io.Dir.cwd().readFileAlloc(init.io, dictionary_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(dictionary);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibBestSplitWithDictionaryAlloc(init.gpa, data, dictionary, block_len, options);
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        try stdout.print("input_bytes={d} dictionary_bytes={d} block_len={d} output_bytes={d} path={s}\n", .{ data.len, dictionary.len, block_len, encoded.len, output_path });
    } else if (std.mem.eql(u8, command, "encode-zlib-dict-best-adaptive-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const dictionary_path = args.next() orelse return error.MissingCorpusPath;
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const dictionary = try std.Io.Dir.cwd().readFileAlloc(init.io, dictionary_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(dictionary);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibBestAdaptiveSplitWithDictionaryAlloc(init.gpa, data, dictionary, options, options.split_options);
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        try stdout.print("input_bytes={d} dictionary_bytes={d} output_bytes={d} path={s}\n", .{ data.len, dictionary.len, encoded.len, output_path });
    } else if (std.mem.eql(u8, command, "encode-vort-sidecar-best-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const stream_path = args.next() orelse return error.MissingCorpusPath;
        const sidecar_path = args.next() orelse return error.MissingCorpusPath;
        const block_len = try parseBlockLen(args.next(), 8192);
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const sidecar = try vort.storeEncodeSidecarBlockedBestStreamAlloc(init.gpa, data, block_len);
        defer sidecar.deinit(init.gpa);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = stream_path, .data = sidecar.stream });
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = sidecar_path, .data = sidecar.sidecar_index });
        try stdout.print("input_bytes={d} stream_bytes={d} sidecar_bytes={d} stream={s} sidecar={s}\n", .{ data.len, sidecar.stream.len, sidecar.sidecar_index.len, stream_path, sidecar_path });
    } else if (std.mem.eql(u8, command, "encode-vort-embedded-best-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const stream_path = args.next() orelse return error.MissingCorpusPath;
        const block_len = try parseBlockLen(args.next(), 8192);
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const stream = try vort.storeEncodeBlockedBestStreamAlloc(init.gpa, data, block_len);
        defer init.gpa.free(stream);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = stream_path, .data = stream });
        try stdout.print("input_bytes={d} stream_bytes={d} embedded_index=true stream={s}\n", .{ data.len, stream.len, stream_path });
    } else if (std.mem.eql(u8, command, "encode-vort-seekable-tier-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const stream_path = args.next() orelse return error.MissingCorpusPath;
        const tier = try parseSeekabilityTier(args.next());
        const options = vort.SeekableNativeOptions.withSeekabilityTier(tier);
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const stream = try vort.storeEncodeSeekableNativeStreamAlloc(init.gpa, data, options);
        defer init.gpa.free(stream);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = stream_path, .data = stream });
        try stdout.print("input_bytes={d} stream_bytes={d} embedded_index=true seekability_tier={s} block_len={d} stream={s}\n", .{ data.len, stream.len, @tagName(tier), options.block_len, stream_path });
    } else if (std.mem.eql(u8, command, "encode-vort-blocked-best-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const stream_path = args.next() orelse return error.MissingCorpusPath;
        const block_len = try parseBlockLen(args.next(), 8192);
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const sidecar = try vort.storeEncodeSidecarBlockedBestStreamAlloc(init.gpa, data, block_len);
        defer sidecar.deinit(init.gpa);
        // zstd_compare uses this command to isolate block-fragmentation bytes:
        // write only the concatenated data frames, not the sidecar index payload.
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = stream_path, .data = sidecar.stream });
        try stdout.print("input_bytes={d} stream_bytes={d} sidecar_bytes={d} embedded_index=false stream={s}\n", .{ data.len, sidecar.stream.len, sidecar.sidecar_index.len, stream_path });
    } else if (std.mem.eql(u8, command, "encode-vort-embedded-dict-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const stream_path = args.next() orelse return error.MissingCorpusPath;
        const block_len = try parseBlockLen(args.next(), 8192);
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const stream = try vort.storeEncodeSelfContainedDictionaryStreamAlloc(init.gpa, data, block_len, 256, 8);
        defer init.gpa.free(stream);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = stream_path, .data = stream });
        try stdout.print("input_bytes={d} stream_bytes={d} embedded_index=true embedded_dictionary=true stream={s}\n", .{ data.len, stream.len, stream_path });
    } else if (std.mem.eql(u8, command, "verify-vort-sidecar-index-file")) {
        const stream_path = args.next() orelse return error.MissingCorpusPath;
        const sidecar_path = args.next() orelse return error.MissingCorpusPath;
        const validation_mode = try parseSidecarValidationMode(args.next());
        const output_format = try parseValidationOutputFormat(args.next());
        const stream = try std.Io.Dir.cwd().readFileAlloc(init.io, stream_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(stream);
        const sidecar = try std.Io.Dir.cwd().readFileAlloc(init.io, sidecar_path, init.gpa, .limited(16 * 1024 * 1024));
        defer init.gpa.free(sidecar);
        const report = vort.storeValidateSidecarIndexReportAlloc(init.gpa, stream, sidecar, .{ .mode = validation_mode });
        if (!report.ok) {
            if (output_format == .json) {
                try printValidationJson(stdout, "sidecar", report, stream.len, sidecar.len);
            } else {
                try printValidationFailure(stdout, "sidecar", report);
            }
            try stdout.flush();
            return error.CorruptFrame;
        }
        if (output_format == .json) {
            try printValidationJson(stdout, "sidecar", report, stream.len, sidecar.len);
        } else {
            try stdout.print("sidecar_ok=true mode={s} stream_bytes={d} sidecar_bytes={d}\n", .{ @tagName(validation_mode), stream.len, sidecar.len });
        }
    } else if (std.mem.eql(u8, command, "verify-vort-embedded-index-file")) {
        const stream_path = args.next() orelse return error.MissingCorpusPath;
        const validation_mode = try parseSidecarValidationMode(args.next());
        const output_format = try parseValidationOutputFormat(args.next());
        const stream = try std.Io.Dir.cwd().readFileAlloc(init.io, stream_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(stream);
        const report = vort.storeValidateEmbeddedIndexReportAlloc(init.gpa, stream, .{ .mode = validation_mode });
        if (!report.ok) {
            if (output_format == .json) {
                try printValidationJson(stdout, "embedded", report, stream.len, null);
            } else {
                try printValidationFailure(stdout, "embedded", report);
            }
            try stdout.flush();
            return error.CorruptFrame;
        }
        if (output_format == .json) {
            try printValidationJson(stdout, "embedded", report, stream.len, null);
        } else {
            try stdout.print("embedded_index_ok=true mode={s} stream_bytes={d}\n", .{ @tagName(validation_mode), stream.len });
        }
    } else if (std.mem.eql(u8, command, "decode-vort-sidecar-range-file")) {
        const stream_path = args.next() orelse return error.MissingCorpusPath;
        const sidecar_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const offset = try std.fmt.parseInt(u64, args.next() orelse return error.MissingCorpusPath, 10);
        const length = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
        const stream = try std.Io.Dir.cwd().readFileAlloc(init.io, stream_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(stream);
        const sidecar = try std.Io.Dir.cwd().readFileAlloc(init.io, sidecar_path, init.gpa, .limited(16 * 1024 * 1024));
        defer init.gpa.free(sidecar);
        const range = try vort.storeDecodeSidecarIndexedRangeAlloc(init.gpa, stream, sidecar, offset, length);
        defer init.gpa.free(range);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = range });
        try stdout.print("range_bytes={d} crc32={d} path={s}\n", .{ range.len, vort.crc32(range), output_path });
    } else if (std.mem.eql(u8, command, "decode-vort-embedded-range-file")) {
        const stream_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const offset = try std.fmt.parseInt(u64, args.next() orelse return error.MissingCorpusPath, 10);
        const length = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
        const stream = try std.Io.Dir.cwd().readFileAlloc(init.io, stream_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(stream);
        const range = try vort.storeDecodeIndexedRangeAlloc(init.gpa, stream, offset, length);
        defer init.gpa.free(range);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = range });
        try stdout.print("range_bytes={d} crc32={d} path={s}\n", .{ range.len, vort.crc32(range), output_path });
    } else if (std.mem.eql(u8, command, "bench-decode-raw-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const expected_output_len = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
        const iterations = try parseIterations(args.next(), 3);
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const output = try init.gpa.alloc(u8, expected_output_len);
        defer init.gpa.free(output);
        const result = try benchDecodeRaw(compressed, output, iterations, init.io);
        try stdout.print("mode=raw compressed_bytes={d} decoded_bytes={d} iterations={d} elapsed_ns={d} checksum={d}\n", .{ compressed.len, result.decoded_bytes, iterations, result.elapsed_ns, result.checksum });
    } else if (std.mem.eql(u8, command, "bench-decode-vort-best-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const expected_output_len = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
        const iterations = try parseIterations(args.next(), 3);
        const frame = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(frame);
        const output = try init.gpa.alloc(u8, expected_output_len);
        defer init.gpa.free(output);
        const result = try benchDecodeVortBest(frame, output, iterations, init.io);
        try stdout.print("mode=vort_best compressed_bytes={d} decoded_bytes={d} iterations={d} elapsed_ns={d} checksum={d}\n", .{ frame.len, result.decoded_bytes, iterations, result.elapsed_ns, result.checksum });
    } else if (std.mem.eql(u8, command, "bench-decode-vort-embedded-range-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const length = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
        const iterations = try parseIterations(args.next(), 3);
        const stream = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(stream);
        const output = try init.gpa.alloc(u8, length);
        defer init.gpa.free(output);
        const result = try benchDecodeVortEmbeddedRange(init.gpa, stream, 0, output, iterations, init.io);
        try stdout.print("mode=vort_embedded compressed_bytes={d} decoded_bytes={d} iterations={d} elapsed_ns={d} checksum={d}\n", .{ stream.len, result.decoded_bytes, iterations, result.elapsed_ns, result.checksum });
    } else if (std.mem.eql(u8, command, "bench-decode-vort-embedded-offset-range-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const offset = try std.fmt.parseInt(u64, args.next() orelse return error.MissingCorpusPath, 10);
        const length = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
        const iterations = try parseIterations(args.next(), 3);
        const stream = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(stream);
        const output = try init.gpa.alloc(u8, length);
        defer init.gpa.free(output);
        const result = try benchDecodeVortEmbeddedRange(init.gpa, stream, offset, output, iterations, init.io);
        try stdout.print("mode=vort_embedded_range offset={d} compressed_bytes={d} decoded_bytes={d} iterations={d} elapsed_ns={d} checksum={d}\n", .{ offset, stream.len, result.decoded_bytes, iterations, result.elapsed_ns, result.checksum });
    } else if (std.mem.eql(u8, command, "decode-vort-embedded-auto-range-file")) {
        const stream_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const offset = try std.fmt.parseInt(u64, args.next() orelse return error.MissingCorpusPath, 10);
        const length = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
        const stream = try std.Io.Dir.cwd().readFileAlloc(init.io, stream_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(stream);
        const range = try vort.storeDecodeIndexedRangeAutoAlloc(init.gpa, stream, offset, length);
        defer init.gpa.free(range);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = range });
        try stdout.print("range_bytes={d} crc32={d} path={s}\n", .{ range.len, vort.crc32(range), output_path });
    } else if (std.mem.eql(u8, command, "encode-vort-sidecar-dict-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const stream_path = args.next() orelse return error.MissingCorpusPath;
        const sidecar_path = args.next() orelse return error.MissingCorpusPath;
        const block_len = try parseBlockLen(args.next(), 8192);
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const sidecar = try vort.storeEncodeSidecarSelfContainedDictionaryStreamAlloc(init.gpa, data, block_len, 256, 8);
        defer sidecar.deinit(init.gpa);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = stream_path, .data = sidecar.stream });
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = sidecar_path, .data = sidecar.sidecar_index });
        try stdout.print("input_bytes={d} stream_bytes={d} sidecar_bytes={d} stream={s} sidecar={s}\n", .{ data.len, sidecar.stream.len, sidecar.sidecar_index.len, stream_path, sidecar_path });
    } else if (std.mem.eql(u8, command, "decode-vort-sidecar-auto-range-file")) {
        const stream_path = args.next() orelse return error.MissingCorpusPath;
        const sidecar_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const offset = try std.fmt.parseInt(u64, args.next() orelse return error.MissingCorpusPath, 10);
        const length = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
        const stream = try std.Io.Dir.cwd().readFileAlloc(init.io, stream_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(stream);
        const sidecar = try std.Io.Dir.cwd().readFileAlloc(init.io, sidecar_path, init.gpa, .limited(16 * 1024 * 1024));
        defer init.gpa.free(sidecar);
        const range = try vort.storeDecodeSidecarIndexedRangeAutoAlloc(init.gpa, stream, sidecar, offset, length);
        defer init.gpa.free(range);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = range });
        try stdout.print("range_bytes={d} crc32={d} path={s}\n", .{ range.len, vort.crc32(range), output_path });
    } else if (std.mem.eql(u8, command, "encode-vort-sidecar-ldm-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const stream_path = args.next() orelse return error.MissingCorpusPath;
        const sidecar_path = args.next() orelse return error.MissingCorpusPath;
        const block_len = try parseBlockLen(args.next(), 8192);
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const sidecar = try vort.storeEncodeSidecarBlockedBestStreamWithLdmAlloc(init.gpa, data, block_len, .{}, .{ .min_distance = 32769, .min_length = 16 });
        defer sidecar.deinit(init.gpa);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = stream_path, .data = sidecar.stream });
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = sidecar_path, .data = sidecar.sidecar_index });
        try stdout.print("input_bytes={d} stream_bytes={d} sidecar_bytes={d} stream={s} sidecar={s}\n", .{ data.len, sidecar.stream.len, sidecar.sidecar_index.len, stream_path, sidecar_path });
    } else if (std.mem.eql(u8, command, "decode-raw-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const decoded = if (max_output_len) |limit|
            try vort.decodeRawDeflateAllocLimited(init.gpa, compressed, limit)
        else
            try vort.decodeRawDeflateAlloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try printDecoded(stdout, "raw", compressed.len, decoded);
    } else if (std.mem.eql(u8, command, "decode-raw-dict-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const dictionary = args.next() orelse "";
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const decoded = if (max_output_len) |limit|
            try vort.decodeRawDeflateAllocWithDictionaryLimited(init.gpa, compressed, dictionary, limit)
        else
            try vort.decodeRawDeflateAllocWithDictionary(init.gpa, compressed, dictionary);
        defer init.gpa.free(decoded);
        try printDecoded(stdout, "raw_dict", compressed.len, decoded);
    } else if (std.mem.eql(u8, command, "decode-raw-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const decoded = if (max_output_len) |limit|
            try vort.decodeRawDeflateAllocLimited(init.gpa, compressed, limit)
        else
            try vort.decodeRawDeflateAlloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
        try stdout.print("compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ compressed.len, decoded.len, output_path });
    } else if (std.mem.eql(u8, command, "decode-raw-dict-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const dictionary_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const dictionary = try std.Io.Dir.cwd().readFileAlloc(init.io, dictionary_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(dictionary);
        const decoded = if (max_output_len) |limit|
            try vort.decodeRawDeflateAllocWithDictionaryLimited(init.gpa, compressed, dictionary, limit)
        else
            try vort.decodeRawDeflateAllocWithDictionary(init.gpa, compressed, dictionary);
        defer init.gpa.free(decoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
        try stdout.print("compressed_bytes={d} dictionary_bytes={d} decoded_bytes={d} path={s}\n", .{ compressed.len, dictionary.len, decoded.len, output_path });
    } else if (std.mem.eql(u8, command, "inspect-raw-header-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_format = try parseHeaderInspectOutputFormat(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const info = try vort.parseRawDeflateHeaderInfo(compressed);
        try printRawHeaderInfo(stdout, compressed.len, info, output_format);
    } else if (std.mem.eql(u8, command, "decode-zlib-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const decoded = if (max_output_len) |limit|
            try vort.decodeZlibAllocLimited(init.gpa, compressed, limit)
        else
            try vort.decodeZlibAlloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
        try stdout.print("compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ compressed.len, decoded.len, output_path });
    } else if (std.mem.eql(u8, command, "decode-zlib-concat-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const decoded = if (max_output_len) |limit|
            try vort.decodeZlibConcatenatedAllocLimited(init.gpa, compressed, limit)
        else
            try vort.decodeZlibConcatenatedAlloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
        try stdout.print("compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ compressed.len, decoded.len, output_path });
    } else if (std.mem.eql(u8, command, "decode-zlib-dict-concat-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const dictionary_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const dictionary = try std.Io.Dir.cwd().readFileAlloc(init.io, dictionary_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(dictionary);
        const decoded = if (max_output_len) |limit|
            try vort.decodeZlibConcatenatedAllocWithDictionaryLimited(init.gpa, compressed, dictionary, limit)
        else
            try vort.decodeZlibConcatenatedAllocWithDictionary(init.gpa, compressed, dictionary);
        defer init.gpa.free(decoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
        try stdout.print("compressed_bytes={d} dictionary_bytes={d} decoded_bytes={d} path={s}\n", .{ compressed.len, dictionary.len, decoded.len, output_path });
    } else if (std.mem.eql(u8, command, "inspect-zlib-header-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_format = try parseHeaderInspectOutputFormat(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const info = try vort.parseZlibHeaderInfo(compressed);
        try printZlibHeaderInfo(stdout, compressed.len, info, output_format);
    } else if (std.mem.eql(u8, command, "inspect-zlib-deflate-header-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_format = try parseHeaderInspectOutputFormat(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const wrapper = try vort.parseZlibHeaderInfo(compressed);
        const info = try vort.parseRawDeflateHeaderInfo(compressed[wrapper.data_offset..]);
        if (output_format == .json) {
            const stream = try inspectZlibStreamForWrappedJson(init.gpa, compressed);
            try printWrappedDeflateHeaderJson(stdout, zlibWrappedDeflateContext(compressed.len, wrapper.data_offset, stream), info);
        } else {
            try printRawHeaderInfo(stdout, compressed.len - wrapper.data_offset, info, output_format);
        }
    } else if (std.mem.eql(u8, command, "inspect-zlib-dict-deflate-header-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const dictionary_path = args.next() orelse return error.MissingCorpusPath;
        const output_format = try parseHeaderInspectOutputFormat(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const dictionary = try std.Io.Dir.cwd().readFileAlloc(init.io, dictionary_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(dictionary);
        const wrapper = try vort.parseZlibHeaderInfo(compressed);
        const info = try vort.parseRawDeflateHeaderInfo(compressed[wrapper.data_offset..]);
        const stream = try vort.inspectZlibStreamAllocWithDictionary(init.gpa, compressed, dictionary);
        if (output_format == .json) {
            try printWrappedDeflateHeaderJson(stdout, zlibWrappedDeflateContext(compressed.len, wrapper.data_offset, stream), info);
        } else {
            try printRawHeaderInfo(stdout, compressed.len - wrapper.data_offset, info, output_format);
        }
    } else if (std.mem.eql(u8, command, "decode-zlib-dict-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const dictionary_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const dictionary = try std.Io.Dir.cwd().readFileAlloc(init.io, dictionary_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(dictionary);
        const decoded = if (max_output_len) |limit|
            try vort.decodeZlibAllocWithDictionaryLimited(init.gpa, compressed, dictionary, limit)
        else
            try vort.decodeZlibAllocWithDictionary(init.gpa, compressed, dictionary);
        defer init.gpa.free(decoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
        try stdout.print("compressed_bytes={d} dictionary_bytes={d} decoded_bytes={d} path={s}\n", .{ compressed.len, dictionary.len, decoded.len, output_path });
    } else if (std.mem.eql(u8, command, "decode-gzip-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const decoded = if (max_output_len) |limit|
            try vort.decodeGzipConcatenatedAllocLimited(init.gpa, compressed, limit)
        else
            try vort.decodeGzipConcatenatedAlloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
        try stdout.print("compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ compressed.len, decoded.len, output_path });
    } else if (std.mem.eql(u8, command, "inspect-gzip-header-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_format = try parseHeaderInspectOutputFormat(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const info = try vort.parseGzipHeaderInfo(compressed);
        try printGzipHeaderInfo(stdout, compressed.len, info, output_format);
    } else if (std.mem.eql(u8, command, "inspect-gzip-deflate-header-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_format = try parseHeaderInspectOutputFormat(args.next());
        const member_index = try parseOptionalMemberIndex(args.next());
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const member = try vort.inspectGzipMemberAlloc(init.gpa, compressed, member_index);
        const info = try vort.parseRawDeflateHeaderInfo(compressed[member.deflate_offset..]);
        if (output_format == .json)
            try printWrappedDeflateHeaderJson(stdout, gzipWrappedDeflateContext(compressed.len, member), info)
        else
            try printRawHeaderInfo(stdout, compressed.len - member.deflate_offset, info, output_format);
    } else if (std.mem.eql(u8, command, "decode-zlib-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const decoded = if (max_output_len) |limit|
            try vort.decodeZlibAllocLimited(init.gpa, compressed, limit)
        else
            try vort.decodeZlibAlloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try printDecoded(stdout, "zlib", compressed.len, decoded);
    } else if (std.mem.eql(u8, command, "decode-zlib-concat-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const decoded = if (max_output_len) |limit|
            try vort.decodeZlibConcatenatedAllocLimited(init.gpa, compressed, limit)
        else
            try vort.decodeZlibConcatenatedAlloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try printDecoded(stdout, "zlib_concat", compressed.len, decoded);
    } else if (std.mem.eql(u8, command, "decode-zlib-dict-concat-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const dictionary = args.next() orelse "";
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const decoded = if (max_output_len) |limit|
            try vort.decodeZlibConcatenatedAllocWithDictionaryLimited(init.gpa, compressed, dictionary, limit)
        else
            try vort.decodeZlibConcatenatedAllocWithDictionary(init.gpa, compressed, dictionary);
        defer init.gpa.free(decoded);
        try printDecoded(stdout, "zlib_dict_concat", compressed.len, decoded);
    } else if (std.mem.eql(u8, command, "inspect-raw-header-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const output_format = try parseHeaderInspectOutputFormat(args.next());
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const info = try vort.parseRawDeflateHeaderInfo(compressed);
        try printRawHeaderInfo(stdout, compressed.len, info, output_format);
    } else if (std.mem.eql(u8, command, "inspect-zlib-header-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const output_format = try parseHeaderInspectOutputFormat(args.next());
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const info = try vort.parseZlibHeaderInfo(compressed);
        try printZlibHeaderInfo(stdout, compressed.len, info, output_format);
    } else if (std.mem.eql(u8, command, "inspect-zlib-deflate-header-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const output_format = try parseHeaderInspectOutputFormat(args.next());
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const wrapper = try vort.parseZlibHeaderInfo(compressed);
        const info = try vort.parseRawDeflateHeaderInfo(compressed[wrapper.data_offset..]);
        if (output_format == .json) {
            const stream = try inspectZlibStreamForWrappedJson(init.gpa, compressed);
            try printWrappedDeflateHeaderJson(stdout, zlibWrappedDeflateContext(compressed.len, wrapper.data_offset, stream), info);
        } else {
            try printRawHeaderInfo(stdout, compressed.len - wrapper.data_offset, info, output_format);
        }
    } else if (std.mem.eql(u8, command, "inspect-zlib-dict-deflate-header-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const dictionary = args.next() orelse return error.MissingCorpusPath;
        const output_format = try parseHeaderInspectOutputFormat(args.next());
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const wrapper = try vort.parseZlibHeaderInfo(compressed);
        const info = try vort.parseRawDeflateHeaderInfo(compressed[wrapper.data_offset..]);
        const stream = try vort.inspectZlibStreamAllocWithDictionary(init.gpa, compressed, dictionary);
        if (output_format == .json) {
            try printWrappedDeflateHeaderJson(stdout, zlibWrappedDeflateContext(compressed.len, wrapper.data_offset, stream), info);
        } else {
            try printRawHeaderInfo(stdout, compressed.len - wrapper.data_offset, info, output_format);
        }
    } else if (std.mem.eql(u8, command, "decode-zlib-dict-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const dictionary = args.next() orelse "";
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const decoded = if (max_output_len) |limit|
            try vort.decodeZlibAllocWithDictionaryLimited(init.gpa, compressed, dictionary, limit)
        else
            try vort.decodeZlibAllocWithDictionary(init.gpa, compressed, dictionary);
        defer init.gpa.free(decoded);
        try printDecoded(stdout, "zlib_dict", compressed.len, decoded);
    } else if (std.mem.eql(u8, command, "decode-gzip-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const max_output_len = try parseOptionalLimit(args.next());
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const decoded = if (max_output_len) |limit|
            try vort.decodeGzipConcatenatedAllocLimited(init.gpa, compressed, limit)
        else
            try vort.decodeGzipConcatenatedAlloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try printDecoded(stdout, "gzip", compressed.len, decoded);
    } else if (std.mem.eql(u8, command, "inspect-gzip-header-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const output_format = try parseHeaderInspectOutputFormat(args.next());
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const info = try vort.parseGzipHeaderInfo(compressed);
        try printGzipHeaderInfo(stdout, compressed.len, info, output_format);
    } else if (std.mem.eql(u8, command, "inspect-gzip-deflate-header-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const output_format = try parseHeaderInspectOutputFormat(args.next());
        const member_index = try parseOptionalMemberIndex(args.next());
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const member = try vort.inspectGzipMemberAlloc(init.gpa, compressed, member_index);
        const info = try vort.parseRawDeflateHeaderInfo(compressed[member.deflate_offset..]);
        if (output_format == .json)
            try printWrappedDeflateHeaderJson(stdout, gzipWrappedDeflateContext(compressed.len, member), info)
        else
            try printRawHeaderInfo(stdout, compressed.len - member.deflate_offset, info, output_format);
    } else {
        try stdout.print("unknown command: {s}\n\n", .{command});
        try printHelp(stdout);
    }

    try stdout.flush();
}

fn printHelp(stdout: *std.Io.Writer) !void {
    try stdout.print(
        \\vort bootstrap CLI
        \\
        \\basics:
        \\  help | --help              Show this message
        \\  checksum [text]            Print Adler-32, CRC-32, and CRC-32C for text
        \\  checksum-file [path]       Print Adler-32, CRC-32, and CRC-32C for a file
        \\  store-roundtrip [text]     Encode/decode the native store frame
        \\
        \\compatibility formats:
        \\  zlib-store-roundtrip [text] Encode/decode zlib-wrapped stored deflate
        \\  gzip-store-roundtrip [text] Encode/decode gzip-wrapped stored deflate
        \\  encode-zstd-native-hex [text] [auto|raw_or_rle|literal_only] [checksum] [content_size]
        \\                              Encode text as dependency-free native-subset Zstandard hex
        \\  encode-zstd-native-bytes-hex [hex] [auto|raw_or_rle|literal_only] [checksum] [content_size]
        \\                              Encode bytes as dependency-free native-subset Zstandard hex
        \\  decode-zstd-native-hex [hex] [max_output]
        \\                              Decode dependency-free native-subset Zstandard hex
        \\  size-zstd-native-hex [hex] [max_output]
        \\                              Preflight dependency-free native-subset Zstandard decoded size
        \\  size-lz4-block-prefix-hex [hex] [prefix_hex] [max_output]
        \\                              Preflight LZ4 block decoded size with prefix history
        \\  encode-lz4-block-prefix-hex [hex] [prefix_hex]
        \\                              Encode LZ4 block with prefix history
        \\  decode-lz4-block-prefix-hex [hex] [prefix_hex] [max_output]
        \\                              Decode LZ4 block with prefix history
        \\  decode-raw-hex [hex] [max_output]
        \\                              Decode raw deflate hex to text
        \\  decode-raw-dict-hex [hex] [dict] [max_output]
        \\                              Decode raw deflate hex with a preset dictionary
        \\  decode-raw-file <in> <out> [max_output]
        \\                              Decode raw deflate file bytes with an optional output limit
        \\  decode-raw-dict-file <in> <out> <dict> [max_output]
        \\                              Decode raw deflate file bytes with a preset dictionary file
        \\  inspect-raw-header-hex [hex] [text|json]
        \\                              Print parsed raw deflate first-block metadata for hex input
        \\  inspect-raw-header-file <in> [text|json]
        \\                              Print parsed raw deflate first-block metadata for a file
        \\  decode-zlib-hex [hex] [max_output]
        \\                              Decode zlib-wrapped deflate hex to text
        \\  decode-zlib-concat-hex [hex] [max_output]
        \\                              Decode concatenated zlib stream hex to text
        \\  decode-zlib-dict-concat-hex [hex] [dict] [max_output]
        \\                              Decode concatenated zlib FDICT stream hex with a preset dictionary
        \\  decode-zlib-dict-hex [hex] [dict] [max_output]
        \\                              Decode zlib-wrapped deflate hex with a preset dictionary
        \\  decode-zlib-file <in> <out> [max_output]
        \\                              Decode a zlib file with an optional output limit
        \\  decode-zlib-concat-file <in> <out> [max_output]
        \\                              Decode a concatenated zlib file with an optional output limit
        \\  decode-zlib-dict-concat-file <in> <out> <dict> [max_output]
        \\                              Decode a concatenated zlib FDICT file with a preset dictionary file
        \\  decode-zlib-dict-file <in> <out> <dict> [max_output]
        \\                              Decode a zlib file with a preset dictionary file
        \\  inspect-zlib-header-hex [hex] [text|json]
        \\                              Print parsed zlib header metadata for hex input
        \\  inspect-zlib-header-file <in> [text|json]
        \\                              Print parsed zlib header metadata for a file
        \\  inspect-zlib-deflate-header-hex [hex] [text|json]
        \\                              Inspect the raw deflate header inside a zlib stream
        \\  inspect-zlib-dict-deflate-header-hex [hex] [dict] [text|json]
        \\                              Inspect a zlib FDICT stream using a preset dictionary
        \\  inspect-zlib-deflate-header-file <in> [text|json]
        \\                              Inspect the raw deflate header inside a zlib file
        \\  inspect-zlib-dict-deflate-header-file <in> <dict> [text|json]
        \\                              Inspect a zlib FDICT file using a preset dictionary file
        \\  decode-gzip-hex [hex] [max_output]
        \\                              Decode gzip-wrapped deflate hex to text
        \\  decode-gzip-file <in> <out> [max_output]
        \\                              Decode a gzip file with an optional output limit
        \\  inspect-gzip-header-hex [hex] [text|json]
        \\                              Print parsed gzip header metadata for hex input
        \\  inspect-gzip-header-file <in> [text|json]
        \\                              Print parsed gzip header metadata for a file
        \\  inspect-gzip-deflate-header-hex [hex] [text|json] [member_index]
        \\                              Inspect the raw deflate header inside a gzip stream member
        \\  inspect-gzip-deflate-header-file <in> [text|json] [member_index]
        \\                              Inspect the raw deflate header inside a gzip file member
        \\  encode-raw-dict-best-hex [text] [dict] [level]
        \\                              Encode raw deflate that may reference preset dictionary history
        \\  encode-zlib-dict-best-hex [text] [dict] [level]
        \\                              Encode a zlib FDICT/DICTID frame requiring a preset dictionary
        \\  encode-vort-best-file <in> <out>
        \\                              Encode one native Vort best frame
        \\  encode-raw-fixed-file <in> <out> [level]
        \\                              Encode raw deflate file bytes with fixed Huffman blocks
        \\  encode-zlib-best-file <in> <out> [level]
        \\                              Encode a zlib-compatible file with best-block selection
        \\  encode-raw-best-file <in> <out> [level]
        \\                              Encode raw deflate file bytes with best-block selection
        \\  encode-gzip-best-file <in> <out> [level]
        \\                              Encode a gzip-compatible file with best-block selection
        \\  encode-raw-dict-best-file <in> <out> <dict> [level]
        \\                              Encode raw deflate file bytes using preset dictionary history
        \\  encode-raw-dict-best-split-file <in> <out> <dict> <block_len> [level]
        \\                              Encode split raw deflate file bytes using preset dictionary history
        \\  encode-raw-dict-best-adaptive-file <in> <out> <dict> [level]
        \\                              Encode adaptive-split raw deflate file bytes using preset dictionary history
        \\  encode-zlib-dict-best-file <in> <out> <dict> [level]
        \\                              Encode a zlib FDICT/DICTID file using preset dictionary history
        \\  encode-zlib-dict-best-split-file <in> <out> <dict> <block_len> [level]
        \\                              Encode split zlib FDICT/DICTID file using preset dictionary history
        \\  encode-zlib-dict-best-adaptive-file <in> <out> <dict> [level]
        \\                              Encode adaptive-split zlib FDICT/DICTID file using preset dictionary history
        \\
        \\native indexed file workflows:
        \\  encode-vort-sidecar-best-file <in> <stream> <sidecar> [block_len]
        \\                              Encode native Vort stream plus external sidecar index
        \\  verify-vort-sidecar-index-file <stream> <sidecar> [full|metadata] [text|json]
        \\                              Validate an external sidecar index against a stream
        \\  decode-vort-sidecar-range-file <stream> <sidecar> <out> <offset> <len>
        \\                              Decode an indexed range through an external sidecar
        \\  encode-vort-embedded-best-file <in> <stream> [block_len]
        \\                              Encode native Vort stream with embedded index
        \\  encode-vort-seekable-tier-file <in> <stream> <seek_fast|balanced|ratio>
        \\                              Encode native Vort stream using a seekability tier block size
        \\  encode-vort-blocked-best-file <in> <stream> [block_len]
        \\                              Encode native Vort blocked stream without embedded index
        \\  verify-vort-embedded-index-file <stream> [full|metadata] [text|json]
        \\                              Validate an embedded-index stream
        \\  decode-vort-embedded-range-file <stream> <out> <offset> <len>
        \\                              Decode an indexed range from an embedded-index stream
        \\  bench-decode-raw-file <in> <decoded_len> [iterations]
        \\                              Time raw deflate decode in one CLI process
        \\  bench-decode-vort-best-file <in> <decoded_len> [iterations]
        \\                              Time native Vort best-frame decode in one CLI process
        \\  bench-decode-vort-embedded-range-file <stream> <decoded_len> [iterations]
        \\                              Time embedded-index range decode in one CLI process
        \\  bench-decode-vort-embedded-offset-range-file <stream> <offset> <len> [iterations]
        \\                              Time embedded-index offset range decode in one CLI process
        \\  encode-vort-embedded-dict-file <in> <stream> [block_len]
        \\                              Encode self-contained dictionary stream with embedded index
        \\  decode-vort-embedded-auto-range-file <stream> <out> <offset> <len>
        \\                              Decode embedded-index range with dictionary auto-detection
        \\  encode-vort-sidecar-dict-file <in> <stream> <sidecar> [block_len]
        \\                              Encode self-contained dictionary stream plus sidecar index
        \\  decode-vort-sidecar-auto-range-file <stream> <sidecar> <out> <offset> <len>
        \\                              Decode sidecar range with embedded dictionary auto-detection
        \\  encode-vort-sidecar-ldm-file <in> <stream> <sidecar> [block_len]
        \\                              Encode LDM-aware native stream plus sidecar index
        \\
        \\This CLI is a smoke surface for the library-first Vort APIs.
        \\
    , .{});
}

fn hexToOwnedBytes(allocator: std.mem.Allocator, hex: []const u8) ![]u8 {
    if ((hex.len & 1) != 0) return error.InvalidHexInput;
    const bytes = try allocator.alloc(u8, hex.len / 2);
    errdefer allocator.free(bytes);
    var i: usize = 0;
    while (i < bytes.len) : (i += 1) {
        bytes[i] = try std.fmt.parseInt(u8, hex[i * 2 .. i * 2 + 2], 16);
    }
    return bytes;
}

fn printDecoded(stdout: *std.Io.Writer, label: []const u8, compressed_len: usize, decoded: []const u8) !void {
    try stdout.print("{s}_compressed_bytes={d} decoded_bytes={d} crc32={d} text={s}\n", .{
        label,
        compressed_len,
        decoded.len,
        vort.crc32(decoded),
        decoded,
    });
}

fn printHex(stdout: *std.Io.Writer, bytes: []const u8) !void {
    try printHexInline(stdout, bytes);
    try stdout.print("\n", .{});
}

fn printHexInline(stdout: *std.Io.Writer, bytes: []const u8) !void {
    for (bytes) |byte| try stdout.print("{x:0>2}", .{byte});
}

const DecodeBenchResult = struct {
    elapsed_ns: u64,
    decoded_bytes: usize,
    checksum: u32,
};

fn benchDecodeRaw(compressed: []const u8, output: []u8, iterations: usize, io: std.Io) !DecodeBenchResult {
    const start = std.Io.Clock.awake.now(io);
    var checksum: u32 = 0;
    var decoded_bytes: usize = 0;
    for (0..iterations) |_| {
        const result = try vort.decodeRawDeflate(compressed, output);
        decoded_bytes = result.output_written;
        checksum +%= vort.crc32(output[0..decoded_bytes]);
    }
    const elapsed_ns_signed = start.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds();
    if (elapsed_ns_signed < 0) return error.InvalidTimestamp;
    return .{
        .elapsed_ns = @intCast(elapsed_ns_signed),
        .decoded_bytes = decoded_bytes,
        .checksum = checksum,
    };
}

fn benchDecodeVortBest(frame: []const u8, output: []u8, iterations: usize, io: std.Io) !DecodeBenchResult {
    const start = std.Io.Clock.awake.now(io);
    var checksum: u32 = 0;
    var decoded_bytes: usize = 0;
    for (0..iterations) |_| {
        decoded_bytes = try vort.storeDecodeAnyInto(frame, output);
        checksum +%= vort.crc32(output[0..decoded_bytes]);
    }
    const elapsed_ns_signed = start.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds();
    if (elapsed_ns_signed < 0) return error.InvalidTimestamp;
    return .{
        .elapsed_ns = @intCast(elapsed_ns_signed),
        .decoded_bytes = decoded_bytes,
        .checksum = checksum,
    };
}

fn benchDecodeVortEmbeddedRange(allocator: std.mem.Allocator, stream: []const u8, offset: u64, output: []u8, iterations: usize, io: std.Io) !DecodeBenchResult {
    const embedded_index = try vort.storeViewEmbeddedIndex(stream);
    const index_len = embedded_index.entry_count;
    const index_buffer = try allocator.alloc(vort.StoreFrameIndexEntry, index_len);
    defer allocator.free(index_buffer);
    const start = std.Io.Clock.awake.now(io);
    var checksum: u32 = 0;
    var decoded_bytes: usize = 0;
    for (0..iterations) |_| {
        const result = try vort.storeDecodeIndexedRangeIntoWithIndexBuffer(allocator, stream, offset, output.len, output, index_buffer);
        decoded_bytes = result.output_written;
        checksum +%= result.crc32;
    }
    const elapsed_ns_signed = start.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds();
    if (elapsed_ns_signed < 0) return error.InvalidTimestamp;
    return .{
        .elapsed_ns = @intCast(elapsed_ns_signed),
        .decoded_bytes = decoded_bytes,
        .checksum = checksum,
    };
}

const HeaderInspectOutputFormat = enum { text, json };

const WrappedDeflateContext = struct {
    wrapper: []const u8,
    wrapper_bytes: usize,
    member_offset: usize,
    deflate_offset: usize,
    member_index: usize,
    exact_deflate_bytes: ?usize = null,
    stream_deflate_bytes: ?usize = null,
    stream_output_bytes: ?usize = null,
    stream_footer_offset: ?usize = null,
    stream_end_offset: ?usize = null,
    stream_footer_adler32: ?u32 = null,
    stream_adler32: ?u32 = null,
    stream_adler32_matches: ?bool = null,
    member_deflate_bytes: ?usize = null,
    member_output_bytes: ?usize = null,
    member_footer_offset: ?usize = null,
    member_end_offset: ?usize = null,
    member_footer_crc32: ?u32 = null,
    member_crc32: ?u32 = null,
    member_crc32_matches: ?bool = null,
    member_footer_isize: ?u32 = null,
    member_isize: ?u32 = null,
    member_isize_matches: ?bool = null,
};

fn printRawHeaderInfo(stdout: *std.Io.Writer, compressed_len: usize, info: vort.RawDeflateHeaderInfo, output_format: HeaderInspectOutputFormat) !void {
    if (output_format == .json) return printRawHeaderJson(stdout, compressed_len, info);

    try stdout.print(
        "raw_header compressed_bytes={d} final={} block_type={s} data_bit_offset={d} data_byte_offset={d} header_bits_consumed={d} header_bytes_consumed={d} stored_len=",
        .{
            compressed_len,
            info.final,
            @tagName(info.block_type),
            info.data_bit_offset,
            info.data_byte_offset,
            info.header_bits_consumed,
            info.header_bytes_consumed,
        },
    );
    try printOptionalJson(u16, stdout, info.stored_len);
    try stdout.print(" stored_nlen=", .{});
    try printOptionalJson(u16, stdout, info.stored_nlen);
    try stdout.print(" stored_payload_offset=", .{});
    try printOptionalJson(usize, stdout, info.stored_payload_offset);
    try stdout.print(" dynamic_hlit=", .{});
    try printOptionalJson(u16, stdout, info.dynamic_hlit);
    try stdout.print(" dynamic_hdist=", .{});
    try printOptionalJson(u16, stdout, info.dynamic_hdist);
    try stdout.print(" dynamic_hclen=", .{});
    try printOptionalJson(u8, stdout, info.dynamic_hclen);
    try stdout.print(" dynamic_code_length_count=", .{});
    try printOptionalJson(u8, stdout, info.dynamic_code_length_count);
    try stdout.print(" dynamic_code_length_lengths=", .{});
    try printCodeLengthArray(stdout, &info.dynamic_code_length_lengths);
    try stdout.print(" dynamic_code_length_repeat_prev=", .{});
    try printOptionalJson(u16, stdout, info.dynamic_code_length_repeat_prev);
    try stdout.print(" dynamic_code_length_repeat_zero_short=", .{});
    try printOptionalJson(u16, stdout, info.dynamic_code_length_repeat_zero_short);
    try stdout.print(" dynamic_code_length_repeat_zero_long=", .{});
    try printOptionalJson(u16, stdout, info.dynamic_code_length_repeat_zero_long);
    try stdout.print(" dynamic_literal_nonzero=", .{});
    try printOptionalJson(u16, stdout, info.dynamic_literal_nonzero);
    try stdout.print(" dynamic_literal_zero=", .{});
    try printOptionalJson(u16, stdout, info.dynamic_literal_zero);
    try stdout.print(" dynamic_literal_max_bits=", .{});
    try printOptionalJson(u8, stdout, info.dynamic_literal_max_bits);
    try stdout.print(" dynamic_literal_length_histogram=", .{});
    try printU16Array16(stdout, &info.dynamic_literal_length_histogram);
    try stdout.print(" dynamic_distance_nonzero=", .{});
    try printOptionalJson(u16, stdout, info.dynamic_distance_nonzero);
    try stdout.print(" dynamic_distance_zero=", .{});
    try printOptionalJson(u16, stdout, info.dynamic_distance_zero);
    try stdout.print(" dynamic_distance_max_bits=", .{});
    try printOptionalJson(u8, stdout, info.dynamic_distance_max_bits);
    try stdout.print(" dynamic_distance_length_histogram=", .{});
    try printU16Array16(stdout, &info.dynamic_distance_length_histogram);
    try stdout.print(" dynamic_has_eob=", .{});
    try printOptionalBoolJson(stdout, info.dynamic_has_eob);
    try stdout.print(" dynamic_lengths_bit_offset=", .{});
    try printOptionalJson(usize, stdout, info.dynamic_lengths_bit_offset);
    try stdout.print(" dynamic_lengths_byte_offset=", .{});
    try printOptionalJson(usize, stdout, info.dynamic_lengths_byte_offset);
    try stdout.print("\n", .{});
}

fn printZlibHeaderInfo(stdout: *std.Io.Writer, compressed_len: usize, info: vort.ZlibHeaderInfo, output_format: HeaderInspectOutputFormat) !void {
    if (output_format == .json) return printZlibHeaderJson(stdout, compressed_len, info);

    try stdout.print(
        "zlib_header compressed_bytes={d} data_offset={d} cmf=0x{x:0>2} flg=0x{x:0>2} method={d} window_bits={d} window_size={d} fcheck={d} fdict={} flevel={d} dictid=",
        .{
            compressed_len,
            info.data_offset,
            info.cmf,
            info.flg,
            info.compression_method,
            info.window_bits,
            info.window_size,
            info.fcheck,
            info.uses_dictionary,
            info.flevel,
        },
    );
    if (info.dictionary_id) |dictid| {
        try stdout.print("{d}\n", .{dictid});
    } else {
        try stdout.print("null\n", .{});
    }
}

fn printGzipHeaderInfo(stdout: *std.Io.Writer, compressed_len: usize, info: vort.GzipHeaderInfo, output_format: HeaderInspectOutputFormat) !void {
    if (output_format == .json) return printGzipHeaderJson(stdout, compressed_len, info);

    try stdout.print(
        "gzip_header compressed_bytes={d} data_offset={d} flags=0x{x:0>2} text={} mtime={d} xfl={d} os={d} extra_present={} extra_len={d} extra_hex=",
        .{
            compressed_len,
            info.data_offset,
            info.flags,
            info.text,
            info.mtime,
            info.xfl,
            info.os,
            info.extra != null,
            if (info.extra) |extra| extra.len else 0,
        },
    );
    if (info.extra) |extra| {
        try printHexInline(stdout, extra);
    } else {
        try stdout.print("null", .{});
    }
    try stdout.print(" filename=", .{});
    try printOptionalJsonBytes(stdout, info.filename);
    try stdout.print(" comment=", .{});
    try printOptionalJsonBytes(stdout, info.comment);
    if (info.header_crc) |crc| {
        try stdout.print(" header_crc={d}\n", .{crc});
    } else {
        try stdout.print(" header_crc=null\n", .{});
    }
}

fn printRawHeaderJson(stdout: *std.Io.Writer, compressed_len: usize, info: vort.RawDeflateHeaderInfo) !void {
    try printRawHeaderJsonObject(stdout, compressed_len, info);
    try stdout.print("\n", .{});
}

fn printRawHeaderJsonObject(stdout: *std.Io.Writer, compressed_len: usize, info: vort.RawDeflateHeaderInfo) !void {
    try stdout.print(
        "{{\"schema\":\"vort.raw_deflate_header_info\",\"schema_version\":1,\"compressed_bytes\":{d},\"final\":{},\"block_type\":\"{s}\",\"data_bit_offset\":{d},\"data_byte_offset\":{d},\"header_bits_consumed\":{d},\"header_bytes_consumed\":{d},\"stored_len\":",
        .{
            compressed_len,
            info.final,
            @tagName(info.block_type),
            info.data_bit_offset,
            info.data_byte_offset,
            info.header_bits_consumed,
            info.header_bytes_consumed,
        },
    );
    try printOptionalJson(u16, stdout, info.stored_len);
    try stdout.print(",\"stored_nlen\":", .{});
    try printOptionalJson(u16, stdout, info.stored_nlen);
    try stdout.print(",\"stored_payload_offset\":", .{});
    try printOptionalJson(usize, stdout, info.stored_payload_offset);
    try stdout.print(",\"dynamic_hlit\":", .{});
    try printOptionalJson(u16, stdout, info.dynamic_hlit);
    try stdout.print(",\"dynamic_hdist\":", .{});
    try printOptionalJson(u16, stdout, info.dynamic_hdist);
    try stdout.print(",\"dynamic_hclen\":", .{});
    try printOptionalJson(u8, stdout, info.dynamic_hclen);
    try stdout.print(",\"dynamic_code_length_count\":", .{});
    try printOptionalJson(u8, stdout, info.dynamic_code_length_count);
    try stdout.print(",\"dynamic_code_length_lengths\":", .{});
    try printCodeLengthArray(stdout, &info.dynamic_code_length_lengths);
    try stdout.print(",\"dynamic_code_length_repeat_prev\":", .{});
    try printOptionalJson(u16, stdout, info.dynamic_code_length_repeat_prev);
    try stdout.print(",\"dynamic_code_length_repeat_zero_short\":", .{});
    try printOptionalJson(u16, stdout, info.dynamic_code_length_repeat_zero_short);
    try stdout.print(",\"dynamic_code_length_repeat_zero_long\":", .{});
    try printOptionalJson(u16, stdout, info.dynamic_code_length_repeat_zero_long);
    try stdout.print(",\"dynamic_literal_nonzero\":", .{});
    try printOptionalJson(u16, stdout, info.dynamic_literal_nonzero);
    try stdout.print(",\"dynamic_literal_zero\":", .{});
    try printOptionalJson(u16, stdout, info.dynamic_literal_zero);
    try stdout.print(",\"dynamic_literal_max_bits\":", .{});
    try printOptionalJson(u8, stdout, info.dynamic_literal_max_bits);
    try stdout.print(",\"dynamic_literal_length_histogram\":", .{});
    try printU16Array16(stdout, &info.dynamic_literal_length_histogram);
    try stdout.print(",\"dynamic_distance_nonzero\":", .{});
    try printOptionalJson(u16, stdout, info.dynamic_distance_nonzero);
    try stdout.print(",\"dynamic_distance_zero\":", .{});
    try printOptionalJson(u16, stdout, info.dynamic_distance_zero);
    try stdout.print(",\"dynamic_distance_max_bits\":", .{});
    try printOptionalJson(u8, stdout, info.dynamic_distance_max_bits);
    try stdout.print(",\"dynamic_distance_length_histogram\":", .{});
    try printU16Array16(stdout, &info.dynamic_distance_length_histogram);
    try stdout.print(",\"dynamic_has_eob\":", .{});
    try printOptionalBoolJson(stdout, info.dynamic_has_eob);
    try stdout.print(",\"dynamic_lengths_bit_offset\":", .{});
    try printOptionalJson(usize, stdout, info.dynamic_lengths_bit_offset);
    try stdout.print(",\"dynamic_lengths_byte_offset\":", .{});
    try printOptionalJson(usize, stdout, info.dynamic_lengths_byte_offset);
    try stdout.print("}}", .{});
}

fn inspectZlibStreamForWrappedJson(allocator: std.mem.Allocator, compressed: []const u8) !?vort.ZlibStreamInfo {
    return vort.inspectZlibStreamAlloc(allocator, compressed) catch |err| switch (err) {
        // The header-level command has no dictionary argument. Preserve useful
        // raw-header inspection for FDICT streams while leaving checksum and
        // exact-length diagnostics null when the preset dictionary is required.
        error.NeedDictionary => null,
        else => return err,
    };
}

fn zlibWrappedDeflateContext(wrapper_bytes: usize, deflate_offset: usize, stream: ?vort.ZlibStreamInfo) WrappedDeflateContext {
    var context = WrappedDeflateContext{
        .wrapper = "zlib",
        .wrapper_bytes = wrapper_bytes,
        .member_offset = 0,
        .deflate_offset = deflate_offset,
        .member_index = 0,
    };
    if (stream) |info| {
        context.exact_deflate_bytes = info.deflate_bytes;
        context.stream_deflate_bytes = info.deflate_bytes;
        context.stream_output_bytes = info.output_bytes;
        context.stream_footer_offset = info.footer_offset;
        context.stream_end_offset = info.end_offset;
        context.stream_footer_adler32 = info.footer_adler32;
        context.stream_adler32 = info.adler32;
        context.stream_adler32_matches = info.adler32_matches;
    }
    return context;
}

fn gzipWrappedDeflateContext(wrapper_bytes: usize, member: vort.GzipMemberInfo) WrappedDeflateContext {
    return .{
        .wrapper = "gzip",
        .wrapper_bytes = wrapper_bytes,
        .member_offset = member.member_offset,
        .deflate_offset = member.deflate_offset,
        .member_index = member.member_index,
        .exact_deflate_bytes = member.deflate_bytes,
        .member_deflate_bytes = member.deflate_bytes,
        .member_output_bytes = member.output_bytes,
        .member_footer_offset = member.footer_offset,
        .member_end_offset = member.end_offset,
        .member_footer_crc32 = member.footer_crc32,
        .member_crc32 = member.crc32,
        .member_crc32_matches = member.crc32_matches,
        .member_footer_isize = member.footer_isize,
        .member_isize = member.isize,
        .member_isize_matches = member.isize_matches,
    };
}

fn printWrappedDeflateHeaderJson(stdout: *std.Io.Writer, context: WrappedDeflateContext, info: vort.RawDeflateHeaderInfo) !void {
    const scope = if (std.mem.eql(u8, context.wrapper, "gzip")) "gzip_member" else "zlib_stream";
    try stdout.print(
        "{{\"schema\":\"vort.wrapped_deflate_header_info\",\"schema_version\":1,\"wrapper\":\"{s}\",\"scope\":\"{s}\",\"member_index\":{d},\"member_offset\":{d},\"wrapper_bytes\":{d},\"deflate_offset\":{d},\"deflate_bytes\":{d},\"deflate_span_kind\":\"header_tail\",\"exact_deflate_bytes\":",
        .{
            context.wrapper,
            scope,
            context.member_index,
            context.member_offset,
            context.wrapper_bytes,
            context.deflate_offset,
            context.wrapper_bytes - context.deflate_offset,
        },
    );
    try printOptionalJson(usize, stdout, context.exact_deflate_bytes);
    try stdout.print(",\"stream_deflate_bytes\":", .{});
    try printOptionalJson(usize, stdout, context.stream_deflate_bytes);
    try stdout.print(",\"stream_output_bytes\":", .{});
    try printOptionalJson(usize, stdout, context.stream_output_bytes);
    try stdout.print(",\"stream_footer_offset\":", .{});
    try printOptionalJson(usize, stdout, context.stream_footer_offset);
    try stdout.print(",\"stream_end_offset\":", .{});
    try printOptionalJson(usize, stdout, context.stream_end_offset);
    try stdout.print(",\"stream_footer_adler32\":", .{});
    try printOptionalJson(u32, stdout, context.stream_footer_adler32);
    try stdout.print(",\"stream_adler32\":", .{});
    try printOptionalJson(u32, stdout, context.stream_adler32);
    try stdout.print(",\"stream_adler32_matches\":", .{});
    try printOptionalBoolJson(stdout, context.stream_adler32_matches);
    try stdout.print(",\"member_deflate_bytes\":", .{});
    try printOptionalJson(usize, stdout, context.member_deflate_bytes);
    try stdout.print(",\"member_output_bytes\":", .{});
    try printOptionalJson(usize, stdout, context.member_output_bytes);
    try stdout.print(",\"member_footer_offset\":", .{});
    try printOptionalJson(usize, stdout, context.member_footer_offset);
    try stdout.print(",\"member_end_offset\":", .{});
    try printOptionalJson(usize, stdout, context.member_end_offset);
    try stdout.print(",\"member_footer_crc32\":", .{});
    try printOptionalJson(u32, stdout, context.member_footer_crc32);
    try stdout.print(",\"member_crc32\":", .{});
    try printOptionalJson(u32, stdout, context.member_crc32);
    try stdout.print(",\"member_crc32_matches\":", .{});
    try printOptionalBoolJson(stdout, context.member_crc32_matches);
    try stdout.print(",\"member_footer_isize\":", .{});
    try printOptionalJson(u32, stdout, context.member_footer_isize);
    try stdout.print(",\"member_isize\":", .{});
    try printOptionalJson(u32, stdout, context.member_isize);
    try stdout.print(",\"member_isize_matches\":", .{});
    try printOptionalBoolJson(stdout, context.member_isize_matches);
    try stdout.print(",\"raw_header\":", .{});
    try printRawHeaderJsonObject(stdout, context.wrapper_bytes - context.deflate_offset, info);
    try stdout.print("}}\n", .{});
}

fn printCodeLengthArray(stdout: *std.Io.Writer, lengths: *const [19]u4) !void {
    try stdout.print("[", .{});
    for (lengths, 0..) |length, i| {
        if (i != 0) try stdout.print(",", .{});
        try stdout.print("{d}", .{length});
    }
    try stdout.print("]", .{});
}

fn printU16Array16(stdout: *std.Io.Writer, values: *const [16]u16) !void {
    try stdout.print("[", .{});
    for (values, 0..) |value, i| {
        if (i != 0) try stdout.print(",", .{});
        try stdout.print("{d}", .{value});
    }
    try stdout.print("]", .{});
}

fn printZlibHeaderJson(stdout: *std.Io.Writer, compressed_len: usize, info: vort.ZlibHeaderInfo) !void {
    try stdout.print(
        "{{\"schema\":\"vort.zlib_header_info\",\"schema_version\":1,\"compressed_bytes\":{d},\"data_offset\":{d},\"cmf\":{d},\"flg\":{d},\"compression_method\":{d},\"window_bits\":{d},\"window_size\":{d},\"fcheck\":{d},\"uses_dictionary\":{},\"flevel\":{d},\"dictionary_id\":",
        .{
            compressed_len,
            info.data_offset,
            info.cmf,
            info.flg,
            info.compression_method,
            info.window_bits,
            info.window_size,
            info.fcheck,
            info.uses_dictionary,
            info.flevel,
        },
    );
    try printOptionalJson(u32, stdout, info.dictionary_id);
    try stdout.print("}}\n", .{});
}

fn printGzipHeaderJson(stdout: *std.Io.Writer, compressed_len: usize, info: vort.GzipHeaderInfo) !void {
    try stdout.print(
        "{{\"schema\":\"vort.gzip_header_info\",\"schema_version\":1,\"compressed_bytes\":{d},\"data_offset\":{d},\"flags\":{d},\"text\":{},\"mtime\":{d},\"xfl\":{d},\"os\":{d},\"extra_present\":{},\"extra_len\":{d},\"extra_hex\":",
        .{
            compressed_len,
            info.data_offset,
            info.flags,
            info.text,
            info.mtime,
            info.xfl,
            info.os,
            info.extra != null,
            if (info.extra) |extra| extra.len else 0,
        },
    );
    if (info.extra) |extra| {
        try stdout.print("\"", .{});
        try printHexInline(stdout, extra);
        try stdout.print("\"", .{});
    } else {
        try stdout.print("null", .{});
    }
    try stdout.print(",\"filename\":", .{});
    try printOptionalJsonBytes(stdout, info.filename);
    try stdout.print(",\"comment\":", .{});
    try printOptionalJsonBytes(stdout, info.comment);
    try stdout.print(",\"header_crc\":", .{});
    try printOptionalJson(u16, stdout, info.header_crc);
    try stdout.print("}}\n", .{});
}

fn printOptionalJsonBytes(stdout: *std.Io.Writer, maybe_bytes: ?[]const u8) !void {
    if (maybe_bytes) |bytes| {
        try printJsonBytes(stdout, bytes);
    } else {
        try stdout.print("null", .{});
    }
}

fn printJsonBytes(stdout: *std.Io.Writer, bytes: []const u8) !void {
    try stdout.print("\"", .{});
    for (bytes) |byte| {
        switch (byte) {
            '"' => try stdout.print("\\\"", .{}),
            '\\' => try stdout.print("\\\\", .{}),
            '\n' => try stdout.print("\\n", .{}),
            '\r' => try stdout.print("\\r", .{}),
            '\t' => try stdout.print("\\t", .{}),
            else => {
                if (byte >= 0x20 and byte <= 0x7e) {
                    try stdout.print("{c}", .{byte});
                } else {
                    try stdout.print("\\u00{x:0>2}", .{byte});
                }
            },
        }
    }
    try stdout.print("\"", .{});
}

fn printValidationFailure(stdout: *std.Io.Writer, label: []const u8, report: vort.ValidationReport) !void {
    try stdout.print("{s}_validation_ok=false mode={s} stage={s} error={s}", .{
        label,
        @tagName(report.mode),
        @tagName(report.stage),
        report.error_name,
    });
    if (report.recoverability_hint != .none) try stdout.print(" hint={s}", .{@tagName(report.recoverability_hint)});
    if (report.frame_index) |value| try stdout.print(" frame_index={d}", .{value});
    if (report.frame_offset) |value| try stdout.print(" frame_offset={d}", .{value});
    if (report.uncompressed_offset) |value| try stdout.print(" uncompressed_offset={d}", .{value});
    if (report.frame_flags) |value| try stdout.print(" frame_flags={d}", .{value});
    if (report.frame_mode.len != 0) try stdout.print(" frame_mode={s}", .{report.frame_mode});
    try stdout.print("\n", .{});
}

fn printValidationJson(stdout: *std.Io.Writer, label: []const u8, report: vort.ValidationReport, stream_len: usize, sidecar_len: ?usize) !void {
    try stdout.print("{{\"schema\":\"vort.validation_report\",\"schema_version\":1,\"target\":\"{s}\",\"ok\":{},\"mode\":\"{s}\",\"stage\":\"{s}\",\"error\":", .{
        label,
        report.ok,
        @tagName(report.mode),
        @tagName(report.stage),
    });
    try std.json.Stringify.value(report.error_name, .{}, stdout);
    try stdout.print(",\"recoverability_hint\":\"{s}\",\"frame_index\":", .{@tagName(report.recoverability_hint)});
    try printOptionalJson(usize, stdout, report.frame_index);
    try stdout.print(",\"frame_offset\":", .{});
    try printOptionalJson(usize, stdout, report.frame_offset);
    try stdout.print(",\"uncompressed_offset\":", .{});
    try printOptionalJson(u64, stdout, report.uncompressed_offset);
    try stdout.print(",\"frame_flags\":", .{});
    try printOptionalJson(u8, stdout, report.frame_flags);
    try stdout.print(",\"frame_mode\":", .{});
    try std.json.Stringify.value(report.frame_mode, .{}, stdout);
    try stdout.print(",\"frame_count\":{d},\"total_uncompressed\":{d},\"combined_checksum\":", .{ report.frame_count, report.total_uncompressed });
    try printOptionalJson(u32, stdout, report.combined_checksum);
    try stdout.print(",\"stream_bytes\":{d},\"sidecar_bytes\":", .{stream_len});
    try printOptionalJson(usize, stdout, sidecar_len);
    try stdout.print("}}\n", .{});
}

fn printOptionalJson(comptime T: type, stdout: *std.Io.Writer, value: ?T) !void {
    if (value) |payload| {
        try stdout.print("{d}", .{payload});
    } else {
        try stdout.print("null", .{});
    }
}

fn printOptionalBoolJson(stdout: *std.Io.Writer, value: ?bool) !void {
    if (value) |payload| {
        try stdout.print("{}", .{payload});
    } else {
        try stdout.print("null", .{});
    }
}

fn parseParserMode(text: ?[]const u8) vort.ParserMode {
    return parseCompressionOptions(text).parser;
}

fn makeDemoLdmPrefix() [33_000]u8 {
    var out: [33_000]u8 = undefined;
    var x: u32 = 0x1234_5678;
    for (&out) |*byte| {
        x = x *% 1664525 +% 1013904223;
        byte.* = @truncate(x >> 24);
    }
    return out;
}

fn parseBlockLen(text: ?[]const u8, default: usize) !usize {
    const value = text orelse return default;
    const parsed = try std.fmt.parseInt(usize, value, 10);
    if (parsed == 0) return error.InvalidBlockPlan;
    return parsed;
}

fn parseSeekabilityTier(text: ?[]const u8) !vort.SeekabilityTier {
    const value = text orelse return error.MissingCorpusPath;
    if (std.mem.eql(u8, value, "seek-fast") or std.mem.eql(u8, value, "seek_fast")) return .seek_fast;
    if (std.mem.eql(u8, value, "balanced")) return .balanced;
    if (std.mem.eql(u8, value, "ratio")) return .ratio;
    return error.InvalidSeekabilityTier;
}

fn parseIterations(text: ?[]const u8, default: usize) !usize {
    const value = text orelse return default;
    const parsed = try std.fmt.parseInt(usize, value, 10);
    if (parsed == 0) return error.InvalidBlockPlan;
    return parsed;
}

fn parseOptionalLimit(text: ?[]const u8) !?usize {
    const value = text orelse return null;
    return try std.fmt.parseInt(usize, value, 10);
}

fn parseOptionalMemberIndex(text: ?[]const u8) !usize {
    const value = text orelse return 0;
    return try std.fmt.parseInt(usize, value, 10);
}

fn parseSidecarValidationMode(text: ?[]const u8) !vort.SidecarValidationMode {
    const value = text orelse return .full;
    if (std.mem.eql(u8, value, "metadata") or std.mem.eql(u8, value, "fast")) return .metadata;
    if (std.mem.eql(u8, value, "full")) return .full;
    return error.InvalidSidecarValidationMode;
}

const ValidationOutputFormat = enum { text, json };

fn parseValidationOutputFormat(text: ?[]const u8) !ValidationOutputFormat {
    const value = text orelse return .text;
    if (std.mem.eql(u8, value, "text")) return .text;
    if (std.mem.eql(u8, value, "json")) return .json;
    return error.InvalidSidecarValidationMode;
}

fn parseHeaderInspectOutputFormat(text: ?[]const u8) !HeaderInspectOutputFormat {
    const value = text orelse return .text;
    if (std.mem.eql(u8, value, "text")) return .text;
    if (std.mem.eql(u8, value, "json")) return .json;
    return error.InvalidSidecarValidationMode;
}

fn parseCompressionOptions(text: ?[]const u8) vort.CompressionOptions {
    const value = text orelse return vort.optionsForCompressionLevel(.default);
    if (std.mem.eql(u8, value, "fastest")) return vort.optionsForCompressionLevel(.fastest);
    if (std.mem.eql(u8, value, "fast")) return vort.optionsForCompressionLevel(.fast);
    if (std.mem.eql(u8, value, "hash")) return .{ .parser = .hash };
    if (std.mem.eql(u8, value, "default")) return vort.optionsForCompressionLevel(.default);
    if (std.mem.eql(u8, value, "best")) return vort.optionsForCompressionLevel(.best);
    if (std.mem.eql(u8, value, "filtered")) return .{ .strategy = .filtered };
    if (std.mem.eql(u8, value, "huffman") or std.mem.eql(u8, value, "huffman-only")) return .{ .strategy = .huffman_only };
    if (std.mem.eql(u8, value, "rle")) return .{ .strategy = .rle };
    if (std.mem.eql(u8, value, "greedy")) return .{ .parser = .greedy };
    if (std.mem.eql(u8, value, "lazy")) return .{ .parser = .lazy };
    if (std.mem.eql(u8, value, "optimal")) return .{ .parser = .optimal };
    return vort.optionsForCompressionLevel(.default);
}

fn parseZstdNativeSelection(text: ?[]const u8) !vort.ZstdNativeFrameSelection {
    const value = text orelse return .auto;
    if (std.mem.eql(u8, value, "auto")) return .auto;
    if (std.mem.eql(u8, value, "raw_or_rle") or std.mem.eql(u8, value, "raw-rle")) return .raw_or_rle;
    if (std.mem.eql(u8, value, "literal_only") or std.mem.eql(u8, value, "literal-only")) return .literal_only;
    return error.InvalidZstdNativeSelection;
}

fn parseOptionalBool(text: ?[]const u8, default: bool) !bool {
    const value = text orelse return default;
    if (std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "1") or std.mem.eql(u8, value, "yes")) return true;
    if (std.mem.eql(u8, value, "false") or std.mem.eql(u8, value, "0") or std.mem.eql(u8, value, "no")) return false;
    return error.InvalidBoolean;
}
