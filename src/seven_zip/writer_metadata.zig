//! Shared terminal packed-stream construction for one-shot and backpatch 7z writers.

const std = @import("std");
const checksum = @import("../checksum.zig");
const coders = @import("coders.zig");
const wire = @import("writer_wire.zig");

pub fn optionsForNextEncryptedStream(
    base: coders.Options,
    next_stream_index: *u64,
) !coders.Options {
    if (base.encryption == null) return base;
    var options = base;
    options.encryption_stream_index = next_stream_index.*;
    const stream_count: u64 = if (base.bcj2) 4 else 1;
    next_stream_index.* = std.math.add(u64, next_stream_index.*, stream_count) catch
        return error.IntegerOverflow;
    return options;
}

pub fn appendExternalPayload(
    allocator: std.mem.Allocator,
    packed_data: *std.ArrayList(u8),
    external: *wire.EncodedExternalStreams,
    input: []const u8,
    base_options: coders.Options,
    compression: coders.Compression,
    next_encryption_stream_index: *u64,
    first_pack_position: u64,
) !usize {
    std.debug.assert(external.count < wire.max_external_streams);
    if (external.count == 0) external.pack_position = first_pack_position;
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

pub fn appendFinalHeader(
    allocator: std.mem.Allocator,
    packed_data: *std.ArrayList(u8),
    next_header: *std.ArrayList(u8),
    ordinary_header: []const u8,
    base_options: coders.Options,
    next_encryption_stream_index: *u64,
    header_pack_position: u64,
) !void {
    if (base_options.header_compression == null and !base_options.encrypt_header) {
        try next_header.appendSlice(allocator, ordinary_header);
        return;
    }

    var header_options = base_options;
    header_options.compression = base_options.header_compression orelse .copy;
    header_options.solid = false;
    header_options.header_compression = null;
    header_options.external_names = null;
    header_options.external_metadata = null;
    header_options.encrypt_header = false;
    if (!base_options.encrypt_header) header_options.encryption = null;
    header_options.bcj2 = false;
    header_options.bcj2_start_ip = 0;
    header_options.filters = &.{};
    header_options = try optionsForNextEncryptedStream(
        header_options,
        next_encryption_stream_index,
    );
    const payload = try coders.appendPayloadDetailed(
        allocator,
        packed_data,
        ordinary_header,
        header_options,
    );
    const header_folders = [_]wire.EncodedFolder{.{
        .packed_sizes = .{
            std.math.cast(u64, payload.packed_size) orelse return error.IntegerOverflow,
            0,
            0,
            0,
        },
        .unpacked_size = std.math.cast(u64, ordinary_header.len) orelse
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
        .crc32 = checksum.crc32Best(ordinary_header),
        .first_substream = 0,
        .substream_count = 1,
    }};
    const header_substreams = [_]wire.EncodedSubstream{.{
        .unpacked_size = header_folders[0].unpacked_size,
        .crc32 = header_folders[0].crc32,
    }};
    try next_header.append(allocator, wire.Nid.encoded_header);
    try wire.writeStreamsBody(
        allocator,
        next_header,
        &header_folders,
        &header_substreams,
        header_options,
        header_pack_position,
    );
}
