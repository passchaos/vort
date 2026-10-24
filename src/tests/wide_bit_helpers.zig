//! Independent LSB-first oracle, byte geometry model, and immutable fixtures.
//! Captured only from git archive 3e59413a, never pending production.
const std = @import("std");
pub const bitstream = @import("../bitstream.zig");
pub const fast = @import("../br/fast_bit_reader.zig");
pub const count = @import("../io/bit_count.zig");
pub const Count = count.BitCount;
pub const TrackingAllocator = @import("br_total_memory_helpers.zig").TrackingAllocator;
pub const plain = "wide-bit abcdefghabcdefghXabcdefgh | little stored payload\n" ** 2;
pub const bytes = [_]u8{ 0xad, 0x72, 0xc1, 0x1e, 0x5a, 0xe6, 0xf3, 0x08, 0x99, 0x54, 0x27, 0xbb, 0x00, 0xfe, 0x83, 0x61 };
pub const Api = enum { stored, stored_chunks, stored_large, planned_balanced, planned_chunks };
pub const Wire = struct { api: Api, hex: []const u8 };
pub const frozen_wires = [_]Wire{
    .{ .api = .stored, .hex = "500710776964652d6269742061626364656667686162636465666768586162636465666768207c206c6974746c652073746f726564207061796c6f61640a776964652d6269742061626364656667686162636465666768586162636465666768207c206c6974746c652073746f726564207061796c6f61640a03" },
    .{ .api = .stored_chunks, .hex = "210b01776964652d6d657461800008776964652d6269742061626364656667682003086162636465666768586162636465666768207c206c6974746c652073746f726564207061796c6f61640a776964652d6269742061626364656667686162636465666768586162636465666768207c206c6974746c652073746f726564207061796c6f61640a03" },
    .{ .api = .stored_large, .hex = "119e8500776964652d6d657461a80308776964652d6269742061626364656667686162636465666768586162636465666768207c206c6974746c652073746f726564207061796c6f61640a776964652d6269742061626364656667686162636465666768586162636465666768207c206c6974746c652073746f726564207061796c6f61640a03" },
    .{ .api = .planned_balanced, .hex = "a20e003c00baad5bd242b175ebf5570f878b1e44301d71e8aabc604a7d9525570d506d2c7d4c4abff0611a618213be85b1e89913a71f" },
    .{ .api = .planned_chunks, .hex = "000110776964652d6269742061626364656667682003001e0037d75fd26a7c15341c061e5d114c431cb92a2f9812dd7e61c12731d0ca0ac7b7619a9f7f" },
};
pub const Cursor = struct { width: u6, value: u32, position: usize };
pub const frozen_cursor = [_]Cursor{
    .{ .width = 3, .value = 5, .position = 3 },
    .{ .width = 5, .value = 21, .position = 8 },
    .{ .width = 9, .value = 370, .position = 17 },
    .{ .width = 1, .value = 0, .position = 18 },
    .{ .width = 17, .value = 34736, .position = 35 },
    .{ .width = 24, .value = 1998027, .position = 59 },
    .{ .width = 7, .value = 33, .position = 66 },
    .{ .width = 2, .value = 2, .position = 68 },
};
pub const Bound = struct { input: u64, standard: u64, large_metadata: u64 };
pub const frozen_bounds = [_]Bound{
    .{ .input = 0, .standard = 1, .large_metadata = 14 },
    .{ .input = 1, .standard = 5, .large_metadata = 18 },
    .{ .input = 65535, .standard = 65539, .large_metadata = 65552 },
    .{ .input = 65536, .standard = 65540, .large_metadata = 65553 },
    .{ .input = 65537, .standard = 65542, .large_metadata = 65554 },
    .{ .input = 16777216, .standard = 16777221, .large_metadata = 16777234 },
    .{ .input = 536870911, .standard = 536871040, .large_metadata = 536871053 },
    .{ .input = 536870912, .standard = 536871041, .large_metadata = 536871054 },
    .{ .input = 536870913, .standard = 536871045, .large_metadata = 536871058 },
    .{ .input = 4294967295, .standard = 4294968320, .large_metadata = 4294968333 },
};
pub const LayoutField = struct { name: []const u8, offset: usize };
pub const Layout = struct { size: usize, alignment: usize, fields: []const LayoutField };
pub const scalar_layout: Layout = .{ .size = 40, .alignment = 8, .fields = &.{
    .{ .name = "input", .offset = 0 },
    .{ .name = "bit_len", .offset = 16 },
    .{ .name = "byte_index", .offset = 24 },
    .{ .name = "bit_index", .offset = 32 },
} };
pub const buffered_layout: Layout = .{ .size = 48, .alignment = 8, .fields = &.{
    .{ .name = "input", .offset = 0 },
    .{ .name = "byte_index", .offset = 16 },
    .{ .name = "bit_buffer", .offset = 24 },
    .{ .name = "bit_count", .offset = 32 },
    .{ .name = "consumed_bits", .offset = 40 },
} };
pub const chunked_layout: Layout = .{ .size = 96, .alignment = 8, .fields = &.{
    .{ .name = "chunks", .offset = 0 },
    .{ .name = "byte_index", .offset = 16 },
    .{ .name = "bit_index", .offset = 88 },
    .{ .name = "total_len", .offset = 24 },
    .{ .name = "chunk_index", .offset = 32 },
    .{ .name = "chunk_start", .offset = 40 },
    .{ .name = "staged_byte_index", .offset = 48 },
    .{ .name = "bit_buffer", .offset = 56 },
    .{ .name = "bit_count", .offset = 64 },
    .{ .name = "staged_chunk_index", .offset = 72 },
    .{ .name = "staged_chunk_start", .offset = 80 },
} };
pub const span_layout: Layout = .{ .size = 88, .alignment = 8, .fields = &.{
    .{ .name = "chunks", .offset = 0 },
    .{ .name = "byte_index", .offset = 16 },
    .{ .name = "bit_index", .offset = 80 },
    .{ .name = "total_len", .offset = 24 },
    .{ .name = "source_absolute", .offset = 32 },
    .{ .name = "source_chunk_index", .offset = 40 },
    .{ .name = "source_chunk_start", .offset = 48 },
    .{ .name = "source_local", .offset = 56 },
    .{ .name = "bit_buffer", .offset = 64 },
    .{ .name = "bit_count", .offset = 72 },
} };
pub const fast_layout: Layout = .{ .size = 48, .alignment = 8, .fields = &.{
    .{ .name = "input", .offset = 0 },
    .{ .name = "bit_len", .offset = 16 },
    .{ .name = "next_byte", .offset = 24 },
    .{ .name = "bit_buffer", .offset = 32 },
    .{ .name = "bit_count", .offset = 40 },
} };
pub fn frozenAlloc(a: std.mem.Allocator, sample: Wire) ![]u8 {
    const output = try a.alloc(u8, sample.hex.len / 2);
    errdefer a.free(output);
    _ = try std.fmt.hexToBytes(output, sample.hex);
    return output;
}
/// One bit at a time, independent of little-endian word windows or reservoirs.
/// Partial logical tails ignore the physically present high padding bits.
pub fn oraclePadded(input: []const u8, logical_bits: usize, position: usize, width: u6) u64 {
    var value: u64 = 0;
    for (0..width) |bit| {
        const absolute = position + bit;
        if (absolute < logical_bits and absolute / 8 < input.len) {
            const one: u64 = (input[absolute / 8] >> @as(u3, @intCast(absolute % 8))) & 1;
            value |= one << @as(u6, @intCast(bit));
        }
    }
    return value;
}
pub fn chunksFor(comptime layout: enum { bytes, uneven }, input: []const u8, storage: *[33][]const u8) []const []const u8 {
    if (layout == .bytes) {
        for (input, 0..) |_, i| {
            storage[2 * i] = input[i..][0..1];
            storage[2 * i + 1] = "";
        }
        storage[2 * input.len] = "";
        return storage[0 .. 2 * input.len + 1];
    }
    storage[0..7].* = .{ "", input[0..1], "", input[1..5], input[5..9], "", input[9..] };
    return storage[0..7];
}
pub fn untouched(input: []const u8) !void {
    for (input) |b| try std.testing.expectEqual(@as(u8, 0xa5), b);
}
pub fn expectPosition(reader: anytype, position: usize) !void {
    try std.testing.expectEqual(@as(Count, position), reader.bitPosition());
    try std.testing.expectEqual(position / 8 + @intFromBool(position % 8 != 0), reader.byteOffset());
}
pub fn expectNativeLayout(comptime T: type, comptime layout: Layout) !void {
    if (@bitSizeOf(usize) == 64) {
        try std.testing.expectEqual(layout.size, @sizeOf(T));
        try std.testing.expectEqual(layout.alignment, @alignOf(T));
        inline for (layout.fields) |field| try std.testing.expectEqual(field.offset, @offsetOf(T, field.name));
    }
}
/// RFC 7932 stored geometry expressed as byte costs. Only the small prefix
/// needs bits; each nonempty block aligns before its payload. u128 arithmetic
/// keeps this independent of the production whole-stream BitCount helper.
pub fn storedBound(input_len: u64, window: u5, large: bool, metadata_len: usize, block_limit: usize) u128 {
    var prefix: u128 = if (large) 14 else if (window == 16) 1 else if (window >= 18) 4 else 7;
    var output: u128 = 0;
    if (metadata_len != 0) {
        prefix += 6 + (if (metadata_len <= 256) @as(u128, 8) else 16);
        output = (prefix + 7) / 8 + metadata_len;
        prefix = 0;
    }
    const full = input_len / block_limit;
    const tail = input_len % block_limit;
    if (full != 0) {
        const nibbles: u128 = if (block_limit <= 65536) 4 else if (block_limit <= 1048576) 5 else 6;
        output += (prefix + 4 + nibbles * 4 + 7) / 8 + block_limit;
        if (full > 1) output += @as(u128, full - 1) * ((4 + nibbles * 4 + 7) / 8 + block_limit);
        prefix = 0;
    }
    if (tail != 0) {
        const nibbles: u128 = if (tail <= 65536) 4 else if (tail <= 1048576) 5 else 6;
        output += (prefix + 4 + nibbles * 4 + 7) / 8 + tail;
        prefix = 0;
    }
    return output + (prefix + 2 + 7) / 8;
}
