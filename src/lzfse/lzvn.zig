const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || std.mem.Allocator.Error || error{
    InvalidLzvnStream,
};

const max_distance: usize = std.math.maxInt(u16);
const hash_table_size: usize = 1 << 16;
const invalid_position = std.math.maxInt(u32);

pub fn encodeAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, input);
    return output.toOwnedSlice(allocator);
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
) Error!usize {
    if (input.len > std.math.maxInt(u32)) return error.InvalidLzvnStream;
    const start = output.items.len;
    errdefer output.items.len = start;
    const table = try allocator.alloc(u32, hash_table_size);
    defer allocator.free(table);
    @memset(table, invalid_position);

    var position: usize = 0;
    var literal_start: usize = 0;
    while (position + 4 <= input.len) {
        const hash = hashAt(input, position);
        const candidate_u32 = table[hash];
        table[hash] = @intCast(position);
        if (candidate_u32 == invalid_position) {
            position += 1;
            continue;
        }
        const candidate: usize = candidate_u32;
        const distance = position - candidate;
        if (distance == 0 or distance > max_distance or
            !std.mem.eql(u8, input[candidate..][0..3], input[position..][0..3]))
        {
            position += 1;
            continue;
        }

        var match_len: usize = 3;
        while (position + match_len < input.len and
            input[candidate + match_len] == input[position + match_len])
            match_len += 1;
        const literal_len = position - literal_start;
        const combined_literal_len: usize = @min(literal_len, 3);
        try emitLiteralChunks(
            allocator,
            output,
            input[literal_start .. position - combined_literal_len],
        );
        const first_match_len: usize = @min(match_len, 4);
        const opcode: u8 = @intCast(combined_literal_len * 64 +
            (first_match_len - 3) * 8 + 0x07);
        try output.append(allocator, opcode);
        var distance_bytes: [2]u8 = undefined;
        std.mem.writeInt(u16, &distance_bytes, @intCast(distance), .little);
        try output.appendSlice(allocator, &distance_bytes);
        try output.appendSlice(
            allocator,
            input[position - combined_literal_len .. position],
        );
        try emitMatchChunks(allocator, output, match_len - first_match_len);

        const match_end = position + match_len;
        var update = position + 1;
        while (update + 4 <= match_end) : (update += 1)
            table[hashAt(input, update)] = @intCast(update);
        position = match_end;
        literal_start = position;
    }
    try emitLiteralChunks(allocator, output, input[literal_start..]);
    try output.appendSlice(allocator, &.{ 0x06, 0, 0, 0, 0, 0, 0, 0 });
    return output.items.len - start;
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
) Error!usize {
    const encoded = try encodeAlloc(allocator, input);
    defer allocator.free(encoded);
    if (output.len < encoded.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

pub fn decodedSize(input: []const u8) Error!usize {
    return decodedSizeLimited(input, std.math.maxInt(usize));
}

pub fn decodedSizeLimited(input: []const u8, max_output_len: usize) Error!usize {
    return decodeInternal(input, null, 0, max_output_len);
}

pub fn decodedSizeWithPrefixLimited(
    input: []const u8,
    prefix_len: usize,
    max_output_len: usize,
) Error!usize {
    const output_end = std.math.add(usize, prefix_len, max_output_len) catch
        return error.IntegerOverflow;
    return decodeInternal(input, null, prefix_len, output_end);
}

pub fn decodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
) Error![]u8 {
    return decodeAllocLimited(allocator, input, std.math.maxInt(usize));
}

pub fn decodeAllocLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    max_output_len: usize,
) Error![]u8 {
    const size = try decodedSizeLimited(input, max_output_len);
    const output = try allocator.alloc(u8, size);
    errdefer allocator.free(output);
    _ = try decodeInto(input, output, size);
    return output;
}

pub fn decodeInto(
    input: []const u8,
    output: []u8,
    expected_size: ?usize,
) Error!usize {
    const written = try decodeInternal(input, output, 0, output.len);
    if (expected_size) |size| if (written != size) return error.SizeMismatch;
    return written;
}

pub fn decodeIntoWithPrefix(
    input: []const u8,
    output: []u8,
    output_start: usize,
    expected_size: ?usize,
) Error!usize {
    if (output_start > output.len) return error.OutputTooSmall;
    const written = try decodeInternal(input, output, output_start, output.len);
    if (expected_size) |size| if (written != size) return error.SizeMismatch;
    return written;
}

fn decodeInternal(
    input: []const u8,
    output: ?[]u8,
    output_start: usize,
    max_output_end: usize,
) Error!usize {
    var input_offset: usize = 0;
    var output_offset = output_start;
    var previous_distance: ?usize = null;

    while (true) {
        if (input_offset >= input.len) return error.TruncatedFrame;
        const opcode = input[input_offset];

        if (opcode == 0x06) {
            input_offset = try checkedEnd(input_offset, 8, input.len);
            if (input_offset != input.len) return error.TrailingData;
            return output_offset - output_start;
        }
        if (opcode == 0x0e or opcode == 0x16) {
            input_offset += 1;
            continue;
        }

        if (opcode == 0xe0) {
            const length_offset = try checkedEnd(input_offset, 2, input.len);
            const literal_len: usize = @as(usize, input[input_offset + 1]) + 16;
            try copyLiteral(
                input,
                &input_offset,
                length_offset,
                literal_len,
                output,
                &output_offset,
                max_output_end,
            );
            continue;
        }
        if (opcode >= 0xe1 and opcode <= 0xef) {
            try copyLiteral(
                input,
                &input_offset,
                input_offset + 1,
                opcode & 0x0f,
                output,
                &output_offset,
                max_output_end,
            );
            continue;
        }
        if (opcode == 0xf0) {
            _ = try checkedEnd(input_offset, 2, input.len);
            const match_len: usize = @as(usize, input[input_offset + 1]) + 16;
            input_offset += 2;
            try copyMatch(
                previous_distance orelse return error.InvalidLzvnStream,
                match_len,
                output,
                &output_offset,
                max_output_end,
            );
            continue;
        }
        if (opcode >= 0xf1) {
            input_offset += 1;
            try copyMatch(
                previous_distance orelse return error.InvalidLzvnStream,
                opcode & 0x0f,
                output,
                &output_offset,
                max_output_end,
            );
            continue;
        }

        var opcode_len: usize = undefined;
        var literal_len: usize = undefined;
        var match_len: usize = undefined;
        var distance: usize = undefined;
        if (opcode >= 0xa0 and opcode <= 0xbf) {
            opcode_len = 3;
            _ = try checkedEnd(input_offset, opcode_len, input.len);
            literal_len = (opcode >> 3) & 0x03;
            const tail = std.mem.readInt(u16, input[input_offset + 1 ..][0..2], .little);
            match_len = (@as(usize, opcode & 0x07) << 2 | tail & 0x03) + 3;
            distance = tail >> 2;
        } else if (isCombinedOpcode(opcode)) {
            const kind = opcode & 0x07;
            literal_len = opcode >> 6;
            match_len = @as(usize, (opcode >> 3) & 0x07) + 3;
            switch (kind) {
                0...5 => {
                    opcode_len = 2;
                    _ = try checkedEnd(input_offset, opcode_len, input.len);
                    distance = @as(usize, opcode & 0x07) << 8 |
                        input[input_offset + 1];
                },
                6 => {
                    opcode_len = 1;
                    distance = previous_distance orelse return error.InvalidLzvnStream;
                },
                7 => {
                    opcode_len = 3;
                    _ = try checkedEnd(input_offset, opcode_len, input.len);
                    distance = std.mem.readInt(
                        u16,
                        input[input_offset + 1 ..][0..2],
                        .little,
                    );
                },
                else => unreachable,
            }
        } else {
            return error.InvalidLzvnStream;
        }

        const literal_offset = try checkedEnd(input_offset, opcode_len, input.len);
        try copyLiteral(
            input,
            &input_offset,
            literal_offset,
            literal_len,
            output,
            &output_offset,
            max_output_end,
        );
        previous_distance = distance;
        try copyMatch(
            distance,
            match_len,
            output,
            &output_offset,
            max_output_end,
        );
    }
}

fn emitLiteralChunks(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    literals: []const u8,
) Error!void {
    var offset: usize = 0;
    while (offset < literals.len) {
        const remaining = literals.len - offset;
        const chunk_len = @min(remaining, 271);
        if (chunk_len <= 15) {
            try output.append(allocator, 0xe0 | @as(u8, @intCast(chunk_len)));
        } else {
            try output.append(allocator, 0xe0);
            try output.append(allocator, @intCast(chunk_len - 16));
        }
        try output.appendSlice(allocator, literals[offset..][0..chunk_len]);
        offset += chunk_len;
    }
}

fn emitMatchChunks(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    length: usize,
) Error!void {
    var remaining = length;
    while (remaining != 0) {
        const chunk_len = @min(remaining, 271);
        if (chunk_len <= 15) {
            try output.append(allocator, 0xf0 | @as(u8, @intCast(chunk_len)));
        } else {
            try output.append(allocator, 0xf0);
            try output.append(allocator, @intCast(chunk_len - 16));
        }
        remaining -= chunk_len;
    }
}

fn hashAt(input: []const u8, position: usize) usize {
    const value = std.mem.readInt(u32, input[position..][0..4], .little);
    return @truncate((value *% 0x9e37_79b1) >> 16);
}

fn isCombinedOpcode(opcode: u8) bool {
    const high = opcode >> 4;
    const in_combined_range = high <= 0x06 or high == 0x08 or high == 0x09 or high == 0x0c;
    if (!in_combined_range) return false;
    if (opcode & 0x07 != 0x06) return true;
    // Previous-distance opcodes deliberately leave several otherwise similar
    // bit patterns undefined.
    return high == 0x04 or high == 0x05 or high == 0x06 or
        high == 0x08 or high == 0x09 or high == 0x0c;
}

fn copyLiteral(
    input: []const u8,
    input_offset: *usize,
    literal_offset: usize,
    literal_len: usize,
    output: ?[]u8,
    output_offset: *usize,
    max_output_len: usize,
) Error!void {
    const literal_end = try checkedEnd(literal_offset, literal_len, input.len);
    const output_end = std.math.add(usize, output_offset.*, literal_len) catch
        return error.IntegerOverflow;
    if (output_end > max_output_len)
        return if (output == null) error.OutputLimitExceeded else error.OutputTooSmall;
    if (output) |bytes| {
        if (output_end > bytes.len) return error.OutputTooSmall;
        @memcpy(bytes[output_offset.*..output_end], input[literal_offset..literal_end]);
    }
    input_offset.* = literal_end;
    output_offset.* = output_end;
}

fn copyMatch(
    distance: usize,
    match_len: usize,
    output: ?[]u8,
    output_offset: *usize,
    max_output_len: usize,
) Error!void {
    if (distance == 0 or distance > output_offset.*) return error.InvalidLzvnStream;
    const output_end = std.math.add(usize, output_offset.*, match_len) catch
        return error.IntegerOverflow;
    if (output_end > max_output_len)
        return if (output == null) error.OutputLimitExceeded else error.OutputTooSmall;
    if (output) |bytes| {
        if (output_end > bytes.len) return error.OutputTooSmall;
        var index = output_offset.*;
        while (index < output_end) : (index += 1) bytes[index] = bytes[index - distance];
    }
    output_offset.* = output_end;
}

fn checkedEnd(start: usize, size: usize, limit: usize) Error!usize {
    const end = std.math.add(usize, start, size) catch return error.IntegerOverflow;
    if (end > limit) return error.TruncatedFrame;
    return end;
}

test "LZVN reference payload decodes literal and repeated matches" {
    const payload = [_]u8{
        0xc8, 0x03, 'a', 'b', 'c', 0xf0, 0x18, 0xe1, 'c',
        0x06, 0,    0,   0,   0,   0,    0,    0,
    };
    const expected = "abcabcabcabcabcabcabcabcabcabcabcabcabcabcabcabc";
    try std.testing.expectEqual(expected.len, try decodedSize(&payload));
    var output: [expected.len]u8 = undefined;
    try std.testing.expectEqual(expected.len, try decodeInto(&payload, &output, expected.len));
    try std.testing.expectEqualSlices(u8, expected, &output);
}

test "LZVN rejects truncation invalid distances trailing data and limits" {
    try std.testing.expectError(error.TruncatedFrame, decodedSize(""));
    try std.testing.expectError(error.InvalidLzvnStream, decodedSize(&.{ 0xf1, 0x06, 0, 0, 0, 0, 0, 0, 0 }));
    try std.testing.expectError(error.TrailingData, decodedSize(&.{ 0x06, 0, 0, 0, 0, 0, 0, 0, 1 }));
    try std.testing.expectError(error.InvalidLzvnStream, decodedSize(&.{ 0x1e, 0x06, 0, 0, 0, 0, 0, 0, 0 }));
    try std.testing.expectError(
        error.OutputLimitExceeded,
        decodedSizeLimited(&.{ 0xe3, 'a', 'b', 'c', 0x06, 0, 0, 0, 0, 0, 0, 0 }, 2),
    );
    var output: [2]u8 = undefined;
    try std.testing.expectError(
        error.OutputTooSmall,
        decodeInto(&.{ 0xe3, 'a', 'b', 'c', 0x06, 0, 0, 0, 0, 0, 0, 0 }, &output, 3),
    );
}

test "LZVN deterministic writer round trips literals and long matches" {
    const allocator = std.testing.allocator;
    const input = "LZVN deterministic compressed payload abcabcabc\n" ** 512;
    const encoded = try encodeAlloc(allocator, input);
    defer allocator.free(encoded);
    try std.testing.expect(encoded.len < input.len);
    const repeated = try encodeAlloc(allocator, input);
    defer allocator.free(repeated);
    try std.testing.expectEqualSlices(u8, encoded, repeated);
    const decoded = try decodeAlloc(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);

    var unique: [300]u8 = undefined;
    for (&unique, 0..) |*byte, index| byte.* = @truncate(index * 73 + index / 11);
    const literal_encoded = try encodeAlloc(allocator, &unique);
    defer allocator.free(literal_encoded);
    const literal_decoded = try decodeAlloc(allocator, literal_encoded);
    defer allocator.free(literal_decoded);
    try std.testing.expectEqualSlices(u8, &unique, literal_decoded);
}
