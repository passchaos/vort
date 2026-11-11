const std = @import("std");

pub const plain = "abcdef";
pub const max_plain_len = plain.len * 2;
pub const dictionary = "preset history!!";
pub const Mode = enum { zlib, zlib_options, zlib_dictionary, zlib_dictionary_options, gzip, gzip_options, gzip_concatenated, gzip_concatenated_options };

pub fn hasDictionary(comptime mode: Mode) bool {
    return mode == .zlib_dictionary or mode == .zlib_dictionary_options;
}

pub fn isGzip(comptime mode: Mode) bool {
    return switch (mode) {
        .gzip, .gzip_options, .gzip_concatenated, .gzip_concatenated_options => true,
        else => false,
    };
}

pub fn encode(comptime D: type, comptime mode: Mode) ![]u8 {
    if (mode == .gzip_concatenated or mode == .gzip_concatenated_options) {
        const member = try D.encodeGzipStoredAlloc(std.testing.allocator, plain);
        defer std.testing.allocator.free(member);
        const joined = try std.testing.allocator.alloc(u8, member.len * 2);
        @memcpy(joined[0..member.len], member);
        @memcpy(joined[member.len..], member);
        return joined;
    }
    return if (hasDictionary(mode))
        D.encodeZlibStoredWithDictionaryAlloc(std.testing.allocator, plain, dictionary)
    else if (isGzip(mode))
        D.encodeGzipStoredAlloc(std.testing.allocator, plain)
    else
        D.encodeZlibStoredAlloc(std.testing.allocator, plain);
}

pub fn split(wire: []const u8) [3][]const u8 {
    return .{ wire[0..4], "", wire[4..] };
}

pub fn decode(comptime D: type, comptime mode: Mode, chunks: []const []const u8, scratch: []u8, output: []u8, dict: []const u8) !usize {
    return switch (mode) {
        .zlib => D.decodeZlibChunks(chunks, scratch, output),
        .zlib_options => D.decodeZlibChunksWithOptions(chunks, scratch, output, .{}),
        .zlib_dictionary => D.decodeZlibChunksWithDictionary(chunks, scratch, output, dict),
        .zlib_dictionary_options => D.decodeZlibChunksWithDictionaryAndOptions(chunks, scratch, output, dict, .{}),
        .gzip => D.decodeGzipChunks(chunks, scratch, output),
        .gzip_options => D.decodeGzipChunksWithOptions(chunks, scratch, output, .{}),
        .gzip_concatenated => D.decodeGzipConcatenatedChunks(chunks, scratch, output),
        .gzip_concatenated_options => D.decodeGzipConcatenatedChunksWithOptions(chunks, scratch, output, .{}),
    };
}

pub fn expectPlain(written: usize, output: []const u8) !void {
    try std.testing.expectEqual(plain.len, written);
    try std.testing.expectEqualSlices(u8, plain, output[0..written]);
}

pub fn expectDecoded(comptime mode: Mode, written: usize, output: []const u8) !void {
    const expected = if (mode == .gzip_concatenated or mode == .gzip_concatenated_options) plain ++ plain else plain;
    try std.testing.expectEqual(expected.len, written);
    try std.testing.expectEqualSlices(u8, expected, output[0..written]);
}

pub fn copyBytes(comptime T: type, value: *const T) [@sizeOf(T)]u8 {
    var result: [@sizeOf(T)]u8 = undefined;
    @memcpy(&result, std.mem.asBytes(value));
    return result;
}
