//! Exact stored-wire geometry, independent of byte slices or allocation. The
//! first block absorbs the incoming bit offset; every following full block has
//! identical byte-aligned cost, so large bounds take constant work per chunk.
const std = @import("std");
const bit_count = @import("../../io/bit_count.zig");
const metadata_header = @import("metadata_header.zig");
pub const BitCount = bit_count.BitCount;
pub const Error = bit_count.Error || error{InvalidBlockPlan};
pub const max_block_len: usize = 1 << 24;

fn add(first: BitCount, second: BitCount) Error!BitCount {
    return std.math.add(BitCount, first, second) catch error.IntegerOverflow;
}

fn alignToByte(bits: BitCount) Error!BitCount {
    return add(bits, (8 - bits % 8) % 8);
}

pub fn uncompressed(bits: BitCount, block_len: usize) Error!BitCount {
    if (block_len == 0 or block_len > max_block_len) return error.InvalidBlockPlan;
    const len_minus_one = block_len - 1;
    const mnibbles: BitCount = if (len_minus_one <= 0xffff) 4 else if (len_minus_one <= 0xfffff) 5 else 6;
    // ISLAST + MNIBBLES + MLEN + ISUNCOMPRESSED, then payload alignment.
    const payload_start = try alignToByte(try add(bits, 1 + 2 + mnibbles * 4 + 1));
    return add(payload_start, try bit_count.fromBytes(block_len));
}

pub fn metadata(bits: BitCount, metadata_len: usize) Error!BitCount {
    return metadata_header.addBits(bits, metadata_len);
}

pub fn blocks(bits: BitCount, input_len: usize, block_len: usize) Error!BitCount {
    if (block_len == 0 or block_len > max_block_len) return error.InvalidBlockPlan;
    if (input_len == 0) return bits;
    const first_len = @min(input_len, block_len);
    var result = try uncompressed(bits, first_len);
    const remaining = input_len - first_len;
    const full_count = remaining / block_len;
    if (full_count != 0) {
        const full_bits = try uncompressed(0, block_len);
        const repeated = std.math.mul(BitCount, @as(BitCount, full_count), full_bits) catch return error.IntegerOverflow;
        result = try add(result, repeated);
    }
    const tail = remaining % block_len;
    if (tail != 0) result = try uncompressed(result, tail);
    return result;
}

test {
    _ = @import("stored_bit_bound_tests.zig");
}
