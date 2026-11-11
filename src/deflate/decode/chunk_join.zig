//! Allocation-free coalescing of borrowed compressed spans. Admission finishes
//! before any copy or caller-owned decoder state can be changed.
const std = @import("std");
const alias = @import("../decoder/output_alias.zig");

pub const Error = error{ IntegerOverflow, OutputTooSmall, InvalidBlockPlan };

pub const Borrows = struct {
    /// Buffers/object storage which the join must not overwrite.
    protected: []const []const u8 = &.{},
    /// Dictionary and other bytes read after joining.
    reads: []const []const u8 = &.{},
    /// Caller-buffer decoder output, disjoint from its actual contiguous input
    /// and dictionaries. Original source spans may be reused after coalescing.
    destination: []const u8 = &.{},
    /// Mutable receiver/diagnostics. A refusal must not record an error through
    /// an object that aliases the very borrow being rejected.
    observer: []const u8 = &.{},
};

const Plan = struct {
    joined: []const u8,
    coalesce: bool,
};

pub fn validate(chunks: []const []const u8, scratch: []u8, borrows: Borrows) Error!void {
    _ = try prepare(chunks, scratch, borrows);
}

pub fn join(chunks: []const []const u8, scratch: []u8, borrows: Borrows) Error![]const u8 {
    const plan = try prepare(chunks, scratch, borrows);
    if (!plan.coalesce) return plan.joined;
    const joined = scratch[0..plan.joined.len];
    var offset: usize = 0;
    for (chunks) |chunk| {
        move(joined[offset..][0..chunk.len], chunk);
        offset += chunk.len;
    }
    return joined;
}

fn prepare(chunks: []const []const u8, scratch: []u8, borrows: Borrows) Error!Plan {
    const chunk_table = try descriptorBytes(chunks);
    const protected_table = try descriptorBytes(borrows.protected);
    const read_table = try descriptorBytes(borrows.reads);
    // This receiver may be written even while reporting a size/format error.
    // Refuse its conflicts before any error-recording path can damage a borrow.
    if (borrows.observer.len != 0) {
        const observer = borrows.observer;
        if (alias.overlaps(observer, chunk_table) or
            alias.overlaps(observer, protected_table) or
            alias.overlaps(observer, read_table) or
            alias.overlaps(observer, borrows.destination)) return error.InvalidBlockPlan;
        for (chunks) |chunk| if (alias.overlaps(observer, chunk)) return error.InvalidBlockPlan;
        for (borrows.protected) |span| if (alias.overlaps(observer, span)) return error.InvalidBlockPlan;
        for (borrows.reads) |span| if (alias.overlaps(observer, span)) return error.InvalidBlockPlan;
    }
    var total: usize = 0;
    var single: ?[]const u8 = null;
    var non_empty: usize = 0;
    for (chunks) |chunk| {
        total = std.math.add(usize, total, chunk.len) catch return error.IntegerOverflow;
        if (chunk.len == 0) continue;
        single = chunk;
        non_empty += 1;
    }

    // A single nonempty source is already contiguous. Its unused scratch must
    // impose neither a capacity requirement nor a borrow conflict.
    const coalesce = non_empty > 1;
    const joined = if (non_empty == 1) single.? else blk: {
        if (scratch.len < total) return error.OutputTooSmall;
        break :blk scratch[0..total];
    };
    // No compressed bytes means no join/decode payload writes. Preserve the
    // downstream empty-input error instead of admitting unused output/dict
    // borrows as though a payload existed. Receiver safety was checked above.
    if (total == 0) return .{ .joined = joined, .coalesce = false };
    var first_write: ?usize = null;
    var last_write: usize = 0;
    if (coalesce) {
        var offset: usize = 0;
        for (chunks) |chunk| {
            // Earlier actual writes must not destroy a source still needed by
            // this copy. The current copy itself can safely use memmove.
            if (first_write) |first| {
                if (alias.overlaps(joined[first..last_write], chunk))
                    return error.InvalidBlockPlan;
            }
            if (chunk.len != 0 and chunk.ptr != joined[offset..].ptr) {
                if (first_write == null) first_write = offset;
                last_write = offset + chunk.len;
            }
            offset += chunk.len;
        }
    }

    if (first_write) |first| {
        // Protect the envelope of actual writes, excluding leading/trailing
        // identity spans. Gaps inside it are conservative, without allocating
        // per-chunk metadata or adding a quadratic overlap scan.
        const writes = joined[first..last_write];
        if (alias.overlaps(writes, chunk_table) or
            alias.overlaps(writes, protected_table) or
            alias.overlaps(writes, read_table) or
            alias.overlaps(writes, borrows.destination) or
            alias.overlaps(writes, borrows.observer)) return error.InvalidBlockPlan;
        for (borrows.protected) |span| if (alias.overlaps(writes, span)) return error.InvalidBlockPlan;
        for (borrows.reads) |span| if (alias.overlaps(writes, span)) return error.InvalidBlockPlan;
    }
    if (alias.overlaps(joined, borrows.destination)) return error.InvalidBlockPlan;
    for (borrows.reads) |span|
        if (alias.overlaps(borrows.destination, span)) return error.InvalidBlockPlan;
    return .{ .joined = joined, .coalesce = coalesce };
}

fn descriptorBytes(descriptors: []const []const u8) Error![]const u8 {
    const len = std.math.mul(usize, descriptors.len, @sizeOf([]const u8)) catch return error.IntegerOverflow;
    return @as([*]const u8, @ptrCast(descriptors.ptr))[0..len];
}

fn move(destination: []u8, source: []const u8) void {
    if (source.len == 0 or destination.ptr == source.ptr) return;
    if (!alias.overlaps(destination, source)) {
        @memcpy(destination, source);
    } else if (@intFromPtr(destination.ptr) < @intFromPtr(source.ptr)) {
        std.mem.copyForwards(u8, destination, source);
    } else {
        std.mem.copyBackwards(u8, destination, source);
    }
}
