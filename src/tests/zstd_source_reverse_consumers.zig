//! Compile and execution contract for the source-backed Zstd reverse primitive.
const std = @import("std");

pub fn contracts(
    comptime Source: type,
    comptime SliceSource: type,
    comptime Range: type,
    comptime Reader: type,
    comptime SliceReader: type,
) !void {
    comptime {
        _ = Source;
        _ = Range.init;
        _ = Range.subrange;
        _ = Range.readExact;
        _ = Range.byte;
        _ = Reader.init;
        _ = Reader.peekSmall;
        _ = Reader.readSmallAvailable;
        _ = Reader.snapshot;
    }

    const bytes = [_]u8{ 0x37, 0xc2, 0x19, 0x6e, 0xa4, 0x5b, 0xd0 };
    var source = SliceSource{ .bytes = &bytes };
    const complete = try Range.init(source.source(), 0, bytes.len);
    const range = try complete.subrange(1, bytes.len - 1);
    var page: [9]u8 = @splat(0xa5);
    var actual = try Reader.init(range, &page);
    var expected = try SliceReader.init(bytes[1..]);
    while (expected.available() != 0) {
        const width: u4 = @intCast(@min(@as(usize, 11), expected.available()));
        try std.testing.expectEqual(try expected.peekSmall(width), try actual.peekSmall(width));
        try std.testing.expectEqual(try expected.readSmall(width), try actual.readSmall(width));
    }
    try actual.expectEnd();
    const snapshot = actual.snapshot();
    try std.testing.expectEqual(page.len, snapshot.page_capacity);
    try std.testing.expect(snapshot.page_loads > 0);
    try std.testing.expect(snapshot.live_page_bytes <= page.len);
}
