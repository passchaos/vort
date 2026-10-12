const std = @import("std");
const bsdiff = @import("bsdiff.zig");
const codec = @import("puffin_codec.zig");
const format = @import("format.zig");
const protobuf = @import("protobuf.zig");

pub const Error = format.Error || protobuf.Error || bsdiff.Error ||
    codec.Error || std.mem.Allocator.Error;

pub const ApplyOptions = struct {
    max_output_len: usize = std.math.maxInt(usize),
    max_header_len: usize = 16 * 1024 * 1024,
    max_extents: usize = 1 << 20,
    max_puff_stream_len: usize = 1024 * 1024 * 1024,
    max_bsdiff_control_bytes: usize = 64 * 1024 * 1024,
};

const Extent = struct {
    offset: u64,
    length: u64,
};

const StreamInfo = struct {
    deflates: []Extent,
    puffs: []Extent,
    puff_length: usize,

    fn deinit(self: *StreamInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.deflates);
        allocator.free(self.puffs);
        self.* = undefined;
    }
};

const Header = struct {
    source: StreamInfo,
    destination: StreamInfo,
    inner_patch: []const u8,

    fn deinit(self: *Header, allocator: std.mem.Allocator) void {
        self.source.deinit(allocator);
        self.destination.deinit(allocator);
        self.* = undefined;
    }
};

pub fn applyAlloc(
    allocator: std.mem.Allocator,
    source: []const u8,
    patch: []const u8,
    expected_output_len: usize,
    options: ApplyOptions,
) Error![]u8 {
    if (expected_output_len > options.max_output_len)
        return error.OutputLimitExceeded;
    var header = try parseHeaderAlloc(allocator, patch, options);
    defer header.deinit(allocator);
    try validateMapping(
        header.source,
        source.len,
        options.max_extents,
    );
    try validateMapping(
        header.destination,
        expected_output_len,
        options.max_extents,
    );
    const source_puff = try puffStreamAlloc(
        allocator,
        source,
        header.source,
    );
    defer allocator.free(source_puff);
    const destination_puff = try bsdiff.applyAlloc(
        allocator,
        source_puff,
        header.inner_patch,
        header.destination.puff_length,
        .{
            .max_output_len = options.max_puff_stream_len,
            .max_control_bytes = options.max_bsdiff_control_bytes,
        },
    );
    defer allocator.free(destination_puff);
    return huffStreamAlloc(
        allocator,
        destination_puff,
        header.destination,
        expected_output_len,
    );
}

pub fn decodedSizeAlloc(
    allocator: std.mem.Allocator,
    patch: []const u8,
    options: ApplyOptions,
) Error!usize {
    var header = try parseHeaderAlloc(allocator, patch, options);
    defer header.deinit(allocator);
    const size = try physicalLength(header.destination);
    if (size > options.max_output_len) return error.OutputLimitExceeded;
    return size;
}

fn parseHeaderAlloc(
    allocator: std.mem.Allocator,
    patch: []const u8,
    options: ApplyOptions,
) Error!Header {
    if (patch.len < 8) return error.TruncatedFrame;
    if (!std.mem.eql(u8, patch[0..4], "PUF1"))
        return error.InvalidPuffinPatch;
    const header_len: usize = std.mem.readInt(u32, patch[4..8], .big);
    if (header_len > options.max_header_len)
        return error.OutputLimitExceeded;
    if (header_len > patch.len - 8) return error.TruncatedFrame;
    const header_bytes = patch[8..][0..header_len];
    var version: u64 = 0;
    var version_seen = false;
    var source: ?StreamInfo = null;
    errdefer if (source) |*value| value.deinit(allocator);
    var destination: ?StreamInfo = null;
    errdefer if (destination) |*value| value.deinit(allocator);
    var patch_type: u64 = 0;
    var patch_type_seen = false;
    var reader = protobuf.Reader.init(header_bytes);
    while (try reader.next()) |field| switch (field.number) {
        1 => {
            if (version_seen) return error.InvalidPuffinPatch;
            version_seen = true;
            version = try protobuf.expectVarint(field);
        },
        2 => {
            if (source != null) return error.InvalidPuffinPatch;
            source = try parseStreamInfoAlloc(
                allocator,
                try protobuf.expectBytes(field),
                options,
            );
        },
        3 => {
            if (destination != null) return error.InvalidPuffinPatch;
            destination = try parseStreamInfoAlloc(
                allocator,
                try protobuf.expectBytes(field),
                options,
            );
        },
        4 => {
            if (patch_type_seen) return error.InvalidPuffinPatch;
            patch_type_seen = true;
            patch_type = try protobuf.expectVarint(field);
        },
        else => {},
    };
    if (version != 1) return error.UnsupportedVersion;
    if (patch_type != 0) return error.UnsupportedPuffinPatch;
    return .{
        .source = source orelse return error.InvalidPuffinPatch,
        .destination = destination orelse return error.InvalidPuffinPatch,
        .inner_patch = patch[8 + header_len ..],
    };
}

fn parseStreamInfoAlloc(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    options: ApplyOptions,
) Error!StreamInfo {
    var deflates: std.ArrayList(Extent) = .empty;
    errdefer deflates.deinit(allocator);
    var puffs_bits: std.ArrayList(Extent) = .empty;
    defer puffs_bits.deinit(allocator);
    var puff_length: u64 = 0;
    var puff_length_seen = false;
    var reader = protobuf.Reader.init(bytes);
    while (try reader.next()) |field| switch (field.number) {
        1 => {
            if (deflates.items.len >= options.max_extents)
                return error.OutputLimitExceeded;
            try deflates.append(
                allocator,
                try parseExtent(try protobuf.expectBytes(field)),
            );
        },
        2 => {
            if (puffs_bits.items.len >= options.max_extents)
                return error.OutputLimitExceeded;
            try puffs_bits.append(
                allocator,
                try parseExtent(try protobuf.expectBytes(field)),
            );
        },
        3 => {
            if (puff_length_seen) return error.InvalidPuffinPatch;
            puff_length_seen = true;
            puff_length = try protobuf.expectVarint(field);
        },
        else => {},
    };
    if (deflates.items.len != puffs_bits.items.len)
        return error.InvalidPuffinPatch;
    const puff_length_usize = std.math.cast(usize, puff_length) orelse
        return error.OutputLimitExceeded;
    if (puff_length_usize > options.max_puff_stream_len)
        return error.OutputLimitExceeded;
    const puffs = try allocator.alloc(Extent, puffs_bits.items.len);
    errdefer allocator.free(puffs);
    for (puffs_bits.items, puffs) |encoded, *decoded| {
        if (encoded.offset % 8 != 0 or encoded.length % 8 != 0)
            return error.InvalidPuffinPatch;
        decoded.* = .{
            .offset = encoded.offset / 8,
            .length = encoded.length / 8,
        };
    }
    return .{
        .deflates = try deflates.toOwnedSlice(allocator),
        .puffs = puffs,
        .puff_length = puff_length_usize,
    };
}

fn parseExtent(bytes: []const u8) Error!Extent {
    var offset: u64 = 0;
    var offset_seen = false;
    var length: u64 = 0;
    var length_seen = false;
    var reader = protobuf.Reader.init(bytes);
    while (try reader.next()) |field| switch (field.number) {
        1 => {
            if (offset_seen) return error.InvalidPuffinPatch;
            offset_seen = true;
            offset = try protobuf.expectVarint(field);
        },
        2 => {
            if (length_seen) return error.InvalidPuffinPatch;
            length_seen = true;
            length = try protobuf.expectVarint(field);
        },
        else => {},
    };
    if (length == 0) return error.InvalidPuffinPatch;
    return .{ .offset = offset, .length = length };
}

fn validateMapping(
    info: StreamInfo,
    physical_len: usize,
    max_extents: usize,
) Error!void {
    if (info.deflates.len != info.puffs.len or
        info.deflates.len > max_extents)
        return error.InvalidPuffinPatch;
    var previous_deflate_end: u64 = 0;
    var previous_puff_end: u64 = 0;
    for (info.deflates, info.puffs) |deflate, puff| {
        const deflate_end = std.math.add(u64, deflate.offset, deflate.length) catch
            return error.IntegerOverflow;
        const puff_end = std.math.add(u64, puff.offset, puff.length) catch
            return error.IntegerOverflow;
        if (deflate.offset < previous_deflate_end or
            puff.offset < previous_puff_end or
            deflate_end > @as(u64, physical_len) * 8 or
            puff_end > info.puff_length)
            return error.InvalidPuffinPatch;
        previous_deflate_end = deflate_end;
        previous_puff_end = puff_end;
    }
}

fn physicalLength(info: StreamInfo) Error!usize {
    if (info.puffs.len == 0) return info.puff_length;
    const deflate = info.deflates[info.deflates.len - 1];
    const puff = info.puffs[info.puffs.len - 1];
    const deflate_end = std.math.add(u64, deflate.offset, deflate.length) catch
        return error.IntegerOverflow;
    const puff_end = std.math.add(u64, puff.offset, puff.length) catch
        return error.IntegerOverflow;
    if (puff_end > info.puff_length) return error.InvalidPuffinPatch;
    const physical_u64 = std.math.add(
        u64,
        deflate_end / 8,
        info.puff_length - puff_end,
    ) catch return error.IntegerOverflow;
    return std.math.cast(usize, physical_u64) orelse
        return error.OutputLimitExceeded;
}

fn puffStreamAlloc(
    allocator: std.mem.Allocator,
    source: []const u8,
    info: StreamInfo,
) Error![]u8 {
    const output = try allocator.alloc(u8, info.puff_length);
    errdefer allocator.free(output);
    var output_offset: usize = 0;
    var puff_position: u64 = 0;
    var deflate_position: u64 = 0;
    var extent_index: usize = 0;
    while (output_offset < output.len) {
        const deflate = if (extent_index < info.deflates.len)
            info.deflates[extent_index]
        else
            Extent{ .offset = @as(u64, source.len) * 8, .length = 0 };
        const puff = if (extent_index < info.puffs.len)
            info.puffs[extent_index]
        else
            Extent{ .offset = info.puff_length, .length = 0 };
        if (puff_position < puff.offset) {
            const start_byte = deflate_position / 8;
            const end_byte = (deflate.offset + 7) / 8;
            if (end_byte <= start_byte) return error.InvalidPuffinPatch;
            const count_u64 = @min(
                output.len - output_offset,
                end_byte - start_byte,
            );
            const count: usize = @intCast(count_u64);
            const source_start: usize = @intCast(start_byte);
            if (source_start > source.len or count > source.len - source_start)
                return error.InvalidPuffinPatch;
            @memcpy(output[output_offset..][0..count], source[source_start..][0..count]);
            if ((start_byte + count) * 8 > deflate.offset) {
                const keep: u3 = @intCast(deflate.offset & 7);
                output[output_offset + count - 1] &=
                    if (keep == 0) 0 else (@as(u8, 1) << keep) - 1;
            }
            if (start_byte * 8 < deflate_position)
                output[output_offset] >>= @intCast(deflate_position & 7);
            deflate_position = start_byte * 8 + count_u64 * 8;
            if (deflate_position > deflate.offset)
                deflate_position = deflate.offset;
            output_offset += count;
            puff_position += count_u64;
        } else {
            if (puff_position != puff.offset or extent_index >= info.deflates.len)
                return error.InvalidPuffinPatch;
            const transformed = try codec.puffDeflateAlloc(
                allocator,
                source,
                deflate.offset,
                deflate.length,
                @intCast(puff.length),
            );
            defer allocator.free(transformed);
            if (transformed.len != puff.length or transformed.len > output.len - output_offset)
                return error.SizeMismatch;
            @memcpy(output[output_offset..][0..transformed.len], transformed);
            output_offset += transformed.len;
            puff_position += puff.length;
            deflate_position = deflate.offset + deflate.length;
            extent_index += 1;
        }
    }
    if (puff_position != info.puff_length or extent_index != info.deflates.len)
        return error.InvalidPuffinPatch;
    return output;
}

fn huffStreamAlloc(
    allocator: std.mem.Allocator,
    puff_stream: []const u8,
    info: StreamInfo,
    output_len: usize,
) Error![]u8 {
    if (puff_stream.len != info.puff_length) return error.SizeMismatch;
    const output = try allocator.alloc(u8, output_len);
    errdefer allocator.free(output);
    @memset(output, 0);
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    var puff_position: u64 = 0;
    var deflate_position: u64 = 0;
    var last_byte: u8 = 0;
    var extent_index: usize = 0;
    while (input_offset < puff_stream.len) {
        const deflate = if (extent_index < info.deflates.len)
            info.deflates[extent_index]
        else
            Extent{ .offset = @as(u64, output_len) * 8, .length = 0 };
        const puff = if (extent_index < info.puffs.len)
            info.puffs[extent_index]
        else
            Extent{ .offset = info.puff_length, .length = 0 };
        if (deflate_position < (deflate.offset & ~@as(u64, 7))) {
            const count_u64 = @min(
                puff_stream.len - input_offset,
                deflate.offset / 8 - deflate_position / 8,
            );
            const count: usize = @intCast(count_u64);
            if (count == 0 or count > output.len - output_offset)
                return error.InvalidPuffinPatch;
            @memcpy(output[output_offset..][0..count], puff_stream[input_offset..][0..count]);
            input_offset += count;
            output_offset += count;
            puff_position += count_u64;
            deflate_position += count_u64 * 8;
            continue;
        }
        if (extent_index >= info.deflates.len or puff_position > puff.offset)
            return error.InvalidPuffinPatch;
        if (deflate_position < deflate.offset) {
            if (input_offset >= puff_stream.len) return error.TruncatedFrame;
            last_byte |= puff_stream[input_offset] << @intCast(deflate_position & 7);
            input_offset += 1;
            puff_position += 1;
            deflate_position = deflate.offset;
        }
        if (puff_position != puff.offset or puff.length > puff_stream.len - input_offset)
            return error.InvalidPuffinPatch;
        const end_bit = deflate.offset + deflate.length;
        const extra_byte: usize = if ((end_bit & 7) != 0 and
            ((end_bit + 7) & ~@as(u64, 7)) <= nextDeflateOffset(info, extent_index, output_len))
            1
        else
            0;
        if (puff.length + extra_byte > puff_stream.len - input_offset)
            return error.TruncatedFrame;
        const transformed = try codec.huffDeflateAlloc(
            allocator,
            puff_stream[input_offset..][0..@intCast(puff.length)],
            @intCast(deflate.offset & 7),
            deflate.length,
        );
        defer allocator.free(transformed);
        if (transformed.len == 0) return error.InvalidPuffinStream;
        transformed[0] |= last_byte;
        last_byte = 0;
        var write_len = transformed.len;
        deflate_position = end_bit;
        if (extra_byte == 1) {
            transformed[transformed.len - 1] |=
                puff_stream[input_offset + @as(usize, @intCast(puff.length))] << @intCast(end_bit & 7);
            deflate_position = (end_bit + 7) & ~@as(u64, 7);
        } else if (end_bit & 7 != 0) {
            last_byte = transformed[transformed.len - 1];
            write_len -= 1;
        }
        if (write_len > output.len - output_offset)
            return error.OutputTooSmall;
        @memcpy(output[output_offset..][0..write_len], transformed[0..write_len]);
        output_offset += write_len;
        input_offset += @intCast(puff.length + extra_byte);
        puff_position += puff.length + extra_byte;
        extent_index += 1;
    }
    if (input_offset != puff_stream.len or output_offset != output.len or
        extent_index != info.deflates.len or last_byte != 0)
        return error.SizeMismatch;
    return output;
}

fn nextDeflateOffset(info: StreamInfo, index: usize, output_len: usize) u64 {
    return if (index + 1 < info.deflates.len)
        info.deflates[index + 1].offset
    else
        @as(u64, output_len) * 8;
}

test "Android OTA Puffin applies the pinned AOSP fixed and stored patch" {
    const allocator = std.testing.allocator;
    const source = [_]u8{
        0x11, 0x22, 0x63, 0x64, 0x62, 0x66, 0x61, 0x05, 0x00,
        0x33, 0x03, 0x00, 0x63, 0x04, 0x00, 0x44, 0x55,
    };
    const expected = [_]u8{
        0x63, 0x64, 0x62, 0x66, 0x61, 0x05, 0x00, 0x33, 0x66,
        0x01, 0x05, 0x00, 0xfa, 0xff, 1,    2,    3,    4,
        5,    0x63, 0x04, 0x00,
    };
    const patch = &test_puffdiff_fixture;
    const decoded = try applyAlloc(
        allocator,
        &source,
        patch,
        expected.len,
        .{ .max_output_len = 4096 },
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &expected, decoded);
}

test "Android OTA Puffin maps non-byte-aligned deflate extents reversibly" {
    const allocator = std.testing.allocator;
    const deflate = [_]u8{ 0x63, 0x64, 0x62, 0x66, 0x61, 0x05, 0x00 };
    var source = [_]u8{ 0xa5, 0x5a, 0xc3, 0x3c, 0x96, 0x69, 0xf0, 0x0f, 0x77 };
    const bit_offset = 3;
    const bit_length = 50;
    for (0..bit_length) |index| {
        const destination_bit = bit_offset + index;
        const value = (deflate[index / 8] >> @intCast(index % 8)) & 1;
        const mask = @as(u8, 1) << @intCast(destination_bit % 8);
        if (value != 0)
            source[destination_bit / 8] |= mask
        else
            source[destination_bit / 8] &= ~mask;
    }
    const deflates = [_]Extent{.{ .offset = bit_offset, .length = bit_length }};
    const puffs = [_]Extent{.{ .offset = 1, .length = 11 }};
    const info = StreamInfo{
        .deflates = @constCast(&deflates),
        .puffs = @constCast(&puffs),
        .puff_length = 15,
    };
    const puffed = try puffStreamAlloc(allocator, &source, info);
    defer allocator.free(puffed);
    const restored = try huffStreamAlloc(allocator, puffed, info, source.len);
    defer allocator.free(restored);
    try std.testing.expectEqualSlices(u8, &source, restored);
}

test "Android OTA Puffin rejects malformed and over-limit patches" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(
        error.TruncatedFrame,
        applyAlloc(allocator, "", "PUF1", 0, .{}),
    );
    var bad_magic = test_puffdiff_fixture;
    bad_magic[0] ^= 1;
    try std.testing.expectError(
        error.InvalidPuffinPatch,
        applyAlloc(allocator, "", &bad_magic, 0, .{}),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        applyAlloc(
            allocator,
            "",
            &test_puffdiff_fixture,
            22,
            .{ .max_output_len = 21 },
        ),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        applyAlloc(
            allocator,
            "",
            &test_puffdiff_fixture,
            22,
            .{ .max_header_len = 1 },
        ),
    );
    var bad_version = test_puffdiff_fixture;
    bad_version[9] = 2;
    try std.testing.expectError(
        error.UnsupportedVersion,
        applyAlloc(allocator, "", &bad_version, 22, .{}),
    );
}

pub const test_puffdiff_fixture = [_]u8{
    0x50, 0x55, 0x46, 0x31, 0x00, 0x00, 0x00, 0x51, 0x08, 0x01, 0x12, 0x27, 0x0a, 0x04, 0x08, 0x10,
    0x10, 0x32, 0x0a, 0x04, 0x08, 0x50, 0x10, 0x0a, 0x0a, 0x04, 0x08, 0x60, 0x10, 0x12, 0x12, 0x04,
    0x08, 0x10, 0x10, 0x58, 0x12, 0x04, 0x08, 0x78, 0x10, 0x28, 0x12, 0x05, 0x08, 0xa8, 0x01, 0x10,
    0x38, 0x18, 0x1f, 0x1a, 0x24, 0x0a, 0x02, 0x10, 0x32, 0x0a, 0x04, 0x08, 0x48, 0x10, 0x50, 0x0a,
    0x05, 0x08, 0x98, 0x01, 0x10, 0x12, 0x12, 0x02, 0x10, 0x58, 0x12, 0x04, 0x08, 0x70, 0x10, 0x58,
    0x12, 0x05, 0x08, 0xc8, 0x01, 0x10, 0x38, 0x18, 0x21, 0x42, 0x53, 0x44, 0x49, 0x46, 0x46, 0x34,
    0x30, 0x38, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x34, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x21, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x42, 0x5a, 0x68, 0x39, 0x31, 0x41, 0x59,
    0x26, 0x53, 0x59, 0x65, 0x29, 0x8c, 0x9b, 0x00, 0x00, 0x03, 0x60, 0x40, 0x7a, 0x0e, 0x08, 0x00,
    0x40, 0x00, 0x20, 0x00, 0x21, 0x22, 0x9a, 0x3d, 0x4f, 0x50, 0x40, 0x0c, 0x3b, 0xc7, 0x9b, 0xb2,
    0x21, 0x0e, 0xe9, 0x15, 0x98, 0x7a, 0x7c, 0x5d, 0xc9, 0x14, 0xe1, 0x42, 0x41, 0x94, 0xa6, 0x32,
    0x6c, 0x42, 0x5a, 0x68, 0x39, 0x31, 0x41, 0x59, 0x26, 0x53, 0x59, 0xf1, 0x20, 0x5f, 0x0d, 0x00,
    0x00, 0x02, 0x41, 0x15, 0x42, 0x08, 0x20, 0x00, 0x40, 0x00, 0x00, 0x02, 0x40, 0x00, 0x20, 0x00,
    0x22, 0x3d, 0x23, 0x10, 0x86, 0x03, 0x96, 0x54, 0x11, 0x16, 0x5f, 0x17, 0x72, 0x45, 0x38, 0x50,
    0x90, 0xf1, 0x20, 0x5f, 0x0d, 0x42, 0x5a, 0x68, 0x39, 0x31, 0x41, 0x59, 0x26, 0x53, 0x59, 0x07,
    0xd4, 0xcb, 0x6e, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x20, 0x00, 0x21, 0x18, 0x46, 0x82,
    0xee, 0x48, 0xa7, 0x0a, 0x12, 0x00, 0xfa, 0x99, 0x6d, 0xc0,
};
