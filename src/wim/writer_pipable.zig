const std = @import("std");
const archive_mod = @import("archive.zig");
const core = @import("../core.zig");
const format = @import("format.zig");
const pipable = @import("pipable.zig");
const pipable_xml = @import("writer_pipable_xml.zig");

pub const Error = core.Error || archive_mod.Error || format.Error ||
    std.mem.Allocator.Error || error{
    UnsupportedPipableWimInput,
    InvalidPipableWimResource,
};

pub const Options = struct {
    /// Integrity is disabled by default so the output remains consumable by a
    /// strictly sequential reader through the trailing header.
    integrity: bool = false,
};

const PlannedEntry = struct {
    entry: archive_mod.LookupEntry,
    output_resource: format.ResourceHeader = undefined,
};

const integrity_chunk_size: usize = 10 * 1024 * 1024;

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: Options,
) Error![]u8 {
    const archive = try archive_mod.Archive.init(input);
    if (archive.header.pipable or archive.header.total_parts != 1 or
        archive.header.part_number != 1 or archive.header.image_count == 0)
        return error.UnsupportedPipableWimInput;
    var lookup = try archive.readLookupTableRawAlloc(
        allocator,
        input.len / format.lookup_entry_size,
        input.len,
    );
    defer lookup.deinit();
    const xml = try archive.readXmlAllocLimited(allocator, input.len);
    defer allocator.free(xml);
    if (xml.len == 0) return error.UnsupportedPipableWimInput;
    const leading_xml = try pipable_xml.leadingAlloc(allocator, xml);
    defer allocator.free(leading_xml);

    const plans = try allocator.alloc(PlannedEntry, lookup.entries.len);
    defer allocator.free(plans);
    var metadata_count: u32 = 0;
    for (lookup.entries, plans) |entry, *plan| {
        try validateEntry(input, archive.header, entry);
        if (entry.resource.isMetadata()) {
            metadata_count = std.math.add(u32, metadata_count, 1) catch
                return error.IntegerOverflow;
            if (entry.reference_count != 1)
                return error.UnsupportedPipableWimInput;
        }
        plan.* = .{ .entry = entry };
    }
    if (metadata_count != archive.header.image_count)
        return error.UnsupportedPipableWimInput;

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendNTimes(allocator, 0, format.header_size);

    _ = try appendRawBlob(allocator, &output, leading_xml, 0x02);
    for (plans) |*plan| {
        if (!plan.entry.resource.isMetadata()) continue;
        plan.output_resource = try appendConvertedBlob(
            allocator,
            &output,
            input,
            archive.header,
            plan.entry.resource,
            &plan.entry.sha1,
        );
    }
    for (plans) |*plan| {
        if (plan.entry.resource.isMetadata()) continue;
        plan.output_resource = try appendConvertedBlob(
            allocator,
            &output,
            input,
            archive.header,
            plan.entry.resource,
            &plan.entry.sha1,
        );
    }

    var lookup_bytes: std.ArrayList(u8) = .empty;
    defer lookup_bytes.deinit(allocator);
    for (plans) |plan| {
        if (!plan.entry.resource.isMetadata()) continue;
        try appendLookupEntry(allocator, &lookup_bytes, plan);
    }
    for (plans) |plan| {
        if (plan.entry.resource.isMetadata()) continue;
        try appendLookupEntry(allocator, &lookup_bytes, plan);
    }
    const lookup_resource = try appendRawBlob(
        allocator,
        &output,
        lookup_bytes.items,
        0x02,
    );
    const lookup_end = output.items.len;
    const final_xml = try pipable_xml.finalAlloc(allocator, xml, output.items.len);
    defer allocator.free(final_xml);
    const xml_resource = try appendRawBlob(allocator, &output, final_xml, 0x02);
    const integrity_resource = if (options.integrity)
        try appendIntegrity(allocator, &output, lookup_end)
    else
        zeroResource();

    var boot_metadata = zeroResource();
    if (archive.header.boot_index != 0) {
        var image_index: u32 = 0;
        for (plans) |plan| {
            if (!plan.entry.resource.isMetadata()) continue;
            image_index += 1;
            if (image_index == archive.header.boot_index) {
                boot_metadata = plan.output_resource;
                break;
            }
        }
    }
    const trailing_header_offset = output.items.len;
    try output.appendNTimes(allocator, 0, format.header_size);
    writeHeader(
        output.items[0..format.header_size],
        archive.header,
        false,
        zeroResource(),
        zeroResource(),
        zeroResource(),
        zeroResource(),
    );
    writeHeader(
        output.items[trailing_header_offset..][0..format.header_size],
        archive.header,
        true,
        lookup_resource,
        xml_resource,
        boot_metadata,
        integrity_resource,
    );
    return output.toOwnedSlice(allocator);
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    options: Options,
) Error!usize {
    const encoded = try encodeAlloc(allocator, input, options);
    defer allocator.free(encoded);
    try output.ensureUnusedCapacity(allocator, encoded.len);
    output.appendSliceAssumeCapacity(encoded);
    return encoded.len;
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
    options: Options,
) Error!usize {
    const encoded = try encodeAlloc(allocator, input, options);
    defer allocator.free(encoded);
    if (encoded.len > output.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

fn validateEntry(
    input: []const u8,
    header: format.Header,
    entry: archive_mod.LookupEntry,
) Error!void {
    if (entry.part_number != 1 or entry.reference_count == 0 or
        entry.resource.isSolid() or entry.resource.isSpanned())
        return error.UnsupportedPipableWimInput;
    if (entry.resource.isCompressed() and header.compression == .none)
        return error.UnsupportedPipableWimInput;
    const offset = std.math.cast(usize, entry.resource.offset_in_wim) orelse
        return error.IntegerOverflow;
    const size = std.math.cast(usize, entry.resource.size_in_wim) orelse
        return error.IntegerOverflow;
    const end = std.math.add(usize, offset, size) catch return error.IntegerOverflow;
    if (offset < format.header_size or end > input.len)
        return error.UnsupportedPipableWimInput;
}

fn appendConvertedBlob(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    header: format.Header,
    resource: format.ResourceHeader,
    sha1: *const [20]u8,
) Error!format.ResourceHeader {
    try appendBlobHeader(
        allocator,
        output,
        resource.uncompressed_size,
        sha1,
        resource.flags,
    );
    const output_offset = output.items.len;
    const source_offset: usize = @intCast(resource.offset_in_wim);
    const source_size: usize = @intCast(resource.size_in_wim);
    const source = input[source_offset..][0..source_size];
    if (!resource.isCompressed()) {
        if (resource.size_in_wim != resource.uncompressed_size)
            return error.InvalidPipableWimResource;
        try output.appendSlice(allocator, source);
    } else {
        try appendCompressedPayload(
            allocator,
            output,
            source,
            resource.uncompressed_size,
            header.chunk_size,
        );
    }
    const uncompressed_size = std.math.cast(
        usize,
        resource.uncompressed_size,
    ) orelse return error.IntegerOverflow;
    return resourceHeader(
        output_offset,
        output.items.len - output_offset,
        uncompressed_size,
        resource.flags,
    );
}

fn appendCompressedPayload(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    source: []const u8,
    raw_output_len: u64,
    chunk_size: usize,
) Error!void {
    const output_len = std.math.cast(usize, raw_output_len) orelse
        return error.IntegerOverflow;
    if (output_len == 0 or chunk_size == 0)
        return error.InvalidPipableWimResource;
    const chunk_count = 1 + (output_len - 1) / chunk_size;
    const entry_size: usize = if (raw_output_len <= std.math.maxInt(u32)) 4 else 8;
    const table_size = std.math.mul(usize, chunk_count - 1, entry_size) catch
        return error.IntegerOverflow;
    if (table_size > source.len) return error.InvalidPipableWimResource;
    const table = source[0..table_size];
    const chunk_data = source[table_size..];
    var previous: usize = 0;
    for (0..chunk_count) |index| {
        const next = if (index + 1 == chunk_count)
            chunk_data.len
        else blk: {
            const table_offset = index * entry_size;
            const raw = if (entry_size == 4)
                @as(u64, format.readU32(table, table_offset))
            else
                format.readU64(table, table_offset);
            break :blk std.math.cast(usize, raw) orelse
                return error.IntegerOverflow;
        };
        const decoded_len = @min(chunk_size, output_len - index * chunk_size);
        if (next <= previous or next > chunk_data.len or
            next - previous > decoded_len)
            return error.InvalidPipableWimResource;
        writeU32Append(allocator, output, @intCast(next - previous)) catch |err|
            return err;
        try output.appendSlice(allocator, chunk_data[previous..next]);
        previous = next;
    }
    try output.appendSlice(allocator, table);
}

fn appendRawBlob(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    data: []const u8,
    flags: u8,
) Error!format.ResourceHeader {
    if (data.len == 0) return error.InvalidPipableWimResource;
    var sha1: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash(data, &sha1, .{});
    try appendBlobHeader(allocator, output, data.len, &sha1, flags);
    const offset = output.items.len;
    try output.appendSlice(allocator, data);
    return resourceHeader(offset, data.len, data.len, flags);
}

fn appendBlobHeader(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    uncompressed_size: u64,
    sha1: *const [20]u8,
    flags: u8,
) Error!void {
    const offset = output.items.len;
    try output.appendNTimes(allocator, 0, pipable.blob_header_size);
    writeU64(output.items, offset, pipable.blob_magic);
    writeU64(output.items, offset + 8, uncompressed_size);
    @memcpy(output.items[offset + 16 .. offset + 36], sha1);
    writeU32(output.items, offset + 36, flags);
}

fn appendLookupEntry(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    plan: PlannedEntry,
) Error!void {
    const offset = output.items.len;
    try output.appendNTimes(allocator, 0, format.lookup_entry_size);
    writeResourceHeader(output.items, offset, plan.output_resource);
    writeU16(output.items, offset + 24, 1);
    writeU32(output.items, offset + 26, plan.entry.reference_count);
    @memcpy(output.items[offset + 30 .. offset + 50], &plan.entry.sha1);
}

fn appendIntegrity(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    lookup_end: usize,
) Error!format.ResourceHeader {
    const checked_len = lookup_end - format.header_size;
    const count = if (checked_len == 0)
        0
    else
        1 + (checked_len - 1) / integrity_chunk_size;
    const table_len = std.math.add(
        usize,
        12,
        std.math.mul(usize, count, 20) catch return error.IntegerOverflow,
    ) catch return error.IntegerOverflow;
    const offset = output.items.len;
    try output.appendNTimes(allocator, 0, table_len);
    writeU32(output.items, offset, @intCast(table_len));
    writeU32(output.items, offset + 4, @intCast(count));
    writeU32(output.items, offset + 8, integrity_chunk_size);
    for (0..count) |index| {
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

fn writeHeader(
    output: []u8,
    source: format.Header,
    full: bool,
    lookup: format.ResourceHeader,
    xml: format.ResourceHeader,
    boot_metadata: format.ResourceHeader,
    integrity: format.ResourceHeader,
) void {
    @memset(output, 0);
    @memcpy(output[0..8], &format.pipable_magic);
    writeU32(output, 8, format.header_size);
    writeU32(output, 12, source.version);
    writeU32(output, 16, source.flags & ~@as(u32, 0x0000_0048));
    writeU32(output, 20, @intCast(source.chunk_size));
    @memcpy(output[24..40], &source.guid);
    writeU16(output, 40, 1);
    writeU16(output, 42, 1);
    writeU32(output, 44, source.image_count);
    if (full) {
        writeResourceHeader(output, 48, lookup);
        writeResourceHeader(output, 72, xml);
        writeResourceHeader(output, 96, boot_metadata);
        writeResourceHeader(output, 124, integrity);
    }
    writeU32(output, 120, source.boot_index);
}

fn resourceHeader(
    offset: usize,
    stored_size: usize,
    uncompressed_size: usize,
    flags: u8,
) Error!format.ResourceHeader {
    if (stored_size >= @as(u64, 1) << 56) return error.IntegerOverflow;
    return .{
        .size_in_wim = stored_size,
        .flags = flags,
        .offset_in_wim = offset,
        .uncompressed_size = uncompressed_size,
    };
}

fn zeroResource() format.ResourceHeader {
    return .{ .size_in_wim = 0, .flags = 0, .offset_in_wim = 0, .uncompressed_size = 0 };
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

fn writeU32Append(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: u32,
) Error!void {
    const offset = output.items.len;
    try output.appendNTimes(allocator, 0, 4);
    writeU32(output.items, offset, value);
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
