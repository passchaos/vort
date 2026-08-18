const std = @import("std");
const predefined = @import("predefined.zig");
const reverse_bits = @import("bit_reader.zig");

pub const Error = error{
    CorruptFrame,
    IntegerOverflow,
    InvalidMatch,
    OutputTooSmall,
    TruncatedFrame,
};

pub const Result = struct {
    literal_len: usize,
    match_len: usize,
    offset_base: usize,
    offset_bits: u8,
    offset_extra: usize,
};

/// Decode exactly one all-predefined sequence without constructing the general
/// three-table mode object. Repeat-offset mutation and byte emission remain in
/// the parent codec, keeping this module focused on table/bitstream semantics.
pub fn decode(bitstream: []const u8) Error!Result {
    var reader = try reverse_bits.Reader.init(bitstream);
    const ll = try predefined.literal(try reader.read(6));
    const of = try predefined.offset(try reader.read(5));
    const ml = try predefined.match(try reader.read(6));
    const offset_extra = try reader.read(of.additional_bits);
    const match_len = std.math.add(
        usize,
        ml.base,
        try reader.read(ml.additional_bits),
    ) catch return error.IntegerOverflow;
    const literal_len = std.math.add(
        usize,
        ll.base,
        try reader.read(ll.additional_bits),
    ) catch return error.IntegerOverflow;
    try reader.expectEnd();
    return .{
        .literal_len = literal_len,
        .match_len = match_len,
        .offset_base = of.base,
        .offset_bits = of.additional_bits,
        .offset_extra = offset_extra,
    };
}

test "single predefined sequence rejects missing bitstream" {
    try std.testing.expectError(error.TruncatedFrame, decode(&.{}));
}
