const std = @import("std");
const core = @import("core.zig");
const bitstream = @import("bitstream.zig");

pub const Error = core.Error || std.mem.Allocator.Error;

pub const max_uncompressed_meta_block_len: usize = 1 << 24;

pub const default_window_bits: u5 = 16;

pub const StoredStreamOptions = struct {
    window_bits: u5 = default_window_bits,
    metadata: []const u8 = "",
};

const BitWriter = struct {
    out: *std.ArrayList(u8),
    bit_index: u3 = 0,

    fn writeBits(self: *BitWriter, allocator: std.mem.Allocator, value: u64, count: u6) Error!void {
        if (count > 64) return error.CorruptFrame;
        var remaining = count;
        var cursor = value;
        while (remaining > 0) : (remaining -= 1) {
            if (self.bit_index == 0) try self.out.append(allocator, 0);
            if ((cursor & 1) != 0) self.out.items[self.out.items.len - 1] |= @as(u8, 1) << self.bit_index;
            cursor >>= 1;
            self.bit_index +%= 1;
        }
    }

    fn alignToByte(self: *BitWriter) void {
        self.bit_index = 0;
    }

    fn writeAlignedBytes(self: *BitWriter, allocator: std.mem.Allocator, bytes: []const u8) Error!void {
        if (self.bit_index != 0) return error.CorruptFrame;
        try self.out.appendSlice(allocator, bytes);
    }
};

pub fn encodeStoredStreamAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    return try encodeStoredStreamWithOptionsAlloc(allocator, input, .{});
}

pub fn encodeStoredStreamWithOptionsAlloc(allocator: std.mem.Allocator, input: []const u8, options: StoredStreamOptions) Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try encodeStoredStreamWithOptionsAppend(allocator, &out, input, options);
    return out.toOwnedSlice(allocator);
}

pub fn encodeStoredStreamAppend(allocator: std.mem.Allocator, out: *std.ArrayList(u8), input: []const u8) Error!void {
    try encodeStoredStreamWithOptionsAppend(allocator, out, input, .{});
}

pub fn encodeStoredStreamWithOptionsAppend(allocator: std.mem.Allocator, out: *std.ArrayList(u8), input: []const u8, options: StoredStreamOptions) Error!void {
    var writer = BitWriter{ .out = out };
    try writeWindowBits(allocator, &writer, options.window_bits);
    if (options.metadata.len != 0) try writeMetadataMetaBlock(allocator, &writer, options.metadata);

    var offset: usize = 0;
    while (offset < input.len) {
        const block_len = @min(input.len - offset, max_uncompressed_meta_block_len);
        try writeUncompressedMetaBlock(allocator, &writer, input[offset..][0..block_len]);
        offset += block_len;
    }

    // End with an empty final meta-block. Brotli forbids marking an
    // uncompressed meta-block as the last one, so even non-empty stored streams
    // need this explicit terminator.
    try writer.writeBits(allocator, 1, 1); // ISLAST
    try writer.writeBits(allocator, 1, 1); // ISLASTEMPTY
}

pub fn encodeStoredStreamInto(input: []const u8, output: []u8) Error!usize {
    return try encodeStoredStreamWithOptionsInto(input, output, .{});
}

pub fn encodeStoredStreamWithOptionsInto(input: []const u8, output: []u8, options: StoredStreamOptions) Error!usize {
    var fba = std.heap.FixedBufferAllocator.init(output);
    const encoded = try encodeStoredStreamWithOptionsAlloc(fba.allocator(), input, options);
    return encoded.len;
}

fn writeUncompressedMetaBlock(allocator: std.mem.Allocator, writer: *BitWriter, block: []const u8) Error!void {
    if (block.len == 0 or block.len > max_uncompressed_meta_block_len) return error.InvalidBlockPlan;
    const len_minus_one = block.len - 1;
    const mnibbles: usize = if (len_minus_one <= 0xffff)
        4
    else if (len_minus_one <= 0xfffff)
        5
    else
        6;
    const mnibbles_code: u2 = switch (mnibbles) {
        4 => 0b00,
        5 => 0b01,
        6 => 0b10,
        else => unreachable,
    };

    try writer.writeBits(allocator, 0, 1); // ISLAST = false.
    try writer.writeBits(allocator, mnibbles_code, 2);
    try writer.writeBits(allocator, @intCast(len_minus_one), @intCast(mnibbles * 4));
    try writer.writeBits(allocator, 1, 1); // ISUNCOMPRESSED.
    writer.alignToByte();
    try writer.writeAlignedBytes(allocator, block);
}

fn writeMetadataMetaBlock(allocator: std.mem.Allocator, writer: *BitWriter, metadata: []const u8) Error!void {
    if (metadata.len > 0x1_0000) return error.InvalidBlockPlan;
    try writer.writeBits(allocator, 0, 1); // ISLAST = false.
    try writer.writeBits(allocator, 0b11, 2); // MNIBBLES = 0.
    try writer.writeBits(allocator, 0, 1); // reserved.
    if (metadata.len == 0) {
        try writer.writeBits(allocator, 0, 2); // MSKIPBYTES = 0.
    } else {
        const len_minus_one = metadata.len - 1;
        const mskipbytes: usize = if (len_minus_one <= 0xff) 1 else 2;
        try writer.writeBits(allocator, @intCast(mskipbytes), 2);
        try writer.writeBits(allocator, @intCast(len_minus_one), @intCast(mskipbytes * 8));
    }
    writer.alignToByte();
    try writer.writeAlignedBytes(allocator, metadata);
}

pub fn decodeStreamAlloc(allocator: std.mem.Allocator, stream: []const u8) Error![]u8 {
    return try decodeStreamAllocLimited(allocator, stream, std.math.maxInt(usize));
}

pub fn decodeStreamAllocLimited(allocator: std.mem.Allocator, stream: []const u8, max_output_len: usize) Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    _ = try decodeStreamAppendLimited(allocator, &out, stream, max_output_len);
    return out.toOwnedSlice(allocator);
}

pub fn decodeStreamAppend(allocator: std.mem.Allocator, out: *std.ArrayList(u8), stream: []const u8) Error!usize {
    return try decodeStreamAppendLimited(allocator, out, stream, std.math.maxInt(usize));
}

pub fn decodeStreamAppendLimited(allocator: std.mem.Allocator, out: *std.ArrayList(u8), stream: []const u8, max_output_len: usize) Error!usize {
    const decoded_len = try decodedStreamSizeLimited(stream, max_output_len);
    try out.ensureUnusedCapacity(allocator, decoded_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(decoded_len);
    const written = decodeStreamInto(stream, slot) catch |err| {
        out.items.len = start;
        return err;
    };
    if (written != decoded_len) {
        out.items.len = start;
        return error.SizeMismatch;
    }
    return written;
}

pub fn decodeStreamInto(stream: []const u8, output: []u8) Error!usize {
    var reader = bitstream.BitReader.init(stream);
    try readWindowBits(&reader);
    var written: usize = 0;
    while (true) {
        const is_last = try reader.readBits(u1, 1) == 1;
        if (is_last) {
            const is_last_empty = try reader.readBits(u1, 1) == 1;
            if (is_last_empty) {
                try ensureZeroPaddingAndEnd(reader);
                return written;
            }
        }

        const mnibbles_code = try reader.readBits(u2, 2);
        const mnibbles: usize = switch (mnibbles_code) {
            0b00 => 4,
            0b01 => 5,
            0b10 => 6,
            0b11 => 0,
        };
        if (mnibbles == 0) {
            try skipMetadataMetaBlock(&reader);
            continue;
        }
        const len_minus_one = try reader.readBits(u32, @intCast(mnibbles * 4));
        if (mnibbles > 4 and ((len_minus_one >> @intCast((mnibbles - 1) * 4)) & 0xf) == 0) return error.CorruptFrame;
        const meta_block_len = std.math.add(usize, len_minus_one, 1) catch return error.IntegerOverflow;
        if (is_last) return error.UnsupportedBrotliFeature;
        const is_uncompressed = try reader.readBits(u1, 1) == 1;
        if (!is_uncompressed) return error.UnsupportedBrotliFeature;
        try consumeZeroPaddingToByte(&reader);
        if (output.len - written < meta_block_len) return error.OutputTooSmall;
        try reader.readAlignedBytes(output[written..][0..meta_block_len]);
        written += meta_block_len;
    }
}

pub fn decodedStreamSize(stream: []const u8) Error!usize {
    return try decodedStreamSizeLimited(stream, std.math.maxInt(usize));
}

pub fn decodedStreamSizeLimited(stream: []const u8, max_output_len: usize) Error!usize {
    var reader = bitstream.BitReader.init(stream);
    try readWindowBits(&reader);
    var total: usize = 0;
    while (true) {
        const is_last = try reader.readBits(u1, 1) == 1;
        if (is_last) {
            const is_last_empty = try reader.readBits(u1, 1) == 1;
            if (is_last_empty) {
                try ensureZeroPaddingAndEnd(reader);
                return total;
            }
        }

        const mnibbles_code = try reader.readBits(u2, 2);
        const mnibbles: usize = switch (mnibbles_code) {
            0b00 => 4,
            0b01 => 5,
            0b10 => 6,
            0b11 => 0,
        };
        if (mnibbles == 0) {
            try skipMetadataMetaBlock(&reader);
            continue;
        }
        const len_minus_one = try reader.readBits(u32, @intCast(mnibbles * 4));
        if (mnibbles > 4 and ((len_minus_one >> @intCast((mnibbles - 1) * 4)) & 0xf) == 0) return error.CorruptFrame;
        const meta_block_len = std.math.add(usize, len_minus_one, 1) catch return error.IntegerOverflow;
        if (is_last) return error.UnsupportedBrotliFeature;
        const is_uncompressed = try reader.readBits(u1, 1) == 1;
        if (!is_uncompressed) return error.UnsupportedBrotliFeature;
        try consumeZeroPaddingToByte(&reader);
        total = std.math.add(usize, total, meta_block_len) catch return error.IntegerOverflow;
        if (total > max_output_len) return error.OutputLimitExceeded;
        if (reader.byte_index > stream.len or stream.len - reader.byte_index < meta_block_len) return error.TruncatedFrame;
        reader.byte_index += meta_block_len;
    }
}

fn readWindowBits(reader: *bitstream.BitReader) Error!void {
    _ = try readWindowBitsValue(reader);
}

fn readWindowBitsValue(reader: *bitstream.BitReader) Error!u5 {
    const first = try reader.readBits(u1, 1);
    if (first == 0) return 16;
    const low3 = try reader.readBits(u3, 3);
    if (low3 != 0) return @as(u5, low3) + 17;

    const tail = try reader.readBits(u3, 3);
    return switch (tail) {
        0 => 17,
        1 => error.CorruptFrame,
        else => @as(u5, tail) + 8,
    };
}

fn writeWindowBits(allocator: std.mem.Allocator, writer: *BitWriter, window_bits: u5) Error!void {
    switch (window_bits) {
        16 => try writer.writeBits(allocator, 0, 1),
        18...24 => {
            try writer.writeBits(allocator, 1, 1);
            try writer.writeBits(allocator, @as(u64, window_bits - 17), 3);
        },
        17 => {
            try writer.writeBits(allocator, 1, 1);
            try writer.writeBits(allocator, 0, 3);
            try writer.writeBits(allocator, 0, 3);
        },
        10...15 => {
            try writer.writeBits(allocator, 1, 1);
            try writer.writeBits(allocator, 0, 3);
            try writer.writeBits(allocator, @as(u64, window_bits - 8), 3);
        },
        else => return error.InvalidBlockPlan,
    }
}

fn consumeZeroPaddingToByte(reader: *bitstream.BitReader) Error!void {
    if (reader.bit_index == 0) return;
    const pad_bits: u6 = 8 - @as(u6, reader.bit_index);
    const padding = try reader.readBits(u8, pad_bits);
    if (padding != 0) return error.CorruptFrame;
}

fn skipMetadataMetaBlock(reader: *bitstream.BitReader) Error!void {
    const reserved = try reader.readBits(u1, 1);
    if (reserved != 0) return error.CorruptFrame;
    const mskipbytes = try reader.readBits(u2, 2);
    var metadata_len: usize = 0;
    if (mskipbytes != 0) {
        const len_minus_one = try reader.readBits(u32, @intCast(@as(usize, mskipbytes) * 8));
        if (mskipbytes > 1 and ((len_minus_one >> @intCast((@as(usize, mskipbytes) - 1) * 8)) & 0xff) == 0) return error.CorruptFrame;
        metadata_len = std.math.add(usize, len_minus_one, 1) catch return error.IntegerOverflow;
    }
    try consumeZeroPaddingToByte(reader);
    if (reader.byte_index > reader.input.len or reader.input.len - reader.byte_index < metadata_len) return error.TruncatedFrame;
    reader.byte_index += metadata_len;
}

fn ensureZeroPaddingAndEnd(reader: bitstream.BitReader) Error!void {
    var copy = reader;
    try consumeZeroPaddingToByte(&copy);
    if (copy.byte_index != copy.input.len) return error.TrailingData;
}

test "br stored stream encodes RFC-valid empty stream" {
    const encoded = try encodeStoredStreamAlloc(std.testing.allocator, "");
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqualSlices(u8, &[_]u8{0x06}, encoded);
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "", decoded);
}

test "br stored stream round trips hello with known bytes" {
    const encoded = try encodeStoredStreamAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x40, 0x00, 0x10, 'h', 'e', 'l', 'l', 'o', 0x03 }, encoded);
    try std.testing.expectEqual(@as(usize, 5), try decodedStreamSize(encoded));
    const decoded = try decodeStreamAllocLimited(std.testing.allocator, encoded, 5);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "hello", decoded);
    try std.testing.expectError(error.OutputLimitExceeded, decodedStreamSizeLimited(encoded, 4));
    var out: [5]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 5), try decodeStreamInto(encoded, &out));
    try std.testing.expectEqualSlices(u8, "hello", &out);
}

test "br stored stream supports all RFC window bits" {
    inline for (.{ 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24 }) |bits| {
        const encoded = try encodeStoredStreamWithOptionsAlloc(std.testing.allocator, "window", .{ .window_bits = bits });
        defer std.testing.allocator.free(encoded);
        try std.testing.expectEqual(@as(usize, 6), try decodedStreamSize(encoded));
        const decoded = try decodeStreamAlloc(std.testing.allocator, encoded);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, "window", decoded);
    }
}

test "br stored stream skips metadata meta-blocks" {
    const encoded = try encodeStoredStreamWithOptionsAlloc(std.testing.allocator, "payload", .{ .metadata = "vort-metadata" });
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqual(@as(usize, 7), try decodedStreamSize(encoded));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "payload", decoded);
}

test "br stored stream decodes multiple uncompressed meta-blocks" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writeUncompressedMetaBlock(std.testing.allocator, &writer, "first ");
    try writeUncompressedMetaBlock(std.testing.allocator, &writer, "second");
    try writer.writeBits(std.testing.allocator, 1, 1);
    try writer.writeBits(std.testing.allocator, 1, 1);

    const payload = "first second";
    try std.testing.expectEqual(payload.len, try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "br stored stream rejects unsupported compressed blocks and trailing data" {
    try std.testing.expectError(error.TruncatedFrame, decodeStreamAlloc(std.testing.allocator, &[_]u8{ 0x00, 0x00 }));
    try std.testing.expectError(error.TrailingData, decodedStreamSize(&[_]u8{ 0x06, 0x00 }));
    try std.testing.expectError(error.TruncatedFrame, decodedStreamSize(&[_]u8{ 0x40, 0x00, 0x10, 'h' }));
}

test "br stored stream rejects malformed metadata meta-blocks" {
    var reserved_bad: std.ArrayList(u8) = .empty;
    defer reserved_bad.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &reserved_bad };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLAST = false.
    try writer.writeBits(std.testing.allocator, 0b11, 2); // MNIBBLES = 0.
    try writer.writeBits(std.testing.allocator, 1, 1); // reserved, invalid.
    try writer.writeBits(std.testing.allocator, 0, 2);
    try std.testing.expectError(error.CorruptFrame, decodedStreamSize(reserved_bad.items));

    var truncated = try encodeStoredStreamWithOptionsAlloc(std.testing.allocator, "", .{ .metadata = "metadata" });
    defer std.testing.allocator.free(truncated);
    try std.testing.expectError(error.TruncatedFrame, decodedStreamSize(truncated[0 .. truncated.len - 1]));
}
