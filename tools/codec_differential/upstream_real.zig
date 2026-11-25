//! Reference-produced wires for the real-file correctness lane. Forced flush
//! boundaries make every large input exercise genuine continuation state.
const std = @import("std");
const Zstd = @import("../zstd/libzstd_runtime.zig").Runtime;
const Brotli = @import("../br/libbrotli_runtime.zig").Runtime;
const wide_brotli = @import("wide_brotli.zig");

pub const chunk_len = 64 * 1024;
pub const default_file_limit = 8 * 1024 * 1024;
pub const maximum_file_limit = 64 * 1024 * 1024;
pub const maximum_dictionary_len = 32 * 1024;

pub const Options = struct {
    brotli_wide: bool = false,
    record_flushes: bool = false,
    raw_dictionary: ?[]const u8 = null,
};

pub const DictionaryFixture = struct {
    storage: []u8,
    dictionary: []const u8,
    input: []const u8,
};

pub fn dictionarySmokeInput(a: std.mem.Allocator) !DictionaryFixture {
    const storage = try a.alloc(u8, maximum_dictionary_len + 3 * chunk_len + 333);
    var rng = std.Random.DefaultPrng.init(0x766f_7274_6469_6374);
    rng.random().bytes(storage);
    const dictionary = storage[0..maximum_dictionary_len];
    const input = storage[maximum_dictionary_len..];
    const repeated = 12 * 1024;
    // High-entropy bytes from the dictionary cannot be recreated as local
    // matches. Subsequent chunks also exercise copies across flush boundaries.
    @memcpy(input[0..repeated], dictionary[dictionary.len - repeated ..]);
    var offset: usize = chunk_len;
    while (offset < input.len) : (offset += chunk_len) {
        const n = @min(repeated, input.len - offset);
        @memcpy(input[offset..][0..n], input[offset - repeated ..][0..n]);
    }
    return .{ .storage = storage, .dictionary = dictionary, .input = input };
}

pub const Checkpoint = struct {
    flush_index: usize,
    wire_bytes: usize,
    decoded_bytes: usize,
};

const Checkpoints = struct {
    items: [3]Checkpoint = undefined,
    len: usize = 0,

    pub fn slice(self: *const Checkpoints) []const Checkpoint {
        return self.items[0..self.len];
    }

    fn select(offsets: []const usize, wire_len: usize) !Checkpoints {
        var result: Checkpoints = .{};
        if (offsets.len == 0) return result;
        var previous: usize = 0;
        for (offsets) |offset| {
            if (offset <= previous or offset >= wire_len) return error.InvalidReferenceFlushOffset;
            previous = offset;
        }
        for ([_]usize{ 0, offsets.len / 2, offsets.len - 1 }) |i| {
            if (result.len != 0 and result.items[result.len - 1].flush_index == i + 1) continue;
            result.items[result.len] = .{ .flush_index = i + 1, .wire_bytes = offsets[i], .decoded_bytes = (i + 1) * chunk_len };
            result.len += 1;
        }
        return result;
    }
};

pub const Wire = struct {
    bytes: []u8,
    encoder: []const u8,
    level: u4,
    flush_interval: ?usize = chunk_len,
    checkpoints: Checkpoints = .{},
};

pub fn encode(comptime c: type, a: std.mem.Allocator, input: []const u8, codec: anytype, mode: Options) !Wire {
    if (mode.brotli_wide and (mode.record_flushes or mode.raw_dictionary != null)) return error.ConflictingRealStreamModes;
    if (codec == .gzip and mode.raw_dictionary != null) return error.UnsupportedGzipDictionary;
    const offsets: ?[]usize = if (mode.record_flushes) try a.alloc(usize, (input.len -| 1) / chunk_len) else null;
    defer if (offsets) |positions| a.free(positions);
    var wire: Wire = switch (codec) {
        .raw, .zlib, .gzip => .{
            .bytes = try deflate(c, a, input, switch (codec) {
                .raw => -15,
                .zlib => 15,
                .gzip => 31,
                else => unreachable,
            }, offsets, mode.raw_dictionary),
            .encoder = "libz deflateInit2(level=6,windowBits=-15/15/31,memLevel=8,strategy=default); Z_SYNC_FLUSH",
            .level = 6,
        },
        .zstd => result: {
            var upstream = try Zstd.open();
            defer upstream.deinit();
            if (!std.mem.eql(u8, upstream.version(), std.mem.span(c.ZSTD_versionString())))
                return error.ReferenceVersionMismatch;
            const options: Zstd.AdvancedOptions = .{
                .level = 3,
                .content_size = false,
                .checksum = true,
                .window_log = 17,
            };
            break :result .{
                .bytes = if (mode.raw_dictionary) |dictionary|
                    try upstream.encodeStreamingWithRawPrefixAlloc(a, input, options, chunk_len, dictionary, offsets)
                else if (offsets) |positions|
                    try upstream.encodeStreamingWithFlushOffsetsAlloc(a, input, options, chunk_len, positions)
                else
                    try upstream.encodeStreamingAlloc(a, input, options, chunk_len, true),
                .encoder = "libzstd compressStream2(level=3,windowLog=17,checksum,unknown-size); ZSTD_e_flush",
                .level = 3,
            };
        },
        .br => result: {
            var upstream = try Brotli.open();
            defer upstream.deinit();
            if (upstream.encoder_version() != c.BrotliDecoderVersion()) return error.ReferenceVersionMismatch;
            if (mode.brotli_wide) break :result .{
                .bytes = try upstream.encodeWithOptionsAlloc(a, input, .{ .quality = wide_brotli.quality, .lgwin = wide_brotli.window_bits }),
                .encoder = wide_brotli.encoder,
                .level = wide_brotli.quality,
                .flush_interval = null,
            };
            const chunks = try a.alloc([]const u8, std.math.divCeil(usize, input.len, chunk_len) catch unreachable);
            defer a.free(chunks);
            for (chunks, 0..) |*chunk, i| {
                const offset = i * chunk_len;
                chunk.* = input[offset..][0..@min(chunk_len, input.len - offset)];
            }
            const options: Brotli.StreamingOptions = .{ .quality = 5, .lgwin = 16, .lgblock = 16 };
            break :result .{
                .bytes = if (mode.raw_dictionary) |dictionary|
                    try upstream.encodeFlushedChunksWithRawDictionaryAlloc(a, chunks, options, dictionary, offsets)
                else if (offsets) |positions|
                    try upstream.encodeFlushedChunksWithOffsetsAlloc(a, chunks, options, positions)
                else
                    try upstream.encodeFlushedChunksWithOptionsAlloc(a, chunks, options),
                .encoder = "libbrotli CompressStream(q=5,lgwin=16,lgblock=16,generic); BROTLI_OPERATION_FLUSH",
                .level = 5,
            };
        },
    };
    errdefer a.free(wire.bytes);
    if (offsets) |positions| wire.checkpoints = try Checkpoints.select(positions, wire.bytes.len);
    return wire;
}

fn deflate(comptime c: type, a: std.mem.Allocator, input: []const u8, window_bits: c_int, offsets: ?[]usize, raw_dictionary: ?[]const u8) ![]u8 {
    var stream = std.mem.zeroes(c.z_stream);
    if (c.deflateInit2(&stream, 6, c.Z_DEFLATED, window_bits, 8, c.Z_DEFAULT_STRATEGY) != c.Z_OK)
        return error.ReferenceEncodeFailed;
    defer _ = c.deflateEnd(&stream);
    if (raw_dictionary) |dictionary| {
        if (c.deflateSetDictionary(&stream, dictionary.ptr, @intCast(dictionary.len)) != c.Z_OK)
            return error.ReferenceEncodeFailed;
    }

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(a);
    var offset: usize = 0;
    while (true) {
        const end = offset + @min(chunk_len, input.len - offset);
        const final = end == input.len;
        stream.next_in = @constCast(input[offset..end].ptr);
        stream.avail_in = @intCast(end - offset);
        while (true) {
            var bytes: [32 * 1024]u8 = undefined;
            stream.avail_out = bytes.len;
            stream.next_out = &bytes;
            const before = stream.avail_in;
            const status = c.deflate(&stream, if (final) c.Z_FINISH else c.Z_SYNC_FLUSH);
            const written = bytes.len - stream.avail_out;
            try output.appendSlice(a, bytes[0..written]);
            if (status == c.Z_STREAM_END) {
                if (!final or stream.avail_in != 0) return error.ReferenceEncodeFailed;
                return output.toOwnedSlice(a);
            }
            if (status != c.Z_OK or (written == 0 and before == stream.avail_in)) return error.ReferenceEncodeFailed;
            if (!final and stream.avail_in == 0 and stream.avail_out != 0) break;
        }
        if (offsets) |positions| positions[offset / chunk_len] = output.items.len;
        offset = end;
    }
}

pub fn digest(bytes: []const u8) [64]u8 {
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &hash, .{});
    return std.fmt.bytesToHex(hash, .lower);
}
