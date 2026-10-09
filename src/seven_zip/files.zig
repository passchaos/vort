const std = @import("std");
const core = @import("../core.zig");
const number = @import("number.zig");
const streams_mod = @import("streams.zig");
const types = @import("types.zig");

pub const Error = core.Error || number.Error || error{
    Invalid7zArchive,
    Unsupported7zFeature,
};

const Nid = struct {
    const end: u8 = 0x00;
    const empty_stream: u8 = 0x0e;
    const empty_file: u8 = 0x0f;
    const anti: u8 = 0x10;
    const name: u8 = 0x11;
    const dummy: u8 = 0x19;
};

pub const Files = struct {
    allocator: std.mem.Allocator,
    entries: []types.Entry,

    pub fn deinit(self: Files) void {
        for (self.entries) |entry| self.allocator.free(entry.name);
        self.allocator.free(self.entries);
    }
};

pub fn parse(
    allocator: std.mem.Allocator,
    reader: *number.Reader,
    streams: *const streams_mod.Streams,
    max_entries: usize,
) !Files {
    const file_count = try reader.readSize();
    if (file_count > max_entries) return error.OutputLimitExceeded;
    const entries = try allocator.alloc(types.Entry, file_count);
    var initialized_names: usize = 0;
    errdefer {
        for (entries[0..initialized_names]) |entry| allocator.free(entry.name);
        allocator.free(entries);
    }
    for (entries) |*entry| entry.* = .{
        .name = &.{},
        .size = 0,
        .kind = .file,
        .method = null,
        .crc32 = null,
        .folder_index = null,
        .offset_in_folder = 0,
    };

    const empty_streams = try allocator.alloc(bool, file_count);
    defer allocator.free(empty_streams);
    @memset(empty_streams, false);
    var empty_files: ?[]bool = null;
    defer if (empty_files) |values| allocator.free(values);
    var names_seen = false;
    var empty_streams_seen = false;

    while (true) {
        const property = try reader.readByte();
        if (property == Nid.end) break;
        const property_size = try reader.readSize();
        var data = try reader.subReader(property_size);
        switch (property) {
            Nid.empty_stream => {
                if (empty_streams_seen or property_size != (file_count + 7) / 8)
                    return error.Invalid7zArchive;
                empty_streams_seen = true;
                try readBitVector(&data, empty_streams);
            },
            Nid.empty_file => {
                if (!empty_streams_seen or empty_files != null) return error.Invalid7zArchive;
                var empty_count: usize = 0;
                for (empty_streams) |empty| empty_count += @intFromBool(empty);
                if (property_size != (empty_count + 7) / 8) return error.Invalid7zArchive;
                const values = try allocator.alloc(bool, empty_count);
                errdefer allocator.free(values);
                try readBitVector(&data, values);
                empty_files = values;
            },
            Nid.anti => {
                if (!empty_streams_seen) return error.Invalid7zArchive;
                var empty_count: usize = 0;
                for (empty_streams) |empty| empty_count += @intFromBool(empty);
                if (property_size != (empty_count + 7) / 8) return error.Invalid7zArchive;
                const ignored = try allocator.alloc(bool, empty_count);
                defer allocator.free(ignored);
                try readBitVector(&data, ignored);
                for (ignored) |anti| if (anti) return error.Unsupported7zFeature;
            },
            Nid.name => {
                if (names_seen) return error.Invalid7zArchive;
                names_seen = true;
                if (try data.readByte() != 0) return error.Unsupported7zFeature;
                for (entries) |*entry| {
                    entry.name = try readName(allocator, &data);
                    initialized_names += 1;
                }
            },
            Nid.dummy => {
                for (data.bytes) |byte| if (byte != 0) return error.Invalid7zArchive;
                data.offset = data.bytes.len;
            },
            else => data.offset = data.bytes.len,
        }
        if (data.remaining() != 0) return error.Invalid7zArchive;
    }

    if (!names_seen) {
        for (entries) |*entry| {
            entry.name = try allocator.dupe(u8, "");
            initialized_names += 1;
        }
    }

    var folder_index: usize = 0;
    var substream_index: usize = 0;
    var offset_in_folder: u64 = 0;
    var empty_index: usize = 0;
    for (entries, 0..) |*entry, index| {
        if (empty_streams[index]) {
            const is_empty_file = if (empty_files) |values| values[empty_index] else false;
            empty_index += 1;
            entry.kind = if (is_empty_file) .file else .directory;
            continue;
        }
        while (folder_index < streams.folders.len and
            substream_index >= streams.folders[folder_index].first_substream + streams.folders[folder_index].substream_count)
        {
            folder_index += 1;
            offset_in_folder = 0;
        }
        if (folder_index >= streams.folders.len or substream_index >= streams.substream_sizes.len)
            return error.Invalid7zArchive;
        entry.size = streams.substream_sizes[substream_index];
        entry.crc32 = streams.substream_crcs[substream_index];
        entry.folder_index = folder_index;
        entry.method = streams.folders[folder_index].primaryMethod();
        entry.offset_in_folder = offset_in_folder;
        offset_in_folder = std.math.add(u64, offset_in_folder, entry.size) catch
            return error.IntegerOverflow;
        substream_index += 1;
    }
    if (substream_index != streams.substream_sizes.len) return error.Invalid7zArchive;
    return .{ .allocator = allocator, .entries = entries };
}

fn readBitVector(reader: *number.Reader, values: []bool) !void {
    var byte: u8 = 0;
    for (values, 0..) |*value, index| {
        if (index & 7 == 0) byte = try reader.readByte();
        value.* = byte & (@as(u8, 0x80) >> @intCast(index & 7)) != 0;
    }
}

fn readName(allocator: std.mem.Allocator, reader: *number.Reader) ![]u8 {
    var units: std.ArrayList(u16) = .empty;
    defer units.deinit(allocator);
    while (true) {
        if (reader.remaining() < 2) return error.Invalid7zArchive;
        const bytes = try reader.take(2);
        const unit = @as(u16, bytes[0]) | (@as(u16, bytes[1]) << 8);
        if (unit == 0) break;
        try units.append(allocator, unit);
    }
    return std.unicode.utf16LeToUtf8Alloc(allocator, units.items) catch |err| switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => error.Invalid7zArchive,
    };
}
