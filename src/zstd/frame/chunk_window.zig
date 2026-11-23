//! Header-only window admission before coalescing caller-owned chunks.
const std = @import("std");
const core = @import("../../core.zig");
const byte_source = @import("../../io/source.zig");
const source_frame = @import("../source/frame.zig");
const source_input = @import("../source/input.zig");
const stream_cursor = @import("../source/stream_cursor.zig");
const frame_format = @import("format.zig");
const window_limit = @import("window_limit.zig");

/// Check each data window before traversing that frame's blocks. Only wire
/// headers are read; block, skippable and checksum bytes are range-checked.
/// Unlimited callers bypass the preflight altogether.
pub fn validate(
    chunks: []const []const u8,
    format: frame_format.FrameFormat,
    max_window_size: core.StreamCount,
) core.Error!void {
    if (max_window_size == std.math.maxInt(core.StreamCount)) return;

    var len: u64 = 0;
    for (chunks) |chunk| {
        const chunk_len = std.math.cast(u64, chunk.len) orelse return error.IntegerOverflow;
        len = std.math.add(u64, len, chunk_len) catch return error.IntegerOverflow;
    }
    var view: ChunkView = .{ .remaining = chunks };
    const source: byte_source.Source = .{ .context = &view, .len = len, .read_at = ChunkView.readAt };
    validateSource(source, format, max_window_size) catch |err| switch (err) {
        // Only a violation of the private adapter's forward-read invariant
        // can fail a source read; caller chunks have no fallible I/O.
        error.SourceReadFailed => return error.InvalidStreamState,
        else => |wire_error| return wire_error,
    };
}

fn validateSource(
    source: byte_source.Source,
    format: frame_format.FrameFormat,
    max_window_size: core.StreamCount,
) stream_cursor.Error!void {
    var cursor = stream_cursor.Cursor.init(try source_input.Range.init(source, 0, source.len), format);
    while (try cursor.next()) |element| {
        const frame = switch (element) {
            .data => |frame| frame,
            .skippable => continue,
        };
        try window_limit.validate(frame.header.window_size, max_window_size);

        var offset = frame.first_block_offset;
        while (true) {
            const block = try source_frame.parseBlock(frame, offset);
            offset = block.next_header_offset;
            if (block.header.last) break;
        }
        if (frame.header.has_checksum) {
            const footer = try frame.available.subrange(offset - frame.available.offset, 4);
            offset = try footer.end();
        }
        try cursor.finishData(offset);
    }
}

/// The layout parsers read headers in ascending order. Retain the last chunk
/// location so skipped payloads only cost a walk over their chunk descriptors.
const ChunkView = struct {
    remaining: []const []const u8,
    chunk_offset: u64 = 0,

    fn readAt(context: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
        const self: *ChunkView = @ptrCast(@alignCast(context));
        if (offset < self.chunk_offset) return error.SourceReadFailed;
        while (self.remaining.len != 0) {
            const chunk = self.remaining[0];
            const chunk_len: u64 = @intCast(chunk.len);
            const relative = offset - self.chunk_offset;
            if (relative < chunk_len) {
                const bytes = chunk[@intCast(relative)..];
                const amount = @min(bytes.len, output.len);
                @memcpy(output[0..amount], bytes[0..amount]);
                return amount;
            }
            self.remaining = self.remaining[1..];
            self.chunk_offset += chunk_len; // The total was checked before traversal.
        }
        return 0;
    }
};

test "Zstd chunk window walks split block, checksum and skippable ranges" {
    const wire = "\x5f\x2a\x4d\x18\x03\x00\x00\x00\xff\xff\xff" ++ // Skippable.
        "\x28\xb5\x2f\xfd\x04\x00" ++ // 1 KiB window, checksum.
        "\x18\x00\x00abc" ++ // Raw, three bytes.
        "\x52\x00\x00z" ++ // RLE, ten bytes from one wire byte.
        "\x15\x00\x00\xff\xff" ++ // Last compressed block, two opaque bytes.
        "\xff\xff\xff\xff" ++ // Opaque checksum.
        "\x28\xb5\x2f\xfd\x00\x08\x01\x00\x00"; // 2 KiB window, empty raw block.
    var chunks: [2 * wire.len + 1][]const u8 = @splat("");
    for (0..wire.len) |index| chunks[2 * index + 1] = wire[index..][0..1];

    try validate(&chunks, .standard, 2048);
    try std.testing.expectError(error.OutputLimitExceeded, validate(&chunks, .standard, 2047));
    try std.testing.expectError(error.CorruptFrame, validate(&chunks, .magicless, 2048));
}

test "Zstd chunk window admits only complete headers before reading blocks" {
    const window: core.StreamCount = 1 << 32;
    const header = "\xe0\x00\x00\x00\x00\x01\x00\x00\x00";
    const chunks: []const []const u8 = &.{ header[0..2], "", header[2..] };
    try std.testing.expectError(error.OutputLimitExceeded, validate(chunks, .magicless, window - 1));
    try std.testing.expectError(error.TruncatedFrame, validate(chunks, .magicless, window));
    try std.testing.expectError(error.TruncatedFrame, validate(&.{header[0 .. header.len - 1]}, .magicless, 0));
    try validate(&.{"junk"}, .standard, std.math.maxInt(core.StreamCount));
    try std.testing.expectError(error.InvalidMagic, validate(&.{"junk"}, .standard, 0));
}
