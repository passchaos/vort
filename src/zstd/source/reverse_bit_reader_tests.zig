const std = @import("std");
const byte_source = @import("../../io/source.zig");
const source_input = @import("input.zig");
const source_bits = @import("reverse_bit_reader.zig");
const slice_bits = @import("../sequence/bit_reader.zig");

const SourceMode = enum { normal, zero, excessive, fail };

const TrackingSource = struct {
    bytes: []const u8,
    base_offset: u64 = 0,
    max_chunk: usize = std.math.maxInt(usize),
    mode: SourceMode = .normal,
    calls: usize = 0,
    max_requested: usize = 0,
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
        switch (self.mode) {
            .zero => return 0,
            .excessive => return output.len + 1,
            .fail => return error.SourceReadFailed,
            .normal => {},
        }
        if (offset < self.base_offset) return error.SourceReadFailed;
        const relative = std.math.cast(usize, offset - self.base_offset) orelse
            return error.SourceReadFailed;
        if (relative >= self.bytes.len) return 0;
        const amount = @min(self.max_chunk, @min(output.len, self.bytes.len - relative));
        @memcpy(output[0..amount], self.bytes[relative..][0..amount]);
        return amount;
    }
};

fn fillPattern(bytes: []u8, seed: u64) void {
    var state = seed;
    for (bytes) |*byte| {
        state = state *% 6364136223846793005 +% 1442695040888963407;
        byte.* = @truncate(state >> 37);
    }
}

fn setMarker(bytes: []u8, marker: u3) void {
    const marker_mask: u8 = @as(u8, 1) << marker;
    const payload_mask: u8 = marker_mask - 1;
    bytes[bytes.len - 1] = marker_mask | (bytes[bytes.len - 1] & payload_mask);
}

fn expectReadEqual(expected: *slice_bits.Reader, actual: *source_bits.Reader, width: u8) !void {
    const expected_result = expected.read(width);
    const actual_result = actual.read(width);
    if (expected_result) |value| {
        try std.testing.expectEqual(value, try actual_result);
    } else |expected_error| {
        if (actual_result) |_| {
            return error.TestExpectedError;
        } else |actual_error| {
            try std.testing.expect(expected_error == actual_error);
        }
    }
}

fn expectPeekEqual(expected: slice_bits.Reader, actual: *source_bits.Reader, width: u8) !void {
    var expected_copy = expected;
    const expected_result = expected_copy.read(width);
    const actual_result = actual.peek(width);
    if (expected_result) |value| {
        try std.testing.expectEqual(value, try actual_result);
    } else |expected_error| {
        if (actual_result) |_| {
            return error.TestExpectedError;
        } else |actual_error| {
            try std.testing.expect(expected_error == actual_error);
        }
    }
    try std.testing.expectEqual(expected.available(), actual.available());
}

test "Zstd source reverse exhaustive pages alignments markers and widths match slice reader" {
    var bytes: [37]u8 = undefined;
    var page_storage: [4096 + 2]u8 = undefined;
    const page_lengths = [_]usize{ 9, 10, 17, 31, 4096 };

    for (page_lengths) |page_len| {
        for (0..8) |marker_index| {
            fillPattern(&bytes, 0x8e55_119a_6b03_42d1 + @as(u64, @intCast(marker_index)));
            setMarker(&bytes, @intCast(marker_index));
            for (0..8) |alignment| {
                for (0..@bitSizeOf(usize) + 1) |width_index| {
                    @memset(&page_storage, 0xd7);
                    page_storage[0] = 0x39;
                    page_storage[page_len + 1] = 0xc6;
                    var source = TrackingSource{ .bytes = &bytes };
                    const range = try source_input.Range.init(source.source(page_len), 0, bytes.len);
                    var actual = try source_bits.Reader.init(range, page_storage[1 .. page_len + 1]);
                    var expected = try slice_bits.Reader.init(&bytes);
                    if (alignment != 0) {
                        try actual.skip(@intCast(alignment));
                        try expected.skip(@intCast(alignment));
                    }
                    const width: u8 = @intCast(width_index);
                    try expectPeekEqual(expected, &actual, width);
                    try expectReadEqual(&expected, &actual, width);
                    try std.testing.expectEqual(expected.available(), actual.available());
                    try std.testing.expectEqual(@as(u8, 0x39), page_storage[0]);
                    try std.testing.expectEqual(@as(u8, 0xc6), page_storage[page_len + 1]);
                    try std.testing.expect(source.max_requested <= page_len);
                }
            }
        }
    }
}

test "Zstd source reverse random mixed operations match slice reader on every page size" {
    var bytes: [32 * 1024 + 13]u8 = undefined;
    fillPattern(&bytes, 0xf7a2_04d9_518b_c36e);
    bytes[bytes.len - 1] |= 0x80;
    var page_storage: [4096]u8 = undefined;
    var prng = std.Random.DefaultPrng.init(0xc571_90d3_8ba4_7761);
    const random = prng.random();

    for ([_]usize{ 9, 10, 17, 31, 4096 }) |page_len| {
        @memset(&page_storage, 0xa5);
        var source = TrackingSource{ .bytes = &bytes };
        const range = try source_input.Range.init(source.source(page_len), 0, bytes.len);
        var actual = try source_bits.Reader.init(range, page_storage[0..page_len]);
        var expected = try slice_bits.Reader.init(&bytes);
        var operation: usize = 0;
        while (expected.available() != 0) : (operation += 1) {
            try std.testing.expectEqual(expected.available(), actual.available());
            const maximum = @min(@as(usize, @bitSizeOf(usize)), expected.available());
            const width: u8 = @intCast(1 + random.uintLessThan(usize, maximum));
            try expectPeekEqual(expected, &actual, width);
            switch (operation % 4) {
                0 => try expectReadEqual(&expected, &actual, width),
                1 => {
                    try expected.skip(width);
                    try actual.skip(width);
                },
                2 => {
                    const small: u4 = @intCast(@min(@as(usize, 15), width));
                    try std.testing.expectEqual(try expected.readSmall(small), try actual.readSmall(small));
                },
                else => {
                    const requested: u4 = @intCast(random.uintLessThan(u8, 16));
                    const expected_value = try expected.readSmallAvailable(requested);
                    const actual_value = try actual.readSmallAvailable(requested);
                    try std.testing.expectEqual(expected_value.count, actual_value.count);
                    try std.testing.expectEqual(expected_value.value, actual_value.value);
                    if (actual_value.count == 0) {
                        try expected.skip(width);
                        try actual.skip(width);
                    }
                },
            }
        }
        try actual.expectEnd();
        try expected.expectEnd();
        const snapshot = actual.snapshot();
        try std.testing.expect(snapshot.page_loads > 1);
        try std.testing.expect(snapshot.bytes_loaded >= bytes.len);
        try std.testing.expect(snapshot.descending_loads > 0);
        try std.testing.expectEqual(page_len, snapshot.page_capacity);
        try std.testing.expect(snapshot.live_page_bytes <= page_len);
        try std.testing.expect(snapshot.page_capacity < bytes.len);
        try std.testing.expect(source.max_requested <= page_len);
    }
}

test "Zstd source reverse fields refill across page boundaries without retaining the range" {
    var bytes: [257]u8 = undefined;
    fillPattern(&bytes, 0x1978_55a6_c21d_0bf4);
    bytes[bytes.len - 1] = 0xd3;
    var source = TrackingSource{ .bytes = &bytes };
    const range = try source_input.Range.init(source.source(9), 0, bytes.len);
    var page: [9]u8 = @splat(0xcc);
    var actual = try source_bits.Reader.init(range, &page);
    var expected = try slice_bits.Reader.init(&bytes);
    const widths = [_]u8{ 3, 17, 64, 5, 29, 1, 47, 8, 63, 11 };
    var index: usize = 0;
    while (expected.available() != 0) : (index += 1) {
        const selected: u8 = @intCast(@min(expected.available(), widths[index % widths.len]));
        try expectPeekEqual(expected, &actual, selected);
        try expectReadEqual(&expected, &actual, selected);
    }
    const snapshot = actual.snapshot();
    try std.testing.expect(snapshot.page_loads > 20);
    try std.testing.expect(snapshot.descending_loads + 1 == snapshot.page_loads);
    try std.testing.expect(snapshot.bytes_loaded > bytes.len);
    try std.testing.expectEqual(@as(usize, 9), snapshot.page_capacity);
    try std.testing.expect(snapshot.live_page_bytes <= snapshot.page_capacity);
    try std.testing.expect(source.max_requested <= page.len);
}

test "Zstd source reverse completes one two and three byte callback reads" {
    var bytes: [193]u8 = undefined;
    fillPattern(&bytes, 0xa88f_6d11_27ea_5039);
    bytes[bytes.len - 1] |= 0x80;
    for (1..4) |short_len| {
        var source = TrackingSource{ .bytes = &bytes, .max_chunk = short_len };
        const range = try source_input.Range.init(source.source(31), 0, bytes.len);
        var page: [31]u8 = @splat(0x55);
        var actual = try source_bits.Reader.init(range, &page);
        var expected = try slice_bits.Reader.init(&bytes);
        while (expected.available() != 0) {
            const width: u8 = @intCast(@min(@as(usize, 23), expected.available()));
            try expectReadEqual(&expected, &actual, width);
        }
        try actual.expectEnd();
        try std.testing.expect(source.calls > actual.snapshot().page_loads);
        try std.testing.expect(source.max_requested <= page.len);
    }
}

test "Zstd source reverse rejects undersized page before any source callback" {
    const bytes = [_]u8{0x80};
    var source = TrackingSource{ .bytes = &bytes };
    const range = try source_input.Range.init(source.source(8), 0, bytes.len);
    var short_page: [source_bits.minimum_page_len - 1]u8 = @splat(0xa5);
    try std.testing.expectError(error.OutputTooSmall, source_bits.Reader.init(range, &short_page));
    try std.testing.expectEqual(@as(usize, 0), source.calls);
    for (short_page) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

test "Zstd source reverse uses nonzero synthetic offsets beyond four GiB" {
    var bytes: [113]u8 = undefined;
    fillPattern(&bytes, 0x43b9_17fc_ee02_75a6);
    bytes[bytes.len - 1] |= 0x80;
    const base = (@as(u64, 1) << 32) + 0x12_345;
    var source = TrackingSource{ .bytes = &bytes, .base_offset = base, .max_chunk = 3 };
    const range = try source_input.Range.init(source.source(17), base, bytes.len);
    var page: [17]u8 = undefined;
    var actual = try source_bits.Reader.init(range, &page);
    var expected = try slice_bits.Reader.init(&bytes);
    while (expected.available() != 0) {
        const width: u8 = @intCast(@min(@as(usize, 31), expected.available()));
        try expectReadEqual(&expected, &actual, width);
    }
    const snapshot = actual.snapshot();
    try std.testing.expect(source.min_observed_offset.? >= base);
    try std.testing.expect(source.max_observed_offset > std.math.maxInt(u32));
    try std.testing.expect(snapshot.last_page_offset.? >= base);
    try std.testing.expect(snapshot.descending_loads > 0);
}

test "Zstd source reverse maps zero excessive and failed callbacks" {
    const bytes = [_]u8{0x80};
    inline for (.{
        .{ SourceMode.zero, error.TruncatedFrame },
        .{ SourceMode.excessive, error.SourceReadFailed },
        .{ SourceMode.fail, error.SourceReadFailed },
    }) |case| {
        var source = TrackingSource{ .bytes = &bytes, .mode = case[0] };
        const range = try source_input.Range.init(source.source(9), 0, bytes.len);
        var page: [9]u8 = undefined;
        try std.testing.expectError(case[1], source_bits.Reader.init(range, &page));
        try std.testing.expectEqual(@as(usize, 1), source.calls);
    }
}

test "Zstd source reverse range rejects overflow and every out of bounds access" {
    const bytes = [_]u8{ 0x11, 0x22, 0x80 };
    var source = TrackingSource{ .bytes = &bytes };
    const input = source.source(9);
    try std.testing.expectError(error.IntegerOverflow, source_input.Range.init(input, std.math.maxInt(u64), 2));
    try std.testing.expectError(error.TruncatedFrame, source_input.Range.init(input, 2, 2));
    const range = try source_input.Range.init(input, 1, 2);
    try std.testing.expectEqual(@as(u64, 3), try range.end());
    try std.testing.expectError(error.IntegerOverflow, range.subrange(std.math.maxInt(u64), 2));
    try std.testing.expectError(error.TruncatedFrame, range.subrange(1, 2));
    var output: [2]u8 = undefined;
    try std.testing.expectError(error.IntegerOverflow, range.readExact(std.math.maxInt(u64), output[0..1]));
    try std.testing.expectError(error.TruncatedFrame, range.readExact(1, &output));
    try std.testing.expectError(error.TruncatedFrame, range.byte(2));
    const impossible = source_input.Range{ .source = input, .offset = std.math.maxInt(u64), .len = 1 };
    try std.testing.expectError(error.IntegerOverflow, impossible.end());
    try std.testing.expectEqual(@as(usize, 0), source.calls);
}

test "Zstd source reverse page is poison safe reusable and canary bounded" {
    var first: [79]u8 = undefined;
    var second: [79]u8 = undefined;
    fillPattern(&first, 0xe6b2_a039_117c_8d54);
    fillPattern(&second, 0x31c7_5afe_9042_d816);
    first[first.len - 1] = 0xa5;
    second[second.len - 1] = 0xe3;
    var storage: [19]u8 = @splat(0x4d);

    inline for (.{ &first, &second }) |bytes| {
        @memset(storage[1..18], 0xde);
        storage[0] = 0x71;
        storage[18] = 0x8e;
        var source = TrackingSource{ .bytes = bytes };
        const range = try source_input.Range.init(source.source(17), 0, bytes.len);
        var actual = try source_bits.Reader.init(range, storage[1..18]);
        var expected = try slice_bits.Reader.init(bytes);
        while (expected.available() != 0) {
            const width: u8 = @intCast(@min(@as(usize, 13), expected.available()));
            try expectReadEqual(&expected, &actual, width);
        }
        try actual.expectEnd();
        try std.testing.expectEqual(@as(u8, 0x71), storage[0]);
        try std.testing.expectEqual(@as(u8, 0x8e), storage[18]);
        try std.testing.expect(source.max_requested <= 17);
    }
}

test "Zstd source reverse poisoned stale page is fully replaced on descending refill" {
    var bytes: [101]u8 = undefined;
    fillPattern(&bytes, 0x741b_ca09_85e3_2d6f);
    bytes[bytes.len - 1] = 0xf1;
    var source = TrackingSource{ .bytes = &bytes };
    const range = try source_input.Range.init(source.source(9), 0, bytes.len);
    var storage: [11]u8 = @splat(0x3c);
    var actual = try source_bits.Reader.init(range, storage[1..10]);
    var expected = try slice_bits.Reader.init(&bytes);
    var refills: usize = 0;
    while (expected.available() > 73) {
        try actual.skip(72);
        try expected.skip(72);
        @memset(storage[1..10], 0xe7);
        try expectReadEqual(&expected, &actual, 1);
        refills += 1;
        try std.testing.expectEqual(@as(u8, 0x3c), storage[0]);
        try std.testing.expectEqual(@as(u8, 0x3c), storage[10]);
    }
    try std.testing.expect(refills > 8);
    try std.testing.expect(actual.snapshot().descending_loads >= refills);
}

test "Zstd source reverse reports marker truncation corruption and width errors" {
    var page: [9]u8 = undefined;
    const empty = [_]u8{};
    var empty_source = TrackingSource{ .bytes = &empty };
    const empty_range = try source_input.Range.init(empty_source.source(9), 0, 0);
    try std.testing.expectError(error.TruncatedFrame, source_bits.Reader.init(empty_range, &page));
    try std.testing.expectEqual(@as(usize, 0), empty_source.calls);

    const zero = [_]u8{0};
    var zero_source = TrackingSource{ .bytes = &zero };
    const zero_range = try source_input.Range.init(zero_source.source(9), 0, 1);
    try std.testing.expectError(error.CorruptFrame, source_bits.Reader.init(zero_range, &page));

    const valid = [_]u8{ 0x53, 0x80 };
    var valid_source = TrackingSource{ .bytes = &valid };
    const valid_range = try source_input.Range.init(valid_source.source(9), 0, valid.len);
    var reader = try source_bits.Reader.init(valid_range, &page);
    const too_wide: u8 = @bitSizeOf(usize) + 1;
    try std.testing.expectError(error.CorruptFrame, reader.read(too_wide));
    try std.testing.expectError(error.CorruptFrame, reader.peek(too_wide));
    try std.testing.expectError(error.CorruptFrame, reader.expectEnd());
    const remaining: u8 = @intCast(reader.available());
    try reader.skip(remaining);
    try reader.expectEnd();
    try std.testing.expectError(error.TruncatedFrame, reader.read(1));
    try std.testing.expectError(error.TruncatedFrame, reader.skip(1));
}
