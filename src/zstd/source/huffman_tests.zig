const happy = @import("huffman_tests/happy.zig");
const failures = @import("huffman_tests/failures.zig");

pub fn contracts(comptime Support: type) !void {
    try happy.contracts(Support);
    try failures.contracts(Support);
}
