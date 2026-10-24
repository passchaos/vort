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
