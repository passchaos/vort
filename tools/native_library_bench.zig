const std = @import("std");
const vort = @import("vort");

const Codec = enum { lz4, zstd };
const Mode = enum {
    one_shot,
    incremental,
    incremental_direct,
    incremental_fallback,
    chain_depth_0,
    chain_depth_default,
    match_budget_0,
    match_budget_full,
    high_byte_binary,
    sequence_huffman_literals_plain,
    sequence_huffman_literals,
    dictionary_plain,
    dictionary,
    dictionary_set_plain,
    dictionary_set,
    dictionary_set_chunked_plain,
    dictionary_set_chunked,
    dictionary_set_chunked_append_plain,
    dictionary_set_chunked_append,
    dictionary_set_chunked_append_exact_plain,
    dictionary_set_chunked_append_exact,
    dictionary_set_reusable_plain,
    dictionary_set_reusable,
    dictionary_set_reusable_append_exact_plain,
    dictionary_set_reusable_append_exact,
    dictionary_set_direct_plain,
    dictionary_set_direct,
    dictionary_set_fallback_plain,
    dictionary_set_fallback,
};

const Case = struct {
    name: []const u8,
    payload: []const u8,
};

const Row = struct {
    codec: Codec,
    mode: Mode,
    case_name: []const u8,
    input_bytes: usize,
    encoded_bytes: usize,
    iterations: usize,
    encode_ns: u64,
    decode_ns: u64,
    encode_mib_s: f64,
    decode_mib_s: f64,
    checksum: u64,
};

const Options = struct {
    iterations: usize = 200,
    csv_path: ?[]const u8 = null,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const options = try parseOptions(&args);

    const cases = [_]Case{
        .{ .name = "text", .payload = "Native library benchmark text payload. " ** 1024 },
        .{ .name = "structured", .payload = "{\"service\":\"vort\",\"codec\":\"native\",\"value\":12345}\n" ** 768 },
        .{ .name = "repetitive", .payload = ("abcdefghijklmnopqrstuvwxyz012345" ** 4) ** 256 },
    };

    try smokeLz4LinkedDirectFallback(init.gpa);
    try smokeLz4DeepHashChain(init.gpa);
    try smokeLz4LinkedDeepHashChain(init.gpa);
    try smokeLz4ChainDepthBudget(init.gpa);
    try smokeZstdMultiblockDirectFallback(init.gpa);
    try smokeReusableChunkedDecoders(init.gpa);
    try smokeZstdManyRepeatedSequences(init.gpa);
    try smokeZstdSequenceInspectFixtures(init.gpa);
    try smokeZstdNoSizeMultiCompressed(init.gpa);
    try smokeZstdMatchSearchBudget(init.gpa);
    try smokeNativeDictionaryBenchRows(init.gpa);
    try smokeNativeDictionarySetBenchRows(init.gpa);
    try smokeNativeDictionarySetChunkedBenchRows(init.gpa);

    var rows: std.ArrayList(Row) = .empty;
    defer rows.deinit(init.gpa);
    for (cases) |case| {
        try rows.append(init.gpa, try lz4OneShotRow(init.io, init.gpa, case, options.iterations));
        try rows.append(init.gpa, try lz4IncrementalRow(init.io, init.gpa, case, options.iterations));
        try rows.append(init.gpa, try lz4IncrementalDirectRow(init.io, init.gpa, case, options.iterations));
        try rows.append(init.gpa, try lz4IncrementalFallbackRow(init.io, init.gpa, case, options.iterations));
        try rows.append(init.gpa, try zstdOneShotRow(init.io, init.gpa, case, options.iterations));
        try rows.append(init.gpa, try zstdIncrementalRow(init.io, init.gpa, case, options.iterations));
        try rows.append(init.gpa, try zstdIncrementalDirectRow(init.io, init.gpa, case, options.iterations));
        try rows.append(init.gpa, try zstdIncrementalFallbackRow(init.io, init.gpa, case, options.iterations));
    }
    try rows.append(init.gpa, try lz4ChainDepthRow(init.io, init.gpa, .chain_depth_0, 0, options.iterations));
    try rows.append(init.gpa, try lz4ChainDepthRow(
        init.io,
        init.gpa,
        .chain_depth_default,
        vort.lz4NativeMaxChainDepth,
        options.iterations,
    ));
    try rows.append(init.gpa, try zstdMatchBudgetRow(init.io, init.gpa, .match_budget_0, 0, options.iterations));
    try rows.append(init.gpa, try zstdMatchBudgetRow(
        init.io,
        init.gpa,
        .match_budget_full,
        vort.zstdNativeMaxMatchSearchBudget,
        options.iterations,
    ));
    try rows.append(init.gpa, try zstdHighByteBinaryRow(init.io, init.gpa, options.iterations));
    try rows.append(init.gpa, try zstdSequenceHuffmanLiteralsRow(init.io, init.gpa, .sequence_huffman_literals_plain, false, options.iterations));
    try rows.append(init.gpa, try zstdSequenceHuffmanLiteralsRow(init.io, init.gpa, .sequence_huffman_literals, true, options.iterations));
    try rows.append(init.gpa, try lz4DictionaryRow(init.io, init.gpa, .dictionary_plain, false, options.iterations));
    try rows.append(init.gpa, try lz4DictionaryRow(init.io, init.gpa, .dictionary, true, options.iterations));
    try rows.append(init.gpa, try zstdDictionaryRow(init.io, init.gpa, .dictionary_plain, false, options.iterations));
    try rows.append(init.gpa, try zstdDictionaryRow(init.io, init.gpa, .dictionary, true, options.iterations));
    try rows.append(init.gpa, try lz4DictionarySetRow(init.io, init.gpa, .dictionary_set_plain, false, options.iterations));
    try rows.append(init.gpa, try lz4DictionarySetRow(init.io, init.gpa, .dictionary_set, true, options.iterations));
    try rows.append(init.gpa, try zstdDictionarySetRow(init.io, init.gpa, .dictionary_set_plain, false, options.iterations));
    try rows.append(init.gpa, try zstdDictionarySetRow(init.io, init.gpa, .dictionary_set, true, options.iterations));
    try rows.append(init.gpa, try lz4DictionarySetChunkedRow(init.io, init.gpa, .dictionary_set_chunked_plain, false, options.iterations));
    try rows.append(init.gpa, try lz4DictionarySetChunkedRow(init.io, init.gpa, .dictionary_set_chunked, true, options.iterations));
    try rows.append(init.gpa, try zstdDictionarySetChunkedRow(init.io, init.gpa, .dictionary_set_chunked_plain, false, options.iterations));
    try rows.append(init.gpa, try zstdDictionarySetChunkedRow(init.io, init.gpa, .dictionary_set_chunked, true, options.iterations));
    try rows.append(init.gpa, try lz4DictionarySetChunkedAppendRow(init.io, init.gpa, .dictionary_set_chunked_append_plain, false, false, options.iterations));
    try rows.append(init.gpa, try lz4DictionarySetChunkedAppendRow(init.io, init.gpa, .dictionary_set_chunked_append, true, false, options.iterations));
    try rows.append(init.gpa, try zstdDictionarySetChunkedAppendRow(init.io, init.gpa, .dictionary_set_chunked_append_plain, false, false, options.iterations));
    try rows.append(init.gpa, try zstdDictionarySetChunkedAppendRow(init.io, init.gpa, .dictionary_set_chunked_append, true, false, options.iterations));
    try rows.append(init.gpa, try lz4DictionarySetChunkedAppendRow(init.io, init.gpa, .dictionary_set_chunked_append_exact_plain, false, true, options.iterations));
    try rows.append(init.gpa, try lz4DictionarySetChunkedAppendRow(init.io, init.gpa, .dictionary_set_chunked_append_exact, true, true, options.iterations));
    try rows.append(init.gpa, try zstdDictionarySetChunkedAppendRow(init.io, init.gpa, .dictionary_set_chunked_append_exact_plain, false, true, options.iterations));
    try rows.append(init.gpa, try zstdDictionarySetChunkedAppendRow(init.io, init.gpa, .dictionary_set_chunked_append_exact, true, true, options.iterations));
    try rows.append(init.gpa, try lz4DictionarySetReusableChunkedRow(init.io, init.gpa, .dictionary_set_reusable_plain, false, options.iterations));
    try rows.append(init.gpa, try lz4DictionarySetReusableChunkedRow(init.io, init.gpa, .dictionary_set_reusable, true, options.iterations));
    try rows.append(init.gpa, try zstdDictionarySetReusableChunkedRow(init.io, init.gpa, .dictionary_set_reusable_plain, false, options.iterations));
    try rows.append(init.gpa, try zstdDictionarySetReusableChunkedRow(init.io, init.gpa, .dictionary_set_reusable, true, options.iterations));
    try rows.append(init.gpa, try lz4DictionarySetReusableAppendExactRow(init.io, init.gpa, .dictionary_set_reusable_append_exact_plain, false, options.iterations));
    try rows.append(init.gpa, try lz4DictionarySetReusableAppendExactRow(init.io, init.gpa, .dictionary_set_reusable_append_exact, true, options.iterations));
    try rows.append(init.gpa, try zstdDictionarySetReusableAppendExactRow(init.io, init.gpa, .dictionary_set_reusable_append_exact_plain, false, options.iterations));
    try rows.append(init.gpa, try zstdDictionarySetReusableAppendExactRow(init.io, init.gpa, .dictionary_set_reusable_append_exact, true, options.iterations));
    try rows.append(init.gpa, try lz4DictionarySetDirectRow(init.io, init.gpa, .dictionary_set_direct_plain, false, options.iterations));
    try rows.append(init.gpa, try lz4DictionarySetDirectRow(init.io, init.gpa, .dictionary_set_direct, true, options.iterations));
    try rows.append(init.gpa, try zstdDictionarySetDirectRow(init.io, init.gpa, .dictionary_set_direct_plain, false, options.iterations));
    try rows.append(init.gpa, try zstdDictionarySetDirectRow(init.io, init.gpa, .dictionary_set_direct, true, options.iterations));
    try rows.append(init.gpa, try lz4DictionarySetFallbackRow(init.io, init.gpa, .dictionary_set_fallback_plain, false, options.iterations));
    try rows.append(init.gpa, try lz4DictionarySetFallbackRow(init.io, init.gpa, .dictionary_set_fallback, true, options.iterations));
    try rows.append(init.gpa, try zstdDictionarySetFallbackRow(init.io, init.gpa, .dictionary_set_fallback_plain, false, options.iterations));
    try rows.append(init.gpa, try zstdDictionarySetFallbackRow(init.io, init.gpa, .dictionary_set_fallback, true, options.iterations));

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try writeCsv(&csv.writer, rows.items);
    if (options.csv_path) |path| {
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
    } else {
        var stdout_buffer: [1024]u8 = undefined;
        var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
        try stdout_writer.interface.writeAll(csv.written());
        try stdout_writer.interface.flush();
    }
}

fn parseOptions(args: *std.process.Args.Iterator) !Options {
    var options: Options = .{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--iterations")) {
            const value = args.next() orelse return error.MissingIterationCount;
            options.iterations = try std.fmt.parseInt(usize, value, 10);
            if (options.iterations == 0) return error.InvalidIterationCount;
        } else if (std.mem.eql(u8, arg, "--csv")) {
            options.csv_path = args.next() orelse return error.MissingCsvPath;
        } else {
            return error.UnknownArgument;
        }
    }
    return options;
}

fn lz4OneShotRow(io: std.Io, allocator: std.mem.Allocator, case: Case, iterations: usize) !Row {
    const options: vort.Lz4NativeFrameOptions = .{ .content_checksum = false, .block_checksum = true };
    const encoded = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, case.payload, options);
    defer allocator.free(encoded);
    const decoded = try allocator.alloc(u8, case.payload.len);
    defer allocator.free(decoded);
    try expectRoundTrip(vort.lz4DecodeNativeFrameInto(encoded, decoded), case.payload, decoded);

    const encode_result = try timeEncodeLz4(io, allocator, case.payload, options, iterations);
    const decode_result = try timeDecodeLz4OneShot(io, encoded, decoded, case.payload, iterations);
    return makeRow(.lz4, .one_shot, case, encoded.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn lz4IncrementalRow(io: std.Io, allocator: std.mem.Allocator, case: Case, iterations: usize) !Row {
    const options: vort.Lz4NativeFrameOptions = .{ .content_checksum = false, .block_checksum = true };
    const encoded = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, case.payload, options);
    defer allocator.free(encoded);
    const decoded = try allocator.alloc(u8, case.payload.len);
    defer allocator.free(decoded);
    try decodeLz4Incremental(allocator, encoded, decoded);
    if (!std.mem.eql(u8, case.payload, decoded)) return error.SizeMismatch;

    const decode_result = try timeDecodeLz4Incremental(io, allocator, encoded, decoded, case.payload, iterations);
    const encode_result = try timeEncodeLz4(io, allocator, case.payload, options, iterations);
    return makeRow(.lz4, .incremental, case, encoded.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn lz4IncrementalDirectRow(io: std.Io, allocator: std.mem.Allocator, case: Case, iterations: usize) !Row {
    const options: vort.Lz4NativeFrameOptions = .{ .content_checksum = false, .block_checksum = true };
    const encoded = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, case.payload, options);
    defer allocator.free(encoded);
    const decoded = try allocator.alloc(u8, case.payload.len);
    defer allocator.free(decoded);
    try decodeLz4IncrementalDirect(allocator, encoded, decoded);
    if (!std.mem.eql(u8, case.payload, decoded)) return error.SizeMismatch;

    const decode_result = try timeDecodeLz4IncrementalDirect(io, allocator, encoded, decoded, case.payload, iterations);
    const encode_result = try timeEncodeLz4(io, allocator, case.payload, options, iterations);
    return makeRow(.lz4, .incremental_direct, case, encoded.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn lz4IncrementalFallbackRow(io: std.Io, allocator: std.mem.Allocator, case: Case, iterations: usize) !Row {
    const options: vort.Lz4NativeFrameOptions = .{ .content_checksum = false, .block_checksum = true };
    const encoded = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, case.payload, options);
    defer allocator.free(encoded);
    const decoded = try allocator.alloc(u8, case.payload.len);
    defer allocator.free(decoded);
    try decodeLz4IncrementalFallback(allocator, encoded, decoded, case.payload);

    const decode_result = try timeDecodeLz4IncrementalFallback(io, allocator, encoded, decoded, case.payload, iterations);
    const encode_result = try timeEncodeLz4(io, allocator, case.payload, options, iterations);
    return makeRow(.lz4, .incremental_fallback, case, encoded.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn zstdOneShotRow(io: std.Io, allocator: std.mem.Allocator, case: Case, iterations: usize) !Row {
    const options: vort.ZstdNativeFrameOptions = .{ .selection = .literal_only, .content_checksum = false };
    const encoded = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, case.payload, options);
    defer allocator.free(encoded.frame);
    const decoded = try allocator.alloc(u8, case.payload.len);
    defer allocator.free(decoded);
    try expectRoundTrip(vort.zstdDecodeNativeFrameInto(encoded.frame, decoded), case.payload, decoded);

    const encode_result = try timeEncodeZstd(io, allocator, case.payload, options, iterations);
    const decode_result = try timeDecodeZstdOneShot(io, encoded.frame, decoded, case.payload, iterations);
    return makeRow(.zstd, .one_shot, case, encoded.frame.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn zstdIncrementalRow(io: std.Io, allocator: std.mem.Allocator, case: Case, iterations: usize) !Row {
    const options: vort.ZstdNativeFrameOptions = .{ .selection = .literal_only, .content_checksum = false };
    const encoded = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, case.payload, options);
    defer allocator.free(encoded.frame);
    const decoded = try allocator.alloc(u8, case.payload.len);
    defer allocator.free(decoded);
    try decodeZstdIncremental(allocator, encoded.frame, decoded);
    if (!std.mem.eql(u8, case.payload, decoded)) return error.SizeMismatch;

    const decode_result = try timeDecodeZstdIncremental(io, allocator, encoded.frame, decoded, case.payload, iterations);
    const encode_result = try timeEncodeZstd(io, allocator, case.payload, options, iterations);
    return makeRow(.zstd, .incremental, case, encoded.frame.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn zstdIncrementalDirectRow(io: std.Io, allocator: std.mem.Allocator, case: Case, iterations: usize) !Row {
    const options: vort.ZstdNativeFrameOptions = .{ .selection = .literal_only, .content_checksum = false };
    const encoded = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, case.payload, options);
    defer allocator.free(encoded.frame);
    const decoded = try allocator.alloc(u8, case.payload.len);
    defer allocator.free(decoded);
    try decodeZstdIncrementalDirect(allocator, encoded.frame, decoded);
    if (!std.mem.eql(u8, case.payload, decoded)) return error.SizeMismatch;

    const decode_result = try timeDecodeZstdIncrementalDirect(io, allocator, encoded.frame, decoded, case.payload, iterations);
    const encode_result = try timeEncodeZstd(io, allocator, case.payload, options, iterations);
    return makeRow(.zstd, .incremental_direct, case, encoded.frame.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn zstdIncrementalFallbackRow(io: std.Io, allocator: std.mem.Allocator, case: Case, iterations: usize) !Row {
    const options: vort.ZstdNativeFrameOptions = .{ .selection = .literal_only, .content_checksum = false };
    const encoded = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, case.payload, options);
    defer allocator.free(encoded.frame);
    const decoded = try allocator.alloc(u8, case.payload.len);
    defer allocator.free(decoded);
    try decodeZstdIncrementalFallback(allocator, encoded.frame, decoded, case.payload);

    const decode_result = try timeDecodeZstdIncrementalFallback(io, allocator, encoded.frame, decoded, case.payload, iterations);
    const encode_result = try timeEncodeZstd(io, allocator, case.payload, options, iterations);
    return makeRow(.zstd, .incremental_fallback, case, encoded.frame.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn lz4ChainDepthRow(
    io: std.Io,
    allocator: std.mem.Allocator,
    mode: Mode,
    chain_depth: u8,
    iterations: usize,
) !Row {
    const payload = lz4_chain_depth_payload;
    const case: Case = .{ .name = "chain_depth", .payload = payload };
    const options: vort.Lz4NativeFrameOptions = .{
        .content_checksum = false,
        .block_checksum = true,
        .chain_depth = chain_depth,
    };
    const encoded = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, payload, options);
    defer allocator.free(encoded);
    const decoded = try allocator.alloc(u8, payload.len);
    defer allocator.free(decoded);
    try expectRoundTrip(vort.lz4DecodeNativeFrameInto(encoded, decoded), payload, decoded);

    const encode_result = try timeEncodeLz4(io, allocator, payload, options, iterations);
    const decode_result = try timeDecodeLz4OneShot(io, encoded, decoded, payload, iterations);
    return makeRow(.lz4, mode, case, encoded.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn zstdMatchBudgetRow(
    io: std.Io,
    allocator: std.mem.Allocator,
    mode: Mode,
    match_search_budget: usize,
    iterations: usize,
) !Row {
    const payload = zstd_match_budget_payload;
    const case: Case = .{ .name = "mixed_budget", .payload = payload };
    const options: vort.ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
        .match_search_budget = match_search_budget,
    };
    const encoded = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, payload, options);
    defer allocator.free(encoded.frame);
    const decoded = try allocator.alloc(u8, payload.len);
    defer allocator.free(decoded);
    try expectRoundTrip(vort.zstdDecodeNativeFrameInto(encoded.frame, decoded), payload, decoded);

    const encode_result = try timeEncodeZstd(io, allocator, payload, options, iterations);
    const decode_result = try timeDecodeZstdOneShot(io, encoded.frame, decoded, payload, iterations);
    return makeRow(.zstd, mode, case, encoded.frame.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn zstdHighByteBinaryRow(io: std.Io, allocator: std.mem.Allocator, iterations: usize) !Row {
    const payload = &zstd_high_byte_binary_payload;
    const case: Case = .{ .name = "high_byte_binary", .payload = payload };
    const options: vort.ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };
    const encoded = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, payload, options);
    defer allocator.free(encoded.frame);
    const decoded = try allocator.alloc(u8, payload.len);
    defer allocator.free(decoded);
    try expectRoundTrip(vort.zstdDecodeNativeFrameInto(encoded.frame, decoded), payload, decoded);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(encoded.frame);
    if (first_block.block_type != .compressed) return error.SizeMismatch;
    if (first_block.payload_len >= payload.len) return error.SizeMismatch;

    const encode_result = try timeEncodeZstd(io, allocator, payload, options, iterations);
    const decode_result = try timeDecodeZstdOneShot(io, encoded.frame, decoded, payload, iterations);
    return makeRow(.zstd, .high_byte_binary, case, encoded.frame.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn zstdSequenceHuffmanLiteralsRow(
    io: std.Io,
    allocator: std.mem.Allocator,
    mode: Mode,
    use_dictionary: bool,
    iterations: usize,
) !Row {
    const dict = vort.ZstdNativeDictionary.init(0x5a53_4801, &zstd_sequence_huffman_dictionary_content);
    const payload = &zstd_sequence_huffman_literals_payload;
    const case: Case = .{ .name = "sequence_huffman_literals", .payload = payload };
    const options: vort.ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
        .match_search_budget = 0,
    };
    const encoded = if (use_dictionary)
        try vort.zstdEncodeNativeFrameWithDictionaryAlloc(allocator, payload, options, dict)
    else
        try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, payload, options);
    defer allocator.free(encoded.frame);
    const decoded = try allocator.alloc(u8, payload.len);
    defer allocator.free(decoded);
    if (use_dictionary) {
        try expectRoundTrip(vort.zstdDecodeNativeFrameIntoWithDictionary(encoded.frame, decoded, dict), payload, decoded);
        if (vort.zstdDecodeNativeFrameAlloc(allocator, encoded.frame)) |missing_dict_decoded| {
            allocator.free(missing_dict_decoded);
            return error.SizeMismatch;
        } else |err| switch (err) {
            error.NeedDictionary => {},
            else => return err,
        }
        const first_block = try vort.zstdInspectNativeFrameFirstBlock(encoded.frame);
        if (first_block.block_type != .compressed) return error.SizeMismatch;
        if ((encoded.frame[first_block.payload_offset] & 0x03) != 2) return error.SizeMismatch;
    } else {
        try expectRoundTrip(vort.zstdDecodeNativeFrameInto(encoded.frame, decoded), payload, decoded);
    }

    const encode_result = try timeEncodeZstdDictionary(io, allocator, payload, options, dict, use_dictionary, iterations);
    const decode_result = try timeDecodeZstdDictionaryOneShot(io, encoded.frame, decoded, payload, dict, use_dictionary, iterations);
    return makeRow(.zstd, mode, case, encoded.frame.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn lz4DictionaryRow(
    io: std.Io,
    allocator: std.mem.Allocator,
    mode: Mode,
    use_dictionary: bool,
    iterations: usize,
) !Row {
    const dict = vort.Lz4NativeDictionary.init(0x4c5a_4401, lz4_dictionary_content);
    const payload = lz4_dictionary_payload;
    const case: Case = .{ .name = "dictionary", .payload = payload };
    const options: vort.Lz4NativeFrameOptions = .{
        .content_checksum = false,
        .block_checksum = true,
    };
    const encoded = if (use_dictionary)
        try vort.lz4EncodeNativeFrameWithDictionaryAlloc(allocator, payload, options, dict)
    else
        try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, payload, options);
    defer allocator.free(encoded);
    const decoded = try allocator.alloc(u8, payload.len);
    defer allocator.free(decoded);
    if (use_dictionary) {
        try expectRoundTrip(vort.lz4DecodeNativeFrameIntoWithDictionary(encoded, decoded, dict), payload, decoded);
    } else {
        try expectRoundTrip(vort.lz4DecodeNativeFrameInto(encoded, decoded), payload, decoded);
    }

    const encode_result = try timeEncodeLz4Dictionary(io, allocator, payload, options, dict, use_dictionary, iterations);
    const decode_result = try timeDecodeLz4DictionaryOneShot(io, encoded, decoded, payload, dict, use_dictionary, iterations);
    return makeRow(.lz4, mode, case, encoded.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn zstdDictionaryRow(
    io: std.Io,
    allocator: std.mem.Allocator,
    mode: Mode,
    use_dictionary: bool,
    iterations: usize,
) !Row {
    const dict = vort.ZstdNativeDictionary.init(0x5a53_4401, zstd_dictionary_content);
    const payload = zstd_dictionary_payload;
    const case: Case = .{ .name = "dictionary", .payload = payload };
    const options: vort.ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };
    const encoded = if (use_dictionary)
        try vort.zstdEncodeNativeFrameWithDictionaryAlloc(allocator, payload, options, dict)
    else
        try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, payload, options);
    defer allocator.free(encoded.frame);
    const decoded = try allocator.alloc(u8, payload.len);
    defer allocator.free(decoded);
    if (use_dictionary) {
        try expectRoundTrip(vort.zstdDecodeNativeFrameIntoWithDictionary(encoded.frame, decoded, dict), payload, decoded);
    } else {
        try expectRoundTrip(vort.zstdDecodeNativeFrameInto(encoded.frame, decoded), payload, decoded);
    }

    const encode_result = try timeEncodeZstdDictionary(io, allocator, payload, options, dict, use_dictionary, iterations);
    const decode_result = try timeDecodeZstdDictionaryOneShot(io, encoded.frame, decoded, payload, dict, use_dictionary, iterations);
    return makeRow(.zstd, mode, case, encoded.frame.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn lz4DictionarySetRow(
    io: std.Io,
    allocator: std.mem.Allocator,
    mode: Mode,
    use_dictionary_set: bool,
    iterations: usize,
) !Row {
    const first_dict = vort.Lz4NativeDictionary.init(0x4c5a_4501, lz4_dictionary_set_first_content);
    const second_dict = vort.Lz4NativeDictionary.init(0x4c5a_4502, lz4_dictionary_set_second_content);
    const dictionary_set = vort.Lz4NativeDictionarySet.init(&.{ first_dict, second_dict });
    const case: Case = .{ .name = "dictionary_set", .payload = lz4_dictionary_set_payload };
    const options: vort.Lz4NativeFrameOptions = .{
        .content_checksum = false,
        .block_checksum = true,
    };

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try appendLz4DictionarySetFrames(allocator, &encoded, options, dictionary_set, first_dict, second_dict, use_dictionary_set);

    const decoded = try allocator.alloc(u8, lz4_dictionary_set_payload.len);
    defer allocator.free(decoded);
    if (use_dictionary_set) {
        try expectRoundTrip(vort.lz4DecodeNativeConcatenatedFrameIntoWithDictionarySet(encoded.items, decoded, dictionary_set), lz4_dictionary_set_payload, decoded);
    } else {
        try expectRoundTrip(vort.lz4DecodeNativeConcatenatedFrameInto(encoded.items, decoded), lz4_dictionary_set_payload, decoded);
    }

    const encode_result = try timeEncodeLz4DictionarySet(io, allocator, options, dictionary_set, first_dict, second_dict, use_dictionary_set, iterations);
    const decode_result = try timeDecodeLz4DictionarySetOneShot(io, encoded.items, decoded, dictionary_set, use_dictionary_set, iterations);
    return makeRow(.lz4, mode, case, encoded.items.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn zstdDictionarySetRow(
    io: std.Io,
    allocator: std.mem.Allocator,
    mode: Mode,
    use_dictionary_set: bool,
    iterations: usize,
) !Row {
    const first_dict = vort.ZstdNativeDictionary.init(0x5a53_4501, zstd_dictionary_set_first_content);
    const second_dict = vort.ZstdNativeDictionary.init(0x5a53_4502, zstd_dictionary_set_second_content);
    const dictionary_set = vort.ZstdNativeDictionarySet.init(&.{ first_dict, second_dict });
    const case: Case = .{ .name = "dictionary_set", .payload = zstd_dictionary_set_payload };
    const options: vort.ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try appendZstdDictionarySetFrames(allocator, &encoded, options, dictionary_set, first_dict, second_dict, use_dictionary_set);

    const decoded = try allocator.alloc(u8, zstd_dictionary_set_payload.len);
    defer allocator.free(decoded);
    if (use_dictionary_set) {
        try expectRoundTrip(vort.zstdDecodeNativeConcatenatedFrameIntoWithDictionarySet(encoded.items, decoded, dictionary_set), zstd_dictionary_set_payload, decoded);
    } else {
        try expectRoundTrip(vort.zstdDecodeNativeConcatenatedFrameInto(encoded.items, decoded), zstd_dictionary_set_payload, decoded);
    }

    const encode_result = try timeEncodeZstdDictionarySet(io, allocator, options, dictionary_set, first_dict, second_dict, use_dictionary_set, iterations);
    const decode_result = try timeDecodeZstdDictionarySetOneShot(io, encoded.items, decoded, dictionary_set, use_dictionary_set, iterations);
    return makeRow(.zstd, mode, case, encoded.items.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn lz4DictionarySetChunkedRow(
    io: std.Io,
    allocator: std.mem.Allocator,
    mode: Mode,
    use_dictionary_set: bool,
    iterations: usize,
) !Row {
    const first_dict = vort.Lz4NativeDictionary.init(0x4c5a_4501, lz4_dictionary_set_first_content);
    const second_dict = vort.Lz4NativeDictionary.init(0x4c5a_4502, lz4_dictionary_set_second_content);
    const dictionary_set = vort.Lz4NativeDictionarySet.init(&.{ first_dict, second_dict });
    const case: Case = .{ .name = "dictionary_set_chunked", .payload = lz4_dictionary_set_payload };
    const options: vort.Lz4NativeFrameOptions = .{
        .content_checksum = false,
        .block_checksum = true,
    };

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try appendLz4DictionarySetFrames(allocator, &encoded, options, dictionary_set, first_dict, second_dict, use_dictionary_set);
    const chunks = dictionarySetChunks(encoded.items);
    const join = try allocator.alloc(u8, encoded.items.len);
    defer allocator.free(join);
    const decoded = try allocator.alloc(u8, lz4_dictionary_set_payload.len);
    defer allocator.free(decoded);
    if (use_dictionary_set) {
        try expectRoundTrip(vort.lz4DecodeNativeConcatenatedFrameChunksIntoWithDictionarySet(&chunks, join, decoded, dictionary_set), lz4_dictionary_set_payload, decoded);
    } else {
        try expectRoundTrip(vort.lz4DecodeNativeConcatenatedFrameChunksInto(&chunks, join, decoded), lz4_dictionary_set_payload, decoded);
    }

    const encode_result = try timeEncodeLz4DictionarySet(io, allocator, options, dictionary_set, first_dict, second_dict, use_dictionary_set, iterations);
    const decode_result = try timeDecodeLz4DictionarySetChunked(io, &chunks, join, decoded, dictionary_set, use_dictionary_set, iterations);
    return makeRow(.lz4, mode, case, encoded.items.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn zstdDictionarySetChunkedRow(
    io: std.Io,
    allocator: std.mem.Allocator,
    mode: Mode,
    use_dictionary_set: bool,
    iterations: usize,
) !Row {
    const first_dict = vort.ZstdNativeDictionary.init(0x5a53_4501, zstd_dictionary_set_first_content);
    const second_dict = vort.ZstdNativeDictionary.init(0x5a53_4502, zstd_dictionary_set_second_content);
    const dictionary_set = vort.ZstdNativeDictionarySet.init(&.{ first_dict, second_dict });
    const case: Case = .{ .name = "dictionary_set_chunked", .payload = zstd_dictionary_set_payload };
    const options: vort.ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try appendZstdDictionarySetFrames(allocator, &encoded, options, dictionary_set, first_dict, second_dict, use_dictionary_set);
    const chunks = dictionarySetChunks(encoded.items);
    const join = try allocator.alloc(u8, encoded.items.len);
    defer allocator.free(join);
    const decoded = try allocator.alloc(u8, zstd_dictionary_set_payload.len);
    defer allocator.free(decoded);
    if (use_dictionary_set) {
        try expectRoundTrip(vort.zstdDecodeNativeConcatenatedFrameChunksIntoWithDictionarySet(&chunks, join, decoded, dictionary_set), zstd_dictionary_set_payload, decoded);
    } else {
        try expectRoundTrip(vort.zstdDecodeNativeConcatenatedFrameChunksInto(&chunks, join, decoded), zstd_dictionary_set_payload, decoded);
    }

    const encode_result = try timeEncodeZstdDictionarySet(io, allocator, options, dictionary_set, first_dict, second_dict, use_dictionary_set, iterations);
    const decode_result = try timeDecodeZstdDictionarySetChunked(io, &chunks, join, decoded, dictionary_set, use_dictionary_set, iterations);
    return makeRow(.zstd, mode, case, encoded.items.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn lz4DictionarySetChunkedAppendRow(
    io: std.Io,
    allocator: std.mem.Allocator,
    mode: Mode,
    use_dictionary_set: bool,
    exact_size: bool,
    iterations: usize,
) !Row {
    const first_dict = vort.Lz4NativeDictionary.init(0x4c5a_4501, lz4_dictionary_set_first_content);
    const second_dict = vort.Lz4NativeDictionary.init(0x4c5a_4502, lz4_dictionary_set_second_content);
    const dictionary_set = vort.Lz4NativeDictionarySet.init(&.{ first_dict, second_dict });
    const case: Case = .{ .name = if (exact_size) "dictionary_set_chunked_append_exact" else "dictionary_set_chunked_append", .payload = lz4_dictionary_set_payload };
    const options: vort.Lz4NativeFrameOptions = .{
        .content_checksum = false,
        .block_checksum = true,
    };

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try appendLz4DictionarySetFrames(allocator, &encoded, options, dictionary_set, first_dict, second_dict, use_dictionary_set);
    const chunks = dictionarySetChunks(encoded.items);
    const join = try allocator.alloc(u8, encoded.items.len);
    defer allocator.free(join);
    if (use_dictionary_set) {
        try verifyLz4DictionarySetChunkedAppend(allocator, &chunks, join, dictionary_set, true, exact_size);
    } else {
        try verifyLz4DictionarySetChunkedAppend(allocator, &chunks, join, dictionary_set, false, exact_size);
    }

    const encode_result = try timeEncodeLz4DictionarySet(io, allocator, options, dictionary_set, first_dict, second_dict, use_dictionary_set, iterations);
    const decode_result = try timeDecodeLz4DictionarySetChunkedAppend(io, allocator, &chunks, join, dictionary_set, use_dictionary_set, exact_size, iterations);
    return makeRow(.lz4, mode, case, encoded.items.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn zstdDictionarySetChunkedAppendRow(
    io: std.Io,
    allocator: std.mem.Allocator,
    mode: Mode,
    use_dictionary_set: bool,
    exact_size: bool,
    iterations: usize,
) !Row {
    const first_dict = vort.ZstdNativeDictionary.init(0x5a53_4501, zstd_dictionary_set_first_content);
    const second_dict = vort.ZstdNativeDictionary.init(0x5a53_4502, zstd_dictionary_set_second_content);
    const dictionary_set = vort.ZstdNativeDictionarySet.init(&.{ first_dict, second_dict });
    const case: Case = .{ .name = if (exact_size) "dictionary_set_chunked_append_exact" else "dictionary_set_chunked_append", .payload = zstd_dictionary_set_payload };
    const options: vort.ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try appendZstdDictionarySetFrames(allocator, &encoded, options, dictionary_set, first_dict, second_dict, use_dictionary_set);
    const chunks = dictionarySetChunks(encoded.items);
    const join = try allocator.alloc(u8, encoded.items.len);
    defer allocator.free(join);
    if (use_dictionary_set) {
        try verifyZstdDictionarySetChunkedAppend(allocator, &chunks, join, dictionary_set, true, exact_size);
    } else {
        try verifyZstdDictionarySetChunkedAppend(allocator, &chunks, join, dictionary_set, false, exact_size);
    }

    const encode_result = try timeEncodeZstdDictionarySet(io, allocator, options, dictionary_set, first_dict, second_dict, use_dictionary_set, iterations);
    const decode_result = try timeDecodeZstdDictionarySetChunkedAppend(io, allocator, &chunks, join, dictionary_set, use_dictionary_set, exact_size, iterations);
    return makeRow(.zstd, mode, case, encoded.items.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn lz4DictionarySetReusableChunkedRow(
    io: std.Io,
    allocator: std.mem.Allocator,
    mode: Mode,
    use_dictionary_set: bool,
    iterations: usize,
) !Row {
    const first_dict = vort.Lz4NativeDictionary.init(0x4c5a_4501, lz4_dictionary_set_first_content);
    const second_dict = vort.Lz4NativeDictionary.init(0x4c5a_4502, lz4_dictionary_set_second_content);
    const dictionary_set = vort.Lz4NativeDictionarySet.init(&.{ first_dict, second_dict });
    const case: Case = .{ .name = "dictionary_set_reusable", .payload = lz4_dictionary_set_payload };
    const options: vort.Lz4NativeFrameOptions = .{
        .content_checksum = false,
        .block_checksum = true,
    };

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try appendLz4DictionarySetFrames(allocator, &encoded, options, dictionary_set, first_dict, second_dict, use_dictionary_set);
    const chunks = dictionarySetChunks(encoded.items);
    const join = try allocator.alloc(u8, encoded.items.len);
    defer allocator.free(join);
    const decoded = try allocator.alloc(u8, lz4_dictionary_set_payload.len);
    defer allocator.free(decoded);
    var decoder = vort.Lz4NativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    if (use_dictionary_set) {
        try expectRoundTrip(decoder.decodeConcatenatedChunksIntoSliceWithDictionarySet(&chunks, join, decoded, dictionary_set), lz4_dictionary_set_payload, decoded);
    } else {
        try expectRoundTrip(decoder.decodeConcatenatedChunksIntoSlice(&chunks, join, decoded), lz4_dictionary_set_payload, decoded);
    }

    const encode_result = try timeEncodeLz4DictionarySet(io, allocator, options, dictionary_set, first_dict, second_dict, use_dictionary_set, iterations);
    const decode_result = try timeDecodeLz4DictionarySetReusableChunked(io, allocator, &chunks, join, decoded, dictionary_set, use_dictionary_set, iterations);
    return makeRow(.lz4, mode, case, encoded.items.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn zstdDictionarySetReusableChunkedRow(
    io: std.Io,
    allocator: std.mem.Allocator,
    mode: Mode,
    use_dictionary_set: bool,
    iterations: usize,
) !Row {
    const first_dict = vort.ZstdNativeDictionary.init(0x5a53_4501, zstd_dictionary_set_first_content);
    const second_dict = vort.ZstdNativeDictionary.init(0x5a53_4502, zstd_dictionary_set_second_content);
    const dictionary_set = vort.ZstdNativeDictionarySet.init(&.{ first_dict, second_dict });
    const case: Case = .{ .name = "dictionary_set_reusable", .payload = zstd_dictionary_set_payload };
    const options: vort.ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try appendZstdDictionarySetFrames(allocator, &encoded, options, dictionary_set, first_dict, second_dict, use_dictionary_set);
    const chunks = dictionarySetChunks(encoded.items);
    const join = try allocator.alloc(u8, encoded.items.len);
    defer allocator.free(join);
    const decoded = try allocator.alloc(u8, zstd_dictionary_set_payload.len);
    defer allocator.free(decoded);
    var decoder = vort.ZstdNativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    if (use_dictionary_set) {
        try expectRoundTrip(decoder.decodeConcatenatedChunksIntoSliceWithDictionarySet(&chunks, join, decoded, dictionary_set), zstd_dictionary_set_payload, decoded);
    } else {
        try expectRoundTrip(decoder.decodeConcatenatedChunksIntoSlice(&chunks, join, decoded), zstd_dictionary_set_payload, decoded);
    }

    const encode_result = try timeEncodeZstdDictionarySet(io, allocator, options, dictionary_set, first_dict, second_dict, use_dictionary_set, iterations);
    const decode_result = try timeDecodeZstdDictionarySetReusableChunked(io, allocator, &chunks, join, decoded, dictionary_set, use_dictionary_set, iterations);
    return makeRow(.zstd, mode, case, encoded.items.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn lz4DictionarySetReusableAppendExactRow(
    io: std.Io,
    allocator: std.mem.Allocator,
    mode: Mode,
    use_dictionary_set: bool,
    iterations: usize,
) !Row {
    const first_dict = vort.Lz4NativeDictionary.init(0x4c5a_4501, lz4_dictionary_set_first_content);
    const second_dict = vort.Lz4NativeDictionary.init(0x4c5a_4502, lz4_dictionary_set_second_content);
    const dictionary_set = vort.Lz4NativeDictionarySet.init(&.{ first_dict, second_dict });
    const case: Case = .{ .name = "dictionary_set_reusable_append_exact", .payload = lz4_dictionary_set_payload };
    const options: vort.Lz4NativeFrameOptions = .{
        .content_checksum = false,
        .block_checksum = true,
    };

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try appendLz4DictionarySetFrames(allocator, &encoded, options, dictionary_set, first_dict, second_dict, use_dictionary_set);
    const chunks = dictionarySetChunks(encoded.items);
    const join = try allocator.alloc(u8, encoded.items.len);
    defer allocator.free(join);
    var decoder = vort.Lz4NativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try verifyLz4ReusableAppendExactInto(&decoder, &out, &chunks, join, dictionary_set, use_dictionary_set);

    const encode_result = try timeEncodeLz4DictionarySet(io, allocator, options, dictionary_set, first_dict, second_dict, use_dictionary_set, iterations);
    const decode_result = try timeDecodeLz4DictionarySetReusableAppendExact(io, allocator, &chunks, join, dictionary_set, use_dictionary_set, iterations);
    return makeRow(.lz4, mode, case, encoded.items.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn zstdDictionarySetReusableAppendExactRow(
    io: std.Io,
    allocator: std.mem.Allocator,
    mode: Mode,
    use_dictionary_set: bool,
    iterations: usize,
) !Row {
    const first_dict = vort.ZstdNativeDictionary.init(0x5a53_4501, zstd_dictionary_set_first_content);
    const second_dict = vort.ZstdNativeDictionary.init(0x5a53_4502, zstd_dictionary_set_second_content);
    const dictionary_set = vort.ZstdNativeDictionarySet.init(&.{ first_dict, second_dict });
    const case: Case = .{ .name = "dictionary_set_reusable_append_exact", .payload = zstd_dictionary_set_payload };
    const options: vort.ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try appendZstdDictionarySetFrames(allocator, &encoded, options, dictionary_set, first_dict, second_dict, use_dictionary_set);
    const chunks = dictionarySetChunks(encoded.items);
    const join = try allocator.alloc(u8, encoded.items.len);
    defer allocator.free(join);
    var decoder = vort.ZstdNativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try verifyZstdReusableAppendExactInto(&decoder, &out, &chunks, join, dictionary_set, use_dictionary_set);

    const encode_result = try timeEncodeZstdDictionarySet(io, allocator, options, dictionary_set, first_dict, second_dict, use_dictionary_set, iterations);
    const decode_result = try timeDecodeZstdDictionarySetReusableAppendExact(io, allocator, &chunks, join, dictionary_set, use_dictionary_set, iterations);
    return makeRow(.zstd, mode, case, encoded.items.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn lz4DictionarySetDirectRow(
    io: std.Io,
    allocator: std.mem.Allocator,
    mode: Mode,
    use_dictionary_set: bool,
    iterations: usize,
) !Row {
    const first_dict = vort.Lz4NativeDictionary.init(0x4c5a_4501, lz4_dictionary_set_first_content);
    const second_dict = vort.Lz4NativeDictionary.init(0x4c5a_4502, lz4_dictionary_set_second_content);
    const dictionary_set = vort.Lz4NativeDictionarySet.init(&.{ first_dict, second_dict });
    const case: Case = .{ .name = "dictionary_set_direct", .payload = lz4_dictionary_set_payload };
    const options: vort.Lz4NativeFrameOptions = .{
        .content_checksum = false,
        .block_checksum = true,
    };

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try appendLz4DictionarySetFrames(allocator, &encoded, options, dictionary_set, first_dict, second_dict, use_dictionary_set);
    const decoded = try allocator.alloc(u8, lz4_dictionary_set_payload.len);
    defer allocator.free(decoded);
    try decodeLz4DictionarySetDirect(allocator, encoded.items, decoded, dictionary_set, use_dictionary_set);

    const encode_result = try timeEncodeLz4DictionarySet(io, allocator, options, dictionary_set, first_dict, second_dict, use_dictionary_set, iterations);
    const decode_result = try timeDecodeLz4DictionarySetDirect(io, allocator, encoded.items, decoded, dictionary_set, use_dictionary_set, iterations);
    return makeRow(.lz4, mode, case, encoded.items.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn zstdDictionarySetDirectRow(
    io: std.Io,
    allocator: std.mem.Allocator,
    mode: Mode,
    use_dictionary_set: bool,
    iterations: usize,
) !Row {
    const first_dict = vort.ZstdNativeDictionary.init(0x5a53_4501, zstd_dictionary_set_first_content);
    const second_dict = vort.ZstdNativeDictionary.init(0x5a53_4502, zstd_dictionary_set_second_content);
    const dictionary_set = vort.ZstdNativeDictionarySet.init(&.{ first_dict, second_dict });
    const case: Case = .{ .name = "dictionary_set_direct", .payload = zstd_dictionary_set_payload };
    const options: vort.ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try appendZstdDictionarySetFrames(allocator, &encoded, options, dictionary_set, first_dict, second_dict, use_dictionary_set);
    const decoded = try allocator.alloc(u8, zstd_dictionary_set_payload.len);
    defer allocator.free(decoded);
    try decodeZstdDictionarySetDirect(allocator, encoded.items, decoded, dictionary_set, use_dictionary_set);

    const encode_result = try timeEncodeZstdDictionarySet(io, allocator, options, dictionary_set, first_dict, second_dict, use_dictionary_set, iterations);
    const decode_result = try timeDecodeZstdDictionarySetDirect(io, allocator, encoded.items, decoded, dictionary_set, use_dictionary_set, iterations);
    return makeRow(.zstd, mode, case, encoded.items.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn lz4DictionarySetFallbackRow(
    io: std.Io,
    allocator: std.mem.Allocator,
    mode: Mode,
    use_dictionary_set: bool,
    iterations: usize,
) !Row {
    const first_dict = vort.Lz4NativeDictionary.init(0x4c5a_4501, lz4_dictionary_set_first_content);
    const second_dict = vort.Lz4NativeDictionary.init(0x4c5a_4502, lz4_dictionary_set_second_content);
    const dictionary_set = vort.Lz4NativeDictionarySet.init(&.{ first_dict, second_dict });
    const case: Case = .{ .name = "dictionary_set_fallback", .payload = lz4_dictionary_set_payload };
    const options: vort.Lz4NativeFrameOptions = .{
        .content_checksum = false,
        .block_checksum = true,
    };

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try appendLz4DictionarySetFrames(allocator, &encoded, options, dictionary_set, first_dict, second_dict, use_dictionary_set);
    const decoded = try allocator.alloc(u8, lz4_dictionary_set_payload.len);
    defer allocator.free(decoded);
    try decodeLz4DictionarySetFallback(allocator, encoded.items, decoded, dictionary_set, use_dictionary_set);

    const encode_result = try timeEncodeLz4DictionarySet(io, allocator, options, dictionary_set, first_dict, second_dict, use_dictionary_set, iterations);
    const decode_result = try timeDecodeLz4DictionarySetFallback(io, allocator, encoded.items, decoded, dictionary_set, use_dictionary_set, iterations);
    return makeRow(.lz4, mode, case, encoded.items.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn zstdDictionarySetFallbackRow(
    io: std.Io,
    allocator: std.mem.Allocator,
    mode: Mode,
    use_dictionary_set: bool,
    iterations: usize,
) !Row {
    const first_dict = vort.ZstdNativeDictionary.init(0x5a53_4501, zstd_dictionary_set_first_content);
    const second_dict = vort.ZstdNativeDictionary.init(0x5a53_4502, zstd_dictionary_set_second_content);
    const dictionary_set = vort.ZstdNativeDictionarySet.init(&.{ first_dict, second_dict });
    const case: Case = .{ .name = "dictionary_set_fallback", .payload = zstd_dictionary_set_payload };
    const options: vort.ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try appendZstdDictionarySetFrames(allocator, &encoded, options, dictionary_set, first_dict, second_dict, use_dictionary_set);
    const decoded = try allocator.alloc(u8, zstd_dictionary_set_payload.len);
    defer allocator.free(decoded);
    try decodeZstdDictionarySetFallback(allocator, encoded.items, decoded, dictionary_set, use_dictionary_set);

    const encode_result = try timeEncodeZstdDictionarySet(io, allocator, options, dictionary_set, first_dict, second_dict, use_dictionary_set, iterations);
    const decode_result = try timeDecodeZstdDictionarySetFallback(io, allocator, encoded.items, decoded, dictionary_set, use_dictionary_set, iterations);
    return makeRow(.zstd, mode, case, encoded.items.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

const TimeResult = struct { elapsed_ns: u64, checksum: u64 };

const lz4_chain_depth_payload = ("abcdefghijklmnopqrstuvwxyz012345" ** 4) ** 16;

const zstd_match_budget_payload =
    "bbeegfabcceeehaabcdfacefegahabdffgabcccfeggbcddffgah" ++
    "ccccfeggbcddffgahceegfabcceeehaabcdfacefegahabdffgab" ++
    "cccfeggbcddfechbcecececececece";

const zstd_high_byte_binary_payload = makeZstdHighByteBinaryPayload();
const zstd_sequence_huffman_dictionary_content = makeZstdSequenceHuffmanDictionaryContent();
const zstd_sequence_huffman_literals_payload = makeZstdSequenceHuffmanLiteralsPayload();

const lz4_dictionary_content = "abcdefghijklmnop";
const lz4_dictionary_payload = "prefix-abcdefghijklmnop-tail-abcdefghijklmnop";
const zstd_dictionary_content = "abcdefghijklmnop";
const zstd_dictionary_payload = "prefix-abcdefghijklmnop-tail-abcdefghijklmnop";
const lz4_dictionary_set_first_content = "abcdefghijklmnop";
const lz4_dictionary_set_second_content = "QRSTUVWXYZabcdef";
const lz4_dictionary_set_first_payload = "prefix-abcdefghijklmnop-set-one";
const lz4_dictionary_set_second_payload = "prefix-QRSTUVWXYZabcdef-set-two";
const lz4_dictionary_set_payload = lz4_dictionary_set_first_payload ++ lz4_dictionary_set_second_payload;
const zstd_dictionary_set_first_content = "abcdefghijklmnop";
const zstd_dictionary_set_second_content = "QRSTUVWXYZabcdef";
const zstd_dictionary_set_first_payload = "prefix-abcdefghijklmnop-set-one";
const zstd_dictionary_set_second_payload = "prefix-QRSTUVWXYZabcdef-set-two";
const zstd_dictionary_set_payload = zstd_dictionary_set_first_payload ++ zstd_dictionary_set_second_payload;

fn makeZstdHighByteBinaryPayload() [1024]u8 {
    @setEvalBranchQuota(4096);
    var payload: [1024]u8 = undefined;
    var state: u32 = 0xfeed_beef;
    for (&payload) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @intCast(129 + ((state >> 16) % 127));
    }
    return payload;
}

fn makeZstdSequenceHuffmanDictionaryContent() [64]u8 {
    @setEvalBranchQuota(1024);
    var dict: [64]u8 = undefined;
    var state: u32 = 0x9e37_79b9;
    for (&dict) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    return dict;
}

fn makeZstdSequenceHuffmanLiteralsPayload() [832]u8 {
    @setEvalBranchQuota(1024);
    var payload: [832]u8 = undefined;
    @memset(payload[0..192], 'A');
    @memset(payload[192..384], 'B');
    @memcpy(payload[384..448], &zstd_sequence_huffman_dictionary_content);
    @memset(payload[448..640], 'B');
    @memset(payload[640..832], 'A');
    return payload;
}

fn timeEncodeLz4(io: std.Io, allocator: std.mem.Allocator, payload: []const u8, options: vort.Lz4NativeFrameOptions, iterations: usize) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        const encoded = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, payload, options);
        checksum +%= encoded.len;
        allocator.free(encoded);
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeEncodeLz4Dictionary(
    io: std.Io,
    allocator: std.mem.Allocator,
    payload: []const u8,
    options: vort.Lz4NativeFrameOptions,
    dict: vort.Lz4NativeDictionary,
    use_dictionary: bool,
    iterations: usize,
) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        const encoded = if (use_dictionary)
            try vort.lz4EncodeNativeFrameWithDictionaryAlloc(allocator, payload, options, dict)
        else
            try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, payload, options);
        checksum +%= encoded.len;
        allocator.free(encoded);
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeEncodeZstd(io: std.Io, allocator: std.mem.Allocator, payload: []const u8, options: vort.ZstdNativeFrameOptions, iterations: usize) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        const encoded = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, payload, options);
        checksum +%= encoded.frame.len;
        allocator.free(encoded.frame);
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeEncodeZstdDictionary(
    io: std.Io,
    allocator: std.mem.Allocator,
    payload: []const u8,
    options: vort.ZstdNativeFrameOptions,
    dict: vort.ZstdNativeDictionary,
    use_dictionary: bool,
    iterations: usize,
) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        const encoded = if (use_dictionary)
            try vort.zstdEncodeNativeFrameWithDictionaryAlloc(allocator, payload, options, dict)
        else
            try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, payload, options);
        checksum +%= encoded.frame.len;
        allocator.free(encoded.frame);
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeEncodeLz4DictionarySet(
    io: std.Io,
    allocator: std.mem.Allocator,
    options: vort.Lz4NativeFrameOptions,
    dictionary_set: vort.Lz4NativeDictionarySet,
    first_dict: vort.Lz4NativeDictionary,
    second_dict: vort.Lz4NativeDictionary,
    use_dictionary_set: bool,
    iterations: usize,
) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        var encoded: std.ArrayList(u8) = .empty;
        defer encoded.deinit(allocator);
        try appendLz4DictionarySetFrames(allocator, &encoded, options, dictionary_set, first_dict, second_dict, use_dictionary_set);
        checksum +%= encoded.items.len;
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeEncodeZstdDictionarySet(
    io: std.Io,
    allocator: std.mem.Allocator,
    options: vort.ZstdNativeFrameOptions,
    dictionary_set: vort.ZstdNativeDictionarySet,
    first_dict: vort.ZstdNativeDictionary,
    second_dict: vort.ZstdNativeDictionary,
    use_dictionary_set: bool,
    iterations: usize,
) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        var encoded: std.ArrayList(u8) = .empty;
        defer encoded.deinit(allocator);
        try appendZstdDictionarySetFrames(allocator, &encoded, options, dictionary_set, first_dict, second_dict, use_dictionary_set);
        checksum +%= encoded.items.len;
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeDecodeLz4OneShot(io: std.Io, encoded: []const u8, decoded: []u8, expected: []const u8, iterations: usize) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        try expectRoundTrip(vort.lz4DecodeNativeFrameInto(encoded, decoded), expected, decoded);
        checksum +%= decoded[0];
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeDecodeLz4DictionaryOneShot(
    io: std.Io,
    encoded: []const u8,
    decoded: []u8,
    expected: []const u8,
    dict: vort.Lz4NativeDictionary,
    use_dictionary: bool,
    iterations: usize,
) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        if (use_dictionary) {
            try expectRoundTrip(vort.lz4DecodeNativeFrameIntoWithDictionary(encoded, decoded, dict), expected, decoded);
        } else {
            try expectRoundTrip(vort.lz4DecodeNativeFrameInto(encoded, decoded), expected, decoded);
        }
        checksum +%= decoded[0];
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeDecodeZstdOneShot(io: std.Io, encoded: []const u8, decoded: []u8, expected: []const u8, iterations: usize) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        try expectRoundTrip(vort.zstdDecodeNativeFrameInto(encoded, decoded), expected, decoded);
        checksum +%= decoded[0];
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeDecodeZstdDictionaryOneShot(
    io: std.Io,
    encoded: []const u8,
    decoded: []u8,
    expected: []const u8,
    dict: vort.ZstdNativeDictionary,
    use_dictionary: bool,
    iterations: usize,
) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        if (use_dictionary) {
            try expectRoundTrip(vort.zstdDecodeNativeFrameIntoWithDictionary(encoded, decoded, dict), expected, decoded);
        } else {
            try expectRoundTrip(vort.zstdDecodeNativeFrameInto(encoded, decoded), expected, decoded);
        }
        checksum +%= decoded[0];
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeDecodeLz4DictionarySetOneShot(
    io: std.Io,
    encoded: []const u8,
    decoded: []u8,
    dictionary_set: vort.Lz4NativeDictionarySet,
    use_dictionary_set: bool,
    iterations: usize,
) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        if (use_dictionary_set) {
            try expectRoundTrip(vort.lz4DecodeNativeConcatenatedFrameIntoWithDictionarySet(encoded, decoded, dictionary_set), lz4_dictionary_set_payload, decoded);
        } else {
            try expectRoundTrip(vort.lz4DecodeNativeConcatenatedFrameInto(encoded, decoded), lz4_dictionary_set_payload, decoded);
        }
        checksum +%= decoded[0];
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeDecodeZstdDictionarySetOneShot(
    io: std.Io,
    encoded: []const u8,
    decoded: []u8,
    dictionary_set: vort.ZstdNativeDictionarySet,
    use_dictionary_set: bool,
    iterations: usize,
) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        if (use_dictionary_set) {
            try expectRoundTrip(vort.zstdDecodeNativeConcatenatedFrameIntoWithDictionarySet(encoded, decoded, dictionary_set), zstd_dictionary_set_payload, decoded);
        } else {
            try expectRoundTrip(vort.zstdDecodeNativeConcatenatedFrameInto(encoded, decoded), zstd_dictionary_set_payload, decoded);
        }
        checksum +%= decoded[0];
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeDecodeLz4DictionarySetChunked(
    io: std.Io,
    chunks: []const []const u8,
    join: []u8,
    decoded: []u8,
    dictionary_set: vort.Lz4NativeDictionarySet,
    use_dictionary_set: bool,
    iterations: usize,
) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        if (use_dictionary_set) {
            try expectRoundTrip(vort.lz4DecodeNativeConcatenatedFrameChunksIntoWithDictionarySet(chunks, join, decoded, dictionary_set), lz4_dictionary_set_payload, decoded);
        } else {
            try expectRoundTrip(vort.lz4DecodeNativeConcatenatedFrameChunksInto(chunks, join, decoded), lz4_dictionary_set_payload, decoded);
        }
        checksum +%= decoded[0];
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeDecodeZstdDictionarySetChunked(
    io: std.Io,
    chunks: []const []const u8,
    join: []u8,
    decoded: []u8,
    dictionary_set: vort.ZstdNativeDictionarySet,
    use_dictionary_set: bool,
    iterations: usize,
) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        if (use_dictionary_set) {
            try expectRoundTrip(vort.zstdDecodeNativeConcatenatedFrameChunksIntoWithDictionarySet(chunks, join, decoded, dictionary_set), zstd_dictionary_set_payload, decoded);
        } else {
            try expectRoundTrip(vort.zstdDecodeNativeConcatenatedFrameChunksInto(chunks, join, decoded), zstd_dictionary_set_payload, decoded);
        }
        checksum +%= decoded[0];
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeDecodeLz4DictionarySetChunkedAppend(
    io: std.Io,
    allocator: std.mem.Allocator,
    chunks: []const []const u8,
    join: []u8,
    dictionary_set: vort.Lz4NativeDictionarySet,
    use_dictionary_set: bool,
    exact_size: bool,
    iterations: usize,
) !TimeResult {
    var checksum: u64 = 0;
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        try verifyLz4DictionarySetChunkedAppendInto(allocator, &out, chunks, join, dictionary_set, use_dictionary_set, exact_size);
        checksum +%= out.items["prefix:".len];
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeDecodeZstdDictionarySetChunkedAppend(
    io: std.Io,
    allocator: std.mem.Allocator,
    chunks: []const []const u8,
    join: []u8,
    dictionary_set: vort.ZstdNativeDictionarySet,
    use_dictionary_set: bool,
    exact_size: bool,
    iterations: usize,
) !TimeResult {
    var checksum: u64 = 0;
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        try verifyZstdDictionarySetChunkedAppendInto(allocator, &out, chunks, join, dictionary_set, use_dictionary_set, exact_size);
        checksum +%= out.items["prefix:".len];
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeDecodeLz4DictionarySetReusableChunked(
    io: std.Io,
    allocator: std.mem.Allocator,
    chunks: []const []const u8,
    join: []u8,
    decoded: []u8,
    dictionary_set: vort.Lz4NativeDictionarySet,
    use_dictionary_set: bool,
    iterations: usize,
) !TimeResult {
    var checksum: u64 = 0;
    var decoder = vort.Lz4NativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        if (use_dictionary_set) {
            try expectRoundTrip(decoder.decodeConcatenatedChunksIntoSliceWithDictionarySet(chunks, join, decoded, dictionary_set), lz4_dictionary_set_payload, decoded);
        } else {
            try expectRoundTrip(decoder.decodeConcatenatedChunksIntoSlice(chunks, join, decoded), lz4_dictionary_set_payload, decoded);
        }
        checksum +%= decoded[0];
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeDecodeZstdDictionarySetReusableChunked(
    io: std.Io,
    allocator: std.mem.Allocator,
    chunks: []const []const u8,
    join: []u8,
    decoded: []u8,
    dictionary_set: vort.ZstdNativeDictionarySet,
    use_dictionary_set: bool,
    iterations: usize,
) !TimeResult {
    var checksum: u64 = 0;
    var decoder = vort.ZstdNativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        if (use_dictionary_set) {
            try expectRoundTrip(decoder.decodeConcatenatedChunksIntoSliceWithDictionarySet(chunks, join, decoded, dictionary_set), zstd_dictionary_set_payload, decoded);
        } else {
            try expectRoundTrip(decoder.decodeConcatenatedChunksIntoSlice(chunks, join, decoded), zstd_dictionary_set_payload, decoded);
        }
        checksum +%= decoded[0];
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeDecodeLz4DictionarySetReusableAppendExact(
    io: std.Io,
    allocator: std.mem.Allocator,
    chunks: []const []const u8,
    join: []u8,
    dictionary_set: vort.Lz4NativeDictionarySet,
    use_dictionary_set: bool,
    iterations: usize,
) !TimeResult {
    var checksum: u64 = 0;
    var decoder = vort.Lz4NativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        try verifyLz4ReusableAppendExactInto(&decoder, &out, chunks, join, dictionary_set, use_dictionary_set);
        checksum +%= out.items["prefix:".len];
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeDecodeZstdDictionarySetReusableAppendExact(
    io: std.Io,
    allocator: std.mem.Allocator,
    chunks: []const []const u8,
    join: []u8,
    dictionary_set: vort.ZstdNativeDictionarySet,
    use_dictionary_set: bool,
    iterations: usize,
) !TimeResult {
    var checksum: u64 = 0;
    var decoder = vort.ZstdNativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        try verifyZstdReusableAppendExactInto(&decoder, &out, chunks, join, dictionary_set, use_dictionary_set);
        checksum +%= out.items["prefix:".len];
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeDecodeLz4DictionarySetDirect(
    io: std.Io,
    allocator: std.mem.Allocator,
    encoded: []const u8,
    decoded: []u8,
    dictionary_set: vort.Lz4NativeDictionarySet,
    use_dictionary_set: bool,
    iterations: usize,
) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        try decodeLz4DictionarySetDirect(allocator, encoded, decoded, dictionary_set, use_dictionary_set);
        checksum +%= decoded[0];
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeDecodeZstdDictionarySetDirect(
    io: std.Io,
    allocator: std.mem.Allocator,
    encoded: []const u8,
    decoded: []u8,
    dictionary_set: vort.ZstdNativeDictionarySet,
    use_dictionary_set: bool,
    iterations: usize,
) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        try decodeZstdDictionarySetDirect(allocator, encoded, decoded, dictionary_set, use_dictionary_set);
        checksum +%= decoded[0];
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeDecodeLz4DictionarySetFallback(
    io: std.Io,
    allocator: std.mem.Allocator,
    encoded: []const u8,
    decoded: []u8,
    dictionary_set: vort.Lz4NativeDictionarySet,
    use_dictionary_set: bool,
    iterations: usize,
) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        try decodeLz4DictionarySetFallback(allocator, encoded, decoded, dictionary_set, use_dictionary_set);
        checksum +%= decoded[0];
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeDecodeZstdDictionarySetFallback(
    io: std.Io,
    allocator: std.mem.Allocator,
    encoded: []const u8,
    decoded: []u8,
    dictionary_set: vort.ZstdNativeDictionarySet,
    use_dictionary_set: bool,
    iterations: usize,
) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        try decodeZstdDictionarySetFallback(allocator, encoded, decoded, dictionary_set, use_dictionary_set);
        checksum +%= decoded[0];
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeDecodeLz4Incremental(io: std.Io, allocator: std.mem.Allocator, encoded: []const u8, decoded: []u8, expected: []const u8, iterations: usize) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        try decodeLz4Incremental(allocator, encoded, decoded);
        if (!std.mem.eql(u8, expected, decoded)) return error.SizeMismatch;
        checksum +%= decoded[0];
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeDecodeZstdIncremental(io: std.Io, allocator: std.mem.Allocator, encoded: []const u8, decoded: []u8, expected: []const u8, iterations: usize) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        try decodeZstdIncremental(allocator, encoded, decoded);
        if (!std.mem.eql(u8, expected, decoded)) return error.SizeMismatch;
        checksum +%= decoded[0];
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeDecodeLz4IncrementalDirect(io: std.Io, allocator: std.mem.Allocator, encoded: []const u8, decoded: []u8, expected: []const u8, iterations: usize) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        try decodeLz4IncrementalDirect(allocator, encoded, decoded);
        if (!std.mem.eql(u8, expected, decoded)) return error.SizeMismatch;
        checksum +%= decoded[0];
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeDecodeZstdIncrementalDirect(io: std.Io, allocator: std.mem.Allocator, encoded: []const u8, decoded: []u8, expected: []const u8, iterations: usize) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        try decodeZstdIncrementalDirect(allocator, encoded, decoded);
        if (!std.mem.eql(u8, expected, decoded)) return error.SizeMismatch;
        checksum +%= decoded[0];
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeDecodeLz4IncrementalFallback(io: std.Io, allocator: std.mem.Allocator, encoded: []const u8, decoded: []u8, expected: []const u8, iterations: usize) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        try decodeLz4IncrementalFallback(allocator, encoded, decoded, expected);
        checksum +%= decoded[0];
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeDecodeZstdIncrementalFallback(io: std.Io, allocator: std.mem.Allocator, encoded: []const u8, decoded: []u8, expected: []const u8, iterations: usize) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        try decodeZstdIncrementalFallback(allocator, encoded, decoded, expected);
        checksum +%= decoded[0];
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn smokeLz4LinkedDirectFallback(allocator: std.mem.Allocator) !void {
    var payload: [64 * 1024 + 4096]u8 = undefined;
    var state: u32 = 0x1234_abcd;
    for (payload[0 .. 64 * 1024]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(payload[64 * 1024 ..], payload[60 * 1024 .. 64 * 1024]);
    const encoded = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, &payload, .{
        .content_checksum = false,
        .block_checksum = true,
        .block_mode = .linked,
        .block_size_id = .max64kb,
    });
    defer allocator.free(encoded);

    var decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    var decoded: [payload.len]u8 = undefined;
    const initial = try decoder.step(encoded, decoded[0..0]);
    if (initial.status != .need_output) return error.SizeMismatch;
    if (!std.mem.eql(u8, decoder.diagnostics().phase_name, "direct_output")) return error.SizeMismatch;
    const first = try decoder.step("", decoded[0 .. 64 * 1024]);
    if (first.status != .need_output or first.progress.output_written != 64 * 1024) return error.SizeMismatch;
    if (decoder.decoded_scratch.items.len != 0) return error.SizeMismatch;
    const partial = try decoder.step("", decoded[64 * 1024 ..][0..127]);
    if (partial.status != .need_output or partial.progress.output_written != 127) return error.SizeMismatch;
    if (decoder.decoded_scratch.items.len != payload.len) return error.SizeMismatch;
    const done = try decoder.step("", decoded[64 * 1024 + 127 ..]);
    if (done.status != .done) return error.SizeMismatch;
    if (!std.mem.eql(u8, &payload, &decoded)) return error.SizeMismatch;
}

fn smokeLz4DeepHashChain(allocator: std.mem.Allocator) !void {
    var payload: [160]u8 = undefined;
    @memset(&payload, 'z');
    const long = "AAAABCDEFGHIJKLMNOP";
    const target_start = 120;
    @memcpy(payload[0..long.len], long);
    @memcpy(payload[target_start..][0..long.len], long);
    for (0..12) |i| {
        const pos = 24 + i * 6;
        @memcpy(payload[pos..][0..4], "AAAA");
        payload[pos + 4] = @intCast('a' + i);
    }

    const encoded = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, &payload, .{
        .content_checksum = false,
        .block_checksum = true,
    });
    defer allocator.free(encoded);
    const first_block = (try vort.lz4InspectNativeFrameFirstBlock(encoded)) orelse return error.SizeMismatch;
    if (!first_block.is_compressed) return error.SizeMismatch;
    if (encoded.len >= try vort.lz4EncodedNativeFrameBound(payload.len)) return error.SizeMismatch;

    var decoder = vort.Lz4NativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    const decoded = try decoder.decodeScratch(encoded);
    if (!std.mem.eql(u8, &payload, decoded)) return error.SizeMismatch;
}

fn smokeLz4LinkedDeepHashChain(allocator: std.mem.Allocator) !void {
    var long: [512]u8 = undefined;
    @memcpy(long[0..4], "AAAA");
    for (long[4..], 0..) |*byte, i| byte.* = @intCast('A' + (i % 23));

    const payload = try allocator.alloc(u8, 64 * 1024 + long.len);
    defer allocator.free(payload);
    @memset(payload, 'z');
    @memcpy(payload[0..long.len], &long);
    for (0..12) |i| {
        const pos = 1024 + i * 6;
        @memcpy(payload[pos..][0..4], "AAAA");
        payload[pos + 4] = @intCast('a' + i);
    }
    @memcpy(payload[64 * 1024 ..][0..long.len], &long);

    const encoded = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, payload, .{
        .content_checksum = false,
        .block_checksum = true,
        .block_mode = .linked,
        .block_size_id = .max64kb,
    });
    defer allocator.free(encoded);
    const first_block = (try vort.lz4InspectNativeFrameFirstBlock(encoded)) orelse return error.SizeMismatch;
    const second_block = (try vort.lz4InspectNativeFrameBlockAt(encoded, first_block.next_header_offset)) orelse return error.SizeMismatch;
    if (!second_block.is_compressed) return error.SizeMismatch;

    var decoder = vort.Lz4NativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    const decoded = try decoder.decodeScratch(encoded);
    if (!std.mem.eql(u8, payload, decoded)) return error.SizeMismatch;
}

fn smokeLz4ChainDepthBudget(allocator: std.mem.Allocator) !void {
    const depth0 = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, lz4_chain_depth_payload, .{
        .content_checksum = false,
        .block_checksum = true,
        .chain_depth = 0,
    });
    defer allocator.free(depth0);
    const default_depth = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, lz4_chain_depth_payload, .{
        .content_checksum = false,
        .block_checksum = true,
        .chain_depth = vort.lz4NativeMaxChainDepth,
    });
    defer allocator.free(default_depth);

    if (default_depth.len >= depth0.len) return error.SizeMismatch;
    var decoded: [lz4_chain_depth_payload.len]u8 = undefined;
    try expectRoundTrip(vort.lz4DecodeNativeFrameInto(depth0, &decoded), lz4_chain_depth_payload, &decoded);
    try expectRoundTrip(vort.lz4DecodeNativeFrameInto(default_depth, &decoded), lz4_chain_depth_payload, &decoded);
}

fn smokeZstdMultiblockDirectFallback(allocator: std.mem.Allocator) !void {
    const payload = "a" ** 264;
    const encoded = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, payload, .{
        .selection = .literal_only,
        .content_checksum = true,
        .block_size_max = payload.len / 2,
    });
    defer allocator.free(encoded.frame);

    var decoder = vort.ZstdNativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    var decoded: [payload.len]u8 = undefined;
    const first = try decoder.step(encoded.frame, decoded[0..0]);
    if (first.status != .need_output) return error.SizeMismatch;
    if (!std.mem.eql(u8, decoder.diagnostics().phase_name, "direct_output")) return error.SizeMismatch;
    const partial = try decoder.step("", decoded[0..17]);
    if (partial.status != .need_output or partial.progress.output_written != 17) return error.SizeMismatch;
    if (decoder.decoded_scratch.items.len != payload.len) return error.SizeMismatch;
    const done = try decoder.step("", decoded[17..]);
    if (done.status != .done) return error.SizeMismatch;
    if (!std.mem.eql(u8, payload, &decoded)) return error.SizeMismatch;
}

fn smokeReusableChunkedDecoders(allocator: std.mem.Allocator) !void {
    const lz4_payload = "bench-lz4-chunked-reusable";
    const lz4_encoded = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, lz4_payload, .{
        .content_checksum = false,
        .block_checksum = true,
    });
    defer allocator.free(lz4_encoded);
    const lz4_chunks = [_][]const u8{
        lz4_encoded[0..5],
        lz4_encoded[5..],
    };
    const lz4_join = try allocator.alloc(u8, lz4_encoded.len);
    defer allocator.free(lz4_join);
    var lz4_decoder = vort.Lz4NativeFrameDecoder.init(allocator);
    defer lz4_decoder.deinit();
    const lz4_exact = try lz4_decoder.decodeConcatenatedChunksAllocExactSize(&lz4_chunks, lz4_join, lz4_payload.len);
    defer allocator.free(lz4_exact);
    if (!std.mem.eql(u8, lz4_payload, lz4_exact)) return error.SizeMismatch;
    const lz4_size = try lz4_decoder.decodedConcatenatedChunksSize(&lz4_chunks, lz4_join);
    if (lz4_size != lz4_payload.len) return error.SizeMismatch;

    const zstd_payload = "bench-zstd-chunked-reusable";
    const zstd_encoded = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, zstd_payload, .{
        .selection = .literal_only,
        .content_checksum = false,
    });
    defer allocator.free(zstd_encoded.frame);
    const zstd_chunks = [_][]const u8{
        zstd_encoded.frame[0..7],
        zstd_encoded.frame[7..],
    };
    const zstd_join = try allocator.alloc(u8, zstd_encoded.frame.len);
    defer allocator.free(zstd_join);
    var zstd_decoder = vort.ZstdNativeFrameDecoder.init(allocator);
    defer zstd_decoder.deinit();
    const zstd_exact = try zstd_decoder.decodeConcatenatedChunksAllocExactSize(&zstd_chunks, zstd_join, zstd_payload.len);
    defer allocator.free(zstd_exact);
    if (!std.mem.eql(u8, zstd_payload, zstd_exact)) return error.SizeMismatch;
    const zstd_size = try zstd_decoder.decodedConcatenatedChunksSize(&zstd_chunks, zstd_join);
    if (zstd_size != zstd_payload.len) return error.SizeMismatch;
}

fn smokeZstdManyRepeatedSequences(allocator: std.mem.Allocator) !void {
    const patterns = [_][]const u8{
        "ab", "cd", "ef", "gh", "ij", "kl", "mn", "op", "qr", "st",
        "uv", "wx", "yz", "AB", "CD", "EF", "GH", "IJ", "KL", "MN",
    };
    var payload: std.ArrayList(u8) = .empty;
    defer payload.deinit(allocator);
    for (patterns) |pattern| {
        for (0..12) |_| try payload.appendSlice(allocator, pattern);
    }

    const encoded = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, payload.items, .{
        .selection = .literal_only,
        .content_checksum = false,
    });
    defer allocator.free(encoded.frame);
    const first_block = try vort.zstdInspectNativeFrameFirstBlock(encoded.frame);
    if (first_block.block_type != .compressed) return error.SizeMismatch;
    const summary = try vort.zstdSummarizeNativeFrameBlocks(encoded.frame);
    if (summary.compressed_block_count != 1) return error.SizeMismatch;

    var decoder = vort.ZstdNativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    const decoded = try decoder.decodeScratch(encoded.frame);
    if (!std.mem.eql(u8, payload.items, decoded)) return error.SizeMismatch;
    const decoded_len = try decoder.decodedSize(encoded.frame);
    if (decoded_len != payload.items.len) return error.SizeMismatch;
}

fn smokeZstdSequenceInspectFixtures(allocator: std.mem.Allocator) !void {
    const frame_hex =
        "28b52ffd20a2240100606162636465666768696a6b6c10180210aeb5070b83c3c2c360e030701878383c1cec922d00000001fc3b20";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    const first_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, first_block);
    if (first_modes.literal_length_mode != .predefined or
        first_modes.offset_mode != .rle or
        first_modes.match_length_mode != .compressed) return error.SizeMismatch;

    const second_block = try vort.zstdInspectNativeFrameBlockAt(&frame, first_block.next_header_offset);
    const second_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, second_block);
    if (second_modes.literal_length_mode != .repeat or
        second_modes.offset_mode != .repeat or
        second_modes.match_length_mode != .repeat) return error.SizeMismatch;

    const decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(decoded);
    if (decoded.len != 162) return error.SizeMismatch;

    const bad_hex = "28b52ffd209a250100606162636465666768696a6b6c10180210aeb5070b83c3c2c360e030701878383c1cec92";
    var bad: [bad_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&bad, bad_hex);
    bad[25] ^= 0xff;
    const bad_block = try vort.zstdInspectNativeFrameFirstBlock(&bad);
    if (vort.zstdInspectNativeFrameBlockSequenceModes(&bad, bad_block)) |_| {
        return error.SizeMismatch;
    } else |err| switch (err) {
        error.CorruptFrame => {},
        else => return err,
    }
}

fn smokeZstdNoSizeMultiCompressed(allocator: std.mem.Allocator) !void {
    const block_len = 1024;
    const payload = try allocator.alloc(u8, block_len * 2);
    defer allocator.free(payload);
    @memset(payload[0..block_len], 'a');
    @memset(payload[block_len..], 'b');

    const encoded = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, payload, .{
        .selection = .literal_only,
        .content_checksum = false,
        .include_content_size = false,
        .block_size_max = block_len,
    });
    defer allocator.free(encoded.frame);

    const header = try vort.zstdInspectNativeFrameHeader(encoded.frame);
    if (header.content_size != null) return error.SizeMismatch;
    const summary = try vort.zstdSummarizeNativeStream(encoded.frame);
    if (summary.frame_count != 1 or summary.block_count != 2 or summary.compressed_block_count != 2) {
        return error.SizeMismatch;
    }
    if (try vort.zstdDecodedNativeFrameSizeLimited(encoded.frame, payload.len) != payload.len) return error.SizeMismatch;
    if (vort.zstdDecodedNativeFrameSizeLimited(encoded.frame, payload.len - 1)) |_| {
        return error.SizeMismatch;
    } else |err| switch (err) {
        error.OutputLimitExceeded => {},
        else => return err,
    }

    const decoded = try vort.zstdDecodeNativeFrameAllocLimited(allocator, encoded.frame, payload.len);
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, payload, decoded)) return error.SizeMismatch;

    const checksummed = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, payload, .{
        .selection = .literal_only,
        .content_checksum = true,
        .include_content_size = false,
        .block_size_max = block_len,
    });
    defer allocator.free(checksummed.frame);
    const checksummed_summary = try vort.zstdSummarizeNativeStream(checksummed.frame);
    if (checksummed_summary.frame_count != 1 or checksummed_summary.block_count != 2 or checksummed_summary.compressed_block_count != 2) {
        return error.SizeMismatch;
    }

    var bad_checksum = try allocator.dupe(u8, checksummed.frame);
    defer allocator.free(bad_checksum);
    bad_checksum[bad_checksum.len - 1] ^= 0x01;
    if (try vort.zstdDecodedNativeFrameSizeLimited(bad_checksum, payload.len) != payload.len) return error.SizeMismatch;
    if (vort.zstdDecodeNativeFrameAllocLimited(allocator, bad_checksum, payload.len)) |bad_decoded| {
        allocator.free(bad_decoded);
        return error.SizeMismatch;
    } else |err| switch (err) {
        error.ChecksumMismatch => {},
        else => return err,
    }
    if (vort.zstdDecodeNativeFrameAllocLimited(allocator, bad_checksum, payload.len - 1)) |bad_decoded| {
        allocator.free(bad_decoded);
        return error.SizeMismatch;
    } else |err| switch (err) {
        error.OutputLimitExceeded => {},
        else => return err,
    }

    const truncated_checksum = checksummed.frame[0 .. checksummed.frame.len - 2];
    if (vort.zstdDecodedNativeFrameSizeLimited(truncated_checksum, payload.len)) |_| {
        return error.SizeMismatch;
    } else |err| switch (err) {
        error.TruncatedFrame => {},
        else => return err,
    }
    if (vort.zstdDecodedNativeFrameSizeLimited(truncated_checksum, payload.len - 1)) |_| {
        return error.SizeMismatch;
    } else |err| switch (err) {
        error.OutputLimitExceeded => {},
        else => return err,
    }
}

fn smokeZstdMatchSearchBudget(allocator: std.mem.Allocator) !void {
    const budget0 = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, zstd_match_budget_payload, .{
        .selection = .literal_only,
        .content_checksum = false,
        .match_search_budget = 0,
    });
    defer allocator.free(budget0.frame);
    const full = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, zstd_match_budget_payload, .{
        .selection = .literal_only,
        .content_checksum = false,
        .match_search_budget = vort.zstdNativeMaxMatchSearchBudget,
    });
    defer allocator.free(full.frame);

    if (full.frame.len >= budget0.frame.len) return error.SizeMismatch;
    var decoded: [zstd_match_budget_payload.len]u8 = undefined;
    try expectRoundTrip(vort.zstdDecodeNativeFrameInto(budget0.frame, &decoded), zstd_match_budget_payload, &decoded);
    try expectRoundTrip(vort.zstdDecodeNativeFrameInto(full.frame, &decoded), zstd_match_budget_payload, &decoded);
}

fn smokeNativeDictionaryBenchRows(allocator: std.mem.Allocator) !void {
    const lz4_dict = vort.Lz4NativeDictionary.init(0x4c5a_4401, lz4_dictionary_content);
    const lz4_options: vort.Lz4NativeFrameOptions = .{
        .content_checksum = false,
        .block_checksum = true,
    };
    const lz4_plain = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, lz4_dictionary_payload, lz4_options);
    defer allocator.free(lz4_plain);
    const lz4_dict_frame = try vort.lz4EncodeNativeFrameWithDictionaryAlloc(allocator, lz4_dictionary_payload, lz4_options, lz4_dict);
    defer allocator.free(lz4_dict_frame);
    if (lz4_dict_frame.len >= lz4_plain.len) return error.SizeMismatch;
    var lz4_out: [lz4_dictionary_payload.len]u8 = undefined;
    try expectRoundTrip(vort.lz4DecodeNativeFrameInto(lz4_plain, &lz4_out), lz4_dictionary_payload, &lz4_out);
    try expectRoundTrip(vort.lz4DecodeNativeFrameIntoWithDictionary(lz4_dict_frame, &lz4_out, lz4_dict), lz4_dictionary_payload, &lz4_out);

    const zstd_dict = vort.ZstdNativeDictionary.init(0x5a53_4401, zstd_dictionary_content);
    const zstd_options: vort.ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };
    const zstd_plain = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, zstd_dictionary_payload, zstd_options);
    defer allocator.free(zstd_plain.frame);
    const zstd_dict_frame = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(allocator, zstd_dictionary_payload, zstd_options, zstd_dict);
    defer allocator.free(zstd_dict_frame.frame);
    if (zstd_dict_frame.frame.len >= zstd_plain.frame.len) return error.SizeMismatch;
    var zstd_out: [zstd_dictionary_payload.len]u8 = undefined;
    try expectRoundTrip(vort.zstdDecodeNativeFrameInto(zstd_plain.frame, &zstd_out), zstd_dictionary_payload, &zstd_out);
    try expectRoundTrip(vort.zstdDecodeNativeFrameIntoWithDictionary(zstd_dict_frame.frame, &zstd_out, zstd_dict), zstd_dictionary_payload, &zstd_out);
}

fn smokeNativeDictionarySetBenchRows(allocator: std.mem.Allocator) !void {
    const lz4_first_dict = vort.Lz4NativeDictionary.init(0x4c5a_4501, lz4_dictionary_set_first_content);
    const lz4_second_dict = vort.Lz4NativeDictionary.init(0x4c5a_4502, lz4_dictionary_set_second_content);
    const lz4_dictionary_set = vort.Lz4NativeDictionarySet.init(&.{ lz4_first_dict, lz4_second_dict });
    const lz4_options: vort.Lz4NativeFrameOptions = .{
        .content_checksum = false,
        .block_checksum = true,
    };
    var lz4_plain: std.ArrayList(u8) = .empty;
    defer lz4_plain.deinit(allocator);
    try appendLz4DictionarySetFrames(allocator, &lz4_plain, lz4_options, lz4_dictionary_set, lz4_first_dict, lz4_second_dict, false);
    var lz4_set_stream: std.ArrayList(u8) = .empty;
    defer lz4_set_stream.deinit(allocator);
    try appendLz4DictionarySetFrames(allocator, &lz4_set_stream, lz4_options, lz4_dictionary_set, lz4_first_dict, lz4_second_dict, true);
    if (lz4_set_stream.items.len >= lz4_plain.items.len) return error.SizeMismatch;
    var lz4_out: [lz4_dictionary_set_payload.len]u8 = undefined;
    try expectRoundTrip(vort.lz4DecodeNativeConcatenatedFrameInto(lz4_plain.items, &lz4_out), lz4_dictionary_set_payload, &lz4_out);
    try expectRoundTrip(vort.lz4DecodeNativeConcatenatedFrameIntoWithDictionarySet(lz4_set_stream.items, &lz4_out, lz4_dictionary_set), lz4_dictionary_set_payload, &lz4_out);

    const zstd_first_dict = vort.ZstdNativeDictionary.init(0x5a53_4501, zstd_dictionary_set_first_content);
    const zstd_second_dict = vort.ZstdNativeDictionary.init(0x5a53_4502, zstd_dictionary_set_second_content);
    const zstd_dictionary_set = vort.ZstdNativeDictionarySet.init(&.{ zstd_first_dict, zstd_second_dict });
    const zstd_options: vort.ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };
    var zstd_plain: std.ArrayList(u8) = .empty;
    defer zstd_plain.deinit(allocator);
    try appendZstdDictionarySetFrames(allocator, &zstd_plain, zstd_options, zstd_dictionary_set, zstd_first_dict, zstd_second_dict, false);
    var zstd_set_stream: std.ArrayList(u8) = .empty;
    defer zstd_set_stream.deinit(allocator);
    try appendZstdDictionarySetFrames(allocator, &zstd_set_stream, zstd_options, zstd_dictionary_set, zstd_first_dict, zstd_second_dict, true);
    if (zstd_set_stream.items.len >= zstd_plain.items.len) return error.SizeMismatch;
    var zstd_out: [zstd_dictionary_set_payload.len]u8 = undefined;
    try expectRoundTrip(vort.zstdDecodeNativeConcatenatedFrameInto(zstd_plain.items, &zstd_out), zstd_dictionary_set_payload, &zstd_out);
    try expectRoundTrip(vort.zstdDecodeNativeConcatenatedFrameIntoWithDictionarySet(zstd_set_stream.items, &zstd_out, zstd_dictionary_set), zstd_dictionary_set_payload, &zstd_out);
}

fn smokeNativeDictionarySetChunkedBenchRows(allocator: std.mem.Allocator) !void {
    const lz4_first_dict = vort.Lz4NativeDictionary.init(0x4c5a_4501, lz4_dictionary_set_first_content);
    const lz4_second_dict = vort.Lz4NativeDictionary.init(0x4c5a_4502, lz4_dictionary_set_second_content);
    const lz4_dictionary_set = vort.Lz4NativeDictionarySet.init(&.{ lz4_first_dict, lz4_second_dict });
    const lz4_options: vort.Lz4NativeFrameOptions = .{
        .content_checksum = false,
        .block_checksum = true,
    };
    var lz4_plain: std.ArrayList(u8) = .empty;
    defer lz4_plain.deinit(allocator);
    try appendLz4DictionarySetFrames(allocator, &lz4_plain, lz4_options, lz4_dictionary_set, lz4_first_dict, lz4_second_dict, false);
    var lz4_set_stream: std.ArrayList(u8) = .empty;
    defer lz4_set_stream.deinit(allocator);
    try appendLz4DictionarySetFrames(allocator, &lz4_set_stream, lz4_options, lz4_dictionary_set, lz4_first_dict, lz4_second_dict, true);
    const lz4_plain_chunks = dictionarySetChunks(lz4_plain.items);
    const lz4_set_chunks = dictionarySetChunks(lz4_set_stream.items);
    const lz4_plain_join = try allocator.alloc(u8, lz4_plain.items.len);
    defer allocator.free(lz4_plain_join);
    const lz4_set_join = try allocator.alloc(u8, lz4_set_stream.items.len);
    defer allocator.free(lz4_set_join);
    var lz4_out: [lz4_dictionary_set_payload.len]u8 = undefined;
    try expectRoundTrip(vort.lz4DecodeNativeConcatenatedFrameChunksInto(&lz4_plain_chunks, lz4_plain_join, &lz4_out), lz4_dictionary_set_payload, &lz4_out);
    try expectRoundTrip(vort.lz4DecodeNativeConcatenatedFrameChunksIntoWithDictionarySet(&lz4_set_chunks, lz4_set_join, &lz4_out, lz4_dictionary_set), lz4_dictionary_set_payload, &lz4_out);

    const zstd_first_dict = vort.ZstdNativeDictionary.init(0x5a53_4501, zstd_dictionary_set_first_content);
    const zstd_second_dict = vort.ZstdNativeDictionary.init(0x5a53_4502, zstd_dictionary_set_second_content);
    const zstd_dictionary_set = vort.ZstdNativeDictionarySet.init(&.{ zstd_first_dict, zstd_second_dict });
    const zstd_options: vort.ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };
    var zstd_plain: std.ArrayList(u8) = .empty;
    defer zstd_plain.deinit(allocator);
    try appendZstdDictionarySetFrames(allocator, &zstd_plain, zstd_options, zstd_dictionary_set, zstd_first_dict, zstd_second_dict, false);
    var zstd_set_stream: std.ArrayList(u8) = .empty;
    defer zstd_set_stream.deinit(allocator);
    try appendZstdDictionarySetFrames(allocator, &zstd_set_stream, zstd_options, zstd_dictionary_set, zstd_first_dict, zstd_second_dict, true);
    const zstd_plain_chunks = dictionarySetChunks(zstd_plain.items);
    const zstd_set_chunks = dictionarySetChunks(zstd_set_stream.items);
    const zstd_plain_join = try allocator.alloc(u8, zstd_plain.items.len);
    defer allocator.free(zstd_plain_join);
    const zstd_set_join = try allocator.alloc(u8, zstd_set_stream.items.len);
    defer allocator.free(zstd_set_join);
    var zstd_out: [zstd_dictionary_set_payload.len]u8 = undefined;
    try expectRoundTrip(vort.zstdDecodeNativeConcatenatedFrameChunksInto(&zstd_plain_chunks, zstd_plain_join, &zstd_out), zstd_dictionary_set_payload, &zstd_out);
    try expectRoundTrip(vort.zstdDecodeNativeConcatenatedFrameChunksIntoWithDictionarySet(&zstd_set_chunks, zstd_set_join, &zstd_out, zstd_dictionary_set), zstd_dictionary_set_payload, &zstd_out);

    var lz4_decoder = vort.Lz4NativeFrameDecoder.init(allocator);
    defer lz4_decoder.deinit();
    try expectRoundTrip(lz4_decoder.decodeConcatenatedChunksIntoSlice(&lz4_plain_chunks, lz4_plain_join, &lz4_out), lz4_dictionary_set_payload, &lz4_out);
    try expectRoundTrip(lz4_decoder.decodeConcatenatedChunksIntoSliceWithDictionarySet(&lz4_set_chunks, lz4_set_join, &lz4_out, lz4_dictionary_set), lz4_dictionary_set_payload, &lz4_out);

    var zstd_decoder = vort.ZstdNativeFrameDecoder.init(allocator);
    defer zstd_decoder.deinit();
    try expectRoundTrip(zstd_decoder.decodeConcatenatedChunksIntoSlice(&zstd_plain_chunks, zstd_plain_join, &zstd_out), zstd_dictionary_set_payload, &zstd_out);
    try expectRoundTrip(zstd_decoder.decodeConcatenatedChunksIntoSliceWithDictionarySet(&zstd_set_chunks, zstd_set_join, &zstd_out, zstd_dictionary_set), zstd_dictionary_set_payload, &zstd_out);

    try decodeLz4DictionarySetDirect(allocator, lz4_plain.items, &lz4_out, lz4_dictionary_set, false);
    try decodeLz4DictionarySetDirect(allocator, lz4_set_stream.items, &lz4_out, lz4_dictionary_set, true);
    try decodeZstdDictionarySetDirect(allocator, zstd_plain.items, &zstd_out, zstd_dictionary_set, false);
    try decodeZstdDictionarySetDirect(allocator, zstd_set_stream.items, &zstd_out, zstd_dictionary_set, true);
}

fn dictionarySetChunks(encoded: []const u8) [3][]const u8 {
    const first_end = @max(@as(usize, 1), encoded.len / 3);
    const second_end = @max(first_end + 1, (encoded.len * 2) / 3);
    return .{
        encoded[0..first_end],
        encoded[first_end..second_end],
        encoded[second_end..],
    };
}

fn appendLz4DictionarySetFrames(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    options: vort.Lz4NativeFrameOptions,
    dictionary_set: vort.Lz4NativeDictionarySet,
    first_dict: vort.Lz4NativeDictionary,
    second_dict: vort.Lz4NativeDictionary,
    use_dictionary_set: bool,
) !void {
    const first = if (use_dictionary_set)
        try vort.lz4EncodeNativeFrameWithDictionarySetAlloc(allocator, lz4_dictionary_set_first_payload, options, dictionary_set, first_dict.id)
    else
        try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, lz4_dictionary_set_first_payload, options);
    defer allocator.free(first);
    const second = if (use_dictionary_set)
        try vort.lz4EncodeNativeFrameWithDictionarySetAlloc(allocator, lz4_dictionary_set_second_payload, options, dictionary_set, second_dict.id)
    else
        try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, lz4_dictionary_set_second_payload, options);
    defer allocator.free(second);
    try out.appendSlice(allocator, first);
    try out.appendSlice(allocator, second);
}

fn appendZstdDictionarySetFrames(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    options: vort.ZstdNativeFrameOptions,
    dictionary_set: vort.ZstdNativeDictionarySet,
    first_dict: vort.ZstdNativeDictionary,
    second_dict: vort.ZstdNativeDictionary,
    use_dictionary_set: bool,
) !void {
    const first = if (use_dictionary_set)
        try vort.zstdEncodeNativeFrameWithDictionarySetAlloc(allocator, zstd_dictionary_set_first_payload, options, dictionary_set, first_dict.id)
    else
        try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, zstd_dictionary_set_first_payload, options);
    defer allocator.free(first.frame);
    const second = if (use_dictionary_set)
        try vort.zstdEncodeNativeFrameWithDictionarySetAlloc(allocator, zstd_dictionary_set_second_payload, options, dictionary_set, second_dict.id)
    else
        try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, zstd_dictionary_set_second_payload, options);
    defer allocator.free(second.frame);
    try out.appendSlice(allocator, first.frame);
    try out.appendSlice(allocator, second.frame);
}

fn decodeLz4Incremental(allocator: std.mem.Allocator, encoded: []const u8, decoded: []u8) !void {
    var decoder = vort.Lz4NativeIncrementalFrameDecoder.init(allocator);
    defer decoder.deinit();
    try drainIncremental(&decoder, encoded, decoded);
}

fn decodeZstdIncremental(allocator: std.mem.Allocator, encoded: []const u8, decoded: []u8) !void {
    var decoder = vort.ZstdNativeIncrementalFrameDecoder.init(allocator);
    defer decoder.deinit();
    try drainIncremental(&decoder, encoded, decoded);
}

fn decodeLz4IncrementalDirect(allocator: std.mem.Allocator, encoded: []const u8, decoded: []u8) !void {
    var decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = decoded.len,
        .max_decoded_buffer_len = decoded.len,
    });
    defer decoder.deinit();
    const first = try decoder.step(encoded, decoded[0..0]);
    if (first.status != .need_output) return error.SizeMismatch;
    if (!std.mem.eql(u8, decoder.diagnostics().phase_name, "direct_output")) return error.SizeMismatch;
    const done = try decoder.step("", decoded);
    if (done.status != .done or done.progress.output_written != decoded.len) return error.SizeMismatch;
}

fn decodeZstdIncrementalDirect(allocator: std.mem.Allocator, encoded: []const u8, decoded: []u8) !void {
    var decoder = vort.ZstdNativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = decoded.len,
        .max_decoded_buffer_len = decoded.len,
    });
    defer decoder.deinit();
    const first = try decoder.step(encoded, decoded[0..0]);
    if (first.status != .need_output) return error.SizeMismatch;
    if (!std.mem.eql(u8, decoder.diagnostics().phase_name, "direct_output")) return error.SizeMismatch;
    const done = try decoder.step("", decoded);
    if (done.status != .done or done.progress.output_written != decoded.len) return error.SizeMismatch;
}

fn decodeLz4IncrementalFallback(allocator: std.mem.Allocator, encoded: []const u8, decoded: []u8, expected: []const u8) !void {
    var decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = decoded.len,
        .max_decoded_buffer_len = decoded.len,
    });
    defer decoder.deinit();
    try drainIncrementalFallback(&decoder, encoded, decoded, expected, true);
}

fn decodeZstdIncrementalFallback(allocator: std.mem.Allocator, encoded: []const u8, decoded: []u8, expected: []const u8) !void {
    var decoder = vort.ZstdNativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = decoded.len,
        .max_decoded_buffer_len = decoded.len,
    });
    defer decoder.deinit();
    try drainIncrementalFallback(&decoder, encoded, decoded, expected, true);
}

fn decodeLz4DictionarySetDirect(
    allocator: std.mem.Allocator,
    encoded: []const u8,
    decoded: []u8,
    dictionary_set: vort.Lz4NativeDictionarySet,
    use_dictionary_set: bool,
) !void {
    var decoder = if (use_dictionary_set)
        vort.Lz4NativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(allocator, dictionary_set, .{
            .expected_output_len = decoded.len,
            .max_decoded_buffer_len = decoded.len,
        })
    else
        vort.Lz4NativeIncrementalFrameDecoder.initWithOptions(allocator, .{
            .expected_output_len = decoded.len,
            .max_decoded_buffer_len = decoded.len,
        });
    defer decoder.deinit();
    try drainDirectDictionarySet(&decoder, encoded, decoded, lz4_dictionary_set_payload);
}

fn decodeZstdDictionarySetDirect(
    allocator: std.mem.Allocator,
    encoded: []const u8,
    decoded: []u8,
    dictionary_set: vort.ZstdNativeDictionarySet,
    use_dictionary_set: bool,
) !void {
    var decoder = if (use_dictionary_set)
        vort.ZstdNativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(allocator, dictionary_set, .{
            .expected_output_len = decoded.len,
            .max_decoded_buffer_len = decoded.len,
        })
    else
        vort.ZstdNativeIncrementalFrameDecoder.initWithOptions(allocator, .{
            .expected_output_len = decoded.len,
            .max_decoded_buffer_len = decoded.len,
        });
    defer decoder.deinit();
    try drainDirectDictionarySet(&decoder, encoded, decoded, zstd_dictionary_set_payload);
}

fn decodeLz4DictionarySetFallback(
    allocator: std.mem.Allocator,
    encoded: []const u8,
    decoded: []u8,
    dictionary_set: vort.Lz4NativeDictionarySet,
    use_dictionary_set: bool,
) !void {
    var decoder = if (use_dictionary_set)
        vort.Lz4NativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(allocator, dictionary_set, .{
            .expected_output_len = decoded.len,
            .max_decoded_buffer_len = decoded.len,
        })
    else
        vort.Lz4NativeIncrementalFrameDecoder.initWithOptions(allocator, .{
            .expected_output_len = decoded.len,
            .max_decoded_buffer_len = decoded.len,
        });
    defer decoder.deinit();
    try drainIncrementalFallback(&decoder, encoded, decoded, lz4_dictionary_set_payload, use_dictionary_set);
}

fn decodeZstdDictionarySetFallback(
    allocator: std.mem.Allocator,
    encoded: []const u8,
    decoded: []u8,
    dictionary_set: vort.ZstdNativeDictionarySet,
    use_dictionary_set: bool,
) !void {
    var decoder = if (use_dictionary_set)
        vort.ZstdNativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(allocator, dictionary_set, .{
            .expected_output_len = decoded.len,
            .max_decoded_buffer_len = decoded.len,
        })
    else
        vort.ZstdNativeIncrementalFrameDecoder.initWithOptions(allocator, .{
            .expected_output_len = decoded.len,
            .max_decoded_buffer_len = decoded.len,
        });
    defer decoder.deinit();
    try drainIncrementalFallback(&decoder, encoded, decoded, zstd_dictionary_set_payload, use_dictionary_set);
}

fn drainIncrementalFallback(decoder: anytype, encoded: []const u8, decoded: []u8, expected: []const u8, require_scratch_fallback: bool) !void {
    const initial = try decoder.step(encoded, decoded[0..0]);
    if (initial.status != .need_output) return error.SizeMismatch;

    var written: usize = 0;
    const first_len = @min(decoded.len, @max(@as(usize, 1), decoded.len / 32));
    const first = try decoder.step("", decoded[0..first_len]);
    written += first.progress.output_written;
    if (first.status != .need_output or written != first_len) return error.SizeMismatch;
    // For a single frame the scratch buffer usually contains the whole frame
    // payload. For concatenated streams it may contain only the current frame,
    // which is still the fallback behavior this benchmark row is meant to
    // exercise. The final equality check below verifies full stream output.
    if (require_scratch_fallback and decoder.decoded_scratch.items.len == 0) return error.SizeMismatch;

    while (true) {
        const result = try decoder.step("", decoded[written..]);
        written += result.progress.output_written;
        if (result.status == .done) break;
        if (result.status != .need_output or result.progress.output_written == 0) return error.SizeMismatch;
    }
    if (written != expected.len) return error.SizeMismatch;
    if (!std.mem.eql(u8, expected, decoded[0..written])) return error.SizeMismatch;
}

fn drainDirectDictionarySet(decoder: anytype, encoded: []const u8, decoded: []u8, expected: []const u8) !void {
    const first = try decoder.step(encoded, decoded[0..0]);
    if (first.status != .need_output) return error.SizeMismatch;
    if (!std.mem.eql(u8, decoder.diagnostics().phase_name, "direct_output")) return error.SizeMismatch;

    var written: usize = 0;
    while (true) {
        const result = try decoder.step("", decoded[written..]);
        written += result.progress.output_written;
        if (result.status == .done) break;
        if (result.status != .need_output or result.progress.output_written == 0) return error.SizeMismatch;
    }
    if (written != expected.len) return error.SizeMismatch;
    if (!std.mem.eql(u8, expected, decoded[0..written])) return error.SizeMismatch;
}

fn drainIncremental(decoder: anytype, encoded: []const u8, decoded: []u8) !void {
    const split = @max(@as(usize, 1), encoded.len / 3);
    var offset: usize = 0;
    var out_offset: usize = 0;
    while (offset < encoded.len) {
        const end = @min(encoded.len, offset + split);
        const result = try decoder.step(encoded[offset..end], decoded[out_offset..out_offset]);
        offset += result.progress.input_read;
        if (result.status == .need_output) break;
        if (result.status == .done) break;
    }
    while (true) {
        const end = @min(decoded.len, out_offset + 31);
        const result = try decoder.step("", decoded[out_offset..end]);
        out_offset += result.progress.output_written;
        if (result.status == .done) break;
        if (result.status != .need_output) return error.SizeMismatch;
    }
    if (out_offset != decoded.len) return error.SizeMismatch;
}

fn verifyLz4DictionarySetChunkedAppend(
    allocator: std.mem.Allocator,
    chunks: []const []const u8,
    join: []u8,
    dictionary_set: vort.Lz4NativeDictionarySet,
    use_dictionary_set: bool,
    exact_size: bool,
) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try verifyLz4DictionarySetChunkedAppendInto(allocator, &out, chunks, join, dictionary_set, use_dictionary_set, exact_size);
}

fn verifyLz4DictionarySetChunkedAppendInto(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    chunks: []const []const u8,
    join: []u8,
    dictionary_set: vort.Lz4NativeDictionarySet,
    use_dictionary_set: bool,
    exact_size: bool,
) !void {
    out.clearRetainingCapacity();
    try out.appendSlice(allocator, "prefix:");
    const written = if (use_dictionary_set)
        if (exact_size)
            try vort.lz4DecodeNativeConcatenatedFrameChunksAppendExactSizeWithDictionarySet(
                allocator,
                out,
                chunks,
                join,
                dictionary_set,
                lz4_dictionary_set_payload.len,
            )
        else
            try vort.lz4DecodeNativeConcatenatedFrameChunksAppendWithDictionarySet(
                allocator,
                out,
                chunks,
                join,
                dictionary_set,
            )
    else if (exact_size)
        try vort.lz4DecodeNativeConcatenatedFrameChunksAppendExactSize(
            allocator,
            out,
            chunks,
            join,
            lz4_dictionary_set_payload.len,
        )
    else
        try vort.lz4DecodeNativeConcatenatedFrameChunksAppend(
            allocator,
            out,
            chunks,
            join,
        );
    if (written != lz4_dictionary_set_payload.len) return error.SizeMismatch;
    if (!std.mem.eql(u8, out.items, "prefix:" ++ lz4_dictionary_set_payload)) return error.SizeMismatch;
}

fn verifyZstdDictionarySetChunkedAppend(
    allocator: std.mem.Allocator,
    chunks: []const []const u8,
    join: []u8,
    dictionary_set: vort.ZstdNativeDictionarySet,
    use_dictionary_set: bool,
    exact_size: bool,
) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try verifyZstdDictionarySetChunkedAppendInto(allocator, &out, chunks, join, dictionary_set, use_dictionary_set, exact_size);
}

fn verifyZstdDictionarySetChunkedAppendInto(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    chunks: []const []const u8,
    join: []u8,
    dictionary_set: vort.ZstdNativeDictionarySet,
    use_dictionary_set: bool,
    exact_size: bool,
) !void {
    out.clearRetainingCapacity();
    try out.appendSlice(allocator, "prefix:");
    const written = if (use_dictionary_set)
        if (exact_size)
            try vort.zstdDecodeNativeConcatenatedFrameChunksAppendExactSizeWithDictionarySet(
                allocator,
                out,
                chunks,
                join,
                dictionary_set,
                zstd_dictionary_set_payload.len,
            )
        else
            try vort.zstdDecodeNativeConcatenatedFrameChunksAppendWithDictionarySet(
                allocator,
                out,
                chunks,
                join,
                dictionary_set,
            )
    else if (exact_size)
        try vort.zstdDecodeNativeConcatenatedFrameChunksAppendExactSize(
            allocator,
            out,
            chunks,
            join,
            zstd_dictionary_set_payload.len,
        )
    else
        try vort.zstdDecodeNativeConcatenatedFrameChunksAppend(
            allocator,
            out,
            chunks,
            join,
        );
    if (written != zstd_dictionary_set_payload.len) return error.SizeMismatch;
    if (!std.mem.eql(u8, out.items, "prefix:" ++ zstd_dictionary_set_payload)) return error.SizeMismatch;
}

fn verifyLz4ReusableAppendExactInto(
    decoder: *vort.Lz4NativeFrameDecoder,
    out: *std.ArrayList(u8),
    chunks: []const []const u8,
    join: []u8,
    dictionary_set: vort.Lz4NativeDictionarySet,
    use_dictionary_set: bool,
) !void {
    out.clearRetainingCapacity();
    try out.appendSlice(decoder.allocator, "prefix:");
    const written = if (use_dictionary_set)
        try decoder.decodeConcatenatedChunksAppendExactSizeWithDictionarySet(out, chunks, join, dictionary_set, lz4_dictionary_set_payload.len)
    else
        try decoder.decodeConcatenatedChunksAppendExactSize(out, chunks, join, lz4_dictionary_set_payload.len);
    if (written != lz4_dictionary_set_payload.len) return error.SizeMismatch;
    if (!std.mem.eql(u8, out.items, "prefix:" ++ lz4_dictionary_set_payload)) return error.SizeMismatch;
}

fn verifyZstdReusableAppendExactInto(
    decoder: *vort.ZstdNativeFrameDecoder,
    out: *std.ArrayList(u8),
    chunks: []const []const u8,
    join: []u8,
    dictionary_set: vort.ZstdNativeDictionarySet,
    use_dictionary_set: bool,
) !void {
    out.clearRetainingCapacity();
    try out.appendSlice(decoder.allocator, "prefix:");
    const written = if (use_dictionary_set)
        try decoder.decodeConcatenatedChunksAppendExactSizeWithDictionarySet(out, chunks, join, dictionary_set, zstd_dictionary_set_payload.len)
    else
        try decoder.decodeConcatenatedChunksAppendExactSize(out, chunks, join, zstd_dictionary_set_payload.len);
    if (written != zstd_dictionary_set_payload.len) return error.SizeMismatch;
    if (!std.mem.eql(u8, out.items, "prefix:" ++ zstd_dictionary_set_payload)) return error.SizeMismatch;
}

fn expectRoundTrip(written_result: anytype, expected: []const u8, decoded: []u8) !void {
    const written = try written_result;
    if (written != expected.len) return error.SizeMismatch;
    if (!std.mem.eql(u8, expected, decoded[0..written])) return error.SizeMismatch;
}

fn makeRow(codec: Codec, mode: Mode, case: Case, encoded_len: usize, iterations: usize, encode_ns: u64, decode_ns: u64, checksum: u64) Row {
    return .{
        .codec = codec,
        .mode = mode,
        .case_name = case.name,
        .input_bytes = case.payload.len,
        .encoded_bytes = encoded_len,
        .iterations = iterations,
        .encode_ns = encode_ns,
        .decode_ns = decode_ns,
        .encode_mib_s = mibPerSecond(case.payload.len * iterations, encode_ns),
        .decode_mib_s = mibPerSecond(case.payload.len * iterations, decode_ns),
        .checksum = checksum,
    };
}

fn elapsedNs(io: std.Io, start: std.Io.Timestamp) u64 {
    const elapsed = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return if (elapsed <= 0) 0 else @intCast(elapsed);
}

fn mibPerSecond(bytes: usize, ns: u64) f64 {
    if (ns == 0) return 0.0;
    const mib = @as(f64, @floatFromInt(bytes)) / (1024.0 * 1024.0);
    const seconds = @as(f64, @floatFromInt(ns)) / 1_000_000_000.0;
    return mib / seconds;
}

fn codecName(codec: Codec) []const u8 {
    return switch (codec) {
        .lz4 => "lz4",
        .zstd => "zstd",
    };
}

fn modeName(mode: Mode) []const u8 {
    return switch (mode) {
        .one_shot => "one_shot",
        .incremental => "incremental",
        .incremental_direct => "incremental_direct",
        .incremental_fallback => "incremental_fallback",
        .chain_depth_0 => "chain_depth_0",
        .chain_depth_default => "chain_depth_default",
        .match_budget_0 => "match_budget_0",
        .match_budget_full => "match_budget_full",
        .high_byte_binary => "high_byte_binary",
        .sequence_huffman_literals_plain => "sequence_huffman_literals_plain",
        .sequence_huffman_literals => "sequence_huffman_literals",
        .dictionary_plain => "dictionary_plain",
        .dictionary => "dictionary",
        .dictionary_set_plain => "dictionary_set_plain",
        .dictionary_set => "dictionary_set",
        .dictionary_set_chunked_plain => "dictionary_set_chunked_plain",
        .dictionary_set_chunked => "dictionary_set_chunked",
        .dictionary_set_chunked_append_plain => "dictionary_set_chunked_append_plain",
        .dictionary_set_chunked_append => "dictionary_set_chunked_append",
        .dictionary_set_chunked_append_exact_plain => "dictionary_set_chunked_append_exact_plain",
        .dictionary_set_chunked_append_exact => "dictionary_set_chunked_append_exact",
        .dictionary_set_reusable_plain => "dictionary_set_reusable_plain",
        .dictionary_set_reusable => "dictionary_set_reusable",
        .dictionary_set_reusable_append_exact_plain => "dictionary_set_reusable_append_exact_plain",
        .dictionary_set_reusable_append_exact => "dictionary_set_reusable_append_exact",
        .dictionary_set_direct_plain => "dictionary_set_direct_plain",
        .dictionary_set_direct => "dictionary_set_direct",
        .dictionary_set_fallback_plain => "dictionary_set_fallback_plain",
        .dictionary_set_fallback => "dictionary_set_fallback",
    };
}

fn writeCsv(writer: *std.Io.Writer, rows: []const Row) !void {
    try writer.writeAll("codec,mode,case,input_bytes,encoded_bytes,iterations,encode_ns,decode_ns,encode_mib_s,decode_mib_s,checksum\n");
    for (rows) |row| {
        try writer.print("{s},{s},{s},{d},{d},{d},{d},{d},{d:.4},{d:.4},{d}\n", .{
            codecName(row.codec),
            modeName(row.mode),
            row.case_name,
            row.input_bytes,
            row.encoded_bytes,
            row.iterations,
            row.encode_ns,
            row.decode_ns,
            row.encode_mib_s,
            row.decode_mib_s,
            row.checksum,
        });
    }
}
