const std = @import("std");

pub const Error = error{
    InvalidArArchive,
    IntegerOverflow,
    RangeOutOfBounds,
};

pub const Format = enum {
    gnu32,
    gnu64,

    pub fn memberName(self: Format) []const u8 {
        return switch (self) {
            .gnu32 => "/",
            .gnu64 => "/SYM64/",
        };
    }

    pub fn wordLen(self: Format) usize {
        return switch (self) {
            .gnu32 => @sizeOf(u32),
            .gnu64 => @sizeOf(u64),
        };
    }
};

pub fn formatFromMemberName(name: []const u8) ?Format {
    if (std.mem.eql(u8, name, "/")) return .gnu32;
    if (std.mem.eql(u8, name, "/SYM64/")) return .gnu64;
    return null;
}

pub const Symbol = struct {
    name: []const u8,
    member_header_offset: usize,
};

pub const Table = struct {
    bytes: []const u8,
    format: Format,
    count: usize,
    names_offset: usize,

    pub fn iterator(self: Table) Iterator {
        return .{
            .table = self,
            .name_offset = self.names_offset,
        };
    }

    pub fn symbolAt(self: Table, wanted: usize) Error!Symbol {
        if (wanted >= self.count) return error.RangeOutOfBounds;
        var iterator_value = self.iterator();
        var index: usize = 0;
        while (iterator_value.next()) |symbol| : (index += 1)
            if (index == wanted) return symbol;
        return error.InvalidArArchive;
    }

    pub fn find(self: Table, name: []const u8) ?Symbol {
        var iterator_value = self.iterator();
        while (iterator_value.next()) |symbol|
            if (std.mem.eql(u8, symbol.name, name)) return symbol;
        return null;
    }
};

pub const Iterator = struct {
    table: Table,
    index: usize = 0,
    name_offset: usize,

    pub fn next(self: *Iterator) ?Symbol {
        if (self.index >= self.table.count) return null;
        const member_header_offset = readOffset(self.table, self.index);
        const tail = self.table.bytes[self.name_offset..];
        const name_len = std.mem.indexOfScalar(u8, tail, 0).?;
        const symbol = Symbol{
            .name = tail[0..name_len],
            .member_header_offset = member_header_offset,
        };
        self.index += 1;
        self.name_offset += name_len + 1;
        return symbol;
    }
};

pub fn parse(bytes: []const u8, format: Format) Error!Table {
    const word_len = format.wordLen();
    if (bytes.len < word_len) return error.InvalidArArchive;
    const count_u64 = switch (format) {
        .gnu32 => std.mem.readInt(u32, bytes[0..4], .big),
        .gnu64 => std.mem.readInt(u64, bytes[0..8], .big),
    };
    const count = std.math.cast(usize, count_u64) orelse return error.IntegerOverflow;
    const offsets_len = std.math.mul(usize, count, word_len) catch
        return error.IntegerOverflow;
    const names_offset = std.math.add(usize, word_len, offsets_len) catch
        return error.IntegerOverflow;
    if (names_offset > bytes.len) return error.InvalidArArchive;
    for (0..count) |index| {
        const start = word_len + index * word_len;
        const value = switch (format) {
            .gnu32 => std.mem.readInt(u32, bytes[start..][0..4], .big),
            .gnu64 => std.mem.readInt(u64, bytes[start..][0..8], .big),
        };
        _ = std.math.cast(usize, value) orelse return error.IntegerOverflow;
    }

    var name_offset = names_offset;
    for (0..count) |_| {
        const tail = bytes[name_offset..];
        const name_len = std.mem.indexOfScalar(u8, tail, 0) orelse
            return error.InvalidArArchive;
        if (name_len == 0) return error.InvalidArArchive;
        name_offset = std.math.add(usize, name_offset, name_len + 1) catch
            return error.IntegerOverflow;
    }
    const padding = bytes[name_offset..];
    if (padding.len > 1 or (padding.len == 1 and padding[0] != 0))
        return error.InvalidArArchive;

    return .{
        .bytes = bytes,
        .format = format,
        .count = count,
        .names_offset = names_offset,
    };
}

fn readOffset(table: Table, index: usize) usize {
    const word_len = table.format.wordLen();
    const start = word_len + index * word_len;
    return switch (table.format) {
        .gnu32 => std.mem.readInt(u32, table.bytes[start..][0..4], .big),
        .gnu64 => @intCast(std.mem.readInt(u64, table.bytes[start..][0..8], .big)),
    };
}

test "GNU ar symbol tables parse 32-bit and 64-bit member offsets" {
    const cases = [_]struct {
        format: Format,
        bytes: []const u8,
    }{
        .{
            .format = .gnu32,
            .bytes = "\x00\x00\x00\x02" ++
                "\x00\x00\x00\x64" ++
                "\x00\x00\x01\x2c" ++
                "alpha\x00beta\x00\x00",
        },
        .{
            .format = .gnu64,
            .bytes = "\x00\x00\x00\x00\x00\x00\x00\x02" ++
                "\x00\x00\x00\x00\x00\x00\x00\x64" ++
                "\x00\x00\x00\x00\x00\x00\x01\x2c" ++
                "alpha\x00beta\x00\x00",
        },
    };
    for (cases) |case| {
        const table = try parse(case.bytes, case.format);
        try std.testing.expectEqual(@as(usize, 2), table.count);
        try std.testing.expectEqualStrings("alpha", (try table.symbolAt(0)).name);
        try std.testing.expectEqual(@as(usize, 100), (try table.symbolAt(0)).member_header_offset);
        const beta = table.find("beta").?;
        try std.testing.expectEqual(@as(usize, 300), beta.member_header_offset);
        try std.testing.expect(table.find("missing") == null);
        try std.testing.expectError(error.RangeOutOfBounds, table.symbolAt(2));
    }
}

test "GNU ar symbol table rejects malformed counts names and padding" {
    try std.testing.expectError(error.InvalidArArchive, parse("\x00\x00\x00", .gnu32));
    try std.testing.expectError(
        error.InvalidArArchive,
        parse("\x00\x00\x00\x01\x00\x00\x00\x08unterminated", .gnu32),
    );
    try std.testing.expectError(
        error.InvalidArArchive,
        parse("\x00\x00\x00\x01\x00\x00\x00\x08\x00", .gnu32),
    );
    try std.testing.expectError(
        error.InvalidArArchive,
        parse("\x00\x00\x00\x01\x00\x00\x00\x08name\x00xx", .gnu32),
    );
}
