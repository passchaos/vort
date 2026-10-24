const std = @import("std");

pub const invalid = std.math.maxInt(u32);
pub const hash_size: usize = 1 << 16;

/// Absolute positions, including generation stamps, are compacted only after
/// the source's checked 64MiB prefix/128KiB block bounds prove they fit u32.
pub const Node = struct {
    position: u32 = invalid,
    left: u32 = invalid,
    right: u32 = invalid,
    short_previous: u32 = invalid,
};
comptime {
    std.debug.assert(@sizeOf(Node) == 16);
}

pub const Match = struct { length: usize = 0, distance: usize = 0 };

/// Borrowed strictly increasing length frontier. Distances are one-based byte
/// distances. Equal lengths keep the smaller distance. Views and iterators are
/// invalidated by the next find/getMatches/skip/reset/prepare or owner deinit.
pub const Matches = struct {
    items: []const Match,

    pub fn slice(self: Matches) []const Match {
        return self.items;
    }
    pub fn best(self: Matches) Match {
        return if (self.items.len == 0) .{} else self.items[self.items.len - 1];
    }
    pub fn iterator(self: Matches) Iterator {
        return .{ .items = self.items };
    }
};

pub const Iterator = struct {
    items: []const Match,
    position: usize = 0,

    pub fn next(self: *Iterator) ?Match {
        if (self.position == self.items.len) return null;
        defer self.position += 1;
        return self.items[self.position];
    }
};
