const std = @import("std");
const core = @import("../core.zig");
const format = @import("format.zig");

pub const Error = core.Error || format.Error || std.mem.Allocator.Error;

pub const Attribute = struct {
    name: []const u8,
    value: []const u8,
};

pub const Attributes = struct {
    allocator: std.mem.Allocator,
    storage: []u8,
    entries: []Attribute,

    pub fn deinit(self: *Attributes) void {
        self.allocator.free(self.entries);
        self.allocator.free(self.storage);
        self.* = undefined;
    }

    pub fn find(self: Attributes, name: []const u8) ?Attribute {
        for (self.entries) |entry|
            if (std.mem.eql(u8, entry.name, name)) return entry;
        return null;
    }
};

const ibody_header_size: usize = 12;
const entry_header_size: usize = 4;

const EncodedName = struct {
    index: u8,
    suffix: []const u8,
};

const WireAttribute = struct {
    prefix: []const u8,
    suffix: []const u8,
    value: []const u8,
    padded_size: usize,

    fn nameLen(self: WireAttribute) Error!usize {
        return checkedAdd(self.prefix.len, self.suffix.len);
    }
};

const Scanner = struct {
    image: []const u8,
    block_size: usize,
    xattr_block: u32,
    ibody: []const u8,
    shared_count: usize,
    shared_index: usize = 0,
    inline_position: usize,

    fn init(
        image: []const u8,
        block_size: usize,
        xattr_block: u32,
        ibody_start: usize,
        ibody_size: usize,
    ) Error!Scanner {
        if (ibody_size == 0) return .{
            .image = image,
            .block_size = block_size,
            .xattr_block = xattr_block,
            .ibody = &.{},
            .shared_count = 0,
            .inline_position = 0,
        };
        if (ibody_size < ibody_header_size or ibody_size & 3 != 0)
            return error.InvalidErofs;
        const ibody_end = try checkedEnd(ibody_start, ibody_size, image.len);
        const ibody = image[ibody_start..ibody_end];
        for (ibody[5..ibody_header_size]) |reserved|
            if (reserved != 0) return error.InvalidErofs;
        const shared_count: usize = ibody[4];
        const inline_position = try checkedAdd(
            ibody_header_size,
            try checkedMul(shared_count, 4),
        );
        if (inline_position > ibody.len) return error.InvalidErofs;
        return .{
            .image = image,
            .block_size = block_size,
            .xattr_block = xattr_block,
            .ibody = ibody,
            .shared_count = shared_count,
            .inline_position = inline_position,
        };
    }

    fn next(self: *Scanner) Error!?WireAttribute {
        if (self.shared_index < self.shared_count) {
            const id_offset = ibody_header_size + self.shared_index * 4;
            const id = format.readU32(self.ibody, id_offset);
            self.shared_index += 1;
            const shared_base = try checkedMul(self.xattr_block, self.block_size);
            const shared_offset = try checkedAdd(shared_base, try checkedMul(id, 4));
            return try parseEntry(self.image, shared_offset, self.image.len);
        }
        if (self.inline_position == self.ibody.len) return null;
        const remaining = self.ibody[self.inline_position..];
        if (allZero(remaining)) {
            self.inline_position = self.ibody.len;
            return null;
        }
        const entry = try parseEntry(self.ibody, self.inline_position, self.ibody.len);
        self.inline_position = try checkedAdd(self.inline_position, entry.padded_size);
        return entry;
    }
};

pub fn readAllocLimited(
    allocator: std.mem.Allocator,
    image: []const u8,
    block_size: usize,
    xattr_block: u32,
    ibody_start: usize,
    ibody_size: usize,
    max_count: usize,
    max_total_bytes: usize,
) Error!Attributes {
    var scanner = try Scanner.init(
        image,
        block_size,
        xattr_block,
        ibody_start,
        ibody_size,
    );
    var count: usize = 0;
    var total_bytes: usize = 0;
    while (try scanner.next()) |entry| {
        if (count == max_count) return error.OutputLimitExceeded;
        count += 1;
        total_bytes = try checkedAdd(total_bytes, try entry.nameLen());
        total_bytes = try checkedAdd(total_bytes, entry.value.len);
        if (total_bytes > max_total_bytes) return error.OutputLimitExceeded;
    }

    const entries = try allocator.alloc(Attribute, count);
    errdefer allocator.free(entries);
    const storage = try allocator.alloc(u8, total_bytes);
    errdefer allocator.free(storage);

    scanner = try Scanner.init(
        image,
        block_size,
        xattr_block,
        ibody_start,
        ibody_size,
    );
    var entry_index: usize = 0;
    var storage_position: usize = 0;
    while (try scanner.next()) |wire| {
        if (entry_index >= entries.len) return error.InvalidErofs;
        const name_len = try wire.nameLen();
        const name_start = storage_position;
        const name_end = try checkedAdd(name_start, name_len);
        const value_end = try checkedAdd(name_end, wire.value.len);
        if (value_end > storage.len) return error.InvalidErofs;
        @memcpy(storage[name_start..][0..wire.prefix.len], wire.prefix);
        @memcpy(storage[name_start + wire.prefix.len .. name_end], wire.suffix);
        @memcpy(storage[name_end..value_end], wire.value);
        entries[entry_index] = .{
            .name = storage[name_start..name_end],
            .value = storage[name_end..value_end],
        };
        for (entries[0..entry_index]) |previous|
            if (std.mem.eql(u8, previous.name, entries[entry_index].name))
                return error.InvalidErofs;
        entry_index += 1;
        storage_position = value_end;
    }
    if (entry_index != entries.len or storage_position != storage.len)
        return error.InvalidErofs;
    return .{ .allocator = allocator, .storage = storage, .entries = entries };
}

pub fn encodedSize(attributes: []const Attribute) Error!usize {
    if (attributes.len == 0) return 0;
    var size: usize = ibody_header_size;
    for (attributes, 0..) |attribute, index| {
        const encoded = try encodeName(attribute.name);
        if (attribute.value.len > std.math.maxInt(u16)) return error.InvalidErofs;
        for (attributes[0..index]) |previous|
            if (std.mem.eql(u8, previous.name, attribute.name))
                return error.InvalidErofs;
        size = try checkedAdd(
            size,
            try align4(try checkedAdd(
                entry_header_size,
                try checkedAdd(encoded.suffix.len, attribute.value.len),
            )),
        );
    }
    _ = try ibodyIcount(size);
    return size;
}

pub fn ibodyIcount(size: usize) Error!u16 {
    if (size == 0) return 0;
    if (size < ibody_header_size or size & 3 != 0) return error.InvalidErofs;
    const count = try checkedAdd(1, (size - ibody_header_size) / 4);
    if (count > std.math.maxInt(u16)) return error.InvalidErofs;
    return @intCast(count);
}

pub fn writeIbody(output: []u8, attributes: []const Attribute) Error!void {
    const expected_size = try encodedSize(attributes);
    if (output.len != expected_size) return error.InvalidErofs;
    if (output.len == 0) return;
    @memset(output, 0);
    var position: usize = ibody_header_size;
    for (attributes) |attribute| {
        const encoded = try encodeName(attribute.name);
        output[position] = @intCast(encoded.suffix.len);
        output[position + 1] = encoded.index;
        std.mem.writeInt(u16, output[position + 2 ..][0..2], @intCast(attribute.value.len), .little);
        const name_start = position + entry_header_size;
        const value_start = name_start + encoded.suffix.len;
        @memcpy(output[name_start..value_start], encoded.suffix);
        @memcpy(output[value_start..][0..attribute.value.len], attribute.value);
        position = try checkedAdd(
            position,
            try align4(try checkedAdd(
                entry_header_size,
                try checkedAdd(encoded.suffix.len, attribute.value.len),
            )),
        );
    }
    if (position != output.len) return error.InvalidErofs;
}

fn parseEntry(input: []const u8, start: usize, limit: usize) Error!WireAttribute {
    if (limit > input.len or start > limit or limit - start < entry_header_size)
        return error.InvalidErofs;
    const name_len: usize = input[start];
    const name_index = input[start + 1];
    if (name_index & 0x80 != 0) return error.UnsupportedErofsFeature;
    const prefix = try prefixForIndex(name_index);
    if (((name_index == 2 or name_index == 3) and name_len != 0) or
        ((name_index == 1 or name_index == 4 or name_index == 5 or name_index == 6) and
            name_len == 0))
        return error.InvalidErofs;
    const value_len: usize = format.readU16(input, start + 2);
    const payload_len = try checkedAdd(name_len, value_len);
    const raw_size = try checkedAdd(entry_header_size, payload_len);
    const padded_size = try align4(raw_size);
    if (padded_size > limit - start) return error.InvalidErofs;
    const name_start = start + entry_header_size;
    const name_end = name_start + name_len;
    const value_end = name_end + value_len;
    const full_name_len = try checkedAdd(prefix.len, name_len);
    if (full_name_len == 0 or full_name_len > format.name_max or
        std.mem.indexOfScalar(u8, input[name_start..name_end], 0) != null)
        return error.InvalidErofs;
    return .{
        .prefix = prefix,
        .suffix = input[name_start..name_end],
        .value = input[name_end..value_end],
        .padded_size = padded_size,
    };
}

fn encodeName(name: []const u8) Error!EncodedName {
    if (name.len == 0 or name.len > format.name_max or
        std.mem.indexOfScalar(u8, name, 0) != null)
        return error.InvalidErofs;
    if (std.mem.eql(u8, name, "system.posix_acl_access"))
        return .{ .index = 2, .suffix = &.{} };
    if (std.mem.eql(u8, name, "system.posix_acl_default"))
        return .{ .index = 3, .suffix = &.{} };
    inline for (.{
        .{ @as(u8, 1), "user." },
        .{ @as(u8, 4), "trusted." },
        .{ @as(u8, 5), "lustre." },
        .{ @as(u8, 6), "security." },
    }) |item| {
        if (std.mem.startsWith(u8, name, item[1])) {
            if (name.len == item[1].len) return error.InvalidErofs;
            return .{ .index = item[0], .suffix = name[item[1].len..] };
        }
    }
    return .{ .index = 0, .suffix = name };
}

fn prefixForIndex(index: u8) Error![]const u8 {
    return switch (index) {
        0 => "",
        1 => "user.",
        2 => "system.posix_acl_access",
        3 => "system.posix_acl_default",
        4 => "trusted.",
        5 => "lustre.",
        6 => "security.",
        else => error.UnsupportedErofsFeature,
    };
}

fn allZero(bytes: []const u8) bool {
    for (bytes) |byte| if (byte != 0) return false;
    return true;
}

fn align4(value: usize) Error!usize {
    return (try checkedAdd(value, 3)) & ~@as(usize, 3);
}

fn checkedAdd(left: anytype, right: anytype) Error!usize {
    return std.math.add(usize, @intCast(left), @intCast(right)) catch
        return error.IntegerOverflow;
}

fn checkedMul(left: anytype, right: anytype) Error!usize {
    return std.math.mul(usize, @intCast(left), @intCast(right)) catch
        return error.IntegerOverflow;
}

fn checkedEnd(start: usize, length: usize, limit: usize) Error!usize {
    const end = try checkedAdd(start, length);
    if (end > limit) return error.TruncatedFrame;
    return end;
}
