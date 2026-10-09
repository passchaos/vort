const std = @import("std");
const checksum = @import("../checksum.zig");
const core = @import("../core.zig");
const number = @import("number.zig");
const streams_mod = @import("streams.zig");
const files_mod = @import("files.zig");
const types = @import("types.zig");
const deflate = @import("../deflate.zig");
const bzip2 = @import("../bzip2.zig");
const lzma_decoder = @import("../lzma/decoder.zig");
const xz_container = @import("../xz/container.zig");
const xz_filters = @import("../xz/filters.zig");
const bcj2 = @import("bcj2.zig");

pub const Error = core.Error || number.Error || streams_mod.Error || files_mod.Error ||
    deflate.Error || bzip2.Error || lzma_decoder.Error || xz_container.Error || error{
    Invalid7zArchive,
    Unsupported7zFeature,
    EntryNotFound,
    EntryHasNoStream,
};

pub const Entry = types.Entry;

pub const DecodeOptions = struct {
    max_output_len: usize = std.math.maxInt(usize),
    max_dictionary_size: usize = 512 * 1024 * 1024,
    max_folder_output_len: usize = 512 * 1024 * 1024,
};

pub const ParseOptions = struct {
    max_encoded_header_size: usize = 64 * 1024 * 1024,
    max_dictionary_size: usize = 64 * 1024 * 1024,
    max_entries: usize = 1_000_000,
    max_streams: usize = 1_000_000,
};

const signature = [_]u8{ '7', 'z', 0xbc, 0xaf, 0x27, 0x1c };
const signature_header_size: usize = 32;

const Nid = struct {
    const end: u8 = 0x00;
    const header: u8 = 0x01;
    const archive_properties: u8 = 0x02;
    const additional_streams: u8 = 0x03;
    const main_streams: u8 = 0x04;
    const files: u8 = 0x05;
    const encoded_header: u8 = 0x17;
};

pub const Archive = struct {
    allocator: std.mem.Allocator,
    bytes: []const u8,
    entries: []Entry,
    streams: streams_mod.Streams,
    next_header_start: usize,
    next_header_size: usize,
    packed_data_limit: usize,

    pub fn deinit(self: Archive) void {
        for (self.entries) |entry| self.allocator.free(entry.name);
        self.allocator.free(self.entries);
        self.streams.deinit();
    }

    pub fn entryAt(self: Archive, index: usize) Error!Entry {
        if (index >= self.entries.len) return error.EntryNotFound;
        return self.entries[index];
    }

    pub fn find(self: Archive, name: []const u8) ?Entry {
        for (self.entries) |entry| if (std.mem.eql(u8, entry.name, name)) return entry;
        return null;
    }

    pub fn extractEntryInto(self: Archive, entry: Entry, output: []u8) !usize {
        const size = std.math.cast(usize, entry.size) orelse return error.OutputTooSmall;
        if (output.len < size) return error.OutputTooSmall;
        const decoded = try self.decodeEntryAllocWithOptions(self.allocator, entry, .{
            .max_output_len = output.len,
        });
        defer self.allocator.free(decoded);
        @memcpy(output[0..decoded.len], decoded);
        return decoded.len;
    }

    pub fn extractEntryAlloc(self: Archive, allocator: std.mem.Allocator, entry: Entry) ![]u8 {
        return self.extractEntryAllocLimited(allocator, entry, std.math.maxInt(usize));
    }

    pub fn extractEntryAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        entry: Entry,
        max_output_len: usize,
    ) ![]u8 {
        return self.decodeEntryAllocWithOptions(allocator, entry, .{ .max_output_len = max_output_len });
    }

    pub fn decodeEntryAllocWithOptions(
        self: Archive,
        allocator: std.mem.Allocator,
        entry: Entry,
        options: DecodeOptions,
    ) ![]u8 {
        const folder_index = entry.folder_index orelse {
            if (entry.kind == .file and entry.size == 0) return allocator.alloc(u8, 0);
            return error.EntryHasNoStream;
        };
        const folder = self.streams.folders[folder_index];
        const folder_size = std.math.cast(usize, folder.unpack_size) orelse
            return error.OutputLimitExceeded;
        const entry_size = std.math.cast(usize, entry.size) orelse
            return error.OutputLimitExceeded;
        if (entry_size > options.max_output_len) return error.OutputLimitExceeded;
        if (folder_size > options.max_folder_output_len) return error.OutputLimitExceeded;
        const decoded = try decodeFolderAlloc(
            allocator,
            self.bytes,
            self.packed_data_limit,
            &self.streams,
            folder_index,
            folder_size,
            options.max_dictionary_size,
        );
        errdefer allocator.free(decoded);
        const entry_start = std.math.cast(usize, entry.offset_in_folder) orelse
            return error.Invalid7zArchive;
        const entry_end = std.math.add(usize, entry_start, entry_size) catch
            return error.Invalid7zArchive;
        if (entry_end > decoded.len) return error.SizeMismatch;
        const entry_bytes = decoded[entry_start..entry_end];
        if (entry.crc32) |expected|
            if (checksum.crc32Best(entry_bytes) != expected) return error.ChecksumMismatch;
        if (entry_start == 0 and entry_end == decoded.len) return decoded;
        const result = try allocator.dupe(u8, entry_bytes);
        allocator.free(decoded);
        return result;
    }

    pub fn extractByNameAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        name: []const u8,
        max_output_len: usize,
    ) ![]u8 {
        const entry = self.find(name) orelse return error.EntryNotFound;
        return self.extractEntryAllocLimited(allocator, entry, max_output_len);
    }

    pub fn extractByNameAlloc(self: Archive, allocator: std.mem.Allocator, name: []const u8) ![]u8 {
        return self.extractByNameAllocLimited(allocator, name, std.math.maxInt(usize));
    }
};

pub fn parseAlloc(allocator: std.mem.Allocator, input: []const u8) !Archive {
    return parseAllocWithOptions(allocator, input, .{});
}

pub fn parseAllocWithOptions(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: ParseOptions,
) !Archive {
    if (input.len < signature_header_size) return error.TruncatedFrame;
    if (!std.mem.eql(u8, input[0..signature.len], &signature)) return error.InvalidMagic;
    if (input[6] != 0 or input[7] != 4) return error.UnsupportedVersion;
    if (checksum.crc32Best(input[12..32]) != std.mem.readInt(u32, input[8..12], .little))
        return error.ChecksumMismatch;

    const next_offset_u64 = std.mem.readInt(u64, input[12..20], .little);
    const next_size_u64 = std.mem.readInt(u64, input[20..28], .little);
    const next_offset = std.math.cast(usize, next_offset_u64) orelse
        return error.Invalid7zArchive;
    const next_size = std.math.cast(usize, next_size_u64) orelse
        return error.Invalid7zArchive;
    const next_start = std.math.add(usize, signature_header_size, next_offset) catch
        return error.Invalid7zArchive;
    const next_end = std.math.add(usize, next_start, next_size) catch
        return error.Invalid7zArchive;
    if (next_end != input.len) return error.Invalid7zArchive;
    const next_header = input[next_start..next_end];
    if (checksum.crc32Best(next_header) != std.mem.readInt(u32, input[28..32], .little))
        return error.ChecksumMismatch;

    var owned_header: ?[]u8 = null;
    defer if (owned_header) |bytes| allocator.free(bytes);
    var header_bytes = next_header;
    var packed_data_limit = next_start;
    if (next_header.len == 0) return error.Invalid7zArchive;
    if (next_header[0] == Nid.encoded_header) {
        var encoded_reader = number.Reader.init(next_header[1..]);
        const encoded_streams = try streams_mod.parse(allocator, &encoded_reader, options.max_streams);
        defer encoded_streams.deinit();
        if (encoded_reader.remaining() != 0) return error.TrailingData;
        if (encoded_streams.folders.len != 1 or encoded_streams.substream_sizes.len != 1)
            return error.Unsupported7zFeature;
        try validatePackedStreams(input, next_start, &encoded_streams);
        const encoded_pack_start_u64 = std.math.add(u64, signature_header_size, encoded_streams.pack_position) catch
            return error.IntegerOverflow;
        packed_data_limit = std.math.cast(usize, encoded_pack_start_u64) orelse
            return error.Invalid7zArchive;
        const unpack_size = std.math.cast(usize, encoded_streams.folders[0].unpack_size) orelse
            return error.OutputLimitExceeded;
        if (unpack_size > options.max_encoded_header_size) return error.OutputLimitExceeded;
        owned_header = try decodeFolderAlloc(
            allocator,
            input,
            next_start,
            &encoded_streams,
            0,
            unpack_size,
            options.max_dictionary_size,
        );
        header_bytes = owned_header.?;
    }

    var reader = number.Reader.init(header_bytes);
    if (try reader.readByte() != Nid.header) return error.Invalid7zArchive;

    var streams = streams_mod.Streams{ .allocator = allocator };
    errdefer streams.deinit();
    var have_streams = false;
    var files: ?files_mod.Files = null;
    errdefer if (files) |owned| owned.deinit();
    while (true) switch (try reader.readByte()) {
        Nid.end => break,
        Nid.archive_properties => try skipArchiveProperties(&reader),
        Nid.additional_streams => return error.Unsupported7zFeature,
        Nid.main_streams => {
            if (have_streams) return error.Invalid7zArchive;
            streams = try streams_mod.parse(allocator, &reader, options.max_streams);
            have_streams = true;
        },
        Nid.files => {
            if (files != null) return error.Invalid7zArchive;
            files = try files_mod.parse(allocator, &reader, &streams, options.max_entries);
        },
        else => return error.Invalid7zArchive,
    };
    if (reader.remaining() != 0) return error.TrailingData;
    const owned_files = files orelse return error.Invalid7zArchive;
    try validatePackedStreams(input, packed_data_limit, &streams);
    return .{
        .allocator = allocator,
        .bytes = input,
        .entries = owned_files.entries,
        .streams = streams,
        .next_header_start = next_start,
        .next_header_size = next_size,
        .packed_data_limit = packed_data_limit,
    };
}

fn decodeFolderAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    packed_limit: usize,
    streams: *const streams_mod.Streams,
    folder_index: usize,
    expected_size: usize,
    max_dictionary_size: usize,
) ![]u8 {
    if (folder_index >= streams.folders.len) return error.Invalid7zArchive;
    const folder = streams.folders[folder_index];
    if (folder.bcj2_coder_index) |bcj2_index| {
        if (folder.pack_stream_count != 4 or folder.coder_count != 2)
            return error.Invalid7zArchive;
        var packed_streams: [4][]const u8 = undefined;
        for (&packed_streams, 0..) |*packed_stream, index| {
            packed_stream.* = try packBytes(input, packed_limit, streams, folder.pack_index + index);
            if (streams.pack_crcs[folder.pack_index + index]) |expected|
                if (checksum.crc32Best(packed_stream.*) != expected) return error.ChecksumMismatch;
        }
        const primary_index = folder.decode_order[0];
        const primary = folder.coders[primary_index];
        const main_size = std.math.cast(
            usize,
            folder.coder_unpack_sizes[primary_index],
        ) orelse return error.OutputLimitExceeded;
        const side_size = std.math.add(
            usize,
            packed_streams[1].len,
            packed_streams[2].len,
        ) catch return error.IntegerOverflow;
        const calculated_size = std.math.add(usize, main_size, side_size) catch
            return error.IntegerOverflow;
        if (main_size > expected_size or side_size > expected_size or
            calculated_size != expected_size)
            return error.Invalid7zArchive;
        const main = try decodePrimaryAlloc(
            allocator,
            packed_streams[0],
            primary,
            main_size,
            max_dictionary_size,
        );
        defer allocator.free(main);
        const bcj_coder = folder.coders[bcj2_index];
        const start_ip = if (bcj_coder.properties_len == 4)
            std.mem.readInt(u32, bcj_coder.propertyBytes()[0..4], .little)
        else
            0;
        const decoded = try bcj2.decodeAlloc(
            allocator,
            main,
            packed_streams[1],
            packed_streams[2],
            packed_streams[3],
            expected_size,
            start_ip,
        );
        errdefer allocator.free(decoded);
        if (folder.crc32) |expected|
            if (checksum.crc32Best(decoded) != expected) return error.ChecksumMismatch;
        return decoded;
    }

    const packed_bytes = try packBytes(input, packed_limit, streams, folder.pack_index);
    if (streams.pack_crcs[folder.pack_index]) |expected|
        if (checksum.crc32Best(packed_bytes) != expected) return error.ChecksumMismatch;

    const primary = folder.coders[folder.decode_order[0]];
    const decoded = try decodePrimaryAlloc(
        allocator,
        packed_bytes,
        primary,
        expected_size,
        max_dictionary_size,
    );
    errdefer allocator.free(decoded);
    for (folder.decode_order[1..folder.coder_count]) |coder_index| {
        const coder = folder.coders[coder_index];
        const filter_id: u64 = switch (coder.method) {
            .delta => 0x03,
            .x86 => 0x04,
            .powerpc => 0x05,
            .ia64 => 0x06,
            .arm => 0x07,
            .arm_thumb => 0x08,
            .sparc => 0x09,
            else => return error.Unsupported7zFeature,
        };
        const filter = xz_filters.parse(filter_id, coder.propertyBytes()) catch |err| switch (err) {
            error.InvalidXzHeader => return error.Invalid7zArchive,
            error.UnsupportedXzFeature => return error.Unsupported7zFeature,
        };
        xz_filters.decodeChain(decoded, &.{filter});
    }
    if (decoded.len != expected_size) return error.SizeMismatch;
    if (folder.crc32) |expected|
        if (checksum.crc32Best(decoded) != expected) return error.ChecksumMismatch;
    return decoded;
}

fn decodePrimaryAlloc(
    allocator: std.mem.Allocator,
    packed_bytes: []const u8,
    primary: streams_mod.Coder,
    expected_size: usize,
    max_dictionary_size: usize,
) ![]u8 {
    return switch (primary.method) {
        .copy => try allocator.dupe(u8, packed_bytes),
        .deflate => try deflate.decodeRawAutoAllocExactSize(allocator, packed_bytes, expected_size),
        .bzip2 => try bzip2.decodeAllocLimited(allocator, packed_bytes, expected_size),
        .lzma => try lzma_decoder.decode7zPayloadAllocLimited(
            allocator,
            packed_bytes,
            primary.propertyBytes(),
            expected_size,
            max_dictionary_size,
        ),
        .lzma2 => try xz_container.decode7zPayloadAllocLimited(
            allocator,
            packed_bytes,
            primary.propertyBytes()[0],
            expected_size,
            max_dictionary_size,
        ),
        else => return error.Unsupported7zFeature,
    };
}

fn packBytes(
    input: []const u8,
    packed_limit: usize,
    streams: *const streams_mod.Streams,
    index: usize,
) Error![]const u8 {
    if (index >= streams.pack_sizes.len) return error.Invalid7zArchive;
    var relative: u64 = streams.pack_position;
    for (streams.pack_sizes[0..index]) |size|
        relative = std.math.add(u64, relative, size) catch return error.IntegerOverflow;
    const start_u64 = std.math.add(u64, signature_header_size, relative) catch
        return error.IntegerOverflow;
    const start = std.math.cast(usize, start_u64) orelse return error.Invalid7zArchive;
    const size = std.math.cast(usize, streams.pack_sizes[index]) orelse
        return error.Invalid7zArchive;
    const end = std.math.add(usize, start, size) catch return error.Invalid7zArchive;
    if (end > packed_limit or end > input.len) return error.Invalid7zArchive;
    return input[start..end];
}

fn skipArchiveProperties(reader: *number.Reader) !void {
    while (true) {
        const property = try reader.readByte();
        if (property == Nid.end) return;
        _ = try reader.take(try reader.readSize());
    }
}

fn validatePackedStreams(input: []const u8, next_header_start: usize, streams: *const streams_mod.Streams) Error!void {
    var end_u64 = std.math.add(u64, signature_header_size, streams.pack_position) catch
        return error.IntegerOverflow;
    for (streams.pack_sizes) |size|
        end_u64 = std.math.add(u64, end_u64, size) catch return error.IntegerOverflow;
    const end = std.math.cast(usize, end_u64) orelse return error.Invalid7zArchive;
    if (end > next_header_start or end > input.len) return error.Invalid7zArchive;
}

test "7z parser reads external stored archive and extracts Copy data" {
    const encoded_hex = "377abcaf271c000475f1135610000000000000004a000000000000003201544f68656c6c6f20736576656e207a69700a0104060001091000070b01000101000c1000080a014ec301fe00000501111500680065006c006c006f002e007400780074000000140a0100a20454527157dd01150601002080b4810000";
    var encoded: [encoded_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&encoded, encoded_hex);
    const archive = try parseAlloc(std.testing.allocator, &encoded);
    defer archive.deinit();
    try std.testing.expectEqual(@as(usize, 1), archive.entries.len);
    try std.testing.expectEqualStrings("hello.txt", archive.entries[0].name);
    const decoded = try archive.extractEntryAlloc(std.testing.allocator, archive.entries[0]);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "hello seven zip\n", decoded);
}

test "7z parser decodes an LZMA header and solid LZMA2 folder" {
    const encoded_hex = "377abcaf271c00040a2979aa87000000000000002000000000000000ade04c8f01001b68656c6c6f20736576656e207a69700a7365636f6e642066696c650a000000813307ae0fd00eb03c9f3f47410bb386352f17fd2617271b1712b76cc646cd175a374f3e01028eede9c4c3121b4b36e57d12bc0a891dbf7ec82b8fcb26594152cd05a314a4c1f0d70bff298133b03ae4fe5d260d79f6b918732ea45ea456b583a30000000017062001096700070b01000123030101055d001000000c7e0a013f0929860000";
    var encoded: [encoded_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&encoded, encoded_hex);
    const archive = try parseAlloc(std.testing.allocator, &encoded);
    defer archive.deinit();
    try std.testing.expectEqual(@as(usize, 2), archive.entries.len);
    try std.testing.expectEqualStrings("hello.txt", archive.entries[0].name);
    try std.testing.expectEqualStrings("second.txt", archive.entries[1].name);
    try std.testing.expectEqual(archive.entries[0].folder_index, archive.entries[1].folder_index);

    const first = try archive.extractByNameAlloc(std.testing.allocator, "hello.txt");
    defer std.testing.allocator.free(first);
    try std.testing.expectEqualSlices(u8, "hello seven zip\n", first);
    const second = try archive.extractByNameAlloc(std.testing.allocator, "second.txt");
    defer std.testing.allocator.free(second);
    try std.testing.expectEqualSlices(u8, "second file\n", second);
}
