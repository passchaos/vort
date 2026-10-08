const std = @import("std");
const container = @import("container.zig");

pub const Error = container.Error;
pub const Check = container.Check;

pub const EncodeOptions = struct {
    check: Check = .crc64,
    block_size: usize = 1024 * 1024,
};

const stream_magic = [_]u8{ 0xfd, '7', 'z', 'X', 'Z', 0x00 };
const stream_footer_magic = [_]u8{ 'Y', 'Z' };
const max_lzma2_uncompressed_chunk: usize = 65_536;
const max_vli: u64 = (@as(u64, 1) << 63) - 1;

const BlockRecord = struct {
    unpadded_size: u64,
    uncompressed_size: u64,
};

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

/// Append a deterministic XZ stream without changing `out.items` on error.
pub fn encodeStoredAppend(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    options: EncodeOptions,
) !usize {
    if (options.block_size == 0) return error.InvalidBlockPlan;
    const check_size = try checkSize(options.check);

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try encoded.appendSlice(allocator, &stream_magic);
    const stream_flags = [_]u8{ 0, @intFromEnum(options.check) };
    try encoded.appendSlice(allocator, &stream_flags);
    try appendU32(allocator, &encoded, std.hash.Crc32.hash(&stream_flags));

    var records: std.ArrayList(BlockRecord) = .empty;
    defer records.deinit(allocator);
    var input_offset: usize = 0;
    while (input_offset < input.len) {
        const block_len = @min(options.block_size, input.len - input_offset);
        const block = input[input_offset..][0..block_len];
        const block_start = encoded.items.len;
        try appendBlockHeader(allocator, &encoded);
        const packed_size = try appendStoredLzma2(allocator, &encoded, block);
        const padding_len = (4 - ((8 + packed_size) % 4)) % 4;
        try encoded.appendNTimes(allocator, 0, padding_len);
        try appendCheck(allocator, &encoded, options.check, block);
        const unpadded_size = std.math.add(u64, 12 + @as(u64, @intCast(packed_size)), check_size) catch
            return error.IntegerOverflow;
        try records.append(allocator, .{
            .unpadded_size = unpadded_size,
            .uncompressed_size = try usizeToVli(block.len),
        });
        std.debug.assert(encoded.items.len > block_start);
        input_offset += block_len;
    }

    const index_start = encoded.items.len;
    try encoded.append(allocator, 0);
    try appendVli(allocator, &encoded, try usizeToVli(records.items.len));
    for (records.items) |record| {
        try appendVli(allocator, &encoded, record.unpadded_size);
        try appendVli(allocator, &encoded, record.uncompressed_size);
    }
    while ((encoded.items.len - index_start) % 4 != 0) try encoded.append(allocator, 0);
    try appendU32(allocator, &encoded, std.hash.Crc32.hash(encoded.items[index_start..]));
    const index_size = encoded.items.len - index_start;
    if (index_size % 4 != 0 or index_size / 4 == 0 or index_size / 4 - 1 > std.math.maxInt(u32))
        return error.IntegerOverflow;

    var footer_fields: [6]u8 = undefined;
    std.mem.writeInt(u32, footer_fields[0..4], @intCast(index_size / 4 - 1), .little);
    @memcpy(footer_fields[4..6], &stream_flags);
    try appendU32(allocator, &encoded, std.hash.Crc32.hash(&footer_fields));
    try encoded.appendSlice(allocator, &footer_fields);
    try encoded.appendSlice(allocator, &stream_footer_magic);

    try out.ensureUnusedCapacity(allocator, encoded.items.len);
    out.appendSliceAssumeCapacity(encoded.items);
    return encoded.items.len;
}

fn appendBlockHeader(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    var header = [_]u8{ 2, 0, 0x21, 1, 0, 0, 0, 0 };
    try output.appendSlice(allocator, &header);
    try appendU32(allocator, output, std.hash.Crc32.hash(&header));
}

fn appendStoredLzma2(allocator: std.mem.Allocator, output: *std.ArrayList(u8), input: []const u8) !usize {
    const start = output.items.len;
    var offset: usize = 0;
    while (offset < input.len) {
        const chunk_len = @min(max_lzma2_uncompressed_chunk, input.len - offset);
        try output.append(allocator, if (offset == 0) 1 else 2);
        try appendU16Big(allocator, output, @intCast(chunk_len - 1));
        try output.appendSlice(allocator, input[offset..][0..chunk_len]);
        offset += chunk_len;
    }
    try output.append(allocator, 0);
    return output.items.len - start;
}

fn appendCheck(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    check: Check,
    input: []const u8,
) !void {
    switch (check) {
        .none => {},
        .crc32 => try appendU32(allocator, output, std.hash.Crc32.hash(input)),
        .crc64 => try appendU64(allocator, output, std.hash.crc.Crc64Xz.hash(input)),
        .sha256 => {
            var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(input, &digest, .{});
            try output.appendSlice(allocator, &digest);
        },
        else => return error.UnsupportedXzFeature,
    }
}

fn checkSize(check: Check) Error!u64 {
    return switch (check) {
        .none => 0,
        .crc32 => 4,
        .crc64 => 8,
        .sha256 => std.crypto.hash.sha2.Sha256.digest_length,
        else => error.UnsupportedXzFeature,
    };
}

fn appendVli(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value_arg: u64) !void {
    if (value_arg > max_vli) return error.IntegerOverflow;
    var value = value_arg;
    while (value >= 0x80) {
        try output.append(allocator, @as(u8, @truncate(value)) | 0x80);
        value >>= 7;
    }
    try output.append(allocator, @truncate(value));
}

fn usizeToVli(value: usize) Error!u64 {
    const converted = std.math.cast(u64, value) orelse return error.IntegerOverflow;
    if (converted > max_vli) return error.IntegerOverflow;
    return converted;
}

fn appendU16Big(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: u16) !void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, value, .big);
    try output.appendSlice(allocator, &bytes);
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

test "XZ stored writer round trips checks and multiple blocks" {
    const allocator = std.testing.allocator;
    const input = "XZ uncompressed LZMA2 chunks " ** 300;
    inline for (.{ Check.none, Check.crc32, Check.crc64, Check.sha256 }) |check| {
        const encoded = try encodeStoredAlloc(allocator, input, .{ .check = check, .block_size = 1024 });
        defer allocator.free(encoded);
        const decoded = try container.decodeAlloc(allocator, encoded);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
        const info = try container.inspect(allocator, encoded);
        try std.testing.expectEqual(check, info.check);
        try std.testing.expectEqual(@as(usize, (input.len + 1023) / 1024), info.block_count);
    }
}

test "XZ stored writer caller-owned and append APIs are transactional" {
    const allocator = std.testing.allocator;
    const input = "transactional XZ output";
    const encoded = try encodeStoredAlloc(allocator, input, .{});
    defer allocator.free(encoded);

    const output = try allocator.alloc(u8, encoded.len);
    defer allocator.free(output);
    try std.testing.expectEqual(encoded.len, try encodeStoredInto(allocator, input, output, .{}));
    try std.testing.expectEqualSlices(u8, encoded, output);
    try std.testing.expectError(error.OutputTooSmall, encodeStoredInto(allocator, input, output[0 .. output.len - 1], .{}));

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    const prefix_len = appended.items.len;
    try std.testing.expectEqual(encoded.len, try encodeStoredAppend(allocator, &appended, input, .{}));
    try std.testing.expectEqualSlices(u8, "prefix:", appended.items[0..prefix_len]);
    try std.testing.expectEqualSlices(u8, encoded, appended.items[prefix_len..]);

    const before = try allocator.dupe(u8, appended.items);
    defer allocator.free(before);
    try std.testing.expectError(
        error.InvalidBlockPlan,
        encodeStoredAppend(allocator, &appended, input, .{ .block_size = 0 }),
    );
    try std.testing.expectEqualSlices(u8, before, appended.items);
}
