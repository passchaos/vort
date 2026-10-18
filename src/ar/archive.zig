const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidArArchive,
    UnsupportedArFeature,
    ArEntryNotFound,
    ArEntryRequiresResolver,
    ArEntryNotExternal,
};

pub const signature = "!<arch>\n";
pub const thin_signature = "!<thin>\n";
pub const header_size: usize = 60;

pub const Entry = struct {
    name: []const u8,
    data_offset: usize,
    size: usize,
    header_offset: usize,
    stored_size: usize,
    next_offset: usize,
    timestamp: u64,
    owner: u32,
    group: u32,
    mode: u32,
    safe_path: bool,
    external: bool,
};

pub const Archive = struct {
    bytes: []const u8,
    entry_count: usize,
    string_table: ?[]const u8,
    thin: bool,

    pub fn iterator(self: Archive) Iterator {
        return .{ .archive = self, .offset = signature.len };
    }

    pub fn entryAt(self: Archive, wanted: usize) Error!Entry {
        if (wanted >= self.entry_count) return error.RangeOutOfBounds;
        var iterator_value = self.iterator();
        var index: usize = 0;
        while (try iterator_value.next()) |entry| : (index += 1)
            if (index == wanted) return entry;
        return error.InvalidArArchive;
    }

    pub fn find(self: Archive, name: []const u8) Error!?Entry {
        var iterator_value = self.iterator();
        while (try iterator_value.next()) |entry|
            if (std.mem.eql(u8, entry.name, name)) return entry;
        return null;
    }

    pub fn extractInto(self: Archive, entry: Entry, output: []u8) Error!usize {
        const canonical = try self.canonicalEntry(entry);
        if (canonical.external) return error.ArEntryRequiresResolver;
        if (output.len < canonical.size) return error.OutputTooSmall;
        @memcpy(output[0..canonical.size], self.bytes[canonical.data_offset..][0..canonical.size]);
        return canonical.size;
    }

    pub fn extractAlloc(self: Archive, allocator: std.mem.Allocator, entry: Entry) ![]u8 {
        return self.extractAllocLimited(allocator, entry, std.math.maxInt(usize));
    }

    pub fn extractAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        entry: Entry,
        max_output_len: usize,
    ) ![]u8 {
        const canonical = try self.canonicalEntry(entry);
        if (canonical.external) return error.ArEntryRequiresResolver;
        if (canonical.size > max_output_len) return error.OutputLimitExceeded;
        return allocator.dupe(u8, self.bytes[canonical.data_offset..][0..canonical.size]);
    }

    pub fn extractByNameAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        name: []const u8,
        max_output_len: usize,
    ) ![]u8 {
        const entry = (try self.find(name)) orelse return error.ArEntryNotFound;
        return self.extractAllocLimited(allocator, entry, max_output_len);
    }

    pub fn extractThinInto(
        self: Archive,
        entry: Entry,
        source: []const u8,
        output: []u8,
    ) Error!usize {
        const canonical = try self.canonicalEntry(entry);
        if (!canonical.external) return error.ArEntryNotExternal;
        if (source.len < canonical.size) return error.SizeMismatch;
        if (output.len < canonical.size) return error.OutputTooSmall;
        @memcpy(output[0..canonical.size], source[0..canonical.size]);
        return canonical.size;
    }

    pub fn extractThinAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        entry: Entry,
        source: []const u8,
        max_output_len: usize,
    ) ![]u8 {
        const canonical = try self.canonicalEntry(entry);
        if (!canonical.external) return error.ArEntryNotExternal;
        if (canonical.size > max_output_len) return error.OutputLimitExceeded;
        if (source.len < canonical.size) return error.SizeMismatch;
        return allocator.dupe(u8, source[0..canonical.size]);
    }

    pub fn extractThinAlloc(
        self: Archive,
        allocator: std.mem.Allocator,
        entry: Entry,
        source: []const u8,
    ) ![]u8 {
        return self.extractThinAllocLimited(
            allocator,
            entry,
            source,
            std.math.maxInt(usize),
        );
    }

    pub fn extractThinByNameAlloc(
        self: Archive,
        allocator: std.mem.Allocator,
        name: []const u8,
        source: []const u8,
    ) ![]u8 {
        return self.extractThinByNameAllocLimited(
            allocator,
            name,
            source,
            std.math.maxInt(usize),
        );
    }

    pub fn extractThinByNameAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        name: []const u8,
        source: []const u8,
        max_output_len: usize,
    ) ![]u8 {
        const entry = (try self.find(name)) orelse return error.ArEntryNotFound;
        return self.extractThinAllocLimited(allocator, entry, source, max_output_len);
    }

    fn canonicalEntry(self: Archive, entry: Entry) Error!Entry {
        const parsed = (try parseMember(self.bytes, entry.header_offset, self.string_table, self.thin)).entry orelse
            return error.InvalidArArchive;
        if (!sameEntry(parsed, entry)) return error.InvalidArArchive;
        return parsed;
    }
};

pub const Iterator = struct {
    archive: Archive,
    offset: usize,

    pub fn next(self: *Iterator) Error!?Entry {
        while (self.offset < self.archive.bytes.len) {
            const member = try parseMember(
                self.archive.bytes,
                self.offset,
                self.archive.string_table,
                self.archive.thin,
            );
            self.offset = member.next_offset;
            if (member.entry) |entry| return entry;
        }
        return null;
    }
};

const ParsedMember = struct {
    entry: ?Entry,
    next_offset: usize,
    string_table: ?[]const u8 = null,
};

pub fn parse(bytes: []const u8) Error!Archive {
    const thin = bytes.len >= thin_signature.len and
        std.mem.eql(u8, bytes[0..thin_signature.len], thin_signature);
    if (!thin and (bytes.len < signature.len or
        !std.mem.eql(u8, bytes[0..signature.len], signature)))
        return error.InvalidMagic;
    var offset: usize = signature.len;
    var entry_count: usize = 0;
    var string_table: ?[]const u8 = null;
    while (offset < bytes.len) {
        const member = try parseMember(bytes, offset, string_table, thin);
        if (member.string_table) |table| string_table = table;
        if (member.entry != null) entry_count = std.math.add(usize, entry_count, 1) catch
            return error.IntegerOverflow;
        offset = member.next_offset;
    }
    if (offset != bytes.len) return error.InvalidArArchive;
    return .{
        .bytes = bytes,
        .entry_count = entry_count,
        .string_table = string_table,
        .thin = thin,
    };
}

fn parseMember(
    bytes: []const u8,
    offset: usize,
    string_table: ?[]const u8,
    thin: bool,
) Error!ParsedMember {
    const header_end = try checkedEnd(offset, header_size, bytes.len);
    const header = bytes[offset..header_end];
    if (!std.mem.eql(u8, header[58..60], "`\n")) return error.InvalidArArchive;
    const timestamp = try parseNumber(u64, header[16..28], 10);
    const owner = try parseNumber(u32, header[28..34], 10);
    const group = try parseNumber(u32, header[34..40], 10);
    const mode = try parseNumber(u32, header[40..48], 8);
    const stored_size = try parseNumber(usize, header[48..58], 10);
    const raw_name = std.mem.trimEnd(u8, header[0..16], " ");
    if (raw_name.len == 0) return error.InvalidArArchive;
    if (thin and std.mem.startsWith(u8, raw_name, "#1/"))
        return error.UnsupportedArFeature;
    const embedded = !thin or std.mem.eql(u8, raw_name, "//") or isSymbolTable(raw_name);
    const physical_size = if (embedded) stored_size else 0;
    const stored_end = try checkedEnd(header_end, physical_size, bytes.len);
    var next_offset = stored_end;
    if (physical_size & 1 != 0) {
        next_offset = try checkedEnd(stored_end, 1, bytes.len);
        if (bytes[stored_end] != '\n') return error.InvalidArArchive;
    }
    if (std.mem.eql(u8, raw_name, "//")) return .{
        .entry = null,
        .next_offset = next_offset,
        .string_table = bytes[header_end..stored_end],
    };
    if (isSymbolTable(raw_name)) return .{ .entry = null, .next_offset = next_offset };

    var name: []const u8 = undefined;
    var data_offset = header_end;
    var data_size = stored_size;
    if (std.mem.startsWith(u8, raw_name, "#1/")) {
        const name_len = try parseDecimalSlice(usize, raw_name[3..]);
        if (name_len == 0 or name_len > stored_size) return error.InvalidArArchive;
        name = bytes[header_end..][0..name_len];
        if (std.mem.indexOfScalar(u8, name, 0) != null or
            std.mem.indexOfScalar(u8, name, '\n') != null)
            return error.InvalidArArchive;
        data_offset += name_len;
        data_size -= name_len;
    } else if (raw_name[0] == '/' and raw_name.len > 1 and
        std.ascii.isDigit(raw_name[1]))
    {
        const table = string_table orelse return error.InvalidArArchive;
        const name_offset = try parseDecimalSlice(usize, raw_name[1..]);
        if (name_offset >= table.len) return error.InvalidArArchive;
        const tail = table[name_offset..];
        const slash = std.mem.indexOf(u8, tail, "/\n") orelse
            std.mem.indexOfScalar(u8, tail, 0) orelse return error.InvalidArArchive;
        if (slash == 0) return error.InvalidArArchive;
        name = tail[0..slash];
    } else {
        name = if (raw_name.len > 1 and raw_name[raw_name.len - 1] == '/')
            raw_name[0 .. raw_name.len - 1]
        else
            raw_name;
    }
    if (name.len == 0) return error.InvalidArArchive;
    return .{
        .entry = .{
            .name = name,
            .data_offset = data_offset,
            .size = data_size,
            .header_offset = offset,
            .stored_size = physical_size,
            .next_offset = next_offset,
            .timestamp = timestamp,
            .owner = owner,
            .group = group,
            .mode = mode,
            .safe_path = isSafePath(name),
            .external = thin,
        },
        .next_offset = next_offset,
    };
}

fn isSymbolTable(name: []const u8) bool {
    return std.mem.eql(u8, name, "/") or std.mem.eql(u8, name, "/SYM64/") or
        std.mem.eql(u8, name, "__.SYMDEF") or
        std.mem.eql(u8, name, "__.SYMDEF SORTED");
}

fn parseNumber(comptime T: type, field: []const u8, base: u8) Error!T {
    const value = std.mem.trim(u8, field, " ");
    if (value.len == 0) return 0;
    return std.fmt.parseInt(T, value, base) catch error.InvalidArArchive;
}

fn parseDecimalSlice(comptime T: type, value: []const u8) Error!T {
    if (value.len == 0) return error.InvalidArArchive;
    for (value) |byte| if (!std.ascii.isDigit(byte)) return error.InvalidArArchive;
    return std.fmt.parseInt(T, value, 10) catch error.InvalidArArchive;
}

fn checkedEnd(start: usize, size: usize, limit: usize) Error!usize {
    const end = std.math.add(usize, start, size) catch return error.IntegerOverflow;
    if (end > limit) return error.TruncatedFrame;
    return end;
}

fn sameEntry(a: Entry, b: Entry) bool {
    return std.mem.eql(u8, a.name, b.name) and a.data_offset == b.data_offset and
        a.size == b.size and a.header_offset == b.header_offset and
        a.stored_size == b.stored_size and a.next_offset == b.next_offset and
        a.timestamp == b.timestamp and a.owner == b.owner and a.group == b.group and
        a.mode == b.mode and a.safe_path == b.safe_path and a.external == b.external;
}

pub fn isSafePath(path: []const u8) bool {
    if (path.len == 0 or path[0] == '/' or path[0] == '\\') return false;
    var components = std.mem.splitAny(u8, path, "/\\");
    while (components.next()) |component| {
        if (component.len == 0 or std.mem.eql(u8, component, ".") or
            std.mem.eql(u8, component, ".."))
            return false;
    }
    return true;
}

test "ar parser rejects thin truncated and malformed archives" {
    try std.testing.expectError(error.InvalidMagic, parse(""));
    const empty_thin = try parse(thin_signature);
    try std.testing.expect(empty_thin.thin);
    try std.testing.expectEqual(@as(usize, 0), empty_thin.entry_count);
    try std.testing.expectError(error.TruncatedFrame, parse(signature ++ "short"));
}
