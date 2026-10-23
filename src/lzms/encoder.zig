const std = @import("std");
const core = @import("../core.zig");
const adaptive = @import("adaptive_huffman.zig");
const probability = @import("probability.zig");
const tables = @import("tables.zig");
const x86 = @import("x86.zig");
const streams = @import("stream_encoder.zig");
const RangeEncoder = streams.RangeEncoder;
const BackwardBitWriter = streams.BackwardBitWriter;
const appendU16AssumeCapacity = streams.appendU16AssumeCapacity;

pub const Error = core.Error || adaptive.Error || std.mem.Allocator.Error || error{
    InvalidLzms,
};

/// Encodes a complete independent LZMS buffer. This reference path emits
/// literal items only; adaptive Huffman coding still produces real compression
/// for skewed inputs, while WIM callers can retain raw chunks when it does not.
pub fn encodeAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    if (input.len > tables.max_buffer_size) return error.OutputLimitExceeded;
    if (input.len == 0) return allocator.alloc(u8, 0);

    const transformed = try allocator.dupe(u8, input);
    defer allocator.free(transformed);
    if (transformed.len > 17) {
        const x86_scratch = try allocator.create([65_536]i32);
        defer allocator.destroy(x86_scratch);
        x86.apply(transformed, x86_scratch);
    }

    var range = RangeEncoder{};
    defer range.bytes.deinit(allocator);
    var bits = BackwardBitWriter{ .allocator = allocator };
    defer bits.words.deinit(allocator);
    var literals = try adaptive.AdaptiveEncoder(256).init(256, 1024);
    var main_probabilities: [16]probability.Entry = @splat(.{});
    var main_state: u32 = 0;
    for (transformed) |literal| {
        try encodeDecisionBit(
            allocator,
            &range,
            &main_state,
            &main_probabilities,
            0,
        );
        try literals.encode(&bits, literal);
    }
    try bits.finish();
    try range.finish(allocator);

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    const bit_bytes = std.math.mul(usize, bits.words.items.len, 2) catch
        return error.IntegerOverflow;
    const total = std.math.add(usize, range.bytes.items.len, bit_bytes) catch
        return error.IntegerOverflow;
    try output.ensureTotalCapacity(allocator, total);
    output.appendSliceAssumeCapacity(range.bytes.items);
    var word_index = bits.words.items.len;
    while (word_index != 0) {
        word_index -= 1;
        appendU16AssumeCapacity(&output, bits.words.items[word_index]);
    }
    std.debug.assert(output.items.len == total and total & 1 == 0);
    return output.toOwnedSlice(allocator);
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
) Error!usize {
    const encoded = try encodeAlloc(allocator, input);
    defer allocator.free(encoded);
    try output.ensureUnusedCapacity(allocator, encoded.len);
    output.appendSliceAssumeCapacity(encoded);
    return encoded.len;
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
) Error!usize {
    const encoded = try encodeAlloc(allocator, input);
    defer allocator.free(encoded);
    if (encoded.len > output.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

fn encodeDecisionBit(
    allocator: std.mem.Allocator,
    range: *RangeEncoder,
    state: *u32,
    entries: []probability.Entry,
    bit: u1,
) !void {
    const entry = &entries[state.*];
    state.* = ((state.* << 1) | bit) & @as(u32, @intCast(entries.len - 1));
    const predicted = entry.probability();
    entry.update(bit);
    try range.encodeBit(allocator, bit, predicted);
}
