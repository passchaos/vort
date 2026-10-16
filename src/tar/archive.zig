const std = @import("std");
const core = @import("../core.zig");
const sparse = @import("sparse.zig");

pub const Error = core.Error || sparse.Error || error{
    InvalidTarArchive,
    InvalidTarHeader,
    InvalidTarChecksum,
    UnsupportedTarEntryType,
    TarEntryNotFound,
};

pub const SparseFormat = sparse.Format;
pub const SparseExtent = sparse.Extent;
pub const SparseInfo = sparse.Info;

const block_size: usize = 512;

pub const Kind = enum {
    file,
    directory,
    symbolic_link,
    hard_link,
    other,
};

pub const Path = struct {
    prefix: []const u8 = "",
    name: []const u8,

    pub fn len(self: Path) usize {
        return self.prefix.len + @intFromBool(self.prefix.len != 0) + self.name.len;
    }

    pub fn eql(self: Path, expected: []const u8) bool {
        if (expected.len != self.len()) return false;
        if (self.prefix.len == 0) return std.mem.eql(u8, self.name, expected);
        return std.mem.eql(u8, self.prefix, expected[0..self.prefix.len]) and
            expected[self.prefix.len] == '/' and
            std.mem.eql(u8, self.name, expected[self.prefix.len + 1 ..]);
    }

    pub fn writeInto(self: Path, output: []u8) Error!usize {
        if (output.len < self.len()) return error.OutputTooSmall;
        @memcpy(output[0..self.prefix.len], self.prefix);
        var offset = self.prefix.len;
        if (self.prefix.len != 0) {
            output[offset] = '/';
            offset += 1;
        }
        @memcpy(output[offset..][0..self.name.len], self.name);
        return self.len();
    }

    pub fn alloc(self: Path, allocator: std.mem.Allocator) ![]u8 {
        const result = try allocator.alloc(u8, self.len());
        errdefer allocator.free(result);
        _ = try self.writeInto(result);
        return result;
    }

    pub fn isSafeRelative(self: Path) bool {
        if (self.len() == 0 or self.name.len == 0) return false;
        if (self.prefix.len != 0 and self.prefix[0] == '/') return false;
        if (self.prefix.len == 0 and self.name[0] == '/') return false;
        if (std.mem.indexOfScalar(u8, self.prefix, '\\') != null or
            std.mem.indexOfScalar(u8, self.name, '\\') != null) return false;
        if (self.len() >= 2 and std.ascii.isAlphabetic(self.byteAt(0)) and self.byteAt(1) == ':') return false;
        var component_start: usize = 0;
        const total_len = self.len();
        while (component_start < total_len) {
            const component_end = self.findSeparator(component_start) orelse total_len;
            if (component_end == component_start or
                (component_end - component_start == 1 and self.byteAt(component_start) == '.') or
                (component_end - component_start == 2 and
                    self.byteAt(component_start) == '.' and self.byteAt(component_start + 1) == '.'))
                return false;
            if (component_end == total_len) break;
            component_start = component_end + 1;
        }
        return true;
    }

    fn findSeparator(self: Path, start: usize) ?usize {
        for (start..self.len()) |index| if (self.byteAt(index) == '/') return index;
        return null;
    }

    fn byteAt(self: Path, index: usize) u8 {
        if (self.prefix.len == 0) return self.name[index];
        if (index < self.prefix.len) return self.prefix[index];
        if (index == self.prefix.len) return '/';
        return self.name[index - self.prefix.len - 1];
    }
};

pub const Entry = struct {
    path: Path,
    link_name: []const u8,
    kind: Kind,
    type_flag: u8,
    mode: u32,
    mtime: u64,
    size: usize,
    header_offset: usize,
    data_offset: usize,
    data: []const u8,
    sparse: ?SparseInfo = null,
};

pub const Archive = struct {
    bytes: []const u8,
    entry_count: usize,

    pub fn iterator(self: Archive) Iterator {
        return .{ .archive = self };
    }

    pub fn entryAt(self: Archive, index: usize) Error!Entry {
        if (index >= self.entry_count) return error.RangeOutOfBounds;
        var iterator_value = self.iterator();
        var current: usize = 0;
        while (try iterator_value.next()) |entry| : (current += 1)
            if (current == index) return entry;
        return error.InvalidTarArchive;
    }

    pub fn find(self: Archive, name: []const u8) Error!?Entry {
        var iterator_value = self.iterator();
        while (try iterator_value.next()) |entry|
            if (entry.path.eql(name)) return entry;
        return null;
    }

    pub fn entriesAlloc(self: Archive, allocator: std.mem.Allocator) ![]Entry {
        const entries = try allocator.alloc(Entry, self.entry_count);
        errdefer allocator.free(entries);
        var iterator_value = self.iterator();
        var index: usize = 0;
        while (try iterator_value.next()) |entry| : (index += 1) entries[index] = entry;
        if (index != entries.len) return error.InvalidTarArchive;
        return entries;
    }

    pub fn extractInto(self: Archive, entry: Entry, output: []u8) Error!usize {
        _ = self;
        switch (entry.kind) {
            .file => {},
            .directory => if (entry.size != 0) return error.InvalidTarArchive,
            else => return error.UnsupportedTarEntryType,
        }
        if (entry.sparse) |sparse_info| return sparse_info.extractInto(output);
        if (output.len < entry.size) return error.OutputTooSmall;
        if (entry.data.len != entry.size) return error.InvalidTarArchive;
        @memcpy(output[0..entry.size], entry.data);
        return entry.size;
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
        if (entry.size > max_output_len) return error.OutputLimitExceeded;
        const output = try allocator.alloc(u8, entry.size);
        errdefer allocator.free(output);
        const written = try self.extractInto(entry, output);
        if (written != output.len) return error.SizeMismatch;
        return output;
    }

    pub fn extractByNameAlloc(self: Archive, allocator: std.mem.Allocator, name: []const u8) ![]u8 {
        return self.extractByNameAllocLimited(allocator, name, std.math.maxInt(usize));
    }

    pub fn extractByNameAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        name: []const u8,
        max_output_len: usize,
    ) ![]u8 {
        const entry = (try self.find(name)) orelse return error.TarEntryNotFound;
        return self.extractAllocLimited(allocator, entry, max_output_len);
    }
};

pub const Attributes = struct {
    path: ?[]const u8 = null,
    link_path: ?[]const u8 = null,
    size: ?u64 = null,
    sparse_major: ?u64 = null,
    sparse_minor: ?u64 = null,
    sparse_name: ?[]const u8 = null,
    sparse_size: ?u64 = null,
    sparse_numblocks: ?u64 = null,
    sparse_map: ?[]const u8 = null,
    sparse_pax_00: ?[]const u8 = null,
};

pub const Iterator = struct {
    archive: Archive,
    offset: usize = 0,
    finished: bool = false,
    global: Attributes = .{},
    pending: Attributes = .{},

    pub fn next(self: *Iterator) Error!?Entry {
        if (self.finished) return null;
        while (true) {
            if (self.offset == self.archive.bytes.len) {
                if (hasPending(self.pending)) return error.InvalidTarArchive;
                self.finished = true;
                return null;
            }
            const header_end = try checkedEnd(self.offset, block_size, self.archive.bytes.len);
            const header = self.archive.bytes[self.offset..header_end];
            if (allZero(header)) {
                for (self.archive.bytes[self.offset..]) |byte|
                    if (byte != 0) return error.InvalidTarArchive;
                self.finished = true;
                return null;
            }
            try validateChecksum(header);

            const header_size = try parseNumber(header[124..136]);
            const type_flag = header[156];
            var data_start = header_end;
            if (type_flag == 'S') {
                if (hasSparse(self.pending)) return error.InvalidTarHeader;
                var extended = header[482];
                if (extended > 1) return error.InvalidTarHeader;
                while (extended != 0) {
                    const extension_end = try checkedEnd(
                        data_start,
                        block_size,
                        self.archive.bytes.len,
                    );
                    extended = self.archive.bytes[data_start + 504];
                    if (extended > 1) return error.InvalidTarHeader;
                    data_start = extension_end;
                }
            }
            const header_data_size = try u64ToUsize(header_size);
            const header_data_end = try checkedEnd(data_start, header_data_size, self.archive.bytes.len);
            const next_offset = try paddedEnd(header_data_end, self.archive.bytes.len);
            switch (type_flag) {
                'x' => {
                    try parsePax(self.archive.bytes[data_start..header_data_end], &self.pending);
                    self.offset = next_offset;
                    continue;
                },
                'g' => {
                    try parsePax(self.archive.bytes[data_start..header_data_end], &self.global);
                    if (hasSparse(self.global)) return error.InvalidTarHeader;
                    self.offset = next_offset;
                    continue;
                },
                'L' => {
                    self.pending.path = trimExtensionString(self.archive.bytes[data_start..header_data_end]);
                    self.offset = next_offset;
                    continue;
                },
                'K' => {
                    self.pending.link_path = trimExtensionString(self.archive.bytes[data_start..header_data_end]);
                    self.offset = next_offset;
                    continue;
                },
                else => {},
            }

            const stored_payload = self.archive.bytes[data_start..header_data_end];
            const sparse_info = if (type_flag == 'S') old: {
                const logical_size = try u64ToUsize(try parseNumber(header[483..495]));
                break :old try sparse.parseOldGnu(
                    self.archive.bytes[self.offset + 386 .. data_start],
                    logical_size,
                    stored_payload,
                );
            } else try parseSparseInfo(self.pending, stored_payload);
            const actual_size_u64 = if (sparse_info) |info|
                info.logical_size
            else
                self.pending.size orelse self.global.size orelse header_size;
            const actual_size = try u64ToUsize(actual_size_u64);
            const data_end = if (sparse_info == null)
                try checkedEnd(data_start, actual_size, self.archive.bytes.len)
            else
                header_data_end;
            self.offset = try paddedEnd(data_end, self.archive.bytes.len);
            const header_path = pathFromHeader(header);
            const path = if (self.pending.sparse_name orelse self.pending.path orelse self.global.path) |name|
                Path{ .name = name }
            else
                header_path;
            const link_name = self.pending.link_path orelse self.global.link_path orelse headerString(header[157..257]);
            const mode_u64 = try parseNumber(header[100..108]);
            if (mode_u64 > std.math.maxInt(u32)) return error.InvalidTarHeader;
            if (sparse_info != null and kindFromType(type_flag) != .file)
                return error.InvalidTarHeader;
            const entry_data = if (sparse_info) |info| info.data else self.archive.bytes[data_start..data_end];
            const entry = Entry{
                .path = path,
                .link_name = link_name,
                .kind = kindFromType(type_flag),
                .type_flag = type_flag,
                .mode = @intCast(mode_u64),
                .mtime = try parseNumber(header[136..148]),
                .size = actual_size,
                .header_offset = data_start - block_size,
                .data_offset = data_start + (stored_payload.len - entry_data.len),
                .data = entry_data,
                .sparse = sparse_info,
            };
            self.pending = .{};
            return entry;
        }
    }
};

pub fn parse(bytes: []const u8) Error!Archive {
    var archive = Archive{ .bytes = bytes, .entry_count = 0 };
    var iterator_value = archive.iterator();
    while (try iterator_value.next()) |_| archive.entry_count += 1;
    return archive;
}

pub fn extractEntryInto(bytes: []const u8, index: usize, output: []u8) Error!usize {
    const archive = try parse(bytes);
    return archive.extractInto(try archive.entryAt(index), output);
}

pub fn extractEntryAlloc(allocator: std.mem.Allocator, bytes: []const u8, index: usize) ![]u8 {
    const archive = try parse(bytes);
    return archive.extractAlloc(allocator, try archive.entryAt(index));
}

pub fn extractByNameAlloc(allocator: std.mem.Allocator, bytes: []const u8, name: []const u8) ![]u8 {
    return (try parse(bytes)).extractByNameAlloc(allocator, name);
}

pub fn extractByNameAllocLimited(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    name: []const u8,
    max_output_len: usize,
) ![]u8 {
    return (try parse(bytes)).extractByNameAllocLimited(allocator, name, max_output_len);
}

pub fn pathFromHeader(header: []const u8) Path {
    const name = headerString(header[0..100]);
    const magic = header[257..263];
    const prefix = if (std.mem.eql(u8, magic[0..5], "ustar") and
        (magic[5] == 0 or magic[5] == ' '))
        headerString(header[345..500])
    else
        "";
    return .{ .prefix = prefix, .name = name };
}

pub fn kindFromType(type_flag: u8) Kind {
    return switch (type_flag) {
        0, '0', '7', 'S' => .file,
        '1' => .hard_link,
        '2' => .symbolic_link,
        '5' => .directory,
        else => .other,
    };
}

pub fn parsePax(payload: []const u8, attributes: *Attributes) Error!void {
    var offset: usize = 0;
    while (offset < payload.len) {
        const space = std.mem.findScalarPos(u8, payload, offset, ' ') orelse return error.InvalidTarHeader;
        const record_len = std.fmt.parseInt(usize, payload[offset..space], 10) catch return error.InvalidTarHeader;
        if (record_len == 0) return error.InvalidTarHeader;
        const end = try checkedEnd(offset, record_len, payload.len);
        if (end <= space + 1 or payload[end - 1] != '\n') return error.InvalidTarHeader;
        const record = payload[space + 1 .. end - 1];
        const equals = std.mem.findScalarPos(u8, record, 0, '=') orelse return error.InvalidTarHeader;
        const key = record[0..equals];
        const value = record[equals + 1 ..];
        if (std.mem.eql(u8, key, "path")) {
            if (value.len == 0 or std.mem.indexOfScalar(u8, value, 0) != null) return error.InvalidTarHeader;
            attributes.path = value;
        } else if (std.mem.eql(u8, key, "linkpath")) {
            if (std.mem.indexOfScalar(u8, value, 0) != null) return error.InvalidTarHeader;
            attributes.link_path = value;
        } else if (std.mem.eql(u8, key, "size")) {
            attributes.size = std.fmt.parseInt(u64, value, 10) catch return error.InvalidTarHeader;
        } else if (std.mem.eql(u8, key, "GNU.sparse.major")) {
            attributes.sparse_major = std.fmt.parseInt(u64, value, 10) catch return error.InvalidTarHeader;
        } else if (std.mem.eql(u8, key, "GNU.sparse.minor")) {
            attributes.sparse_minor = std.fmt.parseInt(u64, value, 10) catch return error.InvalidTarHeader;
        } else if (std.mem.eql(u8, key, "GNU.sparse.name")) {
            if (value.len == 0 or std.mem.indexOfScalar(u8, value, 0) != null)
                return error.InvalidTarHeader;
            attributes.sparse_name = value;
        } else if (std.mem.eql(u8, key, "GNU.sparse.size") or
            std.mem.eql(u8, key, "GNU.sparse.realsize"))
        {
            attributes.sparse_size = std.fmt.parseInt(u64, value, 10) catch return error.InvalidTarHeader;
        } else if (std.mem.eql(u8, key, "GNU.sparse.numblocks")) {
            attributes.sparse_numblocks = std.fmt.parseInt(u64, value, 10) catch return error.InvalidTarHeader;
        } else if (std.mem.eql(u8, key, "GNU.sparse.map")) {
            if (value.len == 0) return error.InvalidTarHeader;
            attributes.sparse_map = value;
        } else if (std.mem.eql(u8, key, "GNU.sparse.offset") or
            std.mem.eql(u8, key, "GNU.sparse.numbytes"))
        {
            attributes.sparse_pax_00 = payload;
        }
        offset = end;
    }
}

pub fn hasPending(attributes: Attributes) bool {
    return attributes.path != null or attributes.link_path != null or attributes.size != null or
        hasSparse(attributes);
}

pub fn hasSparse(attributes: Attributes) bool {
    return attributes.sparse_major != null or attributes.sparse_minor != null or
        attributes.sparse_name != null or attributes.sparse_size != null or
        attributes.sparse_numblocks != null or attributes.sparse_map != null or
        attributes.sparse_pax_00 != null;
}

fn parseSparseInfo(attributes: Attributes, payload: []const u8) Error!?SparseInfo {
    if (!hasSparse(attributes)) return null;
    if (attributes.size != null) return error.InvalidTarHeader;
    const logical_size = try u64ToUsize(attributes.sparse_size orelse
        return error.InvalidTarHeader);
    if (attributes.sparse_major) |major| {
        if (major != 1 or attributes.sparse_minor != 0 or
            attributes.sparse_name == null or attributes.sparse_map != null or
            attributes.sparse_numblocks != null or attributes.sparse_pax_00 != null)
            return error.UnsupportedTarEntryType;
        return try sparse.parsePax10(payload, logical_size);
    }
    if (attributes.sparse_minor != null) return error.InvalidTarHeader;
    const declared_count = if (attributes.sparse_numblocks) |count|
        try u64ToUsize(count)
    else
        null;
    if (attributes.sparse_pax_00) |pax_payload| {
        if (attributes.sparse_map != null) return error.InvalidTarHeader;
        return try sparse.parsePax00(
            pax_payload,
            declared_count,
            logical_size,
            payload,
        );
    }
    const map = attributes.sparse_map orelse return error.InvalidTarHeader;
    return try sparse.parsePax01(map, declared_count, logical_size, payload);
}

pub fn trimExtensionString(value: []const u8) []const u8 {
    const nul = std.mem.indexOfScalar(u8, value, 0) orelse value.len;
    return std.mem.trimEnd(u8, value[0..nul], "\n");
}

pub fn headerString(field: []const u8) []const u8 {
    return field[0 .. std.mem.indexOfScalar(u8, field, 0) orelse field.len];
}

pub fn parseNumber(field: []const u8) Error!u64 {
    if (field.len == 0) return error.InvalidTarHeader;
    if (field[0] & 0x80 != 0) {
        if (field[0] & 0x40 != 0) return error.UnsupportedTarEntryType;
        var value: u64 = field[0] & 0x3f;
        for (field[1..]) |byte|
            value = std.math.add(u64, std.math.mul(u64, value, 256) catch return error.IntegerOverflow, byte) catch
                return error.IntegerOverflow;
        return value;
    }
    const trimmed = std.mem.trim(u8, field, " \x00");
    if (trimmed.len == 0) return 0;
    for (trimmed) |byte| if (byte < '0' or byte > '7') return error.InvalidTarHeader;
    return std.fmt.parseInt(u64, trimmed, 8) catch return error.IntegerOverflow;
}

pub fn validateChecksum(header: []const u8) Error!void {
    const expected = try parseNumber(header[148..156]);
    var actual: u64 = 0;
    for (header, 0..) |byte, index|
        actual += if (index >= 148 and index < 156) ' ' else byte;
    if (actual != expected) return error.InvalidTarChecksum;
}

pub fn allZero(bytes: []const u8) bool {
    for (bytes) |byte| if (byte != 0) return false;
    return true;
}

pub fn u64ToUsize(value: u64) Error!usize {
    return std.math.cast(usize, value) orelse error.UnsupportedTarEntryType;
}

fn paddedEnd(data_end: usize, limit: usize) Error!usize {
    const remainder = data_end % block_size;
    return checkedEnd(data_end, if (remainder == 0) 0 else block_size - remainder, limit);
}

fn checkedEnd(start: usize, len: usize, limit: usize) Error!usize {
    const end = std.math.add(usize, start, len) catch return error.IntegerOverflow;
    if (end > limit) return error.TruncatedFrame;
    return end;
}
