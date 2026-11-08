const std = @import("std");
pub const byte_source = @import("../../../io/source.zig");
pub const literal_stream = @import("../literal_stream.zig");
pub const reverse = @import("../reverse_bit_reader.zig");
pub const source_huffman = @import("../huffman.zig");
pub const source_input = @import("../input.zig");
pub const source_literals = @import("../literals.zig");
pub const huffman_common = @import("../huffman_literal_tests/common.zig");

pub const Mode = enum {
    normal,
    zero,
    excessive,
    fail,
};

pub const TrackingSource = struct {
    bytes: []const u8,
    base_offset: u64 = 0,
    max_chunk: usize = std.math.maxInt(usize),
    mode: Mode = .normal,
    fault_call: ?usize = null,
    calls: usize = 0,
    max_requested: usize = 0,
    min_offset: ?u64 = null,

    pub fn source(self: *TrackingSource) byte_source.Source {
        return .{
            .context = self,
            .len = self.base_offset + @as(u64, @intCast(self.bytes.len)),
            .read_at = readAt,
        };
    }

    pub fn clearFault(self: *TrackingSource) void {
        self.mode = .normal;
        self.fault_call = null;
    }

    pub fn resetTelemetry(self: *TrackingSource) void {
        self.calls = 0;
        self.max_requested = 0;
        self.min_offset = null;
    }

    fn readAt(raw: *anyopaque, absolute: u64, output: []u8) error{SourceReadFailed}!usize {
        const self: *TrackingSource = @ptrCast(@alignCast(raw));
        self.calls += 1;
        self.max_requested = @max(self.max_requested, output.len);
        self.min_offset = if (self.min_offset) |old| @min(old, absolute) else absolute;
        const selected = self.fault_call == null or self.fault_call.? == self.calls;
        if (selected) switch (self.mode) {
            .normal => {},
            .zero => return 0,
            .excessive => return output.len + 1,
            .fail => return error.SourceReadFailed,
        };
        if (absolute < self.base_offset) return error.SourceReadFailed;
        const position = std.math.cast(usize, absolute - self.base_offset) orelse
            return error.SourceReadFailed;
        if (position >= self.bytes.len) return 0;
        const amount = @min(self.max_chunk, @min(output.len, self.bytes.len - position));
        @memcpy(output[0..amount], self.bytes[position..][0..amount]);
        return amount;
    }
};

pub const DummyCodec = struct {
    pub const Table = u8;

    pub fn readSymbol(_: *reverse.Reader, _: *const Table) !u8 {
        return error.CorruptFrame;
    }
};

pub fn layout(
    source: *TrackingSource,
    kind: @import("../../literals/header.zig").Kind,
    regenerated_size: usize,
) !source_literals.Layout {
    const payload = try source_input.Range.init(
        source.source(),
        source.base_offset,
        @intCast(source.bytes.len),
    );
    const empty = try payload.subrange(0, 0);
    return .{
        .kind = kind,
        .size_format = 0,
        .regenerated_size = regenerated_size,
        .compressed_size = 0,
        .header_range = empty,
        .literal_payload = payload,
        .tree_description = null,
        .streams = .none,
        .sequence_count = 0,
        .sequence_count_range = empty,
        .sequence_payload = empty,
    };
}

pub fn expectPageCanaries(storage: []const u8, page_len: usize) !void {
    try std.testing.expectEqual(@as(u8, 0x39), storage[0]);
    try std.testing.expectEqual(@as(u8, 0xc6), storage[page_len + 1]);
}

pub fn expectOutputCanaries(storage: []const u8) !void {
    try std.testing.expectEqual(@as(u8, 0x51), storage[0]);
    try std.testing.expectEqual(@as(u8, 0xae), storage[storage.len - 1]);
}

pub fn expectedError(mode: Mode) anyerror {
    return switch (mode) {
        .zero => error.TruncatedFrame,
        .excessive, .fail => error.SourceReadFailed,
        .normal => unreachable,
    };
}
