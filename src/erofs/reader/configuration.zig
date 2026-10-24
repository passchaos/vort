const std = @import("std");
const format = @import("../format.zig");
const input_module = @import("input.zig");
const options_module = @import("../codec/options.zig");

pub const Error = format.Error || input_module.Error || error{UnsupportedErofsCompression};
pub const Configuration = struct {
    available_algorithms: u16 = 0x0f,
    options: options_module.DecodeOptions = .{},
    lz4_max_pcluster_blocks: usize = 256,

    pub fn require(self: Configuration, algorithm: format.Compression, encoded_size: usize, block_size: usize) Error!void {
        const bit = @as(u16, 1) << @as(u4, @intCast(@intFromEnum(algorithm)));
        if (self.available_algorithms & bit == 0) return error.InvalidErofs;
        if (algorithm == .lz4) {
            const maximum = std.math.mul(usize, self.lz4_max_pcluster_blocks, block_size) catch return error.IntegerOverflow;
            if (encoded_size > maximum) return error.InvalidErofs;
        }
    }
};

/// Configuration records are primary metadata, ordered by algorithm ID. Only
/// fixed known fields are retained; extension payloads are read in bounded
/// chunks so their ranges and Source errors cannot be skipped.
pub fn read(input: input_module.Input, header: format.Superblock) Error!Configuration {
    var result = Configuration{};
    if (header.feature_incompat & format.feature_incompat_compression_config == 0) {
        const distance = header.available_compression_algorithms;
        result.available_algorithms = if (distance != 0 or header.feature_incompat & 1 != 0) 1 else 0;
        result.options.lz4_max_distance = if (distance == 0) 65535 else distance;
        result.lz4_max_pcluster_blocks = 1;
        return result;
    }
    const mask = header.available_compression_algorithms;
    if (mask & ~@as(u16, 0x0f) != 0) return error.UnsupportedErofsCompression;
    result.available_algorithms = mask;
    var position = std.math.add(usize, format.super_offset, header.super_size) catch return error.IntegerOverflow;
    const image_len = try header.imageSize64();
    for (0..4) |index| {
        if (mask & (@as(u16, 1) << @as(u4, @intCast(index))) == 0) continue;
        position = (std.math.add(usize, position, 3) catch return error.IntegerOverflow) & ~@as(usize, 3);
        try checkEnd(position, 2, image_len);
        const length: usize = try input.integer(u16, position);
        const minimum: usize = if (index <= 1) 14 else 6;
        if (length < minimum) return error.InvalidErofs;
        position = std.math.add(usize, position, 2) catch return error.IntegerOverflow;
        try checkEnd(position, length, image_len);
        var known: [14]u8 = @splat(0);
        try input.read(position, known[0..minimum]);
        switch (index) {
            0 => {
                const distance = format.readU16(&known, 0);
                result.options.lz4_max_distance = if (distance == 0) 65535 else distance;
                const blocks = @max(@as(usize, 1), format.readU16(&known, 2));
                if (blocks > (1024 * 1024) / header.block_size) return error.InvalidErofs;
                result.lz4_max_pcluster_blocks = blocks;
            },
            1 => {
                const dictionary = format.readU32(&known, 0);
                if (dictionary < 4096 or dictionary > 8 * 1024 * 1024) return error.InvalidErofs;
                if (format.readU16(&known, 4) != 0) return error.UnsupportedErofsCompression;
                result.options.lzma_dictionary_size = dictionary;
            },
            2 => {
                if (known[0] < 8 or known[0] > 15) return error.InvalidErofs;
                result.options.deflate_max_distance = @as(usize, 1) << @as(u5, @intCast(known[0]));
            },
            3 => {
                if (known[0] != 0) return error.UnsupportedErofsCompression;
                if (known[1] > 10) return error.InvalidErofs;
                result.options.zstandard_max_window_size = @as(u64, 1) << @as(u6, @intCast(known[1] + 10));
            },
            else => unreachable,
        }
        var extension: [256]u8 = undefined;
        var consumed = minimum;
        while (consumed < length) {
            const size = @min(extension.len, length - consumed);
            try input.read(position + consumed, extension[0..size]);
            consumed += size;
        }
        position = std.math.add(usize, position, length) catch return error.IntegerOverflow;
    }
    return result;
}

fn checkEnd(start: usize, size: usize, len: u64) Error!void {
    const end = std.math.add(usize, start, size) catch return error.IntegerOverflow;
    if (end > len) return error.TruncatedFrame;
}
