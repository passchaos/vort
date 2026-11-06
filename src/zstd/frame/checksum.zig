const std = @import("std");

/// Ignoring a content checksum changes only its comparison. Callers still
/// parse the entire footer before this check and preserve all other policies.
pub fn validate(expected: u32, actual: u32, ignore: bool) error{ChecksumMismatch}!void {
    if (!ignore and expected != actual) return error.ChecksumMismatch;
}

pub fn consumeFooter(frame: []const u8, offset: *usize, decoded: []const u8, ignore: bool) error{ TruncatedFrame, ChecksumMismatch }!void {
    if (offset.* > frame.len) return error.TruncatedFrame;
    if (frame.len - offset.* < 4) return error.TruncatedFrame;
    const expected = std.mem.readInt(u32, frame[offset.*..][0..4], .little);
    const actual: u32 = @truncate(std.hash.XxHash64.hash(0, decoded));
    try validate(expected, actual, ignore);
    offset.* += 4;
}

test "Zstd checksum footer rejects invalid offsets without advancing cursor" {
    const frame = [_]u8{ 0, 0, 0, 0 };
    for ([_]bool{ false, true }) |ignore| {
        for ([_]usize{ frame.len + 1, std.math.maxInt(usize) }) |invalid| {
            var offset = invalid;
            try std.testing.expectError(error.TruncatedFrame, consumeFooter(&frame, &offset, "payload", ignore));
            try std.testing.expectEqual(invalid, offset);
        }
    }
}
