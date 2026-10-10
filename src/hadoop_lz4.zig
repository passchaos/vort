const std = @import("std");
const core = @import("core.zig");
const lz4 = @import("lz4.zig");

pub const Error = core.Error || lz4.Error || std.mem.Allocator.Error || error{
    InvalidHadoopLz4Stream,
};

pub const Options = struct {
    block_size: usize = 256 * 1024,
    chunk_size: usize = 64 * 1024,
};

pub const Block = struct {
    offset: usize,
    uncompressed_size: usize,
    chunk_count: usize,
    next_offset: usize,
};

pub const Archive = struct {
    bytes: []const u8,
    block_count: usize,
    chunk_count: usize,
    decoded_size: usize,
};

pub fn parse(input: []const u8) Error!Archive {
    var offset: usize = 0;
    var block_count: usize = 0;
    var chunk_count: usize = 0;
    var decoded_size: usize = 0;
    while (offset < input.len) {
        const block = try parseBlock(input, offset);
        block_count = std.math.add(usize, block_count, 1) catch
            return error.IntegerOverflow;
        chunk_count = std.math.add(usize, chunk_count, block.chunk_count) catch
            return error.IntegerOverflow;
        decoded_size = std.math.add(usize, decoded_size, block.uncompressed_size) catch
            return error.IntegerOverflow;
        offset = block.next_offset;
    }
    return .{
        .bytes = input,
        .block_count = block_count,
        .chunk_count = chunk_count,
        .decoded_size = decoded_size,
    };
}

pub fn parseBlock(input: []const u8, offset: usize) Error!Block {
    var position = try checkedEnd(offset, 4, input.len);
    const expected_size: usize = std.mem.readInt(u32, input[offset..][0..4], .big);
    if (expected_size == 0) return error.InvalidHadoopLz4Stream;
    var decoded_size: usize = 0;
    var chunk_count: usize = 0;
    while (decoded_size < expected_size) {
        const data_offset = try checkedEnd(position, 4, input.len);
        const compressed_size: usize = std.mem.readInt(u32, input[position..][0..4], .big);
        if (compressed_size == 0) return error.InvalidHadoopLz4Stream;
        const next_offset = try checkedEnd(data_offset, compressed_size, input.len);
        const chunk_size = try lz4.decodedBlockSize(input[data_offset..next_offset]);
        const next_decoded = std.math.add(usize, decoded_size, chunk_size) catch
            return error.IntegerOverflow;
        if (next_decoded > expected_size) return error.InvalidHadoopLz4Stream;
        decoded_size = next_decoded;
        chunk_count = std.math.add(usize, chunk_count, 1) catch
            return error.IntegerOverflow;
        position = next_offset;
    }
    return .{
        .offset = offset,
        .uncompressed_size = expected_size,
        .chunk_count = chunk_count,
        .next_offset = position,
    };
}

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: Options,
) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, input, options);
    return output.toOwnedSlice(allocator);
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    options: Options,
) !usize {
    if (options.block_size == 0 or options.chunk_size == 0 or
        options.block_size > std.math.maxInt(u32) or
        options.chunk_size > std.math.maxInt(u32))
        return error.InvalidHadoopLz4Stream;
    const start = output.items.len;
    errdefer output.items.len = start;
    var block_start: usize = 0;
    while (block_start < input.len) {
        const block_len = @min(options.block_size, input.len - block_start);
        try appendBe32(allocator, output, @intCast(block_len));
        var chunk_start: usize = 0;
        while (chunk_start < block_len) {
            const chunk_len = @min(options.chunk_size, block_len - chunk_start);
            const plain = input[block_start + chunk_start ..][0..chunk_len];
            const compressed = try lz4.encodeBlockAlloc(allocator, plain);
            defer allocator.free(compressed);
            try appendBe32(allocator, output, std.math.cast(u32, compressed.len) orelse
                return error.IntegerOverflow);
            try output.appendSlice(allocator, compressed);
            chunk_start += chunk_len;
        }
        block_start += block_len;
    }
    return output.items.len - start;
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: Options,
    output: []u8,
) !usize {
    const encoded = try encodeAlloc(allocator, input, options);
    defer allocator.free(encoded);
    if (output.len < encoded.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

pub fn decodeAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return decodeAllocLimited(allocator, input, std.math.maxInt(usize));
}

pub fn decodeAllocLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    max_output_len: usize,
) ![]u8 {
    const archive = try parse(input);
    if (archive.decoded_size > max_output_len) return error.OutputLimitExceeded;
    const output = try allocator.alloc(u8, archive.decoded_size);
    errdefer allocator.free(output);
    _ = try decodeInto(input, output);
    return output;
}

pub fn decodeInto(input: []const u8, output: []u8) !usize {
    const archive = try parse(input);
    if (output.len < archive.decoded_size) return error.OutputTooSmall;
    var position: usize = 0;
    var output_offset: usize = 0;
    while (position < input.len) {
        const expected_size: usize = std.mem.readInt(u32, input[position..][0..4], .big);
        position += 4;
        const block_end = std.math.add(usize, output_offset, expected_size) catch
            return error.IntegerOverflow;
        while (output_offset < block_end) {
            const compressed_size: usize = std.mem.readInt(u32, input[position..][0..4], .big);
            position += 4;
            const chunk_size = try lz4.decodedBlockSize(input[position..][0..compressed_size]);
            if (chunk_size > block_end - output_offset) return error.InvalidHadoopLz4Stream;
            const written = try lz4.decodeBlockIntoSlice(
                input[position..][0..compressed_size],
                output[output_offset..][0..chunk_size],
                chunk_size,
            );
            if (written != chunk_size) return error.SizeMismatch;
            position += compressed_size;
            output_offset += chunk_size;
        }
    }
    return output_offset;
}

fn appendBe32(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: u32,
) Error!void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .big);
    try output.appendSlice(allocator, &bytes);
}

fn checkedEnd(start: usize, size: usize, limit: usize) Error!usize {
    const end = std.math.add(usize, start, size) catch return error.IntegerOverflow;
    if (end > limit) return error.TruncatedFrame;
    return end;
}

test "Hadoop LZ4 writer round trips nested blocks and chunks" {
    const allocator = std.testing.allocator;
    const input = "Hadoop LZ4 payload alpha beta gamma\n" ** 8192;
    const encoded = try encodeAlloc(allocator, input, .{
        .block_size = 32 * 1024,
        .chunk_size = 4096,
    });
    defer allocator.free(encoded);
    const archive = try parse(encoded);
    try std.testing.expect(archive.block_count > 1);
    try std.testing.expect(archive.chunk_count > archive.block_count);
    const decoded = try decodeAlloc(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "Hadoop LZ4 supports empty streams bounds and malformed sizes" {
    const allocator = std.testing.allocator;
    const empty = try encodeAlloc(allocator, "", .{});
    defer allocator.free(empty);
    try std.testing.expectEqual(@as(usize, 0), empty.len);
    const input = "bounded hadoop lz4";
    const encoded = try encodeAlloc(allocator, input, .{});
    defer allocator.free(encoded);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        decodeAllocLimited(allocator, encoded, input.len - 1),
    );
    try std.testing.expectError(error.TruncatedFrame, parse(encoded[0 .. encoded.len - 1]));
}
