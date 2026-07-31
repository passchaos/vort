const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var stdout_buffer: [256]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    var checked: usize = 0;
    try checkDictionaryIdValidation(init.gpa);
    checked += 1;
    try checkDictionaryMatchEncoding(init.gpa);
    checked += 1;
    try checkDictionarySequenceHuffmanLiterals(init.gpa);
    checked += 1;
    try checkDictionaryHighByteSequenceHuffmanLiterals(init.gpa);
    checked += 1;
    try checkCompressedSequenceTableInspect(init.gpa);
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
    try stdout.flush();
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
    try expectError(error.NeedDictionary, vort.zstdDecodeNativeFrameAllocWithDictionary(allocator, encoded, wrong));

    const decoded = try vort.zstdDecodeNativeFrameAllocWithDictionary(allocator, encoded, dict);
    defer allocator.free(decoded);
    try expectEqualSlices(payload, decoded);
    try expect((try vort.zstdDecodedNativeFrameSizeWithDictionary(encoded, dict)) == payload.len);
    try expectError(error.OutputLimitExceeded, vort.zstdDecodedNativeFrameSizeLimitedWithDictionary(encoded, payload.len - 1, dict));
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
        stream.items[0..9],
        stream.items[9 .. first.frame.len + 2],
        stream.items[first.frame.len + 2 .. first.frame.len + skip.len + 4],
        stream.items[first.frame.len + skip.len + 4 ..],
    };
    const join = try allocator.alloc(u8, stream.items.len);
    defer allocator.free(join);
    const short_join = try allocator.alloc(u8, stream.items.len - 1);
    defer allocator.free(short_join);
    var short_join_output: [expected.len]u8 = undefined;
    try expectError(error.OutputTooSmall, vort.zstdDecodeNativeConcatenatedFrameChunksIntoWithDictionarySet(&chunks, short_join, &short_join_output, dictionary_set));
    try expectError(error.OutputTooSmall, vort.zstdDecodedNativeConcatenatedFrameChunksSizeWithDictionarySet(&chunks, short_join, dictionary_set));
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
