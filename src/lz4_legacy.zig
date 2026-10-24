const std = @import("std");
const core = @import("core.zig");
const lz4 = @import("lz4.zig");
const incremental_decoder = @import("lz4_legacy/incremental_decoder.zig");
const incremental_encoder = @import("lz4_legacy/incremental_encoder.zig");
const incremental_encoder_tests = @import("lz4_legacy/incremental_encoder_tests.zig");
const incremental_tests = @import("lz4_legacy/incremental_tests.zig");

pub const Error = core.Error || lz4.Error || incremental_encoder.Encoder.Error || std.mem.Allocator.Error || error{
    InvalidLz4LegacyStream,
};

pub const magic = [_]u8{ 0x02, 0x21, 0x4c, 0x18 };
pub const max_block_size: usize = 8 * 1024 * 1024;
pub const max_compressed_block_size: usize = max_block_size + max_block_size / 255 + 16;
pub const IncrementalDecoder = incremental_decoder.Decoder;
pub const IncrementalEncoder = incremental_encoder.Encoder;

pub const Options = struct {
    block_size: usize = max_block_size,
};

pub const Block = struct {
    offset: usize,
    data_offset: usize,
    compressed_size: usize,
    decoded_size: usize,
    next_offset: usize,
};

pub const BlockIterator = struct {
    input: []const u8,
    position: usize = magic.len,

    pub fn next(self: *BlockIterator) Error!?Block {
        if (self.position == self.input.len) return null;
        const block = try parseBlock(self.input, self.position);
        self.position = block.next_offset;
        return block;
    }
};

pub const Archive = struct {
    bytes: []const u8,
    block_count: usize,
    decoded_size: usize,

    pub fn iterator(self: Archive) BlockIterator {
        return .{ .input = self.bytes };
    }
};

pub fn isLegacy(input: []const u8) bool {
    return input.len >= magic.len and std.mem.eql(u8, input[0..magic.len], &magic);
}

pub fn parse(input: []const u8) Error!Archive {
    return parseLimited(input, std.math.maxInt(usize));
}

pub fn parseLimited(input: []const u8, max_output_len: usize) Error!Archive {
    try validateMagic(input);
    var iterator = BlockIterator{ .input = input };
    var block_count: usize = 0;
    var decoded_size: usize = 0;
    while (try iterator.next()) |block| {
        block_count = std.math.add(usize, block_count, 1) catch
            return error.IntegerOverflow;
        decoded_size = std.math.add(usize, decoded_size, block.decoded_size) catch
            return error.IntegerOverflow;
        if (decoded_size > max_output_len) return error.OutputLimitExceeded;
    }
    return .{
        .bytes = input,
        .block_count = block_count,
        .decoded_size = decoded_size,
    };
}

pub fn parseBlock(input: []const u8, offset: usize) Error!Block {
    if (offset < magic.len) return error.InvalidLz4LegacyStream;
    const data_offset = try checkedEnd(offset, 4, input.len);
    const compressed_size: usize = std.mem.readInt(u32, input[offset..][0..4], .little);
    if (compressed_size == 0 or compressed_size > max_compressed_block_size)
        return error.InvalidLz4LegacyStream;
    const next_offset = try checkedEnd(data_offset, compressed_size, input.len);
    const decoded_size = try lz4.decodedBlockSizeLimited(
        input[data_offset..next_offset],
        max_block_size,
    );
    if (decoded_size == 0) return error.InvalidLz4LegacyStream;
    return .{
        .offset = offset,
        .data_offset = data_offset,
        .compressed_size = compressed_size,
        .decoded_size = decoded_size,
        .next_offset = next_offset,
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
    if (options.block_size == 0 or options.block_size > max_block_size)
        return error.InvalidLz4LegacyStream;
    const start = output.items.len;
    errdefer output.items.len = start;
    try output.appendSlice(allocator, &magic);
    if (input.len == 0) return magic.len;

    var encoder = try lz4.BlockEncoder.init(allocator);
    defer encoder.deinit();
    var input_offset: usize = 0;
    while (input_offset < input.len) {
        const block_len = @min(options.block_size, input.len - input_offset);
        const header_offset = output.items.len;
        try output.appendNTimes(allocator, 0, 4);
        const payload_offset = output.items.len;
        _ = try encoder.append(output, input[input_offset..][0..block_len]);
        const compressed_size = output.items.len - payload_offset;
        if (compressed_size == 0 or compressed_size > max_compressed_block_size)
            return error.InvalidLz4LegacyStream;
        std.mem.writeInt(
            u32,
            output.items[header_offset..][0..4],
            std.math.cast(u32, compressed_size) orelse return error.IntegerOverflow,
            .little,
        );
        input_offset += block_len;
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
    const archive = try parseLimited(input, max_output_len);
    const output = try allocator.alloc(u8, archive.decoded_size);
    errdefer allocator.free(output);
    _ = try decodeIntoParsed(archive, output);
    return output;
}

pub fn decodeInto(input: []const u8, output: []u8) !usize {
    return decodeIntoParsed(try parse(input), output);
}

fn decodeIntoParsed(archive: Archive, output: []u8) Error!usize {
    if (output.len < archive.decoded_size) return error.OutputTooSmall;
    var output_offset: usize = 0;
    var iterator = archive.iterator();
    while (try iterator.next()) |block| {
        const block_output = output[output_offset..][0..block.decoded_size];
        const written = try lz4.decodeBlockIntoSlice(
            archive.bytes[block.data_offset..block.next_offset],
            block_output,
            block.decoded_size,
        );
        if (written != block.decoded_size) return error.SizeMismatch;
        output_offset += written;
    }
    return output_offset;
}

fn validateMagic(input: []const u8) Error!void {
    if (input.len < magic.len) return error.TruncatedFrame;
    if (!isLegacy(input)) return error.InvalidMagic;
}

fn checkedEnd(start: usize, size: usize, limit: usize) Error!usize {
    const end = std.math.add(usize, start, size) catch return error.IntegerOverflow;
    if (end > limit) return error.TruncatedFrame;
    return end;
}

test "LZ4 legacy frame round trips empty tiny and multiple blocks" {
    const allocator = std.testing.allocator;
    const empty = try encodeAlloc(allocator, "", .{});
    defer allocator.free(empty);
    try std.testing.expectEqualSlices(u8, &magic, empty);
    const empty_archive = try parse(empty);
    try std.testing.expectEqual(@as(usize, 0), empty_archive.block_count);
    try std.testing.expectEqual(@as(usize, 0), empty_archive.decoded_size);

    const input = "LZ4 legacy independent block payload\n" ** 256;
    const encoded = try encodeAlloc(allocator, input, .{ .block_size = 257 });
    defer allocator.free(encoded);
    const archive = try parse(encoded);
    try std.testing.expect(archive.block_count > 2);
    try std.testing.expectEqual(input.len, archive.decoded_size);
    var iterator = archive.iterator();
    var iterated: usize = 0;
    while (try iterator.next()) |block| {
        try std.testing.expect(block.decoded_size <= 257);
        iterated += 1;
    }
    try std.testing.expectEqual(archive.block_count, iterated);
    const decoded = try decodeAlloc(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "LZ4 legacy frame enforces bounds and rejects malformed streams" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.TruncatedFrame, parse(""));
    try std.testing.expectError(error.InvalidMagic, parse("bad!"));
    try std.testing.expectError(error.InvalidLz4LegacyStream, encodeAlloc(allocator, "x", .{ .block_size = 0 }));

    const input = "bounded legacy LZ4" ** 32;
    const encoded = try encodeAlloc(allocator, input, .{});
    defer allocator.free(encoded);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        decodeAllocLimited(allocator, encoded, input.len - 1),
    );
    try std.testing.expectError(error.TruncatedFrame, parse(encoded[0 .. encoded.len - 1]));

    var zero_block = magic ++ [_]u8{ 0, 0, 0, 0 };
    try std.testing.expectError(error.InvalidLz4LegacyStream, parse(&zero_block));
    var huge_block = magic ++ [_]u8{ 0xff, 0xff, 0xff, 0xff };
    try std.testing.expectError(error.InvalidLz4LegacyStream, parse(&huge_block));
}

test {
    _ = incremental_decoder;
    _ = incremental_encoder;
    _ = incremental_encoder_tests;
    _ = incremental_tests;
}
