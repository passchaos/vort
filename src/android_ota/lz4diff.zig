const std = @import("std");
const bzip2 = @import("../bzip2.zig");
const lz4 = @import("../lz4.zig");
const bsdiff = @import("bsdiff.zig");
const format = @import("format.zig");
const protobuf = @import("protobuf.zig");
const puffin = @import("puffin.zig");

pub const Error = format.Error || protobuf.Error || lz4.Error ||
    bsdiff.Error || puffin.Error || std.mem.Allocator.Error;

pub const magic = "LZ4DIFF";
pub const version: u32 = 1;
pub const fixed_header_len: usize = 16;

pub const CompressionType = enum(u32) {
    uncompressed = 0,
    lz4 = 1,
    lz4hc = 2,
    _,
};

pub const InnerPatchType = enum(u32) {
    bsdiff = 0,
    puffdiff = 1,
    _,
};

pub const Block = struct {
    uncompressed_offset: usize,
    uncompressed_length: usize,
    compressed_length: usize,
    sha256_hash: []const u8,
    postfix_bspatch: []const u8,

    pub fn isCompressed(self: Block) bool {
        return self.compressed_length < self.uncompressed_length;
    }
};

pub const CompressionInfo = struct {
    compression: CompressionType,
    level: i32,
    blocks: []Block,
    zero_padding_enabled: bool,

    fn deinit(self: *CompressionInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.blocks);
        self.* = undefined;
    }
};

pub const Patch = struct {
    allocator: std.mem.Allocator,
    source: CompressionInfo,
    destination: CompressionInfo,
    inner_type: InnerPatchType,
    inner_patch: []const u8,

    pub fn initAlloc(
        allocator: std.mem.Allocator,
        bytes: []const u8,
        options: ParseOptions,
    ) Error!Patch {
        return parseAlloc(allocator, bytes, options);
    }

    pub fn deinit(self: *Patch) void {
        self.source.deinit(self.allocator);
        self.destination.deinit(self.allocator);
        self.* = undefined;
    }
};

pub const ParseOptions = struct {
    max_header_len: usize = 16 * 1024 * 1024,
    max_blocks: usize = 1 << 20,
    max_decompressed_len: usize = 1024 * 1024 * 1024,
};

pub const ApplyOptions = struct {
    max_output_len: usize = std.math.maxInt(usize),
    max_header_len: usize = 16 * 1024 * 1024,
    max_blocks: usize = 1 << 20,
    max_decompressed_len: usize = 1024 * 1024 * 1024,
    max_bsdiff_control_bytes: usize = 64 * 1024 * 1024,
    max_puffin_header_len: usize = 16 * 1024 * 1024,
    max_puffin_extents: usize = 1 << 20,
    max_puff_stream_len: usize = 1024 * 1024 * 1024,
};

pub fn parseAlloc(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    options: ParseOptions,
) Error!Patch {
    if (bytes.len < fixed_header_len) return error.TruncatedFrame;
    if (!std.mem.eql(u8, bytes[0..magic.len], magic))
        return error.InvalidLz4diffPatch;
    if (std.mem.readInt(u32, bytes[magic.len..][0..4], .big) != version)
        return error.UnsupportedVersion;
    const protobuf_len: usize = std.mem.readInt(
        u32,
        bytes[magic.len + 4 ..][0..4],
        .big,
    );
    if (protobuf_len > options.max_header_len)
        return error.OutputLimitExceeded;
    if (protobuf_len > bytes.len - fixed_header_len)
        return error.TruncatedFrame;
    const protobuf_bytes = bytes[fixed_header_len..][0..protobuf_len];

    var source: ?CompressionInfo = null;
    errdefer if (source) |*info| info.deinit(allocator);
    var destination: ?CompressionInfo = null;
    errdefer if (destination) |*info| info.deinit(allocator);
    var inner_type: InnerPatchType = .bsdiff;
    var inner_type_seen = false;
    var reader = protobuf.Reader.init(protobuf_bytes);
    while (try reader.next()) |field| switch (field.number) {
        1 => {
            if (source != null) return error.InvalidLz4diffPatch;
            source = try parseCompressionInfoAlloc(
                allocator,
                try protobuf.expectBytes(field),
                options,
            );
        },
        2 => {
            if (destination != null) return error.InvalidLz4diffPatch;
            destination = try parseCompressionInfoAlloc(
                allocator,
                try protobuf.expectBytes(field),
                options,
            );
        },
        3 => {
            if (inner_type_seen) return error.InvalidLz4diffPatch;
            inner_type_seen = true;
            const raw = try protobuf.expectVarint(field);
            inner_type = @enumFromInt(std.math.cast(u32, raw) orelse
                return error.InvalidLz4diffPatch);
        },
        else => {},
    };
    const source_value = source orelse return error.InvalidLz4diffPatch;
    source = null;
    errdefer {
        var info = source_value;
        info.deinit(allocator);
    }
    const destination_value = destination orelse
        return error.InvalidLz4diffPatch;
    destination = null;
    errdefer {
        var info = destination_value;
        info.deinit(allocator);
    }
    _ = try validateInfo(
        source_value,
        std.math.maxInt(usize),
        options.max_decompressed_len,
        false,
    );
    _ = try validateInfo(
        destination_value,
        std.math.maxInt(usize),
        options.max_decompressed_len,
        false,
    );
    return .{
        .allocator = allocator,
        .source = source_value,
        .destination = destination_value,
        .inner_type = inner_type,
        .inner_patch = bytes[fixed_header_len + protobuf_len ..],
    };
}

pub fn applyAlloc(
    allocator: std.mem.Allocator,
    source_bytes: []const u8,
    patch_bytes: []const u8,
    expected_output_len: usize,
    options: ApplyOptions,
) Error![]u8 {
    if (expected_output_len > options.max_output_len)
        return error.OutputLimitExceeded;
    var patch = try parseAlloc(allocator, patch_bytes, .{
        .max_header_len = options.max_header_len,
        .max_blocks = options.max_blocks,
        .max_decompressed_len = options.max_decompressed_len,
    });
    defer patch.deinit();
    const source_sizes = try validateInfo(
        patch.source,
        source_bytes.len,
        options.max_decompressed_len,
        false,
    );
    const destination_sizes = try validateInfo(
        patch.destination,
        options.max_output_len,
        options.max_decompressed_len,
        true,
    );
    if (source_sizes.compressed != source_bytes.len or
        destination_sizes.compressed != expected_output_len)
        return error.SizeMismatch;

    const source_uncompressed = try decompressAlloc(
        allocator,
        source_bytes,
        patch.source,
        source_sizes.uncompressed,
    );
    defer allocator.free(source_uncompressed);
    const destination_uncompressed = switch (patch.inner_type) {
        .bsdiff => try bsdiff.applyAlloc(
            allocator,
            source_uncompressed,
            patch.inner_patch,
            destination_sizes.uncompressed,
            .{
                .max_output_len = options.max_decompressed_len,
                .max_control_bytes = options.max_bsdiff_control_bytes,
            },
        ),
        .puffdiff => try puffin.applyAlloc(
            allocator,
            source_uncompressed,
            patch.inner_patch,
            destination_sizes.uncompressed,
            .{
                .max_output_len = options.max_decompressed_len,
                .max_header_len = options.max_puffin_header_len,
                .max_extents = options.max_puffin_extents,
                .max_puff_stream_len = options.max_puff_stream_len,
                .max_bsdiff_control_bytes = options.max_bsdiff_control_bytes,
            },
        ),
        else => return error.UnsupportedLz4diffPatch,
    };
    defer allocator.free(destination_uncompressed);
    return compressAlloc(
        allocator,
        destination_uncompressed,
        patch.destination,
        destination_sizes.compressed,
        options,
    );
}

const Sizes = struct {
    compressed: usize,
    uncompressed: usize,
};

fn validateInfo(
    info: CompressionInfo,
    max_compressed_len: usize,
    max_decompressed_len: usize,
    for_compression: bool,
) Error!Sizes {
    var compressed: usize = 0;
    var uncompressed: usize = 0;
    var has_compressed_block = false;
    for (info.blocks) |block| {
        if (block.uncompressed_offset != uncompressed or
            block.uncompressed_length == 0 or
            block.compressed_length == 0 or
            block.compressed_length > block.uncompressed_length)
            return error.InvalidLz4diffPatch;
        if (block.isCompressed()) has_compressed_block = true;
        compressed = std.math.add(
            usize,
            compressed,
            block.compressed_length,
        ) catch return error.IntegerOverflow;
        uncompressed = std.math.add(
            usize,
            uncompressed,
            block.uncompressed_length,
        ) catch return error.IntegerOverflow;
        if (compressed > max_compressed_len or
            uncompressed > max_decompressed_len)
            return error.OutputLimitExceeded;
        if (block.sha256_hash.len != 0 and block.sha256_hash.len != 32)
            return error.InvalidLz4diffPatch;
    }
    if (info.blocks.len == 0) return error.InvalidLz4diffPatch;
    if (for_compression and has_compressed_block) switch (info.compression) {
        .lz4, .lz4hc => {},
        else => return error.UnsupportedLz4diffCompression,
    };
    return .{ .compressed = compressed, .uncompressed = uncompressed };
}

fn parseCompressionInfoAlloc(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    options: ParseOptions,
) Error!CompressionInfo {
    var compression: CompressionType = .uncompressed;
    var level: i32 = 0;
    var algorithm_seen = false;
    var zero_padding_enabled = false;
    var zero_padding_seen = false;
    var blocks: std.ArrayList(Block) = .empty;
    errdefer blocks.deinit(allocator);
    var reader = protobuf.Reader.init(bytes);
    while (try reader.next()) |field| switch (field.number) {
        1 => {
            if (algorithm_seen) return error.InvalidLz4diffPatch;
            algorithm_seen = true;
            const parsed = try parseAlgorithm(try protobuf.expectBytes(field));
            compression = parsed.compression;
            level = parsed.level;
        },
        2 => {
            if (blocks.items.len >= options.max_blocks)
                return error.OutputLimitExceeded;
            try blocks.append(
                allocator,
                try parseBlock(try protobuf.expectBytes(field)),
            );
        },
        3 => {
            if (zero_padding_seen) return error.InvalidLz4diffPatch;
            zero_padding_seen = true;
            zero_padding_enabled = switch (try protobuf.expectVarint(field)) {
                0 => false,
                1 => true,
                else => return error.InvalidLz4diffPatch,
            };
        },
        else => {},
    };
    return .{
        .compression = compression,
        .level = level,
        .blocks = try blocks.toOwnedSlice(allocator),
        .zero_padding_enabled = zero_padding_enabled,
    };
}

fn parseAlgorithm(bytes: []const u8) Error!struct {
    compression: CompressionType,
    level: i32,
} {
    var compression: CompressionType = .uncompressed;
    var compression_seen = false;
    var level: i32 = 0;
    var level_seen = false;
    var reader = protobuf.Reader.init(bytes);
    while (try reader.next()) |field| switch (field.number) {
        1 => {
            if (compression_seen) return error.InvalidLz4diffPatch;
            compression_seen = true;
            const raw = try protobuf.expectVarint(field);
            compression = @enumFromInt(std.math.cast(u32, raw) orelse
                return error.InvalidLz4diffPatch);
        },
        2 => {
            if (level_seen) return error.InvalidLz4diffPatch;
            level_seen = true;
            const raw = try protobuf.expectVarint(field);
            level = @bitCast(@as(u32, @truncate(raw)));
        },
        else => {},
    };
    return .{ .compression = compression, .level = level };
}

fn parseBlock(bytes: []const u8) Error!Block {
    var block: Block = .{
        .uncompressed_offset = 0,
        .uncompressed_length = 0,
        .compressed_length = 0,
        .sha256_hash = "",
        .postfix_bspatch = "",
    };
    var seen: u5 = 0;
    var reader = protobuf.Reader.init(bytes);
    while (try reader.next()) |field| switch (field.number) {
        1, 2, 3 => {
            const bit: u5 = @as(u5, 1) << @intCast(field.number - 1);
            if (seen & bit != 0) return error.InvalidLz4diffPatch;
            seen |= bit;
            const value = std.math.cast(
                usize,
                try protobuf.expectVarint(field),
            ) orelse return error.OutputLimitExceeded;
            switch (field.number) {
                1 => block.uncompressed_offset = value,
                2 => block.uncompressed_length = value,
                3 => block.compressed_length = value,
                else => unreachable,
            }
        },
        4, 5 => {
            const bit: u5 = @as(u5, 1) << @intCast(field.number - 1);
            if (seen & bit != 0) return error.InvalidLz4diffPatch;
            seen |= bit;
            const value = try protobuf.expectBytes(field);
            if (field.number == 4)
                block.sha256_hash = value
            else
                block.postfix_bspatch = value;
        },
        else => {},
    };
    return block;
}

fn decompressAlloc(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    info: CompressionInfo,
    output_len: usize,
) Error![]u8 {
    const output = try allocator.alloc(u8, output_len);
    errdefer allocator.free(output);
    var compressed_offset: usize = 0;
    for (info.blocks) |block| {
        const cluster = bytes[compressed_offset..][0..block.compressed_length];
        const destination = output[block.uncompressed_offset..][0..block.uncompressed_length];
        if (!block.isCompressed()) {
            @memcpy(destination, cluster);
        } else {
            var padding: usize = 0;
            if (info.zero_padding_enabled) {
                const padding_limit = @min(@as(usize, 4096), cluster.len);
                while (padding < padding_limit and cluster[padding] == 0)
                    padding += 1;
            }
            try decodePartial(cluster[padding..], destination);
        }
        compressed_offset += block.compressed_length;
    }
    return output;
}

fn compressAlloc(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    info: CompressionInfo,
    output_len: usize,
    options: ApplyOptions,
) Error![]u8 {
    const output = try allocator.alloc(u8, output_len);
    errdefer allocator.free(output);
    var hc_encoder: ?lz4.HcDestSizeEncoder = if (info.compression == .lz4hc)
        try lz4.HcDestSizeEncoder.init(allocator)
    else
        null;
    defer if (hc_encoder) |*encoder| encoder.deinit();
    var compressed_offset: usize = 0;
    for (info.blocks) |block| {
        const destination = output[compressed_offset..][0..block.compressed_length];
        const uncompressed = bytes[block.uncompressed_offset..];
        if (!block.isCompressed()) {
            @memcpy(destination, uncompressed[0..block.uncompressed_length]);
        } else {
            const result = switch (info.compression) {
                .lz4 => try lz4.encodeBlockDestSize(uncompressed, destination),
                .lz4hc => try hc_encoder.?.encode(
                    uncompressed,
                    destination,
                    info.level,
                ),
                else => return error.UnsupportedLz4diffCompression,
            };
            if (result.consumed != block.uncompressed_length)
                return error.SizeMismatch;
            if (result.written < destination.len) {
                const padding = destination.len - result.written;
                if (info.zero_padding_enabled) {
                    std.mem.copyBackwards(
                        u8,
                        destination[padding..],
                        destination[0..result.written],
                    );
                    @memset(destination[0..padding], 0);
                } else {
                    @memset(destination[result.written..], 0);
                }
            }
        }

        if (block.postfix_bspatch.len != 0) {
            if (block.sha256_hash.len != 0)
                try verifySha256(destination, block.sha256_hash);
            const fixed = try bsdiff.applyAlloc(
                allocator,
                destination,
                block.postfix_bspatch,
                block.compressed_length,
                .{
                    .max_output_len = options.max_output_len,
                    .max_control_bytes = options.max_bsdiff_control_bytes,
                },
            );
            defer allocator.free(fixed);
            @memcpy(destination, fixed);
        }
        compressed_offset += block.compressed_length;
    }
    return output;
}

fn decodePartial(input: []const u8, output: []u8) Error!void {
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (output_offset < output.len) {
        if (input_offset >= input.len) return error.TruncatedFrame;
        const token = input[input_offset];
        input_offset += 1;
        var literal_length: usize = token >> 4;
        if (literal_length == 15)
            literal_length = try readExtendedLength(input, &input_offset, 15);
        if (literal_length > input.len - input_offset)
            return error.TruncatedFrame;
        if (literal_length > output.len - output_offset)
            return error.InvalidLz4diffPatch;
        @memcpy(
            output[output_offset..][0..literal_length],
            input[input_offset..][0..literal_length],
        );
        input_offset += literal_length;
        output_offset += literal_length;
        if (output_offset == output.len) return;
        if (input.len - input_offset < 2) return error.TruncatedFrame;
        const match_offset = std.mem.readInt(
            u16,
            input[input_offset..][0..2],
            .little,
        );
        input_offset += 2;
        if (match_offset == 0 or match_offset > output_offset)
            return error.InvalidLz4diffPatch;
        var match_length: usize = (token & 0x0f) + 4;
        if (token & 0x0f == 15)
            match_length = try readExtendedLength(input, &input_offset, 19);
        if (match_length > output.len - output_offset)
            return error.InvalidLz4diffPatch;
        const match_start = output_offset - match_offset;
        copyMatch(output, &output_offset, match_start, match_length);
    }
}

fn readExtendedLength(
    input: []const u8,
    offset: *usize,
    initial: usize,
) Error!usize {
    var length = initial;
    while (true) {
        if (offset.* >= input.len) return error.TruncatedFrame;
        const value = input[offset.*];
        offset.* += 1;
        length = std.math.add(usize, length, value) catch
            return error.IntegerOverflow;
        if (value != 255) return length;
    }
}

fn copyMatch(
    output: []u8,
    output_offset: *usize,
    match_start: usize,
    length: usize,
) void {
    const destination_start = output_offset.*;
    const initial_available = destination_start - match_start;
    var copied: usize = 0;
    while (copied < length) {
        const available = if (copied == 0) initial_available else copied;
        const count = @min(available, length - copied);
        const source_start = if (copied == 0) match_start else destination_start;
        @memcpy(
            output[destination_start + copied ..][0..count],
            output[source_start..][0..count],
        );
        copied += count;
    }
    output_offset.* += length;
}

fn verifySha256(bytes: []const u8, expected: []const u8) Error!void {
    if (expected.len != 32) return error.InvalidLz4diffPatch;
    var actual: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &actual, .{});
    if (!std.mem.eql(u8, &actual, expected))
        return error.ChecksumMismatch;
}

test "Android OTA LZ4DIFF fixed header preserves AOSP seven-byte magic layout" {
    var bytes: [fixed_header_len]u8 = @splat(0);
    @memcpy(bytes[0..magic.len], magic);
    std.mem.writeInt(u32, bytes[magic.len..][0..4], version, .big);
    std.mem.writeInt(u32, bytes[magic.len + 4 ..][0..4], 0, .big);
    try std.testing.expectEqual(@as(u8, 0), bytes[15]);
    try std.testing.expectError(
        error.InvalidLz4diffPatch,
        parseAlloc(std.testing.allocator, &bytes, .{}),
    );
}

test "Android OTA LZ4DIFF applies BSDIFF and exact LZ4HC recompression with postfix" {
    const allocator = std.testing.allocator;
    const source_logical = try allocator.alloc(u8, 8192);
    defer allocator.free(source_logical);
    const destination_logical = try allocator.alloc(u8, 8192);
    defer allocator.free(destination_logical);
    const source_phrase = "source LZ4DIFF block ";
    const destination_phrase = "target LZ4DIFF data ";
    for (source_logical, 0..) |*byte, index|
        byte.* = source_phrase[index % source_phrase.len];
    for (destination_logical, 0..) |*byte, index|
        byte.* = destination_phrase[index % destination_phrase.len];

    const source_physical = try compressedTestBlockAlloc(
        allocator,
        source_logical,
        4096,
        true,
        .lz4hc,
        7,
    );
    defer allocator.free(source_physical);
    const local_destination = try compressedTestBlockAlloc(
        allocator,
        destination_logical,
        4096,
        false,
        .lz4hc,
        5,
    );
    defer allocator.free(local_destination);
    const expected = try allocator.dupe(u8, local_destination);
    defer allocator.free(expected);
    expected[expected.len - 1] = 0xa5;

    const inner_patch = try testBsdiffPatchAlloc(
        allocator,
        source_logical,
        destination_logical,
    );
    defer allocator.free(inner_patch);
    const postfix = try testBsdiffPatchAlloc(
        allocator,
        local_destination,
        expected,
    );
    defer allocator.free(postfix);
    var local_hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(local_destination, &local_hash, .{});
    const patch = try testPatchAlloc(
        allocator,
        .lz4hc,
        7,
        source_logical.len,
        source_physical.len,
        true,
        .lz4hc,
        5,
        destination_logical.len,
        expected.len,
        false,
        &local_hash,
        postfix,
        .bsdiff,
        inner_patch,
    );
    defer allocator.free(patch);

    const decoded = try applyAlloc(
        allocator,
        source_physical,
        patch,
        expected.len,
        .{},
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);

    const corrupt = try allocator.dupe(u8, patch);
    defer allocator.free(corrupt);
    const hash_offset = std.mem.indexOf(u8, corrupt, &local_hash).?;
    corrupt[hash_offset] ^= 1;
    try std.testing.expectError(
        error.ChecksumMismatch,
        applyAlloc(
            allocator,
            source_physical,
            corrupt,
            expected.len,
            .{},
        ),
    );
}

test "Android OTA LZ4DIFF applies PUFFDIFF through uncompressed blocks" {
    const allocator = std.testing.allocator;
    const source_prefix = [_]u8{
        0x11, 0x22, 0x63, 0x64, 0x62, 0x66, 0x61, 0x05, 0x00,
        0x33, 0x03, 0x00, 0x63, 0x04, 0x00, 0x44, 0x55,
    };
    const expected_prefix = [_]u8{
        0x63, 0x64, 0x62, 0x66, 0x61, 0x05, 0x00, 0x33, 0x66,
        0x01, 0x05, 0x00, 0xfa, 0xff, 1,    2,    3,    4,
        5,    0x63, 0x04, 0x00,
    };
    const patch = try testPatchAlloc(
        allocator,
        .uncompressed,
        0,
        source_prefix.len,
        source_prefix.len,
        false,
        .uncompressed,
        0,
        expected_prefix.len,
        expected_prefix.len,
        false,
        "",
        "",
        .puffdiff,
        &puffin.test_puffdiff_fixture,
    );
    defer allocator.free(patch);
    const decoded = try applyAlloc(
        allocator,
        &source_prefix,
        patch,
        expected_prefix.len,
        .{},
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &expected_prefix, decoded);
}

test "Android OTA LZ4DIFF rejects malformed metadata and unknown compression" {
    const allocator = std.testing.allocator;
    const inner = try testBsdiffPatchAlloc(allocator, "abcd", "wxyz");
    defer allocator.free(inner);
    const patch = try testPatchAlloc(
        allocator,
        .lz4,
        0,
        8,
        4,
        false,
        @enumFromInt(99),
        0,
        8,
        4,
        false,
        "",
        "",
        .bsdiff,
        inner,
    );
    defer allocator.free(patch);
    try std.testing.expectError(
        error.UnsupportedLz4diffCompression,
        applyAlloc(allocator, "abcd", patch, 4, .{}),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        parseAlloc(allocator, patch, .{ .max_decompressed_len = 7 }),
    );
    try std.testing.expectError(
        error.TruncatedFrame,
        parseAlloc(allocator, patch[0..15], .{}),
    );
    const bad_version = try allocator.dupe(u8, patch);
    defer allocator.free(bad_version);
    bad_version[10] = 2;
    try std.testing.expectError(
        error.UnsupportedVersion,
        parseAlloc(allocator, bad_version, .{}),
    );
}

fn compressedTestBlockAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    capacity: usize,
    zero_padding_enabled: bool,
    compression: CompressionType,
    compression_level: i32,
) ![]u8 {
    const output = try allocator.alloc(u8, capacity);
    errdefer allocator.free(output);
    const result = switch (compression) {
        .lz4 => try lz4.encodeBlockDestSize(input, output),
        .lz4hc => try lz4.encodeBlockHcDestSize(
            allocator,
            input,
            output,
            compression_level,
        ),
        else => return error.TestUnexpectedResult,
    };
    if (result.consumed != input.len) return error.TestUnexpectedResult;
    const padding = capacity - result.written;
    if (zero_padding_enabled) {
        std.mem.copyBackwards(u8, output[padding..], output[0..result.written]);
        @memset(output[0..padding], 0);
    } else {
        @memset(output[result.written..], 0);
    }
    return output;
}

fn testPatchAlloc(
    allocator: std.mem.Allocator,
    source_compression: CompressionType,
    source_level: i32,
    source_uncompressed_len: usize,
    source_compressed_len: usize,
    source_zero_padding: bool,
    destination_compression: CompressionType,
    destination_level: i32,
    destination_uncompressed_len: usize,
    destination_compressed_len: usize,
    destination_zero_padding: bool,
    destination_hash: []const u8,
    postfix: []const u8,
    inner_type: InnerPatchType,
    inner_patch: []const u8,
) ![]u8 {
    const source = try testCompressionInfoAlloc(
        allocator,
        source_compression,
        source_level,
        source_uncompressed_len,
        source_compressed_len,
        source_zero_padding,
        "",
        "",
    );
    defer allocator.free(source);
    const destination = try testCompressionInfoAlloc(
        allocator,
        destination_compression,
        destination_level,
        destination_uncompressed_len,
        destination_compressed_len,
        destination_zero_padding,
        destination_hash,
        postfix,
    );
    defer allocator.free(destination);
    var header: std.ArrayList(u8) = .empty;
    defer header.deinit(allocator);
    try protobuf.appendMessageField(allocator, &header, 1, source);
    try protobuf.appendMessageField(allocator, &header, 2, destination);
    try protobuf.appendVarintField(
        allocator,
        &header,
        3,
        @intFromEnum(inner_type),
    );
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendSlice(allocator, magic);
    var number: [4]u8 = undefined;
    std.mem.writeInt(u32, &number, version, .big);
    try output.appendSlice(allocator, &number);
    std.mem.writeInt(u32, &number, @intCast(header.items.len), .big);
    try output.appendSlice(allocator, &number);
    try output.append(allocator, 0);
    try output.appendSlice(allocator, header.items);
    try output.appendSlice(allocator, inner_patch);
    return output.toOwnedSlice(allocator);
}

fn testCompressionInfoAlloc(
    allocator: std.mem.Allocator,
    compression: CompressionType,
    compression_level: i32,
    uncompressed_len: usize,
    compressed_len: usize,
    zero_padding: bool,
    hash: []const u8,
    postfix: []const u8,
) ![]u8 {
    var algorithm: std.ArrayList(u8) = .empty;
    defer algorithm.deinit(allocator);
    try protobuf.appendVarintField(
        allocator,
        &algorithm,
        1,
        @intFromEnum(compression),
    );
    if (compression_level != 0)
        try protobuf.appendVarintField(
            allocator,
            &algorithm,
            2,
            @as(u32, @bitCast(compression_level)),
        );
    var block: std.ArrayList(u8) = .empty;
    defer block.deinit(allocator);
    try protobuf.appendVarintField(allocator, &block, 2, uncompressed_len);
    try protobuf.appendVarintField(allocator, &block, 3, compressed_len);
    if (hash.len != 0)
        try protobuf.appendBytesField(allocator, &block, 4, hash);
    if (postfix.len != 0)
        try protobuf.appendBytesField(allocator, &block, 5, postfix);
    var info: std.ArrayList(u8) = .empty;
    errdefer info.deinit(allocator);
    try protobuf.appendMessageField(allocator, &info, 1, algorithm.items);
    try protobuf.appendMessageField(allocator, &info, 2, block.items);
    if (zero_padding)
        try protobuf.appendVarintField(allocator, &info, 3, 1);
    return info.toOwnedSlice(allocator);
}

fn testBsdiffPatchAlloc(
    allocator: std.mem.Allocator,
    source: []const u8,
    destination: []const u8,
) ![]u8 {
    if (source.len != destination.len) return error.TestUnexpectedResult;
    const diff = try allocator.alloc(u8, destination.len);
    defer allocator.free(diff);
    for (diff, source, destination) |*byte, old, new|
        byte.* = new -% old;
    var control: [24]u8 = @splat(0);
    std.mem.writeInt(u64, control[0..8], destination.len, .little);
    const control_compressed = try bzip2.encodeAlloc(allocator, &control, .{});
    defer allocator.free(control_compressed);
    const diff_compressed = try bzip2.encodeAlloc(allocator, diff, .{});
    defer allocator.free(diff_compressed);
    const extra_compressed = try bzip2.encodeAlloc(allocator, "", .{});
    defer allocator.free(extra_compressed);
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendSlice(allocator, "BSDIFF40");
    var sizes: [24]u8 = @splat(0);
    std.mem.writeInt(u64, sizes[0..8], control_compressed.len, .little);
    std.mem.writeInt(u64, sizes[8..16], diff_compressed.len, .little);
    std.mem.writeInt(u64, sizes[16..24], destination.len, .little);
    try output.appendSlice(allocator, &sizes);
    try output.appendSlice(allocator, control_compressed);
    try output.appendSlice(allocator, diff_compressed);
    try output.appendSlice(allocator, extra_compressed);
    return output.toOwnedSlice(allocator);
}
