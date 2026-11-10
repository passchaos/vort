//! Frozen reference bytes and bounded direct writers, without quality search.
const std = @import("std");
const h = @import("helpers.zig");
pub const external = [_]u8{
    0xa1, 0xc0, 0x00, 0x00, 0x20, 0xe0, 0x38, 0xbc,
    0xde, 0xdd, 0x77, 0x5f, 0x44, 0xa4, 0x1a, 0x24,
    0x9f, 0x6a, 0x3c, 0xa7, 0x83, 0xd6, 0xc7, 0x00,
}; // Existing Node quality-five reference fixture.
pub const external_plain = "hello brotli hello brotli";
pub const raw = [_]u8{ 0xa1, 0xa8, 0x00, 0xc0, 0x2f, 0x01, 0x10, 0xc4, 0x44, 0x09, 0x00 };
pub const raw_plain = "Kot lomom kolol slona!";
pub const large = [_]u8{
    0x11, 0x59, 0xfc, 0x34, 0x00, 0x10, 0x73, 0x1b, 0xf5, 0x95, 0x74, 0x21,
    0xee, 0xf1, 0x6d, 0x51, 0xb1, 0x08, 0x83, 0x81, 0xac, 0x08, 0x0e, 0x39,
    0x70, 0xf8, 0xbe, 0x25, 0x21, 0x86, 0xc0, 0x81, 0x87, 0x6c, 0x2f, 0xe5,
    0x2a, 0x19, 0xba, 0x2d, 0x35, 0xd8, 0x2f, 0xd2, 0x2f, 0x2e, 0x83, 0x35,
    0x27, 0x32, 0xe0, 0x17, 0x13, 0x00, 0x7c, 0x8f, 0x75, 0xc0, 0xa2, 0x56,
    0x6a, 0xeb, 0x63, 0x52, 0x10,
}; // libbrotli 1.1.0, quality=5, generic, lgwin=25.
pub const large_plain = "large window brotli compatibility payload 0123456789\n" ** 64;
pub const repeated = "r" ** 257;
pub const stored_plain = "Brotli quota stored payload";

// Existing serialized fixture format: RAW "raw", two five-byte custom words,
// one identity transform and one custom dictionary, without a context map.
pub const serialized = [_]u8{
    0x91, 0x00, 3,   'r', 'a', 'w', 1,
    0,    1,    0,   0,   0,   0,   0,
    0,    0,    0,   0,   0,   0,   0,
    0,    0,    0,   0,   0,   0,   0,
    0,    0,    0,   0,   0,   0,   0,
    'h',  'e',  'l', 'l', 'o', 'w', 'o',
    'r',  'l',  'd', 1,   1,   0,   0,
    1,    0,    0,   0,   1,   0,   0,
    0,
};

pub fn serializedWire(comptime B: type) ![]u8 {
    const commands = [_]B.IncrementalTestSupport.HqCommand{.{
        .insert_start = 0,
        .insert_len = 0,
        .copy_len = 5,
        .has_copy = true,
        .source = .static,
        .dictionary_output_len = 5,
        .dictionary_address = 0,
    }};
    const result = try B.IncrementalTestSupport.encodeHqCommandPlan(h.a, "hello", &commands, .{ .compound_dictionary_size = 3 });
    return result.bytes;
}

pub fn multi(comptime B: type) ![]u8 {
    // Exercise compressed -> compressed -> metadata -> dictionary -> stored.
    const fixture = try @import("../../summary/wide_size_fixture.zig").create(h.a, .{
        .full_blocks = 2,
        .block_len = 257,
        .tail_len = 0,
    });
    _ = B;
    return fixture.wire;
}
pub const multi_plain = ("a" ** 514) ++ "world!";
