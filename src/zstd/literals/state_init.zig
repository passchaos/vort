/// Raw/RLE sections leave caller storage untouched. A small optional pointer
/// represents absence without materializing an unused Huffman state payload.
pub fn init(
    state: anytype,
    block: []const u8,
    section: anytype,
    comptime init_cursor: anytype,
) !?@TypeOf(state) {
    if (section.kind != .compressed and section.kind != .treeless) return null;
    state.tree = section.huffman_tree orelse return error.CorruptFrame;
    const Lookup = @TypeOf(state.lookup);
    if (!state.lookup.buildComplete(&state.tree))
        state.lookup = Lookup.build(&state.tree);
    state.cursor = try init_cursor(block, section);
    state.decoded = 0;
    return state;
}
