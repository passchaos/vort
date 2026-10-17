const std = @import("std");
const core = @import("../core.zig");
const format = @import("format.zig");
const metadata_writer = @import("writer_metadata.zig");
const pipable_writer = @import("writer_pipable.zig");
const resource_writer = @import("writer_resource.zig");
const security = @import("writer_security.zig");
const split_writer = @import("writer_split.zig");
const streams = @import("writer_streams.zig");
const tree_mod = @import("writer_tree.zig");
const xml_writer = @import("writer_xml.zig");

pub const Error = core.Error || format.Error || metadata_writer.Error ||
    pipable_writer.Error || resource_writer.Error || split_writer.Error || tree_mod.Error ||
    std.mem.Allocator.Error || error{
    InvalidWimWriterOptions,
    InvalidWimEntry,
    WimResourceTooLarge,
};

pub const Entry = tree_mod.Entry;
pub const EntryKind = tree_mod.EntryKind;
pub const NamedStream = streams.NamedStream;
pub const ReparseData = streams.ReparseData;
pub const Compression = resource_writer.Compression;
pub const SplitOptions = split_writer.Options;
pub const SplitPart = split_writer.Part;
pub const SplitArchive = split_writer.SplitArchive;
pub const PipableOptions = pipable_writer.Options;

pub const Options = struct {
    compression: Compression = .xpress,
    /// null selects 32 KiB for XPRESS and 0 for stored WIMs.
    chunk_size: ?usize = null,
    image_name: []const u8 = "Vort Image",
    integrity: bool = true,
    guid: ?[16]u8 = null,
    root_creation_time: u64 = 0,
    root_last_access_time: u64 = 0,
    root_last_write_time: u64 = 0,
    xml_creation_time: u64 = 0,
    xml_last_modification_time: u64 = 0,
    root_security_descriptor: ?[]const u8 = null,
    bootable: bool = false,
};

pub const Image = struct {
    name: []const u8 = "Vort Image",
    entries: []const Entry,
    root_creation_time: u64 = 0,
    root_last_access_time: u64 = 0,
    root_last_write_time: u64 = 0,
    root_security_descriptor: ?[]const u8 = null,
    creation_time: u64 = 0,
    last_modification_time: u64 = 0,
};

pub const ImagesOptions = struct {
    compression: Compression = .xpress,
    /// null selects 32 KiB for XPRESS and 0 for stored WIMs.
    chunk_size: ?usize = null,
    integrity: bool = true,
    guid: ?[16]u8 = null,
    boot_index: u32 = 0,
};

const Blob = struct {
    sha1: [std.crypto.hash.Sha1.digest_length]u8,
    data: []const u8,
    reference_count: u32,
    resource: format.ResourceHeader = undefined,
};

const PlannedImage = struct {
    tree: tree_mod.Tree,
    metadata: []u8,
    metadata_hash: [std.crypto.hash.Sha1.digest_length]u8,
    metadata_resource: format.ResourceHeader = undefined,
};

const integrity_chunk_size: usize = 10 * 1024 * 1024;

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    entries: []const Entry,
    options: Options,
) Error![]u8 {
    const images = [_]Image{.{
        .name = options.image_name,
        .entries = entries,
        .root_creation_time = options.root_creation_time,
        .root_last_access_time = options.root_last_access_time,
        .root_last_write_time = options.root_last_write_time,
        .root_security_descriptor = options.root_security_descriptor,
        .creation_time = options.xml_creation_time,
        .last_modification_time = options.xml_last_modification_time,
    }};
    return encodeImagesAlloc(allocator, &images, .{
        .compression = options.compression,
        .chunk_size = options.chunk_size,
        .integrity = options.integrity,
        .guid = options.guid,
        .boot_index = @intFromBool(options.bootable),
    });
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entries: []const Entry,
    options: Options,
) Error!usize {
    const encoded = try encodeAlloc(allocator, entries, options);
    defer allocator.free(encoded);
    try output.ensureUnusedCapacity(allocator, encoded.len);
    output.appendSliceAssumeCapacity(encoded);
    return encoded.len;
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    entries: []const Entry,
    output: []u8,
    options: Options,
) Error!usize {
    const encoded = try encodeAlloc(allocator, entries, options);
    defer allocator.free(encoded);
    if (encoded.len > output.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

pub fn encodeImagesAlloc(
    allocator: std.mem.Allocator,
    images: []const Image,
    options: ImagesOptions,
) Error![]u8 {
    const chunk_size = try effectiveChunkSize(options.compression, options.chunk_size);
    try validateImagesOptions(images, options, chunk_size);

    var planned: std.ArrayList(PlannedImage) = .empty;
    defer deinitPlannedImages(allocator, &planned);
    for (images) |image| {
        var tree = try tree_mod.build(allocator, image.entries, .{
            .creation_time = image.root_creation_time,
            .last_access_time = image.root_last_access_time,
            .last_write_time = image.root_last_write_time,
            .security_descriptor = image.root_security_descriptor,
        });
        errdefer tree.deinit();
        var security_table = try security.plan(allocator, &tree);
        defer security_table.deinit();
        const metadata = try metadata_writer.encodeAlloc(
            allocator,
            &tree,
            security_table.descriptors,
        );
        errdefer allocator.free(metadata);
        var metadata_hash: [std.crypto.hash.Sha1.digest_length]u8 = undefined;
        std.crypto.hash.Sha1.hash(metadata, &metadata_hash, .{});
        try planned.append(allocator, .{
            .tree = tree,
            .metadata = metadata,
            .metadata_hash = metadata_hash,
        });
    }

    var blobs: std.ArrayList(Blob) = .empty;
    defer blobs.deinit(allocator);
    for (planned.items) |image|
        try collectBlobs(allocator, &blobs, image.tree.nodes);

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendNTimes(allocator, 0, format.header_size);
    for (blobs.items) |*blob| {
        blob.resource = try resource_writer.append(
            allocator,
            &output,
            blob.data,
            options.compression,
            chunk_size,
            0,
        );
    }
    for (planned.items) |*image| {
        image.metadata_resource = try resource_writer.append(
            allocator,
            &output,
            image.metadata,
            options.compression,
            chunk_size,
            0x02,
        );
    }

    const lookup_offset = output.items.len;
    for (blobs.items) |blob|
        try appendLookupEntry(allocator, &output, blob.resource, blob.reference_count, &blob.sha1);
    for (planned.items) |image|
        try appendLookupEntry(
            allocator,
            &output,
            image.metadata_resource,
            1,
            &image.metadata_hash,
        );
    const lookup_resource = try resourceHeader(
        lookup_offset,
        output.items.len - lookup_offset,
        output.items.len - lookup_offset,
        0x02,
    );
    const lookup_end = output.items.len;

    const xml_offset = output.items.len;
    const xml_infos = try allocator.alloc(xml_writer.ImageInfo, images.len);
    defer allocator.free(xml_infos);
    for (images, planned.items, xml_infos) |image, plan, *info| {
        info.* = .{
            .name = image.name,
            .directory_count = plan.tree.directoryCount(),
            .file_count = plan.tree.fileCount(),
            .total_bytes = try plan.tree.totalStreamBytes(),
            .hard_link_bytes = try plan.tree.hardLinkBytes(),
            .creation_time = image.creation_time,
            .last_modification_time = image.last_modification_time,
        };
    }
    const xml = try xml_writer.encodeAlloc(allocator, xml_infos, xml_offset);
    defer allocator.free(xml);
    try output.appendSlice(allocator, xml);
    const xml_resource = try resourceHeader(xml_offset, xml.len, xml.len, 0x02);

    const integrity_resource = if (options.integrity)
        try appendIntegrity(allocator, &output, lookup_end)
    else
        zeroResource();
    const guid = options.guid orelse deriveImagesGuid(planned.items, images);
    const boot_metadata = if (options.boot_index == 0)
        zeroResource()
    else
        planned.items[options.boot_index - 1].metadata_resource;
    writeHeader(
        output.items[0..format.header_size],
        options.compression,
        chunk_size,
        &guid,
        @intCast(images.len),
        lookup_resource,
        xml_resource,
        boot_metadata,
        options.boot_index,
        integrity_resource,
    );
    return output.toOwnedSlice(allocator);
}

pub fn encodeImagesAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    images: []const Image,
    options: ImagesOptions,
) Error!usize {
    const encoded = try encodeImagesAlloc(allocator, images, options);
    defer allocator.free(encoded);
    try output.ensureUnusedCapacity(allocator, encoded.len);
    output.appendSliceAssumeCapacity(encoded);
    return encoded.len;
}

pub fn encodeImagesInto(
    allocator: std.mem.Allocator,
    images: []const Image,
    output: []u8,
    options: ImagesOptions,
) Error!usize {
    const encoded = try encodeImagesAlloc(allocator, images, options);
    defer allocator.free(encoded);
    if (encoded.len > output.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

pub fn splitArchiveAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: SplitOptions,
) Error!SplitArchive {
    return split_writer.splitAlloc(allocator, input, options);
}

pub fn encodeSplitAlloc(
    allocator: std.mem.Allocator,
    entries: []const Entry,
    options: Options,
    split_options: SplitOptions,
) Error!SplitArchive {
    const encoded = try encodeAlloc(allocator, entries, options);
    defer allocator.free(encoded);
    return split_writer.splitAlloc(allocator, encoded, split_options);
}

pub fn encodeImagesSplitAlloc(
    allocator: std.mem.Allocator,
    images: []const Image,
    options: ImagesOptions,
    split_options: SplitOptions,
) Error!SplitArchive {
    const encoded = try encodeImagesAlloc(allocator, images, options);
    defer allocator.free(encoded);
    return split_writer.splitAlloc(allocator, encoded, split_options);
}

pub fn toPipableAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: PipableOptions,
) Error![]u8 {
    return pipable_writer.encodeAlloc(allocator, input, options);
}

pub fn toPipableAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    options: PipableOptions,
) Error!usize {
    return pipable_writer.encodeAppend(allocator, output, input, options);
}

pub fn toPipableInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
    options: PipableOptions,
) Error!usize {
    return pipable_writer.encodeInto(allocator, input, output, options);
}

pub fn encodePipableAlloc(
    allocator: std.mem.Allocator,
    entries: []const Entry,
    options: Options,
    pipable_options: PipableOptions,
) Error![]u8 {
    var standard_options = options;
    standard_options.integrity = false;
    const standard = try encodeAlloc(allocator, entries, standard_options);
    defer allocator.free(standard);
    return pipable_writer.encodeAlloc(allocator, standard, pipable_options);
}

pub fn encodePipableAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entries: []const Entry,
    options: Options,
    pipable_options: PipableOptions,
) Error!usize {
    const encoded = try encodePipableAlloc(
        allocator,
        entries,
        options,
        pipable_options,
    );
    defer allocator.free(encoded);
    try output.ensureUnusedCapacity(allocator, encoded.len);
    output.appendSliceAssumeCapacity(encoded);
    return encoded.len;
}

pub fn encodePipableInto(
    allocator: std.mem.Allocator,
    entries: []const Entry,
    output: []u8,
    options: Options,
    pipable_options: PipableOptions,
) Error!usize {
    const encoded = try encodePipableAlloc(
        allocator,
        entries,
        options,
        pipable_options,
    );
    defer allocator.free(encoded);
    if (encoded.len > output.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

pub fn encodeImagesPipableAlloc(
    allocator: std.mem.Allocator,
    images: []const Image,
    options: ImagesOptions,
    pipable_options: PipableOptions,
) Error![]u8 {
    var standard_options = options;
    standard_options.integrity = false;
    const standard = try encodeImagesAlloc(allocator, images, standard_options);
    defer allocator.free(standard);
    return pipable_writer.encodeAlloc(allocator, standard, pipable_options);
}

pub fn encodeImagesPipableAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    images: []const Image,
    options: ImagesOptions,
    pipable_options: PipableOptions,
) Error!usize {
    const encoded = try encodeImagesPipableAlloc(
        allocator,
        images,
        options,
        pipable_options,
    );
    defer allocator.free(encoded);
    try output.ensureUnusedCapacity(allocator, encoded.len);
    output.appendSliceAssumeCapacity(encoded);
    return encoded.len;
}

pub fn encodeImagesPipableInto(
    allocator: std.mem.Allocator,
    images: []const Image,
    output: []u8,
    options: ImagesOptions,
    pipable_options: PipableOptions,
) Error!usize {
    const encoded = try encodeImagesPipableAlloc(
        allocator,
        images,
        options,
        pipable_options,
    );
    defer allocator.free(encoded);
    if (encoded.len > output.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

pub fn encodePipableSplitAlloc(
    allocator: std.mem.Allocator,
    entries: []const Entry,
    options: Options,
    split_options: SplitOptions,
    pipable_options: PipableOptions,
) Error!SplitArchive {
    var standard_options = options;
    standard_options.integrity = false;
    var standard_split_options = split_options;
    standard_split_options.integrity = false;
    var standard = try encodeSplitAlloc(
        allocator,
        entries,
        standard_options,
        standard_split_options,
    );
    defer standard.deinit();
    return pipableSplitAlloc(allocator, standard.parts, pipable_options);
}

pub fn encodeImagesPipableSplitAlloc(
    allocator: std.mem.Allocator,
    images: []const Image,
    options: ImagesOptions,
    split_options: SplitOptions,
    pipable_options: PipableOptions,
) Error!SplitArchive {
    var standard_options = options;
    standard_options.integrity = false;
    var standard_split_options = split_options;
    standard_split_options.integrity = false;
    var standard = try encodeImagesSplitAlloc(
        allocator,
        images,
        standard_options,
        standard_split_options,
    );
    defer standard.deinit();
    return pipableSplitAlloc(allocator, standard.parts, pipable_options);
}

fn pipableSplitAlloc(
    allocator: std.mem.Allocator,
    source_parts: []const SplitPart,
    options: PipableOptions,
) Error!SplitArchive {
    if (source_parts.len == 0) return error.InvalidWimSplitOptions;
    const parts = try allocator.alloc(SplitPart, source_parts.len);
    errdefer allocator.free(parts);
    var initialized: usize = 0;
    errdefer for (parts[0..initialized]) |part| allocator.free(part.bytes);
    for (source_parts, parts) |source, *part| {
        part.* = .{
            .part_number = source.part_number,
            .bytes = try pipable_writer.encodeAlloc(
                allocator,
                source.bytes,
                options,
            ),
        };
        initialized += 1;
    }
    return .{ .allocator = allocator, .parts = parts };
}

fn deinitPlannedImages(
    allocator: std.mem.Allocator,
    planned: *std.ArrayList(PlannedImage),
) void {
    for (planned.items) |*image| {
        allocator.free(image.metadata);
        image.tree.deinit();
    }
    planned.deinit(allocator);
}

fn effectiveChunkSize(
    compression: Compression,
    selected: ?usize,
) Error!usize {
    return selected orelse switch (compression) {
        .stored => 0,
        .xpress => 32 * 1024,
    };
}

fn validateImagesOptions(
    images: []const Image,
    options: ImagesOptions,
    chunk_size: usize,
) Error!void {
    if (images.len == 0 or images.len > 65_535 or options.boot_index > images.len)
        return error.InvalidWimWriterOptions;
    try resource_writer.validate(options.compression, chunk_size);
    for (images, 0..) |image, index| {
        try xml_writer.validateName(image.name);
        if (image.name.len == 0) continue;
        for (images[0..index]) |prior| {
            if (prior.name.len != 0 and std.ascii.eqlIgnoreCase(prior.name, image.name))
                return error.InvalidWimWriterOptions;
        }
    }
}

fn collectBlobs(
    allocator: std.mem.Allocator,
    blobs: *std.ArrayList(Blob),
    nodes: []const tree_mod.Node,
) Error!void {
    for (nodes) |node| {
        const stream_set = node.streamSet();
        if (stream_set.mainData()) |data| try collectBlob(allocator, blobs, data);
        var iterator = stream_set.extraStreams();
        while (iterator.next()) |stream|
            try collectBlob(allocator, blobs, stream.data);
    }
}

fn collectBlob(
    allocator: std.mem.Allocator,
    blobs: *std.ArrayList(Blob),
    data: []const u8,
) Error!void {
    if (data.len == 0) return;
    const sha1 = streams.hash(data);
    for (blobs.items) |*blob| {
        if (!std.mem.eql(u8, &blob.sha1, &sha1)) continue;
        if (!std.mem.eql(u8, blob.data, data)) return error.InvalidWimEntry;
        blob.reference_count = std.math.add(u32, blob.reference_count, 1) catch
            return error.IntegerOverflow;
        return;
    }
    try blobs.append(allocator, .{
        .sha1 = sha1,
        .data = data,
        .reference_count = 1,
    });
}

fn appendLookupEntry(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    resource: format.ResourceHeader,
    reference_count: u32,
    sha1: *const [std.crypto.hash.Sha1.digest_length]u8,
) Error!void {
    const offset = output.items.len;
    try output.appendNTimes(allocator, 0, format.lookup_entry_size);
    writeResourceHeader(output.items, offset, resource);
    writeU16(output.items, offset + 24, 1);
    writeU32(output.items, offset + 26, reference_count);
    @memcpy(output.items[offset + 30 .. offset + 50], sha1);
}

fn appendIntegrity(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    lookup_end: usize,
) Error!format.ResourceHeader {
    if (lookup_end < format.header_size or lookup_end > output.items.len)
        return error.InvalidWimWriterOptions;
    const checked_len = lookup_end - format.header_size;
    const entry_count = if (checked_len == 0)
        0
    else
        1 + (checked_len - 1) / integrity_chunk_size;
    if (entry_count > std.math.maxInt(u32)) return error.WimResourceTooLarge;
    const table_len = try checkedAdd(
        12,
        std.math.mul(usize, entry_count, std.crypto.hash.Sha1.digest_length) catch
            return error.IntegerOverflow,
    );
    const offset = output.items.len;
    try output.appendNTimes(allocator, 0, table_len);
    writeU32(output.items, offset, @as(u32, @intCast(table_len)));
    writeU32(output.items, offset + 4, @as(u32, @intCast(entry_count)));
    writeU32(output.items, offset + 8, integrity_chunk_size);
    for (0..entry_count) |index| {
        const start = format.header_size + index * integrity_chunk_size;
        const end = @min(lookup_end, start + integrity_chunk_size);
        std.crypto.hash.Sha1.hash(
            output.items[start..end],
            output.items[offset + 12 + index * 20 ..][0..20],
            .{},
        );
    }
    return resourceHeader(offset, table_len, table_len, 0);
}

fn resourceHeader(
    offset: usize,
    stored_size: usize,
    uncompressed_size: usize,
    flags: u8,
) Error!format.ResourceHeader {
    if (stored_size >= @as(u64, 1) << 56)
        return error.WimResourceTooLarge;
    return .{
        .size_in_wim = stored_size,
        .flags = flags,
        .offset_in_wim = offset,
        .uncompressed_size = uncompressed_size,
    };
}

fn deriveGuid(
    metadata_hash: *const [std.crypto.hash.Sha1.digest_length]u8,
    image_name: []const u8,
) [16]u8 {
    var hasher = std.crypto.hash.Sha1.init(.{});
    hasher.update("vort deterministic WIM\x00");
    hasher.update(metadata_hash);
    hasher.update(image_name);
    var digest: [std.crypto.hash.Sha1.digest_length]u8 = undefined;
    hasher.final(&digest);
    var guid: [16]u8 = undefined;
    @memcpy(&guid, digest[0..16]);
    guid[6] = (guid[6] & 0x0f) | 0x50;
    guid[8] = (guid[8] & 0x3f) | 0x80;
    return guid;
}

fn deriveImagesGuid(
    planned: []const PlannedImage,
    images: []const Image,
) [16]u8 {
    if (images.len == 1)
        return deriveGuid(&planned[0].metadata_hash, images[0].name);
    var hasher = std.crypto.hash.Sha1.init(.{});
    hasher.update("vort deterministic multi-image WIM\x00");
    for (planned, images) |plan, image| {
        hasher.update(&plan.metadata_hash);
        var name_len: [8]u8 = undefined;
        std.mem.writeInt(u64, &name_len, image.name.len, .little);
        hasher.update(&name_len);
        hasher.update(image.name);
    }
    var digest: [std.crypto.hash.Sha1.digest_length]u8 = undefined;
    hasher.final(&digest);
    var guid: [16]u8 = undefined;
    @memcpy(&guid, digest[0..16]);
    guid[6] = (guid[6] & 0x0f) | 0x50;
    guid[8] = (guid[8] & 0x3f) | 0x80;
    return guid;
}

fn zeroResource() format.ResourceHeader {
    return .{
        .size_in_wim = 0,
        .flags = 0,
        .offset_in_wim = 0,
        .uncompressed_size = 0,
    };
}

fn writeHeader(
    header: []u8,
    compression: Compression,
    chunk_size: usize,
    guid: *const [16]u8,
    image_count: u32,
    lookup_resource: format.ResourceHeader,
    xml_resource: format.ResourceHeader,
    boot_metadata: format.ResourceHeader,
    boot_index: u32,
    integrity_resource: format.ResourceHeader,
) void {
    @memset(header, 0);
    @memcpy(header[0..8], &format.magic);
    writeU32(header, 8, format.header_size);
    writeU32(header, 12, format.default_version);
    const flags: u32 = switch (compression) {
        .stored => 0,
        .xpress => 0x0000_0002 | 0x0002_0000,
    };
    writeU32(header, 16, flags);
    writeU32(header, 20, @as(u32, @intCast(chunk_size)));
    @memcpy(header[24..40], guid);
    writeU16(header, 40, 1);
    writeU16(header, 42, 1);
    writeU32(header, 44, image_count);
    writeResourceHeader(header, 48, lookup_resource);
    writeResourceHeader(header, 72, xml_resource);
    writeResourceHeader(header, 96, boot_metadata);
    writeU32(header, 120, boot_index);
    writeResourceHeader(header, 124, integrity_resource);
}

fn writeResourceHeader(
    output: []u8,
    offset: usize,
    resource: format.ResourceHeader,
) void {
    for (0..7) |index|
        output[offset + index] = @truncate(resource.size_in_wim >> @intCast(index * 8));
    output[offset + 7] = resource.flags;
    writeU64(output, offset + 8, resource.offset_in_wim);
    writeU64(output, offset + 16, resource.uncompressed_size);
}

fn checkedAdd(left: usize, right: usize) Error!usize {
    return std.math.add(usize, left, right) catch error.IntegerOverflow;
}

fn writeU16(output: []u8, offset: usize, value: u16) void {
    std.mem.writeInt(u16, output[offset..][0..2], value, .little);
}

fn writeU32(output: []u8, offset: usize, value: u32) void {
    std.mem.writeInt(u32, output[offset..][0..4], value, .little);
}

fn writeU64(output: []u8, offset: usize, value: u64) void {
    std.mem.writeInt(u64, output[offset..][0..8], value, .little);
}
