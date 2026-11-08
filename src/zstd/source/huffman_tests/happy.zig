const std = @import("std");
const common = @import("common.zig");
const source_huffman = common.source_huffman;

fn directAndFseDifferential(comptime Support: type) !void {
    inline for (.{
        &common.minimum_direct_description,
        &common.direct_description,
        &common.maximum_direct_description,
        &common.fse_description,
    }) |description| {
        const fixture = common.compressedFixture(description, 0, true, true);
        var source = common.TrackingSource{ .bytes = fixture.bytes() };
        const prefix = try common.prefixFor(&fixture, &source, false);
        var scratch: [source_huffman.maximum_scratch_len]u8 = @splat(0xa5);
        const prepared = (try source_huffman.prepare(
            Support.Codec,
            prefix,
            null,
            scratch[0..description.len],
        )).?;
        const expected = try Support.parseStdDescription(description);
        try Support.expectTableEqual(&expected, &prepared.table);
        try std.testing.expectEqual(source_huffman.Origin.new_tree, prepared.origin);
        try std.testing.expectEqual(@as(u64, description.len), prepared.description_bytes);
        try common.expectRange(prepared.description.?, fixture.header_len, description.len);
        try std.testing.expect(prepared.replace_on_block_success);
    }
}

fn rawAndRleReadNothingDuringPrepare(comptime Support: type) !void {
    inline for (.{ @import("../../literals/header.zig").Kind.raw, .rle }) |kind| {
        const fixture = common.plainFixture(kind);
        var source = common.TrackingSource{ .bytes = fixture.bytes() };
        const prefix = try common.prefixFor(&fixture, &source, false);
        const calls = source.calls;
        var scratch: [0]u8 = .{};
        try std.testing.expect((try source_huffman.prepare(
            Support.Codec,
            prefix,
            null,
            &scratch,
        )) == null);
        try std.testing.expectEqual(calls, source.calls);
    }
}

fn treelessReuseIsPendingAndReadFree(comptime Support: type) !void {
    const committed = try Support.parseStdDescription(&common.direct_description);
    const fixture = common.treelessFixture();
    var source = common.TrackingSource{ .bytes = fixture.bytes() };
    const prefix = try common.prefixFor(&fixture, &source, true);
    const calls = source.calls;
    var scratch: [0]u8 = .{};
    const prepared = (try source_huffman.prepare(
        Support.Codec,
        prefix,
        &committed,
        &scratch,
    )).?;
    try Support.expectTableEqual(&committed, &prepared.table);
    try std.testing.expectEqual(source_huffman.Origin.treeless_reuse, prepared.origin);
    try std.testing.expect(prepared.description == null);
    try std.testing.expectEqual(@as(u64, 0), prepared.description_bytes);
    try std.testing.expect(!prepared.replace_on_block_success);
    try std.testing.expectEqual(calls, source.calls);
}

fn pendingTableOwnsItsData(comptime Support: type) !void {
    const committed = try Support.parseStdDescription(&common.fse_description);
    const before = committed;
    const fixture = common.compressedFixture(&common.direct_description, 0, true, true);
    var source = common.TrackingSource{ .bytes = fixture.bytes() };
    const prefix = try common.prefixFor(&fixture, &source, false);
    var guarded: [common.direct_description.len + 2]u8 = @splat(0x6d);
    const prepared = (try source_huffman.prepare(
        Support.Codec,
        prefix,
        &committed,
        guarded[1 .. guarded.len - 1],
    )).?;
    try Support.expectTableEqual(&before, &committed);
    try std.testing.expectEqual(@as(u8, 0x6d), guarded[0]);
    try std.testing.expectEqual(@as(u8, 0x6d), guarded[guarded.len - 1]);
    @memset(guarded[1 .. guarded.len - 1], 0xee);
    const expected = try Support.parseStdDescription(&common.direct_description);
    try Support.expectTableEqual(&expected, &prepared.table);
}

fn shortReadsAndWideOffsets(comptime Support: type) !void {
    inline for (.{ &common.direct_description, &common.fse_description }) |description| {
        for (1..4) |chunk| {
            const fixture = common.compressedFixture(description, 0, true, true);
            var source = common.TrackingSource{ .bytes = fixture.bytes(), .max_chunk = chunk };
            const prefix = try common.prefixFor(&fixture, &source, false);
            source.resetAccounting();
            var scratch: [source_huffman.maximum_scratch_len]u8 = undefined;
            const prepared = (try source_huffman.prepare(
                Support.Codec,
                prefix,
                null,
                scratch[0..description.len],
            )).?;
            const expected = try Support.parseStdDescription(description);
            try Support.expectTableEqual(&expected, &prepared.table);
            try std.testing.expectEqual(
                (description.len + chunk - 1) / chunk,
                source.calls,
            );
        }
    }

    const base = (@as(u64, 1) << 32) + 0x9876;
    const fixture = common.compressedFixture(&common.direct_description, 0, true, true);
    var source = common.TrackingSource{ .bytes = fixture.bytes(), .base_offset = base };
    const prefix = try common.prefixFor(&fixture, &source, false);
    source.resetAccounting();
    var scratch: [common.direct_description.len]u8 = undefined;
    const prepared = (try source_huffman.prepare(Support.Codec, prefix, null, &scratch)).?;
    try common.expectRange(prepared.description.?, base + fixture.header_len, common.direct_description.len);
    try std.testing.expect(source.min_observed_offset.? > std.math.maxInt(u32));
}

fn streamDataRemainsUnread(comptime Support: type) !void {
    inline for (.{
        .{ .description = &common.direct_description, .size_format = @as(u2, 1) },
        .{ .description = &common.fse_description, .size_format = @as(u2, 0) },
    }) |case| {
        const fixture = common.compressedFixture(case.description, case.size_format, true, true);
        var source = common.TrackingSource{ .bytes = fixture.bytes() };
        const prefix = try common.prefixFor(&fixture, &source, false);
        const forbidden = [_]common.Span{.{
            .offset = fixture.header_len + fixture.description_len,
            .len = fixture.stream_len,
        }};
        source.forbidden = &forbidden;
        source.resetAccounting();
        var scratch: [source_huffman.maximum_scratch_len]u8 = undefined;
        _ = (try source_huffman.prepare(
            Support.Codec,
            prefix,
            null,
            scratch[0..case.description.len],
        )).?;
        try std.testing.expect(!source.forbidden_read);
        try std.testing.expectEqual(case.description.len, source.bytes_returned);
    }
}

pub fn contracts(comptime Support: type) !void {
    try std.testing.expectEqual(@as(usize, 128), source_huffman.maximum_scratch_len);
    try directAndFseDifferential(Support);
    try rawAndRleReadNothingDuringPrepare(Support);
    try treelessReuseIsPendingAndReadFree(Support);
    try pendingTableOwnsItsData(Support);
    try shortReadsAndWideOffsets(Support);
    try streamDataRemainsUnread(Support);
}
