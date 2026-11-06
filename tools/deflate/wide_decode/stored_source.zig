//! RFC 1951 byte stream: nonfinal 65535-byte stored blocks and one final
//! remainder (possibly empty). Only one bounded repeated payload exists.
const std = @import("std");
pub const chunk_len = 65536;
pub const repeated = [_]u8{'R'} ** chunk_len;

pub const Source = struct {
    remaining: u64,
    emitted_input: u64 = 0,
    emitted_payload: u64 = 0,
    blocks: u64 = 0,
    header: [5]u8 = undefined,
    header_offset: usize = 5,
    body_remaining: usize = 0,
    final: bool = false,
    ended: bool = false,
    offered_body: bool = false,

    pub fn init(count: u64) Source {
        return .{ .remaining = count };
    }
    pub fn next(self: *Source) []const u8 {
        if (self.ended) return &.{};
        if (self.header_offset < self.header.len) {
            self.offered_body = false;
            return self.header[self.header_offset..];
        }
        if (self.body_remaining != 0) {
            self.offered_body = true;
            return repeated[0..self.body_remaining];
        }
        if (self.final) {
            self.ended = true;
            return &.{};
        }
        self.final = self.remaining < 65535;
        const len: u16 = @intCast(@min(self.remaining, 65535));
        self.header[0] = @intFromBool(self.final);
        std.mem.writeInt(u16, self.header[1..3], len, .little);
        std.mem.writeInt(u16, self.header[3..5], ~len, .little);
        self.header_offset = 0;
        self.body_remaining = len;
        self.remaining -= len;
        self.blocks += 1;
        return self.next();
    }
    pub fn consume(self: *Source, count: usize) !void {
        self.emitted_input = try std.math.add(u64, self.emitted_input, @intCast(count));
        if (self.offered_body) {
            self.body_remaining -= count;
            self.emitted_payload = try std.math.add(u64, self.emitted_payload, @intCast(count));
        } else self.header_offset += count;
    }
};
