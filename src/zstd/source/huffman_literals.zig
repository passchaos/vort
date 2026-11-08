//! Resumable, caller-paged Huffman literal execution over source ranges.
//!
//! The cursor decodes literals in logical output order and reuses one caller
//! page while advancing across the four independent reverse streams. It never
//! owns or publishes the prepared Huffman table; block-level state commit stays
//! with the future sequence/match executor.
const std = @import("std");
const core = @import("../../core.zig");
const source_input = @import("input.zig");
const source_huffman = @import("huffman.zig");
const source_literals = @import("literals.zig");
const reverse = @import("reverse_bit_reader.zig");

pub const Error = core.Error || source_input.Error;

pub const Snapshot = struct {
    decoded: usize,
    remaining: usize,
    stream_index: u2,
    segment_end: usize,
    finished: bool,
    reader: reverse.Snapshot,
};

pub fn Cursor(comptime Codec: type) type {
    return struct {
        const Self = @This();

        table: *const Codec.Table,
        streams: source_literals.Streams,
        reader: reverse.Reader,
        regenerated_size: usize,
        segment_len: usize,
        segment_end: usize,
        decoded: usize = 0,
        stream_index: u2 = 0,
        finished: bool = false,

        pub fn remaining(self: Self) usize {
            return self.regenerated_size - self.decoded;
        }

        pub fn isFinished(self: Self) bool {
            return self.finished;
        }

        /// Decode exactly `dest.len` next literals. On error, `snapshot()`
        /// reports the committed output prefix, including symbols written by
        /// this call before a later source refill or stream-boundary failure.
        pub fn copyNext(self: *Self, dest: []u8) Error!void {
            if (dest.len > self.remaining()) return error.CorruptFrame;
            if (try slicesOverlap(dest, self.reader.page))
                return error.InvalidStreamState;
            for (dest) |*out| out.* = try self.readSymbol();
            if (self.decoded == self.regenerated_size) {
                try self.expectEnd();
            } else if (dest.len != 0) {
                try self.advanceCompletedStreams();
            }
        }

        pub fn readSymbol(self: *Self) Error!u8 {
            if (self.decoded >= self.regenerated_size or self.finished)
                return error.CorruptFrame;
            try self.prepareStreamForSymbol();
            const symbol = try Codec.readSymbol(&self.reader, &self.table.*);
            self.decoded += 1;
            return symbol;
        }

        pub fn expectEnd(self: *Self) Error!void {
            if (self.decoded != self.regenerated_size) return error.CorruptFrame;
            while (!self.finished) {
                if (self.decoded != self.segment_end) return error.CorruptFrame;
                try self.finishStream();
            }
        }

        pub fn snapshot(self: Self) Snapshot {
            return .{
                .decoded = self.decoded,
                .remaining = self.remaining(),
                .stream_index = self.stream_index,
                .segment_end = self.segment_end,
                .finished = self.finished,
                .reader = self.reader.snapshot(),
            };
        }

        fn prepareStreamForSymbol(self: *Self) Error!void {
            try self.advanceCompletedStreams();
            if (self.finished or self.decoded > self.segment_end)
                return error.CorruptFrame;
        }

        fn advanceCompletedStreams(self: *Self) Error!void {
            while (self.decoded == self.segment_end and !self.finished)
                try self.finishStream();
        }

        fn finishStream(self: *Self) Error!void {
            try self.reader.expectEnd();
            switch (self.streams) {
                .one => {
                    if (self.decoded != self.regenerated_size)
                        return error.CorruptFrame;
                    self.finished = true;
                },
                .four => |ranges| {
                    if (self.stream_index == 3) {
                        if (self.decoded != self.regenerated_size)
                            return error.CorruptFrame;
                        self.finished = true;
                        return;
                    }
                    const next_index: u2 = self.stream_index + 1;
                    const next_range = ranges[next_index];
                    const page = self.reader.page;
                    self.reader = try reverse.Reader.init(next_range, page);
                    self.stream_index = next_index;
                    self.segment_end = try segmentEnd(
                        self.regenerated_size,
                        self.segment_len,
                        next_index,
                    );
                },
                .none => return error.CorruptFrame,
            }
        }
    };
}

pub fn init(
    comptime Codec: type,
    layout: source_literals.Layout,
    prepared: *const source_huffman.Prepared(Codec),
    page: []u8,
) Error!Cursor(Codec) {
    // `prepared`, its source context, and `page` must remain stable and valid
    // for the cursor lifetime. The page is exclusive to this cursor.
    if (page.len < reverse.minimum_page_len) return error.OutputTooSmall;
    if (layout.kind != .compressed and layout.kind != .treeless)
        return error.CorruptFrame;
    if ((layout.kind == .compressed and prepared.origin != .new_tree) or
        (layout.kind == .treeless and prepared.origin != .treeless_reuse))
        return error.CorruptFrame;
    return switch (layout.streams) {
        .none => error.CorruptFrame,
        .one => |range| blk: {
            break :blk .{
                .table = &prepared.table,
                .streams = .{ .one = range },
                .reader = try reverse.Reader.init(range, page),
                .regenerated_size = layout.regenerated_size,
                .segment_len = layout.regenerated_size,
                .segment_end = layout.regenerated_size,
            };
        },
        .four => |ranges| blk: {
            const segment_len = std.math.add(usize, layout.regenerated_size, 3) catch
                return error.IntegerOverflow;
            const rounded = segment_len / 4;
            const first_three = std.math.mul(usize, rounded, 3) catch
                return error.IntegerOverflow;
            if (first_three > layout.regenerated_size) return error.CorruptFrame;
            break :blk .{
                .table = &prepared.table,
                .streams = .{ .four = ranges },
                .reader = try reverse.Reader.init(ranges[0], page),
                .regenerated_size = layout.regenerated_size,
                .segment_len = rounded,
                .segment_end = rounded,
            };
        },
    };
}

fn slicesOverlap(a: []const u8, b: []const u8) Error!bool {
    if (a.len == 0 or b.len == 0) return false;
    const a_start = @intFromPtr(a.ptr);
    const b_start = @intFromPtr(b.ptr);
    const a_end = std.math.add(usize, a_start, a.len) catch
        return error.IntegerOverflow;
    const b_end = std.math.add(usize, b_start, b.len) catch
        return error.IntegerOverflow;
    return a_start < b_end and b_start < a_end;
}

fn segmentEnd(
    regenerated_size: usize,
    segment_len: usize,
    stream_index: u2,
) Error!usize {
    if (stream_index == 3) return regenerated_size;
    const end = std.math.mul(usize, segment_len, @as(usize, stream_index) + 1) catch
        return error.IntegerOverflow;
    if (end > regenerated_size) return error.CorruptFrame;
    return end;
}
