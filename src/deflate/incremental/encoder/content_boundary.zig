//! Bounded content-defined cuts for independently decodable Deflate segments.
const minimum_span = 8 * 1024;
const hit_bits = 13;
const gear = makeGear();

pub const Scan = struct {
    take: usize,
    hash: u64 = 0,
    boundary: bool = false,
};

/// Scan only bytes that can still fit in the current segment. The hash is a
/// function of at most the last 64 bytes, independent of the stream origin.
/// Callers install the proposed hash/cut only after accepting `take` bytes.
pub fn scan(initial: u64, buffered: usize, maximum: usize, input: []const u8) Scan {
    var hash = initial;
    const minimum = @min(minimum_span, maximum);
    for (input, 0..) |byte, i| {
        hash = (hash << 1) +% gear[byte];
        const length = buffered + i + 1;
        if (length == maximum or (length >= minimum and hash >> (64 - hit_bits) == 0))
            return .{ .take = i + 1, .hash = hash, .boundary = true };
    }
    return .{ .take = input.len, .hash = hash };
}

fn makeGear() [256]u64 {
    @setEvalBranchQuota(5000);
    var result: [256]u64 = undefined;
    var state: u64 = 0x7b2d534a9c61e0f3;
    for (&result) |*entry| {
        state +%= 0x9e3779b97f4a7c15;
        var word = state;
        word = (word ^ (word >> 30)) *% 0xbf58476d1ce4e5b9;
        word = (word ^ (word >> 27)) *% 0x94d049bb133111eb;
        entry.* = word ^ (word >> 31);
    }
    return result;
}
