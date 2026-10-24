const std = @import("std");
const archive_mod = @import("archive.zig");
const core = @import("../core.zig");
const format = @import("format.zig");

pub const Error = core.Error || archive_mod.Error || format.Error ||
    std.mem.Allocator.Error || error{
    InvalidWimSplitOptions,
    UnsupportedWimSplitInput,
    TooManyWimParts,
};

pub const Options = struct {
    /// Soft payload target, matching wimlib_split(). Container overhead is not
    /// counted and an indivisible resource may exceed this size.
    max_part_size: usize,
    /// null preserves whether the source WIM has an integrity table.
    integrity: ?bool = null,
};

pub const Part = struct {
    part_number: u16,
    bytes: []u8,
};

pub const SplitArchive = struct {
    allocator: std.mem.Allocator,
    parts: []Part,

    pub fn deinit(self: *SplitArchive) void {
        for (self.parts) |part| self.allocator.free(part.bytes);
        self.allocator.free(self.parts);
        self.* = undefined;
    }
};

const PlannedEntry = struct {
    entry: archive_mod.LookupEntry,
    part_index: usize,
    output_resource: format.ResourceHeader = undefined,
};

const integrity_chunk_size: usize = 10 * 1024 * 1024;

pub fn splitAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: Options,
) Error!SplitArchive {
    if (options.max_part_size == 0) return error.InvalidWimSplitOptions;
    const archive = try archive_mod.Archive.init(input);
    if (archive.header.pipable or archive.header.total_parts != 1 or
        archive.header.part_number != 1 or archive.header.image_count == 0)
        return error.UnsupportedWimSplitInput;
    var lookup = try archive.readLookupTableRawAlloc(
        allocator,
        input.len / format.lookup_entry_size,
        input.len,
    );
    defer lookup.deinit();
    if (lookup.entries.len == 0) return error.UnsupportedWimSplitInput;
    const xml = try archive.readXmlAllocLimited(allocator, input.len);
    defer allocator.free(xml);

    const plans = try allocator.alloc(PlannedEntry, lookup.entries.len);
    defer allocator.free(plans);
    var metadata_count: u32 = 0;
    var metadata_payload_size: usize = 0;
    for (lookup.entries, plans) |entry, *plan| {
        try validateEntry(input, archive.header, entry);
        if (entry.resource.isMetadata()) {
            metadata_count = std.math.add(u32, metadata_count, 1) catch
                return error.IntegerOverflow;
            metadata_payload_size = std.math.add(
                usize,
                metadata_payload_size,
                @intCast(entry.resource.size_in_wim),
            ) catch return error.IntegerOverflow;
        }
        plan.* = .{ .entry = entry, .part_index = 0 };
    }
    if (metadata_count != archive.header.image_count)
        return error.UnsupportedWimSplitInput;

    var part_payload_sizes: std.ArrayList(usize) = .empty;
    defer part_payload_sizes.deinit(allocator);
    try part_payload_sizes.append(allocator, metadata_payload_size);
    var part_index: usize = 0;
    for (plans) |*plan| {
        if (plan.entry.resource.isMetadata()) continue;
        const resource_size: usize = @intCast(plan.entry.resource.size_in_wim);
        const with_resource = std.math.add(
            usize,
            part_payload_sizes.items[part_index],
            resource_size,
        ) catch return error.IntegerOverflow;
        if (with_resource >= options.max_part_size and
            part_payload_sizes.items[part_index] != 0)
        {
            if (part_payload_sizes.items.len == std.math.maxInt(u16))
                return error.TooManyWimParts;
            try part_payload_sizes.append(allocator, 0);
            part_index += 1;
        }
        plan.part_index = part_index;
        part_payload_sizes.items[part_index] = std.math.add(
            usize,
            part_payload_sizes.items[part_index],
            resource_size,
        ) catch return error.IntegerOverflow;
    }

    const parts = try allocator.alloc(Part, part_payload_sizes.items.len);
    errdefer allocator.free(parts);
    var initialized: usize = 0;
    errdefer for (parts[0..initialized]) |part| allocator.free(part.bytes);
    const include_integrity = options.integrity orelse
        !archive.header.integrity_table.isZero();
    for (parts, 0..) |*part, index| {
        part.* = .{
            .part_number = @intCast(index + 1),
            .bytes = try buildPart(
                allocator,
                input,
                archive.header,
                xml,
                plans,
                index,
                parts.len,
                include_integrity,
            ),
        };
        initialized += 1;
    }
    return .{ .allocator = allocator, .parts = parts };
}

fn validateEntry(
    input: []const u8,
    header: format.Header,
    entry: archive_mod.LookupEntry,
) Error!void {
    if (entry.part_number != 1 or entry.reference_count == 0 or
        entry.resource.isSolid() or entry.resource.isSpanned())
        return error.UnsupportedWimSplitInput;
    if (entry.resource.isMetadata() and entry.reference_count != 1)
        return error.UnsupportedWimSplitInput;
    const offset = std.math.cast(usize, entry.resource.offset_in_wim) orelse
        return error.IntegerOverflow;
    const size = std.math.cast(usize, entry.resource.size_in_wim) orelse
        return error.IntegerOverflow;
    const end = std.math.add(usize, offset, size) catch
        return error.IntegerOverflow;
    if (offset < format.header_size or end > input.len)
        return error.UnsupportedWimSplitInput;
    if (entry.resource.isCompressed() and header.compression == .none)
        return error.UnsupportedWimSplitInput;
}

fn buildPart(
    allocator: std.mem.Allocator,
    input: []const u8,
    source_header: format.Header,
    xml: []const u8,
    plans: []PlannedEntry,
    selected_part: usize,
    total_parts: usize,
    include_integrity: bool,
) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendNTimes(allocator, 0, format.header_size);

    for (plans) |*plan| {
        if (plan.part_index != selected_part or
            (plan.entry.resource.isMetadata() and selected_part != 0))
            continue;
        const source_offset: usize = @intCast(plan.entry.resource.offset_in_wim);
        const source_size: usize = @intCast(plan.entry.resource.size_in_wim);
        const output_offset = output.items.len;
        try output.appendSlice(
            allocator,
            input[source_offset..][0..source_size],
        );
        plan.output_resource = plan.entry.resource;
        plan.output_resource.offset_in_wim = output_offset;
    }

    const lookup_offset = output.items.len;
    if (selected_part == 0) {
        for (plans) |plan| {
            if (!plan.entry.resource.isMetadata()) continue;
            try appendLookupEntry(
                allocator,
                &output,
                plan,
                @intCast(selected_part + 1),
            );
        }
    }
    for (plans) |plan| {
        if (plan.entry.resource.isMetadata() or plan.part_index != selected_part)
            continue;
        try appendLookupEntry(
            allocator,
            &output,
            plan,
            @intCast(selected_part + 1),
        );
    }
    const lookup_size = output.items.len - lookup_offset;
    const lookup_resource = try resourceHeader(
        lookup_offset,
        lookup_size,
        lookup_size,
        0x02,
    );
    const lookup_end = output.items.len;

    const xml_offset = output.items.len;
    try output.appendSlice(allocator, xml);
    const xml_resource = try resourceHeader(xml_offset, xml.len, xml.len, 0x02);
    const integrity_resource = if (include_integrity)
        try appendIntegrity(allocator, &output, lookup_end)
    else
        zeroResource();
    var boot_metadata = zeroResource();
    var boot_index: u32 = 0;
    if (total_parts == 1 and source_header.boot_index != 0) {
        var image_index: u32 = 0;
        for (plans) |plan| {
            if (!plan.entry.resource.isMetadata()) continue;
            image_index += 1;
            if (image_index == source_header.boot_index) {
                boot_metadata = plan.output_resource;
                boot_index = image_index;
                break;
            }
        }
    }
    writeHeader(
        output.items[0..format.header_size],
        source_header,
        @intCast(selected_part + 1),
        @intCast(total_parts),
        lookup_resource,
        xml_resource,
        boot_metadata,
        boot_index,
        integrity_resource,
    );
    return output.toOwnedSlice(allocator);
}

fn appendLookupEntry(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    plan: PlannedEntry,
    part_number: u16,
) Error!void {
    const offset = output.items.len;
    try output.appendNTimes(allocator, 0, format.lookup_entry_size);
    writeResourceHeader(output.items, offset, plan.output_resource);
    writeU16(output.items, offset + 24, part_number);
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
    if (table_len > std.math.maxInt(u32)) return error.IntegerOverflow;
    const offset = output.items.len;
    try output.appendNTimes(allocator, 0, table_len);
    writeU32(output.items, offset, @as(u32, @intCast(table_len)));
    writeU32(output.items, offset + 4, @as(u32, @intCast(count)));
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
    part_number: u16,
    total_parts: u16,
    lookup: format.ResourceHeader,
    xml: format.ResourceHeader,
    boot_metadata: format.ResourceHeader,
    boot_index: u32,
    integrity: format.ResourceHeader,
) void {
    @memset(output, 0);
    @memcpy(output[0..8], &format.magic);
    writeU32(output, 8, format.header_size);
    writeU32(output, 12, source.version);
    var flags = source.flags & ~@as(u32, 0x0000_0040);
    if (total_parts > 1) flags |= 0x0000_0008 else flags &= ~@as(u32, 0x0000_0008);
    writeU32(output, 16, flags);
    writeU32(output, 20, @as(u32, @intCast(source.chunk_size)));
    @memcpy(output[24..40], &source.guid);
    writeU16(output, 40, part_number);
    writeU16(output, 42, total_parts);
    writeU32(output, 44, source.image_count);
    writeResourceHeader(output, 48, lookup);
    writeResourceHeader(output, 72, xml);
    writeResourceHeader(output, 96, boot_metadata);
    writeU32(output, 120, boot_index);
    writeResourceHeader(output, 124, integrity);
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

fn writeU16(output: []u8, offset: usize, value: u16) void {
    std.mem.writeInt(u16, output[offset..][0..2], value, .little);
}

fn writeU32(output: []u8, offset: usize, value: u32) void {
    std.mem.writeInt(u32, output[offset..][0..4], value, .little);
}

fn writeU64(output: []u8, offset: usize, value: u64) void {
    std.mem.writeInt(u64, output[offset..][0..8], value, .little);
}
