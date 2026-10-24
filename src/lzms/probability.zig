const std = @import("std");

pub const bits = 6;
pub const denominator = 1 << bits;
const initial_probability = 48;
const initial_recent_bits: u64 = 0x0000_0000_5555_5555;

pub const Entry = struct {
    zero_count: u32 = initial_probability,
    recent_bits: u64 = initial_recent_bits,

    pub fn probability(self: Entry) u32 {
        return if (self.zero_count == 0)
            1
        else if (self.zero_count == denominator)
            denominator - 1
        else
            self.zero_count;
    }

    pub fn update(self: *Entry, bit: u1) void {
        const oldest: u1 = @truncate(self.recent_bits >> 63);
        if (oldest > bit) {
            self.zero_count += 1;
        } else if (oldest < bit) {
            self.zero_count -= 1;
        }
        self.recent_bits = (self.recent_bits << 1) | bit;
    }
};

test "LZMS probability history remains bounded" {
    var entry = Entry{};
    for (0..256) |_|
        entry.update(0);
    try std.testing.expectEqual(@as(u32, denominator), entry.zero_count);
    try std.testing.expectEqual(@as(u32, denominator - 1), entry.probability());
    for (0..256) |_|
        entry.update(1);
    try std.testing.expectEqual(@as(u32, 0), entry.zero_count);
    try std.testing.expectEqual(@as(u32, 1), entry.probability());
}
