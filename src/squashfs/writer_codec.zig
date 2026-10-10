const std = @import("std");
const core = @import("../core.zig");
const deflate = @import("../deflate.zig");
const lz4 = @import("../lz4.zig");
const lzma = @import("../lzma.zig");
const lzo1x = @import("../lzo1x.zig");
const xz = @import("../xz.zig");
const zstd = @import("../zstd.zig");
const format = @import("format.zig");

pub const Error = core.Error || deflate.Error || lz4.Error || lzma.Error ||
    lzo1x.Error || xz.Error || zstd.Error || std.mem.Allocator.Error;

pub const Mode = enum {
    stored,
    gzip,
    lzma,
    lzo,
    xz,
    lz4,
    zstandard,
};

const lz4_legacy_options = [_]u8{
    1, 0, 0, 0, // LZ4 legacy block stream version.
    0, 0, 0, 0, // Default non-HC encoder flags.
};

pub fn compression(mode: Mode) format.Compression {
    return switch (mode) {
        .stored, .gzip => .gzip,
        .lzma => .lzma,
        .lzo => .lzo,
        .xz => .xz,
        .lz4 => .lz4,
        .zstandard => .zstandard,
    };
}

pub fn compressorOptions(mode: Mode) ?[]const u8 {
    return switch (mode) {
        .lz4 => &lz4_legacy_options,
        else => null,
    };
}

pub fn compressAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    mode: Mode,
    block_size: usize,
) Error!?[]u8 {
    return switch (mode) {
        .stored => null,
        .gzip => try deflate.encodeZlibBestAlloc(
            allocator,
            input,
            deflate.optionsForLevel(.default),
        ),
        .lzma => try lzma.encodeAlloc(allocator, input, .{
            .dictionary_size = @intCast(@min(block_size, std.math.maxInt(u16))),
            .size_mode = .known,
        }),
        .lzo => try lzo1x.encodeAlloc(allocator, input, .{}),
        .xz => try xz.encodeAlloc(allocator, input, .{
            .check = .crc32,
            .block_size = @max(input.len, 1),
        }),
        .lz4 => try lz4.encodeBlockAlloc(allocator, input),
        .zstandard => try zstd.encodeFrameWithOptionsAlloc(allocator, input, .{}),
    };
}

test "SquashFS writer codecs round trip every compressed mode" {
    const decoder = @import("codec.zig");
    const allocator = std.testing.allocator;
    const input = "SquashFS codec adapter payload 0123456789\n" ** 300;
    inline for (.{ Mode.gzip, .lzma, .lzo, .xz, .lz4, .zstandard }) |mode| {
        const encoded = (try compressAlloc(allocator, input, mode, 128 * 1024)).?;
        defer allocator.free(encoded);
        const decoded = try decoder.decodeAllocExact(
            allocator,
            compression(mode),
            encoded,
            input.len,
        );
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }
    try std.testing.expect((try compressAlloc(allocator, input, .stored, 128 * 1024)) == null);
    try std.testing.expectEqualSlices(u8, &lz4_legacy_options, compressorOptions(.lz4).?);
    try std.testing.expect(compressorOptions(.xz) == null);
}
