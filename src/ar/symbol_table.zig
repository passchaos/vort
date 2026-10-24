const std = @import("std");

pub const Error = error{
    InvalidArArchive,
    IntegerOverflow,
    RangeOutOfBounds,
};

pub const Format = enum {
    gnu32,
    gnu64,
    bsd32,
    bsd32_sorted,
    bsd64,
    bsd64_sorted,

    pub fn memberName(self: Format) []const u8 {
        return switch (self) {
            .gnu32 => "/",
            .gnu64 => "/SYM64/",
            .bsd32 => "__.SYMDEF",
            .bsd32_sorted => "__.SYMDEF SORTED",
            .bsd64 => "__.SYMDEF_64",
            .bsd64_sorted => "__.SYMDEF_64 SORTED",
        };
    }

    pub fn wordLen(self: Format) usize {
        return switch (self) {
            .gnu32, .bsd32, .bsd32_sorted => @sizeOf(u32),
            .gnu64, .bsd64, .bsd64_sorted => @sizeOf(u64),
        };
    }

    pub fn isBsd(self: Format) bool {
        return switch (self) {
            .gnu32, .gnu64 => false,
            .bsd32, .bsd32_sorted, .bsd64, .bsd64_sorted => true,
        };
    }

    pub fn sorted(self: Format) bool {
        return switch (self) {
            .bsd32_sorted, .bsd64_sorted => true,
            else => false,
        };
    }
};

pub fn formatFromMemberName(name: []const u8) ?Format {
    if (std.mem.eql(u8, name, "/")) return .gnu32;
    if (std.mem.eql(u8, name, "/SYM64/")) return .gnu64;
    if (std.mem.eql(u8, name, "__.SYMDEF")) return .bsd32;
    if (std.mem.eql(u8, name, "__.SYMDEF SORTED")) return .bsd32_sorted;
    if (std.mem.eql(u8, name, "__.SYMDEF_64")) return .bsd64;
    if (std.mem.eql(u8, name, "__.SYMDEF_64 SORTED")) return .bsd64_sorted;
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
        const member_header_offset = readMemberOffset(self.table, self.index);
        const symbol_name_offset = if (self.table.format.isBsd())
            self.table.names_offset + readBsdStringOffset(self.table, self.index)
        else
            self.name_offset;
        const tail = self.table.bytes[symbol_name_offset..];
        const name_len = std.mem.indexOfScalar(u8, tail, 0).?;
        const symbol = Symbol{
            .name = tail[0..name_len],
            .member_header_offset = member_header_offset,
        };
        self.index += 1;
        if (!self.table.format.isBsd()) self.name_offset += name_len + 1;
        return symbol;
    }
};

pub fn parse(bytes: []const u8, format: Format) Error!Table {
    return if (format.isBsd()) parseBsd(bytes, format) else parseGnu(bytes, format);
}

fn parseGnu(bytes: []const u8, format: Format) Error!Table {
    const word_len = format.wordLen();
    if (bytes.len < word_len) return error.InvalidArArchive;
    const count_u64 = switch (format) {
        .gnu32 => std.mem.readInt(u32, bytes[0..4], .big),
        .gnu64 => std.mem.readInt(u64, bytes[0..8], .big),
        else => unreachable,
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
            else => unreachable,
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

fn parseBsd(bytes: []const u8, format: Format) Error!Table {
    const word_len = format.wordLen();
    if (bytes.len < word_len * 2) return error.InvalidArArchive;
    const ranlib_bytes_u64 = readLittleWord(bytes, 0, format);
    const record_len = word_len * 2;
    if (ranlib_bytes_u64 % record_len != 0) return error.InvalidArArchive;
    const ranlib_bytes = std.math.cast(usize, ranlib_bytes_u64) orelse
        return error.IntegerOverflow;
    const count = ranlib_bytes / record_len;
    const string_size_offset = std.math.add(usize, word_len, ranlib_bytes) catch
        return error.IntegerOverflow;
    const names_offset = std.math.add(usize, string_size_offset, word_len) catch
        return error.IntegerOverflow;
    if (names_offset > bytes.len) return error.InvalidArArchive;
    const string_size_u64 = readLittleWord(bytes, string_size_offset, format);
    const string_size = std.math.cast(usize, string_size_u64) orelse
        return error.IntegerOverflow;
    const names_end = std.math.add(usize, names_offset, string_size) catch
        return error.IntegerOverflow;
    if (names_end > bytes.len) return error.InvalidArArchive;
    const padding = bytes[names_end..];
    if (padding.len > 7) return error.InvalidArArchive;
    for (padding) |byte| if (byte != 0) return error.InvalidArArchive;

    for (0..count) |index| {
        const record_offset = word_len + index * record_len;
        const string_offset_u64 = readLittleWord(bytes, record_offset, format);
        const string_offset = std.math.cast(usize, string_offset_u64) orelse
            return error.IntegerOverflow;
        if (string_offset >= string_size) return error.InvalidArArchive;
        const tail = bytes[names_offset + string_offset .. names_end];
        const name_len = std.mem.indexOfScalar(u8, tail, 0) orelse
            return error.InvalidArArchive;
        if (name_len == 0) return error.InvalidArArchive;
        const member_offset_u64 = readLittleWord(bytes, record_offset + word_len, format);
        _ = std.math.cast(usize, member_offset_u64) orelse return error.IntegerOverflow;
    }

    return .{
        .bytes = bytes,
        .format = format,
        .count = count,
        .names_offset = names_offset,
    };
}

fn readMemberOffset(table: Table, index: usize) usize {
    const word_len = table.format.wordLen();
    const start = if (table.format.isBsd())
        word_len + index * word_len * 2 + word_len
    else
        word_len + index * word_len;
    return switch (table.format) {
        .gnu32 => std.mem.readInt(u32, table.bytes[start..][0..4], .big),
        .gnu64 => @intCast(std.mem.readInt(u64, table.bytes[start..][0..8], .big)),
        .bsd32, .bsd32_sorted => std.mem.readInt(u32, table.bytes[start..][0..4], .little),
        .bsd64, .bsd64_sorted => @intCast(std.mem.readInt(u64, table.bytes[start..][0..8], .little)),
    };
}

fn readBsdStringOffset(table: Table, index: usize) usize {
    const word_len = table.format.wordLen();
    const start = word_len + index * word_len * 2;
    return @intCast(readLittleWord(table.bytes, start, table.format));
}

fn readLittleWord(bytes: []const u8, offset: usize, format: Format) u64 {
    return switch (format) {
        .bsd32, .bsd32_sorted => std.mem.readInt(u32, bytes[offset..][0..4], .little),
        .bsd64, .bsd64_sorted => std.mem.readInt(u64, bytes[offset..][0..8], .little),
        else => unreachable,
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
