const std = @import("std");
pub const byte_source = @import("../../../io/source.zig");
pub const source_input = @import("../input.zig");
pub const source_literals = @import("../literals.zig");
pub const source_sequences = @import("../sequences.zig");
pub const source_sequence_cursor = @import("../sequence_cursor.zig");

pub const Mode = enum { normal, zero, excessive, fail };

pub const Span = struct {
    offset: usize,
    len: usize,

    fn overlaps(self: Span, offset: usize, len: usize) bool {
        return offset < self.offset + self.len and self.offset < offset + len;
    }
};

pub const TrackingSource = struct {
    bytes: []const u8,
    base_offset: u64 = 0,
    max_chunk: usize = std.math.maxInt(usize),
    mode: Mode = .normal,
    fault_call: ?usize = null,
    forbidden: []const Span = &.{},
    calls: usize = 0,
    bytes_returned: usize = 0,
    max_requested: usize = 0,
    forbidden_read: bool = false,
    min_observed_offset: ?u64 = null,
    max_observed_offset: u64 = 0,

    pub fn source(self: *TrackingSource, max_read_size: usize) byte_source.Source {
        return .{
            .context = self,
            .len = self.base_offset + @as(u64, @intCast(self.bytes.len)),
            .read_at = readAt,
            .max_read_size = max_read_size,
        };
    }

    pub fn clearFault(self: *TrackingSource) void {
        self.mode = .normal;
        self.fault_call = null;
    }

    fn readAt(raw: *anyopaque, absolute: u64, output: []u8) error{SourceReadFailed}!usize {
        const self: *TrackingSource = @ptrCast(@alignCast(raw));
        self.calls += 1;
        self.max_requested = @max(self.max_requested, output.len);
        self.min_observed_offset = if (self.min_observed_offset) |old|
            @min(old, absolute)
        else
            absolute;
        self.max_observed_offset = @max(self.max_observed_offset, absolute);
        if (absolute < self.base_offset) return error.SourceReadFailed;
        const offset = std.math.cast(usize, absolute - self.base_offset) orelse
            return error.SourceReadFailed;
        for (self.forbidden) |span| {
            if (span.overlaps(offset, output.len)) {
                self.forbidden_read = true;
                return error.SourceReadFailed;
            }
        }
        if (self.fault_call == null or self.fault_call.? == self.calls) switch (self.mode) {
            .normal => {},
            .zero => return 0,
            .excessive => return output.len + 1,
            .fail => return error.SourceReadFailed,
        };
        if (offset >= self.bytes.len) return 0;
        const amount = @min(self.max_chunk, @min(output.len, self.bytes.len - offset));
        @memcpy(output[0..amount], self.bytes[offset..][0..amount]);
        self.bytes_returned += amount;
        return amount;
    }
};

pub fn expectedError(mode: Mode) anyerror {
    return switch (mode) {
        .zero => error.TruncatedFrame,
        .excessive, .fail => error.SourceReadFailed,
        .normal => unreachable,
    };
}

pub fn layoutFor(range: source_input.Range, sequence_count: usize) !source_literals.Layout {
    const empty = try range.subrange(0, 0);
    return .{
        .kind = .raw,
        .size_format = 0,
        .regenerated_size = 0,
        .compressed_size = 0,
        .header_range = empty,
        .literal_payload = empty,
        .tree_description = null,
        .streams = .none,
        .sequence_count = sequence_count,
        .sequence_count_range = empty,
        .sequence_payload = range,
    };
}

pub fn prepareRange(
    comptime Support: type,
    fixture: *const Support.OwnedFixture,
    range: source_input.Range,
) !source_sequences.Prepared(Support.Tables) {
    const layout = try layoutFor(range, fixture.sequence_count);
    var scratch: [1]u8 = undefined;
    return (try source_sequences.prepare(
        Support.Codec,
        layout,
        if (fixture.previous_tables) |*tables| tables else null,
        &scratch,
    )) orelse error.TestUnexpectedResult;
}

pub fn prepareFixture(
    comptime Support: type,
    fixture: *const Support.OwnedFixture,
    source: *TrackingSource,
    max_read_size: usize,
) !source_sequences.Prepared(Support.Tables) {
    const range = try source_input.Range.init(
        source.source(max_read_size),
        source.base_offset,
        @intCast(fixture.bytes.len),
    );
    return prepareRange(Support, fixture, range);
}

pub fn expectSequenceEqual(expected: anytype, actual: anytype) !void {
    try std.testing.expectEqual(expected.literal_len, actual.literal_len);
    try std.testing.expectEqual(expected.match_len, actual.match_len);
    try std.testing.expectEqual(expected.match_offset, actual.match_offset);
}

pub fn expectStep(
    step: anytype,
    sequence: anytype,
    snapshot: source_sequence_cursor.Snapshot,
    decoded: usize,
    remaining: usize,
) !void {
    try expectSequenceEqual(step.sequence, sequence);
    try std.testing.expectEqual(decoded, snapshot.decoded);
    try std.testing.expectEqual(remaining, snapshot.remaining);
    try std.testing.expectEqual(step.ll_state, snapshot.ll_state);
    try std.testing.expectEqual(step.of_state, snapshot.of_state);
    try std.testing.expectEqual(step.ml_state, snapshot.ml_state);
    try std.testing.expectEqual(step.repeated_offsets, snapshot.repeated_offsets);
    try std.testing.expectEqual(step.remaining_bits, snapshot.reader_remaining_bits);
    try std.testing.expectEqual(remaining == 0, snapshot.finished);
}

pub fn expectSemanticSnapshotEqual(
    expected: source_sequence_cursor.Snapshot,
    actual: source_sequence_cursor.Snapshot,
) !void {
    try std.testing.expectEqual(expected.decoded, actual.decoded);
    try std.testing.expectEqual(expected.remaining, actual.remaining);
    try std.testing.expectEqual(expected.ll_state, actual.ll_state);
    try std.testing.expectEqual(expected.of_state, actual.of_state);
    try std.testing.expectEqual(expected.ml_state, actual.ml_state);
    try std.testing.expectEqual(expected.repeated_offsets, actual.repeated_offsets);
    try std.testing.expectEqual(expected.reader_remaining_bits, actual.reader_remaining_bits);
    try std.testing.expectEqual(expected.finished, actual.finished);
}

pub fn expectPageCanaries(storage: []const u8, page_len: usize) !void {
    try std.testing.expectEqual(@as(u8, 0x39), storage[0]);
    try std.testing.expectEqual(@as(u8, 0xc6), storage[page_len + 1]);
}

pub fn resolvedTupleIndex(comptime Support: type, modes: [3]Support.ResolvedMode) u5 {
    return @intCast(@as(usize, @intFromEnum(modes[0])) * 9 +
        @as(usize, @intFromEnum(modes[1])) * 3 +
        @as(usize, @intFromEnum(modes[2])));
}

pub fn wireTupleIndex(comptime Support: type, modes: [3]Support.Mode) u6 {
    return @intCast(@as(usize, @intFromEnum(modes[0])) * 16 +
        @as(usize, @intFromEnum(modes[1])) * 4 +
        @as(usize, @intFromEnum(modes[2])));
}
