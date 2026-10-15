const std = @import("std");
const core = @import("../../core.zig");
const types = @import("../types.zig");

pub const CompressionMethod = types.CompressionMethod;

pub const Options = struct {
    /// Absolute file offset represented by the first byte passed to `step`.
    /// Use this when the caller has already skipped an SFX prefix.
    initial_offset: usize = 0,
    max_entries: usize = std.math.maxInt(usize),
    /// Retained local names plus the final archive comment.
    max_metadata_size: usize = 64 * 1024 * 1024,
    /// Encoded central-directory bytes processed before the archive ending.
    max_central_directory_size: usize = std.math.maxInt(usize),
    max_control_record_size: usize = 256 * 1024,
    max_entry_output_len: usize = std.math.maxInt(usize),
    max_total_output_len: usize = std.math.maxInt(usize),
    max_bzip2_compressed_block_len: usize = 4 * 1024 * 1024,
    max_bzip2_decoded_block_len: usize = 64 * 1024 * 1024,
    max_zstd_compressed_buffer_len: usize = 1024 * 1024,
    max_lzma_dictionary_size: usize = 64 * 1024 * 1024,
    max_lzma_compressed_buffer_len: usize = 1024 * 1024,
    max_xz_dictionary_size: usize = 64 * 1024 * 1024,
    max_xz_compressed_block_len: usize = 64 * 1024 * 1024,
    max_xz_decoded_block_len: usize = 64 * 1024 * 1024,
    max_xz_index_footer_len: usize = 16 * 1024 * 1024,
    max_xz_block_count: usize = 1024 * 1024,
    max_ppmd_memory_size: usize = 64 * 1024 * 1024,
    max_ppmd_compressed_buffer_len: usize = 1024 * 1024,
    password: ?[]const u8 = null,
    allow_trailing_data: bool = false,
};

pub const Phase = enum {
    record_signature,
    local_fixed,
    local_variable,
    entry_data,
    entry_descriptor,
    central_fixed,
    central_variable,
    zip64_end_prefix,
    zip64_end,
    zip64_locator,
    digital_signature_fixed,
    digital_signature,
    end_fixed,
    end_comment,
    done,
    failed,
};

pub const StepResult = struct {
    progress: core.Progress = .{},
    status: Status,

    pub const Status = enum {
        need_input,
        need_output,
        entry_header,
        entry_done,
        done,
    };
};

/// The name borrows reader-owned metadata and remains valid until `reset` or
/// `deinit`. Descriptor-derived values become non-null at `.entry_done`.
pub const EntryInfo = struct {
    name: []const u8,
    method: CompressionMethod,
    flags: u16,
    local_header_offset: usize,
    uses_descriptor: bool,
    zip64_local: bool,
    crc32: ?u32,
    compressed_size: ?usize,
    uncompressed_size: ?usize,
};
