const std = @import("std");
const core = @import("core.zig");
const snappy = @import("snappy.zig");

pub const Error = core.Error || snappy.Error || std.mem.Allocator.Error || error{
    InvalidXerialSnappyStream,
    InvalidHadoopSnappyStream,
};

pub const xerial_magic = [_]u8{ 0x82, 'S', 'N', 'A', 'P', 'P', 'Y', 0 };
pub const xerial_header = xerial_magic ++ [_]u8{ 0, 0, 0, 1, 0, 0, 0, 1 };

pub const XerialOptions = struct {
    block_size: usize = 32 * 1024,
};

pub const HadoopOptions = struct {
    block_size: usize = 256 * 1024,
    chunk_size: usize = 64 * 1024,
};

pub const XerialChunk = struct {
    offset: usize,
    data_offset: usize,
    compressed_size: usize,
    uncompressed_size: usize,
    next_offset: usize,
};

pub const XerialArchive = struct {
    bytes: []const u8,
    chunk_count: usize,
    decoded_size: usize,

    pub fn iterator(self: XerialArchive) XerialIterator {
        return .{ .archive = self };
    }
};

pub const XerialIterator = struct {
    archive: XerialArchive,
    offset: usize = xerial_header.len,

    pub fn next(self: *XerialIterator) Error!?XerialChunk {
        if (self.offset == self.archive.bytes.len) return null;
        const chunk = try parseXerialChunk(self.archive.bytes, self.offset);
        self.offset = chunk.next_offset;
        return chunk;
    }
};

pub const HadoopChunk = struct {
    offset: usize,
    data_offset: usize,
    compressed_size: usize,
    uncompressed_size: usize,
    next_offset: usize,
};

pub const HadoopBlock = struct {
    offset: usize,
    uncompressed_size: usize,
    chunk_count: usize,
    next_offset: usize,
};

pub const HadoopArchive = struct {
    bytes: []const u8,
    block_count: usize,
    chunk_count: usize,
    decoded_size: usize,
};

pub fn parseXerial(input: []const u8) Error!XerialArchive {
    if (input.len < xerial_header.len or
        !std.mem.eql(u8, input[0..xerial_header.len], &xerial_header))
        return error.InvalidMagic;
    var offset: usize = xerial_header.len;
    var chunk_count: usize = 0;
    var decoded_size: usize = 0;
    while (offset < input.len) {
        const chunk = try parseXerialChunk(input, offset);
        chunk_count = std.math.add(usize, chunk_count, 1) catch
            return error.IntegerOverflow;
        decoded_size = std.math.add(usize, decoded_size, chunk.uncompressed_size) catch
            return error.IntegerOverflow;
        offset = chunk.next_offset;
    }
    return .{ .bytes = input, .chunk_count = chunk_count, .decoded_size = decoded_size };
}

pub fn parseXerialChunk(input: []const u8, offset: usize) Error!XerialChunk {
    const data_offset = try checkedEnd(offset, 4, input.len);
    const compressed_size: usize = std.mem.readInt(u32, input[offset..][0..4], .big);
    if (compressed_size == 0) return error.InvalidXerialSnappyStream;
    const next_offset = try checkedEnd(data_offset, compressed_size, input.len);
    const uncompressed_size = try snappy.decodedBlockSize(input[data_offset..next_offset]);
    return .{
        .offset = offset,
        .data_offset = data_offset,
        .compressed_size = compressed_size,
        .uncompressed_size = uncompressed_size,
        .next_offset = next_offset,
    };
}

pub fn encodeXerialAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: XerialOptions,
) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeXerialAppend(allocator, &output, input, options);
    return output.toOwnedSlice(allocator);
}

pub fn encodeXerialAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    options: XerialOptions,
) !usize {
    if (options.block_size == 0 or options.block_size > std.math.maxInt(u32))
        return error.InvalidXerialSnappyStream;
    const start = output.items.len;
    errdefer output.items.len = start;
    try output.appendSlice(allocator, &xerial_header);
    var encoder = snappy.Encoder.init(allocator);
    defer encoder.deinit();
    var position: usize = 0;
    while (position < input.len) {
        const length = @min(options.block_size, input.len - position);
        const compressed = try encoder.encodeBlockAlloc(input[position..][0..length]);
        defer allocator.free(compressed);
        try appendBe32(allocator, output, std.math.cast(u32, compressed.len) orelse
            return error.IntegerOverflow);
        try output.appendSlice(allocator, compressed);
        position += length;
    }
    return output.items.len - start;
}

pub fn decodeXerialAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
) ![]u8 {
    return decodeXerialAllocLimited(allocator, input, std.math.maxInt(usize));
}

pub fn decodeXerialAllocLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    max_output_len: usize,
) ![]u8 {
    const archive = try parseXerial(input);
    if (archive.decoded_size > max_output_len) return error.OutputLimitExceeded;
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.ensureTotalCapacity(allocator, archive.decoded_size);
    var iterator_value = archive.iterator();
    while (try iterator_value.next()) |chunk| {
        _ = try snappy.decodeBlockAppendExactSize(
            allocator,
            &output,
            input[chunk.data_offset..][0..chunk.compressed_size],
            chunk.uncompressed_size,
        );
    }
    return output.toOwnedSlice(allocator);
}

pub fn decodeXerialInto(input: []const u8, output: []u8) !usize {
    const archive = try parseXerial(input);
    if (output.len < archive.decoded_size) return error.OutputTooSmall;
    var output_offset: usize = 0;
    var iterator_value = archive.iterator();
    while (try iterator_value.next()) |chunk| {
        _ = try snappy.decodeBlockIntoExactSize(
            input[chunk.data_offset..][0..chunk.compressed_size],
            output[output_offset..][0..chunk.uncompressed_size],
            chunk.uncompressed_size,
        );
        output_offset += chunk.uncompressed_size;
    }
    return output_offset;
}

pub fn encodeXerialInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: XerialOptions,
    output: []u8,
) !usize {
    const encoded = try encodeXerialAlloc(allocator, input, options);
    defer allocator.free(encoded);
    if (output.len < encoded.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

pub fn parseHadoop(input: []const u8) Error!HadoopArchive {
    var offset: usize = 0;
    var block_count: usize = 0;
    var chunk_count: usize = 0;
    var decoded_size: usize = 0;
    while (offset < input.len) {
        const block = try parseHadoopBlock(input, offset);
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

pub fn parseHadoopBlock(input: []const u8, offset: usize) Error!HadoopBlock {
    var position = try checkedEnd(offset, 4, input.len);
    const expected_size: usize = std.mem.readInt(u32, input[offset..][0..4], .big);
    if (expected_size == 0) return error.InvalidHadoopSnappyStream;
    var decoded_size: usize = 0;
    var chunk_count: usize = 0;
    while (decoded_size < expected_size) {
        const data_offset = try checkedEnd(position, 4, input.len);
        const compressed_size: usize = std.mem.readInt(u32, input[position..][0..4], .big);
        if (compressed_size == 0) return error.InvalidHadoopSnappyStream;
        const next_offset = try checkedEnd(data_offset, compressed_size, input.len);
        const chunk_size = try snappy.decodedBlockSize(input[data_offset..next_offset]);
        const next_decoded = std.math.add(usize, decoded_size, chunk_size) catch
            return error.IntegerOverflow;
        if (next_decoded > expected_size)
            return error.InvalidHadoopSnappyStream;
        decoded_size = next_decoded;
        chunk_count = std.math.add(usize, chunk_count, 1) catch
            return error.IntegerOverflow;
        position = next_offset;
    }
    if (decoded_size != expected_size) return error.InvalidHadoopSnappyStream;
    return .{
        .offset = offset,
        .uncompressed_size = expected_size,
        .chunk_count = chunk_count,
        .next_offset = position,
    };
}

pub fn encodeHadoopAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: HadoopOptions,
) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeHadoopAppend(allocator, &output, input, options);
    return output.toOwnedSlice(allocator);
}

pub fn encodeHadoopAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    options: HadoopOptions,
) !usize {
    if (options.block_size == 0 or options.chunk_size == 0 or
        options.block_size > std.math.maxInt(u32) or
        options.chunk_size > std.math.maxInt(u32))
        return error.InvalidHadoopSnappyStream;
    const start = output.items.len;
    errdefer output.items.len = start;
    var encoder = snappy.Encoder.init(allocator);
    defer encoder.deinit();
    var block_start: usize = 0;
    while (block_start < input.len) {
        const block_len = @min(options.block_size, input.len - block_start);
        try appendBe32(allocator, output, @intCast(block_len));
        var chunk_start: usize = 0;
        while (chunk_start < block_len) {
            const chunk_len = @min(options.chunk_size, block_len - chunk_start);
            const plain = input[block_start + chunk_start ..][0..chunk_len];
            const compressed = try encoder.encodeBlockAlloc(plain);
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

pub fn decodeHadoopAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
) ![]u8 {
    return decodeHadoopAllocLimited(allocator, input, std.math.maxInt(usize));
}

pub fn decodeHadoopAllocLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    max_output_len: usize,
) ![]u8 {
    const archive = try parseHadoop(input);
    if (archive.decoded_size > max_output_len) return error.OutputLimitExceeded;
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.ensureTotalCapacity(allocator, archive.decoded_size);
    var position: usize = 0;
    while (position < input.len) {
        const expected_size: usize = std.mem.readInt(u32, input[position..][0..4], .big);
        position += 4;
        const block_end = std.math.add(usize, output.items.len, expected_size) catch
            return error.IntegerOverflow;
        while (output.items.len < block_end) {
            const compressed_size: usize = std.mem.readInt(u32, input[position..][0..4], .big);
            position += 4;
            _ = try snappy.decodeBlockAppendLimited(
                allocator,
                &output,
                input[position..][0..compressed_size],
                block_end - output.items.len,
            );
            position += compressed_size;
        }
        if (output.items.len != block_end) return error.InvalidHadoopSnappyStream;
    }
    return output.toOwnedSlice(allocator);
}

pub fn decodeHadoopInto(input: []const u8, output: []u8) !usize {
    const archive = try parseHadoop(input);
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
            const chunk_size = try snappy.decodedBlockSize(input[position..][0..compressed_size]);
            if (chunk_size > block_end - output_offset) return error.InvalidHadoopSnappyStream;
            _ = try snappy.decodeBlockIntoExactSize(
                input[position..][0..compressed_size],
                output[output_offset..][0..chunk_size],
                chunk_size,
            );
            position += compressed_size;
            output_offset += chunk_size;
        }
    }
    return output_offset;
}

pub fn encodeHadoopInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: HadoopOptions,
    output: []u8,
) !usize {
    const encoded = try encodeHadoopAlloc(allocator, input, options);
    defer allocator.free(encoded);
    if (output.len < encoded.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
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

test "Xerial Snappy writer round trips multiple independent blocks" {
    const allocator = std.testing.allocator;
    const input = "Xerial Snappy payload alpha beta gamma\n" ** 4096;
    const encoded = try encodeXerialAlloc(allocator, input, .{ .block_size = 4096 });
    defer allocator.free(encoded);
    const archive = try parseXerial(encoded);
    try std.testing.expect(archive.chunk_count > 1);
    const decoded = try decodeXerialAlloc(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "Hadoop Snappy writer round trips nested blocks and chunks" {
    const allocator = std.testing.allocator;
    const input = "Hadoop Snappy payload alpha beta gamma\n" ** 8192;
    const encoded = try encodeHadoopAlloc(allocator, input, .{
        .block_size = 32 * 1024,
        .chunk_size = 4096,
    });
    defer allocator.free(encoded);
    const archive = try parseHadoop(encoded);
    try std.testing.expect(archive.block_count > 1);
    try std.testing.expect(archive.chunk_count > archive.block_count);
    const decoded = try decodeHadoopAlloc(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "Snappy framing rejects bad magic truncation and output limits" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.InvalidMagic, parseXerial(""));
    const xerial = try encodeXerialAlloc(allocator, "payload", .{});
    defer allocator.free(xerial);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        decodeXerialAllocLimited(allocator, xerial, 6),
    );
    try std.testing.expectError(error.TruncatedFrame, parseXerial(xerial[0 .. xerial.len - 1]));
    const hadoop = try encodeHadoopAlloc(allocator, "payload", .{});
    defer allocator.free(hadoop);
    try std.testing.expectError(error.TruncatedFrame, parseHadoop(hadoop[0 .. hadoop.len - 1]));
}
