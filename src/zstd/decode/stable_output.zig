//! Caller-owned output storage doubles as bounded current-frame history.
const std = @import("std");
const core = @import("../../core.zig");
const count = core.stream_count;
const Count = core.StreamCount;
pub const Error = core.Error;

pub fn overlaps(first: []const u8, second: []const u8) bool {
    if (first.len == 0 or second.len == 0) return false;
    const a = @intFromPtr(first.ptr);
    const b = @intFromPtr(second.ptr);
    // Subtraction avoids overflow from a synthetic end address.
    return if (a <= b) b - a < first.len else a - b < second.len;
}

/// Validate complete borrowed storage before output or frame state changes.
/// The header owner also invokes this for a full dictionary's entropy bytes.
pub fn validateAlias(output: []const u8, dictionary: []const u8) Error!void {
    if (overlaps(output, dictionary)) return error.InvalidBlockPlan;
}

/// Value-only view. Construct it again after producing output rather than
/// caching a pointer into the decoder or a stale produced-length snapshot.
pub const HistoryBackend = struct {
    dictionary: []const u8,
    output: []const u8,
    len: Count,

    /// `limit` is the combined cap supplied by the decoder's existing
    /// historyLength contract. Individual slices remain physically bounded.
    pub fn init(dictionary: []const u8, output: []const u8, limit: Count) Error!HistoryBackend {
        const output_len = count.bounded(limit, output.len);
        const dictionary_len = count.bounded(limit - count.fromLocal(output_len), dictionary.len);
        return .{
            .dictionary = dictionary[dictionary.len - dictionary_len ..],
            .output = output[output.len - output_len ..],
            .len = try count.addLocal(count.fromLocal(dictionary_len), output_len),
        };
    }

    pub fn byteBack(self: HistoryBackend, distance: usize) Error!u8 {
        if (distance == 0 or count.fromLocal(distance) > self.len) return error.InvalidMatch;
        const source = self.len - count.fromLocal(distance);
        if (source < count.fromLocal(self.dictionary.len))
            return self.dictionary[try count.toLocal(source)];
        return self.output[try count.toLocal(source - count.fromLocal(self.dictionary.len))];
    }

    /// Copy an existing chronological span. A match longer than its distance
    /// uses copyMatch so newly produced bytes participate in forward overlap.
    pub fn readBack(self: HistoryBackend, distance: usize, destination: []u8) Error!void {
        if (distance == 0 or count.fromLocal(distance) > self.len or destination.len > distance)
            return error.InvalidMatch;
        try self.validateDestination(destination);
        var source = self.len - count.fromLocal(distance);
        var written: usize = 0;
        const dictionary_len = count.fromLocal(self.dictionary.len);
        if (source < dictionary_len) {
            const n = count.bounded(dictionary_len - source, destination.len);
            const next_source = try count.addLocal(source, n);
            const local_source = try count.toLocal(source);
            @memcpy(destination[0..n], self.dictionary[local_source..][0..n]);
            source = next_source;
            written = n;
        }
        if (written != destination.len) {
            const local_source = try count.toLocal(source - dictionary_len);
            @memcpy(destination[written..], self.output[local_source..][0 .. destination.len - written]);
        }
    }

    /// Seed from dictionary/output history, then expand the exact recurrence
    /// through caller storage. No unused buffer byte can become a source.
    pub fn copyMatch(self: HistoryBackend, distance: usize, destination: []u8) Error!void {
        if (distance == 0 or count.fromLocal(distance) > self.len) return error.InvalidMatch;
        try self.validateDestination(destination);
        if (destination.len == 0) return;
        const seed = @min(distance, destination.len);
        try self.readBack(distance, destination[0..seed]);
        if (seed == 1) {
            @memset(destination[1..], destination[0]);
            return;
        }
        var written = seed;
        while (written < destination.len) {
            const n = @min(written, destination.len - written);
            @memcpy(destination[written..][0..n], destination[0..n]);
            written += n;
        }
    }

    fn validateDestination(self: HistoryBackend, destination: []u8) Error!void {
        try validateAlias(destination, self.dictionary);
        try validateAlias(destination, self.output);
    }
};

pub const Binding = struct {
    buffer: ?[]u8 = null,
    /// Caller-visible bytes are published by the decoder's accounting policy,
    /// including committed partial output reported by a later step error.
    written: usize = 0,
    /// Live bytes are usable by later sequences within the same outer step.
    produced: usize = 0,
    frame_start: usize = 0,
    /// Combined history cap, already derived by the header owner.
    window: Count = 0,
    dictionary: []const u8 = &.{},
    frame_active: bool = false,

    pub fn bind(self: *Binding, output: []u8) Error!void {
        if (self.frame_active or self.produced != self.written) return error.InvalidStreamState;
        try validateAlias(output, self.dictionary);
        self.* = .{ .buffer = output };
    }

    pub fn clear(self: *Binding) void {
        self.* = .{};
    }

    /// Reset a decoding session while retaining the caller's chosen storage.
    pub fn reset(self: *Binding) void {
        self.* = .{ .buffer = self.buffer };
    }

    /// An automatically concatenated frame may start before this step's bytes
    /// are published. Its history begins after all live prior output.
    pub fn nextFrame(self: *Binding) void {
        self.clearFramePrefix();
        self.frame_start = self.produced;
    }

    /// Only the main decoder selects and consumes the frame dictionary/prefix.
    pub fn beginFrame(self: *Binding, dictionary: []const u8, limit: Count) Error!void {
        const output = try self.geometry();
        if (self.frame_active) return error.InvalidStreamState;
        try validateAlias(output, dictionary);
        self.frame_start = self.produced;
        self.dictionary = dictionary;
        self.window = limit;
        self.frame_active = true;
    }

    pub fn clearFramePrefix(self: *Binding) void {
        self.dictionary = &.{};
        self.window = 0;
        self.frame_active = false;
    }

    pub fn remaining(self: *const Binding) Error![]u8 {
        const output = try self.geometry();
        return output[self.produced..];
    }

    /// Reserve an unpublished region before the producer mutates caller bytes.
    pub fn destination(self: *const Binding, len: usize) Error![]u8 {
        const output = try self.remaining();
        if (len > output.len) return error.OutputTooSmall;
        return output[0..len];
    }

    pub fn advanceProduced(self: *Binding, len: usize) Error!void {
        _ = try self.destination(len);
        self.produced = std.math.add(usize, self.produced, len) catch return error.IntegerOverflow;
    }

    pub fn publish(self: *Binding) Error!usize {
        _ = try self.geometry();
        const delta = self.produced - self.written;
        self.written = self.produced;
        return delta;
    }

    pub fn published(self: *const Binding) []const u8 {
        const output = self.buffer orelse return &.{};
        std.debug.assert(self.written <= output.len);
        return output[0..self.written];
    }

    pub fn historyBackend(self: *const Binding) Error!HistoryBackend {
        const output = try self.geometry();
        return HistoryBackend.init(self.dictionary, output[self.frame_start..self.produced], self.window);
    }

    pub fn copyMatch(self: *Binding, distance: usize, len: usize) Error![]u8 {
        if (!self.frame_active) return error.InvalidStreamState;
        const destination_bytes = try self.destination(len);
        const history = try self.historyBackend();
        try history.copyMatch(distance, destination_bytes);
        try self.advanceProduced(len);
        return destination_bytes;
    }

    fn geometry(self: *const Binding) Error![]u8 {
        const output = self.buffer orelse return error.InvalidStreamState;
        if (self.written > self.produced or self.produced > output.len or self.frame_start > self.produced)
            return error.InvalidStreamState;
        return output;
    }
};

test "Zstd stable output helper uses live dictionary-crossing matches before publication" {
    var storage: [16]u8 = @splat(0xa5);
    var binding: Binding = .{};
    try binding.bind(&storage);
    try binding.beginFrame("ab", 12);
    (try binding.destination(1))[0] = 'c';
    try binding.advanceProduced(1);
    try std.testing.expectEqual(@as(Count, 3), (try binding.historyBackend()).len);
    try std.testing.expectEqual(@as(u8, 'a'), try (try binding.historyBackend()).byteBack(3));
    _ = try binding.copyMatch(3, 8);
    try std.testing.expectEqualStrings("cabcabcab", storage[0..binding.produced]);
    try std.testing.expectEqual(@as(usize, 0), binding.published().len);
    try std.testing.expectEqual(@as(usize, 9), try binding.publish());
    binding.nextFrame();
    try binding.beginFrame("xy", 4);
    (try binding.destination(1))[0] = 'z';
    try binding.advanceProduced(1);
    try std.testing.expectError(error.InvalidMatch, (try binding.historyBackend()).byteBack(4));
    _ = try binding.copyMatch(3, 3);
    try std.testing.expectEqualStrings("zxyz", storage[9..13]);
    const before = storage;
    try std.testing.expectError(error.OutputTooSmall, binding.copyMatch(1, 4));
    try std.testing.expectEqualSlices(u8, &before, &storage);
    try std.testing.expectEqual(@as(usize, 9), binding.written);
    try std.testing.expectEqual(@as(usize, 13), binding.produced);
    try std.testing.expectEqual(@as(usize, 4), try binding.publish());
}

test "Zstd stable output helper rejects full buffer aliases and clears frame borrows" {
    var storage: [16]u8 = @splat(0xa5);
    var binding: Binding = .{};
    try binding.bind(&storage);
    try std.testing.expectError(error.InvalidBlockPlan, binding.beginFrame(storage[12..14], 4));
    try std.testing.expect(!binding.frame_active);
    try binding.beginFrame("prefix", 32);
    try std.testing.expectEqual(@as(Count, 6), (try binding.historyBackend()).len);
    try std.testing.expectError(error.InvalidStreamState, binding.bind(&storage));
    binding.clearFramePrefix();
    try std.testing.expectEqual(@as(Count, 0), (try binding.historyBackend()).len);
    try std.testing.expectEqual(@as(usize, 0), binding.dictionary.len);
    binding.reset();
    try std.testing.expect(binding.buffer != null);
    binding.clear();
    try std.testing.expect(binding.buffer == null);
}

test "Zstd stable output helper bounds history without narrowing logical limits" {
    var output: [4]u8 = .{ 'd', 'e', 'f', 'g' };
    const wide: Count = @as(Count, 1) << 32;
    const history = try HistoryBackend.init("ABC", &output, wide);
    try std.testing.expectEqual(@as(Count, 7), history.len);
    var destination: [10]u8 = undefined;
    try history.readBack(6, destination[0..5]);
    try std.testing.expectEqualStrings("BCdef", destination[0..5]);
    try history.copyMatch(6, &destination);
    try std.testing.expectEqualStrings("BCdefgBCde", &destination);
    const tail = try HistoryBackend.init("ABC", &output, 4);
    try std.testing.expectEqual(@as(usize, 0), tail.dictionary.len);
    try std.testing.expectEqualStrings("defg", tail.output);
    try std.testing.expectError(error.InvalidBlockPlan, history.copyMatch(1, output[3..]));
    try std.testing.expectEqualStrings("defg", &output);
}

test "Zstd stable output helper retains the exact dictionary plus window suffix" {
    const dictionary = "ABC";
    const output = "123456789";
    const window: usize = 4;
    const capacity = dictionary.len + window;
    for ([_]usize{ window - 1, window, window + 1, capacity - 1, capacity, capacity + 1 }) |produced| {
        var oracle: [dictionary.len + output.len]u8 = undefined;
        @memcpy(oracle[0..dictionary.len], dictionary);
        @memcpy(oracle[dictionary.len..][0..produced], output[0..produced]);
        const total = dictionary.len + produced;
        const retained: usize = @min(total, capacity);
        const expected = oracle[total - retained .. total];
        const history = try HistoryBackend.init(dictionary, output[0..produced], capacity);
        try std.testing.expectEqual(@as(Count, retained), history.len);
        for (1..retained + 1) |distance|
            try std.testing.expectEqual(expected[retained - distance], try history.byteBack(distance));
        try std.testing.expectError(error.InvalidMatch, history.byteBack(retained + 1));
    }
}

test "Zstd stable output helper starts the next frame after unpublished live bytes" {
    var storage: [8]u8 = @splat(0xa5);
    var binding: Binding = .{};
    try binding.bind(&storage);
    try binding.beginFrame(&.{}, 8);
    @memcpy(try binding.destination(2), "ab");
    try binding.advanceProduced(2);
    try std.testing.expectEqual(@as(usize, 0), binding.written);
    binding.nextFrame();
    try std.testing.expectEqual(@as(usize, 2), binding.frame_start);
    try binding.beginFrame(&.{}, 8);
    try std.testing.expectEqual(@as(Count, 0), (try binding.historyBackend()).len);
    try std.testing.expectError(error.InvalidMatch, binding.copyMatch(1, 2));
    @memcpy(try binding.destination(2), "xy");
    try binding.advanceProduced(2);
    try std.testing.expectEqual(@as(u8, 'x'), try (try binding.historyBackend()).byteBack(2));
    try std.testing.expectError(error.InvalidMatch, (try binding.historyBackend()).byteBack(3));
    try std.testing.expectEqual(@as(usize, 4), try binding.publish());
    try std.testing.expectEqualStrings("abxy", binding.published());
}

test "Zstd stable output helper accepts unaligned exact buffers and preserves guards" {
    for (0..32) |offset| {
        var storage: [64]u8 = @splat(0xa5);
        var binding: Binding = .{};
        try binding.bind(storage[offset..][0..16]);
        try binding.beginFrame("abcd", 20);
        @memcpy(try binding.destination(2), "XY");
        try binding.advanceProduced(2);
        _ = try binding.copyMatch(6, 14);
        try std.testing.expectEqual(@as(usize, 0), (try binding.remaining()).len);
        try std.testing.expectEqual(@as(usize, 16), try binding.publish());
        try std.testing.expectEqualStrings("XYabcdXYabcdXYab", binding.published());
        const before = storage;
        try std.testing.expectError(error.OutputTooSmall, binding.destination(1));
        try std.testing.expectEqualSlices(u8, &before, &storage);
        for (storage[0..offset]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
        for (storage[offset + 16 ..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    }
}
