const std = @import("std");
const core = @import("../../core.zig");
pub const Error = core.Error || error{InvalidErofs};
const block_size: usize = 4096;

pub fn blockCount(length: usize) Error!usize {
    if (length == 0) return 0;
    return try checkedAdd(length, block_size - 1) / block_size;
}

pub fn checkedAdd(left: usize, right: usize) Error!usize {
    return std.math.add(usize, left, right) catch return error.IntegerOverflow;
}

pub fn checkedMul(left: usize, right: usize) Error!usize {
    return std.math.mul(usize, left, right) catch return error.IntegerOverflow;
}

pub fn alignForward(value: usize, alignment: usize) Error!usize {
    if (alignment == 0 or !std.math.isPowerOfTwo(alignment)) return error.InvalidErofs;
    return (try checkedAdd(value, alignment - 1)) & ~(alignment - 1);
}
