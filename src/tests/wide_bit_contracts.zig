const std = @import("std");
const br = @import("../br.zig");
const h = @import("wide_bit_helpers.zig");
const bits = h.bitstream;

test "Wide bit archived stored and planned wires remain exact across native readers" {
    const a = std.testing.allocator;
    const chunks = [_][]const u8{ h.plain[0..17], "", h.plain[17..] };
    for (h.frozen_wires) |sample| {
        const expected = try h.frozenAlloc(a, sample);
        defer a.free(expected);
        const actual = switch (sample.api) {
            .stored => try br.encodeStoredStreamAlloc(a, h.plain),
            .stored_chunks => try br.encodeStoredStreamChunksWithOptionsAlloc(a, &chunks, .{ .metadata = "wide-meta", .window_bits = 10 }),
            .stored_large => try br.encodeStoredStreamWithOptionsAlloc(a, h.plain, .{ .metadata = "wide-meta", .large_window = true, .window_bits = 30 }),
            .planned_balanced => try br.encodePlannedStreamWithOptionsAlloc(a, h.plain, .{ .level = .balanced }),
            .planned_chunks => try br.encodePlannedStreamChunksWithOptionsAlloc(a, &chunks, .{}),
        };
        defer a.free(actual);
        try std.testing.expectEqualSlices(u8, expected, actual);
        const decoded = try br.decodeStreamAllocWithOptions(a, actual, .{ .allow_large_window = sample.api == .stored_large });
        defer a.free(decoded);
        try std.testing.expectEqualSlices(u8, h.plain, decoded);
    }
}

test "Wide bit native layouts retain archived offsets while narrow targets widen whole positions only" {
    try h.expectNativeLayout(bits.BitReader, h.scalar_layout);
    try h.expectNativeLayout(bits.BufferedBitReader, h.buffered_layout);
    try h.expectNativeLayout(bits.ChunkedBitReader, h.chunked_layout);
    try h.expectNativeLayout(bits.ChunkedSpanBitReader, h.span_layout);
    try h.expectNativeLayout(h.fast.Reader, h.fast_layout);
    try std.testing.expect(@TypeOf(@as(bits.BitReader, undefined).bit_len) == h.Count);
    try std.testing.expect(@TypeOf(@as(bits.BufferedBitReader, undefined).consumed_bits) == h.Count);
    inline for (.{ bits.BitReader, bits.BufferedBitReader, bits.ChunkedBitReader, bits.ChunkedSpanBitReader }) |T| {
        try std.testing.expect(@TypeOf(@as(T, undefined).byte_index) == usize);
        try std.testing.expect(@TypeOf(@as(T, undefined).bitPosition()) == h.Count);
    }
    inline for (.{ bits.BufferedBitReader, bits.ChunkedBitReader, bits.ChunkedSpanBitReader, h.fast.Reader }) |T|
        try std.testing.expect(@TypeOf(@as(T, undefined).bit_count) == usize);
    try std.testing.expect(@TypeOf(@as(h.fast.Reader, undefined).next_byte) == usize);
    try std.testing.expect(@TypeOf(@as(h.fast.Reader, undefined).bit_len) == h.Count);
    try std.testing.expect(h.Count == if (@bitSizeOf(usize) < 64) u64 else usize);
}

test "Wide bit archived mixed values and cursor checkpoints hold for all five readers" {
    var scalar = bits.BitReader.init(&h.bytes);
    var buffered = bits.BufferedBitReader.init(&h.bytes);
    var storage: [33][]const u8 = undefined;
    const chunks = h.chunksFor(.uneven, &h.bytes, &storage);
    var chunked = try bits.ChunkedBitReader.init(chunks);
    var span = try bits.ChunkedSpanBitReader.init(chunks);
    var fast = h.fast.Reader.initFrom(scalar);
    for (h.frozen_cursor) |sample| {
        inline for (.{ &scalar, &buffered, &chunked, &span }) |reader| {
            try std.testing.expectEqual(sample.value, try reader.readBits(u32, sample.width));
            try h.expectPosition(reader.*, sample.position);
        }
        try std.testing.expectEqual(sample.value, try fast.readBits(u32, sample.width));
        try std.testing.expectEqual(@as(h.Count, sample.position), fast.bitPosition());
        var synced = bits.BitReader.init(&h.bytes);
        fast.syncTo(&synced);
        try h.expectPosition(synced, sample.position);
    }
}

test "Wide bit scalar complete probes and reads agree with a one bit oracle at every alignment" {
    for (0..8) |start| {
        for ([_]u6{ 0, 1, 7, 8, 9, 15, 16, 24, 31, 32, 55, 63 }) |width| {
            var scalar = bits.BitReader.init(&h.bytes);
            scalar.bit_index = @intCast(start);
            const expected = h.oraclePadded(&h.bytes, h.bytes.len * 8, start, width);
            try std.testing.expectEqual(expected, scalar.peekBitsPadded(u64, width));
            try std.testing.expectEqual(expected, try scalar.peekBits(u64, width));
            try h.expectPosition(scalar, start);
            try std.testing.expectEqual(expected, try scalar.readBits(u64, width));
            try h.expectPosition(scalar, start + width);
        }
    }
}

test "Wide bit partial scalar padding hides real high bytes beyond every logical endpoint" {
    const dirty = [_]u8{ 0xad, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff };
    for (0..65) |logical| {
        for (0..logical + 1) |start| {
            var scalar = bits.BitReader.initBitLength(&dirty, @intCast(logical));
            scalar.byte_index = start / 8;
            scalar.bit_index = @intCast(start % 8);
            for ([_]u6{ 0, 1, 9, 16, 24, 32, 63 }) |width| {
                try std.testing.expectEqual(h.oraclePadded(&dirty, logical, start, width), scalar.peekBitsPadded(u64, width));
                try h.expectPosition(scalar, start);
            }
            try std.testing.expectEqual(@as(u9, @intCast(h.oraclePadded(&dirty, logical, start, 9))), scalar.peekBits9Padded());
        }
    }
}

test "Wide bit partial scalar and Brotli failures retain logical cursor after probes and invalid widths" {
    const dirty = [_]u8{ 0xff, 0xff, 0xff, 0xff, 0xff };
    for (1..32) |logical| {
        var scalar = bits.BitReader.initBitLength(&dirty, @intCast(logical));
        try scalar.skipBits(@intCast(logical - 1));
        var fast = h.fast.Reader.initFrom(scalar);
        _ = scalar.peekBitsPadded(u32, 24);
        _ = fast.peekBitsPadded(u32, 24);
        try std.testing.expectError(error.TruncatedFrame, scalar.readBits(u32, 2));
        try std.testing.expectError(error.TruncatedFrame, fast.readBits(u32, 2));
        try h.expectPosition(scalar, logical - 1);
        try std.testing.expectEqual(@as(h.Count, logical - 1), fast.bitPosition());
        try std.testing.expectError(error.CorruptFrame, scalar.readBits(u8, 9));
        try std.testing.expectError(error.CorruptFrame, fast.readBits(u8, 9));
        try std.testing.expectEqual(@as(u32, 1), try scalar.readBits(u32, 1));
        try std.testing.expectEqual(@as(u32, 1), try fast.readBits24StagedFirst(1));
        try std.testing.expectEqual(@as(u32, 0), try scalar.readBits(u32, 0));
        try std.testing.expectEqual(@as(u32, 0), try fast.readBits(u32, 0));
        try std.testing.expectError(error.TruncatedFrame, scalar.skipBits(1));
        try std.testing.expectError(error.TruncatedFrame, fast.readBits(u32, 1));
        try std.testing.expectEqual(@as(h.Count, logical), fast.bitPosition());
    }
}

test "Wide bit Brotli hot probes staged fields and synchronization match the independent oracle" {
    for (0..8) |start| {
        for ([_]u6{ 1, 7, 8, 9, 10, 15, 16, 24, 31, 32 }) |width| {
            var scalar = bits.BitReader.init(&h.bytes);
            scalar.bit_index = @intCast(start);
            var fast = h.fast.Reader.initFrom(scalar);
            const expected = h.oraclePadded(&h.bytes, h.bytes.len * 8, start, width);
            try std.testing.expectEqual(expected, fast.peekBitsPadded(u64, width));
            try std.testing.expectEqual(@as(u9, @intCast(h.oraclePadded(&h.bytes, h.bytes.len * 8, start, 9))), fast.peekBits9Padded());
            try std.testing.expectEqual(@as(u10, @intCast(h.oraclePadded(&h.bytes, h.bytes.len * 8, start, 10))), fast.peekBits10Padded());
            const value: u32 = if (width <= 24) try fast.readBits24StagedFirst(@intCast(width)) else try fast.readBits(u32, width);
            try std.testing.expectEqual(@as(u32, @intCast(expected)), value);
            fast.syncTo(&scalar);
            try h.expectPosition(scalar, start + width);
        }
    }
    const dirty = [_]u8{ 0xad, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff };
    for (0..65) |logical| {
        for (0..logical + 1) |start| {
            var scalar = bits.BitReader.initBitLength(&dirty, @intCast(logical));
            scalar.byte_index = start / 8;
            scalar.bit_index = @intCast(start % 8);
            var fast = h.fast.Reader.initFrom(scalar);
            try std.testing.expectEqual(h.oraclePadded(&dirty, logical, start, 32), fast.peekBitsPadded(u64, 32));
            try std.testing.expectEqual(@as(h.Count, start), fast.bitPosition());
        }
    }
}

test "Wide bit buffered word refill and wide fields preserve independent values without overconsumption" {
    for (0..8) |start| {
        for ([_]u6{ 0, 1, 7, 8, 9, 16, 24, 31, 32, 55, 63 }) |width| {
            var buffered = bits.BufferedBitReader.init(&h.bytes);
            try buffered.skipBits(@intCast(start));
            const expected = h.oraclePadded(&h.bytes, h.bytes.len * 8, start, width);
            try std.testing.expectEqual(expected, buffered.peekBitsPadded(u64, width));
            try h.expectPosition(buffered, start);
            try std.testing.expectEqual(expected, try buffered.readBits(u64, width));
            try h.expectPosition(buffered, start + width);
            try std.testing.expectEqual(h.oraclePadded(&h.bytes, h.bytes.len * 8, start + width, 9), try buffered.readBits(u64, 9));
            try h.expectPosition(buffered, start + width + 9);
        }
    }
}

test "Wide bit both chunk readers match independent probes in one byte and empty chunk layouts" {
    var storage: [33][]const u8 = undefined;
    const chunks = h.chunksFor(.bytes, &h.bytes, &storage);
    for (0..8) |start| {
        for ([_]u6{ 0, 1, 9, 16, 24, 32, 55, 63 }) |width| {
            var chunked = try bits.ChunkedBitReader.init(chunks);
            var span = try bits.ChunkedSpanBitReader.init(chunks);
            inline for (.{ &chunked, &span }) |reader| {
                try reader.skipBits(@intCast(start));
                const expected = h.oraclePadded(&h.bytes, h.bytes.len * 8, start, width);
                try std.testing.expectEqual(expected, reader.peekBitsPadded(u64, width));
                try h.expectPosition(reader.*, start);
                try std.testing.expectEqual(expected, try reader.readBits(u64, width));
                try h.expectPosition(reader.*, start + width);
            }
        }
    }
}

test "Wide bit uneven chunk layouts keep copied aligned integers and later reservoir reads ordered" {
    var storage: [33][]const u8 = undefined;
    const chunks = h.chunksFor(.uneven, &h.bytes, &storage);
    var chunked = try bits.ChunkedBitReader.init(chunks);
    var span = try bits.ChunkedSpanBitReader.init(chunks);
    inline for (.{ &chunked, &span }) |reader| {
        try std.testing.expectEqual(@as(u32, @intCast(h.oraclePadded(&h.bytes, h.bytes.len * 8, 0, 3))), try reader.readBits(u32, 3));
        _ = reader.peekBitsPadded(u64, 32);
        reader.alignToByte();
        try std.testing.expectEqual(std.mem.readInt(u32, h.bytes[1..5], .little), try reader.readAlignedInt(u32, .little));
        try h.expectPosition(reader.*, 40);
        try std.testing.expectEqual(h.oraclePadded(&h.bytes, h.bytes.len * 8, 40, 17), try reader.readBits(u64, 17));
        try h.expectPosition(reader.*, 57);
    }
}

test "Wide bit aligned reads preserve caller sentinels and cursor on malformed tails" {
    var scalar = bits.BitReader.init(&h.bytes);
    var buffered = bits.BufferedBitReader.init(&h.bytes);
    var storage: [33][]const u8 = undefined;
    const chunks = h.chunksFor(.uneven, &h.bytes, &storage);
    var chunked = try bits.ChunkedBitReader.init(chunks);
    var span = try bits.ChunkedSpanBitReader.init(chunks);
    inline for (.{ &scalar, &buffered, &chunked, &span }) |reader| {
        try reader.skipBits(3);
        var output: [17]u8 = @splat(0xa5);
        try std.testing.expectError(error.CorruptFrame, reader.readAlignedBytes(output[0..1]));
        try h.expectPosition(reader.*, 3);
        reader.alignToByte();
        try std.testing.expectError(error.TruncatedFrame, reader.readAlignedBytes(&output));
        try h.untouched(&output);
        try h.expectPosition(reader.*, 8);
        try reader.readAlignedBytes(output[0..4]);
        try std.testing.expectEqualSlices(u8, h.bytes[1..5], output[0..4]);
        try h.untouched(output[4..]);
        try h.expectPosition(reader.*, 40);
    }
    const dirty = [_]u8{ 0xff, 0xff };
    var partial = bits.BitReader.initBitLength(&dirty, 9);
    try partial.skipBits(9);
    partial.alignToByte();
    var output: [1]u8 = @splat(0xa5);
    try std.testing.expectError(error.TruncatedFrame, partial.readAlignedBytes(&output));
    try h.untouched(&output);
    try h.expectPosition(partial, 16);
}

test "Wide bit staged peeks commit exactly the selected symbol width across reservoir readers" {
    var buffered = bits.BufferedBitReader.init(&h.bytes);
    var storage: [33][]const u8 = undefined;
    const chunks = h.chunksFor(.uneven, &h.bytes, &storage);
    var chunked = try bits.ChunkedBitReader.init(chunks);
    var span = try bits.ChunkedSpanBitReader.init(chunks);
    var fast = h.fast.Reader.initFrom(bits.BitReader.init(&h.bytes));
    var position: usize = 0;
    for ([_]u6{ 3, 9, 1, 15, 7, 24 }) |width| {
        inline for (.{ &buffered, &chunked, &span, &fast }) |reader| {
            try std.testing.expectEqual(h.oraclePadded(&h.bytes, h.bytes.len * 8, position, 24), reader.peekBitsPadded(u64, 24));
            try std.testing.expect(reader.hasStagedBits(width));
            reader.advanceBitsStagedAssumeAvailable(width);
            try std.testing.expectEqual(@as(h.Count, position + width), reader.bitPosition());
        }
        position += width;
    }
}

test "Wide bit chunk offset constructors and exhausted probes preserve actual slice boundaries" {
    var storage: [33][]const u8 = undefined;
    const chunks = h.chunksFor(.uneven, &h.bytes, &storage);
    for (0..h.bytes.len + 1) |offset| {
        var chunked = try bits.ChunkedBitReader.initAt(chunks, offset);
        var span = try bits.ChunkedSpanBitReader.initAtKnownTotal(chunks, offset, h.bytes.len);
        inline for (.{ &chunked, &span }) |reader| {
            try h.expectPosition(reader.*, offset * 8);
            try std.testing.expectEqual(h.oraclePadded(&h.bytes, h.bytes.len * 8, offset * 8, 24), reader.peekBitsPadded(u64, 24));
            if (offset == h.bytes.len) {
                try std.testing.expectError(error.TruncatedFrame, reader.readBits(u8, 1));
                try h.expectPosition(reader.*, offset * 8);
            }
        }
    }
    try std.testing.expectError(error.TruncatedFrame, bits.ChunkedBitReader.initAt(chunks, h.bytes.len + 1));
    try std.testing.expectError(error.TruncatedFrame, bits.ChunkedSpanBitReader.initAt(chunks, h.bytes.len + 1));
    const tail = h.bytes[0..3];
    const split = [_][]const u8{ tail[0..1], "", tail[1..2], "", tail[2..] };
    var scalar = bits.BitReader.init(tail);
    var buffered = bits.BufferedBitReader.init(tail);
    var chunked = try bits.ChunkedBitReader.init(&split);
    var span = try bits.ChunkedSpanBitReader.init(&split);
    inline for (.{ &scalar, &buffered, &chunked, &span }) |reader| {
        try reader.skipBits(17);
        try std.testing.expectEqual(h.oraclePadded(tail, 24, 17, 24), reader.peekBitsPadded(u64, 24));
        try std.testing.expectError(error.TruncatedFrame, reader.readBits(u64, 8));
        try std.testing.expectError(error.TruncatedFrame, reader.skipBits(8));
        try std.testing.expectError(error.CorruptFrame, reader.readBits(u8, 9));
        try h.expectPosition(reader.*, 17);
        try std.testing.expectEqual(h.oraclePadded(tail, 24, 17, 7), try reader.readBits(u64, 7));
        try std.testing.expectEqual(@as(u64, 0), try reader.readBits(u64, 0));
        try h.expectPosition(reader.*, 24);
    }
    var source = bits.BitReader.init(tail);
    try source.skipBits(17);
    var fast = h.fast.Reader.initFrom(source);
    try std.testing.expectEqual(h.oraclePadded(tail, 24, 17, 24), fast.peekBitsPadded(u64, 24));
    try std.testing.expectError(error.TruncatedFrame, fast.readBits(u64, 8));
    try std.testing.expectEqual(@as(h.Count, 17), fast.bitPosition());
    try std.testing.expectEqual(h.oraclePadded(tail, 24, 17, 7), try fast.readBits(u64, 7));
    try std.testing.expectEqual(@as(h.Count, 24), fast.bitPosition());
}
