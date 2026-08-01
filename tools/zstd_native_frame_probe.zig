const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var stdout_buffer: [256]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    var checked: usize = 0;
    try checkDirectHuffmanBoundaries(init.gpa);
    checked += 1;
    try checkNoSizeCompressedBlockLimits(init.gpa);
    checked += 1;
    try checkHighByteFseHuffman(init.gpa);
    checked += 1;
    try checkSystemZstdHighByteFrame(init.gpa);
    checked += 1;
    try checkTreelessRepeatHuffmanLiterals(init.gpa);
    checked += 1;
    try checkRepeatOffsetAdditionalBits(init.gpa);
    checked += 1;
    try checkRepeatOffsetZeroLiteralSelector(init.gpa);
    checked += 1;
    try checkRepeatOffsetZeroLiteralSecondSelector(init.gpa);
    checked += 1;
    try checkRepeatOffsetLiteralSecondSelector(init.gpa);
    checked += 1;
    try checkRepeatOffsetZeroLiteralInvalidSelector(init.gpa);
    checked += 1;
    try checkRepeatOffsetZeroLiteralRep0MinusOneAfterUpdate(init.gpa);
    checked += 1;
    try checkRepeatedRleSequenceTables(init.gpa);
    checked += 1;
    try checkMultiplePredefinedSequenceStateTransitions(init.gpa);
    checked += 1;
    try checkMixedRlePredefinedSequenceModes(init.gpa);
    checked += 1;
    try checkRepeatMixedRlePredefinedSequenceModes(init.gpa);
    checked += 1;
    checked += try checkLibZstdGeneratedLibraryFrames(init.gpa);
    try checkSplitHeaderIncremental(init.gpa);
    checked += 1;
    try checkSplitSkippableHeaderIncremental(init.gpa);
    checked += 1;
    checked += try checkHandcraftedFrameValidation(init.gpa);
    checked += try checkHandcraftedHeaderAndSkippableValidation(init.gpa);

    try stdout.print("zstd_native_frame_probe_ok cases={d}\n", .{checked});
    try stdout.flush();
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

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    const appended_written = try vort.zstdDecodeNativeFrameAppendExactSize(allocator, &appended, encoded.frame, payload.len);
    try expect(appended_written == payload.len);
    try expectPrefixedPayload(appended.items, &payload);
    appended.clearRetainingCapacity();
    try expectError(error.SizeMismatch, vort.zstdDecodeNativeFrameAppendExactSize(allocator, &appended, encoded.frame, payload.len - 1));
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

fn checkLibZstdGeneratedLibraryFrames(allocator: std.mem.Allocator) !usize {
    var sequential: [2048]u8 = undefined;
    for (&sequential, 0..) |*byte, i| byte.* = @intCast(i % 251);

    var randomish: [2048]u8 = undefined;
    var rng = std.Random.DefaultPrng.init(0x7a57_1b5d);
    for (&randomish) |*byte| byte.* = rng.random().int(u8);

    const json_unit = "{\"service\":\"vort\",\"codec\":\"zstd\",\"native\":true,\"value\":12345}\n";
    const cases = [_][]const u8{
        "abcd" ** 512,
        &sequential,
        json_unit ** 64,
        &randomish,
    };
    const levels = [_]c_int{ 1, 9 };
    const option_sets = [_]vort.ZstdLibFrameOptions{
        .{},
        .{ .include_content_size = false },
        .{ .include_content_size = false, .content_checksum = true },
    };

    var checked: usize = 0;
    for (cases) |payload| {
        for (levels) |level| {
            for (option_sets) |options| {
                try checkLibZstdGeneratedLibraryFrame(allocator, payload, level, options);
                checked += 1;
            }
        }
    }
    return checked;
}

fn checkLibZstdGeneratedLibraryFrame(
    allocator: std.mem.Allocator,
    payload: []const u8,
    level: c_int,
    options: vort.ZstdLibFrameOptions,
) !void {
    const encoded = try vort.zstdEncodeFrameWithLevelAndOptionsAlloc(allocator, payload, level, options);
    defer allocator.free(encoded);

    // This is intentionally a pure Zig library differential: libzstd writes the
    // compatibility frame through Vort's library wrapper, then the dependency-
    // free native decoder must agree across one-shot, caller-buffer, reusable,
    // append, and bounded-size public APIs. No CLI command participates in the
    // oracle path.
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
    try expect(stream_summary.block_count >= 1);
    try expect(stream_summary.skippable_frame_count == 0);

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

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    const appended_written = try decoder.decodeAppendExactSize(&appended, encoded, payload.len);
    try expect(appended_written == payload.len);
    try expectPrefixedPayload(appended.items, payload);
    appended.clearRetainingCapacity();
    try expectError(error.SizeMismatch, decoder.decodeAppendExactSize(&appended, encoded, payload.len - 1));
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
    const repeat_after_raw_block = try vort.zstdInspectNativeFrameBlockAt(&raw_before_repeat, raw_block.next_header_offset);
    try expectError(error.CorruptFrame, vort.zstdInspectNativeFrameBlockSequenceModes(&raw_before_repeat, repeat_after_raw_block));
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(&raw_before_repeat));
    var raw_before_repeat_output: [8]u8 = undefined;
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(&raw_before_repeat, &raw_before_repeat_output));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &raw_before_repeat));
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
