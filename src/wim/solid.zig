const std = @import("std");
const core = @import("../core.zig");
const codec = @import("codec.zig");
const format = @import("format.zig");

pub const Error = core.Error || codec.Error || format.Error || std.mem.Allocator.Error ||
    error{InvalidWim};

pub const resource_magic: u64 = 0x1_0000_0000;

pub const LookupKind = enum {
    standalone,
    solid_resource,
    solid_blob,
};

pub const Resource = struct {
    header: format.ResourceHeader,
    uncompressed_size: u64,
    chunk_size: usize,
    compression: format.Compression,
    chunk_count: usize,
    chunk_table_offset: usize,
    chunk_data_offset: usize,
};

pub const PartSource = struct {
    context: *anyopaque,
    bytes_for_part: *const fn (
        context: *anyopaque,
        part_number: u16,
    ) Error![]const u8,
};

const ResourceRecord = struct {
    resource: Resource,
    part_number: u16,
};

const Span = struct {
    resource_index: usize,
    offset: u64,
    end: u64,
};

pub fn resolveEntries(
    allocator: std.mem.Allocator,
    archive_bytes: []const u8,
    version: u32,
    entries: anytype,
) Error!void {
    const Context = struct {
        bytes: []const u8,

        fn bytesForPart(context: *anyopaque, _: u16) Error![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(context));
            return self.bytes;
        }
    };
    var context = Context{ .bytes = archive_bytes };
    return resolveEntriesFromParts(allocator, version, entries, .{
        .context = &context,
        .bytes_for_part = Context.bytesForPart,
    });
}

pub fn resolveEntriesFromParts(
    allocator: std.mem.Allocator,
    version: u32,
    entries: anytype,
    source: PartSource,
) Error!void {
    var index: usize = 0;
    while (index < entries.len) {
        if (!entries[index].resource.isSolid()) {
            index += 1;
            continue;
        }
        if (version != format.solid_version) return error.InvalidWim;
        const run_start = index;
        while (index < entries.len and entries[index].resource.isSolid())
            index += 1;
        try resolveRun(
            allocator,
            entries[run_start..index],
            source,
        );
    }
}

fn resolveRun(
    allocator: std.mem.Allocator,
    entries: anytype,
    source: PartSource,
) Error!void {
    var resources: std.ArrayList(ResourceRecord) = .empty;
    defer resources.deinit(allocator);
    for (entries) |entry| {
        if (entry.resource.uncompressed_size != resource_magic) continue;
        if (!entry.hashIsZero() or entry.reference_count == 0)
            return error.InvalidWim;
        const archive_bytes = try source.bytes_for_part(
            source.context,
            entry.part_number,
        );
        try resources.append(allocator, .{
            .resource = try parseResource(archive_bytes, entry.resource),
            .part_number = entry.part_number,
        });
    }
    if (resources.items.len == 0) return error.InvalidWim;

    var spans: std.ArrayList(Span) = .empty;
    defer spans.deinit(allocator);
    var resource_marker_index: usize = 0;
    for (entries) |*entry| {
        if (entry.resource.uncompressed_size == resource_magic) {
            entry.kind = .solid_resource;
            entry.solid_resource = resources.items[resource_marker_index].resource;
            resource_marker_index += 1;
            continue;
        }
        if (entry.resource.size_in_wim == 0 or entry.hashIsZero() or
            entry.resource.isMetadata())
            return error.InvalidWim;
        var relative_offset = entry.resource.offset_in_wim;
        var found = false;
        for (resources.items, 0..) |record, resource_index| {
            if (relative_offset < record.resource.uncompressed_size) {
                const blob_end = std.math.add(
                    u64,
                    relative_offset,
                    entry.resource.size_in_wim,
                ) catch return error.IntegerOverflow;
                if (blob_end > record.resource.uncompressed_size or
                    entry.part_number != record.part_number)
                    return error.InvalidWim;
                entry.kind = .solid_blob;
                entry.solid_resource = record.resource;
                entry.solid_offset = relative_offset;
                try spans.append(allocator, .{
                    .resource_index = resource_index,
                    .offset = relative_offset,
                    .end = blob_end,
                });
                found = true;
                break;
            }
            relative_offset -= record.resource.uncompressed_size;
        }
        if (!found) return error.InvalidWim;
    }
    if (resource_marker_index != resources.items.len) return error.InvalidWim;

    std.mem.sort(Span, spans.items, {}, spanLessThan);
    if (spans.items.len > 1) {
        for (spans.items[1..], 1..) |span, span_index| {
            const previous = spans.items[span_index - 1];
            if (span.resource_index == previous.resource_index and
                span.offset < previous.end)
                return error.InvalidWim;
        }
    }
}

fn parseResource(
    archive_bytes: []const u8,
    header: format.ResourceHeader,
) Error!Resource {
    const resource_start = std.math.cast(usize, header.offset_in_wim) orelse
        return error.IntegerOverflow;
    const stored_size = std.math.cast(usize, header.size_in_wim) orelse
        return error.IntegerOverflow;
    const resource_end = try checkedEnd(resource_start, stored_size, archive_bytes.len);
    if (stored_size < 20) return error.InvalidWim;
    const uncompressed_size = format.readU64(archive_bytes, resource_start);
    const chunk_size: usize = format.readU32(archive_bytes, resource_start + 8);
    const compression = switch (format.readU32(archive_bytes, resource_start + 12)) {
        1 => format.Compression.xpress,
        2 => format.Compression.lzx,
        3 => format.Compression.lzms,
        else => return error.UnsupportedWimCompression,
    };
    if (uncompressed_size == 0) return error.InvalidWim;
    try format.validateChunkSize(compression, chunk_size);
    const decoded_size = std.math.cast(usize, uncompressed_size) orelse
        return error.IntegerOverflow;
    const chunk_count = (std.math.add(
        usize,
        decoded_size,
        chunk_size - 1,
    ) catch return error.IntegerOverflow) / chunk_size;
    const table_size = std.math.mul(usize, chunk_count, 4) catch
        return error.IntegerOverflow;
    const chunk_table_offset = resource_start + 16;
    const chunk_data_offset = try checkedEnd(
        chunk_table_offset,
        table_size,
        resource_end,
    );
    var encoded_total: usize = 0;
    for (0..chunk_count) |chunk_index| {
        const encoded_size: usize = format.readU32(
            archive_bytes,
            chunk_table_offset + chunk_index * 4,
        );
        const decoded_chunk_size = @min(
            chunk_size,
            decoded_size - chunk_index * chunk_size,
        );
        if (encoded_size == 0 or encoded_size > decoded_chunk_size)
            return error.InvalidWim;
        encoded_total = std.math.add(usize, encoded_total, encoded_size) catch
            return error.IntegerOverflow;
    }
    const calculated_end = std.math.add(
        usize,
        chunk_data_offset,
        encoded_total,
    ) catch return error.IntegerOverflow;
    if (calculated_end != resource_end) return error.InvalidWim;
    return .{
        .header = header,
        .uncompressed_size = uncompressed_size,
        .chunk_size = chunk_size,
        .compression = compression,
        .chunk_count = chunk_count,
        .chunk_table_offset = chunk_table_offset,
        .chunk_data_offset = chunk_data_offset,
    };
}

pub fn readBlobAllocLimited(
    allocator: std.mem.Allocator,
    archive_bytes: []const u8,
    entry: anytype,
    max_output_len: usize,
    max_solid_chunk_bytes: usize,
) Error![]u8 {
    const solid = entry.solid_resource orelse return error.InvalidWim;
    const output_len = std.math.cast(usize, entry.resource.size_in_wim) orelse
        return error.IntegerOverflow;
    if (output_len > max_output_len) return error.OutputLimitExceeded;
    const blob_start = std.math.cast(usize, entry.solid_offset) orelse
        return error.IntegerOverflow;
    const resource_size = std.math.cast(usize, solid.uncompressed_size) orelse
        return error.IntegerOverflow;
    const blob_end = std.math.add(usize, blob_start, output_len) catch
        return error.IntegerOverflow;
    if (blob_end > resource_size) return error.InvalidWim;
    const scratch_len = @min(solid.chunk_size, resource_size);
    if (scratch_len > max_solid_chunk_bytes) return error.OutputLimitExceeded;
    const output = try allocator.alloc(u8, output_len);
    errdefer allocator.free(output);
    const scratch = try allocator.alloc(u8, scratch_len);
    defer allocator.free(scratch);

    var encoded_offset = solid.chunk_data_offset;
    var copied: usize = 0;
    for (0..solid.chunk_count) |chunk_index| {
        const encoded_size: usize = format.readU32(
            archive_bytes,
            solid.chunk_table_offset + chunk_index * 4,
        );
        const encoded_end = try checkedEnd(
            encoded_offset,
            encoded_size,
            archive_bytes.len,
        );
        const decoded_start = chunk_index * solid.chunk_size;
        const decoded_len = @min(solid.chunk_size, resource_size - decoded_start);
        const decoded_end = decoded_start + decoded_len;
        if (decoded_end > blob_start and decoded_start < blob_end) {
            const decoded_chunk = scratch[0..decoded_len];
            const encoded_chunk = archive_bytes[encoded_offset..encoded_end];
            if (encoded_size == decoded_len) {
                @memcpy(decoded_chunk, encoded_chunk);
            } else {
                try codec.decodeChunkInto(
                    allocator,
                    solid.compression,
                    encoded_chunk,
                    decoded_chunk,
                    solid.chunk_size,
                );
            }
            const copy_start = @max(decoded_start, blob_start);
            const copy_end = @min(decoded_end, blob_end);
            const copy_len = copy_end - copy_start;
            @memcpy(
                output[copy_start - blob_start ..][0..copy_len],
                decoded_chunk[copy_start - decoded_start ..][0..copy_len],
            );
            copied += copy_len;
        }
        encoded_offset = encoded_end;
    }
    if (copied != output_len) return error.InvalidWim;
    return output;
}

fn spanLessThan(_: void, left: Span, right: Span) bool {
    return left.resource_index < right.resource_index or
        (left.resource_index == right.resource_index and left.offset < right.offset);
}

fn checkedEnd(start: usize, length: usize, limit: usize) Error!usize {
    const end = std.math.add(usize, start, length) catch return error.IntegerOverflow;
    if (end > limit) return error.TruncatedFrame;
    return end;
}
