const std = @import("std");
const checksum = @import("checksum.zig");
const core = @import("core.zig");
const lzo1x = @import("lzo1x.zig");
const lzop = @import("lzop.zig");

pub const Error = core.Error || lzo1x.Error || lzop.Error || std.mem.Allocator.Error || error{
    InvalidHadoopLzoIndex,
    HadoopLzoBlockOutOfRange,
};

pub const Index = struct {
    bytes: []const u8,
    block_count: usize,

    pub fn offsetAt(self: Index, block: usize) Error!u64 {
        if (block >= self.block_count) return error.HadoopLzoBlockOutOfRange;
        return std.mem.readInt(u64, self.bytes[block * 8 ..][0..8], .big);
    }

    pub fn firstAtOrAfter(self: Index, position: u64) Error!?usize {
        var low: usize = 0;
        var high = self.block_count;
        while (low < high) {
            const middle = low + (high - low) / 2;
            if (try self.offsetAt(middle) < position)
                low = middle + 1
            else
                high = middle;
        }
        return if (low == self.block_count) null else low;
    }
};

pub const Block = struct {
    offset: usize,
    data_offset: usize,
    next_offset: usize,
    uncompressed_size: usize,
    compressed_size: usize,
    compressed: bool,
    data_adler32: ?u32,
    data_crc32: ?u32,
    compressed_adler32: ?u32,
    compressed_crc32: ?u32,
    filter: ?u32,
};

const Scanner = struct {
    input: []const u8,
    position: usize = 0,
    header: ?lzop.Header = null,

    fn next(self: *Scanner) Error!?Block {
        while (true) {
            if (self.header == null) {
                if (self.position == self.input.len) return null;
                const header = try lzop.parseHeader(self.input[self.position..]);
                self.position += header.encoded_size;
                self.header = header;
            }
            const header = self.header.?;
            const block_offset = self.position;
            const uncompressed_size = try readU32(self.input, &self.position);
            if (uncompressed_size == 0) {
                self.header = null;
                continue;
            }
            if (uncompressed_size == std.math.maxInt(u32) or uncompressed_size > 64 * 1024 * 1024)
                return error.InvalidLzopStream;
            const compressed_size = try readU32(self.input, &self.position);
            if (compressed_size == 0 or compressed_size > uncompressed_size)
                return error.InvalidLzopStream;
            const compressed = compressed_size < uncompressed_size;
            const data_adler = if (header.flags & lzop.Flag.adler32_data != 0)
                try readU32(self.input, &self.position)
            else
                null;
            const data_crc = if (header.flags & lzop.Flag.crc32_data != 0)
                try readU32(self.input, &self.position)
            else
                null;
            const compressed_adler = if (compressed and
                header.flags & lzop.Flag.adler32_compressed != 0)
                try readU32(self.input, &self.position)
            else
                null;
            const compressed_crc = if (compressed and
                header.flags & lzop.Flag.crc32_compressed != 0)
                try readU32(self.input, &self.position)
            else
                null;
            const data_offset = self.position;
            const next_offset = try checkedEnd(data_offset, compressed_size, self.input.len);
            const payload = self.input[data_offset..next_offset];
            if (compressed_adler) |expected|
                if (checksum.adler32(payload) != expected) return error.ChecksumMismatch;
            if (compressed_crc) |expected|
                if (checksum.crc32Best(payload) != expected) return error.ChecksumMismatch;
            self.position = next_offset;
            return .{
                .offset = block_offset,
                .data_offset = data_offset,
                .next_offset = next_offset,
                .uncompressed_size = uncompressed_size,
                .compressed_size = compressed_size,
                .compressed = compressed,
                .data_adler32 = data_adler,
                .data_crc32 = data_crc,
                .compressed_adler32 = compressed_adler,
                .compressed_crc32 = compressed_crc,
                .filter = header.filter,
            };
        }
    }
};

pub fn parseIndex(bytes: []const u8) Error!Index {
    if (bytes.len % 8 != 0) return error.InvalidHadoopLzoIndex;
    const count = bytes.len / 8;
    var previous: ?u64 = null;
    for (0..count) |block| {
        const offset = std.mem.readInt(u64, bytes[block * 8 ..][0..8], .big);
        if (previous) |value| if (offset <= value) return error.InvalidHadoopLzoIndex;
        previous = offset;
    }
    return .{ .bytes = bytes, .block_count = count };
}

pub fn generateIndexAlloc(allocator: std.mem.Allocator, lzop_bytes: []const u8) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    var scanner = Scanner{ .input = lzop_bytes };
    while (try scanner.next()) |block| {
        var bytes: [8]u8 = undefined;
        std.mem.writeInt(u64, &bytes, block.offset, .big);
        try output.appendSlice(allocator, &bytes);
    }
    return output.toOwnedSlice(allocator);
}

pub fn validateIndex(lzop_bytes: []const u8, index_bytes: []const u8) Error!Index {
    const index = try parseIndex(index_bytes);
    var scanner = Scanner{ .input = lzop_bytes };
    var block_number: usize = 0;
    while (try scanner.next()) |block| : (block_number += 1) {
        if (block_number >= index.block_count or
            try index.offsetAt(block_number) != block.offset)
            return error.InvalidHadoopLzoIndex;
    }
    if (block_number != index.block_count) return error.InvalidHadoopLzoIndex;
    return index;
}

pub fn decodeBlockRangeAlloc(
    allocator: std.mem.Allocator,
    lzop_bytes: []const u8,
    index_bytes: []const u8,
    first_block: usize,
    block_count: usize,
    max_output_len: usize,
) ![]u8 {
    const index = try validateIndex(lzop_bytes, index_bytes);
    const range_end = std.math.add(usize, first_block, block_count) catch
        return error.IntegerOverflow;
    if (range_end > index.block_count) return error.HadoopLzoBlockOutOfRange;
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    var scanner = Scanner{ .input = lzop_bytes };
    var block_number: usize = 0;
    while (try scanner.next()) |block| : (block_number += 1) {
        if (block_number < first_block) continue;
        if (block_number == range_end) break;
        if (block.uncompressed_size > max_output_len -| output.items.len)
            return error.OutputLimitExceeded;
        const decoded = try decodeBlockAlloc(allocator, lzop_bytes, block);
        defer allocator.free(decoded);
        try output.appendSlice(allocator, decoded);
    }
    return output.toOwnedSlice(allocator);
}

fn decodeBlockAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    block: Block,
) ![]u8 {
    const output = try allocator.alloc(u8, block.uncompressed_size);
    errdefer allocator.free(output);
    const payload = input[block.data_offset..][0..block.compressed_size];
    if (block.compressed) {
        const written = try lzo1x.decodeInto(payload, output);
        if (written != output.len) return error.SizeMismatch;
    } else {
        @memcpy(output, payload);
    }
    if (block.filter) |distance| applyDeltaFilter(output, @intCast(distance));
    if (block.data_adler32) |expected|
        if (checksum.adler32(output) != expected) return error.ChecksumMismatch;
    if (block.data_crc32) |expected|
        if (checksum.crc32Best(output) != expected) return error.ChecksumMismatch;
    return output;
}

fn applyDeltaFilter(bytes: []u8, distance_u8: u8) void {
    if (distance_u8 == 0 or bytes.len <= distance_u8) return;
    const distance: usize = distance_u8;
    for (distance..bytes.len) |index| bytes[index] +%= bytes[index - distance];
}

fn readU32(input: []const u8, offset: *usize) Error!u32 {
    if (input.len -| offset.* < 4) return error.TruncatedFrame;
    const value = std.mem.readInt(u32, input[offset.*..][0..4], .big);
    offset.* += 4;
    return value;
}

fn checkedEnd(start: usize, size: usize, limit: usize) Error!usize {
    const end = std.math.add(usize, start, size) catch return error.IntegerOverflow;
    if (end > limit) return error.TruncatedFrame;
    return end;
}

test "Hadoop LZO index round trips offsets and block ranges" {
    const allocator = std.testing.allocator;
    const input = "Hadoop LZO indexed payload alpha beta gamma\n" ** 4096;
    const encoded = try lzop.encodeAlloc(allocator, input, .{
        .block_size = 4096,
        .checksum = .crc32,
        .compressed_checksum = true,
    });
    defer allocator.free(encoded);
    const index_bytes = try generateIndexAlloc(allocator, encoded);
    defer allocator.free(index_bytes);
    const index = try validateIndex(encoded, index_bytes);
    try std.testing.expect(index.block_count > 2);
    const decoded = try decodeBlockRangeAlloc(
        allocator,
        encoded,
        index_bytes,
        1,
        2,
        8192,
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input[4096..12288], decoded);
}

test "Hadoop LZO index rejects unsorted truncated and mismatched offsets" {
    try std.testing.expectError(error.InvalidHadoopLzoIndex, parseIndex(&.{0}));
    var duplicate: [16]u8 = @splat(0);
    try std.testing.expectError(error.InvalidHadoopLzoIndex, parseIndex(&duplicate));
}
