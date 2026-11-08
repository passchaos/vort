const std = @import("std");
const byte_source = @import("../../io/source.zig");
const header = @import("../literals/header.zig");
const sequence_count = @import("../sequence/count.zig");
const source_input = @import("input.zig");
const source_literals = @import("literals.zig");

const SourceMode = enum { normal, zero, excessive, fail };

const Span = struct {
    offset: usize,
    len: usize,
};

const TrackingSource = struct {
    bytes: []const u8,
    base_offset: u64 = 0,
    max_chunk: usize = std.math.maxInt(usize),
    mode: SourceMode = .normal,
    fault_call: ?usize = null,
    forbidden: []const Span = &.{},
    calls: usize = 0,
    max_requested: usize = 0,
    forbidden_read: bool = false,
    min_observed_offset: ?u64 = null,
    max_observed_offset: u64 = 0,

    fn source(self: *TrackingSource, max_read_size: usize) byte_source.Source {
        return .{
            .context = self,
            .len = self.base_offset + @as(u64, @intCast(self.bytes.len)),
            .read_at = readAt,
            .max_read_size = max_read_size,
        };
    }

    fn readAt(raw: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
        const self: *TrackingSource = @ptrCast(@alignCast(raw));
        self.calls += 1;
        self.max_requested = @max(self.max_requested, output.len);
        self.min_observed_offset = if (self.min_observed_offset) |old| @min(old, offset) else offset;
        self.max_observed_offset = @max(self.max_observed_offset, offset);
        if (self.fault_call == null or self.fault_call.? == self.calls) {
            switch (self.mode) {
                .zero => return 0,
                .excessive => return output.len + 1,
                .fail => return error.SourceReadFailed,
                .normal => {},
            }
        }
        if (offset < self.base_offset) return error.SourceReadFailed;
        const relative = std.math.cast(usize, offset - self.base_offset) orelse
            return error.SourceReadFailed;
        const request_end = std.math.add(usize, relative, output.len) catch
            return error.SourceReadFailed;
        for (self.forbidden) |span| {
            const span_end = span.offset + span.len;
            if (relative < span_end and span.offset < request_end) {
                self.forbidden_read = true;
                return error.SourceReadFailed;
            }
        }
        if (relative >= self.bytes.len) return 0;
        const amount = @min(self.max_chunk, @min(output.len, self.bytes.len - relative));
        @memcpy(output[0..amount], self.bytes[relative..][0..amount]);
        return amount;
    }
};

const Fixture = struct {
    storage: [1024]u8 = @splat(0),
    len: usize = 0,

    fn bytes(self: *const Fixture) []const u8 {
        return self.storage[0..self.len];
    }

    fn appendByte(self: *Fixture, value: u8) void {
        self.storage[self.len] = value;
        self.len += 1;
    }

    fn appendRepeat(self: *Fixture, value: u8, len: usize) void {
        @memset(self.storage[self.len..][0..len], value);
        self.len += len;
    }

    fn appendLittle(self: *Fixture, value: u64, len: usize) void {
        for (0..len) |index| self.appendByte(@truncate(value >> @intCast(index * 8)));
    }
};

fn kindBits(kind: header.Kind) u2 {
    return @intFromEnum(kind);
}

fn appendHeader(
    fixture: *Fixture,
    kind: header.Kind,
    size_format: u2,
    regenerated_size: usize,
    compressed_size: usize,
) usize {
    const start = fixture.len;
    const wire: u64 = switch (kind) {
        .raw, .rle => if (size_format == 0 or size_format == 2)
            (@as(u64, regenerated_size) << 3) | kindBits(kind)
        else
            (@as(u64, regenerated_size) << 4) |
                (@as(u64, size_format) << 2) | kindBits(kind),
        .compressed, .treeless => blk: {
            const size_bits: u6 = switch (size_format) {
                0, 1 => 10,
                2 => 14,
                3 => 18,
            };
            const values = @as(u64, regenerated_size) |
                (@as(u64, compressed_size) << size_bits);
            break :blk (values << 4) |
                (@as(u64, size_format) << 2) | kindBits(kind);
        },
    };
    const len: usize = switch (kind) {
        .raw, .rle => switch (size_format) {
            0, 2 => 1,
            1 => 2,
            3 => 3,
        },
        .compressed, .treeless => switch (size_format) {
            0, 1 => 3,
            2 => 4,
            3 => 5,
        },
    };
    fixture.appendLittle(wire, len);
    return fixture.len - start;
}

fn appendCount(fixture: *Fixture, count_len: usize) usize {
    const start = fixture.len;
    switch (count_len) {
        1 => fixture.appendByte(7),
        2 => {
            fixture.appendByte(129);
            fixture.appendByte(0);
        },
        3 => {
            fixture.appendByte(255);
            fixture.appendByte(0x34);
            fixture.appendByte(0x12);
        },
        else => unreachable,
    }
    return fixture.len - start;
}

fn expectedCount(count_len: usize) usize {
    return switch (count_len) {
        1 => 7,
        2 => 256,
        3 => 0x9134,
        else => unreachable,
    };
}

fn regeneratedForFormat(size_format: u2) usize {
    return switch (size_format) {
        0 => 6,
        1 => 5,
        2 => 7,
        3 => 5,
    };
}

fn appendStreams(fixture: *Fixture, size_format: u2, stream_data_len: usize) void {
    if (size_format == 0) {
        fixture.appendRepeat(0xa7, stream_data_len);
        return;
    }
    std.debug.assert(stream_data_len >= 10);
    fixture.appendLittle(1, 2);
    fixture.appendLittle(2, 2);
    fixture.appendLittle(1, 2);
    fixture.appendRepeat(0xb8, stream_data_len - 6);
}

const BuiltLayout = struct {
    fixture: Fixture,
    header_len: usize,
    literal_len: usize,
    description_len: usize,
    count_len: usize,
};

fn buildLayoutFixture(kind: header.Kind, size_format: u2, count_len: usize) BuiltLayout {
    var fixture: Fixture = .{};
    const regenerated_size = regeneratedForFormat(size_format);
    const description_len: usize = if (kind == .compressed) 2 else 0;
    const stream_data_len: usize = if (size_format == 0) 10 else 12;
    const compressed_size = if (kind == .compressed or kind == .treeless)
        description_len + stream_data_len
    else
        0;
    const header_len = appendHeader(
        &fixture,
        kind,
        size_format,
        regenerated_size,
        compressed_size,
    );
    switch (kind) {
        .raw => fixture.appendRepeat(0x61, regenerated_size),
        .rle => fixture.appendByte(0x62),
        .compressed => {
            fixture.appendByte(128);
            fixture.appendByte(0x10);
            appendStreams(&fixture, size_format, stream_data_len);
        },
        .treeless => appendStreams(&fixture, size_format, stream_data_len),
    }
    const literal_len: usize = switch (kind) {
        .raw => regenerated_size,
        .rle => 1,
        .compressed, .treeless => compressed_size,
    };
    _ = appendCount(&fixture, count_len);
    fixture.appendByte(0xc9);
    fixture.appendByte(0xda);
    return .{
        .fixture = fixture,
        .header_len = header_len,
        .literal_len = literal_len,
        .description_len = description_len,
        .count_len = count_len,
    };
}

fn expectRange(range: source_input.Range, offset: u64, len: u64) !void {
    try std.testing.expectEqual(offset, range.offset);
    try std.testing.expectEqual(len, range.len);
}

fn expectLayout(
    layout: source_literals.Layout,
    built: *const BuiltLayout,
    kind: header.Kind,
    size_format: u2,
    base: u64,
) !void {
    try std.testing.expectEqual(kind, layout.kind);
    try std.testing.expectEqual(size_format, layout.size_format);
    try std.testing.expectEqual(regeneratedForFormat(size_format), layout.regenerated_size);
    try expectRange(layout.header_range, base, built.header_len);
    const literal_offset = base + built.header_len;
    try expectRange(layout.literal_payload, literal_offset, built.literal_len);
    const count_offset = literal_offset + built.literal_len;
    try std.testing.expectEqual(expectedCount(built.count_len), layout.sequence_count);
    try expectRange(layout.sequence_count_range, count_offset, built.count_len);
    try expectRange(layout.sequence_payload, count_offset + built.count_len, 2);

    switch (kind) {
        .raw, .rle => {
            try std.testing.expect(layout.tree_description == null);
            try std.testing.expect(layout.streams == .none);
            try std.testing.expectEqual(@as(usize, 0), layout.compressed_size);
        },
        .compressed, .treeless => {
            try std.testing.expectEqual(built.literal_len, layout.compressed_size);
            if (kind == .compressed) {
                try expectRange(layout.tree_description.?, literal_offset, built.description_len);
            } else try std.testing.expect(layout.tree_description == null);
            const stream_start = literal_offset + built.description_len;
            const stream_len = built.literal_len - built.description_len;
            if (size_format == 0) {
                try expectRange(layout.streams.one, stream_start, stream_len);
            } else {
                const streams = layout.streams.four;
                try expectRange(streams[0], stream_start + 6, 1);
                try expectRange(streams[1], stream_start + 7, 2);
                try expectRange(streams[2], stream_start + 9, 1);
                try expectRange(streams[3], stream_start + 10, stream_len - 10);
            }
        },
    }
}

fn differentialHeaders(comptime Support: type) !void {
    inline for (.{ header.Kind.raw, header.Kind.rle, header.Kind.compressed, header.Kind.treeless }) |kind| {
        inline for (0..4) |format_index| {
            const size_format: u2 = @intCast(format_index);
            var fixture: Fixture = .{};
            const regenerated_size = regeneratedForFormat(size_format);
            const compressed_size: usize = if (kind == .compressed or kind == .treeless)
                (if (size_format == 0) 7 else 19)
            else
                0;
            const header_len = appendHeader(
                &fixture,
                kind,
                size_format,
                regenerated_size,
                compressed_size,
            );
            const current = try header.parse(fixture.bytes());
            const legacy = try Support.parseHeader(fixture.bytes());
            try std.testing.expectEqual(kind, legacy.kind);
            try std.testing.expectEqual(size_format, legacy.size_format);
            try std.testing.expectEqual(header_len, legacy.encoded_len);
            try std.testing.expectEqual(current.regenerated_size, legacy.regenerated_size);
            try std.testing.expectEqual(current.compressed_size, legacy.compressed_size);
        }
    }
}

fn differentialCounts(comptime Support: type) !void {
    const wires = [_][]const u8{
        &.{0},
        &.{127},
        &.{ 128, 0x5a },
        &.{ 254, 0xff },
        &.{ 255, 0, 0 },
        &.{ 255, 0xff, 0xff },
    };
    for (wires) |wire| {
        const current = try sequence_count.parse(wire);
        const legacy = try Support.parseCount(wire);
        try std.testing.expectEqual(current, legacy.count);
        try std.testing.expectEqual(sequence_count.encodedLen(wire[0]), legacy.encoded_len);
    }
}

fn allKindsAndFormats() !void {
    inline for (.{ header.Kind.raw, header.Kind.rle, header.Kind.compressed, header.Kind.treeless }) |kind| {
        inline for (0..4) |format_index| {
            const size_format: u2 = @intCast(format_index);
            const built = buildLayoutFixture(kind, size_format, 1 + format_index % 3);
            var source = TrackingSource{ .bytes = built.fixture.bytes() };
            const block = try source_input.Range.init(source.source(6), 0, built.fixture.len);
            const layout = try source_literals.parseLayout(block, kind == .treeless);
            try expectLayout(layout, &built, kind, size_format, 0);
            try std.testing.expect(source.max_requested <= 6);
        }
    }
}

fn treeDescriptionBoundaries() !void {
    const cases = [_]struct { first: u8, description_len: usize }{
        .{ .first = 0, .description_len = 1 },
        .{ .first = 127, .description_len = 128 },
        .{ .first = 128, .description_len = 2 },
        .{ .first = 255, .description_len = 65 },
    };
    for (cases) |case| {
        var fixture: Fixture = .{};
        const header_len = appendHeader(&fixture, .compressed, 0, 3, case.description_len + 1);
        fixture.appendByte(case.first);
        fixture.appendRepeat(0x29, case.description_len);
        fixture.appendByte(0);
        var source = TrackingSource{ .bytes = fixture.bytes() };
        const block = try source_input.Range.init(source.source(6), 0, fixture.len);
        const layout = try source_literals.parseLayout(block, false);
        try expectRange(layout.tree_description.?, header_len, case.description_len);
        try expectRange(layout.streams.one, header_len + case.description_len, 1);
        try std.testing.expectEqual(@as(usize, 0), layout.sequence_count);
    }

    var truncated: Fixture = .{};
    _ = appendHeader(&truncated, .compressed, 0, 3, 10);
    truncated.appendByte(127);
    truncated.appendRepeat(0, 9);
    truncated.appendByte(0);
    var source = TrackingSource{ .bytes = truncated.bytes() };
    const block = try source_input.Range.init(source.source(6), 0, truncated.len);
    try std.testing.expectError(error.TruncatedFrame, source_literals.parseLayout(block, false));
}

fn fourStreamJumpBoundaries() !void {
    var exact: Fixture = .{};
    const exact_header = appendHeader(&exact, .treeless, 1, 3, 10);
    exact.appendLittle(1, 2);
    exact.appendLittle(2, 2);
    exact.appendLittle(1, 2);
    exact.appendRepeat(0x91, 4);
    exact.appendByte(0);
    var exact_source = TrackingSource{ .bytes = exact.bytes() };
    const exact_block = try source_input.Range.init(exact_source.source(6), 0, exact.len);
    const exact_layout = try source_literals.parseLayout(exact_block, true);
    const ranges = exact_layout.streams.four;
    try expectRange(ranges[0], exact_header + 6, 1);
    try expectRange(ranges[1], exact_header + 7, 2);
    try expectRange(ranges[2], exact_header + 9, 1);
    try expectRange(ranges[3], exact_header + 10, 0);

    var invalid: Fixture = .{};
    _ = appendHeader(&invalid, .treeless, 1, 3, 10);
    invalid.appendLittle(5, 2);
    invalid.appendLittle(5, 2);
    invalid.appendLittle(5, 2);
    invalid.appendRepeat(0x82, 4);
    invalid.appendByte(0);
    var invalid_source = TrackingSource{ .bytes = invalid.bytes() };
    const invalid_block = try source_input.Range.init(invalid_source.source(6), 0, invalid.len);
    try std.testing.expectError(error.CorruptFrame, source_literals.parseLayout(invalid_block, true));

    var short_after_tree: Fixture = .{};
    _ = appendHeader(&short_after_tree, .compressed, 1, 3, 10);
    short_after_tree.appendByte(134); // Five-byte direct tree description.
    short_after_tree.appendRepeat(0x33, 9);
    short_after_tree.appendByte(0);
    var short_source = TrackingSource{ .bytes = short_after_tree.bytes() };
    const short_block = try source_input.Range.init(short_source.source(6), 0, short_after_tree.len);
    try std.testing.expectError(error.CorruptFrame, source_literals.parseLayout(short_block, false));
}

fn countTiersAndTrailingLayer() !void {
    for (1..4) |count_len| {
        var fixture: Fixture = .{};
        _ = appendHeader(&fixture, .raw, 0, 0, 0);
        _ = appendCount(&fixture, count_len);
        fixture.appendByte(0xaa);
        fixture.appendByte(0xbb);
        var source = TrackingSource{ .bytes = fixture.bytes() };
        const block = try source_input.Range.init(source.source(3), 0, fixture.len);
        const layout = try source_literals.parseLayout(block, false);
        try std.testing.expectEqual(expectedCount(count_len), layout.sequence_count);
        try std.testing.expectEqual(@as(u64, count_len), layout.sequence_count_range.len);
        try std.testing.expectEqual(@as(u64, 2), layout.sequence_payload.len);
    }

    const bytes = [_]u8{ 0, 0, 0xde, 0xad, 0xbe };
    var source = TrackingSource{ .bytes = &bytes };
    const block = try source_input.Range.init(source.source(3), 0, bytes.len);
    const layout = try source_literals.parseLayout(block, false);
    try std.testing.expectEqual(@as(usize, 0), layout.sequence_count);
    try expectRange(layout.sequence_count_range, 1, 1);
    try expectRange(layout.sequence_payload, 2, 3);
}

fn shortReads() !void {
    const built = buildLayoutFixture(.compressed, 3, 3);
    for (1..4) |short_len| {
        var source = TrackingSource{
            .bytes = built.fixture.bytes(),
            .max_chunk = short_len,
        };
        const block = try source_input.Range.init(source.source(6), 0, built.fixture.len);
        const layout = try source_literals.parseLayout(block, false);
        try expectLayout(layout, &built, .compressed, 3, 0);
        try std.testing.expect(source.calls > 4);
        try std.testing.expect(source.max_requested <= 6);
    }
}

fn callbackFailures() !void {
    const built = buildLayoutFixture(.compressed, 3, 3);
    inline for (.{
        .{ SourceMode.zero, error.TruncatedFrame },
        .{ SourceMode.excessive, error.SourceReadFailed },
        .{ SourceMode.fail, error.SourceReadFailed },
    }) |case| {
        for (1..7) |fault_call| {
            var source = TrackingSource{
                .bytes = built.fixture.bytes(),
                .mode = case[0],
                .fault_call = fault_call,
            };
            const block = try source_input.Range.init(source.source(6), 0, built.fixture.len);
            try std.testing.expectError(case[1], source_literals.parseLayout(block, false));
            try std.testing.expectEqual(fault_call, source.calls);
        }
    }
}

fn wideBaseAndCanaries() !void {
    const built = buildLayoutFixture(.compressed, 2, 2);
    var storage: [1026]u8 = @splat(0x5c);
    @memcpy(storage[1..][0..built.fixture.len], built.fixture.bytes());
    storage[0] = 0x17;
    storage[built.fixture.len + 1] = 0xe8;
    const base = (@as(u64, 1) << 32) + 0x45_678;
    var source = TrackingSource{
        .bytes = storage[1..][0..built.fixture.len],
        .base_offset = base,
        .max_chunk = 2,
    };
    const block = try source_input.Range.init(source.source(6), base, built.fixture.len);
    const layout = try source_literals.parseLayout(block, false);
    try expectLayout(layout, &built, .compressed, 2, base);
    try std.testing.expect(source.min_observed_offset.? >= base);
    try std.testing.expect(source.max_observed_offset > std.math.maxInt(u32));
    try std.testing.expectEqual(@as(u8, 0x17), storage[0]);
    try std.testing.expectEqual(@as(u8, 0xe8), storage[built.fixture.len + 1]);
}

fn forbiddenPayloadsAreNeverRead() !void {
    inline for (.{ header.Kind.raw, header.Kind.rle, header.Kind.compressed, header.Kind.treeless }) |kind| {
        inline for (.{ @as(u2, 0), @as(u2, 1) }) |size_format| {
            const built = buildLayoutFixture(kind, size_format, 1);
            const literal_offset = built.header_len;
            const sequence_offset = literal_offset + built.literal_len + built.count_len;
            var forbidden_storage: [6]Span = undefined;
            var forbidden_len: usize = 0;
            switch (kind) {
                .raw, .rle => {
                    forbidden_storage[forbidden_len] = .{
                        .offset = literal_offset,
                        .len = built.literal_len,
                    };
                    forbidden_len += 1;
                },
                .compressed, .treeless => {
                    const stream_start = literal_offset + built.description_len;
                    const stream_len = built.literal_len - built.description_len;
                    if (size_format == 0) {
                        forbidden_storage[forbidden_len] = .{
                            .offset = stream_start,
                            .len = stream_len,
                        };
                        forbidden_len += 1;
                    } else {
                        forbidden_storage[forbidden_len] = .{
                            .offset = stream_start + 6,
                            .len = stream_len - 6,
                        };
                        forbidden_len += 1;
                    }
                },
            }
            forbidden_storage[forbidden_len] = .{ .offset = sequence_offset, .len = 2 };
            forbidden_len += 1;
            var source = TrackingSource{
                .bytes = built.fixture.bytes(),
                .forbidden = forbidden_storage[0..forbidden_len],
            };
            const block = try source_input.Range.init(source.source(6), 0, built.fixture.len);
            const layout = try source_literals.parseLayout(block, kind == .treeless);
            try expectLayout(layout, &built, kind, size_format, 0);
            try std.testing.expect(!source.forbidden_read);
        }
    }
}

fn truncationAndTreeState() !void {
    const treeless = buildLayoutFixture(.treeless, 0, 1);
    var tree_source = TrackingSource{ .bytes = treeless.fixture.bytes() };
    const tree_block = try source_input.Range.init(tree_source.source(6), 0, treeless.fixture.len);
    try std.testing.expectError(error.CorruptFrame, source_literals.parseLayout(tree_block, false));

    const full = buildLayoutFixture(.compressed, 1, 3);
    const required = full.header_len + full.literal_len + full.count_len;
    for (0..required) |len| {
        var source = TrackingSource{ .bytes = full.fixture.bytes()[0..len] };
        const block = try source_input.Range.init(source.source(6), 0, len);
        _ = source_literals.parseLayout(block, false) catch |err| {
            try std.testing.expect(err == error.TruncatedFrame or err == error.CorruptFrame);
            continue;
        };
        return error.TestUnexpectedResult;
    }
}

pub fn contracts(comptime Support: type) !void {
    try differentialHeaders(Support);
    try differentialCounts(Support);
    try allKindsAndFormats();
    try treeDescriptionBoundaries();
    try fourStreamJumpBoundaries();
    try countTiersAndTrailingLayer();
    try shortReads();
    try callbackFailures();
    try wideBaseAndCanaries();
    try forbiddenPayloadsAreNeverRead();
    try truncationAndTreeState();
}
