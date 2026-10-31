const std = @import("std");
const core = @import("../../core.zig");

/// Fixed-reservoir reader used once an incremental Brotli decoder has parsed
/// its bounded header. A checkpoint lets callers make multi-bit Huffman and
/// command operations atomic across arbitrary input boundaries.
pub const Reader = struct {
    input: []const u8,
    input_read: *usize,
    staged_bits: *u128,
    staged_bit_count: *u8,
    /// Wrapping consumed-bit phase, used only for byte alignment. Absolute
    /// stream positions are tracked separately in byte counters.
    stream_bits: *usize,

    pub const Checkpoint = struct {
        input_read: usize,
        staged_bits: u128,
        staged_bit_count: u8,
        stream_bits: usize,
    };

    pub fn init(
        input: []const u8,
        input_read: *usize,
        staged_bits: *u128,
        staged_bit_count: *u8,
        stream_bits: *usize,
    ) Reader {
        return .{
            .input = input,
            .input_read = input_read,
            .staged_bits = staged_bits,
            .staged_bit_count = staged_bit_count,
            .stream_bits = stream_bits,
        };
    }

    pub fn checkpoint(self: *const Reader) Checkpoint {
        return .{
            .input_read = self.input_read.*,
            .staged_bits = self.staged_bits.*,
            .staged_bit_count = self.staged_bit_count.*,
            .stream_bits = self.stream_bits.*,
        };
    }

    pub fn restore(self: *Reader, saved: Checkpoint) void {
        self.input_read.* = saved.input_read;
        self.staged_bits.* = saved.staged_bits;
        self.staged_bit_count.* = saved.staged_bit_count;
        self.stream_bits.* = saved.stream_bits;
    }

    /// Roll back decoded bits while retaining bytes tentatively loaded after
    /// the checkpoint. This is used for multi-field commands whose extra bits
    /// may span several caller chunks; the next attempt can then progress
    /// without requiring the caller to retain an ever-growing input prefix.
    pub fn restoreKeepingInput(self: *Reader, saved: Checkpoint) core.Error!void {
        const consumed_input = self.input_read.* - saved.input_read;
        if (@as(usize, saved.staged_bit_count) + consumed_input * 8 > 127) return error.CorruptFrame;
        self.staged_bits.* = saved.staged_bits;
        for (self.input[saved.input_read..self.input_read.*], 0..) |byte, i|
            self.staged_bits.* |= @as(u128, byte) << @intCast(@as(usize, saved.staged_bit_count) + i * 8);
        self.staged_bit_count.* = @intCast(@as(usize, saved.staged_bit_count) + consumed_input * 8);
        self.stream_bits.* = saved.stream_bits;
    }

    /// Total bits still available across the staged reservoir and unread input.
    /// Huffman fast paths use this after a zero-padded peek so a padded lookup
    /// hit cannot publish a symbol that the real input cannot reach.
    pub fn hasStagedBits(self: *const Reader, count: u4) bool {
        return @as(usize, self.staged_bit_count.*) + (self.input.len - self.input_read.*) * 8 >= count;
    }

    /// Stage just enough input bytes for a zero-padded lookahead and return the
    /// low `count` bits. Staging here means the paired advance does not load
    /// the same bytes a second time. Truncated lookups pad with zeros; callers
    /// must check `hasStagedBits` before consuming.
    pub fn peekBitsPadded(self: Reader, comptime T: type, count: u6) T {
        std.debug.assert(count <= @bitSizeOf(T));
        if (count == 0) return 0;
        while (self.staged_bit_count.* < count and self.input_read.* < self.input.len) {
            self.staged_bits.* |= @as(u128, self.input[self.input_read.*]) << @intCast(self.staged_bit_count.*);
            self.staged_bit_count.* += 8;
            self.input_read.* += 1;
        }
        const mask = (@as(u128, 1) << @intCast(count)) - 1;
        return @intCast(self.staged_bits.* & mask);
    }

    /// Consume bits proven available by `hasStagedBits`. Bytes needed to
    /// complete the staged reservoir are pulled from the caller's input.
    pub fn advanceBitsStagedAssumeAvailable(self: *Reader, count: u6) void {
        std.debug.assert(self.hasStagedBits(@intCast(count)));
        while (self.staged_bit_count.* < count) {
            self.staged_bits.* |= @as(u128, self.input[self.input_read.*]) << @intCast(self.staged_bit_count.*);
            self.staged_bit_count.* += 8;
            self.input_read.* += 1;
        }
        self.staged_bits.* >>= @intCast(count);
        self.staged_bit_count.* -= count;
        self.stream_bits.* +%= count;
    }

    pub fn readBits(self: *Reader, comptime T: type, count: u6) core.Error!T {
        if (count > @bitSizeOf(T)) return error.CorruptFrame;
        while (self.staged_bit_count.* < count) {
            if (self.input_read.* == self.input.len) return error.TruncatedFrame;
            if (self.staged_bit_count.* > 120) return error.CorruptFrame;
            self.staged_bits.* |= @as(u128, self.input[self.input_read.*]) << @intCast(self.staged_bit_count.*);
            self.staged_bit_count.* += 8;
            self.input_read.* += 1;
        }
        if (count == 0) return 0;
        const mask = (@as(u128, 1) << @intCast(count)) - 1;
        const value: T = @intCast(self.staged_bits.* & mask);
        self.staged_bits.* >>= @intCast(count);
        self.staged_bit_count.* -= count;
        self.stream_bits.* +%= count;
        return value;
    }
};

test "Brotli incremental reader peek and advance match committed reads" {
    var input: [40]u8 = undefined;
    var state: u32 = 0x243f_6a88;
    for (&input) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    var ref_read: usize = 0;
    var ref_bits: u128 = 0;
    var ref_count: u8 = 0;
    var ref_stream: usize = 0;
    var fast_read: usize = 0;
    var fast_bits: u128 = 0;
    var fast_count: u8 = 0;
    var fast_stream: usize = 0;
    var reference = Reader.init(&input, &ref_read, &ref_bits, &ref_count, &ref_stream);
    var fast = Reader.init(&input, &fast_read, &fast_bits, &fast_count, &fast_stream);
    const widths = [_]u6{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 };
    var index: usize = 0;
    while (index < 64) : (index += 1) {
        const width = widths[index % widths.len];
        const peeked = fast.peekBitsPadded(u16, width);
        const committed = reference.readBits(u16, width) catch break;
        try std.testing.expectEqual(committed, peeked);
        try std.testing.expect(fast.hasStagedBits(@intCast(width)));
        fast.advanceBitsStagedAssumeAvailable(width);
        try std.testing.expectEqual(ref_read, fast_read);
        try std.testing.expectEqual(ref_bits, fast_bits);
        try std.testing.expectEqual(ref_count, fast_count);
        try std.testing.expectEqual(ref_stream, fast_stream);
    }
    // A short tail is zero-padded by peek but is not reported as decodable.
    while (fast.hasStagedBits(1)) fast.advanceBitsStagedAssumeAvailable(1);
    try std.testing.expect(!fast.hasStagedBits(8));
    try std.testing.expectEqual(@as(u16, 0), fast.peekBitsPadded(u16, 8));
}
