const std = @import("std");
const core = @import("../core.zig");
const aes = @import("aes.zig");
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

pub const max_coders: usize = 5;
pub const max_streams_per_folder: usize = 8;
pub const max_coder_properties: usize = 34;

pub const Coder = struct {
    method: types.Method,
    properties: [max_coder_properties]u8 = @splat(0),
    properties_len: u6 = 0,
    input_count: u3 = 1,
    output_count: u3 = 1,
    input_start: u4 = 0,
    output_start: u3 = 0,

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
    packed_inputs: [max_streams_per_folder]u4 = @splat(0),
    pack_stream_count: u4 = 1,
    bcj2_coder_index: ?u3 = null,
    aes_coder_index: ?u3 = null,
    unpack_size: u64 = 0,
    crc32: ?u32 = null,
    first_substream: usize = 0,
    substream_count: usize = 1,

    pub fn primaryMethod(self: *const Folder) types.Method {
        for (self.decode_order[0..self.coder_count]) |coder_index| {
            const method = self.coders[coder_index].method;
            if (isCompression(method)) return method;
        }
        return .copy;
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
    return parseWithExternal(allocator, reader, max_streams, &.{});
}

pub fn parseWithExternal(
    allocator: std.mem.Allocator,
    reader: *number.Reader,
    max_streams: usize,
    external_streams: []const []u8,
) !Streams {
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
            try parseUnpackInfo(allocator, reader, &result, max_streams, external_streams);
        },
        Nid.substreams_info => {
            if (!have_unpack_info or have_substreams_info) return error.Invalid7zArchive;
            have_substreams_info = true;
            try parseSubStreamsInfo(allocator, reader, &result, max_streams);
        },
        else => return error.Invalid7zArchive,
    };

    if (have_pack_info != have_unpack_info) return error.Invalid7zArchive;
    var expected_pack_streams: usize = 0;
    for (result.folders) |folder|
        expected_pack_streams = std.math.add(usize, expected_pack_streams, folder.pack_stream_count) catch
            return error.IntegerOverflow;
    if (result.pack_sizes.len != expected_pack_streams) return error.Invalid7zArchive;
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
    external_streams: []const []u8,
) !void {
    if (try reader.readByte() != Nid.folder) return error.Invalid7zArchive;
    const count = try reader.readSize();
    if (count > max_streams) return error.OutputLimitExceeded;
    const external = try reader.readByte();
    var external_reader: number.Reader = undefined;
    const folder_reader = if (external == 0)
        reader
    else external_source: {
        const index = try reader.readSize();
        if (index >= external_streams.len) return error.Invalid7zArchive;
        external_reader = number.Reader.init(external_streams[index]);
        break :external_source &external_reader;
    };
    result.folders = try allocator.alloc(Folder, count);
    var next_pack_index: usize = 0;
    for (result.folders) |*folder| {
        folder.* = try parseFolder(folder_reader, next_pack_index);
        next_pack_index += folder.pack_stream_count;
    }
    if (external != 0 and folder_reader.remaining() != 0)
        return error.Invalid7zArchive;
    if (next_pack_index != result.pack_sizes.len) return error.Invalid7zArchive;

    if (try reader.readByte() != Nid.coders_unpack_size) return error.Invalid7zArchive;
    for (result.folders) |*folder| {
        for (0..folder.coder_count) |index|
            folder.coder_unpack_sizes[index] = try reader.readNumber();
        folder.unpack_size = folder.coder_unpack_sizes[folder.decode_order[folder.coder_count - 1]];
        if (folder.bcj2_coder_index == null) {
            const first_sized_order: usize = @intFromBool(folder.aes_coder_index != null);
            for (folder.decode_order[first_sized_order..folder.coder_count]) |coder_index| {
                const coder_size = folder.coder_unpack_sizes[coder_index];
                if (coder_size != folder.unpack_size)
                    return error.Invalid7zArchive;
            }
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
    var total_inputs: usize = 0;
    var total_outputs: usize = 0;
    for (folder.coders[0..coder_count]) |*coder| {
        coder.* = try parseCoder(reader);
        coder.input_start = @intCast(total_inputs);
        coder.output_start = @intCast(total_outputs);
        total_inputs += coder.input_count;
        total_outputs += coder.output_count;
    }
    if (total_inputs > max_streams_per_folder or total_outputs > max_coders)
        return error.Unsupported7zFeature;

    var bound_inputs: [max_streams_per_folder]bool = @splat(false);
    var bound_outputs: [max_coders]bool = @splat(false);
    var bind_inputs: [max_coders]u4 = @splat(0);
    var bind_outputs: [max_coders]u3 = @splat(0);
    var next_coder: [max_coders]?u3 = @splat(null);
    const bind_count = total_outputs - 1;
    for (0..bind_count) |bind_index| {
        const input_index = try reader.readSize();
        const output_index = try reader.readSize();
        if (input_index >= total_inputs or output_index >= total_outputs or
            bound_inputs[input_index] or bound_outputs[output_index])
            return error.Invalid7zArchive;
        bound_inputs[input_index] = true;
        bound_outputs[output_index] = true;
        bind_inputs[bind_index] = @intCast(input_index);
        bind_outputs[bind_index] = @intCast(output_index);
    }

    const packed_count = total_inputs - bind_count;
    if (packed_count == 0 or packed_count > max_streams_per_folder)
        return error.Invalid7zArchive;
    folder.pack_stream_count = @intCast(packed_count);
    if (packed_count == 1) {
        for (bound_inputs[0..total_inputs], 0..) |bound, input_index| if (!bound) {
            folder.packed_inputs[0] = @intCast(input_index);
            break;
        };
    } else {
        var seen_packed: [max_streams_per_folder]bool = @splat(false);
        for (folder.packed_inputs[0..packed_count]) |*input_index| {
            const value = try reader.readSize();
            if (value >= total_inputs or bound_inputs[value] or seen_packed[value])
                return error.Invalid7zArchive;
            input_index.* = @intCast(value);
            seen_packed[value] = true;
        }
        for (bound_inputs[0..total_inputs], seen_packed[0..total_inputs]) |bound, is_packed|
            if (!bound and !is_packed) return error.Invalid7zArchive;
    }

    var bcj2_index: ?usize = null;
    var aes_index: ?usize = null;
    for (folder.coders[0..coder_count], 0..) |coder, index| {
        if (coder.method == .bcj2) {
            if (bcj2_index != null) return error.Unsupported7zFeature;
            bcj2_index = index;
        }
        if (coder.method == .aes256_sha256) {
            if (aes_index != null) return error.Unsupported7zFeature;
            aes_index = index;
        }
    }
    if (bcj2_index) |bcj_index| {
        if (aes_index != null) return error.Unsupported7zFeature;
        if (coder_count != 2 or packed_count != 4) return error.Unsupported7zFeature;
        const primary_index: usize = 1 - bcj_index;
        const primary = folder.coders[primary_index];
        const bcj = folder.coders[bcj_index];
        if (!isCompression(primary.method) or primary.input_count != 1 or
            primary.output_count != 1 or bcj.input_count != 4 or bcj.output_count != 1)
            return error.Unsupported7zFeature;
        if (bind_count != 1 or bind_outputs[0] != primary.output_start or
            bind_inputs[0] != bcj.input_start)
            return error.Unsupported7zFeature;
        const expected_inputs = [_]usize{
            primary.input_start,
            bcj.input_start + 1,
            bcj.input_start + 2,
            bcj.input_start + 3,
        };
        for (folder.packed_inputs[0..4], expected_inputs) |actual, expected|
            if (actual != expected) return error.Unsupported7zFeature;
        folder.decode_order[0] = @intCast(primary_index);
        folder.decode_order[1] = @intCast(bcj_index);
        folder.bcj2_coder_index = @intCast(bcj_index);
        return folder;
    }

    for (folder.coders[0..coder_count]) |coder|
        if (coder.input_count != 1 or coder.output_count != 1)
            return error.Unsupported7zFeature;
    for (bind_inputs[0..bind_count], bind_outputs[0..bind_count]) |input_index, output_index| {
        const input_coder = coderForInput(&folder, input_index) orelse
            return error.Invalid7zArchive;
        const output_coder = coderForOutput(&folder, output_index) orelse
            return error.Invalid7zArchive;
        next_coder[output_coder] = @intCast(input_coder);
    }

    var start: ?usize = null;
    var finish: ?usize = null;
    for (0..coder_count) |index| {
        if (!isCoderInputBound(&folder, bound_inputs, index)) {
            if (start != null) return error.Unsupported7zFeature;
            start = index;
        }
        if (!bound_outputs[folder.coders[index].output_start]) {
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
    var compression_order: usize = 0;
    if (folder.coders[folder.decode_order[0]].method == .aes256_sha256) {
        folder.aes_coder_index = folder.decode_order[0];
        compression_order = 1;
    } else if (aes_index != null) {
        return error.Unsupported7zFeature;
    }
    if (compression_order == coder_count) return folder;
    if (!isCompression(folder.coders[folder.decode_order[compression_order]].method))
        return error.Unsupported7zFeature;
    for (folder.decode_order[compression_order + 1 .. coder_count]) |coder_index|
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
    if (input_count == 0 or input_count > max_streams_per_folder or
        output_count == 0 or output_count > max_coders)
        return error.Unsupported7zFeature;
    const properties = if (flags & 0x20 != 0)
        try reader.take(try reader.readSize())
    else
        &.{};
    if (properties.len > max_coder_properties) return error.Unsupported7zFeature;

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
    else if (std.mem.eql(u8, id, &.{ 0x03, 0x03, 0x01, 0x1b }))
        .bcj2
    else if (std.mem.eql(u8, id, &.{ 0x06, 0xf1, 0x07, 0x01 }))
        .aes256_sha256
    else
        return error.Unsupported7zFeature;
    if (((method == .copy or method == .deflate or method == .bzip2) and properties.len != 0) or
        (method == .lzma and properties.len != 5) or
        (method == .lzma2 and properties.len != 1) or
        (method == .delta and properties.len != 1) or
        (isBcj(method) and properties.len != 0 and properties.len != 4) or
        (method == .bcj2 and (input_count != 4 or output_count != 1 or
            (properties.len != 0 and properties.len != 4))) or
        (method == .aes256_sha256 and (input_count != 1 or output_count != 1)))
        return error.Invalid7zArchive;
    if (method == .aes256_sha256)
        _ = aes.parseProperties(properties) catch return error.Invalid7zArchive;

    var coder = Coder{
        .method = method,
        .input_count = @intCast(input_count),
        .output_count = @intCast(output_count),
    };
    coder.properties_len = @intCast(properties.len);
    @memcpy(coder.properties[0..properties.len], properties);
    return coder;
}

fn coderForInput(folder: *const Folder, input_index: usize) ?usize {
    for (folder.coders[0..folder.coder_count], 0..) |coder, index|
        if (input_index >= coder.input_start and input_index < coder.input_start + coder.input_count)
            return index;
    return null;
}

fn coderForOutput(folder: *const Folder, output_index: usize) ?usize {
    for (folder.coders[0..folder.coder_count], 0..) |coder, index|
        if (output_index >= coder.output_start and output_index < coder.output_start + coder.output_count)
            return index;
    return null;
}

fn isCoderInputBound(
    folder: *const Folder,
    bound_inputs: [max_streams_per_folder]bool,
    coder_index: usize,
) bool {
    const coder = folder.coders[coder_index];
    for (bound_inputs[coder.input_start..][0..coder.input_count]) |bound|
        if (bound) return true;
    return false;
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

test "7z StreamsInfo reads external folder definitions" {
    const encoded = [_]u8{
        Nid.pack_info,   0,          1,       Nid.size, 7, Nid.end,
        Nid.unpack_info, Nid.folder, 1,       1,        0, Nid.coders_unpack_size,
        7,               Nid.end,    Nid.end,
    };
    var external_folder = [_]u8{ 1, 1, 0 };
    const external_streams = [_][]u8{external_folder[0..]};
    var reader = number.Reader.init(&encoded);
    const parsed = try parseWithExternal(
        std.testing.allocator,
        &reader,
        8,
        &external_streams,
    );
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 1), parsed.folders.len);
    try std.testing.expectEqual(types.Method.copy, parsed.folders[0].primaryMethod());
    try std.testing.expectEqual(@as(u64, 7), parsed.folders[0].unpack_size);

    var bad_index = encoded;
    bad_index[10] = 1;
    var bad_index_reader = number.Reader.init(&bad_index);
    try std.testing.expectError(
        error.Invalid7zArchive,
        parseWithExternal(std.testing.allocator, &bad_index_reader, 8, &external_streams),
    );

    var trailing_folder = [_]u8{ 1, 1, 0, 0 };
    const trailing_streams = [_][]u8{trailing_folder[0..]};
    var trailing_reader = number.Reader.init(&encoded);
    try std.testing.expectError(
        error.Invalid7zArchive,
        parseWithExternal(std.testing.allocator, &trailing_reader, 8, &trailing_streams),
    );
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

test "7z Folder orders AES before Copy decoding" {
    const encoded = [_]u8{
        2,
        0x24,
        0x06,
        0xf1,
        0x07,
        0x01,
        1,
        aes.direct_key_power,
        1,
        0,
        1,
        0,
    };
    var reader = number.Reader.init(&encoded);
    const folder = try parseFolder(&reader, 3);
    try std.testing.expectEqual(@as(?u3, 0), folder.aes_coder_index);
    try std.testing.expectEqual(types.Method.aes256_sha256, folder.coders[folder.decode_order[0]].method);
    try std.testing.expectEqual(types.Method.copy, folder.primaryMethod());
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

test "7z Folder rejects truncated standalone BCJ2 graph" {
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
    try std.testing.expectError(error.TruncatedFrame, parseFolder(&reader, 0));
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
