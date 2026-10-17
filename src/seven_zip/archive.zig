const std = @import("std");
const aes = @import("aes.zig");
const checksum = @import("../checksum.zig");
const core = @import("../core.zig");
const number = @import("number.zig");
const packed_input = @import("packed_input.zig");
const source_mod = @import("source.zig");
const streams_mod = @import("streams.zig");
const files_mod = @import("files.zig");
const types = @import("types.zig");
const deflate = @import("../deflate.zig");
const bzip2 = @import("../bzip2.zig");
const lzma_decoder = @import("../lzma/decoder.zig");
const xz_container = @import("../xz/container.zig");
const xz_filters = @import("../xz/filters.zig");
const bcj2 = @import("bcj2.zig");
const ppmd7 = @import("ppmd7.zig");

pub const Error = core.Error || number.Error || streams_mod.Error || files_mod.Error || aes.Error ||
    deflate.Error || bzip2.Error || lzma_decoder.Error || xz_container.Error || ppmd7.Error ||
    packed_input.Error || source_mod.Error || error{
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
    max_packed_stream_size: usize = 512 * 1024 * 1024,
    max_kdf_cycles_power: u6 = aes.max_cycles_power,
    password: ?[]const u8 = null,
};

pub const ParseOptions = struct {
    max_next_header_size: usize = 64 * 1024 * 1024,
    max_encoded_header_size: usize = 64 * 1024 * 1024,
    max_packed_stream_size: usize = 64 * 1024 * 1024,
    max_external_metadata_size: usize = 64 * 1024 * 1024,
    max_dictionary_size: usize = 64 * 1024 * 1024,
    max_entries: usize = 1_000_000,
    max_streams: usize = 1_000_000,
    max_kdf_cycles_power: u6 = aes.max_cycles_power,
    password: ?[]const u8 = null,
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
        return decodeEntryFromInputAlloc(
            allocator,
            entry,
            &self.streams,
            packed_input.Input.fromBytes(
                self.bytes,
                self.packed_data_limit,
                options.max_packed_stream_size,
            ),
            options,
        );
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
    const layout = try parseSignatureHeader(input, input.len, options);
    const next_start = std.math.cast(usize, layout.next_header_start) orelse
        return error.Invalid7zArchive;
    const next_end = std.math.add(usize, next_start, layout.next_header_size) catch
        return error.Invalid7zArchive;
    const next_header = input[next_start..next_end];
    if (checksum.crc32Best(next_header) != layout.next_header_crc)
        return error.ChecksumMismatch;
    const parsed = try parseBodyAlloc(
        allocator,
        next_header,
        packed_input.Input.fromBytes(input, next_start, options.max_packed_stream_size),
        options,
    );
    errdefer parsed.deinit();
    return .{
        .allocator = allocator,
        .bytes = input,
        .entries = parsed.entries,
        .streams = parsed.streams,
        .next_header_start = next_start,
        .next_header_size = layout.next_header_size,
        .packed_data_limit = std.math.cast(usize, parsed.packed_data_limit) orelse
            return error.Invalid7zArchive,
    };
}

pub const HeaderLayout = struct {
    next_header_start: u64,
    next_header_size: usize,
    next_header_crc: u32,
};

pub fn parseSignatureHeader(
    header: []const u8,
    archive_len: u64,
    options: ParseOptions,
) Error!HeaderLayout {
    if (header.len < signature_header_size) return error.TruncatedFrame;
    if (!std.mem.eql(u8, header[0..signature.len], &signature)) return error.InvalidMagic;
    if (header[6] != 0 or header[7] != 4) return error.UnsupportedVersion;
    if (checksum.crc32Best(header[12..32]) != std.mem.readInt(u32, header[8..12], .little))
        return error.ChecksumMismatch;

    const next_offset = std.mem.readInt(u64, header[12..20], .little);
    const next_size_u64 = std.mem.readInt(u64, header[20..28], .little);
    const next_size = std.math.cast(usize, next_size_u64) orelse
        return error.OutputLimitExceeded;
    if (next_size > options.max_next_header_size) return error.OutputLimitExceeded;
    const next_start = std.math.add(u64, signature_header_size, next_offset) catch
        return error.IntegerOverflow;
    const next_end = std.math.add(u64, next_start, next_size_u64) catch
        return error.IntegerOverflow;
    if (next_end != archive_len) return error.Invalid7zArchive;
    return .{
        .next_header_start = next_start,
        .next_header_size = next_size,
        .next_header_crc = std.mem.readInt(u32, header[28..32], .little),
    };
}

pub const ParsedArchive = struct {
    allocator: std.mem.Allocator,
    entries: []Entry,
    streams: streams_mod.Streams,
    packed_data_limit: u64,

    pub fn deinit(self: ParsedArchive) void {
        for (self.entries) |entry| self.allocator.free(entry.name);
        self.allocator.free(self.entries);
        self.streams.deinit();
    }
};

pub fn parseBodyAlloc(
    allocator: std.mem.Allocator,
    next_header: []const u8,
    initial_input: packed_input.Input,
    options: ParseOptions,
) !ParsedArchive {
    var owned_header: ?[]u8 = null;
    defer if (owned_header) |bytes| allocator.free(bytes);
    var header_bytes = next_header;
    var packed_data_limit = initial_input.packedLimit();
    if (next_header.len == 0) return error.Invalid7zArchive;
    if (next_header[0] == Nid.encoded_header) {
        var encoded_reader = number.Reader.init(next_header[1..]);
        const encoded_streams = try streams_mod.parse(allocator, &encoded_reader, options.max_streams);
        defer encoded_streams.deinit();
        if (encoded_reader.remaining() != 0) return error.TrailingData;
        if (encoded_streams.folders.len != 1 or encoded_streams.substream_sizes.len != 1)
            return error.Unsupported7zFeature;
        const encoded_input = initial_input;
        try encoded_input.validateStreams(&encoded_streams);
        const encoded_pack_start_u64 = std.math.add(u64, signature_header_size, encoded_streams.pack_position) catch
            return error.IntegerOverflow;
        packed_data_limit = encoded_pack_start_u64;
        const unpack_size = std.math.cast(usize, encoded_streams.folders[0].unpack_size) orelse
            return error.OutputLimitExceeded;
        if (unpack_size > options.max_encoded_header_size) return error.OutputLimitExceeded;
        owned_header = try decodeFolderAlloc(
            allocator,
            encoded_input,
            &encoded_streams,
            0,
            unpack_size,
            options.max_dictionary_size,
            options.password,
            options.max_kdf_cycles_power,
        );
        header_bytes = owned_header.?;
    }

    var reader = number.Reader.init(header_bytes);
    if (try reader.readByte() != Nid.header) return error.Invalid7zArchive;

    var streams = streams_mod.Streams{ .allocator = allocator };
    errdefer streams.deinit();
    var have_streams = false;
    var external_streams: ?[][]u8 = null;
    defer if (external_streams) |items| freeExternalStreams(allocator, items);
    var files: ?files_mod.Files = null;
    errdefer if (files) |owned| owned.deinit();
    while (true) switch (try reader.readByte()) {
        Nid.end => break,
        Nid.archive_properties => try skipArchiveProperties(&reader),
        Nid.additional_streams => {
            if (external_streams != null or have_streams or files != null)
                return error.Invalid7zArchive;
            const additional = try streams_mod.parse(allocator, &reader, options.max_streams);
            defer additional.deinit();
            const additional_input = initial_input.withLimit(packed_data_limit);
            try additional_input.validateStreams(&additional);
            external_streams = try decodeExternalStreamsAlloc(
                allocator,
                additional_input,
                &additional,
                options.max_dictionary_size,
                options.max_external_metadata_size,
                options.password,
                options.max_kdf_cycles_power,
            );
        },
        Nid.main_streams => {
            if (have_streams) return error.Invalid7zArchive;
            streams = try streams_mod.parseWithExternal(
                allocator,
                &reader,
                options.max_streams,
                if (external_streams) |items| items else &.{},
            );
            have_streams = true;
        },
        Nid.files => {
            if (files != null) return error.Invalid7zArchive;
            files = try files_mod.parse(
                allocator,
                &reader,
                &streams,
                if (external_streams) |items| items else &.{},
                options.max_entries,
            );
        },
        else => return error.Invalid7zArchive,
    };
    if (reader.remaining() != 0) return error.TrailingData;
    const owned_files = files orelse return error.Invalid7zArchive;
    try initial_input.withLimit(packed_data_limit).validateStreams(&streams);
    return .{
        .allocator = allocator,
        .entries = owned_files.entries,
        .streams = streams,
        .packed_data_limit = packed_data_limit,
    };
}

pub fn decodeEntryFromInputAlloc(
    allocator: std.mem.Allocator,
    entry: Entry,
    streams: *const streams_mod.Streams,
    input: packed_input.Input,
    options: DecodeOptions,
) ![]u8 {
    const folder_index = entry.folder_index orelse {
        if (entry.kind == .file and entry.size == 0) return allocator.alloc(u8, 0);
        return error.EntryHasNoStream;
    };
    if (folder_index >= streams.folders.len) return error.Invalid7zArchive;
    const folder = streams.folders[folder_index];
    const folder_size = std.math.cast(usize, folder.unpack_size) orelse
        return error.OutputLimitExceeded;
    const entry_size = std.math.cast(usize, entry.size) orelse
        return error.OutputLimitExceeded;
    if (entry_size > options.max_output_len) return error.OutputLimitExceeded;
    if (folder_size > options.max_folder_output_len) return error.OutputLimitExceeded;
    const decoded = try decodeFolderAlloc(
        allocator,
        input,
        streams,
        folder_index,
        folder_size,
        options.max_dictionary_size,
        options.password,
        options.max_kdf_cycles_power,
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

fn decodeExternalStreamsAlloc(
    allocator: std.mem.Allocator,
    input: packed_input.Input,
    streams: *const streams_mod.Streams,
    max_dictionary_size: usize,
    max_output_size: usize,
    password: ?[]const u8,
    max_kdf_cycles_power: u6,
) ![][]u8 {
    const items = try allocator.alloc([]u8, streams.folders.len);
    var initialized: usize = 0;
    errdefer {
        for (items[0..initialized]) |bytes| allocator.free(bytes);
        allocator.free(items);
    }
    var total_size: usize = 0;
    for (streams.folders, 0..) |folder, index| {
        const size = std.math.cast(usize, folder.unpack_size) orelse
            return error.OutputLimitExceeded;
        total_size = std.math.add(usize, total_size, size) catch
            return error.OutputLimitExceeded;
        if (total_size > max_output_size) return error.OutputLimitExceeded;
        items[index] = try decodeFolderAlloc(
            allocator,
            input,
            streams,
            index,
            size,
            max_dictionary_size,
            password,
            max_kdf_cycles_power,
        );
        initialized += 1;
    }
    return items;
}

fn freeExternalStreams(allocator: std.mem.Allocator, items: [][]u8) void {
    for (items) |bytes| allocator.free(bytes);
    allocator.free(items);
}

fn decodeFolderAlloc(
    allocator: std.mem.Allocator,
    input: packed_input.Input,
    streams: *const streams_mod.Streams,
    folder_index: usize,
    expected_size: usize,
    max_dictionary_size: usize,
    password: ?[]const u8,
    max_kdf_cycles_power: u6,
) ![]u8 {
    if (folder_index >= streams.folders.len) return error.Invalid7zArchive;
    const folder = streams.folders[folder_index];
    if (folder.bcj2_coder_index) |bcj2_index| {
        if (folder.pack_stream_count != 4 or
            (folder.coder_count != 2 and folder.coder_count != 6))
            return error.Invalid7zArchive;
        var loaded_streams: [4]packed_input.Loaded = undefined;
        var loaded_count: usize = 0;
        defer for (loaded_streams[0..loaded_count]) |loaded| loaded.deinit(allocator);
        for (&loaded_streams, 0..) |*loaded, index| {
            loaded.* = try input.load(allocator, streams, folder.pack_index + index);
            loaded_count += 1;
            if (streams.pack_crcs[folder.pack_index + index]) |expected|
                if (checksum.crc32Best(loaded.bytes) != expected) return error.ChecksumMismatch;
        }
        var branch_streams: [4][]const u8 = undefined;
        var owned_branches: [4]?[]u8 = @splat(null);
        defer for (owned_branches) |owned|
            if (owned) |bytes| allocator.free(bytes);
        for (folder.bcj2_branches, 0..) |branch, branch_index| {
            const packed_bytes = loaded_streams[branch.pack_stream_offset].bytes;
            branch_streams[branch_index] = if (branch.aes_coder_index) |aes_index| decrypted: {
                const coder = folder.coders[aes_index];
                const properties = aes.parseProperties(coder.propertyBytes()) catch
                    return error.Invalid7zArchive;
                const decoded_size = std.math.cast(
                    usize,
                    folder.coder_unpack_sizes[aes_index],
                ) orelse return error.OutputLimitExceeded;
                const decoded = try aes.decryptAlloc(
                    allocator,
                    packed_bytes,
                    decoded_size,
                    password,
                    properties,
                    max_kdf_cycles_power,
                );
                owned_branches[branch_index] = decoded;
                break :decrypted decoded;
            } else packed_bytes;
        }

        const primary_index = folder.primaryCoderIndex() orelse
            return error.Invalid7zArchive;
        const primary = folder.coders[primary_index];
        const main_size = std.math.cast(
            usize,
            folder.coder_unpack_sizes[primary_index],
        ) orelse return error.OutputLimitExceeded;
        const side_size = std.math.add(
            usize,
            branch_streams[1].len,
            branch_streams[2].len,
        ) catch return error.IntegerOverflow;
        const calculated_size = std.math.add(usize, main_size, side_size) catch
            return error.IntegerOverflow;
        if (main_size > expected_size or side_size > expected_size or
            calculated_size != expected_size)
            return error.Invalid7zArchive;
        const main = try decodePrimaryAlloc(
            allocator,
            branch_streams[0],
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
            branch_streams[1],
            branch_streams[2],
            branch_streams[3],
            expected_size,
            start_ip,
        );
        errdefer allocator.free(decoded);
        if (folder.crc32) |expected|
            if (checksum.crc32Best(decoded) != expected) return error.ChecksumMismatch;
        return decoded;
    }

    const loaded = try input.load(allocator, streams, folder.pack_index);
    defer loaded.deinit(allocator);
    const packed_bytes = loaded.bytes;
    if (streams.pack_crcs[folder.pack_index]) |expected|
        if (checksum.crc32Best(packed_bytes) != expected) return error.ChecksumMismatch;

    var current: []const u8 = packed_bytes;
    var owned: ?[]u8 = null;
    errdefer if (owned) |bytes| allocator.free(bytes);
    for (folder.decode_order[0..folder.coder_count]) |coder_index| {
        const coder = folder.coders[coder_index];
        const coder_size = std.math.cast(usize, folder.coder_unpack_sizes[coder_index]) orelse
            return error.OutputLimitExceeded;
        switch (coder.method) {
            .aes256_sha256 => {
                const properties = aes.parseProperties(coder.propertyBytes()) catch
                    return error.Invalid7zArchive;
                const next = try aes.decryptAlloc(
                    allocator,
                    current,
                    coder_size,
                    password,
                    properties,
                    max_kdf_cycles_power,
                );
                if (owned) |bytes| allocator.free(bytes);
                owned = next;
                current = next;
            },
            .copy, .deflate, .bzip2, .lzma, .lzma2, .ppmd7 => {
                const next = try decodePrimaryAlloc(
                    allocator,
                    current,
                    coder,
                    coder_size,
                    max_dictionary_size,
                );
                if (owned) |bytes| allocator.free(bytes);
                owned = next;
                current = next;
            },
            .delta, .x86, .powerpc, .ia64, .arm, .arm_thumb, .sparc, .arm64, .riscv => {
                if (current.len != coder_size) return error.SizeMismatch;
                const mutable = owned orelse return error.Invalid7zArchive;
                try decodeFilter(mutable, coder);
            },
            else => return error.Unsupported7zFeature,
        }
    }
    const decoded = owned orelse return error.Invalid7zArchive;
    if (decoded.len != expected_size) return error.SizeMismatch;
    if (folder.crc32) |expected|
        if (checksum.crc32Best(decoded) != expected) return error.ChecksumMismatch;
    owned = null;
    return decoded;
}

fn decodeFilter(decoded: []u8, coder: streams_mod.Coder) Error!void {
    const filter_id: u64 = switch (coder.method) {
        .delta => 0x03,
        .x86 => 0x04,
        .powerpc => 0x05,
        .ia64 => 0x06,
        .arm => 0x07,
        .arm_thumb => 0x08,
        .sparc => 0x09,
        .arm64 => 0x0a,
        .riscv => 0x0b,
        else => return error.Unsupported7zFeature,
    };
    const filter = xz_filters.parse(filter_id, coder.propertyBytes()) catch |err| switch (err) {
        error.InvalidXzHeader => return error.Invalid7zArchive,
        error.UnsupportedXzFeature => return error.Unsupported7zFeature,
    };
    xz_filters.decodeChain(decoded, &.{filter});
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
        .ppmd7 => try ppmd7.decodeAllocLimited(
            allocator,
            packed_bytes,
            primary.propertyBytes(),
            expected_size,
            max_dictionary_size,
        ),
        else => return error.Unsupported7zFeature,
    };
}

fn skipArchiveProperties(reader: *number.Reader) !void {
    while (true) {
        const property = try reader.readByte();
        if (property == Nid.end) return;
        _ = try reader.take(try reader.readSize());
    }
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
