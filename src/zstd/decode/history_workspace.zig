//! Caller-owned circular history for ordinary incremental Zstd output.
const std = @import("std");
const core = @import("../../core.zig");
const stable = @import("stable_output.zig");

const Count = core.StreamCount;
const count = core.stream_count;

pub fn requiredLen(window_size: Count, dictionary_len: usize) core.Error!usize {
    return count.toLocal(try count.addLocal(window_size, dictionary_len));
}

pub const Binding = struct {
    storage: []u8 = &.{},
    bound: bool = false,
    window: usize = 0,
    limit: usize = 0,
    head: usize = 0,
    len: usize = 0,

    pub fn init(storage: []u8) core.Error!Binding {
        return .{ .storage = storage, .bound = true };
    }

    pub fn active(self: Binding) bool {
        return self.bound;
    }

    pub fn capacity(self: Binding) usize {
        return self.storage.len;
    }

    pub fn beginFrame(self: *Binding, window_size: Count, dictionary_len: usize) core.Error!void {
        const window = try count.toLocal(window_size);
        const limit = try requiredLen(window_size, dictionary_len);
        if (limit > self.storage.len) return error.OutputTooSmall;
        self.window = window;
        self.limit = limit;
        self.head = 0;
        self.len = 0;
    }

    pub fn resetFrame(self: *Binding) void {
        self.limit = 0;
        self.window = 0;
        self.head = 0;
        self.len = 0;
    }

    pub fn clear(self: *Binding) void {
        self.* = .{};
    }

    pub fn validateSlice(self: Binding, other: []const u8) core.Error!void {
        if (!self.active()) return;
        try stable.validateAlias(self.storage, other);
    }

    pub fn validateIo(self: Binding, input: []const u8, output: []const u8) core.Error!void {
        try self.validateSlice(input);
        try self.validateSlice(output);
    }

    pub fn validateDictionary(self: Binding, dictionary: anytype) core.Error!void {
        try self.validateSlice(dictionary.content);
        if (dictionary.standard_bytes) |bytes| try self.validateSlice(bytes);
        if (dictionary.prepared) |prepared| try self.validateSlice(std.mem.asBytes(prepared));
    }

    pub fn append(self: *Binding, bytes: []const u8) void {
        if (bytes.len == 0 or self.limit == 0) return;
        if (bytes.len >= self.limit) {
            @memcpy(self.storage[0..self.limit], bytes[bytes.len - self.limit ..]);
            self.head = 0;
            self.len = self.limit;
            return;
        }
        const first = @min(bytes.len, self.limit - self.head);
        @memcpy(self.storage[self.head..][0..first], bytes[0..first]);
        if (first != bytes.len)
            @memcpy(self.storage[0 .. bytes.len - first], bytes[first..]);
        self.head = (self.head + bytes.len) % self.limit;
        self.len = @min(self.limit, self.len + bytes.len);
    }

    pub fn copyMatch(
        self: Binding,
        dictionary: []const u8,
        output: []u8,
        written: *usize,
        step_start: usize,
        committed_position: Count,
        distance: usize,
        match_len: usize,
    ) core.Error!void {
        if (step_start > written.* or output.len - written.* < match_len)
            return error.OutputTooSmall;
        const current = written.* - step_start;
        const crossed = if (committed_position > count.fromLocal(self.window))
            count.bounded(committed_position - count.fromLocal(self.window), dictionary.len)
        else
            0;
        const dictionary_keep = dictionary.len - crossed;
        const current_keep = current;
        const ring_keep = self.len;
        const available = std.math.add(
            usize,
            dictionary_keep,
            std.math.add(usize, ring_keep, current_keep) catch return error.IntegerOverflow,
        ) catch return error.IntegerOverflow;
        if (distance == 0 or distance > available) return error.InvalidMatch;
        const destination = written.*;
        for (0..match_len) |i| {
            const source = available + i - distance;
            output[destination + i] = if (source < dictionary_keep)
                dictionary[dictionary.len - dictionary_keep + source]
            else if (source < dictionary_keep + ring_keep)
                self.chronological(self.len - ring_keep + source - dictionary_keep)
            else if (source < available)
                output[written.* - current_keep + source - dictionary_keep - ring_keep]
            else
                output[destination + source - available];
        }
        written.* += match_len;
    }

    pub fn availableLen(self: Binding, dictionary_len: usize, produced: Count) core.Error!usize {
        const crossed = if (produced > count.fromLocal(self.window))
            count.bounded(produced - count.fromLocal(self.window), dictionary_len)
        else
            0;
        return std.math.add(usize, self.len, dictionary_len - crossed) catch return error.IntegerOverflow;
    }

    fn chronological(self: Binding, position: usize) u8 {
        std.debug.assert(position < self.len and self.limit != 0);
        const oldest = (self.head + self.limit - self.len) % self.limit;
        return self.storage[(oldest + position) % self.limit];
    }
};

test "Zstd history workspace ring preserves wraps and overlapping matches" {
    var storage: [7]u8 = undefined;
    var ring = try Binding.init(&storage);
    try ring.beginFrame(7, 0);
    ring.append("abcdef");
    ring.append("ghij");
    var output: [13]u8 = undefined;
    var written: usize = 0;
    try ring.copyMatch(&.{}, &output, &written, 0, output.len, 3, output.len);
    try std.testing.expectEqualSlices(u8, "hijhijhijhijh", &output);
    ring.append(&output);
    try std.testing.expectEqual(@as(usize, 7), ring.len);
}

test "Zstd history workspace ring phases dictionary into expanded output history" {
    var storage: [7]u8 = undefined;
    var ring = try Binding.init(&storage);
    const dictionary = "WXYZ";
    try ring.beginFrame(3, dictionary.len);
    ring.append("abc");
    var output: [1]u8 = undefined;
    var written: usize = 0;
    try ring.copyMatch(dictionary, &output, &written, 0, 3, 7, 1);
    try std.testing.expectEqualStrings("W", &output);
    written = 0;
    try ring.copyMatch(dictionary, &output, &written, 0, 4, 6, 1);
    try std.testing.expectEqualStrings("X", &output);
    try std.testing.expectEqual(@as(usize, 7), try ring.availableLen(dictionary.len, 3));
    try std.testing.expectEqual(@as(usize, 6), try ring.availableLen(dictionary.len, 4));
    try std.testing.expectEqual(@as(usize, 3), try ring.availableLen(dictionary.len, 7));
}
