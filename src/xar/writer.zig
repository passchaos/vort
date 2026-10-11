const std = @import("std");
const bzip2 = @import("../bzip2.zig");
const deflate = @import("../deflate.zig");
const lzma = @import("../lzma.zig");
const xz = @import("../xz.zig");
const format = @import("format.zig");

pub const Error = format.Error || bzip2.Error || deflate.Error || lzma.Error ||
    xz.Error || std.mem.Allocator.Error;

pub const Compression = enum {
    auto,
    copy,
    zlib,
    bzip2,
    lzma,
    xz,
};

pub const EntryKind = enum {
    file,
    directory,
    symlink,
};

pub const EncodeEntry = struct {
    path: []const u8,
    kind: EntryKind = .file,
    data: []const u8 = "",
    link_target: []const u8 = "",
    mode: ?u32 = null,
    uid: u64 = 0,
    gid: u64 = 0,
};

pub const EncodeOptions = struct {
    compression: Compression = .zlib,
    checksum: format.ChecksumAlgorithm = .sha1,
    copy_if_larger: bool = true,
};

const Node = struct {
    path: []u8,
    name: []u8,
    parent: ?usize,
    kind: EntryKind,
    data: []const u8,
    link_target: []const u8,
    mode: u32,
    uid: u64,
    gid: u64,
    explicit: bool,
    encoding: format.Encoding = .copy,
    offset: usize = 0,
    packed_size: usize = 0,
    archived_checksum: format.Digest = .{},
    extracted_checksum: format.Digest = .{},

    fn deinit(self: Node, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
        allocator.free(self.name);
    }
};

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    entries: []const EncodeEntry,
    options: EncodeOptions,
) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, entries, options);
    return output.toOwnedSlice(allocator);
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entries: []const EncodeEntry,
    options: EncodeOptions,
) Error!usize {
    const start = output.items.len;
    errdefer output.shrinkRetainingCapacity(start);
    const nodes = try buildNodesAlloc(allocator, entries);
    defer {
        for (nodes) |node| node.deinit(allocator);
        allocator.free(nodes);
    }
    var heap: std.ArrayList(u8) = .empty;
    defer heap.deinit(allocator);
    try heap.appendNTimes(allocator, 0, options.checksum.digestSize());
    for (nodes) |*node| {
        if (node.kind != .file) continue;
        var encoded: ?[]u8 = null;
        defer if (encoded) |bytes| allocator.free(bytes);
        const selected: []const u8 = switch (options.compression) {
            .copy => blk: {
                node.encoding = .copy;
                break :blk node.data;
            },
            .auto, .zlib, .bzip2, .lzma, .xz => blk: {
                encoded = try encodePayload(allocator, node.data, options.compression);
                if ((options.copy_if_larger or options.compression == .auto) and
                    encoded.?.len >= node.data.len)
                {
                    node.encoding = .copy;
                    break :blk node.data;
                }
                node.encoding = compressionEncoding(options.compression);
                break :blk encoded.?;
            },
        };
        node.offset = heap.items.len;
        node.packed_size = selected.len;
        node.archived_checksum = format.hash(options.checksum, selected);
        node.extracted_checksum = format.hash(options.checksum, node.data);
        try heap.appendSlice(allocator, selected);
    }

    const toc = try buildTocAlloc(allocator, nodes, options.checksum);
    defer allocator.free(toc);
    const packed_toc = try deflate.encodeZlibBestAlloc(allocator, toc, .{});
    defer allocator.free(packed_toc);
    const toc_digest = format.hash(options.checksum, packed_toc);
    if (toc_digest.slice().len != 0)
        @memcpy(heap.items[0..toc_digest.slice().len], toc_digest.slice());

    var header: [format.base_header_size]u8 = @splat(0);
    writeU32Be(&header, 0, format.magic);
    writeU16Be(&header, 4, format.base_header_size);
    writeU16Be(&header, 6, 1);
    writeU64Be(&header, 8, packed_toc.len);
    writeU64Be(&header, 16, toc.len);
    writeU32Be(&header, 24, @intFromEnum(options.checksum));
    try output.appendSlice(allocator, &header);
    try output.appendSlice(allocator, packed_toc);
    try output.appendSlice(allocator, heap.items);
    return output.items.len - start;
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    entries: []const EncodeEntry,
    options: EncodeOptions,
    output: []u8,
) Error!usize {
    const encoded = try encodeAlloc(allocator, entries, options);
    defer allocator.free(encoded);
    if (encoded.len > output.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

fn buildNodesAlloc(
    allocator: std.mem.Allocator,
    entries: []const EncodeEntry,
) Error![]Node {
    var nodes: std.ArrayList(Node) = .empty;
    errdefer {
        for (nodes.items) |node| node.deinit(allocator);
        nodes.deinit(allocator);
    }
    for (entries) |entry| {
        if (entry.path.len == 0 or entry.path[0] == '/' or
            entry.path[entry.path.len - 1] == '/')
            return error.InvalidXar;
        if (entry.kind != .file and entry.data.len != 0)
            return error.InvalidXar;
        if (entry.kind == .symlink and entry.link_target.len == 0)
            return error.InvalidXar;
        if (entry.kind != .symlink and entry.link_target.len != 0)
            return error.InvalidXar;
        var components = std.mem.splitScalar(u8, entry.path, '/');
        var prefix: std.ArrayList(u8) = .empty;
        defer prefix.deinit(allocator);
        var parent: ?usize = null;
        while (components.next()) |component| {
            if (!validComponent(component)) return error.InvalidXar;
            if (prefix.items.len != 0) try prefix.append(allocator, '/');
            try prefix.appendSlice(allocator, component);
            const is_final = prefix.items.len == entry.path.len;
            if (findNode(nodes.items, prefix.items)) |index| {
                if (is_final) {
                    var node = &nodes.items[index];
                    if (node.explicit or node.kind != .directory or
                        entry.kind != .directory)
                        return error.InvalidXar;
                    node.explicit = true;
                    node.mode = entry.mode orelse 0o755;
                    node.uid = entry.uid;
                    node.gid = entry.gid;
                } else if (nodes.items[index].kind != .directory) {
                    return error.InvalidXar;
                }
                parent = index;
                continue;
            }
            const path = try allocator.dupe(u8, prefix.items);
            errdefer allocator.free(path);
            const name = try allocator.dupe(u8, component);
            errdefer allocator.free(name);
            try nodes.append(allocator, .{
                .path = path,
                .name = name,
                .parent = parent,
                .kind = if (is_final) entry.kind else .directory,
                .data = if (is_final) entry.data else "",
                .link_target = if (is_final) entry.link_target else "",
                .mode = entry.mode orelse if (is_final)
                    switch (entry.kind) {
                        .file => 0o644,
                        .directory => 0o755,
                        .symlink => 0o777,
                    }
                else
                    0o755,
                .uid = if (is_final) entry.uid else 0,
                .gid = if (is_final) entry.gid else 0,
                .explicit = is_final,
            });
            parent = nodes.items.len - 1;
        }
    }
    return nodes.toOwnedSlice(allocator);
}

fn buildTocAlloc(
    allocator: std.mem.Allocator,
    nodes: []const Node,
    checksum_algorithm: format.ChecksumAlgorithm,
) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendSlice(
        allocator,
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" ++
            "<xar><toc><creation-time>1970-01-01T00:00:00Z</creation-time>",
    );
    if (checksum_algorithm != .none) {
        try output.appendSlice(allocator, "<checksum style=\"");
        try output.appendSlice(allocator, checksum_algorithm.style());
        try output.appendSlice(allocator, "\"><offset>0</offset><size>");
        try appendDecimal(allocator, &output, checksum_algorithm.digestSize());
        try output.appendSlice(allocator, "</size></checksum>");
    }
    for (nodes, 0..) |node, index|
        if (node.parent == null) try appendNode(allocator, &output, nodes, index);
    try output.appendSlice(allocator, "</toc></xar>\n");
    return output.toOwnedSlice(allocator);
}

fn appendNode(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    nodes: []const Node,
    index: usize,
) Error!void {
    const node = nodes[index];
    try output.appendSlice(allocator, "<file id=\"");
    try appendDecimal(allocator, output, index + 1);
    try output.appendSlice(allocator, "\"><name>");
    try appendXmlEscaped(allocator, output, node.name);
    try output.appendSlice(allocator, "</name><type>");
    try output.appendSlice(allocator, switch (node.kind) {
        .file => "file",
        .directory => "directory",
        .symlink => "symlink",
    });
    try output.appendSlice(allocator, "</type><mode>0");
    try appendOctal(allocator, output, node.mode);
    try output.appendSlice(allocator, "</mode><uid>");
    try appendDecimal(allocator, output, node.uid);
    try output.appendSlice(allocator, "</uid><gid>");
    try appendDecimal(allocator, output, node.gid);
    try output.appendSlice(allocator, "</gid>");
    if (node.kind == .symlink) {
        try output.appendSlice(allocator, "<link type=\"broken\">");
        try appendXmlEscaped(allocator, output, node.link_target);
        try output.appendSlice(allocator, "</link>");
    } else if (node.kind == .file) {
        try output.appendSlice(allocator, "<data><length>");
        try appendDecimal(allocator, output, node.packed_size);
        try output.appendSlice(allocator, "</length><offset>");
        try appendDecimal(allocator, output, node.offset);
        try output.appendSlice(allocator, "</offset><size>");
        try appendDecimal(allocator, output, node.data.len);
        try output.appendSlice(allocator, "</size><encoding style=\"");
        try output.appendSlice(allocator, node.encoding.style());
        try output.appendSlice(allocator, "\"/>");
        if (node.archived_checksum.algorithm != .none) {
            try appendDigest(allocator, output, "archived-checksum", node.archived_checksum);
            try appendDigest(allocator, output, "extracted-checksum", node.extracted_checksum);
        }
        try output.appendSlice(allocator, "</data>");
    }
    for (nodes, 0..) |child, child_index|
        if (child.parent == index) try appendNode(allocator, output, nodes, child_index);
    try output.appendSlice(allocator, "</file>");
}

fn appendDigest(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    tag: []const u8,
    digest: format.Digest,
) Error!void {
    try output.append(allocator, '<');
    try output.appendSlice(allocator, tag);
    try output.appendSlice(allocator, " style=\"");
    try output.appendSlice(allocator, digest.algorithm.style());
    try output.appendSlice(allocator, "\">");
    const hex = "0123456789abcdef";
    for (digest.slice()) |byte| {
        try output.append(allocator, hex[byte >> 4]);
        try output.append(allocator, hex[byte & 0x0f]);
    }
    try output.appendSlice(allocator, "</");
    try output.appendSlice(allocator, tag);
    try output.append(allocator, '>');
}

fn encodePayload(
    allocator: std.mem.Allocator,
    input: []const u8,
    compression: Compression,
) Error![]u8 {
    return switch (compression) {
        .auto, .zlib => deflate.encodeZlibBestAlloc(allocator, input, .{}),
        .bzip2 => bzip2.encodeAlloc(allocator, input, .{}),
        .lzma => lzma.encodeAlloc(allocator, input, .{}),
        .xz => xz.encodeAlloc(allocator, input, .{}),
        .copy => unreachable,
    };
}

fn compressionEncoding(compression: Compression) format.Encoding {
    return switch (compression) {
        .auto, .zlib => .zlib,
        .bzip2 => .bzip2,
        .lzma => .lzma,
        .xz => .xz,
        .copy => .copy,
    };
}

fn findNode(nodes: []const Node, path: []const u8) ?usize {
    for (nodes, 0..) |node, index|
        if (std.mem.eql(u8, node.path, path)) return index;
    return null;
}

fn validComponent(name: []const u8) bool {
    if (name.len == 0 or std.mem.eql(u8, name, ".") or
        std.mem.eql(u8, name, ".."))
        return false;
    return std.mem.indexOfAny(u8, name, "/\\\x00") == null;
}

fn appendXmlEscaped(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
) Error!void {
    for (input) |byte| {
        const replacement: []const u8 = switch (byte) {
            '&' => "&amp;",
            '<' => "&lt;",
            '>' => "&gt;",
            '"' => "&quot;",
            '\'' => "&apos;",
            else => {
                if (byte < 0x20 and byte != '\t' and byte != '\n' and byte != '\r')
                    return error.InvalidXar;
                try output.append(allocator, byte);
                continue;
            },
        };
        try output.appendSlice(allocator, replacement);
    }
}

fn appendDecimal(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: anytype,
) Error!void {
    var buffer: [32]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, "{d}", .{value}) catch
        return error.IntegerOverflow;
    try output.appendSlice(allocator, text);
}

fn appendOctal(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: u32,
) Error!void {
    var buffer: [16]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, "{o}", .{value}) catch
        return error.IntegerOverflow;
    try output.appendSlice(allocator, text);
}

fn writeU16Be(bytes: []u8, offset: usize, value: anytype) void {
    std.mem.writeInt(u16, bytes[offset..][0..2], @intCast(value), .big);
}

fn writeU32Be(bytes: []u8, offset: usize, value: anytype) void {
    std.mem.writeInt(u32, bytes[offset..][0..4], @intCast(value), .big);
}

fn writeU64Be(bytes: []u8, offset: usize, value: anytype) void {
    std.mem.writeInt(u64, bytes[offset..][0..8], @intCast(value), .big);
}
