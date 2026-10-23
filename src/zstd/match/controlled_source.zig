const std = @import("std");
const controls = @import("../encode/controls.zig");

pub const Record = struct {
    literal_len: usize,
    distance: usize,
    match_len: usize,
    match_end: usize,
};
pub const Parameters = struct {
    strategy: controls.Strategy,
    acceleration: u32 = 1,
    search_budget: usize = controls.legacy_search_budget,
    initial_repeated_offsets: [3]usize = .{ 1, 4, 8 },
    profile: ?*controls.Profile = null,
};
pub const Match = struct { length: usize = 0, distance: usize = 0 };
pub const Origin = enum { dictionary, history, block };

/// Dictionary suffix and completed-frame history are adjacent logical bytes
/// before the current block. No combined-prefix allocation is required.
pub const Source = struct {
    dictionary: []const u8,
    history: []const u8,
    block: []const u8,
    window_len: usize,

    pub fn init(dictionary: []const u8, history: []const u8, block: []const u8, window_len: usize) Source {
        const retained_history = history[history.len - @min(history.len, window_len) ..];
        const dictionary_len = @min(dictionary.len, window_len - retained_history.len);
        return .{ .dictionary = dictionary[dictionary.len - dictionary_len ..], .history = retained_history, .block = block, .window_len = window_len };
    }
    pub fn prefixLen(self: Source) usize {
        return self.dictionary.len + self.history.len;
    }
    pub fn totalLen(self: Source) usize {
        return self.prefixLen() + self.block.len;
    }
    pub fn byteAt(self: Source, position: usize) u8 {
        if (position < self.dictionary.len) return self.dictionary[position];
        const after_dictionary = position - self.dictionary.len;
        if (after_dictionary < self.history.len) return self.history[after_dictionary];
        return self.block[after_dictionary - self.history.len];
    }
    pub fn origin(self: Source, position: usize) Origin {
        if (position < self.dictionary.len) return .dictionary;
        if (position < self.prefixLen()) return .history;
        return .block;
    }
    /// Input lookahead also proves overlapping copies: bytes beyond the match
    /// start must equal their earlier recurrence in the caller's immutable block.
    pub fn match(self: Source, block_position: usize, candidate: usize, minimum: usize) Match {
        if (block_position > self.block.len or minimum > self.block.len - block_position) return .{};
        const position = self.prefixLen() + block_position;
        if (candidate >= position or position - candidate > self.window_len) return .{};
        var length: usize = 0;
        while (length < self.block.len - block_position and
            self.byteAt(candidate + length) == self.block[block_position + length]) : (length += 1)
        {}
        if (length < minimum) return .{};
        return .{ .length = length, .distance = position - candidate };
    }
};
