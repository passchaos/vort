//! Conservative representable-cost range for the fixed-price prefix proof.
const std = @import("std");

/// A literal-only suffix costs at most nine bits per byte. For minimum match
/// four, B[k] includes length four at seven bits, leaving enough space for the
/// maximum eighteen-bit fixed distance price. Larger inputs keep the original
/// comparison rather than introducing a new API rejection.
pub fn costsFitInputLength(comptime Count: type, count: Count) bool {
    return count <= std.math.maxInt(Count) / 9;
}
