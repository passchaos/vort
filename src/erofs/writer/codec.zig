const std = @import("std");
const core = @import("../../core.zig");
const deflate = @import("../../deflate.zig");
const lz4 = @import("../../lz4.zig");
const lzma = @import("../../lzma.zig");
const zstd = @import("../../zstd.zig");
const format = @import("../format.zig");

pub const Error = core.Error || deflate.Error || lz4.Error || lzma.Error || zstd.Error ||
    std.mem.Allocator.Error || error{InvalidErofs};

pub const Compression = enum {
    stored,
    lz4,
    deflate,
    zstandard,
    lzma,
};

const lzma_configuration = [_]u8{
    14, 0, // Payload length.
    0, 128, 0, 0, // 32 KiB dictionary.
    0, 0, // Standard MicroLZMA format.
    0, 0, 0, 0, 0, 0, 0, 0, // Reserved.
};

const deflate_configuration = [_]u8{
    6, 0, // Payload length.
    15, // 32 KiB DEFLATE window.
    0,
    0,
    0,
    0,
    0,
};

const zstandard_configuration = [_]u8{
    6, 0, // Payload length.
    0, // Standard Zstandard frame format.
    5, // 32 KiB maximum window: windowLog 15 minus 10.
    0,
    0,
    0,
    0,
};

pub fn algorithm(compression: Compression) ?format.Compression {
    return switch (compression) {
        .stored => null,
        .lz4 => .lz4,
        .lzma => .lzma,
        .deflate => .deflate,
        .zstandard => .zstandard,
    };
}

pub fn configuration(compression: Compression) ?[]const u8 {
    return switch (compression) {
        .lzma => &lzma_configuration,
        .deflate => &deflate_configuration,
        .zstandard => &zstandard_configuration,
        else => null,
    };
}

pub fn featureIncompat(compression: Compression) u32 {
    return switch (compression) {
        .stored => 0,
        .lz4 => 0x0000_0001,
        .lzma, .deflate, .zstandard => 0x0000_0003,
    };
}

pub fn compressionField(compression: Compression) u16 {
    return switch (compression) {
        .stored => 0,
        .lz4 => 0xffff,
        .lzma => 1 << @intFromEnum(format.Compression.lzma),
        .deflate => 1 << @intFromEnum(format.Compression.deflate),
        .zstandard => 1 << @intFromEnum(format.Compression.zstandard),
    };
}

pub fn configurationSizeForExtent(compression: Compression, extent_size: usize) usize {
    if (compression == .lz4 and extent_size > 4096) return 16;
    return if (configuration(compression)) |bytes| bytes.len else 0;
}

pub fn writeConfigurationForExtent(output: []u8, compression: Compression, extent_size: usize) Error!void {
    if (output.len != configurationSizeForExtent(compression, extent_size))
        return error.InvalidErofs;
    if (compression == .lz4 and extent_size > 4096) {
        const blocks = extent_size / 4096;
        if (blocks > std.math.maxInt(u16)) return error.InvalidErofs;
        @memset(output, 0);
        std.mem.writeInt(u16, output[0..2], 14, .little);
        std.mem.writeInt(u16, output[2..4], std.math.maxInt(u16), .little);
        std.mem.writeInt(u16, output[4..6], @intCast(blocks), .little);
    } else if (configuration(compression)) |bytes| {
        @memcpy(output, bytes);
    }
}

pub fn featureIncompatForExtent(compression: Compression, extent_size: usize) u32 {
    return featureIncompat(compression) |
        (if (compression == .lz4 and extent_size > 4096) @as(u32, 2) else 0);
}

pub fn compressionFieldForExtent(compression: Compression, extent_size: usize) u16 {
    if (compression == .lz4 and extent_size > 4096) return 1;
    return compressionField(compression);
}

pub const Encoder = struct {
    allocator: std.mem.Allocator,
    compression: Compression,
    lz4_encoder: ?lz4.BlockEncoder = null,
    owned_scratch: ?[]u8 = null,
    zstandard_window_log: ?u6 = null,

    pub fn init(allocator: std.mem.Allocator, compression: Compression) Error!Encoder {
        if (compression == .stored) return error.InvalidErofs;
        return .{
            .allocator = allocator,
            .compression = compression,
            .lz4_encoder = if (compression == .lz4)
                try lz4.BlockEncoder.init(allocator)
            else
                null,
        };
    }

    pub fn deinit(self: *Encoder) void {
        if (self.owned_scratch) |bytes| self.allocator.free(bytes);
        if (self.lz4_encoder) |*encoder| encoder.deinit();
        self.* = undefined;
    }

    pub fn encodeScratch(self: *Encoder, input: []const u8) Error![]const u8 {
        if (self.owned_scratch) |bytes| {
            self.allocator.free(bytes);
            self.owned_scratch = null;
        }
        return switch (self.compression) {
            .stored => error.InvalidErofs,
            .lz4 => try self.lz4_encoder.?.encodeScratch(input),
            .lzma => blk: {
                const encoded = try lzma.encodeMicroAlloc(self.allocator, input, .{});
                self.owned_scratch = encoded;
                break :blk encoded;
            },
            .deflate => blk: {
                const options = deflate.optionsForLevel(.default);
                const encoded = if (input.len > 4096 and deflate.usesStoredFastPath(input, options))
                    try deflate.encodeRawDynamicWithOptionsAlloc(self.allocator, input, options)
                else
                    try deflate.encodeRawBestAlloc(self.allocator, input, options);
                self.owned_scratch = encoded;
                break :blk encoded;
            },
            .zstandard => blk: {
                const encoded = try zstd.encodeFrameWithOptionsAlloc(
                    self.allocator,
                    input,
                    .{ .content_checksum = false, .window_log = self.zstandard_window_log },
                );
                self.owned_scratch = encoded;
                break :blk encoded;
            },
        };
    }
};

test "EROFS writer codecs round trip compressed extents" {
    const codec = @import("../codec.zig");
    const allocator = std.testing.allocator;
    const input = "EROFS writer codec payload 0123456789\n" ** 100;
    inline for (.{ Compression.lz4, .lzma, .deflate, .zstandard }) |compression| {
        var encoder = try Encoder.init(allocator, compression);
        defer encoder.deinit();
        const encoded = try encoder.encodeScratch(input);
        const decoded = try codec.decodeExtentAlloc(
            allocator,
            algorithm(compression).?,
            encoded,
            input.len,
            false,
        );
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }
    try std.testing.expectEqual(@as(u16, 4), compressionField(.deflate));
    try std.testing.expectEqual(@as(u16, 2), compressionField(.lzma));
    try std.testing.expectEqual(@as(usize, 16), configuration(.lzma).?.len);
    try std.testing.expectEqual(@as(u16, 8), compressionField(.zstandard));
    try std.testing.expectEqual(@as(usize, 8), configuration(.deflate).?.len);
    try std.testing.expectEqual(@as(usize, 8), configuration(.zstandard).?.len);
}
