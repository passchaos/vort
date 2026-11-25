//! Internal wire rules shared by the slice and random-access seek tables.

const std = @import("std");
const core = @import("../core.zig");

pub const table_skippable_magic: u32 = 0x184d2a5e;
pub const footer_magic: u32 = 0x8f92eab1;
pub const max_frames: u32 = 0x0800_0000;
pub const header_len = 8;
pub const footer_len = 9;
pub const plain_entry_len = 8;
pub const checked_entry_len = 12;

pub const Entry = struct {
    frame_index: u32,
    compressed_offset: u64,
    decompressed_offset: u64,
    compressed_size: u32,
    decompressed_size: u32,
    checksum: ?u32,
};

pub fn entrySize(has_checksums: bool) u8 {
    return if (has_checksums) checked_entry_len else plain_entry_len;
}

pub const Layout = struct {
    entry_count: u32,
    has_checksums: bool,
    entry_size: u8,
    payload_size: u32,

    pub fn init(entry_count: u32, has_checksums: bool) core.Error!Layout {
        if (entry_count > max_frames) return error.CorruptFrame;
        const stride = entrySize(has_checksums);
        // max_frames * checked_entry_len + footer_len fits in u32.
        return .{
            .entry_count = entry_count,
            .has_checksums = has_checksums,
            .entry_size = stride,
            .payload_size = entry_count * stride + footer_len,
        };
    }

    pub fn frameSize(self: Layout) u64 {
        return @as(u64, self.payload_size) + header_len;
    }

    pub fn frameOffset(self: Layout, stream_len: u64) core.Error!u64 {
        return std.math.sub(u64, stream_len, self.frameSize()) catch error.TruncatedFrame;
    }
};

pub fn parseFooter(footer: *const [footer_len]u8) core.Error!Layout {
    if (std.mem.readInt(u32, footer[5..9], .little) != footer_magic) return error.InvalidMagic;
    const descriptor = footer[4];
    if (descriptor & 0x7c != 0) return error.CorruptFrame;
    return Layout.init(std.mem.readInt(u32, footer[0..4], .little), descriptor & 0x80 != 0);
}

pub fn validateHeader(header: *const [header_len]u8, layout: Layout) core.Error!void {
    if (std.mem.readInt(u32, header[0..4], .little) != table_skippable_magic) return error.InvalidMagic;
    if (std.mem.readInt(u32, header[4..8], .little) != layout.payload_size) return error.CorruptFrame;
}

pub fn readEntryAndAdvance(bytes: []const u8, has_checksums: bool, frame_index: u32, compressed_offset: *u64, decompressed_offset: *u64) core.Error!Entry {
    if (bytes.len < entrySize(has_checksums)) return error.TruncatedFrame;
    const entry: Entry = .{
        .frame_index = frame_index,
        .compressed_offset = compressed_offset.*,
        .decompressed_offset = decompressed_offset.*,
        .compressed_size = std.mem.readInt(u32, bytes[0..4], .little),
        .decompressed_size = std.mem.readInt(u32, bytes[4..8], .little),
        .checksum = if (has_checksums) std.mem.readInt(u32, bytes[8..12], .little) else null,
    };
    compressed_offset.* = std.math.add(u64, compressed_offset.*, entry.compressed_size) catch return error.IntegerOverflow;
    decompressed_offset.* = std.math.add(u64, decompressed_offset.*, entry.decompressed_size) catch return error.IntegerOverflow;
    return entry;
}

pub fn frameIndexForDecompressedOffset(entries: []const Entry, decompressed_size: u64, offset: u64) core.Error!u32 {
    if (offset >= decompressed_size) return error.RangeOutOfBounds;
    var low: usize = 0;
    var high = entries.len;
    while (low < high) {
        const mid = low + (high - low) / 2;
        const current = entries[mid];
        const end = std.math.add(u64, current.decompressed_offset, current.decompressed_size) catch return error.IntegerOverflow;
        if (end <= offset)
            low = mid + 1
        else
            high = mid;
    }
    if (low >= entries.len) return error.RangeOutOfBounds;
    return std.math.cast(u32, low) orelse error.IntegerOverflow;
}
