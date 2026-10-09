const std = @import("std");
const core = @import("../core.zig");
const number = @import("number.zig");
const types = @import("types.zig");

pub const Error = core.Error || number.Error || error{Invalid7zArchive};

pub const Kind = enum(u2) {
    creation_time,
    access_time,
    modification_time,
    attributes,
};

pub const kind_count = std.meta.fields(Kind).len;
pub const Indices = [kind_count]?usize;

pub fn id(kind: Kind) u8 {
    return switch (kind) {
        .creation_time => 0x12,
        .access_time => 0x13,
        .modification_time => 0x14,
        .attributes => 0x15,
    };
}

pub fn kindFromId(property_id: u8) ?Kind {
    return switch (property_id) {
        0x12 => .creation_time,
        0x13 => .access_time,
        0x14 => .modification_time,
        0x15 => .attributes,
        else => null,
    };
}

pub fn parse(
    allocator: std.mem.Allocator,
    kind: Kind,
    data: *number.Reader,
    external_streams: []const []u8,
    entries: []types.Entry,
    seen: *[kind_count]bool,
) !void {
    const kind_index = @intFromEnum(kind);
    if (seen[kind_index]) return error.Invalid7zArchive;
    seen[kind_index] = true;

    const definitions = try allocator.alloc(bool, entries.len);
    defer allocator.free(definitions);
    try readDefinitions(data, definitions);
    const external = try data.readByte();
    var external_reader: number.Reader = undefined;
    const value_reader = if (external == 0)
        data
    else external_source: {
        const index = try data.readSize();
        if (data.remaining() != 0 or index >= external_streams.len)
            return error.Invalid7zArchive;
        external_reader = number.Reader.init(external_streams[index]);
        break :external_source &external_reader;
    };

    for (entries, definitions) |*entry, defined| {
        if (!defined) continue;
        switch (kind) {
            .creation_time => entry.creation_time = try value_reader.readU64(),
            .access_time => entry.access_time = try value_reader.readU64(),
            .modification_time => entry.modification_time = try value_reader.readU64(),
            .attributes => entry.attributes = try value_reader.readU32(),
        }
    }
    if (value_reader.remaining() != 0) return error.Invalid7zArchive;
}

pub fn appendValues(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entries: []const types.EncodeEntry,
    kind: Kind,
) !void {
    for (entries) |entry| switch (kind) {
        .creation_time => if (entry.creation_time) |value|
            try appendU64(allocator, output, value),
        .access_time => if (entry.access_time) |value|
            try appendU64(allocator, output, value),
        .modification_time => if (entry.modification_time) |value|
            try appendU64(allocator, output, value),
        .attributes => if (entry.attributes) |value|
            try appendU32(allocator, output, value),
    };
}

pub fn write(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entries: []const types.EncodeEntry,
    external_indices: Indices,
) !void {
    inline for (std.meta.tags(Kind)) |kind|
        try writeOne(
            allocator,
            output,
            entries,
            kind,
            external_indices[@intFromEnum(kind)],
        );
}

fn writeOne(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entries: []const types.EncodeEntry,
    kind: Kind,
    external_index: ?usize,
) !void {
    var property: std.ArrayList(u8) = .empty;
    defer property.deinit(allocator);
    const defined_count = try appendDefinitions(allocator, &property, entries, kind);
    if (defined_count == 0) return;
    if (external_index) |index| {
        try property.append(allocator, 1);
        try number.append(allocator, &property, index);
    } else {
        try property.append(allocator, 0);
        try appendValues(allocator, &property, entries, kind);
    }
    try output.append(allocator, id(kind));
    try number.append(allocator, output, property.items.len);
    try output.appendSlice(allocator, property.items);
}

fn appendDefinitions(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entries: []const types.EncodeEntry,
    kind: Kind,
) !usize {
    var defined_count: usize = 0;
    for (entries) |entry| defined_count += @intFromBool(isDefined(entry, kind));
    if (defined_count == 0) return 0;
    if (defined_count == entries.len) {
        try output.append(allocator, 1);
        return defined_count;
    }
    try output.append(allocator, 0);
    var byte: u8 = 0;
    for (entries, 0..) |entry, index| {
        if (isDefined(entry, kind)) byte |= @as(u8, 0x80) >> @intCast(index & 7);
        if (index & 7 == 7) {
            try output.append(allocator, byte);
            byte = 0;
        }
    }
    if (entries.len & 7 != 0) try output.append(allocator, byte);
    return defined_count;
}

fn isDefined(entry: types.EncodeEntry, kind: Kind) bool {
    return switch (kind) {
        .creation_time => entry.creation_time != null,
        .access_time => entry.access_time != null,
        .modification_time => entry.modification_time != null,
        .attributes => entry.attributes != null,
    };
}

fn readDefinitions(reader: *number.Reader, definitions: []bool) !void {
    const all_defined = try reader.readByte();
    if (all_defined > 1) return error.Invalid7zArchive;
    if (all_defined == 1) {
        @memset(definitions, true);
        return;
    }
    var byte: u8 = 0;
    for (definitions, 0..) |*defined, index| {
        if (index & 7 == 0) byte = try reader.readByte();
        defined.* = byte & (@as(u8, 0x80) >> @intCast(index & 7)) != 0;
    }
}

fn appendU32(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: u32) !void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .little);
    try output.appendSlice(allocator, &bytes);
}

fn appendU64(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: u64) !void {
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, value, .little);
    try output.appendSlice(allocator, &bytes);
}
