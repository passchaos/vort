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
        if (written.* > output.len) return error.OutputTooSmall;
        if (match_len > output.len - written.*) return error.OutputTooSmall;
        if (step_start > written.*) return error.OutputTooSmall;
        if (distance == 0) return error.InvalidMatch;

        const current = std.math.sub(usize, written.*, step_start) catch
            return error.IntegerOverflow;
        const segments = try self.visibleSegments(dictionary.len, committed_position, current);
        const available = try segments.available();
        if (distance > available) return error.InvalidMatch;

        const destination = written.*;
        const destination_end = std.math.add(usize, destination, match_len) catch
            return error.IntegerOverflow;
        const dictionary_start = std.math.sub(usize, dictionary.len, segments.dictionary_keep) catch
            return error.IntegerOverflow;
        const ring_start = std.math.sub(usize, self.len, segments.ring_keep) catch
            return error.IntegerOverflow;
        const current_start = std.math.sub(usize, written.*, segments.current_keep) catch
            return error.IntegerOverflow;
        const ring_end = std.math.add(usize, segments.dictionary_keep, segments.ring_keep) catch
            return error.IntegerOverflow;
        const source_start = std.math.sub(usize, available, distance) catch
            return error.IntegerOverflow;
        _ = std.math.add(usize, source_start, match_len) catch
            return error.IntegerOverflow;

        var source = source_start;
        var destination_index = destination;
        while (destination_index < destination_end) {
            output[destination_index] = if (source < segments.dictionary_keep)
                dictionary[std.math.add(usize, dictionary_start, source) catch return error.IntegerOverflow]
            else if (source < ring_end)
                self.chronological(std.math.add(
                    usize,
                    ring_start,
                    std.math.sub(usize, source, segments.dictionary_keep) catch return error.IntegerOverflow,
                ) catch return error.IntegerOverflow)
            else if (source < available)
                output[
                    std.math.add(
                        usize,
                        current_start,
                        std.math.sub(usize, source, ring_end) catch return error.IntegerOverflow,
                    ) catch return error.IntegerOverflow
                ]
            else
                output[
                    std.math.add(
                        usize,
                        destination,
                        std.math.sub(usize, source, available) catch return error.IntegerOverflow,
                    ) catch return error.IntegerOverflow
                ];
            source = std.math.add(usize, source, 1) catch return error.IntegerOverflow;
            destination_index = std.math.add(usize, destination_index, 1) catch return error.IntegerOverflow;
        }
        written.* = destination_end;
    }

    pub fn availableLen(self: Binding, dictionary_len: usize, produced: Count) core.Error!usize {
        return (try self.visibleSegments(dictionary_len, produced, 0)).available();
    }

    pub fn availableLenWithCurrent(
        self: Binding,
        dictionary_len: usize,
        committed_position: Count,
        current_len: usize,
    ) core.Error!usize {
        return (try self.visibleSegments(dictionary_len, committed_position, current_len)).available();
    }

    const VisibleSegments = struct {
        dictionary_keep: usize,
        ring_keep: usize,
        current_keep: usize,

        fn available(self: VisibleSegments) core.Error!usize {
            const output_keep = std.math.add(usize, self.ring_keep, self.current_keep) catch
                return error.IntegerOverflow;
            return std.math.add(usize, self.dictionary_keep, output_keep) catch
                return error.IntegerOverflow;
        }
    };

    fn visibleSegments(
        self: Binding,
        dictionary_len: usize,
        committed_position: Count,
        current: usize,
    ) core.Error!VisibleSegments {
        const total_position = try count.addLocal(committed_position, current);
        const window_position = count.fromLocal(self.window);
        const visible = if (total_position < window_position)
            std.math.add(usize, dictionary_len, try count.toLocal(total_position)) catch
                return error.IntegerOverflow
        else
            self.window;
        // Before the window, all dictionary bytes remain addressable. If it exceeds the window,
        // only its newest window-sized suffix can enter the boundary phase-out.
        const phased_dictionary_len = @min(dictionary_len, self.window);
        const dictionary_keep = if (total_position < window_position)
            dictionary_len
        else if (total_position == window_position)
            phased_dictionary_len
        else blk: {
            const crossed_position = std.math.sub(Count, total_position, window_position) catch
                return error.IntegerOverflow;
            const crossed = count.bounded(crossed_position, phased_dictionary_len);
            break :blk std.math.sub(usize, phased_dictionary_len, crossed) catch
                return error.IntegerOverflow;
        };
        const output_keep = std.math.sub(usize, visible, dictionary_keep) catch
            return error.IntegerOverflow;
        const current_keep = @min(current, output_keep);
        const requested_ring_keep = std.math.sub(usize, output_keep, current_keep) catch
            return error.IntegerOverflow;
        return .{
            .dictionary_keep = dictionary_keep,
            .ring_keep = @min(self.len, requested_ring_keep),
            .current_keep = current_keep,
        };
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
    try ring.copyMatch(dictionary, &output, &written, 0, 2, 6, 1);
    try std.testing.expectEqualStrings("W", &output);
    try std.testing.expectEqual(@as(usize, 6), try ring.availableLen(dictionary.len, 2));
    written = 0;
    try ring.copyMatch(dictionary, &output, &written, 0, 3, 3, 1);
    try std.testing.expectEqualStrings("X", &output);
    written = 0;
    try ring.copyMatch(dictionary, &output, &written, 0, 4, 3, 1);
    try std.testing.expectEqualStrings("Y", &output);
    try std.testing.expectEqual(@as(usize, 3), try ring.availableLen(dictionary.len, 3));
    try std.testing.expectEqual(@as(usize, 3), try ring.availableLen(dictionary.len, 4));
    try std.testing.expectEqual(@as(usize, 3), try ring.availableLen(dictionary.len, 7));
}

test "Zstd history workspace dictionary visibility follows window boundaries" {
    const Case = struct { produced: usize, visible: usize, first: u8 };
    const cases = [_]Case{
        .{ .produced = 7, .visible = 10, .first = 'X' },
        .{ .produced = 8, .visible = 8, .first = 'X' },
        .{ .produced = 9, .visible = 8, .first = 'Y' },
        .{ .produced = 11, .visible = 8, .first = 'd' },
        .{ .produced = 12, .visible = 8, .first = 'e' },
    };
    const history = "abcdefghijkl";
    for (cases) |case| {
        var storage: [11]u8 = undefined;
        var ring = try Binding.init(&storage);
        try ring.beginFrame(8, 3);
        ring.append(history[0..case.produced]);
        try std.testing.expectEqual(case.visible, try ring.availableLen(3, case.produced));

        var output: [1]u8 = undefined;
        var written: usize = 0;
        try ring.copyMatch("XYZ", &output, &written, 0, case.produced, case.visible, 1);
        try std.testing.expectEqual(case.first, output[0]);
        written = 0;
        try std.testing.expectError(
            error.InvalidMatch,
            ring.copyMatch("XYZ", &output, &written, 0, case.produced, case.visible + 1, 1),
        );
    }
}

test "Zstd history workspace match crosses dictionary ring current and overlap" {
    var storage: [10]u8 = undefined;
    var ring = try Binding.init(&storage);
    try ring.beginFrame(8, 2);
    ring.append("abc");
    var output: [10]u8 = undefined;
    @memcpy(output[0..2], "xy");
    var written: usize = 2;
    try std.testing.expectEqual(
        @as(usize, 7),
        try ring.availableLenWithCurrent(2, 3, written),
    );
    try ring.copyMatch("DE", &output, &written, 0, 3, 7, 8);
    try std.testing.expectEqualStrings("xyDEabcxyD", &output);
}

test "Zstd history workspace uses wrapped ring suffix and actual retained length" {
    var storage: [7]u8 = undefined;
    var ring = try Binding.init(&storage);
    try ring.beginFrame(5, 2);
    ring.append("0123456789");
    try std.testing.expectEqual(@as(usize, 5), try ring.availableLen(2, 10));
    var output: [5]u8 = undefined;
    var written: usize = 0;
    try ring.copyMatch("XY", &output, &written, 0, 10, 5, 5);
    try std.testing.expectEqualStrings("56789", &output);

    var short_storage: [10]u8 = undefined;
    var short = try Binding.init(&short_storage);
    try short.beginFrame(8, 2);
    short.append("ab");
    try std.testing.expectEqual(@as(usize, 4), try short.availableLen(2, 7));
}

test "Zstd history workspace positions stay wide and additions are checked" {
    var storage: [8]u8 = undefined;
    var ring = try Binding.init(&storage);
    try ring.beginFrame(8, 0);
    ring.append("abcdefgh");
    const wide: Count = (@as(Count, 1) << 32) + 17;
    try std.testing.expectEqual(@as(usize, 8), try ring.availableLen(0, wide));
    var output: [2]u8 = .{ 'q', 0 };
    var written: usize = 0;
    try ring.copyMatch(&.{}, output[0..1], &written, 0, wide, 8, 1);
    try std.testing.expectEqual(@as(u8, 'a'), output[0]);

    written = 1;
    try std.testing.expectError(
        error.IntegerOverflow,
        ring.copyMatch(&.{}, &output, &written, 0, std.math.maxInt(Count), 1, 0),
    );
    written = 3;
    try std.testing.expectError(
        error.OutputTooSmall,
        ring.copyMatch(&.{}, &output, &written, 0, 0, 1, 0),
    );
}
