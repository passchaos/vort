const std = @import("std");
const core = @import("core.zig");

pub const Error = core.Error || std.mem.Allocator.Error;

const Header = struct {
    decoded_len: usize,
    index: usize,
};

pub fn encodeBlockAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try encodeBlockAppend(allocator, &out, input);
    return out.toOwnedSlice(allocator);
}

pub fn encodeBlockAppend(allocator: std.mem.Allocator, out: *std.ArrayList(u8), input: []const u8) Error!void {
    try writeVarint(allocator, out, input.len);
    try emitLiteral(allocator, out, input);
}

pub fn encodeBlockInto(input: []const u8, output: []u8) Error!usize {
    var fba = std.heap.FixedBufferAllocator.init(output);
    const encoded = try encodeBlockAlloc(fba.allocator(), input);
    return encoded.len;
}

pub fn decodeBlockAlloc(allocator: std.mem.Allocator, block: []const u8) Error![]u8 {
    return try decodeBlockAllocLimited(allocator, block, std.math.maxInt(usize));
}

pub fn decodeBlockAllocLimited(allocator: std.mem.Allocator, block: []const u8, max_output_len: usize) Error![]u8 {
    const decoded_len = try decodedBlockSizeLimited(block, max_output_len);
    const out = try allocator.alloc(u8, decoded_len);
    errdefer allocator.free(out);
    const written = try decodeBlockInto(block, out);
    if (written != decoded_len) return error.SizeMismatch;
    return out;
}

pub fn decodeBlockAppend(allocator: std.mem.Allocator, out: *std.ArrayList(u8), block: []const u8) Error!usize {
    return try decodeBlockAppendLimited(allocator, out, block, std.math.maxInt(usize));
}

pub fn decodeBlockAppendLimited(allocator: std.mem.Allocator, out: *std.ArrayList(u8), block: []const u8, max_output_len: usize) Error!usize {
    const decoded_len = try decodedBlockSizeLimited(block, max_output_len);
    try out.ensureUnusedCapacity(allocator, decoded_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(decoded_len);
    const written = decodeBlockInto(block, slot) catch |err| {
        out.items.len = start;
        return err;
    };
    if (written != decoded_len) {
        out.items.len = start;
        return error.SizeMismatch;
    }
    return written;
}

pub fn decodeBlockInto(block: []const u8, output: []u8) Error!usize {
    const header = try readHeader(block);
    if (output.len < header.decoded_len) return error.OutputTooSmall;
    var input_index = header.index;
    var written: usize = 0;
    while (input_index < block.len) {
        if (written == header.decoded_len) return error.TrailingData;
        const tag = block[input_index];
        input_index += 1;
        switch (tag & 0x03) {
            0 => {
                const literal_len = try readLiteralLen(tag, block, &input_index);
                if (literal_len > header.decoded_len - written) return error.SizeMismatch;
                if (block.len - input_index < literal_len) return error.TruncatedFrame;
                @memcpy(output[written..][0..literal_len], block[input_index..][0..literal_len]);
                input_index += literal_len;
                written += literal_len;
            },
            1 => {
                const len: usize = 4 + ((tag >> 2) & 0x07);
                if (block.len - input_index < 1) return error.TruncatedFrame;
                const offset: usize = (@as(usize, tag & 0xe0) << 3) | block[input_index];
                input_index += 1;
                try copyFromHistory(output[0..header.decoded_len], written, offset, len);
                written += len;
            },
            2 => {
                const len: usize = 1 + (tag >> 2);
                if (block.len - input_index < 2) return error.TruncatedFrame;
                const offset = std.mem.readInt(u16, block[input_index..][0..2], .little);
                input_index += 2;
                try copyFromHistory(output[0..header.decoded_len], written, offset, len);
                written += len;
            },
            3 => {
                const len: usize = 1 + (tag >> 2);
                if (block.len - input_index < 4) return error.TruncatedFrame;
                const offset = std.mem.readInt(u32, block[input_index..][0..4], .little);
                input_index += 4;
                try copyFromHistory(output[0..header.decoded_len], written, offset, len);
                written += len;
            },
            else => unreachable,
        }
    }
    if (written != header.decoded_len) return error.TruncatedFrame;
    return written;
}

pub fn decodedBlockSize(block: []const u8) Error!usize {
    return try decodedBlockSizeLimited(block, std.math.maxInt(usize));
}

pub fn decodedBlockSizeLimited(block: []const u8, max_output_len: usize) Error!usize {
    const header = try readHeader(block);
    if (header.decoded_len > max_output_len) return error.OutputLimitExceeded;
    var input_index = header.index;
    var written: usize = 0;
    while (input_index < block.len) {
        if (written == header.decoded_len) return error.TrailingData;
        const tag = block[input_index];
        input_index += 1;
        switch (tag & 0x03) {
            0 => {
                const literal_len = try readLiteralLen(tag, block, &input_index);
                if (literal_len > header.decoded_len - written) return error.SizeMismatch;
                if (block.len - input_index < literal_len) return error.TruncatedFrame;
                input_index += literal_len;
                written += literal_len;
            },
            1 => {
                const len: usize = 4 + ((tag >> 2) & 0x07);
                if (block.len - input_index < 1) return error.TruncatedFrame;
                const offset: usize = (@as(usize, tag & 0xe0) << 3) | block[input_index];
                input_index += 1;
                try validateCopy(written, header.decoded_len, offset, len);
                written += len;
            },
            2 => {
                const len: usize = 1 + (tag >> 2);
                if (block.len - input_index < 2) return error.TruncatedFrame;
                const offset = std.mem.readInt(u16, block[input_index..][0..2], .little);
                input_index += 2;
                try validateCopy(written, header.decoded_len, offset, len);
                written += len;
            },
            3 => {
                const len: usize = 1 + (tag >> 2);
                if (block.len - input_index < 4) return error.TruncatedFrame;
                const offset = std.mem.readInt(u32, block[input_index..][0..4], .little);
                input_index += 4;
                try validateCopy(written, header.decoded_len, offset, len);
                written += len;
            },
            else => unreachable,
        }
    }
    if (written != header.decoded_len) return error.TruncatedFrame;
    return header.decoded_len;
}

fn readHeader(block: []const u8) Error!Header {
    var result: usize = 0;
    var shift: u6 = 0;
    var index: usize = 0;
    while (index < block.len and index < 5) : (index += 1) {
        const byte = block[index];
        const payload = byte & 0x7f;
        if (index == 4 and payload > 0x0f) return error.CorruptFrame;
        result |= @as(usize, payload) << shift;
        if ((byte & 0x80) == 0) {
            return .{ .decoded_len = result, .index = index + 1 };
        }
        shift += 7;
    }
    return if (index < 5) error.TruncatedFrame else error.CorruptFrame;
}

fn writeVarint(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: usize) Error!void {
    if (value > std.math.maxInt(u32)) return error.OutputLimitExceeded;
    var remaining = value;
    while (remaining >= 0x80) {
        try out.append(allocator, @as(u8, @intCast(remaining & 0x7f)) | 0x80);
        remaining >>= 7;
    }
    try out.append(allocator, @intCast(remaining));
}

fn readLiteralLen(tag: u8, block: []const u8, input_index: *usize) Error!usize {
    const tag_len = tag >> 2;
    if (tag_len < 60) return @as(usize, tag_len) + 1;
    const byte_count: usize = @as(usize, tag_len) - 59;
    if (block.len - input_index.* < byte_count) return error.TruncatedFrame;
    var len_minus_one: usize = 0;
    var shift: u6 = 0;
    var i: usize = 0;
    while (i < byte_count) : (i += 1) {
        len_minus_one |= @as(usize, block[input_index.* + i]) << shift;
        shift += 8;
    }
    input_index.* += byte_count;
    return std.math.add(usize, len_minus_one, 1) catch error.IntegerOverflow;
}

fn emitLiteral(allocator: std.mem.Allocator, out: *std.ArrayList(u8), literal: []const u8) Error!void {
    if (literal.len == 0) return;
    const len_minus_one = literal.len - 1;
    if (len_minus_one < 60) {
        try out.append(allocator, @intCast(len_minus_one << 2));
    } else {
        var byte_count: usize = 1;
        var tmp = len_minus_one;
        while (tmp >= 0x100) : (tmp >>= 8) byte_count += 1;
        if (byte_count > 4) return error.OutputLimitExceeded;
        try out.append(allocator, @intCast((59 + byte_count) << 2));
        tmp = len_minus_one;
        var i: usize = 0;
        while (i < byte_count) : (i += 1) {
            try out.append(allocator, @intCast(tmp & 0xff));
            tmp >>= 8;
        }
    }
    try out.appendSlice(allocator, literal);
}

fn validateCopy(written: usize, decoded_len: usize, offset_raw: anytype, len: usize) Error!void {
    const offset: usize = @intCast(offset_raw);
    if (offset == 0 or offset > written) return error.InvalidMatch;
    if (len > decoded_len - written) return error.SizeMismatch;
}

fn copyFromHistory(output: []u8, written: usize, offset_raw: anytype, len: usize) Error!void {
    try validateCopy(written, output.len, offset_raw, len);
    const offset: usize = @intCast(offset_raw);
    var i: usize = 0;
    while (i < len) : (i += 1) {
        output[written + i] = output[written - offset + i];
    }
}

test "snappy raw block encodes empty and hello with known bytes" {
    const empty = try encodeBlockAlloc(std.testing.allocator, "");
    defer std.testing.allocator.free(empty);
    try std.testing.expectEqualSlices(u8, &[_]u8{0x00}, empty);
    try std.testing.expectEqual(@as(usize, 0), try decodedBlockSize(empty));

    const hello = try encodeBlockAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(hello);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x05, 0x10, 'h', 'e', 'l', 'l', 'o' }, hello);
    const decoded = try decodeBlockAlloc(std.testing.allocator, hello);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "hello", decoded);
}

test "snappy raw block round trips repeated payload with copy tokens" {
    const payload = "abcabcabcabcabcabc" ** 16;
    const encoded = try encodeBlockAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqual(payload.len, try decodedBlockSize(encoded));
    const decoded = try decodeBlockAllocLimited(std.testing.allocator, encoded, payload.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expectError(error.OutputLimitExceeded, decodedBlockSizeLimited(encoded, payload.len - 1));
}

test "snappy raw block decodes copy1 copy2 and copy4 forms" {
    const copy1 = [_]u8{ 12, 0x08, 'a', 'b', 'c', 0x15, 3 };
    var copy1_out: [12]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 12), try decodeBlockInto(&copy1, &copy1_out));
    try std.testing.expectEqualSlices(u8, "abcabcabcabc", &copy1_out);

    const copy2 = [_]u8{ 5, 0x00, 'a', 0x0e, 0x01, 0x00 };
    var copy2_out: [5]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 5), try decodeBlockInto(&copy2, &copy2_out));
    try std.testing.expectEqualSlices(u8, "aaaaa", &copy2_out);

    const copy4 = [_]u8{ 5, 0x00, 'z', 0x0f, 0x01, 0x00, 0x00, 0x00 };
    var copy4_out: [5]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 5), try decodeBlockInto(&copy4, &copy4_out));
    try std.testing.expectEqualSlices(u8, "zzzzz", &copy4_out);
}

test "snappy raw block supports extended literal lengths" {
    const payload = "x" ** 300;
    const encoded = try encodeBlockAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const decoded = try decodeBlockAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "snappy raw block rejects malformed input" {
    try std.testing.expectError(error.TruncatedFrame, decodedBlockSize(&[_]u8{}));
    try std.testing.expectError(error.CorruptFrame, decodedBlockSize(&[_]u8{ 0x80, 0x80, 0x80, 0x80, 0x80 }));
    try std.testing.expectError(error.TruncatedFrame, decodedBlockSize(&[_]u8{ 5, 0x10, 'h' }));
    try std.testing.expectError(error.InvalidMatch, decodedBlockSize(&[_]u8{ 4, 0x0e, 0x00, 0x00 }));
    try std.testing.expectError(error.InvalidMatch, decodedBlockSize(&[_]u8{ 4, 0x0e, 0x01, 0x00 }));
    try std.testing.expectError(error.TrailingData, decodedBlockSize(&[_]u8{ 0, 0 }));
}
