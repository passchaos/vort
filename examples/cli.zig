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
    } else if (std.mem.eql(u8, command, "encode-zlib-fixed-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibFixedWithOptionsAlloc(init.gpa, payload, options);
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
    } else if (std.mem.eql(u8, command, "encode-zlib-dynamic-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibDynamicWithOptionsAlloc(init.gpa, payload, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-gzip-dynamic-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeGzipDynamicWithOptionsAlloc(init.gpa, payload, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-zlib-best-file-hex")) {
        const path = args.next() orelse return error.MissingCorpusPath;
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibBestAlloc(init.gpa, data, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
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
        const stream = try std.Io.Dir.cwd().readFileAlloc(init.io, stream_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(stream);
        const sidecar = try std.Io.Dir.cwd().readFileAlloc(init.io, sidecar_path, init.gpa, .limited(16 * 1024 * 1024));
        defer init.gpa.free(sidecar);
        const report = vort.storeValidateSidecarIndexReportAlloc(init.gpa, stream, sidecar, .{ .mode = validation_mode });
        if (!report.ok) {
            try printValidationFailure(stdout, "sidecar", report);
            try stdout.flush();
            return error.CorruptFrame;
        }
        try stdout.print("sidecar_ok=true mode={s} stream_bytes={d} sidecar_bytes={d}\n", .{ @tagName(validation_mode), stream.len, sidecar.len });
    } else if (std.mem.eql(u8, command, "verify-vort-embedded-index-file")) {
        const stream_path = args.next() orelse return error.MissingCorpusPath;
        const validation_mode = try parseSidecarValidationMode(args.next());
        const stream = try std.Io.Dir.cwd().readFileAlloc(init.io, stream_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(stream);
        const report = vort.storeValidateEmbeddedIndexReportAlloc(init.gpa, stream, .{ .mode = validation_mode });
        if (!report.ok) {
            try printValidationFailure(stdout, "embedded", report);
            try stdout.flush();
            return error.CorruptFrame;
        }
        try stdout.print("embedded_index_ok=true mode={s} stream_bytes={d}\n", .{ @tagName(validation_mode), stream.len });
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
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const decoded = try vort.decodeRawDeflateAlloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try printDecoded(stdout, "raw", compressed.len, decoded);
    } else if (std.mem.eql(u8, command, "decode-zlib-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(compressed);
        const decoded = try vort.decodeZlibAlloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
        try stdout.print("compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ compressed.len, decoded.len, output_path });
    } else if (std.mem.eql(u8, command, "decode-zlib-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const decoded = try vort.decodeZlibAlloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try printDecoded(stdout, "zlib", compressed.len, decoded);
    } else if (std.mem.eql(u8, command, "decode-gzip-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const decoded = try vort.decodeGzipConcatenatedAlloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try printDecoded(stdout, "gzip", compressed.len, decoded);
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
        \\  decode-raw-hex [hex]      Decode raw deflate hex to text
        \\  decode-zlib-hex [hex]     Decode zlib-wrapped deflate hex to text
        \\  decode-gzip-hex [hex]     Decode gzip-wrapped deflate hex to text
        \\  encode-zlib-best-file <in> <out> [level]
        \\                              Encode a zlib-compatible file with best-block selection
        \\
        \\native indexed file workflows:
        \\  encode-vort-sidecar-best-file <in> <stream> <sidecar> [block_len]
        \\                              Encode native Vort stream plus external sidecar index
        \\  verify-vort-sidecar-index-file <stream> <sidecar> [full|metadata]
        \\                              Validate an external sidecar index against a stream
        \\  decode-vort-sidecar-range-file <stream> <sidecar> <out> <offset> <len>
        \\                              Decode an indexed range through an external sidecar
        \\  encode-vort-embedded-best-file <in> <stream> [block_len]
        \\                              Encode native Vort stream with embedded index
        \\  verify-vort-embedded-index-file <stream> [full|metadata]
        \\                              Validate an embedded-index stream
        \\  decode-vort-embedded-range-file <stream> <out> <offset> <len>
        \\                              Decode an indexed range from an embedded-index stream
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
    for (bytes) |byte| try stdout.print("{x:0>2}", .{byte});
    try stdout.print("\n", .{});
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

fn parseSidecarValidationMode(text: ?[]const u8) !vort.SidecarValidationMode {
    const value = text orelse return .full;
    if (std.mem.eql(u8, value, "metadata") or std.mem.eql(u8, value, "fast")) return .metadata;
    if (std.mem.eql(u8, value, "full")) return .full;
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
