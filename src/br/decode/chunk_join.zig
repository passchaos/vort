//! Checked, allocation-free joining of borrowed compressed chunks. Preflight
//! finishes before the first write; descriptors and decode borrows stay live.
const std = @import("std");
const alias = @import("alias.zig");
const shared = @import("../shared_dictionary.zig");
const serialized = @import("../serialized_dictionary.zig");

pub const Error = error{ IntegerOverflow, OutputTooSmall, InvalidBlockPlan, CorruptFrame };

pub fn join(chunks: []const []const u8, scratch: []u8, protected: []const []const u8, dictionary: shared.Dictionary) Error![]const u8 {
    // Check both table extents before reading their first descriptor. In
    // particular, sliceAsBytes must not perform an unchecked multiplication.
    const chunk_table = try descriptorBytes(chunks);
    const protected_table = try descriptorBytes(protected);
    var total: usize = 0;
    for (chunks) |chunk| total = std.math.add(usize, total, chunk.len) catch return error.IntegerOverflow;
    if (scratch.len < total) return error.OutputTooSmall;
    const joined = scratch[0..total];
    if (alias.overlaps(joined, chunk_table) or alias.overlaps(joined, protected_table)) return error.InvalidBlockPlan;
    for (protected) |span| if (alias.overlaps(joined, span)) return error.InvalidBlockPlan;

    // Preserve the scalar dictionary validator's public decode error mapping,
    // but reject an invalid RAW count before touching its descriptor array.
    const raw_count = std.math.add(usize, dictionary.raw_prefixes.len, @intFromBool(if (dictionary.serialized) |view| view.raw_prefix.len != 0 else false)) catch return error.IntegerOverflow;
    if (raw_count > shared.max_raw_prefixes) return error.CorruptFrame;
    dictionary.validate() catch |err| switch (err) {
        error.IntegerOverflow => return error.IntegerOverflow,
        else => return error.CorruptFrame,
    };
    if (dictionary.serialized) |view| {
        if (!nestedCountsSafe(view)) return error.CorruptFrame;
    }
    if (try dictionaryOverlaps(joined, dictionary)) return error.InvalidBlockPlan;

    // A current chunk can move within its own destination. Earlier writes
    // must not touch that chunk's source, however. Track the envelope between
    // the first and last actual write: leading/trailing identity chunks do
    // not create hazards, and an all-identity join remains a no-op. Gaps inside
    // that envelope are conservatively protected without per-chunk storage.
    var first_write: ?usize = null;
    var last_write: usize = 0;
    var offset: usize = 0;
    for (chunks) |chunk| {
        if (first_write) |first| {
            if (alias.overlaps(joined[first..last_write], chunk)) return error.InvalidBlockPlan;
        }
        if (chunk.len != 0 and chunk.ptr != joined[offset..].ptr) {
            if (first_write == null) first_write = offset;
            last_write = offset + chunk.len;
        }
        offset += chunk.len;
    }

    offset = 0;
    for (chunks) |chunk| {
        move(joined[offset..][0..chunk.len], chunk);
        offset += chunk.len;
    }
    return joined;
}

/// Check an observer binding before its first write. This pass only compares
/// borrow geometry; ordinary scalar validation and short-scratch precedence
/// remain in join. Unsafe dictionary counts exclude descriptor traversal here.
pub fn validateObserver(chunks: []const []const u8, scratch: []u8, protected: []const []const u8, dictionary: shared.Dictionary, observer_span: []const u8) Error!void {
    if (observer_span.len == 0) return;
    const chunk_table = try descriptorBytes(chunks);
    const protected_table = try descriptorBytes(protected);
    if (alias.overlaps(observer_span, chunk_table) or alias.overlaps(observer_span, protected_table)) return error.InvalidBlockPlan;
    var total: usize = 0;
    for (chunks) |chunk| total = std.math.add(usize, total, chunk.len) catch return error.IntegerOverflow;
    if (alias.overlaps(observer_span, scratch[0..@min(total, scratch.len)])) return error.InvalidBlockPlan;
    for (chunks) |chunk| if (alias.overlaps(observer_span, chunk)) return error.InvalidBlockPlan;
    for (protected) |span| if (alias.overlaps(observer_span, span)) return error.InvalidBlockPlan;
    if (try dictionaryOverlaps(observer_span, dictionary)) return error.InvalidBlockPlan;
}

fn nestedCountsSafe(view: *const serialized.Dictionary) bool {
    return view.word_list_count <= view.word_lists.len and
        view.transform_list_count <= view.transform_lists.len and
        view.dictionary_count <= view.dictionaries.len;
}

fn dictionaryOverlaps(span: []const u8, dictionary: shared.Dictionary) Error!bool {
    // An excessive count is rejected by scalar validation in join. Protect a
    // representable descriptor-table span without traversing a forged array;
    // unrepresentable invalid counts retain their later scalar error mapping.
    const raw_table_len: ?usize = std.math.mul(usize, dictionary.raw_prefixes.len, @sizeOf([]const u8)) catch null;
    if (raw_table_len) |len| {
        const table = @as([*]const u8, @ptrCast(dictionary.raw_prefixes.ptr))[0..len];
        if (alias.overlaps(span, table)) return true;
    }
    if (dictionary.raw_prefixes.len <= shared.max_raw_prefixes) {
        for (dictionary.raw_prefixes) |prefix| if (alias.overlaps(span, prefix)) return true;
    }
    if (dictionary.serialized) |view| {
        if (alias.overlaps(span, std.mem.asBytes(view)) or
            alias.overlaps(span, view.encoded) or
            alias.overlaps(span, view.raw_prefix)) return true;
        // The geometry pass can still protect each bounded active table when
        // another count is malformed. join rejects the malformed view before
        // using any of these descriptor arrays for decoding.
        if (view.word_list_count <= view.word_lists.len) {
            for (view.word_lists[0..view.word_list_count]) |words| if (alias.overlaps(span, words.data)) return true;
        }
        if (view.transform_list_count <= view.transform_lists.len) {
            for (view.transform_lists[0..view.transform_list_count]) |transforms| {
                if (alias.overlaps(span, transforms.prefix_suffix) or alias.overlaps(span, transforms.transforms)) return true;
                if (transforms.params) |params| if (alias.overlaps(span, params)) return true;
            }
        }
    }
    return false;
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

test "Brotli compressed chunk join borrow contracts" {
    try @import("tests/chunk_borrows.zig").joinContracts();
}
