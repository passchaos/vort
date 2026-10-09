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

pub const max_coders: usize = 4;

pub const Coder = struct {
    method: types.Method,
    properties: [5]u8 = @splat(0),
    properties_len: u3 = 0,

    pub fn propertyBytes(self: *const Coder) []const u8 {
        return self.properties[0..self.properties_len];
    }
};

pub const Folder = struct {
    coders: [max_coders]Coder = undefined,
    coder_count: u3,
    decode_order: [max_coders]u3 = @splat(0),
    coder_unpack_sizes: [max_coders]u64 = @splat(0),
    pack_index: usize,
    unpack_size: u64 = 0,
    crc32: ?u32 = null,
    first_substream: usize = 0,
    substream_count: usize = 1,

    pub fn primaryMethod(self: *const Folder) types.Method {
        return self.coders[self.decode_order[0]].method;
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
    for (result.folders) |*folder| {
        for (0..folder.coder_count) |index|
            folder.coder_unpack_sizes[index] = try reader.readNumber();
        folder.unpack_size = folder.coder_unpack_sizes[folder.decode_order[folder.coder_count - 1]];
        for (folder.coder_unpack_sizes[0..folder.coder_count]) |coder_size| {
            if (coder_size != folder.unpack_size)
                return error.Invalid7zArchive;
        }
    }

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
    if (coder_count == 0 or coder_count > max_coders) return error.Unsupported7zFeature;
    var folder = Folder{ .coder_count = @intCast(coder_count), .pack_index = pack_index };
    for (folder.coders[0..coder_count]) |*coder| coder.* = try parseCoder(reader);

    var bound_inputs: [max_coders]bool = @splat(false);
    var bound_outputs: [max_coders]bool = @splat(false);
    var next_coder: [max_coders]?u3 = @splat(null);
    for (0..coder_count - 1) |_| {
        const input_index = try reader.readSize();
        const output_index = try reader.readSize();
        if (input_index >= coder_count or output_index >= coder_count or
            bound_inputs[input_index] or bound_outputs[output_index])
            return error.Invalid7zArchive;
        bound_inputs[input_index] = true;
        bound_outputs[output_index] = true;
        next_coder[output_index] = @intCast(input_index);
    }

    var start: ?usize = null;
    var finish: ?usize = null;
    for (0..coder_count) |index| {
        if (!bound_inputs[index]) {
            if (start != null) return error.Unsupported7zFeature;
            start = index;
        }
        if (!bound_outputs[index]) {
            if (finish != null) return error.Unsupported7zFeature;
            finish = index;
        }
    }
    const start_index = start orelse return error.Invalid7zArchive;
    const finish_index = finish orelse return error.Invalid7zArchive;
    var visited: [max_coders]bool = @splat(false);
    var current = start_index;
    for (0..coder_count) |order_index| {
        if (visited[current]) return error.Invalid7zArchive;
        visited[current] = true;
        folder.decode_order[order_index] = @intCast(current);
        if (order_index + 1 == coder_count) {
            if (current != finish_index or next_coder[current] != null)
                return error.Unsupported7zFeature;
        } else {
            current = next_coder[current] orelse return error.Unsupported7zFeature;
        }
    }
    if (!isCompression(folder.coders[folder.decode_order[0]].method))
        return error.Unsupported7zFeature;
    for (folder.decode_order[1..coder_count]) |coder_index|
        if (!isFilter(folder.coders[coder_index].method)) return error.Unsupported7zFeature;
    return folder;
}

fn parseCoder(reader: *number.Reader) !Coder {
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
    else if (std.mem.eql(u8, id, &.{0x03}))
        .delta
    else if (std.mem.eql(u8, id, &.{ 0x03, 0x03, 0x01, 0x03 }))
        .x86
    else if (std.mem.eql(u8, id, &.{ 0x03, 0x03, 0x02, 0x05 }))
        .powerpc
    else if (std.mem.eql(u8, id, &.{ 0x03, 0x03, 0x04, 0x01 }))
        .ia64
    else if (std.mem.eql(u8, id, &.{ 0x03, 0x03, 0x05, 0x01 }))
        .arm
    else if (std.mem.eql(u8, id, &.{ 0x03, 0x03, 0x07, 0x01 }))
        .arm_thumb
    else if (std.mem.eql(u8, id, &.{ 0x03, 0x03, 0x08, 0x05 }))
        .sparc
    else
        return error.Unsupported7zFeature;
    if (((method == .copy or method == .deflate or method == .bzip2) and properties.len != 0) or
        (method == .lzma and properties.len != 5) or
        (method == .lzma2 and properties.len != 1) or
        (method == .delta and properties.len != 1) or
        (isBcj(method) and properties.len != 0 and properties.len != 4))
        return error.Invalid7zArchive;

    var coder = Coder{ .method = method };
    coder.properties_len = @intCast(properties.len);
    @memcpy(coder.properties[0..properties.len], properties);
    return coder;
}

fn isCompression(method: types.Method) bool {
    return switch (method) {
        .copy, .deflate, .bzip2, .lzma, .lzma2 => true,
        else => false,
    };
}

fn isFilter(method: types.Method) bool {
    return switch (method) {
        .delta, .x86, .powerpc, .ia64, .arm, .arm_thumb, .sparc => true,
        else => false,
    };
}

fn isBcj(method: types.Method) bool {
    return switch (method) {
        .x86, .powerpc, .ia64, .arm, .arm_thumb, .sparc => true,
        else => false,
    };
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
    try std.testing.expectEqual(types.Method.copy, parsed.folders[0].primaryMethod());
    try std.testing.expectEqual(@as(u64, 16), parsed.folders[0].unpack_size);
    try std.testing.expectEqual(@as(?u32, 0xfe01_c34e), parsed.folders[0].crc32);
    try std.testing.expectEqual(@as(usize, encoded.len), reader.offset);
}

test "7z Folder orders LZMA2 and x86 BCJ for decoding" {
    const encoded = [_]u8{
        2,
        0x21,
        0x21,
        1,
        0x0f,
        0x04,
        0x03,
        0x03,
        0x01,
        0x03,
        1,
        0,
    };
    var reader = number.Reader.init(&encoded);
    const folder = try parseFolder(&reader, 7);

    try std.testing.expectEqual(@as(u3, 2), folder.coder_count);
    try std.testing.expectEqual(@as(usize, 7), folder.pack_index);
    try std.testing.expectEqual(types.Method.lzma2, folder.primaryMethod());
    try std.testing.expectEqual(types.Method.x86, folder.coders[folder.decode_order[1]].method);
    try std.testing.expectEqual(@as(usize, encoded.len), reader.offset);
}

test "7z Folder parses Delta filter properties" {
    const encoded = [_]u8{
        2,
        0x21,
        0x21,
        1,
        0x0f,
        0x21,
        0x03,
        1,
        3,
        1,
        0,
    };
    var reader = number.Reader.init(&encoded);
    const folder = try parseFolder(&reader, 0);
    const delta = folder.coders[folder.decode_order[1]];

    try std.testing.expectEqual(types.Method.delta, delta.method);
    try std.testing.expectEqualSlices(u8, &.{3}, delta.propertyBytes());
    try std.testing.expectEqual(@as(usize, encoded.len), reader.offset);
}

test "7z Folder rejects disconnected cyclic coder graph" {
    const encoded = [_]u8{
        3,
        0x21,
        0x21,
        1,
        0x0f,
        0x04,
        0x03,
        0x03,
        0x01,
        0x03,
        0x21,
        0x03,
        1,
        3,
        1,
        0,
        0,
        1,
    };
    var reader = number.Reader.init(&encoded);
    try std.testing.expectError(error.Unsupported7zFeature, parseFolder(&reader, 0));
}

test "7z Folder rejects a second compression coder" {
    const encoded = [_]u8{
        2,
        0x21,
        0x21,
        1,
        0x0f,
        0x23,
        0x03,
        0x01,
        0x01,
        5,
        0x5d,
        0,
        0,
        0x10,
        0,
        1,
        0,
    };
    var reader = number.Reader.init(&encoded);
    try std.testing.expectError(error.Unsupported7zFeature, parseFolder(&reader, 0));
}

test "7z Folder rejects multi-input BCJ2 coder" {
    const encoded = [_]u8{
        1,
        0x14,
        0x03,
        0x03,
        0x01,
        0x1b,
        4,
        1,
    };
    var reader = number.Reader.init(&encoded);
    try std.testing.expectError(error.Unsupported7zFeature, parseFolder(&reader, 0));
}

test "7z StreamsInfo rejects size-changing classic filter chain" {
    const encoded = [_]u8{
        Nid.pack_info,   0,          1,       Nid.size, 3,                      Nid.end,
        Nid.unpack_info, Nid.folder, 1,       0,        2,                      0x21,
        0x21,            1,          0x0f,    0x04,     0x03,                   0x03,
        0x01,            0x03,       1,       0,        Nid.coders_unpack_size, 4,
        5,               Nid.end,    Nid.end,
    };
    var reader = number.Reader.init(&encoded);
    try std.testing.expectError(error.Invalid7zArchive, parse(std.testing.allocator, &reader, 8));
}
