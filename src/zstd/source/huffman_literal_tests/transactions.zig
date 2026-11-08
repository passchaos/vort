const std = @import("std");
const common = @import("common.zig");
const source_huffman_literals = common.source_huffman_literals;

fn decodePending(
    comptime Support: type,
    source: *common.TrackingSource,
    oracle: *Support.SliceOracle,
    block: common.source_frame.BlockLayout,
    decoded: *const common.PreparedBlock(Support),
) !void {
    const expected = try common.expectedLiterals(
        Support,
        oracle,
        common.blockBytes(source, block),
        decoded.layout.regenerated_size,
    );
    defer std.testing.allocator.free(expected);
    const output = try std.testing.allocator.alloc(u8, expected.len);
    defer std.testing.allocator.free(output);
    var page: [17]u8 = undefined;
    var cursor = try source_huffman_literals.init(
        Support.Codec,
        decoded.layout,
        &decoded.prepared,
        &page,
    );
    try cursor.copyNext(output);
    try std.testing.expectEqualSlices(u8, expected, output);
}

fn wholeBlockCommitBoundary(comptime Support: type) !void {
    const bytes = try common.decodeHex(common.repeat_hex);
    defer std.testing.allocator.free(bytes);
    var source = common.TrackingSource{ .bytes = bytes };
    var oracle = Support.initSliceOracle();
    var committed: ?Support.Codec.Table = null;

    for (0..2) |block_index| {
        const block = try common.blockAt(&source, block_index);
        const committed_before = committed;
        const decoded = try common.prepareBlock(
            Support,
            block,
            if (committed) |*table| table else null,
        );
        try std.testing.expect(decoded.prepared.replace_on_block_success);
        try decodePending(Support, &source, &oracle, block, &decoded);

        // Literal success alone is not publication: a later sequence or match
        // failure must leave the frame's committed tree unchanged.
        try std.testing.expectEqualDeep(committed_before, committed);
        const pending_before = decoded.prepared;
        try std.testing.expectEqualDeep(pending_before, decoded.prepared);

        // This assignment models the enclosing block executor's sole commit
        // point after literals, sequences and matches have all succeeded.
        common.commitIfSuccessful(Support, &decoded.prepared, &committed);
        try std.testing.expect(committed != null);
        try std.testing.expectEqualDeep(decoded.prepared.table, committed.?);
    }

    const committed_before_treeless = committed.?;
    const treeless_block = try common.blockAt(&source, 2);
    const treeless = try common.prepareBlock(Support, treeless_block, &committed.?);
    try std.testing.expect(!treeless.prepared.replace_on_block_success);
    try std.testing.expectEqual(.treeless_reuse, treeless.prepared.origin);
    try decodePending(Support, &source, &oracle, treeless_block, &treeless);
    try std.testing.expectEqualDeep(committed_before_treeless, committed.?);
    common.commitIfSuccessful(Support, &treeless.prepared, &committed);
    try std.testing.expectEqualDeep(committed_before_treeless, committed.?);
}

pub fn contracts(comptime Support: type) !void {
    try wholeBlockCommitBoundary(Support);
}
