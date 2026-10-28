const Codec = @import("row_tags.zig");
const h = @import("row_tags_tests/edges/helpers.zig");
pub fn contracts(comptime C: type) !void {
    try @import("row_tags_tests/properties.zig").contracts(C);
    try @import("row_tags_tests/random.zig").contracts(C);
    try @import("row_tags_tests/dp_contracts.zig").contracts();
    try edges();
}
fn edges() !void {
    const E = @import("search_edges.zig");
    try @import("row_tags_tests/edges/boundaries.zig").contracts(E);
    try @import("row_tags_tests/edges/quotas.zig").contracts(E);
    try @import("row_tags_tests/edges/errors.zig").contracts(E);
    try @import("row_tags_tests/edges/smoke.zig").contracts(E);
    inline for (.{ false, true }) |whole| {
        inline for (.{ false, true }) |complete| {
            for ([_]usize{ 1, 8, 16 }) |width| {
                for ([_]?u64{ null, 0, 1, 17 }) |quota| {
                    _ = try h.compare(E, whole, complete, width, .{ .maximum = 100, .tagged = true, .limit = quota });
                }
            }
        }
    }
}
test "Zstd HQ search row tags all hash collisions exact keys and aliased candidates" {
    try @import("row_tags_tests/properties.zig").contracts(Codec);
}
test "Zstd HQ search row tags arbitrary rows random insertion and tag synchronization" {
    try @import("row_tags_tests/random.zig").contracts(Codec);
}
test "Zstd HQ search row tags frozen DP profiles admission and requested heap bytes" {
    try @import("row_tags_tests/dp_contracts.zig").contracts();
}
test "Zstd HQ search row tags optional edge fallback and tagged target table" {
    try edges();
}
