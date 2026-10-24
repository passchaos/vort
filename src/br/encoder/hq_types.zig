const std = @import("std");
const distance = @import("distance.zig");
const command_lut = @import("../command_lut.zig");
const distance_history = @import("../decoder/distance_history.zig");

pub const Error = error{ InvalidBlockPlan, IntegerOverflow };
pub const initial_recent: [4]usize = .{ 16, 15, 11, 4 };

/// The parser's selected wire representation, preserved across plan and emit.
/// distance_code is semantic: 0..15 for short codes, otherwise distance + 15.
pub const ExactEncoding = struct {
    command_symbol: u16,
    distance_code: usize = 0,
    distance_encoding: ?distance.Encoding = null,
    distance_parameters: distance.Parameters = distance.Parameters.init(0, 0),
    format: distance.Format = .standard,

    pub fn validate(self: ExactEncoding, insert_len: usize, copy_len: usize, has_copy: bool) Error!void {
        if (self.command_symbol >= command_lut.entries.len) return error.InvalidBlockPlan;
        const entry = command_lut.entries[self.command_symbol];
        if (insert_len < entry.insert_base or insert_len - entry.insert_base >= (@as(usize, 1) << entry.insert_extra_bits) or
            copy_len < entry.copy_base or copy_len - entry.copy_base >= (@as(usize, 1) << entry.copy_extra_bits)) return error.InvalidBlockPlan;
        if (!has_copy) {
            if (self.distance_code != 0 or self.distance_encoding != null) return error.InvalidBlockPlan;
            return;
        }
        if (entry.distance_code == 0) {
            if (self.distance_code != 0 or self.distance_encoding != null) return error.InvalidBlockPlan;
        } else {
            const encoded = self.distance_encoding orelse return error.InvalidBlockPlan;
            const expected = if (self.distance_code < 16)
                distance.Encoding{ .symbol = @intCast(self.distance_code) }
            else
                distance.encodeWithFormat(self.distance_code - 15, self.distance_parameters, self.format) orelse return error.InvalidBlockPlan;
            if (!std.meta.eql(expected, encoded)) return error.InvalidBlockPlan;
        }
    }
};

pub fn resolveDistanceCode(code: usize, recent: *const [4]usize) Error!usize {
    if (code >= 16) return code - 15;
    var result: usize = undefined;
    distance_history.resolveShortInto(@intCast(code), recent, &result) catch |err| switch (err) {
        error.IntegerOverflow => return error.IntegerOverflow,
        else => return error.InvalidBlockPlan,
    };
    if (result == 0) return error.InvalidBlockPlan;
    return result;
}

pub fn recentAfter(source: anytype, semantic_code: usize, wire_distance: usize, previous: [4]usize) [4]usize {
    var next = previous;
    if (source != .static and semantic_code != 0) distance_history.push(&next, wire_distance);
    return next;
}

pub const Match = struct { length: usize = 0, distance: usize = 0 };

/// Only already-produced bytes of this frame belong to normal LZ history.
/// Compound dictionary attachments remain a separate dictionary provider.
pub const Source = struct {
    history: []const u8,
    input: []const u8,
    /// Maximum backward distance: the selected format's window size minus sixteen.
    window_len: usize,
    frame_offset: u64,
    recent: [4]usize = initial_recent,
    format: distance.Format = .standard,

    pub fn init(history: []const u8, input: []const u8, window_bits: u8, frame_offset: u64) Error!Source {
        return initWithFormat(history, input, window_bits, frame_offset, .standard);
    }
    pub fn initWithFormat(history: []const u8, input: []const u8, window_bits: u8, frame_offset: u64, format: distance.Format) Error!Source {
        const maximum: u8 = if (format == .standard) 24 else 30;
        if (window_bits < 10 or window_bits > maximum or history.len > frame_offset) return error.InvalidBlockPlan;
        const window_len = (@as(usize, 1) << @intCast(window_bits)) - 16;
        const source: Source = .{ .history = history[history.len - @min(history.len, window_len) ..], .input = input, .window_len = window_len, .frame_offset = frame_offset, .format = format };
        try source.validate();
        return source;
    }
    pub fn validate(self: Source) Error!void {
        const max_bits: u5 = if (self.format == .standard) 24 else 30;
        const maximum = (@as(usize, 1) << max_bits) - 16;
        if (self.window_len < (1 << 10) - 16 or self.window_len > maximum or self.history.len > self.window_len or self.history.len > self.frame_offset)
            return error.InvalidBlockPlan;
        const size = std.math.add(usize, self.window_len, 16) catch return error.IntegerOverflow;
        if (!std.math.isPowerOfTwo(size)) return error.InvalidBlockPlan;
        _ = try self.checkedTotalLen();
        _ = try self.absolutePosition(self.input.len);
    }
    pub fn prefixLen(self: Source) usize {
        return self.history.len;
    }
    pub fn totalLen(self: Source) usize {
        return self.history.len + self.input.len;
    }
    pub fn checkedTotalLen(self: Source) Error!usize {
        return std.math.add(usize, self.history.len, self.input.len) catch error.IntegerOverflow;
    }
    pub fn absolutePosition(self: Source, input_position: usize) Error!u64 {
        if (input_position > self.input.len) return error.InvalidBlockPlan;
        const local = std.math.cast(u64, input_position) orelse return error.IntegerOverflow;
        return std.math.add(u64, self.frame_offset, local) catch error.IntegerOverflow;
    }
    pub fn maxBackward(self: Source, input_position: usize) Error!usize {
        const window = std.math.cast(u64, self.window_len) orelse return error.IntegerOverflow;
        return std.math.cast(usize, @min(try self.absolutePosition(input_position), window)) orelse error.IntegerOverflow;
    }
    pub fn byteAt(self: Source, position: usize) u8 {
        return if (position < self.history.len) self.history[position] else self.input[position - self.history.len];
    }
    pub fn byteAtChecked(self: Source, position: usize) Error!u8 {
        if (position >= try self.checkedTotalLen()) return error.InvalidBlockPlan;
        return self.byteAt(position);
    }
    pub fn match(self: Source, input_position: usize, candidate: usize, minimum: usize) Match {
        if (input_position > self.input.len or minimum > self.input.len - input_position) return .{};
        const position = self.prefixLen() + input_position;
        if (candidate >= position or position - candidate > self.window_len) return .{};
        var length: usize = 0;
        while (length < self.input.len - input_position and self.byteAt(candidate + length) == self.input[input_position + length]) : (length += 1) {}
        return if (length >= minimum) .{ .length = length, .distance = position - candidate } else .{};
    }
};

test {
    _ = @import("large_window_types_tests.zig");
}
