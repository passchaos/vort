const std = @import("std");
const format = @import("format.zig");

pub const Error = format.Error || std.mem.Allocator.Error;

pub const TocChecksum = struct {
    defined: bool = false,
    algorithm: format.ChecksumAlgorithm = .none,
    offset: usize = 0,
    size: usize = 0,
};

pub const Toc = struct {
    entries: []format.Entry,
    checksum: TocChecksum,

    pub fn deinit(self: Toc, allocator: std.mem.Allocator) void {
        for (self.entries) |entry| entry.deinit(allocator);
        allocator.free(self.entries);
    }
};

const Tag = struct {
    name: []const u8,
    attributes: []const u8,
    self_closing: bool,
};

const Token = union(enum) {
    start: Tag,
    end: []const u8,
    text: []const u8,
};

const Cursor = struct {
    bytes: []const u8,
    position: usize = 0,

    fn nextStructural(self: *Cursor) Error!?Token {
        while (try self.next()) |token| {
            switch (token) {
                .text => |text| if (std.mem.trim(u8, text, " \r\n\t").len == 0)
                    continue
                else
                    return error.InvalidXarToc,
                else => return token,
            }
        }
        return null;
    }

    fn next(self: *Cursor) Error!?Token {
        while (self.position < self.bytes.len) {
            if (self.bytes[self.position] != '<') {
                const end = std.mem.indexOfScalarPos(
                    u8,
                    self.bytes,
                    self.position,
                    '<',
                ) orelse self.bytes.len;
                const text = self.bytes[self.position..end];
                self.position = end;
                return .{ .text = text };
            }
            if (std.mem.startsWith(u8, self.bytes[self.position..], "<!--")) {
                const end = std.mem.indexOfPos(
                    u8,
                    self.bytes,
                    self.position + 4,
                    "-->",
                ) orelse return error.InvalidXarToc;
                self.position = end + 3;
                continue;
            }
            if (std.mem.startsWith(u8, self.bytes[self.position..], "<?")) {
                const end = std.mem.indexOfPos(
                    u8,
                    self.bytes,
                    self.position + 2,
                    "?>",
                ) orelse return error.InvalidXarToc;
                self.position = end + 2;
                continue;
            }
            if (std.mem.startsWith(u8, self.bytes[self.position..], "<![CDATA[")) {
                const start = self.position + 9;
                const end = std.mem.indexOfPos(u8, self.bytes, start, "]]>") orelse
                    return error.InvalidXarToc;
                self.position = end + 3;
                return .{ .text = self.bytes[start..end] };
            }
            if (std.mem.startsWith(u8, self.bytes[self.position..], "<!")) {
                self.position = try skipDeclaration(self.bytes, self.position + 2);
                continue;
            }
            return try self.parseTag();
        }
        return null;
    }

    fn parseTag(self: *Cursor) Error!Token {
        var position = self.position + 1;
        var is_end = false;
        if (position < self.bytes.len and self.bytes[position] == '/') {
            is_end = true;
            position += 1;
        }
        const name_start = position;
        while (position < self.bytes.len and isNameByte(self.bytes[position]))
            position += 1;
        if (position == name_start) return error.InvalidXarToc;
        const name = self.bytes[name_start..position];
        const attributes_start = position;
        var quote: ?u8 = null;
        while (position < self.bytes.len) : (position += 1) {
            const byte = self.bytes[position];
            if (quote) |delimiter| {
                if (byte == delimiter) quote = null;
                continue;
            }
            if (byte == '\'' or byte == '"') {
                quote = byte;
                continue;
            }
            if (byte != '>') continue;
            var end = position;
            while (end > attributes_start and
                std.ascii.isWhitespace(self.bytes[end - 1]))
                end -= 1;
            const self_closing = end > attributes_start and
                self.bytes[end - 1] == '/';
            if (self_closing) end -= 1;
            while (end > attributes_start and
                std.ascii.isWhitespace(self.bytes[end - 1]))
                end -= 1;
            const attributes = self.bytes[attributes_start..end];
            self.position = position + 1;
            if (is_end) {
                if (self_closing or std.mem.trim(u8, attributes, " \r\n\t").len != 0)
                    return error.InvalidXarToc;
                return .{ .end = name };
            }
            return .{ .start = .{
                .name = name,
                .attributes = attributes,
                .self_closing = self_closing,
            } };
        }
        return error.InvalidXarToc;
    }
};

const EntryBuilder = struct {
    id: ?u64 = null,
    name_text: ?[]const u8 = null,
    name_base64: bool = false,
    kind: format.EntryKind = .other,
    type_seen: bool = false,
    mode: ?u32 = null,
    uid: ?u64 = null,
    gid: ?u64 = null,
    link_text: ?[]const u8 = null,
    link_base64: bool = false,
    data: ?format.Data = null,
    index: ?usize = null,
};

pub fn parseAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    max_entries: usize,
    max_depth: usize,
) Error!Toc {
    var entries: std.ArrayList(format.Entry) = .empty;
    errdefer {
        for (entries.items) |entry| entry.deinit(allocator);
        entries.deinit(allocator);
    }
    var cursor = Cursor{ .bytes = input };
    const xar = try expectStart(&cursor, "xar");
    if (xar.self_closing) return error.InvalidXarToc;
    const toc_tag = try expectStart(&cursor, "toc");
    if (toc_tag.self_closing) return error.InvalidXarToc;
    var checksum = TocChecksum{};
    while (true) {
        const token = (try cursor.nextStructural()) orelse return error.InvalidXarToc;
        switch (token) {
            .end => |name| {
                if (!std.mem.eql(u8, name, "toc")) return error.InvalidXarToc;
                break;
            },
            .start => |tag| {
                if (std.mem.eql(u8, tag.name, "file")) {
                    try parseFile(
                        allocator,
                        &cursor,
                        tag,
                        &entries,
                        null,
                        "",
                        0,
                        max_depth,
                        max_entries,
                    );
                } else if (std.mem.eql(u8, tag.name, "checksum")) {
                    if (checksum.defined) return error.InvalidXarToc;
                    checksum = try parseTocChecksum(&cursor, tag);
                } else {
                    try skipElement(&cursor, tag);
                }
            },
            .text => unreachable,
        }
    }
    const xar_end = (try cursor.nextStructural()) orelse return error.InvalidXarToc;
    switch (xar_end) {
        .end => |name| if (!std.mem.eql(u8, name, "xar"))
            return error.InvalidXarToc,
        else => return error.InvalidXarToc,
    }
    if ((try cursor.nextStructural()) != null) return error.TrailingData;
    return .{
        .entries = try entries.toOwnedSlice(allocator),
        .checksum = checksum,
    };
}

fn parseFile(
    allocator: std.mem.Allocator,
    cursor: *Cursor,
    start: Tag,
    entries: *std.ArrayList(format.Entry),
    parent: ?usize,
    parent_path: []const u8,
    depth: usize,
    max_depth: usize,
    max_entries: usize,
) Error!void {
    if (start.self_closing or depth >= max_depth) return error.InvalidXarToc;
    var builder = EntryBuilder{};
    if (attribute(start, "id")) |id_text|
        builder.id = std.fmt.parseInt(u64, id_text, 10) catch
            return error.InvalidXarToc;
    while (true) {
        const token = (try cursor.nextStructural()) orelse return error.InvalidXarToc;
        switch (token) {
            .end => |name| {
                if (!std.mem.eql(u8, name, "file")) return error.InvalidXarToc;
                break;
            },
            .start => |tag| {
                if (std.mem.eql(u8, tag.name, "name")) {
                    if (builder.name_text != null) return error.InvalidXarToc;
                    builder.name_text = try readTextElement(cursor, tag, "name");
                    builder.name_base64 = attributeIsBase64(tag);
                } else if (std.mem.eql(u8, tag.name, "type")) {
                    if (builder.type_seen) return error.InvalidXarToc;
                    builder.type_seen = true;
                    const value = try readTextElement(cursor, tag, "type");
                    builder.kind = if (std.mem.eql(u8, value, "file"))
                        .file
                    else if (std.mem.eql(u8, value, "directory"))
                        .directory
                    else if (std.mem.eql(u8, value, "symlink"))
                        .symlink
                    else
                        .other;
                } else if (std.mem.eql(u8, tag.name, "data")) {
                    if (builder.data != null) return error.InvalidXarToc;
                    builder.data = try parseData(cursor, tag);
                } else if (std.mem.eql(u8, tag.name, "link")) {
                    if (builder.link_text != null) return error.InvalidXarToc;
                    builder.link_text = try readTextElement(cursor, tag, "link");
                    builder.link_base64 = attributeIsBase64(tag);
                } else if (std.mem.eql(u8, tag.name, "mode")) {
                    if (builder.mode != null) return error.InvalidXarToc;
                    builder.mode = try parseMode(try readTextElement(cursor, tag, "mode"));
                } else if (std.mem.eql(u8, tag.name, "uid")) {
                    if (builder.uid != null) return error.InvalidXarToc;
                    builder.uid = try parseDecimal(try readTextElement(cursor, tag, "uid"));
                } else if (std.mem.eql(u8, tag.name, "gid")) {
                    if (builder.gid != null) return error.InvalidXarToc;
                    builder.gid = try parseDecimal(try readTextElement(cursor, tag, "gid"));
                } else if (std.mem.eql(u8, tag.name, "file")) {
                    const index = try ensureEntry(
                        allocator,
                        entries,
                        &builder,
                        parent,
                        parent_path,
                        max_entries,
                    );
                    try parseFile(
                        allocator,
                        cursor,
                        tag,
                        entries,
                        index,
                        entries.items[index].path,
                        depth + 1,
                        max_depth,
                        max_entries,
                    );
                } else {
                    try skipElement(cursor, tag);
                }
            },
            .text => unreachable,
        }
    }
    const index = try ensureEntry(
        allocator,
        entries,
        &builder,
        parent,
        parent_path,
        max_entries,
    );
    var entry = &entries.items[index];
    entry.kind = if (builder.kind == .other and builder.data != null)
        .file
    else
        builder.kind;
    entry.mode = builder.mode;
    entry.uid = builder.uid;
    entry.gid = builder.gid;
    entry.data = builder.data;
    if (builder.link_text) |text| {
        if (entry.link_target != null) return error.InvalidXarToc;
        entry.link_target = if (builder.link_base64)
            try decodeBase64TextAlloc(allocator, text)
        else
            try decodeXmlTextAlloc(allocator, text);
    }
}

fn ensureEntry(
    allocator: std.mem.Allocator,
    entries: *std.ArrayList(format.Entry),
    builder: *EntryBuilder,
    parent: ?usize,
    parent_path: []const u8,
    max_entries: usize,
) Error!usize {
    if (builder.index) |index| return index;
    if (entries.items.len >= max_entries) return error.OutputLimitExceeded;
    const name_text = builder.name_text orelse return error.InvalidXarToc;
    const name = if (builder.name_base64)
        try decodeBase64TextAlloc(allocator, name_text)
    else
        try decodeXmlTextAlloc(allocator, name_text);
    defer allocator.free(name);
    if (!validComponent(name)) return error.InvalidXarToc;
    const path_len = std.math.add(
        usize,
        parent_path.len,
        name.len + @intFromBool(parent_path.len != 0),
    ) catch return error.IntegerOverflow;
    const path = try allocator.alloc(u8, path_len);
    errdefer allocator.free(path);
    var position: usize = 0;
    if (parent_path.len != 0) {
        @memcpy(path[0..parent_path.len], parent_path);
        position = parent_path.len;
        path[position] = '/';
        position += 1;
    }
    @memcpy(path[position..], name);
    for (entries.items) |entry|
        if (std.mem.eql(u8, entry.path, path)) return error.InvalidXarToc;
    try entries.append(allocator, .{
        .id = builder.id,
        .parent = parent,
        .path = path,
        .kind = builder.kind,
        .mode = builder.mode,
        .uid = builder.uid,
        .gid = builder.gid,
        .link_target = null,
        .data = builder.data,
    });
    builder.index = entries.items.len - 1;
    return builder.index.?;
}

fn parseData(cursor: *Cursor, start: Tag) Error!format.Data {
    if (start.self_closing) return error.InvalidXarToc;
    var size: ?usize = null;
    var packed_size: ?usize = null;
    var offset: ?usize = null;
    var encoding: format.Encoding = .copy;
    var encoding_seen = false;
    var archived_checksum = format.Digest{};
    var archived_checksum_seen = false;
    var extracted_checksum = format.Digest{};
    var extracted_checksum_seen = false;
    while (true) {
        const token = (try cursor.nextStructural()) orelse return error.InvalidXarToc;
        switch (token) {
            .end => |name| {
                if (!std.mem.eql(u8, name, "data")) return error.InvalidXarToc;
                break;
            },
            .start => |tag| {
                if (std.mem.eql(u8, tag.name, "size")) {
                    if (size != null) return error.InvalidXarToc;
                    size = try parseUsize(try readTextElement(cursor, tag, "size"));
                } else if (std.mem.eql(u8, tag.name, "length")) {
                    if (packed_size != null) return error.InvalidXarToc;
                    packed_size = try parseUsize(try readTextElement(cursor, tag, "length"));
                } else if (std.mem.eql(u8, tag.name, "offset")) {
                    if (offset != null) return error.InvalidXarToc;
                    offset = try parseUsize(try readTextElement(cursor, tag, "offset"));
                } else if (std.mem.eql(u8, tag.name, "encoding")) {
                    if (encoding_seen) return error.InvalidXarToc;
                    encoding_seen = true;
                    const style = attribute(tag, "style") orelse "";
                    if (std.mem.indexOf(u8, style, "encrypted") != null)
                        return error.EncryptedXarEntry;
                    encoding = format.Encoding.fromStyle(style) orelse
                        return error.UnsupportedXarCompression;
                    try skipElement(cursor, tag);
                } else if (std.mem.eql(u8, tag.name, "archived-checksum")) {
                    if (archived_checksum_seen) return error.InvalidXarToc;
                    archived_checksum_seen = true;
                    archived_checksum = try parseDigest(cursor, tag);
                } else if (std.mem.eql(u8, tag.name, "extracted-checksum")) {
                    if (extracted_checksum_seen) return error.InvalidXarToc;
                    extracted_checksum_seen = true;
                    extracted_checksum = try parseDigest(cursor, tag);
                } else {
                    try skipElement(cursor, tag);
                }
            },
            .text => unreachable,
        }
    }
    return .{
        .size = size orelse return error.InvalidXarToc,
        .packed_size = packed_size orelse return error.InvalidXarToc,
        .offset = offset orelse return error.InvalidXarToc,
        .encoding = encoding,
        .archived_checksum = archived_checksum,
        .extracted_checksum = extracted_checksum,
    };
}

fn parseDigest(cursor: *Cursor, tag: Tag) Error!format.Digest {
    const style = attribute(tag, "style") orelse return error.InvalidXarToc;
    const algorithm = format.ChecksumAlgorithm.fromStyle(style) orelse
        return error.UnsupportedXarChecksum;
    const text = try readTextElement(cursor, tag, tag.name);
    if (text.len != algorithm.digestSize() * 2) return error.InvalidXarToc;
    var digest = format.Digest{ .algorithm = algorithm };
    _ = std.fmt.hexToBytes(digest.bytes[0..algorithm.digestSize()], text) catch
        return error.InvalidXarToc;
    return digest;
}

fn parseTocChecksum(cursor: *Cursor, tag: Tag) Error!TocChecksum {
    if (tag.self_closing) return error.InvalidXarToc;
    const algorithm = format.ChecksumAlgorithm.fromStyle(
        attribute(tag, "style") orelse return error.InvalidXarToc,
    ) orelse return error.UnsupportedXarChecksum;
    var offset: ?usize = null;
    var size: ?usize = null;
    while (true) {
        const token = (try cursor.nextStructural()) orelse return error.InvalidXarToc;
        switch (token) {
            .end => |name| {
                if (!std.mem.eql(u8, name, "checksum")) return error.InvalidXarToc;
                break;
            },
            .start => |child| {
                if (std.mem.eql(u8, child.name, "offset")) {
                    if (offset != null) return error.InvalidXarToc;
                    offset = try parseUsize(try readTextElement(cursor, child, "offset"));
                } else if (std.mem.eql(u8, child.name, "size")) {
                    if (size != null) return error.InvalidXarToc;
                    size = try parseUsize(try readTextElement(cursor, child, "size"));
                } else {
                    try skipElement(cursor, child);
                }
            },
            .text => unreachable,
        }
    }
    const checksum_size = size orelse return error.InvalidXarToc;
    if (checksum_size != algorithm.digestSize()) return error.InvalidXarToc;
    return .{
        .defined = true,
        .algorithm = algorithm,
        .offset = offset orelse return error.InvalidXarToc,
        .size = checksum_size,
    };
}

fn expectStart(cursor: *Cursor, expected: []const u8) Error!Tag {
    const token = (try cursor.nextStructural()) orelse return error.InvalidXarToc;
    return switch (token) {
        .start => |tag| if (std.mem.eql(u8, tag.name, expected))
            tag
        else
            error.InvalidXarToc,
        else => error.InvalidXarToc,
    };
}

fn readTextElement(cursor: *Cursor, tag: Tag, expected: []const u8) Error![]const u8 {
    if (!std.mem.eql(u8, tag.name, expected) or tag.self_closing)
        return error.InvalidXarToc;
    const token = (try cursor.next()) orelse return error.InvalidXarToc;
    const text = switch (token) {
        .text => |value| value,
        .end => |name| {
            if (!std.mem.eql(u8, name, expected)) return error.InvalidXarToc;
            return "";
        },
        else => return error.InvalidXarToc,
    };
    const end = (try cursor.next()) orelse return error.InvalidXarToc;
    switch (end) {
        .end => |name| if (!std.mem.eql(u8, name, expected))
            return error.InvalidXarToc,
        else => return error.InvalidXarToc,
    }
    return std.mem.trim(u8, text, " \r\n\t");
}

fn skipElement(cursor: *Cursor, start: Tag) Error!void {
    if (start.self_closing) return;
    var depth: usize = 1;
    while (depth != 0) {
        const token = (try cursor.next()) orelse return error.InvalidXarToc;
        switch (token) {
            .start => |tag| if (!tag.self_closing) {
                depth = std.math.add(usize, depth, 1) catch
                    return error.IntegerOverflow;
            },
            .end => depth -= 1,
            .text => {},
        }
    }
}

fn attribute(tag: Tag, wanted: []const u8) ?[]const u8 {
    var position: usize = 0;
    while (position < tag.attributes.len) {
        while (position < tag.attributes.len and
            std.ascii.isWhitespace(tag.attributes[position]))
            position += 1;
        const name_start = position;
        while (position < tag.attributes.len and isNameByte(tag.attributes[position]))
            position += 1;
        if (position == name_start) return null;
        const name = tag.attributes[name_start..position];
        while (position < tag.attributes.len and
            std.ascii.isWhitespace(tag.attributes[position]))
            position += 1;
        if (position == tag.attributes.len or tag.attributes[position] != '=') return null;
        position += 1;
        while (position < tag.attributes.len and
            std.ascii.isWhitespace(tag.attributes[position]))
            position += 1;
        if (position == tag.attributes.len or
            (tag.attributes[position] != '\'' and tag.attributes[position] != '"'))
            return null;
        const quote = tag.attributes[position];
        position += 1;
        const value_start = position;
        while (position < tag.attributes.len and tag.attributes[position] != quote)
            position += 1;
        if (position == tag.attributes.len) return null;
        const value = tag.attributes[value_start..position];
        position += 1;
        if (std.mem.eql(u8, name, wanted)) return value;
    }
    return null;
}

fn decodeXmlTextAlloc(allocator: std.mem.Allocator, text: []const u8) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    var position: usize = 0;
    while (position < text.len) {
        if (text[position] != '&') {
            try output.append(allocator, text[position]);
            position += 1;
            continue;
        }
        const end = std.mem.indexOfScalarPos(u8, text, position + 1, ';') orelse
            return error.InvalidXarToc;
        const entity = text[position + 1 .. end];
        const replacement: u8 = if (std.mem.eql(u8, entity, "amp"))
            '&'
        else if (std.mem.eql(u8, entity, "lt"))
            '<'
        else if (std.mem.eql(u8, entity, "gt"))
            '>'
        else if (std.mem.eql(u8, entity, "quot"))
            '"'
        else if (std.mem.eql(u8, entity, "apos"))
            '\''
        else
            return error.InvalidXarToc;
        try output.append(allocator, replacement);
        position = end + 1;
    }
    return output.toOwnedSlice(allocator);
}

fn decodeBase64TextAlloc(allocator: std.mem.Allocator, text: []const u8) Error![]u8 {
    const decoder = std.base64.standard.decoderWithIgnore(" \r\n\t");
    var output = try allocator.alloc(u8, decoder.calcSizeUpperBound(text.len));
    errdefer allocator.free(output);
    const length = decoder.decode(output, text) catch return error.InvalidXarToc;
    if (length != output.len) output = try allocator.realloc(output, length);
    return output;
}

fn attributeIsBase64(tag: Tag) bool {
    const value = attribute(tag, "enctype") orelse return false;
    return std.ascii.eqlIgnoreCase(value, "base64");
}

fn parseDecimal(text: []const u8) Error!u64 {
    return std.fmt.parseInt(u64, text, 10) catch error.InvalidXarToc;
}

fn parseUsize(text: []const u8) Error!usize {
    const value = try parseDecimal(text);
    return std.math.cast(usize, value) orelse error.IntegerOverflow;
}

fn parseMode(text: []const u8) Error!u32 {
    const base: u8 = if (text.len > 1 and text[0] == '0') 8 else 10;
    return std.fmt.parseInt(u32, text, base) catch error.InvalidXarToc;
}

fn validComponent(name: []const u8) bool {
    if (name.len == 0 or std.mem.eql(u8, name, ".") or
        std.mem.eql(u8, name, ".."))
        return false;
    return std.mem.indexOfAny(u8, name, "/\\\x00") == null;
}

fn skipDeclaration(bytes: []const u8, start: usize) Error!usize {
    var position = start;
    var quote: ?u8 = null;
    var bracket_depth: usize = 0;
    while (position < bytes.len) : (position += 1) {
        const byte = bytes[position];
        if (quote) |delimiter| {
            if (byte == delimiter) quote = null;
            continue;
        }
        if (byte == '\'' or byte == '"') {
            quote = byte;
        } else if (byte == '[') {
            bracket_depth += 1;
        } else if (byte == ']') {
            if (bracket_depth == 0) return error.InvalidXarToc;
            bracket_depth -= 1;
        } else if (byte == '>' and bracket_depth == 0) {
            return position + 1;
        }
    }
    return error.InvalidXarToc;
}

fn isNameByte(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '-' or
        byte == ':' or byte == '.';
}
