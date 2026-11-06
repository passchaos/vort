//! Public incremental wrapper contracts executed on wasm32-wasi.
//! Report slots are documented beside each group; offsets and decoder geometry
//! come from the running codec rather than a prescribed control-state layout.
const std = @import("std");
const codec = @import("codec");
const allocator = std.heap.page_allocator;
const history_len = 32 * 1024;
var values: [64]u64 = @splat(0);

fn require(ok: bool) error{DeflateRelaxedWasmMismatch}!void {
    if (!ok) return error.DeflateRelaxedWasmMismatch;
}

fn geometry() void {
    values[0] = @bitSizeOf(usize);
    values[1] = history_len;
    values[2] = @sizeOf(codec.ZlibIncrementalDecoder);
    values[3] = @sizeOf(codec.GzipIncrementalDecoder);
    values[4] = 0;
}

const Advance = struct { input: usize, output: usize };
fn step(decoder: anytype, input: []const u8, output: []u8) !Advance {
    const before = decoder.snapshot();
    const advanced = try decoder.step(input, output);
    const after = decoder.snapshot();
    try require(after.total_input == before.total_input + advanced.progress.input_read);
    try require(after.total_output == before.total_output + advanced.progress.output_written);
    try require(std.meta.eql(after.last_step_progress, advanced.progress));
    const diagnostics = decoder.diagnostics();
    try require(diagnostics.input_read.? == after.total_input);
    try require(diagnostics.output_written == after.total_output);
    try require(std.meta.eql(diagnostics.last_step_progress.?, advanced.progress));
    return .{ .input = advanced.progress.input_read, .output = advanced.progress.output_written };
}

fn stepError(expected: anyerror, decoder: anytype, input: []const u8, output: []u8) !void {
    const before = decoder.snapshot();
    if (decoder.step(input, output)) |_| return error.ExpectedStepFailure else |err| try require(err == expected);
    const after = decoder.snapshot();
    try require(after.total_input == before.total_input + after.last_step_progress.input_read);
    try require(after.total_output == before.total_output + after.last_step_progress.output_written);
    try require(after.last_error_input_offset.? == after.total_input);
    try require(after.last_error_output_offset.? == after.total_output);
    const diagnostics = decoder.diagnostics();
    try require(diagnostics.error_input_offset.? == after.total_input);
    try require(diagnostics.error_output_offset.? == after.total_output);
    try require(std.meta.eql(diagnostics.last_step_progress.?, after.last_step_progress));
}

fn finishError(expected: anyerror, decoder: anytype) !void {
    if (decoder.finish()) |_| return error.ExpectedFinishFailure else |err| try require(err == expected);
}

export fn deflateRelaxedWasmReport(index: u32) u64 {
    return if (index < values.len) values[index] else 0;
}

// 6 payload, 7 zlib wire, 8 zlib output, 9 full Adler footer,
// 10 short Adler footer, 11 gzip wire, 12 gzip output, 13 full gzip footer,
// 14 short gzip footer, 15 CRC refusals, 16 ISIZE refusals,
// 17 CRC-ignored output, 18 ISIZE-ignored output, 19 doubly ignored members.
fn footer() !void {
    geometry();
    @memset(values[6..20], 0);
    const payload = "footer";
    const zlib_wire = try codec.encodeZlibFixedAlloc(allocator, payload);
    defer allocator.free(zlib_wire);
    zlib_wire[zlib_wire.len - 1] ^= 1;
    var history: [history_len]u8 = undefined;
    var output: [16]u8 = undefined;
    var zlib = try codec.ZlibIncrementalDecoder.init(.{ .ignore_adler = true }, &history);
    _ = try step(&zlib, zlib_wire, &output);
    try zlib.finish();
    try require(std.mem.eql(u8, payload, output[0..payload.len]));
    try require(zlib.snapshot().footer_received == 4 and zlib.snapshot().stream_count == 1);
    values[6] = payload.len;
    values[7] = zlib_wire.len;
    values[8] = zlib.snapshot().total_output;
    values[9] = zlib.snapshot().footer_received;
    var zlib_short = try codec.ZlibIncrementalDecoder.init(.{ .ignore_adler = true }, &history);
    _ = try step(&zlib_short, zlib_wire[0 .. zlib_wire.len - 1], &output);
    try finishError(error.TruncatedFrame, &zlib_short);
    values[10] = zlib_short.snapshot().footer_received;
    try require(values[10] + 1 == values[9]);
    var zlib_strict = try codec.ZlibIncrementalDecoder.init(.{}, &history);
    try stepError(error.ChecksumMismatch, &zlib_strict, zlib_wire, &output);

    const gzip_wire = try codec.encodeGzipFixedAlloc(allocator, payload);
    defer allocator.free(gzip_wire);
    const footer_offset = gzip_wire.len - 8;
    values[11] = gzip_wire.len;
    for (0..3) |mask| {
        gzip_wire[footer_offset] ^= @intFromBool(mask != 1);
        gzip_wire[footer_offset + 4] ^= @intFromBool(mask != 0);
        defer {
            gzip_wire[footer_offset] ^= @intFromBool(mask != 1);
            gzip_wire[footer_offset + 4] ^= @intFromBool(mask != 0);
        }
        var decoder = try codec.GzipIncrementalDecoder.init(.{
            .ignore_crc32 = mask != 1,
            .ignore_isize = mask != 0,
        }, &history);
        _ = try step(&decoder, gzip_wire, &output);
        try decoder.finish();
        try require(decoder.snapshot().member_count == 1);
        try require(std.mem.eql(u8, payload, output[0..payload.len]));
        try require(decoder.snapshot().total_input == gzip_wire.len);
        values[12] = decoder.snapshot().total_output;
        values[13] = decoder.snapshot().footer_received;
        if (mask == 0) values[17] = decoder.snapshot().total_output;
        if (mask == 1) values[18] = decoder.snapshot().total_output;
        if (mask == 2) values[19] = decoder.snapshot().member_count;
        var short = try codec.GzipIncrementalDecoder.init(.{
            .ignore_crc32 = mask != 1,
            .ignore_isize = mask != 0,
        }, &history);
        _ = try step(&short, gzip_wire[0 .. gzip_wire.len - 1], &output);
        try finishError(error.TruncatedFrame, &short);
        values[14] = short.snapshot().footer_received;
        try require(values[14] + 1 == values[13]);
        if (mask < 2) {
            const err = if (mask == 0) error.ChecksumMismatch else error.SizeMismatch;
            var strict = try codec.GzipIncrementalDecoder.init(.{}, &history);
            try stepError(err, &strict, gzip_wire, &output);
            // Ignoring the other field must not waive this corrupted field.
            var independent = try codec.GzipIncrementalDecoder.init(.{
                .ignore_crc32 = mask == 1,
                .ignore_isize = mask == 0,
            }, &history);
            try stepError(err, &independent, gzip_wire, &output);
            values[15 + mask] = 2;
        }
    }
}

export fn deflateRelaxedWasmFooter() u32 {
    footer() catch |err| {
        values[4] = @intFromError(err);
        return 101;
    };
    values[5] |= 1;
    return 0;
}

// 20..27 zlib: members, validated end, accepted input, retained prefix,
// output, current-tail accepted input, restored-tail length, final member input.
// 28..35 gzip: the same observations. 36/37 EOF-only retained prefixes,
// 38/39 zlib/gzip final member start offsets.
fn members() !void {
    geometry();
    @memset(values[20..40], 0);
    const zfirst = try codec.encodeZlibFixedAlloc(allocator, "one");
    defer allocator.free(zfirst);
    const zsecond = try codec.encodeZlibFixedAlloc(allocator, "two");
    defer allocator.free(zsecond);
    const gfirst = try codec.encodeGzipFixedAlloc(allocator, "one");
    defer allocator.free(gfirst);
    const gsecond = try codec.encodeGzipStoredWithHeaderAlloc(allocator, "two", .{ .header_crc = true });
    defer allocator.free(gsecond);
    var history: [history_len]u8 = undefined;
    var output: [16]u8 = undefined;
    var zlib = try codec.ZlibIncrementalDecoder.init(.{ .allow_concatenated = true, .allow_trailing_data = true }, &history);
    _ = try step(&zlib, zfirst, &output);
    _ = try step(&zlib, zsecond[0..1], output[3..]);
    _ = try step(&zlib, zsecond[1..], output[3..]);
    _ = try step(&zlib, zsecond[0..1], &.{});
    const ztail = [_]u8{ 0, 'x', 'y' };
    const zstopped = try step(&zlib, &ztail, &.{});
    try zlib.finish();
    const zrestored = try std.mem.concat(allocator, u8, &.{ zlib.trailingPrefix(), ztail[zstopped.input..] });
    defer allocator.free(zrestored);
    try require(std.mem.eql(u8, "onetwo", output[0..6]));
    try require(zlib.snapshot().stream_count == 2 and zlib.snapshot().total_output == 6);
    try require(zlib.memberEndOffset().? == zfirst.len + zsecond.len);
    try require(zlib.snapshot().total_input == zlib.memberEndOffset().? + 1);
    try require(zstopped.input == 0 and zlib.trailingPrefix().len == 1);
    try require(zrestored.len == ztail.len + 1 and zrestored[0] == zsecond[0]);
    try require(std.mem.eql(u8, &ztail, zrestored[1..]));
    values[20] = zlib.snapshot().stream_count;
    values[21] = zlib.memberEndOffset().?;
    values[22] = zlib.snapshot().total_input;
    values[23] = zlib.trailingPrefix().len;
    values[24] = zlib.snapshot().total_output;
    values[25] = zstopped.input;
    values[26] = zrestored.len;
    values[27] = zlib.snapshot().stream_input;
    values[38] = zlib.snapshot().stream_offset;

    var gzip = try codec.GzipIncrementalDecoder.init(.{ .allow_concatenated = true, .allow_trailing_data = true }, &history);
    _ = try step(&gzip, gfirst, &output);
    _ = try step(&gzip, gsecond[0..1], output[3..]);
    _ = try step(&gzip, gsecond[1..], output[3..]);
    _ = try step(&gzip, gsecond[0..1], &.{});
    const gtail = [_]u8{ 0, 'x', 'y' };
    const gstopped = try step(&gzip, &gtail, &.{});
    try gzip.finish();
    const grestored = try std.mem.concat(allocator, u8, &.{ gzip.trailingPrefix(), gtail[gstopped.input..] });
    defer allocator.free(grestored);
    try require(std.mem.eql(u8, "onetwo", output[0..6]));
    try require(gzip.snapshot().member_count == 2 and gzip.snapshot().total_output == 6);
    try require(gzip.memberEndOffset().? == gfirst.len + gsecond.len);
    try require(gzip.snapshot().total_input == gzip.memberEndOffset().? + 1);
    try require(gstopped.input == 0 and gzip.trailingPrefix().len == 1);
    try require(grestored.len == gtail.len + 1 and grestored[0] == gsecond[0]);
    try require(std.mem.eql(u8, &gtail, grestored[1..]));
    values[28] = gzip.snapshot().member_count;
    values[29] = gzip.memberEndOffset().?;
    values[30] = gzip.snapshot().total_input;
    values[31] = gzip.trailingPrefix().len;
    values[32] = gzip.snapshot().total_output;
    values[33] = gstopped.input;
    values[34] = grestored.len;
    values[35] = gzip.snapshot().member_input;
    values[39] = gzip.snapshot().member_offset;

    zlib.reset();
    _ = try step(&zlib, zfirst, &output);
    _ = try step(&zlib, zsecond, output[3..]);
    _ = try step(&zlib, zsecond[0..1], &.{});
    try zlib.finish();
    values[36] = zlib.trailingPrefix().len;
    try require(values[36] == 1 and zlib.snapshot().total_input == zlib.memberEndOffset().? + 1);
    gzip.reset();
    _ = try step(&gzip, gfirst, &output);
    _ = try step(&gzip, gsecond, output[3..]);
    _ = try step(&gzip, gsecond[0..1], &.{});
    try gzip.finish();
    values[37] = gzip.trailingPrefix().len;
    try require(values[37] == 1 and gzip.snapshot().total_input == gzip.memberEndOffset().? + 1);
}

export fn deflateRelaxedWasmMembers() u32 {
    members() catch |err| {
        values[4] = @intFromError(err);
        return 201;
    };
    values[5] |= 2;
    return 0;
}

// 40 bad method, 41 bad reserved flags, 42 bad FHCRC, 43 committed-header
// truncation, 44 metadata cap, 45 bad zlib header, 46 requested DICTID,
// 47 accepted dictionary-member header, 48 recovered member output,
// 49 dictionary mismatch refusal.
fn headers() !void {
    geometry();
    @memset(values[40..50], 0);
    const first = try codec.encodeGzipFixedAlloc(allocator, "");
    defer allocator.free(first);
    const second = try codec.encodeGzipStoredWithHeaderAlloc(allocator, "two", .{ .filename = "name", .header_crc = true });
    defer allocator.free(second);
    const header = try codec.parseGzipHeaderInfo(second);
    var history: [history_len]u8 = undefined;
    var output: [16]u8 = undefined;
    for ([_]usize{ 2, 3, header.data_offset - 2 }, 0..) |index, slot| {
        const original = second[index];
        second[index] = if (index == 2) 0 else if (index == 3) 0x80 else original ^ 1;
        defer second[index] = original;
        var decoder = try codec.GzipIncrementalDecoder.init(.{
            .allow_concatenated = true,
            .allow_trailing_data = true,
            .ignore_crc32 = true,
            .ignore_isize = true,
        }, &history);
        _ = try step(&decoder, first, &output);
        _ = try step(&decoder, second[0..1], &output);
        try stepError(error.BadGzipHeader, &decoder, second[1..], &output);
        try require(decoder.snapshot().last_error_member_index.? == 1);
        try require(decoder.memberEndOffset().? == first.len);
        values[40 + slot] = 1;
    }
    var short = try codec.GzipIncrementalDecoder.init(.{
        .allow_concatenated = true,
        .allow_trailing_data = true,
        .ignore_crc32 = true,
        .ignore_isize = true,
    }, &history);
    _ = try step(&short, first, &output);
    _ = try step(&short, second[0..2], &output);
    try finishError(error.TruncatedFrame, &short);
    try require(short.snapshot().last_error_member_index.? == 1 and short.trailingPrefix().len == 0);
    values[43] = 1;
    var limited = try codec.GzipIncrementalDecoder.init(.{
        .ignore_crc32 = true,
        .ignore_isize = true,
        .max_header_metadata_len = 2,
    }, &history);
    try stepError(error.OutputLimitExceeded, &limited, second, &output);
    values[44] = 1;
    var bad_zlib = try codec.ZlibIncrementalDecoder.init(.{ .ignore_adler = true, .allow_trailing_data = true }, &history);
    try stepError(error.BadZlibHeader, &bad_zlib, &.{ 0x78, 0x02 }, &output);
    values[45] = 1;

    const dictionary = "wasm dictionary";
    const payload = "dict";
    const zfirst = try codec.encodeZlibFixedAlloc(allocator, "one");
    defer allocator.free(zfirst);
    const dict_wire = try codec.encodeZlibStoredWithDictionaryAlloc(allocator, payload, dictionary);
    defer allocator.free(dict_wire);
    const dict_header = try codec.parseZlibHeaderInfo(dict_wire);
    var needs_dictionary = try codec.ZlibIncrementalDecoder.init(.{
        .allow_concatenated = true,
        .allow_trailing_data = true,
        .ignore_adler = true,
    }, &history);
    _ = try step(&needs_dictionary, zfirst, &output);
    try stepError(error.NeedDictionary, &needs_dictionary, dict_wire, output[3..]);
    try require(needs_dictionary.requiredDictionaryId().? == dict_header.dictionary_id.?);
    const accepted = needs_dictionary.snapshot().last_step_progress.input_read;
    try require(accepted == dict_header.data_offset);
    try finishError(error.NeedDictionary, &needs_dictionary);
    if (needs_dictionary.provideDictionary("wrong")) |_| return error.ExpectedDictionaryMismatch else |err| try require(err == error.DictionaryMismatch);
    values[49] = 1;
    values[46] = needs_dictionary.requiredDictionaryId().?;
    values[47] = accepted;
    try needs_dictionary.provideDictionary(dictionary);
    _ = try step(&needs_dictionary, dict_wire[accepted..], output[3..]);
    try needs_dictionary.finish();
    try require(std.mem.eql(u8, "one" ++ payload, output[0 .. 3 + payload.len]));
    values[48] = needs_dictionary.snapshot().stream_output;
}

export fn deflateRelaxedWasmHeaders() u32 {
    headers() catch |err| {
        values[4] = @intFromError(err);
        return 301;
    };
    values[5] |= 4;
    return 0;
}

// 50 raw-error wire, 51 accepted input, 52 error input offset, 53 payload,
// 54 error-step input, 55 error-step output, 56 cumulative output,
// 57 member output, 58 actual CRC, 59 expected CRC, 60 diagnostic output
// offset, 61 snapshot output offset, 62 reset progress/count sum,
// 63 error-step output after a previous two-byte output step.
fn progress() !void {
    geometry();
    @memset(values[50..64], 0);
    const payload = "abc";
    const template = try codec.encodeGzipStoredAlloc(allocator, payload);
    defer allocator.free(template);
    const header = try codec.parseGzipHeaderInfo(template);
    const expected_crc = std.mem.readInt(u32, template[template.len - 8 ..][0..4], .little);
    const blocks = [_]u8{ 0, 3, 0, 0xfc, 0xff, 'a', 'b', 'c', 7 };
    const wire = try std.mem.concat(allocator, u8, &.{ template[0..header.data_offset], &blocks });
    defer allocator.free(wire);
    var history: [history_len]u8 = undefined;
    var output: [16]u8 = undefined;
    var decoder = try codec.GzipIncrementalDecoder.init(.{ .ignore_crc32 = true, .ignore_isize = true }, &history);
    try stepError(error.InvalidDeflateBlockType, &decoder, wire, &output);
    const snapshot = decoder.snapshot();
    const diagnostics = decoder.diagnostics();
    try require(std.mem.eql(u8, payload, output[0..payload.len]));
    try require(snapshot.total_input == wire.len and snapshot.last_step_progress.input_read == wire.len);
    try require(snapshot.total_output == payload.len and snapshot.member_output == payload.len);
    try require(snapshot.last_step_progress.output_written == payload.len and decoder.crc.digest() == expected_crc);
    values[50] = wire.len;
    values[51] = snapshot.total_input;
    values[52] = snapshot.last_error_input_offset.?;
    values[53] = payload.len;
    values[54] = snapshot.last_step_progress.input_read;
    values[55] = snapshot.last_step_progress.output_written;
    values[56] = snapshot.total_output;
    values[57] = snapshot.member_output;
    values[58] = decoder.crc.digest();
    values[59] = expected_crc;
    values[60] = diagnostics.error_output_offset.?;
    values[61] = snapshot.last_error_output_offset.?;
    decoder.reset();
    const reset = decoder.snapshot();
    values[62] = reset.total_input + reset.total_output + reset.last_step_progress.input_read + reset.last_step_progress.output_written;
    try require(values[62] == 0 and reset.last_error_output_offset == null);
    try require(decoder.diagnostics().error_output_offset == null and decoder.memberEndOffset() == null);
    const first = try step(&decoder, wire, output[0..2]);
    try require(first.output == 2);
    try stepError(error.InvalidDeflateBlockType, &decoder, wire[first.input..], output[2..3]);
    try require(decoder.snapshot().total_output == payload.len and decoder.crc.digest() == expected_crc);
    values[63] = decoder.snapshot().last_step_progress.output_written;
    try require(values[63] == payload.len - first.output);
}

export fn deflateRelaxedWasmProgress() u32 {
    progress() catch |err| {
        values[4] = @intFromError(err);
        return 401;
    };
    values[5] |= 8;
    return 0;
}
