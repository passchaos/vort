const std = @import("std");
const byte_source = @import("../../io/source.zig");
const seekable = @import("../seekable.zig");
const seek_table = @import("seek_table.zig");
const wire = @import("../seek_table_wire.zig");

/// Only the tail exists in memory. Enforce the exact read regions for each
/// phase, including the full requested span and not just the returned bytes.
const TrackingTail = struct {
    frame_offset: u64,
    bytes: []const u8,
    phase: enum { envelope, entries } = .envelope,
    mode: enum { normal, eof, fail } = .normal,
    request_limit: usize = std.math.maxInt(usize),
    short_limit: usize = std.math.maxInt(usize),
    calls: usize = 0,
    bytes_read: usize = 0,
    largest_request: usize = 0,

    fn source(self: *TrackingTail) byte_source.Source {
        return .{ .context = self, .len = self.frame_offset + self.bytes.len, .read_at = read, .max_read_size = self.request_limit };
    }

    fn read(context: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
        const self: *TrackingTail = @ptrCast(@alignCast(context));
        self.calls += 1;
        self.largest_request = @max(self.largest_request, output.len);
        const relative = std.math.sub(u64, offset, self.frame_offset) catch return error.SourceReadFailed;
        if (relative > self.bytes.len) return error.SourceReadFailed;
        const start: usize = @intCast(relative);
        if (output.len > @min(self.request_limit, self.bytes.len - start)) return error.SourceReadFailed;
        const end = start + output.len;
        const footer_offset = self.bytes.len - wire.footer_len;
        switch (self.phase) {
            .envelope => if (end > wire.header_len and start < footer_offset) return error.SourceReadFailed,
            .entries => if (start < wire.header_len or end > footer_offset) return error.SourceReadFailed,
        }
        switch (self.mode) {
            .normal => {},
            .eof => return 0,
            .fail => return error.SourceReadFailed,
        }
        const amount = @min(self.short_limit, output.len);
        @memcpy(output[0..amount], self.bytes[start..][0..amount]);
        self.bytes_read += amount;
        return amount;
    }
};

test "Zstd source seek table opens only the envelope, builds on short reads and matches the slice index" {
    const sizes = [_]seekable.FrameSize{
        .{ .compressed_size = 3, .decompressed_size = 0, .checksum = 0x11 },
        .{ .compressed_size = 5, .decompressed_size = 4, .checksum = 0x22 },
        .{ .compressed_size = 7, .decompressed_size = 0, .checksum = 0x33 },
        .{ .compressed_size = 11, .decompressed_size = 3, .checksum = 0x44 },
        .{ .compressed_size = 13, .decompressed_size = 0, .checksum = 0x55 },
    };
    const frame_offset = 39;
    for ([_]bool{ false, true }) |checksums| {
        var stream: [128]u8 = @splat(0xa5);
        const size = try seekable.encodeTableInto(&sizes, checksums, stream[frame_offset..]);
        const end = frame_offset + size;
        stream[end - 5] |= 0x03; // Unused descriptor bits must be ignored.
        var tail: TrackingTail = .{ .frame_offset = frame_offset, .bytes = stream[frame_offset..end], .request_limit = 5, .short_limit = 2 };
        const table = try seek_table.open(tail.source());
        try std.testing.expectEqual(@as(u64, frame_offset), table.frame_offset);
        try std.testing.expectEqual(@as(u32, sizes.len), table.entry_count);
        try std.testing.expectEqual(checksums, table.has_checksums);
        try std.testing.expectEqual(wire.header_len + wire.footer_len, tail.bytes_read);
        const envelope_calls = tail.calls;

        var storage: [sizes.len + 1]seekable.Entry = undefined;
        const sentinel: seekable.Entry = .{ .frame_index = 100, .compressed_offset = 101, .decompressed_offset = 102, .compressed_size = 103, .decompressed_size = 104, .checksum = null };
        @memset(&storage, sentinel);
        try std.testing.expectError(error.OutputTooSmall, table.buildIndex(storage[0 .. sizes.len - 1]));
        try std.testing.expectEqual(envelope_calls, tail.calls);
        for (storage) |entry| try std.testing.expectEqual(sentinel, entry);

        tail.phase = .entries;
        const index = try table.buildIndex(&storage);
        try std.testing.expectEqual(@as(usize, sizes.len), index.entries.len);
        try std.testing.expect(index.entries.ptr == storage[0..].ptr);
        try std.testing.expectEqual(sentinel, storage[sizes.len]);
        try std.testing.expectEqual(@as(u64, 7), index.decompressed_size);
        try std.testing.expectEqual(@as(usize, 5), tail.largest_request);
        try std.testing.expectEqual(size, tail.bytes_read);

        var slice_storage: [sizes.len]seekable.Entry = undefined;
        const slice_index = try seekable.buildIndex(try seekable.inspect(stream[0..end]), &slice_storage);
        for (slice_index.entries, index.entries) |expected, actual| try std.testing.expectEqual(expected, actual);
        const index_calls = tail.calls;
        for (0..7) |offset| try std.testing.expectEqual(
            try slice_index.frameIndexForDecompressedOffset(offset),
            try index.frameIndexForDecompressedOffset(offset),
        );
        try std.testing.expectError(error.RangeOutOfBounds, index.frameIndexForDecompressedOffset(7));
        try std.testing.expectEqual(index_calls, tail.calls);
    }
}

test "Zstd source seek table batches entries at sparse offsets above 4 GiB" {
    const count = 700;
    var sizes: [count]seekable.FrameSize = @splat(.{ .compressed_size = 1, .decompressed_size = 0, .checksum = 0 });
    sizes[0].compressed_size = std.math.maxInt(u32);
    sizes[1].compressed_size = 2;
    for (sizes[0..4]) |*size| size.decompressed_size = seekable.max_frame_decompressed_size;
    sizes[4].decompressed_size = 7;
    sizes[count - 1].checksum = 0x1234abcd;
    const boundary: u64 = 1 << 32;
    var encoded: [wire.header_len + count * wire.checked_entry_len + wire.footer_len]u8 = undefined;
    const size = try seekable.encodeTableInto(&sizes, true, &encoded);
    var tail: TrackingTail = .{ .frame_offset = boundary + count - 1, .bytes = encoded[0..size] };
    const table = try seek_table.open(tail.source());
    try std.testing.expectEqual(tail.frame_offset, table.frame_offset);
    try std.testing.expectEqual(@as(usize, 2), tail.calls);
    tail.phase = .entries;

    var storage: [count]seekable.Entry = undefined;
    const index = try table.buildIndex(&storage);
    try std.testing.expect(tail.calls > 3 and tail.calls < count);
    try std.testing.expect(tail.largest_request <= 4 * 1024);
    try std.testing.expectEqual(size, tail.bytes_read);
    try std.testing.expectEqual(boundary + 1, index.entries[2].compressed_offset);
    try std.testing.expectEqual(tail.frame_offset - 1, index.entries[count - 1].compressed_offset);
    try std.testing.expectEqual(@as(?u32, 0x1234abcd), index.entries[count - 1].checksum);
    try std.testing.expectEqual(boundary + 7, index.decompressed_size);
    try std.testing.expectEqual(@as(u32, 3), try index.frameIndexForDecompressedOffset(boundary - 1));
    try std.testing.expectEqual(@as(u32, 4), try index.frameIndexForDecompressedOffset(boundary + 6));
}

test "Zstd source seek table rejects invalid envelope and keeps cumulative validation in build" {
    var bytes: [64]u8 = undefined;
    const size = try seekable.encodeTableInto(&.{.{ .compressed_size = 32, .decompressed_size = 7 }}, false, &bytes);
    var tail: TrackingTail = .{ .frame_offset = 32, .bytes = bytes[0..size] };
    var source = tail.source();
    source.len = 16;
    try std.testing.expectError(error.TruncatedFrame, seek_table.open(source));
    try std.testing.expectEqual(@as(usize, 0), tail.calls);

    tail.mode = .eof;
    try std.testing.expectError(error.TruncatedFrame, seek_table.open(tail.source()));
    tail.mode = .normal;
    const patches = [_]struct { offset: usize, replacement: u32, expected: seek_table.Error }{
        .{ .offset = size - 4, .replacement = 0, .expected = error.InvalidMagic },
        .{ .offset = 0, .replacement = 0, .expected = error.InvalidMagic },
        .{ .offset = 4, .replacement = 18, .expected = error.CorruptFrame },
        .{ .offset = size - wire.footer_len, .replacement = wire.max_frames + 1, .expected = error.CorruptFrame },
        .{ .offset = size - wire.footer_len, .replacement = 100, .expected = error.TruncatedFrame },
        // Footer count remains 1, but a reserved descriptor bit is set.
        .{ .offset = size - 8, .replacement = 0x04000000, .expected = error.CorruptFrame },
    };
    for (patches) |patch| {
        const saved = std.mem.readInt(u32, bytes[patch.offset..][0..4], .little);
        std.mem.writeInt(u32, bytes[patch.offset..][0..4], patch.replacement, .little);
        try std.testing.expectError(patch.expected, seek_table.open(tail.source()));
        std.mem.writeInt(u32, bytes[patch.offset..][0..4], saved, .little);
    }

    var storage: [1]seekable.Entry = undefined;
    for ([_]u32{ 31, 33 }) |bad_compressed_size| {
        std.mem.writeInt(u32, bytes[wire.header_len..][0..4], bad_compressed_size, .little);
        tail.phase = .envelope;
        const table = try seek_table.open(tail.source());
        tail.phase = .entries;
        try std.testing.expectError(error.CorruptFrame, table.buildIndex(&storage));
        try std.testing.expectEqual(bad_compressed_size, storage[0].compressed_size);
    }
    tail.mode = .fail;
    tail.phase = .envelope;
    try std.testing.expectError(error.SourceReadFailed, seek_table.open(tail.source()));
}

test "Zstd source seek table handles empty indexes and rejects inconsistent manually built tables before reading" {
    var bytes: [64]u8 = undefined;
    const size = try seekable.encodeTableInto(&.{}, false, &bytes);
    var tail: TrackingTail = .{ .frame_offset = 0, .bytes = bytes[0..size] };
    const table = try seek_table.open(tail.source());
    const envelope_calls = tail.calls;
    const index = try table.buildIndex(&.{});
    try std.testing.expectEqual(@as(usize, 0), index.entries.len);
    try std.testing.expectEqual(@as(u64, 0), index.decompressed_size);
    try std.testing.expectError(error.RangeOutOfBounds, index.frameIndexForDecompressedOffset(0));

    var forged = table;
    forged.frame_offset = std.math.maxInt(u64);
    try std.testing.expectError(error.CorruptFrame, forged.buildIndex(&.{}));
    forged.frame_offset = 0;
    forged.entry_count = 2;
    var storage: [2]seekable.Entry = undefined;
    try std.testing.expectError(error.TruncatedFrame, forged.buildIndex(&storage));
    try std.testing.expectEqual(envelope_calls, tail.calls);
}
