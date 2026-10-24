const std = @import("std");

/// Complete codec defaults remain available to standalone extent callers.
/// Archive readers replace them with the values declared by the filesystem.
pub const DecodeOptions = struct {
    lz4_max_distance: usize = 65535,
    lzma_dictionary_size: u32 = 8 * 1024 * 1024,
    deflate_max_distance: usize = 32768,
    zstandard_max_window_size: u64 = std.math.maxInt(u64),
};
