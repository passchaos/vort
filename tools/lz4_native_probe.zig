const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var stdout_buffer: [256]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const options = try parseOptions(init.gpa, &args);
    defer options.deinit(init.gpa);

    var cases = std.ArrayList(Case).empty;
    defer {
        for (cases.items) |case| {
            init.gpa.free(case.name);
            init.gpa.free(case.payload);
        }
        cases.deinit(init.gpa);
    }
    try addGeneratedCases(init.gpa, &cases);
    try addFileCases(init.io, init.gpa, &cases, options);

    var checked: usize = 0;
    for (cases.items) |case| {
        try checkFrameRoundTrips(init.gpa, case);
        try checkBlockRoundTrip(init.gpa, case);
        checked += 1;
    }
    try checkPrefixPreflight(init.gpa);
    checked += 1;
    try checkPrefixEncoder(init.gpa);
    checked += 1;
    try checkDictionaryFrame(init.gpa);
    checked += 1;
    try checkDictionarySetStreamInspection(init.gpa);
    checked += 1;
    try checkSplitHeaderIncremental(init.gpa);
    checked += 1;
    try checkSplitSkippableHeaderIncremental(init.gpa);
    checked += 1;
    try checkSkippableOnlyStream(init.gpa);
    checked += 1;
    try checkSkippableThenEmptyFrame(init.gpa);
    checked += 1;
    try checkEmptyFrameThenSkippable(init.gpa);
    checked += 1;
    try checkEmptySkippableThenPayloadFrame(init.gpa);
    checked += 1;
    try checkPayloadSkippableThenEmptyFrame(init.gpa);
    checked += 1;
    const lib_generated_cases = try checkLibLz4GeneratedLibraryFrames(init.gpa);
    checked += lib_generated_cases;
    checked += try checkSkippableMalformedStreams(init.gpa);
    checked += try checkSkippableChecksumAndTrailingStreams(init.gpa);
    checked += try checkInvalidFrameHeaders(init.gpa);
    checked += try checkInvalidFrameBlocks(init.gpa);
    checked += try checkInvalidFrameContentSizes(init.gpa);
    checked += try checkInvalidFrameChecksumsAndTrailing(init.gpa);

    try stdout.print("lz4_native_probe_ok cases={d}\n", .{checked});
    try printCoverage(stdout, "lz4_native_probe", checked, &.{
        "block",
        "bounded-limits",
        "checksum",
        "chunked",
        "reusable-chunked",
        "dictionary",
        "dictionary-set",
        "incremental",
        "lib-generated",
        "malformed",
        "native-generated",
        "skippable",
    }, &.{
        .{ .capability = "chunked", .cases = lib_generated_cases },
        .{ .capability = "reusable-chunked", .cases = lib_generated_cases },
        .{ .capability = "incremental", .cases = lib_generated_cases },
        .{ .capability = "lib-generated", .cases = lib_generated_cases },
    });
    try stdout.flush();
}

const CoverageCase = struct {
    capability: []const u8,
    cases: usize,
};

fn printCoverage(stdout: anytype, marker: []const u8, default_cases: usize, capabilities: []const []const u8, overrides: []const CoverageCase) !void {
    for (capabilities) |capability| {
        var cases = default_cases;
        for (overrides) |override| {
            if (std.mem.eql(u8, override.capability, capability)) {
                cases = override.cases;
                break;
            }
        }
        try stdout.print("{s}_coverage capability={s} cases={d}\n", .{ marker, capability, cases });
    }
}

const Case = struct {
    name: []const u8,
    payload: []u8,
};

const Options = struct {
    paths: std.ArrayList([]const u8) = .empty,
    dirs: std.ArrayList([]const u8) = .empty,
    limit: usize = 24 * 1024,
    max_files: usize = 8,

    fn deinit(self: Options, allocator: std.mem.Allocator) void {
        for (self.paths.items) |path| allocator.free(path);
        for (self.dirs.items) |dir| allocator.free(dir);
        var paths = self.paths;
        paths.deinit(allocator);
        var dirs = self.dirs;
        dirs.deinit(allocator);
    }
};

fn parseOptions(allocator: std.mem.Allocator, args: *std.process.Args.Iterator) !Options {
    var options: Options = .{};
    errdefer options.deinit(allocator);
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--path")) {
            const path = args.next() orelse return error.MissingPath;
            try options.paths.append(allocator, try allocator.dupe(u8, path));
        } else if (std.mem.eql(u8, arg, "--dir")) {
            const dir = args.next() orelse return error.MissingPath;
            try options.dirs.append(allocator, try allocator.dupe(u8, dir));
        } else if (std.mem.eql(u8, arg, "--limit")) {
            const text = args.next() orelse return error.MissingLimit;
            options.limit = try std.fmt.parseInt(usize, text, 10);
        } else if (std.mem.eql(u8, arg, "--max-files")) {
            const text = args.next() orelse return error.MissingLimit;
            options.max_files = try std.fmt.parseInt(usize, text, 10);
        } else {
            return error.UnknownArgument;
        }
    }
    return options;
}

fn addGeneratedCases(allocator: std.mem.Allocator, cases: *std.ArrayList(Case)) !void {
    try addGeneratedCase(allocator, cases, "empty", "");
    try addGeneratedCase(allocator, cases, "tiny", "hello");
    try addGeneratedCase(allocator, cases, "repeated", "abcd" ** 256);
    try addGeneratedCase(allocator, cases, "json", "{\"key\":\"value\",\"array\":[1,2,3],\"text\":\"abcdefg\"}\n" ** 128);

    var rng = std.Random.DefaultPrng.init(0x4c5a34);
    try cases.append(allocator, .{ .name = try allocator.dupe(u8, "printable"), .payload = try randomFromAlphabet(allocator, &rng, 4096, printable_alphabet) });
    try cases.append(allocator, .{ .name = try allocator.dupe(u8, "dna"), .payload = try randomFromAlphabet(allocator, &rng, 8192, "ACGTN") });
    try cases.append(allocator, .{ .name = try allocator.dupe(u8, "linked-tail-copy"), .payload = try linkedTailCopyPayload(allocator, &rng) });
}

fn addGeneratedCase(allocator: std.mem.Allocator, cases: *std.ArrayList(Case), name: []const u8, payload: []const u8) !void {
    try cases.append(allocator, .{ .name = try allocator.dupe(u8, name), .payload = try allocator.dupe(u8, payload) });
}

fn addFileCases(io: std.Io, allocator: std.mem.Allocator, cases: *std.ArrayList(Case), options: Options) !void {
    for (options.paths.items) |path| {
        try addFileCase(io, allocator, cases, path, options.limit);
    }

    var discovered: usize = 0;
    for (options.dirs.items) |dir_path| {
        var dir = try std.Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true });
        defer dir.close(io);
        var iter = dir.iterate();
        while (try iter.next(io)) |entry| {
            if (entry.kind != .file) continue;
            if (options.max_files != 0 and discovered >= options.max_files) return;
            const path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dir_path, entry.name });
            defer allocator.free(path);
            try addFileCase(io, allocator, cases, path, options.limit);
            discovered += 1;
        }
    }
}

fn addFileCase(io: std.Io, allocator: std.mem.Allocator, cases: *std.ArrayList(Case), path: []const u8, limit: usize) !void {
    const full_payload = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(128 * 1024 * 1024));
    const payload = if (limit != 0 and full_payload.len > limit) blk: {
        const truncated = try allocator.dupe(u8, full_payload[0..limit]);
        allocator.free(full_payload);
        break :blk truncated;
    } else full_payload;
    errdefer allocator.free(payload);
    try cases.append(allocator, .{ .name = try allocator.dupe(u8, path), .payload = payload });
}

const printable_alphabet =
    " !\"#$%&'()*+,-./0123456789:;<=>?@" ++
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~";

fn randomFromAlphabet(
    allocator: std.mem.Allocator,
    rng: *std.Random.DefaultPrng,
    len: usize,
    alphabet: []const u8,
) ![]u8 {
    const out = try allocator.alloc(u8, len);
    for (out) |*byte| byte.* = alphabet[rng.random().uintLessThan(usize, alphabet.len)];
    return out;
}

fn linkedTailCopyPayload(allocator: std.mem.Allocator, rng: *std.Random.DefaultPrng) ![]u8 {
    const first_block_len = 64 * 1024;
    const second_block_len = 4 * 1024;
    const out = try allocator.alloc(u8, first_block_len + second_block_len);
    rng.random().bytes(out[0..first_block_len]);
    @memcpy(out[first_block_len..], out[first_block_len - second_block_len .. first_block_len]);
    return out;
}

fn checkFrameRoundTrips(allocator: std.mem.Allocator, case: Case) !void {
    const lib_frame = try vort.lz4EncodeFrameAlloc(allocator, case.payload);
    defer allocator.free(lib_frame);
    const native_decoded = try vort.lz4DecodeNativeFrameAlloc(allocator, lib_frame);
    defer allocator.free(native_decoded);
    try expectPayload(case, native_decoded);
    var lib_appended: std.ArrayList(u8) = .empty;
    defer lib_appended.deinit(allocator);
    try lib_appended.appendSlice(allocator, "prefix:");
    const lib_appended_written = try vort.lz4DecodeFrameAppendExactSize(allocator, &lib_appended, lib_frame, case.payload.len);
    if (lib_appended_written != case.payload.len) return error.Lz4ProbeSizeMismatch;
    if (lib_appended.items.len != "prefix:".len + case.payload.len) return error.Lz4ProbeSizeMismatch;
    if (!std.mem.eql(u8, lib_appended.items[0.."prefix:".len], "prefix:")) return error.Lz4ProbeMismatch;
    if (!std.mem.eql(u8, lib_appended.items["prefix:".len..], case.payload)) return error.Lz4ProbeMismatch;
    lib_appended.clearRetainingCapacity();
    if (vort.lz4DecodeFrameAppendExactSize(allocator, &lib_appended, lib_frame, case.payload.len + 1)) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| switch (err) {
        error.SizeMismatch => {},
        else => return err,
    }

    const native_frame = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, case.payload, .{
        .content_checksum = true,
        .include_content_size = true,
        .block_checksum = true,
    });
    defer allocator.free(native_frame);
    const native_stream_summary = try vort.lz4SummarizeNativeStream(native_frame);
    if (native_stream_summary.frame_count != 1) return error.Lz4ProbeMismatch;
    if (native_stream_summary.block_count == 0 and case.payload.len != 0) return error.Lz4ProbeMismatch;
    if (native_stream_summary.skippable_frame_count != 0) return error.Lz4ProbeMismatch;
    if (native_stream_summary.payload_bytes == 0 and case.payload.len != 0) return error.Lz4ProbeMismatch;
    const native_block_summary = try vort.lz4SummarizeNativeFrameBlocks(native_frame);
    if (native_block_summary.block_count != native_stream_summary.block_count) return error.Lz4ProbeMismatch;
    if (native_block_summary.compressed_block_count != native_stream_summary.compressed_block_count) return error.Lz4ProbeMismatch;
    if (native_block_summary.raw_block_count != native_stream_summary.raw_block_count) return error.Lz4ProbeMismatch;
    const lib_decoded = try vort.lz4DecodeFrameAlloc(allocator, native_frame);
    defer allocator.free(lib_decoded);
    try expectPayload(case, lib_decoded);
    var native_appended: std.ArrayList(u8) = .empty;
    defer native_appended.deinit(allocator);
    try native_appended.appendSlice(allocator, "prefix:");
    const native_appended_written = try vort.lz4DecodeNativeFrameAppendExactSize(allocator, &native_appended, native_frame, case.payload.len);
    if (native_appended_written != case.payload.len) return error.Lz4ProbeSizeMismatch;
    if (native_appended.items.len != "prefix:".len + case.payload.len) return error.Lz4ProbeSizeMismatch;
    if (!std.mem.eql(u8, native_appended.items[0.."prefix:".len], "prefix:")) return error.Lz4ProbeMismatch;
    if (!std.mem.eql(u8, native_appended.items["prefix:".len..], case.payload)) return error.Lz4ProbeMismatch;
    native_appended.clearRetainingCapacity();
    if (vort.lz4DecodeNativeFrameAppendExactSize(allocator, &native_appended, native_frame, case.payload.len + 1)) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| switch (err) {
        error.SizeMismatch => {},
        else => return err,
    }

    const shallow_chain_frame = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, case.payload, .{
        .content_checksum = false,
        .include_content_size = true,
        .block_checksum = true,
        .chain_depth = 4,
    });
    defer allocator.free(shallow_chain_frame);
    const shallow_decoded = try vort.lz4DecodeNativeFrameAlloc(allocator, shallow_chain_frame);
    defer allocator.free(shallow_decoded);
    try expectPayload(case, shallow_decoded);
    if (vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, case.payload, .{
        .chain_depth = 255,
    })) |invalid_frame| {
        allocator.free(invalid_frame);
        return error.Lz4ProbeExpectedInvalidBlockPlan;
    } else |err| switch (err) {
        error.InvalidBlockPlan => {},
        else => return err,
    }

    if (case.payload.len > 64 * 1024) {
        const linked_native_frame = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, case.payload, .{
            .content_checksum = true,
            .include_content_size = true,
            .block_checksum = true,
            .block_size_id = .max64kb,
            .block_mode = .linked,
        });
        defer allocator.free(linked_native_frame);
        const decoded_len = try vort.lz4DecodedFrameSize(linked_native_frame);
        if (decoded_len != case.payload.len) return error.Lz4ProbeSizeMismatch;
        const linked_decoded = try vort.lz4DecodeNativeFrameAlloc(allocator, linked_native_frame);
        defer allocator.free(linked_decoded);
        try expectPayload(case, linked_decoded);
        try checkLinkedFrameInspection(case, linked_native_frame);
        try checkLinkedDirectFallback(allocator, case, linked_native_frame);
    }
}

fn checkLinkedFrameInspection(case: Case, frame: []const u8) !void {
    const header = try vort.lz4InspectNativeFrameHeader(frame);
    if (header.block_independent) return error.Lz4ProbeMismatch;
    if (!header.block_checksum or !header.content_checksum) return error.Lz4ProbeMismatch;
    if (header.expected_content_size == null or header.expected_content_size.? != case.payload.len) return error.Lz4ProbeSizeMismatch;

    const summary = try vort.lz4SummarizeNativeFrameBlocks(frame);
    if (summary.block_count < 2) return error.Lz4ProbeSizeMismatch;
    if (summary.compressed_block_count == 0) return error.Lz4ProbeMismatch;
    if (summary.raw_block_count == 0) return error.Lz4ProbeMismatch;

    var iterator = try vort.lz4IterateNativeFrameBlocks(frame);
    var iterated_blocks: usize = 0;
    var iterated_payload_bytes: usize = 0;
    var saw_compressed = false;
    var saw_raw = false;
    while (try iterator.next()) |block| {
        iterated_blocks += 1;
        iterated_payload_bytes += block.payload_len;
        saw_compressed = saw_compressed or block.is_compressed;
        saw_raw = saw_raw or !block.is_compressed;
        if (block.block_checksum_offset == null) return error.Lz4ProbeMismatch;
    }
    if (iterated_blocks != summary.block_count) return error.Lz4ProbeSizeMismatch;
    if (iterated_payload_bytes != summary.payload_bytes) return error.Lz4ProbeSizeMismatch;
    if (!saw_compressed or !saw_raw) return error.Lz4ProbeMismatch;
}

fn checkLinkedDirectFallback(allocator: std.mem.Allocator, case: Case, frame: []const u8) !void {
    const first_block = (try vort.lz4InspectNativeFrameFirstBlock(frame)) orelse return error.Lz4ProbeSizeMismatch;
    const second_block = (try vort.lz4InspectNativeFrameBlockAt(frame, first_block.next_header_offset)) orelse return error.Lz4ProbeSizeMismatch;
    if (first_block.is_compressed or !second_block.is_compressed) return;

    var decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = case.payload.len,
        .max_decoded_buffer_len = case.payload.len,
    });
    defer decoder.deinit();
    const output = try allocator.alloc(u8, case.payload.len);
    defer allocator.free(output);
    const initial = try decoder.step(frame, output[0..0]);
    if (initial.status != .need_output) return error.Lz4ProbeMismatch;
    if (!std.mem.eql(u8, "direct_output", decoder.diagnostics().phase_name)) return error.Lz4ProbeMismatch;
    const first = try decoder.step("", output[0 .. 64 * 1024]);
    if (first.status != .need_output) return error.Lz4ProbeMismatch;
    if (first.progress.output_written != 64 * 1024) return error.Lz4ProbeSizeMismatch;
    if (decoder.decoded_scratch.items.len != 0) return error.Lz4ProbeMismatch;
    const partial = try decoder.step("", output[64 * 1024 ..][0..127]);
    if (partial.status != .need_output) return error.Lz4ProbeMismatch;
    if (partial.progress.output_written != 127) return error.Lz4ProbeSizeMismatch;
    if (decoder.decoded_scratch.items.len != case.payload.len) return error.Lz4ProbeSizeMismatch;
    const done = try decoder.step("", output[64 * 1024 + 127 ..]);
    if (done.status != .done) return error.Lz4ProbeMismatch;
    try expectPayload(case, output);
}

fn checkBlockRoundTrip(allocator: std.mem.Allocator, case: Case) !void {
    const block = try vort.lz4EncodeBlockAlloc(allocator, case.payload);
    defer allocator.free(block);
    const decoded_len = try vort.lz4DecodedBlockSize(block);
    if (decoded_len != case.payload.len) return error.Lz4ProbeSizeMismatch;
    const decoded = try vort.lz4DecodeBlockAlloc(allocator, block, case.payload.len);
    defer allocator.free(decoded);
    try expectPayload(case, decoded);

    const depth_block = try vort.lz4EncodeBlockWithChainDepthAlloc(allocator, case.payload, 4);
    defer allocator.free(depth_block);
    const depth_decoded = try vort.lz4DecodeBlockAlloc(allocator, depth_block, case.payload.len);
    defer allocator.free(depth_decoded);
    try expectPayload(case, depth_decoded);

    var encoder = try vort.Lz4BlockEncoder.init(allocator);
    defer encoder.deinit();
    const scratch = try encoder.encodeScratchWithChainDepth(case.payload, 4);
    const scratch_decoded = try vort.lz4DecodeBlockAlloc(allocator, scratch, case.payload.len);
    defer allocator.free(scratch_decoded);
    try expectPayload(case, scratch_decoded);
}

fn checkPrefixPreflight(allocator: std.mem.Allocator) !void {
    const prefix = "abcdefghijklmnop";
    const prefix_match = [_]u8{ 0x04, 4, 0 };
    if (vort.lz4DecodedBlockSize(&prefix_match)) |_| {
        return error.Lz4ProbeExpectedInvalidMatch;
    } else |err| switch (err) {
        error.InvalidMatch => {},
        else => return err,
    }
    if (try vort.lz4DecodedBlockSizeWithPrefix(&prefix_match, prefix) != 8) {
        return error.Lz4ProbeSizeMismatch;
    }
    if (try vort.lz4DecodedBlockSizeWithPrefixLimited(&prefix_match, prefix, 8) != 8) {
        return error.Lz4ProbeSizeMismatch;
    }
    if (vort.lz4DecodedBlockSizeWithPrefixLimited(&prefix_match, prefix, 7)) |_| {
        return error.Lz4ProbeExpectedOutputLimit;
    } else |err| switch (err) {
        error.OutputLimitExceeded => {},
        else => return err,
    }

    const decoded = try vort.lz4DecodeBlockWithPrefixAlloc(allocator, &prefix_match, 8, prefix);
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, "mnopmnop", decoded)) return error.Lz4ProbeMismatch;

    var into_buffer: [8]u8 = undefined;
    const written = try vort.lz4DecodeBlockWithPrefixIntoSlice(allocator, &prefix_match, &into_buffer, 8, prefix);
    if (written != into_buffer.len) return error.Lz4ProbeSizeMismatch;
    if (!std.mem.eql(u8, "mnopmnop", &into_buffer)) return error.Lz4ProbeMismatch;
    if (vort.lz4DecodeBlockWithPrefixIntoSlice(allocator, &prefix_match, into_buffer[0..7], 8, prefix)) |_| {
        return error.Lz4ProbeExpectedOutputLimit;
    } else |err| switch (err) {
        error.OutputTooSmall => {},
        else => return err,
    }
}

fn checkPrefixEncoder(allocator: std.mem.Allocator) !void {
    const prefix_len = 64 * 1024;
    const block_len = 4 * 1024;
    const prefix = try allocator.alloc(u8, prefix_len);
    defer allocator.free(prefix);
    const payload = try allocator.alloc(u8, block_len);
    defer allocator.free(payload);

    var state: u32 = 0x51ed_1234;
    for (prefix) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(payload, prefix[prefix.len - payload.len ..]);

    const encoded = try vort.lz4EncodeBlockWithPrefixAlloc(allocator, payload, prefix);
    defer allocator.free(encoded);
    if (encoded.len >= payload.len) return error.Lz4ProbeSizeMismatch;
    if (try vort.lz4DecodedBlockSizeWithPrefix(encoded, prefix) != payload.len) {
        return error.Lz4ProbeSizeMismatch;
    }

    const decoded = try vort.lz4DecodeBlockWithPrefixAlloc(allocator, encoded, payload.len, prefix);
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, payload, decoded)) return error.Lz4ProbeMismatch;

    const block_bound = try vort.lz4EncodedBlockBound(payload.len);
    const encoded_into = try allocator.alloc(u8, block_bound);
    defer allocator.free(encoded_into);
    const written = try vort.lz4EncodeBlockWithPrefixIntoSlice(allocator, payload, prefix, encoded_into);
    if (!std.mem.eql(u8, encoded, encoded_into[0..written])) return error.Lz4ProbeMismatch;
    const depth_written = try vort.lz4EncodeBlockWithPrefixIntoSliceAndChainDepth(allocator, payload, prefix, encoded_into, 4);
    const depth_decoded = try vort.lz4DecodeBlockWithPrefixAlloc(allocator, encoded_into[0..depth_written], payload.len, prefix);
    defer allocator.free(depth_decoded);
    if (!std.mem.eql(u8, payload, depth_decoded)) return error.Lz4ProbeMismatch;
    if (vort.lz4EncodeBlockWithPrefixIntoSlice(allocator, payload, prefix, encoded_into[0 .. written - 1])) |_| {
        return error.Lz4ProbeExpectedOutputLimit;
    } else |err| switch (err) {
        error.OutputTooSmall => {},
        else => return err,
    }
}

fn checkDictionaryFrame(allocator: std.mem.Allocator) !void {
    const dict = vort.Lz4NativeDictionary.init(0x1234_abcd, "abcdefghijklmnop");
    const payload = "abcdefghijklmnop-tail";
    const encoded = try vort.lz4EncodeNativeFrameWithDictionaryAlloc(allocator, payload, .{
        .content_checksum = false,
        .block_checksum = true,
    }, dict);
    defer allocator.free(encoded);

    const header = try vort.lz4InspectNativeFrameHeader(encoded);
    if (header.dictionary_id != dict.id) return error.Lz4ProbeMismatch;
    if (vort.lz4DecodeNativeFrameAlloc(allocator, encoded)) |decoded_without_dict| {
        allocator.free(decoded_without_dict);
        return error.Lz4ProbeExpectedInvalidMatch;
    } else |err| switch (err) {
        error.NeedDictionary => {},
        else => return err,
    }

    const wrong = vort.Lz4NativeDictionary.init(dict.id + 1, dict.content);
    try expectNeedDictionary(vort.lz4DecodedNativeFrameSizeWithDictionary(encoded, wrong));
    var wrong_output: [payload.len]u8 = undefined;
    try expectNeedDictionary(vort.lz4DecodeNativeFrameIntoWithDictionary(encoded, &wrong_output, wrong));
    try expectAllocNeedDictionary(allocator, vort.lz4DecodeNativeFrameAllocWithDictionary(allocator, encoded, wrong));

    const checksummed = try vort.lz4EncodeNativeFrameWithDictionaryAlloc(allocator, payload, .{
        .content_checksum = true,
        .block_checksum = true,
    }, dict);
    defer allocator.free(checksummed);
    var wrong_checksum = try allocator.dupe(u8, checksummed);
    defer allocator.free(wrong_checksum);
    wrong_checksum[wrong_checksum.len - 1] ^= 0x01;
    const checksummed_header = try vort.lz4InspectNativeFrameHeader(wrong_checksum);
    if (checksummed_header.dictionary_id != dict.id or !checksummed_header.content_checksum) {
        return error.Lz4ProbeMismatch;
    }
    try expectNeedDictionary(vort.lz4DecodedNativeFrameSize(wrong_checksum));
    try expectNeedDictionary(vort.lz4DecodedNativeFrameSizeWithDictionary(wrong_checksum, wrong));
    var checksum_priority_output: [payload.len]u8 = undefined;
    try expectNeedDictionary(vort.lz4DecodeNativeFrameInto(wrong_checksum, &checksum_priority_output));
    try expectNeedDictionary(vort.lz4DecodeNativeFrameIntoWithDictionary(wrong_checksum, &checksum_priority_output, wrong));
    try expectAllocNeedDictionary(allocator, vort.lz4DecodeNativeFrameAlloc(allocator, wrong_checksum));
    try expectAllocNeedDictionary(allocator, vort.lz4DecodeNativeFrameAllocWithDictionary(allocator, wrong_checksum, wrong));
    if (try vort.lz4DecodedNativeFrameSizeWithDictionary(wrong_checksum, dict) != payload.len) return error.Lz4ProbeSizeMismatch;
    if (vort.lz4DecodeNativeFrameIntoWithDictionary(wrong_checksum, &checksum_priority_output, dict)) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| switch (err) {
        error.ChecksumMismatch => {},
        else => return err,
    }
    if (vort.lz4DecodeNativeFrameAllocWithDictionary(allocator, wrong_checksum, dict)) |bad_checksum_decoded| {
        allocator.free(bad_checksum_decoded);
        return error.Lz4ProbeExpectedFrameError;
    } else |err| switch (err) {
        error.ChecksumMismatch => {},
        else => return err,
    }
    var missing_checksum_decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer missing_checksum_decoder.deinit();
    try expectNeedDictionary(missing_checksum_decoder.step(wrong_checksum, checksum_priority_output[0..0]));
    if (!std.mem.eql(u8, "NeedDictionary", missing_checksum_decoder.diagnostics().last_error_name)) {
        return error.Lz4ProbeMismatch;
    }
    if (!std.mem.eql(u8, "frame", missing_checksum_decoder.diagnostics().last_error_phase_name)) {
        return error.Lz4ProbeMismatch;
    }
    var bad_checksum_decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithDictionaryAndOptions(allocator, dict, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer bad_checksum_decoder.deinit();
    const bad_checksum_initial = try bad_checksum_decoder.step(wrong_checksum, checksum_priority_output[0..0]);
    if (bad_checksum_initial.status != .need_output) return error.Lz4ProbeMismatch;
    try expectError(error.ChecksumMismatch, bad_checksum_decoder.step("", &checksum_priority_output));
    if (!std.mem.eql(u8, "ChecksumMismatch", bad_checksum_decoder.diagnostics().last_error_name)) {
        return error.Lz4ProbeMismatch;
    }
    if (!std.mem.eql(u8, "direct_output", bad_checksum_decoder.diagnostics().last_error_phase_name)) {
        return error.Lz4ProbeMismatch;
    }

    var wrong_block_checksum = try allocator.dupe(u8, encoded);
    defer allocator.free(wrong_block_checksum);
    const checksum_priority_block = (try vort.lz4InspectNativeFrameFirstBlock(wrong_block_checksum)) orelse {
        return error.Lz4ProbeMismatch;
    };
    if (checksum_priority_block.block_checksum_offset == null) return error.Lz4ProbeMismatch;
    wrong_block_checksum[checksum_priority_block.block_checksum_offset.?] ^= 0x01;
    try expectNeedDictionary(vort.lz4DecodedNativeFrameSize(wrong_block_checksum));
    try expectNeedDictionary(vort.lz4DecodedNativeFrameSizeWithDictionary(wrong_block_checksum, wrong));
    var block_checksum_priority_output: [payload.len]u8 = undefined;
    try expectNeedDictionary(vort.lz4DecodeNativeFrameInto(wrong_block_checksum, &block_checksum_priority_output));
    try expectNeedDictionary(vort.lz4DecodeNativeFrameIntoWithDictionary(wrong_block_checksum, &block_checksum_priority_output, wrong));
    try expectAllocNeedDictionary(allocator, vort.lz4DecodeNativeFrameAlloc(allocator, wrong_block_checksum));
    try expectAllocNeedDictionary(allocator, vort.lz4DecodeNativeFrameAllocWithDictionary(allocator, wrong_block_checksum, wrong));
    try expectError(error.ChecksumMismatch, vort.lz4DecodedNativeFrameSizeWithDictionary(wrong_block_checksum, dict));
    try expectError(error.ChecksumMismatch, vort.lz4DecodeNativeFrameIntoWithDictionary(wrong_block_checksum, &block_checksum_priority_output, dict));
    try expectAllocError(allocator, error.ChecksumMismatch, vort.lz4DecodeNativeFrameAllocWithDictionary(allocator, wrong_block_checksum, dict));
    var missing_block_checksum_decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer missing_block_checksum_decoder.deinit();
    try expectNeedDictionary(missing_block_checksum_decoder.step(wrong_block_checksum, block_checksum_priority_output[0..0]));
    if (!std.mem.eql(u8, "NeedDictionary", missing_block_checksum_decoder.diagnostics().last_error_name)) {
        return error.Lz4ProbeMismatch;
    }
    if (!std.mem.eql(u8, "frame", missing_block_checksum_decoder.diagnostics().last_error_phase_name)) {
        return error.Lz4ProbeMismatch;
    }
    var bad_block_checksum_decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithDictionaryAndOptions(allocator, dict, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer bad_block_checksum_decoder.deinit();
    try expectError(error.ChecksumMismatch, bad_block_checksum_decoder.step(wrong_block_checksum, block_checksum_priority_output[0..0]));
    if (!std.mem.eql(u8, "ChecksumMismatch", bad_block_checksum_decoder.diagnostics().last_error_name)) {
        return error.Lz4ProbeMismatch;
    }
    if (!std.mem.eql(u8, "frame", bad_block_checksum_decoder.diagnostics().last_error_phase_name)) {
        return error.Lz4ProbeMismatch;
    }

    const invalid_match = try frameWithSingleBlockAndDictionary(
        allocator,
        0x61, // Dictionary_ID.
        0x40,
        4,
        "\x10a\x00\x00",
        "\x00\x00\x00\x00",
        dict.id,
    );
    defer allocator.free(invalid_match);
    const invalid_match_header = try vort.lz4InspectNativeFrameHeader(invalid_match);
    if (invalid_match_header.dictionary_id != dict.id) return error.Lz4ProbeMismatch;
    try expectNeedDictionary(vort.lz4DecodedNativeFrameSize(invalid_match));
    try expectNeedDictionary(vort.lz4DecodedNativeFrameSizeWithDictionary(invalid_match, wrong));
    var invalid_match_output: [payload.len]u8 = undefined;
    try expectNeedDictionary(vort.lz4DecodeNativeFrameInto(invalid_match, &invalid_match_output));
    try expectNeedDictionary(vort.lz4DecodeNativeFrameIntoWithDictionary(invalid_match, &invalid_match_output, wrong));
    try expectAllocNeedDictionary(allocator, vort.lz4DecodeNativeFrameAlloc(allocator, invalid_match));
    try expectAllocNeedDictionary(allocator, vort.lz4DecodeNativeFrameAllocWithDictionary(allocator, invalid_match, wrong));
    try expectError(error.InvalidMatch, vort.lz4DecodedNativeFrameSizeWithDictionary(invalid_match, dict));
    try expectError(error.InvalidMatch, vort.lz4DecodeNativeFrameIntoWithDictionary(invalid_match, &invalid_match_output, dict));
    try expectAllocError(allocator, error.InvalidMatch, vort.lz4DecodeNativeFrameAllocWithDictionary(allocator, invalid_match, dict));
    var missing_invalid_match_decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = invalid_match_output.len,
        .max_decoded_buffer_len = invalid_match_output.len,
    });
    defer missing_invalid_match_decoder.deinit();
    try expectNeedDictionary(missing_invalid_match_decoder.step(invalid_match, invalid_match_output[0..0]));
    if (!std.mem.eql(u8, "NeedDictionary", missing_invalid_match_decoder.diagnostics().last_error_name)) {
        return error.Lz4ProbeMismatch;
    }
    if (!std.mem.eql(u8, "frame", missing_invalid_match_decoder.diagnostics().last_error_phase_name)) {
        return error.Lz4ProbeMismatch;
    }
    var invalid_match_decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithDictionaryAndOptions(allocator, dict, .{
        .expected_output_len = invalid_match_output.len,
        .max_decoded_buffer_len = invalid_match_output.len,
    });
    defer invalid_match_decoder.deinit();
    try expectError(error.InvalidMatch, invalid_match_decoder.step(invalid_match, invalid_match_output[0..0]));
    if (!std.mem.eql(u8, "InvalidMatch", invalid_match_decoder.diagnostics().last_error_name)) {
        return error.Lz4ProbeMismatch;
    }
    if (!std.mem.eql(u8, "frame", invalid_match_decoder.diagnostics().last_error_phase_name)) {
        return error.Lz4ProbeMismatch;
    }

    const size_mismatch = try frameWithSingleBlockAndContentSizeAndDictionary(
        allocator,
        0x69, // Content Size + Dictionary_ID.
        0x40,
        payload.len + 1,
        0x8000_0000 | payload.len,
        payload,
        "\x00\x00\x00\x00",
        dict.id,
    );
    defer allocator.free(size_mismatch);
    const size_mismatch_header = try vort.lz4InspectNativeFrameHeader(size_mismatch);
    if (size_mismatch_header.dictionary_id != dict.id or size_mismatch_header.expected_content_size == null or size_mismatch_header.expected_content_size.? != payload.len + 1) {
        return error.Lz4ProbeMismatch;
    }
    var size_priority_output: [payload.len + 1]u8 = undefined;
    try expectNeedDictionary(vort.lz4DecodedNativeFrameSize(size_mismatch));
    try expectNeedDictionary(vort.lz4DecodedNativeFrameSizeWithDictionary(size_mismatch, wrong));
    try expectNeedDictionary(vort.lz4DecodeNativeFrameInto(size_mismatch, &size_priority_output));
    try expectNeedDictionary(vort.lz4DecodeNativeFrameIntoWithDictionary(size_mismatch, &size_priority_output, wrong));
    try expectAllocNeedDictionary(allocator, vort.lz4DecodeNativeFrameAlloc(allocator, size_mismatch));
    try expectAllocNeedDictionary(allocator, vort.lz4DecodeNativeFrameAllocWithDictionary(allocator, size_mismatch, wrong));
    try expectError(error.SizeMismatch, vort.lz4DecodedNativeFrameSizeWithDictionary(size_mismatch, dict));
    try expectError(error.SizeMismatch, vort.lz4DecodeNativeFrameIntoWithDictionary(size_mismatch, &size_priority_output, dict));
    try expectAllocError(allocator, error.SizeMismatch, vort.lz4DecodeNativeFrameAllocWithDictionary(allocator, size_mismatch, dict));
    var missing_size_decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = size_priority_output.len,
        .max_decoded_buffer_len = size_priority_output.len,
    });
    defer missing_size_decoder.deinit();
    try expectNeedDictionary(missing_size_decoder.step(size_mismatch, size_priority_output[0..0]));
    if (!std.mem.eql(u8, "NeedDictionary", missing_size_decoder.diagnostics().last_error_name)) {
        return error.Lz4ProbeMismatch;
    }
    if (!std.mem.eql(u8, "frame", missing_size_decoder.diagnostics().last_error_phase_name)) {
        return error.Lz4ProbeMismatch;
    }
    var size_mismatch_decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithDictionaryAndOptions(allocator, dict, .{
        .expected_output_len = size_priority_output.len,
        .max_decoded_buffer_len = size_priority_output.len,
    });
    defer size_mismatch_decoder.deinit();
    try expectError(error.SizeMismatch, size_mismatch_decoder.step(size_mismatch, size_priority_output[0..0]));
    if (!std.mem.eql(u8, "SizeMismatch", size_mismatch_decoder.diagnostics().last_error_name)) {
        return error.Lz4ProbeMismatch;
    }
    if (!std.mem.eql(u8, "frame", size_mismatch_decoder.diagnostics().last_error_phase_name)) {
        return error.Lz4ProbeMismatch;
    }

    var reusable_wrong = vort.Lz4NativeFrameDecoder.init(allocator);
    defer reusable_wrong.deinit();
    try expectNeedDictionary(reusable_wrong.decodedSizeWithDictionary(encoded, wrong));
    try expectAllocNeedDictionary(allocator, reusable_wrong.decodeAllocWithDictionary(encoded, wrong));

    var incremental_wrong = vort.Lz4NativeIncrementalFrameDecoder.initWithDictionaryAndOptions(allocator, wrong, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer incremental_wrong.deinit();
    try expectNeedDictionary(incremental_wrong.step(encoded, &wrong_output));
    if (!std.mem.eql(u8, "NeedDictionary", incremental_wrong.diagnostics().last_error_name)) {
        return error.Lz4ProbeMismatch;
    }
    if (!std.mem.eql(u8, "frame", incremental_wrong.diagnostics().last_error_phase_name)) {
        return error.Lz4ProbeMismatch;
    }

    const decoded = try vort.lz4DecodeNativeFrameAllocWithDictionary(allocator, encoded, dict);
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, payload, decoded)) return error.Lz4ProbeMismatch;
    if (try vort.lz4DecodedNativeFrameSizeWithDictionary(encoded, dict) != payload.len) return error.Lz4ProbeSizeMismatch;

    const second_payload = "abcdefghijklmnop-second";
    const second = try vort.lz4EncodeNativeFrameWithDictionaryAlloc(allocator, second_payload, .{
        .content_checksum = false,
        .block_checksum = true,
    }, dict);
    defer allocator.free(second);
    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(allocator);
    try stream.appendSlice(allocator, encoded);
    try stream.appendSlice(allocator, second);

    const concatenated = try vort.lz4DecodeNativeConcatenatedFrameAllocWithDictionary(allocator, stream.items, dict);
    defer allocator.free(concatenated);
    if (!std.mem.eql(u8, payload ++ second_payload, concatenated)) return error.Lz4ProbeMismatch;
    if (try vort.lz4DecodedNativeConcatenatedFrameSizeWithDictionary(stream.items, dict) != concatenated.len) {
        return error.Lz4ProbeSizeMismatch;
    }
    try expectNeedDictionary(vort.lz4DecodedNativeConcatenatedFrameSizeWithDictionary(stream.items, wrong));
    var wrong_stream_output: [payload.len + second_payload.len]u8 = undefined;
    try expectNeedDictionary(vort.lz4DecodeNativeConcatenatedFrameIntoWithDictionary(stream.items, &wrong_stream_output, wrong));
    try expectAllocNeedDictionary(allocator, vort.lz4DecodeNativeConcatenatedFrameAllocWithDictionary(allocator, stream.items, wrong));

    const first_block = try allocator.alloc(u8, 64 * 1024);
    defer allocator.free(first_block);
    @memset(first_block, 'x');
    const tail = "abcdefghijklmnop-tail-block";
    const multi_payload = try allocator.alloc(u8, first_block.len + tail.len);
    defer allocator.free(multi_payload);
    @memcpy(multi_payload[0..first_block.len], first_block);
    @memcpy(multi_payload[first_block.len..], tail);
    const multi = try vort.lz4EncodeNativeFrameWithDictionaryAlloc(allocator, multi_payload, .{
        .content_checksum = false,
        .block_checksum = true,
        .block_size_id = .max64kb,
        .block_mode = .independent,
    }, dict);
    defer allocator.free(multi);
    const multi_decoded = try vort.lz4DecodeNativeFrameAllocWithDictionary(allocator, multi, dict);
    defer allocator.free(multi_decoded);
    if (!std.mem.eql(u8, multi_payload, multi_decoded)) return error.Lz4ProbeMismatch;
}

fn checkDictionarySetStreamInspection(allocator: std.mem.Allocator) !void {
    const first_dict = vort.Lz4NativeDictionary.init(0x1234_0001, "abcdefghijklmnop");
    const second_dict = vort.Lz4NativeDictionary.init(0x1234_0002, "QRSTUVWXYZabcdef");
    const dictionaries = [_]vort.Lz4NativeDictionary{ first_dict, second_dict };
    const dictionary_set = vort.Lz4NativeDictionarySet.init(&dictionaries);
    const options: vort.Lz4NativeFrameOptions = .{
        .content_checksum = true,
        .block_checksum = true,
    };
    const first_payload = "prefix-abcdefghijklmnop-one";
    const second_payload = "prefix-QRSTUVWXYZabcdef-two";

    const first = try vort.lz4EncodeNativeFrameWithDictionarySetAlloc(allocator, first_payload, options, dictionary_set, first_dict.id);
    defer allocator.free(first);
    const skip = try vort.lz4EncodeSkippableFrameAlloc(allocator, 3, "dict-set-metadata");
    defer allocator.free(skip);
    const second = try vort.lz4EncodeNativeFrameWithDictionarySetAlloc(allocator, second_payload, options, dictionary_set, second_dict.id);
    defer allocator.free(second);

    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(allocator);
    try stream.appendSlice(allocator, first);
    try stream.appendSlice(allocator, skip);
    try stream.appendSlice(allocator, second);

    const summary = try vort.lz4SummarizeNativeStream(stream.items);
    if (summary.frame_count != 2) return error.Lz4ProbeMismatch;
    if (summary.skippable_frame_count != 1) return error.Lz4ProbeMismatch;
    if (summary.skippable_payload_bytes != "dict-set-metadata".len) return error.Lz4ProbeSizeMismatch;
    if (summary.block_count != 2) return error.Lz4ProbeSizeMismatch;
    if (summary.compressed_block_count != 2) return error.Lz4ProbeMismatch;

    var iterator = vort.lz4IterateNativeStream(stream.items);
    const first_element = (try iterator.next()) orelse return error.Lz4ProbeMismatch;
    const skip_element = (try iterator.next()) orelse return error.Lz4ProbeMismatch;
    const second_element = (try iterator.next()) orelse return error.Lz4ProbeMismatch;
    if ((try iterator.next()) != null) return error.Lz4ProbeMismatch;

    const first_frame = switch (first_element) {
        .frame => |frame| frame,
        .skippable => return error.Lz4ProbeMismatch,
    };
    switch (skip_element) {
        .frame => return error.Lz4ProbeMismatch,
        .skippable => |skippable| {
            if (skippable.header.skippable_id != 3) return error.Lz4ProbeMismatch;
            if (!std.mem.eql(u8, skippable.payload, "dict-set-metadata")) return error.Lz4ProbeMismatch;
        },
    }
    const second_frame = switch (second_element) {
        .frame => |frame| frame,
        .skippable => return error.Lz4ProbeMismatch,
    };
    if (first_frame.header.dictionary_id == null or first_frame.header.dictionary_id.? != first_dict.id) return error.Lz4ProbeMismatch;
    if (second_frame.header.dictionary_id == null or second_frame.header.dictionary_id.? != second_dict.id) return error.Lz4ProbeMismatch;

    var first_blocks = try first_frame.blockIterator();
    const first_block = (try first_blocks.next()) orelse return error.Lz4ProbeMismatch;
    if (!first_block.is_compressed or first_block.block_checksum_offset == null) return error.Lz4ProbeMismatch;
    if ((try first_blocks.next()) != null) return error.Lz4ProbeMismatch;

    var second_blocks = try second_frame.blockIterator();
    const second_block = (try second_blocks.next()) orelse return error.Lz4ProbeMismatch;
    if (!second_block.is_compressed or second_block.block_checksum_offset == null) return error.Lz4ProbeMismatch;
    if ((try second_blocks.next()) != null) return error.Lz4ProbeMismatch;

    const decoded = try vort.lz4DecodeNativeConcatenatedFrameAllocWithDictionarySet(allocator, stream.items, dictionary_set);
    defer allocator.free(decoded);
    const expected = first_payload ++ second_payload;
    if (!std.mem.eql(u8, expected, decoded)) return error.Lz4ProbeMismatch;

    const second_start = first.len + skip.len;
    const chunks = [_][]const u8{
        stream.items[0..0],
        stream.items[0..5],
        stream.items[5..5],
        stream.items[5 .. first.len + 3],
        stream.items[first.len + 3 .. second_start + second.len / 2],
        stream.items[second_start + second.len / 2 ..],
        stream.items[stream.items.len..stream.items.len],
    };
    const join = try allocator.alloc(u8, stream.items.len);
    defer allocator.free(join);
    const short_join = try allocator.alloc(u8, stream.items.len - 1);
    defer allocator.free(short_join);
    var short_join_output: [expected.len]u8 = undefined;
    if (vort.lz4DecodeNativeConcatenatedFrameChunksIntoWithDictionarySet(&chunks, short_join, &short_join_output, dictionary_set)) |_| {
        return error.Lz4ProbeExpectedOutputLimit;
    } else |err| switch (err) {
        error.OutputTooSmall => {},
        else => return err,
    }
    if (vort.lz4DecodedNativeConcatenatedFrameChunksSizeWithDictionarySet(&chunks, short_join, dictionary_set)) |_| {
        return error.Lz4ProbeExpectedOutputLimit;
    } else |err| switch (err) {
        error.OutputTooSmall => {},
        else => return err,
    }
    const truncated_chunks = [_][]const u8{stream.items[0 .. stream.items.len - 1]};
    if (vort.lz4DecodedNativeConcatenatedFrameChunksSizeWithDictionarySet(&truncated_chunks, join, dictionary_set)) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| switch (err) {
        error.TruncatedFrame => {},
        else => return err,
    }

    const chunk_size = try vort.lz4DecodedNativeConcatenatedFrameChunksSizeWithDictionarySet(&chunks, join, dictionary_set);
    if (chunk_size != expected.len) return error.Lz4ProbeSizeMismatch;
    const chunk_limited_size = try vort.lz4DecodedNativeConcatenatedFrameChunksSizeLimitedWithDictionarySet(&chunks, join, expected.len, dictionary_set);
    if (chunk_limited_size != expected.len) return error.Lz4ProbeSizeMismatch;
    if (vort.lz4DecodedNativeConcatenatedFrameChunksSizeLimitedWithDictionarySet(&chunks, join, expected.len - 1, dictionary_set)) |_| {
        return error.Lz4ProbeExpectedOutputLimit;
    } else |err| switch (err) {
        error.OutputLimitExceeded => {},
        else => return err,
    }

    const chunk_exact = try vort.lz4DecodeNativeConcatenatedFrameChunksAllocWithDictionarySetExactSize(allocator, &chunks, join, dictionary_set, expected.len);
    defer allocator.free(chunk_exact);
    if (!std.mem.eql(u8, expected, chunk_exact)) return error.Lz4ProbeMismatch;
    if (vort.lz4DecodeNativeConcatenatedFrameChunksAllocWithDictionarySetExactSize(allocator, &chunks, join, dictionary_set, expected.len + 1)) |wrong| {
        allocator.free(wrong);
        return error.Lz4ProbeExpectedFrameError;
    } else |err| switch (err) {
        error.SizeMismatch => {},
        else => return err,
    }

    var into: [expected.len]u8 = undefined;
    const into_written = try vort.lz4DecodeNativeConcatenatedFrameChunksIntoWithDictionarySet(&chunks, join, &into, dictionary_set);
    if (into_written != expected.len or !std.mem.eql(u8, expected, &into)) return error.Lz4ProbeMismatch;

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    const appended_written = try vort.lz4DecodeNativeConcatenatedFrameChunksAppendExactSizeWithDictionarySet(allocator, &appended, &chunks, join, dictionary_set, expected.len);
    if (appended_written != expected.len) return error.Lz4ProbeSizeMismatch;
    if (!std.mem.eql(u8, appended.items, "prefix:" ++ expected)) return error.Lz4ProbeMismatch;

    var reusable = vort.Lz4NativeFrameDecoder.init(allocator);
    defer reusable.deinit();
    const reusable_exact = try reusable.decodeConcatenatedChunksAllocExactSizeWithDictionarySet(&chunks, join, dictionary_set, expected.len);
    defer allocator.free(reusable_exact);
    if (!std.mem.eql(u8, expected, reusable_exact)) return error.Lz4ProbeMismatch;
    const reusable_scratch = try reusable.decodeConcatenatedChunksScratchWithDictionarySet(&chunks, join, dictionary_set);
    if (!std.mem.eql(u8, expected, reusable_scratch)) return error.Lz4ProbeMismatch;
    const reusable_limited_scratch = try reusable.decodeConcatenatedChunksScratchLimitedWithDictionarySet(&chunks, join, expected.len, dictionary_set);
    if (!std.mem.eql(u8, expected, reusable_limited_scratch)) return error.Lz4ProbeMismatch;
    if (reusable.decodeConcatenatedChunksScratchLimitedWithDictionarySet(&chunks, join, expected.len - 1, dictionary_set)) |_| {
        return error.Lz4ProbeExpectedOutputLimit;
    } else |err| switch (err) {
        error.OutputLimitExceeded => {},
        else => return err,
    }
    var reusable_appended: std.ArrayList(u8) = .empty;
    defer reusable_appended.deinit(allocator);
    try reusable_appended.appendSlice(allocator, "prefix:");
    const reusable_appended_written = try reusable.decodeConcatenatedChunksAppendWithDictionarySet(&reusable_appended, &chunks, join, dictionary_set);
    if (reusable_appended_written != expected.len or !std.mem.eql(u8, reusable_appended.items, "prefix:" ++ expected)) {
        return error.Lz4ProbeMismatch;
    }
    reusable_appended.clearRetainingCapacity();
    try reusable_appended.appendSlice(allocator, "prefix:");
    const reusable_limited_appended_written = try reusable.decodeConcatenatedChunksAppendLimitedWithDictionarySet(&reusable_appended, &chunks, join, expected.len, dictionary_set);
    if (reusable_limited_appended_written != expected.len or !std.mem.eql(u8, reusable_appended.items, "prefix:" ++ expected)) {
        return error.Lz4ProbeMismatch;
    }
    reusable_appended.clearRetainingCapacity();
    if (reusable.decodeConcatenatedChunksAppendLimitedWithDictionarySet(&reusable_appended, &chunks, join, expected.len - 1, dictionary_set)) |_| {
        return error.Lz4ProbeExpectedOutputLimit;
    } else |err| switch (err) {
        error.OutputLimitExceeded => {},
        else => return err,
    }

    const missing_set = vort.Lz4NativeDictionarySet.init(&.{first_dict});
    var missing_output: [expected.len]u8 = undefined;
    var checksum_stream = try allocator.dupe(u8, stream.items);
    defer allocator.free(checksum_stream);
    const second_frame_slice = checksum_stream[second_start..];
    const second_checksum_block = (try vort.lz4InspectNativeFrameFirstBlock(second_frame_slice)) orelse {
        return error.Lz4ProbeMismatch;
    };
    if (second_checksum_block.block_checksum_offset == null) return error.Lz4ProbeMismatch;
    checksum_stream[second_start + second_checksum_block.block_checksum_offset.?] ^= 0x01;
    try expectNeedDictionary(vort.lz4DecodedNativeConcatenatedFrameSizeWithDictionarySet(checksum_stream, missing_set));
    try expectNeedDictionary(vort.lz4DecodeNativeConcatenatedFrameIntoWithDictionarySet(checksum_stream, &missing_output, missing_set));
    try expectAllocNeedDictionary(allocator, vort.lz4DecodeNativeConcatenatedFrameAllocWithDictionarySet(allocator, checksum_stream, missing_set));
    try expectError(error.ChecksumMismatch, vort.lz4DecodedNativeConcatenatedFrameSizeWithDictionarySet(checksum_stream, dictionary_set));
    try expectError(error.ChecksumMismatch, vort.lz4DecodeNativeConcatenatedFrameIntoWithDictionarySet(checksum_stream, &missing_output, dictionary_set));
    try expectAllocError(allocator, error.ChecksumMismatch, vort.lz4DecodeNativeConcatenatedFrameAllocWithDictionarySet(allocator, checksum_stream, dictionary_set));
    var missing_set_checksum_decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(allocator, missing_set, .{
        .expected_output_len = expected.len,
        .max_decoded_buffer_len = @max(first_payload.len, second_payload.len),
    });
    defer missing_set_checksum_decoder.deinit();
    const missing_set_initial = try missing_set_checksum_decoder.step(checksum_stream, missing_output[0..0]);
    if (missing_set_initial.status != .need_output) return error.Lz4ProbeMismatch;
    try expectError(error.NeedDictionary, missing_set_checksum_decoder.step("", &missing_output));
    if (!std.mem.eql(u8, "NeedDictionary", missing_set_checksum_decoder.diagnostics().last_error_name)) {
        return error.Lz4ProbeMismatch;
    }
    if (!std.mem.eql(u8, "frame", missing_set_checksum_decoder.diagnostics().last_error_phase_name)) {
        return error.Lz4ProbeMismatch;
    }
    var set_checksum_decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(allocator, dictionary_set, .{
        .expected_output_len = expected.len,
        .max_decoded_buffer_len = @max(first_payload.len, second_payload.len),
    });
    defer set_checksum_decoder.deinit();
    const set_checksum_initial = try set_checksum_decoder.step(checksum_stream, missing_output[0..0]);
    if (set_checksum_initial.status != .need_output) return error.Lz4ProbeMismatch;
    try expectError(error.ChecksumMismatch, set_checksum_decoder.step("", &missing_output));
    if (!std.mem.eql(u8, "ChecksumMismatch", set_checksum_decoder.diagnostics().last_error_name)) {
        return error.Lz4ProbeMismatch;
    }
    if (!std.mem.eql(u8, "frame", set_checksum_decoder.diagnostics().last_error_phase_name)) {
        return error.Lz4ProbeMismatch;
    }

    var content_checksum_stream = try allocator.dupe(u8, stream.items);
    defer allocator.free(content_checksum_stream);
    content_checksum_stream[content_checksum_stream.len - 1] ^= 0x01;
    try expectNeedDictionary(vort.lz4DecodedNativeConcatenatedFrameSizeWithDictionarySet(content_checksum_stream, missing_set));
    try expectNeedDictionary(vort.lz4DecodeNativeConcatenatedFrameIntoWithDictionarySet(content_checksum_stream, &missing_output, missing_set));
    try expectAllocNeedDictionary(allocator, vort.lz4DecodeNativeConcatenatedFrameAllocWithDictionarySet(allocator, content_checksum_stream, missing_set));
    if (try vort.lz4DecodedNativeConcatenatedFrameSizeWithDictionarySet(content_checksum_stream, dictionary_set) != expected.len) {
        return error.Lz4ProbeSizeMismatch;
    }
    try expectError(error.ChecksumMismatch, vort.lz4DecodeNativeConcatenatedFrameIntoWithDictionarySet(content_checksum_stream, &missing_output, dictionary_set));
    try expectAllocError(allocator, error.ChecksumMismatch, vort.lz4DecodeNativeConcatenatedFrameAllocWithDictionarySet(allocator, content_checksum_stream, dictionary_set));
    var missing_set_content_decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(allocator, missing_set, .{
        .expected_output_len = expected.len,
        .max_decoded_buffer_len = @max(first_payload.len, second_payload.len),
    });
    defer missing_set_content_decoder.deinit();
    const missing_content_initial = try missing_set_content_decoder.step(content_checksum_stream, missing_output[0..0]);
    if (missing_content_initial.status != .need_output) return error.Lz4ProbeMismatch;
    try expectError(error.NeedDictionary, missing_set_content_decoder.step("", &missing_output));
    if (!std.mem.eql(u8, "NeedDictionary", missing_set_content_decoder.diagnostics().last_error_name)) {
        return error.Lz4ProbeMismatch;
    }
    if (!std.mem.eql(u8, "frame", missing_set_content_decoder.diagnostics().last_error_phase_name)) {
        return error.Lz4ProbeMismatch;
    }
    var set_content_decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(allocator, dictionary_set, .{
        .expected_output_len = expected.len,
        .max_decoded_buffer_len = @max(first_payload.len, second_payload.len),
    });
    defer set_content_decoder.deinit();
    const set_content_initial = try set_content_decoder.step(content_checksum_stream, missing_output[0..0]);
    if (set_content_initial.status != .need_output) return error.Lz4ProbeMismatch;
    try expectError(error.ChecksumMismatch, set_content_decoder.step("", &missing_output));
    if (!std.mem.eql(u8, "ChecksumMismatch", set_content_decoder.diagnostics().last_error_name)) {
        return error.Lz4ProbeMismatch;
    }
    if (!std.mem.eql(u8, "direct_output", set_content_decoder.diagnostics().last_error_phase_name)) {
        return error.Lz4ProbeMismatch;
    }

    const second_size_mismatch = try frameWithSingleBlockAndContentSizeAndDictionary(
        allocator,
        0x69, // Content Size + Dictionary_ID.
        0x40,
        second_payload.len + 1,
        0x8000_0000 | second_payload.len,
        second_payload,
        "\x00\x00\x00\x00",
        second_dict.id,
    );
    defer allocator.free(second_size_mismatch);
    var size_stream: std.ArrayList(u8) = .empty;
    defer size_stream.deinit(allocator);
    try size_stream.appendSlice(allocator, first);
    try size_stream.appendSlice(allocator, skip);
    try size_stream.appendSlice(allocator, second_size_mismatch);
    try expectNeedDictionary(vort.lz4DecodedNativeConcatenatedFrameSizeWithDictionarySet(size_stream.items, missing_set));
    try expectNeedDictionary(vort.lz4DecodeNativeConcatenatedFrameIntoWithDictionarySet(size_stream.items, &missing_output, missing_set));
    try expectAllocNeedDictionary(allocator, vort.lz4DecodeNativeConcatenatedFrameAllocWithDictionarySet(allocator, size_stream.items, missing_set));
    try expectError(error.SizeMismatch, vort.lz4DecodedNativeConcatenatedFrameSizeWithDictionarySet(size_stream.items, dictionary_set));
    var size_mismatch_output: [expected.len + 1]u8 = undefined;
    try expectError(error.SizeMismatch, vort.lz4DecodeNativeConcatenatedFrameIntoWithDictionarySet(size_stream.items, &size_mismatch_output, dictionary_set));
    try expectAllocError(allocator, error.SizeMismatch, vort.lz4DecodeNativeConcatenatedFrameAllocWithDictionarySet(allocator, size_stream.items, dictionary_set));
    var missing_set_size_decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(allocator, missing_set, .{
        .expected_output_len = expected.len,
        .max_decoded_buffer_len = @max(first_payload.len, second_payload.len),
    });
    defer missing_set_size_decoder.deinit();
    const missing_size_initial = try missing_set_size_decoder.step(size_stream.items, missing_output[0..0]);
    if (missing_size_initial.status != .need_output) return error.Lz4ProbeMismatch;
    try expectError(error.NeedDictionary, missing_set_size_decoder.step("", &missing_output));
    if (!std.mem.eql(u8, "NeedDictionary", missing_set_size_decoder.diagnostics().last_error_name)) {
        return error.Lz4ProbeMismatch;
    }
    if (!std.mem.eql(u8, "frame", missing_set_size_decoder.diagnostics().last_error_phase_name)) {
        return error.Lz4ProbeMismatch;
    }
    var set_size_decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(allocator, dictionary_set, .{
        .expected_output_len = expected.len,
        .max_decoded_buffer_len = @max(first_payload.len, second_payload.len) + 1,
    });
    defer set_size_decoder.deinit();
    const set_size_initial = try set_size_decoder.step(size_stream.items, size_mismatch_output[0..0]);
    if (set_size_initial.status != .need_output) return error.Lz4ProbeMismatch;
    try expectError(error.SizeMismatch, set_size_decoder.step("", &size_mismatch_output));
    if (!std.mem.eql(u8, "SizeMismatch", set_size_decoder.diagnostics().last_error_name)) {
        return error.Lz4ProbeMismatch;
    }
    if (!std.mem.eql(u8, "frame", set_size_decoder.diagnostics().last_error_phase_name)) {
        return error.Lz4ProbeMismatch;
    }

    const second_invalid_match = try frameWithSingleBlockAndDictionary(
        allocator,
        0x61, // Dictionary_ID.
        0x40,
        4,
        "\x10a\x00\x00",
        "\x00\x00\x00\x00",
        second_dict.id,
    );
    defer allocator.free(second_invalid_match);
    var invalid_stream: std.ArrayList(u8) = .empty;
    defer invalid_stream.deinit(allocator);
    try invalid_stream.appendSlice(allocator, first);
    try invalid_stream.appendSlice(allocator, skip);
    try invalid_stream.appendSlice(allocator, second_invalid_match);
    try expectNeedDictionary(vort.lz4DecodedNativeConcatenatedFrameSizeWithDictionarySet(invalid_stream.items, missing_set));
    try expectNeedDictionary(vort.lz4DecodeNativeConcatenatedFrameIntoWithDictionarySet(invalid_stream.items, &missing_output, missing_set));
    try expectAllocNeedDictionary(allocator, vort.lz4DecodeNativeConcatenatedFrameAllocWithDictionarySet(allocator, invalid_stream.items, missing_set));
    try expectError(error.InvalidMatch, vort.lz4DecodedNativeConcatenatedFrameSizeWithDictionarySet(invalid_stream.items, dictionary_set));
    try expectError(error.InvalidMatch, vort.lz4DecodeNativeConcatenatedFrameIntoWithDictionarySet(invalid_stream.items, &missing_output, dictionary_set));
    try expectAllocError(allocator, error.InvalidMatch, vort.lz4DecodeNativeConcatenatedFrameAllocWithDictionarySet(allocator, invalid_stream.items, dictionary_set));
    var missing_set_invalid_decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(allocator, missing_set, .{
        .expected_output_len = expected.len,
        .max_decoded_buffer_len = @max(first_payload.len, second_payload.len),
    });
    defer missing_set_invalid_decoder.deinit();
    const missing_invalid_initial = try missing_set_invalid_decoder.step(invalid_stream.items, missing_output[0..0]);
    if (missing_invalid_initial.status != .need_output) return error.Lz4ProbeMismatch;
    try expectError(error.NeedDictionary, missing_set_invalid_decoder.step("", &missing_output));
    if (!std.mem.eql(u8, "NeedDictionary", missing_set_invalid_decoder.diagnostics().last_error_name)) {
        return error.Lz4ProbeMismatch;
    }
    if (!std.mem.eql(u8, "frame", missing_set_invalid_decoder.diagnostics().last_error_phase_name)) {
        return error.Lz4ProbeMismatch;
    }
    var set_invalid_decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(allocator, dictionary_set, .{
        .expected_output_len = expected.len,
        .max_decoded_buffer_len = @max(first_payload.len, second_payload.len),
    });
    defer set_invalid_decoder.deinit();
    const set_invalid_initial = try set_invalid_decoder.step(invalid_stream.items, missing_output[0..0]);
    if (set_invalid_initial.status != .need_output) return error.Lz4ProbeMismatch;
    try expectError(error.InvalidMatch, set_invalid_decoder.step("", &missing_output));
    if (!std.mem.eql(u8, "InvalidMatch", set_invalid_decoder.diagnostics().last_error_name)) {
        return error.Lz4ProbeMismatch;
    }
    if (!std.mem.eql(u8, "frame", set_invalid_decoder.diagnostics().last_error_phase_name)) {
        return error.Lz4ProbeMismatch;
    }

    try expectNeedDictionary(vort.lz4DecodedNativeConcatenatedFrameSizeWithDictionarySet(stream.items, missing_set));
    try expectNeedDictionary(vort.lz4DecodedNativeConcatenatedFrameSizeLimitedWithDictionarySet(stream.items, expected.len, missing_set));
    try expectNeedDictionary(vort.lz4DecodeNativeConcatenatedFrameIntoWithDictionarySet(stream.items, &missing_output, missing_set));
    try expectAllocNeedDictionary(allocator, vort.lz4DecodeNativeConcatenatedFrameAllocWithDictionarySet(allocator, stream.items, missing_set));
    try expectAllocNeedDictionary(allocator, vort.lz4DecodeNativeConcatenatedFrameAllocWithDictionarySetExactSize(allocator, stream.items, missing_set, expected.len));
    try expectAllocNeedDictionary(allocator, vort.lz4DecodeNativeConcatenatedFrameAllocLimitedWithDictionarySet(allocator, stream.items, expected.len, missing_set));
    try expectNeedDictionary(vort.lz4DecodedNativeConcatenatedFrameChunksSizeWithDictionarySet(&chunks, join, missing_set));
    try expectNeedDictionary(vort.lz4DecodedNativeConcatenatedFrameChunksSizeLimitedWithDictionarySet(&chunks, join, expected.len, missing_set));
    try expectNeedDictionary(vort.lz4DecodeNativeConcatenatedFrameChunksIntoWithDictionarySet(&chunks, join, &missing_output, missing_set));
    try expectAllocNeedDictionary(allocator, vort.lz4DecodeNativeConcatenatedFrameChunksAllocWithDictionarySet(allocator, &chunks, join, missing_set));
    try expectAllocNeedDictionary(allocator, vort.lz4DecodeNativeConcatenatedFrameChunksAllocWithDictionarySetExactSize(allocator, &chunks, join, missing_set, expected.len));
    try expectAllocNeedDictionary(allocator, vort.lz4DecodeNativeConcatenatedFrameChunksAllocWithDictionarySetLimited(allocator, &chunks, join, missing_set, expected.len));
    if (reusable.decodeConcatenatedChunksAllocWithDictionarySet(&chunks, join, missing_set)) |missing| {
        allocator.free(missing);
        return error.Lz4ProbeExpectedFrameError;
    } else |err| switch (err) {
        error.NeedDictionary => {},
        else => return err,
    }
    if (reusable.decodeConcatenatedChunksScratchWithDictionarySet(&chunks, join, missing_set)) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| switch (err) {
        error.NeedDictionary => {},
        else => return err,
    }
    reusable_appended.clearRetainingCapacity();
    if (reusable.decodeConcatenatedChunksAppendWithDictionarySet(&reusable_appended, &chunks, join, missing_set)) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| switch (err) {
        error.NeedDictionary => {},
        else => return err,
    }

    if (vort.lz4DecodeNativeConcatenatedFrameChunksAllocWithDictionarySet(allocator, &chunks, join, missing_set)) |missing| {
        allocator.free(missing);
        return error.Lz4ProbeExpectedFrameError;
    } else |err| switch (err) {
        error.NeedDictionary => {},
        else => return err,
    }
}

fn checkSplitHeaderIncremental(allocator: std.mem.Allocator) !void {
    const payload = "split-header-lz4-native";
    const encoded = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, payload, .{
        .content_checksum = false,
        .include_content_size = true,
        .block_checksum = true,
    });
    defer allocator.free(encoded);

    var decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    const partial = try decoder.step(encoded[0..2], output[0..0]);
    if (partial.status != .need_input) return error.Lz4ProbeMismatch;
    if (partial.progress.input_read != 2 or partial.progress.output_written != 0) return error.Lz4ProbeSizeMismatch;
    if (!std.mem.eql(u8, "frame", decoder.diagnostics().phase_name)) return error.Lz4ProbeMismatch;

    const done = try decoder.step(encoded[2..], &output);
    if (done.status != .done) return error.Lz4ProbeMismatch;
    if (!std.mem.eql(u8, payload, &output)) return error.Lz4ProbeMismatch;
    try decoder.finish();
}

fn checkSplitSkippableHeaderIncremental(allocator: std.mem.Allocator) !void {
    const skip = try vort.lz4EncodeSkippableFrameAlloc(allocator, 6, "split-skip-lz4-metadata");
    defer allocator.free(skip);
    const payload = "split-skippable-header-lz4-native";
    const encoded = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, payload, .{
        .content_checksum = false,
        .include_content_size = true,
        .block_checksum = true,
    });
    defer allocator.free(encoded);
    const tail = try std.mem.concat(allocator, u8, &.{ skip[5..], encoded });
    defer allocator.free(tail);

    var decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;

    // Five bytes include the skippable magic plus one byte of the length field;
    // the incremental decoder must wait in frame parsing instead of treating
    // partial metadata as a malformed or empty stream.
    const partial = try decoder.step(skip[0..5], output[0..0]);
    if (partial.status != .need_input) return error.Lz4ProbeMismatch;
    if (partial.progress.input_read != 5 or partial.progress.output_written != 0) return error.Lz4ProbeSizeMismatch;
    if (!std.mem.eql(u8, "frame", decoder.diagnostics().phase_name)) return error.Lz4ProbeMismatch;

    const done = try decoder.step(tail, &output);
    if (done.status != .done) return error.Lz4ProbeMismatch;
    if (done.progress.input_read != tail.len or done.progress.output_written != payload.len) return error.Lz4ProbeSizeMismatch;
    if (!std.mem.eql(u8, payload, &output)) return error.Lz4ProbeMismatch;
    try decoder.finish();
}

fn checkSkippableOnlyStream(allocator: std.mem.Allocator) !void {
    const expected_len = try vort.lz4EncodedSkippableFrameBound("metadata-only".len);
    const skip = try vort.lz4EncodeSkippableFrameAlloc(allocator, 5, "metadata-only");
    defer allocator.free(skip);
    if (skip.len != expected_len) return error.Lz4ProbeSizeMismatch;

    var into: [64]u8 = undefined;
    const into_written = try vort.lz4EncodeSkippableFrameIntoSlice(5, "metadata-only", &into);
    if (into_written != skip.len) return error.Lz4ProbeSizeMismatch;
    if (!std.mem.eql(u8, skip, into[0..into_written])) return error.Lz4ProbeMismatch;
    try expectError(error.OutputTooSmall, vort.lz4EncodeSkippableFrameIntoSlice(5, "metadata-only", into[0 .. into_written - 1]));

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    try vort.lz4EncodeSkippableFrameAppend(allocator, &appended, 5, "metadata-only");
    if (!std.mem.eql(u8, "prefix:", appended.items[0.."prefix:".len])) return error.Lz4ProbeMismatch;
    if (!std.mem.eql(u8, skip, appended.items["prefix:".len..])) return error.Lz4ProbeMismatch;

    const decoded = try vort.lz4DecodeNativeConcatenatedFrameAlloc(allocator, skip);
    defer allocator.free(decoded);
    if (decoded.len != 0) return error.Lz4ProbeSizeMismatch;
    const exact = try vort.lz4DecodeNativeConcatenatedFrameAllocExactSize(allocator, skip, 0);
    defer allocator.free(exact);
    if (exact.len != 0) return error.Lz4ProbeSizeMismatch;
    try expectError(error.SizeMismatch, vort.lz4DecodeNativeConcatenatedFrameAllocExactSize(allocator, skip, 1));
    if ((try vort.lz4DecodedNativeConcatenatedFrameSize(skip)) != 0) return error.Lz4ProbeSizeMismatch;
    if ((try vort.lz4DecodedNativeConcatenatedFrameSizeLimited(skip, 0)) != 0) return error.Lz4ProbeSizeMismatch;

    const split_a: usize = @min(skip.len, 5);
    const split_b: usize = @min(skip.len, split_a + 3);
    const chunks = [_][]const u8{ skip[0..split_a], skip[split_a..split_b], skip[split_b..] };
    const join = try allocator.alloc(u8, skip.len);
    defer allocator.free(join);
    if ((try vort.lz4DecodedNativeConcatenatedFrameChunksSize(&chunks, join)) != 0) return error.Lz4ProbeSizeMismatch;
    if ((try vort.lz4DecodedNativeConcatenatedFrameChunksSizeLimited(&chunks, join, 0)) != 0) return error.Lz4ProbeSizeMismatch;
    const chunked_exact = try vort.lz4DecodeNativeConcatenatedFrameChunksAllocExactSize(allocator, &chunks, join, 0);
    defer allocator.free(chunked_exact);
    if (chunked_exact.len != 0) return error.Lz4ProbeSizeMismatch;
    try expectAllocError(allocator, error.SizeMismatch, vort.lz4DecodeNativeConcatenatedFrameChunksAllocExactSize(allocator, &chunks, join, 1));
    var chunked_into: [1]u8 = undefined;
    const chunked_written = try vort.lz4DecodeNativeConcatenatedFrameChunksIntoExactSize(&chunks, join, &chunked_into, 0);
    if (chunked_written != 0) return error.Lz4ProbeSizeMismatch;
    try expectError(error.SizeMismatch, vort.lz4DecodeNativeConcatenatedFrameChunksIntoExactSize(&chunks, join, &chunked_into, 1));

    var chunked_appended: std.ArrayList(u8) = .empty;
    defer chunked_appended.deinit(allocator);
    try chunked_appended.appendSlice(allocator, "prefix:");
    const chunked_appended_written = try vort.lz4DecodeNativeConcatenatedFrameChunksAppendExactSize(allocator, &chunked_appended, &chunks, join, 0);
    if (chunked_appended_written != 0) return error.Lz4ProbeSizeMismatch;
    if (!std.mem.eql(u8, chunked_appended.items, "prefix:")) return error.Lz4ProbeMismatch;
    try expectError(error.SizeMismatch, vort.lz4DecodeNativeConcatenatedFrameChunksAppendExactSize(allocator, &chunked_appended, &chunks, join, 1));

    var reusable = vort.Lz4NativeFrameDecoder.init(allocator);
    defer reusable.deinit();
    const reusable_exact = try reusable.decodeConcatenatedChunksAllocExactSize(&chunks, join, 0);
    defer allocator.free(reusable_exact);
    if (reusable_exact.len != 0) return error.Lz4ProbeSizeMismatch;
    try expectAllocError(allocator, error.SizeMismatch, reusable.decodeConcatenatedChunksAllocExactSize(&chunks, join, 1));
    const reusable_written = try reusable.decodeConcatenatedChunksIntoSliceExactSize(&chunks, join, &chunked_into, 0);
    if (reusable_written != 0) return error.Lz4ProbeSizeMismatch;
    try expectError(error.SizeMismatch, reusable.decodeConcatenatedChunksIntoSliceExactSize(&chunks, join, &chunked_into, 1));
    var reusable_appended: std.ArrayList(u8) = .empty;
    defer reusable_appended.deinit(allocator);
    try reusable_appended.appendSlice(allocator, "prefix:");
    const reusable_appended_written = try reusable.decodeConcatenatedChunksAppendExactSize(&reusable_appended, &chunks, join, 0);
    if (reusable_appended_written != 0) return error.Lz4ProbeSizeMismatch;
    if (!std.mem.eql(u8, reusable_appended.items, "prefix:")) return error.Lz4ProbeMismatch;
    try expectError(error.SizeMismatch, reusable.decodeConcatenatedChunksAppendExactSize(&reusable_appended, &chunks, join, 1));

    const summary = try vort.lz4SummarizeNativeStream(skip);
    if (summary.frame_count != 0) return error.Lz4ProbeMismatch;
    if (summary.skippable_frame_count != 1) return error.Lz4ProbeMismatch;
    if (summary.skippable_payload_bytes != "metadata-only".len) return error.Lz4ProbeSizeMismatch;

    var iterator = vort.lz4IterateNativeStream(skip);
    const element = (try iterator.next()) orelse return error.Lz4ProbeMismatch;
    switch (element) {
        .frame => return error.Lz4ProbeMismatch,
        .skippable => |skippable| {
            if (skippable.header.skippable_id != 5) return error.Lz4ProbeMismatch;
            if (!std.mem.eql(u8, skippable.payload, "metadata-only")) return error.Lz4ProbeMismatch;
        },
    }
    if ((try iterator.next()) != null) return error.Lz4ProbeMismatch;

    var incremental_exact = vort.Lz4NativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = 0,
        .max_decoded_buffer_len = 0,
    });
    defer incremental_exact.deinit();
    const incremental_done = try incremental_exact.step(skip, chunked_into[0..0]);
    if (incremental_done.status != .done) return error.Lz4ProbeMismatch;
    if (incremental_done.progress.input_read != skip.len or incremental_done.progress.output_written != 0) return error.Lz4ProbeSizeMismatch;
    if (incremental_exact.diagnostics().output_written != 0) return error.Lz4ProbeSizeMismatch;
    try incremental_exact.finish();

    var incremental_too_large = vort.Lz4NativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = 1,
        .max_decoded_buffer_len = 1,
    });
    defer incremental_too_large.deinit();
    const pending = try incremental_too_large.step(skip, chunked_into[0..0]);
    if (pending.status != .need_input) return error.Lz4ProbeMismatch;
    if (pending.progress.input_read != skip.len or pending.progress.output_written != 0) return error.Lz4ProbeSizeMismatch;
    try expectError(error.SizeMismatch, incremental_too_large.finish());
    if (!std.mem.eql(u8, "SizeMismatch", incremental_too_large.diagnostics().last_error_name)) return error.Lz4ProbeMismatch;
    if (!std.mem.eql(u8, "output", incremental_too_large.diagnostics().last_error_phase_name)) return error.Lz4ProbeMismatch;
}

fn expectLz4ConcatenatedPayloadApis(allocator: std.mem.Allocator, stream: []const u8, payload: []const u8) !void {
    if ((try vort.lz4DecodedNativeConcatenatedFrameSize(stream)) != payload.len) return error.Lz4ProbeSizeMismatch;
    if ((try vort.lz4DecodedNativeConcatenatedFrameSizeLimited(stream, payload.len)) != payload.len) return error.Lz4ProbeSizeMismatch;
    if (payload.len != 0) try expectError(error.OutputLimitExceeded, vort.lz4DecodedNativeConcatenatedFrameSizeLimited(stream, payload.len - 1));

    const decoded = try vort.lz4DecodeNativeConcatenatedFrameAllocExactSize(allocator, stream, payload.len);
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, payload, decoded)) return error.Lz4ProbeMismatch;
    try expectAllocError(allocator, error.SizeMismatch, vort.lz4DecodeNativeConcatenatedFrameAllocExactSize(allocator, stream, payload.len + 1));

    const into = try allocator.alloc(u8, payload.len + 1);
    defer allocator.free(into);
    const written = try vort.lz4DecodeNativeConcatenatedFrameIntoExactSize(stream, into[0..payload.len], payload.len);
    if (written != payload.len) return error.Lz4ProbeSizeMismatch;
    if (!std.mem.eql(u8, payload, into[0..payload.len])) return error.Lz4ProbeMismatch;
    try expectError(error.SizeMismatch, vort.lz4DecodeNativeConcatenatedFrameIntoExactSize(stream, into, payload.len + 1));
    if (payload.len != 0) try expectError(error.OutputTooSmall, vort.lz4DecodeNativeConcatenatedFrameIntoExactSize(stream, into[0 .. payload.len - 1], payload.len));

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    const appended_written = try vort.lz4DecodeNativeConcatenatedFrameAppendExactSize(allocator, &appended, stream, payload.len);
    if (appended_written != payload.len) return error.Lz4ProbeSizeMismatch;
    if (!std.mem.eql(u8, "prefix:", appended.items[0.."prefix:".len])) return error.Lz4ProbeMismatch;
    if (!std.mem.eql(u8, payload, appended.items["prefix:".len..])) return error.Lz4ProbeMismatch;
    appended.clearRetainingCapacity();
    try expectError(error.SizeMismatch, vort.lz4DecodeNativeConcatenatedFrameAppendExactSize(allocator, &appended, stream, payload.len + 1));
    try appended.appendSlice(allocator, "prefix:");
    const appended_limited_written = try vort.lz4DecodeNativeConcatenatedFrameAppendLimited(allocator, &appended, stream, payload.len);
    if (appended_limited_written != payload.len) return error.Lz4ProbeSizeMismatch;
    if (!std.mem.eql(u8, "prefix:", appended.items[0.."prefix:".len])) return error.Lz4ProbeMismatch;
    if (!std.mem.eql(u8, payload, appended.items["prefix:".len..])) return error.Lz4ProbeMismatch;
    appended.clearRetainingCapacity();
    if (payload.len != 0) try expectError(error.OutputLimitExceeded, vort.lz4DecodeNativeConcatenatedFrameAppendLimited(allocator, &appended, stream, payload.len - 1));

    const split_a: usize = @min(stream.len, stream.len / 3 + 1);
    const split_b: usize = @min(stream.len, split_a + stream.len / 3 + 1);
    const chunks = [_][]const u8{ stream[0..split_a], stream[split_a..split_b], stream[split_b..] };
    const join = try allocator.alloc(u8, stream.len);
    defer allocator.free(join);
    if ((try vort.lz4DecodedNativeConcatenatedFrameChunksSize(&chunks, join)) != payload.len) return error.Lz4ProbeSizeMismatch;
    const chunked_written = try vort.lz4DecodeNativeConcatenatedFrameChunksIntoExactSize(&chunks, join, into[0..payload.len], payload.len);
    if (chunked_written != payload.len) return error.Lz4ProbeSizeMismatch;
    if (!std.mem.eql(u8, payload, into[0..payload.len])) return error.Lz4ProbeMismatch;
    try expectError(error.SizeMismatch, vort.lz4DecodeNativeConcatenatedFrameChunksIntoExactSize(&chunks, join, into, payload.len + 1));

    var chunked_appended: std.ArrayList(u8) = .empty;
    defer chunked_appended.deinit(allocator);
    try chunked_appended.appendSlice(allocator, "prefix:");
    const chunked_appended_written = try vort.lz4DecodeNativeConcatenatedFrameChunksAppendExactSize(allocator, &chunked_appended, &chunks, join, payload.len);
    if (chunked_appended_written != payload.len) return error.Lz4ProbeSizeMismatch;
    if (!std.mem.eql(u8, "prefix:", chunked_appended.items[0.."prefix:".len])) return error.Lz4ProbeMismatch;
    if (!std.mem.eql(u8, payload, chunked_appended.items["prefix:".len..])) return error.Lz4ProbeMismatch;
    chunked_appended.clearRetainingCapacity();
    try expectError(error.SizeMismatch, vort.lz4DecodeNativeConcatenatedFrameChunksAppendExactSize(allocator, &chunked_appended, &chunks, join, payload.len + 1));
    try chunked_appended.appendSlice(allocator, "prefix:");
    const chunked_limited_written = try vort.lz4DecodeNativeConcatenatedFrameChunksAppendLimited(allocator, &chunked_appended, &chunks, join, payload.len);
    if (chunked_limited_written != payload.len) return error.Lz4ProbeSizeMismatch;
    if (!std.mem.eql(u8, "prefix:", chunked_appended.items[0.."prefix:".len])) return error.Lz4ProbeMismatch;
    if (!std.mem.eql(u8, payload, chunked_appended.items["prefix:".len..])) return error.Lz4ProbeMismatch;
    chunked_appended.clearRetainingCapacity();
    if (payload.len != 0) try expectError(error.OutputLimitExceeded, vort.lz4DecodeNativeConcatenatedFrameChunksAppendLimited(allocator, &chunked_appended, &chunks, join, payload.len - 1));

    var decoder = vort.Lz4NativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    if ((try decoder.decodedConcatenatedSize(stream)) != payload.len) return error.Lz4ProbeSizeMismatch;
    const reusable_written = try decoder.decodeConcatenatedIntoSliceExactSize(stream, into[0..payload.len], payload.len);
    if (reusable_written != payload.len) return error.Lz4ProbeSizeMismatch;
    if (!std.mem.eql(u8, payload, into[0..payload.len])) return error.Lz4ProbeMismatch;
    try expectError(error.SizeMismatch, decoder.decodeConcatenatedIntoSliceExactSize(stream, into, payload.len + 1));

    var reusable_appended: std.ArrayList(u8) = .empty;
    defer reusable_appended.deinit(allocator);
    try reusable_appended.appendSlice(allocator, "prefix:");
    const reusable_appended_written = try decoder.decodeConcatenatedAppendExactSize(&reusable_appended, stream, payload.len);
    if (reusable_appended_written != payload.len) return error.Lz4ProbeSizeMismatch;
    if (!std.mem.eql(u8, "prefix:", reusable_appended.items[0.."prefix:".len])) return error.Lz4ProbeMismatch;
    if (!std.mem.eql(u8, payload, reusable_appended.items["prefix:".len..])) return error.Lz4ProbeMismatch;
    reusable_appended.clearRetainingCapacity();
    try expectError(error.SizeMismatch, decoder.decodeConcatenatedAppendExactSize(&reusable_appended, stream, payload.len + 1));
    try reusable_appended.appendSlice(allocator, "prefix:");
    const reusable_limited_written = try decoder.decodeConcatenatedAppendLimited(&reusable_appended, stream, payload.len);
    if (reusable_limited_written != payload.len) return error.Lz4ProbeSizeMismatch;
    if (!std.mem.eql(u8, "prefix:", reusable_appended.items[0.."prefix:".len])) return error.Lz4ProbeMismatch;
    if (!std.mem.eql(u8, payload, reusable_appended.items["prefix:".len..])) return error.Lz4ProbeMismatch;
    reusable_appended.clearRetainingCapacity();
    if (payload.len != 0) try expectError(error.OutputLimitExceeded, decoder.decodeConcatenatedAppendLimited(&reusable_appended, stream, payload.len - 1));

    var reusable_chunked_appended: std.ArrayList(u8) = .empty;
    defer reusable_chunked_appended.deinit(allocator);
    try reusable_chunked_appended.appendSlice(allocator, "prefix:");
    const reusable_chunked_appended_written = try decoder.decodeConcatenatedChunksAppendExactSize(&reusable_chunked_appended, &chunks, join, payload.len);
    if (reusable_chunked_appended_written != payload.len) return error.Lz4ProbeSizeMismatch;
    if (!std.mem.eql(u8, "prefix:", reusable_chunked_appended.items[0.."prefix:".len])) return error.Lz4ProbeMismatch;
    if (!std.mem.eql(u8, payload, reusable_chunked_appended.items["prefix:".len..])) return error.Lz4ProbeMismatch;
    reusable_chunked_appended.clearRetainingCapacity();
    try expectError(error.SizeMismatch, decoder.decodeConcatenatedChunksAppendExactSize(&reusable_chunked_appended, &chunks, join, payload.len + 1));
    try reusable_chunked_appended.appendSlice(allocator, "prefix:");
    const reusable_chunked_limited_written = try decoder.decodeConcatenatedChunksAppendLimited(&reusable_chunked_appended, &chunks, join, payload.len);
    if (reusable_chunked_limited_written != payload.len) return error.Lz4ProbeSizeMismatch;
    if (!std.mem.eql(u8, "prefix:", reusable_chunked_appended.items[0.."prefix:".len])) return error.Lz4ProbeMismatch;
    if (!std.mem.eql(u8, payload, reusable_chunked_appended.items["prefix:".len..])) return error.Lz4ProbeMismatch;
    reusable_chunked_appended.clearRetainingCapacity();
    if (payload.len != 0) try expectError(error.OutputLimitExceeded, decoder.decodeConcatenatedChunksAppendLimited(&reusable_chunked_appended, &chunks, join, payload.len - 1));
}

fn checkSkippableThenEmptyFrame(allocator: std.mem.Allocator) !void {
    const skip = try vort.lz4EncodeSkippableFrameAlloc(allocator, 4, "metadata-before-empty");
    defer allocator.free(skip);
    const empty = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, "", .{
        .include_content_size = true,
        .content_checksum = false,
        .block_checksum = false,
    });
    defer allocator.free(empty);
    const stream = try std.mem.concat(allocator, u8, &.{ skip, empty });
    defer allocator.free(stream);

    const summary = try vort.lz4SummarizeNativeStream(stream);
    if (summary.frame_count != 1) return error.Lz4ProbeMismatch;
    if (summary.skippable_frame_count != 1) return error.Lz4ProbeMismatch;
    if (summary.skippable_payload_bytes != "metadata-before-empty".len) return error.Lz4ProbeSizeMismatch;
    try expectLz4ConcatenatedPayloadApis(allocator, stream, "");
    var into: [1]u8 = undefined;

    var incremental = vort.Lz4NativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = 0,
        .max_decoded_buffer_len = 0,
    });
    defer incremental.deinit();
    const done = try incremental.step(stream, into[0..0]);
    if (done.status != .done) return error.Lz4ProbeMismatch;
    if (done.progress.input_read != stream.len or done.progress.output_written != 0) return error.Lz4ProbeSizeMismatch;
    try incremental.finish();

    var too_large = vort.Lz4NativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = 1,
        .max_decoded_buffer_len = 1,
    });
    defer too_large.deinit();
    const pending = try too_large.step(stream, into[0..0]);
    if (pending.status != .need_input) return error.Lz4ProbeMismatch;
    if (pending.progress.input_read != stream.len or pending.progress.output_written != 0) return error.Lz4ProbeSizeMismatch;
    try expectError(error.SizeMismatch, too_large.finish());
}

fn checkEmptyFrameThenSkippable(allocator: std.mem.Allocator) !void {
    const empty = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, "", .{
        .include_content_size = true,
        .content_checksum = false,
        .block_checksum = false,
    });
    defer allocator.free(empty);
    const skip = try vort.lz4EncodeSkippableFrameAlloc(allocator, 4, "metadata-after-empty");
    defer allocator.free(skip);
    const stream = try std.mem.concat(allocator, u8, &.{ empty, skip });
    defer allocator.free(stream);

    const summary = try vort.lz4SummarizeNativeStream(stream);
    if (summary.frame_count != 1) return error.Lz4ProbeMismatch;
    if (summary.skippable_frame_count != 1) return error.Lz4ProbeMismatch;
    if (summary.skippable_payload_bytes != "metadata-after-empty".len) return error.Lz4ProbeSizeMismatch;
    try expectLz4ConcatenatedPayloadApis(allocator, stream, "");
    var into: [1]u8 = undefined;

    var incremental = vort.Lz4NativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = 0,
        .max_decoded_buffer_len = 0,
    });
    defer incremental.deinit();
    const done = try incremental.step(stream, into[0..0]);
    if (done.status != .done) return error.Lz4ProbeMismatch;
    if (done.progress.input_read != stream.len or done.progress.output_written != 0) return error.Lz4ProbeSizeMismatch;
    try incremental.finish();

    var iterator = vort.lz4IterateNativeStream(stream);
    const frame_element = (try iterator.next()) orelse return error.Lz4ProbeMismatch;
    switch (frame_element) {
        .frame => |frame| if (frame.bytes.len != empty.len) return error.Lz4ProbeMismatch,
        .skippable => return error.Lz4ProbeMismatch,
    }
    const skip_element = (try iterator.next()) orelse return error.Lz4ProbeMismatch;
    switch (skip_element) {
        .frame => return error.Lz4ProbeMismatch,
        .skippable => |skippable| {
            if (skippable.header.skippable_id != 4) return error.Lz4ProbeMismatch;
            if (!std.mem.eql(u8, skippable.payload, "metadata-after-empty")) return error.Lz4ProbeMismatch;
        },
    }
    if ((try iterator.next()) != null) return error.Lz4ProbeMismatch;
}

fn checkEmptySkippableThenPayloadFrame(allocator: std.mem.Allocator) !void {
    const payload = "payload-after-empty-and-skip";
    const empty = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, "", .{
        .include_content_size = true,
        .content_checksum = false,
        .block_checksum = false,
    });
    defer allocator.free(empty);
    const skip = try vort.lz4EncodeSkippableFrameAlloc(allocator, 4, "metadata-between-frames");
    defer allocator.free(skip);
    const frame = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, payload, .{
        .include_content_size = true,
        .content_checksum = true,
        .block_checksum = true,
    });
    defer allocator.free(frame);
    const stream = try std.mem.concat(allocator, u8, &.{ empty, skip, frame });
    defer allocator.free(stream);

    const summary = try vort.lz4SummarizeNativeStream(stream);
    if (summary.frame_count != 2) return error.Lz4ProbeMismatch;
    if (summary.skippable_frame_count != 1) return error.Lz4ProbeMismatch;
    if (summary.skippable_payload_bytes != "metadata-between-frames".len) return error.Lz4ProbeSizeMismatch;
    try expectLz4ConcatenatedPayloadApis(allocator, stream, payload);

    var incremental = vort.Lz4NativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer incremental.deinit();
    var inc_output: [payload.len]u8 = undefined;
    var result = try incremental.step(stream, inc_output[0..0]);
    var output_written: usize = 0;
    while (result.status != .done) {
        if (result.status != .need_output) return error.Lz4ProbeMismatch;
        result = try incremental.step("", inc_output[output_written..]);
        output_written += result.progress.output_written;
    }
    if (output_written != payload.len) return error.Lz4ProbeSizeMismatch;
    if (!std.mem.eql(u8, payload, &inc_output)) return error.Lz4ProbeMismatch;
    try incremental.finish();
}

fn checkPayloadSkippableThenEmptyFrame(allocator: std.mem.Allocator) !void {
    const payload = "payload-before-skip-and-empty";
    const frame = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, payload, .{
        .include_content_size = true,
        .content_checksum = true,
        .block_checksum = true,
    });
    defer allocator.free(frame);
    const skip = try vort.lz4EncodeSkippableFrameAlloc(allocator, 4, "metadata-after-payload");
    defer allocator.free(skip);
    const empty = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, "", .{
        .include_content_size = true,
        .content_checksum = false,
        .block_checksum = false,
    });
    defer allocator.free(empty);
    const stream = try std.mem.concat(allocator, u8, &.{ frame, skip, empty });
    defer allocator.free(stream);

    const summary = try vort.lz4SummarizeNativeStream(stream);
    if (summary.frame_count != 2) return error.Lz4ProbeMismatch;
    if (summary.skippable_frame_count != 1) return error.Lz4ProbeMismatch;
    if (summary.skippable_payload_bytes != "metadata-after-payload".len) return error.Lz4ProbeSizeMismatch;
    try expectLz4ConcatenatedPayloadApis(allocator, stream, payload);

    var incremental = vort.Lz4NativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer incremental.deinit();
    var inc_output: [payload.len]u8 = undefined;
    var result = try incremental.step(stream, inc_output[0..0]);
    var output_written: usize = 0;
    while (result.status != .done) {
        if (result.status != .need_output) return error.Lz4ProbeMismatch;
        result = try incremental.step("", inc_output[output_written..]);
        output_written += result.progress.output_written;
    }
    if (output_written != payload.len) return error.Lz4ProbeSizeMismatch;
    if (!std.mem.eql(u8, payload, &inc_output)) return error.Lz4ProbeMismatch;
    try incremental.finish();
}

fn checkLibLz4GeneratedLibraryFrames(allocator: std.mem.Allocator) !usize {
    var sequential: [2048]u8 = undefined;
    for (&sequential, 0..) |*byte, i| byte.* = @intCast(i % 251);

    var randomish: [2048]u8 = undefined;
    var rng = std.Random.DefaultPrng.init(0x1a34_2026);
    for (&randomish) |*byte| byte.* = rng.random().int(u8);

    var binary_mix: [2048]u8 = undefined;
    for (&binary_mix, 0..) |*byte, i| {
        byte.* = switch (i % 11) {
            0 => 0,
            1 => 0xff,
            2 => @intCast(i & 0xff),
            3 => @intCast((i * 31) & 0xff),
            else => @intCast((i / 3) & 0xff),
        };
    }

    var sparse_zero: [2048]u8 = undefined;
    @memset(&sparse_zero, 0);
    for (&sparse_zero, 0..) |*byte, i| {
        if (i % 97 == 0) byte.* = @intCast((i * 17 + 3) & 0xff);
    }

    const json_unit = "{\"service\":\"vort\",\"codec\":\"lz4\",\"native\":true,\"value\":12345}\n";
    const cases = [_]Case{
        .{ .name = "liblz4-small", .payload = @constCast("lz4-small-reference-payload") },
        .{ .name = "liblz4-repeated", .payload = @constCast("abcd" ** 512) },
        .{ .name = "liblz4-sequential", .payload = &sequential },
        .{ .name = "liblz4-json", .payload = @constCast(json_unit ** 64) },
        .{ .name = "liblz4-binary-mix", .payload = &binary_mix },
        .{ .name = "liblz4-sparse-zero", .payload = &sparse_zero },
        .{ .name = "liblz4-randomish", .payload = &randomish },
    };
    const levels = [_]c_int{ 0, 3, 10 };
    const option_sets = [_]vort.Lz4FrameOptions{
        .{},
        .{
            .include_content_size = false,
            .content_checksum = false,
            .block_checksum = false,
            .block_size_id = .max64kb,
            .block_mode = .independent,
        },
        .{
            .include_content_size = false,
            .content_checksum = true,
            .block_checksum = true,
            .block_size_id = .max64kb,
            .block_mode = .linked,
        },
    };

    var checked: usize = 0;
    for (cases) |case| {
        for (levels) |level| {
            for (option_sets) |options| {
                try checkLibLz4GeneratedLibraryFrame(allocator, case, level, options);
                checked += 1;
            }
        }
    }
    return checked;
}

fn checkLibLz4GeneratedLibraryFrame(
    allocator: std.mem.Allocator,
    case: Case,
    level: c_int,
    options: vort.Lz4FrameOptions,
) !void {
    const frame = try vort.lz4EncodeFrameWithLevelAndOptionsAlloc(allocator, case.payload, level, options);
    defer allocator.free(frame);

    // Pure library differential: liblz4 writes the compatibility frame through
    // Vort's library wrapper, then the dependency-free native decoder must
    // agree across one-shot, caller-buffer, reusable, append, incremental, and
    // bounded-size public APIs. This avoids routing the oracle through the CLI.
    const lib_decoded = try vort.lz4DecodeFrameAlloc(allocator, frame);
    defer allocator.free(lib_decoded);
    try expectPayload(case, lib_decoded);

    const lib_into = try allocator.alloc(u8, case.payload.len);
    defer allocator.free(lib_into);
    const lib_written = try vort.lz4DecodeFrameInto(frame, lib_into);
    if (lib_written != case.payload.len) return error.Lz4ProbeSizeMismatch;
    try expectPayload(case, lib_into[0..lib_written]);

    const header = try vort.lz4InspectNativeFrameHeader(frame);
    if (header.block_checksum != options.block_checksum) return error.Lz4ProbeMismatch;
    if (header.content_checksum != options.content_checksum) return error.Lz4ProbeMismatch;
    if (options.include_content_size) {
        if (header.expected_content_size == null or header.expected_content_size.? != case.payload.len) return error.Lz4ProbeSizeMismatch;
    } else if (header.expected_content_size != null) {
        return error.Lz4ProbeMismatch;
    }

    const summary = try vort.lz4SummarizeNativeFrameBlocks(frame);
    if (case.payload.len == 0) {
        if (summary.block_count != 0) return error.Lz4ProbeSizeMismatch;
    } else if (summary.block_count == 0) {
        return error.Lz4ProbeSizeMismatch;
    }
    const stream_summary = try vort.lz4SummarizeNativeStream(frame);
    if (stream_summary.frame_count != 1 or stream_summary.skippable_frame_count != 0) return error.Lz4ProbeMismatch;
    if (stream_summary.block_count != summary.block_count) return error.Lz4ProbeSizeMismatch;

    if (try vort.lz4DecodedNativeFrameSizeLimited(frame, case.payload.len) != case.payload.len) return error.Lz4ProbeSizeMismatch;
    try expectError(error.OutputLimitExceeded, vort.lz4DecodedNativeFrameSizeLimited(frame, case.payload.len - 1));

    const native_decoded = try vort.lz4DecodeNativeFrameAllocLimited(allocator, frame, case.payload.len);
    defer allocator.free(native_decoded);
    try expectPayload(case, native_decoded);
    try expectAllocError(allocator, error.OutputLimitExceeded, vort.lz4DecodeNativeFrameAllocLimited(allocator, frame, case.payload.len - 1));

    const native_into = try allocator.alloc(u8, case.payload.len);
    defer allocator.free(native_into);
    const native_written = try vort.lz4DecodeNativeFrameInto(frame, native_into);
    if (native_written != case.payload.len) return error.Lz4ProbeSizeMismatch;
    try expectPayload(case, native_into[0..native_written]);
    const exact_written = try vort.lz4DecodeNativeFrameIntoExactSize(frame, native_into, case.payload.len);
    if (exact_written != case.payload.len) return error.Lz4ProbeSizeMismatch;
    try expectPayload(case, native_into[0..exact_written]);
    try expectError(error.OutputTooSmall, vort.lz4DecodeNativeFrameInto(frame, native_into[0 .. native_into.len - 1]));
    try expectError(error.OutputTooSmall, vort.lz4DecodeNativeFrameIntoExactSize(frame, native_into[0 .. native_into.len - 1], case.payload.len));
    if (case.payload.len != 0) try expectError(error.SizeMismatch, vort.lz4DecodeNativeFrameIntoExactSize(frame, native_into, case.payload.len - 1));
    const oversized_into = try allocator.alloc(u8, case.payload.len + 1);
    defer allocator.free(oversized_into);
    try expectError(error.SizeMismatch, vort.lz4DecodeNativeFrameIntoExactSize(frame, oversized_into, case.payload.len + 1));

    var decoder = vort.Lz4NativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    const scratch = try decoder.decodeScratchLimited(frame, case.payload.len);
    try expectPayload(case, scratch);
    try expectError(error.OutputLimitExceeded, decoder.decodeScratchLimited(frame, case.payload.len - 1));
    const reusable_into_written = try decoder.decodeIntoSliceExactSize(frame, native_into, case.payload.len);
    if (reusable_into_written != case.payload.len) return error.Lz4ProbeSizeMismatch;
    try expectPayload(case, native_into[0..reusable_into_written]);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    const appended_written = try decoder.decodeAppendExactSize(&appended, frame, case.payload.len);
    if (appended_written != case.payload.len) return error.Lz4ProbeSizeMismatch;
    if (appended.items.len != "prefix:".len + case.payload.len) return error.Lz4ProbeSizeMismatch;
    if (!std.mem.eql(u8, appended.items[0.."prefix:".len], "prefix:")) return error.Lz4ProbeMismatch;
    if (!std.mem.eql(u8, appended.items["prefix:".len..], case.payload)) return error.Lz4ProbeMismatch;
    appended.clearRetainingCapacity();
    try expectError(error.SizeMismatch, decoder.decodeAppendExactSize(&appended, frame, case.payload.len - 1));

    try checkLibLz4GeneratedIncrementalFrame(allocator, case, frame);
    try checkLibLz4GeneratedChunkedFrame(allocator, case, frame);
}

fn checkLibLz4GeneratedIncrementalFrame(allocator: std.mem.Allocator, case: Case, frame: []const u8) !void {
    var decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = case.payload.len,
        .max_decoded_buffer_len = case.payload.len,
    });
    defer decoder.deinit();

    const output = try allocator.alloc(u8, case.payload.len);
    defer allocator.free(output);
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    var status: vort.StepResult.Status = .need_input;

    while (status != .done) {
        const input_chunk_len: usize = if (input_offset < frame.len) @min(frame.len - input_offset, 13) else 0;
        const remaining_output = output.len - output_offset;
        const output_chunk_len: usize = if (remaining_output == 0) 0 else @min(remaining_output, 127);
        const result = try decoder.step(
            frame[input_offset..][0..input_chunk_len],
            output[output_offset..][0..output_chunk_len],
        );
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
        status = result.status;

        switch (status) {
            .need_input => {
                if (input_offset >= frame.len) return error.Lz4ProbeMismatch;
            },
            .need_output => {
                if (output_offset >= output.len) return error.Lz4ProbeMismatch;
            },
            .done => {},
        }
    }

    if (input_offset != frame.len or output_offset != case.payload.len) return error.Lz4ProbeSizeMismatch;
    try expectPayload(case, output);
    try decoder.finish();
}

fn checkLibLz4GeneratedChunkedFrame(allocator: std.mem.Allocator, case: Case, frame: []const u8) !void {
    const split_a: usize = @min(frame.len, 3);
    const split_b: usize = @min(frame.len, split_a + 17);
    const chunks = [_][]const u8{
        frame[0..split_a],
        frame[split_a..split_b],
        frame[split_b..],
    };
    const join = try allocator.alloc(u8, frame.len);
    defer allocator.free(join);

    if (try vort.lz4DecodedNativeFrameChunksSize(&chunks, join) != case.payload.len) return error.Lz4ProbeSizeMismatch;
    if (try vort.lz4DecodedNativeFrameChunksSizeLimited(&chunks, join, case.payload.len) != case.payload.len) return error.Lz4ProbeSizeMismatch;
    try expectError(error.OutputLimitExceeded, vort.lz4DecodedNativeFrameChunksSizeLimited(&chunks, join, case.payload.len - 1));

    const decoded = try vort.lz4DecodeNativeFrameChunksAllocLimited(allocator, &chunks, join, case.payload.len);
    defer allocator.free(decoded);
    try expectPayload(case, decoded);
    try expectAllocError(allocator, error.OutputLimitExceeded, vort.lz4DecodeNativeFrameChunksAllocLimited(allocator, &chunks, join, case.payload.len - 1));

    const into = try allocator.alloc(u8, case.payload.len);
    defer allocator.free(into);
    const written = try vort.lz4DecodeNativeFrameChunksInto(&chunks, join, into);
    if (written != case.payload.len) return error.Lz4ProbeSizeMismatch;
    try expectPayload(case, into[0..written]);
    const exact_written = try vort.lz4DecodeNativeFrameChunksIntoExactSize(&chunks, join, into, case.payload.len);
    if (exact_written != case.payload.len) return error.Lz4ProbeSizeMismatch;
    try expectPayload(case, into[0..exact_written]);
    try expectError(error.OutputTooSmall, vort.lz4DecodeNativeFrameChunksInto(&chunks, join, into[0 .. into.len - 1]));
    try expectError(error.OutputTooSmall, vort.lz4DecodeNativeFrameChunksIntoExactSize(&chunks, join, into[0 .. into.len - 1], case.payload.len));
    if (case.payload.len != 0) try expectError(error.SizeMismatch, vort.lz4DecodeNativeFrameChunksIntoExactSize(&chunks, join, into, case.payload.len - 1));
    const oversized_into = try allocator.alloc(u8, case.payload.len + 1);
    defer allocator.free(oversized_into);
    try expectError(error.SizeMismatch, vort.lz4DecodeNativeFrameChunksIntoExactSize(&chunks, join, oversized_into, case.payload.len + 1));

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    const appended_written = try vort.lz4DecodeNativeFrameChunksAppendExactSize(allocator, &appended, &chunks, join, case.payload.len);
    if (appended_written != case.payload.len) return error.Lz4ProbeSizeMismatch;
    if (!std.mem.eql(u8, appended.items[0.."prefix:".len], "prefix:")) return error.Lz4ProbeMismatch;
    if (!std.mem.eql(u8, appended.items["prefix:".len..], case.payload)) return error.Lz4ProbeMismatch;
    appended.clearRetainingCapacity();
    try expectError(error.SizeMismatch, vort.lz4DecodeNativeFrameChunksAppendExactSize(allocator, &appended, &chunks, join, case.payload.len - 1));

    var decoder = vort.Lz4NativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    if (try decoder.decodedChunksSize(&chunks, join) != case.payload.len) return error.Lz4ProbeSizeMismatch;
    if (try decoder.decodedChunksSizeLimited(&chunks, join, case.payload.len) != case.payload.len) return error.Lz4ProbeSizeMismatch;
    try expectError(error.OutputLimitExceeded, decoder.decodedChunksSizeLimited(&chunks, join, case.payload.len - 1));

    const reusable_decoded = try decoder.decodeChunksAllocLimited(&chunks, join, case.payload.len);
    defer allocator.free(reusable_decoded);
    try expectPayload(case, reusable_decoded);
    try expectAllocError(allocator, error.OutputLimitExceeded, decoder.decodeChunksAllocLimited(&chunks, join, case.payload.len - 1));

    const scratch = try decoder.decodeChunksScratchLimited(&chunks, join, case.payload.len);
    try expectPayload(case, scratch);
    try expectError(error.OutputLimitExceeded, decoder.decodeChunksScratchLimited(&chunks, join, case.payload.len - 1));
    const reusable_exact_written = try decoder.decodeChunksIntoSliceExactSize(&chunks, join, into, case.payload.len);
    if (reusable_exact_written != case.payload.len) return error.Lz4ProbeSizeMismatch;
    try expectPayload(case, into[0..reusable_exact_written]);

    const reusable_into = try allocator.alloc(u8, case.payload.len);
    defer allocator.free(reusable_into);
    const reusable_written = try decoder.decodeChunksIntoSlice(&chunks, join, reusable_into);
    if (reusable_written != case.payload.len) return error.Lz4ProbeSizeMismatch;
    try expectPayload(case, reusable_into[0..reusable_written]);
    try expectError(error.OutputTooSmall, decoder.decodeChunksIntoSlice(&chunks, join, reusable_into[0 .. reusable_into.len - 1]));

    var reusable_appended: std.ArrayList(u8) = .empty;
    defer reusable_appended.deinit(allocator);
    try reusable_appended.appendSlice(allocator, "prefix:");
    const reusable_appended_written = try decoder.decodeChunksAppendExactSize(&reusable_appended, &chunks, join, case.payload.len);
    if (reusable_appended_written != case.payload.len) return error.Lz4ProbeSizeMismatch;
    if (!std.mem.eql(u8, reusable_appended.items[0.."prefix:".len], "prefix:")) return error.Lz4ProbeMismatch;
    if (!std.mem.eql(u8, reusable_appended.items["prefix:".len..], case.payload)) return error.Lz4ProbeMismatch;
    reusable_appended.clearRetainingCapacity();
    try expectError(error.SizeMismatch, decoder.decodeChunksAppendExactSize(&reusable_appended, &chunks, join, case.payload.len - 1));
}

fn checkSkippableMalformedStreams(allocator: std.mem.Allocator) !usize {
    var checked: usize = 0;
    const skip = try vort.lz4EncodeSkippableFrameAlloc(allocator, 7, "lz4-metadata");
    defer allocator.free(skip);
    const reserved_header = try minimalHeaderOnlyFrame(allocator, 0x62, 0x70);
    defer allocator.free(reserved_header);
    const truncated_frame = try frameWithSingleBlock(allocator, 0x60, 0x40, 0x8000_0000 | (64 * 1024), "ab", "");
    defer allocator.free(truncated_frame);

    const skippable_then_reserved = try std.mem.concat(allocator, u8, &.{ skip, reserved_header });
    defer allocator.free(skippable_then_reserved);
    try expectNativeConcatenatedStreamError(allocator, skippable_then_reserved, error.CorruptFrame);
    var iterator = vort.lz4IterateNativeStream(skippable_then_reserved);
    const first = (try iterator.next()) orelse return error.Lz4ProbeMismatch;
    switch (first) {
        .frame => return error.Lz4ProbeMismatch,
        .skippable => |skippable| {
            if (skippable.header.skippable_id != 7) return error.Lz4ProbeMismatch;
            if (!std.mem.eql(u8, skippable.payload, "lz4-metadata")) return error.Lz4ProbeMismatch;
        },
    }
    if (iterator.next()) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != error.CorruptFrame) return err;
    checked += 1;

    const reserved_then_skippable = try std.mem.concat(allocator, u8, &.{ reserved_header, skip });
    defer allocator.free(reserved_then_skippable);
    try expectNativeConcatenatedStreamError(allocator, reserved_then_skippable, error.CorruptFrame);
    var malformed_first = vort.lz4IterateNativeStream(reserved_then_skippable);
    if (malformed_first.next()) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != error.CorruptFrame) return err;
    checked += 1;

    const skippable_then_truncated = try std.mem.concat(allocator, u8, &.{ skip, truncated_frame });
    defer allocator.free(skippable_then_truncated);
    try expectNativeConcatenatedStreamError(allocator, skippable_then_truncated, error.TruncatedFrame);
    var truncated_after_skip = vort.lz4IterateNativeStream(skippable_then_truncated);
    const truncated_first = (try truncated_after_skip.next()) orelse return error.Lz4ProbeMismatch;
    switch (truncated_first) {
        .frame => return error.Lz4ProbeMismatch,
        .skippable => |skippable| {
            if (skippable.header.skippable_id != 7) return error.Lz4ProbeMismatch;
            if (!std.mem.eql(u8, skippable.payload, "lz4-metadata")) return error.Lz4ProbeMismatch;
        },
    }
    if (truncated_after_skip.next()) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != error.TruncatedFrame) return err;
    checked += 1;

    const truncated_then_skippable = try std.mem.concat(allocator, u8, &.{ truncated_frame, skip });
    defer allocator.free(truncated_then_skippable);
    try expectNativeConcatenatedStreamError(allocator, truncated_then_skippable, error.TruncatedFrame);
    var truncated_first_stream = vort.lz4IterateNativeStream(truncated_then_skippable);
    if (truncated_first_stream.next()) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != error.TruncatedFrame) return err;
    checked += 1;

    const payload = "payload-before-truncated-skip";
    const frame = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, payload, .{
        .include_content_size = true,
        .content_checksum = false,
        .block_checksum = false,
    });
    defer allocator.free(frame);
    const truncated_skip_header = skip[0..5];
    const payload_then_truncated_skip = try std.mem.concat(allocator, u8, &.{ frame, truncated_skip_header });
    defer allocator.free(payload_then_truncated_skip);
    try expectNativeConcatenatedStreamError(allocator, payload_then_truncated_skip, error.TruncatedFrame);
    var payload_then_truncated_iter = vort.lz4IterateNativeStream(payload_then_truncated_skip);
    const payload_frame = (try payload_then_truncated_iter.next()) orelse return error.Lz4ProbeMismatch;
    switch (payload_frame) {
        .skippable => return error.Lz4ProbeMismatch,
        .frame => |item| if (try vort.lz4DecodedNativeFrameSize(item.bytes) != payload.len) return error.Lz4ProbeSizeMismatch,
    }
    if (payload_then_truncated_iter.next()) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != error.TruncatedFrame) return err;
    checked += 1;

    const empty = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, "", .{
        .include_content_size = true,
        .content_checksum = false,
        .block_checksum = false,
    });
    defer allocator.free(empty);
    const empty_then_truncated_skip = try std.mem.concat(allocator, u8, &.{ empty, truncated_skip_header });
    defer allocator.free(empty_then_truncated_skip);
    try expectNativeConcatenatedStreamError(allocator, empty_then_truncated_skip, error.TruncatedFrame);
    var empty_then_truncated_iter = vort.lz4IterateNativeStream(empty_then_truncated_skip);
    const empty_frame = (try empty_then_truncated_iter.next()) orelse return error.Lz4ProbeMismatch;
    switch (empty_frame) {
        .skippable => return error.Lz4ProbeMismatch,
        .frame => |item| if (try vort.lz4DecodedNativeFrameSize(item.bytes) != 0) return error.Lz4ProbeSizeMismatch,
    }
    if (empty_then_truncated_iter.next()) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != error.TruncatedFrame) return err;
    checked += 1;

    const truncated_skip_then_payload = try std.mem.concat(allocator, u8, &.{ truncated_skip_header, frame });
    defer allocator.free(truncated_skip_then_payload);
    try expectNativeConcatenatedStreamError(allocator, truncated_skip_then_payload, error.TruncatedFrame);
    var truncated_skip_first = vort.lz4IterateNativeStream(truncated_skip_then_payload);
    if (truncated_skip_first.next()) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != error.TruncatedFrame) return err;
    checked += 1;

    const truncated_skip_then_empty = try std.mem.concat(allocator, u8, &.{ truncated_skip_header, empty });
    defer allocator.free(truncated_skip_then_empty);
    try expectNativeConcatenatedStreamError(allocator, truncated_skip_then_empty, error.TruncatedFrame);
    var truncated_skip_empty_first = vort.lz4IterateNativeStream(truncated_skip_then_empty);
    if (truncated_skip_empty_first.next()) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != error.TruncatedFrame) return err;
    checked += 1;

    var huge_skip = try allocator.alloc(u8, 12);
    defer allocator.free(huge_skip);
    std.mem.writeInt(u32, huge_skip[0..4], 0x184d2a50, .little);
    std.mem.writeInt(u32, huge_skip[4..8], std.math.maxInt(u32), .little);
    @memset(huge_skip[8..], 'x');
    try expectError(error.TruncatedFrame, vort.lz4InspectNativeSkippableFrame(huge_skip));
    try expectNativeConcatenatedStreamError(allocator, huge_skip, error.TruncatedFrame);
    var huge_skip_iter = vort.lz4IterateNativeStream(huge_skip);
    if (huge_skip_iter.next()) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != error.TruncatedFrame) return err;
    checked += 1;

    const huge_skip_then_payload = try std.mem.concat(allocator, u8, &.{ huge_skip, frame });
    defer allocator.free(huge_skip_then_payload);
    try expectNativeConcatenatedStreamError(allocator, huge_skip_then_payload, error.TruncatedFrame);
    var huge_skip_then_payload_iter = vort.lz4IterateNativeStream(huge_skip_then_payload);
    if (huge_skip_then_payload_iter.next()) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != error.TruncatedFrame) return err;
    checked += 1;

    return checked;
}

fn checkSkippableChecksumAndTrailingStreams(allocator: std.mem.Allocator) !usize {
    var checked: usize = 0;
    const skip = try vort.lz4EncodeSkippableFrameAlloc(allocator, 2, "before-frame");
    defer allocator.free(skip);

    const checksum_payload = "skipped-checksum";
    var wrong_checksum_tail: [8]u8 = undefined;
    @memset(wrong_checksum_tail[0..4], 0);
    std.mem.writeInt(u32, wrong_checksum_tail[4..8], std.hash.XxHash32.hash(0, checksum_payload) ^ 0x01, .little);
    const checksum_frame = try frameWithSingleBlock(allocator, 0x64, 0x40, 0x8000_0000 | checksum_payload.len, checksum_payload, &wrong_checksum_tail);
    defer allocator.free(checksum_frame);
    const checksum_stream = try std.mem.concat(allocator, u8, &.{ skip, checksum_frame });
    defer allocator.free(checksum_stream);

    const checksum_summary = try vort.lz4SummarizeNativeStream(checksum_stream);
    if (checksum_summary.skippable_frame_count != 1 or checksum_summary.frame_count != 1) return error.Lz4ProbeMismatch;
    if (try vort.lz4DecodedNativeConcatenatedFrameSize(checksum_stream) != checksum_payload.len) return error.Lz4ProbeSizeMismatch;
    var checksum_output: [checksum_payload.len]u8 = undefined;
    if (vort.lz4DecodeNativeConcatenatedFrameInto(checksum_stream, &checksum_output)) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != error.ChecksumMismatch) return err;
    if (vort.lz4DecodeNativeConcatenatedFrameAlloc(allocator, checksum_stream)) |decoded| {
        allocator.free(decoded);
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != error.ChecksumMismatch) return err;

    var checksum_iterator = vort.lz4IterateNativeStream(checksum_stream);
    const checksum_skip = (try checksum_iterator.next()) orelse return error.Lz4ProbeMismatch;
    switch (checksum_skip) {
        .frame => return error.Lz4ProbeMismatch,
        .skippable => |skippable| {
            if (skippable.header.skippable_id != 2) return error.Lz4ProbeMismatch;
            if (!std.mem.eql(u8, skippable.payload, "before-frame")) return error.Lz4ProbeMismatch;
        },
    }
    const checksum_frame_element = (try checksum_iterator.next()) orelse return error.Lz4ProbeMismatch;
    switch (checksum_frame_element) {
        .skippable => return error.Lz4ProbeMismatch,
        .frame => |frame| {
            if (!frame.header.content_checksum) return error.Lz4ProbeMismatch;
            if (vort.lz4DecodeNativeFrameAlloc(allocator, frame.bytes)) |decoded| {
                allocator.free(decoded);
                return error.Lz4ProbeExpectedFrameError;
            } else |err| if (@as(anyerror, err) != error.ChecksumMismatch) return err;
        },
    }
    if ((try checksum_iterator.next()) != null) return error.Lz4ProbeMismatch;
    checked += 1;

    const trailing_payload = "skipped-trailing";
    const trailing_tail = [_]u8{ 0, 0, 0, 0, 'x', 'x' };
    const trailing_frame = try frameWithSingleBlock(allocator, 0x60, 0x40, 0x8000_0000 | trailing_payload.len, trailing_payload, &trailing_tail);
    defer allocator.free(trailing_frame);
    const trailing_stream = try std.mem.concat(allocator, u8, &.{ skip, trailing_frame });
    defer allocator.free(trailing_stream);
    try expectNativeConcatenatedStreamError(allocator, trailing_stream, error.TruncatedFrame);

    var trailing_iterator = vort.lz4IterateNativeStream(trailing_stream);
    const trailing_skip = (try trailing_iterator.next()) orelse return error.Lz4ProbeMismatch;
    switch (trailing_skip) {
        .frame => return error.Lz4ProbeMismatch,
        .skippable => |skippable| {
            if (skippable.header.skippable_id != 2) return error.Lz4ProbeMismatch;
            if (!std.mem.eql(u8, skippable.payload, "before-frame")) return error.Lz4ProbeMismatch;
        },
    }
    const trailing_frame_element = (try trailing_iterator.next()) orelse return error.Lz4ProbeMismatch;
    switch (trailing_frame_element) {
        .skippable => return error.Lz4ProbeMismatch,
        .frame => |frame| {
            const decoded = try vort.lz4DecodeNativeFrameAlloc(allocator, frame.bytes);
            defer allocator.free(decoded);
            if (!std.mem.eql(u8, trailing_payload, decoded)) return error.Lz4ProbeMismatch;
        },
    }
    if (trailing_iterator.next()) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != error.TruncatedFrame) return err;
    checked += 1;

    return checked;
}

fn checkInvalidFrameHeaders(allocator: std.mem.Allocator) !usize {
    const cases = [_]struct {
        name: []const u8,
        flg: u8,
        bd: u8,
        expected: anyerror,
    }{
        // FLG bit 1 is reserved by the LZ4 frame format. Compute a matching
        // header checksum so this verifies reserved-bit handling rather than
        // accidentally passing through the checksum-mismatch path.
        .{ .name = "flg-reserved-bit", .flg = 0x62, .bd = 0x70, .expected = error.CorruptFrame },
        .{ .name = "bd-reserved-bit", .flg = 0x60, .bd = 0x71, .expected = error.CorruptFrame },
        .{ .name = "unsupported-version", .flg = 0x20, .bd = 0x70, .expected = error.UnsupportedVersion },
    };

    var checked: usize = 0;
    for (cases) |case| {
        const frame = try minimalHeaderOnlyFrame(allocator, case.flg, case.bd);
        defer allocator.free(frame);
        try expectNativeFrameError(allocator, frame, case.expected);
        checked += 1;
    }
    return checked;
}

fn checkInvalidFrameBlocks(allocator: std.mem.Allocator) !usize {
    var checked: usize = 0;

    const too_large = try frameWithSingleBlock(allocator, 0x60, 0x40, 0x8000_0000 | (64 * 1024 + 1), "", "");
    defer allocator.free(too_large);
    try expectNativeFrameBodyError(allocator, too_large, error.CorruptFrame);
    checked += 1;

    const compressed_too_large = try frameWithSingleBlock(allocator, 0x60, 0x40, 64 * 1024 + 1, "", "");
    defer allocator.free(compressed_too_large);
    try expectNativeFrameBodyError(allocator, compressed_too_large, error.CorruptFrame);
    checked += 1;

    const truncated_payload = try frameWithSingleBlock(allocator, 0x60, 0x40, 0x8000_0000 | 4, "ab", "");
    defer allocator.free(truncated_payload);
    try expectNativeFrameBodyError(allocator, truncated_payload, error.TruncatedFrame);
    checked += 1;

    const truncated_compressed_literals = try frameWithSingleBlock(allocator, 0x60, 0x40, 4, "\x60ab", "");
    defer allocator.free(truncated_compressed_literals);
    try expectNativeFrameBodyError(allocator, truncated_compressed_literals, error.TruncatedFrame);
    checked += 1;

    const truncated_literal_len_extension = try frameWithSingleBlock(allocator, 0x60, 0x40, 1, "\xf0", "\x00\x00\x00\x00");
    defer allocator.free(truncated_literal_len_extension);
    try expectNativeFrameDecodeAndSizeError(allocator, truncated_literal_len_extension, error.TruncatedFrame);
    checked += 1;

    const truncated_match_len_extension = try frameWithSingleBlock(allocator, 0x60, 0x40, 4, "\x1fa\x01\x00", "\x00\x00\x00\x00");
    defer allocator.free(truncated_match_len_extension);
    try expectNativeFrameDecodeAndSizeError(allocator, truncated_match_len_extension, error.TruncatedFrame);
    checked += 1;

    const invalid_match_offset = try frameWithSingleBlock(allocator, 0x60, 0x40, 3, "\x00\x01\x00", "\x00\x00\x00\x00");
    defer allocator.free(invalid_match_offset);
    try expectNativeFrameDecodeAndSizeError(allocator, invalid_match_offset, error.InvalidMatch);
    checked += 1;

    const zero_match_offset = try frameWithSingleBlock(allocator, 0x60, 0x40, 4, "\x10a\x00\x00", "\x00\x00\x00\x00");
    defer allocator.free(zero_match_offset);
    try expectNativeFrameDecodeAndSizeError(allocator, zero_match_offset, error.InvalidMatch);
    checked += 1;

    const truncated_match_offset = try frameWithSingleBlock(allocator, 0x60, 0x40, 2, "\x00\x01", "\x00\x00\x00\x00");
    defer allocator.free(truncated_match_offset);
    try expectNativeFrameDecodeAndSizeError(allocator, truncated_match_offset, error.TruncatedFrame);
    checked += 1;

    const truncated_block_checksum = try frameWithSingleBlock(allocator, 0x70, 0x40, 0x8000_0000 | 3, "abc", "\x00\x00");
    defer allocator.free(truncated_block_checksum);
    try expectNativeFrameBodyError(allocator, truncated_block_checksum, error.TruncatedFrame);
    checked += 1;

    return checked;
}

fn checkInvalidFrameContentSizes(allocator: std.mem.Allocator) !usize {
    var checked: usize = 0;
    const payload = "abcd";
    const end_mark = [_]u8{ 0, 0, 0, 0 };

    const declared_too_small = try frameWithSingleBlockAndContentSize(
        allocator,
        0x68,
        0x40,
        payload.len - 1,
        0x8000_0000 | payload.len,
        payload,
        &end_mark,
    );
    defer allocator.free(declared_too_small);
    const small_header = try vort.lz4InspectNativeFrameHeader(declared_too_small);
    if (small_header.expected_content_size == null or small_header.expected_content_size.? != payload.len - 1) {
        return error.Lz4ProbeSizeMismatch;
    }
    try expectNativeFrameAndConcatenatedDecodeSizeError(allocator, declared_too_small, error.SizeMismatch);
    checked += 1;

    const declared_too_large = try frameWithSingleBlockAndContentSize(
        allocator,
        0x68,
        0x40,
        payload.len + 1,
        0x8000_0000 | payload.len,
        payload,
        &end_mark,
    );
    defer allocator.free(declared_too_large);
    const large_header = try vort.lz4InspectNativeFrameHeader(declared_too_large);
    if (large_header.expected_content_size == null or large_header.expected_content_size.? != payload.len + 1) {
        return error.Lz4ProbeSizeMismatch;
    }
    try expectNativeFrameAndConcatenatedDecodeSizeError(allocator, declared_too_large, error.SizeMismatch);
    checked += 1;

    return checked;
}

fn checkInvalidFrameChecksumsAndTrailing(allocator: std.mem.Allocator) !usize {
    var checked: usize = 0;

    const header_checksum = try minimalHeaderOnlyFrame(allocator, 0x60, 0x40);
    defer allocator.free(header_checksum);
    header_checksum[6] ^= 0x01;
    try expectNativeFrameError(allocator, header_checksum, error.ChecksumMismatch);
    checked += 1;

    const block_payload = "abc";
    var wrong_block_checksum_tail: [8]u8 = undefined;
    std.mem.writeInt(u32, wrong_block_checksum_tail[0..4], std.hash.XxHash32.hash(0, block_payload) ^ 0x01, .little);
    @memset(wrong_block_checksum_tail[4..8], 0);
    const block_checksum = try frameWithSingleBlock(allocator, 0x70, 0x40, 0x8000_0000 | block_payload.len, block_payload, &wrong_block_checksum_tail);
    defer allocator.free(block_checksum);
    try expectNativeFrameDecodeAndSizeError(allocator, block_checksum, error.ChecksumMismatch);
    checked += 1;

    const content_payload = "content-checksum";
    var truncated_content_tail = [_]u8{ 0, 0, 0, 0, 0, 0 };
    const truncated_content_checksum = try frameWithSingleBlock(allocator, 0x64, 0x40, 0x8000_0000 | content_payload.len, content_payload, &truncated_content_tail);
    defer allocator.free(truncated_content_checksum);
    try expectNativeFrameDecodeAndSizeError(allocator, truncated_content_checksum, error.TruncatedFrame);
    try expectNativeStreamErrorAfterFirstFrame(allocator, truncated_content_checksum, null, error.TruncatedFrame);
    checked += 1;

    var wrong_content_tail: [8]u8 = undefined;
    @memset(wrong_content_tail[0..4], 0);
    std.mem.writeInt(u32, wrong_content_tail[4..8], std.hash.XxHash32.hash(0, content_payload) ^ 0x01, .little);
    const content_checksum = try frameWithSingleBlock(allocator, 0x64, 0x40, 0x8000_0000 | content_payload.len, content_payload, &wrong_content_tail);
    defer allocator.free(content_checksum);
    try expectNativeFrameDecodeErrorWithSize(allocator, content_checksum, error.ChecksumMismatch, content_payload.len);
    checked += 1;

    const trailing_payload = "trail";
    var trailing_tail = [_]u8{ 0, 0, 0, 0, 'x', 'x' };
    const trailing = try frameWithSingleBlock(allocator, 0x60, 0x40, 0x8000_0000 | trailing_payload.len, trailing_payload, &trailing_tail);
    defer allocator.free(trailing);
    try expectNativeFrameDecodeAndSizeError(allocator, trailing, error.TrailingData);
    try expectNativeStreamErrorAfterFirstFrame(allocator, trailing, trailing_payload, error.TruncatedFrame);
    checked += 1;

    return checked;
}

fn minimalHeaderOnlyFrame(allocator: std.mem.Allocator, flg: u8, bd: u8) ![]u8 {
    var frame: std.ArrayList(u8) = .empty;
    errdefer frame.deinit(allocator);
    try appendLz4FrameHeader(allocator, &frame, flg, bd);
    try frame.appendSlice(allocator, &.{ 0, 0, 0, 0 }); // End mark for otherwise header-only frames.
    return try frame.toOwnedSlice(allocator);
}

fn frameWithSingleBlock(
    allocator: std.mem.Allocator,
    flg: u8,
    bd: u8,
    block_header_value: u32,
    payload: []const u8,
    trailing: []const u8,
) ![]u8 {
    var frame: std.ArrayList(u8) = .empty;
    errdefer frame.deinit(allocator);
    try appendLz4FrameHeader(allocator, &frame, flg, bd);
    var block_header: [4]u8 = undefined;
    std.mem.writeInt(u32, &block_header, block_header_value, .little);
    try frame.appendSlice(allocator, &block_header);
    try frame.appendSlice(allocator, payload);
    try frame.appendSlice(allocator, trailing);
    return try frame.toOwnedSlice(allocator);
}

fn frameWithSingleBlockAndContentSize(
    allocator: std.mem.Allocator,
    flg: u8,
    bd: u8,
    content_size: usize,
    block_header_value: u32,
    payload: []const u8,
    trailing: []const u8,
) ![]u8 {
    var frame: std.ArrayList(u8) = .empty;
    errdefer frame.deinit(allocator);
    try appendLz4FrameHeaderWithContentSize(allocator, &frame, flg, bd, content_size);
    var block_header: [4]u8 = undefined;
    std.mem.writeInt(u32, &block_header, block_header_value, .little);
    try frame.appendSlice(allocator, &block_header);
    try frame.appendSlice(allocator, payload);
    try frame.appendSlice(allocator, trailing);
    return try frame.toOwnedSlice(allocator);
}

fn frameWithSingleBlockAndDictionary(
    allocator: std.mem.Allocator,
    flg: u8,
    bd: u8,
    block_header_value: u32,
    payload: []const u8,
    trailing: []const u8,
    dictionary_id: u32,
) ![]u8 {
    var frame: std.ArrayList(u8) = .empty;
    errdefer frame.deinit(allocator);
    try appendLz4FrameHeaderWithDictionary(allocator, &frame, flg, bd, dictionary_id);
    var block_header: [4]u8 = undefined;
    std.mem.writeInt(u32, &block_header, block_header_value, .little);
    try frame.appendSlice(allocator, &block_header);
    try frame.appendSlice(allocator, payload);
    try frame.appendSlice(allocator, trailing);
    return try frame.toOwnedSlice(allocator);
}

fn frameWithSingleBlockAndContentSizeAndDictionary(
    allocator: std.mem.Allocator,
    flg: u8,
    bd: u8,
    content_size: usize,
    block_header_value: u32,
    payload: []const u8,
    trailing: []const u8,
    dictionary_id: u32,
) ![]u8 {
    var frame: std.ArrayList(u8) = .empty;
    errdefer frame.deinit(allocator);
    try appendLz4FrameHeaderWithContentSizeAndDictionary(allocator, &frame, flg, bd, content_size, dictionary_id);
    var block_header: [4]u8 = undefined;
    std.mem.writeInt(u32, &block_header, block_header_value, .little);
    try frame.appendSlice(allocator, &block_header);
    try frame.appendSlice(allocator, payload);
    try frame.appendSlice(allocator, trailing);
    return try frame.toOwnedSlice(allocator);
}

fn appendLz4FrameHeader(allocator: std.mem.Allocator, frame: *std.ArrayList(u8), flg: u8, bd: u8) !void {
    try frame.appendSlice(allocator, &.{ 0x04, 0x22, 0x4d, 0x18 });
    const descriptor = [_]u8{ flg, bd };
    try frame.appendSlice(allocator, &descriptor);
    try frame.append(allocator, lz4DescriptorChecksum(&descriptor));
}

fn appendLz4FrameHeaderWithContentSize(allocator: std.mem.Allocator, frame: *std.ArrayList(u8), flg: u8, bd: u8, content_size: usize) !void {
    try frame.appendSlice(allocator, &.{ 0x04, 0x22, 0x4d, 0x18 });
    var descriptor: [10]u8 = undefined;
    descriptor[0] = flg;
    descriptor[1] = bd;
    std.mem.writeInt(u64, descriptor[2..10], @intCast(content_size), .little);
    try frame.appendSlice(allocator, &descriptor);
    try frame.append(allocator, lz4DescriptorChecksum(&descriptor));
}

fn appendLz4FrameHeaderWithDictionary(allocator: std.mem.Allocator, frame: *std.ArrayList(u8), flg: u8, bd: u8, dictionary_id: u32) !void {
    try frame.appendSlice(allocator, &.{ 0x04, 0x22, 0x4d, 0x18 });
    var descriptor: [6]u8 = undefined;
    descriptor[0] = flg;
    descriptor[1] = bd;
    std.mem.writeInt(u32, descriptor[2..6], dictionary_id, .little);
    try frame.appendSlice(allocator, &descriptor);
    try frame.append(allocator, lz4DescriptorChecksum(&descriptor));
}

fn appendLz4FrameHeaderWithContentSizeAndDictionary(
    allocator: std.mem.Allocator,
    frame: *std.ArrayList(u8),
    flg: u8,
    bd: u8,
    content_size: usize,
    dictionary_id: u32,
) !void {
    try frame.appendSlice(allocator, &.{ 0x04, 0x22, 0x4d, 0x18 });
    var descriptor: [14]u8 = undefined;
    descriptor[0] = flg;
    descriptor[1] = bd;
    std.mem.writeInt(u64, descriptor[2..10], @intCast(content_size), .little);
    std.mem.writeInt(u32, descriptor[10..14], dictionary_id, .little);
    try frame.appendSlice(allocator, &descriptor);
    try frame.append(allocator, lz4DescriptorChecksum(&descriptor));
}

fn lz4DescriptorChecksum(descriptor: []const u8) u8 {
    return @truncate(std.hash.XxHash32.hash(0, descriptor) >> 8);
}

fn expectError(expected: anyerror, result: anytype) !void {
    if (result) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != expected) return err;
}

fn expectAllocError(allocator: std.mem.Allocator, expected: anyerror, result: anytype) !void {
    if (result) |decoded| {
        allocator.free(decoded);
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != expected) return err;
}

fn expectNeedDictionary(result: anytype) !void {
    if (result) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| switch (err) {
        error.NeedDictionary => {},
        else => return err,
    }
}

fn expectAllocNeedDictionary(allocator: std.mem.Allocator, result: anytype) !void {
    if (result) |decoded| {
        allocator.free(decoded);
        return error.Lz4ProbeExpectedFrameError;
    } else |err| switch (err) {
        error.NeedDictionary => {},
        else => return err,
    }
}

fn expectNativeFrameError(allocator: std.mem.Allocator, frame: []const u8, expected: anyerror) !void {
    if (vort.lz4InspectNativeFrameHeader(frame)) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != expected) return err;

    if (vort.lz4DecodedNativeFrameSize(frame)) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != expected) return err;

    var output: [1]u8 = undefined;
    if (vort.lz4DecodeNativeFrameInto(frame, &output)) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != expected) return err;

    if (vort.lz4DecodeNativeFrameAlloc(allocator, frame)) |decoded| {
        allocator.free(decoded);
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != expected) return err;

    if (vort.lz4SummarizeNativeStream(frame)) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != expected) return err;

    var iterator = vort.lz4IterateNativeStream(frame);
    if (iterator.next()) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != expected) return err;
}

fn expectNativeFrameBodyError(allocator: std.mem.Allocator, frame: []const u8, expected: anyerror) !void {
    _ = try vort.lz4InspectNativeFrameHeader(frame);

    if (vort.lz4DecodedNativeFrameSize(frame)) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != expected) return err;

    const output = try allocator.alloc(u8, 64 * 1024 + 16);
    defer allocator.free(output);
    if (vort.lz4DecodeNativeFrameInto(frame, output)) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != expected) return err;

    if (vort.lz4DecodeNativeFrameAlloc(allocator, frame)) |decoded| {
        allocator.free(decoded);
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != expected) return err;

    if (vort.lz4SummarizeNativeFrameBlocks(frame)) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != expected) return err;

    if (vort.lz4SummarizeNativeStream(frame)) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != expected) return err;

    var iterator = vort.lz4IterateNativeStream(frame);
    if (iterator.next()) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != expected) return err;
}

fn expectNativeFrameDecodeAndSizeError(allocator: std.mem.Allocator, frame: []const u8, expected: anyerror) !void {
    _ = try vort.lz4InspectNativeFrameHeader(frame);

    if (vort.lz4DecodedNativeFrameSize(frame)) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != expected) return err;

    const output = try allocator.alloc(u8, 64 * 1024 + 16);
    defer allocator.free(output);
    if (vort.lz4DecodeNativeFrameInto(frame, output)) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != expected) return err;

    if (vort.lz4DecodeNativeFrameAlloc(allocator, frame)) |decoded| {
        allocator.free(decoded);
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != expected) return err;
}

fn expectNativeFrameAndConcatenatedDecodeSizeError(allocator: std.mem.Allocator, frame: []const u8, expected: anyerror) !void {
    try expectNativeFrameDecodeAndSizeError(allocator, frame, expected);

    const block_summary = try vort.lz4SummarizeNativeFrameBlocks(frame);
    if (block_summary.block_count != 1) return error.Lz4ProbeSizeMismatch;
    const stream_summary = try vort.lz4SummarizeNativeStream(frame);
    if (stream_summary.frame_count != 1 or stream_summary.block_count != 1) return error.Lz4ProbeSizeMismatch;

    if (vort.lz4DecodedNativeConcatenatedFrameSize(frame)) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != expected) return err;

    const output = try allocator.alloc(u8, 64 * 1024 + 16);
    defer allocator.free(output);
    if (vort.lz4DecodeNativeConcatenatedFrameInto(frame, output)) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != expected) return err;

    if (vort.lz4DecodeNativeConcatenatedFrameAlloc(allocator, frame)) |decoded| {
        allocator.free(decoded);
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != expected) return err;
}

fn expectNativeFrameDecodeErrorWithSize(
    allocator: std.mem.Allocator,
    frame: []const u8,
    expected_decode_error: anyerror,
    expected_size: usize,
) !void {
    _ = try vort.lz4InspectNativeFrameHeader(frame);
    if (try vort.lz4DecodedNativeFrameSize(frame) != expected_size) return error.Lz4ProbeSizeMismatch;

    const output = try allocator.alloc(u8, expected_size);
    defer allocator.free(output);
    if (vort.lz4DecodeNativeFrameInto(frame, output)) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != expected_decode_error) return err;

    if (vort.lz4DecodeNativeFrameAlloc(allocator, frame)) |decoded| {
        allocator.free(decoded);
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != expected_decode_error) return err;
}

fn expectNativeConcatenatedStreamError(allocator: std.mem.Allocator, stream: []const u8, expected: anyerror) !void {
    if (vort.lz4DecodedNativeConcatenatedFrameSize(stream)) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != expected) return err;

    const output = try allocator.alloc(u8, 64 * 1024 + 16);
    defer allocator.free(output);
    if (vort.lz4DecodeNativeConcatenatedFrameInto(stream, output)) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != expected) return err;

    if (vort.lz4DecodeNativeConcatenatedFrameAlloc(allocator, stream)) |decoded| {
        allocator.free(decoded);
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != expected) return err;

    if (vort.lz4SummarizeNativeStream(stream)) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != expected) return err;
}

fn expectNativeStreamErrorAfterFirstFrame(
    allocator: std.mem.Allocator,
    frame: []const u8,
    expected_first_payload: ?[]const u8,
    expected_stream_error: anyerror,
) !void {
    if (vort.lz4SummarizeNativeStream(frame)) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != expected_stream_error) return err;

    var iterator = vort.lz4IterateNativeStream(frame);
    if (expected_first_payload) |payload| {
        const first = (try iterator.next()) orelse return error.Lz4ProbeMismatch;
        switch (first) {
            .frame => |stream_frame| {
                const decoded = try vort.lz4DecodeNativeFrameAlloc(allocator, stream_frame.bytes);
                defer allocator.free(decoded);
                if (!std.mem.eql(u8, payload, decoded)) return error.Lz4ProbeMismatch;
            },
            .skippable => return error.Lz4ProbeMismatch,
        }
    }
    if (iterator.next()) |_| {
        return error.Lz4ProbeExpectedFrameError;
    } else |err| if (@as(anyerror, err) != expected_stream_error) return err;
}

fn expectPayload(case: Case, decoded: []const u8) !void {
    if (!std.mem.eql(u8, case.payload, decoded)) {
        std.debug.print(
            "lz4 probe mismatch case={s} expected_len={d} got_len={d} expected_crc={d} got_crc={d}\n",
            .{ case.name, case.payload.len, decoded.len, std.hash.Crc32.hash(case.payload), std.hash.Crc32.hash(decoded) },
        );
        return error.Lz4ProbeMismatch;
    }
}
