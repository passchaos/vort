const std = @import("std");
const core = @import("../core.zig");
const format = @import("format.zig");
const append_image_writer = @import("writer_append_image.zig");
const compact_writer = @import("writer_compact.zig");
const delete_image_writer = @import("writer_delete_image.zig");
const replace_image_writer = @import("writer_replace_image.zig");
const pipable_writer = @import("writer_pipable.zig");
const plan_mod = @import("writer_plan.zig");
const resource_writer = @import("writer_resource.zig");
const split_writer = @import("writer_split.zig");
const solid_writer = @import("writer_solid.zig");
const streams = @import("writer_streams.zig");
const tree_mod = @import("writer_tree.zig");
const wire = @import("writer_wire.zig");
const xml_writer = @import("writer_xml.zig");

pub const Error = core.Error || format.Error || append_image_writer.Error || compact_writer.Error || delete_image_writer.Error || replace_image_writer.Error || pipable_writer.Error || plan_mod.Error ||
    resource_writer.Error || solid_writer.Error || split_writer.Error || tree_mod.Error || wire.Error ||
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
pub const AppendImageOptions = append_image_writer.Options;
pub const appendImageAlloc = append_image_writer.appendAlloc;
pub const appendImageAppend = append_image_writer.appendAppend;
pub const appendImageInto = append_image_writer.appendInto;
pub const CompactOptions = compact_writer.Options;
pub const compactAlloc = compact_writer.compactAlloc;
pub const compactAppend = compact_writer.compactAppend;
pub const compactInto = compact_writer.compactInto;
pub const DeleteImageOptions = delete_image_writer.Options;
pub const deleteImageAlloc = delete_image_writer.deleteAlloc;
pub const deleteImageAppend = delete_image_writer.deleteAppend;
pub const deleteImageInto = delete_image_writer.deleteInto;
pub const ReplaceImageOptions = replace_image_writer.Options;
pub const replaceImageAlloc = replace_image_writer.replaceAlloc;
pub const replaceImageAppend = replace_image_writer.replaceAppend;
pub const replaceImageInto = replace_image_writer.replaceInto;
pub const SolidOptions = solid_writer.Options;
pub const SolidImagesOptions = solid_writer.ImagesOptions;
pub const encodeSolidAlloc = solid_writer.encodeAlloc;
pub const encodeSolidAppend = solid_writer.encodeAppend;
pub const encodeSolidInto = solid_writer.encodeInto;
pub const encodeImagesSolidAlloc = solid_writer.encodeImagesAlloc;
pub const encodeImagesSolidAppend = solid_writer.encodeImagesAppend;
pub const encodeImagesSolidInto = solid_writer.encodeImagesInto;

pub const Options = struct {
    compression: Compression = .xpress,
    /// null selects 32 KiB for XPRESS/LZX/LZMS and 0 for stored WIMs.
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

pub const Image = plan_mod.Image;

pub const ImagesOptions = struct {
    compression: Compression = .xpress,
    /// null selects 32 KiB for XPRESS/LZX/LZMS and 0 for stored WIMs.
    chunk_size: ?usize = null,
    integrity: bool = true,
    guid: ?[16]u8 = null,
    boot_index: u32 = 0,
};

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

    var archive_plan = try plan_mod.Plan.init(allocator, images);
    defer archive_plan.deinit();
    const planned = &archive_plan.images;
    const blobs = &archive_plan.blobs;

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
        try wire.appendLookupEntry(allocator, &output, blob.resource, 1, blob.reference_count, &blob.sha1);
    for (planned.items) |image|
        try wire.appendLookupEntry(
            allocator,
            &output,
            image.metadata_resource,
            1,
            1,
            &image.metadata_hash,
        );
    const lookup_resource = try wire.resourceHeader(
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
    const xml_resource = try wire.resourceHeader(xml_offset, xml.len, xml.len, 0x02);

    const integrity_resource = if (options.integrity)
        try wire.appendIntegrity(allocator, &output, lookup_end)
    else
        wire.zeroResource();
    const guid = options.guid orelse plan_mod.deriveGuid(planned.items, images);
    const boot_metadata = if (options.boot_index == 0)
        wire.zeroResource()
    else
        planned.items[options.boot_index - 1].metadata_resource;
    wire.writeHeader(
        output.items[0..format.header_size],
        format.default_version,
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

fn effectiveChunkSize(
    compression: Compression,
    selected: ?usize,
) Error!usize {
    return selected orelse switch (compression) {
        .stored => 0,
        .xpress => 32 * 1024,
        .lzx => 32 * 1024,
        .lzms => 32 * 1024,
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
