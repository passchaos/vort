const std = @import("std");
const bit_writer = @import("bit_writer.zig");
const bzip2_crc = @import("crc.zig");
const decoder = @import("decoder.zig");

pub const Error = decoder.Error;

pub const EncodeOptions = struct {
    block_size_100k: u4 = 9,
};

const block_magic: u64 = 0x3141_5926_5359;
const end_magic: u64 = 0x1772_4538_5090;
const group_size: usize = 50;

const RleBlock = struct {
    input_read: usize,
    crc32: u32,
};

const BwtBlock = struct {
    bytes: []u8,
    original_pointer: u32,

    fn deinit(self: BwtBlock, allocator: std.mem.Allocator) void {
        allocator.free(self.bytes);
    }
};

pub fn encodeAlloc(allocator: std.mem.Allocator, input: []const u8, options: EncodeOptions) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, input, options);
    return output.toOwnedSlice(allocator);
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
    options: EncodeOptions,
) !usize {
    const encoded = try encodeAlloc(allocator, input, options);
    defer allocator.free(encoded);
    if (output.len < encoded.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

/// Append a complete Bzip2 stream without changing `out.items` on error.
pub fn encodeAppend(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    options: EncodeOptions,
) !usize {
    if (options.block_size_100k < 1 or options.block_size_100k > 9)
        return error.InvalidBzip2Header;
    const block_limit = @as(usize, options.block_size_100k) * 100_000;

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try encoded.appendSlice(allocator, "BZh");
    try encoded.append(allocator, '0' + @as(u8, options.block_size_100k));
    var writer = bit_writer.BitWriter.init(allocator, &encoded);

    var rle_block: std.ArrayList(u8) = .empty;
    defer rle_block.deinit(allocator);
    try rle_block.ensureTotalCapacity(allocator, block_limit);

    var input_offset: usize = 0;
    var combined_crc: u32 = 0;
    while (input_offset < input.len) {
        const block_result = try fillRleBlock(&rle_block, input[input_offset..], block_limit);
        if (block_result.input_read == 0) return error.InvalidBzip2Stream;
        input_offset += block_result.input_read;

        const transformed = try bwtTransformAlloc(allocator, rle_block.items);
        defer transformed.deinit(allocator);
        try writeBlock(&writer, transformed, block_result.crc32);
        combined_crc = std.math.rotl(u32, combined_crc, 1) ^ block_result.crc32;
    }

    try writer.writeBits(48, end_magic);
    try writer.writeBits(32, combined_crc);
    try writer.finish();

    try out.ensureUnusedCapacity(allocator, encoded.items.len);
    out.appendSliceAssumeCapacity(encoded.items);
    return encoded.items.len;
}

fn fillRleBlock(block: *std.ArrayList(u8), input: []const u8, block_limit: usize) !RleBlock {
    block.clearRetainingCapacity();
    var input_offset: usize = 0;
    var crc = bzip2_crc.Crc32{};
    while (input_offset < input.len) {
        const byte = input[input_offset];
        var run_end = input_offset + 1;
        while (run_end < input.len and input[run_end] == byte) : (run_end += 1) {}
        var remaining = run_end - input_offset;
        while (remaining != 0) {
            const run_len = @min(remaining, 259);
            const encoded_len: usize = if (run_len < 4) run_len else 5;
            if (block.items.len + encoded_len > block_limit) {
                if (block.items.len == 0) return error.InvalidBzip2Stream;
                return .{ .input_read = input_offset, .crc32 = crc.digest() };
            }
            if (run_len < 4) {
                for (0..run_len) |_| block.appendAssumeCapacity(byte);
            } else {
                for (0..4) |_| block.appendAssumeCapacity(byte);
                block.appendAssumeCapacity(@intCast(run_len - 4));
            }
            crc.updateRepeat(byte, run_len);
            input_offset += run_len;
            remaining -= run_len;
        }
    }
    return .{ .input_read = input_offset, .crc32 = crc.digest() };
}

fn bwtTransformAlloc(allocator: std.mem.Allocator, input: []const u8) !BwtBlock {
    if (input.len == 0 or input.len > 900_000) return error.InvalidBzip2Stream;
    const order_a = try allocator.alloc(u32, input.len);
    defer allocator.free(order_a);
    const order_b = try allocator.alloc(u32, input.len);
    defer allocator.free(order_b);
    const classes_a = try allocator.alloc(u32, input.len);
    defer allocator.free(classes_a);
    const classes_b = try allocator.alloc(u32, input.len);
    defer allocator.free(classes_b);
    const counts = try allocator.alloc(usize, @max(input.len, 256));
    defer allocator.free(counts);

    @memset(counts[0..256], 0);
    for (input) |byte| counts[byte] += 1;
    var total: usize = 0;
    for (counts[0..256]) |*count| {
        const frequency = count.*;
        count.* = total;
        total += frequency;
    }
    for (input, 0..) |byte, index| {
        order_a[counts[byte]] = @intCast(index);
        counts[byte] += 1;
    }

    var class_count: usize = 1;
    classes_a[order_a[0]] = 0;
    for (1..input.len) |index| {
        if (input[order_a[index]] != input[order_a[index - 1]]) class_count += 1;
        classes_a[order_a[index]] = @intCast(class_count - 1);
    }

    const order = order_a;
    const next_order = order_b;
    var classes = classes_a;
    var next_classes = classes_b;
    var shift: usize = 1;
    while (shift < input.len) : (shift *= 2) {
        for (order, next_order) |position_u32, *shifted| {
            const position: usize = position_u32;
            shifted.* = @intCast(if (position >= shift) position - shift else position + input.len - shift);
        }

        @memset(counts[0..class_count], 0);
        for (next_order) |position| counts[classes[position]] += 1;
        total = 0;
        for (counts[0..class_count]) |*count| {
            const frequency = count.*;
            count.* = total;
            total += frequency;
        }
        for (next_order) |position| {
            const class = classes[position];
            order[counts[class]] = position;
            counts[class] += 1;
        }

        var next_class_count: usize = 1;
        next_classes[order[0]] = 0;
        for (1..input.len) |index| {
            const current: usize = order[index];
            const previous: usize = order[index - 1];
            const current_pair = .{ classes[current], classes[(current + shift) % input.len] };
            const previous_pair = .{ classes[previous], classes[(previous + shift) % input.len] };
            if (current_pair[0] != previous_pair[0] or current_pair[1] != previous_pair[1])
                next_class_count += 1;
            next_classes[current] = @intCast(next_class_count - 1);
        }
        class_count = next_class_count;
        std.mem.swap([]u32, &classes, &next_classes);
    }

    const transformed = try allocator.alloc(u8, input.len);
    errdefer allocator.free(transformed);
    var original_pointer: ?u32 = null;
    for (order, 0..) |start_u32, row| {
        const start: usize = start_u32;
        transformed[row] = input[if (start == 0) input.len - 1 else start - 1];
        if (start == 0) original_pointer = @intCast(row);
    }
    return .{
        .bytes = transformed,
        .original_pointer = original_pointer orelse return error.InvalidBzip2Stream,
    };
}

fn writeBlock(writer: *bit_writer.BitWriter, transformed: BwtBlock, crc32: u32) !void {
    var in_use: [256]bool = @splat(false);
    for (transformed.bytes) |byte| in_use[byte] = true;
    var sequence: [256]u8 = undefined;
    var byte_to_sequence: [256]u8 = @splat(0);
    var sequence_len: usize = 0;
    for (in_use, 0..) |used, byte| if (used) {
        sequence[sequence_len] = @intCast(byte);
        byte_to_sequence[byte] = @intCast(sequence_len);
        sequence_len += 1;
    };

    var symbols: std.ArrayList(u16) = .empty;
    defer symbols.deinit(writer.allocator);
    try symbols.ensureTotalCapacity(writer.allocator, transformed.bytes.len + 1);
    var mtf: [256]u8 = undefined;
    for (mtf[0..sequence_len], 0..) |*value, index| value.* = @intCast(index);
    var zero_run: usize = 0;
    for (transformed.bytes) |byte| {
        const target = byte_to_sequence[byte];
        var mtf_index: usize = 0;
        while (mtf[mtf_index] != target) : (mtf_index += 1) {}
        if (mtf_index == 0) {
            zero_run += 1;
            continue;
        }
        try flushZeroRun(&symbols, writer.allocator, zero_run);
        zero_run = 0;
        try symbols.append(writer.allocator, @intCast(mtf_index + 1));
        const value = mtf[mtf_index];
        var index = mtf_index;
        while (index > 0) : (index -= 1) mtf[index] = mtf[index - 1];
        mtf[0] = value;
    }
    try flushZeroRun(&symbols, writer.allocator, zero_run);
    const end_of_block: u16 = @intCast(sequence_len + 1);
    try symbols.append(writer.allocator, end_of_block);

    try writer.writeBits(48, block_magic);
    try writer.writeBits(32, crc32);
    try writer.writeBit(0);
    try writer.writeBits(24, transformed.original_pointer);

    var group_used: [16]bool = @splat(false);
    for (in_use, 0..) |used, byte| {
        if (used) group_used[byte / 16] = true;
    }
    for (group_used) |used| try writer.writeBit(@intFromBool(used));
    for (group_used, 0..) |used, group| if (used)
        for (in_use[group * 16 ..][0..16]) |byte_used|
            try writer.writeBit(@intFromBool(byte_used));

    try writer.writeBits(3, 2);
    const selector_count: u16 = @intCast((symbols.items.len + group_size - 1) / group_size);
    try writer.writeBits(15, selector_count);
    for (0..selector_count) |_| try writer.writeBit(0);

    const alpha_size = sequence_len + 2;
    const code_length = fixedCodeLength(alpha_size);
    for (0..2) |_| {
        try writer.writeBits(5, code_length);
        for (0..alpha_size) |_| try writer.writeBit(0);
    }
    for (symbols.items) |symbol| try writer.writeBits(code_length, symbol);
}

fn flushZeroRun(symbols: *std.ArrayList(u16), allocator: std.mem.Allocator, run: usize) !void {
    if (run == 0) return;
    var value = run - 1;
    while (true) {
        try symbols.append(allocator, if (value & 1 == 0) 0 else 1);
        if (value < 2) break;
        value = (value - 2) / 2;
    }
}

fn fixedCodeLength(alpha_size: usize) u6 {
    var bits: u6 = 1;
    var capacity: usize = 2;
    while (capacity < alpha_size) {
        capacity *= 2;
        bits += 1;
    }
    return bits;
}

test "Bzip2 encoder round trips empty text binary and long runs" {
    const allocator = std.testing.allocator;
    const binary = [_]u8{ 0, 255, 1, 254, 2, 253 } ** 64;
    const cases = [_][]const u8{
        "",
        "bzip2 encoder round trip " ** 32,
        &binary,
        "A" ** 1000,
    };
    for (cases) |input| {
        const encoded = try encodeAlloc(allocator, input, .{ .block_size_100k = 1 });
        defer allocator.free(encoded);
        const decoded = try decoder.decodeAlloc(allocator, encoded);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }
}

test "Bzip2 encoder append and caller-owned output are transactional" {
    const allocator = std.testing.allocator;
    const input = "transactional bzip2 output " ** 16;
    const encoded = try encodeAlloc(allocator, input, .{ .block_size_100k = 1 });
    defer allocator.free(encoded);

    const output = try allocator.alloc(u8, encoded.len);
    defer allocator.free(output);
    try std.testing.expectEqual(encoded.len, try encodeInto(allocator, input, output, .{ .block_size_100k = 1 }));
    try std.testing.expectEqualSlices(u8, encoded, output);
    try std.testing.expectError(error.OutputTooSmall, encodeInto(allocator, input, output[0 .. output.len - 1], .{}));

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    const prefix_len = appended.items.len;
    try std.testing.expectEqual(encoded.len, try encodeAppend(allocator, &appended, input, .{ .block_size_100k = 1 }));
    try std.testing.expectEqualSlices(u8, "prefix:", appended.items[0..prefix_len]);
    try std.testing.expectEqualSlices(u8, encoded, appended.items[prefix_len..]);

    const before = try allocator.dupe(u8, appended.items);
    defer allocator.free(before);
    try std.testing.expectError(
        error.InvalidBzip2Header,
        encodeAppend(allocator, &appended, input, .{ .block_size_100k = 0 }),
    );
    try std.testing.expectEqualSlices(u8, before, appended.items);
}
