const std = @import("std");
const core = @import("../core.zig");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");
const wire = @import("writer_wire.zig");
const xml_writer = @import("writer_xml.zig");

pub const Error = core.Error || archive_mod.Error || wire.Error ||
    xml_writer.Error || std.mem.Allocator.Error || error{
    InvalidWimWriterOptions,
    UnsupportedWimUpdateInput,
};

pub const Options = struct {
    integrity: ?bool = null,
    max_lookup_entries: usize = 4 * 1024 * 1024,
    max_lookup_bytes: usize = 256 * 1024 * 1024,
    max_xml_bytes: usize = 256 * 1024 * 1024,
};

const ResourceKey = struct {
    offset: u64,
    size: u64,
};

const MarkerInfo = struct {
    decoded_size: u64,
    used: bool = false,
    removed_before: u64 = 0,
};

const CopiedResource = struct {
    new_offset: u64,
    flags: u8,
    uncompressed_size: u64,
};

const PhysicalRange = struct {
    start: usize,
    end: usize,
};

pub fn compactAlloc(
    allocator: std.mem.Allocator,
    source: []const u8,
    options: Options,
) Error![]u8 {
    const archive = try archive_mod.Archive.init(source);
    const unsupported_header_flags: u32 = 0x08 | 0x10 | 0x20 | 0x40;
    if (archive.header.pipable or archive.header.part_number != 1 or
        archive.header.total_parts != 1 or archive.header.image_count == 0 or
        archive.header.flags & unsupported_header_flags != 0)
        return error.UnsupportedWimUpdateInput;
    if (options.max_lookup_entries == 0 or options.max_lookup_bytes == 0 or
        options.max_xml_bytes == 0)
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
    try validateSingleSolidRun(resolved_lookup.entries);
    const xml = try archive.readXmlAllocLimited(allocator, options.max_xml_bytes);
    defer allocator.free(xml);

    var markers: std.ArrayList(MarkerInfo) = .empty;
    defer markers.deinit(allocator);
    var marker_indices: std.AutoHashMapUnmanaged(ResourceKey, usize) = .empty;
    defer marker_indices.deinit(allocator);
    try collectMarkers(
        allocator,
        resolved_lookup.entries,
        &markers,
        &marker_indices,
    );
    try markUsedResources(resolved_lookup.entries, &markers, marker_indices);
    var removed_size: u64 = 0;
    for (markers.items) |*marker| {
        marker.removed_before = removed_size;
        if (!marker.used)
            removed_size = std.math.add(
                u64,
                removed_size,
                marker.decoded_size,
            ) catch return error.IntegerOverflow;
    }

    try validatePhysicalRanges(
        allocator,
        source.len,
        archive.header,
        resolved_lookup.entries,
        markers.items,
        marker_indices,
    );

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendNTimes(allocator, 0, format.header_size);
    var copied: std.AutoHashMapUnmanaged(ResourceKey, CopiedResource) = .empty;
    defer copied.deinit(allocator);
    var rewritten: std.ArrayList(archive_mod.LookupEntry) = .empty;
    defer rewritten.deinit(allocator);
    for (raw_lookup.entries, resolved_lookup.entries) |raw, resolved| {
        if (raw.part_number != 1 or raw.reference_count == 0)
            return error.UnsupportedWimUpdateInput;
        if (raw.resource.isSpanned()) return error.UnsupportedWimUpdateInput;
        var entry = raw;
        switch (resolved.kind) {
            .standalone => entry.resource = try copyPhysicalResource(
                allocator,
                &output,
                source,
                raw.resource,
                &copied,
            ),
            .solid_resource => {
                const marker_index = marker_indices.get(resourceKey(
                    resolved.solid_resource.?.header,
                )) orelse return error.InvalidWim;
                if (!markers.items[marker_index].used) continue;
                entry.resource = try copyPhysicalResource(
                    allocator,
                    &output,
                    source,
                    raw.resource,
                    &copied,
                );
            },
            .solid_blob => {
                const marker_index = marker_indices.get(resourceKey(
                    resolved.solid_resource.?.header,
                )) orelse return error.InvalidWim;
                entry.resource.offset_in_wim = std.math.sub(
                    u64,
                    entry.resource.offset_in_wim,
                    markers.items[marker_index].removed_before,
                ) catch return error.InvalidWim;
            },
        }
        try rewritten.append(allocator, entry);
    }

    const lookup_offset = output.items.len;
    var metadata_count: u32 = 0;
    var boot_metadata = wire.zeroResource();
    for (rewritten.items) |entry| {
        if (entry.resource.isMetadata()) {
            if (entry.hashIsZero() or entry.reference_count != 1 or
                entry.resource.isSolid() or entry.resource.isSpanned())
                return error.UnsupportedWimUpdateInput;
            metadata_count = std.math.add(u32, metadata_count, 1) catch
                return error.IntegerOverflow;
            if (metadata_count == archive.header.boot_index)
                boot_metadata = entry.resource;
        }
        try appendEntry(allocator, &output, entry);
    }
    if (metadata_count != archive.header.image_count)
        return error.UnsupportedWimUpdateInput;
    if (archive.header.boot_index == 0)
        boot_metadata = wire.zeroResource()
    else if (boot_metadata.isZero())
        return error.UnsupportedWimUpdateInput;
    const lookup_resource = try wire.resourceHeader(
        lookup_offset,
        output.items.len - lookup_offset,
        output.items.len - lookup_offset,
        0x02,
    );
    const lookup_end = output.items.len;

    const xml_offset = output.items.len;
    const updated_xml = try xml_writer.updateTotalBytesAlloc(
        allocator,
        xml,
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
        !archive.header.integrity_table.isZero();
    const integrity_resource = if (use_integrity)
        try wire.appendIntegrity(allocator, &output, lookup_end)
    else
        wire.zeroResource();
    wire.writeHeaderWithFlags(
        output.items[0..format.header_size],
        archive.header.version,
        archive.header.flags,
        archive.header.chunk_size,
        &archive.header.guid,
        archive.header.image_count,
        lookup_resource,
        xml_resource,
        boot_metadata,
        archive.header.boot_index,
        integrity_resource,
    );
    return output.toOwnedSlice(allocator);
}

pub fn compactAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    source: []const u8,
    options: Options,
) Error!usize {
    const compacted = try compactAlloc(allocator, source, options);
    defer allocator.free(compacted);
    try output.ensureUnusedCapacity(allocator, compacted.len);
    output.appendSliceAssumeCapacity(compacted);
    return compacted.len;
}

pub fn compactInto(
    allocator: std.mem.Allocator,
    source: []const u8,
    output: []u8,
    options: Options,
) Error!usize {
    const compacted = try compactAlloc(allocator, source, options);
    defer allocator.free(compacted);
    if (compacted.len > output.len) return error.OutputTooSmall;
    @memcpy(output[0..compacted.len], compacted);
    return compacted.len;
}

fn collectMarkers(
    allocator: std.mem.Allocator,
    entries: []const archive_mod.LookupEntry,
    markers: *std.ArrayList(MarkerInfo),
    marker_indices: *std.AutoHashMapUnmanaged(ResourceKey, usize),
) Error!void {
    for (entries) |entry| {
        if (entry.kind != .solid_resource) continue;
        const resource = entry.solid_resource.?;
        const key = resourceKey(resource.header);
        const result = try marker_indices.getOrPut(allocator, key);
        if (result.found_existing) return error.InvalidWim;
        result.value_ptr.* = markers.items.len;
        try markers.append(allocator, .{
            .decoded_size = resource.uncompressed_size,
        });
    }
}

fn validateSingleSolidRun(entries: []const archive_mod.LookupEntry) Error!void {
    var solid_started = false;
    var solid_ended = false;
    for (entries) |entry| {
        if (entry.kind == .solid_resource or entry.kind == .solid_blob) {
            if (solid_ended) return error.UnsupportedWimUpdateInput;
            solid_started = true;
        } else if (solid_started) {
            solid_ended = true;
        }
    }
}

fn markUsedResources(
    entries: []const archive_mod.LookupEntry,
    markers: *std.ArrayList(MarkerInfo),
    marker_indices: std.AutoHashMapUnmanaged(ResourceKey, usize),
) Error!void {
    for (entries) |entry| {
        if (entry.kind != .solid_blob) continue;
        const marker_index = marker_indices.get(resourceKey(
            entry.solid_resource.?.header,
        )) orelse return error.InvalidWim;
        markers.items[marker_index].used = true;
    }
}

fn validatePhysicalRanges(
    allocator: std.mem.Allocator,
    source_len: usize,
    header: format.Header,
    entries: []const archive_mod.LookupEntry,
    markers: []const MarkerInfo,
    marker_indices: std.AutoHashMapUnmanaged(ResourceKey, usize),
) Error!void {
    var ranges: std.ArrayList(PhysicalRange) = .empty;
    defer ranges.deinit(allocator);
    for (entries) |entry| {
        switch (entry.kind) {
            .standalone => {},
            .solid_resource => {
                const marker_index = marker_indices.get(resourceKey(
                    entry.solid_resource.?.header,
                )) orelse return error.InvalidWim;
                if (!markers[marker_index].used) continue;
            },
            .solid_blob => continue,
        }
        const range = try physicalRange(entry.resource, source_len);
        if (resourceOverlaps(range, header.lookup_table) or
            resourceOverlaps(range, header.xml_data) or
            resourceOverlaps(range, header.integrity_table))
            return error.InvalidWim;
        try ranges.append(allocator, range);
    }
    std.mem.sort(PhysicalRange, ranges.items, {}, rangeLessThan);
    if (ranges.items.len > 1)
        for (ranges.items[1..], ranges.items[0 .. ranges.items.len - 1]) |range, prior| {
            if (range.start < prior.end and
                (range.start != prior.start or range.end != prior.end))
                return error.InvalidWim;
        };
}

fn copyPhysicalResource(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    source: []const u8,
    resource: format.ResourceHeader,
    copied: *std.AutoHashMapUnmanaged(ResourceKey, CopiedResource),
) Error!format.ResourceHeader {
    const key = resourceKey(resource);
    if (copied.get(key)) |existing| {
        if (existing.flags != resource.flags or
            existing.uncompressed_size != resource.uncompressed_size)
            return error.InvalidWim;
        var rewritten = resource;
        rewritten.offset_in_wim = existing.new_offset;
        return rewritten;
    }
    const range = try physicalRange(resource, source.len);
    const new_offset: u64 = output.items.len;
    try output.appendSlice(allocator, source[range.start..range.end]);
    try copied.put(allocator, key, .{
        .new_offset = new_offset,
        .flags = resource.flags,
        .uncompressed_size = resource.uncompressed_size,
    });
    var rewritten = resource;
    rewritten.offset_in_wim = new_offset;
    return rewritten;
}

fn physicalRange(
    resource: format.ResourceHeader,
    source_len: usize,
) Error!PhysicalRange {
    if (resource.size_in_wim == 0) return error.InvalidWim;
    const start = std.math.cast(usize, resource.offset_in_wim) orelse
        return error.IntegerOverflow;
    const size = std.math.cast(usize, resource.size_in_wim) orelse
        return error.IntegerOverflow;
    const end = std.math.add(usize, start, size) catch
        return error.IntegerOverflow;
    if (start < format.header_size or end > source_len) return error.InvalidWim;
    return .{ .start = start, .end = end };
}

fn resourceOverlaps(
    range: PhysicalRange,
    resource: format.ResourceHeader,
) bool {
    if (resource.isZero()) return false;
    const start = std.math.cast(usize, resource.offset_in_wim) orelse return true;
    const size = std.math.cast(usize, resource.size_in_wim) orelse return true;
    const end = std.math.add(usize, start, size) catch return true;
    return range.start < end and start < range.end;
}

fn resourceKey(resource: format.ResourceHeader) ResourceKey {
    return .{
        .offset = resource.offset_in_wim,
        .size = resource.size_in_wim,
    };
}

fn rangeLessThan(_: void, left: PhysicalRange, right: PhysicalRange) bool {
    if (left.start != right.start) return left.start < right.start;
    return left.end < right.end;
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
