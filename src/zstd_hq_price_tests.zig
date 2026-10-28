const std = @import("std");
const prices = @import("zstd/match/hq_parser/prices.zig");

test {
    std.testing.refAllDecls(prices);
    _ = @import("zstd/match/hq_parser/price_tests.zig");
}
