const std = @import("std");
const tables = @import("tables.zig");
const model = @import("model.zig");

pub const Item = union(enum) {
    literal: u8,
    match: struct { length: u16, offset: u32 },
};

pub const Summary = struct {
    literals: usize = 0,
    fixed3_matches: usize = 0,
    fixed4_matches: usize = 0,
    variable_matches: usize = 0,
    matched_bytes: usize = 0,
    max_offset: usize = 0,
    extra_bits: usize = 0,
    literal_reference_frames: usize = 0,

    pub fn add(self: *Summary, other: Summary) !void {
        var next = self.*;
        inline for (.{ "literals", "fixed3_matches", "fixed4_matches", "variable_matches", "matched_bytes", "extra_bits", "literal_reference_frames" }) |name|
            @field(next, name) = std.math.add(usize, @field(self, name), @field(other, name)) catch return error.IntegerOverflow;
        next.max_offset = @max(self.max_offset, other.max_offset);
        self.* = next;
    }
};

pub fn validate(items: []const Item, history_len: usize, window_bits: u5) !struct { length: usize, summary: Summary } {
    if (window_bits < tables.min_window_bits or window_bits > tables.max_window_bits or history_len % tables.frame_size != 0)
        return error.InvalidBlockPlan;
    var length: usize = 0;
    var summary = Summary{};
    for (items) |item| {
        switch (item) {
            .literal => {
                if (length == tables.frame_size) return error.InvalidBlockPlan;
                length += 1;
                summary.literals += 1;
            },
            .match => |match| {
                if (match.length < 3 or match.length > 259 or match.length > tables.frame_size - length or
                    match.offset == 0 or match.offset > @as(usize, 1) << window_bits or
                    (match.offset > length and match.offset - length > history_len)) return error.InvalidBlockPlan;
                const entries = positionEntries(window_bits, match.length);
                const slot = try tables.positionSlot(match.offset, entries);
                summary.extra_bits += tables.position_extra[slot];
                switch (match.length) {
                    3 => summary.fixed3_matches += 1,
                    4 => summary.fixed4_matches += 1,
                    else => {
                        const length_slot = try tables.lengthSlot(match.length);
                        summary.extra_bits += tables.length_extra[length_slot];
                        summary.variable_matches += 1;
                    },
                }
                length += match.length;
                summary.matched_bytes += match.length;
                summary.max_offset = @max(summary.max_offset, match.offset);
            },
        }
    }
    if (length == 0) return error.InvalidBlockPlan;
    return .{ .length = length, .summary = summary };
}

pub fn positionEntries(window_bits: u5, length: u16) usize {
    const entries = @as(usize, window_bits) * 2;
    return switch (length) {
        3 => @min(entries, 24),
        4 => @min(entries, 36),
        else => entries,
    };
}

pub const Token = struct { alphabet: usize, symbol: usize, extra: u32 = 0, bits: u5 = 0 };
pub const Iterator = struct {
    items: []const Item,
    window_bits: u5,
    index: usize = 0,
    phase: u2 = 0,

    pub fn next(self: *Iterator) !?Token {
        if (self.index == self.items.len) return null;
        const item = self.items[self.index];
        var token: Token = undefined;
        var phases: u2 = undefined;
        switch (item) {
            .literal => |byte| {
                phases = 2;
                token = if (self.phase == 0)
                    .{ .alphabet = model.selector_index, .symbol = byte >> 6 }
                else
                    .{ .alphabet = byte >> 6, .symbol = byte };
            },
            .match => |match| {
                const selector: usize = switch (match.length) {
                    3 => 4,
                    4 => 5,
                    else => 6,
                };
                phases = if (selector == 6) 3 else 2;
                if (self.phase == 0) {
                    token = .{ .alphabet = model.selector_index, .symbol = selector };
                } else if (selector == 6 and self.phase == 1) {
                    const slot = try tables.lengthSlot(match.length);
                    token = .{ .alphabet = model.length_index, .symbol = slot, .extra = @intCast(match.length - 5 - tables.length_base[slot]), .bits = tables.length_extra[slot] };
                } else {
                    const slot = try tables.positionSlot(match.offset, positionEntries(self.window_bits, match.length));
                    token = .{ .alphabet = selector, .symbol = slot, .extra = @intCast(match.offset - 1 - tables.position_base[slot]), .bits = tables.position_extra[slot] };
                }
            },
        }
        self.phase += 1;
        if (self.phase == phases) {
            self.phase = 0;
            self.index += 1;
        }
        return token;
    }
};
