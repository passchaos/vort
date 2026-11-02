const candidates = @import("ordinal_index_tests/candidates.zig");
const boundaries = @import("ordinal_index_tests/boundaries.zig");
const admission = @import("ordinal_index_tests/admission.zig");

/// Independent candidate IDs, storage boundaries, and admission statistics.
/// The codec owns the test registration and passes its namespace as Codec.
pub fn check(comptime Codec: type) !void {
    try candidates.check(Codec);
    try boundaries.check(Codec);
    try admission.check(Codec);
}
