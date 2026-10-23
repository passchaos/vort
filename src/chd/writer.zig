const std = @import("std");
const deflate = @import("../deflate.zig");
const lzma = @import("../lzma.zig");
const zstd = @import("../zstd.zig");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");
const huffman = @import("huffman.zig");

pub const Error = archive_mod.Error || format.Error || huffman.Error ||
    deflate.Error || lzma.Error || zstd.Error || std.mem.Allocator.Error;

pub const Compression = enum {
    none,
    zlib,
    lzma,
    huffman,
    zstd,
    auto,
};

pub const EncodeMetadata = struct {
    tag: u32,
    flags: u8 = format.metadata_checksum_flag,
    data: []const u8,
};

pub const EncodeOptions = struct {
    compression: Compression = .auto,
    hunk_bytes: u32 = 4096,
    unit_bytes: u32 = 512,
    /// Zlib and auto accept 0...9; explicit Zstd accepts its native signed
    /// levels. Fixed-policy codecs retain legacy nonnegative hints (0...255).
    compression_level: c_int = 6,
    metadata: []const EncodeMetadata = &.{},
    max_metadata_entries: usize = 1 << 16,
    /// Parent ownership remains with the caller for the duration of encoding.
    parent: ?*const archive_mod.Archive = null,
    max_parent_hunks: usize = 1 << 24,
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
        .zlib, .auto => if (options.compression_level < 0 or options.compression_level > 9)
            return error.InvalidChd,
        .zstd => {
            _ = zstd.resolveFrameOptionsForLevel(options.compression_level, .{
                .include_content_size = true,
                .content_checksum = false,
            }) catch return error.InvalidChd;
        },
        .none, .lzma, .huffman => if (options.compression_level < 0 or options.compression_level > 255)
            return error.InvalidChd,
    }
    if (options.metadata.len > options.max_metadata_entries)
        return error.OutputLimitExceeded;
    for (options.metadata) |entry|
        if (entry.data.len > 0x00ff_ffff) return error.InvalidChdMetadata;
    if (options.parent) |parent| {
        if (parent.header.hunk_count > options.max_parent_hunks)
            return error.OutputLimitExceeded;
        if (parent.header.hunk_bytes != options.hunk_bytes or
            parent.header.unit_bytes != options.unit_bytes or
            std.mem.allEqual(u8, &parent.header.combined_sha1, 0))
            return error.InvalidChd;
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
    const parent_scratch = if (options.parent != null)
        try allocator.alloc(u8, options.hunk_bytes)
    else
        null;
    defer if (parent_scratch) |bytes| allocator.free(bytes);
    for (0..hunk_count) |hunk_index| {
        fillHunk(input, hunk_index, options.hunk_bytes, scratch);
        if (options.parent) |parent| {
            if (hunk_index < parent.header.hunk_count) {
                try parent.decodeHunkInto(allocator, hunk_index, parent_scratch.?);
                if (std.mem.eql(u8, scratch, parent_scratch.?)) continue;
            }
        } else if (std.mem.allEqual(u8, scratch, 0)) {
            continue;
        }
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
    const metadata_offset = try appendMetadata(allocator, &output, options.metadata);
    const digests = try computeDigests(allocator, input, options.metadata);
    writeHeader(output.items[0..format.header_size], input, options, .{
        .compressors = @splat(0),
        .map_offset = format.header_size,
        .metadata_offset = metadata_offset,
        .raw_sha1 = digests.raw,
        .combined_sha1 = digests.combined,
        .parent_sha1 = parentSha1(options.parent),
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
    const parent_scratch = if (options.parent != null)
        try allocator.alloc(u8, options.hunk_bytes)
    else
        null;
    defer if (parent_scratch) |bytes| allocator.free(bytes);
    var parent_index = std.AutoHashMap([20]u8, usize).init(allocator);
    defer parent_index.deinit();
    if (options.parent) |parent| {
        for (0..parent.header.hunk_count) |parent_hunk| {
            try parent.decodeHunkInto(allocator, parent_hunk, parent_scratch.?);
            var digest: [20]u8 = undefined;
            std.crypto.hash.Sha1.hash(parent_scratch.?, &digest, .{});
            const result = try parent_index.getOrPut(digest);
            if (!result.found_existing) result.value_ptr.* = parent_hunk;
        }
    }
    var seen = std.AutoHashMap([20]u8, usize).init(allocator);
    defer seen.deinit();
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendNTimes(allocator, 0, format.header_size);

    for (entries, 0..) |*entry, hunk_index| {
        fillHunk(input, hunk_index, options.hunk_bytes, scratch);
        var digest: [20]u8 = undefined;
        std.crypto.hash.Sha1.hash(scratch, &digest, .{});
        if (options.parent) |parent| {
            if (parent_index.get(digest)) |parent_hunk| {
                try parent.decodeHunkInto(allocator, parent_hunk, parent_scratch.?);
                if (std.mem.eql(u8, scratch, parent_scratch.?)) {
                    entry.* = .{
                        .kind = .parent,
                        .length = 0,
                        .offset = std.math.mul(
                            u64,
                            parent_hunk,
                            options.hunk_bytes / options.unit_bytes,
                        ) catch return error.IntegerOverflow,
                        .crc16 = 0,
                    };
                    continue;
                }
            }
        }
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
    const metadata_offset = try appendMetadata(allocator, &output, options.metadata);
    const digests = try computeDigests(allocator, input, options.metadata);
    writeHeader(output.items[0..format.header_size], input, options, .{
        .compressors = compressors,
        .map_offset = map_offset,
        .metadata_offset = metadata_offset,
        .raw_sha1 = digests.raw,
        .combined_sha1 = digests.combined,
        .parent_sha1 = parentSha1(options.parent),
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
            options.compression_level,
            .{ .include_content_size = true, .content_checksum = false },
        ),
        else => error.UnsupportedChdCodec,
    };
}

const HeaderFields = struct {
    compressors: [4]u32,
    map_offset: u64,
    metadata_offset: u64,
    raw_sha1: [20]u8,
    combined_sha1: [20]u8,
    parent_sha1: [20]u8,
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
    format.writeU64Be(output, 48, fields.metadata_offset);
    format.writeU32Be(output, 56, options.hunk_bytes);
    format.writeU32Be(output, 60, options.unit_bytes);
    @memcpy(output[64..84], &fields.raw_sha1);
    @memcpy(output[84..104], &fields.combined_sha1);
    @memcpy(output[104..124], &fields.parent_sha1);
}

const Digests = struct {
    raw: [20]u8,
    combined: [20]u8,
};

fn computeDigests(
    allocator: std.mem.Allocator,
    input: []const u8,
    metadata: []const EncodeMetadata,
) Error!Digests {
    var result: Digests = undefined;
    std.crypto.hash.Sha1.hash(input, &result.raw, .{});
    var hashes: std.ArrayList([24]u8) = .empty;
    defer hashes.deinit(allocator);
    for (metadata) |entry| {
        if (entry.flags & format.metadata_checksum_flag == 0) continue;
        var record: [24]u8 = undefined;
        std.mem.writeInt(u32, record[0..4], entry.tag, .big);
        std.crypto.hash.Sha1.hash(entry.data, record[4..24], .{});
        try hashes.append(allocator, record);
    }
    std.mem.sort([24]u8, hashes.items, {}, metadataHashLessThan);
    var state = std.crypto.hash.Sha1.init(.{});
    state.update(&result.raw);
    for (hashes.items) |*record| state.update(record);
    state.final(&result.combined);
    return result;
}

fn metadataHashLessThan(_: void, left: [24]u8, right: [24]u8) bool {
    return std.mem.order(u8, &left, &right) == .lt;
}

fn appendMetadata(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    metadata: []const EncodeMetadata,
) Error!u64 {
    if (metadata.len == 0) return 0;
    const first_offset = std.math.cast(u64, output.items.len) orelse
        return error.IntegerOverflow;
    var previous_offset: ?usize = null;
    for (metadata) |entry| {
        const offset = output.items.len;
        if (previous_offset) |previous|
            format.writeU64Be(output.items, previous + 8, offset);
        var header = [_]u8{0} ** format.metadata_header_size;
        format.writeU32Be(&header, 0, entry.tag);
        const length_and_flags = (@as(u32, entry.flags) << 24) |
            @as(u32, @intCast(entry.data.len));
        format.writeU32Be(&header, 4, length_and_flags);
        try output.appendSlice(allocator, &header);
        try output.appendSlice(allocator, entry.data);
        previous_offset = offset;
    }
    return first_offset;
}

fn parentSha1(parent: ?*const archive_mod.Archive) [20]u8 {
    return if (parent) |archive| archive.header.combined_sha1 else @splat(0);
}

fn encodeMapAlloc(
    allocator: std.mem.Allocator,
    entries: []const format.MapEntry,
) Error![]u8 {
    var active = [_]bool{false} ** 16;
    var max_length: u32 = 0;
    var max_self: u64 = 0;
    var max_parent: u64 = 0;
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
        if (entry.kind == .parent)
            max_parent = @max(max_parent, entry.offset);
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
    const parent_bits = bitWidth(max_parent);
    for (entries) |entry| switch (entry.kind) {
        .codec_0, .codec_1, .codec_2, .codec_3 => {
            try bits.write(entry.length, length_bits);
            try bits.write(entry.crc16, 16);
        },
        .uncompressed => try bits.write(entry.crc16, 16),
        .self => try bits.write(@intCast(entry.offset), self_bits),
        .parent => try bits.write(@intCast(entry.offset), parent_bits),
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
    output[14] = parent_bits;
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

test {
    _ = @import("zstd_levels_tests.zig");
}
