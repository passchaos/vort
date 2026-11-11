//! Borrow admission for scratch-free readers and their mutable callers.
//! Snapshot-backed dispatch keeps its separate coalescing admission.
const std = @import("std");
const alias = @import("../decoder/output_alias.zig");

pub const Error = error{ IntegerOverflow, InvalidBlockPlan };

pub fn descriptorBytes(chunks: []const []const u8) Error![]const u8 {
    const size = std.math.mul(usize, chunks.len, @sizeOf([]const u8)) catch return error.IntegerOverflow;
    return @as([*]const u8, @ptrCast(chunks.ptr))[0..size];
}

pub fn validateKnownTotal(chunks: []const []const u8, total: usize, dictionary: []const u8, output: []const u8) Error!void {
    const table = try descriptorBytes(chunks);
    if (total == 0) return;
    if (alias.overlaps(output, table) or alias.overlaps(output, dictionary)) return error.InvalidBlockPlan;
    for (chunks) |chunk|
        if (alias.overlaps(output, chunk)) return error.InvalidBlockPlan;
}

pub fn validateWriters(chunks: []const []const u8, total: usize, writers: []const []const u8) Error!void {
    const table = try descriptorBytes(chunks);
    if (total == 0) return;
    for (writers) |writer| {
        if (alias.overlaps(writer, table)) return error.InvalidBlockPlan;
        for (chunks) |chunk|
            if (alias.overlaps(writer, chunk)) return error.InvalidBlockPlan;
    }
}

pub fn validateReceiver(chunks: []const []const u8, dictionary: []const u8, output: []const u8, receiver: []const u8, other_buffers: []const []const u8) Error!void {
    const table = try descriptorBytes(chunks);
    if (alias.overlaps(receiver, table) or alias.overlaps(receiver, dictionary) or
        alias.overlaps(receiver, output)) return error.InvalidBlockPlan;
    for (chunks) |chunk|
        if (alias.overlaps(receiver, chunk)) return error.InvalidBlockPlan;
    for (other_buffers) |buffer|
        if (alias.overlaps(receiver, buffer)) return error.InvalidBlockPlan;
}
