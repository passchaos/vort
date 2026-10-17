const std = @import("std");
const core = @import("../core.zig");
const format = @import("format.zig");
const metadata_writer = @import("writer_metadata.zig");
const resource_writer = @import("writer_resource.zig");
const streams = @import("writer_streams.zig");
const tree_mod = @import("writer_tree.zig");

pub const Error = core.Error || format.Error || metadata_writer.Error ||
    resource_writer.Error || tree_mod.Error || std.mem.Allocator.Error || error{
    InvalidWimWriterOptions,
    InvalidWimEntry,
    WimResourceTooLarge,
};

pub const Entry = tree_mod.Entry;
pub const EntryKind = tree_mod.EntryKind;
pub const NamedStream = streams.NamedStream;
pub const ReparseData = streams.ReparseData;
pub const Compression = resource_writer.Compression;

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
};

const Blob = struct {
    sha1: [std.crypto.hash.Sha1.digest_length]u8,
    data: []const u8,
    reference_count: u32,
    resource: format.ResourceHeader = undefined,
};

const integrity_chunk_size: usize = 10 * 1024 * 1024;

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    entries: []const Entry,
    options: Options,
) Error![]u8 {
    const chunk_size = try effectiveChunkSize(options);
    try validateOptions(options, chunk_size);

    var tree = try tree_mod.build(allocator, entries, .{
        .creation_time = options.root_creation_time,
        .last_access_time = options.root_last_access_time,
        .last_write_time = options.root_last_write_time,
    });
    defer tree.deinit();
    const metadata = try metadata_writer.encodeAlloc(allocator, &tree);
    defer allocator.free(metadata);
    var metadata_hash: [std.crypto.hash.Sha1.digest_length]u8 = undefined;
    std.crypto.hash.Sha1.hash(metadata, &metadata_hash, .{});

    var blobs: std.ArrayList(Blob) = .empty;
    defer blobs.deinit(allocator);
    try collectBlobs(allocator, &blobs, tree.nodes);

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
    const metadata_resource = try resource_writer.append(
        allocator,
        &output,
        metadata,
        options.compression,
        chunk_size,
        0x02,
    );

    const lookup_offset = output.items.len;
    for (blobs.items) |blob|
        try appendLookupEntry(allocator, &output, blob.resource, blob.reference_count, &blob.sha1);
    try appendLookupEntry(allocator, &output, metadata_resource, 1, &metadata_hash);
    const lookup_resource = try resourceHeader(
        lookup_offset,
        output.items.len - lookup_offset,
        output.items.len - lookup_offset,
        0x02,
    );
    const lookup_end = output.items.len;

    const xml_offset = output.items.len;
    const xml = try buildXmlAlloc(
        allocator,
        options,
        tree.directoryCount(),
        tree.fileCount(),
        try tree.totalStreamBytes(),
        xml_offset,
    );
    defer allocator.free(xml);
    try output.appendSlice(allocator, xml);
    const xml_resource = try resourceHeader(
        xml_offset,
        xml.len,
        xml.len,
        0x02,
    );

    const integrity_resource = if (options.integrity)
        try appendIntegrity(allocator, &output, lookup_end)
    else
        format.ResourceHeader{
            .size_in_wim = 0,
            .flags = 0,
            .offset_in_wim = 0,
            .uncompressed_size = 0,
        };

    const guid = options.guid orelse deriveGuid(&metadata_hash, options.image_name);
    writeHeader(
        output.items[0..format.header_size],
        options.compression,
        chunk_size,
        &guid,
        lookup_resource,
        xml_resource,
        integrity_resource,
    );
    return output.toOwnedSlice(allocator);
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

fn effectiveChunkSize(options: Options) Error!usize {
    return options.chunk_size orelse switch (options.compression) {
        .stored => 0,
        .xpress => 32 * 1024,
    };
}

fn validateOptions(options: Options, chunk_size: usize) Error!void {
    try resource_writer.validate(options.compression, chunk_size);
    if (!validXmlText(options.image_name)) return error.InvalidWimWriterOptions;
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

fn buildXmlAlloc(
    allocator: std.mem.Allocator,
    options: Options,
    directory_count: usize,
    file_count: usize,
    total_file_bytes: u64,
    xml_offset: usize,
) Error![]u8 {
    const escaped_name = try escapeXmlAlloc(allocator, options.image_name);
    defer allocator.free(escaped_name);
    const creation_high: u32 = @truncate(options.xml_creation_time >> 32);
    const creation_low: u32 = @truncate(options.xml_creation_time);
    const modified_high: u32 = @truncate(options.xml_last_modification_time >> 32);
    const modified_low: u32 = @truncate(options.xml_last_modification_time);
    const utf8 = try std.fmt.allocPrint(
        allocator,
        "<WIM><IMAGE INDEX=\"1\"><NAME>{s}</NAME>" ++
            "<DIRCOUNT>{d}</DIRCOUNT><FILECOUNT>{d}</FILECOUNT>" ++
            "<TOTALBYTES>{d}</TOTALBYTES><HARDLINKBYTES>0</HARDLINKBYTES>" ++
            "<CREATIONTIME><HIGHPART>{d}</HIGHPART><LOWPART>{d}</LOWPART>" ++
            "</CREATIONTIME><LASTMODIFICATIONTIME><HIGHPART>{d}</HIGHPART>" ++
            "<LOWPART>{d}</LOWPART></LASTMODIFICATIONTIME></IMAGE>" ++
            "<TOTALBYTES>{d}</TOTALBYTES></WIM>",
        .{
            escaped_name,
            directory_count,
            file_count,
            total_file_bytes,
            creation_high,
            creation_low,
            modified_high,
            modified_low,
            xml_offset,
        },
    );
    defer allocator.free(utf8);
    const units = std.unicode.utf8ToUtf16LeAlloc(allocator, utf8) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.InvalidUtf8 => return error.InvalidWimWriterOptions,
    };
    defer allocator.free(units);
    const byte_len = std.math.mul(usize, units.len, 2) catch
        return error.IntegerOverflow;
    const output = try allocator.alloc(u8, try checkedAdd(2, byte_len));
    output[0] = 0xff;
    output[1] = 0xfe;
    for (units, 0..) |unit, index|
        writeU16(output, 2 + index * 2, unit);
    return output;
}

fn escapeXmlAlloc(
    allocator: std.mem.Allocator,
    text: []const u8,
) Error![]u8 {
    if (!validXmlText(text)) return error.InvalidWimWriterOptions;
    var escaped: std.ArrayList(u8) = .empty;
    errdefer escaped.deinit(allocator);
    for (text) |byte| {
        const replacement: []const u8 = switch (byte) {
            '&' => "&amp;",
            '<' => "&lt;",
            '>' => "&gt;",
            else => {
                try escaped.append(allocator, byte);
                continue;
            },
        };
        try escaped.appendSlice(allocator, replacement);
    }
    return escaped.toOwnedSlice(allocator);
}

fn validXmlText(text: []const u8) bool {
    if (!std.unicode.utf8ValidateSlice(text)) return false;
    var view = std.unicode.Utf8View.initUnchecked(text);
    var iterator = view.iterator();
    while (iterator.nextCodepoint()) |codepoint| {
        if (!(codepoint == 0x09 or codepoint == 0x0a or codepoint == 0x0d or
            (codepoint >= 0x20 and codepoint <= 0xd7ff) or
            (codepoint >= 0xe000 and codepoint <= 0xfffd) or
            (codepoint >= 0x10000 and codepoint <= 0x10ffff)))
            return false;
    }
    return true;
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

fn writeHeader(
    header: []u8,
    compression: Compression,
    chunk_size: usize,
    guid: *const [16]u8,
    lookup_resource: format.ResourceHeader,
    xml_resource: format.ResourceHeader,
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
    writeU32(header, 44, 1);
    writeResourceHeader(header, 48, lookup_resource);
    writeResourceHeader(header, 72, xml_resource);
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
