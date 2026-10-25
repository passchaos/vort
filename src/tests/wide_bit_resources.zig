const std = @import("std");
const br = @import("../br.zig");
const h = @import("wide_bit_helpers.zig");
const bits = h.bitstream;

test "Wide bit numeric byte geometry crosses the former bit address ceiling without allocating input" {
    const vectors = [_]struct { bytes: usize, expected: u64 }{
        .{ .bytes = 536870911, .expected = 4294967288 },
        .{ .bytes = 536870912, .expected = 4294967296 },
        .{ .bytes = 536870913, .expected = 4294967304 },
        .{ .bytes = 4294967295, .expected = 34359738360 },
    };
    for (vectors) |v| {
        const count = try h.count.fromBytes(v.bytes);
        try std.testing.expectEqual(@as(h.Count, v.expected), count);
        try std.testing.expectEqual(count, h.count.fromBytesAssumeBounded(v.bytes));
        try std.testing.expectEqual(count + 7, try h.count.position(v.bytes, 7));
        try std.testing.expectEqual(count + 7, h.count.positionAssumeBounded(v.bytes, 7));
        try std.testing.expectEqual(v.bytes, try h.count.floorBytes(count));
        try std.testing.expectEqual(v.bytes, try h.count.ceilBytes(count));
        try std.testing.expectEqual(@as(usize, 63), h.count.bounded(count, 63));
    }
    try std.testing.expect(bits.BitCount == h.Count);
}

test "Wide bit quotient remainder rounding and local narrowing stay checked at maximum integers" {
    for ([_]h.Count{ 0, 1, 7, 8, 9, 15, 16, 17, 4294967295, 4294967296, 4294967297 }) |value| {
        const independent: u128 = value;
        try std.testing.expectEqual(@as(usize, @intCast(independent / 8)), try h.count.floorBytes(value));
        try std.testing.expectEqual(@as(usize, @intCast((independent + 7) / 8)), try h.count.ceilBytes(value));
        try std.testing.expectEqual(@as(usize, @intCast(@min(independent, 17))), h.count.bounded(value, 17));
    }
    const maximum = std.math.maxInt(h.Count);
    if (@bitSizeOf(usize) < 64) {
        try std.testing.expectError(error.IntegerOverflow, h.count.toLocal(4294967296));
        try std.testing.expectEqual(std.math.maxInt(usize), try h.count.floorBytes(try h.count.fromBytes(std.math.maxInt(usize))));
        try std.testing.expectError(error.IntegerOverflow, h.count.ceilBytes(try h.count.fromBytes(std.math.maxInt(usize)) + 1));
        try std.testing.expectError(error.IntegerOverflow, h.count.floorBytes(maximum));
        try std.testing.expectError(error.IntegerOverflow, h.count.ceilBytes(maximum));
    } else {
        try std.testing.expectEqual(@as(usize, @intCast(@as(u128, maximum) / 8)), try h.count.floorBytes(maximum));
        try std.testing.expectEqual(@as(usize, @intCast((@as(u128, maximum) + 7) / 8)), try h.count.ceilBytes(maximum));
        try std.testing.expectError(error.IntegerOverflow, h.count.fromBytes(h.count.max_addressable_bytes + 1));
        try std.testing.expectEqual(maximum, try h.count.position(h.count.max_addressable_bytes, 7));
    }
    try std.testing.expectEqual(@as(usize, 0), h.count.bounded(maximum, 0));
}

test "Wide bit scalar numeric checkpoints report large positions without reading synthetic addresses" {
    // These are geometry checkpoints over a small real slice. They exercise
    // cursor arithmetic only, never read or peek at the synthetic byte index.
    for ([_]usize{ 536870911, 536870912, 536870913, std.math.maxInt(u32) - 1 }) |byte| {
        var reader = bits.BitReader.init(&h.bytes);
        reader.byte_index = byte;
        reader.bit_index = 7;
        reader.bit_len = try h.count.position(byte, 7);
        try std.testing.expectEqual(@as(h.Count, @intCast(@as(u128, byte) * 8 + 7)), reader.bitPosition());
        try std.testing.expectEqual(byte + 1, reader.byteOffset());
        try std.testing.expect(reader.hasBits(0));
        try std.testing.expect(!reader.hasBits(1));
    }
}

test "Wide bit buffered numeric consumed counts round offsets without addition overflow" {
    var reader = bits.BufferedBitReader.init(&h.bytes);
    const values = [_]h.Count{ 4294967295, 4294967296, 4294967304, 34359738359 };
    for (values) |value| {
        reader.consumed_bits = value;
        try std.testing.expectEqual(value, reader.bitPosition());
        try std.testing.expectEqual(@as(usize, @intCast((@as(u128, value) + 7) / 8)), reader.byteOffset());
    }
    reader.consumed_bits = if (@bitSizeOf(usize) == 64) std.math.maxInt(h.Count) else try h.count.fromBytes(std.math.maxInt(usize));
    try std.testing.expectEqual(@as(usize, @intCast((@as(u128, reader.consumed_bits) + 7) / 8)), reader.byteOffset());
    // No refill or read is attempted from these numeric checkpoints.
}

test "Wide bit chunk numeric positions and remaining geometry preserve wide bits and local byte indices" {
    for ([_]usize{ 536870911, 536870912, 536870913, std.math.maxInt(u32) - 1 }) |byte| {
        var chunked = try bits.ChunkedBitReader.init(&.{h.bytes[0..1]});
        var span = try bits.ChunkedSpanBitReader.init(&.{h.bytes[0..1]});
        inline for (.{ &chunked, &span }) |reader| {
            // State geometry only: this small backing cannot provide payload
            // at the numeric checkpoint and is never read by this test.
            reader.total_len = byte + 1;
            reader.byte_index = byte;
            reader.bit_index = 3;
            try std.testing.expectEqual(@as(h.Count, @intCast(@as(u128, byte) * 8 + 3)), reader.bitPosition());
            try std.testing.expectEqual(byte + 1, reader.byteOffset());
            try std.testing.expect(reader.hasBits(5));
            try std.testing.expect(!reader.hasBits(6));
            reader.byte_index = 0;
            reader.bit_index = 0;
            try std.testing.expect(reader.hasBits(63));
        }
    }
}

test "Wide bit Brotli numeric staged endpoints synchronize without touching large backing addresses" {
    for ([_]usize{ 536870911, 536870912, 536870913, std.math.maxInt(u32) - 1 }) |byte| {
        var source = bits.BitReader.init(&h.bytes);
        source.byte_index = byte;
        source.bit_len = try h.count.fromBytes(byte + 1);
        var fast = h.fast.Reader.initFrom(source);
        try std.testing.expectEqual(@as(h.Count, @intCast(@as(u128, byte) * 8)), fast.bitPosition());
        // Algebraically stage five bits from the synthetic final byte. This
        // checks endpoint subtraction/sync only and performs no payload read.
        fast.next_byte = byte + 1;
        fast.bit_count = 5;
        const expected: h.Count = @intCast(@as(u128, byte) * 8 + 3);
        try std.testing.expectEqual(expected, fast.bitPosition());
        fast.syncTo(&source);
        try std.testing.expectEqual(byte, source.byte_index);
        try std.testing.expectEqual(@as(u3, 3), source.bit_index);
        try std.testing.expectEqual(expected, source.bitPosition());
    }
}

test "Wide bit stored public bounds accept 512 MiB numeric lengths with independent format costs" {
    for (h.frozen_bounds) |sample| {
        if (sample.standard > std.math.maxInt(usize)) {
            try std.testing.expectError(error.IntegerOverflow, br.encodedStoredStreamBound(@intCast(sample.input)));
        } else {
            try std.testing.expectEqual(@as(usize, @intCast(sample.standard)), try br.encodedStoredStreamBound(@intCast(sample.input)));
        }
        if (sample.large_metadata <= std.math.maxInt(usize))
            try std.testing.expectEqual(@as(usize, @intCast(sample.large_metadata)), try br.encodedStoredStreamBoundWithOptions(@intCast(sample.input), .{ .large_window = true, .window_bits = 30, .metadata = "wide-meta" }));
    }
    for ([_]usize{ 536870911, 536870912, 536870913 }) |len| {
        for ([_]br.StoredStreamOptions{ .{}, .{ .window_bits = 10 }, .{ .large_window = true, .window_bits = 30, .metadata = "wide-meta" } }) |options| {
            const expected = h.storedBound(len, options.window_bits, options.large_window, options.metadata.len, 16777216);
            try std.testing.expectEqual(@as(usize, @intCast(expected)), try br.encodedStoredStreamBoundWithOptions(len, options));
        }
    }
}

test "Wide bit planned public bounds and actual chunk boundaries preserve independent stored geometry" {
    for ([_]usize{ 536870911, 536870912, 536870913 }) |len| {
        const expected = h.storedBound(len, 16, false, 0, 32768);
        try std.testing.expectEqual(@as(usize, @intCast(expected)), try br.encodedPlannedStreamBound(len));
    }
    var input: [65537]u8 = undefined;
    @memset(&input, 'x');
    const chunks = [_][]const u8{ input[0..1], "", input[1..32769], input[32769..] };
    const stored = try br.encodedStoredStreamChunksBound(&chunks);
    const planned = try br.encodedPlannedStreamChunksBound(&chunks);
    // Each chunk is independently framed: three short stored headers plus a
    // final marker. Prefix WBITS=16 shares the first aligned header byte.
    try std.testing.expectEqual(@as(usize, input.len + 3 * 3 + 1), stored);
    try std.testing.expectEqual(stored, planned);
    var output: [65560]u8 = undefined;
    const written = try br.encodeStoredStreamChunksInto(&chunks, &output);
    try std.testing.expectEqual(stored, written);
    const decoded = try br.decodeStreamAlloc(std.testing.allocator, output[0..written]);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
}

test "Wide bit impossible output geometry and invalid formats fail before resource profiles change" {
    var profile: br.EncodeMemoryProfile = .{ .available = true, .peak_requested_bytes = 113, .live_requested_bytes = 79, .limit = 211 };
    const sentinel = profile;
    const maximum = std.math.maxInt(usize);
    try std.testing.expectError(error.IntegerOverflow, br.encodedStoredStreamBound(maximum));
    try std.testing.expectError(error.InvalidBlockPlan, br.encodedStoredStreamBoundWithOptions(maximum, .{ .window_bits = 9, .memory_profile = &profile, .max_total_working_memory = 0 }));
    try std.testing.expectEqualDeep(sentinel, profile);
    const oversized_metadata: []const u8 = @as([*]const u8, @ptrFromInt(1))[0 .. br.max_metadata_meta_block_len + 1];
    const invalid: br.StoredStreamOptions = .{ .metadata = oversized_metadata, .memory_profile = &profile, .max_total_working_memory = 0 };
    try std.testing.expectError(error.InvalidBlockPlan, br.encodedStoredStreamBoundWithOptions(maximum, invalid));
    var tracked = h.TrackingAllocator.init(std.testing.allocator);
    tracked.fail_alloc_after = 0;
    try std.testing.expectError(error.InvalidBlockPlan, br.encodeStoredStreamWithOptionsAlloc(tracked.allocator(), h.plain, invalid));
    try std.testing.expectEqual(@as(usize, 0), tracked.alloc_attempts);
    try std.testing.expectEqualDeep(sentinel, profile);
}

test "Wide bit small real stored quota and OOM behavior remains precise after address widening" {
    var output: [256]u8 = @splat(0xa5);
    var profile: br.EncodeMemoryProfile = .{};
    const written = try br.encodeStoredStreamWithOptionsInto(h.plain, &output, .{ .max_total_working_memory = 0, .memory_profile = &profile });
    try std.testing.expectEqual(@as(usize, h.plain.len + 4), written);
    try h.untouched(output[written..]);
    try std.testing.expect(profile.available);
    try std.testing.expectEqual(@as(usize, 0), profile.peak_requested_bytes);
    var tracked = h.TrackingAllocator.init(std.testing.allocator);
    tracked.fail_alloc_after = 0;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, br.encodeStoredStreamWithOptionsAlloc(tracked.allocator(), h.plain, .{ .max_total_working_memory = 0 }));
    try std.testing.expectEqual(@as(usize, 0), tracked.alloc_attempts);
    try std.testing.expectError(error.OutOfMemory, br.encodeStoredStreamWithOptionsAlloc(tracked.allocator(), h.plain, .{}));
    try std.testing.expectEqual(@as(usize, 1), tracked.alloc_attempts);
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
}
