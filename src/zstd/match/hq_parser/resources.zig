const std = @import("std");
const source_mod = @import("../controlled_source.zig");
const state = @import("state.zig");
const rep = @import("rep.zig");
pub const WorkingAllocator = @import("../../../io/working_allocator.zig").WorkingAllocator;

pub fn validate(source: source_mod.Source, parameters: state.Parameters) !void {
    try parameters.hq_options.validate();
    try parameters.entropy.validate();
    _ = try source.checkedTotalLen();
    if (source.window_len == 0 or source.window_len > std.math.maxInt(u32) - 3 or
        source.block.len > 128 * 1024 or try source.checkedPrefixLen() > source.window_len)
        return error.InvalidBlockPlan;
    for (parameters.initial_repeated_offsets) |offset|
        if (offset == 0 or offset > std.math.maxInt(u32) - 3) return error.InvalidBlockPlan;
}

pub fn add(left: usize, right: usize) error{WorkingMemoryLimitExceeded}!usize {
    return std.math.add(usize, left, right) catch error.WorkingMemoryLimitExceeded;
}
pub fn multiply(left: usize, right: usize) error{WorkingMemoryLimitExceeded}!usize {
    return std.math.mul(usize, left, right) catch error.WorkingMemoryLimitExceeded;
}
pub fn resultBytes(source: source_mod.Source, minimum: usize) !usize {
    return multiply(source.block.len / minimum, @sizeOf(state.Record) + @sizeOf(u32));
}
pub fn allocatePlan(allocator: std.mem.Allocator, source: source_mod.Source, minimum: usize, repeats: rep.Repeats) !state.Plan {
    const capacity = source.block.len / minimum;
    const records = try allocator.alloc(state.Record, capacity);
    errdefer allocator.free(records);
    const offsets = try allocator.alloc(u32, capacity);
    return .{ .records = records[0..0], .offset_values = offsets[0..0], .record_storage = records, .offset_storage = offsets, .final_repeated_offsets = repeats };
}
pub fn append(plan: *state.Plan, record: state.Record, offset_value: u32) !void {
    if (plan.records.len == plan.record_storage.len) return error.InvalidBlockPlan;
    const position = plan.records.len;
    plan.record_storage[position] = record;
    plan.record_storage[position].offset_value = offset_value;
    plan.offset_storage[position] = offset_value;
    plan.records = plan.record_storage[0 .. position + 1];
    plan.offset_values = plan.offset_storage[0 .. position + 1];
}

pub fn finish(plan: *state.Plan, source: source_mod.Source, initial_repeats: rep.Repeats, parameters: state.Parameters) !void {
    var previous_end: usize = 0;
    var repeats = initial_repeats;
    plan.statistics = .{};
    plan.estimated_cost = 0;
    for (plan.records, plan.offset_values) |record, offset_value| {
        const start = try add(previous_end, record.literal_len);
        const end = try add(start, record.match_len);
        if (end != record.match_end or end > source.block.len or record.match_len < parameters.hq_options.min_match)
            return error.InvalidBlockPlan;
        if (record.offset_value != @as(usize, offset_value)) return error.InvalidBlockPlan;
        const selected = try rep.resolve(record.literal_len, offset_value, repeats);
        if (selected.distance != record.distance) return error.InvalidBlockPlan;
        repeats = selected.repeats;
        const literals = source.block[previous_end..start];
        plan.statistics.addLiterals(literals);
        try plan.statistics.addSequence(record.literal_len, record.match_len, offset_value);
        for (literals) |byte| plan.estimated_cost = std.math.add(u64, plan.estimated_cost, parameters.entropy.literal_prices[byte]) catch return error.IntegerOverflow;
        plan.estimated_cost = std.math.add(u64, plan.estimated_cost, try parameters.entropy.sequencePrice(record.literal_len, record.match_len, offset_value)) catch return error.IntegerOverflow;
        previous_end = end;
    }
    plan.statistics.addLiterals(source.block[previous_end..]);
    for (source.block[previous_end..]) |byte| plan.estimated_cost = std.math.add(u64, plan.estimated_cost, parameters.entropy.literal_prices[byte]) catch return error.IntegerOverflow;
    if (!std.mem.eql(usize, &plan.final_repeated_offsets, &repeats)) return error.InvalidBlockPlan;
    if (parameters.profile) |profile| {
        profile.add("parser_matches", plan.records.len);
        for (plan.records) |record| profile.add("parser_matched_bytes", record.match_len);
    }
}

pub fn matchLength(source: source_mod.Source, position: usize, distance: usize, maximum: usize, profile: ?*@import("../../encode/controls.zig").Profile) usize {
    if (position > source.block.len or distance == 0 or distance > source.window_len) return 0;
    const current = source.prefixLen() + position;
    if (distance > current) return 0;
    const candidate = current - distance;
    const limit = @min(maximum, source.block.len - position);
    var length: usize = 0;
    while (length < limit) {
        const left = span(source, candidate + length);
        const right = source.block[position + length ..];
        const available = @min(limit - length, @min(left.len, right.len));
        var offset: usize = 0;
        while (available - offset >= 32) : (offset += 32) {
            const a: @Vector(32, u8) = left[offset..][0..32].*;
            const b: @Vector(32, u8) = right[offset..][0..32].*;
            if (profile) |p| p.add("byte_comparisons", 32);
            if (std.simd.firstTrue(a != b)) |mismatch| return length + offset + mismatch;
        }
        while (offset < available) : (offset += 1) {
            if (profile) |p| p.add("byte_comparisons", 1);
            if (left[offset] != right[offset]) return length + offset;
        }
        length += available;
    }
    return length;
}
fn span(source: source_mod.Source, absolute: usize) []const u8 {
    if (absolute < source.dictionary.len) return source.dictionary[absolute..];
    const after_dictionary = absolute - source.dictionary.len;
    if (after_dictionary < source.history.len) return source.history[after_dictionary..];
    return source.block[after_dictionary - source.history.len ..];
}
