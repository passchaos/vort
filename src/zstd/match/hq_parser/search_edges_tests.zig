const Codec = @import("search_edges.zig");

pub fn contracts(comptime C: type) !void {
    try @import("search_edges_tests/boundaries.zig").contracts(C);
    try @import("search_edges_tests/quotas.zig").contracts(C);
    try @import("search_edges_tests/errors.zig").contracts(C);
    try @import("search_edges_tests/smoke.zig").contracts(C);
}

test "Zstd HQ search sampled ML boundaries preserve frozen nodes and profile" {
    try @import("search_edges_tests/boundaries.zig").contracts(Codec);
}
test "Zstd HQ search sampled finite quotas preserve every frozen admission prefix" {
    try @import("search_edges_tests/quotas.zig").contracts(Codec);
}
test "Zstd HQ search sampled failures preserve frozen error precedence and overflow" {
    try @import("search_edges_tests/errors.zig").contracts(Codec);
}
test "Zstd HQ search complete spill and whole predecessor preserve frozen edges" {
    try @import("search_edges_tests/smoke.zig").contracts(Codec);
}
