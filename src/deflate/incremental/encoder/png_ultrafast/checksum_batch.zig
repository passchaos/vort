const Adler32 = @import("../../../../checksum.zig").Adler32;

/// Batch-local Adler recurrence using the word already loaded by the token
/// scanner. At most 4096 bytes are accepted before reduction, below NMAX5552.
/// Each eight-byte weighted fold fits u16 (maximum 9180) and the complete
/// unreduced a/b recurrence fits u32. No source is rescanned or heap retained.
pub const Accumulator = struct {
    a: u32,
    b: u32,

    pub inline fn zero(self: *Accumulator, bytes: usize) void {
        self.b += self.a * @as(u32, @intCast(bytes));
    }
    pub inline fn word(self: *Accumulator, bytes: u64) void {
        const native = if (comptime @import("builtin").cpu.arch.endian() == .big) @byteSwap(bytes) else bytes;
        const octets: @Vector(8, u8) = @bitCast(native);
        const wide: @Vector(8, u16) = octets;
        const weights: @Vector(8, u16) = .{ 8, 7, 6, 5, 4, 3, 2, 1 };
        self.b += self.a * 8 + @as(u32, @reduce(.Add, wide * weights));
        self.a += @reduce(.Add, wide);
    }
    pub inline fn commit(self: Accumulator, adler: *Adler32) void {
        adler.a = self.a % 65521;
        adler.b = self.b % 65521;
    }
};
