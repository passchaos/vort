const std = @import("std");
pub const invalid = std.math.maxInt(u32);
pub const hash_size: usize = 1 << 16;
pub const store_lookahead: usize = 128;
pub const max_input_len: usize = 1 << 24;
pub const max_window_len: usize = max_input_len - 16;
pub const max_source_len: usize = 2 * max_input_len;

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

/// Only matcher controls are retained. Quality/mode/beam/iteration resolution
/// stays with the shared HqOptions authority and parser.
pub const Search = struct {
    search_depth: u32,
    nice_len: u32,
    max_working_memory: usize,
    pub fn from(options: anytype) !Search {
        const result = Search{ .search_depth = options.search_depth, .nice_len = options.nice_len, .max_working_memory = options.max_working_memory };
        if (result.search_depth == 0 or result.search_depth > 65536 or result.nice_len < 2 or result.nice_len > max_input_len) return error.InvalidBlockPlan;
        return result;
    }
};

pub const Frontier = struct {
    buffer: []Match,
    count: *usize,
    pub fn add(self: Frontier, length: usize, distance: usize) void {
        if (length < 2) return;
        if (self.count.* != 0) {
            const last = &self.buffer[self.count.* - 1];
            if (length < last.length) return;
            if (length == last.length) {
                last.distance = @min(last.distance, distance);
                return;
            }
        }
        std.debug.assert(self.count.* < self.buffer.len);
        self.buffer[self.count.*] = .{ .length = length, .distance = distance };
        self.count.* += 1;
    }
    pub fn best(self: Frontier) Match {
        return if (self.count.* == 0) .{} else self.buffer[self.count.* - 1];
    }
};
