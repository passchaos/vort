const std = @import("std");

pub const Error = error{
    InputTooLarge,
    OutputTooSmall,
};

/// Result of liblz4-compatible fill-output block compression.
///
/// `consumed` is the source prefix represented by `output[0..written]`.
pub const Result = struct {
    written: usize,
    consumed: usize,
};

const min_match = 4;
const last_literals = 5;
const match_find_limit = 12;
const min_input_len = match_find_limit + 1;
const distance_max = std.math.maxInt(u16);
const hash_log = 12;
const skip_trigger = 6;
const input_64k_limit = 64 * 1024 + match_find_limit - 1;
const max_input_len = 0x7e00_0000;

const TableKind = enum {
    u16,
    u32,
};

/// Compress as much of `input` as fits in `output`, reproducing
/// `LZ4_compress_destSize()` from liblz4 1.9.3 on a 64-bit little-endian host.
///
/// LZ4DIFF depends on both the exact encoded bytes and the consumed source
/// prefix, so this deliberately implements liblz4's fill-output parser rather
/// than truncating a normal LZ4 block.
pub fn compress(input: []const u8, output: []u8) Error!Result {
    if (input.len > max_input_len) return error.InputTooLarge;
    if (output.len == 0) return error.OutputTooSmall;
    if (input.len == 0) {
        output[0] = 0;
        return .{ .written = 1, .consumed = 0 };
    }

    if (input.len < input_64k_limit) {
        var table: [1 << (hash_log + 1)]u16 = @splat(0);
        return compressWithTable(u16, .u16, input, output, &table);
    }
    var table: [1 << hash_log]u32 = @splat(0);
    return compressWithTable(u32, .u32, input, output, &table);
}

fn compressWithTable(
    comptime Index: type,
    comptime table_kind: TableKind,
    input: []const u8,
    output: []u8,
    table: []Index,
) Result {
    var input_index: usize = 0;
    var anchor: usize = 0;
    var output_index: usize = 0;

    if (input.len < min_input_len)
        return emitLastLiterals(input, anchor, output, output_index);

    const match_find_limit_plus_one = input.len - match_find_limit + 1;
    const match_limit = input.len - last_literals;

    putPosition(Index, table_kind, input, table, input_index);
    input_index += 1;
    var forward_hash = hashPosition(table_kind, input, input_index);

    while (true) {
        var match_index: usize = undefined;
        var filled_input_index: usize = undefined;
        var token_index: usize = undefined;

        search: while (true) {
            var forward_index = input_index;
            var step: usize = 1;
            var search_match_count: usize = 1 << skip_trigger;
            while (true) {
                const hash = forward_hash;
                const current = forward_index;
                match_index = @intCast(table[hash]);
                input_index = forward_index;
                forward_index += step;
                step = search_match_count >> skip_trigger;
                search_match_count += 1;

                if (forward_index > match_find_limit_plus_one)
                    return emitLastLiterals(input, anchor, output, output_index);

                forward_hash = hashPosition(table_kind, input, forward_index);
                table[hash] = @intCast(current);
                if (table_kind == .u32 and match_index + distance_max < current)
                    continue;
                if (readU32(input, match_index) == readU32(input, input_index))
                    break;
            }

            filled_input_index = input_index;
            while (input_index > anchor and match_index > 0 and
                input[input_index - 1] == input[match_index - 1])
            {
                input_index -= 1;
                match_index -= 1;
            }

            const literal_len = input_index - anchor;
            token_index = output_index;
            output_index += 1;
            if (output_index + (literal_len + 240) / 255 + literal_len + 2 + 1 +
                (match_find_limit - min_match) > output.len)
            {
                output_index -= 1;
                return emitLastLiterals(input, anchor, output, output_index);
            }
            if (literal_len >= 15) {
                output[token_index] = 15 << 4;
                var remaining = literal_len - 15;
                while (remaining >= 255) : (remaining -= 255) {
                    output[output_index] = 255;
                    output_index += 1;
                }
                output[output_index] = @intCast(remaining);
                output_index += 1;
            } else {
                output[token_index] = @intCast(literal_len << 4);
            }
            @memcpy(output[output_index..][0..literal_len], input[anchor..input_index]);
            output_index += literal_len;

            while (true) {
                if (output_index + 2 + 1 +
                    (match_find_limit - min_match) > output.len)
                {
                    output_index = token_index;
                    return emitLastLiterals(input, anchor, output, output_index);
                }

                const offset: u16 = @intCast(input_index - match_index);
                std.mem.writeInt(u16, output[output_index..][0..2], offset, .little);
                output_index += 2;

                var match_code = countMatch(
                    input,
                    input_index + min_match,
                    match_index + min_match,
                    match_limit,
                );
                input_index += match_code + min_match;
                if (output_index + 1 + last_literals +
                    (match_code + 240) / 255 > output.len)
                {
                    const extension_slots = output.len - output_index - 1 - last_literals;
                    const shortened = 14 + extension_slots * 255;
                    input_index -= match_code - shortened;
                    match_code = shortened;
                    if (input_index <= filled_input_index) {
                        var clear_index = input_index;
                        while (clear_index <= filled_input_index) : (clear_index += 1)
                            table[hashPosition(table_kind, input, clear_index)] = 0;
                    }
                }
                if (match_code >= 15) {
                    output[token_index] += 15;
                    var remaining = match_code - 15;
                    while (remaining >= 255) : (remaining -= 255) {
                        output[output_index] = 255;
                        output_index += 1;
                    }
                    output[output_index] = @intCast(remaining);
                    output_index += 1;
                } else {
                    output[token_index] += @intCast(match_code);
                }

                anchor = input_index;
                if (input_index >= match_find_limit_plus_one)
                    return emitLastLiterals(input, anchor, output, output_index);

                putPosition(Index, table_kind, input, table, input_index - 2);
                const hash = hashPosition(table_kind, input, input_index);
                const current = input_index;
                match_index = @intCast(table[hash]);
                table[hash] = @intCast(current);
                if ((table_kind == .u16 or match_index + distance_max >= current) and
                    readU32(input, match_index) == readU32(input, input_index))
                {
                    token_index = output_index;
                    output[output_index] = 0;
                    output_index += 1;
                    continue;
                }
                input_index += 1;
                forward_hash = hashPosition(table_kind, input, input_index);
                continue :search;
            }
        }
    }
}

fn emitLastLiterals(
    input: []const u8,
    anchor: usize,
    output: []u8,
    initial_output_index: usize,
) Result {
    var output_index = initial_output_index;
    var last_run = input.len - anchor;
    if (output_index + last_run + 1 + (last_run + 255 - 15) / 255 > output.len) {
        last_run = output.len - output_index - 1;
        last_run -= (last_run + 256 - 15) / 256;
    }
    if (last_run >= 15) {
        output[output_index] = 15 << 4;
        output_index += 1;
        var remaining = last_run - 15;
        while (remaining >= 255) : (remaining -= 255) {
            output[output_index] = 255;
            output_index += 1;
        }
        output[output_index] = @intCast(remaining);
        output_index += 1;
    } else {
        output[output_index] = @intCast(last_run << 4);
        output_index += 1;
    }
    @memcpy(output[output_index..][0..last_run], input[anchor..][0..last_run]);
    output_index += last_run;
    return .{
        .written = output_index,
        .consumed = anchor + last_run,
    };
}

fn putPosition(
    comptime Index: type,
    comptime table_kind: TableKind,
    input: []const u8,
    table: []Index,
    index: usize,
) void {
    table[hashPosition(table_kind, input, index)] = @intCast(index);
}

fn hashPosition(
    comptime table_kind: TableKind,
    input: []const u8,
    index: usize,
) usize {
    return switch (table_kind) {
        .u16 => blk: {
            const value = readU32(input, index) *% @as(u32, 2_654_435_761);
            break :blk @intCast(value >> (32 - (hash_log + 1)));
        },
        .u32 => blk: {
            const sequence = std.mem.readInt(u64, input[index..][0..8], .little);
            const mixed = (sequence << 24) *% @as(u64, 889_523_592_379);
            break :blk @intCast(mixed >> (64 - hash_log));
        },
    };
}

fn readU32(input: []const u8, index: usize) u32 {
    return std.mem.readInt(u32, input[index..][0..4], .little);
}

fn countMatch(
    input: []const u8,
    input_index: usize,
    match_index: usize,
    limit: usize,
) usize {
    var index = input_index;
    var candidate = match_index;
    while (index < limit and input[index] == input[candidate]) {
        index += 1;
        candidate += 1;
    }
    return index - input_index;
}

test "LZ4 dest-size handles empty tiny and one-byte outputs" {
    var output: [32]u8 = undefined;
    var result = try compress("", output[0..]);
    try std.testing.expectEqual(@as(usize, 1), result.written);
    try std.testing.expectEqual(@as(usize, 0), result.consumed);
    try std.testing.expectEqual(@as(u8, 0), output[0]);

    result = try compress("hello", output[0..1]);
    try std.testing.expectEqual(@as(usize, 1), result.written);
    try std.testing.expectEqual(@as(usize, 0), result.consumed);
    try std.testing.expectEqual(@as(u8, 0), output[0]);
    try std.testing.expectError(error.OutputTooSmall, compress("hello", output[0..0]));
}

test "LZ4 dest-size matches pinned liblz4 1.9.3 fill-output vectors" {
    const input = "abcabcabcabcabcabcabcabc0123456789" ** 32;
    const vectors = [_]struct {
        capacity: usize,
        consumed: usize,
        encoded: []const u8,
    }{
        .{
            .capacity = 16,
            .consumed = 32,
            .encoded = &.{ 0x3f, 0x61, 0x62, 0x63, 0x03, 0x00, 0x02, 0x80, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37 },
        },
        .{
            .capacity = 31,
            .consumed = 64,
            .encoded = &.{ 0x3f, 0x61, 0x62, 0x63, 0x03, 0x00, 0x02, 0xaf, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x1f, 0x00, 0x02, 0x90, 0x61, 0x62, 0x63, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35 },
        },
        .{
            .capacity = 64,
            .consumed = input.len,
            .encoded = &.{ 0x3f, 0x61, 0x62, 0x63, 0x03, 0x00, 0x02, 0xaf, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x1f, 0x00, 0x02, 0x0f, 0x22, 0x00, 0xff, 0xff, 0xff, 0xf4, 0x50, 0x35, 0x36, 0x37, 0x38, 0x39 },
        },
    };
    for (vectors) |vector| {
        var output: [64]u8 = undefined;
        const result = try compress(input, output[0..vector.capacity]);
        try std.testing.expectEqual(vector.consumed, result.consumed);
        try std.testing.expectEqual(vector.encoded.len, result.written);
        try std.testing.expectEqualSlices(
            u8,
            vector.encoded,
            output[0..result.written],
        );
    }
}
