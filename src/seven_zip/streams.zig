const std = @import("std");
const core = @import("../core.zig");
const number = @import("number.zig");
const types = @import("types.zig");

pub const Error = core.Error || number.Error || error{
    Invalid7zArchive,
    Unsupported7zFeature,
};

pub const Nid = struct {
    pub const end: u8 = 0x00;
    pub const pack_info: u8 = 0x06;
    pub const unpack_info: u8 = 0x07;
    pub const substreams_info: u8 = 0x08;
    pub const size: u8 = 0x09;
    pub const crc: u8 = 0x0a;
    pub const folder: u8 = 0x0b;
    pub const coders_unpack_size: u8 = 0x0c;
    pub const num_unpack_stream: u8 = 0x0d;
};

pub const Folder = struct {
    method: types.Method,
    properties: [5]u8 = @splat(0),
    properties_len: u3 = 0,
    pack_index: usize,
    unpack_size: u64 = 0,
    crc32: ?u32 = null,
    first_substream: usize = 0,
    substream_count: usize = 1,

    pub fn propertyBytes(self: *const Folder) []const u8 {
        return self.properties[0..self.properties_len];
    }
};

pub const Streams = struct {
    allocator: std.mem.Allocator,
    pack_position: u64 = 0,
    pack_sizes: []u64 = &.{},
    pack_crcs: []?u32 = &.{},
    folders: []Folder = &.{},
    substream_sizes: []u64 = &.{},
    substream_crcs: []?u32 = &.{},

    pub fn deinit(self: Streams) void {
        self.allocator.free(self.pack_sizes);
        self.allocator.free(self.pack_crcs);
        self.allocator.free(self.folders);
        self.allocator.free(self.substream_sizes);
        self.allocator.free(self.substream_crcs);
    }
};

pub fn parse(allocator: std.mem.Allocator, reader: *number.Reader, max_streams: usize) !Streams {
    var result = Streams{ .allocator = allocator };
    errdefer result.deinit();
    var have_pack_info = false;
    var have_unpack_info = false;
    var have_substreams_info = false;

    while (true) switch (try reader.readByte()) {
        Nid.end => break,
        Nid.pack_info => {
            if (have_pack_info) return error.Invalid7zArchive;
            have_pack_info = true;
            try parsePackInfo(allocator, reader, &result, max_streams);
        },
        Nid.unpack_info => {
            if (have_unpack_info) return error.Invalid7zArchive;
            have_unpack_info = true;
            try parseUnpackInfo(allocator, reader, &result, max_streams);
        },
        Nid.substreams_info => {
            if (!have_unpack_info or have_substreams_info) return error.Invalid7zArchive;
            have_substreams_info = true;
            try parseSubStreamsInfo(allocator, reader, &result, max_streams);
        },
        else => return error.Invalid7zArchive,
    };

    if (have_pack_info != have_unpack_info) return error.Invalid7zArchive;
    if (result.pack_sizes.len != result.folders.len) return error.Unsupported7zFeature;
    if (have_unpack_info and !have_substreams_info)
        try buildDefaultSubstreams(allocator, &result);
    return result;
}

fn parsePackInfo(
    allocator: std.mem.Allocator,
    reader: *number.Reader,
    result: *Streams,
    max_streams: usize,
) !void {
    result.pack_position = try reader.readNumber();
    const count = try reader.readSize();
    if (count == 0) return error.Invalid7zArchive;
    if (count > max_streams) return error.OutputLimitExceeded;
    result.pack_sizes = try allocator.alloc(u64, count);
    result.pack_crcs = try allocator.alloc(?u32, count);
    @memset(result.pack_crcs, null);

    var have_sizes = false;
    while (true) switch (try reader.readByte()) {
        Nid.end => break,
        Nid.size => {
            if (have_sizes) return error.Invalid7zArchive;
            have_sizes = true;
            for (result.pack_sizes) |*size| size.* = try reader.readNumber();
        },
        Nid.crc => try readDigests(reader, result.pack_crcs),
        else => return error.Invalid7zArchive,
    };
    if (!have_sizes) return error.Invalid7zArchive;
}

fn parseUnpackInfo(
    allocator: std.mem.Allocator,
    reader: *number.Reader,
    result: *Streams,
    max_streams: usize,
) !void {
    if (try reader.readByte() != Nid.folder) return error.Invalid7zArchive;
    const count = try reader.readSize();
    if (count > max_streams) return error.OutputLimitExceeded;
    if (try reader.readByte() != 0) return error.Unsupported7zFeature;
    result.folders = try allocator.alloc(Folder, count);
    var next_pack_index: usize = 0;
    for (result.folders) |*folder| {
        folder.* = try parseFolder(reader, next_pack_index);
        next_pack_index += 1;
    }
    if (next_pack_index != result.pack_sizes.len) return error.Invalid7zArchive;

    if (try reader.readByte() != Nid.coders_unpack_size) return error.Invalid7zArchive;
    for (result.folders) |*folder| folder.unpack_size = try reader.readNumber();

    const next = try reader.readByte();
    if (next == Nid.crc) {
        const digests = try allocator.alloc(?u32, result.folders.len);
        defer allocator.free(digests);
        try readDigests(reader, digests);
        for (result.folders, digests) |*folder, digest| folder.crc32 = digest;
        if (try reader.readByte() != Nid.end) return error.Invalid7zArchive;
    } else if (next != Nid.end) return error.Invalid7zArchive;
}

fn parseFolder(reader: *number.Reader, pack_index: usize) !Folder {
    const coder_count = try reader.readSize();
    if (coder_count != 1) return error.Unsupported7zFeature;
    const flags = try reader.readByte();
    const id_len: usize = flags & 0x0f;
    if (id_len == 0 or flags & 0xc0 != 0) return error.Invalid7zArchive;
    const id = try reader.take(id_len);
    const input_count = if (flags & 0x10 != 0) try reader.readNumber() else 1;
    const output_count = if (flags & 0x10 != 0) try reader.readNumber() else 1;
    if (input_count != 1 or output_count != 1) return error.Unsupported7zFeature;
    const properties = if (flags & 0x20 != 0)
        try reader.take(try reader.readSize())
    else
        &.{};
    if (properties.len > 5) return error.Unsupported7zFeature;

    const method: types.Method = if (std.mem.eql(u8, id, &.{0}))
        .copy
    else if (std.mem.eql(u8, id, &.{ 0x04, 0x01, 0x08 }))
        .deflate
    else if (std.mem.eql(u8, id, &.{ 0x04, 0x02, 0x02 }))
        .bzip2
    else if (std.mem.eql(u8, id, &.{ 0x03, 0x01, 0x01 }))
        .lzma
    else if (std.mem.eql(u8, id, &.{0x21}))
        .lzma2
    else
        return error.Unsupported7zFeature;
    if (((method == .copy or method == .deflate or method == .bzip2) and properties.len != 0) or
        (method == .lzma and properties.len != 5) or
        (method == .lzma2 and properties.len != 1))
        return error.Invalid7zArchive;

    var folder = Folder{ .method = method, .pack_index = pack_index };
    folder.properties_len = @intCast(properties.len);
    @memcpy(folder.properties[0..properties.len], properties);
    return folder;
}

fn parseSubStreamsInfo(
    allocator: std.mem.Allocator,
    reader: *number.Reader,
    result: *Streams,
    max_streams: usize,
) !void {
    const counts = try allocator.alloc(usize, result.folders.len);
    defer allocator.free(counts);
    @memset(counts, 1);

    var next = try reader.readByte();
    if (next == Nid.num_unpack_stream) {
        for (counts) |*count| count.* = try reader.readSize();
        next = try reader.readByte();
    }

    var total_count: usize = 0;
    for (counts) |count|
        total_count = std.math.add(usize, total_count, count) catch return error.IntegerOverflow;
    if (total_count > max_streams) return error.OutputLimitExceeded;
    result.substream_sizes = try allocator.alloc(u64, total_count);
    result.substream_crcs = try allocator.alloc(?u32, total_count);
    @memset(result.substream_crcs, null);

    var stream_index: usize = 0;
    if (next == Nid.size) {
        for (result.folders, counts) |*folder, count| {
            folder.first_substream = stream_index;
            folder.substream_count = count;
            var subtotal: u64 = 0;
            for (0..count -| 1) |_| {
                const size = try reader.readNumber();
                subtotal = std.math.add(u64, subtotal, size) catch return error.IntegerOverflow;
                if (subtotal > folder.unpack_size) return error.Invalid7zArchive;
                result.substream_sizes[stream_index] = size;
                stream_index += 1;
            }
            if (count != 0) {
                result.substream_sizes[stream_index] = folder.unpack_size - subtotal;
                stream_index += 1;
            }
        }
        next = try reader.readByte();
    } else {
        for (result.folders, counts) |*folder, count| {
            if (count != 1) return error.Invalid7zArchive;
            folder.first_substream = stream_index;
            folder.substream_count = 1;
            result.substream_sizes[stream_index] = folder.unpack_size;
            stream_index += 1;
        }
    }

    for (result.folders) |folder| {
        if (folder.substream_count == 1 and folder.crc32 != null) {
            result.substream_crcs[folder.first_substream] = folder.crc32;
        }
    }

    if (next == Nid.crc) {
        var missing_count: usize = 0;
        for (result.substream_crcs) |digest| missing_count += @intFromBool(digest == null);
        const digests = try allocator.alloc(?u32, missing_count);
        defer allocator.free(digests);
        try readDigests(reader, digests);
        var digest_index: usize = 0;
        for (result.substream_crcs) |*digest| if (digest.* == null) {
            digest.* = digests[digest_index];
            digest_index += 1;
        };
        next = try reader.readByte();
    }
    if (next != Nid.end) return error.Invalid7zArchive;
}

fn buildDefaultSubstreams(allocator: std.mem.Allocator, result: *Streams) !void {
    result.substream_sizes = try allocator.alloc(u64, result.folders.len);
    result.substream_crcs = try allocator.alloc(?u32, result.folders.len);
    for (result.folders, 0..) |*folder, index| {
        folder.first_substream = index;
        folder.substream_count = 1;
        result.substream_sizes[index] = folder.unpack_size;
        result.substream_crcs[index] = folder.crc32;
    }
}

fn readDigests(reader: *number.Reader, digests: []?u32) !void {
    const all_defined = try reader.readByte();
    if (all_defined > 1) return error.Invalid7zArchive;
    const defined_bytes = if (all_defined == 0)
        try reader.take((digests.len + 7) / 8)
    else
        &.{};
    for (digests, 0..) |*digest, index| {
        const defined = all_defined == 1 or
            defined_bytes[index / 8] & (@as(u8, 0x80) >> @intCast(index & 7)) != 0;
        digest.* = if (defined) try reader.readU32() else null;
    }
}

test "7z StreamsInfo parses two Copy folders" {
    const encoded = [_]u8{
        Nid.pack_info,   0,          2,       Nid.size,               16,      12,      Nid.end,
        Nid.unpack_info, Nid.folder, 2,       0,                      1,       1,       0,
        1,               1,          0,       Nid.coders_unpack_size, 16,      12,      Nid.crc,
        1,               0x4e,       0xc3,    0x01,                   0xfe,    0x82,    0xff,
        0x72,            0xe4,       Nid.end, Nid.substreams_info,    Nid.end, Nid.end,
    };
    var reader = number.Reader.init(&encoded);
    const parsed = try parse(std.testing.allocator, &reader, 16);
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 2), parsed.folders.len);
    try std.testing.expectEqual(types.Method.copy, parsed.folders[0].method);
    try std.testing.expectEqual(@as(u64, 16), parsed.folders[0].unpack_size);
    try std.testing.expectEqual(@as(?u32, 0xfe01_c34e), parsed.folders[0].crc32);
    try std.testing.expectEqual(@as(usize, encoded.len), reader.offset);
}
