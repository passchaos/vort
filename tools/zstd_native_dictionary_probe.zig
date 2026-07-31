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
    checked += try checkHandcraftedFrameValidation(init.gpa);

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
    const second = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(allocator, second_payload, options, dict);
    defer allocator.free(second.frame);

    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(allocator);
    try stream.appendSlice(allocator, first.frame);
    try stream.appendSlice(allocator, second.frame);

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

    const chunks = [_][]const u8{
        stream.items[0..7],
        stream.items[7 .. stream.items.len - 4],
        stream.items[stream.items.len - 4 ..],
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

    const expected = first_payload ++ second_payload;
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

fn checkHandcraftedFrameValidation(allocator: std.mem.Allocator) !usize {
    var checked: usize = 0;

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
    if (claimed_len > std.compress.zstd.block_size_max) return error.ZstdNativeDictionaryProbeMismatch;
    const block_header_value: u32 = (@as(u32, @intCast(claimed_len)) << 3) | 1;
    try frame.append(allocator, @truncate(block_header_value));
    try frame.append(allocator, @truncate(block_header_value >> 8));
    try frame.append(allocator, @truncate(block_header_value >> 16));
    try frame.appendSlice(allocator, payload);
    try frame.appendSlice(allocator, trailing);
    return try frame.toOwnedSlice(allocator);
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

fn expectStreamIteratorError(frame: []const u8, expected: anyerror) !void {
    var iterator = vort.zstdIterateNativeStream(frame);
    if (iterator.next()) |_| {
        return error.ZstdNativeDictionaryProbeExpectedError;
    } else |err| {
        if (err != expected) return err;
    }
}
