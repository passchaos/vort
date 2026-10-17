const std = @import("std");
const core = @import("../core.zig");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");
const plan_mod = @import("writer_plan.zig");
const resource_writer = @import("writer_resource.zig");
const solid_resource = @import("writer_solid_resource.zig");
const wire = @import("writer_wire.zig");
const xml_writer = @import("writer_xml.zig");

pub const Error = core.Error || archive_mod.Error || plan_mod.Error ||
    resource_writer.Error || solid_resource.Error || wire.Error || xml_writer.Error ||
    std.mem.Allocator.Error || error{
    InvalidWimWriterOptions,
    InvalidWimEntry,
    UnsupportedWimUpdateInput,
};

pub const Options = struct {
    integrity: ?bool = null,
    bootable: bool = false,
    solid_chunk_size: ?usize = null,
    max_lookup_entries: usize = 4 * 1024 * 1024,
    max_lookup_bytes: usize = 256 * 1024 * 1024,
    max_xml_bytes: usize = 256 * 1024 * 1024,
    max_solid_chunk_bytes: usize = 256 * 1024 * 1024,
};

pub fn appendAlloc(
    allocator: std.mem.Allocator,
    source: []const u8,
    image: plan_mod.Image,
    options: Options,
) Error![]u8 {
    const archive = try archive_mod.Archive.init(source);
    const unsupported_header_flags: u32 = 0x08 | 0x10 | 0x20 | 0x40;
    if (archive.header.pipable or archive.header.part_number != 1 or
        archive.header.total_parts != 1 or archive.header.image_count == 0 or
        archive.header.image_count >= 65_535 or
        archive.header.flags & unsupported_header_flags != 0)
        return error.UnsupportedWimUpdateInput;
    if (options.max_lookup_entries == 0 or options.max_lookup_bytes == 0 or
        options.max_xml_bytes == 0 or options.max_solid_chunk_bytes == 0)
        return error.InvalidWimWriterOptions;
    if (options.solid_chunk_size) |chunk_size|
        format.validateChunkSize(.lzms, chunk_size) catch
            return error.InvalidWimWriterOptions;

    var raw_lookup = try archive.readLookupTableRawAlloc(
        allocator,
        options.max_lookup_entries,
        options.max_lookup_bytes,
    );
    defer raw_lookup.deinit();
    var resolved_lookup = try archive.readLookupTableAlloc(
        allocator,
        options.max_lookup_entries,
        options.max_lookup_bytes,
    );
    defer resolved_lookup.deinit();
    if (raw_lookup.entries.len != resolved_lookup.entries.len)
        return error.InvalidWim;
    try validateExistingLookup(archive.header, raw_lookup.entries);

    var plan = try plan_mod.Plan.init(allocator, &.{image});
    defer plan.deinit();
    var unique: std.ArrayList(plan_mod.Blob) = .empty;
    defer unique.deinit(allocator);
    for (plan.blobs.items) |blob| {
        const reused_index = try findReusableBlob(
            allocator,
            archive,
            resolved_lookup.entries,
            blob,
            options.max_solid_chunk_bytes,
        );
        if (reused_index) |index| {
            raw_lookup.entries[index].reference_count = std.math.add(
                u32,
                raw_lookup.entries[index].reference_count,
                blob.reference_count,
            ) catch return error.IntegerOverflow;
        } else {
            try unique.append(allocator, blob);
        }
    }

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendSlice(allocator, source);
    const compression = try writerCompression(archive.header.compression);
    var new_marker: ?format.ResourceHeader = null;
    var solid_base: u64 = 0;
    if (archive.header.version == format.solid_version) {
        solid_base = try existingSolidSize(resolved_lookup.entries);
        const packed_chunk_size = options.solid_chunk_size orelse
            existingSolidChunkSize(resolved_lookup.entries) orelse
            64 * 1024 * 1024;
        new_marker = try solid_resource.append(
            allocator,
            &output,
            unique.items,
            packed_chunk_size,
        );
        for (unique.items) |*blob|
            blob.resource.offset_in_wim = std.math.add(
                u64,
                blob.resource.offset_in_wim,
                solid_base,
            ) catch return error.IntegerOverflow;
    } else if (archive.header.version == format.default_version) {
        for (unique.items) |*blob|
            blob.resource = try resource_writer.append(
                allocator,
                &output,
                blob.data,
                compression,
                archive.header.chunk_size,
                0,
            );
    } else {
        return error.UnsupportedWimUpdateInput;
    }

    const planned = &plan.images.items[0];
    planned.metadata_resource = try resource_writer.append(
        allocator,
        &output,
        planned.metadata,
        compression,
        archive.header.chunk_size,
        0x02,
    );

    const lookup_offset = output.items.len;
    try appendUpdatedLookup(
        allocator,
        &output,
        raw_lookup.entries,
        planned,
        unique.items,
        new_marker,
        archive.header.version == format.solid_version,
    );
    const lookup_resource = try wire.resourceHeader(
        lookup_offset,
        output.items.len - lookup_offset,
        output.items.len - lookup_offset,
        0x02,
    );
    const lookup_end = output.items.len;

    const existing_xml = try archive.readXmlAllocLimited(
        allocator,
        options.max_xml_bytes,
    );
    defer allocator.free(existing_xml);
    const xml_offset = output.items.len;
    const updated_xml = try xml_writer.appendImageAlloc(
        allocator,
        existing_xml,
        archive.header.image_count,
        .{
            .name = image.name,
            .directory_count = planned.tree.directoryCount(),
            .file_count = planned.tree.fileCount(),
            .total_bytes = try planned.tree.totalStreamBytes(),
            .hard_link_bytes = try planned.tree.hardLinkBytes(),
            .creation_time = image.creation_time,
            .last_modification_time = image.last_modification_time,
        },
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
    const use_integrity = options.integrity orelse !archive.header.integrity_table.isZero();
    const integrity_resource = if (use_integrity)
        try wire.appendIntegrity(allocator, &output, lookup_end)
    else
        wire.zeroResource();
    const new_image_index = archive.header.image_count + 1;
    const boot_metadata = if (options.bootable)
        planned.metadata_resource
    else
        archive.header.boot_metadata;
    const boot_index = if (options.bootable)
        new_image_index
    else
        archive.header.boot_index;
    wire.writeHeaderWithFlags(
        output.items[0..format.header_size],
        archive.header.version,
        archive.header.flags,
        archive.header.chunk_size,
        &archive.header.guid,
        new_image_index,
        lookup_resource,
        xml_resource,
        boot_metadata,
        boot_index,
        integrity_resource,
    );
    return output.toOwnedSlice(allocator);
}

pub fn appendAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    source: []const u8,
    image: plan_mod.Image,
    options: Options,
) Error!usize {
    const updated = try appendAlloc(allocator, source, image, options);
    defer allocator.free(updated);
    try output.ensureUnusedCapacity(allocator, updated.len);
    output.appendSliceAssumeCapacity(updated);
    return updated.len;
}

pub fn appendInto(
    allocator: std.mem.Allocator,
    source: []const u8,
    image: plan_mod.Image,
    output: []u8,
    options: Options,
) Error!usize {
    const updated = try appendAlloc(allocator, source, image, options);
    defer allocator.free(updated);
    if (updated.len > output.len) return error.OutputTooSmall;
    @memcpy(output[0..updated.len], updated);
    return updated.len;
}

fn validateExistingLookup(
    header: format.Header,
    entries: []const archive_mod.LookupEntry,
) Error!void {
    var metadata_count: u32 = 0;
    var solid_started = false;
    var solid_ended = false;
    for (entries) |entry| {
        if (entry.part_number != 1 or entry.reference_count == 0)
            return error.UnsupportedWimUpdateInput;
        if (entry.resource.isMetadata()) {
            if (entry.hashIsZero() or entry.reference_count != 1 or
                entry.resource.isSolid() or entry.resource.isSpanned())
                return error.UnsupportedWimUpdateInput;
            metadata_count += 1;
            continue;
        }
        if (entry.resource.isSolid()) {
            if (solid_ended) return error.UnsupportedWimUpdateInput;
            solid_started = true;
        } else if (solid_started) {
            solid_ended = true;
        }
    }
    if (metadata_count != header.image_count)
        return error.UnsupportedWimUpdateInput;
}

fn findReusableBlob(
    allocator: std.mem.Allocator,
    archive: archive_mod.Archive,
    entries: []const archive_mod.LookupEntry,
    blob: plan_mod.Blob,
    max_solid_chunk_bytes: usize,
) Error!?usize {
    var selected: ?usize = null;
    for (entries, 0..) |entry, index| {
        if (entry.resource.isMetadata() or entry.hashIsZero() or
            !std.mem.eql(u8, &entry.sha1, &blob.sha1))
            continue;
        if (selected != null) return error.UnsupportedWimUpdateInput;
        const existing_size = switch (entry.kind) {
            .standalone => entry.resource.uncompressed_size,
            .solid_blob => entry.resource.size_in_wim,
            .solid_resource => return error.UnsupportedWimUpdateInput,
        };
        if (existing_size != blob.data.len) return error.InvalidWimEntry;
        const existing = try archive.extractEntryAllocLimitedWithSolidLimit(
            allocator,
            entry,
            blob.data.len,
            max_solid_chunk_bytes,
        );
        defer allocator.free(existing);
        if (!std.mem.eql(u8, existing, blob.data)) return error.InvalidWimEntry;
        selected = index;
    }
    return selected;
}

fn writerCompression(compression: format.Compression) Error!resource_writer.Compression {
    return switch (compression) {
        .none => .stored,
        .xpress => .xpress,
        .lzx => .lzx,
        .lzms => .lzms,
    };
}

fn existingSolidSize(entries: []const archive_mod.LookupEntry) Error!u64 {
    var total: u64 = 0;
    for (entries) |entry| {
        if (entry.kind == .solid_resource) {
            total = std.math.add(u64, total, entry.solid_resource.?.uncompressed_size) catch
                return error.IntegerOverflow;
        }
    }
    return total;
}

fn existingSolidChunkSize(entries: []const archive_mod.LookupEntry) ?usize {
    for (entries) |entry|
        if (entry.kind == .solid_resource and entry.solid_resource.?.compression == .lzms)
            return entry.solid_resource.?.chunk_size;
    return null;
}

fn appendUpdatedLookup(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    existing: []const archive_mod.LookupEntry,
    planned: *const plan_mod.PlannedImage,
    unique: []const plan_mod.Blob,
    new_marker: ?format.ResourceHeader,
    solid_archive: bool,
) Error!void {
    for (existing) |entry|
        if (entry.resource.isMetadata())
            try appendEntry(allocator, output, entry);
    try wire.appendLookupEntry(
        allocator,
        output,
        planned.metadata_resource,
        1,
        1,
        &planned.metadata_hash,
    );
    for (existing) |entry|
        if (!entry.resource.isMetadata() and !entry.resource.isSolid())
            try appendEntry(allocator, output, entry);
    if (!solid_archive) {
        for (unique) |blob|
            try wire.appendLookupEntry(
                allocator,
                output,
                blob.resource,
                1,
                blob.reference_count,
                &blob.sha1,
            );
    }
    for (existing) |entry|
        if (entry.resource.isSolid())
            try appendEntry(allocator, output, entry);
    if (solid_archive) {
        if (new_marker) |marker| {
            const zero_hash: [20]u8 = @splat(0);
            try wire.appendLookupEntry(allocator, output, marker, 1, 1, &zero_hash);
        }
        for (unique) |blob|
            try wire.appendLookupEntry(
                allocator,
                output,
                blob.resource,
                1,
                blob.reference_count,
                &blob.sha1,
            );
    }
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
