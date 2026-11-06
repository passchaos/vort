const std = @import("std");
const Count = @import("../../core.zig").StreamCount;
pub const a = std.testing.allocator;
pub const boundary: Count = @as(Count, 1) << 32;
pub const block_len: usize = 128 * 1024;
pub const block_count: usize = 32 * 1024;
pub const Tail = enum { raw, compressed, window_edge, beyond_window };

pub fn block(out: *std.ArrayList(u8), kind: u2, size: usize, last: bool) !void {
    var block_header: [3]u8 = undefined;
    std.mem.writeInt(u24, &block_header, @intCast((size << 3) | (@as(usize, kind) << 1) | @intFromBool(last)), .little);
    try out.appendSlice(a, &block_header);
}

pub fn header(out: *std.ArrayList(u8), content_size: ?Count, dictionary_id: ?u8) !void {
    try out.appendSlice(a, &.{ 0x28, 0xb5, 0x2f, 0xfd });
    try out.append(a, @as(u8, if (content_size != null) 0xc0 else 0) | @as(u8, if (dictionary_id != null) 1 else 0));
    try out.append(a, 0x38); // A 128 KiB window; no single-segment narrowing.
    if (dictionary_id) |id| try out.append(a, id);
    if (content_size) |size| {
        var bytes: [8]u8 = undefined;
        std.mem.writeInt(u64, &bytes, size, .little);
        try out.appendSlice(a, &bytes);
    }
}

/// A complete real wire has 32K 128-KiB RLE blocks followed by a 3-byte raw
/// or match block. Its logical output exceeds 4 GiB while wire storage is
/// about 128 KiB. No decoder state or header-only size shortcut is seeded.
pub fn wideAlloc(tail: Tail, content_size: ?Count, dictionary_id: ?u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(a);
    try header(&out, content_size, dictionary_id);
    for (0..block_count) |_| {
        try block(&out, 1, block_len, false);
        try out.append(a, 'R');
    }
    switch (tail) {
        .raw => {
            try block(&out, 0, 3, true);
            try out.appendSlice(a, "end");
        },
        .compressed => {
            // No literals, one RLE-table sequence: offset=4, match length=3.
            try block(&out, 2, 7, true);
            try out.appendSlice(a, &.{ 0, 1, 0x54, 0, 2, 0, 7 });
        },
        .window_edge, .beyond_window => {
            // OF code 17 has base 131069 and 17 extra bits, followed by the
            // end marker. Extra 3 is precisely the window; extra 4 exceeds it.
            try block(&out, 2, 9, true);
            try out.appendSlice(a, &.{ 0, 1, 0x54, 0, 17, 0, if (tail == .window_edge) 3 else 4, 0, 2 });
        },
    }
    return out.toOwnedSlice(a);
}

pub fn smallAlloc(dictionary_id: ?u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(a);
    try header(&out, 3, dictionary_id);
    try block(&out, 0, 3, true);
    try out.appendSlice(a, "end");
    return out.toOwnedSlice(a);
}

pub fn compressedAlloc(repetitions: usize) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(a);
    try header(&out, @as(Count, repetitions) * block_len + 1, null);
    try block(&out, 0, 1, false);
    try out.append(a, 'R');
    for (0..repetitions) |index| {
        try block(&out, 2, 9, index + 1 == repetitions);
        // ML code 52 has base 65539. Extra 65533 makes a 128-KiB match;
        // OF code 2 with zero extra bits selects offset 1. A marker at bit 18
        // terminates the 16 ML and two OF extra bits in the reverse stream.
        try out.appendSlice(a, &.{ 0, 1, 0x54, 0, 2, 52, 0xfd, 0xff, 4 });
    }
    return out.toOwnedSlice(a);
}
