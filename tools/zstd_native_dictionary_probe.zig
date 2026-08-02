const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var stdout_buffer: [256]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    var checked: usize = 0;
    try checkDictionaryIdValidation(init.gpa);
    checked += 1;
    try checkDerivedDictionaryIdApis(init.gpa);
    checked += 1;
    try checkTrainedDictionaryApis(init.gpa);
    checked += 1;
    try checkDictionarySetValidationApis(init.gpa);
    checked += 1;
    try checkDictionaryMatchEncoding(init.gpa);
    checked += 1;
    try checkDictionarySequenceHuffmanLiterals(init.gpa);
    checked += 1;
    try checkDictionaryHighByteSequenceHuffmanLiterals(init.gpa);
    checked += 1;
    try checkCompressedSequenceTableInspect(init.gpa);
    checked += 1;
    try checkMatchLengthCompressedSequenceTableInspect(init.gpa);
    checked += 1;
    try checkRepeatedSequenceTableInspect(init.gpa);
    checked += 1;
    try checkCompressedThenRepeatedSequenceTableInspect(init.gpa);
    checked += 1;
    try checkLiteralLengthCompressedThenRepeatedSequenceTableInspect(init.gpa);
    checked += 1;
    try checkOffsetCompressedThenRepeatedSequenceTableInspect(init.gpa);
    checked += 1;
    try checkMalformedCompressedSequenceTableInspect(init.gpa);
    checked += 1;
    try checkReusableDictionaryApis(init.gpa);
    checked += 1;
    try checkLaterBlockDictionaryMatch(init.gpa);
    checked += 1;
    try checkDictionaryMatchCostScoring(init.gpa);
    checked += 1;
    try checkMixedDictionaryDuplicateMatch(init.gpa);
    checked += 1;
    try checkMixedDictionaryRepeatedMatch(init.gpa);
    checked += 1;
    try checkMatchSearchBudget(init.gpa);
    checked += 1;
    try checkRepeatedBeforeDictionaryMatch(init.gpa);
    checked += 1;
    try checkConcatenatedDictionaryApis(init.gpa);
    checked += 1;
    try checkNoSizeDictionarySetDirectOutput(init.gpa);
    checked += 1;
    try checkDictionaryDirectFallback(init.gpa);
    checked += 1;
    try checkDictionarySetDirectFallback(init.gpa);
    checked += 1;

    try stdout.print("zstd_native_dictionary_probe_ok cases={d}\n", .{checked});
    try printCoverage(stdout, "zstd_native_dictionary_probe", checked, &.{
        "bounded-limits",
        "checksum",
        "chunked",
        "dictionary",
        "dictionary-training",
        "dictionary-set",
        "fse-repeat",
        "incremental",
        "malformed",
        "sequence-tables",
    }, &.{
        .{ .capability = "bounded-limits", .cases = 3 },
        .{ .capability = "checksum", .cases = 4 },
        .{ .capability = "chunked", .cases = 2 },
        .{ .capability = "dictionary-training", .cases = 1 },
        .{ .capability = "dictionary-set", .cases = 4 },
        .{ .capability = "fse-repeat", .cases = 3 },
        .{ .capability = "incremental", .cases = 4 },
        .{ .capability = "malformed", .cases = 2 },
        .{ .capability = "sequence-tables", .cases = 7 },
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

fn checkDictionaryIdValidation(allocator: std.mem.Allocator) !void {
    const dict = vort.ZstdNativeDictionary.init(0x1234, "previous zstd dictionary history");
    const wrong = vort.ZstdNativeDictionary.init(0x1235, dict.content);
    const payload = "plain payload";

    const encoded = try vort.zstdEncodeRawOrRleFrameWithOptionsAlloc(allocator, payload, .{
        .content_checksum = false,
        .dictionary_id = dict.id,
    });
    defer allocator.free(encoded);

    const header = try vort.zstdInspectNativeFrameHeader(encoded);
    try expect(header.dictionary_id == dict.id);
    try expectError(error.NeedDictionary, vort.zstdDecodeNativeFrameAlloc(allocator, encoded));
    try expectError(error.NeedDictionary, vort.zstdDecodedNativeFrameSizeWithDictionary(encoded, wrong));
    var wrong_output: [payload.len]u8 = undefined;
    try expectError(error.NeedDictionary, vort.zstdDecodeNativeFrameIntoWithDictionary(encoded, &wrong_output, wrong));
    try expectError(error.NeedDictionary, vort.zstdDecodeNativeFrameAllocWithDictionary(allocator, encoded, wrong));

    var reusable_wrong = vort.ZstdNativeFrameDecoder.init(allocator);
    defer reusable_wrong.deinit();
    try expectError(error.NeedDictionary, reusable_wrong.decodedSizeWithDictionary(encoded, wrong));
    try expectAllocError(allocator, error.NeedDictionary, reusable_wrong.decodeAllocWithDictionary(encoded, wrong));

    var incremental_wrong = vort.ZstdNativeIncrementalFrameDecoder.initWithDictionaryAndOptions(allocator, wrong, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer incremental_wrong.deinit();
    try expectError(error.NeedDictionary, incremental_wrong.step(encoded, &wrong_output));
    try expectEqualSlices("NeedDictionary", incremental_wrong.diagnostics().last_error_name);
    try expectEqualSlices("frame", incremental_wrong.diagnostics().last_error_phase_name);

    const decoded = try vort.zstdDecodeNativeFrameAllocWithDictionary(allocator, encoded, dict);
    defer allocator.free(decoded);
    try expectEqualSlices(payload, decoded);
    try expect((try vort.zstdDecodedNativeFrameSizeWithDictionary(encoded, dict)) == payload.len);
    try expectError(error.OutputLimitExceeded, vort.zstdDecodedNativeFrameSizeLimitedWithDictionary(encoded, payload.len - 1, dict));

    const second_payload = "plain second payload";
    const second = try vort.zstdEncodeRawOrRleFrameWithOptionsAlloc(allocator, second_payload, .{
        .content_checksum = false,
        .dictionary_id = dict.id,
    });
    defer allocator.free(second);
    const skip = try vort.zstdEncodeSkippableFrameAlloc(allocator, 1, "wrong-dict-zstd");
    defer allocator.free(skip);
    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(allocator);
    try stream.appendSlice(allocator, encoded);
    try stream.appendSlice(allocator, skip);
    try stream.appendSlice(allocator, second);

    const expected_stream_payload = payload ++ second_payload;
    const stream_decoded = try vort.zstdDecodeNativeConcatenatedFrameAllocWithDictionary(allocator, stream.items, dict);
    defer allocator.free(stream_decoded);
    try expectEqualSlices(expected_stream_payload, stream_decoded);
    try expect((try vort.zstdDecodedNativeConcatenatedFrameSizeWithDictionary(stream.items, dict)) == expected_stream_payload.len);

    var wrong_stream_output: [expected_stream_payload.len]u8 = undefined;
    try expectError(error.NeedDictionary, vort.zstdDecodedNativeConcatenatedFrameSizeWithDictionary(stream.items, wrong));
    try expectError(error.NeedDictionary, vort.zstdDecodeNativeConcatenatedFrameIntoWithDictionary(stream.items, &wrong_stream_output, wrong));
    try expectAllocError(allocator, error.NeedDictionary, vort.zstdDecodeNativeConcatenatedFrameAllocWithDictionary(allocator, stream.items, wrong));

    const checksummed = try vort.zstdEncodeRawOrRleFrameWithOptionsAlloc(allocator, payload, .{
        .content_checksum = true,
        .dictionary_id = dict.id,
    });
    defer allocator.free(checksummed);
    var wrong_checksum = try allocator.dupe(u8, checksummed);
    defer allocator.free(wrong_checksum);
    wrong_checksum[wrong_checksum.len - 1] ^= 0x01;
    const checksummed_header = try vort.zstdInspectNativeFrameHeader(wrong_checksum);
    try expect(checksummed_header.dictionary_id == dict.id);
    try expect(checksummed_header.has_checksum);
    try expectError(error.NeedDictionary, vort.zstdDecodedNativeFrameSize(wrong_checksum));
    try expectError(error.NeedDictionary, vort.zstdDecodedNativeFrameSizeWithDictionary(wrong_checksum, wrong));
    var checksum_priority_output: [payload.len]u8 = undefined;
    try expectError(error.NeedDictionary, vort.zstdDecodeNativeFrameInto(wrong_checksum, &checksum_priority_output));
    try expectError(error.NeedDictionary, vort.zstdDecodeNativeFrameIntoWithDictionary(wrong_checksum, &checksum_priority_output, wrong));
    try expectAllocError(allocator, error.NeedDictionary, vort.zstdDecodeNativeFrameAlloc(allocator, wrong_checksum));
    try expectAllocError(allocator, error.NeedDictionary, vort.zstdDecodeNativeFrameAllocWithDictionary(allocator, wrong_checksum, wrong));
    try expect((try vort.zstdDecodedNativeFrameSizeWithDictionary(wrong_checksum, dict)) == payload.len);
    try expectError(error.ChecksumMismatch, vort.zstdDecodeNativeFrameIntoWithDictionary(wrong_checksum, &checksum_priority_output, dict));
    try expectAllocError(allocator, error.ChecksumMismatch, vort.zstdDecodeNativeFrameAllocWithDictionary(allocator, wrong_checksum, dict));
    var missing_checksum_decoder = vort.ZstdNativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer missing_checksum_decoder.deinit();
    try expectError(error.NeedDictionary, missing_checksum_decoder.step(wrong_checksum, checksum_priority_output[0..0]));
    try expectEqualSlices("NeedDictionary", missing_checksum_decoder.diagnostics().last_error_name);
    try expectEqualSlices("frame", missing_checksum_decoder.diagnostics().last_error_phase_name);
    var bad_checksum_decoder = vort.ZstdNativeIncrementalFrameDecoder.initWithDictionaryAndOptions(allocator, dict, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer bad_checksum_decoder.deinit();
    try expectError(error.ChecksumMismatch, bad_checksum_decoder.step(wrong_checksum, checksum_priority_output[0..0]));
    try expectEqualSlices("ChecksumMismatch", bad_checksum_decoder.diagnostics().last_error_name);
    try expectEqualSlices("frame", bad_checksum_decoder.diagnostics().last_error_phase_name);

    const content_size_mismatch = [_]u8{
        0x28, 0xb5, 0x2f, 0xfd,
        0x22, // 2-byte Dictionary_ID, single-segment, one-byte content size.
        0x34, 0x12, // Dictionary_ID == 0x1234.
        0x05, // Advertise five decoded bytes.
        0x21, 0x00, 0x00, // Last raw block with only four payload bytes.
        'a',  'b',  'c',
        'd',
    };
    const mismatch_header = try vort.zstdInspectNativeFrameHeader(&content_size_mismatch);
    try expect(mismatch_header.dictionary_id == dict.id);
    try expect(mismatch_header.content_size.? == 5);
    var size_priority_output: [5]u8 = undefined;
    try expectError(error.NeedDictionary, vort.zstdDecodedNativeFrameSize(&content_size_mismatch));
    try expectError(error.NeedDictionary, vort.zstdDecodedNativeFrameSizeWithDictionary(&content_size_mismatch, wrong));
    try expectError(error.NeedDictionary, vort.zstdDecodeNativeFrameInto(&content_size_mismatch, &size_priority_output));
    try expectError(error.NeedDictionary, vort.zstdDecodeNativeFrameIntoWithDictionary(&content_size_mismatch, &size_priority_output, wrong));
    try expectAllocError(allocator, error.NeedDictionary, vort.zstdDecodeNativeFrameAlloc(allocator, &content_size_mismatch));
    try expectAllocError(allocator, error.NeedDictionary, vort.zstdDecodeNativeFrameAllocWithDictionary(allocator, &content_size_mismatch, wrong));
    try expectError(error.SizeMismatch, vort.zstdDecodedNativeFrameSizeWithDictionary(&content_size_mismatch, dict));
    try expectError(error.SizeMismatch, vort.zstdDecodeNativeFrameIntoWithDictionary(&content_size_mismatch, &size_priority_output, dict));
    try expectAllocError(allocator, error.SizeMismatch, vort.zstdDecodeNativeFrameAllocWithDictionary(allocator, &content_size_mismatch, dict));
    var missing_size_decoder = vort.ZstdNativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = size_priority_output.len,
        .max_decoded_buffer_len = size_priority_output.len,
    });
    defer missing_size_decoder.deinit();
    try expectError(error.NeedDictionary, missing_size_decoder.step(&content_size_mismatch, size_priority_output[0..0]));
    try expectEqualSlices("NeedDictionary", missing_size_decoder.diagnostics().last_error_name);
    try expectEqualSlices("frame", missing_size_decoder.diagnostics().last_error_phase_name);
    var size_mismatch_decoder = vort.ZstdNativeIncrementalFrameDecoder.initWithDictionaryAndOptions(allocator, dict, .{
        .expected_output_len = size_priority_output.len,
        .max_decoded_buffer_len = size_priority_output.len,
    });
    defer size_mismatch_decoder.deinit();
    try expectError(error.SizeMismatch, size_mismatch_decoder.step(&content_size_mismatch, size_priority_output[0..0]));
    try expectEqualSlices("SizeMismatch", size_mismatch_decoder.diagnostics().last_error_name);
    try expectEqualSlices("frame", size_mismatch_decoder.diagnostics().last_error_phase_name);

    const corrupt_block = [_]u8{
        0x28, 0xb5, 0x2f, 0xfd,
        0x22, // 2-byte Dictionary_ID, single-segment, one-byte content size.
        0x34, 0x12, // Dictionary_ID == 0x1234.
        0x04, // Advertise four decoded bytes.
        0x03, 0x00, 0x00, // Last RLE block with zero regenerated size.
        'x',
    };
    const corrupt_header = try vort.zstdInspectNativeFrameHeader(&corrupt_block);
    try expect(corrupt_header.dictionary_id == dict.id);
    var corrupt_priority_output: [4]u8 = undefined;
    try expectError(error.NeedDictionary, vort.zstdDecodedNativeFrameSize(&corrupt_block));
    try expectError(error.NeedDictionary, vort.zstdDecodedNativeFrameSizeWithDictionary(&corrupt_block, wrong));
    try expectError(error.NeedDictionary, vort.zstdDecodeNativeFrameInto(&corrupt_block, &corrupt_priority_output));
    try expectError(error.NeedDictionary, vort.zstdDecodeNativeFrameIntoWithDictionary(&corrupt_block, &corrupt_priority_output, wrong));
    try expectAllocError(allocator, error.NeedDictionary, vort.zstdDecodeNativeFrameAlloc(allocator, &corrupt_block));
    try expectAllocError(allocator, error.NeedDictionary, vort.zstdDecodeNativeFrameAllocWithDictionary(allocator, &corrupt_block, wrong));
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSizeWithDictionary(&corrupt_block, dict));
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameIntoWithDictionary(&corrupt_block, &corrupt_priority_output, dict));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAllocWithDictionary(allocator, &corrupt_block, dict));
    var missing_corrupt_decoder = vort.ZstdNativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = corrupt_priority_output.len,
        .max_decoded_buffer_len = corrupt_priority_output.len,
    });
    defer missing_corrupt_decoder.deinit();
    try expectError(error.NeedDictionary, missing_corrupt_decoder.step(&corrupt_block, corrupt_priority_output[0..0]));
    try expectEqualSlices("NeedDictionary", missing_corrupt_decoder.diagnostics().last_error_name);
    try expectEqualSlices("frame", missing_corrupt_decoder.diagnostics().last_error_phase_name);
    var corrupt_decoder = vort.ZstdNativeIncrementalFrameDecoder.initWithDictionaryAndOptions(allocator, dict, .{
        .expected_output_len = corrupt_priority_output.len,
        .max_decoded_buffer_len = corrupt_priority_output.len,
    });
    defer corrupt_decoder.deinit();
    try expectError(error.CorruptFrame, corrupt_decoder.step(&corrupt_block, corrupt_priority_output[0..0]));
    try expectEqualSlices("CorruptFrame", corrupt_decoder.diagnostics().last_error_name);
    try expectEqualSlices("frame", corrupt_decoder.diagnostics().last_error_phase_name);

    const compressed_malformed_hex =
        "28b52ffd2234129a250100606162636465666768696a6b6c10180210aeb5070b83c3c2c360e030701878383c1cec92";
    var compressed_malformed: [compressed_malformed_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&compressed_malformed, compressed_malformed_hex);
    const compressed_header = try vort.zstdInspectNativeFrameHeader(&compressed_malformed);
    try expect(compressed_header.dictionary_id == dict.id);
    const compressed_block = try vort.zstdInspectNativeFrameFirstBlock(&compressed_malformed);
    try expect(compressed_block.block_type == .compressed);
    // Corrupt the first byte of the ML FSE normalized-count header in a frame
    // that also requires a preset dictionary. Dictionary policy must be
    // resolved before exposing the deeper sequence-table corruption.
    compressed_malformed[compressed_block.payload_offset + 16] ^= 0xff;
    try expectError(error.NeedDictionary, vort.zstdDecodedNativeFrameSize(&compressed_malformed));
    try expectError(error.NeedDictionary, vort.zstdDecodedNativeFrameSizeWithDictionary(&compressed_malformed, wrong));
    var compressed_priority_output: [154]u8 = undefined;
    try expectError(error.NeedDictionary, vort.zstdDecodeNativeFrameInto(&compressed_malformed, &compressed_priority_output));
    try expectError(error.NeedDictionary, vort.zstdDecodeNativeFrameIntoWithDictionary(&compressed_malformed, &compressed_priority_output, wrong));
    try expectAllocError(allocator, error.NeedDictionary, vort.zstdDecodeNativeFrameAlloc(allocator, &compressed_malformed));
    try expectAllocError(allocator, error.NeedDictionary, vort.zstdDecodeNativeFrameAllocWithDictionary(allocator, &compressed_malformed, wrong));
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSizeWithDictionary(&compressed_malformed, dict));
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameIntoWithDictionary(&compressed_malformed, &compressed_priority_output, dict));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAllocWithDictionary(allocator, &compressed_malformed, dict));
    const compressed_set = vort.ZstdNativeDictionarySet.init(&.{dict});
    const compressed_missing_set = vort.ZstdNativeDictionarySet.init(&.{wrong});
    try expectError(error.NeedDictionary, vort.zstdDecodedNativeFrameSizeWithDictionarySet(&compressed_malformed, compressed_missing_set));
    try expectError(error.NeedDictionary, vort.zstdDecodeNativeFrameIntoWithDictionarySet(&compressed_malformed, &compressed_priority_output, compressed_missing_set));
    try expectAllocError(allocator, error.NeedDictionary, vort.zstdDecodeNativeFrameAllocWithDictionarySet(allocator, &compressed_malformed, compressed_missing_set));
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSizeWithDictionarySet(&compressed_malformed, compressed_set));
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameIntoWithDictionarySet(&compressed_malformed, &compressed_priority_output, compressed_set));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAllocWithDictionarySet(allocator, &compressed_malformed, compressed_set));
    var missing_compressed_decoder = vort.ZstdNativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = compressed_priority_output.len,
        .max_decoded_buffer_len = compressed_priority_output.len,
    });
    defer missing_compressed_decoder.deinit();
    try expectError(error.NeedDictionary, missing_compressed_decoder.step(&compressed_malformed, compressed_priority_output[0..0]));
    try expectEqualSlices("NeedDictionary", missing_compressed_decoder.diagnostics().last_error_name);
    try expectEqualSlices("frame", missing_compressed_decoder.diagnostics().last_error_phase_name);
    var compressed_malformed_decoder = vort.ZstdNativeIncrementalFrameDecoder.initWithDictionaryAndOptions(allocator, dict, .{
        .expected_output_len = compressed_priority_output.len,
        .max_decoded_buffer_len = compressed_priority_output.len,
    });
    defer compressed_malformed_decoder.deinit();
    try expectError(error.CorruptFrame, compressed_malformed_decoder.step(&compressed_malformed, compressed_priority_output[0..0]));
    try expectEqualSlices("CorruptFrame", compressed_malformed_decoder.diagnostics().last_error_name);
    try expectEqualSlices("frame", compressed_malformed_decoder.diagnostics().last_error_phase_name);
    var missing_set_compressed_decoder = vort.ZstdNativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(allocator, compressed_missing_set, .{
        .expected_output_len = compressed_priority_output.len,
        .max_decoded_buffer_len = compressed_priority_output.len,
    });
    defer missing_set_compressed_decoder.deinit();
    try expectError(error.NeedDictionary, missing_set_compressed_decoder.step(&compressed_malformed, compressed_priority_output[0..0]));
    try expectEqualSlices("NeedDictionary", missing_set_compressed_decoder.diagnostics().last_error_name);
    try expectEqualSlices("frame", missing_set_compressed_decoder.diagnostics().last_error_phase_name);
    var set_compressed_decoder = vort.ZstdNativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(allocator, compressed_set, .{
        .expected_output_len = compressed_priority_output.len,
        .max_decoded_buffer_len = compressed_priority_output.len,
    });
    defer set_compressed_decoder.deinit();
    try expectError(error.CorruptFrame, set_compressed_decoder.step(&compressed_malformed, compressed_priority_output[0..0]));
    try expectEqualSlices("CorruptFrame", set_compressed_decoder.diagnostics().last_error_name);
    try expectEqualSlices("frame", set_compressed_decoder.diagnostics().last_error_phase_name);
}

fn checkDerivedDictionaryIdApis(allocator: std.mem.Allocator) !void {
    const dict = vort.ZstdNativeDictionary.initFromContent("derived zstd dictionary history");
    const same = vort.ZstdNativeDictionary.initFromContent(dict.content);
    const payload = "pfx-derived zstd dictionary history payload";
    const options: vort.ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };

    try expect(dict.id == vort.crc32(dict.content));
    try expect(dict.id != 0);
    try expect(same.id == dict.id);
    try expectEqualSlices(dict.content, same.content);
    try expect(vort.ZstdNativeDictionary.derivedId("") == 1);
    try expect(vort.ZstdNativeDictionary.initFromContent("").id == 1);

    const encoded = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(allocator, payload, options, dict);
    defer allocator.free(encoded.frame);
    const header = try vort.zstdInspectNativeFrameHeader(encoded.frame);
    try expect(header.dictionary_id == dict.id);

    const decoded = try vort.zstdDecodeNativeFrameAllocWithDictionary(allocator, encoded.frame, same);
    defer allocator.free(decoded);
    try expectEqualSlices(payload, decoded);
}

fn checkTrainedDictionaryApis(allocator: std.mem.Allocator) !void {
    const samples = [_][]const u8{
        "trained-zstd-prefix alpha trained-zstd-tail",
        "trained-zstd-prefix beta trained-zstd-tail",
        "trained-zstd-prefix gamma trained-zstd-tail",
    };
    const trained = try vort.zstdTrainNativeDictionaryAlloc(allocator, &samples, .{
        .target_size = 64,
        .min_phrase_len = 4,
        .max_phrase_len = 18,
        .max_phrases = 96,
    });
    defer trained.deinit(allocator);
    const dict = trained.asDictionary();
    const metadata = trained.metadata();
    const payload = "pfx-trained-zstd-prefix alpha trained-zstd-tail payload";
    const options: vort.ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };

    try expect(dict.id == vort.ZstdNativeDictionary.derivedId(dict.content));
    try expect(dict.id != 0);
    try expect(metadata.id.asInt() == vort.DictionaryId.fromBytes(dict.content).asInt());
    try expect(metadata.content_len == dict.content.len);
    try expect(metadata.window_len == vort.zstdNativeDictionaryWindowLen);
    const encoded_metadata = try vort.encodeDictionaryMetadataAlloc(allocator, metadata);
    defer allocator.free(encoded_metadata);
    try expect(encoded_metadata.len == vort.dictionaryMetadataEncodedLen);
    const decoded_metadata = try vort.decodeDictionaryMetadata(encoded_metadata);
    try expect(decoded_metadata.id.asInt() == metadata.id.asInt());
    try expect(decoded_metadata.content_len == metadata.content_len);
    try expect(decoded_metadata.window_len == metadata.window_len);
    const metadata_dict = try vort.ZstdNativeDictionary.initFromMetadata(decoded_metadata, dict.content);
    try expect(metadata_dict.id == dict.id);
    try expectEqualSlices(metadata_dict.content, dict.content);
    try expectError(error.InvalidDictionaryMetadata, vort.ZstdNativeDictionary.initFromMetadata(decoded_metadata, "wrong-zstd-dict"));
    try expect(dict.content.len > 0);
    try expect(dict.content.len <= 64);
    const match_summary = try vort.summarizeDictionaryMatchesAlloc(allocator, dict.content, payload, 4);
    try expect(match_summary.matches > 0);
    try expect(match_summary.longest >= 4);

    const encoded = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(allocator, payload, options, dict);
    defer allocator.free(encoded.frame);
    const header = try vort.zstdInspectNativeFrameHeader(encoded.frame);
    try expect(header.dictionary_id == dict.id);

    const decoded = try vort.zstdDecodeNativeFrameAllocWithDictionary(allocator, encoded.frame, dict);
    defer allocator.free(decoded);
    try expectEqualSlices(payload, decoded);
}

fn checkDictionarySetValidationApis(allocator: std.mem.Allocator) !void {
    const first = vort.ZstdNativeDictionary.init(0x8181, "zstd-set-first");
    const second = vort.ZstdNativeDictionary.init(0x8282, "zstd-set-second");
    const dictionaries = [_]vort.ZstdNativeDictionary{ first, second };
    const checked = try vort.ZstdNativeDictionarySet.initChecked(&dictionaries);
    try checked.validate();
    try expectEqualSlices(first.content, (checked.find(first.id) orelse return error.ZstdNativeDictionaryProbeMismatch).content);
    try expect(checked.find(0x8383) == null);

    const duplicate = [_]vort.ZstdNativeDictionary{ first, vort.ZstdNativeDictionary.init(first.id, "zstd-duplicate") };
    try expectError(error.DuplicateDictionaryId, vort.ZstdNativeDictionarySet.initChecked(&duplicate));
    try expectError(error.DuplicateDictionaryId, vort.ZstdNativeDictionarySet.init(&duplicate).validate());
    const zero = [_]vort.ZstdNativeDictionary{vort.ZstdNativeDictionary.init(0, "zstd-zero")};
    try expectError(error.NeedDictionary, vort.ZstdNativeDictionarySet.initChecked(&zero));

    const metadata_first = vort.ZstdNativeDictionary.initFromContent("zstd-set-metadata-first");
    const metadata_second = vort.ZstdNativeDictionary.initFromContent("zstd-set-metadata-second");
    const metadata = [_]vort.DictionaryMetadata{
        vort.DictionaryMetadata.fromBytes(metadata_first.content, vort.zstdNativeDictionaryWindowLen),
        vort.DictionaryMetadata.fromBytes(metadata_second.content, vort.zstdNativeDictionaryWindowLen),
    };
    const contents = [_][]const u8{ metadata_first.content, metadata_second.content };
    var catalog: [2]vort.ZstdNativeDictionary = undefined;
    const metadata_set = try vort.ZstdNativeDictionarySet.initFromMetadata(&catalog, &metadata, &contents);
    try metadata_set.validate();
    try expectEqualSlices(metadata_first.content, (metadata_set.find(metadata_first.id) orelse return error.ZstdNativeDictionaryProbeMismatch).content);
    try expectEqualSlices(metadata_second.content, (metadata_set.find(metadata_second.id) orelse return error.ZstdNativeDictionaryProbeMismatch).content);

    var short_catalog: [1]vort.ZstdNativeDictionary = undefined;
    try expectError(error.InvalidDictionaryMetadata, vort.ZstdNativeDictionarySet.initFromMetadata(&short_catalog, &metadata, &contents));
    try expectError(error.InvalidDictionaryMetadata, vort.ZstdNativeDictionarySet.initFromMetadata(&catalog, metadata[0..1], &contents));
    const wrong_contents = [_][]const u8{ metadata_first.content, "wrong-zstd-set-second" };
    try expectError(error.InvalidDictionaryMetadata, vort.ZstdNativeDictionarySet.initFromMetadata(&catalog, &metadata, &wrong_contents));
    const duplicate_metadata = [_]vort.DictionaryMetadata{ metadata[0], metadata[0] };
    const duplicate_contents = [_][]const u8{ metadata_first.content, metadata_first.content };
    try expectError(error.DuplicateDictionaryId, vort.ZstdNativeDictionarySet.initFromMetadata(&catalog, &duplicate_metadata, &duplicate_contents));

    var empty_catalog: [0]vort.ZstdNativeDictionary = .{};
    const empty_metadata_set = try vort.ZstdNativeDictionarySet.initFromMetadata(&empty_catalog, &.{}, &.{});
    try empty_metadata_set.validate();
    try expect(empty_metadata_set.find(metadata_first.id) == null);
    const unexpected_contents = [_][]const u8{metadata_first.content};
    try expectError(error.InvalidDictionaryMetadata, vort.ZstdNativeDictionarySet.initFromMetadata(&empty_catalog, &.{}, &unexpected_contents));

    const owned_metadata_set = try vort.zstdNativeDictionarySetFromMetadataAlloc(allocator, &metadata, &contents);
    defer owned_metadata_set.deinit(allocator);
    const borrowed_metadata_set = owned_metadata_set.asDictionarySet();
    try borrowed_metadata_set.validate();
    try expectEqualSlices(metadata_first.content, (borrowed_metadata_set.find(metadata_first.id) orelse return error.ZstdNativeDictionaryProbeMismatch).content);
    try expectEqualSlices(metadata_second.content, (borrowed_metadata_set.find(metadata_second.id) orelse return error.ZstdNativeDictionaryProbeMismatch).content);

    const empty_owned_set = try vort.zstdNativeDictionarySetFromMetadataAlloc(allocator, &.{}, &.{});
    defer empty_owned_set.deinit(allocator);
    try expect(empty_owned_set.dictionaries.len == 0);
    try expect(empty_owned_set.asDictionarySet().find(metadata_first.id) == null);
    try expectError(error.InvalidDictionaryMetadata, vort.zstdNativeDictionarySetFromMetadataAlloc(allocator, &metadata, &wrong_contents));
}

fn checkDictionaryMatchEncoding(allocator: std.mem.Allocator) !void {
    const dict = vort.ZstdNativeDictionary.init(0x4433_2211, "abcdefghijklmnopQRSTUVWXYZabcd");
    const payload = "pfx-abcdefghijklmnop-mid-QRSTUVWXYZabcd-tail";
    const options: vort.ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };

    const encoded = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(allocator, payload, options, dict);
    defer allocator.free(encoded.frame);
    try expect(encoded.mode == .literal_only);
    const header = try vort.zstdInspectNativeFrameHeader(encoded.frame);
    try expect(header.dictionary_id == dict.id);
    const first_block = try vort.zstdInspectNativeFrameFirstBlock(encoded.frame);
    try expect(first_block.block_type == .compressed);

    try expectError(error.NeedDictionary, vort.zstdDecodeNativeFrameAlloc(allocator, encoded.frame));
    const wrong = vort.ZstdNativeDictionary.init(dict.id + 1, dict.content);
    try expectError(error.NeedDictionary, vort.zstdDecodedNativeFrameSizeWithDictionary(encoded.frame, wrong));
    var wrong_output: [payload.len]u8 = undefined;
    try expectError(error.NeedDictionary, vort.zstdDecodeNativeFrameIntoWithDictionary(encoded.frame, &wrong_output, wrong));
    try expectAllocError(allocator, error.NeedDictionary, vort.zstdDecodeNativeFrameAllocWithDictionary(allocator, encoded.frame, wrong));

    const decoded = try vort.zstdDecodeNativeFrameAllocWithDictionary(allocator, encoded.frame, dict);
    defer allocator.free(decoded);
    try expectEqualSlices(payload, decoded);

    const raw = try vort.zstdEncodeRawOrRleFrameWithOptionsAlloc(allocator, payload, .{
        .content_checksum = false,
        .dictionary_id = dict.id,
    });
    defer allocator.free(raw);
    try expect(encoded.frame.len < raw.len);

    const bound = try vort.zstdEncodedNativeFrameBoundWithDictionary(payload.len, options, dict);
    const into = try allocator.alloc(u8, bound);
    defer allocator.free(into);
    const into_result = try vort.zstdEncodeNativeFrameIntoSliceWithDictionary(allocator, payload, options, dict, into);
    try expect(into_result.mode == .literal_only);
    try expectEqualSlices(encoded.frame, into[0..into_result.written]);
    try expectError(error.OutputTooSmall, vort.zstdEncodeNativeFrameIntoSliceWithDictionary(allocator, payload, options, dict, into[0 .. into_result.written - 1]));
    try expectError(error.NeedDictionary, vort.zstdEncodeNativeFrameWithDictionaryAlloc(allocator, payload, options, vort.ZstdNativeDictionary.init(0, dict.content)));
}

fn checkDictionarySequenceHuffmanLiterals(allocator: std.mem.Allocator) !void {
    var dict_bytes: [512]u8 = undefined;
    var state: u32 = 0x9e37_79b9;
    for (&dict_bytes) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }

    const dict = vort.ZstdNativeDictionary.init(0x4433_2212, &dict_bytes);
    var payload_buffer: std.ArrayList(u8) = .empty;
    defer payload_buffer.deinit(allocator);
    try payload_buffer.appendNTimes(allocator, 'A', 192);
    try payload_buffer.appendNTimes(allocator, 'B', 192);
    try payload_buffer.appendSlice(allocator, &dict_bytes);
    try payload_buffer.appendNTimes(allocator, 'B', 192);
    try payload_buffer.appendNTimes(allocator, 'A', 192);
    const payload = payload_buffer.items;
    const options: vort.ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
        .match_search_budget = 0,
    };

    const encoded = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(allocator, payload, options, dict);
    defer allocator.free(encoded.frame);
    try expect(encoded.mode == .literal_only);
    try expectError(error.NeedDictionary, vort.zstdDecodeNativeFrameAlloc(allocator, encoded.frame));

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(encoded.frame);
    try expect(first_block.block_type == .compressed);
    const literal_header = encoded.frame[first_block.payload_offset];
    try expect((literal_header & 0x03) == 2); // compressed Huffman literals, not raw/RLE literals.

    const decoded = try vort.zstdDecodeNativeFrameAllocWithDictionary(allocator, encoded.frame, dict);
    defer allocator.free(decoded);
    try expectEqualSlices(payload, decoded);

    const raw = try vort.zstdEncodeRawOrRleFrameWithOptionsAlloc(allocator, payload, .{
        .content_checksum = false,
        .dictionary_id = dict.id,
    });
    defer allocator.free(raw);
    try expect(encoded.frame.len < raw.len);
}

fn checkDictionaryHighByteSequenceHuffmanLiterals(allocator: std.mem.Allocator) !void {
    var dict_bytes: [256]u8 = undefined;
    var state: u32 = 0x1234_abcd;
    for (&dict_bytes) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }

    const dict = vort.ZstdNativeDictionary.init(0x4433_2213, &dict_bytes);
    var payload_buffer: std.ArrayList(u8) = .empty;
    defer payload_buffer.deinit(allocator);
    try appendHighByteLiteralRun(allocator, &payload_buffer, 384, 0xfeed_beef);
    try payload_buffer.appendSlice(allocator, &dict_bytes);
    try appendHighByteLiteralRun(allocator, &payload_buffer, 384, 0x0bad_cafe);
    const payload = payload_buffer.items;
    const options: vort.ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
        .match_search_budget = 0,
    };

    const encoded = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(allocator, payload, options, dict);
    defer allocator.free(encoded.frame);
    try expect(encoded.mode == .literal_only);
    try expectError(error.NeedDictionary, vort.zstdDecodeNativeFrameAlloc(allocator, encoded.frame));

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(encoded.frame);
    try expect(first_block.block_type == .compressed);
    const literal_header = encoded.frame[first_block.payload_offset];
    try expect((literal_header & 0x03) == 2); // compressed Huffman literals.
    const huffman_header = encoded.frame[first_block.payload_offset + 3];
    try expect(huffman_header < 128); // FSE-compressed Huffman weights, not direct weights.

    const decoded = try vort.zstdDecodeNativeFrameAllocWithDictionary(allocator, encoded.frame, dict);
    defer allocator.free(decoded);
    try expectEqualSlices(payload, decoded);

    const raw = try vort.zstdEncodeRawOrRleFrameWithOptionsAlloc(allocator, payload, .{
        .content_checksum = false,
        .dictionary_id = dict.id,
    });
    defer allocator.free(raw);
    try expect(encoded.frame.len < raw.len);
}

fn appendHighByteLiteralRun(allocator: std.mem.Allocator, out: *std.ArrayList(u8), len: usize, seed: u32) !void {
    var state = seed;
    for (0..len) |_| {
        state = state *% 1_664_525 +% 1_013_904_223;
        try out.append(allocator, @intCast(129 + ((state >> 16) % 127)));
    }
}

fn checkCompressedSequenceTableInspect(allocator: std.mem.Allocator) !void {
    try checkLiteralAndOffsetCompressedSequenceTableInspect(allocator, 4, 20, .compressed, .predefined);
    try checkLiteralAndOffsetCompressedSequenceTableInspect(allocator, 5, 21, .compressed, .compressed);
}

fn checkMatchLengthCompressedSequenceTableInspect(allocator: std.mem.Allocator) !void {
    // Fixed fixture emitted by Vort's focused ML=FSE writer case:
    // LL=Predefined, OF=RLE, ML=FSE. Keeping it in the public probe makes the
    // inspection/decode contract visible without depending on internal helpers.
    const frame_hex =
        "28b52ffd209a250100606162636465666768696a6b6c10180210aeb5070b83c3c2c360e030701878383c1cec92";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    const modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, first_block);
    try expect(first_block.block_type == .compressed);
    try expect(modes.sequence_count == 16);
    try expect(modes.literal_length_mode == .predefined);
    try expect(modes.offset_mode == .rle);
    try expect(modes.match_length_mode == .compressed);

    const decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(decoded);
    const expected = try matchLengthCompressedFixturePayload(allocator);
    defer allocator.free(expected);
    try expectEqualSlices(expected, decoded);

    var into: [154]u8 = undefined;
    const into_written = try vort.zstdDecodeNativeFrameInto(&frame, &into);
    try expect(into_written == expected.len);
    try expectEqualSlices(expected, into[0..into_written]);
}

fn matchLengthCompressedFixturePayload(allocator: std.mem.Allocator) ![]u8 {
    const literal_lens = [_]usize{ 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
    const match_lens = [_]usize{ 8, 9, 8, 10, 9, 8, 10, 9, 8, 9, 8, 10, 9, 8, 10, 9 };
    var payload: std.ArrayList(u8) = .empty;
    errdefer payload.deinit(allocator);
    for (match_lens, 0..) |match_len, i| {
        if (literal_lens[i] != 0) try payload.appendSlice(allocator, "abcdefghijkl");
        for (0..match_len) |_| try payload.append(allocator, payload.items[payload.items.len - 4]);
    }
    return try payload.toOwnedSlice(allocator);
}

fn checkRepeatedSequenceTableInspect(allocator: std.mem.Allocator) !void {
    // Two-block fixture: the first compressed block defines LL/OF RLE tables and
    // uses the predefined ML table; the second block uses Repeat_Mode for all
    // three sequence tables. This keeps public inspection coverage for table
    // reuse separate from the heavier encoder-side generation tests.
    const frame_hex = "28b52ffd600800440000096101500100002a350000096101fc002a";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    const first_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, first_block);
    try expect(first_block.block_type == .compressed);
    try expect(!first_block.last);
    try expect(first_modes.sequence_count == 1);
    try expect(first_modes.literal_length_mode == .rle);
    try expect(first_modes.offset_mode == .rle);
    try expect(first_modes.match_length_mode == .predefined);

    const second_block = try vort.zstdInspectNativeFrameBlockAt(&frame, first_block.next_header_offset);
    const second_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, second_block);
    try expect(second_block.block_type == .compressed);
    try expect(second_block.last);
    try expect(second_modes.sequence_count == 1);
    try expect(second_modes.literal_length_mode == .repeat);
    try expect(second_modes.offset_mode == .repeat);
    try expect(second_modes.match_length_mode == .repeat);

    const decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(decoded);
    try expect(decoded.len == 264);
    for (decoded) |byte| try expect(byte == 'a');

    var into: [264]u8 = undefined;
    const into_written = try vort.zstdDecodeNativeFrameInto(&frame, &into);
    try expect(into_written == decoded.len);
    try expectEqualSlices(decoded, into[0..into_written]);
}

fn checkCompressedThenRepeatedSequenceTableInspect(allocator: std.mem.Allocator) !void {
    // First block defines ML as a compressed FSE table; the second block uses
    // Repeat_Mode for all sequence tables and therefore reuses that ML table.
    const frame_hex =
        "28b52ffd20a2240100606162636465666768696a6b6c10180210aeb5070b83c3c2c360e030701878383c1cec922d00000001fc3b20";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    const first_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, first_block);
    try expect(first_block.block_type == .compressed);
    try expect(!first_block.last);
    try expect(first_modes.sequence_count == 16);
    try expect(first_modes.literal_length_mode == .predefined);
    try expect(first_modes.offset_mode == .rle);
    try expect(first_modes.match_length_mode == .compressed);

    const second_block = try vort.zstdInspectNativeFrameBlockAt(&frame, first_block.next_header_offset);
    const second_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, second_block);
    try expect(second_block.block_type == .compressed);
    try expect(second_block.last);
    try expect(second_modes.sequence_count == 1);
    try expect(second_modes.literal_length_mode == .repeat);
    try expect(second_modes.offset_mode == .repeat);
    try expect(second_modes.match_length_mode == .repeat);
    try expect((try vort.zstdDecodedNativeFrameSize(&frame)) == 162);

    const decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(decoded);
    const expected = try matchLengthCompressedFixturePayload(allocator);
    defer allocator.free(expected);
    try expect(decoded.len == expected.len + 8);
    try expectEqualSlices(expected, decoded[0..expected.len]);
    try expectEqualSlices(expected[expected.len - 4 ..], decoded[expected.len .. expected.len + 4]);
    try expectEqualSlices(expected[expected.len - 4 ..], decoded[expected.len + 4 ..]);

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

fn checkLiteralLengthCompressedThenRepeatedSequenceTableInspect(allocator: std.mem.Allocator) !void {
    // First block defines LL as a compressed FSE table; the second block uses
    // Repeat_Mode for all sequence tables, covering a different repeated-table
    // transition than the ML=FSE fixture above.
    const frame_hex =
        "28b52ffd20b8040200e402616278616261627879616278616261627879616278616261627861626162787961627861626162787961627861621094106aed0102059966271a8d6e371735000010616201fcb9";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    const first_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, first_block);
    try expect(first_block.block_type == .compressed);
    try expect(!first_block.last);
    try expect(first_modes.sequence_count == 16);
    try expect(first_modes.literal_length_mode == .compressed);
    try expect(first_modes.offset_mode == .rle);
    try expect(first_modes.match_length_mode == .rle);

    const second_block = try vort.zstdInspectNativeFrameBlockAt(&frame, first_block.next_header_offset);
    const second_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, second_block);
    try expect(second_block.block_type == .compressed);
    try expect(second_block.last);
    try expect(second_modes.sequence_count == 1);
    try expect(second_modes.literal_length_mode == .repeat);
    try expect(second_modes.offset_mode == .repeat);
    try expect(second_modes.match_length_mode == .repeat);
    try expect((try vort.zstdDecodedNativeFrameSize(&frame)) == 184);

    const decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(decoded);
    try expect(decoded.len == 184);
    try expectEqualSlices("ababababab", decoded[decoded.len - 10 ..]);

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

fn checkOffsetCompressedThenRepeatedSequenceTableInspect(allocator: std.mem.Allocator) !void {
    // First block defines OF as a compressed FSE table; the second block uses
    // Repeat_Mode for all sequence tables and reuses that offset table.
    const frame_hex =
        "28b52ffd2094240100606162636465666768696a6b6c1024106a1f05830bc3c2c36061b070701838382c7826012d00000001fc4f20";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    const first_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, first_block);
    try expect(first_block.block_type == .compressed);
    try expect(!first_block.last);
    try expect(first_modes.sequence_count == 16);
    try expect(first_modes.literal_length_mode == .predefined);
    try expect(first_modes.offset_mode == .compressed);
    try expect(first_modes.match_length_mode == .rle);

    const second_block = try vort.zstdInspectNativeFrameBlockAt(&frame, first_block.next_header_offset);
    const second_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, second_block);
    try expect(second_block.block_type == .compressed);
    try expect(second_block.last);
    try expect(second_modes.sequence_count == 1);
    try expect(second_modes.literal_length_mode == .repeat);
    try expect(second_modes.offset_mode == .repeat);
    try expect(second_modes.match_length_mode == .repeat);
    try expect((try vort.zstdDecodedNativeFrameSize(&frame)) == 148);

    const decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, &frame);
    defer allocator.free(decoded);
    try expect(decoded.len == 148);

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

fn checkMalformedCompressedSequenceTableInspect(allocator: std.mem.Allocator) !void {
    const frame_hex =
        "28b52ffd209a250100606162636465666768696a6b6c10180210aeb5070b83c3c2c360e030701878383c1cec92";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    // Corrupt the first byte of the ML FSE normalized-count header. This should
    // fail while parsing the sequence table, before sequence execution.
    frame[25] ^= 0xff;
    const first_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    try expectError(error.CorruptFrame, vort.zstdInspectNativeFrameBlockSequenceModes(&frame, first_block));
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(&frame));

    var into: [154]u8 = undefined;
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(&frame, &into));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &frame));

    _ = try std.fmt.hexToBytes(&frame, frame_hex);
    // Raise the ML FSE accuracy-log bias past the supported sequence-table
    // maximum. This should be rejected while parsing table metadata.
    frame[25] = 0x15;
    const bad_accuracy_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    try expectError(error.CorruptFrame, vort.zstdInspectNativeFrameBlockSequenceModes(&frame, bad_accuracy_block));
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(&frame));
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(&frame, &into));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &frame));

    _ = try std.fmt.hexToBytes(&frame, frame_hex);
    // This mutation still leaves enough normalized-count structure for public
    // inspection to identify ML=FSE, but the resulting table/state stream is
    // invalid during sequence preflight/decode.
    frame[25] = 0x00;
    const malformed_state_block = try vort.zstdInspectNativeFrameFirstBlock(&frame);
    const malformed_state_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&frame, malformed_state_block);
    try expect(malformed_state_modes.match_length_mode == .compressed);
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(&frame));
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(&frame, &into));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &frame));

    const short_state_stream_hex =
        "28b52ffd209a1d0100606162636465666768696a6b6c10180210aeb5070b83c3c2c360e030701878383c1cec";
    var short_state_stream: [short_state_stream_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&short_state_stream, short_state_stream_hex);
    const short_state_block = try vort.zstdInspectNativeFrameFirstBlock(&short_state_stream);
    const short_state_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(&short_state_stream, short_state_block);
    try expect(short_state_modes.match_length_mode == .compressed);
    try expectError(error.CorruptFrame, vort.zstdDecodedNativeFrameSize(&short_state_stream));
    try expectError(error.CorruptFrame, vort.zstdDecodeNativeFrameInto(&short_state_stream, &into));
    try expectAllocError(allocator, error.CorruptFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &short_state_stream));

    const truncated_table_hex =
        "28b52ffd209aa50000606162636465666768696a6b6c10180210aeb507";
    var truncated_table: [truncated_table_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&truncated_table, truncated_table_hex);
    const truncated_block = try vort.zstdInspectNativeFrameFirstBlock(&truncated_table);
    try expectError(error.TruncatedFrame, vort.zstdInspectNativeFrameBlockSequenceModes(&truncated_table, truncated_block));
    try expectError(error.TruncatedFrame, vort.zstdDecodedNativeFrameSize(&truncated_table));
    try expectError(error.TruncatedFrame, vort.zstdDecodeNativeFrameInto(&truncated_table, &into));
    try expectAllocError(allocator, error.TruncatedFrame, vort.zstdDecodeNativeFrameAlloc(allocator, &truncated_table));
}

fn checkLiteralAndOffsetCompressedSequenceTableInspect(
    allocator: std.mem.Allocator,
    case_index: usize,
    expected_sequences: usize,
    expected_literal_mode: vort.ZstdNativeSequenceTableMode,
    expected_offset_mode: vort.ZstdNativeSequenceTableMode,
) !void {
    var dict_bytes: [32]u8 = undefined;
    var dict_state: u32 = 0x1234_5678;
    for (&dict_bytes) |*byte| {
        dict_state = dict_state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(dict_state >> 24);
    }

    const dict = vort.ZstdNativeDictionary.init(0x4433_2214, &dict_bytes);
    var payload: std.ArrayList(u8) = .empty;
    defer payload.deinit(allocator);
    var state: u32 = @truncate(case_index *% 747_796_405 +% 2_891_336_453);
    for (0..expected_sequences) |_| {
        state = state *% 1_664_525 +% 1_013_904_223;
        const literal_len: usize = @intCast(1 + ((state >> 24) % 8));
        for (0..literal_len) |_| {
            state = state *% 1_664_525 +% 1_013_904_223;
            try payload.append(allocator, @truncate(state >> 24));
        }
        try payload.appendSlice(allocator, &dict_bytes);
    }
    const options: vort.ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
        .match_search_budget = 0,
    };

    const encoded = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(allocator, payload.items, options, dict);
    defer allocator.free(encoded.frame);
    const first_block = try vort.zstdInspectNativeFrameFirstBlock(encoded.frame);
    const modes = try vort.zstdInspectNativeFrameBlockSequenceModes(encoded.frame, first_block);
    try expect(modes.sequence_count == expected_sequences);
    try expect(modes.literal_length_mode == expected_literal_mode);
    try expect(modes.offset_mode == expected_offset_mode);
    try expect(modes.match_length_mode == .rle);

    const decoded = try vort.zstdDecodeNativeFrameAllocWithDictionary(allocator, encoded.frame, dict);
    defer allocator.free(decoded);
    try expectEqualSlices(payload.items, decoded);
}

fn checkReusableDictionaryApis(allocator: std.mem.Allocator) !void {
    const dict = vort.ZstdNativeDictionary.init(0x77, "prefix-history-block");
    const payload = "prefix-history-block suffix";
    const options: vort.ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };

    var encoder = vort.ZstdNativeFrameEncoder.init(allocator);
    defer encoder.deinit();
    const scratch = try encoder.encodeScratchWithDictionary(payload, options, dict);
    try expect(scratch.mode == .literal_only);

    var decoder = vort.ZstdNativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    const decoded = try decoder.decodeScratchWithDictionary(scratch.frame, dict);
    try expectEqualSlices(payload, decoded);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    const written = try decoder.decodeAppendWithDictionary(&appended, scratch.frame, dict);
    try expect(written == payload.len);
    try expectEqualSlices("prefix:", appended.items[0.."prefix:".len]);
    try expectEqualSlices(payload, appended.items["prefix:".len..]);

    var into: [payload.len]u8 = undefined;
    const into_written = try decoder.decodeIntoSliceWithDictionary(scratch.frame, &into, dict);
    try expect(into_written == payload.len);
    try expectEqualSlices(payload, &into);
}

fn checkLaterBlockDictionaryMatch(allocator: std.mem.Allocator) !void {
    const dict = vort.ZstdNativeDictionary.init(0x99, "abcdefghijklmnop");
    const first_block_payload = "0123456789!@#$%^&*()_+-=[]{}<>";
    const second_block_payload = "pfx-abcdefghijklmnop-tail";
    const payload = first_block_payload ++ second_block_payload;
    const options: vort.ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
        .block_size_max = first_block_payload.len,
    };

    const encoded = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(allocator, payload, options, dict);
    defer allocator.free(encoded.frame);
    try expect(encoded.mode == .literal_only);
    try expectError(error.NeedDictionary, vort.zstdDecodeNativeFrameAlloc(allocator, encoded.frame));

    var iterator = try vort.zstdIterateNativeFrameBlocks(encoded.frame);
    _ = (try iterator.next()) orelse return error.ZstdNativeDictionaryProbeMismatch;
    const second_block = (try iterator.next()) orelse return error.ZstdNativeDictionaryProbeMismatch;
    try expect(second_block.block_type == .compressed);

    const decoded = try vort.zstdDecodeNativeFrameAllocWithDictionary(allocator, encoded.frame, dict);
    defer allocator.free(decoded);
    try expectEqualSlices(payload, decoded);
}

fn checkDictionaryMatchCostScoring(allocator: std.mem.Allocator) !void {
    var dict_bytes: std.ArrayList(u8) = .empty;
    defer dict_bytes.deinit(allocator);
    try dict_bytes.appendSlice(allocator, "ABCDEFGHI");
    try dict_bytes.appendNTimes(allocator, 'x', 70 * 1024);
    try dict_bytes.appendSlice(allocator, "ABCDEFGH");

    const dict = vort.ZstdNativeDictionary.init(0x9A, dict_bytes.items);
    const payload = "ABCDEFGHI-tail";
    const options: vort.ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };

    const encoded = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(allocator, payload, options, dict);
    defer allocator.free(encoded.frame);
    const decoded = try vort.zstdDecodeNativeFrameAllocWithDictionary(allocator, encoded.frame, dict);
    defer allocator.free(decoded);
    try expectEqualSlices(payload, decoded);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(encoded.frame);
    try expect(first_block.block_type == .compressed);
    const raw = try vort.zstdEncodeRawOrRleFrameWithOptionsAlloc(allocator, payload, .{
        .content_checksum = false,
        .dictionary_id = dict.id,
    });
    defer allocator.free(raw);
    try expect(encoded.frame.len < raw.len);
}

fn checkMixedDictionaryDuplicateMatch(allocator: std.mem.Allocator) !void {
    const dict = vort.ZstdNativeDictionary.init(0x9B, "abcdefghijklmnop");
    const payload = "pfx-abcdefghijklmnop-mid-abcdefghijklmnop-tail";
    const options: vort.ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };

    const encoded = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(allocator, payload, options, dict);
    defer allocator.free(encoded.frame);
    try expect(encoded.mode == .literal_only);
    const first_block = try vort.zstdInspectNativeFrameFirstBlock(encoded.frame);
    try expect(first_block.block_type == .compressed);

    const decoded = try vort.zstdDecodeNativeFrameAllocWithDictionary(allocator, encoded.frame, dict);
    defer allocator.free(decoded);
    try expectEqualSlices(payload, decoded);
}

fn checkMixedDictionaryRepeatedMatch(allocator: std.mem.Allocator) !void {
    const dictionary_payload = "abcdefghijklmnopqrstuvwxyz0123456789" ** 8;
    const dict = vort.ZstdNativeDictionary.init(0x9C, dictionary_payload);
    const payload = "pfx-" ++ dictionary_payload ++ "-mid-0123456789xy" ++ ("ab" ** 80) ++ "-tail";
    const options: vort.ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };

    const encoded = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(allocator, payload, options, dict);
    defer allocator.free(encoded.frame);
    try expect(encoded.mode == .literal_only);
    const decoded = try vort.zstdDecodeNativeFrameAllocWithDictionary(allocator, encoded.frame, dict);
    defer allocator.free(decoded);
    try expectEqualSlices(payload, decoded);
}

fn checkMatchSearchBudget(allocator: std.mem.Allocator) !void {
    const dict_content = "DICTMATCH1234567890";
    const unique = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_+-=[]{}";
    const dict = vort.ZstdNativeDictionary.init(0x9E, dict_content);
    const payload = "pfx-" ++ dict_content ++ "-u-" ++ unique ++ "-mid-" ++ unique ++ "-rep-" ++ ("ab" ** 16) ++ "-tail";
    const options: vort.ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };

    const full = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(allocator, payload, options, dict);
    defer allocator.free(full.frame);
    const disabled = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(allocator, payload, .{
        .selection = .literal_only,
        .content_checksum = false,
        .match_search_budget = 0,
    }, dict);
    defer allocator.free(disabled.frame);
    const shallow = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(allocator, payload, .{
        .selection = .literal_only,
        .content_checksum = false,
        .match_search_budget = 2,
    }, dict);
    defer allocator.free(shallow.frame);
    const enough = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(allocator, payload, .{
        .selection = .literal_only,
        .content_checksum = false,
        .match_search_budget = 3,
    }, dict);
    defer allocator.free(enough.frame);

    try expect(full.frame.len == enough.frame.len);
    try expect(disabled.frame.len > shallow.frame.len);
    try expect(shallow.frame.len > full.frame.len);
    try expect((try vort.zstdInspectNativeFrameFirstBlock(full.frame)).payload_len <
        (try vort.zstdInspectNativeFrameFirstBlock(disabled.frame)).payload_len);

    const full_decoded = try vort.zstdDecodeNativeFrameAllocWithDictionary(allocator, full.frame, dict);
    defer allocator.free(full_decoded);
    try expectEqualSlices(payload, full_decoded);
    const disabled_decoded = try vort.zstdDecodeNativeFrameAllocWithDictionary(allocator, disabled.frame, dict);
    defer allocator.free(disabled_decoded);
    try expectEqualSlices(payload, disabled_decoded);

    try expectError(error.InvalidBlockPlan, vort.zstdEncodedNativeFrameBoundWithDictionary(payload.len, .{
        .selection = .literal_only,
        .content_checksum = false,
        .match_search_budget = vort.zstdNativeMaxMatchSearchBudget + 1,
    }, dict));
}

fn checkRepeatedBeforeDictionaryMatch(allocator: std.mem.Allocator) !void {
    const dict = vort.ZstdNativeDictionary.init(0x9D, "abcdefghijklmnop");
    const payload = ("ab" ** 80) ++ "-mid-abcdefghijklmnop-tail";
    const options: vort.ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };

    const encoded = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(allocator, payload, options, dict);
    defer allocator.free(encoded.frame);
    const first_block = try vort.zstdInspectNativeFrameFirstBlock(encoded.frame);
    try expect(first_block.block_type == .compressed);
    const decoded = try vort.zstdDecodeNativeFrameAllocWithDictionary(allocator, encoded.frame, dict);
    defer allocator.free(decoded);
    try expectEqualSlices(payload, decoded);
}

fn checkConcatenatedDictionaryApis(allocator: std.mem.Allocator) !void {
    const dict = vort.ZstdNativeDictionary.init(0x88, "shared-history");
    const first_payload = "shared-history one";
    const second_payload = "shared-history two";
    const options: vort.ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };

    const first = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(allocator, first_payload, options, dict);
    defer allocator.free(first.frame);
    const skip = try vort.zstdEncodeSkippableFrameAlloc(allocator, 4, "zstd-dict-metadata");
    defer allocator.free(skip);
    const second = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(allocator, second_payload, options, dict);
    defer allocator.free(second.frame);

    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(allocator);
    try stream.appendSlice(allocator, first.frame);
    try stream.appendSlice(allocator, skip);
    try stream.appendSlice(allocator, second.frame);

    const summary = try vort.zstdSummarizeNativeStream(stream.items);
    try expect(summary.frame_count == 2);
    try expect(summary.skippable_frame_count == 1);
    try expect(summary.skippable_payload_bytes == "zstd-dict-metadata".len);

    var stream_iterator = vort.zstdIterateNativeStream(stream.items);
    const first_element = (try stream_iterator.next()) orelse return error.ZstdNativeDictionaryProbeMismatch;
    const skip_element = (try stream_iterator.next()) orelse return error.ZstdNativeDictionaryProbeMismatch;
    const second_element = (try stream_iterator.next()) orelse return error.ZstdNativeDictionaryProbeMismatch;
    try expect((try stream_iterator.next()) == null);
    switch (first_element) {
        .frame => |frame| try expect(frame.header.dictionary_id == dict.id),
        .skippable => return error.ZstdNativeDictionaryProbeMismatch,
    }
    switch (skip_element) {
        .frame => return error.ZstdNativeDictionaryProbeMismatch,
        .skippable => |skippable| {
            try expect(skippable.header.skippable_id == 4);
            try expectEqualSlices("zstd-dict-metadata", skippable.payload);
        },
    }
    switch (second_element) {
        .frame => |frame| try expect(frame.header.dictionary_id == dict.id),
        .skippable => return error.ZstdNativeDictionaryProbeMismatch,
    }

    const decoded = try vort.zstdDecodeNativeConcatenatedFrameAllocWithDictionary(allocator, stream.items, dict);
    defer allocator.free(decoded);
    try expectEqualSlices(first_payload ++ second_payload, decoded);
    try expect((try vort.zstdDecodedNativeConcatenatedFrameSizeWithDictionary(stream.items, dict)) == decoded.len);

    var into: [first_payload.len + second_payload.len]u8 = undefined;
    const written = try vort.zstdDecodeNativeConcatenatedFrameIntoWithDictionary(stream.items, &into, dict);
    try expect(written == into.len);
    try expectEqualSlices(first_payload ++ second_payload, &into);

    const dictionary_set = vort.ZstdNativeDictionarySet.init(&.{dict});
    const set_bound = try vort.zstdEncodedNativeFrameBoundWithDictionarySet(first_payload.len, options, dictionary_set, dict.id);
    try expect(first.frame.len <= set_bound);
    try expectError(error.NeedDictionary, vort.zstdEncodedNativeFrameBoundWithDictionarySet(first_payload.len, options, dictionary_set, 0xeeee));
    const set_encoded = try vort.zstdEncodeNativeFrameWithDictionarySetAlloc(allocator, first_payload, options, dictionary_set, dict.id);
    defer allocator.free(set_encoded.frame);
    try expect(set_encoded.mode == first.mode);
    try expectEqualSlices(first.frame, set_encoded.frame);
    var set_appended: std.ArrayList(u8) = .empty;
    defer set_appended.deinit(allocator);
    const set_appended_mode = try vort.zstdEncodeNativeFrameAppendWithDictionarySet(allocator, &set_appended, first_payload, options, dictionary_set, dict.id);
    try expect(set_appended_mode == first.mode);
    try expectEqualSlices(first.frame, set_appended.items);
    const set_into = try allocator.alloc(u8, set_bound);
    defer allocator.free(set_into);
    const set_into_result = try vort.zstdEncodeNativeFrameIntoSliceWithDictionarySet(allocator, first_payload, options, dictionary_set, dict.id, set_into);
    try expect(set_into_result.mode == first.mode);
    try expectEqualSlices(first.frame, set_into[0..set_into_result.written]);
    var set_encoder = vort.ZstdNativeFrameEncoder.init(allocator);
    defer set_encoder.deinit();
    const reusable_set_encoded = try set_encoder.encodeWithDictionarySetAlloc(first_payload, options, dictionary_set, dict.id);
    defer allocator.free(reusable_set_encoded.frame);
    try expect(reusable_set_encoded.mode == first.mode);
    try expectEqualSlices(first.frame, reusable_set_encoded.frame);
    const reusable_set_scratch = try set_encoder.encodeScratchWithDictionarySet(first_payload, options, dictionary_set, dict.id);
    try expect(reusable_set_scratch.mode == first.mode);
    try expectEqualSlices(first.frame, reusable_set_scratch.frame);
    const reusable_set_into_result = try set_encoder.encodeIntoSliceWithDictionarySet(first_payload, options, dictionary_set, dict.id, set_into);
    try expect(reusable_set_into_result.mode == first.mode);
    try expectEqualSlices(first.frame, set_into[0..reusable_set_into_result.written]);
    try expectError(error.NeedDictionary, vort.zstdEncodeNativeFrameWithDictionarySetAlloc(allocator, first_payload, options, dictionary_set, 0xeeee));

    const second_start = first.frame.len + skip.len;
    const chunks = [_][]const u8{
        stream.items[0..7],
        stream.items[7 .. first.frame.len + 5],
        stream.items[first.frame.len + 5 .. second_start + second.frame.len / 2],
        stream.items[second_start + second.frame.len / 2 ..],
    };
    const join = try allocator.alloc(u8, stream.items.len);
    defer allocator.free(join);
    var decoder = vort.ZstdNativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    const chunked_exact = try decoder.decodeConcatenatedChunksAllocExactSizeWithDictionarySet(&chunks, join, dictionary_set, decoded.len);
    defer allocator.free(chunked_exact);
    try expectEqualSlices(decoded, chunked_exact);
    const chunked_scratch = try decoder.decodeConcatenatedChunksScratchWithDictionarySet(&chunks, join, dictionary_set);
    try expectEqualSlices(decoded, chunked_scratch);
    var chunked_appended: std.ArrayList(u8) = .empty;
    defer chunked_appended.deinit(allocator);
    try chunked_appended.appendSlice(allocator, "prefix:");
    try expect((try decoder.decodeConcatenatedChunksAppendWithDictionarySet(&chunked_appended, &chunks, join, dictionary_set)) == decoded.len);
    try expectEqualSlices("prefix:", chunked_appended.items[0.."prefix:".len]);
    try expectEqualSlices(decoded, chunked_appended.items["prefix:".len..]);
    const chunked_size = try decoder.decodedConcatenatedChunksSizeWithDictionarySet(&chunks, join, dictionary_set);
    try expect(chunked_size == decoded.len);
    const chunked_limited_size = try decoder.decodedConcatenatedChunksSizeLimitedWithDictionarySet(&chunks, join, decoded.len, dictionary_set);
    try expect(chunked_limited_size == decoded.len);
}

fn checkNoSizeDictionarySetDirectOutput(allocator: std.mem.Allocator) !void {
    const first_dict = vort.ZstdNativeDictionary.init(0x6161, "abcdefghijklmnop");
    const second_dict = vort.ZstdNativeDictionary.init(0x6162, "QRSTUVWXYZabcdef");
    const dictionary_set = vort.ZstdNativeDictionarySet.init(&.{ first_dict, second_dict });
    const first_payload = "pfx-abcdefghijklmnop-nosize-one";
    const second_payload = "pfx-QRSTUVWXYZabcdef-nosize-two";
    const options: vort.ZstdNativeFrameOptions = .{
        .include_content_size = false,
        .selection = .literal_only,
        .content_checksum = true,
    };

    const first = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(allocator, first_payload, options, first_dict);
    defer allocator.free(first.frame);
    const second = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(allocator, second_payload, options, second_dict);
    defer allocator.free(second.frame);
    const skip = try vort.zstdEncodeSkippableFrameAlloc(allocator, 4, "probe-nosize-set-zstd");
    defer allocator.free(skip);

    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(allocator);
    try stream.appendSlice(allocator, first.frame);
    try stream.appendSlice(allocator, skip);
    try stream.appendSlice(allocator, second.frame);

    const summary = try vort.zstdSummarizeNativeStream(stream.items);
    try expect(summary.frame_count == 2);
    try expect(summary.skippable_frame_count == 1);
    try expect(summary.skippable_payload_bytes == "probe-nosize-set-zstd".len);
    var iterator = vort.zstdIterateNativeStream(stream.items);
    const first_element = (try iterator.next()) orelse return error.ZstdNativeDictionaryProbeMismatch;
    const skip_element = (try iterator.next()) orelse return error.ZstdNativeDictionaryProbeMismatch;
    const second_element = (try iterator.next()) orelse return error.ZstdNativeDictionaryProbeMismatch;
    try expect((try iterator.next()) == null);
    switch (first_element) {
        .frame => |frame| try expect(frame.header.dictionary_id == first_dict.id),
        .skippable => return error.ZstdNativeDictionaryProbeMismatch,
    }
    switch (skip_element) {
        .frame => return error.ZstdNativeDictionaryProbeMismatch,
        .skippable => |skippable| {
            try expect(skippable.header.skippable_id == 4);
            try expectEqualSlices("probe-nosize-set-zstd", skippable.payload);
        },
    }
    switch (second_element) {
        .frame => |frame| try expect(frame.header.dictionary_id == second_dict.id),
        .skippable => return error.ZstdNativeDictionaryProbeMismatch,
    }

    const expected = first_payload ++ second_payload;
    const chunks = [_][]const u8{
        stream.items[0..0],
        stream.items[0..9],
        stream.items[9..9],
        stream.items[9 .. first.frame.len + 2],
        stream.items[first.frame.len + 2 .. first.frame.len + skip.len + 4],
        stream.items[first.frame.len + skip.len + 4 ..],
        stream.items[stream.items.len..stream.items.len],
    };
    const join = try allocator.alloc(u8, stream.items.len);
    defer allocator.free(join);
    const short_join = try allocator.alloc(u8, stream.items.len - 1);
    defer allocator.free(short_join);
    var short_join_output: [expected.len]u8 = undefined;
    try expectError(error.OutputTooSmall, vort.zstdDecodeNativeConcatenatedFrameChunksIntoWithDictionarySet(&chunks, short_join, &short_join_output, dictionary_set));
    try expectError(error.OutputTooSmall, vort.zstdDecodedNativeConcatenatedFrameChunksSizeWithDictionarySet(&chunks, short_join, dictionary_set));
    const truncated_chunks = [_][]const u8{stream.items[0 .. stream.items.len - 1]};
    try expectError(error.TruncatedFrame, vort.zstdDecodedNativeConcatenatedFrameChunksSizeWithDictionarySet(&truncated_chunks, join, dictionary_set));
    var chunked_output: [expected.len]u8 = undefined;
    const chunked_written = try vort.zstdDecodeNativeConcatenatedFrameChunksIntoWithDictionarySet(&chunks, join, &chunked_output, dictionary_set);
    try expect(chunked_written == expected.len);
    try expectEqualSlices(expected, &chunked_output);
    const chunked_exact = try vort.zstdDecodeNativeConcatenatedFrameChunksAllocWithDictionarySetExactSize(allocator, &chunks, join, dictionary_set, expected.len);
    defer allocator.free(chunked_exact);
    try expectEqualSlices(expected, chunked_exact);
    try expectError(error.SizeMismatch, vort.zstdDecodeNativeConcatenatedFrameChunksAllocWithDictionarySetExactSize(allocator, &chunks, join, dictionary_set, expected.len - 1));
    const chunked_limited = try vort.zstdDecodeNativeConcatenatedFrameChunksAllocWithDictionarySetLimited(allocator, &chunks, join, dictionary_set, expected.len);
    defer allocator.free(chunked_limited);
    try expectEqualSlices(expected, chunked_limited);
    try expectError(error.OutputLimitExceeded, vort.zstdDecodeNativeConcatenatedFrameChunksAllocWithDictionarySetLimited(allocator, &chunks, join, dictionary_set, expected.len - 1));
    var chunked_appended: std.ArrayList(u8) = .empty;
    defer chunked_appended.deinit(allocator);
    try chunked_appended.appendSlice(allocator, "prefix:");
    const chunked_appended_written = try vort.zstdDecodeNativeConcatenatedFrameChunksAppendExactSizeWithDictionarySet(allocator, &chunked_appended, &chunks, join, dictionary_set, expected.len);
    try expect(chunked_appended_written == expected.len);
    try expectEqualSlices("prefix:", chunked_appended.items[0.."prefix:".len]);
    try expectEqualSlices(expected, chunked_appended.items["prefix:".len..]);
    chunked_appended.clearRetainingCapacity();
    try expectError(error.SizeMismatch, vort.zstdDecodeNativeConcatenatedFrameChunksAppendExactSizeWithDictionarySet(allocator, &chunked_appended, &chunks, join, dictionary_set, expected.len - 1));
    try expectError(error.OutputLimitExceeded, vort.zstdDecodeNativeConcatenatedFrameChunksAppendLimitedWithDictionarySet(allocator, &chunked_appended, &chunks, join, expected.len - 1, dictionary_set));

    var reusable_decoder = vort.ZstdNativeFrameDecoder.init(allocator);
    defer reusable_decoder.deinit();
    const reusable_exact = try reusable_decoder.decodeConcatenatedChunksAllocExactSizeWithDictionarySet(&chunks, join, dictionary_set, expected.len);
    defer allocator.free(reusable_exact);
    try expectEqualSlices(expected, reusable_exact);
    try expectError(error.SizeMismatch, reusable_decoder.decodeConcatenatedChunksAllocExactSizeWithDictionarySet(&chunks, join, dictionary_set, expected.len - 1));
    const reusable_limited = try reusable_decoder.decodeConcatenatedChunksAllocLimitedWithDictionarySet(&chunks, join, expected.len, dictionary_set);
    defer allocator.free(reusable_limited);
    try expectEqualSlices(expected, reusable_limited);
    try expectError(error.OutputLimitExceeded, reusable_decoder.decodeConcatenatedChunksAllocLimitedWithDictionarySet(&chunks, join, expected.len - 1, dictionary_set));
    const reusable_scratch = try reusable_decoder.decodeConcatenatedChunksScratchLimitedWithDictionarySet(&chunks, join, expected.len, dictionary_set);
    try expectEqualSlices(expected, reusable_scratch);
    try expectError(error.OutputLimitExceeded, reusable_decoder.decodeConcatenatedChunksScratchLimitedWithDictionarySet(&chunks, join, expected.len - 1, dictionary_set));
    var reusable_appended: std.ArrayList(u8) = .empty;
    defer reusable_appended.deinit(allocator);
    try reusable_appended.appendSlice(allocator, "prefix:");
    const reusable_appended_written = try reusable_decoder.decodeConcatenatedChunksAppendExactSizeWithDictionarySet(&reusable_appended, &chunks, join, dictionary_set, expected.len);
    try expect(reusable_appended_written == expected.len);
    try expectEqualSlices("prefix:", reusable_appended.items[0.."prefix:".len]);
    try expectEqualSlices(expected, reusable_appended.items["prefix:".len..]);
    reusable_appended.clearRetainingCapacity();
    try expectError(error.SizeMismatch, reusable_decoder.decodeConcatenatedChunksAppendExactSizeWithDictionarySet(&reusable_appended, &chunks, join, dictionary_set, expected.len - 1));
    try expectError(error.OutputLimitExceeded, reusable_decoder.decodeConcatenatedChunksAppendLimitedWithDictionarySet(&reusable_appended, &chunks, join, expected.len - 1, dictionary_set));

    const missing_set = vort.ZstdNativeDictionarySet.init(&.{first_dict});
    try expectError(error.NeedDictionary, vort.zstdDecodedNativeConcatenatedFrameSizeWithDictionarySet(stream.items, missing_set));
    try expectError(error.NeedDictionary, vort.zstdDecodedNativeConcatenatedFrameSizeLimitedWithDictionarySet(stream.items, expected.len, missing_set));
    var missing_output: [expected.len]u8 = undefined;
    try expectError(error.NeedDictionary, vort.zstdDecodeNativeConcatenatedFrameIntoWithDictionarySet(stream.items, &missing_output, missing_set));
    try expectAllocError(allocator, error.NeedDictionary, vort.zstdDecodeNativeConcatenatedFrameAllocWithDictionarySet(allocator, stream.items, missing_set));
    try expectAllocError(allocator, error.NeedDictionary, vort.zstdDecodeNativeConcatenatedFrameAllocWithDictionarySetExactSize(allocator, stream.items, missing_set, expected.len));
    try expectAllocError(allocator, error.NeedDictionary, vort.zstdDecodeNativeConcatenatedFrameAllocLimitedWithDictionarySet(allocator, stream.items, expected.len, missing_set));
    try expectError(error.NeedDictionary, vort.zstdDecodedNativeConcatenatedFrameChunksSizeWithDictionarySet(&chunks, join, missing_set));
    try expectError(error.NeedDictionary, vort.zstdDecodeNativeConcatenatedFrameChunksIntoWithDictionarySet(&chunks, join, &missing_output, missing_set));
    try expectAllocError(allocator, error.NeedDictionary, vort.zstdDecodeNativeConcatenatedFrameChunksAllocWithDictionarySet(allocator, &chunks, join, missing_set));
    try expectError(error.NeedDictionary, reusable_decoder.decodeConcatenatedChunksAllocWithDictionarySet(&chunks, join, missing_set));
    try expectError(error.NeedDictionary, reusable_decoder.decodeConcatenatedChunksScratchWithDictionarySet(&chunks, join, missing_set));
    reusable_appended.clearRetainingCapacity();
    try expectError(error.NeedDictionary, reusable_decoder.decodeConcatenatedChunksAppendWithDictionarySet(&reusable_appended, &chunks, join, missing_set));

    var decoder = vort.ZstdNativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(allocator, dictionary_set, .{
        .expected_output_len = expected.len,
        .max_decoded_buffer_len = @max(first_payload.len, second_payload.len),
    });
    defer decoder.deinit();
    var output: [expected.len]u8 = undefined;
    const initial = try decoder.step(stream.items, output[0..0]);
    try expect(initial.status == .need_output);
    try expectEqualSlices("direct_output", decoder.diagnostics().phase_name);
    try expect(decoder.snapshot().decoded_len.? == first_payload.len);
    const done = try decoder.step("", &output);
    try expect(done.status == .done);
    try expectEqualSlices(expected, &output);
    try decoder.finish();
}

fn checkDictionaryDirectFallback(allocator: std.mem.Allocator) !void {
    const dict = vort.ZstdNativeDictionary.init(0x6261, "abcdefghijklmnop");
    const payload = "pfx-abcdefghijklmnop-small-output-tail";
    const encoded = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(allocator, payload, .{
        .selection = .literal_only,
        .content_checksum = false,
    }, dict);
    defer allocator.free(encoded.frame);

    var decoder = vort.ZstdNativeIncrementalFrameDecoder.initWithDictionaryAndOptions(allocator, dict, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    const initial = try decoder.step(encoded.frame, output[0..0]);
    try expect(initial.status == .need_output);
    try expectEqualSlices("direct_output", decoder.diagnostics().phase_name);
    const partial = try decoder.step("", output[0..5]);
    try expect(partial.status == .need_output);
    try expect(partial.progress.output_written == 5);
    try expect(decoder.decoded_scratch.items.len == payload.len);
    const done = try decoder.step("", output[5..]);
    try expect(done.status == .done);
    try expectEqualSlices(payload, &output);
}

fn checkDictionarySetDirectFallback(allocator: std.mem.Allocator) !void {
    const dict = vort.ZstdNativeDictionary.init(0x6361, "abcdefghijklmnop");
    const other = vort.ZstdNativeDictionary.init(0x6362, "QRSTUVWXYZabcdef");
    const dictionary_set = vort.ZstdNativeDictionarySet.init(&.{ dict, other });
    const payload = "pfx-abcdefghijklmnop-set-small-output-tail";
    const encoded = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(allocator, payload, .{
        .selection = .literal_only,
        .content_checksum = false,
    }, dict);
    defer allocator.free(encoded.frame);

    var decoder = vort.ZstdNativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(allocator, dictionary_set, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    const initial = try decoder.step(encoded.frame, output[0..0]);
    try expect(initial.status == .need_output);
    try expectEqualSlices("direct_output", decoder.diagnostics().phase_name);
    const partial = try decoder.step("", output[0..5]);
    try expect(partial.status == .need_output);
    try expect(partial.progress.output_written == 5);
    try expect(decoder.decoded_scratch.items.len == payload.len);
    const done = try decoder.step("", output[5..]);
    try expect(done.status == .done);
    try expectEqualSlices(payload, &output);
}

fn expect(ok: bool) !void {
    if (!ok) return error.ZstdNativeDictionaryProbeMismatch;
}

fn expectEqualSlices(expected: []const u8, actual: []const u8) !void {
    if (!std.mem.eql(u8, expected, actual)) return error.ZstdNativeDictionaryProbeMismatch;
}

fn expectError(expected: anyerror, result: anytype) !void {
    if (result) |_| {
        return error.ZstdNativeDictionaryProbeExpectedError;
    } else |err| {
        if (err != expected) return err;
    }
}

fn expectAllocError(allocator: std.mem.Allocator, expected: anyerror, result: anytype) !void {
    if (result) |decoded| {
        allocator.free(decoded);
        return error.ZstdNativeDictionaryProbeExpectedError;
    } else |err| {
        if (err != expected) return err;
    }
}
