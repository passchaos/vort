const std = @import("std");
const core = @import("../core.zig");
const format = @import("format.zig");
const plan_mod = @import("writer_plan.zig");
const resource_writer = @import("writer_resource.zig");
const solid_resource = @import("writer_solid_resource.zig");
const wire = @import("writer_wire.zig");
const xml_writer = @import("writer_xml.zig");

pub const Error = core.Error || format.Error || plan_mod.Error ||
    resource_writer.Error || solid_resource.Error || wire.Error ||
    std.mem.Allocator.Error || error{InvalidWimWriterOptions};

pub const Options = struct {
    metadata_chunk_size: ?usize = null,
    solid_chunk_size: ?usize = null,
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

pub const ImagesOptions = struct {
    metadata_chunk_size: ?usize = null,
    solid_chunk_size: ?usize = null,
    integrity: bool = true,
    guid: ?[16]u8 = null,
    boot_index: u32 = 0,
};

const default_metadata_chunk_size: usize = 128 * 1024;
const default_solid_chunk_size: usize = 64 * 1024 * 1024;

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    entries: []const plan_mod.Entry,
    options: Options,
) Error![]u8 {
    const images = [_]plan_mod.Image{.{
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
        .metadata_chunk_size = options.metadata_chunk_size,
        .solid_chunk_size = options.solid_chunk_size,
        .integrity = options.integrity,
        .guid = options.guid,
        .boot_index = @intFromBool(options.bootable),
    });
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entries: []const plan_mod.Entry,
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
    entries: []const plan_mod.Entry,
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
    images: []const plan_mod.Image,
    options: ImagesOptions,
) Error![]u8 {
    const metadata_chunk_size = options.metadata_chunk_size orelse
        default_metadata_chunk_size;
    const packed_chunk_size = options.solid_chunk_size orelse
        default_solid_chunk_size;
    try validateOptions(images, options, metadata_chunk_size, packed_chunk_size);
    var plan = try plan_mod.Plan.init(allocator, images);
    defer plan.deinit();

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendNTimes(allocator, 0, format.header_size);
    const marker = try solid_resource.append(
        allocator,
        &output,
        plan.blobs.items,
        packed_chunk_size,
    );
    for (plan.images.items) |*image| {
        image.metadata_resource = try resource_writer.append(
            allocator,
            &output,
            image.metadata,
            .lzms,
            metadata_chunk_size,
            0x02,
        );
    }

    const lookup_offset = output.items.len;
    for (plan.images.items) |image|
        try wire.appendLookupEntry(
            allocator,
            &output,
            image.metadata_resource,
            1,
            1,
            &image.metadata_hash,
        );
    if (marker) |resource| {
        const zero_hash: [std.crypto.hash.Sha1.digest_length]u8 = @splat(0);
        try wire.appendLookupEntry(
            allocator,
            &output,
            resource,
            1,
            1,
            &zero_hash,
        );
        for (plan.blobs.items) |blob|
            try wire.appendLookupEntry(
                allocator,
                &output,
                blob.resource,
                1,
                blob.reference_count,
                &blob.sha1,
            );
    }
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
    for (images, plan.images.items, xml_infos) |image, planned, *info| {
        info.* = .{
            .name = image.name,
            .directory_count = planned.tree.directoryCount(),
            .file_count = planned.tree.fileCount(),
            .total_bytes = try planned.tree.totalStreamBytes(),
            .hard_link_bytes = try planned.tree.hardLinkBytes(),
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
    const guid = options.guid orelse plan_mod.deriveGuid(plan.images.items, images);
    const boot_metadata = if (options.boot_index == 0)
        wire.zeroResource()
    else
        plan.images.items[options.boot_index - 1].metadata_resource;
    wire.writeHeader(
        output.items[0..format.header_size],
        format.solid_version,
        .lzms,
        metadata_chunk_size,
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
    images: []const plan_mod.Image,
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
    images: []const plan_mod.Image,
    output: []u8,
    options: ImagesOptions,
) Error!usize {
    const encoded = try encodeImagesAlloc(allocator, images, options);
    defer allocator.free(encoded);
    if (encoded.len > output.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

fn validateOptions(
    images: []const plan_mod.Image,
    options: ImagesOptions,
    metadata_chunk_size: usize,
    packed_chunk_size: usize,
) Error!void {
    if (images.len == 0 or images.len > 65_535 or options.boot_index > images.len)
        return error.InvalidWimWriterOptions;
    resource_writer.validate(.lzms, metadata_chunk_size) catch
        return error.InvalidWimWriterOptions;
    format.validateChunkSize(.lzms, packed_chunk_size) catch
        return error.InvalidWimWriterOptions;
    for (images, 0..) |image, index| {
        try xml_writer.validateName(image.name);
        if (image.name.len == 0) continue;
        for (images[0..index]) |prior|
            if (prior.name.len != 0 and std.ascii.eqlIgnoreCase(prior.name, image.name))
                return error.InvalidWimWriterOptions;
    }
}
