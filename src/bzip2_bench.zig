//! Internal module boundary for the Bzip2 measurement tool; not a public API.
pub const encoder = @import("bzip2/encoder.zig");
pub const reference = @import("bzip2/test_support/bwt_full_doubling.zig");
