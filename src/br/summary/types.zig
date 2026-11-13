//! Logical Brotli summary quantities are independent of physical buffers.
const core = @import("../../core.zig");
const Counter = core.StreamCount;

pub const StreamSummary = struct {
    window_bits: u5,
    /// True only when the stream used the non-RFC Large Window marker. This
    /// remains distinct from `window_bits`, because the extension can encode
    /// values that also exist in RFC 7932.
    large_window: bool = false,
    input_bytes: Counter,
    decoded_bytes: Counter = 0,
    meta_block_count: Counter = 0,
    empty_meta_block_count: Counter = 0,
    metadata_meta_block_count: Counter = 0,
    uncompressed_meta_block_count: Counter = 0,
    compressed_meta_block_count: Counter = 0,
    metadata_bytes: Counter = 0,
    uses_metadata: bool = false,
    uses_uncompressed_meta_blocks: bool = false,
    uses_compressed_meta_blocks: bool = false,
    uses_static_dictionary: bool = false,
    static_dictionary_copy_count: Counter = 0,
    static_dictionary_bytes: Counter = 0,
    uses_shared_dictionary: bool = false,
    shared_dictionary_copy_count: Counter = 0,
    shared_dictionary_bytes: Counter = 0,
    /// Commands decoded from compressed meta-block payloads. This includes a
    /// final command whose insert reaches the end before its copy is applied.
    command_count: Counter = 0,
    zero_insert_command_count: Counter = 0,
    single_literal_insert_command_count: Counter = 0,
    implicit_distance_command_count: Counter = 0,
    /// Applied copy commands grouped by the distance coding path. Implicit
    /// commands consume no distance symbol; short covers explicit symbols
    /// 0--15, direct covers the NDIRECT range, and regular covers the remaining
    /// postfix-coded alphabet.
    implicit_distance_copy_count: Counter = 0,
    short_distance_copy_count: Counter = 0,
    direct_distance_copy_count: Counter = 0,
    regular_distance_copy_count: Counter = 0,
    /// Copy-length command shape indexed by floor(log2(copy length)); the last
    /// bucket includes every copy length greater than or equal to 256.
    copy_length_log2_histogram: [9]Counter = @splat(0),
    /// Applied copies per RFC 7932 distance context (copy length 2, 3, 4,
    /// then 5+). Populated only on summary/diagnostic replay paths.
    distance_context_histogram: [4]Counter = @splat(0),
    lz77_copy_count: Counter = 0,
    lz77_copy_bytes: Counter = 0,
    max_lz77_distance: usize = 0,
    non_overlapping_lz77_copy_count: Counter = 0,
    non_overlapping_lz77_copy_bytes: Counter = 0,
    short_non_overlapping_lz77_copy_count: Counter = 0,
    short_non_overlapping_lz77_copy_bytes: Counter = 0,
    literal_context_mode_bytes: [4]Counter = @splat(0),
    max_literal_block_types: usize = 0,
    max_literal_context_trees: usize = 0,
    max_command_block_types: usize = 0,
    max_distance_block_types: usize = 0,
    max_distance_context_trees: usize = 0,
    max_distance_postfix_bits: u2 = 0,
    max_direct_distance_codes: u16 = 0,
    stored_only: bool = true,
};

pub const StreamSummaryErrorPhase = enum {
    stream,
    window_bits,
    meta_block_header,
    metadata_meta_block,
    uncompressed_meta_block,
    compressed_meta_block,
    padding,
    output_size,
};

pub const StreamSummaryDiagnostics = struct {
    phase: StreamSummaryErrorPhase = .stream,
    offset: Counter = 0,
    meta_block_index: Counter = 0,
};

pub const StreamProbeResult = struct {
    ok: bool,
    summary: ?StreamSummary = null,
    diagnostics: StreamSummaryDiagnostics = .{},
    error_name: []const u8 = "",
};

/// Fresh for each physical meta-block in summaries and HQ inspection.
/// Byte totals and counts which always produce bytes fit the declared 24-bit
/// output length. Dictionary transforms may produce empty words, so command,
/// distance and dictionary-reference cardinalities retain wide counters.
pub const MetaBlockStats = struct {
    max_wire_distance: usize = 0,
    static_dictionary_copy_count: Counter = 0,
    static_dictionary_bytes: usize = 0,
    shared_dictionary_copy_count: Counter = 0,
    shared_dictionary_bytes: usize = 0,
    command_count: Counter = 0,
    zero_insert_command_count: Counter = 0,
    single_literal_insert_command_count: usize = 0,
    implicit_distance_command_count: Counter = 0,
    implicit_distance_copy_count: Counter = 0,
    short_distance_copy_count: Counter = 0,
    direct_distance_copy_count: Counter = 0,
    regular_distance_copy_count: Counter = 0,
    copy_length_log2_histogram: [9]Counter = @splat(0),
    /// Applied copies per RFC 7932 distance context (copy length 2, 3, 4,
    /// then 5+). Populated only on summary/diagnostic replay paths.
    distance_context_histogram: [4]Counter = @splat(0),
    lz77_copy_count: usize = 0,
    lz77_copy_bytes: usize = 0,
    max_lz77_distance: usize = 0,
    non_overlapping_lz77_copy_count: usize = 0,
    non_overlapping_lz77_copy_bytes: usize = 0,
    short_non_overlapping_lz77_copy_count: usize = 0,
    short_non_overlapping_lz77_copy_bytes: usize = 0,
    literal_context_mode_bytes: [4]usize = @splat(0),
    max_literal_block_types: usize = 0,
    max_literal_context_trees: usize = 0,
    max_command_block_types: usize = 0,
    max_distance_block_types: usize = 0,
    max_distance_context_trees: usize = 0,
    max_distance_postfix_bits: u2 = 0,
    max_direct_distance_codes: u16 = 0,
};
