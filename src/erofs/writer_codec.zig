const std = @import("std");
const core = @import("../core.zig");
const deflate = @import("../deflate.zig");
const lz4 = @import("../lz4.zig");
const zstd = @import("../zstd.zig");
const format = @import("format.zig");

pub const Error = core.Error || deflate.Error || lz4.Error || zstd.Error ||
    std.mem.Allocator.Error || error{InvalidErofs};

pub const Compression = enum {
    stored,
    lz4,
    deflate,
    zstandard,
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
        .deflate => .deflate,
        .zstandard => .zstandard,
    };
}

pub fn configuration(compression: Compression) ?[]const u8 {
    return switch (compression) {
        .deflate => &deflate_configuration,
        .zstandard => &zstandard_configuration,
        else => null,
    };
}

pub fn featureIncompat(compression: Compression) u32 {
    return switch (compression) {
        .stored => 0,
        .lz4 => 0x0000_0001,
        .deflate, .zstandard => 0x0000_0003,
    };
}

pub fn compressionField(compression: Compression) u16 {
    return switch (compression) {
        .stored => 0,
        .lz4 => 0xffff,
        .deflate => 1 << @intFromEnum(format.Compression.deflate),
        .zstandard => 1 << @intFromEnum(format.Compression.zstandard),
    };
}

pub const Encoder = struct {
    allocator: std.mem.Allocator,
    compression: Compression,
    lz4_encoder: ?lz4.BlockEncoder = null,
    owned_scratch: ?[]u8 = null,

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
            .deflate => blk: {
                const encoded = try deflate.encodeRawBestAlloc(
                    self.allocator,
                    input,
                    deflate.optionsForLevel(.default),
                );
                self.owned_scratch = encoded;
                break :blk encoded;
            },
            .zstandard => blk: {
                const encoded = try zstd.encodeFrameWithOptionsAlloc(
                    self.allocator,
                    input,
                    .{ .content_checksum = false },
                );
                self.owned_scratch = encoded;
                break :blk encoded;
            },
        };
    }
};

test "EROFS writer codecs round trip compressed extents" {
    const codec = @import("codec.zig");
    const allocator = std.testing.allocator;
    const input = "EROFS writer codec payload 0123456789\n" ** 100;
    inline for (.{ Compression.lz4, .deflate, .zstandard }) |compression| {
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
    try std.testing.expectEqual(@as(u16, 8), compressionField(.zstandard));
    try std.testing.expectEqual(@as(usize, 8), configuration(.deflate).?.len);
    try std.testing.expectEqual(@as(usize, 8), configuration(.zstandard).?.len);
}
