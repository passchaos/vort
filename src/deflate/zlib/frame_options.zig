const window = @import("window.zig");

pub const Mode = enum { stored, fixed, dynamic, dynamic_literal, best, adaptive, png_ultrafast };

/// Framing settings belong to zlib. Compression remains the same generic
/// DEFLATE policy used by raw and gzip APIs. Dictionaries are borrowed.
pub fn Options(comptime C: type) type {
    return struct {
        /// One ledger for the full frame, all raw candidates and output.
        /// Nested compression settings may supply the same policy; conflicting
        /// non-null caps or profile pointers are rejected before publication.
        max_total_working_memory: ?usize = null,
        memory_profile: ?*C.EncodeMemoryProfile = null,
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
            if (self.max_total_working_memory != null and self.compression.max_total_working_memory != null and
                self.max_total_working_memory != self.compression.max_total_working_memory) return error.InvalidBlockPlan;
            if (self.memory_profile != null and self.compression.memory_profile != null and
                self.memory_profile != self.compression.memory_profile) return error.InvalidBlockPlan;
            value.max_total_working_memory = self.max_total_working_memory orelse self.compression.max_total_working_memory;
            value.memory_profile = self.memory_profile orelse self.compression.memory_profile;
            value.compression.lz77_options.window_len = @min(value.compression.lz77_options.window_len, limit);
            return value;
        }
    };
}
