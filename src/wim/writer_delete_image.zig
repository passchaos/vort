const std = @import("std");
const core = @import("../core.zig");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");
const metadata_mod = @import("metadata.zig");
const wire = @import("writer_wire.zig");
const xml_writer = @import("writer_xml.zig");

pub const Error = core.Error || archive_mod.Error || metadata_mod.Error ||
    wire.Error || xml_writer.Error || std.mem.Allocator.Error || error{
    InvalidWimWriterOptions,
    UnsupportedWimUpdateInput,
};

pub const Options = struct {
    integrity: ?bool = null,
    max_lookup_entries: usize = 4 * 1024 * 1024,
    max_lookup_bytes: usize = 256 * 1024 * 1024,
    max_xml_bytes: usize = 256 * 1024 * 1024,
    max_metadata_bytes: usize = 256 * 1024 * 1024,
    max_directory_entries: usize = 1024 * 1024,
    max_path_depth: usize = 256,
};

const HashCounts = std.AutoHashMapUnmanaged([20]u8, u32);

pub fn deleteAlloc(
    allocator: std.mem.Allocator,
    source: []const u8,
    image_index: u32,
    options: Options,
) Error![]u8 {
    const archive = try archive_mod.Archive.init(source);
    const unsupported_header_flags: u32 = 0x08 | 0x10 | 0x20 | 0x40;
    if (archive.header.pipable or archive.header.part_number != 1 or
        archive.header.total_parts != 1 or archive.header.image_count <= 1 or
        image_index == 0 or image_index > archive.header.image_count or
        archive.header.flags & unsupported_header_flags != 0)
        return error.UnsupportedWimUpdateInput;
    if (options.max_lookup_entries == 0 or options.max_lookup_bytes == 0 or
        options.max_xml_bytes == 0 or options.max_metadata_bytes == 0 or
        options.max_directory_entries == 0 or options.max_path_depth == 0)
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
    const metadata_entry_index = try selectedMetadataIndex(
        archive.header,
        raw_lookup.entries,
        image_index,
    );
    const metadata_bytes = try archive.extractEntryAllocLimited(
        allocator,
        resolved_lookup.entries[metadata_entry_index],
        options.max_metadata_bytes,
    );
    var metadata = try metadata_mod.ImageMetadata.fromOwnedBytes(
        allocator,
        metadata_bytes,
    );
    defer metadata.deinit();
    var counts: HashCounts = .empty;
    defer counts.deinit(allocator);
    var visited: std.AutoHashMapUnmanaged(usize, void) = .empty;
    defer visited.deinit(allocator);
    try collectDentryReferences(
        allocator,
        metadata,
        metadata.root,
        &counts,
        &visited,
        0,
        options,
    );

    const keep = try allocator.alloc(bool, raw_lookup.entries.len);
    defer allocator.free(keep);
    @memset(keep, true);
    keep[metadata_entry_index] = false;
    var iterator = counts.iterator();
    while (iterator.next()) |item| {
        const entry_index = try findDataEntry(raw_lookup.entries, item.key_ptr);
        const entry = &raw_lookup.entries[entry_index];
        if (entry.reference_count < item.value_ptr.*)
            return error.InvalidWim;
        entry.reference_count -= item.value_ptr.*;
        if (entry.reference_count == 0) keep[entry_index] = false;
    }

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendSlice(allocator, source);
    const lookup_offset = output.items.len;
    for (raw_lookup.entries, keep) |entry, retain|
        if (retain)
            try wire.appendLookupEntry(
                allocator,
                &output,
                entry.resource,
                entry.part_number,
                entry.reference_count,
                &entry.sha1,
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
    const updated_xml = try xml_writer.deleteImageAlloc(
        allocator,
        existing_xml,
        archive.header.image_count,
        image_index,
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
    const boot_deleted = archive.header.boot_index == image_index;
    const boot_metadata = if (boot_deleted)
        wire.zeroResource()
    else
        archive.header.boot_metadata;
    const boot_index = if (boot_deleted)
        0
    else if (archive.header.boot_index > image_index)
        archive.header.boot_index - 1
    else
        archive.header.boot_index;
    wire.writeHeaderWithFlags(
        output.items[0..format.header_size],
        archive.header.version,
        archive.header.flags,
        archive.header.chunk_size,
        &archive.header.guid,
        archive.header.image_count - 1,
        lookup_resource,
        xml_resource,
        boot_metadata,
        boot_index,
        integrity_resource,
    );
    return output.toOwnedSlice(allocator);
}

pub fn deleteAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    source: []const u8,
    image_index: u32,
    options: Options,
) Error!usize {
    const updated = try deleteAlloc(allocator, source, image_index, options);
    defer allocator.free(updated);
    try output.ensureUnusedCapacity(allocator, updated.len);
    output.appendSliceAssumeCapacity(updated);
    return updated.len;
}

pub fn deleteInto(
    allocator: std.mem.Allocator,
    source: []const u8,
    image_index: u32,
    output: []u8,
    options: Options,
) Error!usize {
    const updated = try deleteAlloc(allocator, source, image_index, options);
    defer allocator.free(updated);
    if (updated.len > output.len) return error.OutputTooSmall;
    @memcpy(output[0..updated.len], updated);
    return updated.len;
}

fn selectedMetadataIndex(
    header: format.Header,
    entries: []const archive_mod.LookupEntry,
    selected_image: u32,
) Error!usize {
    var metadata_count: u32 = 0;
    var selected: ?usize = null;
    for (entries, 0..) |entry, index| {
        if (entry.part_number != 1 or entry.reference_count == 0)
            return error.UnsupportedWimUpdateInput;
        if (!entry.resource.isMetadata()) continue;
        if (entry.hashIsZero() or entry.reference_count != 1 or
            entry.resource.isSolid() or entry.resource.isSpanned())
            return error.UnsupportedWimUpdateInput;
        metadata_count += 1;
        if (metadata_count == selected_image) selected = index;
    }
    if (metadata_count != header.image_count)
        return error.UnsupportedWimUpdateInput;
    return selected orelse error.UnsupportedWimUpdateInput;
}

fn collectDentryReferences(
    allocator: std.mem.Allocator,
    image: metadata_mod.ImageMetadata,
    dentry: metadata_mod.Dentry,
    counts: *HashCounts,
    visited: *std.AutoHashMapUnmanaged(usize, void),
    depth: usize,
    options: Options,
) Error!void {
    try addHash(allocator, counts, &dentry.main_hash);
    var streams = dentry.extraStreams();
    while (try streams.next()) |stream|
        try addHash(allocator, counts, &stream.hash);
    if (!dentry.isDirectory() or dentry.subdir_offset == 0) return;
    if (depth >= options.max_path_depth) return error.OutputLimitExceeded;
    const visited_result = try visited.getOrPut(allocator, dentry.subdir_offset);
    if (visited_result.found_existing) return error.InvalidWimMetadata;
    var directory = try image.readDirectoryAlloc(
        allocator,
        dentry,
        options.max_directory_entries,
    );
    defer directory.deinit();
    for (directory.entries) |child|
        try collectDentryReferences(
            allocator,
            image,
            child,
            counts,
            visited,
            depth + 1,
            options,
        );
}

fn addHash(
    allocator: std.mem.Allocator,
    counts: *HashCounts,
    hash: *const [20]u8,
) Error!void {
    if (std.mem.allEqual(u8, hash, 0)) return;
    const result = try counts.getOrPut(allocator, hash.*);
    if (!result.found_existing) result.value_ptr.* = 0;
    result.value_ptr.* = std.math.add(u32, result.value_ptr.*, 1) catch
        return error.IntegerOverflow;
}

fn findDataEntry(
    entries: []const archive_mod.LookupEntry,
    hash: *const [20]u8,
) Error!usize {
    var selected: ?usize = null;
    for (entries, 0..) |entry, index| {
        if (entry.resource.isMetadata() or entry.hashIsZero() or
            !std.mem.eql(u8, &entry.sha1, hash))
            continue;
        if (selected != null) return error.UnsupportedWimUpdateInput;
        selected = index;
    }
    return selected orelse error.InvalidWim;
}
