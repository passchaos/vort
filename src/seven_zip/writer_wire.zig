const std = @import("std");
const checksum = @import("../checksum.zig");
const coders = @import("coders.zig");
const file_properties = @import("file_properties.zig");
const number = @import("number.zig");
const types = @import("types.zig");

pub const signature = [_]u8{ '7', 'z', 0xbc, 0xaf, 0x27, 0x1c };
pub const start_header_len: usize = 32;

pub const Nid = struct {
    pub const end: u8 = 0x00;
    pub const header: u8 = 0x01;
    pub const additional_streams: u8 = 0x03;
    pub const main_streams: u8 = 0x04;
    pub const files: u8 = 0x05;
    pub const pack_info: u8 = 0x06;
    pub const unpack_info: u8 = 0x07;
    pub const substreams_info: u8 = 0x08;
    pub const size: u8 = 0x09;
    pub const crc: u8 = 0x0a;
    pub const folder: u8 = 0x0b;
    pub const coders_unpack_size: u8 = 0x0c;
    pub const num_unpack_stream: u8 = 0x0d;
    pub const empty_stream: u8 = 0x0e;
    pub const empty_file: u8 = 0x0f;
    pub const name: u8 = 0x11;
    pub const encoded_header: u8 = 0x17;
};

pub const EncodedFolder = struct {
    packed_sizes: [4]u64 = @splat(0),
    pack_stream_count: u3 = 1,
    unpacked_size: u64,
    aes_unpack_sizes: [4]?u64 = @splat(null),
    crc32: u32,
    first_substream: usize,
    substream_count: usize,
};

pub const EncodedSubstream = struct {
    unpacked_size: u64,
    crc32: u32,
};

pub const max_external_streams: usize = 1 + file_properties.kind_count;

pub const EncodedExternalStreams = struct {
    pack_position: u64 = 0,
    folders: [max_external_streams]EncodedFolder = undefined,
    substreams: [max_external_streams]EncodedSubstream = undefined,
    options: [max_external_streams]coders.Options = undefined,
    count: usize = 0,
    name_index: ?usize = null,
    metadata_indices: file_properties.Indices = @splat(null),
};

pub fn makeStartHeaderPatch(
    next_header_offset: u64,
    next_header_size: u64,
    next_header_crc32: u32,
) [start_header_len]u8 {
    var patch: [start_header_len]u8 = @splat(0);
    @memcpy(patch[0..signature.len], &signature);
    patch[6] = 0;
    patch[7] = 4;
    std.mem.writeInt(u64, patch[12..20], next_header_offset, .little);
    std.mem.writeInt(u64, patch[20..28], next_header_size, .little);
    std.mem.writeInt(u32, patch[28..32], next_header_crc32, .little);
    std.mem.writeInt(u32, patch[8..12], checksum.crc32Best(patch[12..32]), .little);
    return patch;
}

pub fn validateEntries(entries: []const types.EncodeEntry) !void {
    for (entries) |entry| {
        if (entry.name.len == 0 or std.mem.indexOfScalar(u8, entry.name, 0) != null)
            return error.Invalid7zEntry;
        if (!std.unicode.utf8ValidateSlice(entry.name)) return error.Invalid7zEntry;
        if (entry.kind == .directory and entry.data.len != 0) return error.Invalid7zEntry;
    }
}

pub fn hasStream(entry: types.EncodeEntry) bool {
    return entry.kind == .file and entry.data.len != 0;
}

pub fn appendNames(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entries: []const types.EncodeEntry,
) !void {
    for (entries) |entry| {
        const utf16 = std.unicode.utf8ToUtf16LeAlloc(allocator, entry.name) catch |err| switch (err) {
            error.InvalidUtf8 => return error.Invalid7zEntry,
            error.OutOfMemory => return error.OutOfMemory,
        };
        defer allocator.free(utf16);
        for (utf16) |unit| try appendU16(allocator, output, unit);
        try appendU16(allocator, output, 0);
    }
}

pub fn writeNextHeader(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entries: []const types.EncodeEntry,
    folders: []const EncodedFolder,
    folder_options: []const coders.Options,
    substreams: []const EncodedSubstream,
    options: coders.Options,
    names: []const u8,
    external_streams: *const EncodedExternalStreams,
) !void {
    try output.append(allocator, Nid.header);
    if (external_streams.count != 0) {
        try output.append(allocator, Nid.additional_streams);
        try writeStreamsBodyConfigured(
            allocator,
            output,
            external_streams.folders[0..external_streams.count],
            external_streams.substreams[0..external_streams.count],
            external_streams.options[0],
            external_streams.options[0..external_streams.count],
            external_streams.pack_position,
        );
    }
    if (folders.len != 0)
        try writeStreamsInfo(allocator, output, folders, folder_options, substreams, options);
    try writeFilesInfo(allocator, output, entries, names, external_streams);
    try output.append(allocator, Nid.end);
}

fn writeStreamsInfo(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    folders: []const EncodedFolder,
    folder_options: []const coders.Options,
    substreams: []const EncodedSubstream,
    options: coders.Options,
) !void {
    try output.append(allocator, Nid.main_streams);
    try writeStreamsBodyConfigured(
        allocator,
        output,
        folders,
        substreams,
        options,
        folder_options,
        0,
    );
}

pub fn writeStreamsBody(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    folders: []const EncodedFolder,
    substreams: []const EncodedSubstream,
    options: coders.Options,
    pack_position: u64,
) !void {
    return writeStreamsBodyConfigured(
        allocator,
        output,
        folders,
        substreams,
        options,
        null,
        pack_position,
    );
}

fn writeStreamsBodyConfigured(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    folders: []const EncodedFolder,
    substreams: []const EncodedSubstream,
    default_options: coders.Options,
    configured_options: ?[]const coders.Options,
    pack_position: u64,
) !void {
    if (configured_options) |folder_options|
        std.debug.assert(folder_options.len == folders.len);
    try output.append(allocator, Nid.pack_info);
    try number.append(allocator, output, pack_position);
    var pack_stream_count: usize = 0;
    for (folders) |folder|
        pack_stream_count = std.math.add(usize, pack_stream_count, folder.pack_stream_count) catch
            return error.IntegerOverflow;
    try number.append(allocator, output, pack_stream_count);
    try output.append(allocator, Nid.size);
    for (folders) |folder|
        for (folder.packed_sizes[0..folder.pack_stream_count]) |packed_size|
            try number.append(allocator, output, packed_size);
    try output.append(allocator, Nid.end);

    try output.append(allocator, Nid.unpack_info);
    try output.append(allocator, Nid.folder);
    try number.append(allocator, output, folders.len);
    try output.append(allocator, 0);
    for (folders, 0..) |_, index| {
        const options = if (configured_options) |folder_options|
            folder_options[index]
        else
            default_options;
        try coders.writeFolder(allocator, output, options);
    }
    try output.append(allocator, Nid.coders_unpack_size);
    for (folders, 0..) |folder, index| {
        const options = if (configured_options) |folder_options|
            folder_options[index]
        else
            default_options;
        for (0..coders.coderCount(options)) |coder_index| {
            const unpack_size = if (options.bcj2 and options.encryption != null and
                coder_index < 4)
                folder.aes_unpack_sizes[3 - coder_index] orelse
                    return error.Invalid7zOptions
            else if (!options.bcj2 and coder_index == 0 and options.encryption != null)
                folder.aes_unpack_sizes[0] orelse return error.Invalid7zOptions
            else
                folder.unpacked_size;
            try number.append(allocator, output, unpack_size);
        }
    }
    try output.append(allocator, Nid.crc);
    try output.append(allocator, 1);
    for (folders) |folder| try appendU32(allocator, output, folder.crc32);
    try output.append(allocator, Nid.end);

    try output.append(allocator, Nid.substreams_info);
    var has_multiple = false;
    for (folders) |folder| has_multiple = has_multiple or folder.substream_count != 1;
    if (has_multiple) {
        try output.append(allocator, Nid.num_unpack_stream);
        for (folders) |folder| try number.append(allocator, output, folder.substream_count);
        try output.append(allocator, Nid.size);
        for (folders) |folder| {
            const folder_substreams = substreams[folder.first_substream..][0..folder.substream_count];
            for (folder_substreams[0 .. folder_substreams.len - 1]) |substream|
                try number.append(allocator, output, substream.unpacked_size);
        }
        try output.append(allocator, Nid.crc);
        try output.append(allocator, 1);
        for (folders) |folder| {
            const folder_substreams = substreams[folder.first_substream..][0..folder.substream_count];
            for (folder_substreams) |substream|
                try appendU32(allocator, output, substream.crc32);
        }
    }
    try output.append(allocator, Nid.end);
    try output.append(allocator, Nid.end);
}

fn writeFilesInfo(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entries: []const types.EncodeEntry,
    names: []const u8,
    external_streams: *const EncodedExternalStreams,
) !void {
    try output.append(allocator, Nid.files);
    try number.append(allocator, output, entries.len);

    var empty_count: usize = 0;
    for (entries) |entry| empty_count += @intFromBool(!hasStream(entry));
    if (empty_count != 0) {
        try output.append(allocator, Nid.empty_stream);
        try number.append(allocator, output, (entries.len + 7) / 8);
        try appendBitVector(allocator, output, entries.len, entries, struct {
            fn get(entry: types.EncodeEntry) bool {
                return !hasStream(entry);
            }
        }.get);

        try output.append(allocator, Nid.empty_file);
        try number.append(allocator, output, (empty_count + 7) / 8);
        var bits: std.ArrayList(bool) = .empty;
        defer bits.deinit(allocator);
        try bits.ensureTotalCapacity(allocator, empty_count);
        for (entries) |entry| if (!hasStream(entry))
            bits.appendAssumeCapacity(entry.kind == .file);
        try appendBools(allocator, output, bits.items);
    }

    try output.append(allocator, Nid.name);
    if (external_streams.name_index) |index| {
        var property: std.ArrayList(u8) = .empty;
        defer property.deinit(allocator);
        try property.append(allocator, 1);
        try number.append(allocator, &property, index);
        try number.append(allocator, output, property.items.len);
        try output.appendSlice(allocator, property.items);
    } else {
        const property_size = std.math.add(usize, names.len, 1) catch
            return error.IntegerOverflow;
        try number.append(allocator, output, property_size);
        try output.append(allocator, 0);
        try output.appendSlice(allocator, names);
    }
    try file_properties.write(
        allocator,
        output,
        entries,
        external_streams.metadata_indices,
    );
    try output.append(allocator, Nid.end);
}

fn appendBitVector(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    count: usize,
    entries: []const types.EncodeEntry,
    comptime predicate: fn (types.EncodeEntry) bool,
) !void {
    var byte: u8 = 0;
    for (0..count) |index| {
        if (predicate(entries[index])) byte |= @as(u8, 0x80) >> @intCast(index & 7);
        if (index & 7 == 7) {
            try output.append(allocator, byte);
            byte = 0;
        }
    }
    if (count & 7 != 0) try output.append(allocator, byte);
}

fn appendBools(allocator: std.mem.Allocator, output: *std.ArrayList(u8), values: []const bool) !void {
    var byte: u8 = 0;
    for (values, 0..) |value, index| {
        if (value) byte |= @as(u8, 0x80) >> @intCast(index & 7);
        if (index & 7 == 7) {
            try output.append(allocator, byte);
            byte = 0;
        }
    }
    if (values.len & 7 != 0) try output.append(allocator, byte);
}

fn appendU16(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: u16) !void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, value, .little);
    try output.appendSlice(allocator, &bytes);
}

pub fn appendU32(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: u32) !void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .little);
    try output.appendSlice(allocator, &bytes);
}

test "7z start-header patch covers offset size and CRC" {
    const patch = makeStartHeaderPatch(123, 456, 0xaabb_ccdd);
    try std.testing.expectEqualSlices(u8, &signature, patch[0..6]);
    try std.testing.expectEqualSlices(u8, &.{ 0, 4 }, patch[6..8]);
    try std.testing.expectEqual(@as(u64, 123), std.mem.readInt(u64, patch[12..20], .little));
    try std.testing.expectEqual(@as(u64, 456), std.mem.readInt(u64, patch[20..28], .little));
    try std.testing.expectEqual(@as(u32, 0xaabb_ccdd), std.mem.readInt(u32, patch[28..32], .little));
    try std.testing.expectEqual(
        checksum.crc32Best(patch[12..32]),
        std.mem.readInt(u32, patch[8..12], .little),
    );
}
