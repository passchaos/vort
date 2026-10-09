const std = @import("std");
const checksum = @import("../checksum.zig");
const core = @import("../core.zig");
const lzo1x = @import("../lzo1x.zig");
const header = @import("header.zig");

pub const Error = core.Error || header.Error || lzo1x.Error || error{InvalidLzopOptions};

pub const Checksum = enum {
    adler32,
    crc32,
};

pub const EncodeOptions = struct {
    block_size: usize = 256 * 1024,
    checksum: Checksum = .adler32,
    compressed_checksum: bool = false,
    header_checksum: Checksum = .adler32,
    filename: []const u8 = "",
    mode: u32 = 0,
    modified_time: u64 = 0,
    lzo_options: lzo1x.EncodeOptions = .{},
};

const max_compatible_block_size: usize = 256 * 1024;
const PayloadMode = enum { compressed_or_stored, stored };

pub fn encodeAlloc(allocator: std.mem.Allocator, input: []const u8, options: EncodeOptions) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, input, options);
    return output.toOwnedSlice(allocator);
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
    options: EncodeOptions,
) !usize {
    const encoded = try encodeAlloc(allocator, input, options);
    defer allocator.free(encoded);
    if (output.len < encoded.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

/// Append one compressed-or-stored LZOP stream transactionally.
pub fn encodeAppend(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    options: EncodeOptions,
) !usize {
    return encodeWithPayload(allocator, out, input, options, .compressed_or_stored);
}

pub fn encodeStoredAlloc(allocator: std.mem.Allocator, input: []const u8, options: EncodeOptions) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeStoredAppend(allocator, &output, input, options);
    return output.toOwnedSlice(allocator);
}

pub fn encodeStoredInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
    options: EncodeOptions,
) !usize {
    const encoded = try encodeStoredAlloc(allocator, input, options);
    defer allocator.free(encoded);
    if (output.len < encoded.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

/// Append one complete LZOP stream without changing `out.items` on error.
pub fn encodeStoredAppend(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    options: EncodeOptions,
) !usize {
    return encodeWithPayload(allocator, out, input, options, .stored);
}

fn encodeWithPayload(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    options: EncodeOptions,
    payload_mode: PayloadMode,
) !usize {
    if (options.block_size == 0 or options.block_size > max_compatible_block_size)
        return error.InvalidLzopOptions;
    if (options.filename.len > std.math.maxInt(u8)) return error.InvalidLzopOptions;

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    const data_flag: u32 = switch (options.checksum) {
        .adler32 => header.Flag.adler32_data,
        .crc32 => header.Flag.crc32_data,
    };
    const header_flag: u32 = switch (options.header_checksum) {
        .adler32 => 0,
        .crc32 => header.Flag.header_crc32,
    };
    const compressed_flag: u32 = if (options.compressed_checksum and payload_mode == .compressed_or_stored)
        switch (options.checksum) {
            .adler32 => header.Flag.adler32_compressed,
            .crc32 => header.Flag.crc32_compressed,
        }
    else
        0;
    try header.append(allocator, &encoded, .{
        .flags = data_flag | compressed_flag | header_flag,
        .filename = options.filename,
        .mode = options.mode,
        .modified_time = options.modified_time,
    });

    var compressed_block: std.ArrayList(u8) = .empty;
    defer compressed_block.deinit(allocator);
    var offset: usize = 0;
    while (offset < input.len) {
        const block_len = @min(options.block_size, input.len - offset);
        const block = input[offset..][0..block_len];
        compressed_block.clearRetainingCapacity();
        if (payload_mode == .compressed_or_stored)
            _ = try lzo1x.encodeAppend(allocator, &compressed_block, block, options.lzo_options);
        const compressed = payload_mode == .compressed_or_stored and
            compressed_block.items.len < block.len;
        const payload = if (compressed) compressed_block.items else block;
        try header.appendU32(allocator, &encoded, @intCast(block.len));
        try header.appendU32(allocator, &encoded, @intCast(payload.len));
        try header.appendU32(allocator, &encoded, checksumValue(options.checksum, block));
        if (compressed and options.compressed_checksum)
            try header.appendU32(allocator, &encoded, checksumValue(options.checksum, payload));
        try encoded.appendSlice(allocator, payload);
        offset += block.len;
    }
    try header.appendU32(allocator, &encoded, 0);

    try out.ensureUnusedCapacity(allocator, encoded.items.len);
    out.appendSliceAssumeCapacity(encoded.items);
    return encoded.items.len;
}

fn checksumValue(kind: Checksum, input: []const u8) u32 {
    return switch (kind) {
        .adler32 => checksum.adler32(input),
        .crc32 => checksum.crc32Best(input),
    };
}

test "LZOP stored writer supports CRC metadata and transactional output" {
    const container = @import("container.zig");
    const input = "LZOP writer payload" ** 32;
    const encoded = try encodeStoredAlloc(std.testing.allocator, input, .{
        .block_size = 64,
        .checksum = .crc32,
        .header_checksum = .crc32,
        .filename = "payload.bin",
        .mode = 0o100640,
    });
    defer std.testing.allocator.free(encoded);
    const decoded = try container.decodeAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    const prefix_len = appended.items.len;
    try std.testing.expectEqual(encoded.len, try encodeStoredAppend(
        std.testing.allocator,
        &appended,
        input,
        .{
            .block_size = 64,
            .checksum = .crc32,
            .header_checksum = .crc32,
            .filename = "payload.bin",
            .mode = 0o100640,
        },
    ));
    try std.testing.expectEqualSlices(u8, "prefix:", appended.items[0..prefix_len]);
    try std.testing.expectEqualSlices(u8, encoded, appended.items[prefix_len..]);

    const before = try std.testing.allocator.dupe(u8, appended.items);
    defer std.testing.allocator.free(before);
    try std.testing.expectError(
        error.InvalidLzopOptions,
        encodeStoredAppend(std.testing.allocator, &appended, input, .{ .block_size = 0 }),
    );
    try std.testing.expectEqualSlices(u8, before, appended.items);
}

test "LZOP writer selects compressed and stored blocks with compressed checksums" {
    const container = @import("container.zig");
    var input: [8192]u8 = undefined;
    @memset(input[0..4096], 'A');
    var prng = std.Random.DefaultPrng.init(0x4c5a_4f50_5f57_5249);
    prng.random().bytes(input[4096..]);

    const encoded = try encodeAlloc(std.testing.allocator, &input, .{
        .block_size = 4096,
        .checksum = .crc32,
        .compressed_checksum = true,
    });
    defer std.testing.allocator.free(encoded);
    const stream_header = try header.parse(encoded);
    try std.testing.expect(stream_header.flags & header.Flag.crc32_data != 0);
    try std.testing.expect(stream_header.flags & header.Flag.crc32_compressed != 0);
    const info = try container.inspect(encoded);
    try std.testing.expectEqual(@as(usize, 2), info.block_count);
    try std.testing.expectEqual(@as(usize, 1), info.compressed_block_count);
    try std.testing.expectEqual(@as(usize, 1), info.stored_block_count);
    const decoded = try container.decodeAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);

    const caller_output = try std.testing.allocator.alloc(u8, encoded.len);
    defer std.testing.allocator.free(caller_output);
    try std.testing.expectEqual(
        encoded.len,
        try encodeInto(std.testing.allocator, &input, caller_output, .{
            .block_size = 4096,
            .checksum = .crc32,
            .compressed_checksum = true,
        }),
    );
    try std.testing.expectEqualSlices(u8, encoded, caller_output);
}
