const std = @import("std");
const h = @import("common.zig");
const Z = h.Z;

pub fn run(init: std.process.Init, wire: []const u8, c: h.Config, dict: ?Z.NativeDictionary, set: Z.NativeDictionarySet, s: *h.State) ![]u8 {
    if (std.mem.eql(u8, c.api, "zip_reader")) return reader(init, wire, c, dict, s);
    const expected_output_len: @FieldType(Z.FrameDecodeOptions, "expected_output_len") = if (c.expected_output_len) |count| count else null;
    const options: Z.FrameDecodeOptions = .{ .format = c.format, .dictionary = if (c.catalog_only) null else dict, .dictionary_set = if (c.catalog_only) set else null, .expected_output_len = expected_output_len, .max_output_len = c.expected_output_len orelse 16 * 1024 * 1024 };
    if (std.mem.eql(u8, c.api, "decode_alloc")) return Z.decodeFrameAllocWithOptions(init.gpa, wire, options);
    if (std.mem.eql(u8, c.api, "decode_seekable")) return Z.decodeNativeSeekableRangeAllocWithDictionary(init.gpa, wire, 0, c.expected_output_len orelse return error.MissingExpectedSize, dict orelse return error.NeedDictionary);
    if (!std.mem.eql(u8, c.api, "decode_incremental")) return error.UnknownProbeApi;
    const incremental_options: Z.NativeIncrementalFrameDecoder.Options = .{ .format = c.format, .expected_output_len = expected_output_len, .max_output_len = c.expected_output_len orelse 16 * 1024 * 1024 };
    var decoder = if (c.catalog_only) Z.NativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(init.gpa, set, incremental_options) else if (dict) |dictionary| Z.NativeIncrementalFrameDecoder.initWithDictionaryAndOptions(init.gpa, dictionary, incremental_options) else Z.NativeIncrementalFrameDecoder.initWithOptions(init.gpa, incremental_options);
    defer decoder.deinit();
    const scratch = try init.gpa.alloc(u8, c.output_chunk);
    defer init.gpa.free(scratch);
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(init.gpa);
    var offset: usize = 0;
    for (0..wire.len * 8 + (c.expected_output_len orelse 65536) * 8 + 65536) |_| {
        const end = offset + @min(wire.len - offset, c.input_chunk);
        const result = try decoder.step(wire[offset..end], scratch);
        offset += result.progress.input_read;
        s.public_step_calls += 1;
        try output.appendSlice(init.gpa, scratch[0..result.progress.output_written]);
        if (offset == wire.len and (result.status == .done or result.status == .need_input)) {
            try decoder.finish();
            s.input_consumed = offset;
            return output.toOwnedSlice(init.gpa);
        }
    }
    return error.ProbeDidNotConverge;
}
fn reader(init: std.process.Init, archive: []const u8, c: h.Config, dict: ?Z.NativeDictionary, s: *h.State) ![]u8 {
    var zip = try h.root.ZipIncrementalReader.initWithOptions(init.gpa, .{ .zstd_dictionary = dict, .max_entries = 1, .max_total_output_len = c.expected_output_len orelse 16 * 1024 * 1024 });
    defer zip.deinit();
    const scratch = try init.gpa.alloc(u8, c.output_chunk);
    defer init.gpa.free(scratch);
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(init.gpa);
    var offset: usize = 0;
    for (0..archive.len * 8 + (c.expected_output_len orelse 65536) * 8 + 65536) |_| {
        const end = offset + @min(archive.len - offset, c.input_chunk);
        const result = try zip.step(archive[offset..end], scratch);
        offset += result.progress.input_read;
        s.public_step_calls += 1;
        try output.appendSlice(init.gpa, scratch[0..result.progress.output_written]);
        if (result.status == .entry_done) s.reader_entries += 1;
        if (result.status == .done) {
            try h.require(offset == archive.len and s.reader_entries == 1);
            s.input_consumed = offset;
            return output.toOwnedSlice(init.gpa);
        }
    }
    return error.ProbeDidNotConverge;
}
