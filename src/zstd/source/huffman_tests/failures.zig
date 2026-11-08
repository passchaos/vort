const std = @import("std");
const common = @import("common.zig");
const source_huffman = common.source_huffman;
const source_literals = common.source_literals;

fn exactScratchAndPreflight(comptime Support: type) !void {
    const fixture = common.compressedFixture(&common.direct_description, 0, true, true);
    var source = common.TrackingSource{ .bytes = fixture.bytes() };
    const prefix = try common.prefixFor(&fixture, &source, false);
    var scratch: [common.direct_description.len]u8 = undefined;
    for (0..common.direct_description.len) |len| {
        source.resetAccounting();
        try std.testing.expectError(
            error.OutputTooSmall,
            source_huffman.prepare(Support.Codec, prefix, null, scratch[0..len]),
        );
        try std.testing.expectEqual(@as(usize, 0), source.calls);
    }

    _ = (try source_huffman.prepare(Support.Codec, prefix, null, &scratch)).?;
}

fn treelessNeedsCommittedTable(comptime Support: type) !void {
    const fixture = common.treelessFixture();
    var source = common.TrackingSource{ .bytes = fixture.bytes() };
    const prefix = try common.prefixFor(&fixture, &source, true);
    source.resetAccounting();
    var scratch: [0]u8 = .{};
    try std.testing.expectError(
        error.CorruptFrame,
        source_huffman.prepare(Support.Codec, prefix, null, &scratch),
    );
    try std.testing.expectEqual(@as(usize, 0), source.calls);

    const forbidden = [_]common.Span{.{
        .offset = fixture.header_len,
        .len = fixture.len - fixture.header_len,
    }};
    var no_previous_source = common.TrackingSource{
        .bytes = fixture.bytes(),
        .forbidden = &forbidden,
    };
    try std.testing.expectError(
        error.CorruptFrame,
        common.prefixFor(&fixture, &no_previous_source, false),
    );
    try std.testing.expect(!no_previous_source.forbidden_read);
}

fn callbackFailures(comptime Support: type) !void {
    const committed = try Support.parseStdDescription(&common.fse_description);
    inline for (.{
        .{ .mode = common.Mode.zero, .expected = error.TruncatedFrame },
        .{ .mode = common.Mode.excessive, .expected = error.SourceReadFailed },
        .{ .mode = common.Mode.fail, .expected = error.SourceReadFailed },
    }) |case| {
        for (1..common.direct_description.len + 1) |fault_call| {
            const before = committed;
            const fixture = common.compressedFixture(&common.direct_description, 0, true, true);
            var source = common.TrackingSource{
                .bytes = fixture.bytes(),
                .max_chunk = 1,
            };
            const prefix = try common.prefixFor(&fixture, &source, false);
            source.resetAccounting();
            source.mode = case.mode;
            source.fault_call = fault_call;
            var scratch: [common.direct_description.len]u8 = undefined;
            try std.testing.expectError(
                case.expected,
                source_huffman.prepare(Support.Codec, prefix, &committed, &scratch),
            );
            try std.testing.expectEqual(fault_call, source.calls);
            try Support.expectTableEqual(&before, &committed);
        }
    }
}

fn treeErrorPrecedesJumpAndCount(comptime Support: type) !void {
    const bad_tree = [_]u8{ 0x80, 0x00 };
    const fixture = common.compressedFixture(&bad_tree, 1, false, false);
    var source = common.TrackingSource{ .bytes = fixture.bytes() };
    const prefix = try common.prefixFor(&fixture, &source, false);
    var scratch: [bad_tree.len]u8 = undefined;
    try std.testing.expectError(
        error.CorruptFrame,
        source_huffman.prepare(Support.Codec, prefix, null, &scratch),
    );
}

fn finishFailureDoesNotCommit(comptime Support: type) !void {
    const committed = try Support.parseStdDescription(&common.fse_description);
    const before = committed;
    const fixture = common.compressedFixture(&common.direct_description, 1, false, true);
    var source = common.TrackingSource{ .bytes = fixture.bytes() };
    const prefix = try common.prefixFor(&fixture, &source, false);
    var scratch: [common.direct_description.len]u8 = undefined;
    const pending = (try source_huffman.prepare(
        Support.Codec,
        prefix,
        &committed,
        &scratch,
    )).?;
    try std.testing.expect(pending.replace_on_block_success);
    try std.testing.expectError(error.CorruptFrame, source_literals.finishLayout(prefix));
    try Support.expectTableEqual(&before, &committed);
}

fn malformedLayoutsRejectBeforeReads(comptime Support: type) !void {
    const fixture = common.compressedFixture(&common.direct_description, 0, true, true);
    var source = common.TrackingSource{ .bytes = fixture.bytes() };
    const prefix = try common.prefixFor(&fixture, &source, false);
    source.resetAccounting();
    var malformed = prefix;
    malformed.stream_data = null;
    var scratch: [common.direct_description.len]u8 = undefined;
    try std.testing.expectError(
        error.CorruptFrame,
        source_huffman.prepare(Support.Codec, malformed, null, &scratch),
    );
    try std.testing.expectEqual(@as(usize, 0), source.calls);
}

pub fn contracts(comptime Support: type) !void {
    try exactScratchAndPreflight(Support);
    try treelessNeedsCommittedTable(Support);
    try callbackFailures(Support);
    try treeErrorPrecedesJumpAndCount(Support);
    try finishFailureDoesNotCommit(Support);
    try malformedLayoutsRejectBeforeReads(Support);
}
