const window = @import("window.zig");

pub const Mode = enum { stored, fixed, dynamic, dynamic_literal, best, adaptive, png_ultrafast };

/// Framing settings belong to zlib. Compression remains the same generic
/// DEFLATE policy used by raw and gzip APIs. Dictionaries are borrowed.
pub fn Options(comptime C: type) type {
    return struct {
        window_bits: u8 = window.default_bits,
        mode: Mode = .best,
        compression: C.CompressionOptions = .{},
        dictionary: ?[]const u8 = null,
        /// Null emits one planned block; stored may still need RFC LEN splits.
        block_len: ?usize = null,
        /// Used by adaptive mode; its one-shot fallback obeys the same window.
        split_options: C.AdaptiveSplitOptions = .{},

        pub fn resolved(self: @This()) (C.Error || window.Error)!@This() {
            const limit = try window.windowLen(self.window_bits);
            if (self.block_len) |length| {
                if (length == 0 or self.mode == .adaptive or self.mode == .png_ultrafast)
                    return error.InvalidBlockPlan;
            }
            if (self.mode == .adaptive and
                (self.split_options.min_block_len == 0 or self.split_options.max_block_len == 0 or
                    self.split_options.min_block_len > self.split_options.max_block_len))
                return error.InvalidBlockPlan;
            var value = self;
            value.compression.lz77_options.window_len = @min(value.compression.lz77_options.window_len, limit);
            return value;
        }
    };
}
