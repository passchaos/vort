//! Paged reverse-bit access over a stable random-access source range.
//!
//! Zstandard entropy streams terminate with a marker in their final byte and
//! are consumed toward lower source offsets. This reader retains only one
//! caller-owned page and never materializes the complete reverse payload.
const std = @import("std");
const core = @import("../../core.zig");
const source_input = @import("input.zig");

pub const minimum_page_len: usize = 9;
pub const Error = core.Error || source_input.Error;

pub const Snapshot = struct {
    page_loads: u64,
    bytes_loaded: u64,
    descending_loads: u64,
    page_capacity: usize,
    live_page_bytes: usize,
    last_page_offset: ?u64,
};

pub const Checkpoint = struct {
    remaining_bits: usize,
};

pub const Reader = struct {
    range: source_input.Range,
    range_len: usize,
    remaining_bits: usize,
    page: []u8,
    page_start: usize = 0,
    page_len: usize = 0,
    page_loads: u64 = 0,
    bytes_loaded: u64 = 0,
    descending_loads: u64 = 0,
    last_page_start: ?usize = null,

    pub fn init(range: source_input.Range, page: []u8) Error!Reader {
        if (page.len < minimum_page_len) return error.OutputTooSmall;
        if (range.len == 0) return error.TruncatedFrame;
        const range_len = std.math.cast(usize, range.len) orelse
            return error.IntegerOverflow;
        const payload_bits = std.math.mul(usize, range_len - 1, 8) catch
            return error.IntegerOverflow;
        var self = Reader{
            .range = range,
            .range_len = range_len,
            .remaining_bits = 0,
            .page = page,
        };
        try self.ensureBytes(range_len - 1, range_len);
        const last = self.cachedByte(range_len - 1);
        if (last == 0) return error.CorruptFrame;
        const marker_bit: usize = 7 - @clz(last);
        self.remaining_bits = std.math.add(usize, payload_bits, marker_bit) catch
            return error.IntegerOverflow;
        return self;
    }

    pub fn read(self: *Reader, bit_count: u8) Error!usize {
        if (bit_count == 0) return 0;
        if (bit_count > @bitSizeOf(usize)) return error.CorruptFrame;
        if (bit_count > self.remaining_bits) return error.TruncatedFrame;
        const start = self.remaining_bits - bit_count;
        const value = try self.gather(start, self.remaining_bits, bit_count);
        self.remaining_bits = start;
        return value;
    }

    pub fn peek(self: *Reader, bit_count: u8) Error!usize {
        if (bit_count == 0) return 0;
        if (bit_count > @bitSizeOf(usize)) return error.CorruptFrame;
        if (bit_count > self.remaining_bits) return error.TruncatedFrame;
        const start = self.remaining_bits - bit_count;
        return self.gather(start, self.remaining_bits, bit_count);
    }

    pub fn peekSmall(self: *Reader, bit_count: u4) Error!usize {
        return self.peek(bit_count);
    }

    pub fn readSmall(self: *Reader, bit_count: u4) Error!usize {
        return self.read(bit_count);
    }

    pub fn readSmallAvailable(self: *Reader, bit_count: u4) Error!struct { value: usize, count: u4 } {
        const count: u4 = @intCast(@min(@as(usize, bit_count), self.remaining_bits));
        return .{
            .value = if (count == 0) 0 else try self.readSmall(count),
            .count = count,
        };
    }

    pub fn skip(self: *Reader, bit_count: u8) Error!void {
        if (bit_count > self.remaining_bits) return error.TruncatedFrame;
        self.remaining_bits -= bit_count;
    }

    pub fn available(self: Reader) usize {
        return self.remaining_bits;
    }

    pub fn expectEnd(self: Reader) Error!void {
        if (self.remaining_bits != 0) return error.CorruptFrame;
    }

    pub fn checkpoint(self: Reader) Checkpoint {
        return .{ .remaining_bits = self.remaining_bits };
    }

    /// Restore only the logical bit cursor. Cached bytes and telemetry remain
    /// reusable; a later read reloads automatically when the cache no longer
    /// covers the restored position.
    pub fn restore(self: *Reader, saved: Checkpoint) void {
        self.remaining_bits = saved.remaining_bits;
    }

    pub fn snapshot(self: Reader) Snapshot {
        return .{
            .page_loads = self.page_loads,
            .bytes_loaded = self.bytes_loaded,
            .descending_loads = self.descending_loads,
            .page_capacity = self.page.len,
            .live_page_bytes = self.page_len,
            .last_page_offset = if (self.last_page_start) |start|
                std.math.add(u64, self.range.offset, @as(u64, @intCast(start))) catch null
            else
                null,
        };
    }

    fn gather(self: *Reader, start_bit: usize, end_bit: usize, bit_count: u8) Error!usize {
        std.debug.assert(bit_count != 0 and start_bit < end_bit);
        const first_byte = start_bit >> 3;
        const last_byte = (end_bit - 1) >> 3;
        const byte_end = last_byte + 1;
        const byte_count = byte_end - first_byte;
        std.debug.assert(byte_count <= minimum_page_len);
        try self.ensureBytes(first_byte, byte_end);

        var reservoir: u72 = 0;
        for (0..byte_count) |index|
            reservoir |= @as(u72, self.cachedByte(first_byte + index)) << @intCast(index * 8);
        const shift: u7 = @intCast(start_bit & 7);
        const mask: u72 = (@as(u72, 1) << @intCast(bit_count)) - 1;
        return @intCast((reservoir >> shift) & mask);
    }

    fn ensureBytes(self: *Reader, start: usize, end: usize) Error!void {
        std.debug.assert(start < end and end <= self.range_len);
        if (self.page_len != 0 and
            start >= self.page_start and
            end <= self.page_start + self.page_len)
        {
            return;
        }

        const next_start = end - @min(end, self.page.len);
        const next_len = end - next_start;
        const next_loads = std.math.add(u64, self.page_loads, 1) catch
            return error.IntegerOverflow;
        const next_bytes = std.math.add(u64, self.bytes_loaded, @as(u64, @intCast(next_len))) catch
            return error.IntegerOverflow;
        const descending = if (self.last_page_start) |previous|
            @intFromBool(next_start < previous)
        else
            0;
        const next_descending = std.math.add(u64, self.descending_loads, descending) catch
            return error.IntegerOverflow;

        // A failed refill invalidates the old cache but never advances the bit
        // cursor. Callers may reset or retry according to their source policy.
        self.page_len = 0;
        try self.range.readExact(@intCast(next_start), self.page[0..next_len]);
        self.page_start = next_start;
        self.page_len = next_len;
        self.page_loads = next_loads;
        self.bytes_loaded = next_bytes;
        self.descending_loads = next_descending;
        self.last_page_start = next_start;
    }

    fn cachedByte(self: Reader, relative: usize) u8 {
        std.debug.assert(self.page_len != 0 and
            relative >= self.page_start and
            relative < self.page_start + self.page_len);
        return self.page[relative - self.page_start];
    }
};

test "Zstd source reverse reader matches slice reads across page boundaries" {
    const byte_source = @import("../../io/source.zig");
    const slice_reader = @import("../sequence/bit_reader.zig");
    var bytes: [257]u8 = undefined;
    for (&bytes, 0..) |*byte, index| byte.* = @truncate(index * 73 + 19);
    bytes[bytes.len - 1] |= 0x80;
    var source_context = byte_source.SliceSource{ .bytes = &bytes };
    const range = try source_input.Range.init(source_context.source(), 0, bytes.len);
    var page: [minimum_page_len]u8 = undefined;
    var actual = try Reader.init(range, &page);
    var expected = try slice_reader.Reader.init(&bytes);
    var width: u8 = 1;
    while (expected.available() != 0) {
        const selected: u8 = @intCast(@min(@as(usize, width), expected.available()));
        try std.testing.expectEqual(try expected.read(selected), try actual.read(selected));
        width = if (width == @min(@bitSizeOf(usize), 31)) 1 else width + 1;
    }
    try actual.expectEnd();
    try std.testing.expect(actual.snapshot().descending_loads != 0);
    try std.testing.expect(actual.snapshot().page_capacity < bytes.len);
}

test "Zstd source reverse reader checkpoint restores across page refills" {
    const byte_source = @import("../../io/source.zig");
    var bytes: [40]u8 = undefined;
    for (&bytes, 0..) |*byte, index| byte.* = @truncate(index * 31 + 7);
    bytes[bytes.len - 1] |= 0x80;
    var source = byte_source.SliceSource{ .bytes = &bytes };
    const range = try source_input.Range.init(source.source(), 0, bytes.len);
    var page: [minimum_page_len]u8 = undefined;
    var reader = try Reader.init(range, &page);
    const saved = reader.checkpoint();
    const expected = try reader.read(9);
    for (0..12) |_| _ = try reader.read(8);
    const loads_before_restore = reader.snapshot().page_loads;
    reader.restore(saved);
    try std.testing.expectEqual(expected, try reader.read(9));
    try std.testing.expect(reader.snapshot().page_loads > loads_before_restore);
}

test "Zstd source reverse reader rejects bit-count overflow before callback" {
    const byte_source = @import("../../io/source.zig");
    const Context = struct {
        calls: usize = 0,
        fn readAt(raw: *anyopaque, _: u64, output: []u8) error{SourceReadFailed}!usize {
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.calls += 1;
            @memset(output, 0x80);
            return output.len;
        }
    };
    var context: Context = .{};
    const overflow_len: u64 = @as(u64, std.math.maxInt(usize) / 8) + 2;
    const source = byte_source.Source{
        .context = &context,
        .len = overflow_len,
        .read_at = Context.readAt,
    };
    const range = try source_input.Range.init(source, 0, overflow_len);
    var page: [minimum_page_len]u8 = undefined;
    try std.testing.expectError(error.IntegerOverflow, Reader.init(range, &page));
    try std.testing.expectEqual(@as(usize, 0), context.calls);
}
