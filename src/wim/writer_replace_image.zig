const std = @import("std");
const core = @import("../core.zig");
const append_writer = @import("writer_append_image.zig");
const archive_mod = @import("archive.zig");
const delete_writer = @import("writer_delete_image.zig");
const format = @import("format.zig");
const plan_mod = @import("writer_plan.zig");
const wire = @import("writer_wire.zig");
const xml_writer = @import("writer_xml.zig");

pub const Error = core.Error || append_writer.Error || archive_mod.Error ||
    delete_writer.Error || format.Error || plan_mod.Error || wire.Error ||
    xml_writer.Error || std.mem.Allocator.Error || error{
    InvalidWimWriterOptions,
    UnsupportedWimUpdateInput,
};

pub const Options = struct {
    integrity: ?bool = null,
    bootable: ?bool = null,
    solid_chunk_size: ?usize = null,
    max_lookup_entries: usize = 4 * 1024 * 1024,
    max_lookup_bytes: usize = 256 * 1024 * 1024,
    max_xml_bytes: usize = 256 * 1024 * 1024,
    max_metadata_bytes: usize = 256 * 1024 * 1024,
    max_directory_entries: usize = 1024 * 1024,
    max_path_depth: usize = 256,
    max_solid_chunk_bytes: usize = 256 * 1024 * 1024,
};

pub fn replaceAlloc(
    allocator: std.mem.Allocator,
    source: []const u8,
    image_index: u32,
    image: plan_mod.Image,
    options: Options,
) Error![]u8 {
    const source_archive = try archive_mod.Archive.init(source);
    const unsupported_header_flags: u32 = 0x08 | 0x10 | 0x20 | 0x40;
    if (source_archive.header.pipable or
        source_archive.header.part_number != 1 or
        source_archive.header.total_parts != 1 or
        source_archive.header.image_count == 0 or
        image_index == 0 or image_index > source_archive.header.image_count or
        source_archive.header.boot_index > source_archive.header.image_count or
        source_archive.header.flags & unsupported_header_flags != 0)
        return error.UnsupportedWimUpdateInput;
    if (options.max_lookup_entries == 0 or options.max_lookup_bytes == 0 or
        options.max_xml_bytes == 0 or options.max_metadata_bytes == 0 or
        options.max_directory_entries == 0 or options.max_path_depth == 0 or
        options.max_solid_chunk_bytes == 0)
        return error.InvalidWimWriterOptions;
    if (options.solid_chunk_size) |chunk_size|
        format.validateChunkSize(.lzms, chunk_size) catch
            return error.InvalidWimWriterOptions;

    const source_xml = try source_archive.readXmlAllocLimited(
        allocator,
        options.max_xml_bytes,
    );
    defer allocator.free(source_xml);
    var replacement_plan = try plan_mod.Plan.init(allocator, &.{image});
    defer replacement_plan.deinit();
    const replacement = &replacement_plan.images.items[0];
    var source_lookup = try source_archive.readLookupTableRawAlloc(
        allocator,
        options.max_lookup_entries,
        options.max_lookup_bytes,
    );
    defer source_lookup.deinit();
    const stage_entry_headroom = std.math.add(
        usize,
        replacement_plan.blobs.items.len,
        2,
    ) catch return error.IntegerOverflow;
    const stage_max_lookup_entries = std.math.add(
        usize,
        source_lookup.entries.len,
        stage_entry_headroom,
    ) catch return error.IntegerOverflow;
    const stage_max_lookup_bytes = std.math.mul(
        usize,
        stage_max_lookup_entries,
        format.lookup_entry_size,
    ) catch return error.IntegerOverflow;
    const replacement_info: xml_writer.ImageInfo = .{
        .name = image.name,
        .directory_count = replacement.tree.directoryCount(),
        .file_count = replacement.tree.fileCount(),
        .total_bytes = try replacement.tree.totalStreamBytes(),
        .hard_link_bytes = try replacement.tree.hardLinkBytes(),
        .creation_time = image.creation_time,
        .last_modification_time = image.last_modification_time,
    };

    // Stage the replacement under an empty name so replacing an image with its
    // existing name does not collide while both images temporarily coexist.
    var staged_image = image;
    staged_image.name = "";
    const appended = try append_writer.appendAlloc(
        allocator,
        source,
        staged_image,
        .{
            .integrity = false,
            .bootable = false,
            .solid_chunk_size = options.solid_chunk_size,
            .max_lookup_entries = options.max_lookup_entries,
            .max_lookup_bytes = options.max_lookup_bytes,
            .max_xml_bytes = options.max_xml_bytes,
            .max_solid_chunk_bytes = options.max_solid_chunk_bytes,
        },
    );
    defer allocator.free(appended);
    const prepared = try delete_writer.deleteAlloc(
        allocator,
        appended,
        image_index,
        .{
            .integrity = false,
            .max_lookup_entries = stage_max_lookup_entries,
            .max_lookup_bytes = stage_max_lookup_bytes,
            .max_xml_bytes = appended.len,
            .max_metadata_bytes = options.max_metadata_bytes,
            .max_directory_entries = options.max_directory_entries,
            .max_path_depth = options.max_path_depth,
        },
    );
    defer allocator.free(prepared);

    const prepared_archive = try archive_mod.Archive.init(prepared);
    if (prepared_archive.header.image_count != source_archive.header.image_count)
        return error.UnsupportedWimUpdateInput;
    var lookup = try prepared_archive.readLookupTableRawAlloc(
        allocator,
        stage_max_lookup_entries,
        stage_max_lookup_bytes,
    );
    defer lookup.deinit();
    const metadata_indices = try metadataIndicesAlloc(
        allocator,
        lookup.entries,
        source_archive.header.image_count,
    );
    defer allocator.free(metadata_indices);

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendSlice(allocator, prepared);
    const lookup_offset = output.items.len;
    for (0..metadata_indices.len) |final_index| {
        const prepared_index = preparedMetadataIndex(
            final_index,
            image_index - 1,
            metadata_indices.len,
        );
        try appendEntry(
            allocator,
            &output,
            lookup.entries[metadata_indices[prepared_index]],
        );
    }
    for (lookup.entries) |entry|
        if (!entry.resource.isMetadata())
            try appendEntry(allocator, &output, entry);
    const lookup_resource = try wire.resourceHeader(
        lookup_offset,
        output.items.len - lookup_offset,
        output.items.len - lookup_offset,
        0x02,
    );
    const lookup_end = output.items.len;

    const xml_offset = output.items.len;
    const updated_xml = try xml_writer.replaceImageAlloc(
        allocator,
        source_xml,
        source_archive.header.image_count,
        image_index,
        replacement_info,
        xml_offset,
    );
    defer allocator.free(updated_xml);
    try output.appendSlice(allocator, updated_xml);
    const xml_resource = try wire.resourceHeader(
        xml_offset,
        updated_xml.len,
        updated_xml.len,
        0x02,
    );
    const use_integrity = options.integrity orelse
        !source_archive.header.integrity_table.isZero();
    const integrity_resource = if (use_integrity)
        try wire.appendIntegrity(allocator, &output, lookup_end)
    else
        wire.zeroResource();

    const boot_index = replacementBootIndex(
        source_archive.header.boot_index,
        image_index,
        options.bootable,
    );
    const boot_metadata = if (boot_index == 0)
        wire.zeroResource()
    else blk: {
        const prepared_index = preparedMetadataIndex(
            boot_index - 1,
            image_index - 1,
            metadata_indices.len,
        );
        break :blk lookup.entries[metadata_indices[prepared_index]].resource;
    };
    wire.writeHeaderWithFlags(
        output.items[0..format.header_size],
        source_archive.header.version,
        source_archive.header.flags,
        source_archive.header.chunk_size,
        &source_archive.header.guid,
        source_archive.header.image_count,
        lookup_resource,
        xml_resource,
        boot_metadata,
        boot_index,
        integrity_resource,
    );
    return output.toOwnedSlice(allocator);
}

pub fn replaceAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    source: []const u8,
    image_index: u32,
    image: plan_mod.Image,
    options: Options,
) Error!usize {
    const updated = try replaceAlloc(
        allocator,
        source,
        image_index,
        image,
        options,
    );
    defer allocator.free(updated);
    try output.ensureUnusedCapacity(allocator, updated.len);
    output.appendSliceAssumeCapacity(updated);
    return updated.len;
}

pub fn replaceInto(
    allocator: std.mem.Allocator,
    source: []const u8,
    image_index: u32,
    image: plan_mod.Image,
    output: []u8,
    options: Options,
) Error!usize {
    const updated = try replaceAlloc(
        allocator,
        source,
        image_index,
        image,
        options,
    );
    defer allocator.free(updated);
    if (updated.len > output.len) return error.OutputTooSmall;
    @memcpy(output[0..updated.len], updated);
    return updated.len;
}

fn metadataIndicesAlloc(
    allocator: std.mem.Allocator,
    entries: []const archive_mod.LookupEntry,
    expected_count: u32,
) Error![]usize {
    const indices = try allocator.alloc(usize, expected_count);
    errdefer allocator.free(indices);
    var count: usize = 0;
    for (entries, 0..) |entry, index| {
        if (entry.part_number != 1 or entry.reference_count == 0)
            return error.UnsupportedWimUpdateInput;
        if (!entry.resource.isMetadata()) continue;
        if (entry.hashIsZero() or entry.reference_count != 1 or
            entry.resource.isSolid() or entry.resource.isSpanned() or
            count == indices.len)
            return error.UnsupportedWimUpdateInput;
        indices[count] = index;
        count += 1;
    }
    if (count != indices.len) return error.UnsupportedWimUpdateInput;
    return indices;
}

fn preparedMetadataIndex(
    final_index: usize,
    replacement_index: usize,
    image_count: usize,
) usize {
    std.debug.assert(final_index < image_count);
    std.debug.assert(replacement_index < image_count);
    if (final_index < replacement_index) return final_index;
    if (final_index == replacement_index) return image_count - 1;
    return final_index - 1;
}

fn replacementBootIndex(
    existing: u32,
    image_index: u32,
    requested: ?bool,
) u32 {
    return if (requested) |bootable|
        if (bootable)
            image_index
        else if (existing == image_index)
            0
        else
            existing
    else
        existing;
}

fn appendEntry(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entry: archive_mod.LookupEntry,
) Error!void {
    try wire.appendLookupEntry(
        allocator,
        output,
        entry.resource,
        entry.part_number,
        entry.reference_count,
        &entry.sha1,
    );
}
