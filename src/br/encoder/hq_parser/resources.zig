const std = @import("std");
const types = @import("../hq_types.zig");
const options = @import("../hq_options.zig");
const command_plan = @import("../command_plan.zig");
const dictionary = @import("../hq_dictionary.zig");
const prices = @import("prices.zig");
const rep = @import("rep.zig");
const state = @import("state.zig");

pub fn add(a: usize, b: usize) !usize {
    return std.math.add(usize, a, b) catch error.WorkingMemoryLimitExceeded;
}
pub fn multiply(a: usize, b: usize) !usize {
    return std.math.mul(usize, a, b) catch error.WorkingMemoryLimitExceeded;
}
pub fn validate(source: types.Source, parameters: state.Parameters, model: *const prices.Model) !void {
    const resolved = parameters.resolved;
    try (options.HqOptions{ .search_depth = resolved.search_depth, .nice_len = resolved.nice_len, .beam_width = resolved.beam_width, .iterations = resolved.iterations, .max_working_memory = resolved.max_working_memory, .block_len = resolved.block_len, .distance_parameters = resolved.distance_parameters }).validate(resolved.quality);
    if (resolved.beam_width == 0 or resolved.iterations == 0 or source.input.len > resolved.block_len or source.format != resolved.format)
        return error.InvalidBlockPlan;
    try source.validate();
    for (parameters.initial_recent_distances orelse source.recent) |value| if (value == 0) return error.InvalidBlockPlan;
    try model.validateWithFormat(resolved.distance_parameters, source.input.len, resolved.format);
}
pub fn commandCapacity(source: types.Source, has_dictionary: bool) usize {
    if (source.input.len == 0) return 0;
    return if (has_dictionary) source.input.len + 1 else source.input.len / 2 + 1;
}
pub fn ownBytes(source: types.Source, parameters: state.Parameters, has_dictionary: bool) !usize {
    if (source.input.len == 0) return 0;
    const command_bytes = try multiply(commandCapacity(source, has_dictionary), @sizeOf(command_plan.Command));
    const literal_bytes = try multiply(try add(source.input.len, 1), @sizeOf(u64));
    const nodes = try multiply(try add(@min(state.horizon, source.input.len), 1), parameters.resolved.beam_width);
    const memo = try multiply(16 * @as(usize, parameters.resolved.beam_width), @sizeOf(state.MatchMemo));
    return add(try add(try add(command_bytes, literal_bytes), try multiply(nodes, @sizeOf(state.Node))), try add(@sizeOf(state.Spill), memo));
}
pub fn allocatePlan(allocator: std.mem.Allocator, source: types.Source, parameters: state.Parameters, has_dictionary: bool) !state.Plan {
    const storage = try allocator.alloc(command_plan.Command, commandCapacity(source, has_dictionary));
    return .{ .commands = storage[0..0], .command_storage = storage, .distance_parameters = parameters.resolved.distance_parameters, .format = parameters.resolved.format, .final_recent_distances = parameters.initial_recent_distances orelse source.recent, .final_previous = parameters.previous, .statistics = .{ .distance_parameters = parameters.resolved.distance_parameters, .format = parameters.resolved.format } };
}
pub fn append(plan: *state.Plan, command: command_plan.Command) !void {
    if (plan.commands.len == plan.command_storage.len) return error.InvalidBlockPlan;
    plan.command_storage[plan.commands.len] = command;
    plan.commands = plan.command_storage[0 .. plan.commands.len + 1];
}
pub fn finish(plan: *state.Plan, source: types.Source, parameters: state.Parameters, model: *const prices.Model, provider: ?*const dictionary.Provider) !void {
    if (plan.format != model.format) return error.InvalidBlockPlan;
    plan.statistics = .{ .distance_parameters = model.distance_parameters, .format = model.format };
    plan.estimated_cost = 0;
    var position: usize = 0;
    var recent = parameters.initial_recent_distances orelse source.recent;
    for (plan.commands) |command| {
        if (command.insert_start != position or command.insert_len > source.input.len - position) return error.InvalidBlockPlan;
        const encoding = command.hq_encoding orelse return error.InvalidBlockPlan;
        try encoding.validate(command.insert_len, command.copy_len, command.has_copy);
        for (source.input[position..][0..command.insert_len], position..) |byte, literal_position| {
            try plan.statistics.addLiteral(model.context(source, literal_position, parameters.previous), byte);
            plan.estimated_cost = std.math.add(u64, plan.estimated_cost, model.literalPrice(source, literal_position, parameters.previous)) catch return error.IntegerOverflow;
        }
        position += command.insert_len;
        const costs = try model.commandCosts(command.insert_len, command.copy_len, if (command.has_copy) encoding.distance_code else null);
        var found = false;
        for (costs.slice()) |cost| {
            if (std.meta.eql(cost.encoding, encoding)) {
                plan.estimated_cost = std.math.add(u64, plan.estimated_cost, cost.cost) catch return error.IntegerOverflow;
                found = true;
                break;
            }
        }
        if (!found) return error.InvalidBlockPlan;
        if (command.has_copy) {
            const output_len = command.outputLen();
            if (output_len == 0 or output_len > source.input.len - position) return error.InvalidBlockPlan;
            const physical_distance = if (command.isLz77()) command.distance else try (provider orelse return error.InvalidBlockPlan).wireDistance(.{ .source = command.source, .copy_len = command.copy_len, .output_len = output_len, .address = command.dictionary_address }, source, position);
            if (!rep.usableDistance(physical_distance, model.format)) return error.InvalidBlockPlan;
            if (try rep.resolve(encoding.distance_code, recent) != physical_distance) return error.InvalidBlockPlan;
            if (command.isLz77() and matchLength(source, position, physical_distance, output_len, null) != output_len) return error.InvalidBlockPlan;
            recent = types.recentAfter(command.source, encoding.distance_code, physical_distance, recent);
            position += output_len;
        } else if (position != source.input.len) return error.InvalidBlockPlan;
        try plan.statistics.addCommand(encoding, command.has_copy, command.outputLen());
    }
    if (position != source.input.len or !std.mem.eql(usize, &plan.final_recent_distances, &recent)) return error.InvalidBlockPlan;
    plan.final_previous = prices.previousAt(source, source.input.len, parameters.previous);
    plan.pending_insert = 0;
    plan.consumed = position;
}
pub fn matchLength(source: types.Source, position: usize, backward: usize, maximum: usize, profile: ?*options.HqProfile) usize {
    if (position > source.input.len or backward == 0 or backward > source.window_len or backward > source.history.len + position) return 0;
    const current = source.history.len + position;
    const candidate = current - backward;
    const limit = @min(maximum, source.input.len - position);
    var matched: usize = 0;
    while (matched < limit) {
        const left = span(source, candidate + matched);
        const right = source.input[position + matched ..];
        const count = @min(limit - matched, @min(left.len, right.len));
        var offset: usize = 0;
        while (count - offset >= 32) : (offset += 32) {
            const a: @Vector(32, u8) = left[offset..][0..32].*;
            const b: @Vector(32, u8) = right[offset..][0..32].*;
            if (profile) |p| p.add("byte_comparisons", 32);
            if (std.simd.firstTrue(a != b)) |different| return matched + offset + different;
        }
        while (offset < count) : (offset += 1) {
            if (profile) |p| p.add("byte_comparisons", 1);
            if (left[offset] != right[offset]) return matched + offset;
        }
        matched += count;
    }
    return matched;
}
fn span(source: types.Source, position: usize) []const u8 {
    return if (position < source.history.len) source.history[position..] else source.input[position - source.history.len ..];
}
