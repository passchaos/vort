//! System libz produces every valid member and independently validates gzip
//! headers. No codec encoder, parser or checksum participates in the oracle.
const std = @import("std");
pub const C = @import("zlib");
pub const Wrapper = enum { raw, zlib, gzip };
pub const Verdict = enum { complete, data, truncated, dictionary };

pub fn bits(wrapper: Wrapper) c_int {
    return switch (wrapper) {
        .raw => -15,
        .zlib => 15,
        .gzip => 31,
    };
}
pub fn adler(bytes: []const u8) u32 {
    return @truncate(C.adler32(C.adler32(0, null, 0), bytes.ptr, @intCast(bytes.len)));
}
pub fn crc(bytes: []const u8) u32 {
    return @truncate(C.crc32(C.crc32(0, null, 0), bytes.ptr, @intCast(bytes.len)));
}
pub fn deflate(a: std.mem.Allocator, wrapper: Wrapper, bytes: []const u8, dictionary: ?[]const u8) ![]u8 {
    var stream: C.z_stream = std.mem.zeroes(C.z_stream);
    if (C.deflateInit2_(&stream, 6, C.Z_DEFLATED, bits(wrapper), 8, C.Z_DEFAULT_STRATEGY, C.ZLIB_VERSION, @sizeOf(C.z_stream)) != C.Z_OK) return error.LibzInit;
    defer _ = C.deflateEnd(&stream);
    if (dictionary) |dict| if (C.deflateSetDictionary(&stream, dict.ptr, @intCast(dict.len)) != C.Z_OK) return error.LibzDictionary;
    const initial_input = stream.total_in;
    stream.next_in = @constCast(bytes.ptr);
    stream.avail_in = @intCast(bytes.len);
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(a);
    for (0..bytes.len * 4 + 256) |_| {
        var out: [17]u8 = undefined;
        stream.next_out = &out;
        stream.avail_out = out.len;
        const status = C.deflate(&stream, C.Z_FINISH);
        const written = out.len - stream.avail_out;
        try result.appendSlice(a, out[0..written]);
        if (status == C.Z_STREAM_END) {
            if (stream.avail_in != 0 or stream.total_in != initial_input + bytes.len) return error.LibzInputProgress;
            return result.toOwnedSlice(a);
        }
        if (status != C.Z_OK or written == 0) return error.LibzDeflate;
    }
    return error.LibzNoProgress;
}

/// Input is one already-recognized member, never arbitrary trailing garbage.
pub fn inflate(wrapper: Wrapper, wire: []const u8) !Verdict {
    var stream: C.z_stream = std.mem.zeroes(C.z_stream);
    if (C.inflateInit2_(&stream, bits(wrapper), C.ZLIB_VERSION, @sizeOf(C.z_stream)) != C.Z_OK) return error.LibzInit;
    defer _ = C.inflateEnd(&stream);
    stream.next_in = @constCast(wire.ptr);
    stream.avail_in = @intCast(wire.len);
    for (0..wire.len * 64 + 4096) |_| {
        const before = stream.avail_in;
        var out: [128]u8 = undefined;
        stream.next_out = &out;
        stream.avail_out = out.len;
        const status = C.inflate(&stream, C.Z_NO_FLUSH);
        if (status == C.Z_STREAM_END) return .complete;
        if (status == C.Z_DATA_ERROR) return .data;
        if (status == C.Z_NEED_DICT) return .dictionary;
        if (status != C.Z_OK and status != C.Z_BUF_ERROR) return error.LibzInflate;
        if (before == stream.avail_in and stream.avail_out == out.len) {
            if (stream.avail_in == 0) return .truncated;
            return error.LibzNoProgress;
        }
    }
    return error.LibzNoProgress;
}
