const std = @import("std");
const core = @import("../core.zig");
const adaptive = @import("adaptive_huffman.zig");
const probability = @import("probability.zig");
const tables = @import("tables.zig");
const x86 = @import("x86.zig");

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

const RangeEncoder = struct {
    bytes: std.ArrayList(u8) = .empty,
    lower_bound: u64 = 0,
    range_size: u32 = std.math.maxInt(u32),
    cache: u16 = 0,
    cache_size: u32 = 1,
    started: bool = false,

    fn encodeBit(
        self: *RangeEncoder,
        allocator: std.mem.Allocator,
        bit: u1,
        zero_probability: u32,
    ) !void {
        if (self.range_size <= 0xffff) {
            self.range_size <<= 16;
            try self.shiftLow(allocator);
        }
        const bound = (self.range_size >> probability.bits) * zero_probability;
        if (bit == 0) {
            self.range_size = bound;
        } else {
            self.lower_bound += bound;
            self.range_size -= bound;
        }
    }

    fn shiftLow(self: *RangeEncoder, allocator: std.mem.Allocator) !void {
        const low: u32 = @truncate(self.lower_bound);
        const carry: u16 = @truncate(self.lower_bound >> 32);
        if (low < 0xffff_0000 or carry != 0) {
            var pending = self.cache_size;
            self.cache_size = 0;
            while (pending != 0) : (pending -= 1) {
                if (self.started) {
                    try appendU16(allocator, &self.bytes, self.cache +% carry);
                } else {
                    self.started = true;
                }
                self.cache = 0xffff;
            }
            self.cache = @truncate(self.lower_bound >> 16);
        }
        self.cache_size += 1;
        self.lower_bound = (self.lower_bound & 0xffff) << 16;
    }

    fn finish(self: *RangeEncoder, allocator: std.mem.Allocator) !void {
        for (0..4) |_|
            try self.shiftLow(allocator);
        if (self.bytes.items.len < 4 or self.bytes.items.len & 1 != 0)
            return error.InvalidLzms;
    }
};

const BackwardBitWriter = struct {
    allocator: std.mem.Allocator,
    words: std.ArrayList(u16) = .empty,
    bit_buffer: u64 = 0,
    bit_count: u6 = 0,

    pub fn writeBits(self: *BackwardBitWriter, value: u16, count: u4) !void {
        std.debug.assert(count != 0 and count <= 15);
        self.bit_count += count;
        self.bit_buffer = (self.bit_buffer << count) | value;
        while (self.bit_count >= 16) {
            self.bit_count -= 16;
            try self.words.append(
                self.allocator,
                @truncate(self.bit_buffer >> @intCast(self.bit_count)),
            );
        }
    }

    fn finish(self: *BackwardBitWriter) !void {
        if (self.bit_count == 0) return;
        try self.words.append(
            self.allocator,
            @truncate(self.bit_buffer << @intCast(16 - self.bit_count)),
        );
        self.bit_count = 0;
        self.bit_buffer = 0;
    }
};

fn appendU16(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: u16,
) !void {
    try output.ensureUnusedCapacity(allocator, 2);
    appendU16AssumeCapacity(output, value);
}

fn appendU16AssumeCapacity(output: *std.ArrayList(u8), value: u16) void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, value, .little);
    output.appendSliceAssumeCapacity(&bytes);
}
