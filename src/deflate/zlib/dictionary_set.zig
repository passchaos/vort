const std = @import("std");
const checksum = @import("../../checksum.zig");

pub const Entry = struct { id: u32, bytes: []const u8 };

/// Borrowed preset dictionaries keyed by RFC 1950 DICTID (Adler-32).
pub const Set = struct {
    entries: []const Entry,

    pub fn fromEntries(entries: []const Entry) Set {
        return .{ .entries = entries };
    }

    pub fn entry(bytes: []const u8) Entry {
        return .{ .id = checksum.adler32(bytes), .bytes = bytes };
    }

    pub fn find(self: Set, id: u32) ?[]const u8 {
        for (self.entries) |candidate|
            if (candidate.id == id) return candidate.bytes;
        return null;
    }
};

test "zlib dictionary set resolves borrowed entries" {
    const entries = [_]Entry{
        .{ .id = 1, .bytes = "one" },
        .{ .id = 2, .bytes = "two" },
    };
    const set = Set.fromEntries(&entries);
    try std.testing.expectEqualSlices(u8, "two", set.find(2).?);
    try std.testing.expectEqual(@as(?[]const u8, null), set.find(3));
}
