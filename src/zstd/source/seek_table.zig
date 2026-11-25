const std = @import("std");
const core = @import("../../core.zig");
const byte_source = @import("../../io/source.zig");
const wire = @import("../seek_table_wire.zig");

pub const Error = core.Error || byte_source.Error;

/// Validated terminal seek-table envelope. Keep the borrowed source context,
/// length, and bytes stable while the table or its index is in use.
pub const Table = struct {
    source: byte_source.Source,
    frame_offset: u64,
    entry_count: u32,
    has_checksums: bool,

    /// Reads only the entry region and builds cumulative offsets without
    /// allocation. Insufficient storage fails before any reads or writes.
    /// Any later failure may leave tentative entries in storage.
    /// The source context is opaque: no slice alias check or immutable backing
    /// is inferred. Storage must not interfere with the source's data or state.
    pub fn buildIndex(self: Table, storage: []wire.Entry) Error!Index {
        const count = std.math.cast(usize, self.entry_count) orelse return error.IntegerOverflow;
        if (storage.len < count) return error.OutputTooSmall;

        // Defend against inconsistent caller-constructed Tables before any
        // reads. This bounds all batches to [frame_offset + header_len, EOF - footer_len).
        const layout = try wire.Layout.init(self.entry_count, self.has_checksums);
        if (self.frame_offset != try layout.frameOffset(self.source.len)) return error.CorruptFrame;
        var read_offset = self.frame_offset + wire.header_len;

        const entries = storage[0..count];
        const stride: usize = layout.entry_size;
        var buffer: [4 * 1024]u8 = undefined;
        var compressed_size: u64 = 0;
        var decompressed_size: u64 = 0;
        var first: usize = 0;
        while (first < count) {
            const size = @min(count - first, buffer.len / stride);
            const bytes = buffer[0 .. size * stride];
            try self.source.readExact(read_offset, bytes);
            for (entries[first..][0..size], 0..) |*entry, i| {
                entry.* = try wire.readEntryAndAdvance(bytes[i * stride ..][0..stride], self.has_checksums, @intCast(first + i), &compressed_size, &decompressed_size);
            }
            read_offset += bytes.len;
            first += size;
        }
        if (compressed_size != self.frame_offset) return error.CorruptFrame;
        return .{ .table = self, .entries = entries, .decompressed_size = decompressed_size };
    }
};

/// Cumulative entries borrow caller storage, which must remain alive and
/// unchanged while the index is in use. Lookup does not read the source.
pub const Index = struct {
    table: Table,
    entries: []const wire.Entry,
    decompressed_size: u64,

    pub fn frameIndexForDecompressedOffset(self: Index, offset: u64) Error!u32 {
        return wire.frameIndexForDecompressedOffset(self.entries, self.decompressed_size, offset);
    }
};

/// Validates the terminal envelope by reading only the footer and the seek
/// table's skippable header. Entry and cumulative size validation is deferred
/// to buildIndex; neither operation reads any indexed frame payload.
pub fn open(source: byte_source.Source) Error!Table {
    if (source.len < wire.header_len + wire.footer_len) return error.TruncatedFrame;
    var footer: [wire.footer_len]u8 = undefined;
    try source.readExact(source.len - wire.footer_len, &footer);
    const layout = try wire.parseFooter(&footer);
    const frame_offset = try layout.frameOffset(source.len);
    var header: [wire.header_len]u8 = undefined;
    try source.readExact(frame_offset, &header);
    try wire.validateHeader(&header, layout);
    return .{
        .source = source,
        .frame_offset = frame_offset,
        .entry_count = layout.entry_count,
        .has_checksums = layout.has_checksums,
    };
}

test {
    _ = @import("seek_table_tests.zig");
}
