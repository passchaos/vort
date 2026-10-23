const std = @import("std");
const container = @import("../container.zig");

/// One-byte-progressive Index/Footer parser. Its counters limit the entire
/// metadata record; only the four-byte CRC and twelve-byte footer are retained.
pub const Decoder = struct {
    stage: enum { indicator, count, unpadded, unpacked, padding, crc, footer, done } = .indicator,
    length: usize = 0,
    record_index: usize = 0,
    value: u64 = 0,
    shift: u6 = 0,
    vli_bytes: usize = 0,
    crc: std.hash.Crc32 = std.hash.Crc32.init(),
    stored_crc: [4]u8 = undefined,
    stored_len: usize = 0,
    footer: [12]u8 = undefined,

    pub fn push(self: *Decoder, byte: u8, records: []const container.BlockRecord, flags: [2]u8, limit: usize) container.Error!bool {
        if (self.length >= limit) return error.OutputLimitExceeded;
        self.length += 1;
        if (self.stage != .crc and self.stage != .footer and self.stage != .done) self.crc.update(&.{byte});
        switch (self.stage) {
            .indicator => {
                if (byte != 0) return error.InvalidXzStream;
                self.stage = .count;
            },
            .count, .unpadded, .unpacked => {
                if (self.vli_bytes == 8 and byte & 0x80 != 0) return error.InvalidXzStream;
                self.value |= @as(u64, byte & 0x7f) << self.shift;
                self.vli_bytes += 1;
                if (byte & 0x80 != 0) {
                    self.shift += 7;
                    return false;
                }
                if (self.vli_bytes > 1 and byte == 0) return error.InvalidXzStream;
                switch (self.stage) {
                    .count => {
                        if (self.value != records.len) return error.InvalidXzStream;
                        self.stage = if (records.len == 0) .padding else .unpadded;
                    },
                    .unpadded => {
                        if (self.value != records[self.record_index].unpadded_size) return error.InvalidXzStream;
                        self.stage = .unpacked;
                    },
                    .unpacked => {
                        if (self.value != records[self.record_index].uncompressed_size) return error.InvalidXzStream;
                        self.record_index += 1;
                        self.stage = if (self.record_index == records.len) .padding else .unpadded;
                    },
                    else => unreachable,
                }
                self.value = 0;
                self.shift = 0;
                self.vli_bytes = 0;
                if (self.stage == .padding and self.length % 4 == 0) self.stage = .crc;
            },
            .padding => {
                if (byte != 0) return error.InvalidXzStream;
                if (self.length % 4 == 0) self.stage = .crc;
            },
            .crc => {
                self.stored_crc[self.stored_len] = byte;
                self.stored_len += 1;
                if (self.stored_len == 4) {
                    if (std.mem.readInt(u32, &self.stored_crc, .little) != self.crc.final()) return error.ChecksumMismatch;
                    self.stored_len = 0;
                    self.stage = .footer;
                }
            },
            .footer => {
                self.footer[self.stored_len] = byte;
                self.stored_len += 1;
                if (self.stored_len == 12) {
                    const footer = self.footer;
                    if (std.hash.Crc32.hash(footer[4..10]) != std.mem.readInt(u32, footer[0..4], .little)) return error.ChecksumMismatch;
                    const backward = (@as(u64, std.mem.readInt(u32, footer[4..8], .little)) + 1) * 4;
                    if (backward != self.length - 12 or !std.mem.eql(u8, footer[8..10], &flags) or !std.mem.eql(u8, footer[10..12], "YZ")) return error.InvalidXzStream;
                    self.stage = .done;
                    return true;
                }
            },
            .done => return error.InvalidStreamState,
        }
        return false;
    }
};
