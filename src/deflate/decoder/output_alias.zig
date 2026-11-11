//! Borrow validation for contiguous caller-buffer Deflate and wrapper decoding.
//! The complete output slice must be disjoint from compressed input and preset
//! dictionary storage before parsing or copying can modify caller memory.
const std = @import("std");
const dictionary_set = @import("../zlib/dictionary_set.zig");

pub fn validate(input: []const u8, dictionary: []const u8, output: []const u8) error{InvalidBlockPlan}!void {
    if (overlaps(output, input) or overlaps(output, dictionary))
        return error.InvalidBlockPlan;
}

pub fn validateSet(input: []const u8, dictionaries: dictionary_set.Set, output: []const u8) error{ IntegerOverflow, InvalidBlockPlan }!void {
    try validate(input, "", output);
    const table_len = std.math.mul(usize, dictionaries.entries.len, @sizeOf(dictionary_set.Entry)) catch return error.IntegerOverflow;
    const table = @as([*]const u8, @ptrCast(dictionaries.entries.ptr))[0..table_len];
    if (overlaps(output, table)) return error.InvalidBlockPlan;
    // Later members may select any entry, so protect the complete set before
    // the first output write instead of checking only the selected dictionary.
    for (dictionaries.entries) |entry|
        if (overlaps(output, entry.bytes)) return error.InvalidBlockPlan;
}

pub fn validateReceiver(receiver: []const u8, input: []const u8, dictionary: []const u8, output: []const u8) error{InvalidBlockPlan}!void {
    // Error recording writes the receiver even when input has no payload.
    if (overlaps(receiver, input) or overlaps(receiver, dictionary) or
        overlaps(receiver, output)) return error.InvalidBlockPlan;
    if (input.len != 0) try validate(input, dictionary, output);
}

/// Compare half-open byte ranges without adding lengths to addresses.
pub fn overlaps(left: []const u8, right: []const u8) bool {
    if (left.len == 0 or right.len == 0) return false;
    const left_start = @intFromPtr(left.ptr);
    const right_start = @intFromPtr(right.ptr);
    return if (left_start <= right_start)
        right_start - left_start < left.len
    else
        left_start - right_start < right.len;
}
