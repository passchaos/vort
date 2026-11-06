//! Real zero-output dictionary commands with explicit progress controls.
const std = @import("std");
const Writer = @import("../encoder/bit_writer.zig").Writer;
const command_encoding = @import("../encoder/command_encoding.zig");
const distance_encoding = @import("../encoder/distance.zig");

/// Built-in words with one custom transform: omit four trailing bytes, with
/// empty affixes. Address zero at copy length four therefore emits no bytes.
pub const dictionary = [_]u8{
    0x91, 0x00, 0x00, // Magic and empty RAW prefix.
    0, // Built-in word list.
    1, // One custom transform list.
    1, 0, 0, // One-byte affix table containing the empty stringlet.
    1, 0, 4, 0, // One omit-last-four transform with empty affixes.
    1, 0, 0, // One built-in/custom dictionary choice.
    0, // Context map disabled.
};

pub const Kind = enum {
    /// Singleton command and distance trees, no extras, inserts, or finite
    /// block counts: the same empty transform would repeat indefinitely.
    stalled,
    /// Exact direct-distance boundary: NPOSTFIX=3 and NDIRECT=120.
    stalled_distance_120,
    /// Low-distance empty transforms remain invalid even when command bits,
    /// finite counters, or output would allow the stream to terminate.
    command_bits,
    /// Two zero-bit empty commands decrement a finite count before switching
    /// to a zero-bit command that inserts the final literal.
    block_remaining,
    /// A singleton command inserts a literal before its empty transformed copy;
    /// its second iteration inserts the final literal without consuming bits.
    output,
    /// Reference-compatible counterparts use distance > 120, so the regular
    /// distance extras additionally advance the input for every empty copy.
    distant_command_bits,
    distant_block_remaining,
    distant_output,
    /// Three distant empty copies consume extras before truncated input.
    distance_bits_truncated,
};

pub fn expected(kind: Kind) []const u8 {
    return if (kind == .output or kind == .distant_output) "xx" else "x";
}

pub fn create(allocator: std.mem.Allocator, kind: Kind) ![]u8 {
    const empty = command_encoding.forLengths(0, 4, false) orelse return error.InvalidBlockPlan;
    const literal = command_encoding.forLengths(1, 2, false) orelse return error.InvalidBlockPlan;
    const inserted = command_encoding.forLengths(1, 4, false) orelse return error.InvalidBlockPlan;
    const selects_command = kind == .command_bits or kind == .distant_command_bits;
    const counts_commands = kind == .block_remaining or kind == .distant_block_remaining;
    const inserts = kind == .output or kind == .distant_output;
    const distant = kind == .distant_command_bits or kind == .distant_block_remaining or kind == .distant_output or kind == .distance_bits_truncated;
    const distance = if (distant) distance_encoding.encode(121, 0).? else null;
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(allocator);
    var writer: Writer = .{ .out = &encoded };
    try writer.writeBits(allocator, 0, 1); // WBITS = 16.
    try writer.writeBits(allocator, 1, 1); // Final compressed meta-block.
    try writer.writeBits(allocator, 0, 1); // ISLASTEMPTY = false.
    try writer.writeBits(allocator, 0, 2); // MNIBBLES = 4.
    try writer.writeBits(allocator, expected(kind).len - 1, 16);
    try writer.writeBits(allocator, 0, 1); // NBLTYPESL = 1.
    if (counts_commands) {
        try writer.writeBits(allocator, 1, 1);
        try writer.writeBits(allocator, 0, 3); // NBLTYPESI = 2.
        try single(allocator, &writer, 1, 2); // Type switch: previous + 1.
        try single(allocator, &writer, 0, 5); // Length base 1, two extra bits.
        try writer.writeBits(allocator, 1, 2); // Initial command count = 2.
    } else try writer.writeBits(allocator, 0, 1); // NBLTYPESI = 1.
    try writer.writeBits(allocator, 0, 1); // NBLTYPESD = 1.
    try writer.writeBits(allocator, if (kind == .stalled_distance_120) 3 else 0, 2);
    const ndirect: u4 = if (kind == .stalled_distance_120) 15 else if (distant) 0 else if (inserts) 2 else 1;
    try writer.writeBits(allocator, ndirect, 4);
    try writer.writeBits(allocator, 0, 2); // LSB6 literal context.
    try writer.writeBits(allocator, 0, 1); // NTREESL = 1.
    try writer.writeBits(allocator, 0, 1); // NTREESD = 1.
    try single(allocator, &writer, 'x', 8);
    if (selects_command) {
        try writer.writeBits(allocator, 1, 2);
        try writer.writeBits(allocator, 1, 2); // Two command symbols.
        try writer.writeBits(allocator, empty.symbol, 10);
        try writer.writeBits(allocator, literal.symbol, 10);
    } else {
        try single(allocator, &writer, if (inserts) inserted.symbol else empty.symbol, 10);
        if (counts_commands) try single(allocator, &writer, literal.symbol, 10);
    }
    try single(allocator, &writer, if (kind == .stalled_distance_120) 135 else if (distance) |value| value.symbol else if (inserts) 17 else 16, if (kind == .stalled_distance_120) 10 else if (ndirect == 0) 6 else 7);
    if (selects_command) {
        try writer.writeBits(allocator, 0, 1); // Empty dictionary command.
        if (distance) |value| try writer.writeBits(allocator, value.extra, value.extra_bits);
        try writer.writeBits(allocator, 1, 1); // Final literal command.
    } else if (counts_commands) {
        // The first two command symbols use no bits. Distant copies have extras.
        if (distance) |value| {
            try writer.writeBits(allocator, value.extra, value.extra_bits);
            try writer.writeBits(allocator, value.extra, value.extra_bits);
        }
        try writer.writeBits(allocator, 0, 2); // Switched count = 1.
    } else if (distance) |value| {
        for (0..if (kind == .distance_bits_truncated) @as(usize, 3) else 1) |_|
            try writer.writeBits(allocator, value.extra, value.extra_bits);
    }
    writer.alignToByte();
    return try encoded.toOwnedSlice(allocator);
}

fn single(allocator: std.mem.Allocator, writer: *Writer, symbol: u16, bits: u6) !void {
    try writer.writeBits(allocator, 1, 2);
    try writer.writeBits(allocator, 0, 2);
    try writer.writeBits(allocator, symbol, bits);
}
