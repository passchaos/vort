const std = @import("std");
const t = std.testing;

// A complete raw Deflate stream: four width-nine fixed literals in a
// nonfinal block, then an empty final stored block at bit offset six.
// The stored block needs seven alignment bits. Independent zlib accepts
// every fixture; Puffin's five-bit SKIP field can represent values 0..31.
const control = [_]u8{ 0x9a, 0x30, 0x61, 0xc2, 0x04, 0x40, 0, 0, 0, 0xff, 0xff };
const expected = [_]u8{ 0, 0, 0x20, 3, 0x90, 0x90, 0x90, 0x90, 0xff, 0x81, 0, 0, 0x80, 0xff, 0x81 };
// Five width-nine literals place the stored block at residue seven, so
// it needs six alignment bits instead of seven.
const control_six = [_]u8{ 0x9a, 0x30, 0x61, 0xc2, 0x84, 0x09, 0x80, 0, 0, 0, 0xff, 0xff };
const expected_six = [_]u8{ 0, 0, 0x20, 4, 0x90, 0x90, 0x90, 0x90, 0x90, 0xff, 0x81, 0, 0, 0x80, 0xff, 0x81 };

fn vector(comptime C: type, comptime raw_control: anytype, comptime puff_control: anytype, comptime padding_index: usize, comptime padding_shift: u3) !void {
    const bits: u64 = raw_control.len * 8;
    for ([_]u8{ 0, 1, 31 }) |skipped| {
        var raw = raw_control;
        raw[padding_index] = skipped << padding_shift;
        const before = raw;
        var wire = puff_control;
        wire[wire.len - 3] |= skipped;
        const result = try C.puffDeflatePaddedAlloc(t.allocator, &raw, 0, bits, wire.len);
        defer t.allocator.free(result.bytes);
        try t.expectEqual(bits, result.consumed_bits);
        try t.expectEqualSlices(u8, &wire, result.bytes);
        const exact = try C.puffDeflateAlloc(t.allocator, &raw, 0, bits, wire.len);
        defer t.allocator.free(exact);
        try t.expectEqualSlices(u8, &wire, exact);
        const restored = try C.huffDeflateAlloc(t.allocator, &wire, 0, bits);
        defer t.allocator.free(restored);
        try t.expectEqualSlices(u8, &raw, restored);
        try t.expectEqualSlices(u8, &before, &raw);
    }
    const max_padding: u8 = if (padding_shift == 1) 127 else 63;
    for ([_]u8{ 32, 64, max_padding }) |skipped| {
        if (skipped > max_padding) continue;
        var raw = raw_control;
        raw[padding_index] = skipped << padding_shift;
        const before = raw;
        try t.expectError(error.InvalidPuffinStream, C.puffDeflatePaddedAlloc(t.allocator, &raw, 0, bits, 64));
        try t.expectError(error.InvalidPuffinStream, C.puffDeflateAlloc(t.allocator, &raw, 0, bits, 64));
        try t.expectEqualSlices(u8, &before, &raw);
    }
}

pub fn contracts(comptime C: type) !void {
    try vector(C, control, expected, 6, 1);
    try vector(C, control_six, expected_six, 7, 2);
}
