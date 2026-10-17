const std = @import("std");

pub const min_window_bits: u5 = 15;
pub const max_window_bits: u5 = 21;

const position_slot_counts = [_]u8{ 30, 32, 34, 36, 38, 42, 50 };

pub fn positionSlotCount(window_bits: u5) usize {
    std.debug.assert(window_bits >= min_window_bits and window_bits <= max_window_bits);
    return position_slot_counts[window_bits - min_window_bits];
}

pub fn positionExtraBits(slot: usize) usize {
    if (slot < 4) return 0;
    if (slot < 36) return slot / 2 - 1;
    return 17;
}

/// Returns the first real match offset represented by an explicit slot.
pub fn positionBase(slot: usize) usize {
    std.debug.assert(slot >= 3 and slot <= 50);
    var base: usize = 0;
    for (0..slot) |index|
        base += @as(usize, 1) << @intCast(positionExtraBits(index));
    return base - 2;
}

test "LZX position slots span every supported WIM window" {
    for (min_window_bits..max_window_bits + 1) |raw_window_bits| {
        const window_bits: u5 = @intCast(raw_window_bits);
        const slots = positionSlotCount(window_bits);
        const last = slots - 1;
        const last_end = positionBase(last) +
            (@as(usize, 1) << @intCast(positionExtraBits(last)));
        try std.testing.expectEqual(
            (@as(usize, 1) << @intCast(window_bits)) - 2,
            last_end,
        );
    }
}
