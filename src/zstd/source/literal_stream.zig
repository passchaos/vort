//! Uniform source-backed literal execution.
//!
//! Raw literals are staged through the caller-owned page before publication,
//! RLE captures its single source byte during initialization, and Huffman
//! literals delegate to the paged reverse-stream cursor. The page and every
//! borrowed source or prepared table must remain stable for the stream's
//! lifetime. Source backing storage must not alias the exclusive page or any
//! output destination; opaque source contexts make that contract impossible
//! to validate here.
const std = @import("std");
const core = @import("../../core.zig");
const source_huffman = @import("huffman.zig");
const source_huffman_literals = @import("huffman_literals.zig");
const source_input = @import("input.zig");
const source_literals = @import("literals.zig");
const reverse = @import("reverse_bit_reader.zig");

pub const Error = core.Error || source_input.Error;
pub const minimum_page_len = reverse.minimum_page_len;

pub const Kind = enum {
    raw,
    rle,
    huffman,
};

pub const Snapshot = struct {
    kind: Kind,
    decoded: usize,
    remaining: usize,
    finished: bool,
    huffman: ?source_huffman_literals.Snapshot = null,
};

const Raw = struct {
    payload: source_input.Range,
    page: []u8,
    regenerated_size: usize,
    decoded: usize = 0,
    page_position: usize = 0,
    page_len: usize = 0,
    finished: bool = false,

    fn remaining(self: Raw) usize {
        return self.regenerated_size - self.decoded;
    }

    fn copyNext(self: *Raw, dest: []u8) Error!void {
        if (dest.len > self.remaining()) return error.CorruptFrame;
        if (slicesOverlap(dest, self.page)) return error.InvalidStreamState;

        var written: usize = 0;
        while (written < dest.len) {
            if (self.page_position == self.page_len) try self.loadPage();
            const available = self.page_len - self.page_position;
            const amount = @min(available, dest.len - written);
            @memcpy(
                dest[written..][0..amount],
                self.page[self.page_position..][0..amount],
            );
            self.page_position += amount;
            self.decoded += amount;
            written += amount;
        }
        if (self.decoded == self.regenerated_size) self.finished = true;
    }

    fn loadPage(self: *Raw) Error!void {
        std.debug.assert(self.page_position == self.page_len);
        std.debug.assert(self.decoded < self.regenerated_size);
        const amount = @min(self.page.len, self.remaining());
        const relative = std.math.cast(u64, self.decoded) orelse
            return error.IntegerOverflow;

        // Do not publish or advance until every byte in this logical page has
        // arrived. A short read followed by failure may poison `page`, but a
        // retry reloads the complete page from the original source position.
        self.page_position = 0;
        self.page_len = 0;
        try self.payload.readExact(relative, self.page[0..amount]);
        self.page_len = amount;
    }
};

const Rle = struct {
    value: u8,
    regenerated_size: usize,
    decoded: usize = 0,
    finished: bool = false,

    fn remaining(self: Rle) usize {
        return self.regenerated_size - self.decoded;
    }

    fn copyNext(self: *Rle, dest: []u8, page: []u8) Error!void {
        if (dest.len > self.remaining()) return error.CorruptFrame;
        if (slicesOverlap(dest, page)) return error.InvalidStreamState;
        @memset(dest, self.value);
        self.decoded += dest.len;
        if (self.decoded == self.regenerated_size) self.finished = true;
    }
};

pub fn Stream(comptime Codec: type) type {
    return union(Kind) {
        const Self = @This();

        raw: Raw,
        rle: struct {
            state: Rle,
            page: []u8,
        },
        huffman: source_huffman_literals.Cursor(Codec),

        pub fn remaining(self: Self) usize {
            return switch (self) {
                .raw => |raw| raw.remaining(),
                .rle => |rle| rle.state.remaining(),
                .huffman => |huffman| huffman.remaining(),
            };
        }

        pub fn isFinished(self: Self) bool {
            return switch (self) {
                .raw => |raw| raw.finished,
                .rle => |rle| rle.state.finished,
                .huffman => |huffman| huffman.isFinished(),
            };
        }

        pub fn snapshot(self: Self) Snapshot {
            return switch (self) {
                .raw => |raw| .{
                    .kind = .raw,
                    .decoded = raw.decoded,
                    .remaining = raw.remaining(),
                    .finished = raw.finished,
                },
                .rle => |rle| .{
                    .kind = .rle,
                    .decoded = rle.state.decoded,
                    .remaining = rle.state.remaining(),
                    .finished = rle.state.finished,
                },
                .huffman => |huffman| blk: {
                    const detail = huffman.snapshot();
                    break :blk .{
                        .kind = .huffman,
                        .decoded = detail.decoded,
                        .remaining = detail.remaining,
                        .finished = detail.finished,
                        .huffman = detail,
                    };
                },
            };
        }

        /// Copy exactly `dest.len` next literals. `committed` is always the
        /// exact prefix written by this call, including on source or terminal
        /// validation errors. The progress pointer must not alias `dest`, the
        /// caller page, or the stream itself; such invalid calls are rejected
        /// before `committed` can safely be initialized.
        pub fn copyNext(self: *Self, dest: []u8, committed: *usize) Error!void {
            const progress = std.mem.asBytes(committed);
            const stream_storage = std.mem.asBytes(self);
            if (slicesOverlap(progress, dest) or
                slicesOverlap(progress, self.callerPage()) or
                slicesOverlap(progress, stream_storage))
                return error.InvalidStreamState;
            committed.* = 0;
            if (slicesOverlap(dest, stream_storage))
                return error.InvalidStreamState;
            const decoded_before = self.snapshot().decoded;
            defer committed.* = self.snapshot().decoded - decoded_before;

            switch (self.*) {
                .raw => |*raw| try raw.copyNext(dest),
                .rle => |*rle| try rle.state.copyNext(dest, rle.page),
                .huffman => |*huffman| try huffman.copyNext(dest),
            }
        }

        pub fn expectEnd(self: *Self) Error!void {
            return switch (self.*) {
                .raw => |*raw| {
                    if (raw.remaining() != 0) return error.CorruptFrame;
                    raw.finished = true;
                },
                .rle => |*rle| {
                    if (rle.state.remaining() != 0) return error.CorruptFrame;
                    rle.state.finished = true;
                },
                .huffman => |*huffman| huffman.expectEnd(),
            };
        }

        fn callerPage(self: *Self) []u8 {
            return switch (self.*) {
                .raw => |raw| raw.page,
                .rle => |rle| rle.page,
                .huffman => |huffman| huffman.reader.page,
            };
        }
    };
}

pub fn init(
    comptime Codec: type,
    layout: source_literals.Layout,
    pending_huffman: ?*const source_huffman.Prepared(Codec),
    page: []u8,
) Error!Stream(Codec) {
    if (page.len < minimum_page_len) return error.OutputTooSmall;

    return switch (layout.kind) {
        .raw => blk: {
            if (pending_huffman != null or !hasNoHuffmanLayout(layout))
                return error.CorruptFrame;
            const expected_len = std.math.cast(u64, layout.regenerated_size) orelse
                return error.IntegerOverflow;
            if (layout.literal_payload.len != expected_len)
                return error.CorruptFrame;
            break :blk .{ .raw = .{
                .payload = layout.literal_payload,
                .page = page,
                .regenerated_size = layout.regenerated_size,
            } };
        },
        .rle => blk: {
            if (pending_huffman != null or !hasNoHuffmanLayout(layout) or
                layout.literal_payload.len != 1)
                return error.CorruptFrame;
            var literal: [1]u8 = undefined;
            try layout.literal_payload.readExact(0, &literal);
            break :blk .{ .rle = .{
                .state = .{
                    .value = literal[0],
                    .regenerated_size = layout.regenerated_size,
                },
                .page = page,
            } };
        },
        .compressed, .treeless => blk: {
            const prepared = pending_huffman orelse return error.CorruptFrame;
            break :blk .{ .huffman = try source_huffman_literals.init(
                Codec,
                layout,
                prepared,
                page,
            ) };
        },
    };
}

fn hasNoHuffmanLayout(layout: source_literals.Layout) bool {
    if (layout.compressed_size != 0 or layout.tree_description != null)
        return false;
    return switch (layout.streams) {
        .none => true,
        else => false,
    };
}

fn slicesOverlap(a: []const u8, b: []const u8) bool {
    if (a.len == 0 or b.len == 0) return false;
    const a_start = @intFromPtr(a.ptr);
    const b_start = @intFromPtr(b.ptr);
    // Subtraction avoids overflow from a synthetic end address.
    return if (a_start <= b_start)
        b_start - a_start < a.len
    else
        a_start - b_start < b.len;
}
