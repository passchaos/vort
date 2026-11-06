//! The decoder policy used by libbrotli for empty transformed dictionary words.
const core = @import("../../core.zig");

/// Direct distance codes cover at most 120. Rejecting empty words at those
/// absolute distances prevents singleton command/distance trees from repeating
/// without consuming a bit or producing a byte. Larger explicit distances
/// consume extra bits and may legitimately produce an empty transformed word.
pub fn validate(absolute_distance: usize, output_len: usize) core.Error!void {
    if (output_len == 0 and absolute_distance <= 120) return error.CorruptFrame;
}
