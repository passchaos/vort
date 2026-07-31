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
    checked += try checkInvalidFrameHeaders(init.gpa);
    checked += try checkInvalidFrameBlocks(init.gpa);
    checked += try checkInvalidFrameChecksumsAndTrailing(init.gpa);

    try stdout.print("lz4_native_probe_ok cases={d}\n", .{checked});
    try stdout.flush();
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
        .content_checksum = false,
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
    const skip = try vort.lz4EncodeSkippableFrameAlloc(allocator, 5, "metadata-only");
    defer allocator.free(skip);

    const decoded = try vort.lz4DecodeNativeConcatenatedFrameAlloc(allocator, skip);
    defer allocator.free(decoded);
    if (decoded.len != 0) return error.Lz4ProbeSizeMismatch;
    const exact = try vort.lz4DecodeNativeConcatenatedFrameAllocExactSize(allocator, skip, 0);
    defer allocator.free(exact);
    if (exact.len != 0) return error.Lz4ProbeSizeMismatch;

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

    const truncated_payload = try frameWithSingleBlock(allocator, 0x60, 0x40, 0x8000_0000 | 4, "ab", "");
    defer allocator.free(truncated_payload);
    try expectNativeFrameBodyError(allocator, truncated_payload, error.TruncatedFrame);
    checked += 1;

    const truncated_block_checksum = try frameWithSingleBlock(allocator, 0x70, 0x40, 0x8000_0000 | 3, "abc", "\x00\x00");
    defer allocator.free(truncated_block_checksum);
    try expectNativeFrameBodyError(allocator, truncated_block_checksum, error.TruncatedFrame);
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

fn appendLz4FrameHeader(allocator: std.mem.Allocator, frame: *std.ArrayList(u8), flg: u8, bd: u8) !void {
    try frame.appendSlice(allocator, &.{ 0x04, 0x22, 0x4d, 0x18 });
    const descriptor = [_]u8{ flg, bd };
    try frame.appendSlice(allocator, &descriptor);
    try frame.append(allocator, lz4DescriptorChecksum(&descriptor));
}

fn lz4DescriptorChecksum(descriptor: []const u8) u8 {
    return @truncate(std.hash.XxHash32.hash(0, descriptor) >> 8);
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
