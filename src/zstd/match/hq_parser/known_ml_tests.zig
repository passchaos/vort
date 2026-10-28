const Codec = @import("sampled_price.zig");
pub fn contracts(comptime C: type) !void {
    try @import("known_ml_tests/primitive.zig").contracts(C);
    try @import("known_ml_tests/edges.zig").contracts();
}
test "Zstd HQ search known ML endpoint prices equal current scalar oracle" {
    try @import("known_ml_tests/primitive.zig").contracts(Codec);
}
test "Zstd HQ search known ML edges preserve frozen tables work and failure order" {
    try @import("known_ml_tests/edges.zig").contracts();
}
