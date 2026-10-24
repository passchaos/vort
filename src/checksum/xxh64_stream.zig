//! XXH64 streaming state with a full-width length on 32-bit targets.
const std = @import("std");

/// Preserve the standard library's 64-bit state and hot path exactly. Narrow
/// targets use the portable state below, whose total length is always u64.
pub const XxHash64 = if (@bitSizeOf(usize) == 64) std.hash.XxHash64 else WideXxHash64;

const p1: u64 = 0x9e3779b185ebca87;
const p2: u64 = 0xc2b2ae3d27d4eb4f;
const p3: u64 = 0x165667b19e3779f9;
const p4: u64 = 0x85ebca77c2b2ae63;
const p5: u64 = 0x27d4eb2f165667c5;

/// Caller-owned portable XXH64. `total_len` includes buffered tail bytes;
/// `tail_len` is always below 32 after update. A processed-stripe flag keeps
/// the large-input branch independent of any truncated length representation.
/// Length mixing follows XXH64's unsigned 64-bit arithmetic. No heap or pointer
/// into this movable state is retained, and final does not change the state.
pub const WideXxHash64 = struct {
    total_len: u64,
    seed: u64,
    lanes: [4]u64,
    tail: [32]u8,
    tail_len: u8,
    large_input: bool,

    pub fn init(seed: u64) WideXxHash64 {
        return .{
            .total_len = 0,
            .seed = seed,
            .lanes = .{ seed +% p1 +% p2, seed +% p2, seed, seed -% p1 },
            .tail = undefined,
            .tail_len = 0,
            .large_input = false,
        };
    }

    pub fn update(self: *WideXxHash64, input: []const u8) void {
        self.total_len +%= @as(u64, input.len);
        const buffered: usize = self.tail_len;
        if (input.len < 32 - buffered) {
            @memcpy(self.tail[buffered..][0..input.len], input);
            self.tail_len += @intCast(input.len);
            return;
        }
        var offset: usize = 0;
        if (buffered != 0) {
            const needed = 32 - buffered;
            @memcpy(self.tail[buffered..][0..needed], input[0..needed]);
            self.stripe(&self.tail);
            offset = needed;
        }
        while (input.len - offset >= 32) : (offset += 32)
            self.stripe(input[offset..][0..32]);
        const remaining = input.len - offset;
        @memcpy(self.tail[0..remaining], input[offset..]);
        self.tail_len = @intCast(remaining);
    }

    fn stripe(self: *WideXxHash64, bytes: *const [32]u8) void {
        inline for (0..4) |lane|
            self.lanes[lane] = round(self.lanes[lane], std.mem.readInt(u64, bytes[lane * 8 ..][0..8], .little));
        self.large_input = true;
    }

    pub fn final(self: *const WideXxHash64) u64 {
        var hash_value = self.seed +% p5;
        if (self.large_input) {
            hash_value = std.math.rotl(u64, self.lanes[0], 1) +%
                std.math.rotl(u64, self.lanes[1], 7) +%
                std.math.rotl(u64, self.lanes[2], 12) +%
                std.math.rotl(u64, self.lanes[3], 18);
            for (self.lanes) |lane|
                hash_value = (hash_value ^ round(0, lane)) *% p1 +% p4;
        }
        hash_value +%= self.total_len;
        const length: usize = self.tail_len;
        var offset: usize = 0;
        while (length - offset >= 8) : (offset += 8) {
            hash_value ^= round(0, std.mem.readInt(u64, self.tail[offset..][0..8], .little));
            hash_value = std.math.rotl(u64, hash_value, 27) *% p1 +% p4;
        }
        if (length - offset >= 4) {
            hash_value ^= @as(u64, std.mem.readInt(u32, self.tail[offset..][0..4], .little)) *% p1;
            hash_value = std.math.rotl(u64, hash_value, 23) *% p2 +% p3;
            offset += 4;
        }
        while (offset < length) : (offset += 1) {
            hash_value ^= @as(u64, self.tail[offset]) *% p5;
            hash_value = std.math.rotl(u64, hash_value, 11) *% p1;
        }
        hash_value ^= hash_value >> 33;
        hash_value *%= p2;
        hash_value ^= hash_value >> 29;
        hash_value *%= p3;
        return hash_value ^ (hash_value >> 32);
    }

    pub fn hash(seed: u64, input: []const u8) u64 {
        var state = init(seed);
        state.update(input);
        return state.final();
    }
};

fn round(accumulator: u64, word: u64) u64 {
    return std.math.rotl(u64, accumulator +% word *% p2, 31) *% p1;
}

test {
    _ = @import("xxh64_stream/tests.zig");
}
