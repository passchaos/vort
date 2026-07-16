const std = @import("std");
const vort = @import("vort");

const CaseStats = struct {
    name: []const u8,
    input_bytes: usize,
    output_bytes: usize,
    allocations: usize,
    deallocations: usize,
    allocated_bytes: usize,
    freed_bytes: usize,
};

const dictionary_deflate_dict = "dictionary deflate validation phrase";
const dictionary_deflate_input = (dictionary_deflate_dict ++ " -- payload ") ** 2;

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    var json_path: ?[]const u8 = null;
    var markdown_path: ?[]const u8 = null;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--json")) {
            json_path = args.next() orelse return error.MissingReportPath;
            continue;
        }
        if (std.mem.eql(u8, arg, "--markdown")) {
            markdown_path = args.next() orelse return error.MissingReportPath;
            continue;
        }
        return error.UnknownArgument;
    }

    const allocator = init.gpa;
    const deflate_rle_stream = try buildDeflateRleStream(allocator);
    defer allocator.free(deflate_rle_stream);
    const indexed_deflate_stream = try buildIndexedDeflateStream(allocator);
    defer allocator.free(indexed_deflate_stream);
    const indexed_store_stream = try buildIndexedStoreStream(allocator);
    defer allocator.free(indexed_store_stream);
    const dict_stream = try buildEmbeddedDictionaryPatchStream(allocator);
    defer allocator.free(dict_stream);
    const dict_indexed_stream = try buildDictionaryPatchIndexedStream(allocator);
    defer allocator.free(dict_indexed_stream);
    const dict_deflate_indexed_stream = try buildDictionaryDeflateIndexedStream(allocator);
    defer allocator.free(dict_deflate_indexed_stream);
    const embedded_dict_deflate_stream = try buildEmbeddedDictionaryDeflateIndexedStream(allocator);
    defer allocator.free(embedded_dict_deflate_stream);
    const self_contained_dict_stream = try vort.storeEncodeSelfContainedDictionaryStreamAlloc(
        allocator,
        ("self-contained dictionary phrase for native streams" ++ "!") ** 3,
        "self-contained dictionary phrase for native streams".len + 1,
        256,
        8,
    );
    defer allocator.free(self_contained_dict_stream);

    var rows: std.ArrayList(CaseStats) = .empty;
    defer rows.deinit(allocator);
    try rows.append(allocator, try measureConcatAlloc(allocator, deflate_rle_stream));
    try rows.append(allocator, try measureConcatInto(allocator, deflate_rle_stream));
    try rows.append(allocator, try measureConcatAutoInto(allocator, dict_stream));
    try rows.append(allocator, try measureLimitedReject(allocator, deflate_rle_stream));
    try rows.append(allocator, try measureAnyDecoderCompressed(allocator));
    try rows.append(allocator, try measureAnyDecoderDictionaryDeflate(allocator));
    try rows.append(allocator, try measureZlibDecoderPngLike(allocator));
    try rows.append(allocator, try measureZlibDecoderPngLikeChunks(allocator));
    try rows.append(allocator, try measureZlibDecoderPngLikeVariedChunks(allocator));
    try rows.append(allocator, try measureZlibDecoderPngScanlines(allocator));
    try rows.append(allocator, try measureZlibDecoderPngReconstruct(allocator));
    try rows.append(allocator, try measureZlibDecoderDictionaryChunks(allocator));
    try rows.append(allocator, try measureGzipDecoderScratch(allocator));
    try rows.append(allocator, try measureGzipDecoderConcatenatedChunks(allocator));
    try rows.append(allocator, try measureRangeAlloc(allocator, indexed_deflate_stream));
    try rows.append(allocator, try measureRangeInto(allocator, indexed_deflate_stream));
    try rows.append(allocator, try measureRangeIntoWithIndexBuffer(allocator, indexed_deflate_stream));
    try rows.append(allocator, try measureDeflatePartialRangeIntoWithScratch(allocator, indexed_deflate_stream));
    try rows.append(allocator, try measureSidecarDeflatePartialRangeIntoWithScratch(allocator));
    try rows.append(allocator, try measureBatchRangeInto(allocator, indexed_deflate_stream));
    try rows.append(allocator, try measureBatchRangeIntoWithIndexBuffer(allocator, indexed_deflate_stream));
    try rows.append(allocator, try measureDictionaryRangeIntoWithIndexBuffer(allocator, dict_indexed_stream));
    try rows.append(allocator, try measureDictionaryDeflateRangeIntoWithPatchScratch(allocator, dict_deflate_indexed_stream));
    try rows.append(allocator, try measureDictionaryDeflatePartialRangeIntoWithScratch(allocator, dict_deflate_indexed_stream));
    try rows.append(allocator, try measureEmbeddedDictionaryDeflateAutoRangeIntoWithBuffers(allocator, embedded_dict_deflate_stream));
    try rows.append(allocator, try measureEmbeddedDictionaryDeflateSelfRangeIntoWithBuffers(allocator, embedded_dict_deflate_stream));
    try rows.append(allocator, try measureLongDistancePartialRangeIntoWithScratch(allocator));
    try rows.append(allocator, try measureSidecarLongDistancePartialRangeIntoWithScratch(allocator));
    try rows.append(allocator, try measureEmbeddedValidation(allocator, self_contained_dict_stream));
    try rows.append(allocator, try measureEmbeddedValidationWithBuffers(allocator, indexed_store_stream));
    try rows.append(allocator, try measureEmbeddedValidationReportWithBuffers(allocator, indexed_store_stream));
    try rows.append(allocator, try measureEmbeddedCompressedValidationWithBuffers(allocator, indexed_deflate_stream));
    try rows.append(allocator, try measureEmbeddedCompressedValidationReportWithBuffers(allocator, indexed_deflate_stream));
    try rows.append(allocator, try measureSidecarCompressedValidationWithBuffers(allocator));
    try rows.append(allocator, try measureSidecarCompressedValidationReportWithBuffers(allocator));
    try rows.append(allocator, try measureEmbeddedLdmValidationWithBuffers(allocator));
    try rows.append(allocator, try measureSidecarLdmValidationWithBuffers(allocator));
    try rows.append(allocator, try measureDictionaryDeflateValidationWithBuffers(allocator, dict_deflate_indexed_stream));
    try rows.append(allocator, try measureDictionaryDeflateValidationReportWithBuffers(allocator, dict_deflate_indexed_stream));

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("case,input_bytes,output_bytes,allocations,deallocations,allocated_bytes,freed_bytes\n", .{});
    for (rows.items) |row| try printStats(stdout, row);
    try stdout.flush();

    if (json_path) |path| try writeJson(init, path, rows.items);
    if (markdown_path) |path| try writeMarkdown(init, path, rows.items);
}

fn printStats(writer: *std.Io.Writer, row: CaseStats) !void {
    try writer.print("{s},{d},{d},{d},{d},{d},{d}\n", .{
        row.name,
        row.input_bytes,
        row.output_bytes,
        row.allocations,
        row.deallocations,
        row.allocated_bytes,
        row.freed_bytes,
    });
}

fn writeJson(init: std.process.Init, path: []const u8, rows: []const CaseStats) !void {
    var writer = std.Io.Writer.Allocating.init(init.gpa);
    defer writer.deinit();
    const w = &writer.writer;
    try w.print(
        "{{\n  \"schema\": \"vort.native_allocation_report\",\n  \"schema_version\": 1,\n  \"case_count\": {d},\n  \"cases\": [\n",
        .{rows.len},
    );
    for (rows, 0..) |row, i| {
        try w.print(
            "    {{\"case\": ",
            .{},
        );
        try std.json.Stringify.value(row.name, .{}, w);
        try w.print(
            ", \"input_bytes\": {d}, \"output_bytes\": {d}, \"allocations\": {d}, \"deallocations\": {d}, \"allocated_bytes\": {d}, \"freed_bytes\": {d}}}{s}\n",
            .{
                row.input_bytes,
                row.output_bytes,
                row.allocations,
                row.deallocations,
                row.allocated_bytes,
                row.freed_bytes,
                if (i + 1 == rows.len) "" else ",",
            },
        );
    }
    try w.print("  ]\n}}\n", .{});
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = writer.written() });
}

fn writeMarkdown(init: std.process.Init, path: []const u8, rows: []const CaseStats) !void {
    var writer = std.Io.Writer.Allocating.init(init.gpa);
    defer writer.deinit();
    const w = &writer.writer;
    try w.print(
        \\# Native allocation report
        \\
        \\| case | input bytes | output bytes | allocations | deallocations | allocated bytes | freed bytes |
        \\| --- | ---: | ---: | ---: | ---: | ---: | ---: |
        \\
    , .{});
    for (rows) |row| {
        try w.print("| {s} | {d} | {d} | {d} | {d} | {d} | {d} |\n", .{
            row.name,
            row.input_bytes,
            row.output_bytes,
            row.allocations,
            row.deallocations,
            row.allocated_bytes,
            row.freed_bytes,
        });
    }
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = writer.written() });
}

fn buildDeflateRleStream(allocator: std.mem.Allocator) ![]u8 {
    const first = "hello hello hello hello";
    const second = "aaaaabbbbbbbbbbbbbcccccccc";
    const first_frame = try vort.storeEncodeDeflateAlloc(allocator, first);
    defer allocator.free(first_frame);
    const second_frame = try vort.storeEncodeRleAlloc(allocator, second);
    defer allocator.free(second_frame);
    var stream = std.ArrayList(u8).empty;
    errdefer stream.deinit(allocator);
    try stream.appendSlice(allocator, first_frame);
    try stream.appendSlice(allocator, second_frame);
    return stream.toOwnedSlice(allocator);
}

fn buildEmbeddedDictionaryPatchStream(allocator: std.mem.Allocator) ![]u8 {
    const dict = "alpha beta gamma";
    const payload = try embeddedDictionaryPayloadAlloc(allocator, dict);
    defer allocator.free(payload);
    const dict_frame = try vort.storeEncodeSkippableAlloc(allocator, payload);
    defer allocator.free(dict_frame);
    const data_frame = try vort.storeEncodeDictionaryPatchAlloc(allocator, dict, "alpha beta", 5);
    defer allocator.free(data_frame);
    var stream = std.ArrayList(u8).empty;
    errdefer stream.deinit(allocator);
    try stream.appendSlice(allocator, dict_frame);
    try stream.appendSlice(allocator, data_frame);
    return stream.toOwnedSlice(allocator);
}

fn buildIndexedDeflateStream(allocator: std.mem.Allocator) ![]u8 {
    const payloads = [_][]const u8{
        "hello hello hello hello",
        "bye bye bye bye bye",
    };
    return vort.storeEncodeIndexedDeflateStreamAlloc(allocator, &payloads);
}

fn buildIndexedStoreStream(allocator: std.mem.Allocator) ![]u8 {
    const payloads = [_][]const u8{ "alpha", "beta", "gamma" };
    return vort.storeEncodeIndexedStreamAlloc(allocator, &payloads);
}

fn buildDictionaryPatchIndexedStream(allocator: std.mem.Allocator) ![]u8 {
    const dict = "alpha beta gamma";
    const input = "zz alpha beta yy gamma";
    const frame = try vort.storeEncodeDictionaryPatchAlloc(allocator, dict, input, 5);
    defer allocator.free(frame);
    const index = try vort.storeBuildFrameIndexAlloc(allocator, frame);
    defer allocator.free(index);
    const index_bytes = try vort.storeEncodeFrameIndexAlloc(allocator, index);
    defer allocator.free(index_bytes);
    const index_frame = try vort.storeEncodeSkippableAlloc(allocator, index_bytes);
    defer allocator.free(index_frame);
    var stream = std.ArrayList(u8).empty;
    errdefer stream.deinit(allocator);
    try stream.appendSlice(allocator, frame);
    try stream.appendSlice(allocator, index_frame);
    return stream.toOwnedSlice(allocator);
}

fn buildDictionaryDeflateIndexedStream(allocator: std.mem.Allocator) ![]u8 {
    const frame = try vort.storeEncodeDictionaryDeflateAlloc(allocator, dictionary_deflate_dict, dictionary_deflate_input, 8);
    defer allocator.free(frame);
    const index = try vort.storeBuildFrameIndexAlloc(allocator, frame);
    defer allocator.free(index);
    const index_bytes = try vort.storeEncodeFrameIndexAlloc(allocator, index);
    defer allocator.free(index_bytes);
    const index_frame = try vort.storeEncodeSkippableAlloc(allocator, index_bytes);
    defer allocator.free(index_frame);
    var stream = std.ArrayList(u8).empty;
    errdefer stream.deinit(allocator);
    try stream.appendSlice(allocator, frame);
    try stream.appendSlice(allocator, index_frame);
    return stream.toOwnedSlice(allocator);
}

fn buildEmbeddedDictionaryDeflateIndexedStream(allocator: std.mem.Allocator) ![]u8 {
    const dict_payload = try embeddedDictionaryPayloadAlloc(allocator, dictionary_deflate_dict);
    defer allocator.free(dict_payload);
    const dict_frame = try vort.storeEncodeSkippableAlloc(allocator, dict_payload);
    defer allocator.free(dict_frame);
    const data_frame = try vort.storeEncodeDictionaryDeflateAlloc(allocator, dictionary_deflate_dict, dictionary_deflate_input, 8);
    defer allocator.free(data_frame);
    var stream_without_index = std.ArrayList(u8).empty;
    defer stream_without_index.deinit(allocator);
    try stream_without_index.appendSlice(allocator, dict_frame);
    try stream_without_index.appendSlice(allocator, data_frame);
    const index = try vort.storeBuildFrameIndexAlloc(allocator, stream_without_index.items);
    defer allocator.free(index);
    const index_bytes = try vort.storeEncodeFrameIndexAlloc(allocator, index);
    defer allocator.free(index_bytes);
    const index_frame = try vort.storeEncodeSkippableAlloc(allocator, index_bytes);
    defer allocator.free(index_frame);
    var stream = std.ArrayList(u8).empty;
    errdefer stream.deinit(allocator);
    try stream.appendSlice(allocator, stream_without_index.items);
    try stream.appendSlice(allocator, index_frame);
    return stream.toOwnedSlice(allocator);
}

fn embeddedDictionaryPayloadAlloc(allocator: std.mem.Allocator, dict: []const u8) ![]u8 {
    const header_len = 20;
    const out = try allocator.alloc(u8, header_len + dict.len);
    errdefer allocator.free(out);
    @memcpy(out[0..4], "VDIC");
    const id = vort.DictionaryId.fromBytes(dict);
    std.mem.writeInt(u64, out[4..12], id.asInt(), .little);
    std.mem.writeInt(u32, out[12..16], @intCast(dict.len), .little);
    std.mem.writeInt(u32, out[16..20], 0, .little);
    @memcpy(out[header_len..], dict);
    return out;
}

fn measureConcatAlloc(backing: std.mem.Allocator, stream: []const u8) !CaseStats {
    var failing = std.testing.FailingAllocator.init(backing, .{});
    const allocator = failing.allocator();
    const decoded = try vort.storeDecodeConcatenatedAlloc(allocator, stream);
    const output_len = decoded.len;
    allocator.free(decoded);
    return stats("concat_alloc", stream.len, output_len, failing);
}

fn measureConcatInto(backing: std.mem.Allocator, stream: []const u8) !CaseStats {
    const summary = try vort.storeInspectConcatenated(stream);
    const output_len = std.math.cast(usize, summary.total_uncompressed) orelse return error.IntegerOverflow;
    const out = try backing.alloc(u8, output_len);
    defer backing.free(out);
    var failing = std.testing.FailingAllocator.init(backing, .{});
    const result = try vort.storeDecodeConcatenatedInto(failing.allocator(), stream, out);
    return stats("concat_into", stream.len, result.output_written, failing);
}

fn measureConcatAutoInto(backing: std.mem.Allocator, stream: []const u8) !CaseStats {
    const summary = try vort.storeInspectConcatenated(stream);
    const output_len = std.math.cast(usize, summary.total_uncompressed) orelse return error.IntegerOverflow;
    const out = try backing.alloc(u8, output_len);
    defer backing.free(out);
    var failing = std.testing.FailingAllocator.init(backing, .{});
    const result = try vort.storeDecodeConcatenatedAutoInto(failing.allocator(), stream, out);
    return stats("concat_auto_into_embedded_dict", stream.len, result.output_written, failing);
}

fn measureLimitedReject(backing: std.mem.Allocator, stream: []const u8) !CaseStats {
    var failing = std.testing.FailingAllocator.init(backing, .{});
    const summary = try vort.storeInspectConcatenated(stream);
    const output_len = std.math.cast(usize, summary.total_uncompressed) orelse return error.IntegerOverflow;
    try std.testing.expectError(error.OutputLimitExceeded, vort.storeDecodeConcatenatedAllocLimited(failing.allocator(), stream, output_len - 1));
    return stats("concat_limited_reject", stream.len, 0, failing);
}

fn measureAnyDecoderCompressed(backing: std.mem.Allocator) !CaseStats {
    const input = "hello hello hello hello";
    const frame = try vort.storeEncodeDeflateAlloc(backing, input);
    defer backing.free(frame);
    const scratch = try backing.alloc(u8, input.len);
    defer backing.free(scratch);
    var out: [input.len]u8 = undefined;
    const failing = std.testing.FailingAllocator.init(backing, .{});
    var decoder = try vort.StoreAnyDecoder.init(frame, scratch);
    const result = try decoder.step(&out);
    try std.testing.expectEqual(out.len, result.progress.output_written);
    return stats("any_decoder_compressed_scratch", frame.len, result.progress.output_written, failing);
}

fn measureAnyDecoderDictionaryDeflate(backing: std.mem.Allocator) !CaseStats {
    const frame = try vort.storeEncodeDictionaryDeflateAlloc(backing, dictionary_deflate_dict, dictionary_deflate_input, 8);
    defer backing.free(frame);
    const payload_scratch = try backing.alloc(u8, dictionary_deflate_input.len);
    defer backing.free(payload_scratch);
    const patch_scratch = try backing.alloc(u8, try vort.maxDictionaryPatchSizeForDecodedLen(dictionary_deflate_input.len));
    defer backing.free(patch_scratch);
    const out = try backing.alloc(u8, dictionary_deflate_input.len);
    defer backing.free(out);
    const failing = std.testing.FailingAllocator.init(backing, .{});
    var decoder = try vort.StoreAnyDecoder.initWithDictionary(frame, dictionary_deflate_dict, .{
        .payload_scratch = payload_scratch,
        .patch_scratch = patch_scratch,
    });
    const result = try decoder.step(out);
    try std.testing.expectEqual(out.len, result.progress.output_written);
    return stats("any_decoder_dictionary_deflate_scratch", frame.len, result.progress.output_written, failing);
}

const png_like_varied_len: usize = 1020;

fn pngLikeVariedIdatFixture() [png_like_varied_len]u8 {
    const widths = [_]usize{ 1, 2, 8, 17 };
    const channels = [_]usize{ 3, 4 };
    const filters = [_]u8{ 0, 1, 2, 3, 4 };
    var out: [png_like_varied_len]u8 = undefined;
    var offset: usize = 0;
    for (filters) |filter| {
        for (channels) |channel_count| {
            for (widths) |width| {
                out[offset] = filter;
                offset += 1;
                const row_len = width * channel_count;
                for (0..row_len) |i| {
                    const value = @as(u32, filter) * 37 + @as(u32, @intCast(channel_count)) * 19 + @as(u32, @intCast(width)) * 11 + @as(u32, @intCast(i)) * 7;
                    out[offset] = @truncate(value);
                    offset += 1;
                }
            }
        }
    }
    std.debug.assert(offset == out.len);
    return out;
}

fn pngLikeIdatFixture() [150]u8 {
    return .{
        // RGB rows: filter byte + 4 pixels * 3 bytes.
        0,    0xff, 0x00, 0x00, 0xff, 0x00, 0xff, 0x00, 0x40, 0x80, 0xc0, 0x20, 0x60,
        1,    0x00, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x7f, 0x80, 0x81, 0xfe, 0xff,
        2,    0x05, 0x05, 0x05, 0x10, 0x10, 0x10, 0x20, 0x21, 0x22, 0x30, 0x31, 0x32,
        3,    0x01, 0x03, 0x06, 0x0a, 0x0f, 0x15, 0x1c, 0x24, 0x2d, 0x37, 0x42, 0x4e,
        4,    0x90, 0x80, 0x70, 0x60, 0x50, 0x40, 0x30, 0x20, 0x10, 0x08, 0x04, 0x02,
        // RGBA rows: filter byte + 4 pixels * 4 bytes.
        0,    0x00, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0x80, 0x00, 0xff, 0x00, 0x80,
        0x00, 0x00, 0xff, 0x80, 1,    0x03, 0x06, 0x09, 0x0c, 0x0f, 0x12, 0x15, 0x18,
        0x1b, 0x1e, 0x21, 0x24, 0x27, 0x2a, 0x2d, 0x30, 2,    0xf0, 0xe0, 0xd0, 0xc0,
        0xb0, 0xa0, 0x90, 0x80, 0x70, 0x60, 0x50, 0x40, 0x30, 0x20, 0x10, 0x00, 3,
        0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd,
        0xee, 0xff, 0x10, 4,    0x7f, 0x80, 0x81, 0x82, 0x40, 0x41, 0x42, 0x43, 0x20,
        0x21, 0x22, 0x23, 0x10, 0x11, 0x12, 0x13,
    };
}

fn pngReconstructionRow(comptime row_len: usize, row_index: usize) [row_len]u8 {
    var row: [row_len]u8 = undefined;
    for (&row, 0..) |*byte, i| {
        const value = @as(u32, @intCast(row_index)) * 29 + @as(u32, @intCast(i)) * 17 + @as(u32, @intCast(i / 3)) * 11;
        byte.* = @truncate(value);
    }
    return row;
}

fn pngPaethPredictorForReport(left: u8, up: u8, up_left: u8) u8 {
    const a: i32 = left;
    const b: i32 = up;
    const c: i32 = up_left;
    const p = a + b - c;
    const pa = if (p - a < 0) -(p - a) else p - a;
    const pb = if (p - b < 0) -(p - b) else p - b;
    const pc = if (p - c < 0) -(p - c) else p - c;
    if (pa <= pb and pa <= pc) return left;
    if (pb <= pc) return up;
    return up_left;
}

fn filterPngScanlineForReport(filter: u8, row: []const u8, previous: ?[]const u8, bytes_per_pixel: usize, filtered: []u8) void {
    std.debug.assert(filtered.len == row.len);
    for (row, 0..) |pixel, i| {
        const left: u8 = if (i >= bytes_per_pixel) row[i - bytes_per_pixel] else 0;
        const up: u8 = if (previous) |prev| prev[i] else 0;
        const up_left: u8 = if (i >= bytes_per_pixel) blk: {
            if (previous) |prev| break :blk prev[i - bytes_per_pixel];
            break :blk 0;
        } else 0;
        const prediction: u8 = switch (filter) {
            0 => 0,
            1 => left,
            2 => up,
            3 => @intCast((@as(u16, left) + @as(u16, up)) / 2),
            4 => pngPaethPredictorForReport(left, up, up_left),
            else => unreachable,
        };
        filtered[i] = pixel -% prediction;
    }
}

fn measureZlibDecoderPngLike(backing: std.mem.Allocator) !CaseStats {
    const png_like = pngLikeIdatFixture();
    const encoded = try vort.encodeZlibBestAlloc(backing, &png_like, vort.deflate.optionsForLevel(.default));
    defer backing.free(encoded);
    const scratch = try backing.alloc(u8, png_like.len);
    defer backing.free(scratch);
    const out = try backing.alloc(u8, png_like.len);
    defer backing.free(out);
    const failing = std.testing.FailingAllocator.init(backing, .{});
    var decoder = try vort.ZlibDecoder.init(encoded, scratch);
    const result = try decoder.step(out);
    try std.testing.expectEqual(out.len, result.progress.output_written);
    return stats("zlib_decoder_png_like_scratch", encoded.len, result.progress.output_written, failing);
}

fn measureZlibDecoderPngLikeChunks(backing: std.mem.Allocator) !CaseStats {
    const png_like = pngLikeIdatFixture();
    const encoded = try vort.encodeZlibBestAlloc(backing, &png_like, vort.deflate.optionsForLevel(.default));
    defer backing.free(encoded);
    const chunks = [_][]const u8{
        encoded[0..5],
        encoded[5 .. encoded.len - 3],
        encoded[encoded.len - 3 ..],
    };
    const compressed_scratch = try backing.alloc(u8, encoded.len);
    defer backing.free(compressed_scratch);
    const output_scratch = try backing.alloc(u8, png_like.len);
    defer backing.free(output_scratch);
    const out = try backing.alloc(u8, png_like.len);
    defer backing.free(out);
    const failing = std.testing.FailingAllocator.init(backing, .{});
    var decoder = try vort.ZlibDecoder.initFromChunksExactSize(&chunks, compressed_scratch, output_scratch, png_like.len);
    const result = try decoder.step(out);
    try std.testing.expectEqual(out.len, result.progress.output_written);
    return stats("zlib_decoder_png_like_chunks_scratch", encoded.len, result.progress.output_written, failing);
}

fn measureZlibDecoderPngLikeVariedChunks(backing: std.mem.Allocator) !CaseStats {
    const png_like = pngLikeVariedIdatFixture();
    const encoded = try vort.encodeZlibBestAlloc(backing, &png_like, vort.deflate.optionsForLevel(.default));
    defer backing.free(encoded);
    const chunks = [_][]const u8{
        encoded[0..7],
        encoded[7 .. encoded.len / 2],
        encoded[encoded.len / 2 .. encoded.len - 5],
        encoded[encoded.len - 5 ..],
    };
    const compressed_scratch = try backing.alloc(u8, encoded.len);
    defer backing.free(compressed_scratch);
    const output_scratch = try backing.alloc(u8, png_like.len);
    defer backing.free(output_scratch);
    const out = try backing.alloc(u8, png_like.len);
    defer backing.free(out);
    const failing = std.testing.FailingAllocator.init(backing, .{});
    var decoder = try vort.ZlibDecoder.initFromChunksExactSize(&chunks, compressed_scratch, output_scratch, png_like.len);
    const result = try decoder.step(out);
    try std.testing.expectEqual(out.len, result.progress.output_written);
    return stats("zlib_decoder_png_varied_chunks_scratch", encoded.len, result.progress.output_written, failing);
}

fn measureZlibDecoderPngScanlines(backing: std.mem.Allocator) !CaseStats {
    const png_like = pngLikeVariedIdatFixture();
    const encoded = try vort.encodeZlibBestAlloc(backing, &png_like, vort.deflate.optionsForLevel(.default));
    defer backing.free(encoded);
    const chunks = [_][]const u8{
        encoded[0..7],
        encoded[7 .. encoded.len / 2],
        encoded[encoded.len / 2 .. encoded.len - 5],
        encoded[encoded.len - 5 ..],
    };
    const compressed_scratch = try backing.alloc(u8, encoded.len);
    defer backing.free(compressed_scratch);
    const output_scratch = try backing.alloc(u8, png_like.len);
    defer backing.free(output_scratch);
    const row = try backing.alloc(u8, 17 * 4);
    defer backing.free(row);

    const failing = std.testing.FailingAllocator.init(backing, .{});
    var decoder = try vort.ZlibDecoder.initFromChunksExactSize(&chunks, compressed_scratch, output_scratch, png_like.len);
    const widths = [_]usize{ 1, 2, 8, 17 };
    const channels = [_]usize{ 3, 4 };
    const filters = [_]u8{ 0, 1, 2, 3, 4 };
    var output_bytes: usize = 0;
    for (filters) |filter| {
        for (channels) |channel_count| {
            for (widths) |width| {
                const row_len = width * channel_count;
                const result = try decoder.stepPngScanline(row[0..row_len]);
                try std.testing.expectEqual(filter, result.filter.?);
                output_bytes += result.progress.output_written;
            }
        }
    }
    try std.testing.expect(decoder.snapshot().done);
    return stats("zlib_decoder_png_scanline_scratch", encoded.len, output_bytes, failing);
}

fn measureZlibDecoderPngReconstruct(backing: std.mem.Allocator) !CaseStats {
    const bpp = 3;
    const row_len = 12;
    const row_count = 5;
    var rows: [row_count][row_len]u8 = undefined;
    var filtered_payload: [row_count * (row_len + 1)]u8 = undefined;
    var payload_offset: usize = 0;
    var previous: ?[]const u8 = null;
    for (0..row_count) |row_index| {
        rows[row_index] = pngReconstructionRow(row_len, row_index);
        const filter: u8 = @intCast(row_index);
        filtered_payload[payload_offset] = filter;
        filterPngScanlineForReport(filter, &rows[row_index], previous, bpp, filtered_payload[payload_offset + 1 ..][0..row_len]);
        previous = &rows[row_index];
        payload_offset += row_len + 1;
    }

    const encoded = try vort.encodeZlibBestAlloc(backing, &filtered_payload, vort.deflate.optionsForLevel(.default));
    defer backing.free(encoded);
    const chunks = [_][]const u8{
        encoded[0..5],
        encoded[5 .. encoded.len - 4],
        encoded[encoded.len - 4 ..],
    };
    const compressed_scratch = try backing.alloc(u8, encoded.len);
    defer backing.free(compressed_scratch);
    const decode_scratch = try backing.alloc(u8, filtered_payload.len);
    defer backing.free(decode_scratch);
    const filtered_row = try backing.alloc(u8, row_len);
    defer backing.free(filtered_row);
    const previous_row = try backing.alloc(u8, row_len);
    defer backing.free(previous_row);
    const output = try backing.alloc(u8, row_len);
    defer backing.free(output);

    const failing = std.testing.FailingAllocator.init(backing, .{});
    var decoder = try vort.ZlibDecoder.initFromChunksExactSize(&chunks, compressed_scratch, decode_scratch, filtered_payload.len);
    var previous_row_slice: ?[]const u8 = null;
    var output_bytes: usize = 0;
    for (0..row_count) |row_index| {
        const result = try decoder.stepPngScanlineReconstruct(filtered_row, previous_row_slice, bpp, output);
        try std.testing.expectEqual(@as(u8, @intCast(row_index)), result.filter.?);
        try std.testing.expectEqualSlices(u8, &rows[row_index], output);
        output_bytes += result.progress.output_written;
        @memcpy(previous_row, output);
        previous_row_slice = previous_row;
    }
    try std.testing.expect(decoder.snapshot().done);
    return stats("zlib_decoder_png_reconstruct_scratch", encoded.len, output_bytes, failing);
}

fn measureZlibDecoderDictionaryChunks(backing: std.mem.Allocator) !CaseStats {
    const dict = "hello ";
    const input = "hello hello hello";
    const encoded = try vort.encodeZlibBestWithDictionaryAlloc(backing, input, dict, vort.deflate.optionsForLevel(.default));
    defer backing.free(encoded);
    const chunks = [_][]const u8{
        encoded[0..6],
        encoded[6 .. encoded.len - 2],
        encoded[encoded.len - 2 ..],
    };
    const compressed_scratch = try backing.alloc(u8, encoded.len);
    defer backing.free(compressed_scratch);
    const output_scratch = try backing.alloc(u8, input.len);
    defer backing.free(output_scratch);
    const out = try backing.alloc(u8, input.len);
    defer backing.free(out);
    const failing = std.testing.FailingAllocator.init(backing, .{});
    var decoder = try vort.ZlibDecoder.initFromChunksWithDictionaryExactSize(&chunks, dict, compressed_scratch, output_scratch, input.len);
    const result = try decoder.step(out);
    try std.testing.expectEqual(out.len, result.progress.output_written);
    return stats("zlib_decoder_dictionary_chunks_scratch", encoded.len, result.progress.output_written, failing);
}

fn measureGzipDecoderScratch(backing: std.mem.Allocator) !CaseStats {
    const input = "gzip bounded decoder payload";
    const encoded = try vort.encodeGzipBestAlloc(backing, input, vort.deflate.optionsForLevel(.default));
    defer backing.free(encoded);
    const scratch = try backing.alloc(u8, input.len);
    defer backing.free(scratch);
    const compressed_scratch = try backing.alloc(u8, encoded.len);
    defer backing.free(compressed_scratch);
    const out = try backing.alloc(u8, input.len);
    defer backing.free(out);
    const chunks = [_][]const u8{
        encoded[0..4],
        encoded[4 .. encoded.len - 8],
        encoded[encoded.len - 8 ..],
    };
    const failing = std.testing.FailingAllocator.init(backing, .{});
    var decoder = try vort.GzipDecoder.initFromChunksExactSize(&chunks, compressed_scratch, scratch, input.len);
    const result = try decoder.step(out);
    try std.testing.expectEqual(out.len, result.progress.output_written);
    return stats("gzip_decoder_scratch", encoded.len, result.progress.output_written, failing);
}

fn measureGzipDecoderConcatenatedChunks(backing: std.mem.Allocator) !CaseStats {
    const plain = "hello world";
    const first = try vort.encodeGzipFixedAlloc(backing, "hello ");
    defer backing.free(first);
    const empty = try vort.encodeGzipFixedAlloc(backing, "");
    defer backing.free(empty);
    const third = try vort.encodeGzipFixedAlloc(backing, "world");
    defer backing.free(third);
    const total = first.len + empty.len + third.len;
    const encoded = try backing.alloc(u8, total);
    defer backing.free(encoded);
    var offset: usize = 0;
    @memcpy(encoded[offset..][0..first.len], first);
    offset += first.len;
    @memcpy(encoded[offset..][0..empty.len], empty);
    offset += empty.len;
    @memcpy(encoded[offset..][0..third.len], third);

    const chunks = [_][]const u8{
        encoded[0 .. first.len - 1],
        encoded[first.len - 1 .. first.len + empty.len + 2],
        encoded[first.len + empty.len + 2 ..],
    };
    const scratch = try backing.alloc(u8, plain.len);
    defer backing.free(scratch);
    const compressed_scratch = try backing.alloc(u8, encoded.len);
    defer backing.free(compressed_scratch);
    const out = try backing.alloc(u8, plain.len);
    defer backing.free(out);
    const failing = std.testing.FailingAllocator.init(backing, .{});
    var decoder = try vort.GzipDecoder.initConcatenatedFromChunksExactSize(&chunks, compressed_scratch, scratch, plain.len);
    const result = try decoder.step(out);
    try std.testing.expectEqual(out.len, result.progress.output_written);
    try std.testing.expectEqualSlices(u8, plain, out);
    return stats("gzip_decoder_concatenated_chunks_scratch", encoded.len, result.progress.output_written, failing);
}

fn measureRangeAlloc(backing: std.mem.Allocator, stream: []const u8) !CaseStats {
    var failing = std.testing.FailingAllocator.init(backing, .{});
    const decoded = try vort.storeDecodeIndexedRangeAlloc(failing.allocator(), stream, 0, "hello hello hello hello".len);
    const output_len = decoded.len;
    failing.allocator().free(decoded);
    return stats("indexed_range_alloc_full_deflate", stream.len, output_len, failing);
}

fn measureRangeInto(backing: std.mem.Allocator, stream: []const u8) !CaseStats {
    const first_len = "hello hello hello hello".len;
    const out = try backing.alloc(u8, first_len);
    defer backing.free(out);
    var failing = std.testing.FailingAllocator.init(backing, .{});
    const result = try vort.storeDecodeIndexedRangeInto(failing.allocator(), stream, 0, first_len, out);
    return stats("indexed_range_into_full_deflate", stream.len, result.output_written, failing);
}

fn measureRangeIntoWithIndexBuffer(backing: std.mem.Allocator, stream: []const u8) !CaseStats {
    const first_len = "hello hello hello hello".len;
    const out = try backing.alloc(u8, first_len);
    defer backing.free(out);
    const view = try vort.storeViewEmbeddedIndex(stream);
    const index = try backing.alloc(vort.store.FrameIndexEntry, view.entry_count);
    defer backing.free(index);
    var failing = std.testing.FailingAllocator.init(backing, .{});
    const result = try vort.storeDecodeIndexedRangeIntoWithIndexBuffer(failing.allocator(), stream, 0, first_len, out, index);
    return stats("indexed_range_into_index_buffer", stream.len, result.output_written, failing);
}

fn measureDeflatePartialRangeIntoWithScratch(backing: std.mem.Allocator, stream: []const u8) !CaseStats {
    const range_offset = 3;
    const range_len = 5;
    const out = try backing.alloc(u8, range_len);
    defer backing.free(out);
    const sizes = try vort.storeRangeBufferSizesForEmbeddedIndex(stream);
    const index_buffer = try backing.alloc(vort.store.FrameIndexEntry, sizes.index_entries);
    defer backing.free(index_buffer);
    const payload_scratch = try backing.alloc(u8, sizes.payload_scratch_len);
    defer backing.free(payload_scratch);
    var failing = std.testing.FailingAllocator.init(backing, .{});
    const result = try vort.storeDecodeIndexedRangeIntoWithBuffers(failing.allocator(), stream, range_offset, out.len, out, .{
        .index_buffer = index_buffer,
        .payload_scratch = payload_scratch,
    });
    return stats("indexed_partial_range_into_scratch", stream.len, result.output_written, failing);
}

fn measureSidecarDeflatePartialRangeIntoWithScratch(backing: std.mem.Allocator) !CaseStats {
    const input = "hello hello hello hello";
    const frame = try vort.storeEncodeDeflateAlloc(backing, input);
    defer backing.free(frame);
    const index = try vort.storeBuildFrameIndexAlloc(backing, frame);
    defer backing.free(index);
    const sidecar = try vort.storeEncodeFrameIndexAlloc(backing, index);
    defer backing.free(sidecar);
    const range_offset = 3;
    const range_len = 5;
    const out = try backing.alloc(u8, range_len);
    defer backing.free(out);
    const sizes = try vort.storeRangeBufferSizesForSidecarIndex(sidecar);
    const index_buffer = try backing.alloc(vort.store.FrameIndexEntry, sizes.index_entries);
    defer backing.free(index_buffer);
    const payload_scratch = try backing.alloc(u8, sizes.payload_scratch_len);
    defer backing.free(payload_scratch);
    var failing = std.testing.FailingAllocator.init(backing, .{});
    const result = try vort.storeDecodeSidecarIndexedRangeIntoWithBuffers(failing.allocator(), frame, sidecar, range_offset, out.len, out, .{
        .index_buffer = index_buffer,
        .payload_scratch = payload_scratch,
    });
    return stats("sidecar_partial_range_into_scratch", frame.len + sidecar.len, result.output_written, failing);
}

fn measureBatchRangeInto(backing: std.mem.Allocator, stream: []const u8) !CaseStats {
    const index = try vort.storeBuildFrameIndexAlloc(backing, stream);
    defer backing.free(index);
    const first_len = std.math.cast(usize, index[0].uncompressed_len) orelse return error.IntegerOverflow;
    const second_len = std.math.cast(usize, index[1].uncompressed_len) orelse return error.IntegerOverflow;
    const first = try backing.alloc(u8, first_len);
    defer backing.free(first);
    const second = try backing.alloc(u8, second_len);
    defer backing.free(second);
    var results: [2]vort.StoreRangeDecodeIntoResult = undefined;
    var failing = std.testing.FailingAllocator.init(backing, .{});
    try vort.storeDecodeIndexedRangesInto(failing.allocator(), stream, &.{
        .{ .offset = 0, .length = first_len, .output = first },
        .{ .offset = index[1].uncompressed_offset, .length = second_len, .output = second },
    }, results[0..]);
    return stats("batch_range_into_fast_paths", stream.len, results[0].output_written + results[1].output_written, failing);
}

fn measureBatchRangeIntoWithIndexBuffer(backing: std.mem.Allocator, stream: []const u8) !CaseStats {
    const index = try vort.storeBuildFrameIndexAlloc(backing, stream);
    defer backing.free(index);
    const first_len = std.math.cast(usize, index[0].uncompressed_len) orelse return error.IntegerOverflow;
    const second_len = std.math.cast(usize, index[1].uncompressed_len) orelse return error.IntegerOverflow;
    const first = try backing.alloc(u8, first_len);
    defer backing.free(first);
    const second = try backing.alloc(u8, second_len);
    defer backing.free(second);
    const view = try vort.storeViewEmbeddedIndex(stream);
    const index_buffer = try backing.alloc(vort.store.FrameIndexEntry, view.entry_count);
    defer backing.free(index_buffer);
    var results: [2]vort.StoreRangeDecodeIntoResult = undefined;
    var failing = std.testing.FailingAllocator.init(backing, .{});
    try vort.storeDecodeIndexedRangesIntoWithIndexBuffer(failing.allocator(), stream, &.{
        .{ .offset = 0, .length = first_len, .output = first },
        .{ .offset = index[1].uncompressed_offset, .length = second_len, .output = second },
    }, results[0..], index_buffer);
    return stats("batch_range_into_index_buffer", stream.len, results[0].output_written + results[1].output_written, failing);
}

fn measureDictionaryRangeIntoWithIndexBuffer(backing: std.mem.Allocator, stream: []const u8) !CaseStats {
    const dict = "alpha beta gamma";
    const input = "zz alpha beta yy gamma";
    const out = try backing.alloc(u8, input.len);
    defer backing.free(out);
    const view = try vort.storeViewEmbeddedIndex(stream);
    const index_buffer = try backing.alloc(vort.store.FrameIndexEntry, view.entry_count);
    defer backing.free(index_buffer);
    var failing = std.testing.FailingAllocator.init(backing, .{});
    const result = try vort.storeDecodeIndexedRangeWithDictionaryIntoWithIndexBuffer(failing.allocator(), dict, stream, 0, out.len, out, index_buffer);
    return stats("dictionary_range_into_index_buffer", stream.len, result.output_written, failing);
}

fn measureDictionaryDeflateRangeIntoWithPatchScratch(backing: std.mem.Allocator, stream: []const u8) !CaseStats {
    const out = try backing.alloc(u8, dictionary_deflate_input.len);
    defer backing.free(out);
    const sizes = try vort.storeDictionaryRangeBufferSizesForEmbeddedIndex(stream);
    const index_buffer = try backing.alloc(vort.store.FrameIndexEntry, sizes.index_entries);
    defer backing.free(index_buffer);
    const patch_scratch = try backing.alloc(u8, sizes.patch_scratch_len);
    defer backing.free(patch_scratch);
    var failing = std.testing.FailingAllocator.init(backing, .{});
    const result = try vort.storeDecodeIndexedRangeWithDictionaryIntoWithBuffers(failing.allocator(), dictionary_deflate_dict, stream, 0, out.len, out, .{ .index_buffer = index_buffer, .patch_scratch = patch_scratch });
    return stats("dictionary_deflate_range_into_patch_scratch", stream.len, result.output_written, failing);
}

fn measureDictionaryDeflatePartialRangeIntoWithScratch(backing: std.mem.Allocator, stream: []const u8) !CaseStats {
    const range_offset = 9;
    const range_len = 32;
    const out = try backing.alloc(u8, range_len);
    defer backing.free(out);
    const sizes = try vort.storeDictionaryRangeBufferSizesForEmbeddedIndex(stream);
    const index_buffer = try backing.alloc(vort.store.FrameIndexEntry, sizes.index_entries);
    defer backing.free(index_buffer);
    const payload_scratch = try backing.alloc(u8, sizes.payload_scratch_len);
    defer backing.free(payload_scratch);
    const patch_scratch = try backing.alloc(u8, sizes.patch_scratch_len);
    defer backing.free(patch_scratch);
    var failing = std.testing.FailingAllocator.init(backing, .{});
    const result = try vort.storeDecodeIndexedRangeWithDictionaryIntoWithBuffers(failing.allocator(), dictionary_deflate_dict, stream, range_offset, out.len, out, .{
        .index_buffer = index_buffer,
        .payload_scratch = payload_scratch,
        .patch_scratch = patch_scratch,
    });
    return stats("dictionary_deflate_partial_range_into_scratch", stream.len, result.output_written, failing);
}

fn measureEmbeddedDictionaryDeflateAutoRangeIntoWithBuffers(backing: std.mem.Allocator, stream: []const u8) !CaseStats {
    const range_offset = 9;
    const range_len = 32;
    const out = try backing.alloc(u8, range_len);
    defer backing.free(out);
    const sizes = try vort.storeDictionaryRangeBufferSizesForEmbeddedIndex(stream);
    const index_buffer = try backing.alloc(vort.store.FrameIndexEntry, sizes.index_entries);
    defer backing.free(index_buffer);
    const payload_scratch = try backing.alloc(u8, sizes.payload_scratch_len);
    defer backing.free(payload_scratch);
    const patch_scratch = try backing.alloc(u8, sizes.patch_scratch_len);
    defer backing.free(patch_scratch);
    var failing = std.testing.FailingAllocator.init(backing, .{});
    const result = try vort.storeDecodeIndexedRangeAutoIntoWithBuffers(failing.allocator(), stream, range_offset, out.len, out, .{
        .index_buffer = index_buffer,
        .payload_scratch = payload_scratch,
        .patch_scratch = patch_scratch,
    });
    return stats("dictionary_deflate_auto_range_into_buffers", stream.len, result.output_written, failing);
}

fn measureEmbeddedDictionaryDeflateSelfRangeIntoWithBuffers(backing: std.mem.Allocator, stream: []const u8) !CaseStats {
    const range_offset = 9;
    const range_len = 32;
    const out = try backing.alloc(u8, range_len);
    defer backing.free(out);
    const sizes = try vort.storeDictionaryRangeBufferSizesForEmbeddedIndex(stream);
    const index_buffer = try backing.alloc(vort.store.FrameIndexEntry, sizes.index_entries);
    defer backing.free(index_buffer);
    const payload_scratch = try backing.alloc(u8, sizes.payload_scratch_len);
    defer backing.free(payload_scratch);
    const patch_scratch = try backing.alloc(u8, sizes.patch_scratch_len);
    defer backing.free(patch_scratch);
    var failing = std.testing.FailingAllocator.init(backing, .{});
    const result = try vort.storeDecodeSelfContainedDictionaryRangeIntoWithBuffers(failing.allocator(), stream, range_offset, out.len, out, .{
        .index_buffer = index_buffer,
        .payload_scratch = payload_scratch,
        .patch_scratch = patch_scratch,
    });
    return stats("dictionary_deflate_self_range_into_buffers", stream.len, result.output_written, failing);
}

fn measureLongDistancePartialRangeIntoWithScratch(backing: std.mem.Allocator) !CaseStats {
    const prefix = deterministicLdmPrefix();
    const input = prefix ++ "----" ++ prefix[0..1024].*;
    const frame = try vort.storeEncodeLongDistanceAlloc(backing, input, .{ .min_distance = 32769, .min_length = 16 });
    defer backing.free(frame);
    const index = try vort.storeBuildFrameIndexAlloc(backing, frame);
    defer backing.free(index);
    const index_bytes = try vort.storeEncodeFrameIndexAlloc(backing, index);
    defer backing.free(index_bytes);
    const index_frame = try vort.storeEncodeSkippableAlloc(backing, index_bytes);
    defer backing.free(index_frame);
    var stream = std.ArrayList(u8).empty;
    defer stream.deinit(backing);
    try stream.appendSlice(backing, frame);
    try stream.appendSlice(backing, index_frame);

    const range_offset = prefix.len + 4;
    const range_len = 16;
    const out = try backing.alloc(u8, range_len);
    defer backing.free(out);
    const sizes = try vort.storeRangeBufferSizesForEmbeddedIndex(stream.items);
    const index_buffer = try backing.alloc(vort.store.FrameIndexEntry, sizes.index_entries);
    defer backing.free(index_buffer);
    const payload_scratch = try backing.alloc(u8, sizes.payload_scratch_len);
    defer backing.free(payload_scratch);
    var failing = std.testing.FailingAllocator.init(backing, .{});
    const result = try vort.storeDecodeIndexedRangeIntoWithBuffers(failing.allocator(), stream.items, range_offset, out.len, out, .{
        .index_buffer = index_buffer,
        .payload_scratch = payload_scratch,
    });
    return stats("ldm_partial_range_into_scratch", stream.items.len, result.output_written, failing);
}

fn measureSidecarLongDistancePartialRangeIntoWithScratch(backing: std.mem.Allocator) !CaseStats {
    const prefix = deterministicLdmPrefix();
    const input = prefix ++ "----" ++ prefix[0..1024].*;
    const frame = try vort.storeEncodeLongDistanceAlloc(backing, input, .{ .min_distance = 32769, .min_length = 16 });
    defer backing.free(frame);
    const index = try vort.storeBuildFrameIndexAlloc(backing, frame);
    defer backing.free(index);
    const sidecar = try vort.storeEncodeFrameIndexAlloc(backing, index);
    defer backing.free(sidecar);
    const range_offset = prefix.len + 4;
    const range_len = 16;
    const out = try backing.alloc(u8, range_len);
    defer backing.free(out);
    const sizes = try vort.storeRangeBufferSizesForSidecarIndex(sidecar);
    const index_buffer = try backing.alloc(vort.store.FrameIndexEntry, sizes.index_entries);
    defer backing.free(index_buffer);
    const payload_scratch = try backing.alloc(u8, sizes.payload_scratch_len);
    defer backing.free(payload_scratch);
    var failing = std.testing.FailingAllocator.init(backing, .{});
    const result = try vort.storeDecodeSidecarIndexedRangeIntoWithBuffers(failing.allocator(), frame, sidecar, range_offset, out.len, out, .{
        .index_buffer = index_buffer,
        .payload_scratch = payload_scratch,
    });
    return stats("sidecar_ldm_partial_range_into_scratch", frame.len + sidecar.len, result.output_written, failing);
}

fn deterministicLdmPrefix() [33_000]u8 {
    var out: [33_000]u8 = undefined;
    var x: u32 = 0x12345678;
    for (&out) |*byte| {
        x = x *% 1664525 +% 1013904223;
        byte.* = @truncate(x >> 24);
    }
    return out;
}

fn measureEmbeddedValidation(backing: std.mem.Allocator, stream: []const u8) !CaseStats {
    var failing = std.testing.FailingAllocator.init(backing, .{});
    try vort.storeValidateEmbeddedIndexAlloc(failing.allocator(), stream);
    return stats("embedded_validation_borrowed_dict", stream.len, 0, failing);
}

fn measureEmbeddedValidationWithBuffers(backing: std.mem.Allocator, stream: []const u8) !CaseStats {
    const view = try vort.storeViewEmbeddedIndex(stream);
    const index_buffer = try backing.alloc(vort.store.FrameIndexEntry, view.entry_count);
    defer backing.free(index_buffer);
    var payload_scratch: [16]u8 = undefined;
    var failing = std.testing.FailingAllocator.init(backing, .{});
    try vort.storeValidateEmbeddedIndexWithOptionsAndBuffersAlloc(failing.allocator(), stream, .{ .mode = .full }, .{
        .index_buffer = index_buffer,
        .payload_scratch = payload_scratch[0..],
    });
    return stats("embedded_validation_with_buffers", stream.len, 0, failing);
}

fn measureEmbeddedValidationReportWithBuffers(backing: std.mem.Allocator, stream: []const u8) !CaseStats {
    const view = try vort.storeViewEmbeddedIndex(stream);
    const index_buffer = try backing.alloc(vort.store.FrameIndexEntry, view.entry_count);
    defer backing.free(index_buffer);
    var payload_scratch: [16]u8 = undefined;
    var failing = std.testing.FailingAllocator.init(backing, .{});
    const report = vort.storeValidateEmbeddedIndexReportWithOptionsAndBuffersAlloc(failing.allocator(), stream, .{ .mode = .full }, .{
        .index_buffer = index_buffer,
        .payload_scratch = payload_scratch[0..],
    });
    try std.testing.expect(report.ok);
    return stats("embedded_validation_report_with_buffers", stream.len, 0, failing);
}

fn measureEmbeddedCompressedValidationWithBuffers(backing: std.mem.Allocator, stream: []const u8) !CaseStats {
    const sizes = try vort.storeSidecarValidationBufferSizesForEmbeddedIndex(stream);
    const index_buffer = try backing.alloc(vort.store.FrameIndexEntry, sizes.index_entries);
    defer backing.free(index_buffer);
    const payload_scratch = try backing.alloc(u8, sizes.payload_scratch_len);
    defer backing.free(payload_scratch);
    var failing = std.testing.FailingAllocator.init(backing, .{});
    try vort.storeValidateEmbeddedIndexWithOptionsAndBuffersAlloc(failing.allocator(), stream, .{ .mode = .full }, .{
        .index_buffer = index_buffer,
        .payload_scratch = payload_scratch,
    });
    return stats("embedded_compressed_validation_with_buffers", stream.len, 0, failing);
}

fn measureEmbeddedCompressedValidationReportWithBuffers(backing: std.mem.Allocator, stream: []const u8) !CaseStats {
    const sizes = try vort.storeSidecarValidationBufferSizesForEmbeddedIndex(stream);
    const index_buffer = try backing.alloc(vort.store.FrameIndexEntry, sizes.index_entries);
    defer backing.free(index_buffer);
    const payload_scratch = try backing.alloc(u8, sizes.payload_scratch_len);
    defer backing.free(payload_scratch);
    var failing = std.testing.FailingAllocator.init(backing, .{});
    const report = vort.storeValidateEmbeddedIndexReportWithOptionsAndBuffersAlloc(failing.allocator(), stream, .{ .mode = .full }, .{
        .index_buffer = index_buffer,
        .payload_scratch = payload_scratch,
    });
    try std.testing.expect(report.ok);
    return stats("embedded_compressed_validation_report_with_buffers", stream.len, 0, failing);
}

fn measureEmbeddedLdmValidationWithBuffers(backing: std.mem.Allocator) !CaseStats {
    const prefix = deterministicLdmPrefix();
    const payloads = [_][]const u8{prefix ++ "----" ++ prefix[0..1024].*};
    const stream = try vort.storeEncodeIndexedLongDistanceStreamAlloc(backing, &payloads, .{ .min_distance = 32769, .min_length = 16 });
    defer backing.free(stream);
    const sizes = try vort.storeSidecarValidationBufferSizesForEmbeddedIndex(stream);
    const index_buffer = try backing.alloc(vort.store.FrameIndexEntry, sizes.index_entries);
    defer backing.free(index_buffer);
    const payload_scratch = try backing.alloc(u8, sizes.payload_scratch_len);
    defer backing.free(payload_scratch);
    var failing = std.testing.FailingAllocator.init(backing, .{});
    try vort.storeValidateEmbeddedIndexWithOptionsAndBuffersAlloc(failing.allocator(), stream, .{ .mode = .full }, .{
        .index_buffer = index_buffer,
        .payload_scratch = payload_scratch,
    });
    return stats("embedded_ldm_validation_with_buffers", stream.len, 0, failing);
}

fn measureSidecarCompressedValidationWithBuffers(backing: std.mem.Allocator) !CaseStats {
    const payload = "hello hello hello hello";
    const frame = try vort.storeEncodeDeflateAlloc(backing, payload);
    defer backing.free(frame);
    const index = try vort.storeBuildFrameIndexAlloc(backing, frame);
    defer backing.free(index);
    const sidecar = try vort.storeEncodeFrameIndexAlloc(backing, index);
    defer backing.free(sidecar);
    const sizes = try vort.storeSidecarValidationBufferSizesForSidecarIndex(sidecar);
    const index_buffer = try backing.alloc(vort.store.FrameIndexEntry, sizes.index_entries);
    defer backing.free(index_buffer);
    const payload_scratch = try backing.alloc(u8, sizes.payload_scratch_len);
    defer backing.free(payload_scratch);
    var failing = std.testing.FailingAllocator.init(backing, .{});
    try vort.storeValidateSidecarIndexWithOptionsAndBuffersAlloc(failing.allocator(), frame, sidecar, .{ .mode = .full }, .{
        .index_buffer = index_buffer,
        .payload_scratch = payload_scratch,
    });
    return stats("sidecar_compressed_validation_with_buffers", frame.len + sidecar.len, 0, failing);
}

fn measureSidecarCompressedValidationReportWithBuffers(backing: std.mem.Allocator) !CaseStats {
    const payload = "hello hello hello hello";
    const frame = try vort.storeEncodeDeflateAlloc(backing, payload);
    defer backing.free(frame);
    const index = try vort.storeBuildFrameIndexAlloc(backing, frame);
    defer backing.free(index);
    const sidecar = try vort.storeEncodeFrameIndexAlloc(backing, index);
    defer backing.free(sidecar);
    const sizes = try vort.storeSidecarValidationBufferSizesForSidecarIndex(sidecar);
    const index_buffer = try backing.alloc(vort.store.FrameIndexEntry, sizes.index_entries);
    defer backing.free(index_buffer);
    const payload_scratch = try backing.alloc(u8, sizes.payload_scratch_len);
    defer backing.free(payload_scratch);
    var failing = std.testing.FailingAllocator.init(backing, .{});
    const report = vort.storeValidateSidecarIndexReportWithOptionsAndBuffersAlloc(failing.allocator(), frame, sidecar, .{ .mode = .full }, .{
        .index_buffer = index_buffer,
        .payload_scratch = payload_scratch,
    });
    try std.testing.expect(report.ok);
    return stats("sidecar_compressed_validation_report_with_buffers", frame.len + sidecar.len, 0, failing);
}

fn measureSidecarLdmValidationWithBuffers(backing: std.mem.Allocator) !CaseStats {
    const prefix = deterministicLdmPrefix();
    const payload = prefix ++ "----" ++ prefix[0..1024].*;
    const frame = try vort.storeEncodeLongDistanceAlloc(backing, payload, .{ .min_distance = 32769, .min_length = 16 });
    defer backing.free(frame);
    const index = try vort.storeBuildFrameIndexAlloc(backing, frame);
    defer backing.free(index);
    const sidecar = try vort.storeEncodeFrameIndexAlloc(backing, index);
    defer backing.free(sidecar);
    const sizes = try vort.storeSidecarValidationBufferSizesForSidecarIndex(sidecar);
    const index_buffer = try backing.alloc(vort.store.FrameIndexEntry, sizes.index_entries);
    defer backing.free(index_buffer);
    const payload_scratch = try backing.alloc(u8, sizes.payload_scratch_len);
    defer backing.free(payload_scratch);
    var failing = std.testing.FailingAllocator.init(backing, .{});
    try vort.storeValidateSidecarIndexWithOptionsAndBuffersAlloc(failing.allocator(), frame, sidecar, .{ .mode = .full }, .{
        .index_buffer = index_buffer,
        .payload_scratch = payload_scratch,
    });
    return stats("sidecar_ldm_validation_with_buffers", frame.len + sidecar.len, 0, failing);
}

fn measureDictionaryDeflateValidationWithBuffers(backing: std.mem.Allocator, stream: []const u8) !CaseStats {
    const sizes = try vort.storeSidecarValidationBufferSizesForEmbeddedIndex(stream);
    const index_buffer = try backing.alloc(vort.store.FrameIndexEntry, sizes.index_entries);
    defer backing.free(index_buffer);
    const payload_scratch = try backing.alloc(u8, sizes.payload_scratch_len);
    defer backing.free(payload_scratch);
    const patch_scratch = try backing.alloc(u8, sizes.patch_scratch_len);
    defer backing.free(patch_scratch);
    var failing = std.testing.FailingAllocator.init(backing, .{});
    try vort.storeValidateEmbeddedIndexWithOptionsAndBuffersAlloc(failing.allocator(), stream, .{ .mode = .full, .dictionary = dictionary_deflate_dict }, .{
        .index_buffer = index_buffer,
        .payload_scratch = payload_scratch,
        .patch_scratch = patch_scratch,
    });
    return stats("dictionary_deflate_validation_with_buffers", stream.len, 0, failing);
}

fn measureDictionaryDeflateValidationReportWithBuffers(backing: std.mem.Allocator, stream: []const u8) !CaseStats {
    const sizes = try vort.storeSidecarValidationBufferSizesForEmbeddedIndex(stream);
    const index_buffer = try backing.alloc(vort.store.FrameIndexEntry, sizes.index_entries);
    defer backing.free(index_buffer);
    const payload_scratch = try backing.alloc(u8, sizes.payload_scratch_len);
    defer backing.free(payload_scratch);
    const patch_scratch = try backing.alloc(u8, sizes.patch_scratch_len);
    defer backing.free(patch_scratch);
    var failing = std.testing.FailingAllocator.init(backing, .{});
    const report = vort.storeValidateEmbeddedIndexReportWithOptionsAndBuffersAlloc(failing.allocator(), stream, .{ .mode = .full, .dictionary = dictionary_deflate_dict }, .{
        .index_buffer = index_buffer,
        .payload_scratch = payload_scratch,
        .patch_scratch = patch_scratch,
    });
    try std.testing.expect(report.ok);
    return stats("dictionary_deflate_validation_report_with_buffers", stream.len, 0, failing);
}

fn stats(name: []const u8, input_len: usize, output_len: usize, failing: std.testing.FailingAllocator) CaseStats {
    return .{
        .name = name,
        .input_bytes = input_len,
        .output_bytes = output_len,
        .allocations = failing.allocations,
        .deallocations = failing.deallocations,
        .allocated_bytes = failing.allocated_bytes,
        .freed_bytes = failing.freed_bytes,
    };
}
