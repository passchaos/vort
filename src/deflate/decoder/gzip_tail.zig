//! Terminal policy shared by gzip buffer and source decoders.
const std = @import("std");

pub fn validateOptions(options: anytype) error{InvalidBlockPlan}!void {
    if (options.allow_trailing_data and options.allow_trailing_zero_padding) return error.InvalidBlockPlan;
}

pub fn validateZeros(suffix: []const u8) error{TrailingData}!void {
    if (!std.mem.allEqual(u8, suffix, 0)) return error.TrailingData;
}

pub fn validateSuffix(suffix: []const u8, options: anytype) error{TrailingData}!void {
    if (suffix.len == 0 or options.allow_trailing_data) return;
    if (!options.allow_trailing_zero_padding) return error.TrailingData;
    try validateZeros(suffix);
}

/// Opt in only at a validated member boundary, never at the start of input.
pub fn startsPadding(input: []const u8, offset: usize, options: anytype) bool {
    return options.allow_trailing_zero_padding and offset != 0 and offset < input.len and input[offset] == 0;
}

pub fn isTerminalPadding(input: []const u8, offset: usize, options: anytype) error{TrailingData}!bool {
    if (!startsPadding(input, offset, options)) return false;
    try validateZeros(input[offset..]);
    return true;
}
