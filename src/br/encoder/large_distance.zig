//! Safe active-distance groups for Large Window Brotli. The wire alphabet
//! describes 62 extra bits, while the supported signed-safe physical range
//! permits only complete groups below 0x7FFFFFFC.
const std = @import("std");

pub const safe_max_distance: usize = 0x7FFFFFFC;
pub const wire_distance_bits: usize = 62;
pub const Limit = struct { alphabet_size: usize, max_distance: usize };

pub fn calculateLimit(npostfix: u2, ndirect: u7) Limit {
    // Locate the group containing the first forbidden physical distance, then
    // retain the preceding whole group. u64 intermediates are host-independent.
    const high: u64 = ((@as(u64, safe_max_distance) - ndirect) >> npostfix) + 4;
    const bits: u6 = std.math.log2_int(u64, high) - 1;
    const half = (high >> bits) & 1;
    const forbidden_group = 2 * (@as(u64, bits) - 1) + half;
    const last_group = forbidden_group - 1;
    const last_bits: u6 = @intCast(last_group / 2 + 1);
    const last_extra = (@as(u64, 1) << last_bits) - 1;
    const base = ((2 + (last_group & 1)) << last_bits) - 4;
    const postfix_mask = (@as(u64, 1) << npostfix) - 1;
    const maximum = ((base + last_extra) << npostfix) + postfix_mask + ndirect + 1;
    return .{
        .alphabet_size = @intCast(16 + @as(u64, ndirect) + ((last_group + 1) << npostfix)),
        .max_distance = @intCast(maximum),
    };
}

pub fn decode(encoded: anytype, npostfix: u2, ndirect: u7) ?usize {
    const limit = calculateLimit(npostfix, ndirect);
    if (encoded.symbol < 16 or encoded.symbol >= limit.alphabet_size) return null;
    const code: u64 = encoded.symbol - 16;
    if (code < ndirect) {
        if (encoded.extra_bits != 0 or encoded.extra != 0) return null;
        return @intCast(code + 1);
    }
    const regular = code - ndirect;
    const group = regular >> npostfix;
    const bits: u64 = group / 2 + 1;
    // Supported active groups never need more than 29 extra bits. The 62-bit
    // format width affects the Huffman symbol encoding, not this safe payload.
    if (bits > 29 or bits != encoded.extra_bits or encoded.extra >= (@as(u64, 1) << @intCast(bits))) return null;
    const mask = (@as(u64, 1) << npostfix) - 1;
    const base = ((2 + (group & 1)) << @intCast(bits)) - 4;
    const physical = ((base + encoded.extra) << npostfix) + (regular & mask) + ndirect + 1;
    if (physical > limit.max_distance or physical > safe_max_distance) return null;
    return std.math.cast(usize, physical);
}
