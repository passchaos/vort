const std = @import("std");
const state = @import("hq_parser/state.zig");
const resources = @import("hq_parser/resources.zig");
const dp = @import("hq_parser/dp.zig");
const dictionary = @import("hq_dictionary.zig");
const tree = @import("hq_tree.zig");
pub const Model = @import("hq_parser/prices.zig").Model;
pub const Statistics = @import("hq_parser/prices.zig").Statistics;
pub const prices = @import("hq_parser/prices.zig");
pub const rep = @import("hq_parser/rep.zig");
pub const Source = @import("hq_types.zig").Source;
pub const Parameters = state.Parameters;
pub const Plan = state.Plan;
pub const Budget = state.Budget;
pub const Matcher = tree.Matcher;

/// Fixed-workspace lower bound; dictionary tuple-frontier growth is charged
/// dynamically by the same budget and never silently reduces candidates.
pub fn requiredWorkingMemory(source: Source, parameters: Parameters, model: *const Model, provider: ?*const dictionary.Provider) !usize {
    try resources.validate(source, parameters, model);
    const shared = parameters.budget orelse if (provider) |active| active.budget else null;
    var bytes: usize = if (shared) |budget| budget.live else try model.workingBytes();
    if (shared == null) if (parameters.matcher) |matcher| {
        bytes = try resources.add(bytes, matcher.workingBytes());
    };
    if (source.input.len == 0) return bytes;
    bytes = try resources.add(bytes, try resources.ownBytes(source, parameters, provider != null));
    if (parameters.matcher == null) bytes = try resources.add(bytes, try tree.Matcher.requiredWorkingMemory(source, parameters.resolved));
    return bytes;
}

/// One actual command parse. Iterations belong to the format bridge, which
/// starts each pass from the same Source/cache/previous state, trains with the
/// first plan's statistics and selects candidates by complete serialized size.
/// Default bounded mode uses 4096-position windows and literal-continuation
/// spill comparisons. Whole-block mode evaluates every input position in one
/// finite beam and prices the terminal command only at the meta-block end.
/// Finite beams do not promise globally optimal cache-state segmentation.
pub fn planAlloc(allocator: std.mem.Allocator, source: Source, parameters: Parameters, model: *const Model, provider: ?*const dictionary.Provider) !Plan {
    const required = try requiredWorkingMemory(source, parameters, model, provider);
    if (parameters.profile) |profile| profile.recordEffective(parameters.resolved);
    if (required > parameters.resolved.max_working_memory) return error.WorkingMemoryLimitExceeded;
    const shared = parameters.budget orelse if (provider) |active| active.budget else null;
    if (shared) |budget| {
        if (provider) |active| if (active.budget != budget) return error.InvalidBlockPlan;
        const expected = budget.allocator();
        if (allocator.ptr != expected.ptr or allocator.vtable != expected.vtable) return error.InvalidBlockPlan;
        const old_limit = budget.limit;
        budget.limit = @min(old_limit, parameters.resolved.max_working_memory);
        defer budget.limit = old_limit;
        defer if (parameters.profile) |profile| profile.recordPeak(budget.peak);
        return dp.run(allocator, budget, source, parameters, model, provider) catch |err| {
            if (err == error.OutOfMemory and budget.last_failure_was_limit) return error.WorkingMemoryLimitExceeded;
            return err;
        };
    }
    const reserved = try resources.add(try model.workingBytes(), if (parameters.matcher) |matcher| matcher.workingBytes() else 0);
    var budget = Budget.init(allocator, parameters.resolved.max_working_memory - reserved);
    defer if (parameters.profile) |profile| profile.recordPeak(budget.peak + reserved);
    var result = dp.run(budget.allocator(), &budget, source, parameters, model, null) catch |err| {
        if (err == error.OutOfMemory and budget.last_failure_was_limit) return error.WorkingMemoryLimitExceeded;
        return err;
    };
    result.peak_working_memory += reserved;
    return result;
}

test {
    _ = @import("hq_parser/tests.zig");
}
