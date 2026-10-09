const std = @import("std");
const core = @import("../../core.zig");

pub const Error = core.Error;

const uncompressed_block_type: u3 = 3;
const max_block_len: usize = 32 * 1024;

/// Encodes one non-empty LZX uncompressed block. Blocks can be concatenated to
/// form one solid LZX stream. The first block carries the one-time Intel E8
/// header. Odd-sized blocks include their required alignment byte after the
/// payload, including the final block for broad decoder interoperability.
pub fn encodeUncompressedBlockAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    first_block: bool,
) ![]u8 {
    if (input.len == 0 or input.len > max_block_len) return error.InvalidBlockPlan;

    var writer = WordBitWriter{};
    errdefer writer.bytes.deinit(allocator);
    if (first_block) try writer.writeBits(allocator, 0, 1);
    try writer.writeBits(allocator, uncompressed_block_type, 3);
    try writer.writeBits(allocator, input.len >> 8, 16);
    try writer.writeBits(allocator, input.len & 0xff, 8);
    try writer.alignForUncompressed(allocator);

    // Uncompressed block headers restore the three recent offsets.
    try appendU32(allocator, &writer.bytes, 1);
    try appendU32(allocator, &writer.bytes, 1);
    try appendU32(allocator, &writer.bytes, 1);
    try writer.bytes.appendSlice(allocator, input);
    if (input.len & 1 != 0) try writer.bytes.append(allocator, 0);
    return writer.bytes.toOwnedSlice(allocator);
}

const WordBitWriter = struct {
    bytes: std.ArrayList(u8) = .empty,
    word: u16 = 0,
    bit_count: u5 = 0,

    fn writeBits(
        self: *WordBitWriter,
        allocator: std.mem.Allocator,
        value: anytype,
        count: u5,
    ) !void {
        std.debug.assert(count > 0 and count <= 16);
        var remaining: usize = count;
        while (remaining != 0) {
            remaining -= 1;
            self.word = (self.word << 1) |
                @as(u1, @truncate(@as(u64, @intCast(value)) >> @intCast(remaining)));
            self.bit_count += 1;
            if (self.bit_count == 16) try self.flushWord(allocator);
        }
    }

    /// LZX uncompressed blocks discard 1..16 bits, so an already aligned
    /// header would require a complete padding word rather than zero bits.
    fn alignForUncompressed(self: *WordBitWriter, allocator: std.mem.Allocator) !void {
        if (self.bit_count == 0) {
            try appendU16(allocator, &self.bytes, 0);
        } else {
            self.word <<= @intCast(16 - @as(usize, self.bit_count));
            try self.flushWord(allocator);
        }
    }

    fn flushWord(self: *WordBitWriter, allocator: std.mem.Allocator) !void {
        try appendU16(allocator, &self.bytes, self.word);
        self.word = 0;
        self.bit_count = 0;
    }
};

fn appendU16(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: u16) !void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, value, .little);
    try out.appendSlice(allocator, &bytes);
}

fn appendU32(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: u32) !void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .little);
    try out.appendSlice(allocator, &bytes);
}

test "LZX uncompressed encoder concatenates odd blocks" {
    const lzx = @import("../lzx.zig");
    const allocator = std.testing.allocator;
    const first = try encodeUncompressedBlockAlloc(allocator, "abc", true);
    defer allocator.free(first);
    const second = try encodeUncompressedBlockAlloc(allocator, "defgh", false);
    defer allocator.free(second);

    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(allocator);
    try stream.appendSlice(allocator, first);
    try stream.appendSlice(allocator, second);
    const decoded = try lzx.decodeAlloc(allocator, stream.items, 8, 15);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings("abcdefgh", decoded);
}

test "LZX uncompressed encoder validates block contracts" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(
        error.InvalidBlockPlan,
        encodeUncompressedBlockAlloc(allocator, "", true),
    );
}
