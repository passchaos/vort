const std = @import("std");
const D = @import("deflate");
const contract = D.CloneTestOracle;

test "Deflate clone standalone contracts" {
    try contract.contracts(D, std.testing.allocator);
}

pub fn main() !void {
    try contract.contracts(D, std.heap.page_allocator);
}
