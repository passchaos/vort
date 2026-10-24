const std = @import("std");
const syntax = @import("../../../../png_ultrafast.zig").incremental_syntax;

/// A batch-local reservoir borrowing existing output storage. Scalar fields
/// remain independent of the encoder/pending bytes until the batch commits.
pub const Writer = struct {
    output: []u8,
    used: usize,
    bits: u64,
    bit_count: u6,

    pub inline fn writeBitsBulk(self: *Writer, value: u64, count: u6) void {
        std.debug.assert(count <= 48 and self.output.len - self.used >= 8);
        const joined = self.bits | (value << self.bit_count);
        const total: u7 = @as(u7, self.bit_count) + count;
        const bytes: usize = total / 8;
        std.mem.writeInt(u64, self.output[self.used..][0..8], joined, .little);
        self.used += bytes;
        self.bits = joined >> @intCast(bytes * 8);
        self.bit_count = @intCast(total % 8);
    }

    /// Complete one canonical zero run. The calling queue loop bounds run size
    /// and output capacity before entry; long carried runs use the old resumable
    /// token path instead. Bits and token decisions exactly match that path.
    pub inline fn zeroRun(self: *Writer, length: usize) void {
        if (length == 0) return;
        self.writeBitsBulk(syntax.codes[0], syntax.lengths[0]);
        var remaining = length - 1;
        while (remaining >= 258) : (remaining -= 258)
            self.writeBitsBulk(syntax.codes[285], @as(u6, syntax.lengths[285]) + 1);
        if (remaining > 4) {
            const selected = syntax.length(remaining);
            self.writeBitsBulk(syntax.codes[selected.symbol], syntax.lengths[selected.symbol]);
            self.writeBitsBulk(selected.extra, @as(u6, selected.extra_bits) + 1);
        } else if (remaining != 0) {
            self.writeBitsBulk(0, @intCast(remaining * syntax.lengths[0]));
        }
    }
};
