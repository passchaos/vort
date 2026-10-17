const std = @import("std");
const checksum = @import("../checksum.zig");
const core = @import("../core.zig");
const aes = @import("aes.zig");
const coders = @import("coders.zig");
const bcj2 = @import("bcj2.zig");
const file_properties = @import("file_properties.zig");
const number = @import("number.zig");
const types = @import("types.zig");
const wire = @import("writer_wire.zig");

pub const Error = core.Error || number.Error || coders.Error || error{
    Invalid7zEntry,
};

pub const EncodeEntry = types.EncodeEntry;
pub const Compression = coders.Compression;
pub const Filter = coders.Filter;
pub const EncryptionOptions = coders.EncryptionOptions;
pub const EncodeOptions = coders.Options;

const EncodedFolder = wire.EncodedFolder;
const EncodedSubstream = wire.EncodedSubstream;
const EncodedExternalStreams = wire.EncodedExternalStreams;
const max_external_streams = wire.max_external_streams;

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
    try wire.validateEntries(entries);

    var stream_count: usize = 0;
    for (entries) |entry| stream_count += @intFromBool(wire.hasStream(entry));
    const folder_count = if (options.solid and stream_count != 0) 1 else stream_count;
    const folders = try allocator.alloc(EncodedFolder, folder_count);
    defer allocator.free(folders);
    const folder_options = try allocator.alloc(EncodeOptions, folder_count);
    defer allocator.free(folder_options);
    const substreams = try allocator.alloc(EncodedSubstream, stream_count);
    defer allocator.free(substreams);
    var next_encryption_stream_index = options.encryption_stream_index;
    if (options.solid and stream_count != 0) {
        var solid_data: std.ArrayList(u8) = .empty;
        defer solid_data.deinit(allocator);
        var stream_index: usize = 0;
        for (entries) |entry| {
            if (!wire.hasStream(entry)) continue;
            try solid_data.appendSlice(allocator, entry.data);
            substreams[stream_index] = .{
                .unpacked_size = std.math.cast(u64, entry.data.len) orelse
                    return error.IntegerOverflow,
                .crc32 = checksum.crc32Best(entry.data),
            };
            stream_index += 1;
        }
        folder_options[0] = try optionsForNextEncryptedStream(
            options,
            &next_encryption_stream_index,
        );
        folders[0] = try appendFolderPayload(
            allocator,
            &packed_data,
            solid_data.items,
            folder_options[0],
            0,
            stream_count,
        );
    } else {
        var stream_index: usize = 0;
        for (entries) |entry| {
            if (!wire.hasStream(entry)) continue;
            const unpacked_size = std.math.cast(u64, entry.data.len) orelse
                return error.IntegerOverflow;
            const crc32 = checksum.crc32Best(entry.data);
            folder_options[stream_index] = try optionsForNextEncryptedStream(
                options,
                &next_encryption_stream_index,
            );
            folders[stream_index] = try appendFolderPayload(
                allocator,
                &packed_data,
                entry.data,
                folder_options[stream_index],
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
    try wire.appendNames(allocator, &names, entries);
    var external_streams = EncodedExternalStreams{};
    if (options.external_names) |compression| {
        external_streams.name_index = try appendExternalPayload(
            allocator,
            &packed_data,
            &external_streams,
            names.items,
            options,
            compression,
            &next_encryption_stream_index,
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
                    &next_encryption_stream_index,
                );
        }
    }
    try wire.writeNextHeader(
        allocator,
        &header,
        entries,
        folders,
        folder_options,
        substreams,
        options,
        names.items,
        &external_streams,
    );

    var next_header: std.ArrayList(u8) = .empty;
    defer next_header.deinit(allocator);
    if (options.header_compression != null or options.encrypt_header) {
        const pack_position = packed_data.items.len;
        var header_options = options;
        header_options.compression = options.header_compression orelse .copy;
        header_options.solid = false;
        header_options.header_compression = null;
        header_options.external_names = null;
        header_options.external_metadata = null;
        header_options.encrypt_header = false;
        if (!options.encrypt_header) header_options.encryption = null;
        header_options.bcj2 = false;
        header_options.bcj2_start_ip = 0;
        header_options.filters = &.{};
        header_options = try optionsForNextEncryptedStream(
            header_options,
            &next_encryption_stream_index,
        );
        const payload = try coders.appendPayloadDetailed(
            allocator,
            &packed_data,
            header.items,
            header_options,
        );
        const header_folders = [_]EncodedFolder{.{
            .packed_sizes = .{
                std.math.cast(u64, payload.packed_size) orelse return error.IntegerOverflow,
                0,
                0,
                0,
            },
            .unpacked_size = std.math.cast(u64, header.items.len) orelse
                return error.IntegerOverflow,
            .aes_unpack_sizes = .{
                if (payload.aes_unpack_size) |size|
                    std.math.cast(u64, size) orelse return error.IntegerOverflow
                else
                    null,
                null,
                null,
                null,
            },
            .crc32 = checksum.crc32Best(header.items),
            .first_substream = 0,
            .substream_count = 1,
        }};
        const header_substreams = [_]EncodedSubstream{.{
            .unpacked_size = header_folders[0].unpacked_size,
            .crc32 = header_folders[0].crc32,
        }};
        try next_header.append(allocator, wire.Nid.encoded_header);
        try wire.writeStreamsBody(
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
    const start_header = wire.makeStartHeaderPatch(
        std.math.cast(u64, packed_data.items.len) orelse return error.IntegerOverflow,
        std.math.cast(u64, next_header.items.len) orelse return error.IntegerOverflow,
        checksum.crc32Best(next_header.items),
    );
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

fn optionsForNextEncryptedStream(
    base: EncodeOptions,
    next_stream_index: *u64,
) !EncodeOptions {
    if (base.encryption == null) return base;
    var options = base;
    options.encryption_stream_index = next_stream_index.*;
    const stream_count: u64 = if (base.bcj2) 4 else 1;
    next_stream_index.* = std.math.add(u64, next_stream_index.*, stream_count) catch
        return error.IntegerOverflow;
    return options;
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
        const payload = try coders.appendPayloadDetailed(allocator, packed_data, input, options);
        folder.packed_sizes[0] = std.math.cast(u64, payload.packed_size) orelse
            return error.IntegerOverflow;
        folder.aes_unpack_sizes[0] = if (payload.aes_unpack_size) |size|
            std.math.cast(u64, size) orelse return error.IntegerOverflow
        else
            null;
        return folder;
    }

    const range_stream = try bcj2.encodeNoConversionAlloc(allocator, input);
    defer allocator.free(range_stream);
    var primary_options = options;
    primary_options.bcj2 = false;
    primary_options.bcj2_start_ip = 0;
    primary_options.filters = &.{};
    primary_options.encryption = null;
    primary_options.encrypt_header = false;
    var main_stream: std.ArrayList(u8) = .empty;
    defer main_stream.deinit(allocator);
    _ = try coders.appendPayload(
        allocator,
        &main_stream,
        input,
        primary_options,
    );
    folder.pack_stream_count = 4;
    const branch_streams = [_][]const u8{ main_stream.items, &.{}, &.{}, range_stream };
    for (branch_streams, 0..) |branch_stream, branch_index| {
        const packed_size = if (options.encryption) |encryption| encrypted: {
            const stream_index = std.math.add(
                u64,
                options.encryption_stream_index,
                @intCast(branch_index),
            ) catch return error.IntegerOverflow;
            folder.aes_unpack_sizes[branch_index] = std.math.cast(u64, branch_stream.len) orelse
                return error.IntegerOverflow;
            break :encrypted try aes.encryptAppend(
                allocator,
                packed_data,
                branch_stream,
                encryption,
                stream_index,
            );
        } else plain: {
            try packed_data.appendSlice(allocator, branch_stream);
            break :plain branch_stream.len;
        };
        folder.packed_sizes[branch_index] = std.math.cast(u64, packed_size) orelse
            return error.IntegerOverflow;
    }
    return folder;
}

fn appendExternalPayload(
    allocator: std.mem.Allocator,
    packed_data: *std.ArrayList(u8),
    external: *EncodedExternalStreams,
    input: []const u8,
    base_options: EncodeOptions,
    compression: Compression,
    next_encryption_stream_index: *u64,
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
    options = try optionsForNextEncryptedStream(options, next_encryption_stream_index);
    const payload = try coders.appendPayloadDetailed(allocator, packed_data, input, options);
    const unpacked_size = std.math.cast(u64, input.len) orelse
        return error.IntegerOverflow;
    const crc32 = checksum.crc32Best(input);
    const index = external.count;
    external.folders[index] = .{
        .packed_sizes = .{
            std.math.cast(u64, payload.packed_size) orelse return error.IntegerOverflow,
            0,
            0,
            0,
        },
        .unpacked_size = unpacked_size,
        .aes_unpack_sizes = .{
            if (payload.aes_unpack_size) |size|
                std.math.cast(u64, size) orelse return error.IntegerOverflow
            else
                null,
            null,
            null,
            null,
        },
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
    try std.testing.expectEqualSlices(u8, &wire.signature, first[0..wire.signature.len]);

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
