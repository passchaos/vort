const std = @import("std");
const vort = @import("vort");

const Codec = enum { lz4, zstd };
const Mode = enum {
    one_shot,
    incremental,
    incremental_direct,
    incremental_fallback,
    lib_decode,
    native_lib_decode,
    chain_depth_0,
    chain_depth_default,
    match_budget_0,
    match_budget_full,
    high_byte_binary,
    lib_generated,
    lib_generated_no_size,
    lib_generated_checksum,
    lib_generated_no_size_checksum,
    lib_generated_independent,
    lib_generated_independent_no_size_checksum,
    sequence_huffman_literals_plain,
    sequence_huffman_literals,
    dictionary_plain,
    dictionary,
    trained_dictionary_plain,
    trained_dictionary,
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
    owned: bool = false,

    fn deinit(self: Case, allocator: std.mem.Allocator) void {
        if (self.owned) {
            allocator.free(self.name);
            allocator.free(self.payload);
        }
    }
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
    path_limit: usize = 128 * 1024,
    paths: std.ArrayList([]const u8) = .empty,

    fn deinit(self: *Options, allocator: std.mem.Allocator) void {
        for (self.paths.items) |path| allocator.free(path);
        self.paths.deinit(allocator);
    }
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    var options = try parseOptions(init.gpa, &args);
    defer options.deinit(init.gpa);

    var cases: std.ArrayList(Case) = .empty;
    defer {
        for (cases.items) |case| case.deinit(init.gpa);
        cases.deinit(init.gpa);
    }
    try addBuiltinCases(init.gpa, &cases);
    try addPathCases(init.io, init.gpa, &cases, options.paths.items, options.path_limit);

    try smokeLz4LinkedDirectCursor(init.gpa);
    try smokeLz4DeepHashChain(init.gpa);
    try smokeLz4LinkedDeepHashChain(init.gpa);
    try smokeLz4ChainDepthBudget(init.gpa);
    try smokeLz4SkippableMalformedStreams(init.gpa);
    try smokeLz4DictionarySetSkippableFallback(init.gpa);
    try smokeZstdDictionarySetSkippableFallback(init.gpa);
    try smokeZstdMultiblockDirectFallback(init.gpa);
    try smokeReusableChunkedDecoders(init.gpa);
    try smokeZstdManyRepeatedSequences(init.gpa);
    try smokeZstdAllCompressedSequenceTables(init.gpa);
    try smokeZstdSequenceInspectFixtures(init.gpa);
    try smokeZstdNoSizeMultiCompressed(init.gpa);
    try smokeZstdMatchSearchBudget(init.gpa);
    try smokeNativeDictionaryBenchRows(init.gpa);
    try smokeNativeDictionarySetBenchRows(init.gpa);
    try smokeNativeDictionarySetChunkedBenchRows(init.gpa);

    var rows: std.ArrayList(Row) = .empty;
    defer rows.deinit(init.gpa);
    for (cases.items) |case| {
        try rows.append(init.gpa, try lz4OneShotRow(init.io, init.gpa, case, options.iterations));
        try rows.append(init.gpa, try lz4IncrementalRow(init.io, init.gpa, case, options.iterations));
        try rows.append(init.gpa, try lz4IncrementalDirectRow(init.io, init.gpa, case, options.iterations));
        try rows.append(init.gpa, try lz4IncrementalFallbackRow(init.io, init.gpa, case, options.iterations));
        try rows.append(init.gpa, try lz4LibDecodeRow(init.io, init.gpa, case, options.iterations));
        try rows.append(init.gpa, try lz4NativeLibDecodeRow(init.io, init.gpa, case, options.iterations));
        try rows.append(init.gpa, try zstdOneShotRow(init.io, init.gpa, case, options.iterations));
        try rows.append(init.gpa, try zstdLibDecodeRow(init.io, init.gpa, case, options.iterations));
        try rows.append(init.gpa, try zstdNativeLibDecodeRow(init.io, init.gpa, case, options.iterations));
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
    try rows.append(init.gpa, try lz4LibGeneratedRow(init.io, init.gpa, .lib_generated, "lib_generated", true, false, .linked, options.iterations));
    try rows.append(init.gpa, try lz4LibGeneratedRow(init.io, init.gpa, .lib_generated_no_size, "lib_generated_no_size", false, false, .linked, options.iterations));
    try rows.append(init.gpa, try lz4LibGeneratedRow(init.io, init.gpa, .lib_generated_checksum, "lib_generated_checksum", true, true, .linked, options.iterations));
    try rows.append(init.gpa, try lz4LibGeneratedRow(init.io, init.gpa, .lib_generated_no_size_checksum, "lib_generated_no_size_checksum", false, true, .linked, options.iterations));
    try rows.append(init.gpa, try lz4LibGeneratedRow(init.io, init.gpa, .lib_generated_independent, "lib_generated_independent", true, false, .independent, options.iterations));
    try rows.append(init.gpa, try lz4LibGeneratedRow(init.io, init.gpa, .lib_generated_independent_no_size_checksum, "lib_generated_independent_no_size_checksum", false, true, .independent, options.iterations));
    try rows.append(init.gpa, try zstdLibGeneratedRow(init.io, init.gpa, .lib_generated, "lib_generated", true, false, options.iterations));
    try rows.append(init.gpa, try zstdLibGeneratedRow(init.io, init.gpa, .lib_generated_no_size, "lib_generated_no_size", false, false, options.iterations));
    try rows.append(init.gpa, try zstdLibGeneratedRow(init.io, init.gpa, .lib_generated_checksum, "lib_generated_checksum", true, true, options.iterations));
    try rows.append(init.gpa, try zstdLibGeneratedRow(init.io, init.gpa, .lib_generated_no_size_checksum, "lib_generated_no_size_checksum", false, true, options.iterations));
    try rows.append(init.gpa, try zstdSequenceHuffmanLiteralsRow(init.io, init.gpa, .sequence_huffman_literals_plain, false, options.iterations));
    try rows.append(init.gpa, try zstdSequenceHuffmanLiteralsRow(init.io, init.gpa, .sequence_huffman_literals, true, options.iterations));
    try rows.append(init.gpa, try lz4DictionaryRow(init.io, init.gpa, .dictionary_plain, false, options.iterations));
    try rows.append(init.gpa, try lz4DictionaryRow(init.io, init.gpa, .dictionary, true, options.iterations));
    try rows.append(init.gpa, try zstdDictionaryRow(init.io, init.gpa, .dictionary_plain, false, options.iterations));
    try rows.append(init.gpa, try zstdDictionaryRow(init.io, init.gpa, .dictionary, true, options.iterations));
    try rows.append(init.gpa, try lz4TrainedDictionaryRow(init.io, init.gpa, .trained_dictionary_plain, false, options.iterations));
    try rows.append(init.gpa, try lz4TrainedDictionaryRow(init.io, init.gpa, .trained_dictionary, true, options.iterations));
    try rows.append(init.gpa, try zstdTrainedDictionaryRow(init.io, init.gpa, .trained_dictionary_plain, false, options.iterations));
    try rows.append(init.gpa, try zstdTrainedDictionaryRow(init.io, init.gpa, .trained_dictionary, true, options.iterations));
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

fn parseOptions(allocator: std.mem.Allocator, args: *std.process.Args.Iterator) !Options {
    var options: Options = .{};
    errdefer options.deinit(allocator);
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--iterations")) {
            const value = args.next() orelse return error.MissingIterationCount;
            options.iterations = try std.fmt.parseInt(usize, value, 10);
            if (options.iterations == 0) return error.InvalidIterationCount;
        } else if (std.mem.eql(u8, arg, "--csv")) {
            options.csv_path = args.next() orelse return error.MissingCsvPath;
        } else if (std.mem.eql(u8, arg, "--limit")) {
            const value = args.next() orelse return error.MissingLimit;
            options.path_limit = try std.fmt.parseInt(usize, value, 10);
            if (options.path_limit == 0) return error.InvalidLimit;
        } else if (std.mem.eql(u8, arg, "--path")) {
            const path = args.next() orelse return error.MissingPath;
            try options.paths.append(allocator, try allocator.dupe(u8, path));
        } else {
            return error.UnknownArgument;
        }
    }
    return options;
}

fn addBuiltinCases(allocator: std.mem.Allocator, cases: *std.ArrayList(Case)) !void {
    try cases.append(allocator, .{ .name = "text", .payload = "Native library benchmark text payload. " ** 1024 });
    try cases.append(allocator, .{ .name = "structured", .payload = "{\"service\":\"vort\",\"codec\":\"native\",\"value\":12345}\n" ** 768 });
    try cases.append(allocator, .{ .name = "repetitive", .payload = ("abcdefghijklmnopqrstuvwxyz012345" ** 4) ** 256 });
}

fn addPathCases(io: std.Io, allocator: std.mem.Allocator, cases: *std.ArrayList(Case), paths: []const []const u8, limit: usize) !void {
    for (paths) |path| {
        const file = try std.Io.Dir.cwd().openFile(io, path, .{});
        defer file.close(io);
        const stat = try file.stat(io);
        const read_len = @min(limit, try checkedU64ToUsize(stat.size));
        if (read_len == 0) continue;
        const payload = try allocator.alloc(u8, read_len);
        errdefer allocator.free(payload);
        var reader_buffer: [4096]u8 = undefined;
        var reader = file.reader(io, &reader_buffer);
        const n = try reader.interface.readSliceShort(payload);
        if (n != read_len) return error.InputTooSmall;
        const name = try caseNameForPath(allocator, path, cases.items.len);
        errdefer allocator.free(name);
        try cases.append(allocator, .{ .name = name, .payload = payload, .owned = true });
    }
}

fn checkedU64ToUsize(value: u64) !usize {
    if (value > std.math.maxInt(usize)) return error.IntegerOverflow;
    return @intCast(value);
}

fn caseNameForPath(allocator: std.mem.Allocator, path: []const u8, index: usize) ![]u8 {
    const base = std.fs.path.basename(path);
    var out: std.Io.Writer.Allocating = .init(allocator);
    errdefer out.deinit();
    try out.writer.print("file{d}_", .{index});
    for (base) |byte| {
        try out.writer.writeByte(if (std.ascii.isAlphanumeric(byte)) byte else '_');
    }
    return try out.toOwnedSlice();
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

fn lz4LibDecodeRow(io: std.Io, allocator: std.mem.Allocator, case: Case, iterations: usize) !Row {
    const options: vort.Lz4FrameOptions = .{
        .include_content_size = true,
        .content_checksum = true,
        .block_checksum = false,
        .block_mode = .linked,
    };
    const encoded = try vort.lz4EncodeFrameWithOptionsAlloc(allocator, case.payload, options);
    defer allocator.free(encoded);
    const decoded = try allocator.alloc(u8, case.payload.len);
    defer allocator.free(decoded);
    try expectRoundTrip(vort.lz4DecodeFrameInto(encoded, decoded), case.payload, decoded);
    try expectRoundTrip(vort.lz4DecodeNativeFrameInto(encoded, decoded), case.payload, decoded);

    const encode_result = try timeEncodeLz4Lib(io, allocator, case.payload, options, iterations);
    const decode_result = try timeDecodeLz4Lib(io, encoded, decoded, case.payload, iterations);
    return makeRow(.lz4, .lib_decode, case, encoded.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn lz4NativeLibDecodeRow(io: std.Io, allocator: std.mem.Allocator, case: Case, iterations: usize) !Row {
    const options: vort.Lz4NativeFrameOptions = .{ .content_checksum = false, .block_checksum = true };
    const encoded = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, case.payload, options);
    defer allocator.free(encoded);
    const decoded = try allocator.alloc(u8, case.payload.len);
    defer allocator.free(decoded);
    try expectRoundTrip(vort.lz4DecodeNativeFrameInto(encoded, decoded), case.payload, decoded);
    try expectRoundTrip(vort.lz4DecodeFrameInto(encoded, decoded), case.payload, decoded);

    const encode_result = try timeEncodeLz4(io, allocator, case.payload, options, iterations);
    const decode_result = try timeDecodeLz4Lib(io, encoded, decoded, case.payload, iterations);
    return makeRow(.lz4, .native_lib_decode, case, encoded.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
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

fn zstdLibDecodeRow(io: std.Io, allocator: std.mem.Allocator, case: Case, iterations: usize) !Row {
    const options: vort.ZstdFrameOptions = .{ .include_content_size = true, .content_checksum = false };
    const encoded = try vort.zstdEncodeFrameWithOptionsAlloc(allocator, case.payload, options);
    defer allocator.free(encoded);
    const decoded = try allocator.alloc(u8, case.payload.len);
    defer allocator.free(decoded);
    try expectRoundTrip(vort.zstdDecodeFrameInto(encoded, decoded), case.payload, decoded);
    try expectRoundTrip(vort.zstdDecodeNativeFrameInto(encoded, decoded), case.payload, decoded);

    const encode_result = try timeEncodeZstdLib(io, allocator, case.payload, options, iterations);
    const decode_result = try timeDecodeZstdLib(io, encoded, decoded, case.payload, iterations);
    return makeRow(.zstd, .lib_decode, case, encoded.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn zstdNativeLibDecodeRow(io: std.Io, allocator: std.mem.Allocator, case: Case, iterations: usize) !Row {
    const options: vort.ZstdNativeFrameOptions = .{ .selection = .literal_only, .content_checksum = false };
    const encoded = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, case.payload, options);
    defer allocator.free(encoded.frame);
    const decoded = try allocator.alloc(u8, case.payload.len);
    defer allocator.free(decoded);
    try expectRoundTrip(vort.zstdDecodeNativeFrameInto(encoded.frame, decoded), case.payload, decoded);
    try expectRoundTrip(vort.zstdDecodeFrameInto(encoded.frame, decoded), case.payload, decoded);

    const encode_result = try timeEncodeZstd(io, allocator, case.payload, options, iterations);
    const decode_result = try timeDecodeZstdLib(io, encoded.frame, decoded, case.payload, iterations);
    return makeRow(.zstd, .native_lib_decode, case, encoded.frame.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
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
    // Keep the historical CSV mode name: this row now measures the resumable
    // small-output path and asserts that Zstd does not allocate decoded scratch.
    const options: vort.ZstdNativeFrameOptions = .{ .selection = .literal_only, .content_checksum = false };
    const encoded = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, case.payload, options);
    defer allocator.free(encoded.frame);
    const decoded = try allocator.alloc(u8, case.payload.len);
    defer allocator.free(decoded);
    decodeZstdIncrementalFallback(allocator, encoded.frame, decoded, case.payload) catch |err| {
        std.debug.print("zstd incremental small-output case failed: {s}: {s}\n", .{ case.name, @errorName(err) });
        return err;
    };

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

fn lz4LibGeneratedRow(
    io: std.Io,
    allocator: std.mem.Allocator,
    mode: Mode,
    case_name: []const u8,
    include_content_size: bool,
    block_checksum: bool,
    block_mode: vort.Lz4BlockMode,
    iterations: usize,
) !Row {
    const payload = lib_generated_payload;
    const case: Case = .{ .name = case_name, .payload = payload };
    const options: vort.Lz4FrameOptions = .{
        .include_content_size = include_content_size,
        .content_checksum = true,
        .block_checksum = block_checksum,
        .block_mode = block_mode,
    };
    const encoded = try vort.lz4EncodeFrameWithOptionsAlloc(allocator, payload, options);
    defer allocator.free(encoded);
    const decoded = try allocator.alloc(u8, payload.len);
    defer allocator.free(decoded);
    try expectRoundTrip(vort.lz4DecodeNativeFrameInto(encoded, decoded), payload, decoded);

    const encode_result = try timeEncodeLz4Lib(io, allocator, payload, options, iterations);
    const decode_result = try timeDecodeLz4OneShot(io, encoded, decoded, payload, iterations);
    return makeRow(.lz4, mode, case, encoded.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn zstdLibGeneratedRow(
    io: std.Io,
    allocator: std.mem.Allocator,
    mode: Mode,
    case_name: []const u8,
    include_content_size: bool,
    content_checksum: bool,
    iterations: usize,
) !Row {
    const payload = lib_generated_payload;
    const case: Case = .{ .name = case_name, .payload = payload };
    const options: vort.ZstdFrameOptions = .{
        .include_content_size = include_content_size,
        .content_checksum = content_checksum,
    };
    const encoded = try vort.zstdEncodeFrameWithOptionsAlloc(allocator, payload, options);
    defer allocator.free(encoded);
    const decoded = try allocator.alloc(u8, payload.len);
    defer allocator.free(decoded);
    try expectRoundTrip(vort.zstdDecodeFrameInto(encoded, decoded), payload, decoded);
    try expectRoundTrip(vort.zstdDecodeNativeFrameInto(encoded, decoded), payload, decoded);

    const encode_result = try timeEncodeZstdLib(io, allocator, payload, options, iterations);
    const decode_result = try timeDecodeZstdOneShot(io, encoded, decoded, payload, iterations);
    return makeRow(.zstd, mode, case, encoded.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
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

fn lz4TrainedDictionaryRow(
    io: std.Io,
    allocator: std.mem.Allocator,
    mode: Mode,
    use_dictionary: bool,
    iterations: usize,
) !Row {
    const trained = try vort.lz4TrainNativeDictionaryAlloc(allocator, &lz4_trained_dictionary_samples, trained_dictionary_options);
    defer trained.deinit(allocator);
    const dict = trained.asDictionary();
    const payload = lz4_trained_dictionary_payload;
    const case: Case = .{ .name = "trained_dictionary", .payload = payload };
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

fn zstdTrainedDictionaryRow(
    io: std.Io,
    allocator: std.mem.Allocator,
    mode: Mode,
    use_dictionary: bool,
    iterations: usize,
) !Row {
    const trained = try vort.zstdTrainNativeDictionaryAlloc(allocator, &zstd_trained_dictionary_samples, trained_dictionary_options);
    defer trained.deinit(allocator);
    const dict = trained.asDictionary();
    const payload = zstd_trained_dictionary_payload;
    const case: Case = .{ .name = "trained_dictionary", .payload = payload };
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
const lib_generated_payload = ("lib-generated native library benchmark payload. " ** 16) ** 8;

const lz4_dictionary_content = "abcdefghijklmnop";
const lz4_dictionary_payload = "prefix-abcdefghijklmnop-tail-abcdefghijklmnop";
const zstd_dictionary_content = "abcdefghijklmnop";
const zstd_dictionary_payload = "prefix-abcdefghijklmnop-tail-abcdefghijklmnop";
const lz4_trained_dictionary_samples = [_][]const u8{
    "trained-lz4-prefix alpha trained-lz4-tail",
    "trained-lz4-prefix beta trained-lz4-tail",
    "trained-lz4-prefix gamma trained-lz4-tail",
};
const lz4_trained_dictionary_payload = "trained-lz4-prefix alpha trained-lz4-tail payload";
const zstd_trained_dictionary_samples = [_][]const u8{
    "trained-zstd-prefix alpha trained-zstd-tail",
    "trained-zstd-prefix beta trained-zstd-tail",
    "trained-zstd-prefix gamma trained-zstd-tail",
};
const zstd_trained_dictionary_payload = "pfx-trained-zstd-prefix alpha trained-zstd-tail payload";
const trained_dictionary_options: vort.Lz4NativeDictionaryTrainOptions = .{
    .target_size = 64,
    .min_phrase_len = 4,
    .max_phrase_len = 18,
    .max_phrases = 96,
};
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

fn timeEncodeLz4Lib(
    io: std.Io,
    allocator: std.mem.Allocator,
    payload: []const u8,
    options: vort.Lz4FrameOptions,
    iterations: usize,
) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        const encoded = try vort.lz4EncodeFrameWithOptionsAlloc(allocator, payload, options);
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

fn timeEncodeZstdLib(
    io: std.Io,
    allocator: std.mem.Allocator,
    payload: []const u8,
    options: vort.ZstdFrameOptions,
    iterations: usize,
) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        const encoded = try vort.zstdEncodeFrameWithOptionsAlloc(allocator, payload, options);
        checksum +%= encoded.len;
        allocator.free(encoded);
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

fn timeDecodeLz4Lib(io: std.Io, encoded: []const u8, decoded: []u8, expected: []const u8, iterations: usize) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        try expectRoundTrip(vort.lz4DecodeFrameInto(encoded, decoded), expected, decoded);
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

fn timeDecodeZstdLib(io: std.Io, encoded: []const u8, decoded: []u8, expected: []const u8, iterations: usize) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        try expectRoundTrip(vort.zstdDecodeFrameInto(encoded, decoded), expected, decoded);
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

fn smokeLz4LinkedDirectCursor(allocator: std.mem.Allocator) !void {
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
        .input_policy = .prevalidated_frame,
    });
    defer decoder.deinit();
    var decoded: [payload.len]u8 = undefined;
    const initial = try decoder.step(encoded, decoded[0..0]);
    if (initial.status != .need_output) return error.SizeMismatch;
    if (!std.mem.eql(u8, decoder.diagnostics().phase_name, "direct_output")) return error.SizeMismatch;
    const first = try decoder.step("", decoded[0 .. 64 * 1024]);
    if (first.status != .need_output or first.progress.output_written != 64 * 1024) return error.SizeMismatch;
    if (decoder.decodedBufferedBytes() != 0 or decoder.decodedBufferCapacity() != 0) return error.SizeMismatch;
    const partial = try decoder.step("", decoded[64 * 1024 ..][0..127]);
    if (partial.status != .need_output or partial.progress.output_written != 127) return error.SizeMismatch;
    if (!decoder.isCompressedBlockStreaming()) return error.SizeMismatch;
    if (decoder.decodedBufferedBytes() != 0 or decoder.decodedBufferCapacity() != 0) return error.SizeMismatch;
    if (decoder.streamedCompressedBlockCount() != 0) return error.SizeMismatch;
    const done = try decoder.step("", decoded[64 * 1024 + 127 ..]);
    if (done.status != .done) return error.SizeMismatch;
    if (decoder.decodedBufferedBytes() != 0 or decoder.decodedBufferCapacity() != 0) return error.SizeMismatch;
    if (decoder.streamedCompressedBlockCount() != 1) return error.SizeMismatch;
    if (!std.mem.eql(u8, &payload, &decoded)) return error.SizeMismatch;

    const skip = try vort.lz4EncodeSkippableFrameAlloc(allocator, 5, "linked-direct");
    defer allocator.free(skip);
    const stream = try std.mem.concat(allocator, u8, &.{ skip, encoded });
    defer allocator.free(stream);
    var stream_decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
        .input_policy = .prevalidated_frame,
    });
    defer stream_decoder.deinit();
    @memset(&decoded, 0);
    const stream_initial = try stream_decoder.step(stream, decoded[0..0]);
    if (stream_initial.status != .need_output) return error.SizeMismatch;
    if (!std.mem.eql(u8, stream_decoder.diagnostics().phase_name, "direct_output")) return error.SizeMismatch;
    const stream_done = try stream_decoder.step("", &decoded);
    if (stream_done.status != .done) return error.SizeMismatch;
    if (!std.mem.eql(u8, &payload, &decoded)) return error.SizeMismatch;

    var fallback_decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
        .input_policy = .prevalidated_frame,
    });
    defer fallback_decoder.deinit();
    @memset(&decoded, 0);
    const fallback_initial = try fallback_decoder.step(stream, decoded[0..0]);
    if (fallback_initial.status != .need_output) return error.SizeMismatch;
    if (!std.mem.eql(u8, fallback_decoder.diagnostics().phase_name, "direct_output")) return error.SizeMismatch;
    const fallback_first = try fallback_decoder.step("", decoded[0 .. 64 * 1024]);
    if (fallback_first.status != .need_output or fallback_first.progress.output_written != 64 * 1024) return error.SizeMismatch;
    if (fallback_decoder.decodedBufferedBytes() != 0 or fallback_decoder.decodedBufferCapacity() != 0) return error.SizeMismatch;
    const fallback_progress = try fallback_decoder.step("", decoded[64 * 1024 ..][0..127]);
    if (fallback_progress.status != .need_output or fallback_progress.progress.output_written != 127) return error.SizeMismatch;
    if (!fallback_decoder.isCompressedBlockStreaming()) return error.SizeMismatch;
    if (fallback_decoder.decodedBufferedBytes() != 0 or fallback_decoder.decodedBufferCapacity() != 0) return error.SizeMismatch;
    if (fallback_decoder.streamedCompressedBlockCount() != 0) return error.SizeMismatch;
    const fallback_done = try fallback_decoder.step("", decoded[64 * 1024 + 127 ..]);
    if (fallback_done.status != .done) return error.SizeMismatch;
    if (fallback_decoder.decodedBufferedBytes() != 0 or fallback_decoder.decodedBufferCapacity() != 0) return error.SizeMismatch;
    if (fallback_decoder.streamedCompressedBlockCount() != 1) return error.SizeMismatch;
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

fn smokeLz4SkippableMalformedStreams(allocator: std.mem.Allocator) !void {
    const skip = try vort.lz4EncodeSkippableFrameAlloc(allocator, 4, "bench-meta");
    defer allocator.free(skip);

    var bad_header: std.ArrayList(u8) = .empty;
    defer bad_header.deinit(allocator);
    try bad_header.appendSlice(allocator, &.{ 0x04, 0x22, 0x4d, 0x18 });
    const descriptor = [_]u8{ 0x62, 0x70 };
    try bad_header.appendSlice(allocator, &descriptor);
    try bad_header.append(allocator, @truncate(std.hash.XxHash32.hash(0, &descriptor) >> 8));
    try bad_header.appendSlice(allocator, &.{ 0, 0, 0, 0 });

    const stream = try std.mem.concat(allocator, u8, &.{ skip, bad_header.items });
    defer allocator.free(stream);

    if (vort.lz4DecodedNativeConcatenatedFrameSize(stream)) |_| return error.SizeMismatch else |err| switch (err) {
        error.CorruptFrame => {},
        else => return err,
    }
    if (vort.lz4SummarizeNativeStream(stream)) |_| return error.SizeMismatch else |err| switch (err) {
        error.CorruptFrame => {},
        else => return err,
    }

    var iterator = vort.lz4IterateNativeStream(stream);
    const first = (try iterator.next()) orelse return error.SizeMismatch;
    switch (first) {
        .frame => return error.SizeMismatch,
        .skippable => |skippable| {
            if (skippable.header.skippable_id != 4 or !std.mem.eql(u8, skippable.payload, "bench-meta")) {
                return error.SizeMismatch;
            }
        },
    }
    if (iterator.next()) |_| return error.SizeMismatch else |err| switch (err) {
        error.CorruptFrame => {},
        else => return err,
    }

    var truncated_frame: std.ArrayList(u8) = .empty;
    defer truncated_frame.deinit(allocator);
    try truncated_frame.appendSlice(allocator, &.{ 0x04, 0x22, 0x4d, 0x18 });
    const valid_descriptor = [_]u8{ 0x60, 0x40 };
    try truncated_frame.appendSlice(allocator, &valid_descriptor);
    try truncated_frame.append(allocator, @truncate(std.hash.XxHash32.hash(0, &valid_descriptor) >> 8));
    var block_header: [4]u8 = undefined;
    std.mem.writeInt(u32, &block_header, 0x8000_0000 | @as(u32, 64 * 1024), .little);
    try truncated_frame.appendSlice(allocator, &block_header);
    try truncated_frame.appendSlice(allocator, "ab");

    const truncated_stream = try std.mem.concat(allocator, u8, &.{ skip, truncated_frame.items });
    defer allocator.free(truncated_stream);
    if (vort.lz4DecodedNativeConcatenatedFrameSize(truncated_stream)) |_| return error.SizeMismatch else |err| switch (err) {
        error.TruncatedFrame => {},
        else => return err,
    }
    if (vort.lz4SummarizeNativeStream(truncated_stream)) |_| return error.SizeMismatch else |err| switch (err) {
        error.TruncatedFrame => {},
        else => return err,
    }

    var truncated_iterator = vort.lz4IterateNativeStream(truncated_stream);
    const truncated_first = (try truncated_iterator.next()) orelse return error.SizeMismatch;
    switch (truncated_first) {
        .frame => return error.SizeMismatch,
        .skippable => |skippable| {
            if (skippable.header.skippable_id != 4 or !std.mem.eql(u8, skippable.payload, "bench-meta")) {
                return error.SizeMismatch;
            }
        },
    }
    if (truncated_iterator.next()) |_| return error.SizeMismatch else |err| switch (err) {
        error.TruncatedFrame => {},
        else => return err,
    }

    const checksum_payload = "bench-checksum";
    const checksum_frame = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, checksum_payload, .{
        .content_checksum = true,
        .block_checksum = false,
    });
    defer allocator.free(checksum_frame);
    var bad_checksum_frame = try allocator.dupe(u8, checksum_frame);
    defer allocator.free(bad_checksum_frame);
    bad_checksum_frame[bad_checksum_frame.len - 1] ^= 0x01;
    const checksum_stream = try std.mem.concat(allocator, u8, &.{ skip, bad_checksum_frame });
    defer allocator.free(checksum_stream);

    if (try vort.lz4DecodedNativeConcatenatedFrameSize(checksum_stream) != checksum_payload.len) return error.SizeMismatch;
    var checksum_output: [checksum_payload.len]u8 = undefined;
    if (vort.lz4DecodeNativeConcatenatedFrameInto(checksum_stream, &checksum_output)) |_| {
        return error.SizeMismatch;
    } else |err| switch (err) {
        error.ChecksumMismatch => {},
        else => return err,
    }

    var checksum_iterator = vort.lz4IterateNativeStream(checksum_stream);
    _ = (try checksum_iterator.next()) orelse return error.SizeMismatch;
    const checksum_frame_element = (try checksum_iterator.next()) orelse return error.SizeMismatch;
    switch (checksum_frame_element) {
        .skippable => return error.SizeMismatch,
        .frame => |frame| if (!frame.header.content_checksum) return error.SizeMismatch,
    }
    if ((try checksum_iterator.next()) != null) return error.SizeMismatch;

    const trailing_payload = "bench-trailing";
    const trailing_frame = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, trailing_payload, .{
        .content_checksum = false,
        .block_checksum = false,
    });
    defer allocator.free(trailing_frame);
    const trailing_stream = try std.mem.concat(allocator, u8, &.{ skip, trailing_frame, "xx" });
    defer allocator.free(trailing_stream);
    if (vort.lz4SummarizeNativeStream(trailing_stream)) |_| return error.SizeMismatch else |err| switch (err) {
        error.TruncatedFrame => {},
        else => return err,
    }

    var trailing_iterator = vort.lz4IterateNativeStream(trailing_stream);
    _ = (try trailing_iterator.next()) orelse return error.SizeMismatch;
    const trailing_frame_element = (try trailing_iterator.next()) orelse return error.SizeMismatch;
    switch (trailing_frame_element) {
        .skippable => return error.SizeMismatch,
        .frame => |frame| {
            const decoded = try vort.lz4DecodeNativeFrameAlloc(allocator, frame.bytes);
            defer allocator.free(decoded);
            if (!std.mem.eql(u8, trailing_payload, decoded)) return error.SizeMismatch;
        },
    }
    if (trailing_iterator.next()) |_| return error.SizeMismatch else |err| switch (err) {
        error.TruncatedFrame => {},
        else => return err,
    }
}

fn smokeLz4DictionarySetSkippableFallback(allocator: std.mem.Allocator) !void {
    const first_dict = vort.Lz4NativeDictionary.init(0x4c5a_4501, lz4_dictionary_set_first_content);
    const second_dict = vort.Lz4NativeDictionary.init(0x4c5a_4502, lz4_dictionary_set_second_content);
    const dictionary_set = vort.Lz4NativeDictionarySet.init(&.{ first_dict, second_dict });
    const options: vort.Lz4NativeFrameOptions = .{
        .content_checksum = false,
        .block_checksum = true,
    };

    const first = try vort.lz4EncodeNativeFrameWithDictionarySetAlloc(allocator, lz4_dictionary_set_first_payload, options, dictionary_set, first_dict.id);
    defer allocator.free(first);
    const first_block = (try vort.lz4InspectNativeFrameFirstBlock(first)) orelse return error.SizeMismatch;
    if (!first_block.is_compressed) return error.SizeMismatch;
    const skip = try vort.lz4EncodeSkippableFrameAlloc(allocator, 6, "dict-fallback");
    defer allocator.free(skip);
    const second = try vort.lz4EncodeNativeFrameWithDictionarySetAlloc(allocator, lz4_dictionary_set_second_payload, options, dictionary_set, second_dict.id);
    defer allocator.free(second);
    const second_block = (try vort.lz4InspectNativeFrameFirstBlock(second)) orelse return error.SizeMismatch;
    if (!second_block.is_compressed) return error.SizeMismatch;
    const stream = try std.mem.concat(allocator, u8, &.{ first, skip, second });
    defer allocator.free(stream);

    const summary = try vort.lz4SummarizeNativeStream(stream);
    if (summary.frame_count != 2 or summary.skippable_frame_count != 1) return error.SizeMismatch;

    var output: [lz4_dictionary_set_payload.len]u8 = undefined;
    var direct_decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(allocator, dictionary_set, .{
        .expected_output_len = lz4_dictionary_set_payload.len,
        .max_decoded_buffer_len = @max(lz4_dictionary_set_first_payload.len, lz4_dictionary_set_second_payload.len),
        .input_policy = .prevalidated_frame,
    });
    defer direct_decoder.deinit();
    const direct_initial = try direct_decoder.step(stream, output[0..0]);
    if (direct_initial.status != .need_output) return error.SizeMismatch;
    if (!std.mem.eql(u8, direct_decoder.diagnostics().phase_name, "direct_output")) return error.SizeMismatch;
    const direct_done = try direct_decoder.step("", &output);
    if (direct_done.status != .done) return error.SizeMismatch;
    if (!std.mem.eql(u8, lz4_dictionary_set_payload, &output)) return error.SizeMismatch;
    if (direct_decoder.decodedBufferedBytes() != 0 or direct_decoder.decodedBufferCapacity() != 0) return error.SizeMismatch;
    if (direct_decoder.streamedCompressedBlockCount() != 0) return error.SizeMismatch;

    var decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(allocator, dictionary_set, .{
        .expected_output_len = lz4_dictionary_set_payload.len,
        .max_decoded_buffer_len = @max(lz4_dictionary_set_first_payload.len, lz4_dictionary_set_second_payload.len),
        .input_policy = .prevalidated_frame,
    });
    defer decoder.deinit();
    @memset(&output, 0);
    const initial = try decoder.step(stream, output[0..0]);
    if (initial.status != .need_output) return error.SizeMismatch;
    const first_len = @max(@as(usize, 1), output.len / 32);
    const first_step = try decoder.step("", output[0..first_len]);
    if (first_step.status != .need_output or first_step.progress.output_written != first_len) return error.SizeMismatch;
    if (!decoder.isCompressedBlockStreaming()) return error.SizeMismatch;
    if (decoder.decodedBufferedBytes() != 0 or decoder.decodedBufferCapacity() != 0) return error.SizeMismatch;
    if (decoder.streamedCompressedBlockCount() != 0) return error.SizeMismatch;

    var written = first_step.progress.output_written;
    while (true) {
        const result = try decoder.step("", output[written..]);
        written += result.progress.output_written;
        if (result.status == .done) break;
        if (result.status != .need_output or result.progress.output_written == 0) return error.SizeMismatch;
    }
    if (written != output.len or !std.mem.eql(u8, lz4_dictionary_set_payload, &output)) return error.SizeMismatch;
    if (decoder.decodedBufferedBytes() != 0 or decoder.decodedBufferCapacity() != 0) return error.SizeMismatch;
    // The tiny first drain forces frame one onto the cursor. Frame two then
    // sees the remaining caller buffer and completes through direct output.
    if (decoder.streamedCompressedBlockCount() != 1) return error.SizeMismatch;
}

fn smokeZstdDictionarySetSkippableFallback(allocator: std.mem.Allocator) !void {
    const first_dict = vort.ZstdNativeDictionary.init(0x5a53_4501, zstd_dictionary_set_first_content);
    const second_dict = vort.ZstdNativeDictionary.init(0x5a53_4502, zstd_dictionary_set_second_content);
    const dictionary_set = vort.ZstdNativeDictionarySet.init(&.{ first_dict, second_dict });
    const options: vort.ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = true,
    };

    const first = try vort.zstdEncodeNativeFrameWithDictionarySetAlloc(allocator, zstd_dictionary_set_first_payload, options, dictionary_set, first_dict.id);
    defer allocator.free(first.frame);
    const skip = try vort.zstdEncodeSkippableFrameAlloc(allocator, 6, "dict-fallback");
    defer allocator.free(skip);
    const second = try vort.zstdEncodeNativeFrameWithDictionarySetAlloc(allocator, zstd_dictionary_set_second_payload, options, dictionary_set, second_dict.id);
    defer allocator.free(second.frame);
    const stream = try std.mem.concat(allocator, u8, &.{ first.frame, skip, second.frame });
    defer allocator.free(stream);

    const summary = try vort.zstdSummarizeNativeStream(stream);
    if (summary.frame_count != 2 or summary.skippable_frame_count != 1) return error.SizeMismatch;

    var output: [zstd_dictionary_set_payload.len]u8 = undefined;
    var direct_decoder = vort.ZstdNativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(allocator, dictionary_set, .{
        .expected_output_len = zstd_dictionary_set_payload.len,
        .max_decoded_buffer_len = @max(zstd_dictionary_set_first_payload.len, zstd_dictionary_set_second_payload.len),
        .input_policy = .prevalidated_frame,
    });
    defer direct_decoder.deinit();
    const direct_initial = try direct_decoder.step(stream, output[0..0]);
    if (direct_initial.status != .need_output) return error.SizeMismatch;
    if (!std.mem.eql(u8, direct_decoder.diagnostics().phase_name, "direct_output")) return error.SizeMismatch;
    const direct_done = try direct_decoder.step("", &output);
    if (direct_done.status != .done) return error.SizeMismatch;
    if (!std.mem.eql(u8, zstd_dictionary_set_payload, &output)) return error.SizeMismatch;
    if (direct_decoder.decoded_scratch.items.len != 0) return error.SizeMismatch;

    var decoder = vort.ZstdNativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(allocator, dictionary_set, .{
        .expected_output_len = zstd_dictionary_set_payload.len,
        .max_decoded_buffer_len = @max(zstd_dictionary_set_first_payload.len, zstd_dictionary_set_second_payload.len),
        .input_policy = .prevalidated_frame,
    });
    defer decoder.deinit();
    @memset(&output, 0);
    const initial = try decoder.step(stream, output[0..0]);
    if (initial.status != .need_output) return error.SizeMismatch;
    const first_len = @max(@as(usize, 1), output.len / 32);
    const first_step = try decoder.step("", output[0..first_len]);
    if (first_step.status != .need_output or first_step.progress.output_written != first_len) return error.SizeMismatch;
    if (decoder.decodedBufferedBytes() != 0 or decoder.decodedBufferCapacity() != 0) return error.SizeMismatch;

    var written = first_step.progress.output_written;
    while (true) {
        const result = try decoder.step("", output[written..]);
        written += result.progress.output_written;
        if (result.status == .done) break;
        if (result.status != .need_output or result.progress.output_written == 0) return error.SizeMismatch;
    }
    if (written != output.len or !std.mem.eql(u8, zstd_dictionary_set_payload, &output)) return error.SizeMismatch;
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
        .input_policy = .prevalidated_frame,
    });
    defer decoder.deinit();
    var decoded: [payload.len]u8 = undefined;
    const first = try decoder.step(encoded.frame, decoded[0..0]);
    if (first.status != .need_output) return error.SizeMismatch;
    if (!std.mem.eql(u8, decoder.diagnostics().phase_name, "direct_output")) return error.SizeMismatch;
    const partial = try decoder.step("", decoded[0..17]);
    if (partial.status != .need_output or partial.progress.output_written != 17) return error.SizeMismatch;
    if (decoder.decodedBufferedBytes() != 0 or decoder.decodedBufferCapacity() != 0) return error.SizeMismatch;
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
    try expectSize(lz4_decoder.decodedChunksSize(&lz4_chunks, lz4_join), lz4_payload.len);
    try expectSize(lz4_decoder.decodedChunksSizeLimited(&lz4_chunks, lz4_join, lz4_payload.len), lz4_payload.len);
    try expectOutputLimit(lz4_decoder.decodedChunksSizeLimited(&lz4_chunks, lz4_join, lz4_payload.len - 1));
    const lz4_exact = try lz4_decoder.decodeChunksAllocExactSize(&lz4_chunks, lz4_join, lz4_payload.len);
    defer allocator.free(lz4_exact);
    if (!std.mem.eql(u8, lz4_payload, lz4_exact)) return error.SizeMismatch;
    try expectOutputLimitAlloc(allocator, lz4_decoder.decodeChunksAllocLimited(&lz4_chunks, lz4_join, lz4_payload.len - 1));
    var lz4_out: [lz4_payload.len]u8 = undefined;
    try expectRoundTrip(lz4_decoder.decodeChunksIntoSlice(&lz4_chunks, lz4_join, &lz4_out), lz4_payload, &lz4_out);
    const lz4_scratch = try lz4_decoder.decodeChunksScratch(&lz4_chunks, lz4_join);
    if (!std.mem.eql(u8, lz4_payload, lz4_scratch)) return error.SizeMismatch;
    var lz4_appended: std.ArrayList(u8) = .empty;
    defer lz4_appended.deinit(allocator);
    try lz4_appended.appendSlice(allocator, "prefix:");
    try expectSize(lz4_decoder.decodeChunksAppendExactSize(&lz4_appended, &lz4_chunks, lz4_join, lz4_payload.len), lz4_payload.len);
    if (!std.mem.eql(u8, lz4_appended.items, "prefix:" ++ lz4_payload)) return error.SizeMismatch;
    const lz4_concatenated_exact = try lz4_decoder.decodeConcatenatedChunksAllocExactSize(&lz4_chunks, lz4_join, lz4_payload.len);
    defer allocator.free(lz4_concatenated_exact);
    if (!std.mem.eql(u8, lz4_payload, lz4_concatenated_exact)) return error.SizeMismatch;

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
    try expectSize(zstd_decoder.decodedChunksSize(&zstd_chunks, zstd_join), zstd_payload.len);
    try expectSize(zstd_decoder.decodedChunksSizeLimited(&zstd_chunks, zstd_join, zstd_payload.len), zstd_payload.len);
    try expectOutputLimit(zstd_decoder.decodedChunksSizeLimited(&zstd_chunks, zstd_join, zstd_payload.len - 1));
    const zstd_exact = try zstd_decoder.decodeChunksAllocExactSize(&zstd_chunks, zstd_join, zstd_payload.len);
    defer allocator.free(zstd_exact);
    if (!std.mem.eql(u8, zstd_payload, zstd_exact)) return error.SizeMismatch;
    try expectOutputLimitAlloc(allocator, zstd_decoder.decodeChunksAllocLimited(&zstd_chunks, zstd_join, zstd_payload.len - 1));
    var zstd_out: [zstd_payload.len]u8 = undefined;
    try expectRoundTrip(zstd_decoder.decodeChunksIntoSlice(&zstd_chunks, zstd_join, &zstd_out), zstd_payload, &zstd_out);
    const zstd_scratch = try zstd_decoder.decodeChunksScratch(&zstd_chunks, zstd_join);
    if (!std.mem.eql(u8, zstd_payload, zstd_scratch)) return error.SizeMismatch;
    var zstd_appended: std.ArrayList(u8) = .empty;
    defer zstd_appended.deinit(allocator);
    try zstd_appended.appendSlice(allocator, "prefix:");
    try expectSize(zstd_decoder.decodeChunksAppendExactSize(&zstd_appended, &zstd_chunks, zstd_join, zstd_payload.len), zstd_payload.len);
    if (!std.mem.eql(u8, zstd_appended.items, "prefix:" ++ zstd_payload)) return error.SizeMismatch;
    const zstd_concatenated_exact = try zstd_decoder.decodeConcatenatedChunksAllocExactSize(&zstd_chunks, zstd_join, zstd_payload.len);
    defer allocator.free(zstd_concatenated_exact);
    if (!std.mem.eql(u8, zstd_payload, zstd_concatenated_exact)) return error.SizeMismatch;

    const lz4_dict = vort.Lz4NativeDictionary.init(0x4c5a_4301, "bench-lz4-history");
    const lz4_dictionary_set = vort.Lz4NativeDictionarySet.init(&.{lz4_dict});
    const lz4_dict_payload = "bench-lz4-history-payload";
    const lz4_dict_encoded = try vort.lz4EncodeNativeFrameWithDictionarySetAlloc(allocator, lz4_dict_payload, .{
        .content_checksum = false,
        .block_checksum = true,
    }, lz4_dictionary_set, lz4_dict.id);
    defer allocator.free(lz4_dict_encoded);
    const lz4_dict_chunks = [_][]const u8{
        lz4_dict_encoded[0..6],
        lz4_dict_encoded[6..],
    };
    const lz4_dict_join = try allocator.alloc(u8, lz4_dict_encoded.len);
    defer allocator.free(lz4_dict_join);
    try expectSize(lz4_decoder.decodedChunksSizeWithDictionarySet(&lz4_dict_chunks, lz4_dict_join, lz4_dictionary_set), lz4_dict_payload.len);
    try expectSize(lz4_decoder.decodedChunksSizeLimitedWithDictionarySet(&lz4_dict_chunks, lz4_dict_join, lz4_dict_payload.len, lz4_dictionary_set), lz4_dict_payload.len);
    try expectOutputLimit(lz4_decoder.decodedChunksSizeLimitedWithDictionarySet(&lz4_dict_chunks, lz4_dict_join, lz4_dict_payload.len - 1, lz4_dictionary_set));
    const lz4_dict_plain = try lz4_decoder.decodeChunksScratchWithDictionarySet(&lz4_dict_chunks, lz4_dict_join, lz4_dictionary_set);
    if (!std.mem.eql(u8, lz4_dict_payload, lz4_dict_plain)) return error.SizeMismatch;
    lz4_appended.clearRetainingCapacity();
    try lz4_appended.appendSlice(allocator, "prefix:");
    try expectSize(lz4_decoder.decodeChunksAppendExactSizeWithDictionarySet(&lz4_appended, &lz4_dict_chunks, lz4_dict_join, lz4_dictionary_set, lz4_dict_payload.len), lz4_dict_payload.len);
    if (!std.mem.eql(u8, lz4_appended.items, "prefix:" ++ lz4_dict_payload)) return error.SizeMismatch;

    const zstd_dict = vort.ZstdNativeDictionary.init(0x5a53_4301, "bench-zstd-history");
    const zstd_dictionary_set = vort.ZstdNativeDictionarySet.init(&.{zstd_dict});
    const zstd_dict_payload = "bench-zstd-history-payload";
    const zstd_dict_encoded = try vort.zstdEncodeNativeFrameWithDictionarySetAlloc(allocator, zstd_dict_payload, .{
        .selection = .literal_only,
        .content_checksum = false,
    }, zstd_dictionary_set, zstd_dict.id);
    defer allocator.free(zstd_dict_encoded.frame);
    const zstd_dict_chunks = [_][]const u8{
        zstd_dict_encoded.frame[0..8],
        zstd_dict_encoded.frame[8..],
    };
    const zstd_dict_join = try allocator.alloc(u8, zstd_dict_encoded.frame.len);
    defer allocator.free(zstd_dict_join);
    try expectSize(zstd_decoder.decodedChunksSizeWithDictionarySet(&zstd_dict_chunks, zstd_dict_join, zstd_dictionary_set), zstd_dict_payload.len);
    try expectSize(zstd_decoder.decodedChunksSizeLimitedWithDictionarySet(&zstd_dict_chunks, zstd_dict_join, zstd_dict_payload.len, zstd_dictionary_set), zstd_dict_payload.len);
    try expectOutputLimit(zstd_decoder.decodedChunksSizeLimitedWithDictionarySet(&zstd_dict_chunks, zstd_dict_join, zstd_dict_payload.len - 1, zstd_dictionary_set));
    const zstd_dict_plain = try zstd_decoder.decodeChunksScratchWithDictionarySet(&zstd_dict_chunks, zstd_dict_join, zstd_dictionary_set);
    if (!std.mem.eql(u8, zstd_dict_payload, zstd_dict_plain)) return error.SizeMismatch;
    zstd_appended.clearRetainingCapacity();
    try zstd_appended.appendSlice(allocator, "prefix:");
    try expectSize(zstd_decoder.decodeChunksAppendExactSizeWithDictionarySet(&zstd_appended, &zstd_dict_chunks, zstd_dict_join, zstd_dictionary_set, zstd_dict_payload.len), zstd_dict_payload.len);
    if (!std.mem.eql(u8, zstd_appended.items, "prefix:" ++ zstd_dict_payload)) return error.SizeMismatch;
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

fn smokeZstdAllCompressedSequenceTables(allocator: std.mem.Allocator) !void {
    // Keep one all-LL/OF/ML=FSE frame in the library benchmark smoke gate. The
    // frame probe has deeper diagnostics; this gate exists to ensure the same
    // sequence-table shape remains exercised by the common library entrypoints
    // that callers benchmark and integrate against.
    const frame_hex =
        "28b52ffd20f0d503004405616263646566676862636464656665666667686967686968696a6a6b6c6b6c6c6d6e6f6d6e6f6e6f70707172717272737475737475747576767778777878797a61797a617a61626263646364646566676566676620a810386b9d03c03e1068ed01a89eb45b9c8181d61f93e495416210faa3bd6039199102";
    const expected_hex =
        "616263646566676865666768626667686266636464646464646566646464646464656664646464646667686966676869676869696768696967686969676869696a6a6a6a6a6a6b6c6c6c6c6c6c6b6c6c6c6c6c6c6d6e6f6c6d6e6f6c6d6d6e6f6d6d6e6f6d6e6e6f6d6d6f70707070707070707172727272727271727272727272737475727374757273747572737475747374757273747576767676767676777878787878777877787878787878797a6178797a6178797a6178797a617a797a617879616262626262626364646464646464636464646464646465666764656667656667676566676765666767656667";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);
    var expected: [expected_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, expected_hex);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    const modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, first_block);
    if (modes.literal_length_mode != .compressed or
        modes.offset_mode != .compressed or
        modes.match_length_mode != .compressed) return error.SizeMismatch;
    if (try vort.zstdDecodedNativeFrameSize(&frame) != expected.len) return error.SizeMismatch;

    var decoded: [expected.len]u8 = undefined;
    try expectRoundTrip(vort.zstdDecodeNativeFrameInto(&frame, &decoded), &expected, &decoded);
    try decodeZstdIncremental(allocator, &frame, &decoded);
    if (!std.mem.eql(u8, &expected, &decoded)) return error.SizeMismatch;

    const chunks = [_][]const u8{
        frame[0..11],
        frame[11..89],
        frame[89..],
    };
    var join: [frame.len]u8 = undefined;
    try expectSize(vort.zstdDecodedNativeFrameChunksSize(&chunks, &join), expected.len);
    @memset(&decoded, 0);
    try expectRoundTrip(vort.zstdDecodeNativeFrameChunksInto(&chunks, &join, &decoded), &expected, &decoded);

    var decoder = vort.ZstdNativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    @memset(&decoded, 0);
    try expectRoundTrip(decoder.decodeChunksIntoSlice(&chunks, &join, &decoded), &expected, &decoded);
    const scratch = try decoder.decodeChunksScratch(&chunks, &join);
    if (!std.mem.eql(u8, &expected, scratch)) return error.SizeMismatch;

    const repeat_frame_hex =
        "28b52ffd600400a4020044036162636465666768696a6b6c6d6e6f7062636464656665666667686967686968696a6a6b6c6b6c6c6d6e6f6d6e6f6e6f7070717210a810386bdbdf106a1f1068ed01fb609ffe1f9f8fcdfb78fedfd865875345020044034142434445464748494a4b4c4d4e4f5042434444454645464647484947484948494a4a4b4c4b4c4c4d4e4f4d4e4f4e4f5050515210fcfb609ffe1f9f8fcdfb78fedfd8658753";
    const repeat_expected_hex =
        "6162636465666768696a6b6c6d6e6f706d6e6f70626e6f706d6e63646d6e6f70646566706465667064656670646566706667686964656670676869706768697067686970676869696a686970676a6b6c676a6b6c676b6c6c676a6b6c6d6e6f6c676b6c6c676d6e6f676d6e6f676e6e6f676d6f70676d6e6f676e7071726e7071726e4142434445464748494a4b4c4d4e4f504d4e4f50424e4f504d4e43444d4e4f50444546504445465044454650444546504647484944454650474849504748495047484950474849494a484950474a4b4c474a4b4c474b4c4c474a4b4c4d4e4f4c474b4c4c474d4e4f474d4e4f474e4e4f474d4f50474d4e4f474e5051524e5051524e";
    var repeat_frame: [repeat_frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&repeat_frame, repeat_frame_hex);
    var repeat_expected: [repeat_expected_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&repeat_expected, repeat_expected_hex);

    const repeat_first = try vort.zstdInspectNativeFrameFirstBlock(&repeat_frame);
    const repeat_first_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&repeat_frame, repeat_first);
    if (repeat_first_modes.literal_length_mode != .compressed or
        repeat_first_modes.offset_mode != .compressed or
        repeat_first_modes.match_length_mode != .compressed) return error.SizeMismatch;
    const repeat_second = try vort.zstdInspectNativeFrameBlockAt(&repeat_frame, repeat_first.next_header_offset);
    const repeat_second_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&repeat_frame, repeat_second);
    if (repeat_second_modes.literal_length_mode != .repeat or
        repeat_second_modes.offset_mode != .repeat or
        repeat_second_modes.match_length_mode != .repeat) return error.SizeMismatch;

    var repeat_decoded: [repeat_expected.len]u8 = undefined;
    try expectRoundTrip(vort.zstdDecodeNativeFrameInto(&repeat_frame, &repeat_decoded), &repeat_expected, &repeat_decoded);
    try decodeZstdIncremental(allocator, &repeat_frame, &repeat_decoded);
    if (!std.mem.eql(u8, &repeat_expected, &repeat_decoded)) return error.SizeMismatch;

    const repeat_chunks = [_][]const u8{
        repeat_frame[0..13],
        repeat_frame[13..101],
        repeat_frame[101..],
    };
    var repeat_join: [repeat_frame.len]u8 = undefined;
    try expectSize(vort.zstdDecodedNativeFrameChunksSize(&repeat_chunks, &repeat_join), repeat_expected.len);
    @memset(&repeat_decoded, 0);
    try expectRoundTrip(decoder.decodeChunksIntoSlice(&repeat_chunks, &repeat_join, &repeat_decoded), &repeat_expected, &repeat_decoded);
    const repeat_scratch = try decoder.decodeChunksScratch(&repeat_chunks, &repeat_join);
    if (!std.mem.eql(u8, &repeat_expected, repeat_scratch)) return error.SizeMismatch;
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

    const lz4_trained = try vort.lz4TrainNativeDictionaryAlloc(allocator, &lz4_trained_dictionary_samples, trained_dictionary_options);
    defer lz4_trained.deinit(allocator);
    const lz4_trained_dict = lz4_trained.asDictionary();
    const lz4_trained_plain = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, lz4_trained_dictionary_payload, lz4_options);
    defer allocator.free(lz4_trained_plain);
    const lz4_trained_frame = try vort.lz4EncodeNativeFrameWithDictionaryAlloc(allocator, lz4_trained_dictionary_payload, lz4_options, lz4_trained_dict);
    defer allocator.free(lz4_trained_frame);
    if (lz4_trained_frame.len >= lz4_trained_plain.len) return error.SizeMismatch;
    var lz4_trained_out: [lz4_trained_dictionary_payload.len]u8 = undefined;
    try expectRoundTrip(vort.lz4DecodeNativeFrameInto(lz4_trained_plain, &lz4_trained_out), lz4_trained_dictionary_payload, &lz4_trained_out);
    try expectRoundTrip(vort.lz4DecodeNativeFrameIntoWithDictionary(lz4_trained_frame, &lz4_trained_out, lz4_trained_dict), lz4_trained_dictionary_payload, &lz4_trained_out);

    const zstd_trained = try vort.zstdTrainNativeDictionaryAlloc(allocator, &zstd_trained_dictionary_samples, trained_dictionary_options);
    defer zstd_trained.deinit(allocator);
    const zstd_trained_dict = zstd_trained.asDictionary();
    const zstd_trained_plain = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, zstd_trained_dictionary_payload, zstd_options);
    defer allocator.free(zstd_trained_plain.frame);
    const zstd_trained_frame = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(allocator, zstd_trained_dictionary_payload, zstd_options, zstd_trained_dict);
    defer allocator.free(zstd_trained_frame.frame);
    if (zstd_trained_frame.frame.len >= zstd_trained_plain.frame.len) return error.SizeMismatch;
    var zstd_trained_out: [zstd_trained_dictionary_payload.len]u8 = undefined;
    try expectRoundTrip(vort.zstdDecodeNativeFrameInto(zstd_trained_plain.frame, &zstd_trained_out), zstd_trained_dictionary_payload, &zstd_trained_out);
    try expectRoundTrip(vort.zstdDecodeNativeFrameIntoWithDictionary(zstd_trained_frame.frame, &zstd_trained_out, zstd_trained_dict), zstd_trained_dictionary_payload, &zstd_trained_out);
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
    // The default bounded block-stream policy interleaves input and output;
    // drive both sides together (see drainIncremental).
    try drainIncremental(&decoder, encoded, decoded);
}

fn decodeLz4IncrementalDirect(allocator: std.mem.Allocator, encoded: []const u8, decoded: []u8) !void {
    var decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = decoded.len,
        .max_decoded_buffer_len = decoded.len,
        .input_policy = .prevalidated_frame,
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
        .input_policy = .prevalidated_frame,
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
        .input_policy = .prevalidated_frame,
    });
    defer decoder.deinit();
    try drainIncrementalFallback(&decoder, encoded, decoded, expected);
    if (decoder.decodedBufferedBytes() != 0 or decoder.decodedBufferCapacity() != 0) return error.SizeMismatch;
    if (decoder.streamedCompressedBlockCount() == 0) return error.SizeMismatch;
}

fn decodeZstdIncrementalFallback(allocator: std.mem.Allocator, encoded: []const u8, decoded: []u8, expected: []const u8) !void {
    var decoder = vort.ZstdNativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = decoded.len,
        .max_decoded_buffer_len = decoded.len,
        .input_policy = .prevalidated_frame,
    });
    defer decoder.deinit();
    try drainIncrementalFallback(&decoder, encoded, decoded, expected);
    if (decoder.decodedBufferedBytes() != 0 or decoder.decodedBufferCapacity() != 0) return error.SizeMismatch;
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
            .input_policy = .prevalidated_frame,
        })
    else
        vort.Lz4NativeIncrementalFrameDecoder.initWithOptions(allocator, .{
            .expected_output_len = decoded.len,
            .max_decoded_buffer_len = decoded.len,
            .input_policy = .prevalidated_frame,
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
            .input_policy = .prevalidated_frame,
        })
    else
        vort.ZstdNativeIncrementalFrameDecoder.initWithOptions(allocator, .{
            .expected_output_len = decoded.len,
            .max_decoded_buffer_len = decoded.len,
            .input_policy = .prevalidated_frame,
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
            .input_policy = .prevalidated_frame,
        })
    else
        vort.Lz4NativeIncrementalFrameDecoder.initWithOptions(allocator, .{
            .expected_output_len = decoded.len,
            .max_decoded_buffer_len = decoded.len,
            .input_policy = .prevalidated_frame,
        });
    defer decoder.deinit();
    try drainIncrementalFallback(&decoder, encoded, decoded, lz4_dictionary_set_payload);
    if (decoder.decodedBufferedBytes() != 0 or decoder.decodedBufferCapacity() != 0) return error.SizeMismatch;
    if (use_dictionary_set and decoder.streamedCompressedBlockCount() == 0) return error.SizeMismatch;
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
            .input_policy = .prevalidated_frame,
        })
    else
        vort.ZstdNativeIncrementalFrameDecoder.initWithOptions(allocator, .{
            .expected_output_len = decoded.len,
            .max_decoded_buffer_len = decoded.len,
            .input_policy = .prevalidated_frame,
        });
    defer decoder.deinit();
    try drainIncrementalFallback(&decoder, encoded, decoded, zstd_dictionary_set_payload);
    if (decoder.decodedBufferedBytes() != 0 or decoder.decodedBufferCapacity() != 0) return error.SizeMismatch;
}

fn drainIncrementalFallback(decoder: anytype, encoded: []const u8, decoded: []u8, expected: []const u8) !void {
    const initial = try decoder.step(encoded, decoded[0..0]);
    if (initial.status != .need_output) return error.SizeMismatch;

    // Drain in caller-sized fragments; block boundaries may write less than
    // the offered slice, so accept any positive output per step.
    var written: usize = 0;
    while (true) {
        const remaining = decoded.len - written;
        const fragment_len = @max(@as(usize, 1), remaining / 7 + 1);
        const result = try decoder.step("", decoded[written..@min(decoded.len, written + fragment_len)]);
        written += result.progress.output_written;
        if (result.status == .done) break;
        if (result.status != .need_output or result.progress.output_written == 0) return error.SizeMismatch;
    }
    if (written != expected.len) return error.SizeMismatch;
    if (!std.mem.eql(u8, expected, decoded[0..written])) return error.SizeMismatch;
}

fn drainDirectDictionarySet(decoder: anytype, encoded: []const u8, decoded: []u8, expected: []const u8) !void {
    // A concatenated dictionary stream contains several data frames. The
    // prevalidated direct path returns need_output after consuming a member
    // and may need the still-buffered tail; resume with the unconsumed input.
    var read: usize = 0;
    var written: usize = 0;
    var provide_input = true;
    while (true) {
        const input: []const u8 = if (provide_input) encoded[read..] else encoded[encoded.len..];
        const result = try decoder.step(input, decoded[written..]);
        read += result.progress.input_read;
        written += result.progress.output_written;
        if (result.status == .done) {
            if (read == encoded.len and written == expected.len) break;
            provide_input = read < encoded.len;
            continue;
        }
        provide_input = result.status == .need_input and read < encoded.len;
        if (!provide_input and result.status != .need_output) return error.SizeMismatch;
        if (!provide_input and result.progress.output_written == 0 and read >= encoded.len) return error.SizeMismatch;
    }
    if (!std.mem.eql(u8, expected, decoded[0..written])) return error.SizeMismatch;
}

fn drainIncremental(decoder: anytype, encoded: []const u8, decoded: []u8) !void {
    // Default bounded block-stream decoders interleave input and output:
    // they can request output after consuming part of the frame and resume
    // when fed more input. Drive both sides on every step (31-byte chunks).
    var read: usize = 0;
    var written: usize = 0;
    while (true) {
        const result = try decoder.step(
            encoded[read..@min(encoded.len, read + 31)],
            decoded[written..@min(decoded.len, written + 31)],
        );
        read += result.progress.input_read;
        written += result.progress.output_written;
        if (result.status == .done and read == encoded.len) break;
        if (result.progress.input_read == 0 and result.progress.output_written == 0) return error.SizeMismatch;
    }
    try decoder.finish();
    if (read != encoded.len or written != decoded.len) return error.SizeMismatch;
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

fn expectSize(size_result: anytype, expected: usize) !void {
    const size = try size_result;
    if (size != expected) return error.SizeMismatch;
}

fn expectOutputLimit(size_result: anytype) !void {
    if (size_result) |_| {
        return error.SizeMismatch;
    } else |err| switch (err) {
        error.OutputLimitExceeded => {},
        else => return err,
    }
}

fn expectOutputLimitAlloc(allocator: std.mem.Allocator, alloc_result: anytype) !void {
    if (alloc_result) |decoded| {
        allocator.free(decoded);
        return error.SizeMismatch;
    } else |err| switch (err) {
        error.OutputLimitExceeded => {},
        else => return err,
    }
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
        .lib_decode => "lib_decode",
        .native_lib_decode => "native_lib_decode",
        .chain_depth_0 => "chain_depth_0",
        .chain_depth_default => "chain_depth_default",
        .match_budget_0 => "match_budget_0",
        .match_budget_full => "match_budget_full",
        .high_byte_binary => "high_byte_binary",
        .lib_generated => "lib_generated",
        .lib_generated_no_size => "lib_generated_no_size",
        .lib_generated_checksum => "lib_generated_checksum",
        .lib_generated_no_size_checksum => "lib_generated_no_size_checksum",
        .lib_generated_independent => "lib_generated_independent",
        .lib_generated_independent_no_size_checksum => "lib_generated_independent_no_size_checksum",
        .sequence_huffman_literals_plain => "sequence_huffman_literals_plain",
        .sequence_huffman_literals => "sequence_huffman_literals",
        .dictionary_plain => "dictionary_plain",
        .dictionary => "dictionary",
        .trained_dictionary_plain => "trained_dictionary_plain",
        .trained_dictionary => "trained_dictionary",
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
