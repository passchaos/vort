const std = @import("std");
const bits = @import("bit_stream.zig");
const BitReader = bits.Reader;
const MsbBitWriter = bits.Writer;
const Model = @import("model.zig").Model;

pub const Decoder = struct {
    reader: BitReader,
    high: u16 = 0xffff,
    low: u16 = 0,
    code: u16 = 0,

    pub fn startFrame(self: *Decoder) !void {
        self.high = 0xffff;
        self.low = 0;
        self.code = @intCast(try self.reader.readBits(16));
    }

    pub fn decodeSymbol(self: *Decoder, model: *Model) !usize {
        if (self.high < self.low or self.code < self.low or self.code > self.high)
            return error.InvalidQuantumStream;

        const total: u32 = model.symbols[0].cumulative;
        const range: u32 = @as(u32, self.high) - self.low + 1;
        const code_range: u32 = @as(u32, self.code) - self.low + 1;
        const scaled = (code_range * total - 1) / range;
        if (scaled >= total) return error.InvalidQuantumStream;

        var boundary_index: usize = 1;
        while (boundary_index < model.entries and
            model.symbols[boundary_index].cumulative > scaled)
        {
            boundary_index += 1;
        }
        const selected = boundary_index - 1;
        const decoded_symbol: usize = model.symbols[selected].symbol;
        const next_cumulative: u32 = model.symbols[boundary_index].cumulative;
        const selected_cumulative: u32 = model.symbols[selected].cumulative;
        const new_high = @as(u32, self.low) + selected_cumulative * range / total - 1;
        const new_low = @as(u32, self.low) + next_cumulative * range / total;
        if (new_high > std.math.maxInt(u16) or new_low > new_high)
            return error.InvalidQuantumStream;
        self.high = @intCast(new_high);
        self.low = @intCast(new_low);
        model.record(boundary_index);

        while (true) {
            if ((self.low & 0x8000) != (self.high & 0x8000)) {
                if ((self.low & 0x4000) != 0 and (self.high & 0x4000) == 0) {
                    self.code ^= 0x4000;
                    self.low &= 0x3fff;
                    self.high |= 0x4000;
                } else break;
            }
            self.low = self.low << 1;
            self.high = (self.high << 1) | 1;
            self.code = (self.code << 1) | @as(u16, @intCast(try self.reader.readBits(1)));
        }
        if (self.code < self.low or self.code > self.high)
            return error.InvalidQuantumStream;
        return decoded_symbol;
    }

    pub fn consumeFrameTrailer(self: *Decoder) !void {
        self.reader.alignToByte();
        var padding: usize = 0;
        while (padding <= 4) : (padding += 1) {
            const byte = try self.reader.readAlignedByte();
            if (byte == 0xff) return;
            if (byte != 0) return error.InvalidQuantumStream;
        }
        return error.InvalidQuantumStream;
    }
};

pub const Encoder = struct {
    writer: *MsbBitWriter,
    low: u32 = 0,
    high: u32 = 0xffff,
    pending_bits: usize = 0,

    pub fn startFrame(self: *Encoder) void {
        self.low = 0;
        self.high = 0xffff;
        self.pending_bits = 0;
    }

    pub fn encodeSymbol(
        self: *Encoder,
        allocator: std.mem.Allocator,
        model: *Model,
        symbol: usize,
    ) !void {
        var selected: usize = 0;
        while (selected < model.entries and model.symbols[selected].symbol != symbol)
            selected += 1;
        if (selected == model.entries) return error.InvalidQuantumStream;

        const total: u32 = model.symbols[0].cumulative;
        const range = self.high - self.low + 1;
        self.high = self.low + @as(u32, model.symbols[selected].cumulative) * range / total - 1;
        self.low += @as(u32, model.symbols[selected + 1].cumulative) * range / total;
        model.record(selected + 1);

        while (true) {
            if (self.high < 0x8000) {
                try self.writeBitAndPending(allocator, 0);
            } else if (self.low >= 0x8000) {
                try self.writeBitAndPending(allocator, 1);
                self.low -= 0x8000;
                self.high -= 0x8000;
            } else if (self.low >= 0x4000 and self.high < 0xc000) {
                self.pending_bits += 1;
                self.low -= 0x4000;
                self.high -= 0x4000;
            } else break;
            self.low <<= 1;
            self.high = (self.high << 1) | 1;
        }
    }

    pub fn finishFrame(self: *Encoder, allocator: std.mem.Allocator) !void {
        self.pending_bits += 1;
        try self.writeBitAndPending(allocator, @intFromBool(self.low >= 0x4000));
    }

    fn writeBitAndPending(
        self: *Encoder,
        allocator: std.mem.Allocator,
        bit: u1,
    ) !void {
        try self.writer.writeBit(allocator, bit);
        while (self.pending_bits != 0) : (self.pending_bits -= 1)
            try self.writer.writeBit(allocator, bit ^ 1);
    }
};
