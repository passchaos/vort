const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var stdout_buffer: [256]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    var checked: usize = 0;
    try checkDictionaryIdValidation(init.gpa);
    checked += 1;
    try checkSingleFrameDictionaryApis(init.gpa);
    checked += 1;
    try checkIndependentBlocksReuseDictionary(init.gpa);
    checked += 1;
    try checkConcatenatedDictionaryApis(init.gpa);
    checked += 1;
    try checkReusableDictionaryApis(init.gpa);
    checked += 1;
    try checkNoSizeDictionarySetDirectOutput(init.gpa);
    checked += 1;
    try checkDictionaryDirectFallback(init.gpa);
    checked += 1;
    try checkDictionarySetDirectFallback(init.gpa);
    checked += 1;

    try stdout.print("lz4_native_dictionary_probe_ok cases={d}\n", .{checked});
    try stdout.flush();
}

fn checkDictionaryIdValidation(allocator: std.mem.Allocator) !void {
    const dict = vort.Lz4NativeDictionary.init(0x1234_abcd, "abcdefghijklmnop");
    const wrong = vort.Lz4NativeDictionary.init(0x4321, dict.content);
    const payload = "abcdefghijklmnop-validation";

    const encoded = try vort.lz4EncodeNativeFrameWithDictionaryAlloc(allocator, payload, .{
        .content_checksum = false,
        .block_checksum = true,
    }, dict);
    defer allocator.free(encoded);

    const header = try vort.lz4InspectNativeFrameHeader(encoded);
    try expect(header.dictionary_id == dict.id);
    try expectError(error.NeedDictionary, vort.lz4DecodeNativeFrameAlloc(allocator, encoded));
    try expectError(error.NeedDictionary, vort.lz4DecodeNativeFrameAllocWithDictionary(allocator, encoded, wrong));

    const decoded = try vort.lz4DecodeNativeFrameAllocWithDictionary(allocator, encoded, dict);
    defer allocator.free(decoded);
    try expectEqualSlices(payload, decoded);
}

fn checkSingleFrameDictionaryApis(allocator: std.mem.Allocator) !void {
    const dict = vort.Lz4NativeDictionary.init(0x55aa, "previous lz4 history");
    const payload = "previous lz4 history payload";
    const options: vort.Lz4NativeFrameOptions = .{
        .content_checksum = false,
        .block_checksum = true,
    };

    const encoded = try vort.lz4EncodeNativeFrameWithDictionaryAlloc(allocator, payload, options, dict);
    defer allocator.free(encoded);
    const first_block = (try vort.lz4InspectNativeFrameFirstBlock(encoded)) orelse return error.Lz4NativeDictionaryProbeMismatch;
    try expect(first_block.is_compressed);
    try expect((try vort.lz4DecodedNativeFrameSizeWithDictionary(encoded, dict)) == payload.len);

    var into: [payload.len]u8 = undefined;
    const into_written = try vort.lz4DecodeNativeFrameIntoWithDictionary(encoded, &into, dict);
    try expect(into_written == payload.len);
    try expectEqualSlices(payload, &into);
    try expectError(error.OutputTooSmall, vort.lz4DecodeNativeFrameIntoWithDictionary(encoded, into[0 .. into.len - 1], dict));

    var out = try allocator.alloc(u8, try vort.lz4EncodedNativeFrameBoundWithDictionary(payload.len, options, dict));
    defer allocator.free(out);
    const written = try vort.lz4EncodeNativeFrameIntoSliceWithDictionary(allocator, payload, options, dict, out);
    try expectEqualSlices(encoded, out[0..written]);
}

fn checkIndependentBlocksReuseDictionary(allocator: std.mem.Allocator) !void {
    const dict = vort.Lz4NativeDictionary.init(0x7777, "abcdefghijklmnop");
    const first_block = try allocator.alloc(u8, 64 * 1024);
    defer allocator.free(first_block);
    @memset(first_block, 'x');
    const tail = "abcdefghijklmnop-tail-block";
    const payload = try allocator.alloc(u8, first_block.len + tail.len);
    defer allocator.free(payload);
    @memcpy(payload[0..first_block.len], first_block);
    @memcpy(payload[first_block.len..], tail);

    const encoded = try vort.lz4EncodeNativeFrameWithDictionaryAlloc(allocator, payload, .{
        .content_checksum = false,
        .block_checksum = true,
        .block_size_id = .max64kb,
        .block_mode = .independent,
    }, dict);
    defer allocator.free(encoded);
    var blocks = try vort.lz4IterateNativeFrameBlocks(encoded);
    _ = (try blocks.next()) orelse return error.Lz4NativeDictionaryProbeMismatch;
    const second = (try blocks.next()) orelse return error.Lz4NativeDictionaryProbeMismatch;
    try expect(second.is_compressed);

    const decoded = try vort.lz4DecodeNativeFrameAllocWithDictionary(allocator, encoded, dict);
    defer allocator.free(decoded);
    try expectEqualSlices(payload, decoded);
}

fn checkConcatenatedDictionaryApis(allocator: std.mem.Allocator) !void {
    const dict = vort.Lz4NativeDictionary.init(0x8888, "abcdefghijklmnop");
    const first_payload = "abcdefghijklmnop-one";
    const second_payload = "abcdefghijklmnop-two";
    const options: vort.Lz4NativeFrameOptions = .{
        .content_checksum = false,
        .block_checksum = true,
    };
    const first = try vort.lz4EncodeNativeFrameWithDictionaryAlloc(allocator, first_payload, options, dict);
    defer allocator.free(first);
    const second = try vort.lz4EncodeNativeFrameWithDictionaryAlloc(allocator, second_payload, options, dict);
    defer allocator.free(second);

    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(allocator);
    try stream.appendSlice(allocator, first);
    try stream.appendSlice(allocator, second);

    const expected = first_payload ++ second_payload;
    const decoded = try vort.lz4DecodeNativeConcatenatedFrameAllocWithDictionary(allocator, stream.items, dict);
    defer allocator.free(decoded);
    try expectEqualSlices(expected, decoded);
    try expect((try vort.lz4DecodedNativeConcatenatedFrameSizeWithDictionary(stream.items, dict)) == expected.len);

    var into: [expected.len]u8 = undefined;
    const written = try vort.lz4DecodeNativeConcatenatedFrameIntoWithDictionary(stream.items, &into, dict);
    try expect(written == expected.len);
    try expectEqualSlices(expected, &into);

    const dictionary_set = vort.Lz4NativeDictionarySet.init(&.{dict});
    const set_bound = try vort.lz4EncodedNativeFrameBoundWithDictionarySet(first_payload.len, options, dictionary_set, dict.id);
    try expect(first.len <= set_bound);
    try expectError(error.NeedDictionary, vort.lz4EncodedNativeFrameBoundWithDictionarySet(first_payload.len, options, dictionary_set, 0xeeee));
}

fn checkReusableDictionaryApis(allocator: std.mem.Allocator) !void {
    const dict = vort.Lz4NativeDictionary.init(0x9999, "prefix-history");
    const payload = "prefix-history suffix";
    const options: vort.Lz4NativeFrameOptions = .{
        .content_checksum = false,
        .block_checksum = true,
    };

    var encoder = try vort.Lz4NativeFrameEncoder.init(allocator);
    defer encoder.deinit();
    const encoded = try encoder.encodeScratchWithDictionary(payload, options, dict);

    var decoder = vort.Lz4NativeFrameDecoder.init(allocator);
    defer decoder.deinit();
    const decoded = try decoder.decodeScratchWithDictionary(encoded, dict);
    try expectEqualSlices(payload, decoded);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    const appended_written = try decoder.decodeAppendWithDictionary(&appended, encoded, dict);
    try expect(appended_written == payload.len);
    try expectEqualSlices("prefix:" ++ payload, appended.items);
}

fn checkNoSizeDictionarySetDirectOutput(allocator: std.mem.Allocator) !void {
    const first_dict = vort.Lz4NativeDictionary.init(0x5151, "abcdefghijklmnop");
    const second_dict = vort.Lz4NativeDictionary.init(0x5152, "QRSTUVWXYZabcdef");
    const dictionary_set = vort.Lz4NativeDictionarySet.init(&.{ first_dict, second_dict });
    const first_payload = "abcdefghijklmnop-nosize-one";
    const second_payload = "QRSTUVWXYZabcdef-nosize-two";
    const options: vort.Lz4NativeFrameOptions = .{
        .include_content_size = false,
        .content_checksum = true,
        .block_checksum = true,
    };

    const first = try vort.lz4EncodeNativeFrameWithDictionaryAlloc(allocator, first_payload, options, first_dict);
    defer allocator.free(first);
    const second = try vort.lz4EncodeNativeFrameWithDictionaryAlloc(allocator, second_payload, options, second_dict);
    defer allocator.free(second);
    const skip = try vort.lz4EncodeSkippableFrameAlloc(allocator, 4, "probe-nosize-set-lz4");
    defer allocator.free(skip);

    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(allocator);
    try stream.appendSlice(allocator, first);
    try stream.appendSlice(allocator, skip);
    try stream.appendSlice(allocator, second);

    const expected = first_payload ++ second_payload;
    var decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(allocator, dictionary_set, .{
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
    const dict = vort.Lz4NativeDictionary.init(0x5251, "abcdefghijklmnop");
    const payload = "abcdefghijklmnop-small-output-tail";
    const encoded = try vort.lz4EncodeNativeFrameWithDictionaryAlloc(allocator, payload, .{
        .content_checksum = false,
        .block_checksum = true,
    }, dict);
    defer allocator.free(encoded);

    var decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithDictionaryAndOptions(allocator, dict, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    const initial = try decoder.step(encoded, output[0..0]);
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
    const dict = vort.Lz4NativeDictionary.init(0x5351, "abcdefghijklmnop");
    const other = vort.Lz4NativeDictionary.init(0x5352, "QRSTUVWXYZabcdef");
    const dictionary_set = vort.Lz4NativeDictionarySet.init(&.{ dict, other });
    const payload = "abcdefghijklmnop-set-small-output-tail";
    const encoded = try vort.lz4EncodeNativeFrameWithDictionaryAlloc(allocator, payload, .{
        .content_checksum = false,
        .block_checksum = true,
    }, dict);
    defer allocator.free(encoded);

    var decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(allocator, dictionary_set, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    const initial = try decoder.step(encoded, output[0..0]);
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
    if (!ok) return error.Lz4NativeDictionaryProbeMismatch;
}

fn expectEqualSlices(expected: []const u8, actual: []const u8) !void {
    if (!std.mem.eql(u8, expected, actual)) return error.Lz4NativeDictionaryProbeMismatch;
}

fn expectError(expected: anyerror, result: anytype) !void {
    if (result) |_| {
        return error.Lz4NativeDictionaryProbeExpectedError;
    } else |err| {
        if (err != expected) return err;
    }
}
