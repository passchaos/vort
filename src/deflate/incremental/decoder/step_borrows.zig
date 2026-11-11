//! Call-wide memory admission before incremental state/progress is modified.
//! The compact ring is independent of caller output. Optional semantic storage
//! becomes a writer only when admitted; collisions keep compact decoding.
const std = @import("std");
const core = @import("../../../core.zig");
const alias = @import("../../decoder/output_alias.zig");

const Error = error{ IntegerOverflow, InvalidBlockPlan };

/// Match physical output clipping. An already-admitted match/stored continuation
/// may outlive a caller's change to max/expected options, so those logical limits
/// alone cannot establish an unused output tail.
pub fn outputPrefix(options: anytype, total_output: core.StreamCount, output: []u8) []u8 {
    var remaining = std.math.maxInt(core.StreamCount) - total_output;
    if (comptime @hasField(@TypeOf(options), "stop_at_output_limit")) {
        if (options.stop_at_output_limit)
            remaining = @min(remaining, options.max_output_len -| total_output);
    }
    return output[0..core.stream_count.bounded(remaining, output.len)];
}

pub fn validate(receiver: []const u8, input: []const u8, output: []const u8, history: []const u8) Error!void {
    if (alias.overlaps(receiver, input) or alias.overlaps(receiver, output) or
        alias.overlaps(receiver, history) or alias.overlaps(input, output) or
        alias.overlaps(input, history) or alias.overlaps(output, history))
        return error.InvalidBlockPlan;
}

/// False only restricts the optional fast path; it never relaxes admission.
pub fn rawAdmission(receiver: []const u8, raw: anytype, input: []const u8, output: []const u8) Error!bool {
    try validate(receiver, input, output, raw.history);
    const admitted = semanticCompatible(receiver, raw, input, output);
    if (raw.phase == .fast_dynamic_block and !admitted)
        return error.InvalidBlockPlan;
    return admitted;
}

fn semanticCompatible(receiver: []const u8, raw: anytype, input: []const u8, output: []const u8) bool {
    const workspace = raw.semantic_decoder orelse return true;
    const tables = std.mem.asBytes(workspace);
    return !alias.overlaps(raw.semantic_scratch, receiver) and
        !alias.overlaps(raw.semantic_scratch, input) and
        !alias.overlaps(raw.semantic_scratch, output) and
        !alias.overlaps(tables, receiver) and !alias.overlaps(tables, input) and
        !alias.overlaps(tables, output) and !alias.overlaps(tables, raw.history) and
        !alias.overlaps(tables, raw.semantic_scratch);
}

/// Configured dictionaries remain borrowed across reset and later members.
/// A provideDictionary override is copied and is not part of this borrow.
pub fn dictionaryAdmission(receiver: []const u8, raw: anytype, output: []const u8, dictionary: []const u8) Error!bool {
    try validateDictionary(receiver, raw.history, output, dictionary);
    const workspace = raw.semantic_decoder orelse return true;
    const admitted = !alias.overlaps(raw.semantic_scratch, dictionary) and
        !alias.overlaps(std.mem.asBytes(workspace), dictionary);
    if (raw.phase == .fast_dynamic_block and !admitted)
        return error.InvalidBlockPlan;
    return admitted;
}

pub fn validateDictionary(receiver: []const u8, history: []const u8, output: []const u8, dictionary: []const u8) Error!void {
    if (alias.overlaps(receiver, dictionary) or alias.overlaps(history, dictionary) or
        alias.overlaps(output, dictionary)) return error.InvalidBlockPlan;
}

fn descriptorBytes(dictionaries: anytype) Error![]const u8 {
    const table_len = std.math.mul(usize, dictionaries.entries.len, @sizeOf(@TypeOf(dictionaries.entries[0]))) catch
        return error.IntegerOverflow;
    return @as([*]const u8, @ptrCast(dictionaries.entries.ptr))[0..table_len];
}

pub fn validateSet(receiver: []const u8, history: []const u8, output: []const u8, dictionaries: anytype) Error!void {
    try validateDictionary(receiver, history, output, try descriptorBytes(dictionaries));
    for (dictionaries.entries) |entry|
        try validateDictionary(receiver, history, output, entry.bytes);
}

pub fn setAdmission(receiver: []const u8, raw: anytype, output: []const u8, dictionaries: anytype) Error!bool {
    const table = try descriptorBytes(dictionaries);
    var admitted = try dictionaryAdmission(receiver, raw, output, table);
    for (dictionaries.entries) |entry| {
        const entry_admitted = try dictionaryAdmission(receiver, raw, output, entry.bytes);
        admitted = admitted and entry_admitted;
    }
    return admitted;
}
