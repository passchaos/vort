const std = @import("std");
const block = @import("block.zig");

pub const Error = block.Error || error{
    InvalidLzfStream,
    UnsupportedLzfFeature,
    InvalidLzfOptions,
};

pub const max_block_size: usize = std.math.maxInt(u16);

pub const EncodeOptions = struct {
    block_size: usize = max_block_size,
    eof_marker: bool = false,
};

pub const FileInfo = struct {
    block_count: usize = 0,
    stored_block_count: usize = 0,
    compressed_block_count: usize = 0,
    encoded_size: usize = 0,
    uncompressed_size: usize = 0,
    max_uncompressed_block_size: usize = 0,
    eof_marker: bool = false,
};

const BlockKind = enum { stored, compressed };

const Block = struct {
    kind: BlockKind,
    payload: []const u8,
    uncompressed_size: usize,
    next_offset: usize,
};

pub fn encodedBound(input_len: usize, options: EncodeOptions) Error!usize {
    try validateOptions(options);
    const blocks = input_len / options.block_size + @intFromBool(input_len % options.block_size != 0);
    const headers = std.math.mul(usize, blocks, 5) catch return error.IntegerOverflow;
    const without_marker = std.math.add(usize, input_len, headers) catch
        return error.IntegerOverflow;
    return std.math.add(usize, without_marker, @intFromBool(options.eof_marker)) catch
        return error.IntegerOverflow;
}

pub fn inspect(input: []const u8) Error!FileInfo {
    var info = FileInfo{ .encoded_size = input.len };
    var offset: usize = 0;
    while (offset < input.len) {
        if (input[offset] == 0) {
            if (offset + 1 != input.len) return error.TrailingData;
            info.eof_marker = true;
            offset += 1;
            break;
        }
        const current = try parseBlock(input, offset);
        info.block_count += 1;
        switch (current.kind) {
            .stored => info.stored_block_count += 1,
            .compressed => info.compressed_block_count += 1,
        }
        info.uncompressed_size = std.math.add(
            usize,
            info.uncompressed_size,
            current.uncompressed_size,
        ) catch return error.IntegerOverflow;
        info.max_uncompressed_block_size = @max(
            info.max_uncompressed_block_size,
            current.uncompressed_size,
        );
        offset = current.next_offset;
    }
    return info;
}

pub fn decodedSize(input: []const u8) Error!usize {
    return decodedSizeLimited(input, std.math.maxInt(usize));
}

pub fn decodedSizeLimited(input: []const u8, max_output_len: usize) Error!usize {
    var offset: usize = 0;
    var total: usize = 0;
    while (offset < input.len) {
        if (input[offset] == 0) {
            if (offset + 1 != input.len) return error.TrailingData;
            break;
        }
        const current = try parseBlock(input, offset);
        total = std.math.add(usize, total, current.uncompressed_size) catch
            return error.IntegerOverflow;
        if (total > max_output_len) return error.OutputLimitExceeded;
        offset = current.next_offset;
    }
    return total;
}

pub fn decodeInto(input: []const u8, output: []u8) Error!usize {
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (input_offset < input.len) {
        if (input[input_offset] == 0) {
            if (input_offset + 1 != input.len) return error.TrailingData;
            break;
        }
        const current = try parseBlock(input, input_offset);
        if (current.uncompressed_size > output.len - output_offset)
            return error.OutputTooSmall;
        const target = output[output_offset .. output_offset + current.uncompressed_size];
        switch (current.kind) {
            .stored => @memcpy(target, current.payload),
            .compressed => {
                const written = try block.decodeInto(current.payload, target);
                if (written != target.len) return error.SizeMismatch;
            },
        }
        output_offset += current.uncompressed_size;
        input_offset = current.next_offset;
    }
    return output_offset;
}

pub fn decodeAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    return decodeAllocLimited(allocator, input, std.math.maxInt(usize));
}

pub fn decodeAllocLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    max_output_len: usize,
) Error![]u8 {
    const output_len = try decodedSizeLimited(input, max_output_len);
    const output = try allocator.alloc(u8, output_len);
    errdefer allocator.free(output);
    const written = try decodeInto(input, output);
    if (written != output.len) return error.SizeMismatch;
    return output;
}

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, input, options);
    return output.toOwnedSlice(allocator);
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    options: EncodeOptions,
) Error!usize {
    try validateOptions(options);
    const start = output.items.len;
    errdefer output.items.len = start;

    var offset: usize = 0;
    while (offset < input.len) {
        const count = @min(options.block_size, input.len - offset);
        const source = input[offset .. offset + count];
        const compressed = try block.encodeAlloc(allocator, source);
        defer allocator.free(compressed);
        if (compressed.len < source.len and source.len - compressed.len > 2) {
            try output.appendSlice(allocator, "ZV\x01");
            try appendBe16(allocator, output, @intCast(compressed.len));
            try appendBe16(allocator, output, @intCast(source.len));
            try output.appendSlice(allocator, compressed);
        } else {
            try output.appendSlice(allocator, "ZV\x00");
            try appendBe16(allocator, output, @intCast(source.len));
            try output.appendSlice(allocator, source);
        }
        offset += count;
    }
    if (options.eof_marker) try output.append(allocator, 0);
    return output.items.len - start;
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
    options: EncodeOptions,
) Error!usize {
    const encoded = try encodeAlloc(allocator, input, options);
    defer allocator.free(encoded);
    if (encoded.len > output.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

fn parseBlock(input: []const u8, offset: usize) Error!Block {
    if (offset > input.len or input.len - offset < 3) return error.TruncatedFrame;
    if (!std.mem.eql(u8, input[offset .. offset + 2], "ZV")) return error.InvalidMagic;
    return switch (input[offset + 2]) {
        0 => blk: {
            if (input.len - offset < 5) return error.TruncatedFrame;
            const uncompressed_size = readBe16(input, offset + 3);
            const payload_start = offset + 5;
            const payload_end = std.math.add(usize, payload_start, uncompressed_size) catch
                return error.IntegerOverflow;
            if (payload_end > input.len) return error.TruncatedFrame;
            break :blk .{
                .kind = .stored,
                .payload = input[payload_start..payload_end],
                .uncompressed_size = uncompressed_size,
                .next_offset = payload_end,
            };
        },
        1 => blk: {
            if (input.len - offset < 7) return error.TruncatedFrame;
            const compressed_size = readBe16(input, offset + 3);
            const uncompressed_size = readBe16(input, offset + 5);
            if (compressed_size == 0 or uncompressed_size == 0)
                return error.InvalidLzfStream;
            const payload_start = offset + 7;
            const payload_end = std.math.add(usize, payload_start, compressed_size) catch
                return error.IntegerOverflow;
            if (payload_end > input.len) return error.TruncatedFrame;
            const payload = input[payload_start..payload_end];
            if (try block.decodedSize(payload) != uncompressed_size)
                return error.SizeMismatch;
            break :blk .{
                .kind = .compressed,
                .payload = payload,
                .uncompressed_size = uncompressed_size,
                .next_offset = payload_end,
            };
        },
        else => error.UnsupportedLzfFeature,
    };
}

fn validateOptions(options: EncodeOptions) Error!void {
    if (options.block_size == 0 or options.block_size > max_block_size)
        return error.InvalidLzfOptions;
}

fn readBe16(input: []const u8, offset: usize) usize {
    return std.mem.readInt(u16, input[offset..][0..2], .big);
}

fn appendBe16(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: u16,
) Error!void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, value, .big);
    try output.appendSlice(allocator, &bytes);
}

test "LZF ZV stream round trips mixed stored and compressed blocks" {
    const allocator = std.testing.allocator;
    var input: [96 * 1024]u8 = undefined;
    var state: u32 = 0x6c7a_6601;
    for (input[0 .. 32 * 1024]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memset(input[32 * 1024 .. 64 * 1024], 'A');
    @memcpy(input[64 * 1024 ..], input[0 .. 32 * 1024]);

    const encoded = try encodeAlloc(allocator, &input, .{ .block_size = 32 * 1024 });
    defer allocator.free(encoded);
    try std.testing.expect(encoded.len <= try encodedBound(input.len, .{ .block_size = 32 * 1024 }));
    const info = try inspect(encoded);
    try std.testing.expectEqual(@as(usize, 3), info.block_count);
    try std.testing.expect(info.stored_block_count != 0);
    try std.testing.expect(info.compressed_block_count != 0);
    try std.testing.expectEqual(input.len, info.uncompressed_size);
    try std.testing.expectEqual(input.len, try decodedSize(encoded));
    const decoded = try decodeAlloc(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
}

test "LZF ZV stream handles empty input EOF marker and caller buffers" {
    const allocator = std.testing.allocator;
    const empty = try encodeAlloc(allocator, "", .{});
    defer allocator.free(empty);
    try std.testing.expectEqual(@as(usize, 0), empty.len);
    try std.testing.expectEqual(@as(usize, 0), try decodedSize(empty));

    const marked = try encodeAlloc(allocator, "", .{ .eof_marker = true });
    defer allocator.free(marked);
    try std.testing.expectEqualSlices(u8, &.{0}, marked);
    try std.testing.expect((try inspect(marked)).eof_marker);

    const empty_stored = "ZV\x00\x00\x00";
    const empty_info = try inspect(empty_stored);
    try std.testing.expectEqual(@as(usize, 1), empty_info.stored_block_count);
    try std.testing.expectEqual(@as(usize, 0), try decodedSize(empty_stored));

    const input = "caller-owned LZF stream" ** 64;
    const encoded = try encodeAlloc(allocator, input, .{ .eof_marker = true });
    defer allocator.free(encoded);
    const caller_encoded = try allocator.alloc(u8, encoded.len);
    defer allocator.free(caller_encoded);
    try std.testing.expectEqual(
        encoded.len,
        try encodeInto(allocator, input, caller_encoded, .{ .eof_marker = true }),
    );
    try std.testing.expectEqualSlices(u8, encoded, caller_encoded);
    try std.testing.expectError(
        error.OutputTooSmall,
        encodeInto(allocator, input, caller_encoded[0 .. caller_encoded.len - 1], .{ .eof_marker = true }),
    );
    var output: [input.len]u8 = undefined;
    try std.testing.expectEqual(input.len, try decodeInto(encoded, &output));
    try std.testing.expectEqualSlices(u8, input, &output);
    try std.testing.expectError(
        error.OutputTooSmall,
        decodeInto(encoded, output[0 .. output.len - 1]),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        decodeAllocLimited(allocator, encoded, input.len - 1),
    );
}

test "LZF ZV stream rejects malformed headers sizes and trailing data" {
    try std.testing.expectError(error.TruncatedFrame, inspect("Z"));
    try std.testing.expectError(error.InvalidMagic, inspect("NOPE!"));
    try std.testing.expectError(error.UnsupportedLzfFeature, inspect("ZV\x02xx"));
    try std.testing.expectError(error.InvalidLzfStream, inspect("ZV\x01\x00\x00\x00\x00"));
    try std.testing.expectError(error.TruncatedFrame, inspect("ZV\x00\x00\x02x"));
    try std.testing.expectError(error.SizeMismatch, inspect("ZV\x01\x00\x02\x00\x04\x00x"));
    try std.testing.expectError(error.TrailingData, inspect(&.{ 0, 1 }));

    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(std.testing.allocator);
    try output.appendSlice(std.testing.allocator, "prefix");
    const before = try std.testing.allocator.dupe(u8, output.items);
    defer std.testing.allocator.free(before);
    try std.testing.expectError(
        error.InvalidLzfOptions,
        encodeAppend(std.testing.allocator, &output, "payload", .{ .block_size = 0 }),
    );
    try std.testing.expectEqualSlices(u8, before, output.items);
}
