const std = @import("std");
const common = @import("common.zig");

const source_frame = common.source_frame;
const source_input = common.source_input;
const FrameFormat = common.FrameFormat;
const Fixture = common.Fixture;
const SliceHeaderResult = common.SliceHeaderResult;
const Span = common.Span;
const TrackingSource = common.TrackingSource;

const skippable_magic_min: u32 = 0x184d_2a50;
const block_size_limit: usize = 128 * 1024;

fn expectHeaderMatches(
    layout: source_frame.DataFrameLayout,
    oracle: SliceHeaderResult,
    descriptor: u8,
    format: FrameFormat,
    base: u64,
) !void {
    const prefix_len = common.prefixLen(format);
    const encoded_len = common.expectedEncodedLen(descriptor);
    const header_len = prefix_len + encoded_len;
    const dictionary_len = common.dictionaryFieldLen(descriptor);
    const content_len = common.contentSizeFieldLen(descriptor);
    const single_segment = (descriptor & 0x20) != 0;
    const encoded_content = common.encodedContentSize(content_len);
    const content_size: ?u64 = if (content_len == 0)
        null
    else
        encoded_content + @as(u64, if (content_len == 2) 256 else 0);
    const window_size: u64 = if (single_segment) content_size.? else 2816;
    const block_size_max: usize = @intCast(@min(window_size, block_size_limit));

    try std.testing.expectEqual(encoded_len, layout.header.encoded_len);
    try std.testing.expectEqual(content_size, layout.header.content_size);
    try std.testing.expectEqual((descriptor & 0x04) != 0, layout.header.has_checksum);
    try std.testing.expectEqual(single_segment, layout.header.single_segment);
    try std.testing.expectEqual(window_size, layout.header.window_size);
    try std.testing.expectEqual(block_size_max, layout.header.block_size_max);
    try std.testing.expectEqual(common.expectedDictionaryId(dictionary_len), layout.header.dictionary_id);
    try common.expectRange(layout.prefix_range, base, prefix_len);
    try common.expectRange(layout.wire_header_range, base + prefix_len, encoded_len);
    try common.expectRange(layout.header_range, base, header_len);
    try std.testing.expectEqual(base + header_len, layout.first_block_offset);

    try std.testing.expectEqual(layout.header.encoded_len, oracle.encoded_len);
    try std.testing.expectEqual(layout.header.content_size, oracle.content_size);
    try std.testing.expectEqual(layout.header.has_checksum, oracle.has_checksum);
    try std.testing.expectEqual(layout.header.single_segment, oracle.single_segment);
    try std.testing.expectEqual(layout.header.window_size, oracle.window_size);
    try std.testing.expectEqual(layout.header.block_size_max, oracle.block_size_max);
    try std.testing.expectEqual(layout.header.dictionary_id, oracle.dictionary_id);
    try std.testing.expectEqual(header_len, oracle.first_block_offset);
}

fn descriptorAndFormatDifferential(comptime Support: type) !void {
    for (0..256) |descriptor_value| {
        const descriptor: u8 = @intCast(descriptor_value);
        for ([_]FrameFormat{ .standard, .magicless }) |format| {
            var fixture: Fixture = .{};
            _ = common.appendDataHeader(&fixture, format, descriptor);
            var source = TrackingSource{ .bytes = fixture.bytes() };
            const available = try source_input.Range.init(source.source(17), 0, fixture.len);
            if ((descriptor & 0x08) != 0) {
                try std.testing.expectError(
                    error.CorruptFrame,
                    source_frame.parseDataFrameHeader(available, format),
                );
                try std.testing.expectError(
                    error.CorruptFrame,
                    Support.parseSliceHeader(fixture.bytes(), format),
                );
                continue;
            }

            const layout = try source_frame.parseDataFrameHeader(available, format);
            const oracle: SliceHeaderResult = try Support.parseSliceHeader(
                fixture.bytes(),
                format,
            );
            try expectHeaderMatches(layout, oracle, descriptor, format, 0);
            try common.expectRange(
                layout.blocks,
                layout.first_block_offset,
                fixture.len - layout.header_range.len,
            );
        }
    }

    var clear_fixture: Fixture = .{};
    _ = common.appendDataHeader(&clear_fixture, .magicless, 0x00);
    var set_fixture: Fixture = .{};
    _ = common.appendDataHeader(&set_fixture, .magicless, 0x10);
    const clear = try Support.parseSliceHeader(clear_fixture.bytes(), .magicless);
    const set = try Support.parseSliceHeader(set_fixture.bytes(), .magicless);
    try std.testing.expectEqual(clear.content_size, set.content_size);
    try std.testing.expectEqual(clear.window_size, set.window_size);
    try std.testing.expectEqual(clear.dictionary_id, set.dictionary_id);
}

fn maximumHeaderTruncation(comptime Support: type) !void {
    inline for (.{ FrameFormat.standard, FrameFormat.magicless }) |format| {
        var fixture: Fixture = .{};
        const header_len = common.appendDataHeader(&fixture, format, 0xd3);
        try std.testing.expectEqual(common.prefixLen(format) + 14, header_len);
        for (0..header_len) |len| {
            var source = TrackingSource{ .bytes = fixture.bytes()[0..len] };
            const available = try source_input.Range.init(source.source(18), 0, len);
            try std.testing.expectError(
                error.TruncatedFrame,
                source_frame.parseDataFrameHeader(available, format),
            );
            try std.testing.expectError(
                error.TruncatedFrame,
                Support.parseSliceHeader(fixture.bytes()[0..len], format),
            );
        }
        var source = TrackingSource{ .bytes = fixture.bytes() };
        const available = try source_input.Range.init(source.source(18), 0, fixture.len);
        _ = try source_frame.parseDataFrameHeader(available, format);
    }
}

fn streamElementPrefixes() !void {
    var data_fixture: Fixture = .{};
    _ = common.appendDataHeader(&data_fixture, .standard, 0x20);
    var data_source = TrackingSource{ .bytes = data_fixture.bytes() };
    const data_range = try source_input.Range.init(data_source.source(8), 0, data_fixture.len);
    const data = try source_frame.parseStreamElementHeader(data_range, .standard);
    switch (data) {
        .data => |layout| try std.testing.expectEqual(@as(u64, 6), layout.first_block_offset),
        .skippable => return error.TestUnexpectedResult,
    }

    for (0..16) |id_value| {
        const id: u4 = @intCast(id_value);
        var fixture: Fixture = .{};
        fixture.appendLittle(skippable_magic_min + @as(u32, id), 4);
        fixture.appendLittle(3, 4);
        fixture.appendRepeat(0xc7, 3);
        fixture.appendRepeat(0x5a, 2); // Concatenated suffix is not part of skip.
        const forbidden = [_]Span{.{ .offset = 8, .len = 3 }};
        var source = TrackingSource{ .bytes = fixture.bytes(), .forbidden = &forbidden };
        const available = try source_input.Range.init(source.source(8), 0, fixture.len);
        const element = try source_frame.parseStreamElementHeader(available, .standard);
        switch (element) {
            .data => return error.TestUnexpectedResult,
            .skippable => |skip| {
                try std.testing.expectEqual(skippable_magic_min + @as(u32, id), skip.magic);
                try std.testing.expectEqual(id, skip.skippable_id);
                try common.expectRange(skip.header_range, 0, 8);
                try common.expectRange(skip.payload, 8, 3);
                try common.expectRange(skip.frame_range, 0, 11);
                try std.testing.expectEqual(@as(u64, 11), skip.next_element_offset);
            },
        }
        try std.testing.expect(!source.forbidden_read);
        try std.testing.expectEqual(@as(usize, 2), source.calls);
        try std.testing.expectError(
            error.InvalidMagic,
            source_frame.parseDataFrameHeader(available, .standard),
        );
    }

    var unknown_fixture: Fixture = .{};
    unknown_fixture.appendLittle(0x1234_5678, 4);
    var unknown_source = TrackingSource{ .bytes = unknown_fixture.bytes() };
    const unknown_range = try source_input.Range.init(
        unknown_source.source(4),
        0,
        unknown_fixture.len,
    );
    try std.testing.expectError(
        error.InvalidMagic,
        source_frame.parseStreamElementHeader(unknown_range, .standard),
    );

    var skip_fixture: Fixture = .{};
    skip_fixture.appendLittle(skippable_magic_min, 4);
    skip_fixture.appendLittle(0, 4);
    var magicless_source = TrackingSource{ .bytes = skip_fixture.bytes() };
    const magicless_range = try source_input.Range.init(
        magicless_source.source(8),
        0,
        skip_fixture.len,
    );
    const magicless = try source_frame.parseStreamElementHeader(magicless_range, .magicless);
    switch (magicless) {
        .data => |layout| {
            try common.expectRange(layout.prefix_range, 0, 0);
            try std.testing.expectEqual(@as(u64, 4), layout.first_block_offset);
        },
        .skippable => return error.TestUnexpectedResult,
    }
}

fn skippableBoundsDoNotReadPayload() !void {
    var fixture: Fixture = .{};
    fixture.appendLittle(skippable_magic_min + 7, 4);
    fixture.appendLittle(5, 4);
    fixture.appendRepeat(0x9e, 5);
    const forbidden = [_]Span{.{ .offset = 8, .len = 5 }};
    var source = TrackingSource{
        .bytes = fixture.bytes(),
        .forbidden = &forbidden,
        .max_chunk = 1,
    };
    const available = try source_input.Range.init(source.source(1), 0, fixture.len);
    _ = try source_frame.parseStreamElementHeader(available, .standard);
    try std.testing.expect(!source.forbidden_read);
    try std.testing.expectEqual(@as(usize, 8), source.calls);

    for (0..5) |payload_prefix| {
        const len = 8 + payload_prefix;
        const present = [_]Span{.{ .offset = 8, .len = payload_prefix }};
        var short_source = TrackingSource{
            .bytes = fixture.bytes()[0..len],
            .forbidden = &present,
        };
        const short_range = try source_input.Range.init(short_source.source(8), 0, len);
        try std.testing.expectError(
            error.TruncatedFrame,
            source_frame.parseStreamElementHeader(short_range, .standard),
        );
        try std.testing.expect(!short_source.forbidden_read);
    }

    var wide_fixture: Fixture = .{};
    wide_fixture.appendLittle(skippable_magic_min + 15, 4);
    wide_fixture.appendLittle(std.math.maxInt(u32), 4);
    const logical_len = @as(u64, 8) + std.math.maxInt(u32);
    var wide_source = TrackingSource{
        .bytes = wide_fixture.bytes(),
        .logical_len = logical_len,
    };
    const wide_range = try source_input.Range.init(wide_source.source(8), 0, logical_len);
    const wide = try source_frame.parseStreamElementHeader(wide_range, .standard);
    switch (wide) {
        .data => return error.TestUnexpectedResult,
        .skippable => |skip| {
            try std.testing.expectEqual(@as(u4, 15), skip.skippable_id);
            try common.expectRange(skip.payload, 8, std.math.maxInt(u32));
            try std.testing.expectEqual(logical_len, skip.next_element_offset);
        },
    }
    try std.testing.expectEqual(@as(usize, 2), wide_source.calls);
}

pub fn contracts(comptime Support: type) !void {
    try descriptorAndFormatDifferential(Support);
    try maximumHeaderTruncation(Support);
    try streamElementPrefixes();
    try skippableBoundsDoNotReadPayload();
}
