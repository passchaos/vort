const std = @import("std");
pub const byte_source = @import("../../../io/source.zig");
pub const source_frame = @import("../frame.zig");
pub const source_huffman = @import("../huffman.zig");
pub const source_huffman_literals = @import("../huffman_literals.zig");
pub const source_input = @import("../input.zig");
pub const source_literals = @import("../literals.zig");

pub const numbered_hex = @embedFile("../../testdata/libzstd-numbered-json.frame.hex");
pub const repeat_hex = @embedFile("../../testdata/decodecorpus-predefined-repeat.frame.hex");

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
    fault_span: ?Span = null,
    forbidden: []const Span = &.{},
    calls: usize = 0,
    bytes_returned: usize = 0,
    forbidden_read: bool = false,
    min_observed_offset: ?u64 = null,
    max_observed_offset: u64 = 0,

    pub fn source(self: *TrackingSource) byte_source.Source {
        return .{
            .context = self,
            .len = self.base_offset + @as(u64, @intCast(self.bytes.len)),
            .read_at = readAt,
        };
    }

    pub fn reset(self: *TrackingSource) void {
        self.mode = .normal;
        self.fault_call = null;
        self.fault_span = null;
        self.calls = 0;
        self.bytes_returned = 0;
        self.forbidden_read = false;
        self.min_observed_offset = null;
        self.max_observed_offset = 0;
    }

    fn readAt(raw: *anyopaque, absolute: u64, output: []u8) error{SourceReadFailed}!usize {
        const self: *TrackingSource = @ptrCast(@alignCast(raw));
        self.calls += 1;
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
        const selected = self.fault_call == null or self.fault_call.? == self.calls;
        const in_span = self.fault_span == null or self.fault_span.?.overlaps(offset, output.len);
        if (selected and in_span) switch (self.mode) {
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

pub fn decodeHex(comptime encoded: []const u8) ![]u8 {
    const hex = std.mem.trim(u8, encoded, " \r\n\t");
    const bytes = try std.testing.allocator.alloc(u8, hex.len / 2);
    errdefer std.testing.allocator.free(bytes);
    _ = try std.fmt.hexToBytes(bytes, hex);
    return bytes;
}

pub fn availableRange(source: *TrackingSource) !source_input.Range {
    return source_input.Range.init(
        source.source(),
        source.base_offset,
        @intCast(source.bytes.len),
    );
}

pub fn blockAt(source: *TrackingSource, index: usize) !source_frame.BlockLayout {
    const frame = try source_frame.parseDataFrameHeader(try availableRange(source), .standard);
    var block = try source_frame.parseFirstBlock(frame);
    for (0..index) |_| block = try source_frame.parseBlock(frame, block.next_header_offset);
    return block;
}

pub fn blockBytes(source: *const TrackingSource, block: source_frame.BlockLayout) []const u8 {
    const offset: usize = @intCast(block.payload.offset - source.base_offset);
    const len: usize = @intCast(block.payload.len);
    return source.bytes[offset..][0..len];
}

pub fn PreparedBlock(comptime Support: type) type {
    return struct {
        layout: source_literals.Layout,
        prepared: source_huffman.Prepared(Support.Codec),
    };
}

pub fn prepareBlock(
    comptime Support: type,
    block: source_frame.BlockLayout,
    committed: ?*const Support.Codec.Table,
) !PreparedBlock(Support) {
    const prefix = try source_literals.parsePrefix(block.payload, committed != null);
    var scratch: [source_huffman.maximum_scratch_len]u8 = undefined;
    const prepared = (try source_huffman.prepare(
        Support.Codec,
        prefix,
        committed,
        &scratch,
    )) orelse return error.TestUnexpectedResult;
    return .{
        .layout = try source_literals.finishLayout(prefix),
        .prepared = prepared,
    };
}

pub fn commitIfSuccessful(
    comptime Support: type,
    prepared: *const source_huffman.Prepared(Support.Codec),
    committed: *?Support.Codec.Table,
) void {
    if (prepared.replace_on_block_success) committed.* = prepared.table;
}

pub fn expectedLiterals(
    comptime Support: type,
    oracle: *Support.SliceOracle,
    block: []const u8,
    regenerated_size: usize,
) ![]u8 {
    const output = try std.testing.allocator.alloc(u8, regenerated_size);
    errdefer std.testing.allocator.free(output);
    try Support.decodeSliceLiterals(oracle, block, output);
    return output;
}

pub fn streamRanges(layout: source_literals.Layout) ![4]source_input.Range {
    return switch (layout.streams) {
        .four => |ranges| ranges,
        else => error.TestUnexpectedResult,
    };
}

pub fn oneRange(layout: source_literals.Layout) !source_input.Range {
    return switch (layout.streams) {
        .one => |range| range,
        else => error.TestUnexpectedResult,
    };
}

pub fn relativeSpan(source: *const TrackingSource, range: source_input.Range) Span {
    return .{
        .offset = @intCast(range.offset - source.base_offset),
        .len = @intCast(range.len),
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
