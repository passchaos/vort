const std = @import("std");
const deflate = @import("../deflate.zig");
const lzma = @import("../lzma.zig");
const zstd = @import("../zstd.zig");
const format = @import("format.zig");
const huffman = @import("huffman.zig");

pub const Error = format.Error || huffman.Error || deflate.Error || lzma.Error ||
    zstd.Error || std.mem.Allocator.Error;

pub const Compression = enum {
    none,
    zlib,
    lzma,
    huffman,
    zstd,
    auto,
};

pub const EncodeOptions = struct {
    compression: Compression = .auto,
    hunk_bytes: u32 = 4096,
    unit_bytes: u32 = 512,
    compression_level: u8 = 6,
};

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) Error![]u8 {
    try validateOptions(options);
    return switch (options.compression) {
        .none => encodeUncompressedAlloc(allocator, input, options),
        .zlib, .lzma, .huffman, .zstd, .auto => encodeCompressedAlloc(allocator, input, options),
    };
}

fn validateOptions(options: EncodeOptions) Error!void {
    if (options.hunk_bytes == 0 or
        options.hunk_bytes > format.maximum_hunk_bytes or
        options.unit_bytes == 0 or
        options.hunk_bytes % options.unit_bytes != 0)
        return error.InvalidChd;
    switch (options.compression) {
        .zlib, .auto => if (options.compression_level > 9)
            return error.InvalidChd,
        .zstd => if (options.compression_level > 22)
            return error.InvalidChd,
        .none, .lzma, .huffman => {},
    }
}

const auto_codecs = [_]format.Codec{
    .zlib,
    .lzma,
    .huffman,
    .zstd,
};

fn codecsFor(compression: Compression) []const format.Codec {
    return switch (compression) {
        .none => &.{},
        .zlib => &.{.zlib},
        .lzma => &.{.lzma},
        .huffman => &.{.huffman},
        .zstd => &.{.zstd},
        .auto => &auto_codecs,
    };
}

fn encodeUncompressedAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) Error![]u8 {
    const hunk_count = std.math.divCeil(
        usize,
        input.len,
        options.hunk_bytes,
    ) catch return error.IntegerOverflow;
    const map_bytes = std.math.mul(usize, hunk_count, 4) catch
        return error.IntegerOverflow;
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendNTimes(allocator, 0, format.header_size + map_bytes);
    const padding = (options.hunk_bytes - output.items.len % options.hunk_bytes) %
        options.hunk_bytes;
    try output.appendNTimes(allocator, 0, padding);

    const scratch = try allocator.alloc(u8, options.hunk_bytes);
    defer allocator.free(scratch);
    for (0..hunk_count) |hunk_index| {
        fillHunk(input, hunk_index, options.hunk_bytes, scratch);
        if (std.mem.allEqual(u8, scratch, 0)) continue;
        if (output.items.len % options.hunk_bytes != 0)
            return error.InvalidChd;
        const raw_offset = output.items.len / options.hunk_bytes;
        if (raw_offset > std.math.maxInt(u32))
            return error.OutputLimitExceeded;
        format.writeU32Be(
            output.items,
            format.header_size + hunk_index * 4,
            @intCast(raw_offset),
        );
        try output.appendSlice(allocator, scratch);
    }
    writeHeader(output.items[0..format.header_size], input, options, .{
        .compressors = @splat(0),
        .map_offset = format.header_size,
    });
    return output.toOwnedSlice(allocator);
}

fn encodeCompressedAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) Error![]u8 {
    const codecs = codecsFor(options.compression);
    if (codecs.len == 0 or codecs.len > 4) return error.InvalidChd;
    var compressors = [_]u32{0} ** 4;
    for (codecs, 0..) |codec, slot|
        compressors[slot] = @intFromEnum(codec);
    const hunk_count = std.math.divCeil(
        usize,
        input.len,
        options.hunk_bytes,
    ) catch return error.IntegerOverflow;
    const entries = try allocator.alloc(format.MapEntry, hunk_count);
    defer allocator.free(entries);
    const scratch = try allocator.alloc(u8, options.hunk_bytes);
    defer allocator.free(scratch);
    var seen = std.AutoHashMap([20]u8, usize).init(allocator);
    defer seen.deinit();
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendNTimes(allocator, 0, format.header_size);

    for (entries, 0..) |*entry, hunk_index| {
        fillHunk(input, hunk_index, options.hunk_bytes, scratch);
        var digest: [20]u8 = undefined;
        std.crypto.hash.Sha1.hash(scratch, &digest, .{});
        const seen_result = try seen.getOrPut(digest);
        if (seen_result.found_existing and samePaddedHunk(
            input,
            seen_result.value_ptr.*,
            hunk_index,
            options.hunk_bytes,
        )) {
            entry.* = .{
                .kind = .self,
                .length = 0,
                .offset = seen_result.value_ptr.*,
                .crc16 = 0,
            };
            continue;
        }
        if (!seen_result.found_existing)
            seen_result.value_ptr.* = hunk_index;

        const choice = try chooseCompressedAlloc(
            allocator,
            scratch,
            codecs,
            options,
        );
        defer allocator.free(choice.bytes);
        const use_compressed = choice.bytes.len <= options.hunk_bytes and
            choice.bytes.len <= 0x00ff_ffff and
            (options.compression != .auto or choice.bytes.len < options.hunk_bytes);
        const stored = if (use_compressed) choice.bytes else scratch;
        const offset = std.math.cast(u64, output.items.len) orelse
            return error.IntegerOverflow;
        try output.appendSlice(allocator, stored);
        entry.* = .{
            .kind = if (use_compressed)
                @enumFromInt(choice.slot)
            else
                .uncompressed,
            .length = @intCast(stored.len),
            .offset = offset,
            .crc16 = format.crc16(scratch),
        };
    }

    const map_offset = std.math.cast(u64, output.items.len) orelse
        return error.IntegerOverflow;
    const encoded_map = try encodeMapAlloc(
        allocator,
        entries,
    );
    defer allocator.free(encoded_map);
    try output.appendSlice(allocator, encoded_map);
    writeHeader(output.items[0..format.header_size], input, options, .{
        .compressors = compressors,
        .map_offset = map_offset,
    });
    return output.toOwnedSlice(allocator);
}

const CompressedChoice = struct {
    bytes: []u8,
    slot: u8,
};

fn chooseCompressedAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    codecs: []const format.Codec,
    options: EncodeOptions,
) Error!CompressedChoice {
    var best: ?CompressedChoice = null;
    errdefer if (best) |choice| allocator.free(choice.bytes);
    for (codecs, 0..) |codec, slot| {
        const candidate = try encodeCodecAlloc(allocator, codec, input, options);
        if (best == null or candidate.len < best.?.bytes.len) {
            if (best) |previous| allocator.free(previous.bytes);
            best = .{ .bytes = candidate, .slot = @intCast(slot) };
        } else {
            allocator.free(candidate);
        }
    }
    return best orelse error.InvalidChd;
}

fn encodeCodecAlloc(
    allocator: std.mem.Allocator,
    codec: format.Codec,
    input: []const u8,
    options: EncodeOptions,
) Error![]u8 {
    return switch (codec) {
        .zlib => deflate.encodeRawBestAlloc(
            allocator,
            input,
            try deflate.optionsForZlibLevel(@intCast(options.compression_level)),
        ),
        .lzma => lzma.encodeChdPayloadAlloc(
            allocator,
            input,
            format.alignedLzmaDictionarySize(options.hunk_bytes),
        ),
        .huffman => huffman.encodeHunkAlloc(allocator, input),
        .zstd => zstd.encodeFrameWithLevelAndOptionsAlloc(
            allocator,
            input,
            @intCast(options.compression_level),
            .{ .include_content_size = true, .content_checksum = false },
        ),
        else => error.UnsupportedChdCodec,
    };
}

const HeaderFields = struct {
    compressors: [4]u32,
    map_offset: u64,
};

fn writeHeader(
    output: []u8,
    input: []const u8,
    options: EncodeOptions,
    fields: HeaderFields,
) void {
    @memset(output, 0);
    @memcpy(output[0..8], format.signature);
    format.writeU32Be(output, 8, format.header_size);
    format.writeU32Be(output, 12, format.version);
    for (fields.compressors, 0..) |compressor, index|
        format.writeU32Be(output, 16 + index * 4, compressor);
    format.writeU64Be(output, 32, input.len);
    format.writeU64Be(output, 40, fields.map_offset);
    format.writeU32Be(output, 56, options.hunk_bytes);
    format.writeU32Be(output, 60, options.unit_bytes);
    var raw_sha1: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash(input, &raw_sha1, .{});
    @memcpy(output[64..84], &raw_sha1);
    var combined_sha1: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash(&raw_sha1, &combined_sha1, .{});
    @memcpy(output[84..104], &combined_sha1);
}

fn encodeMapAlloc(
    allocator: std.mem.Allocator,
    entries: []const format.MapEntry,
) Error![]u8 {
    var active = [_]bool{false} ** 16;
    var max_length: u32 = 0;
    var max_self: u64 = 0;
    var expanded_crc: u16 = 0xffff;
    for (entries) |entry| {
        const kind: usize = @intFromEnum(entry.kind);
        if (kind >= active.len) return error.InvalidChdMap;
        active[kind] = true;
        switch (entry.kind) {
            .codec_0, .codec_1, .codec_2, .codec_3 => max_length = @max(max_length, entry.length),
            else => {},
        }
        if (entry.kind == .self)
            max_self = @max(max_self, entry.offset);
        var raw: [format.expanded_map_entry_size]u8 = undefined;
        entry.writeExpanded(&raw);
        expanded_crc = format.crc16Update(expanded_crc, &raw);
    }

    var active_count: usize = 0;
    var active_symbols: [16]usize = undefined;
    for (active, 0..) |is_active, symbol| {
        if (!is_active) continue;
        active_symbols[active_count] = symbol;
        active_count += 1;
    }
    var lengths = [_]u8{0} ** 16;
    if (active_count == 1) {
        lengths[active_symbols[0]] = 1;
    } else if (active_count == 2) {
        lengths[active_symbols[0]] = 1;
        lengths[active_symbols[1]] = 1;
    } else if (active_count > 2) {
        const long_bits = bitWidth(active_count - 1);
        const capacity = @as(usize, 1) << @intCast(long_bits);
        const short_count = capacity - active_count;
        for (active_symbols[0..active_count], 0..) |symbol, index|
            lengths[symbol] = if (index < short_count)
                long_bits - 1
            else
                long_bits;
    }
    const codes = try canonicalCodes(lengths);
    var bits = huffman.BitWriter.init(allocator);
    defer bits.deinit();

    for (lengths) |length| {
        if (length == 1) {
            try bits.write(1, 4);
            try bits.write(1, 4);
        } else {
            try bits.write(length, 4);
        }
    }
    for (entries) |entry| {
        const symbol: usize = @intFromEnum(entry.kind);
        try bits.write(codes[symbol], lengths[symbol]);
    }
    const length_bits = bitWidth(max_length);
    const self_bits = bitWidth(max_self);
    for (entries) |entry| switch (entry.kind) {
        .codec_0, .codec_1, .codec_2, .codec_3 => {
            try bits.write(entry.length, length_bits);
            try bits.write(entry.crc16, 16);
        },
        .uncompressed => try bits.write(entry.crc16, 16),
        .self => try bits.write(@intCast(entry.offset), self_bits),
        else => return error.InvalidChdMap,
    };
    const payload = try bits.finishAlloc();
    defer allocator.free(payload);
    if (payload.len > std.math.maxInt(u32)) return error.OutputLimitExceeded;
    const total_len = std.math.add(
        usize,
        format.compressed_map_header_size,
        payload.len,
    ) catch return error.IntegerOverflow;
    const output = try allocator.alloc(u8, total_len);
    errdefer allocator.free(output);
    @memset(output[0..format.compressed_map_header_size], 0);
    format.writeU32Be(output, 0, @intCast(payload.len));
    format.writeU48Be(output, 4, format.header_size);
    format.writeU16Be(output, 10, expanded_crc);
    output[12] = length_bits;
    output[13] = self_bits;
    output[14] = bitWidth(0);
    @memcpy(output[format.compressed_map_header_size..], payload);
    return output;
}

fn canonicalCodes(lengths: [16]u8) Error![16]u32 {
    var counts = [_]u32{0} ** 9;
    for (lengths) |length| {
        if (length > 8) return error.InvalidHuffmanCode;
        counts[length] += 1;
    }
    var starts = [_]u32{0} ** 9;
    var current: u32 = 0;
    var length: usize = 8;
    while (length != 0) : (length -= 1) {
        const sum = current + counts[length];
        const next = sum >> 1;
        if (length != 1 and next * 2 != sum)
            return error.InvalidHuffmanCode;
        starts[length] = current;
        current = next;
    }
    var codes = [_]u32{0} ** 16;
    for (lengths, 0..) |symbol_length, symbol| {
        if (symbol_length == 0) continue;
        codes[symbol] = starts[symbol_length];
        starts[symbol_length] += 1;
    }
    return codes;
}

fn bitWidth(value: anytype) u8 {
    if (value == 0) return 0;
    return @intCast(@bitSizeOf(@TypeOf(value)) - @clz(value));
}

fn fillHunk(
    input: []const u8,
    hunk_index: usize,
    hunk_bytes: usize,
    output: []u8,
) void {
    @memset(output, 0);
    const start = hunk_index * hunk_bytes;
    if (start >= input.len) return;
    const end = @min(input.len, start + hunk_bytes);
    @memcpy(output[0 .. end - start], input[start..end]);
}

fn samePaddedHunk(
    input: []const u8,
    first_index: usize,
    second_index: usize,
    hunk_bytes: usize,
) bool {
    const first_start = first_index * hunk_bytes;
    const second_start = second_index * hunk_bytes;
    for (0..hunk_bytes) |offset| {
        const first = if (first_start + offset < input.len)
            input[first_start + offset]
        else
            0;
        const second = if (second_start + offset < input.len)
            input[second_start + offset]
        else
            0;
        if (first != second) return false;
    }
    return true;
}
