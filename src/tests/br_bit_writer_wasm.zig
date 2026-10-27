//! Import this probe from a root under src/ so the writer's relative imports
//! remain in the module. Successful reserved writes use an independent bit loop.
const std = @import("std");
const Writer = @import("../br/encoder/bit_writer.zig").Writer;

const Kind = enum { general, huffman };
var general_cases: u32 = 0;
var huffman_cases: u32 = 0;
var spill_cases: u32 = 0;
var fingerprint: u32 = 0;

fn compare(kind: Kind, offset: u3, width: u6, value: u64, prefix: usize, previous: u8, exact_capacity: bool, bounded: bool) u32 {
    const guard = 4;
    var actual: [48]u8 = @splat(0xcc);
    for (actual[guard..][0..prefix], 0..) |*byte, index| byte.* = @truncate(0x35 + index * 17);
    const initial_len = prefix + @intFromBool(offset != 0);
    if (offset != 0) actual[guard + prefix] = previous;
    var expected = actual;
    var expected_len = initial_len;
    var expected_offset = offset;
    // Append a zero byte only when starting a new byte. OR one input bit at a
    // time, preserving the complete old partial byte just like the old writer.
    for (0..width) |bit| {
        if (expected_offset == 0) {
            expected[guard + expected_len] = 0;
            expected_len += 1;
        }
        const input_bit: u8 = @intCast((value >> @as(u6, @intCast(bit))) & 1);
        expected[guard + expected_len - 1] |= input_bit << expected_offset;
        expected_offset +%= 1;
    }
    var out: std.ArrayList(u8) = .{
        .items = actual[guard..][0..initial_len],
        .capacity = if (exact_capacity) expected_len else 32,
    };
    var writer = Writer{ .out = &out, .bit_index = offset, .bounded = bounded };
    // Any unexpected allocation fails. Both reserved modes have enough room
    // for the complete field, including the possible ninth-byte spill.
    var empty: [0]u8 = .{};
    var allocator = std.heap.FixedBufferAllocator.init(&empty);
    switch (kind) {
        .general => writer.writeBits(allocator.allocator(), value, width) catch return 1,
        .huffman => writer.writeHuffmanBits(allocator.allocator(), @intCast(value), @intCast(width)) catch return 2,
    }
    if (out.items.len != expected_len) return 3;
    if (writer.bit_index != expected_offset) return 4;
    // The complete backing array includes prefix guards and every byte beyond
    // logical output, even spare bytes advertised by the ArrayList capacity.
    if (!std.mem.eql(u8, &expected, &actual)) return 5;
    const expected_position: u64 = @as(u64, prefix) * 8 + @as(u64, offset) + width;
    if (writer.bitPosition() != expected_position) return 6;
    if (kind == .general) {
        general_cases += 1;
        if (@as(u7, offset) + width > 64) spill_cases += 1;
    } else huffman_cases += 1;
    for (actual) |byte| fingerprint = (fingerprint ^ byte) *% 16777619;
    return 0;
}

export fn brBitWriterWasmSmoke() callconv(.c) u32 {
    general_cases = 0;
    huffman_cases = 0;
    spill_cases = 0;
    fingerprint = 2166136261;
    for ([_]Kind{ .general, .huffman }) |kind| {
        for (0..8) |offset| {
            const first: usize = if (kind == .general) 0 else 1;
            const stop: usize = if (kind == .general) 64 else 16;
            for (first..stop) |width| {
                const mask: u64 = if (width == 0) 0 else (@as(u64, 1) << @as(u6, @intCast(width))) - 1;
                const high: u64 = if (width == 0) 0 else @as(u64, 1) << @as(u6, @intCast(width - 1));
                const values = [_]u64{ 0, 1, std.math.maxInt(u64), 0x8000_0000_0000_0000, 0x1357_9bdf_2468_ace0, high };
                for (values) |raw| {
                    const value = if (kind == .huffman) raw & mask else raw;
                    for ([_]usize{ 0, 3 }) |prefix| {
                        for ([_]u8{ 0, 0xa5 }) |previous| {
                            for ([_]bool{ true, false }) |exact_capacity| {
                                for ([_]bool{ true, false }) |bounded| {
                                    const status = compare(kind, @intCast(offset), @intCast(width), value, prefix, previous, exact_capacity, bounded);
                                    if (status != 0) return status;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    return 0;
}

export fn brBitWriterGeneralCases() callconv(.c) u32 {
    return general_cases;
}
export fn brBitWriterHuffmanCases() callconv(.c) u32 {
    return huffman_cases;
}
export fn brBitWriterNineByteSpills() callconv(.c) u32 {
    return spill_cases;
}
export fn brBitWriterFingerprint() callconv(.c) u32 {
    return fingerprint;
}

test "Brotli bit writer wasm probe has independent bit and guard coverage" {
    try std.testing.expectEqual(@as(u32, 0), brBitWriterWasmSmoke());
    try std.testing.expectEqual(@as(u32, 49152), general_cases);
    try std.testing.expectEqual(@as(u32, 11520), huffman_cases);
    try std.testing.expectEqual(@as(u32, 2016), spill_cases);
    std.debug.print("writer probe fingerprint={x}\n", .{fingerprint});
}
