const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var stdout_buffer: [256]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    const filter = try parseProbeFilter(init);
    var checked: usize = 0;
    var non_lib_generated_cases: usize = 0;
    if (filter.runHandcrafted()) {
        try checkDirectHuffmanBoundaries(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkNoSizeCompressedBlockLimits(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkHighByteFseHuffman(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkSystemZstdHighByteFrame(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkTreelessRepeatHuffmanLiterals(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkTreelessRepeatHuffmanAcrossRawBlock(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkTreelessRepeatHuffmanAcrossRleBlock(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkRepeatOffsetAdditionalBits(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkRepeatOffsetZeroLiteralSelector(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkRepeatOffsetZeroLiteralSecondSelector(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkRepeatOffsetLiteralZerothSelector(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkRepeatOffsetRepeatModePositiveSelector(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkRepeatOffsetRepeatModePositiveSecondSelectors(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkRepeatOffsetLiteralFirstSelector(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkRepeatOffsetLiteralSecondSelector(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkRepeatOffsetZeroLiteralInvalidSelector(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkRepeatOffsetZeroLiteralRep0MinusOneAfterUpdate(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkRepeatOffsetRepeatModeZeroLiteralRep0MinusOneAfterUpdate(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkRepeatedRleSequenceTables(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkMultiplePredefinedSequenceStateTransitions(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkManyPredefinedSequenceStateTransitions(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkFirstBlockRepeatSequenceModeIsRejected(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkFirstBlockMixedRepeatSequenceModeIsRejected(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkFirstBlockOffsetAndMatchRepeatSequenceModesAreRejected(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkMixedRlePredefinedSequenceModes(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkRepeatMixedRlePredefinedSequenceModes(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkRepeatSequenceTablesAcrossRawBlock(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkRepeatSequenceTablesAcrossRleBlock(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkRepeatSequenceTablesAcrossRawAndRleBlocks(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkRepeatSequenceTablesAcrossRleAndRawBlocks(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkLiteralLengthCompressedThenRepeatedSequenceTables(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkMatchLengthCompressedThenRepeatedSequenceTables(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkOffsetCompressedThenRepeatedSequenceTables(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkOffsetAndMatchLengthCompressedSequenceTables(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkCompressedOffsetRepeatSelectorFrame(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkAllCompressedSequenceTableFrame(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkAllCompressedThenRepeatedSequenceTables(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkFixedLibZstdFseSequenceFrames(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
    }
    const lib_generated_cases = if (filter.runLibGenerated()) try checkLibZstdGeneratedLibraryFrames(init.gpa) else 0;
    checked += lib_generated_cases;
    if (filter.runHandcrafted()) {
        try checkSplitHeaderIncremental(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkSplitSkippableHeaderIncremental(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        try checkSkippableOnlyStream(init.gpa);
        checked += 1;
        non_lib_generated_cases += 1;
        const handcrafted_frame_cases = try checkHandcraftedFrameValidation(init.gpa);
        checked += handcrafted_frame_cases;
        non_lib_generated_cases += handcrafted_frame_cases;
        const handcrafted_header_cases = try checkHandcraftedHeaderAndSkippableValidation(init.gpa);
        checked += handcrafted_header_cases;
        non_lib_generated_cases += handcrafted_header_cases;
    }

    const general_chunked_cases: usize = if (filter.runHandcrafted()) 10 else 0;
    const general_fse_repeat_cases: usize = if (filter.runHandcrafted()) 5 else 0;

    try stdout.print("zstd_native_frame_probe_ok cases={d}\n", .{checked});
    try printCoverage(stdout, "zstd_native_frame_probe", checked, &.{
        "bounded-limits",
        "checksum",
        "chunked",
        "reusable-chunked",
        "fse-repeat",
        "huffman",
        "incremental",
        "lib-generated",
        "malformed",
        "native-generated",
        "sequence-tables",
        "skippable",
    }, &.{
        .{ .capability = "chunked", .cases = lib_generated_cases + general_chunked_cases },
        .{ .capability = "reusable-chunked", .cases = lib_generated_cases + general_chunked_cases },
        .{ .capability = "fse-repeat", .cases = general_fse_repeat_cases },
        .{ .capability = "incremental", .cases = lib_generated_cases + general_chunked_cases },
        .{ .capability = "lib-generated", .cases = lib_generated_cases },
        .{ .capability = "malformed", .cases = lib_generated_cases + non_lib_generated_cases },
    });
    try stdout.flush();
}

const ProbeFilter = enum {
    all,
    handcrafted,
    lib_generated,

    fn runHandcrafted(self: ProbeFilter) bool {
        return self == .all or self == .handcrafted;
    }

    fn runLibGenerated(self: ProbeFilter) bool {
        return self == .all or self == .lib_generated;
    }
};

fn parseProbeFilter(init: std.process.Init) !ProbeFilter {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.skip();

    var filter: ProbeFilter = .all;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--only")) {
            const value = args.next() orelse return error.ZstdNativeFrameProbeMismatch;
            if (std.mem.eql(u8, value, "all")) {
                filter = .all;
            } else if (std.mem.eql(u8, value, "handcrafted")) {
                filter = .handcrafted;
            } else if (std.mem.eql(u8, value, "lib-generated")) {
                filter = .lib_generated;
            } else {
                return error.ZstdNativeFrameProbeMismatch;
            }
        } else if (std.mem.startsWith(u8, arg, "--only=")) {
            const value = arg["--only=".len..];
            if (std.mem.eql(u8, value, "all")) {
                filter = .all;
            } else if (std.mem.eql(u8, value, "handcrafted")) {
                filter = .handcrafted;
            } else if (std.mem.eql(u8, value, "lib-generated")) {
                filter = .lib_generated;
            } else {
                return error.ZstdNativeFrameProbeMismatch;
            }
        } else {
            return error.ZstdNativeFrameProbeMismatch;
        }
    }
    return filter;
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

fn checkDirectHuffmanBoundaries(allocator: std.mem.Allocator) !void {
    var payload: [129 * 64]u8 = undefined;
    for (payload[0..129], 0..) |*byte, i| byte.* = @intCast(i);
    var state: u32 = 0x1290_0f5e;
    for (payload[129..]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @intCast((state >> 16) % 129);
    }

    const encoded = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, &payload, .{
        .selection = .literal_only,
        .content_checksum = false,
    });
    defer allocator.free(encoded.frame);
    try expect(encoded.mode == .literal_only);
    try expect((try vort.zstdDecodedNativeFrameSize(encoded.frame)) == payload.len);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(encoded.frame);
    try expect(first_block.block_type == .compressed);
    const summary = try vort.zstdSummarizeNativeFrameBlocks(encoded.frame);
    try expect(summary.compressed_block_count == 1);

    const decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, encoded.frame);
    defer allocator.free(decoded);
    try expectEqualSlices(&payload, decoded);

    var into: [payload.len]u8 = undefined;
    const written = try vort.zstdDecodeNativeFrameInto(encoded.frame, &into);
    try expect(written == payload.len);
    try expectEqualSlices(&payload, &into);
    const exact_written = try vort.zstdDecodeNativeFrameIntoExactSize(encoded.frame, &into, payload.len);
    try expect(exact_written == payload.len);
    try expectEqualSlices(&payload, &into);
    try expectError(error.OutputTooSmall, vort.zstdDecodeNativeFrameIntoExactSize(encoded.frame, into[0 .. into.len - 1], payload.len));
    try expectError(error.SizeMismatch, vort.zstdDecodeNativeFrameIntoExactSize(encoded.frame, &into, payload.len - 1));
    var oversized_into: [payload.len + 1]u8 = undefined;
    try expectError(error.SizeMismatch, vort.zstdDecodeNativeFrameIntoExactSize(encoded.frame, &oversized_into, payload.len + 1));

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    const appended_written = try vort.zstdDecodeNativeFrameAppendExactSize(allocator, &appended, encoded.frame, payload.len);
    try expect(appended_written == payload.len);
    try expectPrefixedPayload(appended.items, &payload);
    appended.clearRetainingCapacity();
    try expectError(error.SizeMismatch, vort.zstdDecodeNativeFrameAppendExactSize(allocator, &appended, encoded.frame, payload.len - 1));
    try expectError(error.SizeMismatch, vort.zstdDecodeNativeFrameAppendExactSize(allocator, &appended, encoded.frame, payload.len + 1));

    var decoder = vort.ZstdNativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    const reusable_exact_written = try decoder.decodeIntoSliceExactSize(encoded.frame, &into, payload.len);
    try expect(reusable_exact_written == payload.len);
    try expectEqualSlices(&payload, into[0..reusable_exact_written]);
    try expectError(error.OutputTooSmall, decoder.decodeIntoSliceExactSize(encoded.frame, into[0 .. into.len - 1], payload.len));
    try expectError(error.SizeMismatch, decoder.decodeIntoSliceExactSize(encoded.frame, &into, payload.len - 1));
    var reusable_appended: std.ArrayList(u8) = .empty;
    defer reusable_appended.deinit(allocator);
    try reusable_appended.appendSlice(allocator, "prefix:");
    const reusable_appended_written = try decoder.decodeAppendExactSize(&reusable_appended, encoded.frame, payload.len);
    try expect(reusable_appended_written == payload.len);
    try expectPrefixedPayload(reusable_appended.items, &payload);
    reusable_appended.clearRetainingCapacity();
    try expectError(error.SizeMismatch, decoder.decodeAppendExactSize(&reusable_appended, encoded.frame, payload.len - 1));
    try expectError(error.SizeMismatch, decoder.decodeAppendExactSize(&reusable_appended, encoded.frame, payload.len + 1));
}

fn checkNoSizeCompressedBlockLimits(allocator: std.mem.Allocator) !void {
    var payload: [129 * 64]u8 = undefined;
    for (payload[0..129], 0..) |*byte, i| byte.* = @intCast(i);
    var state: u32 = 0x1290_0f5e;
    for (payload[129..]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @intCast((state >> 16) % 129);
    }

    const encoded = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, &payload, .{
        .selection = .literal_only,
        .content_checksum = false,
        .include_content_size = false,
    });
    defer allocator.free(encoded.frame);
    try expect(encoded.mode == .literal_only);
    const header = try vort.zstdInspectNativeFrameHeader(encoded.frame);
    try expect(header.content_size == null);
    const first_block = try vort.zstdInspectNativeFrameFirstBlock(encoded.frame);
    try expect(first_block.block_type == .compressed);
    try expect((try vort.zstdDecodedNativeFrameSizeLimited(encoded.frame, payload.len)) == payload.len);
    try expectError(error.OutputLimitExceeded, vort.zstdDecodedNativeFrameSizeLimited(encoded.frame, payload.len - 1));

    const decoded = try vort.zstdDecodeNativeFrameAllocLimited(allocator, encoded.frame, payload.len);
    defer allocator.free(decoded);
    try expectEqualSlices(&payload, decoded);
    try expectAllocError(allocator, error.OutputLimitExceeded, vort.zstdDecodeNativeFrameAllocLimited(allocator, encoded.frame, payload.len - 1));

    var into: [payload.len]u8 = undefined;
    const written = try vort.zstdDecodeNativeFrameInto(encoded.frame, &into);
    try expect(written == payload.len);
    try expectEqualSlices(&payload, &into);
    try expectError(error.OutputTooSmall, vort.zstdDecodeNativeFrameInto(encoded.frame, into[0 .. into.len - 1]));

    const checksummed = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, &payload, .{
        .selection = .literal_only,
        .content_checksum = true,
        .include_content_size = false,
    });
    defer allocator.free(checksummed.frame);
    const checksummed_block = try vort.zstdInspectNativeFrameFirstBlock(checksummed.frame);
    try expect(checksummed_block.block_type == .compressed);

    var corrupt_checksum = try allocator.dupe(u8, checksummed.frame);
    defer allocator.free(corrupt_checksum);
    corrupt_checksum[corrupt_checksum.len - 1] ^= 0x01;

    try expect((try vort.zstdDecodedNativeFrameSizeLimited(corrupt_checksum, payload.len)) == payload.len);
    try expectError(error.OutputLimitExceeded, vort.zstdDecodedNativeFrameSizeLimited(corrupt_checksum, payload.len - 1));
    var checksum_into: [payload.len]u8 = undefined;
    try expectError(error.ChecksumMismatch, vort.zstdDecodeNativeFrameInto(corrupt_checksum, &checksum_into));
    try expectAllocError(allocator, error.ChecksumMismatch, vort.zstdDecodeNativeFrameAllocLimited(allocator, corrupt_checksum, payload.len));
    try expectAllocError(allocator, error.OutputLimitExceeded, vort.zstdDecodeNativeFrameAllocLimited(allocator, corrupt_checksum, payload.len - 1));

    const truncated_checksum = checksummed.frame[0 .. checksummed.frame.len - 2];
    try expectError(error.TruncatedFrame, vort.zstdDecodedNativeFrameSizeLimited(truncated_checksum, payload.len));
    var truncated_into: [payload.len]u8 = undefined;
    try expectError(error.TruncatedFrame, vort.zstdDecodeNativeFrameInto(truncated_checksum, &truncated_into));
    try expectAllocError(allocator, error.TruncatedFrame, vort.zstdDecodeNativeFrameAllocLimited(allocator, truncated_checksum, payload.len));
    try expectError(error.OutputLimitExceeded, vort.zstdDecodedNativeFrameSizeLimited(truncated_checksum, payload.len - 1));
    try expectAllocError(allocator, error.OutputLimitExceeded, vort.zstdDecodeNativeFrameAllocLimited(allocator, truncated_checksum, payload.len - 1));

    const small_block_len = 1024;
    const multi_payload = try allocator.alloc(u8, small_block_len * 2);
    defer allocator.free(multi_payload);
    @memset(multi_payload[0..small_block_len], 'a');
    @memset(multi_payload[small_block_len..], 'b');

    const multi = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, multi_payload, .{
        .selection = .literal_only,
        .content_checksum = false,
        .include_content_size = false,
        .block_size_max = small_block_len,
    });
    defer allocator.free(multi.frame);
    try expect(multi.mode == .literal_only);
    const multi_header = try vort.zstdInspectNativeFrameHeader(multi.frame);
    try expect(multi_header.content_size == null);
    const multi_summary = try vort.zstdSummarizeNativeFrameBlocks(multi.frame);
    try expect(multi_summary.block_count == 2);
    try expect(multi_summary.compressed_block_count == 2);
    try expect(multi_summary.raw_block_count == 0);
    const multi_stream_summary = try vort.zstdSummarizeNativeStream(multi.frame);
    try expect(multi_stream_summary.frame_count == 1);
    try expect(multi_stream_summary.skippable_frame_count == 0);
    try expect(multi_stream_summary.block_count == 2);
    try expect(multi_stream_summary.compressed_block_count == 2);

    var multi_stream = vort.zstdIterateNativeStream(multi.frame);
    const multi_element = (try multi_stream.next()) orelse return error.ZstdNativeFrameProbeMismatch;
    const multi_frame = switch (multi_element) {
        .skippable => return error.ZstdNativeFrameProbeMismatch,
        .frame => |frame| frame,
    };
    try expect(multi_frame.header.content_size == null);
    var multi_blocks = try multi_frame.blockIterator();
    const stream_first_block = (try multi_blocks.next()) orelse return error.ZstdNativeFrameProbeMismatch;
    const stream_second_block = (try multi_blocks.next()) orelse return error.ZstdNativeFrameProbeMismatch;
    try expect(stream_first_block.block_type == .compressed);
    try expect(stream_second_block.block_type == .compressed);
    try expect(!stream_first_block.last);
    try expect(stream_second_block.last);
    if ((try multi_blocks.next()) != null) return error.ZstdNativeFrameProbeMismatch;
    if ((try multi_stream.next()) != null) return error.ZstdNativeFrameProbeMismatch;

    try expect((try vort.zstdDecodedNativeFrameSizeLimited(multi.frame, multi_payload.len)) == multi_payload.len);
    try expectError(error.OutputLimitExceeded, vort.zstdDecodedNativeFrameSizeLimited(multi.frame, multi_payload.len - 1));

    const multi_decoded = try vort.zstdDecodeNativeFrameAllocLimited(allocator, multi.frame, multi_payload.len);
    defer allocator.free(multi_decoded);
    try expectEqualSlices(multi_payload, multi_decoded);
    try expectAllocError(allocator, error.OutputLimitExceeded, vort.zstdDecodeNativeFrameAllocLimited(allocator, multi.frame, multi_payload.len - 1));

    const multi_into = try allocator.alloc(u8, multi_payload.len);
    defer allocator.free(multi_into);
    const multi_written = try vort.zstdDecodeNativeFrameInto(multi.frame, multi_into);
    try expect(multi_written == multi_payload.len);
    try expectEqualSlices(multi_payload, multi_into);
    try expectError(error.OutputTooSmall, vort.zstdDecodeNativeFrameInto(multi.frame, multi_into[0 .. multi_into.len - 1]));

    const multi_checksummed = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, multi_payload, .{
        .selection = .literal_only,
        .content_checksum = true,
        .include_content_size = false,
        .block_size_max = small_block_len,
    });
    defer allocator.free(multi_checksummed.frame);
    const multi_checksummed_summary = try vort.zstdSummarizeNativeFrameBlocks(multi_checksummed.frame);
    try expect(multi_checksummed_summary.block_count == 2);
    try expect(multi_checksummed_summary.compressed_block_count == 2);

    var multi_bad_checksum = try allocator.dupe(u8, multi_checksummed.frame);
    defer allocator.free(multi_bad_checksum);
    multi_bad_checksum[multi_bad_checksum.len - 1] ^= 0x01;
    try expect((try vort.zstdDecodedNativeFrameSizeLimited(multi_bad_checksum, multi_payload.len)) == multi_payload.len);
    try expectError(error.OutputLimitExceeded, vort.zstdDecodedNativeFrameSizeLimited(multi_bad_checksum, multi_payload.len - 1));
    try expectError(error.ChecksumMismatch, vort.zstdDecodeNativeFrameInto(multi_bad_checksum, multi_into));
    try expectAllocError(allocator, error.ChecksumMismatch, vort.zstdDecodeNativeFrameAllocLimited(allocator, multi_bad_checksum, multi_payload.len));
    try expectAllocError(allocator, error.OutputLimitExceeded, vort.zstdDecodeNativeFrameAllocLimited(allocator, multi_bad_checksum, multi_payload.len - 1));

    const multi_truncated_checksum = multi_checksummed.frame[0 .. multi_checksummed.frame.len - 2];
    try expectError(error.TruncatedFrame, vort.zstdDecodedNativeFrameSizeLimited(multi_truncated_checksum, multi_payload.len));
    try expectError(error.TruncatedFrame, vort.zstdDecodeNativeFrameInto(multi_truncated_checksum, multi_into));
    try expectAllocError(allocator, error.TruncatedFrame, vort.zstdDecodeNativeFrameAllocLimited(allocator, multi_truncated_checksum, multi_payload.len));
    try expectError(error.OutputLimitExceeded, vort.zstdDecodedNativeFrameSizeLimited(multi_truncated_checksum, multi_payload.len - 1));
    try expectAllocError(allocator, error.OutputLimitExceeded, vort.zstdDecodeNativeFrameAllocLimited(allocator, multi_truncated_checksum, multi_payload.len - 1));
}

fn checkHighByteFseHuffman(allocator: std.mem.Allocator) !void {
    var payload: [2048]u8 = undefined;
    var state: u32 = 0xfeed_beef;
    for (&payload) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @intCast(129 + ((state >> 16) % 127));
    }

    const encoded = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, &payload, .{
        .selection = .literal_only,
        .content_checksum = false,
    });
    defer allocator.free(encoded.frame);
    try expect(encoded.mode == .literal_only);
    const first_block = try vort.zstdInspectNativeFrameFirstBlock(encoded.frame);
    // High-byte literals exceed the direct-tree header limit, so the native
    // writer must switch to FSE-compressed Huffman weights while keeping the
    // frame decodable by both libzstd and Vort native APIs.
    try expect(first_block.block_type == .compressed);
    try expect(first_block.payload_len < payload.len);
    try expect(vort.zstdNativeMaxDirectHuffmanSymbol == 128);

    const decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, encoded.frame);
    defer allocator.free(decoded);
    try expectEqualSlices(&payload, decoded);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    const appended_written = try vort.zstdDecodeNativeFrameAppendExactSize(allocator, &appended, encoded.frame, payload.len);
    try expect(appended_written == payload.len);
    try expectPrefixedPayload(appended.items, &payload);
    appended.clearRetainingCapacity();
    try expectError(error.SizeMismatch, vort.zstdDecodeNativeFrameAppendExactSize(allocator, &appended, encoded.frame, payload.len - 1));

    var corrupt_weights = try allocator.dupe(u8, encoded.frame);
    defer allocator.free(corrupt_weights);
    corrupt_weights[first_block.payload_offset + 4] ^= 0xff;
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(corrupt_weights));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, corrupt_weights));
    var corrupt_into: [payload.len]u8 = undefined;
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(corrupt_weights, &corrupt_into));
}

fn checkSystemZstdHighByteFrame(allocator: std.mem.Allocator) !void {
    // Reference frame generated by `zstd -1` for the same deterministic
    // high-byte payload below. It exercises FSE-compressed Huffman weights in
    // the decoder. Keeping this fixed fixture beside the native-emitted case
    // protects both independently generated FSE Huffman weight layouts.
    const frame_hex =
        "28b52ffd0448ed1d000a40e00e3710657a2b5cbc991677a0b3d956ae1aa76ac132b29a169ab2abdcef38e438a8e62e6e" ++
        "8751108babaaaaaaaaaaaaaaaaaaaaaaaaaaaa6a82dc00e000de00011a743a1b53265298afc9b6d511eafdfb11ac9293" ++
        "d0a14a7d96cfc230b3638a7f4757b96b3ed48f2acb7273acc6da4c10cf84205edc146a7a1c1bc141241bd97a36d22568" ++
        "380c714546867cc708e570de39de1db351a366494d0f9d38f490b315c5d4a34f6c766be69968bb2c59c5abce2efb74bc" ++
        "cb27ab382acc19c65f061ec2cbe58ecc4553faade7073b6320ac17eddf5b354bc699e63d8db571afead1cb2f16c8e096" ++
        "4488f1f614d1e8066f0317df5d9bd7acfb0817a1f15a72d6be3cb2c119b23ea5ac04fe28276cee1b0b1a2cc17df71e5d" ++
        "4cb78eea4f478f955b74db1d753b45cfb08268b64e9504461ede5e7385c25b172089072e49910b621506561f489fe4f9" ++
        "0353a562c7e0e3b0d4af63e4863a34d0e114eb22782b1168692c0619d1fd651aac1db620bf1c9ef6c0f7e18b67b6f617" ++
        "6734ea0dbeb070c13361764b5fab4d8ac7bfb34840aa720c98387f4d82131a342c2ea2c8e8d68ac02874a0d3e9329225" ++
        "6c3d3b0e9e4532652c8ceec784fda47e3e045084440bd43c813675c2df2512355054a1860d651b6c14ccf3fa0c87866a" ++
        "ee3e3a731a6544894f41740e870787c027e512e0bd4179eebe236accf708f05c2c848acdce16737a237cf37cde43dcc4" ++
        "eba704bd5a68c7f581e3792a1278f5e170a9a4a149621ce618a3b494661285fded5440f63bf9e18204a68ea29bfc8db0" ++
        "414d2172ad6adbc64c4e42fa4c0b17a3d0f2243d3371ab8e150238fc9122120fe39072b35d9ade6f7bc97a616be63698" ++
        "9e6951479016ef60848f19035ad0b73717af6b7485f548c38384e9b18c6f2e512564c9bc9ad793eb133b95bb05da2fed" ++
        "c7590f1539aaa271377c878b4c4d23c0b012e31f0f70b93673d46b354e0f5e1b6cb35c3d79e232c73b9ddc82ce1ee201" ++
        "034739a9859916f7cbc7354d000814fd0d2be85e1f05a83e0f7b5494184fe522d8444d7aba093d5404f4395e5350e724" ++
        "252b6742d92e63e0031b03749b955abe8af13f96e68297ad70a0b75403c251e69fd28141a7cb427915a185fe3ebba658" ++
        "0aad3b3687ec0e0223872ab2889fc31bb119d025a8e76b75c7cb19adce204e061144d64cb1dc245d7c2aedc57c5b6fe2" ++
        "c563fcd13cb11d4384924d007e926ecf14f454bd17851fc900817e255b9257e7a829e0d15090c01ef2f156b388adcbf7" ++
        "154c79355b3c8dcd3da36c75528dc888647dc67d3161516903be3b4b04684521e840251200549941ee8e716f073d3689" ++
        "02493b020700d91e49ee";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    var payload: [1024]u8 = undefined;
    var state: u32 = 0xfeed_beef;
    for (&payload) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @intCast(129 + ((state >> 16) % 127));
    }

    const decoded_size = try vort.zstdDecodedNativeFrameSize(&frame);
    try expect(decoded_size == payload.len);
    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    try expect(first_block.block_type == .compressed);
    const summary = try vort.zstdSummarizeNativeFrameBlocks(&frame);
    try expect(summary.block_count == 1);
    try expect(summary.compressed_block_count == 1);
    try expect(summary.raw_block_count == 0);
    try expect(summary.rle_block_count == 0);
    const decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(decoded);
    try expectEqualSlices(&payload, decoded);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    const appended_written = try vort.zstdDecodeNativeFrameAppendExactSize(allocator, &appended, &frame, payload.len);
    try expect(appended_written == payload.len);
    try expectPrefixedPayload(appended.items, &payload);
    appended.clearRetainingCapacity();
    try expectError(error.SizeMismatch, vort.zstdDecodeNativeFrameAppendExactSize(allocator, &appended, &frame, payload.len - 1));
}

fn checkTreelessRepeatHuffmanLiterals(allocator: std.mem.Allocator) !void {
    const unit = "{\"key\":\"value\",\"number\":123,\"array\":[1,2,3],\"text\":\"abcdefg\"}\n";
    const payload = unit ** 200;
    const frame_hex =
        "28b52ffd00680c0200e2c30d1290cf016c3325f0fdb0cddd2ce10b3339ce4e20b" ++
        "fb1a5123a279f76cdb7192d3a14f27ba43cef2102b95c08d2f8fea2efd493d" ++
        "fe58e0301007e7f411fa0750100e3030920bfb1a5123a279f76cdb7192d3a" ++
        "14f27ba43cef2102b95c08d2f8fea2efd493dfe58e0301007e7f411fa0";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    const first_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, first_block);
    try expect(first_block.block_type == .compressed);
    try expect(!first_block.last);
    try expect(first_modes.literals_kind == .compressed);
    try expect(first_modes.sequence_count == 1);
    try expect(first_modes.literal_length_mode == .predefined);
    try expect(first_modes.offset_mode == .predefined);
    try expect(first_modes.match_length_mode == .predefined);

    const second_block = try vort.zstdInspectNativeFrameBlockAt(&frame, first_block.next_header_offset);
    const second_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, second_block);
    try expect(second_block.block_type == .compressed);
    try expect(second_block.last);
    try expect(second_modes.literals_kind == .treeless);
    try expect(second_modes.sequence_count == 1);
    try expect(second_modes.literal_length_mode == .predefined);
    try expect(second_modes.offset_mode == .predefined);
    try expect(second_modes.match_length_mode == .predefined);
    try expect(second_modes.regenerated_literals_size == first_modes.regenerated_literals_size);

    const summary = try vort.zstdSummarizeNativeFrameBlocks(&frame);
    try expect(summary.block_count == 2);
    try expect(summary.compressed_block_count == 2);
    try expect((try vort.zstdDecodedNativeFrameSize(&frame)) == payload.len);

    const decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(decoded);
    try expectEqualSlices(payload, decoded);

    var into: [payload.len]u8 = undefined;
    const into_written = try vort.zstdDecodeNativeFrameInto(&frame, &into);
    try expect(into_written == payload.len);
    try expectEqualSlices(payload, &into);

    var corrupt_tree = frame;
    corrupt_tree[first_block.payload_offset + 5] ^= 0xff;
    const corrupt_first_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&corrupt_tree, first_block);
    try expect(corrupt_first_modes.literals_kind == .compressed);
    const corrupt_second_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&corrupt_tree, second_block);
    try expect(corrupt_second_modes.literals_kind == .treeless);
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(&corrupt_tree));
    var corrupt_into: [payload.len]u8 = undefined;
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(&corrupt_tree, &corrupt_into));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &corrupt_tree));

    var corrupt_stream = frame;
    corrupt_stream[first_block.payload_offset + 12] ^= 0xff;
    const corrupt_stream_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&corrupt_stream, first_block);
    try expect(corrupt_stream_modes.literals_kind == .compressed);
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(&corrupt_stream));
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(&corrupt_stream, &corrupt_into));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &corrupt_stream));

    var corrupt_stream_lengths = frame;
    corrupt_stream_lengths[first_block.payload_offset + 22] ^= 0xff;
    const corrupt_lengths_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&corrupt_stream_lengths, first_block);
    try expect(corrupt_lengths_modes.literals_kind == .compressed);
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(&corrupt_stream_lengths));
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(&corrupt_stream_lengths, &corrupt_into));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &corrupt_stream_lengths));
}

fn checkTreelessRepeatHuffmanAcrossRawBlock(allocator: std.mem.Allocator) !void {
    // Treeless literal blocks reuse the most recent Huffman tree in the frame.
    // Raw/RLE blocks must not clear that tree. This fixture inserts a raw block
    // between a tree-defining compressed block and a treeless compressed block,
    // keeping the behavior pinned through public inspect/decode APIs.
    const unit = "{\"key\":\"value\",\"number\":123,\"array\":[1,2,3],\"text\":\"abcdefg\"}\n";
    const payload = (unit ** 100) ++ "RAW" ++ (unit ** 100);
    const frame_hex =
        "28b52ffd00680c0200e2c30d1290cf016c3325f0fdb0cddd2ce10b3339ce4e20b" ++
        "fb1a5123a279f76cdb7192d3a14f27ba43cef2102b95c08d2f8fea2efd493d" ++
        "fe58e0301007e7f411fa0180000524157750100e3030920bfb1a5123a279" ++
        "f76cdb7192d3a14f27ba43cef2102b95c08d2f8fea2efd493dfe58e0301007e7f411fa0";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    try expect(first_block.block_type == .compressed);
    try expect(!first_block.last);
    const first_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, first_block);
    try expect(first_modes.literals_kind == .compressed);

    const raw_block = try vort.zstdInspectNativeFrameBlockAt(&frame, first_block.next_header_offset);
    try expect(raw_block.block_type == .raw);
    try expect(!raw_block.last);

    const second_block = try vort.zstdInspectNativeFrameBlockAt(&frame, raw_block.next_header_offset);
    try expect(second_block.block_type == .compressed);
    try expect(second_block.last);
    const second_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, second_block);
    try expect(second_modes.literals_kind == .treeless);
    try expect(second_modes.regenerated_literals_size == first_modes.regenerated_literals_size);

    const summary = try vort.zstdSummarizeNativeFrameBlocks(&frame);
    try expect(summary.block_count == 3);
    try expect(summary.compressed_block_count == 2);
    try expect(summary.raw_block_count == 1);
    try expect(summary.rle_block_count == 0);

    const lib_decoded = try vort.zstdDecodeFrameAlloc(allocator, &frame);
    defer allocator.free(lib_decoded);
    try expectEqualSlices(payload, lib_decoded);
    try expect((try vort.zstdDecodedFrameSize(&frame)) >= payload.len);

    const native_decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(native_decoded);
    try expectEqualSlices(payload, native_decoded);
    try checkIncrementalFrameLibraryApis(allocator, payload, &frame);
    try checkChunkedFrameLibraryApis(allocator, payload, &frame);

    var into: [payload.len]u8 = undefined;
    const written = try vort.zstdDecodeNativeFrameIntoExactSize(&frame, &into, payload.len);
    try expect(written == payload.len);
    try expectEqualSlices(payload, into[0..written]);
    try expectError(error.OutputTooSmall, vort.zstdDecodeNativeFrameIntoExactSize(&frame, into[0 .. into.len - 1], payload.len));
    try expectError(error.SizeMismatch, vort.zstdDecodeNativeFrameIntoExactSize(&frame, &into, payload.len - 1));
}

fn checkTreelessRepeatHuffmanAcrossRleBlock(allocator: std.mem.Allocator) !void {
    // RLE blocks also must not clear the previous Huffman tree used by later
    // treeless literals. This is the RLE sibling of the raw-block fixture above,
    // pinning both non-compressed block flavors through public APIs.
    const unit = "{\"key\":\"value\",\"number\":123,\"array\":[1,2,3],\"text\":\"abcdefg\"}\n";
    const payload = (unit ** 100) ++ ("R" ** 3) ++ (unit ** 100);
    const frame_hex =
        "28b52ffd00680c0200e2c30d1290cf016c3325f0fdb0cddd2ce10b3339ce4e20b" ++
        "fb1a5123a279f76cdb7192d3a14f27ba43cef2102b95c08d2f8fea2efd493d" ++
        "fe58e0301007e7f411fa01a000052750100e3030920bfb1a5123a279f76c" ++
        "db7192d3a14f27ba43cef2102b95c08d2f8fea2efd493dfe58e0301007e7f411fa0";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    try expect(first_block.block_type == .compressed);
    try expect(!first_block.last);
    const first_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, first_block);
    try expect(first_modes.literals_kind == .compressed);

    const rle_block = try vort.zstdInspectNativeFrameBlockAt(&frame, first_block.next_header_offset);
    try expect(rle_block.block_type == .rle);
    try expect(!rle_block.last);

    const second_block = try vort.zstdInspectNativeFrameBlockAt(&frame, rle_block.next_header_offset);
    try expect(second_block.block_type == .compressed);
    try expect(second_block.last);
    const second_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, second_block);
    try expect(second_modes.literals_kind == .treeless);
    try expect(second_modes.regenerated_literals_size == first_modes.regenerated_literals_size);

    const summary = try vort.zstdSummarizeNativeFrameBlocks(&frame);
    try expect(summary.block_count == 3);
    try expect(summary.compressed_block_count == 2);
    try expect(summary.raw_block_count == 0);
    try expect(summary.rle_block_count == 1);

    const lib_decoded = try vort.zstdDecodeFrameAlloc(allocator, &frame);
    defer allocator.free(lib_decoded);
    try expectEqualSlices(payload, lib_decoded);
    try expect((try vort.zstdDecodedFrameSize(&frame)) >= payload.len);

    const native_decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(native_decoded);
    try expectEqualSlices(payload, native_decoded);
    try checkIncrementalFrameLibraryApis(allocator, payload, &frame);
    try checkChunkedFrameLibraryApis(allocator, payload, &frame);

    var into: [payload.len]u8 = undefined;
    const written = try vort.zstdDecodeNativeFrameIntoExactSize(&frame, &into, payload.len);
    try expect(written == payload.len);
    try expectEqualSlices(payload, into[0..written]);
    try expectError(error.OutputTooSmall, vort.zstdDecodeNativeFrameIntoExactSize(&frame, into[0 .. into.len - 1], payload.len));
    try expectError(error.SizeMismatch, vort.zstdDecodeNativeFrameIntoExactSize(&frame, &into, payload.len - 1));
}

fn checkRepeatOffsetAdditionalBits(allocator: std.mem.Allocator) !void {
    // Handcrafted one-sequence frame where OF=RLE uses offset code 2. The
    // reverse bitstream supplies the two extra offset bits, selecting the
    // smallest offset=4 case and protecting repeat-offset/additional-bit decode
    // through the public frame APIs.
    const frame_hex = "28b52ffd240e4500000961015401020a04005ee3cf";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    const modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, first_block);
    try expect(first_block.block_type == .compressed);
    try expect(first_block.last);
    try expect(modes.literals_kind == .rle);
    try expect(modes.sequence_count == 1);
    try expect(modes.literal_length_mode == .rle);
    try expect(modes.offset_mode == .rle);
    try expect(modes.match_length_mode == .rle);
    try expect((try vort.zstdDecodedNativeFrameSize(&frame)) == 14);

    const decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(decoded);
    try expectEqualSlices("aaaaaaaaaaaaaa", decoded);

    var into: [14]u8 = undefined;
    const into_written = try vort.zstdDecodeNativeFrameInto(&frame, &into);
    try expect(into_written == decoded.len);
    try expectEqualSlices(decoded, into[0..into_written]);
}

fn checkRepeatOffsetZeroLiteralSelector(allocator: std.mem.Allocator) !void {
    // Raw first block seeds the history with "abcd". The compressed second
    // block has literal_len=0 and OF code 0, which selects rep1 rather than
    // rep0. That should copy the four-byte history prefix and produce
    // "abcdabcd".
    const frame_hex = "28b52ffd2008200000616263643d000000015400000101";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    try expect(first_block.block_type == .raw);
    try expect(!first_block.last);
    const second_block = try vort.zstdInspectNativeFrameBlockAt(&frame, first_block.next_header_offset);
    const modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, second_block);
    try expect(second_block.block_type == .compressed);
    try expect(second_block.last);
    try expect(modes.literals_kind == .raw);
    try expect(modes.regenerated_literals_size == 0);
    try expect(modes.sequence_count == 1);
    try expect(modes.literal_length_mode == .rle);
    try expect(modes.offset_mode == .rle);
    try expect(modes.match_length_mode == .rle);
    try expect((try vort.zstdDecodedNativeFrameSize(&frame)) == 8);

    const decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(decoded);
    try expectEqualSlices("abcdabcd", decoded);

    var into: [8]u8 = undefined;
    const into_written = try vort.zstdDecodeNativeFrameInto(&frame, &into);
    try expect(into_written == decoded.len);
    try expectEqualSlices(decoded, into[0..into_written]);
}

fn checkRepeatOffsetZeroLiteralSecondSelector(allocator: std.mem.Allocator) !void {
    // literal_len=0 shifts OF code 1 into the repeat-offset selector range.
    // With extra bit 0, selector 2 chooses the initial rep2=8 and copies the
    // eight-byte raw prefix.
    const frame_hex = "28b52ffd201040000061626364656667683d000000015400010502";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    try expect(first_block.block_type == .raw);
    const second_block = try vort.zstdInspectNativeFrameBlockAt(&frame, first_block.next_header_offset);
    const modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, second_block);
    try expect(second_block.block_type == .compressed);
    try expect(second_block.last);
    try expect(modes.literals_kind == .raw);
    try expect(modes.regenerated_literals_size == 0);
    try expect(modes.sequence_count == 1);
    try expect(modes.offset_mode == .rle);

    const decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(decoded);
    try expectEqualSlices("abcdefghabcdefgh", decoded);
    var output: [16]u8 = undefined;
    const written = try vort.zstdDecodeNativeFrameInto(&frame, &output);
    try expect(written == decoded.len);
    try expectEqualSlices(decoded, output[0..written]);
}

fn checkRepeatOffsetLiteralZerothSelector(allocator: std.mem.Allocator) !void {
    // With literal_len>0, OF code 0 selects rep0 directly. The current frame
    // starts with the default rep0=1, emits two raw literals, then uses an
    // overlapping one-byte match to fill the tail. This complements the
    // positive-literal rep1/rep2 fixtures and keeps all three non-shifted
    // repeat selectors visible in the public frame probe.
    const frame_hex = "28b52ffd201240000061626364656667684d000010696a015402000501";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    try expect(first_block.block_type == .raw);
    const second_block = try vort.zstdInspectNativeFrameBlockAt(&frame, first_block.next_header_offset);
    const modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, second_block);
    try expect(second_block.block_type == .compressed);
    try expect(second_block.last);
    try expect(modes.literals_kind == .raw);
    try expect(modes.regenerated_literals_size == 2);
    try expect(modes.sequence_count == 1);
    try expect(modes.literal_length_mode == .rle);
    try expect(modes.offset_mode == .rle);
    try expect(modes.match_length_mode == .rle);

    const expected = "abcdefghi" ++ ("j" ** 9);
    const lib_decoded = try vort.zstdDecodeFrameAlloc(allocator, &frame);
    defer allocator.free(lib_decoded);
    try expectEqualSlices(expected, lib_decoded);

    const decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(decoded);
    try expectEqualSlices(expected, decoded);
    var output: [expected.len]u8 = undefined;
    const written = try vort.zstdDecodeNativeFrameInto(&frame, &output);
    try expect(written == decoded.len);
    try expectEqualSlices(decoded, output[0..written]);
}

fn checkRepeatOffsetRepeatModePositiveSelector(allocator: std.mem.Allocator) !void {
    // The second compressed block below repeats the LL/OF/ML RLE tables defined
    // by the previous compressed block. It then emits a positive literal run and
    // uses OF code 0, proving Repeat_Mode preserves enough table state for the
    // non-shifted rep0 selector path rather than only for zero-literal matches.
    const frame_hex = "28b52ffd201c40000061626364656667684c000010696a015402000501350000106b6c01fc01";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const expected = "abcdefghi" ++ ("j" ** 9) ++ "k" ++ ("l" ** 9);
    const lib_decoded = try vort.zstdDecodeFrameAlloc(allocator, &frame);
    defer allocator.free(lib_decoded);
    try expectEqualSlices(expected, lib_decoded);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    try expect(first_block.block_type == .raw);
    try expect(!first_block.last);
    const second_block = try vort.zstdInspectNativeFrameBlockAt(&frame, first_block.next_header_offset);
    try expect(second_block.block_type == .compressed);
    try expect(!second_block.last);
    const third_block = try vort.zstdInspectNativeFrameBlockAt(&frame, second_block.next_header_offset);
    try expect(third_block.block_type == .compressed);
    try expect(third_block.last);

    const second_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, second_block);
    try expect(second_modes.literals_kind == .raw);
    try expect(second_modes.regenerated_literals_size == 2);
    try expect(second_modes.sequence_count == 1);
    try expect(second_modes.literal_length_mode == .rle);
    try expect(second_modes.offset_mode == .rle);
    try expect(second_modes.match_length_mode == .rle);
    const third_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, third_block);
    try expect(third_modes.literals_kind == .raw);
    try expect(third_modes.regenerated_literals_size == 2);
    try expect(third_modes.sequence_count == 1);
    try expect(third_modes.literal_length_mode == .repeat);
    try expect(third_modes.offset_mode == .repeat);
    try expect(third_modes.match_length_mode == .repeat);

    const summary = try vort.zstdSummarizeNativeFrameBlocks(&frame);
    try expect(summary.block_count == 3);
    try expect(summary.raw_block_count == 1);
    try expect(summary.compressed_block_count == 2);

    try expect((try vort.zstdDecodedNativeFrameSize(&frame)) == expected.len);
    const decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(decoded);
    try expectEqualSlices(expected, decoded);
    var output: [expected.len]u8 = undefined;
    const written = try vort.zstdDecodeNativeFrameInto(&frame, &output);
    try expect(written == decoded.len);
    try expectEqualSlices(decoded, output[0..written]);
}

fn checkRepeatOffsetRepeatModePositiveSecondSelectors(allocator: std.mem.Allocator) !void {
    // Complement the Repeat_Mode rep0 fixture above with repeated-table replay
    // for the positive-literal rep1 and rep2 selectors. The defining block uses
    // explicit RLE tables for LL/OF/ML, while the final block repeats those
    // tables and relies on the decoder to preserve both sequence-table state
    // and the repeated-offset ring across compressed-block boundaries.
    const cases = [_]struct {
        name: []const u8,
        frame_hex: []const u8,
        expected: []const u8,
    }{
        .{
            .name = "repeat-mode-positive-rep1",
            .frame_hex = "28b52ffd201c40000061626364656667684c000010696a015402010502350000106b6c01fc02",
            .expected = "abcdefghijghijghijklllllllll",
        },
        .{
            .name = "repeat-mode-positive-rep2",
            .frame_hex = "28b52ffd201c40000061626364656667684c000010696a015402010503350000106b6c01fc03",
            .expected = "abcdefghijcdefghijklijklijkl",
        },
    };

    inline for (cases) |case| {
        var frame: [case.frame_hex.len / 2]u8 = undefined;
        _ = try std.fmt.hexToBytes(&frame, case.frame_hex);

        const lib_decoded = try vort.zstdDecodeFrameAlloc(allocator, &frame);
        defer allocator.free(lib_decoded);
        try expectEqualSlices(case.expected, lib_decoded);

        const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
        try expect(first_block.block_type == .raw);
        try expect(!first_block.last);
        const second_block = try vort.zstdInspectNativeFrameBlockAt(&frame, first_block.next_header_offset);
        try expect(second_block.block_type == .compressed);
        try expect(!second_block.last);
        const third_block = try vort.zstdInspectNativeFrameBlockAt(&frame, second_block.next_header_offset);
        try expect(third_block.block_type == .compressed);
        try expect(third_block.last);

        const second_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, second_block);
        try expect(second_modes.literals_kind == .raw);
        try expect(second_modes.sequence_count == 1);
        try expect(second_modes.literal_length_mode == .rle);
        try expect(second_modes.offset_mode == .rle);
        try expect(second_modes.match_length_mode == .rle);
        const third_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, third_block);
        try expect(third_modes.literals_kind == .raw);
        try expect(third_modes.sequence_count == 1);
        try expect(third_modes.literal_length_mode == .repeat);
        try expect(third_modes.offset_mode == .repeat);
        try expect(third_modes.match_length_mode == .repeat);

        const summary = try vort.zstdSummarizeNativeFrameBlocks(&frame);
        try expect(summary.block_count == 3);
        try expect(summary.raw_block_count == 1);
        try expect(summary.compressed_block_count == 2);

        try expect((try vort.zstdDecodedNativeFrameSize(&frame)) == case.expected.len);
        const decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
        defer allocator.free(decoded);
        try expectEqualSlices(case.expected, decoded);
        var output: [case.expected.len]u8 = undefined;
        const written = try vort.zstdDecodeNativeFrameInto(&frame, &output);
        try expect(written == decoded.len);
        try expectEqualSlices(decoded, output[0..written]);

        var decoder = vort.ZstdNativeFrameDecoder.init(allocator);
        defer decoder.deinit();
        const scratch = try decoder.decodeScratch(&frame);
        try expectEqualSlices(case.expected, scratch);
        var appended: std.ArrayList(u8) = .empty;
        defer appended.deinit(allocator);
        try appended.appendSlice(allocator, "prefix:");
        const appended_written = try decoder.decodeAppendExactSize(&appended, &frame, case.expected.len);
        try expect(appended_written == case.expected.len);
        try expectPrefixedPayload(appended.items, case.expected);
    }
}

fn checkRepeatOffsetLiteralFirstSelector(allocator: std.mem.Allocator) !void {
    // With literal_len>0, OF code 1 plus extra bit 0 selects rep1 without the
    // zero-literal selector shift. The two emitted literals become part of the
    // match history before replay, so an offset of four expands "ij" into the
    // overlapping "ghijghij" tail.
    const frame_hex = "28b52ffd201240000061626364656667684d000010696a015402010502";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    try expect(first_block.block_type == .raw);
    const second_block = try vort.zstdInspectNativeFrameBlockAt(&frame, first_block.next_header_offset);
    const modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, second_block);
    try expect(second_block.block_type == .compressed);
    try expect(second_block.last);
    try expect(modes.literals_kind == .raw);
    try expect(modes.regenerated_literals_size == 2);
    try expect(modes.sequence_count == 1);
    try expect(modes.literal_length_mode == .rle);
    try expect(modes.offset_mode == .rle);
    try expect(modes.match_length_mode == .rle);

    const expected = "abcdefghijghijghij";
    const decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(decoded);
    try expectEqualSlices(expected, decoded);
    var output: [expected.len]u8 = undefined;
    const written = try vort.zstdDecodeNativeFrameInto(&frame, &output);
    try expect(written == decoded.len);
    try expectEqualSlices(decoded, output[0..written]);
}

fn checkRepeatOffsetLiteralSecondSelector(allocator: std.mem.Allocator) !void {
    // With literal_len>0, OF code 1 plus extra bit 1 selects the initial
    // rep2=8 without the zero-literal selector shift. The sequence first emits
    // two literal bytes, so the match copies from eight bytes behind the
    // post-literal position ("cdefghij").
    const frame_hex = "28b52ffd201240000061626364656667684d000010696a015402010503";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    try expect(first_block.block_type == .raw);
    const second_block = try vort.zstdInspectNativeFrameBlockAt(&frame, first_block.next_header_offset);
    const modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, second_block);
    try expect(second_block.block_type == .compressed);
    try expect(second_block.last);
    try expect(modes.literals_kind == .raw);
    try expect(modes.regenerated_literals_size == 2);
    try expect(modes.sequence_count == 1);
    try expect(modes.literal_length_mode == .rle);
    try expect(modes.offset_mode == .rle);
    try expect(modes.match_length_mode == .rle);

    const decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(decoded);
    try expectEqualSlices("abcdefghijcdefghij", decoded);
    var output: [18]u8 = undefined;
    const written = try vort.zstdDecodeNativeFrameInto(&frame, &output);
    try expect(written == decoded.len);
    try expectEqualSlices(decoded, output[0..written]);
}

fn checkRepeatOffsetZeroLiteralInvalidSelector(allocator: std.mem.Allocator) !void {
    // literal_len=0 adjusts OF code 1 by one selector slot. With extra bit 1,
    // raw selector 3 means "rep0 - 1"; the initial rep0 is 1, so the
    // resolved offset would be zero and must fail as an invalid match.
    const frame_hex = "28b52ffd20043d000000015400010103";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    const modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, block);
    try expect(block.block_type == .compressed);
    try expect(block.last);
    try expect(modes.literals_kind == .raw);
    try expect(modes.regenerated_literals_size == 0);
    try expect(modes.sequence_count == 1);
    try expect(modes.literal_length_mode == .rle);
    try expect(modes.offset_mode == .rle);
    try expect(modes.match_length_mode == .rle);

    try expectError(error.InvalidMatch, vort.zstdDecodedNativeFrameSize(&frame));
    var output: [8]u8 = undefined;
    try expectError(error.InvalidMatch, vort.zstdDecodeNativeFrameInto(&frame, &output));
    try expectAllocError(allocator, error.InvalidMatch, vort.zstdDecodeNativeFrameAlloc(allocator, &frame));
}

fn checkRepeatOffsetZeroLiteralRep0MinusOneAfterUpdate(allocator: std.mem.Allocator) !void {
    // The previous invalid-selector fixture pins the initial `rep0 - 1 == 0`
    // error path. This stream first updates rep0 with a direct offset=4 match,
    // then uses a zero-literal OF-code-1 sequence whose extra bit selects
    // `rep0 - 1 == 3`. That makes the selector valid and verifies that native
    // decode mutates repeat offsets across compressed blocks before applying
    // the Zstandard zero-literal selector adjustment.
    const expected = "abcdabcabca";
    const frame_hex = "28b52ffd200b200000616263643c0000000154000200073d000000015400010103";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    try expect((try vort.zstdDecodedFrameSize(&frame)) == expected.len);
    const lib_decoded = try vort.zstdDecodeFrameAlloc(allocator, &frame);
    defer allocator.free(lib_decoded);
    try expectEqualSlices(expected, lib_decoded);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    try expect(first_block.block_type == .raw);
    try expect(!first_block.last);
    const second_block = try vort.zstdInspectNativeFrameBlockAt(&frame, first_block.next_header_offset);
    try expect(second_block.block_type == .compressed);
    try expect(!second_block.last);
    const third_block = try vort.zstdInspectNativeFrameBlockAt(&frame, second_block.next_header_offset);
    try expect(third_block.block_type == .compressed);
    try expect(third_block.last);

    const second_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, second_block);
    try expect(second_modes.regenerated_literals_size == 0);
    try expect(second_modes.sequence_count == 1);
    try expect(second_modes.literal_length_mode == .rle);
    try expect(second_modes.offset_mode == .rle);
    try expect(second_modes.match_length_mode == .rle);
    const third_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, third_block);
    try expect(third_modes.regenerated_literals_size == 0);
    try expect(third_modes.sequence_count == 1);
    try expect(third_modes.literal_length_mode == .rle);
    try expect(third_modes.offset_mode == .rle);
    try expect(third_modes.match_length_mode == .rle);

    const summary = try vort.zstdSummarizeNativeFrameBlocks(&frame);
    try expect(summary.block_count == 3);
    try expect(summary.raw_block_count == 1);
    try expect(summary.compressed_block_count == 2);

    try expect((try vort.zstdDecodedNativeFrameSize(&frame)) == expected.len);
    const native_decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(native_decoded);
    try expectEqualSlices(expected, native_decoded);

    var into: [expected.len]u8 = undefined;
    const written = try vort.zstdDecodeNativeFrameInto(&frame, &into);
    try expect(written == expected.len);
    try expectEqualSlices(expected, into[0..written]);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    const appended_written = try vort.zstdDecodeNativeFrameAppendExactSize(allocator, &appended, &frame, expected.len);
    try expect(appended_written == expected.len);
    try expectPrefixedPayload(appended.items, expected);
    appended.clearRetainingCapacity();
    try expectError(error.SizeMismatch, vort.zstdDecodeNativeFrameAppendExactSize(allocator, &appended, &frame, expected.len - 1));
}

fn checkRepeatOffsetRepeatModeZeroLiteralRep0MinusOneAfterUpdate(allocator: std.mem.Allocator) !void {
    // Extend the non-Repeat_Mode `rep0 - 1` fixture above by replaying the
    // RLE sequence tables in a fourth compressed block. The direct-offset block
    // first updates rep0 to 4, the next zero-literal selector uses rep0-1=3,
    // and the Repeat_Mode block then reuses the same selector shape against the
    // mutated repeated-offset ring. This pins the interaction between
    // Repeat_Mode table replay and repeated-offset updates through public APIs.
    const expected = "abcdabcabcacaca";
    const frame_hex = "28b52ffd200f200000616263643c0000000154000200073c0000000154000101032500000001fc03";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    try expect((try vort.zstdDecodedFrameSize(&frame)) == expected.len);
    const lib_decoded = try vort.zstdDecodeFrameAlloc(allocator, &frame);
    defer allocator.free(lib_decoded);
    try expectEqualSlices(expected, lib_decoded);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    try expect(first_block.block_type == .raw);
    try expect(!first_block.last);
    const second_block = try vort.zstdInspectNativeFrameBlockAt(&frame, first_block.next_header_offset);
    try expect(second_block.block_type == .compressed);
    try expect(!second_block.last);
    const third_block = try vort.zstdInspectNativeFrameBlockAt(&frame, second_block.next_header_offset);
    try expect(third_block.block_type == .compressed);
    try expect(!third_block.last);
    const fourth_block = try vort.zstdInspectNativeFrameBlockAt(&frame, third_block.next_header_offset);
    try expect(fourth_block.block_type == .compressed);
    try expect(fourth_block.last);

    const second_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, second_block);
    try expect(second_modes.regenerated_literals_size == 0);
    try expect(second_modes.sequence_count == 1);
    try expect(second_modes.literal_length_mode == .rle);
    try expect(second_modes.offset_mode == .rle);
    try expect(second_modes.match_length_mode == .rle);
    const third_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, third_block);
    try expect(third_modes.regenerated_literals_size == 0);
    try expect(third_modes.sequence_count == 1);
    try expect(third_modes.literal_length_mode == .rle);
    try expect(third_modes.offset_mode == .rle);
    try expect(third_modes.match_length_mode == .rle);
    const fourth_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, fourth_block);
    try expect(fourth_modes.regenerated_literals_size == 0);
    try expect(fourth_modes.sequence_count == 1);
    try expect(fourth_modes.literal_length_mode == .repeat);
    try expect(fourth_modes.offset_mode == .repeat);
    try expect(fourth_modes.match_length_mode == .repeat);

    const summary = try vort.zstdSummarizeNativeFrameBlocks(&frame);
    try expect(summary.block_count == 4);
    try expect(summary.raw_block_count == 1);
    try expect(summary.compressed_block_count == 3);

    try expect((try vort.zstdDecodedNativeFrameSize(&frame)) == expected.len);
    try expect((try vort.zstdDecodedNativeFrameSizeLimited(&frame, expected.len)) == expected.len);
    try expectError(error.OutputLimitExceeded, vort.zstdDecodedNativeFrameSizeLimited(&frame, expected.len - 1));

    const native_decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(native_decoded);
    try expectEqualSlices(expected, native_decoded);

    var into: [expected.len]u8 = undefined;
    const written = try vort.zstdDecodeNativeFrameInto(&frame, &into);
    try expect(written == expected.len);
    try expectEqualSlices(expected, into[0..written]);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    const appended_written = try vort.zstdDecodeNativeFrameAppendExactSize(allocator, &appended, &frame, expected.len);
    try expect(appended_written == expected.len);
    try expectPrefixedPayload(appended.items, expected);
    appended.clearRetainingCapacity();
    try expectError(error.SizeMismatch, vort.zstdDecodeNativeFrameAppendExactSize(allocator, &appended, &frame, expected.len - 1));

    var decoder = vort.ZstdNativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    const scratch = try decoder.decodeScratch(&frame);
    try expectEqualSlices(expected, scratch);

    try checkIncrementalFrameLibraryApis(allocator, expected, &frame);
    try checkChunkedFrameLibraryApis(allocator, expected, &frame);
}

fn checkRepeatedRleSequenceTables(allocator: std.mem.Allocator) !void {
    // First compressed block defines LL/OF/ML as RLE tables; the second block
    // uses Repeat_Mode for all three and relies on the previous table state.
    const frame_hex = "28b52ffd240844000009610154010000012d0000096101fc01f370e91d";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    const first_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, first_block);
    try expect(first_block.block_type == .compressed);
    try expect(!first_block.last);
    try expect(first_modes.literals_kind == .rle);
    try expect(first_modes.sequence_count == 1);
    try expect(first_modes.literal_length_mode == .rle);
    try expect(first_modes.offset_mode == .rle);
    try expect(first_modes.match_length_mode == .rle);

    const second_block = try vort.zstdInspectNativeFrameBlockAt(&frame, first_block.next_header_offset);
    const second_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, second_block);
    try expect(second_block.block_type == .compressed);
    try expect(second_block.last);
    try expect(second_modes.literals_kind == .rle);
    try expect(second_modes.sequence_count == 1);
    try expect(second_modes.literal_length_mode == .repeat);
    try expect(second_modes.offset_mode == .repeat);
    try expect(second_modes.match_length_mode == .repeat);
    try expect((try vort.zstdDecodedNativeFrameSize(&frame)) == 8);

    const decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(decoded);
    try expectEqualSlices("aaaaaaaa", decoded);

    var into: [8]u8 = undefined;
    const into_written = try vort.zstdDecodeNativeFrameInto(&frame, &into);
    try expect(into_written == decoded.len);
    try expectEqualSlices(decoded, into[0..into_written]);
}

fn checkMultiplePredefinedSequenceStateTransitions(allocator: std.mem.Allocator) !void {
    // A single compressed block with two predefined-table sequences. The
    // second sequence is only correct if the decoder applies LL/OF/ML state
    // transitions after the first sequence; this keeps that state-machine
    // behavior visible through public library APIs rather than only unit tests.
    const expected = "a" ** 18;
    const frame_hex = "28b52ffd20124d0000116102000060071002";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const lib_decoded = try vort.zstdDecodeFrameAlloc(allocator, &frame);
    defer allocator.free(lib_decoded);
    try expectEqualSlices(expected, lib_decoded);
    try expect((try vort.zstdDecodedFrameSize(&frame)) == expected.len);

    const block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    try expect(block.block_type == .compressed);
    try expect(block.last);
    const modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, block);
    try expect(modes.literals_kind == .rle);
    try expect(modes.regenerated_literals_size == 2);
    try expect(modes.sequence_count == 2);
    try expect(modes.literal_length_mode == .predefined);
    try expect(modes.offset_mode == .predefined);
    try expect(modes.match_length_mode == .predefined);

    const summary = try vort.zstdSummarizeNativeFrameBlocks(&frame);
    try expect(summary.block_count == 1);
    try expect(summary.compressed_block_count == 1);
    try expect(summary.raw_block_count == 0);
    try expect(summary.rle_block_count == 0);

    try expect((try vort.zstdDecodedNativeFrameSize(&frame)) == expected.len);
    try expect((try vort.zstdDecodedNativeFrameSizeLimited(&frame, expected.len)) == expected.len);
    try expectError(error.OutputLimitExceeded, vort.zstdDecodedNativeFrameSizeLimited(&frame, expected.len - 1));

    const native_decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(native_decoded);
    try expectEqualSlices(expected, native_decoded);

    var decoder = vort.ZstdNativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    const scratch = try decoder.decodeScratch(&frame);
    try expectEqualSlices(expected, scratch);
    try expect((try decoder.decodedSizeLimited(&frame, expected.len)) == expected.len);
    try expectError(error.OutputLimitExceeded, decoder.decodedSizeLimited(&frame, expected.len - 1));

    var into: [expected.len]u8 = undefined;
    const written = try vort.zstdDecodeNativeFrameInto(&frame, &into);
    try expect(written == expected.len);
    try expectEqualSlices(expected, into[0..written]);
    try expectError(error.OutputTooSmall, vort.zstdDecodeNativeFrameInto(&frame, into[0 .. into.len - 1]));

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    const appended_written = try decoder.decodeAppendExactSize(&appended, &frame, expected.len);
    try expect(appended_written == expected.len);
    try expectPrefixedPayload(appended.items, expected);
    appended.clearRetainingCapacity();
    try expectError(error.SizeMismatch, decoder.decodeAppendExactSize(&appended, &frame, expected.len - 1));
}

fn checkManyPredefinedSequenceStateTransitions(allocator: std.mem.Allocator) !void {
    // Keep a public fixture with more than two predefined-table transitions.
    // The LL state deliberately cycles through several states while OF/ML stay
    // simple, making regressions in streaming state updates visible through
    // library APIs and the probe dashboard rather than only private unit tests.
    const expected = "a" ** 30;
    const frame_hex = "28b52ffd201e7500002961050000600010001c00d80184";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const lib_decoded = try vort.zstdDecodeFrameAlloc(allocator, &frame);
    defer allocator.free(lib_decoded);
    try expectEqualSlices(expected, lib_decoded);
    try expect((try vort.zstdDecodedFrameSize(&frame)) == expected.len);

    const block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    try expect(block.block_type == .compressed);
    try expect(block.last);
    const modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, block);
    try expect(modes.literals_kind == .rle);
    try expect(modes.regenerated_literals_size == 5);
    try expect(modes.sequence_count == 5);
    try expect(modes.literal_length_mode == .predefined);
    try expect(modes.offset_mode == .predefined);
    try expect(modes.match_length_mode == .predefined);

    try expect((try vort.zstdDecodedNativeFrameSize(&frame)) == expected.len);
    try expect((try vort.zstdDecodedNativeFrameSizeLimited(&frame, expected.len)) == expected.len);
    try expectError(error.OutputLimitExceeded, vort.zstdDecodedNativeFrameSizeLimited(&frame, expected.len - 1));

    const native_decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(native_decoded);
    try expectEqualSlices(expected, native_decoded);
    try checkIncrementalFrameLibraryApis(allocator, expected, &frame);
    try checkChunkedFrameLibraryApis(allocator, expected, &frame);

    var into: [expected.len]u8 = undefined;
    const written = try vort.zstdDecodeNativeFrameIntoExactSize(&frame, &into, expected.len);
    try expect(written == expected.len);
    try expectEqualSlices(expected, into[0..written]);
    try expectError(error.OutputTooSmall, vort.zstdDecodeNativeFrameIntoExactSize(&frame, into[0 .. into.len - 1], expected.len));
    try expectError(error.SizeMismatch, vort.zstdDecodeNativeFrameIntoExactSize(&frame, &into, expected.len - 1));
}

fn checkFirstBlockRepeatSequenceModeIsRejected(allocator: std.mem.Allocator) !void {
    // Repeat_Mode sequence tables are only valid after a previous compressed
    // block has established tables in the same frame. Keep this malformed shape
    // in the public probe so all public inspect/preflight/decode facades agree
    // on CorruptFrame instead of leaking uninitialized table state.
    const frame = [_]u8{
        0x28, 0xb5, 0x2f, 0xfd,
        0x20, 0x04, // Single-segment frame with content size 4.
        0x2d, 0x00, 0x00, // Last compressed block with five payload bytes.
        0x09, 'a', // RLE literals, regenerated size 1.
        0x01, // One sequence.
        0xfc, // Repeat_Mode for LL, OF, and ML without previous tables.
        0x01, // Minimal reverse bitstream end mark.
    };

    const block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    try expect(block.block_type == .compressed);
    try expect(block.last);
    try expectError(error.CorruptFrame, vort.zstdInspectNativeFrameBlockSequenceModes(&frame, block));
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(&frame));
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSizeLimited(&frame, 4));

    var into: [4]u8 = undefined;
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(&frame, &into));
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameIntoExactSize(&frame, &into, into.len));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &frame));

    var decoder = vort.ZstdNativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    try expectError(error.CorruptFrame, decoder.decodeIntoSlice(&frame, &into));
    try expectAllocError(allocator, error.CorruptFrame, decoder.decodeAlloc(&frame));
}

fn checkFirstBlockMixedRepeatSequenceModeIsRejected(allocator: std.mem.Allocator) !void {
    // A repeat in any one of the three sequence-table slots still requires
    // previous table state. This fixture differs from the all-repeat case above
    // by mixing LL=Repeat_Mode with OF/ML=RLE_Mode, pinning the partial-repeat
    // error path through the same public facades.
    const frame = [_]u8{
        0x28, 0xb5, 0x2f, 0xfd,
        0x20, 0x04, // Single-segment frame with content size 4.
        0x3d, 0x00, 0x00, // Last compressed block with seven payload bytes.
        0x09, 'a', // RLE literals, regenerated size 1.
        0x01, // One sequence.
        0xd4, // LL=Repeat_Mode, OF=RLE_Mode, ML=RLE_Mode.
        0x00, // OF RLE symbol: repeated offset code 0.
        0x00, // ML RLE symbol: match length 3.
        0x01, // Minimal reverse bitstream end mark.
    };

    const block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    try expect(block.block_type == .compressed);
    try expect(block.last);
    try expectError(error.CorruptFrame, vort.zstdInspectNativeFrameBlockSequenceModes(&frame, block));
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(&frame));

    var into: [4]u8 = undefined;
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(&frame, &into));
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameIntoExactSize(&frame, &into, into.len));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &frame));

    var decoder = vort.ZstdNativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    try expectError(error.CorruptFrame, decoder.decodeIntoSlice(&frame, &into));
    try expectAllocError(allocator, error.CorruptFrame, decoder.decodeAlloc(&frame));
}

fn checkFirstBlockOffsetAndMatchRepeatSequenceModesAreRejected(allocator: std.mem.Allocator) !void {
    // Sibling coverage for the LL=Repeat_Mode first-block case above. Repeat in
    // either OF or ML also requires previous sequence tables, and mixed-mode
    // payload parsing must reject that missing state after reading only the RLE
    // symbols that actually belong to the non-repeat table slots.
    const offset_repeat_frame = [_]u8{
        0x28, 0xb5, 0x2f, 0xfd,
        0x20, 0x04, // Single-segment frame with content size 4.
        0x3d, 0x00, 0x00, // Last compressed block with seven payload bytes.
        0x09, 'a', // RLE literals, regenerated size 1.
        0x01, // One sequence.
        0x74, // LL=RLE_Mode, OF=Repeat_Mode, ML=RLE_Mode.
        0x00, // LL RLE symbol: literal length 0.
        0x00, // ML RLE symbol: match length 3.
        0x01, // Minimal reverse bitstream end mark.
    };
    try expectFirstBlockRepeatStateError(allocator, &offset_repeat_frame);

    const match_repeat_frame = [_]u8{
        0x28, 0xb5, 0x2f, 0xfd,
        0x20, 0x04, // Single-segment frame with content size 4.
        0x3d, 0x00, 0x00, // Last compressed block with seven payload bytes.
        0x09, 'a', // RLE literals, regenerated size 1.
        0x01, // One sequence.
        0x5c, // LL=RLE_Mode, OF=RLE_Mode, ML=Repeat_Mode.
        0x00, // LL RLE symbol: literal length 0.
        0x00, // OF RLE symbol: repeated offset code 0.
        0x01, // Minimal reverse bitstream end mark.
    };
    try expectFirstBlockRepeatStateError(allocator, &match_repeat_frame);
}

fn expectFirstBlockRepeatStateError(allocator: std.mem.Allocator, frame: []const u8) !void {
    const block = try vort.zstdInspectNativeFrameFirstBlock(frame);
    try expect(block.block_type == .compressed);
    try expect(block.last);
    try expectError(error.CorruptFrame, vort.zstdInspectNativeFrameBlockSequenceModes(frame, block));
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(frame));

    var into: [4]u8 = undefined;
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(frame, &into));
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameIntoExactSize(frame, &into, into.len));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, frame));

    var decoder = vort.ZstdNativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    try expectError(error.CorruptFrame, decoder.decodeIntoSlice(frame, &into));
    try expectAllocError(allocator, error.CorruptFrame, decoder.decodeAlloc(frame));
}

fn checkMixedRlePredefinedSequenceModes(allocator: std.mem.Allocator) !void {
    // Mixed mode bytes are serialized LL/OF/ML in one compact descriptor. Keep
    // a public fixture where LL/OF are RLE tables while ML remains predefined so
    // future table-parser work cannot accidentally assume one shared mode for
    // all sequence alphabets.
    const expected = "a" ** 132;
    const frame_hex = "28b52ffd2084450000096101500100002a";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const lib_decoded = try vort.zstdDecodeFrameAlloc(allocator, &frame);
    defer allocator.free(lib_decoded);
    try expectEqualSlices(expected, lib_decoded);
    try expect((try vort.zstdDecodedFrameSize(&frame)) == expected.len);

    const block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    try expect(block.block_type == .compressed);
    try expect(block.last);
    const modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, block);
    try expect(modes.literals_kind == .rle);
    try expect(modes.regenerated_literals_size == 1);
    try expect(modes.sequence_count == 1);
    try expect(modes.literal_length_mode == .rle);
    try expect(modes.offset_mode == .rle);
    try expect(modes.match_length_mode == .predefined);

    try expect((try vort.zstdDecodedNativeFrameSize(&frame)) == expected.len);
    try expect((try vort.zstdDecodedNativeFrameSizeLimited(&frame, expected.len)) == expected.len);
    try expectError(error.OutputLimitExceeded, vort.zstdDecodedNativeFrameSizeLimited(&frame, expected.len - 1));

    const native_decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(native_decoded);
    try expectEqualSlices(expected, native_decoded);

    var decoder = vort.ZstdNativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    const scratch = try decoder.decodeScratch(&frame);
    try expectEqualSlices(expected, scratch);

    var into: [expected.len]u8 = undefined;
    const written = try decoder.decodeIntoSlice(&frame, &into);
    try expect(written == expected.len);
    try expectEqualSlices(expected, into[0..written]);
    try expectError(error.OutputTooSmall, decoder.decodeIntoSlice(&frame, into[0 .. into.len - 1]));

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    const appended_written = try vort.zstdDecodeNativeFrameAppendExactSize(allocator, &appended, &frame, expected.len);
    try expect(appended_written == expected.len);
    try expectPrefixedPayload(appended.items, expected);
    appended.clearRetainingCapacity();
    try expectError(error.SizeMismatch, vort.zstdDecodeNativeFrameAppendExactSize(allocator, &appended, &frame, expected.len - 1));
}

fn checkRepeatMixedRlePredefinedSequenceModes(allocator: std.mem.Allocator) !void {
    // The first block defines a mixed LL/OF=RLE + ML=Predefined sequence table
    // set; the second block uses Repeat_Mode for all three alphabets. This
    // proves the native frame-state replay used by inspection and decode can
    // carry heterogeneous table modes across compressed blocks.
    const expected = "a" ** 264;
    const frame_hex = "28b52ffd600800440000096101500100002a350000096101fc002a";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const lib_decoded = try vort.zstdDecodeFrameAlloc(allocator, &frame);
    defer allocator.free(lib_decoded);
    try expectEqualSlices(expected, lib_decoded);
    try expect((try vort.zstdDecodedFrameSize(&frame)) == expected.len);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    try expect(first_block.block_type == .compressed);
    try expect(!first_block.last);
    const first_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, first_block);
    try expect(first_modes.literals_kind == .rle);
    try expect(first_modes.regenerated_literals_size == 1);
    try expect(first_modes.sequence_count == 1);
    try expect(first_modes.literal_length_mode == .rle);
    try expect(first_modes.offset_mode == .rle);
    try expect(first_modes.match_length_mode == .predefined);

    const second_block = try vort.zstdInspectNativeFrameBlockAt(&frame, first_block.next_header_offset);
    try expect(second_block.block_type == .compressed);
    try expect(second_block.last);
    const second_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, second_block);
    try expect(second_modes.literals_kind == .rle);
    try expect(second_modes.regenerated_literals_size == 1);
    try expect(second_modes.sequence_count == 1);
    try expect(second_modes.literal_length_mode == .repeat);
    try expect(second_modes.offset_mode == .repeat);
    try expect(second_modes.match_length_mode == .repeat);

    const summary = try vort.zstdSummarizeNativeFrameBlocks(&frame);
    try expect(summary.block_count == 2);
    try expect(summary.compressed_block_count == 2);
    try expect(summary.raw_block_count == 0);
    try expect(summary.rle_block_count == 0);

    try expect((try vort.zstdDecodedNativeFrameSize(&frame)) == expected.len);
    try expect((try vort.zstdDecodedNativeFrameSizeLimited(&frame, expected.len)) == expected.len);
    try expectError(error.OutputLimitExceeded, vort.zstdDecodedNativeFrameSizeLimited(&frame, expected.len - 1));

    const native_decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(native_decoded);
    try expectEqualSlices(expected, native_decoded);

    var decoder = vort.ZstdNativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    const scratch = try decoder.decodeScratch(&frame);
    try expectEqualSlices(expected, scratch);

    var into: [expected.len]u8 = undefined;
    const written = try vort.zstdDecodeNativeFrameInto(&frame, &into);
    try expect(written == expected.len);
    try expectEqualSlices(expected, into[0..written]);
    try expectError(error.OutputTooSmall, vort.zstdDecodeNativeFrameInto(&frame, into[0 .. into.len - 1]));

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    const appended_written = try decoder.decodeAppendExactSize(&appended, &frame, expected.len);
    try expect(appended_written == expected.len);
    try expectPrefixedPayload(appended.items, expected);
    appended.clearRetainingCapacity();
    try expectError(error.SizeMismatch, decoder.decodeAppendExactSize(&appended, &frame, expected.len - 1));
}

fn checkRepeatSequenceTablesAcrossRawBlock(allocator: std.mem.Allocator) !void {
    // Raw and RLE blocks do not define sequence tables. A later compressed block
    // may still use Repeat_Mode to reuse tables established by an earlier
    // compressed block in the same frame. This guards the public inspector and
    // decoder replay logic against accidentally clearing table state while
    // walking non-compressed blocks.
    const expected = ("a" ** 132) ++ "RAW" ++ ("a" ** 132);
    const frame_hex = "28b52ffd600b00440000096101500100002a180000524157350000096101fc002a";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const lib_decoded = try vort.zstdDecodeFrameAlloc(allocator, &frame);
    defer allocator.free(lib_decoded);
    try expectEqualSlices(expected, lib_decoded);
    try expect((try vort.zstdDecodedFrameSize(&frame)) == expected.len);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    try expect(first_block.block_type == .compressed);
    try expect(!first_block.last);
    const first_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, first_block);
    try expect(first_modes.literal_length_mode == .rle);
    try expect(first_modes.offset_mode == .rle);
    try expect(first_modes.match_length_mode == .predefined);

    const raw_block = try vort.zstdInspectNativeFrameBlockAt(&frame, first_block.next_header_offset);
    try expect(raw_block.block_type == .raw);
    try expect(!raw_block.last);

    const repeat_block = try vort.zstdInspectNativeFrameBlockAt(&frame, raw_block.next_header_offset);
    try expect(repeat_block.block_type == .compressed);
    try expect(repeat_block.last);
    const repeat_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, repeat_block);
    try expect(repeat_modes.literal_length_mode == .repeat);
    try expect(repeat_modes.offset_mode == .repeat);
    try expect(repeat_modes.match_length_mode == .repeat);

    const summary = try vort.zstdSummarizeNativeFrameBlocks(&frame);
    try expect(summary.block_count == 3);
    try expect(summary.compressed_block_count == 2);
    try expect(summary.raw_block_count == 1);
    try expect(summary.rle_block_count == 0);

    try expect((try vort.zstdDecodedNativeFrameSize(&frame)) == expected.len);
    try expect((try vort.zstdDecodedNativeFrameSizeLimited(&frame, expected.len)) == expected.len);
    try expectError(error.OutputLimitExceeded, vort.zstdDecodedNativeFrameSizeLimited(&frame, expected.len - 1));

    const native_decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(native_decoded);
    try expectEqualSlices(expected, native_decoded);
    try checkIncrementalFrameLibraryApis(allocator, expected, &frame);
    try checkChunkedFrameLibraryApis(allocator, expected, &frame);

    var into: [expected.len]u8 = undefined;
    const written = try vort.zstdDecodeNativeFrameIntoExactSize(&frame, &into, expected.len);
    try expect(written == expected.len);
    try expectEqualSlices(expected, into[0..written]);
    try expectError(error.OutputTooSmall, vort.zstdDecodeNativeFrameIntoExactSize(&frame, into[0 .. into.len - 1], expected.len));
    try expectError(error.SizeMismatch, vort.zstdDecodeNativeFrameIntoExactSize(&frame, &into, expected.len - 1));
}

fn checkRepeatSequenceTablesAcrossRleBlock(allocator: std.mem.Allocator) !void {
    // RLE blocks, like raw blocks, carry no sequence tables. Keep a sibling of
    // the raw-block fixture above to prove the inspector/decode replay state is
    // preserved across every non-compressed block flavor.
    const expected = ("a" ** 132) ++ ("R" ** 3) ++ ("a" ** 132);
    const frame_hex = "28b52ffd600b00440000096101500100002a1a000052350000096101fc002a";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const lib_decoded = try vort.zstdDecodeFrameAlloc(allocator, &frame);
    defer allocator.free(lib_decoded);
    try expectEqualSlices(expected, lib_decoded);
    try expect((try vort.zstdDecodedFrameSize(&frame)) == expected.len);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    try expect(first_block.block_type == .compressed);
    try expect(!first_block.last);
    const first_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, first_block);
    try expect(first_modes.literal_length_mode == .rle);
    try expect(first_modes.offset_mode == .rle);
    try expect(first_modes.match_length_mode == .predefined);

    const rle_block = try vort.zstdInspectNativeFrameBlockAt(&frame, first_block.next_header_offset);
    try expect(rle_block.block_type == .rle);
    try expect(!rle_block.last);

    const repeat_block = try vort.zstdInspectNativeFrameBlockAt(&frame, rle_block.next_header_offset);
    try expect(repeat_block.block_type == .compressed);
    try expect(repeat_block.last);
    const repeat_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, repeat_block);
    try expect(repeat_modes.literal_length_mode == .repeat);
    try expect(repeat_modes.offset_mode == .repeat);
    try expect(repeat_modes.match_length_mode == .repeat);

    const summary = try vort.zstdSummarizeNativeFrameBlocks(&frame);
    try expect(summary.block_count == 3);
    try expect(summary.compressed_block_count == 2);
    try expect(summary.raw_block_count == 0);
    try expect(summary.rle_block_count == 1);

    try expect((try vort.zstdDecodedNativeFrameSize(&frame)) == expected.len);
    try expect((try vort.zstdDecodedNativeFrameSizeLimited(&frame, expected.len)) == expected.len);
    try expectError(error.OutputLimitExceeded, vort.zstdDecodedNativeFrameSizeLimited(&frame, expected.len - 1));

    const native_decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(native_decoded);
    try expectEqualSlices(expected, native_decoded);
    try checkIncrementalFrameLibraryApis(allocator, expected, &frame);
    try checkChunkedFrameLibraryApis(allocator, expected, &frame);

    var into: [expected.len]u8 = undefined;
    const written = try vort.zstdDecodeNativeFrameIntoExactSize(&frame, &into, expected.len);
    try expect(written == expected.len);
    try expectEqualSlices(expected, into[0..written]);
    try expectError(error.OutputTooSmall, vort.zstdDecodeNativeFrameIntoExactSize(&frame, into[0 .. into.len - 1], expected.len));
    try expectError(error.SizeMismatch, vort.zstdDecodeNativeFrameIntoExactSize(&frame, &into, expected.len - 1));
}

fn checkOffsetCompressedThenRepeatedSequenceTables(allocator: std.mem.Allocator) !void {
    // Public frame-level fixture for an OF=FSE table followed by Repeat_Mode.
    // Dictionary probes already cover this shape while testing dictionary APIs;
    // keeping a non-dictionary frame probe protects the general frame decoder
    // and stream inspector from regressing compressed offset-table replay.
    const frame_hex =
        "28b52ffd2094240100606162636465666768696a6b6c1024106a1f05830bc3c2c36061b070701838382c7826012d00000001fc4f20";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    try expect(first_block.block_type == .compressed);
    try expect(!first_block.last);
    const first_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, first_block);
    try expect(first_modes.sequence_count == 16);
    try expect(first_modes.literal_length_mode == .predefined);
    try expect(first_modes.offset_mode == .compressed);
    try expect(first_modes.match_length_mode == .rle);

    const second_block = try vort.zstdInspectNativeFrameBlockAt(&frame, first_block.next_header_offset);
    try expect(second_block.block_type == .compressed);
    try expect(second_block.last);
    const second_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, second_block);
    try expect(second_modes.sequence_count == 1);
    try expect(second_modes.literal_length_mode == .repeat);
    try expect(second_modes.offset_mode == .repeat);
    try expect(second_modes.match_length_mode == .repeat);

    const summary = try vort.zstdSummarizeNativeFrameBlocks(&frame);
    try expect(summary.block_count == 2);
    try expect(summary.compressed_block_count == 2);
    try expect(summary.raw_block_count == 0);
    try expect(summary.rle_block_count == 0);
    try expect((try vort.zstdDecodedNativeFrameSize(&frame)) == 148);
    try expect((try vort.zstdDecodedNativeFrameSizeLimited(&frame, 148)) == 148);
    try expectError(error.OutputLimitExceeded, vort.zstdDecodedNativeFrameSizeLimited(&frame, 147));

    const decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(decoded);
    try expect(decoded.len == 148);
    var into: [148]u8 = undefined;
    const written = try vort.zstdDecodeNativeFrameInto(&frame, &into);
    try expect(written == decoded.len);
    try expectEqualSlices(decoded, into[0..written]);

    var decoder = vort.ZstdNativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    const scratch = try decoder.decodeScratch(&frame);
    try expectEqualSlices(decoded, scratch);

    const short_repeat_state_hex =
        "28b52ffd2094240100606162636465666768696a6b6c1024106a1f05830bc3c2c36061b070701838382c7826012500000001fc4f";
    var short_repeat_state: [short_repeat_state_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&short_repeat_state, short_repeat_state_hex);
    const repeat_first = try vort.zstdInspectNativeFrameFirstBlock(&short_repeat_state);
    const repeat_second = try vort.zstdInspectNativeFrameBlockAt(&short_repeat_state, repeat_first.next_header_offset);
    const repeat_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&short_repeat_state, repeat_second);
    try expect(repeat_modes.sequence_count == 1);
    try expect(repeat_modes.literal_length_mode == .repeat);
    try expect(repeat_modes.offset_mode == .repeat);
    try expect(repeat_modes.match_length_mode == .repeat);
    try expectError(error.TruncatedFrame, vort.zstdDecodedNativeFrameSize(&short_repeat_state));
    var short_repeat_output: [148]u8 = undefined;
    try expectError(error.TruncatedFrame, vort.zstdDecodeNativeFrameInto(&short_repeat_state, &short_repeat_output));
    try expectAllocError(allocator, error.TruncatedFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &short_repeat_state));

    const short_state_hex =
        "28b52ffd20941c0100606162636465666768696a6b6c1024106a1f05830bc3c2c36061b070701838382c78262d00000001fc4f20";
    var short_state: [short_state_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&short_state, short_state_hex);
    const short_block = try vort.zstdInspectNativeFrameFirstBlock(&short_state);
    const short_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&short_state, short_block);
    try expect(short_modes.offset_mode == .compressed);
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(&short_state));
    var short_output: [148]u8 = undefined;
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(&short_state, &short_output));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &short_state));
}

fn checkOffsetAndMatchLengthCompressedSequenceTables(allocator: std.mem.Allocator) !void {
    // Fixture generated through the public native writer from a structured
    // duplicate-heavy payload. It chooses LL=Predefined while both OF and ML use
    // compressed FSE tables, complementing the single-table and all-table FSE
    // fixtures. This keeps mixed compressed/predefined sequence-table decode
    // visible through public frame APIs rather than only internal writer tests.
    const frame_hex =
        "28b52ffd60bd01fd0a0092a14ee300000000000000000000000000000000000000000000000000000000000000000333" ++
        "33343333333231233333123000000666975b96655996cb5d4e511445b9dce59224492e77390441d6badce58ecb154551" ++
        "14c5e52e471004415cee72c3300c97bb9c20085575b9cb0d2e475114455197bbdc344dd374b9cb4992245dee72511441" ++
        "d0e52e27b8dcf33ccff35cee7281402010b8dce51cc7712e77b9a66918e672975b2e972449922497bb1c82200872b9cb" ++
        "adb5d6e52e771c87615cee72c5e586611886e17297130441102e77b9aaaaaacb5d6e301804045cee72d4e524499224e9" ++
        "72978ba2288a2e77390882a0cb5d4e201000005cee728fe3388ee35cee724dd334cde52ec7300c73b9cb2dcb72b9cb29" ++
        "cae52e975cee7297bbdc5a6bad75b9cb1dc7711c97bb9c6118c6e52e5714c5e52e4710c3e52e17102810c86b0d102e86" ++
        "2f07b6386dedb4b4d36a4fa33dadb64d0fba2d330025a26972";
    const expected_hex =
        "616263646162636442616263646162636443436162636461626364444444616263646162636445454545616263646162" ++
        "636446464646466162636461626364474747474747616263646162636461626364616263644961626364616263644a4a" ++
        "61626364616263644b4b4b61626364616263644c4c4c4c61626364616263644d4d4d4d4d61626364616263644e4e4e4e" ++
        "4e4e61626364616263646162636461626364506162636461626364515161626364616263645252526162636461626364" ++
        "535353536162636461626364545454545461626364616263645555555555556162636461626364616263646162636457" ++
        "61626364616263645858616263646162636459595961626364616263645a5a5a5a616263646162636441414141416162" ++
        "636461626364424242424242616263646162636461626364616263644461626364616263644545616263646162636446" ++
        "464661626364616263644747474761626364616263644848484848616263646162636449494949494961626364616263" ++
        "6461626364616263644b61626364616263644c4c61626364616263644d4d4d61626364616263644e4e4e4e6162636461" ++
        "6263644f4f4f4f4f61626364616263645050505050506162636461626364616263646162636452616263646162636453" ++
        "536162636461626364545454616263646162636455555555616263646162636456565656566162636461626364575757" ++
        "575757616263646162636461626364616263645961626364616263645a5a616263646162636441414161626364616263" ++
        "644242424261626364616263644343434343616263646162636444444444444461626364616263646162636461626364" ++
        "4661626364616263644747616263646162636448484861626364616263644949494961626364616263644a4a4a4a4a61" ++
        "626364616263644b4b4b4b4b4b61626364616263646162636461626364";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);
    var expected: [expected_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, expected_hex);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    try expect(first_block.block_type == .compressed);
    try expect(first_block.last);
    const modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, first_block);
    try expect(modes.sequence_count == 16);
    try expect(modes.literal_length_mode == .predefined);
    try expect(modes.offset_mode == .compressed);
    try expect(modes.match_length_mode == .compressed);

    const summary = try vort.zstdSummarizeNativeFrameBlocks(&frame);
    try expect(summary.block_count == 1);
    try expect(summary.compressed_block_count == 1);
    try expect(summary.raw_block_count == 0);
    try expect(summary.rle_block_count == 0);

    try expect((try vort.zstdDecodedFrameSize(&frame)) == expected.len);
    const lib_decoded = try vort.zstdDecodeFrameAlloc(allocator, &frame);
    defer allocator.free(lib_decoded);
    try expectEqualSlices(&expected, lib_decoded);

    try expect((try vort.zstdDecodedNativeFrameSize(&frame)) == expected.len);
    try expect((try vort.zstdDecodedNativeFrameSizeLimited(&frame, expected.len)) == expected.len);
    try expectError(error.OutputLimitExceeded, vort.zstdDecodedNativeFrameSizeLimited(&frame, expected.len - 1));

    const native_decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(native_decoded);
    try expectEqualSlices(&expected, native_decoded);
    try checkIncrementalFrameLibraryApis(allocator, &expected, &frame);
    try checkChunkedFrameLibraryApis(allocator, &expected, &frame);

    var into: [expected.len]u8 = undefined;
    const written = try vort.zstdDecodeNativeFrameInto(&frame, &into);
    try expect(written == expected.len);
    try expectEqualSlices(&expected, into[0..written]);
    try expectError(error.OutputTooSmall, vort.zstdDecodeNativeFrameInto(&frame, into[0 .. into.len - 1]));

    var decoder = vort.ZstdNativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    const scratch = try decoder.decodeScratch(&frame);
    try expectEqualSlices(&expected, scratch);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    const appended_written = try decoder.decodeAppendExactSize(&appended, &frame, expected.len);
    try expect(appended_written == expected.len);
    try expectPrefixedPayload(appended.items, &expected);
    appended.clearRetainingCapacity();
    try expectError(error.SizeMismatch, decoder.decodeAppendExactSize(&appended, &frame, expected.len - 1));

    var truncated_table = frame;
    setZstdProbeBlockPayloadLenAt(&truncated_table, first_block.header_offset, true, 240);
    const truncated_table_slice = truncated_table[0 .. first_block.payload_offset + 240];
    const truncated_table_block = try vort.zstdInspectNativeFrameFirstBlock(truncated_table_slice);
    try expectError(error.TruncatedFrame, vort.zstdInspectNativeFrameBlockSequenceModes(truncated_table_slice, truncated_table_block));
    try expectError(error.TruncatedFrame, vort.zstdDecodedNativeFrameSize(truncated_table_slice));
    var truncated_table_output: [expected.len]u8 = undefined;
    try expectError(error.TruncatedFrame, vort.zstdDecodeNativeFrameInto(truncated_table_slice, &truncated_table_output));
    try expectAllocError(allocator, error.TruncatedFrame, vort.zstdDecodeNativeFrameAlloc(allocator, truncated_table_slice));

    var bad_mode = frame;
    try expect(bad_mode[328] == 0x28); // LL=Predefined, OF=FSE, ML=FSE, reserved low bits clear.
    bad_mode[328] = 0x29; // Set a reserved low bit in the mixed sequence-mode byte.
    const bad_mode_block = try vort.zstdInspectNativeFrameFirstBlock(&bad_mode);
    try expectError(error.CorruptFrame, vort.zstdInspectNativeFrameBlockSequenceModes(&bad_mode, bad_mode_block));
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(&bad_mode));
    var bad_mode_output: [expected.len]u8 = undefined;
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(&bad_mode, &bad_mode_output));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &bad_mode));

    var short_bitstream = frame;
    setZstdProbeBlockPayloadLenAt(&short_bitstream, first_block.header_offset, true, first_block.payload_len - 1);
    const short_bitstream_slice = short_bitstream[0 .. first_block.next_header_offset - 1];
    const short_bitstream_block = try vort.zstdInspectNativeFrameFirstBlock(short_bitstream_slice);
    const short_bitstream_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(short_bitstream_slice, short_bitstream_block);
    try expect(short_bitstream_modes.literal_length_mode == .predefined);
    try expect(short_bitstream_modes.offset_mode == .compressed);
    try expect(short_bitstream_modes.match_length_mode == .compressed);
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(short_bitstream_slice));
    var short_bitstream_output: [expected.len]u8 = undefined;
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(short_bitstream_slice, &short_bitstream_output));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, short_bitstream_slice));
}

fn checkCompressedOffsetRepeatSelectorFrame(allocator: std.mem.Allocator) !void {
    // This frame is generated by Vort's native sequence writer with an
    // OF=compressed-FSE table whose symbol stream includes repeat-offset
    // selectors, rather than only absolute-offset symbols. Keeping the fixture
    // in the public frame probe guards the library decode/inspect APIs in
    // addition to the lower-level writer unit test that verifies the planned OF
    // codes directly.
    const frame_hex =
        "28b52ffd2057550100b8616263646566676862636465666768696a6b6c6d6e6f701024d03e011753dc0c7999e5caa423132817";
    const expected_hex =
        "616263646566676865666768626667686263636363636468626363656363646866636468666764686667686866676469696969696a6a6a6a6a6b69696a6a6c696a6a6c6d6a6a6c6d6e6a6c6d6a6f6f6f6f6f7070707070";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);
    var expected: [expected_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, expected_hex);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    try expect(first_block.block_type == .compressed);
    try expect(first_block.last);
    const modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, first_block);
    try expect(modes.sequence_count == 16);
    try expect(modes.literal_length_mode == .predefined);
    try expect(modes.offset_mode == .compressed);
    try expect(modes.match_length_mode == .rle);

    const summary = try vort.zstdSummarizeNativeFrameBlocks(&frame);
    try expect(summary.block_count == 1);
    try expect(summary.compressed_block_count == 1);
    try expect(summary.raw_block_count == 0);
    try expect(summary.rle_block_count == 0);

    try expect((try vort.zstdDecodedFrameSize(&frame)) == expected.len);
    const lib_decoded = try vort.zstdDecodeFrameAlloc(allocator, &frame);
    defer allocator.free(lib_decoded);
    try expectEqualSlices(&expected, lib_decoded);

    try expect((try vort.zstdDecodedNativeFrameSize(&frame)) == expected.len);
    try expect((try vort.zstdDecodedNativeFrameSizeLimited(&frame, expected.len)) == expected.len);
    try expectError(error.OutputLimitExceeded, vort.zstdDecodedNativeFrameSizeLimited(&frame, expected.len - 1));

    const native_decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(native_decoded);
    try expectEqualSlices(&expected, native_decoded);

    var into: [expected.len]u8 = undefined;
    const written = try vort.zstdDecodeNativeFrameInto(&frame, &into);
    try expect(written == expected.len);
    try expectEqualSlices(&expected, into[0..written]);
    try expectError(error.OutputTooSmall, vort.zstdDecodeNativeFrameInto(&frame, into[0 .. into.len - 1]));

    var decoder = vort.ZstdNativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    const scratch = try decoder.decodeScratch(&frame);
    try expectEqualSlices(&expected, scratch);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    const appended_written = try vort.zstdDecodeNativeFrameAppendExactSize(allocator, &appended, &frame, expected.len);
    try expect(appended_written == expected.len);
    try expectPrefixedPayload(appended.items, &expected);
    appended.clearRetainingCapacity();
    try expectError(error.SizeMismatch, vort.zstdDecodeNativeFrameAppendExactSize(allocator, &appended, &frame, expected.len - 1));
}

fn checkAllCompressedSequenceTableFrame(allocator: std.mem.Allocator) !void {
    // Fixed fixture emitted through the generic table-plan writer path after it
    // learned to keep all-compressed LL/OF/ML candidates. The older planner
    // treated that shape as "not mixed" and skipped the only emitter capable of
    // serializing an LL=FSE, OF=FSE, ML=FSE sequence block.
    const frame_hex =
        "28b52ffd20f0d503004405616263646566676862636464656665666667686967686968696a6a6b6c6b6c6c6d6e6f6d6e6f6e6f70707172717272737475737475747576767778777878797a61797a617a61626263646364646566676566676620a810386b9d03c03e1068ed01a89eb45b9c8181d61f93e495416210faa3bd6039199102";
    const expected_hex =
        "616263646566676865666768626667686266636464646464646566646464646464656664646464646667686966676869676869696768696967686969676869696a6a6a6a6a6a6b6c6c6c6c6c6c6b6c6c6c6c6c6c6d6e6f6c6d6e6f6c6d6d6e6f6d6d6e6f6d6e6e6f6d6d6f70707070707070707172727272727271727272727272737475727374757273747572737475747374757273747576767676767676777878787878777877787878787878797a6178797a6178797a6178797a617a797a617879616262626262626364646464646464636464646464646465666764656667656667676566676765666767656667";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);
    var expected: [expected_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, expected_hex);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    try expect(first_block.block_type == .compressed);
    try expect(first_block.last);
    const modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, first_block);
    try expect(modes.sequence_count == 32);
    try expect(modes.literal_length_mode == .compressed);
    try expect(modes.offset_mode == .compressed);
    try expect(modes.match_length_mode == .compressed);

    const summary = try vort.zstdSummarizeNativeFrameBlocks(&frame);
    try expect(summary.block_count == 1);
    try expect(summary.compressed_block_count == 1);
    try expect(summary.raw_block_count == 0);
    try expect(summary.rle_block_count == 0);

    try expect((try vort.zstdDecodedFrameSize(&frame)) == expected.len);
    const lib_decoded = try vort.zstdDecodeFrameAlloc(allocator, &frame);
    defer allocator.free(lib_decoded);
    try expectEqualSlices(&expected, lib_decoded);

    try expect((try vort.zstdDecodedNativeFrameSize(&frame)) == expected.len);
    try expect((try vort.zstdDecodedNativeFrameSizeLimited(&frame, expected.len)) == expected.len);
    try expectError(error.OutputLimitExceeded, vort.zstdDecodedNativeFrameSizeLimited(&frame, expected.len - 1));

    const native_decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(native_decoded);
    try expectEqualSlices(&expected, native_decoded);
    try checkIncrementalFrameLibraryApis(allocator, &expected, &frame);
    try checkChunkedFrameLibraryApis(allocator, &expected, &frame);

    var into: [expected.len]u8 = undefined;
    const written = try vort.zstdDecodeNativeFrameInto(&frame, &into);
    try expect(written == expected.len);
    try expectEqualSlices(&expected, into[0..written]);
    try expectError(error.OutputTooSmall, vort.zstdDecodeNativeFrameInto(&frame, into[0 .. into.len - 1]));

    var decoder = vort.ZstdNativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    const scratch = try decoder.decodeScratch(&frame);
    try expectEqualSlices(&expected, scratch);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    const appended_written = try vort.zstdDecodeNativeFrameAppendExactSize(allocator, &appended, &frame, expected.len);
    try expect(appended_written == expected.len);
    try expectPrefixedPayload(appended.items, &expected);
    appended.clearRetainingCapacity();
    try expectError(error.SizeMismatch, vort.zstdDecodeNativeFrameAppendExactSize(allocator, &appended, &frame, expected.len - 1));

    var truncated_table = frame;
    setZstdProbeBlockPayloadLen(&truncated_table, 88);
    const truncated_table_slice = truncated_table[0 .. 9 + 88];
    const truncated_table_block = try vort.zstdInspectNativeFrameFirstBlock(truncated_table_slice);
    try expectError(error.TruncatedFrame, vort.zstdInspectNativeFrameBlockSequenceModes(truncated_table_slice, truncated_table_block));
    try expectError(error.TruncatedFrame, vort.zstdDecodedNativeFrameSize(truncated_table_slice));
    var truncated_table_output: [expected.len]u8 = undefined;
    try expectError(error.TruncatedFrame, vort.zstdDecodeNativeFrameInto(truncated_table_slice, &truncated_table_output));
    try expectAllocError(allocator, error.TruncatedFrame, vort.zstdDecodeNativeFrameAlloc(allocator, truncated_table_slice));

    var short_state = frame;
    setZstdProbeBlockPayloadLen(&short_state, 121);
    const short_state_slice = short_state[0 .. frame.len - 1];
    const short_state_block = try vort.zstdInspectNativeFrameFirstBlock(short_state_slice);
    const short_state_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(short_state_slice, short_state_block);
    try expect(short_state_modes.literal_length_mode == .compressed);
    try expect(short_state_modes.offset_mode == .compressed);
    try expect(short_state_modes.match_length_mode == .compressed);
    try expectError(error.TruncatedFrame, vort.zstdDecodedNativeFrameSize(short_state_slice));
    var short_state_output: [expected.len]u8 = undefined;
    try expectError(error.TruncatedFrame, vort.zstdDecodeNativeFrameInto(short_state_slice, &short_state_output));
    try expectAllocError(allocator, error.TruncatedFrame, vort.zstdDecodeNativeFrameAlloc(allocator, short_state_slice));

    var bad_mode = frame;
    bad_mode[96] = 0xa9; // Low mode bits are reserved by zstd and must stay zero.
    const bad_mode_block = try vort.zstdInspectNativeFrameFirstBlock(&bad_mode);
    try expectError(error.CorruptFrame, vort.zstdInspectNativeFrameBlockSequenceModes(&bad_mode, bad_mode_block));
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(&bad_mode));
    var bad_mode_output: [expected.len]u8 = undefined;
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(&bad_mode, &bad_mode_output));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &bad_mode));

    var zero_end_mark = frame;
    zero_end_mark[zero_end_mark.len - 1] = 0;
    const zero_end_block = try vort.zstdInspectNativeFrameFirstBlock(&zero_end_mark);
    const zero_end_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&zero_end_mark, zero_end_block);
    try expect(zero_end_modes.literal_length_mode == .compressed);
    try expect(zero_end_modes.offset_mode == .compressed);
    try expect(zero_end_modes.match_length_mode == .compressed);
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(&zero_end_mark));
    var zero_end_output: [expected.len]u8 = undefined;
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(&zero_end_mark, &zero_end_output));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &zero_end_mark));
}

fn checkAllCompressedThenRepeatedSequenceTables(allocator: std.mem.Allocator) !void {
    // First block defines LL/OF/ML as compressed FSE tables; the second block
    // uses Repeat_Mode for all three. This exercises table replay with the
    // densest sequence-table shape that the bootstrap writer can emit.
    const frame_hex =
        "28b52ffd600400a4020044036162636465666768696a6b6c6d6e6f7062636464656665666667686967686968696a6a6b6c6b6c6c6d6e6f6d6e6f6e6f7070717210a810386bdbdf106a1f1068ed01fb609ffe1f9f8fcdfb78fedfd865875345020044034142434445464748494a4b4c4d4e4f5042434444454645464647484947484948494a4a4b4c4b4c4c4d4e4f4d4e4f4e4f5050515210fcfb609ffe1f9f8fcdfb78fedfd8658753";
    const expected_hex =
        "6162636465666768696a6b6c6d6e6f706d6e6f70626e6f706d6e63646d6e6f70646566706465667064656670646566706667686964656670676869706768697067686970676869696a686970676a6b6c676a6b6c676b6c6c676a6b6c6d6e6f6c676b6c6c676d6e6f676d6e6f676e6e6f676d6f70676d6e6f676e7071726e7071726e4142434445464748494a4b4c4d4e4f504d4e4f50424e4f504d4e43444d4e4f50444546504445465044454650444546504647484944454650474849504748495047484950474849494a484950474a4b4c474a4b4c474b4c4c474a4b4c4d4e4f4c474b4c4c474d4e4f474d4e4f474e4e4f474d4f50474d4e4f474e5051524e5051524e";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);
    var expected: [expected_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, expected_hex);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    try expect(first_block.block_type == .compressed);
    try expect(!first_block.last);
    const first_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, first_block);
    try expect(first_modes.sequence_count == 16);
    try expect(first_modes.literal_length_mode == .compressed);
    try expect(first_modes.offset_mode == .compressed);
    try expect(first_modes.match_length_mode == .compressed);

    const second_block = try vort.zstdInspectNativeFrameBlockAt(&frame, first_block.next_header_offset);
    try expect(second_block.block_type == .compressed);
    try expect(second_block.last);
    const second_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, second_block);
    try expect(second_modes.sequence_count == 16);
    try expect(second_modes.literal_length_mode == .repeat);
    try expect(second_modes.offset_mode == .repeat);
    try expect(second_modes.match_length_mode == .repeat);

    const summary = try vort.zstdSummarizeNativeFrameBlocks(&frame);
    try expect(summary.block_count == 2);
    try expect(summary.compressed_block_count == 2);
    try expect(summary.raw_block_count == 0);
    try expect(summary.rle_block_count == 0);
    try expect((try vort.zstdDecodedNativeFrameSize(&frame)) == expected.len);
    try expect((try vort.zstdDecodedNativeFrameSizeLimited(&frame, expected.len)) == expected.len);
    try expectError(error.OutputLimitExceeded, vort.zstdDecodedNativeFrameSizeLimited(&frame, expected.len - 1));

    const lib_decoded = try vort.zstdDecodeFrameAlloc(allocator, &frame);
    defer allocator.free(lib_decoded);
    try expectEqualSlices(&expected, lib_decoded);

    const native_decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(native_decoded);
    try expectEqualSlices(&expected, native_decoded);
    try checkIncrementalFrameLibraryApis(allocator, &expected, &frame);
    try checkChunkedFrameLibraryApis(allocator, &expected, &frame);

    var into: [expected.len]u8 = undefined;
    const written = try vort.zstdDecodeNativeFrameInto(&frame, &into);
    try expect(written == expected.len);
    try expectEqualSlices(&expected, into[0..written]);

    var decoder = vort.ZstdNativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    const scratch = try decoder.decodeScratch(&frame);
    try expectEqualSlices(&expected, scratch);

    var short_repeat_state = frame;
    setZstdProbeBlockPayloadLenAt(&short_repeat_state, first_block.next_header_offset, true, 71);
    const short_repeat_slice = short_repeat_state[0 .. frame.len - 1];
    const short_repeat_block = try vort.zstdInspectNativeFrameBlockAt(short_repeat_slice, first_block.next_header_offset);
    const short_repeat_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(short_repeat_slice, short_repeat_block);
    try expect(short_repeat_modes.literal_length_mode == .repeat);
    try expect(short_repeat_modes.offset_mode == .repeat);
    try expect(short_repeat_modes.match_length_mode == .repeat);
    try expectError(error.TruncatedFrame, vort.zstdDecodedNativeFrameSize(short_repeat_slice));
    var short_repeat_output: [expected.len]u8 = undefined;
    try expectError(error.TruncatedFrame, vort.zstdDecodeNativeFrameInto(short_repeat_slice, &short_repeat_output));
    try expectAllocError(allocator, error.TruncatedFrame, vort.zstdDecodeNativeFrameAlloc(allocator, short_repeat_slice));

    var bad_repeat_mode = frame;
    bad_repeat_mode[152] = 0xfd; // Repeat-mode byte keeps the low reserved bits clear.
    const bad_repeat_block = try vort.zstdInspectNativeFrameBlockAt(&bad_repeat_mode, first_block.next_header_offset);
    try expectError(error.CorruptFrame, vort.zstdInspectNativeFrameBlockSequenceModes(&bad_repeat_mode, bad_repeat_block));
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(&bad_repeat_mode));
    var bad_repeat_output: [expected.len]u8 = undefined;
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(&bad_repeat_mode, &bad_repeat_output));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &bad_repeat_mode));

    var zero_repeat_end_mark = frame;
    zero_repeat_end_mark[zero_repeat_end_mark.len - 1] = 0;
    const zero_repeat_block = try vort.zstdInspectNativeFrameBlockAt(&zero_repeat_end_mark, first_block.next_header_offset);
    const zero_repeat_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&zero_repeat_end_mark, zero_repeat_block);
    try expect(zero_repeat_modes.literal_length_mode == .repeat);
    try expect(zero_repeat_modes.offset_mode == .repeat);
    try expect(zero_repeat_modes.match_length_mode == .repeat);
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(&zero_repeat_end_mark));
    var zero_repeat_output: [expected.len]u8 = undefined;
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(&zero_repeat_end_mark, &zero_repeat_output));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &zero_repeat_end_mark));
}

fn checkFixedLibZstdFseSequenceFrames(allocator: std.mem.Allocator) !void {
    // Fixed libzstd-generated frames from the unit suite. They exercise native
    // decode of a single-frame OF=FSE shape and a single-frame LL/OF/ML=FSE
    // shape through the public probe, complementing Vort-emitted repeat-mode
    // fixtures with reference-generated entropy payloads.
    var payload: std.ArrayList(u8) = .empty;
    defer payload.deinit(allocator);
    for (0..20) |i| {
        const line = try std.fmt.allocPrint(
            allocator,
            "{{\"k\":\"{d:0>4}\",\"n\":{d},\"txt\":\"abcdefghijklmnopqrstuvwxyz0123456789\"}}\n",
            .{ i, i },
        );
        defer allocator.free(line);
        try payload.appendSlice(allocator, line);
    }

    const cases = [_]struct {
        frame_hex: []const u8,
        expect_ll_fse: bool,
        expect_of_fse: bool,
        expect_ml_fse: bool,
    }{
        .{
            .frame_hex = "28b52ffd04480d05008246171b604fda9c7c0c3be3e2e30209a920082d844864" ++
                "7777ec670a42a39c2921d4cdbcab9a89786767971242ddccbbaa99887780cc13" ++
                "6a5e4d3cbb582a94896445200f47e3612c1c4502713014080341e0eaabb2de" ++
                "98faf3e6666657778e092720f0750344c9ae87b9d2732eeb11f77a982b7dce" ++
                "653de25e0f73a5e7dc65254ec31a8f60d7c330e97318eb11ec7a18263d87" ++
                "b11ec1ae0ec3a4e70833602852141ad6cc48",
            .expect_ll_fse = false,
            .expect_of_fse = true,
            .expect_ml_fse = false,
        },
        .{
            .frame_hex = "28b52ffd0458bd04006286161d404fd4010c12709f71cdcb65012b8aa20c2b" ++
                "adb44686e60ccbf0189303ffffffff9fbfe75c6b8cada5544a083d20d3e71" ++
                "a5b2aa1f362a950269218813c1c8d87b1701409c4c150200c0481c2c64a6" ++
                "c93b04f9b666616d6292627a831ecebff6790734a0f1118396384ffff1d1f" ++
                "351a6514ea22a98a124d541551a887841a1aa91692544238998e4eabd5ea" ++
                "745a261a1840a4061ad6cc48",
            .expect_ll_fse = true,
            .expect_of_fse = true,
            .expect_ml_fse = true,
        },
    };

    inline for (cases) |case| {
        var frame: [case.frame_hex.len / 2]u8 = undefined;
        _ = try std.fmt.hexToBytes(&frame, case.frame_hex);

        const block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
        try expect(block.block_type == .compressed);
        try expect(block.last);
        const modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, block);
        try expect((modes.literal_length_mode == .compressed) == case.expect_ll_fse);
        try expect((modes.offset_mode == .compressed) == case.expect_of_fse);
        try expect((modes.match_length_mode == .compressed) == case.expect_ml_fse);

        const lib_decoded = try vort.zstdDecodeFrameAlloc(allocator, &frame);
        defer allocator.free(lib_decoded);
        try expectEqualSlices(payload.items, lib_decoded);

        const native_decoded = try vort.zstdDecodeNativeFrameAllocLimited(allocator, &frame, payload.items.len);
        defer allocator.free(native_decoded);
        try expectEqualSlices(payload.items, native_decoded);
        try checkIncrementalFrameLibraryApis(allocator, payload.items, &frame);
        try checkChunkedFrameLibraryApis(allocator, payload.items, &frame);

        const into = try allocator.alloc(u8, payload.items.len);
        defer allocator.free(into);
        const written = try vort.zstdDecodeNativeFrameIntoExactSize(&frame, into, payload.items.len);
        try expect(written == payload.items.len);
        try expectEqualSlices(payload.items, into[0..written]);
        try expectError(error.OutputTooSmall, vort.zstdDecodeNativeFrameIntoExactSize(&frame, into[0 .. into.len - 1], payload.items.len));
    }
}

fn setZstdProbeBlockPayloadLen(frame: []u8, payload_len: usize) void {
    // The handcrafted fixtures in this probe all use a simple one-frame,
    // one-block zstd layout: 4-byte magic, 2-byte frame header, then a 3-byte
    // block header. Keep length mutations local to that fixture shape so the
    // negative tests exercise payload parsing without changing unrelated frame
    // metadata.
    const header: u24 = @intCast((payload_len << 3) | (2 << 1) | 1);
    std.mem.writeInt(u24, frame[6..][0..3], header, .little);
}

fn setZstdProbeBlockPayloadLenAt(frame: []u8, header_offset: usize, last: bool, payload_len: usize) void {
    const header: u24 = @intCast((payload_len << 3) | (2 << 1) | @intFromBool(last));
    std.mem.writeInt(u24, frame[header_offset..][0..3], header, .little);
}

fn checkRepeatSequenceTablesAcrossRawAndRleBlocks(allocator: std.mem.Allocator) !void {
    // Raw and RLE blocks may appear back-to-back between a compressed table
    // definition and a later Repeat_Mode block. This fixture keeps that replay
    // state visible through public APIs after crossing both non-compressed block
    // kinds in one frame, rather than only one at a time.
    const expected = ("a" ** 132) ++ "RAW" ++ ("R" ** 3) ++ ("a" ** 132);
    const frame_hex = "28b52ffd600e00440000096101500100002a1800005241571a000052350000096101fc002a";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const lib_decoded = try vort.zstdDecodeFrameAlloc(allocator, &frame);
    defer allocator.free(lib_decoded);
    try expectEqualSlices(expected, lib_decoded);
    try expect((try vort.zstdDecodedFrameSize(&frame)) == expected.len);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    try expect(first_block.block_type == .compressed);
    try expect(!first_block.last);
    const first_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, first_block);
    try expect(first_modes.literal_length_mode == .rle);
    try expect(first_modes.offset_mode == .rle);
    try expect(first_modes.match_length_mode == .predefined);

    const raw_block = try vort.zstdInspectNativeFrameBlockAt(&frame, first_block.next_header_offset);
    try expect(raw_block.block_type == .raw);
    try expect(!raw_block.last);

    const rle_block = try vort.zstdInspectNativeFrameBlockAt(&frame, raw_block.next_header_offset);
    try expect(rle_block.block_type == .rle);
    try expect(!rle_block.last);

    const repeat_block = try vort.zstdInspectNativeFrameBlockAt(&frame, rle_block.next_header_offset);
    try expect(repeat_block.block_type == .compressed);
    try expect(repeat_block.last);
    const repeat_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, repeat_block);
    try expect(repeat_modes.literal_length_mode == .repeat);
    try expect(repeat_modes.offset_mode == .repeat);
    try expect(repeat_modes.match_length_mode == .repeat);

    const summary = try vort.zstdSummarizeNativeFrameBlocks(&frame);
    try expect(summary.block_count == 4);
    try expect(summary.compressed_block_count == 2);
    try expect(summary.raw_block_count == 1);
    try expect(summary.rle_block_count == 1);

    try expect((try vort.zstdDecodedNativeFrameSize(&frame)) == expected.len);
    try expect((try vort.zstdDecodedNativeFrameSizeLimited(&frame, expected.len)) == expected.len);
    try expectError(error.OutputLimitExceeded, vort.zstdDecodedNativeFrameSizeLimited(&frame, expected.len - 1));

    const native_decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(native_decoded);
    try expectEqualSlices(expected, native_decoded);
    try checkIncrementalFrameLibraryApis(allocator, expected, &frame);
    try checkChunkedFrameLibraryApis(allocator, expected, &frame);

    var into: [expected.len]u8 = undefined;
    const written = try vort.zstdDecodeNativeFrameIntoExactSize(&frame, &into, expected.len);
    try expect(written == expected.len);
    try expectEqualSlices(expected, into[0..written]);
    try expectError(error.OutputTooSmall, vort.zstdDecodeNativeFrameIntoExactSize(&frame, into[0 .. into.len - 1], expected.len));
    try expectError(error.SizeMismatch, vort.zstdDecodeNativeFrameIntoExactSize(&frame, &into, expected.len - 1));
}

fn checkRepeatSequenceTablesAcrossRleAndRawBlocks(allocator: std.mem.Allocator) !void {
    // Sibling of the raw-then-RLE fixture above: the order of non-compressed
    // blocks must not matter when preserving same-frame sequence table state.
    const expected = ("a" ** 132) ++ ("R" ** 3) ++ "RAW" ++ ("a" ** 132);
    const frame_hex = "28b52ffd600e00440000096101500100002a1a000052180000524157350000096101fc002a";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const lib_decoded = try vort.zstdDecodeFrameAlloc(allocator, &frame);
    defer allocator.free(lib_decoded);
    try expectEqualSlices(expected, lib_decoded);
    try expect((try vort.zstdDecodedFrameSize(&frame)) == expected.len);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    try expect(first_block.block_type == .compressed);
    try expect(!first_block.last);
    const first_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, first_block);
    try expect(first_modes.literal_length_mode == .rle);
    try expect(first_modes.offset_mode == .rle);
    try expect(first_modes.match_length_mode == .predefined);

    const rle_block = try vort.zstdInspectNativeFrameBlockAt(&frame, first_block.next_header_offset);
    try expect(rle_block.block_type == .rle);
    try expect(!rle_block.last);

    const raw_block = try vort.zstdInspectNativeFrameBlockAt(&frame, rle_block.next_header_offset);
    try expect(raw_block.block_type == .raw);
    try expect(!raw_block.last);

    const repeat_block = try vort.zstdInspectNativeFrameBlockAt(&frame, raw_block.next_header_offset);
    try expect(repeat_block.block_type == .compressed);
    try expect(repeat_block.last);
    const repeat_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, repeat_block);
    try expect(repeat_modes.literal_length_mode == .repeat);
    try expect(repeat_modes.offset_mode == .repeat);
    try expect(repeat_modes.match_length_mode == .repeat);

    const summary = try vort.zstdSummarizeNativeFrameBlocks(&frame);
    try expect(summary.block_count == 4);
    try expect(summary.compressed_block_count == 2);
    try expect(summary.raw_block_count == 1);
    try expect(summary.rle_block_count == 1);

    try expect((try vort.zstdDecodedNativeFrameSize(&frame)) == expected.len);
    try expect((try vort.zstdDecodedNativeFrameSizeLimited(&frame, expected.len)) == expected.len);
    try expectError(error.OutputLimitExceeded, vort.zstdDecodedNativeFrameSizeLimited(&frame, expected.len - 1));

    const native_decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(native_decoded);
    try expectEqualSlices(expected, native_decoded);
    try checkIncrementalFrameLibraryApis(allocator, expected, &frame);
    try checkChunkedFrameLibraryApis(allocator, expected, &frame);

    var into: [expected.len]u8 = undefined;
    const written = try vort.zstdDecodeNativeFrameIntoExactSize(&frame, &into, expected.len);
    try expect(written == expected.len);
    try expectEqualSlices(expected, into[0..written]);
    try expectError(error.OutputTooSmall, vort.zstdDecodeNativeFrameIntoExactSize(&frame, into[0 .. into.len - 1], expected.len));
    try expectError(error.SizeMismatch, vort.zstdDecodeNativeFrameIntoExactSize(&frame, &into, expected.len - 1));
}

fn checkLiteralLengthCompressedThenRepeatedSequenceTables(allocator: std.mem.Allocator) !void {
    // Public frame-level fixture for an LL=FSE table followed by Repeat_Mode.
    // Together with the ML/OF fixtures this keeps all three compressed sequence
    // alphabets visible through the non-dictionary frame decode/inspect APIs.
    const frame_hex =
        "28b52ffd20b8040200e402616278616261627879616278616261627879616278616261627861626162787961627861626162787961627861621094106aed0102059966271a8d6e371735000010616201fcb9";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    try expect(first_block.block_type == .compressed);
    try expect(!first_block.last);
    const first_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, first_block);
    try expect(first_modes.sequence_count == 16);
    try expect(first_modes.literal_length_mode == .compressed);
    try expect(first_modes.offset_mode == .rle);
    try expect(first_modes.match_length_mode == .rle);

    const second_block = try vort.zstdInspectNativeFrameBlockAt(&frame, first_block.next_header_offset);
    try expect(second_block.block_type == .compressed);
    try expect(second_block.last);
    const second_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, second_block);
    try expect(second_modes.sequence_count == 1);
    try expect(second_modes.literal_length_mode == .repeat);
    try expect(second_modes.offset_mode == .repeat);
    try expect(second_modes.match_length_mode == .repeat);

    const summary = try vort.zstdSummarizeNativeFrameBlocks(&frame);
    try expect(summary.block_count == 2);
    try expect(summary.compressed_block_count == 2);
    try expect(summary.raw_block_count == 0);
    try expect(summary.rle_block_count == 0);
    try expect((try vort.zstdDecodedNativeFrameSize(&frame)) == 184);
    try expect((try vort.zstdDecodedNativeFrameSizeLimited(&frame, 184)) == 184);
    try expectError(error.OutputLimitExceeded, vort.zstdDecodedNativeFrameSizeLimited(&frame, 183));

    const decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(decoded);
    try expect(decoded.len == 184);
    try expectEqualSlices("ababababab", decoded[decoded.len - 10 ..]);
    var into: [184]u8 = undefined;
    const written = try vort.zstdDecodeNativeFrameInto(&frame, &into);
    try expect(written == decoded.len);
    try expectEqualSlices(decoded, into[0..written]);

    var decoder = vort.ZstdNativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    const scratch = try decoder.decodeScratch(&frame);
    try expectEqualSlices(decoded, scratch);

    const short_repeat_state_hex =
        "28b52ffd20b8040200e402616278616261627879616278616261627879616278616261627861626162787961627861626162787961627861621094106aed0102059966271a8d6e37172d000010616201fc";
    var short_repeat_state: [short_repeat_state_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&short_repeat_state, short_repeat_state_hex);
    const repeat_first = try vort.zstdInspectNativeFrameFirstBlock(&short_repeat_state);
    const repeat_second = try vort.zstdInspectNativeFrameBlockAt(&short_repeat_state, repeat_first.next_header_offset);
    try expectError(error.TruncatedFrame, vort.zstdInspectNativeFrameBlockSequenceModes(&short_repeat_state, repeat_second));
    try expectError(error.TruncatedFrame, vort.zstdDecodedNativeFrameSize(&short_repeat_state));
    var short_repeat_output: [184]u8 = undefined;
    try expectError(error.TruncatedFrame, vort.zstdDecodeNativeFrameInto(&short_repeat_state, &short_repeat_output));
    try expectAllocError(allocator, error.TruncatedFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &short_repeat_state));

    const short_state_hex =
        "28b52ffd20b8fc0100e402616278616261627879616278616261627879616278616261627861626162787961627861626162787961627861621094106aed0102059966271a8d6e3735000010616201fcb9";
    var short_state: [short_state_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&short_state, short_state_hex);
    const short_block = try vort.zstdInspectNativeFrameFirstBlock(&short_state);
    const short_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&short_state, short_block);
    try expect(short_modes.literal_length_mode == .compressed);
    try expectError(error.TruncatedFrame, vort.zstdDecodedNativeFrameSize(&short_state));
    var short_output: [184]u8 = undefined;
    try expectError(error.TruncatedFrame, vort.zstdDecodeNativeFrameInto(&short_state, &short_output));
    try expectAllocError(allocator, error.TruncatedFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &short_state));
}

fn checkMatchLengthCompressedThenRepeatedSequenceTables(allocator: std.mem.Allocator) !void {
    // Public frame-level fixture for an ML=FSE table followed by Repeat_Mode.
    // This mirrors the dictionary probe's heavier sequence-table fixture but
    // keeps the non-dictionary frame decode/inspect surface independently
    // covered.
    const frame_hex =
        "28b52ffd20a2240100606162636465666768696a6b6c10180210aeb5070b83c3c2c360e030701878383c1cec922d00000001fc3b20";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    try expect(first_block.block_type == .compressed);
    try expect(!first_block.last);
    const first_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, first_block);
    try expect(first_modes.sequence_count == 16);
    try expect(first_modes.literal_length_mode == .predefined);
    try expect(first_modes.offset_mode == .rle);
    try expect(first_modes.match_length_mode == .compressed);

    const second_block = try vort.zstdInspectNativeFrameBlockAt(&frame, first_block.next_header_offset);
    try expect(second_block.block_type == .compressed);
    try expect(second_block.last);
    const second_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, second_block);
    try expect(second_modes.sequence_count == 1);
    try expect(second_modes.literal_length_mode == .repeat);
    try expect(second_modes.offset_mode == .repeat);
    try expect(second_modes.match_length_mode == .repeat);

    const summary = try vort.zstdSummarizeNativeFrameBlocks(&frame);
    try expect(summary.block_count == 2);
    try expect(summary.compressed_block_count == 2);
    try expect(summary.raw_block_count == 0);
    try expect(summary.rle_block_count == 0);
    try expect((try vort.zstdDecodedNativeFrameSize(&frame)) == 162);
    try expect((try vort.zstdDecodedNativeFrameSizeLimited(&frame, 162)) == 162);
    try expectError(error.OutputLimitExceeded, vort.zstdDecodedNativeFrameSizeLimited(&frame, 161));

    const decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(decoded);
    try expect(decoded.len == 162);
    var into: [162]u8 = undefined;
    const written = try vort.zstdDecodeNativeFrameInto(&frame, &into);
    try expect(written == decoded.len);
    try expectEqualSlices(decoded, into[0..written]);

    var decoder = vort.ZstdNativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    const scratch = try decoder.decodeScratch(&frame);
    try expectEqualSlices(decoded, scratch);

    const short_repeat_state_hex =
        "28b52ffd20a2240100606162636465666768696a6b6c10180210aeb5070b83c3c2c360e030701878383c1cec922500000001fc3b";
    var short_repeat_state: [short_repeat_state_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&short_repeat_state, short_repeat_state_hex);
    const repeat_first = try vort.zstdInspectNativeFrameFirstBlock(&short_repeat_state);
    const repeat_second = try vort.zstdInspectNativeFrameBlockAt(&short_repeat_state, repeat_first.next_header_offset);
    const repeat_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&short_repeat_state, repeat_second);
    try expect(repeat_modes.sequence_count == 1);
    try expect(repeat_modes.literal_length_mode == .repeat);
    try expect(repeat_modes.offset_mode == .repeat);
    try expect(repeat_modes.match_length_mode == .repeat);
    try expectError(error.TruncatedFrame, vort.zstdDecodedNativeFrameSize(&short_repeat_state));
    var short_repeat_output: [162]u8 = undefined;
    try expectError(error.TruncatedFrame, vort.zstdDecodeNativeFrameInto(&short_repeat_state, &short_repeat_output));
    try expectAllocError(allocator, error.TruncatedFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &short_repeat_state));
}

fn checkLibZstdGeneratedLibraryFrames(allocator: std.mem.Allocator) !usize {
    var sequential: [2048]u8 = undefined;
    for (&sequential, 0..) |*byte, i| byte.* = @intCast(i % 251);

    var randomish: [2048]u8 = undefined;
    var rng = std.Random.DefaultPrng.init(0x7a57_1b5d);
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

    const boundary_payload_len = std.compress.zstd.block_size_max + 1;
    const boundary_multiblock = try allocator.alloc(u8, boundary_payload_len);
    defer allocator.free(boundary_multiblock);
    for (boundary_multiblock, 0..) |*byte, i| {
        // The +1 boundary catches off-by-one mistakes in frame/block walking:
        // libzstd must emit a second block whose decoded contribution is tiny,
        // while Vort's native APIs still need to account for it across sized,
        // unsized, checksummed, incremental, and chunked decode paths.
        byte.* = @intCast((i * 73 + i / 257) & 0xff);
    }

    const large_payload_len = std.compress.zstd.block_size_max + 8192;
    const large_multiblock = try allocator.alloc(u8, large_payload_len);
    defer allocator.free(large_multiblock);
    for (large_multiblock, 0..) |*byte, i| {
        // Force libzstd to emit more than one data block while keeping the
        // content deterministic and mixed enough to exercise literal/sequence
        // handling rather than collapsing into a single trivial RLE shape.
        const stripe = i % 4096;
        byte.* = switch (stripe % 13) {
            0 => @intCast((i / 17) & 0xff),
            1, 2, 3 => @intCast('A' + (stripe % 23)),
            4 => 0,
            5 => 0xff,
            else => @intCast((stripe * 31 + i / 4096) & 0xff),
        };
    }

    const triple_payload_len = std.compress.zstd.block_size_max * 2 + 1;
    const triple_multiblock = try allocator.alloc(u8, triple_payload_len);
    defer allocator.free(triple_multiblock);
    for (triple_multiblock, 0..) |*byte, i| {
        // One byte past two full blocks forces a third block and keeps the
        // frame iterator moving beyond the second-block truncation fixtures.
        const lane = i % 8191;
        byte.* = switch (lane % 17) {
            0 => @intCast((i / 257) & 0xff),
            1, 2 => @intCast('0' + (lane % 10)),
            3 => 0,
            4 => 0xff,
            5, 6, 7 => @intCast('a' + (lane % 26)),
            else => @intCast((lane * 19 + i / 8191) & 0xff),
        };
    }

    const high_entropy_payload_len = std.compress.zstd.block_size_max * 2 + 333;
    const high_entropy_multiblock = try allocator.alloc(u8, high_entropy_payload_len);
    defer allocator.free(high_entropy_multiblock);
    var high_entropy_rng = std.Random.DefaultPrng.init(0x4851_7d5a_e3c0_129b);
    for (high_entropy_multiblock) |*byte| {
        // A deterministic high-entropy corpus complements the structured
        // multi-block fixtures above. It tends to drive libzstd toward raw or
        // nearly-uncompressible block shapes while still exercising the same
        // public native decode, chunked, checksum, and truncation paths.
        byte.* = high_entropy_rng.random().int(u8);
    }

    var structured_logs: std.ArrayList(u8) = .empty;
    defer structured_logs.deinit(allocator);
    var log_index: usize = 0;
    while (structured_logs.items.len < std.compress.zstd.block_size_max * 2 + 4096) : (log_index += 1) {
        const line = try std.fmt.allocPrint(
            allocator,
            "{{\"ts\":\"2026-08-02T{d:0>2}:{d:0>2}:{d:0>2}.000Z\",\"level\":\"{s}\",\"service\":\"vort-zstd\",\"trace\":\"{x:0>8}\",\"message\":\"structured libzstd differential row {d}\",\"payload\":\"alpha beta gamma delta epsilon\"}}\n",
            .{
                (log_index / 3600) % 24,
                (log_index / 60) % 60,
                log_index % 60,
                if (log_index % 11 == 0) "warn" else if (log_index % 17 == 0) "error" else "info",
                @as(u32, @truncate(log_index *% 2_654_435_761)),
                log_index,
            },
        );
        defer allocator.free(line);
        // Structured logs sit between highly repetitive and high-entropy
        // corpora. They keep JSON syntax, repeated field names, and varied
        // values visible in the libzstd-generated multi-block differential.
        try structured_logs.appendSlice(allocator, line);
    }

    const json_unit = "{\"service\":\"vort\",\"codec\":\"zstd\",\"native\":true,\"value\":12345}\n";
    const cases = [_]struct {
        payload: []const u8,
        min_blocks: usize,
    }{
        .{ .payload = "zstd-small-reference-payload", .min_blocks = 1 },
        .{ .payload = "abcd" ** 512, .min_blocks = 1 },
        .{ .payload = &sequential, .min_blocks = 1 },
        .{ .payload = json_unit ** 64, .min_blocks = 1 },
        .{ .payload = &binary_mix, .min_blocks = 1 },
        .{ .payload = &sparse_zero, .min_blocks = 1 },
        .{ .payload = &randomish, .min_blocks = 1 },
        .{ .payload = structured_logs.items, .min_blocks = 3 },
        .{ .payload = boundary_multiblock, .min_blocks = 2 },
        .{ .payload = large_multiblock, .min_blocks = 2 },
        .{ .payload = triple_multiblock, .min_blocks = 3 },
        .{ .payload = high_entropy_multiblock, .min_blocks = 3 },
    };
    // This generated-frame matrix is a decode/API smoke, not an encoder-ratio
    // benchmark. Level 0 deliberately selects the raw/RLE compatibility writer
    // so Debug CI still covers sized/unsized/checksummed multi-block frames,
    // truncation, chunked drains, and reusable decoders without repeatedly
    // paying the bootstrap match-planning cost. Hand-authored fixtures above
    // keep compressed-block, Huffman, and sequence-table behavior covered.
    const levels = [_]c_int{0};
    const option_sets = [_]vort.ZstdFrameOptions{
        .{},
        .{ .include_content_size = false },
        .{ .include_content_size = false, .content_checksum = true },
    };

    var checked: usize = 0;
    for (cases) |case| {
        for (levels) |level| {
            for (option_sets) |options| {
                checked += try checkLibZstdGeneratedLibraryFrame(allocator, case.payload, level, options, case.min_blocks);
            }
        }
    }
    return checked;
}

fn checkLibZstdGeneratedLibraryFrame(
    allocator: std.mem.Allocator,
    payload: []const u8,
    level: c_int,
    options: vort.ZstdFrameOptions,
    min_blocks: usize,
) !usize {
    const encoded = try vort.zstdEncodeFrameWithLevelAndOptionsAlloc(allocator, payload, level, options);
    defer allocator.free(encoded);
    var checked: usize = 1;

    // This is intentionally a pure Zig library differential: libzstd writes the
    // compatibility frame through Vort's library wrapper, then the dependency-
    // free native decoder must agree across one-shot, caller-buffer, reusable,
    // append, incremental, and bounded-size public APIs. No CLI command
    // participates in the oracle path.
    const lib_decoded = try vort.zstdDecodeFrameAlloc(allocator, encoded);
    defer allocator.free(lib_decoded);
    try expectEqualSlices(payload, lib_decoded);

    const lib_into = try allocator.alloc(u8, payload.len);
    defer allocator.free(lib_into);
    const lib_written = try vort.zstdDecodeFrameInto(encoded, lib_into);
    try expect(lib_written == payload.len);
    try expectEqualSlices(payload, lib_into[0..lib_written]);

    const stream_summary = try vort.zstdSummarizeNativeStream(encoded);
    try expect(stream_summary.frame_count == 1);
    try expect(stream_summary.block_count >= min_blocks);
    try expect(stream_summary.skippable_frame_count == 0);
    const block_summary = try vort.zstdSummarizeNativeFrameBlocks(encoded);
    try expect(block_summary.block_count == stream_summary.block_count);
    try expect(block_summary.block_count >= min_blocks);

    try expect((try vort.zstdDecodedNativeFrameSizeLimited(encoded, payload.len)) == payload.len);
    try expectError(error.OutputLimitExceeded, vort.zstdDecodedNativeFrameSizeLimited(encoded, payload.len - 1));

    const native_decoded = try vort.zstdDecodeNativeFrameAllocLimited(allocator, encoded, payload.len);
    defer allocator.free(native_decoded);
    try expectEqualSlices(payload, native_decoded);
    try expectAllocError(allocator, error.OutputLimitExceeded, vort.zstdDecodeNativeFrameAllocLimited(allocator, encoded, payload.len - 1));

    const native_into = try allocator.alloc(u8, payload.len);
    defer allocator.free(native_into);
    const native_written = try vort.zstdDecodeNativeFrameInto(encoded, native_into);
    try expect(native_written == payload.len);
    try expectEqualSlices(payload, native_into[0..native_written]);
    try expectError(error.OutputTooSmall, vort.zstdDecodeNativeFrameInto(encoded, native_into[0 .. native_into.len - 1]));

    var decoder = vort.ZstdNativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    const scratch = try decoder.decodeScratchLimited(encoded, payload.len);
    try expectEqualSlices(payload, scratch);
    try expectError(error.OutputLimitExceeded, decoder.decodeScratchLimited(encoded, payload.len - 1));
    const reusable_exact_written = try decoder.decodeIntoSliceExactSize(encoded, native_into, payload.len);
    try expect(reusable_exact_written == payload.len);
    try expectEqualSlices(payload, native_into[0..reusable_exact_written]);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    const appended_written = try decoder.decodeAppendExactSize(&appended, encoded, payload.len);
    try expect(appended_written == payload.len);
    try expectPrefixedPayload(appended.items, payload);
    appended.clearRetainingCapacity();
    try expectError(error.SizeMismatch, decoder.decodeAppendExactSize(&appended, encoded, payload.len - 1));

    try checkIncrementalFrameLibraryApis(allocator, payload, encoded);
    try checkChunkedFrameLibraryApis(allocator, payload, encoded);

    if (min_blocks > 1) {
        checked += try checkTruncatedLibZstdGeneratedFrameApis(allocator, payload, encoded, min_blocks);
    }
    if (min_blocks > 1 and options.content_checksum) {
        checked += try checkCorruptChecksumLibZstdGeneratedFrameApis(allocator, payload, encoded);
    }
    return checked;
}

fn checkIncrementalFrameLibraryApis(allocator: std.mem.Allocator, payload: []const u8, frame: []const u8) !void {
    var decoder = vort.ZstdNativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();

    const output = try allocator.alloc(u8, payload.len);
    defer allocator.free(output);
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    var status: vort.StepResult.Status = .need_input;

    while (status != .done) {
        const input_chunk_len: usize = if (input_offset < frame.len) @min(frame.len - input_offset, 17) else 0;
        const remaining_output = output.len - output_offset;
        const output_chunk_len: usize = if (remaining_output == 0) 0 else @min(remaining_output, 191);
        const result = try decoder.step(
            frame[input_offset..][0..input_chunk_len],
            output[output_offset..][0..output_chunk_len],
        );
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
        status = result.status;

        switch (status) {
            .need_input => {
                if (input_offset >= frame.len) return error.ZstdNativeFrameProbeMismatch;
            },
            .need_output => {
                if (output_offset >= output.len) return error.ZstdNativeFrameProbeMismatch;
            },
            .done => {},
        }
    }

    try expect(input_offset == frame.len);
    try expect(output_offset == payload.len);
    try expectEqualSlices(payload, output);
    try decoder.finish();
}

fn checkTruncatedLibZstdGeneratedFrameApis(allocator: std.mem.Allocator, payload: []const u8, frame: []const u8, min_blocks: usize) !usize {
    // Derive hostile multi-block fixtures from libzstd output instead of
    // hand-authoring the entropy payload. Dropping the final byte keeps every
    // advertised block/header length intact except the trailing payload/checksum
    // accounting, so all public native facades should converge on
    // TruncatedFrame rather than SizeMismatch, ChecksumMismatch, or silent EOF.
    if (frame.len < 2) return error.ZstdNativeFrameProbeMismatch;
    var checked: usize = 0;
    const truncated = frame[0 .. frame.len - 1];

    const into = try allocator.alloc(u8, payload.len);
    defer allocator.free(into);
    var reusable = vort.ZstdNativeFrameDecoder.init(allocator);
    defer reusable.deinit();

    try checkTruncatedLibZstdGeneratedTailApis(allocator, payload, truncated);
    checked += 1;

    const first_block_payload_truncated = try firstBlockPayloadTruncatedFrame(frame);
    try expectError(error.TruncatedFrame, vort.zstdSummarizeNativeStream(first_block_payload_truncated));
    try expectError(error.TruncatedFrame, vort.zstdSummarizeNativeFrameBlocks(first_block_payload_truncated));
    try expectError(error.TruncatedFrame, vort.zstdDecodedNativeFrameSizeLimited(first_block_payload_truncated, payload.len));
    try expectError(error.TruncatedFrame, vort.zstdDecodeNativeFrameInto(first_block_payload_truncated, into));
    try expectAllocError(allocator, error.TruncatedFrame, vort.zstdDecodeNativeFrameAllocLimited(allocator, first_block_payload_truncated, payload.len));
    try expectError(error.TruncatedFrame, reusable.decodedSizeLimited(first_block_payload_truncated, payload.len));
    try expectError(error.TruncatedFrame, reusable.decodeIntoSlice(first_block_payload_truncated, into));
    try checkTruncatedLibZstdGeneratedIncrementalApis(allocator, payload, first_block_payload_truncated);
    try checkTruncatedLibZstdGeneratedChunkedApis(allocator, payload, first_block_payload_truncated);
    checked += 1;

    const second_block_header_truncated = try secondBlockHeaderTruncatedFrame(frame);
    try expectError(error.TruncatedFrame, vort.zstdSummarizeNativeStream(second_block_header_truncated));
    try expectError(error.TruncatedFrame, vort.zstdSummarizeNativeFrameBlocks(second_block_header_truncated));
    try expectError(error.TruncatedFrame, vort.zstdDecodedNativeFrameSizeLimited(second_block_header_truncated, payload.len));
    try expectError(error.TruncatedFrame, vort.zstdDecodeNativeFrameInto(second_block_header_truncated, into));
    try expectAllocError(allocator, error.TruncatedFrame, vort.zstdDecodeNativeFrameAllocLimited(allocator, second_block_header_truncated, payload.len));
    try expectError(error.TruncatedFrame, reusable.decodedSizeLimited(second_block_header_truncated, payload.len));
    try expectError(error.TruncatedFrame, reusable.decodeIntoSlice(second_block_header_truncated, into));
    try checkTruncatedLibZstdGeneratedIncrementalApis(allocator, payload, second_block_header_truncated);
    try checkTruncatedLibZstdGeneratedChunkedApis(allocator, payload, second_block_header_truncated);
    checked += 1;

    const second_block_payload_truncated = try secondBlockPayloadTruncatedFrame(frame);
    try expectError(error.TruncatedFrame, vort.zstdSummarizeNativeStream(second_block_payload_truncated));
    try expectError(error.TruncatedFrame, vort.zstdSummarizeNativeFrameBlocks(second_block_payload_truncated));
    try expectError(error.TruncatedFrame, vort.zstdDecodedNativeFrameSizeLimited(second_block_payload_truncated, payload.len));
    try expectError(error.TruncatedFrame, vort.zstdDecodeNativeFrameInto(second_block_payload_truncated, into));
    try expectAllocError(allocator, error.TruncatedFrame, vort.zstdDecodeNativeFrameAllocLimited(allocator, second_block_payload_truncated, payload.len));
    try expectError(error.TruncatedFrame, reusable.decodedSizeLimited(second_block_payload_truncated, payload.len));
    try expectError(error.TruncatedFrame, reusable.decodeIntoSlice(second_block_payload_truncated, into));
    try checkTruncatedLibZstdGeneratedIncrementalApis(allocator, payload, second_block_payload_truncated);
    try checkTruncatedLibZstdGeneratedChunkedApis(allocator, payload, second_block_payload_truncated);
    checked += 1;

    if (min_blocks >= 3) {
        const third_block_header_truncated = try nthBlockHeaderTruncatedFrame(frame, 2);
        try expectError(error.TruncatedFrame, vort.zstdSummarizeNativeStream(third_block_header_truncated));
        try expectError(error.TruncatedFrame, vort.zstdSummarizeNativeFrameBlocks(third_block_header_truncated));
        try expectError(error.TruncatedFrame, vort.zstdDecodedNativeFrameSizeLimited(third_block_header_truncated, payload.len));
        try expectError(error.TruncatedFrame, vort.zstdDecodeNativeFrameInto(third_block_header_truncated, into));
        try expectAllocError(allocator, error.TruncatedFrame, vort.zstdDecodeNativeFrameAllocLimited(allocator, third_block_header_truncated, payload.len));
        try expectError(error.TruncatedFrame, reusable.decodedSizeLimited(third_block_header_truncated, payload.len));
        try expectError(error.TruncatedFrame, reusable.decodeIntoSlice(third_block_header_truncated, into));
        try checkTruncatedLibZstdGeneratedIncrementalApis(allocator, payload, third_block_header_truncated);
        try checkTruncatedLibZstdGeneratedChunkedApis(allocator, payload, third_block_header_truncated);
        checked += 1;

        const third_block_payload_truncated = try nthBlockPayloadTruncatedFrame(frame, 2);
        try expectError(error.TruncatedFrame, vort.zstdSummarizeNativeStream(third_block_payload_truncated));
        try expectError(error.TruncatedFrame, vort.zstdSummarizeNativeFrameBlocks(third_block_payload_truncated));
        try expectError(error.TruncatedFrame, vort.zstdDecodedNativeFrameSizeLimited(third_block_payload_truncated, payload.len));
        try expectError(error.TruncatedFrame, vort.zstdDecodeNativeFrameInto(third_block_payload_truncated, into));
        try expectAllocError(allocator, error.TruncatedFrame, vort.zstdDecodeNativeFrameAllocLimited(allocator, third_block_payload_truncated, payload.len));
        try expectError(error.TruncatedFrame, reusable.decodedSizeLimited(third_block_payload_truncated, payload.len));
        try expectError(error.TruncatedFrame, reusable.decodeIntoSlice(third_block_payload_truncated, into));
        try checkTruncatedLibZstdGeneratedIncrementalApis(allocator, payload, third_block_payload_truncated);
        try checkTruncatedLibZstdGeneratedChunkedApis(allocator, payload, third_block_payload_truncated);
        checked += 1;
    }

    return checked;
}

fn checkTruncatedLibZstdGeneratedTailApis(allocator: std.mem.Allocator, payload: []const u8, truncated: []const u8) !void {
    try expectError(error.TruncatedFrame, vort.zstdSummarizeNativeStream(truncated));
    if (vort.zstdSummarizeNativeFrameBlocks(truncated)) |_| {
        // A checksum-only tail truncation leaves every block payload complete,
        // so the block-level inspector may still succeed. Full-frame APIs below
        // must still reject the frame because the advertised checksum is short.
    } else |err| if (err != error.TruncatedFrame) return err;
    try expectError(error.TruncatedFrame, vort.zstdDecodedNativeFrameSizeLimited(truncated, payload.len));

    const into = try allocator.alloc(u8, payload.len);
    defer allocator.free(into);
    try expectError(error.TruncatedFrame, vort.zstdDecodeNativeFrameInto(truncated, into));
    try expectError(error.TruncatedFrame, vort.zstdDecodeNativeFrameIntoExactSize(truncated, into, payload.len));
    try expectAllocError(allocator, error.TruncatedFrame, vort.zstdDecodeNativeFrameAllocLimited(allocator, truncated, payload.len));

    var reusable = vort.ZstdNativeFrameDecoder.init(allocator);
    defer reusable.deinit();
    try expectError(error.TruncatedFrame, reusable.decodedSizeLimited(truncated, payload.len));
    try expectError(error.TruncatedFrame, reusable.decodeIntoSlice(truncated, into));
    try expectAllocError(allocator, error.TruncatedFrame, reusable.decodeAlloc(truncated));

    try checkTruncatedLibZstdGeneratedIncrementalApis(allocator, payload, truncated);
    try checkTruncatedLibZstdGeneratedChunkedApis(allocator, payload, truncated);
}

fn checkTruncatedLibZstdGeneratedIncrementalApis(allocator: std.mem.Allocator, payload: []const u8, truncated: []const u8) !void {
    var decoder = vort.ZstdNativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();

    const output = try allocator.alloc(u8, payload.len);
    defer allocator.free(output);
    const result = try decoder.step(truncated, output[0..0]);
    try expect(result.status == .need_input);
    try expect(result.progress.input_read == truncated.len);
    try expect(result.progress.output_written == 0);
    try expectError(error.TruncatedFrame, decoder.finish());
}

fn checkCorruptChecksumLibZstdGeneratedFrameApis(allocator: std.mem.Allocator, payload: []const u8, frame: []const u8) !usize {
    // Unlike the truncation fixtures, this keeps the libzstd frame structurally
    // complete and corrupts only the checksum trailer. Size preflight should
    // still succeed, while all decode facades must reject the final content
    // verification step with ChecksumMismatch.
    if (frame.len < 4) return error.ZstdNativeFrameProbeMismatch;
    var corrupt = try allocator.dupe(u8, frame);
    defer allocator.free(corrupt);
    corrupt[corrupt.len - 1] ^= 0x01;

    try expect((try vort.zstdDecodedNativeFrameSizeLimited(corrupt, payload.len)) == payload.len);
    try expectError(error.OutputLimitExceeded, vort.zstdDecodedNativeFrameSizeLimited(corrupt, payload.len - 1));
    const summary = try vort.zstdSummarizeNativeStream(corrupt);
    try expect(summary.frame_count == 1);
    try expect(summary.block_count >= 2);

    const into = try allocator.alloc(u8, payload.len);
    defer allocator.free(into);
    try expectError(error.ChecksumMismatch, vort.zstdDecodeNativeFrameInto(corrupt, into));
    try expectError(error.ChecksumMismatch, vort.zstdDecodeNativeFrameIntoExactSize(corrupt, into, payload.len));
    try expectAllocError(allocator, error.ChecksumMismatch, vort.zstdDecodeNativeFrameAllocLimited(allocator, corrupt, payload.len));

    var reusable = vort.ZstdNativeFrameDecoder.init(allocator);
    defer reusable.deinit();
    try expect((try reusable.decodedSizeLimited(corrupt, payload.len)) == payload.len);
    try expectError(error.ChecksumMismatch, reusable.decodeIntoSlice(corrupt, into));
    try expectAllocError(allocator, error.ChecksumMismatch, reusable.decodeAlloc(corrupt));

    try checkCorruptChecksumLibZstdGeneratedIncrementalApis(allocator, payload, corrupt);
    try checkCorruptChecksumLibZstdGeneratedChunkedApis(allocator, payload, corrupt);

    var corrupt_then_truncated = try allocator.dupe(u8, frame[0 .. frame.len - 1]);
    defer allocator.free(corrupt_then_truncated);
    corrupt_then_truncated[corrupt_then_truncated.len - 1] ^= 0x01;
    // The checksum bytes seen so far are already wrong, but the checksum field
    // itself is incomplete. Every full-frame facade should report truncation
    // before attempting checksum comparison.
    try checkTruncatedLibZstdGeneratedTailApis(allocator, payload, corrupt_then_truncated);
    return 2;
}

fn checkCorruptChecksumLibZstdGeneratedIncrementalApis(allocator: std.mem.Allocator, payload: []const u8, frame: []const u8) !void {
    var decoder = vort.ZstdNativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();

    const output = try allocator.alloc(u8, payload.len);
    defer allocator.free(output);
    const initial = decoder.step(frame, output[0..0]) catch |err| {
        if (err != error.ChecksumMismatch) return err;
        return;
    };
    try expect(initial.status == .need_output);
    try expect(initial.progress.input_read == frame.len);
    var written: usize = 0;
    var result: vort.StepResult = initial;
    while (result.status == .need_output) {
        const end = @min(output.len, written + 4096);
        result = decoder.step("", output[written..end]) catch |err| {
            if (err != error.ChecksumMismatch) return err;
            return;
        };
        written += result.progress.output_written;
    }
    try expect(result.status == .done);
    try expect(written == payload.len);
    try expectEqualSlices(payload, output);
    try expectError(error.ChecksumMismatch, decoder.finish());
}

fn checkCorruptChecksumLibZstdGeneratedChunkedApis(allocator: std.mem.Allocator, payload: []const u8, frame: []const u8) !void {
    const split_a: usize = @min(frame.len, 5);
    const split_b: usize = @min(frame.len, split_a + 19);
    const chunks = [_][]const u8{
        frame[0..split_a],
        frame[split_a..split_b],
        frame[split_b..],
    };
    const join = try allocator.alloc(u8, frame.len);
    defer allocator.free(join);

    try expect((try vort.zstdDecodedNativeFrameChunksSizeLimited(&chunks, join, payload.len)) == payload.len);
    try expectAllocError(allocator, error.ChecksumMismatch, vort.zstdDecodeNativeFrameChunksAllocLimited(allocator, &chunks, join, payload.len));

    const into = try allocator.alloc(u8, payload.len);
    defer allocator.free(into);
    try expectError(error.ChecksumMismatch, vort.zstdDecodeNativeFrameChunksInto(&chunks, join, into));
    try expectError(error.ChecksumMismatch, vort.zstdDecodeNativeFrameChunksIntoExactSize(&chunks, join, into, payload.len));

    var decoder = vort.ZstdNativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    try expect((try decoder.decodedChunksSizeLimited(&chunks, join, payload.len)) == payload.len);
    try expectAllocError(allocator, error.ChecksumMismatch, decoder.decodeChunksAllocLimited(&chunks, join, payload.len));
    try expectError(error.ChecksumMismatch, decoder.decodeChunksIntoSlice(&chunks, join, into));
    try expectError(error.ChecksumMismatch, decoder.decodeChunksIntoSliceExactSize(&chunks, join, into, payload.len));
}

fn checkTruncatedLibZstdGeneratedChunkedApis(allocator: std.mem.Allocator, payload: []const u8, truncated: []const u8) !void {
    const split_a: usize = @min(truncated.len, 5);
    const split_b: usize = @min(truncated.len, split_a + 19);
    const chunks = [_][]const u8{
        truncated[0..split_a],
        truncated[split_a..split_b],
        truncated[split_b..],
    };
    const join = try allocator.alloc(u8, truncated.len);
    defer allocator.free(join);

    try expectError(error.TruncatedFrame, vort.zstdDecodedNativeFrameChunksSize(&chunks, join));
    try expectError(error.TruncatedFrame, vort.zstdDecodedNativeFrameChunksSizeLimited(&chunks, join, payload.len));
    try expectAllocError(allocator, error.TruncatedFrame, vort.zstdDecodeNativeFrameChunksAllocLimited(allocator, &chunks, join, payload.len));

    const into = try allocator.alloc(u8, payload.len);
    defer allocator.free(into);
    try expectError(error.TruncatedFrame, vort.zstdDecodeNativeFrameChunksInto(&chunks, join, into));
    try expectError(error.TruncatedFrame, vort.zstdDecodeNativeFrameChunksIntoExactSize(&chunks, join, into, payload.len));

    var decoder = vort.ZstdNativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    try expectError(error.TruncatedFrame, decoder.decodedChunksSize(&chunks, join));
    try expectError(error.TruncatedFrame, decoder.decodedChunksSizeLimited(&chunks, join, payload.len));
    try expectAllocError(allocator, error.TruncatedFrame, decoder.decodeChunksAllocLimited(&chunks, join, payload.len));
    try expectError(error.TruncatedFrame, decoder.decodeChunksIntoSlice(&chunks, join, into));
    try expectError(error.TruncatedFrame, decoder.decodeChunksIntoSliceExactSize(&chunks, join, into, payload.len));
}

fn firstBlockPayloadTruncatedFrame(frame: []const u8) ![]const u8 {
    const first_block = try vort.zstdInspectNativeFrameFirstBlock(frame);
    if (first_block.last or first_block.payload_len == 0) return error.ZstdNativeFrameProbeMismatch;
    return frame[0 .. first_block.payload_offset + first_block.payload_len - 1];
}

fn secondBlockHeaderTruncatedFrame(frame: []const u8) ![]const u8 {
    // Keep the first block complete, then expose only two bytes of the next
    // three-byte block header. This stresses the frame/block walker transition
    // between blocks, distinct from payload-tail and first-payload truncation.
    return try nthBlockHeaderTruncatedFrame(frame, 1);
}

fn secondBlockPayloadTruncatedFrame(frame: []const u8) ![]const u8 {
    return try nthBlockPayloadTruncatedFrame(frame, 1);
}

fn nthBlock(frame: []const u8, index: usize) !vort.ZstdNativeFrameBlockHeader {
    const first_block = try vort.zstdInspectNativeFrameFirstBlock(frame);
    if (index == 0) return first_block;
    var block = first_block;
    for (0..index) |_| {
        if (block.last) return error.ZstdNativeFrameProbeMismatch;
        block = try vort.zstdInspectNativeFrameBlockAt(frame, block.next_header_offset);
    }
    return block;
}

fn nthBlockHeaderTruncatedFrame(frame: []const u8, index: usize) ![]const u8 {
    const previous = try nthBlock(frame, index - 1);
    if (previous.last) return error.ZstdNativeFrameProbeMismatch;
    return frame[0 .. previous.next_header_offset + 2];
}

fn nthBlockPayloadTruncatedFrame(frame: []const u8, index: usize) ![]const u8 {
    const block = try nthBlock(frame, index);
    if (block.payload_len == 0) return error.ZstdNativeFrameProbeMismatch;
    return frame[0 .. block.payload_offset + block.payload_len - 1];
}

fn checkChunkedFrameLibraryApis(allocator: std.mem.Allocator, payload: []const u8, frame: []const u8) !void {
    const split_a: usize = @min(frame.len, 5);
    const split_b: usize = @min(frame.len, split_a + 19);
    const chunks = [_][]const u8{
        frame[0..split_a],
        frame[split_a..split_b],
        frame[split_b..],
    };
    const join = try allocator.alloc(u8, frame.len);
    defer allocator.free(join);

    try expect((try vort.zstdDecodedNativeFrameChunksSize(&chunks, join)) == payload.len);
    try expect((try vort.zstdDecodedNativeFrameChunksSizeLimited(&chunks, join, payload.len)) == payload.len);
    try expectError(error.OutputLimitExceeded, vort.zstdDecodedNativeFrameChunksSizeLimited(&chunks, join, payload.len - 1));

    const decoded = try vort.zstdDecodeNativeFrameChunksAllocLimited(allocator, &chunks, join, payload.len);
    defer allocator.free(decoded);
    try expectEqualSlices(payload, decoded);
    try expectAllocError(allocator, error.OutputLimitExceeded, vort.zstdDecodeNativeFrameChunksAllocLimited(allocator, &chunks, join, payload.len - 1));

    const into = try allocator.alloc(u8, payload.len);
    defer allocator.free(into);
    const written = try vort.zstdDecodeNativeFrameChunksInto(&chunks, join, into);
    try expect(written == payload.len);
    try expectEqualSlices(payload, into[0..written]);
    const exact_written = try vort.zstdDecodeNativeFrameChunksIntoExactSize(&chunks, join, into, payload.len);
    try expect(exact_written == payload.len);
    try expectEqualSlices(payload, into[0..exact_written]);
    try expectError(error.OutputTooSmall, vort.zstdDecodeNativeFrameChunksInto(&chunks, join, into[0 .. into.len - 1]));
    try expectError(error.OutputTooSmall, vort.zstdDecodeNativeFrameChunksIntoExactSize(&chunks, join, into[0 .. into.len - 1], payload.len));
    if (payload.len != 0) try expectError(error.SizeMismatch, vort.zstdDecodeNativeFrameChunksIntoExactSize(&chunks, join, into, payload.len - 1));
    const oversized_into = try allocator.alloc(u8, payload.len + 1);
    defer allocator.free(oversized_into);
    try expectError(error.SizeMismatch, vort.zstdDecodeNativeFrameChunksIntoExactSize(&chunks, join, oversized_into, payload.len + 1));

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    const appended_written = try vort.zstdDecodeNativeFrameChunksAppendExactSize(allocator, &appended, &chunks, join, payload.len);
    try expect(appended_written == payload.len);
    try expectPrefixedPayload(appended.items, payload);
    appended.clearRetainingCapacity();
    try expectError(error.SizeMismatch, vort.zstdDecodeNativeFrameChunksAppendExactSize(allocator, &appended, &chunks, join, payload.len - 1));
    try expectError(error.SizeMismatch, vort.zstdDecodeNativeFrameChunksAppendExactSize(allocator, &appended, &chunks, join, payload.len + 1));

    var decoder = vort.ZstdNativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    try expect((try decoder.decodedChunksSize(&chunks, join)) == payload.len);
    try expect((try decoder.decodedChunksSizeLimited(&chunks, join, payload.len)) == payload.len);
    try expectError(error.OutputLimitExceeded, decoder.decodedChunksSizeLimited(&chunks, join, payload.len - 1));

    const reusable_decoded = try decoder.decodeChunksAllocLimited(&chunks, join, payload.len);
    defer allocator.free(reusable_decoded);
    try expectEqualSlices(payload, reusable_decoded);
    try expectAllocError(allocator, error.OutputLimitExceeded, decoder.decodeChunksAllocLimited(&chunks, join, payload.len - 1));

    const scratch = try decoder.decodeChunksScratchLimited(&chunks, join, payload.len);
    try expectEqualSlices(payload, scratch);
    try expectError(error.OutputLimitExceeded, decoder.decodeChunksScratchLimited(&chunks, join, payload.len - 1));
    const reusable_exact_written = try decoder.decodeChunksIntoSliceExactSize(&chunks, join, into, payload.len);
    try expect(reusable_exact_written == payload.len);
    try expectEqualSlices(payload, into[0..reusable_exact_written]);
    try expectError(error.OutputTooSmall, decoder.decodeChunksIntoSliceExactSize(&chunks, join, into[0 .. into.len - 1], payload.len));
    if (payload.len != 0) try expectError(error.SizeMismatch, decoder.decodeChunksIntoSliceExactSize(&chunks, join, into, payload.len - 1));

    const reusable_into = try allocator.alloc(u8, payload.len);
    defer allocator.free(reusable_into);
    const reusable_written = try decoder.decodeChunksIntoSlice(&chunks, join, reusable_into);
    try expect(reusable_written == payload.len);
    try expectEqualSlices(payload, reusable_into[0..reusable_written]);
    try expectError(error.OutputTooSmall, decoder.decodeChunksIntoSlice(&chunks, join, reusable_into[0 .. reusable_into.len - 1]));

    var reusable_appended: std.ArrayList(u8) = .empty;
    defer reusable_appended.deinit(allocator);
    try reusable_appended.appendSlice(allocator, "prefix:");
    const reusable_appended_written = try decoder.decodeChunksAppendExactSize(&reusable_appended, &chunks, join, payload.len);
    try expect(reusable_appended_written == payload.len);
    try expectPrefixedPayload(reusable_appended.items, payload);
    reusable_appended.clearRetainingCapacity();
    try expectError(error.SizeMismatch, decoder.decodeChunksAppendExactSize(&reusable_appended, &chunks, join, payload.len - 1));
    try expectError(error.SizeMismatch, decoder.decodeChunksAppendExactSize(&reusable_appended, &chunks, join, payload.len + 1));
}

fn checkSplitHeaderIncremental(allocator: std.mem.Allocator) !void {
    const payload = "split-header-zstd-native";
    const encoded = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, payload, .{
        .selection = .literal_only,
        .content_checksum = false,
    });
    defer allocator.free(encoded.frame);

    var decoder = vort.ZstdNativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    const partial = try decoder.step(encoded.frame[0..2], output[0..0]);
    try expect(partial.status == .need_input);
    try expect(partial.progress.input_read == 2);
    try expect(partial.progress.output_written == 0);
    try expectEqualSlices("frame", decoder.diagnostics().phase_name);

    const done = try decoder.step(encoded.frame[2..], &output);
    try expect(done.status == .done);
    try expectEqualSlices(payload, &output);
    try decoder.finish();
}

fn checkSplitSkippableHeaderIncremental(allocator: std.mem.Allocator) !void {
    const skip = try vort.zstdEncodeSkippableFrameAlloc(allocator, 7, "split-skip-zstd-metadata");
    defer allocator.free(skip);
    const payload = "split-skippable-header-zstd-native";
    const encoded = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, payload, .{
        .selection = .literal_only,
        .content_checksum = false,
    });
    defer allocator.free(encoded.frame);
    const tail = try std.mem.concat(allocator, u8, &.{ skip[5..], encoded.frame });
    defer allocator.free(tail);

    var decoder = vort.ZstdNativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;

    // Five bytes include the skippable magic plus one byte of the length field;
    // callers can split arbitrary transport chunks here, so the decoder should
    // remain in the frame phase and wait for the rest of the skippable header.
    const partial = try decoder.step(skip[0..5], output[0..0]);
    try expect(partial.status == .need_input);
    try expect(partial.progress.input_read == 5);
    try expect(partial.progress.output_written == 0);
    try expectEqualSlices("frame", decoder.diagnostics().phase_name);

    const done = try decoder.step(tail, &output);
    try expect(done.status == .done);
    try expect(done.progress.input_read == tail.len);
    try expect(done.progress.output_written == payload.len);
    try expectEqualSlices(payload, &output);
    try decoder.finish();
}

fn checkSkippableOnlyStream(allocator: std.mem.Allocator) !void {
    const expected_len = try vort.zstdEncodedSkippableFrameBound("metadata-only-zstd".len);
    const skip = try vort.zstdEncodeSkippableFrameAlloc(allocator, 9, "metadata-only-zstd");
    defer allocator.free(skip);
    try expect(skip.len == expected_len);

    var into: [64]u8 = undefined;
    const into_written = try vort.zstdEncodeSkippableFrameIntoSlice(9, "metadata-only-zstd", &into);
    try expect(into_written == skip.len);
    try expectEqualSlices(skip, into[0..into_written]);
    try expectError(error.OutputTooSmall, vort.zstdEncodeSkippableFrameIntoSlice(9, "metadata-only-zstd", into[0 .. into_written - 1]));

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    try vort.zstdEncodeSkippableFrameAppend(allocator, &appended, 9, "metadata-only-zstd");
    try expectEqualSlices("prefix:", appended.items[0.."prefix:".len]);
    try expectEqualSlices(skip, appended.items["prefix:".len..]);

    const decoded = try vort.zstdDecodeNativeConcatenatedFrameAlloc(allocator, skip);
    defer allocator.free(decoded);
    try expect(decoded.len == 0);
    const exact = try vort.zstdDecodeNativeConcatenatedFrameAllocExactSize(allocator, skip, 0);
    defer allocator.free(exact);
    try expect(exact.len == 0);
    try expectError(error.SizeMismatch, vort.zstdDecodeNativeConcatenatedFrameAllocExactSize(allocator, skip, 1));
    try expect((try vort.zstdDecodedNativeConcatenatedFrameSize(skip)) == 0);
    try expect((try vort.zstdDecodedNativeConcatenatedFrameSizeLimited(skip, 0)) == 0);

    const summary = try vort.zstdSummarizeNativeStream(skip);
    try expect(summary.frame_count == 0);
    try expect(summary.skippable_frame_count == 1);
    try expect(summary.skippable_payload_bytes == "metadata-only-zstd".len);

    var iterator = vort.zstdIterateNativeStream(skip);
    const element = (try iterator.next()) orelse return error.ZstdNativeFrameProbeMismatch;
    switch (element) {
        .frame => return error.ZstdNativeFrameProbeMismatch,
        .skippable => |skippable| {
            try expect(skippable.header.skippable_id == 9);
            try expectEqualSlices("metadata-only-zstd", skippable.payload);
        },
    }
    if ((try iterator.next()) != null) return error.ZstdNativeFrameProbeMismatch;
}

fn checkHandcraftedFrameValidation(allocator: std.mem.Allocator) !usize {
    var checked: usize = 0;

    const no_size_payload = "nosize-limit";
    const no_size_frame = try handcraftedRawFrame(allocator, no_size_payload.len, no_size_payload, "", false);
    defer allocator.free(no_size_frame);
    const no_size_header = try vort.zstdInspectNativeFrameHeader(no_size_frame);
    try expect(no_size_header.content_size == null);
    try expect((try vort.zstdDecodedNativeFrameSizeLimited(no_size_frame, no_size_payload.len)) == no_size_payload.len);
    try expectError(error.OutputLimitExceeded, vort.zstdDecodedNativeFrameSizeLimited(no_size_frame, no_size_payload.len - 1));
    const no_size_limited = try vort.zstdDecodeNativeFrameAllocLimited(allocator, no_size_frame, no_size_payload.len);
    defer allocator.free(no_size_limited);
    try expectEqualSlices(no_size_payload, no_size_limited);
    try expectAllocError(allocator, error.OutputLimitExceeded, vort.zstdDecodeNativeFrameAllocLimited(allocator, no_size_frame, no_size_payload.len - 1));
    var no_size_into: [no_size_payload.len]u8 = undefined;
    try expect((try vort.zstdDecodeNativeFrameInto(no_size_frame, &no_size_into)) == no_size_payload.len);
    try expectEqualSlices(no_size_payload, &no_size_into);
    try expectError(error.OutputTooSmall, vort.zstdDecodeNativeFrameInto(no_size_frame, no_size_into[0 .. no_size_into.len - 1]));
    checked += 1;

    const no_size_multi_block = [_]u8{
        0x28, 0xb5, 0x2f, 0xfd,
        0x00, // No content size; window descriptor follows.
        0x00, // 1 KiB window.
        0x10, 0x00, 0x00, // Non-final raw block with two payload bytes.
        'a',  'b',
        0x19, 0x00, 0x00, // Final raw block with three more bytes.
        'c',  'd',  'e',
    };
    const no_size_multi_header = try vort.zstdInspectNativeFrameHeader(&no_size_multi_block);
    try expect(no_size_multi_header.content_size == null);
    const no_size_multi_summary = try vort.zstdSummarizeNativeFrameBlocks(&no_size_multi_block);
    try expect(no_size_multi_summary.block_count == 2);
    try expect(no_size_multi_summary.payload_bytes == 5);
    try expect((try vort.zstdDecodedNativeFrameSizeLimited(&no_size_multi_block, 5)) == 5);
    try expectError(error.OutputLimitExceeded, vort.zstdDecodedNativeFrameSizeLimited(&no_size_multi_block, 4));
    const no_size_multi_limited = try vort.zstdDecodeNativeFrameAllocLimited(allocator, &no_size_multi_block, 5);
    defer allocator.free(no_size_multi_limited);
    try expectEqualSlices("abcde", no_size_multi_limited);
    try expectAllocError(allocator, error.OutputLimitExceeded, vort.zstdDecodeNativeFrameAllocLimited(allocator, &no_size_multi_block, 4));
    var no_size_multi_into: [5]u8 = undefined;
    try expect((try vort.zstdDecodeNativeFrameInto(&no_size_multi_block, &no_size_multi_into)) == 5);
    try expectEqualSlices("abcde", &no_size_multi_into);
    try expectError(error.OutputTooSmall, vort.zstdDecodeNativeFrameInto(&no_size_multi_block, no_size_multi_into[0..4]));
    checked += 1;

    const no_size_multi_checksum_mismatch = [_]u8{
        0x28, 0xb5, 0x2f, 0xfd,
        0x04, // No content size, checksum present; window descriptor follows.
        0x00, // 1 KiB window.
        0x10, 0x00, 0x00, // Non-final raw block with two payload bytes.
        'a',  'b',
        0x19, 0x00, 0x00, // Final raw block with three more bytes.
        'c',  'd',  'e',
        0x00, 0x00, 0x00, 0x00, // Wrong checksum for "abcde".
    };
    const no_size_multi_checksum_summary = try vort.zstdSummarizeNativeStream(&no_size_multi_checksum_mismatch);
    try expect(no_size_multi_checksum_summary.frame_count == 1);
    try expect(no_size_multi_checksum_summary.block_count == 2);
    try expect((try vort.zstdDecodedNativeFrameSizeLimited(&no_size_multi_checksum_mismatch, 5)) == 5);
    try expectError(error.OutputLimitExceeded, vort.zstdDecodedNativeFrameSizeLimited(&no_size_multi_checksum_mismatch, 4));
    var no_size_multi_checksum_into: [5]u8 = undefined;
    try expectError(error.ChecksumMismatch, vort.zstdDecodeNativeFrameInto(&no_size_multi_checksum_mismatch, &no_size_multi_checksum_into));
    try expectAllocError(allocator, error.ChecksumMismatch, vort.zstdDecodeNativeFrameAllocLimited(allocator, &no_size_multi_checksum_mismatch, 5));
    try expectAllocError(allocator, error.OutputLimitExceeded, vort.zstdDecodeNativeFrameAllocLimited(allocator, &no_size_multi_checksum_mismatch, 4));
    checked += 1;

    const no_size_multi_truncated_checksum = [_]u8{
        0x28, 0xb5, 0x2f, 0xfd,
        0x04, // No content size, checksum present; window descriptor follows.
        0x00, // 1 KiB window.
        0x10, 0x00, 0x00, // Non-final raw block with two payload bytes.
        'a',  'b',
        0x19, 0x00, 0x00, // Final raw block with three more bytes.
        'c',  'd',  'e',
        0x00, 0x00, // Checksum field is present but truncated.
    };
    try expectError(error.TruncatedFrame, vort.zstdDecodedNativeFrameSizeLimited(&no_size_multi_truncated_checksum, 5));
    var no_size_multi_truncated_into: [5]u8 = undefined;
    try expectError(error.TruncatedFrame, vort.zstdDecodeNativeFrameInto(&no_size_multi_truncated_checksum, &no_size_multi_truncated_into));
    try expectAllocError(allocator, error.TruncatedFrame, vort.zstdDecodeNativeFrameAllocLimited(allocator, &no_size_multi_truncated_checksum, 5));
    try expectError(error.OutputLimitExceeded, vort.zstdDecodedNativeFrameSizeLimited(&no_size_multi_truncated_checksum, 4));
    try expectAllocError(allocator, error.OutputLimitExceeded, vort.zstdDecodeNativeFrameAllocLimited(allocator, &no_size_multi_truncated_checksum, 4));
    try expectError(error.TruncatedFrame, vort.zstdSummarizeNativeStream(&no_size_multi_truncated_checksum));
    try expectStreamIteratorError(&no_size_multi_truncated_checksum, error.TruncatedFrame);
    checked += 1;

    const checksum_payload = "zstd-checksum";
    var wrong_checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &wrong_checksum, @as(u32, @truncate(std.hash.XxHash64.hash(0, checksum_payload))) ^ 0x01, .little);
    const checksum_mismatch = try handcraftedRawFrame(allocator, checksum_payload.len, checksum_payload, &wrong_checksum, true);
    defer allocator.free(checksum_mismatch);
    try expect((try vort.zstdDecodedNativeFrameSize(checksum_mismatch)) == checksum_payload.len);
    var checksum_out: [checksum_payload.len]u8 = undefined;
    try expectError(error.ChecksumMismatch, vort.zstdDecodeNativeFrameInto(checksum_mismatch, &checksum_out));
    try expectAllocError(allocator, error.ChecksumMismatch, vort.zstdDecodeNativeFrameAlloc(allocator, checksum_mismatch));
    const checksum_summary = try vort.zstdSummarizeNativeStream(checksum_mismatch);
    try expect(checksum_summary.frame_count == 1);
    try expect(checksum_summary.raw_block_count == 1);
    checked += 1;

    const truncated_checksum = try handcraftedRawFrame(allocator, checksum_payload.len, checksum_payload, "\x00\x00", true);
    defer allocator.free(truncated_checksum);
    try expectError(error.TruncatedFrame, vort.zstdDecodedNativeFrameSize(truncated_checksum));
    try expectError(error.TruncatedFrame, vort.zstdDecodeNativeFrameInto(truncated_checksum, &checksum_out));
    try expectAllocError(allocator, error.TruncatedFrame, vort.zstdDecodeNativeFrameAlloc(allocator, truncated_checksum));
    try expectError(error.TruncatedFrame, vort.zstdSummarizeNativeStream(truncated_checksum));
    try expectStreamIteratorError(truncated_checksum, error.TruncatedFrame);
    checked += 1;

    const truncated_payload = try handcraftedRawFrame(allocator, 4, "ab", "", false);
    defer allocator.free(truncated_payload);
    _ = try vort.zstdInspectNativeFrameHeader(truncated_payload);
    try expectError(error.TruncatedFrame, vort.zstdDecodedNativeFrameSize(truncated_payload));
    var payload_out: [4]u8 = undefined;
    try expectError(error.TruncatedFrame, vort.zstdDecodeNativeFrameInto(truncated_payload, &payload_out));
    try expectAllocError(allocator, error.TruncatedFrame, vort.zstdDecodeNativeFrameAlloc(allocator, truncated_payload));
    try expectError(error.TruncatedFrame, vort.zstdSummarizeNativeStream(truncated_payload));
    try expectStreamIteratorError(truncated_payload, error.TruncatedFrame);
    checked += 1;

    const content_size_mismatch = [_]u8{
        0x28, 0xb5, 0x2f, 0xfd,
        0x20, // single-segment, one-byte content size.
        0x05, // Advertise five decoded bytes.
        0x21, 0x00, 0x00, // Last raw block with only four payload bytes.
        'a',  'b',  'c',
        'd',
    };
    const mismatch_header = try vort.zstdInspectNativeFrameHeader(&content_size_mismatch);
    try expect(mismatch_header.content_size.? == 5);
    const mismatch_block = try vort.zstdInspectNativeFrameFirstBlock(&content_size_mismatch);
    try expect(mismatch_block.block_type == .raw);
    try expect(mismatch_block.payload_len == 4);
    const mismatch_summary = try vort.zstdSummarizeNativeFrameBlocks(&content_size_mismatch);
    try expect(mismatch_summary.raw_block_count == 1);
    try expectError(error.SizeMismatch, vort.zstdDecodedNativeFrameSize(&content_size_mismatch));
    var mismatch_output: [5]u8 = undefined;
    try expectError(error.SizeMismatch, vort.zstdDecodeNativeFrameInto(&content_size_mismatch, &mismatch_output));
    try expectAllocError(allocator, error.SizeMismatch, vort.zstdDecodeNativeFrameAlloc(allocator, &content_size_mismatch));
    checked += 1;

    const content_size_mismatch_with_checksum = [_]u8{
        0x28, 0xb5, 0x2f, 0xfd,
        0x24, // single-segment, checksum present, one-byte content size.
        0x05, // Advertise five decoded bytes.
        0x21, 0x00, 0x00, // Last raw block with only four payload bytes.
        'a',  'b',  'c',
        'd',
        0x00, 0x00, 0x00, 0x00, // Also wrong, but SizeMismatch is diagnosed first.
    };
    try expectError(error.SizeMismatch, vort.zstdDecodedNativeFrameSize(&content_size_mismatch_with_checksum));
    var mismatch_checksum_output: [5]u8 = undefined;
    try expectError(error.SizeMismatch, vort.zstdDecodeNativeFrameInto(&content_size_mismatch_with_checksum, &mismatch_checksum_output));
    try expectAllocError(allocator, error.SizeMismatch, vort.zstdDecodeNativeFrameAlloc(allocator, &content_size_mismatch_with_checksum));
    checked += 1;

    const multi_block_size_mismatch = [_]u8{
        0x28, 0xb5, 0x2f, 0xfd,
        0x20, // single-segment, one-byte content size.
        0x07, // Advertise seven decoded bytes across the frame.
        0x10, 0x00, 0x00, // Non-final raw block with two payload bytes.
        'a',  'b',
        0x19, 0x00, 0x00, // Final raw block with three more bytes.
        'c',  'd',  'e',
    };
    const multi_summary = try vort.zstdSummarizeNativeFrameBlocks(&multi_block_size_mismatch);
    try expect(multi_summary.block_count == 2);
    try expect(multi_summary.raw_block_count == 2);
    try expect(multi_summary.payload_bytes == 5);
    try expectError(error.SizeMismatch, vort.zstdDecodedNativeFrameSize(&multi_block_size_mismatch));
    var multi_mismatch_output: [7]u8 = undefined;
    try expectError(error.SizeMismatch, vort.zstdDecodeNativeFrameInto(&multi_block_size_mismatch, &multi_mismatch_output));
    try expectAllocError(allocator, error.SizeMismatch, vort.zstdDecodeNativeFrameAlloc(allocator, &multi_block_size_mismatch));
    checked += 1;

    const multi_block_checksum_mismatch = [_]u8{
        0x28, 0xb5, 0x2f, 0xfd,
        0x24, // single-segment, checksum present, one-byte content size.
        0x05,
        0x10, 0x00, 0x00, // Non-final raw block with two payload bytes.
        'a',  'b',
        0x19, 0x00, 0x00, // Final raw block with three more bytes.
        'c',  'd',  'e',
        0x00, 0x00, 0x00, 0x00, // Wrong checksum for the five decoded bytes.
    };
    const multi_checksum_summary = try vort.zstdSummarizeNativeStream(&multi_block_checksum_mismatch);
    try expect(multi_checksum_summary.frame_count == 1);
    try expect(multi_checksum_summary.block_count == 2);
    try expect(multi_checksum_summary.raw_block_count == 2);
    try expect((try vort.zstdDecodedNativeFrameSize(&multi_block_checksum_mismatch)) == 5);
    var multi_checksum_output: [5]u8 = undefined;
    try expectError(error.ChecksumMismatch, vort.zstdDecodeNativeFrameInto(&multi_block_checksum_mismatch, &multi_checksum_output));
    try expectAllocError(allocator, error.ChecksumMismatch, vort.zstdDecodeNativeFrameAlloc(allocator, &multi_block_checksum_mismatch));
    checked += 1;

    const multi_block_truncated_checksum = [_]u8{
        0x28, 0xb5, 0x2f, 0xfd,
        0x24, // single-segment, checksum present, one-byte content size.
        0x05,
        0x10, 0x00, 0x00, // Non-final raw block with two payload bytes.
        'a',  'b',
        0x19, 0x00, 0x00, // Final raw block with three more bytes.
        'c',  'd',  'e',
        0x00, 0x00, // Checksum field is present but truncated.
    };
    try expectError(error.TruncatedFrame, vort.zstdDecodedNativeFrameSize(&multi_block_truncated_checksum));
    var multi_truncated_checksum_output: [5]u8 = undefined;
    try expectError(error.TruncatedFrame, vort.zstdDecodeNativeFrameInto(&multi_block_truncated_checksum, &multi_truncated_checksum_output));
    try expectAllocError(allocator, error.TruncatedFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &multi_block_truncated_checksum));
    try expectError(error.TruncatedFrame, vort.zstdSummarizeNativeStream(&multi_block_truncated_checksum));
    try expectStreamIteratorError(&multi_block_truncated_checksum, error.TruncatedFrame);
    checked += 1;

    const reserved_block_type = [_]u8{
        0x28, 0xb5, 0x2f, 0xfd,
        0x20, // single-segment, no checksum, one-byte content size.
        0x00,
        0x07, 0x00, 0x00, // last block, reserved block type 3.
    };
    try expectError(error.CorruptFrame, vort.zstdInspectNativeFrameFirstBlock(&reserved_block_type));
    try expectNativeStreamOnlyError(allocator, &reserved_block_type, error.CorruptFrame);
    checked += 1;

    const zero_rle_block = [_]u8{
        0x28, 0xb5, 0x2f, 0xfd,
        0x20, // single-segment, no checksum, one-byte content size.
        0x08,
        0x03, 0x00, 0x00, // last RLE block with decoded size 0 is invalid.
    };
    try expectError(error.TruncatedFrame, vort.zstdInspectNativeFrameFirstBlock(&zero_rle_block));
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(&zero_rle_block));
    var zero_rle_output: [8]u8 = undefined;
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(&zero_rle_block, &zero_rle_output));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &zero_rle_block));
    checked += 1;

    const oversized_raw_block = [_]u8{
        0x28, 0xb5, 0x2f, 0xfd,
        0x20, // single-segment, no checksum, one-byte content size.
        0x00,
        0x00, 0x08, 0x00, // raw block size exceeds the advertised block/window limit.
    };
    try expectError(error.CorruptFrame, vort.zstdInspectNativeFrameFirstBlock(&oversized_raw_block));
    try expectNativeStreamOnlyError(allocator, &oversized_raw_block, error.CorruptFrame);
    checked += 1;

    const repeat_without_previous_hex = "28b52ffd20042d0000096101fc01";
    var repeat_without_previous: [repeat_without_previous_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&repeat_without_previous, repeat_without_previous_hex);
    const repeat_block = try vort.zstdInspectNativeFrameFirstBlock(&repeat_without_previous);
    try expectError(error.CorruptFrame, vort.zstdInspectNativeFrameBlockSequenceModes(&repeat_without_previous, repeat_block));
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(&repeat_without_previous));
    var repeat_output: [4]u8 = undefined;
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(&repeat_without_previous, &repeat_output));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &repeat_without_previous));
    checked += 1;

    const raw_before_repeat_hex = "28b52ffd2008200000616263642500000001fc01";
    var raw_before_repeat: [raw_before_repeat_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&raw_before_repeat, raw_before_repeat_hex);
    const raw_block = try vort.zstdInspectNativeFrameFirstBlock(&raw_before_repeat);
    try expect(raw_block.block_type == .raw);
    try expectLiteralBlockSequenceSummary(&raw_before_repeat, raw_block, .raw);
    const repeat_after_raw_block = try vort.zstdInspectNativeFrameBlockAt(&raw_before_repeat, raw_block.next_header_offset);
    try expectError(error.CorruptFrame, vort.zstdInspectNativeFrameBlockSequenceModes(&raw_before_repeat, repeat_after_raw_block));
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(&raw_before_repeat));
    var raw_before_repeat_output: [8]u8 = undefined;
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(&raw_before_repeat, &raw_before_repeat_output));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &raw_before_repeat));
    checked += 1;

    // Like raw blocks, RLE blocks carry bytes but establish no sequence table
    // state. A Repeat_Mode compressed block after only an RLE block must
    // therefore be rejected rather than accidentally reusing stale state from a
    // previous probe or treating the RLE block as a table initializer.
    const rle_before_repeat_hex = "28b52ffd2008220000612500000001fc01";
    var rle_before_repeat: [rle_before_repeat_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&rle_before_repeat, rle_before_repeat_hex);
    const rle_block = try vort.zstdInspectNativeFrameFirstBlock(&rle_before_repeat);
    try expect(rle_block.block_type == .rle);
    try expectLiteralBlockSequenceSummary(&rle_before_repeat, rle_block, .rle);
    const repeat_after_rle_block = try vort.zstdInspectNativeFrameBlockAt(&rle_before_repeat, rle_block.next_header_offset);
    try expectError(error.CorruptFrame, vort.zstdInspectNativeFrameBlockSequenceModes(&rle_before_repeat, repeat_after_rle_block));
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(&rle_before_repeat));
    var rle_before_repeat_output: [8]u8 = undefined;
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(&rle_before_repeat, &rle_before_repeat_output));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &rle_before_repeat));
    checked += 1;

    // Partial Repeat_Mode has the same state precondition as the all-repeat
    // shape above. Keep raw and RLE siblings where LL=Repeat_Mode but OF/ML are
    // immediate RLE symbols so the parser must read mixed-mode payloads without
    // allowing a non-compressed block to satisfy the previous-table invariant.
    const raw_before_mixed_repeat_hex = "28b52ffd2008200000616263643d0000096101d4000001";
    var raw_before_mixed_repeat: [raw_before_mixed_repeat_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&raw_before_mixed_repeat, raw_before_mixed_repeat_hex);
    const raw_mixed_block = try vort.zstdInspectNativeFrameFirstBlock(&raw_before_mixed_repeat);
    try expect(raw_mixed_block.block_type == .raw);
    const mixed_repeat_after_raw_block = try vort.zstdInspectNativeFrameBlockAt(&raw_before_mixed_repeat, raw_mixed_block.next_header_offset);
    try expectError(error.CorruptFrame, vort.zstdInspectNativeFrameBlockSequenceModes(&raw_before_mixed_repeat, mixed_repeat_after_raw_block));
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(&raw_before_mixed_repeat));
    var raw_mixed_repeat_output: [8]u8 = undefined;
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(&raw_before_mixed_repeat, &raw_mixed_repeat_output));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &raw_before_mixed_repeat));
    checked += 1;

    const rle_before_mixed_repeat_hex = "28b52ffd2008220000613d0000096101d4000001";
    var rle_before_mixed_repeat: [rle_before_mixed_repeat_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&rle_before_mixed_repeat, rle_before_mixed_repeat_hex);
    const rle_mixed_block = try vort.zstdInspectNativeFrameFirstBlock(&rle_before_mixed_repeat);
    try expect(rle_mixed_block.block_type == .rle);
    const mixed_repeat_after_rle_block = try vort.zstdInspectNativeFrameBlockAt(&rle_before_mixed_repeat, rle_mixed_block.next_header_offset);
    try expectError(error.CorruptFrame, vort.zstdInspectNativeFrameBlockSequenceModes(&rle_before_mixed_repeat, mixed_repeat_after_rle_block));
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(&rle_before_mixed_repeat));
    var rle_mixed_repeat_output: [8]u8 = undefined;
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(&rle_before_mixed_repeat, &rle_mixed_repeat_output));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &rle_before_mixed_repeat));
    checked += 1;

    const raw_before_offset_repeat_hex = "28b52ffd2008200000616263643d000009610174000001";
    var raw_before_offset_repeat: [raw_before_offset_repeat_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&raw_before_offset_repeat, raw_before_offset_repeat_hex);
    const raw_offset_block = try vort.zstdInspectNativeFrameFirstBlock(&raw_before_offset_repeat);
    try expect(raw_offset_block.block_type == .raw);
    const offset_repeat_after_raw = try vort.zstdInspectNativeFrameBlockAt(&raw_before_offset_repeat, raw_offset_block.next_header_offset);
    try expectError(error.CorruptFrame, vort.zstdInspectNativeFrameBlockSequenceModes(&raw_before_offset_repeat, offset_repeat_after_raw));
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(&raw_before_offset_repeat));
    var raw_offset_output: [8]u8 = undefined;
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(&raw_before_offset_repeat, &raw_offset_output));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &raw_before_offset_repeat));
    checked += 1;

    const raw_before_match_repeat_hex = "28b52ffd2008200000616263643d00000961015c000001";
    var raw_before_match_repeat: [raw_before_match_repeat_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&raw_before_match_repeat, raw_before_match_repeat_hex);
    const raw_match_block = try vort.zstdInspectNativeFrameFirstBlock(&raw_before_match_repeat);
    try expect(raw_match_block.block_type == .raw);
    const match_repeat_after_raw = try vort.zstdInspectNativeFrameBlockAt(&raw_before_match_repeat, raw_match_block.next_header_offset);
    try expectError(error.CorruptFrame, vort.zstdInspectNativeFrameBlockSequenceModes(&raw_before_match_repeat, match_repeat_after_raw));
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(&raw_before_match_repeat));
    var raw_match_output: [8]u8 = undefined;
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(&raw_before_match_repeat, &raw_match_output));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &raw_before_match_repeat));
    checked += 1;

    const rle_before_offset_repeat_hex = "28b52ffd2008220000613d000009610174000001";
    var rle_before_offset_repeat: [rle_before_offset_repeat_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&rle_before_offset_repeat, rle_before_offset_repeat_hex);
    const rle_offset_block = try vort.zstdInspectNativeFrameFirstBlock(&rle_before_offset_repeat);
    try expect(rle_offset_block.block_type == .rle);
    const offset_repeat_after_rle = try vort.zstdInspectNativeFrameBlockAt(&rle_before_offset_repeat, rle_offset_block.next_header_offset);
    try expectError(error.CorruptFrame, vort.zstdInspectNativeFrameBlockSequenceModes(&rle_before_offset_repeat, offset_repeat_after_rle));
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(&rle_before_offset_repeat));
    var rle_offset_output: [8]u8 = undefined;
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(&rle_before_offset_repeat, &rle_offset_output));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &rle_before_offset_repeat));
    checked += 1;

    const rle_before_match_repeat_hex = "28b52ffd2008220000613d00000961015c000001";
    var rle_before_match_repeat: [rle_before_match_repeat_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&rle_before_match_repeat, rle_before_match_repeat_hex);
    const rle_match_block = try vort.zstdInspectNativeFrameFirstBlock(&rle_before_match_repeat);
    try expect(rle_match_block.block_type == .rle);
    const match_repeat_after_rle = try vort.zstdInspectNativeFrameBlockAt(&rle_before_match_repeat, rle_match_block.next_header_offset);
    try expectError(error.CorruptFrame, vort.zstdInspectNativeFrameBlockSequenceModes(&rle_before_match_repeat, match_repeat_after_rle));
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(&rle_before_match_repeat));
    var rle_match_output: [8]u8 = undefined;
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(&rle_before_match_repeat, &rle_match_output));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &rle_before_match_repeat));
    checked += 1;

    const missing_sequence_bitstream_hex = "28b52ffd240e3d00000961015401000a";
    var missing_sequence_bitstream: [missing_sequence_bitstream_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&missing_sequence_bitstream, missing_sequence_bitstream_hex);
    const missing_bits_block = try vort.zstdInspectNativeFrameFirstBlock(&missing_sequence_bitstream);
    try expectError(error.TruncatedFrame, vort.zstdInspectNativeFrameBlockSequenceModes(&missing_sequence_bitstream, missing_bits_block));
    try expectError(error.TruncatedFrame, vort.zstdDecodedNativeFrameSize(&missing_sequence_bitstream));
    var missing_bits_output: [14]u8 = undefined;
    try expectError(error.TruncatedFrame, vort.zstdDecodeNativeFrameInto(&missing_sequence_bitstream, &missing_bits_output));
    try expectAllocError(allocator, error.TruncatedFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &missing_sequence_bitstream));
    checked += 1;

    const zero_end_mark_hex = "28b52ffd240e4500000961015401000a00";
    var zero_end_mark: [zero_end_mark_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&zero_end_mark, zero_end_mark_hex);
    const zero_end_block = try vort.zstdInspectNativeFrameFirstBlock(&zero_end_mark);
    const zero_end_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&zero_end_mark, zero_end_block);
    try expect(zero_end_modes.sequence_count == 1);
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(&zero_end_mark));
    var zero_end_output: [14]u8 = undefined;
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(&zero_end_mark, &zero_end_output));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &zero_end_mark));
    checked += 1;

    const trailing_sequence_byte_hex = "28b52ffd240e4d00000961015401000a0100";
    var trailing_sequence_byte: [trailing_sequence_byte_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&trailing_sequence_byte, trailing_sequence_byte_hex);
    const trailing_sequence_block = try vort.zstdInspectNativeFrameFirstBlock(&trailing_sequence_byte);
    const trailing_sequence_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&trailing_sequence_byte, trailing_sequence_block);
    try expect(trailing_sequence_modes.sequence_count == 1);
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(&trailing_sequence_byte));
    var trailing_sequence_output: [14]u8 = undefined;
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(&trailing_sequence_byte, &trailing_sequence_output));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &trailing_sequence_byte));
    checked += 1;

    const trailing_literal_payload_hex = "28b52ffd20033500001861626300ff";
    var trailing_literal_payload: [trailing_literal_payload_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&trailing_literal_payload, trailing_literal_payload_hex);
    const trailing_literal_block = try vort.zstdInspectNativeFrameFirstBlock(&trailing_literal_payload);
    const trailing_literal_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&trailing_literal_payload, trailing_literal_block);
    try expect(trailing_literal_modes.sequence_count == 0);
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(&trailing_literal_payload));
    var trailing_literal_output: [14]u8 = undefined;
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(&trailing_literal_payload, &trailing_literal_output));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &trailing_literal_payload));
    checked += 1;

    const treeless_without_tree_hex = "28b52ffd200325000033400001";
    var treeless_without_tree: [treeless_without_tree_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&treeless_without_tree, treeless_without_tree_hex);
    const treeless_block = try vort.zstdInspectNativeFrameFirstBlock(&treeless_without_tree);
    try expectError(error.CorruptFrame, vort.zstdInspectNativeFrameBlockSequenceModes(&treeless_without_tree, treeless_block));
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(&treeless_without_tree));
    var treeless_output: [3]u8 = undefined;
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(&treeless_without_tree, &treeless_output));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &treeless_without_tree));
    checked += 1;

    const raw_then_treeless_without_tree_hex = "28b52ffd200318000052415725000033400001";
    var raw_then_treeless_without_tree: [raw_then_treeless_without_tree_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&raw_then_treeless_without_tree, raw_then_treeless_without_tree_hex);
    const raw_before_treeless = try vort.zstdInspectNativeFrameFirstBlock(&raw_then_treeless_without_tree);
    try expect(raw_before_treeless.block_type == .raw);
    const treeless_after_raw = try vort.zstdInspectNativeFrameBlockAt(&raw_then_treeless_without_tree, raw_before_treeless.next_header_offset);
    try expect(treeless_after_raw.block_type == .compressed);
    try expectError(error.CorruptFrame, vort.zstdInspectNativeFrameBlockSequenceModes(&raw_then_treeless_without_tree, treeless_after_raw));
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(&raw_then_treeless_without_tree));
    var raw_then_treeless_output: [6]u8 = undefined;
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(&raw_then_treeless_without_tree, &raw_then_treeless_output));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &raw_then_treeless_without_tree));
    checked += 1;

    const rle_then_treeless_without_tree_hex = "28b52ffd20031a00005225000033400001";
    var rle_then_treeless_without_tree: [rle_then_treeless_without_tree_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&rle_then_treeless_without_tree, rle_then_treeless_without_tree_hex);
    const rle_before_treeless = try vort.zstdInspectNativeFrameFirstBlock(&rle_then_treeless_without_tree);
    try expect(rle_before_treeless.block_type == .rle);
    const treeless_after_rle = try vort.zstdInspectNativeFrameBlockAt(&rle_then_treeless_without_tree, rle_before_treeless.next_header_offset);
    try expect(treeless_after_rle.block_type == .compressed);
    try expectError(error.CorruptFrame, vort.zstdInspectNativeFrameBlockSequenceModes(&rle_then_treeless_without_tree, treeless_after_rle));
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(&rle_then_treeless_without_tree));
    var rle_then_treeless_output: [6]u8 = undefined;
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(&rle_then_treeless_without_tree, &rle_then_treeless_output));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &rle_then_treeless_without_tree));
    checked += 1;

    const tree_then_new_frame_treeless_hex =
        "28b52ffd00680d0200e2c30d1290cf016c3325f0fdb0cddd2ce10b3339ce4e20b" ++
        "fb1a5123a279f76cdb7192d3a14f27ba43cef2102b95c08d2f8fea2efd493d" ++
        "fe58e0301007e7f411fa028b52ffd200325000033400001";
    var tree_then_new_frame_treeless: [tree_then_new_frame_treeless_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&tree_then_new_frame_treeless, tree_then_new_frame_treeless_hex);
    var boundary_iterator = vort.zstdIterateNativeStream(&tree_then_new_frame_treeless);
    const tree_frame = (try boundary_iterator.next()) orelse return error.ZstdNativeFrameProbeMismatch;
    const treeless_frame = (try boundary_iterator.next()) orelse return error.ZstdNativeFrameProbeMismatch;
    try expect((try boundary_iterator.next()) == null);
    const treeless_frame_bytes = switch (treeless_frame) {
        .frame => |frame| frame.bytes,
        .skippable => return error.ZstdNativeFrameProbeMismatch,
    };
    switch (tree_frame) {
        .frame => {},
        .skippable => return error.ZstdNativeFrameProbeMismatch,
    }
    const treeless_boundary_block = try vort.zstdInspectNativeFrameFirstBlock(treeless_frame_bytes);
    try expectError(error.CorruptFrame, vort.zstdInspectNativeFrameBlockSequenceModes(treeless_frame_bytes, treeless_boundary_block));
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeConcatenatedFrameSize(&tree_then_new_frame_treeless));
    var boundary_output: [8192]u8 = undefined;
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeConcatenatedFrameInto(&tree_then_new_frame_treeless, &boundary_output));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeConcatenatedFrameAlloc(allocator, &tree_then_new_frame_treeless));
    checked += 1;

    const skip_between_tree_and_treeless = try vort.zstdEncodeSkippableFrameAlloc(allocator, 3, "tree-boundary");
    defer allocator.free(skip_between_tree_and_treeless);
    const tree_skip_treeless = try std.mem.concat(allocator, u8, &.{
        &[_]u8{
            0x28, 0xb5, 0x2f, 0xfd, 0x00, 0x68,
            0x0d, 0x02, 0x00, 0xe2, 0xc3, 0x0d,
            0x12, 0x90, 0xcf, 0x01, 0x6c, 0x33,
            0x25, 0xf0, 0xfd, 0xb0, 0xcd, 0xdd,
            0x2c, 0xe1, 0x0b, 0x33, 0x39, 0xce,
            0x4e, 0x20, 0xbf, 0xb1, 0xa5, 0x12,
            0x3a, 0x27, 0x9f, 0x76, 0xcd, 0xb7,
            0x19, 0x2d, 0x3a, 0x14, 0xf2, 0x7b,
            0xa4, 0x3c, 0xef, 0x21, 0x02, 0xb9,
            0x5c, 0x08, 0xd2, 0xf8, 0xfe, 0xa2,
            0xef, 0xd4, 0x93, 0xdf, 0xe5, 0x8e,
            0x03, 0x01, 0x00, 0x7e, 0x7f, 0x41,
            0x1f, 0xa0,
        },
        skip_between_tree_and_treeless,
        &[_]u8{
            0x28, 0xb5, 0x2f, 0xfd, 0x20, 0x03,
            0x25, 0x00, 0x00, 0x33, 0x40, 0x00,
            0x01,
        },
    });
    defer allocator.free(tree_skip_treeless);
    const tree_skip_summary = try vort.zstdSummarizeNativeStream(tree_skip_treeless);
    try expect(tree_skip_summary.frame_count == 2);
    try expect(tree_skip_summary.skippable_frame_count == 1);
    try expect(tree_skip_summary.skippable_payload_bytes == "tree-boundary".len);
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeConcatenatedFrameSize(tree_skip_treeless));
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeConcatenatedFrameInto(tree_skip_treeless, &boundary_output));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeConcatenatedFrameAlloc(allocator, tree_skip_treeless));
    checked += 1;

    const tables_then_new_frame_repeat_hex =
        "28b52ffd200e4500000961015401000a01" ++
        "28b52ffd20042d0000096101fc01";
    var tables_then_new_frame_repeat: [tables_then_new_frame_repeat_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&tables_then_new_frame_repeat, tables_then_new_frame_repeat_hex);
    var repeat_boundary_output: [32]u8 = undefined;
    try expectTwoFrameRepeatBoundaryError(allocator, &tables_then_new_frame_repeat, &repeat_boundary_output);
    checked += 1;

    const tables_then_new_frame_literal_repeat_hex =
        "28b52ffd200e4500000961015401000a01" ++
        "28b52ffd20043d0000096101d4000001";
    var tables_then_new_frame_literal_repeat: [tables_then_new_frame_literal_repeat_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&tables_then_new_frame_literal_repeat, tables_then_new_frame_literal_repeat_hex);
    try expectTwoFrameRepeatBoundaryError(allocator, &tables_then_new_frame_literal_repeat, &repeat_boundary_output);
    checked += 1;

    const tables_then_new_frame_offset_repeat_hex =
        "28b52ffd200e4500000961015401000a01" ++
        "28b52ffd20043d000009610174000001";
    var tables_then_new_frame_offset_repeat: [tables_then_new_frame_offset_repeat_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&tables_then_new_frame_offset_repeat, tables_then_new_frame_offset_repeat_hex);
    try expectTwoFrameRepeatBoundaryError(allocator, &tables_then_new_frame_offset_repeat, &repeat_boundary_output);
    checked += 1;

    const tables_then_new_frame_match_repeat_hex =
        "28b52ffd200e4500000961015401000a01" ++
        "28b52ffd20043d00000961015c000001";
    var tables_then_new_frame_match_repeat: [tables_then_new_frame_match_repeat_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&tables_then_new_frame_match_repeat, tables_then_new_frame_match_repeat_hex);
    try expectTwoFrameRepeatBoundaryError(allocator, &tables_then_new_frame_match_repeat, &repeat_boundary_output);
    checked += 1;

    const skip_between_tables_and_repeat = try vort.zstdEncodeSkippableFrameAlloc(allocator, 2, "state-boundary");
    defer allocator.free(skip_between_tables_and_repeat);
    const tables_skip_repeat = try std.mem.concat(allocator, u8, &.{
        &[_]u8{
            0x28, 0xb5, 0x2f, 0xfd, 0x20, 0x0e,
            0x45, 0x00, 0x00, 0x09, 'a',  0x01,
            0x54, 0x01, 0x00, 0x0a, 0x01,
        },
        skip_between_tables_and_repeat,
        &[_]u8{
            0x28, 0xb5, 0x2f, 0xfd, 0x20, 0x04,
            0x2d, 0x00, 0x00, 0x09, 'a',  0x01,
            0xfc, 0x01,
        },
    });
    defer allocator.free(tables_skip_repeat);
    try expectSkippableRepeatBoundaryError(allocator, tables_skip_repeat, "state-boundary".len, &repeat_boundary_output);
    checked += 1;

    const tables_skip_literal_repeat = try std.mem.concat(allocator, u8, &.{
        &[_]u8{
            0x28, 0xb5, 0x2f, 0xfd, 0x20, 0x0e,
            0x45, 0x00, 0x00, 0x09, 'a',  0x01,
            0x54, 0x01, 0x00, 0x0a, 0x01,
        },
        skip_between_tables_and_repeat,
        &[_]u8{
            0x28, 0xb5, 0x2f, 0xfd, 0x20, 0x04,
            0x3d, 0x00, 0x00, 0x09, 'a',  0x01,
            0xd4, 0x00, 0x00, 0x01,
        },
    });
    defer allocator.free(tables_skip_literal_repeat);
    try expectSkippableRepeatBoundaryError(allocator, tables_skip_literal_repeat, "state-boundary".len, &repeat_boundary_output);
    checked += 1;

    const tables_skip_offset_repeat = try std.mem.concat(allocator, u8, &.{
        &[_]u8{
            0x28, 0xb5, 0x2f, 0xfd, 0x20, 0x0e,
            0x45, 0x00, 0x00, 0x09, 'a',  0x01,
            0x54, 0x01, 0x00, 0x0a, 0x01,
        },
        skip_between_tables_and_repeat,
        &[_]u8{
            0x28, 0xb5, 0x2f, 0xfd, 0x20, 0x04,
            0x3d, 0x00, 0x00, 0x09, 'a',  0x01,
            0x74, 0x00, 0x00, 0x01,
        },
    });
    defer allocator.free(tables_skip_offset_repeat);
    try expectSkippableRepeatBoundaryError(allocator, tables_skip_offset_repeat, "state-boundary".len, &repeat_boundary_output);
    checked += 1;

    const tables_skip_match_repeat = try std.mem.concat(allocator, u8, &.{
        &[_]u8{
            0x28, 0xb5, 0x2f, 0xfd, 0x20, 0x0e,
            0x45, 0x00, 0x00, 0x09, 'a',  0x01,
            0x54, 0x01, 0x00, 0x0a, 0x01,
        },
        skip_between_tables_and_repeat,
        &[_]u8{
            0x28, 0xb5, 0x2f, 0xfd, 0x20, 0x04,
            0x3d, 0x00, 0x00, 0x09, 'a',  0x01,
            0x5c, 0x00, 0x00, 0x01,
        },
    });
    defer allocator.free(tables_skip_match_repeat);
    try expectSkippableRepeatBoundaryError(allocator, tables_skip_match_repeat, "state-boundary".len, &repeat_boundary_output);
    checked += 1;

    return checked;
}

fn checkHandcraftedHeaderAndSkippableValidation(allocator: std.mem.Allocator) !usize {
    var checked: usize = 0;

    // Bit 3 of the frame descriptor is reserved by the Zstandard format and
    // must be rejected before any block parsing. The neighboring bit 4 is only
    // unused and accepted by reference decoders, so keep this public probe
    // focused on the true reserved-bit diagnostic.
    const reserved_descriptor_bit = [_]u8{
        0x28, 0xb5, 0x2f, 0xfd,
        0x08, // Reserved descriptor bit set.
        0x00, // Valid window descriptor if parsing were to continue.
    };
    try expectNativeHeaderAndStreamError(allocator, &reserved_descriptor_bit, error.CorruptFrame);
    checked += 1;

    // Descriptor advertises a 2-byte Dictionary_ID field but only one byte is
    // present. Keep the window descriptor valid so this specifically covers
    // field-length accounting, not earlier frame-header parsing.
    const truncated_dictionary_id = [_]u8{
        0x28, 0xb5, 0x2f, 0xfd,
        0x02, // Dictionary_ID flag = 2 bytes, no checksum/content-size.
        0x00, // 1 KiB window descriptor.
        0x34,
    };
    try expectNativeHeaderAndStreamError(allocator, &truncated_dictionary_id, error.TruncatedFrame);
    checked += 1;

    // Content_Size flag 1 requires a 2-byte size field for a non-single-segment
    // frame. Supplying one byte makes the header invalid before block parsing.
    const truncated_content_size = [_]u8{
        0x28, 0xb5, 0x2f, 0xfd,
        0x40, // Content_Size flag = 1; window descriptor still follows.
        0x00,
        0x03,
    };
    try expectNativeHeaderAndStreamError(allocator, &truncated_content_size, error.TruncatedFrame);
    checked += 1;

    const truncated_skippable = try handcraftedSkippableFrame(allocator, 6, "abc");
    defer allocator.free(truncated_skippable);
    try expectError(error.TruncatedFrame, vort.zstdInspectNativeSkippableFrame(truncated_skippable));
    try expectNativeStreamOnlyError(allocator, truncated_skippable, error.TruncatedFrame);
    checked += 1;

    const leading_skippable = try handcraftedSkippableFrame(allocator, 8, "metadata");
    defer allocator.free(leading_skippable);
    const skippable_then_reserved = try std.mem.concat(allocator, u8, &.{ leading_skippable, &reserved_descriptor_bit });
    defer allocator.free(skippable_then_reserved);
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(skippable_then_reserved));
    var stream_output: [1]u8 = undefined;
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(skippable_then_reserved, &stream_output));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, skippable_then_reserved));
    try expectError(error.CorruptFrame, vort.zstdSummarizeNativeStream(skippable_then_reserved));

    var stream_iterator = vort.zstdIterateNativeStream(skippable_then_reserved);
    const first = (try stream_iterator.next()) orelse return error.ZstdNativeFrameProbeMismatch;
    switch (first) {
        .frame => return error.ZstdNativeFrameProbeMismatch,
        .skippable => |skippable| {
            try expect(skippable.header.skippable_id == 0);
            try expectEqualSlices("metadata", skippable.payload);
        },
    }
    if (stream_iterator.next()) |_| {
        return error.ZstdNativeFrameProbeExpectedError;
    } else |err| if (err != error.CorruptFrame) return err;
    checked += 1;

    const reserved_then_skippable = try std.mem.concat(allocator, u8, &.{ &reserved_descriptor_bit, leading_skippable });
    defer allocator.free(reserved_then_skippable);
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(reserved_then_skippable));
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(reserved_then_skippable, &stream_output));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, reserved_then_skippable));
    try expectError(error.CorruptFrame, vort.zstdSummarizeNativeStream(reserved_then_skippable));
    try expectStreamIteratorError(reserved_then_skippable, error.CorruptFrame);
    checked += 1;

    return checked;
}

fn handcraftedRawFrame(
    allocator: std.mem.Allocator,
    claimed_len: usize,
    payload: []const u8,
    trailing: []const u8,
    content_checksum: bool,
) ![]u8 {
    var frame: std.ArrayList(u8) = .empty;
    errdefer frame.deinit(allocator);
    try frame.appendSlice(allocator, &.{ 0x28, 0xb5, 0x2f, 0xfd });
    try frame.append(allocator, if (content_checksum) 0x04 else 0x00);
    try frame.append(allocator, 0x00); // 1 KiB window descriptor for no-content-size frames.
    if (claimed_len > std.compress.zstd.block_size_max) return error.ZstdNativeFrameProbeMismatch;
    const block_header_value: u32 = (@as(u32, @intCast(claimed_len)) << 3) | 1;
    try frame.append(allocator, @truncate(block_header_value));
    try frame.append(allocator, @truncate(block_header_value >> 8));
    try frame.append(allocator, @truncate(block_header_value >> 16));
    try frame.appendSlice(allocator, payload);
    try frame.appendSlice(allocator, trailing);
    return try frame.toOwnedSlice(allocator);
}

fn handcraftedSkippableFrame(allocator: std.mem.Allocator, claimed_len: u32, payload: []const u8) ![]u8 {
    var frame: std.ArrayList(u8) = .empty;
    errdefer frame.deinit(allocator);
    var header: [8]u8 = undefined;
    std.mem.writeInt(u32, header[0..4], 0x184d2a50, .little);
    std.mem.writeInt(u32, header[4..8], claimed_len, .little);
    try frame.appendSlice(allocator, &header);
    try frame.appendSlice(allocator, payload);
    return try frame.toOwnedSlice(allocator);
}

fn expectTwoFrameRepeatBoundaryError(allocator: std.mem.Allocator, stream: []const u8, output: []u8) !void {
    // Repeat_Mode sequence tables are frame-local. This helper verifies the
    // common boundary shape used by the all-repeat and partial-repeat fixtures:
    // the first frame may decode on its own, but the second frame must not see
    // the first frame's tables through inspect, preflight, or decode APIs.
    var iterator = vort.zstdIterateNativeStream(stream);
    const table_frame = (try iterator.next()) orelse return error.ZstdNativeFrameProbeMismatch;
    const repeat_frame = (try iterator.next()) orelse return error.ZstdNativeFrameProbeMismatch;
    try expect((try iterator.next()) == null);
    switch (table_frame) {
        .frame => {},
        .skippable => return error.ZstdNativeFrameProbeMismatch,
    }
    const repeat_frame_bytes = switch (repeat_frame) {
        .frame => |frame| frame.bytes,
        .skippable => return error.ZstdNativeFrameProbeMismatch,
    };
    const repeat_boundary_block = try vort.zstdInspectNativeFrameFirstBlock(repeat_frame_bytes);
    try expectError(error.CorruptFrame, vort.zstdInspectNativeFrameBlockSequenceModes(repeat_frame_bytes, repeat_boundary_block));
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeConcatenatedFrameSize(stream));
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeConcatenatedFrameInto(stream, output));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeConcatenatedFrameAlloc(allocator, stream));
}

fn expectSkippableRepeatBoundaryError(allocator: std.mem.Allocator, stream: []const u8, skippable_payload_len: usize, output: []u8) !void {
    const summary = try vort.zstdSummarizeNativeStream(stream);
    try expect(summary.frame_count == 2);
    try expect(summary.skippable_frame_count == 1);
    try expect(summary.skippable_payload_bytes == skippable_payload_len);
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeConcatenatedFrameSize(stream));
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeConcatenatedFrameInto(stream, output));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeConcatenatedFrameAlloc(allocator, stream));
}

fn expectLiteralBlockSequenceSummary(frame: []const u8, block: vort.ZstdNativeFrameBlockHeader, kind: vort.ZstdNativeLiteralsKind) !void {
    const summary = try vort.zstdInspectNativeFrameBlockSequenceModes(frame, block);
    try expect(summary.literals_kind == kind);
    try expect(summary.regenerated_literals_size == block.payload_len);
    try expect(summary.sequence_count == 0);
    try expect(summary.literal_length_mode == .predefined);
    try expect(summary.offset_mode == .predefined);
    try expect(summary.match_length_mode == .predefined);
}

fn expect(ok: bool) !void {
    if (!ok) return error.ZstdNativeFrameProbeMismatch;
}

fn expectEqualSlices(expected: []const u8, actual: []const u8) !void {
    if (!std.mem.eql(u8, expected, actual)) return error.ZstdNativeFrameProbeMismatch;
}

fn expectPrefixedPayload(actual: []const u8, payload: []const u8) !void {
    if (actual.len != "prefix:".len + payload.len) return error.ZstdNativeFrameProbeMismatch;
    try expectEqualSlices("prefix:", actual[0.."prefix:".len]);
    try expectEqualSlices(payload, actual["prefix:".len..]);
}

fn expectError(expected: anyerror, result: anytype) !void {
    if (result) |_| {
        return error.ZstdNativeFrameProbeExpectedError;
    } else |err| {
        if (err != expected) return err;
    }
}

fn expectAllocError(allocator: std.mem.Allocator, expected: anyerror, result: anytype) !void {
    if (result) |decoded| {
        allocator.free(decoded);
        return error.ZstdNativeFrameProbeExpectedError;
    } else |err| {
        if (err != expected) return err;
    }
}

fn expectStreamIteratorError(frame: []const u8, expected: anyerror) !void {
    var iterator = vort.zstdIterateNativeStream(frame);
    if (iterator.next()) |_| {
        return error.ZstdNativeFrameProbeExpectedError;
    } else |err| {
        if (err != expected) return err;
    }
}

fn expectNativeHeaderAndStreamError(allocator: std.mem.Allocator, frame: []const u8, expected: anyerror) !void {
    try expectError(expected, vort.zstdInspectNativeFrameHeader(frame));
    try expectNativeStreamOnlyError(allocator, frame, expected);
}

fn expectNativeStreamOnlyError(allocator: std.mem.Allocator, frame: []const u8, expected: anyerror) !void {
    try expectError(expected, vort.zstdDecodedNativeFrameSize(frame));

    var output: [1]u8 = undefined;
    try expectError(expected, vort.zstdDecodeNativeFrameInto(frame, &output));
    try expectAllocError(allocator, expected, vort.zstdDecodeNativeFrameAlloc(allocator, frame));
    try expectError(expected, vort.zstdSummarizeNativeStream(frame));
    try expectStreamIteratorError(frame, expected);
}
