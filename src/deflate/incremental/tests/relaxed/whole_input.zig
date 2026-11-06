const std = @import("std");
const a = std.testing.allocator;

pub fn contracts(comptime D: type) !void {
    const zlib = try D.encodeZlibStoredAlloc(a, "abc");
    defer a.free(zlib);
    const gzip = try D.encodeGzipStoredAlloc(a, "abc");
    defer a.free(gzip);
    const dictionary = "dictionary retained for the second zlib member";
    const dict_member = try D.encodeZlibStoredWithDictionaryAlloc(a, "def", dictionary);
    defer a.free(dict_member);
    const with_dict = try std.mem.concat(a, u8, &.{ zlib, dict_member });
    defer a.free(with_dict);
    try rejected(D, false, with_dict, zlib.len, error.NeedDictionary);
    var output: [64]u8 = undefined;
    const zopts: D.ZlibDecodeOptions = .{ .allow_trailing_data = true, .ignore_adler = true };
    try std.testing.expectEqual(@as(usize, 6), try D.decodeZlibConcatenatedWithDictionaryAndOptions(with_dict, &output, dictionary, zopts));
    try std.testing.expectEqualStrings("abcdef", output[0..6]);
    try std.testing.expectError(error.ChecksumMismatch, D.decodeZlibConcatenatedWithDictionaryAndOptions(with_dict, &output, "wrong", zopts));
    const empty_set = D.ZlibDictionarySet.fromEntries(&.{});
    try std.testing.expectError(error.NeedDictionary, D.decodeZlibConcatenatedWithDictionarySetAndOptions(with_dict, &output, empty_set, zopts));

    for ([_][]const u8{ &.{ 0x78, 0x01 }, &.{ 0x78, 0xbb, 0 } }) |prefix| {
        const input = try std.mem.concat(a, u8, &.{ zlib, prefix });
        defer a.free(input);
        try rejected(D, false, input, zlib.len, error.TruncatedFrame);
    }
    const partial_gzip = try std.mem.concat(a, u8, &.{ gzip, &.{ 0x1f, 0x8b } });
    defer a.free(partial_gzip);
    try rejected(D, true, partial_gzip, gzip.len, error.TruncatedFrame);
    for ([_]usize{ 2, 3 }) |field| {
        const damaged = try a.dupe(u8, gzip);
        defer a.free(damaged);
        damaged[field] = if (field == 2) 9 else 0x20;
        const input = try std.mem.concat(a, u8, &.{ gzip, damaged });
        defer a.free(input);
        try rejected(D, true, input, gzip.len, error.BadGzipHeader);
    }
    const header_crc = try D.encodeGzipStoredWithHeaderAlloc(a, "def", .{ .header_crc = true });
    defer a.free(header_crc);
    header_crc[10] ^= 1;
    const bad_header_crc = try std.mem.concat(a, u8, &.{ gzip, header_crc });
    defer a.free(bad_header_crc);
    try rejected(D, true, bad_header_crc, gzip.len, error.BadGzipHeader);

    inline for (.{ false, true }) |is_gzip| {
        const member = if (is_gzip) gzip else zlib;
        const plausible: u8 = if (is_gzip) 0x1f else 0x78;
        for ([_][]const u8{ "garbage", &.{plausible} }) |tail| {
            const input = try std.mem.concat(a, u8, &.{ member, member, tail });
            defer a.free(input);
            const family = if (is_gzip) "Gzip" else "Zlib";
            const Options = @field(D, family ++ "DecodeOptions");
            const probe = @field(D, "probe" ++ family ++ "ConcatenatedWithOptions")(input, &output, Options{ .allow_trailing_data = true });
            try std.testing.expect(probe.ok);
            try std.testing.expectEqual(@as(?usize, 2), probe.member_count);
            try std.testing.expectEqual(@as(?usize, member.len * 2), probe.stream_input_bytes);
            try std.testing.expectEqual(@as(?usize, member.len), probe.last_member_offset);
            try std.testing.expectEqualStrings("abcabc", output[0..6]);
        }
    }
}

fn rejected(comptime D: type, comptime is_gzip: bool, input: []const u8, member_offset: usize, expected: anyerror) !void {
    const family = if (is_gzip) "Gzip" else "Zlib";
    const Options = @field(D, family ++ "DecodeOptions");
    const options: Options = if (is_gzip)
        .{ .allow_trailing_data = true, .ignore_crc32 = true, .ignore_isize = true }
    else
        .{ .allow_trailing_data = true, .ignore_adler = true };
    var output: [64]u8 = @splat(0xa5);
    try std.testing.expectError(expected, @field(D, "decode" ++ family ++ "ConcatenatedWithOptions")(input, &output, options));
    try std.testing.expectError(expected, @field(D, "decode" ++ family ++ "ConcatenatedAllocWithOptionsLimited")(a, input, options, 64));
    try std.testing.expectError(expected, @field(D, "decode" ++ family ++ "ConcatenatedAllocWithOptionsExactSize")(a, input, options, 6));
    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(a);
    try std.testing.expectError(expected, @field(D, "decode" ++ family ++ "ConcatenatedAppendWithOptionsLimited")(a, &appended, input, options, 64));
    var joined: [128]u8 = undefined;
    const chunks = [_][]const u8{ input[0..member_offset], input[member_offset .. member_offset + 1], input[member_offset + 1 ..] };
    const Decoder = @field(D, family ++ "Decoder");
    try std.testing.expectError(expected, Decoder.initConcatenatedFromChunksWithOptionsExactSize(&chunks, &joined, &output, options, 6));
    try std.testing.expectError(expected, Decoder.initConcatenatedWithOptionsExactSize(input, &output, options, 6));
    const probe = @field(D, "probe" ++ family ++ "ConcatenatedWithOptions")(input, &output, options);
    try std.testing.expect(!probe.ok);
    try std.testing.expectEqualStrings(@errorName(expected), probe.error_name);
    try std.testing.expectEqual(@as(?usize, 1), probe.member_index);
    try std.testing.expectEqual(@as(?usize, member_offset), probe.member_offset);
}
