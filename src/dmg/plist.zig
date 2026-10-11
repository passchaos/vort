const std = @import("std");
const format = @import("format.zig");

pub const Error = format.Error || std.mem.Allocator.Error;

pub const Descriptor = struct {
    name: []u8,
    data: []u8,

    pub fn deinit(self: Descriptor, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.data);
    }
};

const Tag = struct {
    name: []const u8,
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
                    return error.InvalidDmgPlist,
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
                const relative = std.mem.indexOfPos(
                    u8,
                    self.bytes,
                    self.position + 4,
                    "-->",
                ) orelse return error.InvalidDmgPlist;
                self.position = relative + 3;
                continue;
            }
            if (std.mem.startsWith(u8, self.bytes[self.position..], "<?")) {
                const relative = std.mem.indexOfPos(
                    u8,
                    self.bytes,
                    self.position + 2,
                    "?>",
                ) orelse return error.InvalidDmgPlist;
                self.position = relative + 2;
                continue;
            }
            if (std.mem.startsWith(u8, self.bytes[self.position..], "<![CDATA[")) {
                const start = self.position + 9;
                const end = std.mem.indexOfPos(u8, self.bytes, start, "]]>") orelse
                    return error.InvalidDmgPlist;
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
        if (position == name_start) return error.InvalidDmgPlist;
        const name = self.bytes[name_start..position];
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
            if (byte == '>') {
                var previous = position;
                while (previous > name_start and
                    std.ascii.isWhitespace(self.bytes[previous - 1]))
                    previous -= 1;
                const self_closing = previous > name_start and
                    self.bytes[previous - 1] == '/';
                self.position = position + 1;
                if (is_end) {
                    if (self_closing) return error.InvalidDmgPlist;
                    return .{ .end = name };
                }
                return .{ .start = .{ .name = name, .self_closing = self_closing } };
            }
        }
        return error.InvalidDmgPlist;
    }
};

pub fn parseBlkxAlloc(
    allocator: std.mem.Allocator,
    xml: []const u8,
    max_descriptors: usize,
) Error![]Descriptor {
    var descriptors: std.ArrayList(Descriptor) = .empty;
    errdefer {
        for (descriptors.items) |descriptor| descriptor.deinit(allocator);
        descriptors.deinit(allocator);
    }
    var cursor = Cursor{ .bytes = xml };
    const plist = try expectStart(&cursor, "plist");
    if (plist.self_closing) return error.InvalidDmgPlist;
    const root = try expectStart(&cursor, "dict");
    if (root.self_closing) return error.InvalidDmgPlist;
    var found_resource_fork = false;
    while (true) {
        const token = (try cursor.nextStructural()) orelse return error.InvalidDmgPlist;
        switch (token) {
            .end => |name| {
                if (!std.mem.eql(u8, name, "dict")) return error.InvalidDmgPlist;
                break;
            },
            .start => |tag| {
                if (!std.mem.eql(u8, tag.name, "key")) return error.InvalidDmgPlist;
                const key = try readTextElement(&cursor, tag, "key");
                const value = try nextStart(&cursor);
                if (std.mem.eql(u8, key, "resource-fork")) {
                    if (found_resource_fork or !std.mem.eql(u8, value.name, "dict") or
                        value.self_closing)
                        return error.InvalidDmgPlist;
                    found_resource_fork = true;
                    try parseResourceFork(
                        allocator,
                        &cursor,
                        &descriptors,
                        max_descriptors,
                    );
                } else {
                    try skipElement(&cursor, value);
                }
            },
            .text => unreachable,
        }
    }
    const plist_end = (try cursor.nextStructural()) orelse
        return error.InvalidDmgPlist;
    switch (plist_end) {
        .end => |name| if (!std.mem.eql(u8, name, "plist"))
            return error.InvalidDmgPlist,
        else => return error.InvalidDmgPlist,
    }
    if ((try cursor.nextStructural()) != null) return error.TrailingData;
    if (!found_resource_fork or descriptors.items.len == 0)
        return error.UnsupportedDmgMetadata;
    return descriptors.toOwnedSlice(allocator);
}

pub fn deinitDescriptors(allocator: std.mem.Allocator, descriptors: []Descriptor) void {
    for (descriptors) |descriptor| descriptor.deinit(allocator);
    allocator.free(descriptors);
}

fn parseResourceFork(
    allocator: std.mem.Allocator,
    cursor: *Cursor,
    descriptors: *std.ArrayList(Descriptor),
    max_descriptors: usize,
) Error!void {
    var found_blkx = false;
    while (true) {
        const token = (try cursor.nextStructural()) orelse return error.InvalidDmgPlist;
        switch (token) {
            .end => |name| {
                if (!std.mem.eql(u8, name, "dict")) return error.InvalidDmgPlist;
                return;
            },
            .start => |tag| {
                if (!std.mem.eql(u8, tag.name, "key")) return error.InvalidDmgPlist;
                const key = try readTextElement(cursor, tag, "key");
                const value = try nextStart(cursor);
                if (std.mem.eql(u8, key, "blkx")) {
                    if (found_blkx or !std.mem.eql(u8, value.name, "array") or
                        value.self_closing)
                        return error.InvalidDmgPlist;
                    found_blkx = true;
                    try parseBlkxArray(
                        allocator,
                        cursor,
                        descriptors,
                        max_descriptors,
                    );
                } else {
                    try skipElement(cursor, value);
                }
            },
            .text => unreachable,
        }
    }
}

fn parseBlkxArray(
    allocator: std.mem.Allocator,
    cursor: *Cursor,
    descriptors: *std.ArrayList(Descriptor),
    max_descriptors: usize,
) Error!void {
    while (true) {
        const token = (try cursor.nextStructural()) orelse return error.InvalidDmgPlist;
        switch (token) {
            .end => |name| {
                if (!std.mem.eql(u8, name, "array")) return error.InvalidDmgPlist;
                return;
            },
            .start => |tag| {
                if (!std.mem.eql(u8, tag.name, "dict") or tag.self_closing)
                    return error.InvalidDmgPlist;
                if (descriptors.items.len >= max_descriptors)
                    return error.OutputLimitExceeded;
                try descriptors.append(allocator, try parseBlkxEntry(allocator, cursor));
            },
            .text => unreachable,
        }
    }
}

fn parseBlkxEntry(allocator: std.mem.Allocator, cursor: *Cursor) Error!Descriptor {
    var name_text: ?[]const u8 = null;
    var data_text: ?[]const u8 = null;
    while (true) {
        const token = (try cursor.nextStructural()) orelse return error.InvalidDmgPlist;
        switch (token) {
            .end => |name| {
                if (!std.mem.eql(u8, name, "dict")) return error.InvalidDmgPlist;
                break;
            },
            .start => |tag| {
                if (!std.mem.eql(u8, tag.name, "key")) return error.InvalidDmgPlist;
                const key = try readTextElement(cursor, tag, "key");
                const value = try nextStart(cursor);
                if (std.mem.eql(u8, key, "Data")) {
                    if (data_text != null or !std.mem.eql(u8, value.name, "data"))
                        return error.InvalidDmgPlist;
                    data_text = try readTextElement(cursor, value, "data");
                } else if (std.mem.eql(u8, key, "Name") or
                    std.mem.eql(u8, key, "CFName"))
                {
                    if (!std.mem.eql(u8, value.name, "string"))
                        return error.InvalidDmgPlist;
                    const text = try readTextElement(cursor, value, "string");
                    if (name_text == null or std.mem.eql(u8, key, "Name"))
                        name_text = text;
                } else {
                    try skipElement(cursor, value);
                }
            },
            .text => unreachable,
        }
    }
    const encoded = data_text orelse return error.InvalidDmgPlist;
    const decoder = std.base64.standard.decoderWithIgnore(" \r\n\t");
    var data = try allocator.alloc(u8, decoder.calcSizeUpperBound(encoded.len));
    errdefer allocator.free(data);
    const data_len = decoder.decode(data, encoded) catch
        return error.InvalidDmgPlist;
    if (data_len != data.len) data = try allocator.realloc(data, data_len);
    const name = try decodeXmlTextAlloc(allocator, name_text orelse "");
    return .{ .name = name, .data = data };
}

fn expectStart(cursor: *Cursor, expected: []const u8) Error!Tag {
    const token = (try cursor.nextStructural()) orelse return error.InvalidDmgPlist;
    return switch (token) {
        .start => |tag| if (std.mem.eql(u8, tag.name, expected))
            tag
        else
            error.InvalidDmgPlist,
        else => error.InvalidDmgPlist,
    };
}

fn nextStart(cursor: *Cursor) Error!Tag {
    const token = (try cursor.nextStructural()) orelse return error.InvalidDmgPlist;
    return switch (token) {
        .start => |tag| tag,
        else => error.InvalidDmgPlist,
    };
}

fn readTextElement(cursor: *Cursor, tag: Tag, expected: []const u8) Error![]const u8 {
    if (!std.mem.eql(u8, tag.name, expected) or tag.self_closing)
        return error.InvalidDmgPlist;
    const text_token = (try cursor.next()) orelse return error.InvalidDmgPlist;
    const text = switch (text_token) {
        .text => |value| value,
        .end => |name| {
            if (!std.mem.eql(u8, name, expected)) return error.InvalidDmgPlist;
            return "";
        },
        else => return error.InvalidDmgPlist,
    };
    const end_token = (try cursor.next()) orelse return error.InvalidDmgPlist;
    switch (end_token) {
        .end => |name| if (!std.mem.eql(u8, name, expected))
            return error.InvalidDmgPlist,
        else => return error.InvalidDmgPlist,
    }
    return std.mem.trim(u8, text, " \r\n\t");
}

fn skipElement(cursor: *Cursor, start: Tag) Error!void {
    if (start.self_closing) return;
    var depth: usize = 1;
    while (depth != 0) {
        const token = (try cursor.next()) orelse return error.InvalidDmgPlist;
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
            if (bracket_depth == 0) return error.InvalidDmgPlist;
            bracket_depth -= 1;
        } else if (byte == '>' and bracket_depth == 0) {
            return position + 1;
        }
    }
    return error.InvalidDmgPlist;
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
            return error.InvalidDmgPlist;
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
            return error.InvalidDmgPlist;
        try output.append(allocator, replacement);
        position = end + 1;
    }
    return output.toOwnedSlice(allocator);
}

fn isNameByte(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '-' or
        byte == ':' or byte == '.';
}
