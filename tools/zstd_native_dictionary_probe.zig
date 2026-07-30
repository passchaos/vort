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
    try checkRepeatedBeforeDictionaryMatch(init.gpa);
    checked += 1;
    try checkConcatenatedDictionaryApis(init.gpa);
    checked += 1;
    try checkNoSizeDictionarySetDirectOutput(init.gpa);
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

    const bound = try vort.zstdEncodedNativeFrameBoundWithOptions(payload.len, .{
        .selection = .literal_only,
        .content_checksum = false,
        .dictionary_id = dict.id,
    });
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
