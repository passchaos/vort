const happy = @import("huffman_literal_tests/happy.zig");
const malformed = @import("huffman_literal_tests/malformed.zig");
const callbacks = @import("huffman_literal_tests/callbacks.zig");
const transactions = @import("huffman_literal_tests/transactions.zig");

/// `Support` supplies the production source codec plus an independent slice
/// oracle with transactional previous-tree state:
///
/// - `Codec`: `Table`, `decodeDescription`, and `readSymbol`.
/// - `SliceOracle` and `initSliceOracle()`.
/// - `decodeSliceLiterals(*SliceOracle, block, exact_output)`.
pub fn contracts(comptime Support: type) !void {
    try happy.contracts(Support);
    try malformed.contracts(Support);
    try callbacks.contracts(Support);
    try transactions.contracts(Support);
}
