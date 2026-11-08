const std = @import("std");
const common = @import("common.zig");

const source_frame = common.source_frame;
const source_input = common.source_input;
const FrameFormat = common.FrameFormat;
const Fixture = common.Fixture;
const SliceBlockKind = common.SliceBlockKind;
const SliceBlockResult = common.SliceBlockResult;
const SourceMode = common.SourceMode;
const Span = common.Span;
const TrackingSource = common.TrackingSource;

fn expectedBlockKind(
    kind: @TypeOf(@as(source_frame.BlockLayout, undefined).header.kind),
) SliceBlockKind {
    return switch (kind) {
        .raw => .raw,
        .rle => .rle,
        .compressed => .compressed,
    };
}

fn expectBlockMatches(
    block: source_frame.BlockLayout,
    oracle: SliceBlockResult,
) !void {
    try std.testing.expectEqual(oracle.last, block.header.last);
    try std.testing.expectEqual(oracle.kind, expectedBlockKind(block.header.kind));
    try std.testing.expectEqual(oracle.declared_len, block.header.declared_len);
    try std.testing.expectEqual(oracle.wire_len, block.header.wire_len);
    try std.testing.expectEqual(@as(u64, oracle.header_offset), block.header_range.offset);
    try std.testing.expectEqual(@as(u64, 3), block.header_range.len);
    try std.testing.expectEqual(@as(u64, oracle.payload_offset), block.payload.offset);
    try std.testing.expectEqual(@as(u64, oracle.wire_len), block.payload.len);
    try std.testing.expectEqual(@as(u64, oracle.next_header_offset), block.next_header_offset);
}

fn blockKindAndFormatDifferential(comptime Support: type) !void {
    inline for (.{ FrameFormat.standard, FrameFormat.magicless }) |format| {
        inline for (.{ SliceBlockKind.raw, SliceBlockKind.rle, SliceBlockKind.compressed }) |kind| {
            inline for (.{ false, true }) |last| {
                var fixture: Fixture = .{};
                const header_len = common.appendDataHeader(&fixture, format, 0x00);
                common.appendBlock(&fixture, 5, kind, last);
                var source = TrackingSource{ .bytes = fixture.bytes() };
                const available = try source_input.Range.init(
                    source.source(9),
                    0,
                    fixture.len,
                );
                const frame = try source_frame.parseDataFrameHeader(available, format);
                const block = try source_frame.parseFirstBlock(frame);
                const oracle: SliceBlockResult = try Support.parseSliceBlock(
                    fixture.bytes(),
                    header_len,
                    format,
                );
                try expectBlockMatches(block, oracle);
                try std.testing.expectEqual(kind, oracle.kind);
                try std.testing.expectEqual(last, oracle.last);
                try std.testing.expectEqual(@as(usize, 5), oracle.declared_len);
                try std.testing.expectEqual(
                    @as(usize, if (kind == .rle) 1 else 5),
                    oracle.wire_len,
                );
                try std.testing.expectError(
                    error.CorruptFrame,
                    source_frame.parseBlock(frame, frame.first_block_offset - 1),
                );
            }
        }

        var reserved_fixture: Fixture = .{};
        const header_len = common.appendDataHeader(&reserved_fixture, format, 0x00);
        common.appendBlockHeader(&reserved_fixture, 0, 3, true);
        var source = TrackingSource{ .bytes = reserved_fixture.bytes() };
        const available = try source_input.Range.init(
            source.source(9),
            0,
            reserved_fixture.len,
        );
        const frame = try source_frame.parseDataFrameHeader(available, format);
        try std.testing.expectError(error.CorruptFrame, source_frame.parseFirstBlock(frame));
        try std.testing.expectError(
            error.CorruptFrame,
            Support.parseSliceBlock(reserved_fixture.bytes(), header_len, format),
        );
    }
}

fn parseLogicalBlock(
    declared_len: usize,
    kind_bits: u2,
    logical_payload_len: usize,
) !source_frame.BlockLayout {
    var fixture: Fixture = .{};
    const header_len = common.appendDataHeader(&fixture, .standard, 0x00);
    fixture.storage[common.prefixLen(.standard) + 1] = 0; // 1 KiB frame window.
    common.appendBlockHeader(&fixture, declared_len, kind_bits, true);
    var source = TrackingSource{
        .bytes = fixture.bytes(),
        .logical_len = header_len + 3 + @as(u64, @intCast(logical_payload_len)),
    };
    const available = try source_input.Range.init(
        source.source(9),
        0,
        source.logical_len.?,
    );
    const frame = try source_frame.parseDataFrameHeader(available, .standard);
    return source_frame.parseFirstBlock(frame);
}

fn blockSizeBoundaries() !void {
    const raw_limit = try parseLogicalBlock(1024, 0, 1024);
    try std.testing.expectEqual(@as(usize, 1024), raw_limit.header.declared_len);
    try std.testing.expectError(error.CorruptFrame, parseLogicalBlock(1025, 0, 1025));
    try std.testing.expectError(error.CorruptFrame, parseLogicalBlock(1025, 1, 1));

    const compressed_limit = try parseLogicalBlock(1024, 2, 1024);
    try std.testing.expectEqual(@as(usize, 1024), compressed_limit.header.declared_len);
    try std.testing.expectError(
        error.CorruptFrame,
        parseLogicalBlock(1025, 2, 1025),
    );
}

fn blockTruncation(comptime Support: type) !void {
    var fixture: Fixture = .{};
    const header_len = common.appendDataHeader(&fixture, .standard, 0x00);
    common.appendBlock(&fixture, 5, .raw, true);

    for (0..3) |header_prefix| {
        const len = header_len + header_prefix;
        var source = TrackingSource{ .bytes = fixture.bytes()[0..len] };
        const available = try source_input.Range.init(source.source(9), 0, len);
        const frame = try source_frame.parseDataFrameHeader(available, .standard);
        try std.testing.expectError(error.TruncatedFrame, source_frame.parseFirstBlock(frame));
        try std.testing.expectError(
            error.TruncatedFrame,
            Support.parseSliceBlock(fixture.bytes()[0..len], header_len, .standard),
        );
    }

    for (0..5) |payload_prefix| {
        const len = header_len + 3 + payload_prefix;
        var source = TrackingSource{ .bytes = fixture.bytes()[0..len] };
        const available = try source_input.Range.init(source.source(9), 0, len);
        const frame = try source_frame.parseDataFrameHeader(available, .standard);
        try std.testing.expectError(error.TruncatedFrame, source_frame.parseFirstBlock(frame));
        try std.testing.expectError(
            error.TruncatedFrame,
            Support.parseSliceBlock(fixture.bytes()[0..len], header_len, .standard),
        );
    }
}

fn parseHeaderAndFirstBlock(available: source_input.Range) !void {
    const frame = try source_frame.parseDataFrameHeader(available, .standard);
    _ = try source_frame.parseFirstBlock(frame);
}

fn oneByteReadsAndCallbackFailures() !void {
    var fixture: Fixture = .{};
    _ = common.appendDataHeader(&fixture, .standard, 0xd3);
    common.appendBlock(&fixture, 3, .compressed, true);
    var short_source = TrackingSource{ .bytes = fixture.bytes(), .max_chunk = 1 };
    const short_range = try source_input.Range.init(short_source.source(1), 0, fixture.len);
    try parseHeaderAndFirstBlock(short_range);
    try std.testing.expectEqual(@as(usize, 1), short_source.max_requested);
    try std.testing.expectEqual(@as(usize, 21), short_source.calls);
    try std.testing.expectEqual(@as(usize, 21), short_source.bytes_returned);

    var failure_fixture: Fixture = .{};
    _ = common.appendDataHeader(&failure_fixture, .standard, 0x00);
    common.appendBlock(&failure_fixture, 1, .raw, true);
    inline for (.{
        .{ SourceMode.zero, error.TruncatedFrame },
        .{ SourceMode.excessive, error.SourceReadFailed },
        .{ SourceMode.fail, error.SourceReadFailed },
    }) |case| {
        for (1..5) |fault_call| {
            var source = TrackingSource{
                .bytes = failure_fixture.bytes(),
                .mode = case[0],
                .fault_call = fault_call,
            };
            const available = try source_input.Range.init(
                source.source(9),
                0,
                failure_fixture.len,
            );
            try std.testing.expectError(case[1], parseHeaderAndFirstBlock(available));
            try std.testing.expectEqual(fault_call, source.calls);
        }
    }
}

fn wideBaseAndPayloadCanaries() !void {
    var fixture: Fixture = .{};
    const header_len = common.appendDataHeader(&fixture, .standard, 0x00);
    common.appendBlock(&fixture, 5, .raw, true);
    const base = (@as(u64, 1) << 32) + 0x67_890;
    var source = TrackingSource{
        .bytes = fixture.bytes(),
        .base_offset = base,
        .max_chunk = 1,
    };
    const available = try source_input.Range.init(source.source(1), base, fixture.len);
    const frame = try source_frame.parseDataFrameHeader(available, .standard);
    const block = try source_frame.parseFirstBlock(frame);
    try common.expectRange(frame.header_range, base, header_len);
    try common.expectRange(block.header_range, base + header_len, 3);
    try common.expectRange(block.payload, base + header_len + 3, 5);
    try std.testing.expect(source.min_observed_offset.? >= base);
    try std.testing.expect(source.max_observed_offset > std.math.maxInt(u32));

    inline for (.{ SliceBlockKind.raw, SliceBlockKind.rle, SliceBlockKind.compressed }) |kind| {
        var payload_fixture: Fixture = .{};
        const payload_header_len = common.appendDataHeader(&payload_fixture, .standard, 0x00);
        common.appendBlock(&payload_fixture, 5, kind, true);
        var storage: [514]u8 = @splat(0x5c);
        @memcpy(storage[1..][0..payload_fixture.len], payload_fixture.bytes());
        storage[0] = 0x17;
        storage[payload_fixture.len + 1] = 0xe8;
        const wire_len: usize = if (kind == .rle) 1 else 5;
        const forbidden = [_]Span{.{
            .offset = payload_header_len + 3,
            .len = wire_len,
        }};
        var payload_source = TrackingSource{
            .bytes = storage[1..][0..payload_fixture.len],
            .forbidden = &forbidden,
        };
        const payload_range = try source_input.Range.init(
            payload_source.source(9),
            0,
            payload_fixture.len,
        );
        const payload_frame = try source_frame.parseDataFrameHeader(payload_range, .standard);
        _ = try source_frame.parseFirstBlock(payload_frame);
        try std.testing.expect(!payload_source.forbidden_read);
        try std.testing.expectEqual(@as(u8, 0x17), storage[0]);
        try std.testing.expectEqual(@as(u8, 0xe8), storage[payload_fixture.len + 1]);
    }
}

pub fn contracts(comptime Support: type) !void {
    try blockKindAndFormatDifferential(Support);
    try blockSizeBoundaries();
    try blockTruncation(Support);
    try oneByteReadsAndCallbackFailures();
    try wideBaseAndPayloadCanaries();
}
