const std = @import("std");
const deflate = @import("../deflate.zig");
const lzma = @import("../lzma.zig");
const zstd = @import("../zstd.zig");
const format = @import("format.zig");
const huffman = @import("huffman.zig");

pub const Error = format.Error || huffman.Error || deflate.Error ||
    lzma.Error || zstd.Error || std.mem.Allocator.Error;

pub const OpenOptions = struct {
    /// Parent ownership remains with the caller and must outlive this archive.
    parent: ?*const Archive = null,
    verify_checksums: bool = true,
    max_hunks: usize = 1 << 24,
    max_expanded_map_bytes: usize = 256 * 1024 * 1024,
    max_metadata_entries: usize = 1 << 16,
    max_compressed_hunk_bytes: usize = 2 * 1024 * 1024,
    max_self_reference_depth: usize = 1 << 20,
};

pub const Archive = struct {
    allocator: std.mem.Allocator,
    bytes: []const u8,
    header: format.Header,
    map: []format.MapEntry,
    metadata: []format.Metadata,
    parent: ?*const Archive,
    verify_checksums: bool,
    uncompressed_map: bool,
    max_self_reference_depth: usize,

    pub fn initAlloc(
        allocator: std.mem.Allocator,
        input: []const u8,
        options: OpenOptions,
    ) Error!Archive {
        const header = try format.parseHeader(input);
        if (header.hunk_count > options.max_hunks)
            return error.OutputLimitExceeded;
        const expanded_map_bytes = std.math.mul(
            usize,
            header.hunk_count,
            format.expanded_map_entry_size,
        ) catch return error.IntegerOverflow;
        if (expanded_map_bytes > options.max_expanded_map_bytes)
            return error.OutputLimitExceeded;
        if (header.hasParent()) {
            const parent = options.parent orelse return error.MissingChdParent;
            if (!std.mem.eql(u8, &header.parent_sha1, &parent.header.combined_sha1) or
                header.hunk_bytes != parent.header.hunk_bytes or
                header.unit_bytes != parent.header.unit_bytes)
                return error.MissingChdParent;
        }
        if (header.isCompressed())
            try validateCodecs(header)
        else if (options.parent != null and !header.hasParent())
            return error.InvalidChd;

        const map = if (header.isCompressed())
            try expandCompressedMap(allocator, input, header, options)
        else
            try parseUncompressedMap(allocator, input, header);
        errdefer allocator.free(map);
        const metadata = try parseMetadataChain(
            allocator,
            input,
            header.metadata_offset,
            options.max_metadata_entries,
        );
        errdefer allocator.free(metadata);
        return .{
            .allocator = allocator,
            .bytes = input,
            .header = header,
            .map = map,
            .metadata = metadata,
            .parent = options.parent,
            .verify_checksums = options.verify_checksums,
            .uncompressed_map = !header.isCompressed(),
            .max_self_reference_depth = options.max_self_reference_depth,
        };
    }

    pub fn deinit(self: *Archive) void {
        self.allocator.free(self.map);
        self.allocator.free(self.metadata);
        self.* = undefined;
    }

    pub fn findMetadata(
        self: Archive,
        wanted_tag: ?u32,
        wanted_index: usize,
    ) ?format.Metadata {
        var matching_index: usize = 0;
        for (self.metadata) |entry| {
            if (wanted_tag == null or entry.tag == wanted_tag.?) {
                if (matching_index == wanted_index) return entry;
                matching_index += 1;
            }
        }
        return null;
    }

    pub fn decodeAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        max_output_len: usize,
    ) Error![]u8 {
        const logical_size = std.math.cast(usize, self.header.logical_bytes) orelse
            return error.OutputLimitExceeded;
        if (logical_size > max_output_len) return error.OutputLimitExceeded;
        const output = try allocator.alloc(u8, logical_size);
        errdefer allocator.free(output);
        try self.readRangeInto(allocator, 0, output);
        if (self.verify_checksums and
            !std.mem.allEqual(u8, &self.header.raw_sha1, 0))
        {
            var actual: [std.crypto.hash.Sha1.digest_length]u8 = undefined;
            std.crypto.hash.Sha1.hash(output, &actual, .{});
            if (!std.mem.eql(u8, &actual, &self.header.raw_sha1))
                return error.ChecksumMismatch;
        }
        if (self.verify_checksums and
            !std.mem.allEqual(u8, &self.header.combined_sha1, 0))
            try self.verifyCombinedSha1(allocator);
        return output;
    }

    fn verifyCombinedSha1(
        self: Archive,
        allocator: std.mem.Allocator,
    ) Error!void {
        var hashes: std.ArrayList([24]u8) = .empty;
        defer hashes.deinit(allocator);
        for (self.metadata) |entry| {
            if (entry.flags & 1 == 0) continue;
            var record: [24]u8 = undefined;
            std.mem.writeInt(u32, record[0..4], entry.tag, .big);
            std.crypto.hash.Sha1.hash(entry.data, record[4..24], .{});
            try hashes.append(allocator, record);
        }
        std.mem.sort([24]u8, hashes.items, {}, metadataHashLessThan);
        var state = std.crypto.hash.Sha1.init(.{});
        state.update(&self.header.raw_sha1);
        for (hashes.items) |*record| state.update(record);
        var actual: [20]u8 = undefined;
        state.final(&actual);
        if (!std.mem.eql(u8, &actual, &self.header.combined_sha1))
            return error.ChecksumMismatch;
    }

    pub fn readRangeAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        offset: usize,
        length: usize,
        max_output_len: usize,
    ) Error![]u8 {
        if (length > max_output_len) return error.OutputLimitExceeded;
        const output = try allocator.alloc(u8, length);
        errdefer allocator.free(output);
        try self.readRangeInto(allocator, offset, output);
        return output;
    }

    pub fn readRangeInto(
        self: Archive,
        allocator: std.mem.Allocator,
        offset: usize,
        output: []u8,
    ) Error!void {
        const end = std.math.add(usize, offset, output.len) catch
            return error.IntegerOverflow;
        if (end > self.header.logical_bytes) return error.RangeOutOfBounds;
        try self.readPaddedRangeInto(allocator, offset, output);
    }

    fn readPaddedRangeInto(
        self: Archive,
        allocator: std.mem.Allocator,
        offset: usize,
        output: []u8,
    ) Error!void {
        const padded_size = std.math.mul(
            usize,
            self.header.hunk_count,
            self.header.hunk_bytes,
        ) catch return error.IntegerOverflow;
        const end = std.math.add(usize, offset, output.len) catch
            return error.IntegerOverflow;
        if (end > padded_size) return error.RangeOutOfBounds;
        if (output.len == 0) return;

        const hunk_bytes: usize = self.header.hunk_bytes;
        const scratch = try allocator.alloc(u8, hunk_bytes);
        defer allocator.free(scratch);
        var position = offset;
        var written: usize = 0;
        while (written < output.len) {
            const hunk_index = position / hunk_bytes;
            const within_hunk = position % hunk_bytes;
            const length = @min(output.len - written, hunk_bytes - within_hunk);
            try self.decodeHunkInto(allocator, hunk_index, scratch);
            @memcpy(
                output[written..][0..length],
                scratch[within_hunk..][0..length],
            );
            position += length;
            written += length;
        }
    }

    pub fn decodeHunkInto(
        self: Archive,
        allocator: std.mem.Allocator,
        hunk_index: usize,
        output: []u8,
    ) Error!void {
        if (hunk_index >= self.map.len) return error.RangeOutOfBounds;
        if (output.len != self.header.hunk_bytes) return error.SizeMismatch;

        var resolved_index = hunk_index;
        var entry = self.map[resolved_index];
        var self_depth: usize = 0;
        while (!self.uncompressed_map and entry.kind == .self) {
            const target = std.math.cast(usize, entry.offset) orelse
                return error.InvalidChdMap;
            if (target >= resolved_index) return error.InvalidChdMap;
            self_depth += 1;
            if (self_depth > self.max_self_reference_depth)
                return error.OutputLimitExceeded;
            resolved_index = target;
            entry = self.map[resolved_index];
        }

        if (self.uncompressed_map) {
            if (entry.offset == 0) {
                if (self.parent) |parent|
                    try parent.decodeHunkInto(allocator, hunk_index, output)
                else
                    @memset(output, 0);
                return;
            }
            try copyEncoded(self.bytes, entry.offset, self.header.hunk_bytes, output);
            return;
        }

        switch (entry.kind) {
            .codec_0, .codec_1, .codec_2, .codec_3 => {
                const encoded = try encodedSlice(self.bytes, entry.offset, entry.length);
                const slot: usize = @intFromEnum(entry.kind);
                const decoded = try decodeCodec(
                    allocator,
                    try self.header.codec(slot),
                    encoded,
                    self.header.hunk_bytes,
                );
                defer allocator.free(decoded);
                @memcpy(output, decoded);
            },
            .uncompressed => try copyEncoded(
                self.bytes,
                entry.offset,
                self.header.hunk_bytes,
                output,
            ),
            .self => unreachable,
            .parent => {
                const parent = self.parent orelse return error.MissingChdParent;
                const parent_offset_u64 = std.math.mul(
                    u64,
                    entry.offset,
                    self.header.unit_bytes,
                ) catch return error.IntegerOverflow;
                const parent_offset = std.math.cast(usize, parent_offset_u64) orelse
                    return error.RangeOutOfBounds;
                try parent.readPaddedRangeInto(allocator, parent_offset, output);
            },
            else => return error.InvalidChdMap,
        }
        const has_crc = switch (entry.kind) {
            .codec_0, .codec_1, .codec_2, .codec_3, .uncompressed => true,
            else => false,
        };
        if (self.verify_checksums and has_crc and
            format.crc16(output) != entry.crc16)
            return error.ChecksumMismatch;
    }
};

fn metadataHashLessThan(_: void, left: [24]u8, right: [24]u8) bool {
    return std.mem.order(u8, &left, &right) == .lt;
}

fn validateCodecs(header: format.Header) Error!void {
    for (header.compressors) |raw| {
        if (raw == 0) continue;
        const codec = std.enums.fromInt(format.Codec, raw) orelse
            return error.UnsupportedChdCodec;
        switch (codec) {
            .zlib, .lzma, .huffman, .zstd => {},
            else => return error.UnsupportedChdCodec,
        }
    }
}

fn parseUncompressedMap(
    allocator: std.mem.Allocator,
    input: []const u8,
    header: format.Header,
) Error![]format.MapEntry {
    const map_offset = std.math.cast(usize, header.map_offset) orelse
        return error.IntegerOverflow;
    const map_bytes = std.math.mul(usize, header.hunk_count, 4) catch
        return error.IntegerOverflow;
    const map_end = std.math.add(usize, map_offset, map_bytes) catch
        return error.IntegerOverflow;
    if (map_end > input.len) return error.TruncatedFrame;
    const entries = try allocator.alloc(format.MapEntry, header.hunk_count);
    errdefer allocator.free(entries);
    for (entries, 0..) |*entry, index| {
        const raw_offset = format.readU32Be(input, map_offset + index * 4);
        const offset = std.math.mul(
            u64,
            raw_offset,
            header.hunk_bytes,
        ) catch return error.IntegerOverflow;
        if (offset != 0) {
            const end = std.math.add(u64, offset, header.hunk_bytes) catch
                return error.IntegerOverflow;
            if (end > input.len) return error.TruncatedFrame;
        }
        entry.* = .{
            .kind = .uncompressed,
            .length = header.hunk_bytes,
            .offset = offset,
            .crc16 = 0,
        };
    }
    return entries;
}

fn expandCompressedMap(
    allocator: std.mem.Allocator,
    input: []const u8,
    header: format.Header,
    options: OpenOptions,
) Error![]format.MapEntry {
    const map_offset = std.math.cast(usize, header.map_offset) orelse
        return error.IntegerOverflow;
    const map_header = try format.parseCompressedMapHeader(input, map_offset);
    const payload_offset = std.math.add(
        usize,
        map_offset,
        format.compressed_map_header_size,
    ) catch return error.IntegerOverflow;
    const payload = input[payload_offset..][0..map_header.encoded_bytes];
    var reader = huffman.BitReader.init(payload);
    var decoder: huffman.MapDecoder = .{};
    try decoder.importRle(&reader);

    const entries = try allocator.alloc(format.MapEntry, header.hunk_count);
    errdefer allocator.free(entries);
    var last_type: u8 = 0;
    var repetitions: usize = 0;
    for (entries) |*entry| {
        const raw_type: u8 = if (repetitions != 0) repeated: {
            repetitions -= 1;
            break :repeated last_type;
        } else decoded: {
            const value: u8 = @intCast(try decoder.decode(&reader));
            if (value == @intFromEnum(format.MapType.rle_small)) {
                repetitions = 2 + try decoder.decode(&reader);
                break :decoded last_type;
            }
            if (value == @intFromEnum(format.MapType.rle_large)) {
                const high = try decoder.decode(&reader);
                const low = try decoder.decode(&reader);
                repetitions = 18 + (high << 4) + low;
                break :decoded last_type;
            }
            last_type = value;
            break :decoded value;
        };
        entry.* = .{
            .kind = std.enums.fromInt(format.MapType, raw_type) orelse
                return error.InvalidChdMap,
            .length = 0,
            .offset = 0,
            .crc16 = 0,
        };
    }
    if (repetitions != 0) return error.InvalidChdMap;

    var current_offset = map_header.first_data_offset;
    var last_self: u64 = 0;
    var last_parent: u64 = 0;
    var expanded_crc: u16 = 0xffff;
    const units_per_hunk = header.hunk_bytes / header.unit_bytes;
    for (entries, 0..) |*entry, hunk_index| {
        entry.offset = current_offset;
        switch (entry.kind) {
            .codec_0, .codec_1, .codec_2, .codec_3 => {
                const slot: usize = @intFromEnum(entry.kind);
                if (header.compressors[slot] == 0) return error.InvalidChdMap;
                entry.length = try reader.read(map_header.length_bits);
                if (entry.length == 0 or
                    entry.length > options.max_compressed_hunk_bytes or
                    entry.length > 0x00ff_ffff)
                    return error.InvalidChdMap;
                entry.crc16 = @intCast(try reader.read(16));
                current_offset = std.math.add(
                    u64,
                    current_offset,
                    entry.length,
                ) catch return error.IntegerOverflow;
            },
            .uncompressed => {
                entry.length = header.hunk_bytes;
                entry.crc16 = @intCast(try reader.read(16));
                current_offset = std.math.add(
                    u64,
                    current_offset,
                    header.hunk_bytes,
                ) catch return error.IntegerOverflow;
            },
            .self => {
                entry.offset = try reader.read(map_header.self_bits);
                last_self = entry.offset;
            },
            .parent => {
                entry.offset = try reader.read(map_header.parent_unit_bits);
                last_parent = entry.offset;
            },
            .self_0 => {
                entry.kind = .self;
                entry.offset = last_self;
            },
            .self_1 => {
                last_self = std.math.add(u64, last_self, 1) catch
                    return error.IntegerOverflow;
                entry.kind = .self;
                entry.offset = last_self;
            },
            .parent_self => {
                const logical_hunk_offset = std.math.mul(
                    u64,
                    hunk_index,
                    header.hunk_bytes,
                ) catch return error.IntegerOverflow;
                last_parent = logical_hunk_offset / header.unit_bytes;
                entry.kind = .parent;
                entry.offset = last_parent;
            },
            .parent_0 => {
                entry.kind = .parent;
                entry.offset = last_parent;
            },
            .parent_1 => {
                last_parent = std.math.add(
                    u64,
                    last_parent,
                    units_per_hunk,
                ) catch return error.IntegerOverflow;
                entry.kind = .parent;
                entry.offset = last_parent;
            },
            .rle_small, .rle_large => return error.InvalidChdMap,
        }
        switch (entry.kind) {
            .codec_0, .codec_1, .codec_2, .codec_3, .uncompressed => {
                const encoded_end = std.math.add(
                    u64,
                    entry.offset,
                    entry.length,
                ) catch return error.IntegerOverflow;
                if (encoded_end > input.len) return error.TruncatedFrame;
            },
            .self => if (entry.offset >= hunk_index) return error.InvalidChdMap,
            .parent => if (!header.hasParent()) return error.InvalidChdMap,
            else => unreachable,
        }
        var raw_entry: [format.expanded_map_entry_size]u8 = undefined;
        entry.writeExpanded(&raw_entry);
        expanded_crc = format.crc16Update(expanded_crc, &raw_entry);
    }
    if (expanded_crc != map_header.expanded_crc16)
        return error.ChecksumMismatch;
    return entries;
}

fn parseMetadataChain(
    allocator: std.mem.Allocator,
    input: []const u8,
    first_offset: u64,
    max_entries: usize,
) Error![]format.Metadata {
    var entries: std.ArrayList(format.Metadata) = .empty;
    errdefer entries.deinit(allocator);
    var seen: std.AutoHashMap(u64, void) = .init(allocator);
    defer seen.deinit();
    var next = first_offset;
    while (next != 0) {
        if (entries.items.len >= max_entries) return error.OutputLimitExceeded;
        const result = try seen.getOrPut(next);
        if (result.found_existing) return error.InvalidChdMetadata;
        const offset = std.math.cast(usize, next) orelse
            return error.IntegerOverflow;
        const entry = try format.parseMetadata(input, offset);
        try entries.append(allocator, entry);
        next = entry.next_offset;
    }
    return entries.toOwnedSlice(allocator);
}

fn encodedSlice(input: []const u8, offset: u64, length: u32) Error![]const u8 {
    const start = std.math.cast(usize, offset) orelse
        return error.IntegerOverflow;
    const end = std.math.add(usize, start, length) catch
        return error.IntegerOverflow;
    if (end > input.len) return error.TruncatedFrame;
    return input[start..end];
}

fn copyEncoded(
    input: []const u8,
    offset: u64,
    length: u32,
    output: []u8,
) Error!void {
    if (output.len != length) return error.SizeMismatch;
    @memcpy(output, try encodedSlice(input, offset, length));
}

fn decodeCodec(
    allocator: std.mem.Allocator,
    codec: format.Codec,
    input: []const u8,
    hunk_bytes: u32,
) Error![]u8 {
    return switch (codec) {
        .zlib => deflate.decodeRawAutoAllocExactSize(
            allocator,
            input,
            hunk_bytes,
        ),
        .lzma => lzma.decodeChdPayloadAllocExactSize(
            allocator,
            input,
            hunk_bytes,
            format.alignedLzmaDictionarySize(hunk_bytes),
        ),
        .huffman => decoded: {
            const output = try allocator.alloc(u8, hunk_bytes);
            errdefer allocator.free(output);
            try huffman.decodeHunk(input, output);
            break :decoded output;
        },
        .zstd => zstd.decodeFrameAllocExactSize(allocator, input, hunk_bytes),
        else => error.UnsupportedChdCodec,
    };
}

test "CHD archive rejects a truncated header" {
    try std.testing.expectError(
        error.TruncatedFrame,
        Archive.initAlloc(std.testing.allocator, "MComprHD", .{}),
    );
}
