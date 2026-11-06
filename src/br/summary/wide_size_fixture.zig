//! Compact real Brotli streams whose output is described without allocating it.
const std = @import("std");
const Writer = @import("../encoder/bit_writer.zig").Writer;
const command_encoding = @import("../encoder/command_encoding.zig");
const distance_encoding = @import("../encoder/distance.zig");
const metadata_header = @import("../encoder/metadata_header.zig");
const Counter = @import("../../io/stream_count.zig").Counter;

pub const full_block_len: usize = 1 << 24;
pub const metadata = "wide";

pub const Options = struct {
    full_blocks: usize = 256,
    block_len: usize = full_block_len,
    tail_len: usize = 1024,
    pattern: []const u8 = "a",
    suffix: bool = true,
    raw_dictionary: bool = false,
};

pub const Fixture = struct {
    wire: []u8,
    core_bytes: Counter,
    core_blocks: usize,
    literal_bytes: Counter,
    decoded_bytes: Counter,
};

/// Every core block uses one explicit-distance command: insert its one- or
/// two-byte seed, then copy that seed with forward overlap. A maximum 16 MiB
/// block takes only a few header bytes and 24 copy-length bits on the wire.
/// The optional suffix tests metadata, a static dictionary reference relative
/// to the active 16-bit window, and an uncompressed block after large output.
pub fn create(allocator: std.mem.Allocator, options: Options) !Fixture {
    if (options.pattern.len == 0 or options.pattern.len > 2 or
        (options.pattern.len == 2 and options.pattern[0] == options.pattern[1]))
        return error.InvalidBlockPlan;
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(allocator);
    var writer: Writer = .{ .out = &encoded };
    try writer.writeBits(allocator, 0, 1); // RFC WBITS = 16.

    var total: Counter = 0;
    for (0..options.full_blocks) |_| {
        try repeatedBlock(allocator, &writer, options.block_len, options.pattern);
        total += options.block_len;
    }
    if (options.tail_len != 0) {
        try repeatedBlock(allocator, &writer, options.tail_len, options.pattern);
        total += options.tail_len;
    }
    const core_blocks = options.full_blocks + @intFromBool(options.tail_len != 0);
    const core_bytes = total;
    if (options.suffix) {
        try (try metadata_header.plan(metadata.len)).write(allocator, &writer);
        try writer.writeAlignedBytes(allocator, metadata);

        // RFC dictionary address 3 at word length 5 is the identity "world".
        // Its distance base is the active history window, even above 4 GiB.
        const max_history: usize = @intCast(@min(total, 65520));
        const distance = distance_encoding.encode(max_history + if (options.raw_dictionary) @as(usize, 5) else 4, 0) orelse
            return error.InvalidBlockPlan;
        const command = command_encoding.forLengths(0, 5, false) orelse
            return error.InvalidBlockPlan;
        try blockHeader(allocator, &writer, 5, false);
        try compressedHeader(allocator, &writer, "a", command.symbol, 0, distance.symbol);
        try writer.writeBits(allocator, distance.extra, distance.extra_bits);
        total += 5;

        try blockHeader(allocator, &writer, 1, true);
        writer.alignToByte();
        try writer.writeAlignedBytes(allocator, "!");
        total += 1;
    }
    try writer.writeBits(allocator, 1, 1); // ISLAST.
    try writer.writeBits(allocator, 1, 1); // ISLASTEMPTY.
    writer.alignToByte();
    return .{
        .wire = try encoded.toOwnedSlice(allocator),
        .core_bytes = core_bytes,
        .core_blocks = core_blocks,
        .literal_bytes = @as(Counter, core_blocks) * options.pattern.len,
        .decoded_bytes = total,
    };
}

fn repeatedBlock(allocator: std.mem.Allocator, writer: *Writer, len: usize, pattern: []const u8) !void {
    if (len < pattern.len + 2 or len > full_block_len) return error.InvalidBlockPlan;
    const copy_len = len - pattern.len;
    const command = command_encoding.forLengths(pattern.len, copy_len, false) orelse
        return error.InvalidBlockPlan;
    try blockHeader(allocator, writer, len, false);
    try compressedHeader(allocator, writer, pattern, command.symbol, @intCast(pattern.len), @intCast(15 + pattern.len));
    try writer.writeBits(allocator, pattern.len - command.command.insert_base, command.command.insert_extra_bits);
    try writer.writeBits(allocator, copy_len - command.command.copy_base, command.command.copy_extra_bits);
    if (pattern.len == 2) {
        // Canonical codes for the sorted two-symbol tree are 0 and 1.
        try writer.writeBits(allocator, @intFromBool(pattern[0] > pattern[1]), 1);
        try writer.writeBits(allocator, @intFromBool(pattern[1] > pattern[0]), 1);
    }
}

fn blockHeader(allocator: std.mem.Allocator, writer: *Writer, len: usize, stored: bool) !void {
    const len_minus_one = len - 1;
    const nibbles: u6 = if (len_minus_one <= 0xffff) 4 else if (len_minus_one <= 0xfffff) 5 else 6;
    try writer.writeBits(allocator, 0, 1); // ISLAST = false.
    try writer.writeBits(allocator, nibbles - 4, 2);
    try writer.writeBits(allocator, len_minus_one, nibbles * 4);
    try writer.writeBits(allocator, @intFromBool(stored), 1);
}

fn compressedHeader(allocator: std.mem.Allocator, writer: *Writer, pattern: []const u8, command: u16, ndirect: u4, distance: u16) !void {
    try writer.writeBits(allocator, 0, 1); // NBLTYPESL = 1.
    try writer.writeBits(allocator, 0, 1); // NBLTYPESI = 1.
    try writer.writeBits(allocator, 0, 1); // NBLTYPESD = 1.
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX = 0.
    try writer.writeBits(allocator, ndirect, 4);
    try writer.writeBits(allocator, 0, 2); // LSB6 literal context mode.
    try writer.writeBits(allocator, 0, 1); // NTREESL = 1.
    try writer.writeBits(allocator, 0, 1); // NTREESD = 1.
    try writer.writeBits(allocator, 1, 2); // Simple literal tree.
    try writer.writeBits(allocator, pattern.len - 1, 2);
    for (pattern) |byte| try writer.writeBits(allocator, byte, 8);
    try singleSymbol(allocator, writer, command, 10);
    try singleSymbol(allocator, writer, distance, if (ndirect == 0) 6 else 7);
}

fn singleSymbol(allocator: std.mem.Allocator, writer: *Writer, symbol: u16, bits: u6) !void {
    try writer.writeBits(allocator, 1, 2);
    try writer.writeBits(allocator, 0, 2);
    try writer.writeBits(allocator, symbol, bits);
}
