const std = @import("std");
const checksum = @import("../checksum.zig");
const core = @import("../core.zig");
const coders = @import("coders.zig");
const bcj2 = @import("bcj2.zig");
const file_properties = @import("file_properties.zig");
const number = @import("number.zig");
const types = @import("types.zig");

pub const Error = core.Error || number.Error || coders.Error || error{
    Invalid7zEntry,
};

pub const EncodeEntry = types.EncodeEntry;
pub const Compression = coders.Compression;
pub const Filter = coders.Filter;
pub const EncodeOptions = coders.Options;

const signature = [_]u8{ '7', 'z', 0xbc, 0xaf, 0x27, 0x1c };

const Nid = struct {
    const end: u8 = 0x00;
    const header: u8 = 0x01;
    const additional_streams: u8 = 0x03;
    const main_streams: u8 = 0x04;
    const files: u8 = 0x05;
    const pack_info: u8 = 0x06;
    const unpack_info: u8 = 0x07;
    const substreams_info: u8 = 0x08;
    const size: u8 = 0x09;
    const crc: u8 = 0x0a;
    const folder: u8 = 0x0b;
    const coders_unpack_size: u8 = 0x0c;
    const num_unpack_stream: u8 = 0x0d;
    const empty_stream: u8 = 0x0e;
    const empty_file: u8 = 0x0f;
    const name: u8 = 0x11;
    const encoded_header: u8 = 0x17;
};

const EncodedFolder = struct {
    packed_sizes: [4]u64 = @splat(0),
    pack_stream_count: u3 = 1,
    unpacked_size: u64,
    crc32: u32,
    first_substream: usize,
    substream_count: usize,
};

const EncodedSubstream = struct {
    unpacked_size: u64,
    crc32: u32,
};

const max_external_streams: usize = 1 + file_properties.kind_count;

const EncodedExternalStreams = struct {
    pack_position: usize = 0,
    folders: [max_external_streams]EncodedFolder = undefined,
    substreams: [max_external_streams]EncodedSubstream = undefined,
    options: [max_external_streams]EncodeOptions = undefined,
    count: usize = 0,
    name_index: ?usize = null,
    metadata_indices: file_properties.Indices = @splat(null),
};

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    entries: []const EncodeEntry,
    options: EncodeOptions,
) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, entries, options);
    return output.toOwnedSlice(allocator);
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    entries: []const EncodeEntry,
    output: []u8,
    options: EncodeOptions,
) !usize {
    const encoded = try encodeAlloc(allocator, entries, options);
    defer allocator.free(encoded);
    if (output.len < encoded.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    entries: []const EncodeEntry,
    options: EncodeOptions,
) !usize {
    try coders.validate(options);
    var packed_data: std.ArrayList(u8) = .empty;
    defer packed_data.deinit(allocator);
    var header: std.ArrayList(u8) = .empty;
    defer header.deinit(allocator);
    try validateEntries(entries);

    var stream_count: usize = 0;
    for (entries) |entry| stream_count += @intFromBool(hasStream(entry));
    const folder_count = if (options.solid and stream_count != 0) 1 else stream_count;
    const folders = try allocator.alloc(EncodedFolder, folder_count);
    defer allocator.free(folders);
    const substreams = try allocator.alloc(EncodedSubstream, stream_count);
    defer allocator.free(substreams);
    if (options.solid and stream_count != 0) {
        var solid_data: std.ArrayList(u8) = .empty;
        defer solid_data.deinit(allocator);
        var stream_index: usize = 0;
        for (entries) |entry| {
            if (!hasStream(entry)) continue;
            try solid_data.appendSlice(allocator, entry.data);
            substreams[stream_index] = .{
                .unpacked_size = std.math.cast(u64, entry.data.len) orelse
                    return error.IntegerOverflow,
                .crc32 = checksum.crc32Best(entry.data),
            };
            stream_index += 1;
        }
        folders[0] = try appendFolderPayload(
            allocator,
            &packed_data,
            solid_data.items,
            options,
            0,
            stream_count,
        );
    } else {
        var stream_index: usize = 0;
        for (entries) |entry| {
            if (!hasStream(entry)) continue;
            const unpacked_size = std.math.cast(u64, entry.data.len) orelse
                return error.IntegerOverflow;
            const crc32 = checksum.crc32Best(entry.data);
            folders[stream_index] = try appendFolderPayload(
                allocator,
                &packed_data,
                entry.data,
                options,
                stream_index,
                1,
            );
            substreams[stream_index] = .{
                .unpacked_size = unpacked_size,
                .crc32 = crc32,
            };
            stream_index += 1;
        }
    }
    var names: std.ArrayList(u8) = .empty;
    defer names.deinit(allocator);
    try appendNames(allocator, &names, entries);
    var external_streams = EncodedExternalStreams{};
    if (options.external_names) |compression| {
        external_streams.name_index = try appendExternalPayload(
            allocator,
            &packed_data,
            &external_streams,
            names.items,
            options,
            compression,
        );
    }
    if (options.external_metadata) |compression| {
        var metadata_values: std.ArrayList(u8) = .empty;
        defer metadata_values.deinit(allocator);

        inline for (std.meta.tags(file_properties.Kind)) |kind| {
            metadata_values.clearRetainingCapacity();
            try file_properties.appendValues(allocator, &metadata_values, entries, kind);
            if (metadata_values.items.len != 0)
                external_streams.metadata_indices[@intFromEnum(kind)] = try appendExternalPayload(
                    allocator,
                    &packed_data,
                    &external_streams,
                    metadata_values.items,
                    options,
                    compression,
                );
        }
    }
    try writeNextHeader(
        allocator,
        &header,
        entries,
        folders,
        substreams,
        options,
        names.items,
        &external_streams,
    );

    var next_header: std.ArrayList(u8) = .empty;
    defer next_header.deinit(allocator);
    if (options.header_compression) |header_compression| {
        const pack_position = packed_data.items.len;
        var header_options = options;
        header_options.compression = header_compression;
        header_options.solid = false;
        header_options.header_compression = null;
        header_options.external_names = null;
        header_options.external_metadata = null;
        header_options.bcj2 = false;
        header_options.bcj2_start_ip = 0;
        header_options.filters = &.{};
        const packed_size = try coders.appendPayload(
            allocator,
            &packed_data,
            header.items,
            header_options,
        );
        const header_folders = [_]EncodedFolder{.{
            .packed_sizes = .{
                std.math.cast(u64, packed_size) orelse return error.IntegerOverflow,
                0,
                0,
                0,
            },
            .unpacked_size = std.math.cast(u64, header.items.len) orelse
                return error.IntegerOverflow,
            .crc32 = checksum.crc32Best(header.items),
            .first_substream = 0,
            .substream_count = 1,
        }};
        const header_substreams = [_]EncodedSubstream{.{
            .unpacked_size = header_folders[0].unpacked_size,
            .crc32 = header_folders[0].crc32,
        }};
        try next_header.append(allocator, Nid.encoded_header);
        try writeStreamsBody(
            allocator,
            &next_header,
            &header_folders,
            &header_substreams,
            header_options,
            pack_position,
        );
    } else {
        try next_header.appendSlice(allocator, header.items);
    }

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try encoded.appendSlice(allocator, &signature);
    try encoded.appendSlice(allocator, &.{ 0, 4 });
    var start_header: [20]u8 = undefined;
    std.mem.writeInt(u64, start_header[0..8], packed_data.items.len, .little);
    std.mem.writeInt(u64, start_header[8..16], next_header.items.len, .little);
    std.mem.writeInt(u32, start_header[16..20], checksum.crc32Best(next_header.items), .little);
    try appendU32(allocator, &encoded, checksum.crc32Best(&start_header));
    try encoded.appendSlice(allocator, &start_header);
    try encoded.appendSlice(allocator, packed_data.items);
    try encoded.appendSlice(allocator, next_header.items);

    try out.ensureUnusedCapacity(allocator, encoded.items.len);
    out.appendSliceAssumeCapacity(encoded.items);
    return encoded.items.len;
}

pub fn encodeStoredAlloc(
    allocator: std.mem.Allocator,
    entries: []const EncodeEntry,
    options: EncodeOptions,
) ![]u8 {
    try validateStoredOptions(options);
    return encodeAlloc(allocator, entries, options);
}

pub fn encodeStoredInto(
    allocator: std.mem.Allocator,
    entries: []const EncodeEntry,
    output: []u8,
    options: EncodeOptions,
) !usize {
    try validateStoredOptions(options);
    return encodeInto(allocator, entries, output, options);
}

pub fn encodeStoredAppend(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    entries: []const EncodeEntry,
    options: EncodeOptions,
) !usize {
    try validateStoredOptions(options);
    return encodeAppend(allocator, out, entries, options);
}

fn validateStoredOptions(options: EncodeOptions) Error!void {
    if (options.compression != .copy or options.filters.len != 0)
        return error.Invalid7zOptions;
}

fn validateEntries(entries: []const EncodeEntry) Error!void {
    for (entries) |entry| {
        if (entry.name.len == 0 or std.mem.indexOfScalar(u8, entry.name, 0) != null)
            return error.Invalid7zEntry;
        if (!std.unicode.utf8ValidateSlice(entry.name)) return error.Invalid7zEntry;
        if (entry.kind == .directory and entry.data.len != 0) return error.Invalid7zEntry;
    }
}

fn hasStream(entry: EncodeEntry) bool {
    return entry.kind == .file and entry.data.len != 0;
}

fn appendFolderPayload(
    allocator: std.mem.Allocator,
    packed_data: *std.ArrayList(u8),
    input: []const u8,
    options: EncodeOptions,
    first_substream: usize,
    substream_count: usize,
) !EncodedFolder {
    var folder = EncodedFolder{
        .unpacked_size = std.math.cast(u64, input.len) orelse
            return error.IntegerOverflow,
        .crc32 = checksum.crc32Best(input),
        .first_substream = first_substream,
        .substream_count = substream_count,
    };
    if (!options.bcj2) {
        const packed_size = try coders.appendPayload(allocator, packed_data, input, options);
        folder.packed_sizes[0] = std.math.cast(u64, packed_size) orelse
            return error.IntegerOverflow;
        return folder;
    }

    const range_stream = try bcj2.encodeNoConversionAlloc(allocator, input);
    defer allocator.free(range_stream);
    var primary_options = options;
    primary_options.bcj2 = false;
    primary_options.bcj2_start_ip = 0;
    primary_options.filters = &.{};
    const main_size = try coders.appendPayload(
        allocator,
        packed_data,
        input,
        primary_options,
    );
    try packed_data.appendSlice(allocator, range_stream);
    folder.pack_stream_count = 4;
    folder.packed_sizes = .{
        std.math.cast(u64, main_size) orelse return error.IntegerOverflow,
        0,
        0,
        std.math.cast(u64, range_stream.len) orelse return error.IntegerOverflow,
    };
    return folder;
}

fn appendExternalPayload(
    allocator: std.mem.Allocator,
    packed_data: *std.ArrayList(u8),
    external: *EncodedExternalStreams,
    input: []const u8,
    base_options: EncodeOptions,
    compression: Compression,
) !usize {
    std.debug.assert(external.count < max_external_streams);
    if (external.count == 0) external.pack_position = packed_data.items.len;
    var options = base_options;
    options.compression = compression;
    options.solid = false;
    options.header_compression = null;
    options.external_names = null;
    options.external_metadata = null;
    options.bcj2 = false;
    options.bcj2_start_ip = 0;
    options.filters = &.{};
    const packed_size = try coders.appendPayload(allocator, packed_data, input, options);
    const unpacked_size = std.math.cast(u64, input.len) orelse
        return error.IntegerOverflow;
    const crc32 = checksum.crc32Best(input);
    const index = external.count;
    external.folders[index] = .{
        .packed_sizes = .{
            std.math.cast(u64, packed_size) orelse return error.IntegerOverflow,
            0,
            0,
            0,
        },
        .unpacked_size = unpacked_size,
        .crc32 = crc32,
        .first_substream = index,
        .substream_count = 1,
    };
    external.substreams[index] = .{
        .unpacked_size = unpacked_size,
        .crc32 = crc32,
    };
    external.options[index] = options;
    external.count += 1;
    return index;
}

fn writeNextHeader(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entries: []const EncodeEntry,
    folders: []const EncodedFolder,
    substreams: []const EncodedSubstream,
    options: EncodeOptions,
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
        try writeStreamsInfo(allocator, output, folders, substreams, options);
    try writeFilesInfo(allocator, output, entries, names, external_streams);
    try output.append(allocator, Nid.end);
}

fn writeStreamsInfo(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    folders: []const EncodedFolder,
    substreams: []const EncodedSubstream,
    options: EncodeOptions,
) !void {
    try output.append(allocator, Nid.main_streams);
    try writeStreamsBody(allocator, output, folders, substreams, options, 0);
}

fn writeStreamsBody(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    folders: []const EncodedFolder,
    substreams: []const EncodedSubstream,
    options: EncodeOptions,
    pack_position: usize,
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
    default_options: EncodeOptions,
    configured_options: ?[]const EncodeOptions,
    pack_position: usize,
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
        for (0..coders.coderCount(options)) |_| try number.append(allocator, output, folder.unpacked_size);
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
    entries: []const EncodeEntry,
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
            fn get(entry: EncodeEntry) bool {
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

fn appendNames(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entries: []const EncodeEntry,
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

fn appendBitVector(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    count: usize,
    entries: []const EncodeEntry,
    comptime predicate: fn (EncodeEntry) bool,
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

fn appendU32(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: u32) !void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .little);
    try output.appendSlice(allocator, &bytes);
}

test "7z stored writer emits deterministic signature and metadata" {
    const entries = [_]EncodeEntry{
        .{ .name = "hello.txt", .data = "hello seven zip\n" },
        .{ .name = "empty.txt" },
        .{ .name = "folder", .kind = .directory },
        .{ .name = "utf8-数据.txt", .data = "payload" },
    };
    const first = try encodeStoredAlloc(std.testing.allocator, &entries, .{});
    defer std.testing.allocator.free(first);
    const second = try encodeStoredAlloc(std.testing.allocator, &entries, .{});
    defer std.testing.allocator.free(second);
    try std.testing.expectEqualSlices(u8, first, second);
    try std.testing.expectEqualSlices(u8, &signature, first[0..signature.len]);

    const out = try std.testing.allocator.alloc(u8, first.len);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqual(first.len, try encodeStoredInto(std.testing.allocator, &entries, out, .{}));
    try std.testing.expectEqualSlices(u8, first, out);
    try std.testing.expectError(
        error.OutputTooSmall,
        encodeStoredInto(std.testing.allocator, &entries, out[0 .. out.len - 1], .{}),
    );

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    const prefix_len = appended.items.len;
    try std.testing.expectEqual(first.len, try encodeStoredAppend(std.testing.allocator, &appended, &entries, .{}));
    try std.testing.expectEqualSlices(u8, "prefix:", appended.items[0..prefix_len]);
    try std.testing.expectEqualSlices(u8, first, appended.items[prefix_len..]);

    const before = try std.testing.allocator.dupe(u8, appended.items);
    defer std.testing.allocator.free(before);
    const invalid = [_]EncodeEntry{.{ .name = "", .data = "bad" }};
    try std.testing.expectError(
        error.Invalid7zEntry,
        encodeStoredAppend(std.testing.allocator, &appended, &invalid, .{}),
    );
    try std.testing.expectEqualSlices(u8, before, appended.items);
    try std.testing.expectError(
        error.Invalid7zOptions,
        encodeStoredAppend(std.testing.allocator, &appended, &entries, .{ .compression = .deflate }),
    );
    try std.testing.expectEqualSlices(u8, before, appended.items);
}

test "7z compressed writer supports caller-owned and transactional append APIs" {
    const entries = [_]EncodeEntry{.{
        .name = "payload.txt",
        .data = "compressible 7z payload\n" ** 64,
    }};
    const options = EncodeOptions{ .compression = .deflate };
    const encoded = try encodeAlloc(std.testing.allocator, &entries, options);
    defer std.testing.allocator.free(encoded);

    const output = try std.testing.allocator.alloc(u8, encoded.len);
    defer std.testing.allocator.free(output);
    try std.testing.expectEqual(encoded.len, try encodeInto(std.testing.allocator, &entries, output, options));
    try std.testing.expectEqualSlices(u8, encoded, output);
    try std.testing.expectError(
        error.OutputTooSmall,
        encodeInto(std.testing.allocator, &entries, output[0 .. output.len - 1], options),
    );

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    const prefix_len = appended.items.len;
    try std.testing.expectEqual(
        encoded.len,
        try encodeAppend(std.testing.allocator, &appended, &entries, options),
    );
    try std.testing.expectEqualSlices(u8, "prefix:", appended.items[0..prefix_len]);
    try std.testing.expectEqualSlices(u8, encoded, appended.items[prefix_len..]);

    const before = try std.testing.allocator.dupe(u8, appended.items);
    defer std.testing.allocator.free(before);
    try std.testing.expectError(
        error.Invalid7zOptions,
        encodeAppend(std.testing.allocator, &appended, &entries, .{
            .compression = .deflate,
            .deflate_level = 10,
        }),
    );
    try std.testing.expectEqualSlices(u8, before, appended.items);
}
