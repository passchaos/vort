const std = @import("std");

/// Inspect seven additional complete words after an already-known zero word.
/// Loads stay inside the caller's proven 64-byte span and use scalar registers;
/// no carry, heap or separate scratch array is added to the encoder.
pub inline fn followingWordsAreZero(bytes: *const [64]u8) bool {
    var combined: u64 = 0;
    inline for (1..8) |word| combined |= std.mem.readInt(u64, bytes[word * 8 ..][0..8], .little);
    return combined == 0;
}
