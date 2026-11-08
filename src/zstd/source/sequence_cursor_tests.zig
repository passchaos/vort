const happy = @import("sequence_cursor_tests/happy.zig");
const callbacks = @import("sequence_cursor_tests/callbacks.zig");
const malformed = @import("sequence_cursor_tests/malformed.zig");

/// `Support` supplies the production codec plus fixtures decoded by the
/// independent in-memory sequence path:
///
/// - `Codec`, `Tables`, `Mode`, `ResolvedMode`, and `Corpus`.
/// - `OwnedFixture`, `loadSequenceFixture`, and `freeSequenceFixture`.
/// - `OwnedOracle`, `decodeSequenceSliceOracle`, and
///   `freeSequenceSliceOracle`.
/// - `emitResolvedFixture` for all 27 concrete P/RLE/FSE mode tuples.
pub fn contracts(comptime Support: type) !void {
    try happy.contracts(Support);
    try callbacks.contracts(Support);
    try malformed.contracts(Support);
}
