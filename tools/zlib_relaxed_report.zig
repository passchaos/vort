const std = @import("std");
const vort = @import("vort");

const Payload = "payload";

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    var json_path: ?[]const u8 = null;
    var markdown_path: ?[]const u8 = null;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--json")) {
            json_path = args.next() orelse return error.MissingJsonPath;
            continue;
        }
        if (std.mem.eql(u8, arg, "--markdown")) {
            markdown_path = args.next() orelse return error.MissingMarkdownPath;
            continue;
        }
        return error.UnknownArgument;
    }

    var strict_rejections: usize = 0;
    var relaxed_successes: usize = 0;
    var dictionary_successes: usize = 0;
    var zlib_concatenated_successes: usize = 0;
    var zlib_decoder_successes: usize = 0;
    var limited_rejections: usize = 0;
    var gzip_strict_rejections: usize = 0;
    var gzip_relaxed_successes: usize = 0;
    var gzip_concatenated_successes: usize = 0;
    var gzip_decoder_successes: usize = 0;
    var gzip_limited_rejections: usize = 0;

    const frame = try vort.encodeZlibLevelAlloc(init.gpa, Payload, 6);
    defer init.gpa.free(frame);

    var bad_adler = try init.gpa.dupe(u8, frame);
    defer init.gpa.free(bad_adler);
    bad_adler[bad_adler.len - 1] ^= 1;
    try expectZlibError(error.ChecksumMismatch, bad_adler, .{});
    strict_rejections += 1;
    try expectZlibPayload(init.gpa, bad_adler, .{ .ignore_adler = true });
    relaxed_successes += 1;

    var trailing = try init.gpa.alloc(u8, frame.len + 1);
    defer init.gpa.free(trailing);
    @memcpy(trailing[0..frame.len], frame);
    trailing[frame.len] = 0xaa;
    try expectZlibError(error.TrailingData, trailing, .{});
    strict_rejections += 1;
    try expectZlibPayload(init.gpa, trailing, .{ .allow_trailing_data = true });
    relaxed_successes += 1;

    var combined = try init.gpa.alloc(u8, frame.len + 1);
    defer init.gpa.free(combined);
    @memcpy(combined[0..frame.len], frame);
    combined[combined.len - 2] ^= 1;
    combined[combined.len - 1] = 0xbb;
    try expectZlibPayload(init.gpa, combined, .{ .ignore_adler = true, .allow_trailing_data = true });
    relaxed_successes += 1;

    try expectAllocExact(init.gpa, combined, .{ .ignore_adler = true, .allow_trailing_data = true });
    relaxed_successes += 1;
    try expectAllocLimited(init.gpa, combined, .{ .ignore_adler = true, .allow_trailing_data = true });
    relaxed_successes += 1;
    try expectLimitExceeded(init.gpa, combined, .{ .ignore_adler = true, .allow_trailing_data = true });
    limited_rejections += 1;

    const dictionary = "pay";
    const dict_frame = try vort.encodeZlibLevelWithDictionaryAlloc(init.gpa, Payload, dictionary, 6);
    defer init.gpa.free(dict_frame);
    var dict_combined = try init.gpa.alloc(u8, dict_frame.len + 1);
    defer init.gpa.free(dict_combined);
    @memcpy(dict_combined[0..dict_frame.len], dict_frame);
    dict_combined[dict_frame.len - 1] ^= 1;
    dict_combined[dict_frame.len] = 0xcc;
    const relaxed = vort.ZlibDecodeOptions{ .ignore_adler = true, .allow_trailing_data = true };
    var dict_out: [Payload.len]u8 = undefined;
    const dict_written = try vort.decodeZlibWithDictionaryAndOptions(dict_combined, &dict_out, dictionary, relaxed);
    if (dict_written != Payload.len or !std.mem.eql(u8, Payload, &dict_out)) return error.PayloadMismatch;
    dictionary_successes += 1;
    const dict_alloc = try vort.decodeZlibAllocWithDictionaryAndOptionsLimited(init.gpa, dict_combined, dictionary, relaxed, Payload.len);
    defer init.gpa.free(dict_alloc);
    if (!std.mem.eql(u8, Payload, dict_alloc)) return error.PayloadMismatch;
    dictionary_successes += 1;

    var zlib_cat = try init.gpa.alloc(u8, bad_adler.len + frame.len + 1);
    defer init.gpa.free(zlib_cat);
    @memcpy(zlib_cat[0..bad_adler.len], bad_adler);
    @memcpy(zlib_cat[bad_adler.len..][0..frame.len], frame);
    zlib_cat[zlib_cat.len - 1] = 0xdd;
    const zlib_cat_relaxed = vort.ZlibDecodeOptions{ .ignore_adler = true, .allow_trailing_data = true };
    var zlib_cat_out: [Payload.len * 2]u8 = undefined;
    const zlib_cat_written = try vort.decodeZlibConcatenatedWithOptions(zlib_cat, &zlib_cat_out, zlib_cat_relaxed);
    if (zlib_cat_written != Payload.len * 2 or !std.mem.eql(u8, Payload ++ Payload, &zlib_cat_out)) return error.PayloadMismatch;
    zlib_concatenated_successes += 1;
    const zlib_cat_alloc = try vort.decodeZlibConcatenatedAllocWithOptionsExactSize(init.gpa, zlib_cat, zlib_cat_relaxed, Payload.len * 2);
    defer init.gpa.free(zlib_cat_alloc);
    if (!std.mem.eql(u8, Payload ++ Payload, zlib_cat_alloc)) return error.PayloadMismatch;
    zlib_concatenated_successes += 1;
    const zlib_cat_limited = try vort.decodeZlibConcatenatedAllocWithOptionsLimited(init.gpa, zlib_cat, zlib_cat_relaxed, Payload.len * 2);
    defer init.gpa.free(zlib_cat_limited);
    if (!std.mem.eql(u8, Payload ++ Payload, zlib_cat_limited)) return error.PayloadMismatch;
    zlib_concatenated_successes += 1;

    var zlib_scratch: [Payload.len]u8 = undefined;
    var zlib_decoder = try vort.ZlibDecoder.initWithOptionsExactSize(combined, &zlib_scratch, relaxed, Payload.len);
    try drainZlibDecoderPayload(&zlib_decoder, Payload);
    zlib_decoder_successes += 1;
    const zlib_chunks = [_][]const u8{ combined[0..3], combined[3 .. combined.len - 1], combined[combined.len - 1 ..] };
    var zlib_compressed_scratch: [128]u8 = undefined;
    var zlib_chunk_decoder = try vort.ZlibDecoder.initFromChunksWithOptionsExactSize(&zlib_chunks, &zlib_compressed_scratch, &zlib_scratch, relaxed, Payload.len);
    try drainZlibDecoderPayload(&zlib_chunk_decoder, Payload);
    zlib_decoder_successes += 1;
    var zlib_reused_decoder = vort.ZlibDecoder{};
    try zlib_reused_decoder.resetWithOptionsExactSize(combined, &zlib_scratch, relaxed, Payload.len);
    try drainZlibDecoderPayload(&zlib_reused_decoder, Payload);
    zlib_decoder_successes += 1;
    var zlib_dict_decoder = try vort.ZlibDecoder.initWithDictionaryAndOptionsExactSize(dict_combined, dictionary, &zlib_scratch, relaxed, Payload.len);
    try drainZlibDecoderPayload(&zlib_dict_decoder, Payload);
    zlib_decoder_successes += 1;
    const zlib_dict_chunks = [_][]const u8{ dict_combined[0..6], dict_combined[6 .. dict_combined.len - 1], dict_combined[dict_combined.len - 1 ..] };
    var zlib_dict_chunk_decoder = try vort.ZlibDecoder.initFromChunksWithDictionaryAndOptionsExactSize(&zlib_dict_chunks, dictionary, &zlib_compressed_scratch, &zlib_scratch, relaxed, Payload.len);
    try drainZlibDecoderPayload(&zlib_dict_chunk_decoder, Payload);
    zlib_decoder_successes += 1;
    var zlib_cat_decoder = try vort.ZlibDecoder.initConcatenatedWithOptionsExactSize(zlib_cat, &zlib_cat_out, zlib_cat_relaxed, Payload.len * 2);
    try drainZlibDecoderPayload(&zlib_cat_decoder, Payload ++ Payload);
    zlib_decoder_successes += 1;
    var zlib_cat_reused_decoder = vort.ZlibDecoder{};
    try zlib_cat_reused_decoder.resetConcatenatedWithOptionsExactSize(zlib_cat, &zlib_cat_out, zlib_cat_relaxed, Payload.len * 2);
    try drainZlibDecoderPayload(&zlib_cat_reused_decoder, Payload ++ Payload);
    zlib_decoder_successes += 1;
    const zlib_cat_chunks = [_][]const u8{ zlib_cat[0..5], zlib_cat[5 .. zlib_cat.len - 4], zlib_cat[zlib_cat.len - 4 ..] };
    var zlib_cat_compressed_scratch: [128]u8 = undefined;
    var zlib_cat_chunk_decoder = try vort.ZlibDecoder.initConcatenatedFromChunksWithOptionsExactSize(&zlib_cat_chunks, &zlib_cat_compressed_scratch, &zlib_cat_out, zlib_cat_relaxed, Payload.len * 2);
    try drainZlibDecoderPayload(&zlib_cat_chunk_decoder, Payload ++ Payload);
    zlib_decoder_successes += 1;

    const gzip_frame = try vort.encodeGzipFixedAlloc(init.gpa, Payload);
    defer init.gpa.free(gzip_frame);

    var bad_crc = try init.gpa.dupe(u8, gzip_frame);
    defer init.gpa.free(bad_crc);
    bad_crc[bad_crc.len - 8] ^= 1;
    try expectGzipError(error.ChecksumMismatch, bad_crc, .{});
    gzip_strict_rejections += 1;
    try expectGzipPayload(init.gpa, bad_crc, .{ .ignore_crc32 = true });
    gzip_relaxed_successes += 1;

    var bad_isize = try init.gpa.dupe(u8, gzip_frame);
    defer init.gpa.free(bad_isize);
    bad_isize[bad_isize.len - 4] ^= 1;
    try expectGzipError(error.SizeMismatch, bad_isize, .{});
    gzip_strict_rejections += 1;
    try expectGzipPayload(init.gpa, bad_isize, .{ .ignore_isize = true });
    gzip_relaxed_successes += 1;

    var gzip_trailing = try init.gpa.alloc(u8, gzip_frame.len + 1);
    defer init.gpa.free(gzip_trailing);
    @memcpy(gzip_trailing[0..gzip_frame.len], gzip_frame);
    gzip_trailing[gzip_frame.len] = 0xdd;
    try expectGzipError(error.TrailingData, gzip_trailing, .{});
    gzip_strict_rejections += 1;
    try expectGzipPayload(init.gpa, gzip_trailing, .{ .allow_trailing_data = true });
    gzip_relaxed_successes += 1;

    var gzip_combined = try init.gpa.alloc(u8, gzip_frame.len + 1);
    defer init.gpa.free(gzip_combined);
    @memcpy(gzip_combined[0..gzip_frame.len], gzip_frame);
    gzip_combined[gzip_frame.len - 8] ^= 1;
    gzip_combined[gzip_frame.len - 4] ^= 1;
    gzip_combined[gzip_frame.len] = 0xee;
    const gzip_relaxed = vort.GzipDecodeOptions{ .ignore_crc32 = true, .ignore_isize = true, .allow_trailing_data = true };
    try expectGzipPayload(init.gpa, gzip_combined, gzip_relaxed);
    gzip_relaxed_successes += 1;
    const gzip_combined_chunks = [_][]const u8{
        gzip_combined[0..4],
        gzip_combined[4 .. gzip_combined.len - 9],
        gzip_combined[gzip_combined.len - 9 ..],
    };
    var gzip_chunk_join_scratch: [128]u8 = undefined;
    var gzip_chunk_out: [Payload.len]u8 = undefined;
    const gzip_chunk_written = try vort.decodeGzipChunksWithOptions(&gzip_combined_chunks, &gzip_chunk_join_scratch, &gzip_chunk_out, gzip_relaxed);
    if (gzip_chunk_written != Payload.len or !std.mem.eql(u8, Payload, &gzip_chunk_out)) return error.PayloadMismatch;
    gzip_relaxed_successes += 1;
    try expectGzipAllocExact(init.gpa, gzip_combined, gzip_relaxed);
    gzip_relaxed_successes += 1;
    try expectGzipAllocLimited(init.gpa, gzip_combined, gzip_relaxed);
    gzip_relaxed_successes += 1;
    try expectGzipLimitExceeded(init.gpa, gzip_combined, gzip_relaxed);
    gzip_limited_rejections += 1;

    var gzip_scratch: [Payload.len]u8 = undefined;
    var gzip_decoder = try vort.GzipDecoder.initWithOptionsExactSize(gzip_combined, &gzip_scratch, gzip_relaxed, Payload.len);
    try drainDecoderPayload(&gzip_decoder, Payload);
    gzip_decoder_successes += 1;

    var compressed_scratch: [128]u8 = undefined;
    var gzip_chunk_decoder = try vort.GzipDecoder.initFromChunksWithOptionsExactSize(&gzip_combined_chunks, &compressed_scratch, &gzip_scratch, gzip_relaxed, Payload.len);
    try drainDecoderPayload(&gzip_chunk_decoder, Payload);
    gzip_decoder_successes += 1;

    var cat = try init.gpa.alloc(u8, bad_crc.len + gzip_frame.len);
    defer init.gpa.free(cat);
    @memcpy(cat[0..bad_crc.len], bad_crc);
    @memcpy(cat[bad_crc.len..], gzip_frame);
    const gzip_concat_relaxed = vort.GzipDecodeOptions{ .ignore_crc32 = true };
    var cat_out: [Payload.len * 2]u8 = undefined;
    const cat_written = try vort.decodeGzipConcatenatedWithOptions(cat, &cat_out, gzip_concat_relaxed);
    if (cat_written != Payload.len * 2 or !std.mem.eql(u8, Payload ++ Payload, &cat_out)) return error.PayloadMismatch;
    gzip_concatenated_successes += 1;
    const cat_alloc = try vort.decodeGzipConcatenatedAllocWithOptionsExactSize(init.gpa, cat, gzip_concat_relaxed, Payload.len * 2);
    defer init.gpa.free(cat_alloc);
    if (!std.mem.eql(u8, Payload ++ Payload, cat_alloc)) return error.PayloadMismatch;
    gzip_concatenated_successes += 1;
    var cat_decoder = try vort.GzipDecoder.initConcatenatedWithOptionsExactSize(cat, &cat_out, gzip_concat_relaxed, Payload.len * 2);
    try drainDecoderPayload(&cat_decoder, Payload ++ Payload);
    gzip_decoder_successes += 1;
    const cat_chunks = [_][]const u8{ cat[0..5], cat[5 .. cat.len - 3], cat[cat.len - 3 ..] };
    var cat_chunk_decoder = try vort.GzipDecoder.initConcatenatedFromChunksWithOptionsExactSize(&cat_chunks, &compressed_scratch, &cat_out, gzip_concat_relaxed, Payload.len * 2);
    try drainDecoderPayload(&cat_chunk_decoder, Payload ++ Payload);
    gzip_decoder_successes += 1;

    var stdout_buffer: [512]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    try stdout_writer.interface.print("relaxed wrapper report: zlib_strict_rejections={d} zlib_relaxed_successes={d} dictionary_successes={d} zlib_concatenated_successes={d} zlib_decoder_successes={d} limited_rejections={d} gzip_strict_rejections={d} gzip_relaxed_successes={d} gzip_concatenated_successes={d} gzip_decoder_successes={d} gzip_limited_rejections={d}\n", .{ strict_rejections, relaxed_successes, dictionary_successes, zlib_concatenated_successes, zlib_decoder_successes, limited_rejections, gzip_strict_rejections, gzip_relaxed_successes, gzip_concatenated_successes, gzip_decoder_successes, gzip_limited_rejections });
    try stdout_writer.interface.flush();

    if (json_path) |path| try writeJson(init, path, strict_rejections, relaxed_successes, dictionary_successes, zlib_concatenated_successes, zlib_decoder_successes, limited_rejections, gzip_strict_rejections, gzip_relaxed_successes, gzip_concatenated_successes, gzip_decoder_successes, gzip_limited_rejections);
    if (markdown_path) |path| try writeMarkdown(init, path, strict_rejections, relaxed_successes, dictionary_successes, zlib_concatenated_successes, zlib_decoder_successes, limited_rejections, gzip_strict_rejections, gzip_relaxed_successes, gzip_concatenated_successes, gzip_decoder_successes, gzip_limited_rejections);
}

fn expectZlibError(expected: anyerror, frame: []const u8, options: vort.ZlibDecodeOptions) !void {
    var out: [Payload.len]u8 = undefined;
    if (vort.decodeZlibWithOptions(frame, &out, options)) |_| return error.ExpectedFailure else |err| {
        if (err != expected) return err;
    }
}

fn expectZlibPayload(allocator: std.mem.Allocator, frame: []const u8, options: vort.ZlibDecodeOptions) !void {
    var out: [Payload.len]u8 = undefined;
    const written = try vort.decodeZlibWithOptions(frame, &out, options);
    if (written != Payload.len or !std.mem.eql(u8, Payload, &out)) return error.PayloadMismatch;
    const decoded = try vort.decodeZlibAllocWithOptions(allocator, frame, options);
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, Payload, decoded)) return error.PayloadMismatch;
}

fn expectGzipError(expected: anyerror, frame: []const u8, options: vort.GzipDecodeOptions) !void {
    var out: [Payload.len]u8 = undefined;
    if (vort.decodeGzipWithOptions(frame, &out, options)) |_| return error.ExpectedFailure else |err| {
        if (err != expected) return err;
    }
}

fn expectGzipPayload(allocator: std.mem.Allocator, frame: []const u8, options: vort.GzipDecodeOptions) !void {
    var out: [Payload.len]u8 = undefined;
    const written = try vort.decodeGzipWithOptions(frame, &out, options);
    if (written != Payload.len or !std.mem.eql(u8, Payload, &out)) return error.PayloadMismatch;
    const decoded = try vort.decodeGzipAllocWithOptions(allocator, frame, options);
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, Payload, decoded)) return error.PayloadMismatch;
}

fn expectGzipAllocExact(allocator: std.mem.Allocator, frame: []const u8, options: vort.GzipDecodeOptions) !void {
    const decoded = try vort.decodeGzipAllocWithOptionsExactSize(allocator, frame, options, Payload.len);
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, Payload, decoded)) return error.PayloadMismatch;
}

fn expectGzipAllocLimited(allocator: std.mem.Allocator, frame: []const u8, options: vort.GzipDecodeOptions) !void {
    const decoded = try vort.decodeGzipAllocWithOptionsLimited(allocator, frame, options, Payload.len);
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, Payload, decoded)) return error.PayloadMismatch;
}

fn expectGzipLimitExceeded(allocator: std.mem.Allocator, frame: []const u8, options: vort.GzipDecodeOptions) !void {
    if (vort.decodeGzipAllocWithOptionsLimited(allocator, frame, options, Payload.len - 1)) |decoded| {
        allocator.free(decoded);
        return error.ExpectedFailure;
    } else |err| switch (err) {
        error.OutputLimitExceeded => return,
        else => return err,
    }
}

fn drainDecoderPayload(decoder: *vort.GzipDecoder, expected: []const u8) !void {
    var output: [Payload.len * 2]u8 = undefined;
    var written: usize = 0;
    while (true) {
        var chunk: [3]u8 = undefined;
        const step = try decoder.step(&chunk);
        @memcpy(output[written..][0..step.progress.output_written], chunk[0..step.progress.output_written]);
        written += step.progress.output_written;
        if (step.status == .done) break;
        if (step.status != .need_output) return error.UnexpectedDecoderStatus;
    }
    if (written != expected.len or !std.mem.eql(u8, expected, output[0..written])) return error.PayloadMismatch;
}

fn drainZlibDecoderPayload(decoder: *vort.ZlibDecoder, expected: []const u8) !void {
    var output: [Payload.len * 2]u8 = undefined;
    var written: usize = 0;
    while (true) {
        var chunk: [3]u8 = undefined;
        const step = try decoder.step(&chunk);
        @memcpy(output[written..][0..step.progress.output_written], chunk[0..step.progress.output_written]);
        written += step.progress.output_written;
        if (step.status == .done) break;
        if (step.status != .need_output) return error.UnexpectedDecoderStatus;
    }
    if (written != expected.len or !std.mem.eql(u8, expected, output[0..written])) return error.PayloadMismatch;
}

fn expectAllocExact(allocator: std.mem.Allocator, frame: []const u8, options: vort.ZlibDecodeOptions) !void {
    const decoded = try vort.decodeZlibAllocWithOptionsExactSize(allocator, frame, options, Payload.len);
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, Payload, decoded)) return error.PayloadMismatch;
}

fn expectAllocLimited(allocator: std.mem.Allocator, frame: []const u8, options: vort.ZlibDecodeOptions) !void {
    const decoded = try vort.decodeZlibAllocWithOptionsLimited(allocator, frame, options, Payload.len);
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, Payload, decoded)) return error.PayloadMismatch;
}

fn expectLimitExceeded(allocator: std.mem.Allocator, frame: []const u8, options: vort.ZlibDecodeOptions) !void {
    if (vort.decodeZlibAllocWithOptionsLimited(allocator, frame, options, Payload.len - 1)) |decoded| {
        allocator.free(decoded);
        return error.ExpectedFailure;
    } else |err| switch (err) {
        error.OutputLimitExceeded => return,
        else => return err,
    }
}

fn writeJson(
    init: std.process.Init,
    path: []const u8,
    strict_rejections: usize,
    relaxed_successes: usize,
    dictionary_successes: usize,
    zlib_concatenated_successes: usize,
    zlib_decoder_successes: usize,
    limited_rejections: usize,
    gzip_strict_rejections: usize,
    gzip_relaxed_successes: usize,
    gzip_concatenated_successes: usize,
    gzip_decoder_successes: usize,
    gzip_limited_rejections: usize,
) !void {
    var writer = std.Io.Writer.Allocating.init(init.gpa);
    defer writer.deinit();
    try writer.writer.print(
        "{{\n" ++
            "  \"schema\": \"vort.zlib_relaxed_report\",\n" ++
            "  \"schema_version\": 4,\n" ++
            "  \"strict_rejections\": {d},\n" ++
            "  \"relaxed_successes\": {d},\n" ++
            "  \"dictionary_successes\": {d},\n" ++
            "  \"zlib_concatenated_successes\": {d},\n" ++
            "  \"zlib_decoder_successes\": {d},\n" ++
            "  \"limited_rejections\": {d},\n" ++
            "  \"gzip_strict_rejections\": {d},\n" ++
            "  \"gzip_relaxed_successes\": {d},\n" ++
            "  \"gzip_concatenated_successes\": {d},\n" ++
            "  \"gzip_decoder_successes\": {d},\n" ++
            "  \"gzip_limited_rejections\": {d}\n" ++
            "}}\n",
        .{
            strict_rejections,
            relaxed_successes,
            dictionary_successes,
            zlib_concatenated_successes,
            zlib_decoder_successes,
            limited_rejections,
            gzip_strict_rejections,
            gzip_relaxed_successes,
            gzip_concatenated_successes,
            gzip_decoder_successes,
            gzip_limited_rejections,
        },
    );
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = writer.written() });
}

fn writeMarkdown(
    init: std.process.Init,
    path: []const u8,
    strict_rejections: usize,
    relaxed_successes: usize,
    dictionary_successes: usize,
    zlib_concatenated_successes: usize,
    zlib_decoder_successes: usize,
    limited_rejections: usize,
    gzip_strict_rejections: usize,
    gzip_relaxed_successes: usize,
    gzip_concatenated_successes: usize,
    gzip_decoder_successes: usize,
    gzip_limited_rejections: usize,
) !void {
    var writer = std.Io.Writer.Allocating.init(init.gpa);
    defer writer.deinit();
    try writer.writer.print(
        "# relaxed wrapper decode report\n\n" ++
            "| metric | value |\n" ++
            "| --- | ---: |\n" ++
            "| zlib strict rejections | {d} |\n" ++
            "| zlib relaxed successes | {d} |\n" ++
            "| zlib dictionary successes | {d} |\n" ++
            "| zlib concatenated successes | {d} |\n" ++
            "| zlib decoder successes | {d} |\n" ++
            "| zlib limited rejections | {d} |\n" ++
            "| gzip strict rejections | {d} |\n" ++
            "| gzip relaxed successes | {d} |\n" ++
            "| gzip concatenated successes | {d} |\n" ++
            "| gzip decoder successes | {d} |\n" ++
            "| gzip limited rejections | {d} |\n",
        .{
            strict_rejections,
            relaxed_successes,
            dictionary_successes,
            zlib_concatenated_successes,
            zlib_decoder_successes,
            limited_rejections,
            gzip_strict_rejections,
            gzip_relaxed_successes,
            gzip_concatenated_successes,
            gzip_decoder_successes,
            gzip_limited_rejections,
        },
    );
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = writer.written() });
}
