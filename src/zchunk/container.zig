const std = @import("std");
const core = @import("../core.zig");
const zstd = @import("../zstd.zig");
const compint = @import("compint.zig");
const hash = @import("hash.zig");

pub const Error = core.Error || zstd.Error || compint.Error || hash.Error ||
    std.mem.Allocator.Error || error{
    InvalidZchunk,
    UnsupportedZchunkCompression,
    UnsupportedZchunkFeature,
    ZchunkChunkOutOfRange,
};

pub const full_magic = [_]u8{ 0, 'Z', 'C', 'K', '1' };
pub const detached_magic = [_]u8{ 0, 'Z', 'H', 'R', '1' };

pub const Compression = enum(u8) {
    none = 0,
    zstandard = 2,
};

pub const Flags = struct {
    streams: bool,
    optional_elements: bool,
    uncompressed_source: bool,
};

pub const Entry = struct {
    number: usize,
    stream_id: usize,
    digest: []const u8,
    uncompressed_digest: ?[]const u8,
    body_offset: usize,
    compressed_size: usize,
    decoded_size: usize,
    dictionary: bool,
    stored: bool,
};

pub const EntryIterator = struct {
    archive: Archive,
    reader: compint.Reader,
    number: usize = 0,
    relative_body_offset: usize = 0,

    pub fn next(self: *EntryIterator) Error!?Entry {
        if (self.number == self.archive.entry_count) return null;
        const stream_id = if (self.archive.flags.streams)
            try self.reader.read()
        else if (self.number == 0)
            @as(usize, 0)
        else
            @as(usize, 1);
        const digest_size = self.archive.chunk_hash_kind.digestSize();
        const digest_end = try checkedEnd(self.reader.position, digest_size, self.reader.end);
        const digest = self.archive.bytes[self.reader.position..digest_end];
        self.reader.position = digest_end;
        const uncompressed_digest = if (self.archive.flags.uncompressed_source) blk: {
            const end = try checkedEnd(self.reader.position, digest_size, self.reader.end);
            const value = self.archive.bytes[self.reader.position..end];
            self.reader.position = end;
            break :blk value;
        } else null;
        const compressed_size = try self.reader.read();
        const decoded_size = try self.reader.read();
        const body_offset = try checkedAdd(self.archive.body_offset, self.relative_body_offset);
        self.relative_body_offset = try checkedAdd(self.relative_body_offset, compressed_size);
        const entry = Entry{
            .number = self.number,
            .stream_id = stream_id,
            .digest = digest,
            .uncompressed_digest = uncompressed_digest,
            .body_offset = body_offset,
            .compressed_size = compressed_size,
            .decoded_size = decoded_size,
            .dictionary = self.number == 0,
            .stored = self.archive.flags.uncompressed_source and hash.isZero(digest),
        };
        self.number += 1;
        return entry;
    }
};

pub const Archive = struct {
    bytes: []const u8,
    detached: bool,
    body_present: bool,
    full_hash_kind: hash.Kind,
    chunk_hash_kind: hash.Kind,
    flags: Flags,
    compression: Compression,
    header_size: usize,
    body_offset: usize,
    body_size: usize,
    entries_offset: usize,
    index_end: usize,
    entry_count: usize,
    decoded_size: usize,
    data_digest: []const u8,

    pub fn iterator(self: Archive) Error!EntryIterator {
        return .{
            .archive = self,
            .reader = try compint.Reader.initRange(self.bytes, self.entries_offset, self.index_end),
        };
    }

    pub fn entryAt(self: Archive, number: usize) Error!Entry {
        if (number >= self.entry_count) return error.ZchunkChunkOutOfRange;
        var cursor = try self.iterator();
        while (try cursor.next()) |entry| {
            if (entry.number == number) return entry;
        }
        return error.ZchunkChunkOutOfRange;
    }

    pub fn decodedSizeForStream(self: Archive, stream_id: usize) Error!usize {
        var total: usize = 0;
        var cursor = try self.iterator();
        while (try cursor.next()) |entry| {
            if (!entry.dictionary and entry.stream_id == stream_id)
                total = try checkedAdd(total, entry.decoded_size);
        }
        return total;
    }
};

pub fn parse(input: []const u8) Error!Archive {
    return parseInternal(input, false);
}

pub fn parseHeader(input: []const u8) Error!Archive {
    return parseInternal(input, true);
}

fn parseInternal(input: []const u8, allow_header_only: bool) Error!Archive {
    if (input.len < full_magic.len) return error.TruncatedFrame;
    const detached = if (std.mem.eql(u8, input[0..5], &full_magic))
        false
    else if (std.mem.eql(u8, input[0..5], &detached_magic))
        true
    else
        return error.InvalidMagic;

    var lead_reader = try compint.Reader.initRange(input, 5, input.len);
    const full_hash_kind = try hash.fromInt(try lead_reader.read());
    if (full_hash_kind != .sha1 and full_hash_kind != .sha256)
        return error.UnsupportedZchunkHash;
    const header_body_size = try lead_reader.read();
    const header_digest_offset = lead_reader.position;
    const digest_size = full_hash_kind.digestSize();
    const header_body_offset = try checkedEnd(header_digest_offset, digest_size, input.len);
    const header_end = try checkedEnd(header_body_offset, header_body_size, input.len);
    const expected_header_digest = input[header_digest_offset..header_body_offset];
    var actual_storage: [64]u8 = undefined;
    const actual_header_digest = if (detached)
        hash.digestSlices(
            full_hash_kind,
            &.{ &full_magic, input[5..header_digest_offset], input[header_body_offset..header_end] },
            &actual_storage,
        )
    else
        hash.digestSlices(
            full_hash_kind,
            &.{ input[0..header_digest_offset], input[header_body_offset..header_end] },
            &actual_storage,
        );
    if (!std.mem.eql(u8, expected_header_digest, actual_header_digest))
        return error.ChecksumMismatch;

    var reader = try compint.Reader.initRange(input, header_body_offset, header_end);
    const data_digest_end = try checkedEnd(reader.position, digest_size, reader.end);
    const data_digest = input[reader.position..data_digest_end];
    reader.position = data_digest_end;
    const flags_value = try reader.read();
    if (flags_value & ~@as(usize, 0x07) != 0) return error.UnsupportedZchunkFeature;
    const flags = Flags{
        .streams = flags_value & 1 != 0,
        .optional_elements = flags_value & 2 != 0,
        .uncompressed_source = flags_value & 4 != 0,
    };
    const compression = std.enums.fromInt(Compression, try reader.read()) orelse
        return error.UnsupportedZchunkCompression;
    if (flags.optional_elements) {
        const count = try reader.read();
        for (0..count) |_| {
            _ = try reader.read();
            const size = try reader.read();
            reader.position = try checkedEnd(reader.position, size, reader.end);
        }
    }
    const index_size = try reader.read();
    const index_start = reader.position;
    const index_end = try checkedEnd(index_start, index_size, reader.end);
    var index_reader = try compint.Reader.initRange(input, index_start, index_end);
    const chunk_hash_kind = try hash.fromInt(try index_reader.read());
    if (flags.uncompressed_source and
        (chunk_hash_kind == .sha1 or chunk_hash_kind == .sha512_128))
        return error.InvalidZchunk;
    const entry_count = try index_reader.read();
    if (entry_count == 0) return error.InvalidZchunk;
    const entries_offset = index_reader.position;

    var archive = Archive{
        .bytes = input,
        .detached = detached,
        .body_present = false,
        .full_hash_kind = full_hash_kind,
        .chunk_hash_kind = chunk_hash_kind,
        .flags = flags,
        .compression = compression,
        .header_size = header_end,
        .body_offset = header_end,
        .body_size = 0,
        .entries_offset = entries_offset,
        .index_end = index_end,
        .entry_count = entry_count,
        .decoded_size = 0,
        .data_digest = data_digest,
    };
    var iterator = try archive.iterator();
    var count: usize = 0;
    var body_size: usize = 0;
    var decoded_size: usize = 0;
    while (try iterator.next()) |entry| {
        if (entry.dictionary and entry.stream_id != 0) return error.InvalidZchunk;
        body_size = try checkedAdd(body_size, entry.compressed_size);
        if (!entry.dictionary and entry.stream_id == 1)
            decoded_size = try checkedAdd(decoded_size, entry.decoded_size);
        count += 1;
    }
    if (count != entry_count or iterator.reader.position != index_end)
        return error.InvalidZchunk;
    archive.body_size = body_size;
    archive.decoded_size = decoded_size;

    reader.position = index_end;
    const signature_count = try reader.read();
    for (0..signature_count) |_| {
        _ = try reader.read();
        const signature_size = try reader.read();
        reader.position = try checkedEnd(reader.position, signature_size, reader.end);
    }
    if (reader.position != header_end) return error.InvalidZchunk;
    if (detached) {
        if (input.len != header_end) return error.TrailingData;
        return archive;
    }
    if (allow_header_only and body_size != 0 and input.len == header_end) return archive;
    if (try checkedEnd(header_end, body_size, input.len) != input.len)
        return error.TrailingData;
    archive.body_present = true;
    try validateBody(archive);
    return archive;
}

fn validateBody(archive: Archive) Error!void {
    if (!archive.flags.uncompressed_source) {
        var storage: [64]u8 = undefined;
        const actual = hash.digest(
            archive.full_hash_kind,
            archive.bytes[archive.body_offset..],
            &storage,
        );
        if (!std.mem.eql(u8, actual, archive.data_digest)) return error.ChecksumMismatch;
    } else if (!hash.isZero(archive.data_digest)) {
        return error.InvalidZchunk;
    }

    var iterator = try archive.iterator();
    while (try iterator.next()) |entry| {
        const payload_end = try checkedEnd(
            entry.body_offset,
            entry.compressed_size,
            archive.bytes.len,
        );
        const payload = archive.bytes[entry.body_offset..payload_end];
        if (entry.dictionary and entry.compressed_size == 0 and entry.decoded_size == 0) {
            if (!hash.isZero(entry.digest)) return error.InvalidZchunk;
            continue;
        }
        if (entry.stored) {
            if (entry.compressed_size != entry.decoded_size) return error.InvalidZchunk;
            const expected = entry.uncompressed_digest orelse return error.InvalidZchunk;
            var storage: [64]u8 = undefined;
            const actual = hash.digest(archive.chunk_hash_kind, payload, &storage);
            if (!std.mem.eql(u8, expected, actual)) return error.ChecksumMismatch;
        } else {
            var storage: [64]u8 = undefined;
            const actual = hash.digest(archive.chunk_hash_kind, payload, &storage);
            if (!std.mem.eql(u8, actual, entry.digest)) return error.ChecksumMismatch;
        }
    }
}

pub fn decodeAllocLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    max_output_len: usize,
) Error![]u8 {
    return decodeStreamAllocLimited(allocator, input, 1, max_output_len);
}

pub fn decodeStreamAllocLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    stream_id: usize,
    max_output_len: usize,
) Error![]u8 {
    const archive = try parse(input);
    if (!archive.body_present) return error.UnsupportedZchunkFeature;
    const output_size = try archive.decodedSizeForStream(stream_id);
    if (output_size > max_output_len) return error.OutputLimitExceeded;
    const dictionary = try decodeDictionaryAlloc(allocator, archive);
    defer if (dictionary) |bytes| allocator.free(bytes);
    var output = try allocator.alloc(u8, output_size);
    errdefer allocator.free(output);
    var output_offset: usize = 0;
    var iterator = try archive.iterator();
    while (try iterator.next()) |entry| {
        if (entry.dictionary or entry.stream_id != stream_id) continue;
        const decoded = try decodeEntryAlloc(allocator, archive, entry, dictionary);
        defer allocator.free(decoded);
        @memcpy(output[output_offset..][0..decoded.len], decoded);
        output_offset += decoded.len;
    }
    return output;
}

pub fn decodeChunkAllocLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    number: usize,
    max_output_len: usize,
) Error![]u8 {
    const archive = try parse(input);
    if (!archive.body_present) return error.UnsupportedZchunkFeature;
    const entry = try archive.entryAt(number);
    if (entry.decoded_size > max_output_len) return error.OutputLimitExceeded;
    const dictionary = if (entry.dictionary)
        null
    else
        try decodeDictionaryAlloc(allocator, archive);
    defer if (dictionary) |bytes| allocator.free(bytes);
    return decodeEntryAlloc(allocator, archive, entry, dictionary);
}

fn decodeDictionaryAlloc(
    allocator: std.mem.Allocator,
    archive: Archive,
) Error!?[]u8 {
    const entry = try archive.entryAt(0);
    if (entry.compressed_size == 0 and entry.decoded_size == 0) return null;
    return try decodeEntryAlloc(allocator, archive, entry, null);
}

fn decodeEntryAlloc(
    allocator: std.mem.Allocator,
    archive: Archive,
    entry: Entry,
    dictionary_bytes: ?[]const u8,
) Error![]u8 {
    const payload_end = try checkedEnd(
        entry.body_offset,
        entry.compressed_size,
        archive.bytes.len,
    );
    const payload = archive.bytes[entry.body_offset..payload_end];
    const decoded = if (archive.compression == .none or entry.stored)
        try allocator.dupe(u8, payload)
    else if (dictionary_bytes) |dictionary_data| blk: {
        const dictionary = if (zstd.isStandardDictionary(dictionary_data))
            (try zstd.NativeDictionary.initFromStandardDictionary(dictionary_data)).dictionary
        else
            zstd.NativeDictionary.initRawContent(dictionary_data);
        break :blk try zstd.decodeFrameAllocWithDictionaryExactSize(
            allocator,
            payload,
            dictionary,
            entry.decoded_size,
        );
    } else try zstd.decodeFrameAllocExactSize(allocator, payload, entry.decoded_size);
    errdefer allocator.free(decoded);
    if (decoded.len != entry.decoded_size) return error.SizeMismatch;
    if (archive.flags.uncompressed_source) {
        const expected = entry.uncompressed_digest orelse return error.InvalidZchunk;
        var storage: [64]u8 = undefined;
        const actual = hash.digest(archive.chunk_hash_kind, decoded, &storage);
        if (!std.mem.eql(u8, expected, actual)) return error.ChecksumMismatch;
    }
    return decoded;
}

fn checkedAdd(a: usize, b: usize) Error!usize {
    return std.math.add(usize, a, b) catch return error.IntegerOverflow;
}

fn checkedEnd(start: usize, size: usize, limit: usize) Error!usize {
    const end = try checkedAdd(start, size);
    if (end > limit) return error.TruncatedFrame;
    return end;
}

test "zchunk 1.1.16 reference file parses verifies and decodes" {
    const allocator = std.testing.allocator;
    const encoded_hex = std.mem.trim(
        u8,
        @embedFile("testdata/zchunk-1.1.16-manual.zck.hex"),
        " \r\n\t",
    );
    const encoded = try allocator.alloc(u8, encoded_hex.len / 2);
    defer allocator.free(encoded);
    _ = try std.fmt.hexToBytes(encoded, encoded_hex);
    const archive = try parse(encoded);
    try std.testing.expect(!archive.detached);
    try std.testing.expectEqual(hash.Kind.sha256, archive.full_hash_kind);
    try std.testing.expectEqual(hash.Kind.sha512_128, archive.chunk_hash_kind);
    try std.testing.expectEqual(Compression.zstandard, archive.compression);
    try std.testing.expectEqual(@as(usize, 115), archive.header_size);
    try std.testing.expectEqual(@as(usize, 2), archive.entry_count);
    try std.testing.expectEqual(@as(usize, 17_000), archive.decoded_size);
    const dictionary = try archive.entryAt(0);
    try std.testing.expect(dictionary.dictionary);
    try std.testing.expectEqual(@as(usize, 0), dictionary.decoded_size);
    const data = try archive.entryAt(1);
    try std.testing.expectEqual(@as(usize, 35), data.compressed_size);
    try std.testing.expectEqual(@as(usize, 17_000), data.decoded_size);
    const decoded = try decodeAllocLimited(allocator, encoded, 17_000);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "alpha beta gamma\n" ** 1000, decoded);

    const header_only = encoded[0..archive.header_size];
    const parsed_header = try parseHeader(header_only);
    try std.testing.expect(!parsed_header.body_present);
    try std.testing.expectError(error.TruncatedFrame, parse(header_only));
    const detached = try allocator.dupe(u8, header_only);
    defer allocator.free(detached);
    @memcpy(detached[0..detached_magic.len], &detached_magic);
    const detached_archive = try parse(detached);
    try std.testing.expect(detached_archive.detached);
    try std.testing.expect(!detached_archive.body_present);
}

test "zchunk rejects corrupt header body and output limits" {
    const allocator = std.testing.allocator;
    const encoded_hex = std.mem.trim(
        u8,
        @embedFile("testdata/zchunk-1.1.16-manual.zck.hex"),
        " \r\n\t",
    );
    const encoded = try allocator.alloc(u8, encoded_hex.len / 2);
    defer allocator.free(encoded);
    _ = try std.fmt.hexToBytes(encoded, encoded_hex);
    encoded[10] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, parse(encoded));
    encoded[10] ^= 1;
    encoded[encoded.len - 1] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, parse(encoded));
    encoded[encoded.len - 1] ^= 1;
    try std.testing.expectError(
        error.OutputLimitExceeded,
        decodeAllocLimited(allocator, encoded, 16_999),
    );
    try std.testing.expectError(error.TruncatedFrame, parse(encoded[0 .. encoded.len - 1]));
}
