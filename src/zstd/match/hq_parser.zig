const std = @import("std");
const controls = @import("../encode/controls.zig");
const source_mod = @import("controlled_source.zig");
const tree = @import("hq_tree.zig");
const lazy2 = @import("lazy2.zig");
const state = @import("hq_parser/state.zig");
const dp = @import("hq_parser/dp.zig");
const resources = @import("hq_parser/resources.zig");
pub const prices = @import("hq_parser/prices.zig");
pub const rep = @import("hq_parser/rep.zig");
pub const Parameters = state.Parameters;
pub const Plan = state.Plan;
pub const Source = source_mod.Source;
pub const EntropyModel = prices.EntropyModel;

pub fn requiredWorkingMemory(source: Source, parameters: Parameters) !usize {
    try resources.validate(source, parameters);
    if (parameters.strategy == .lazy2) return lazy2.requiredWorkingMemory(source, parameters);
    if (parameters.strategy == .btlazy2) return lazy2.requiredWithMatcher(source, parameters, tree.Matcher);
    if (parameters.strategy != .btopt and parameters.strategy != .btultra and parameters.strategy != .btultra2)
        return error.InvalidBlockPlan;
    if (source.block.len < parameters.hq_options.min_match) return 0;
    var required = try resources.add(try dp.ownWorkingBytes(source, parameters), try tree.Matcher.requiredWorkingMemory(source, parameters.hq_options));
    if (warmUp(source, parameters)) required = try resources.add(required, try resources.resultBytes(source, parameters.hq_options.min_match));
    return required;
}

/// The codec owns entropy tables and emitted frame state. This parser borrows
/// their costs, returns explicit offset values and never changes caller state.
/// Cold btultra2 warms statistics on an opt2 pass, resets input/repeat state,
/// then performs a complete opt2 pass under updated prices. Retained prefixes
/// and previously initialized entropy use one opt2 pass, as in libzstd.
pub fn planAlloc(allocator: std.mem.Allocator, source: Source, parameters: Parameters) !Plan {
    const required = try requiredWorkingMemory(source, parameters);
    const effective_model = try parameters.entropy.forStrategy(parameters.strategy);
    var resolved = parameters;
    resolved.entropy = &effective_model;
    defer if (parameters.profile) |profile| profile.recordEffectiveHq(parameters.hq_options);
    if (parameters.profile) |profile| {
        profile.available = true;
        profile.controls_used = true;
        profile.resolved_strategy = parameters.strategy;
        profile.recordEffectiveHq(parameters.hq_options);
    }
    if (required > parameters.hq_options.max_working_memory) return error.WorkingMemoryLimitExceeded;
    if (parameters.strategy == .lazy2) return lazy2.planAlloc(allocator, source, resolved);
    if (parameters.strategy == .btlazy2) return lazy2.planWithMatcher(allocator, source, resolved, tree.Matcher);
    var budget = resources.WorkingAllocator.init(allocator, parameters.hq_options.max_working_memory);
    defer if (parameters.profile) |profile| profile.recordPeakWorkingMemory(budget.peak);
    return run(budget.allocator(), &budget, source, resolved) catch |err| {
        if (err == error.OutOfMemory and budget.last_failure_was_limit) return error.WorkingMemoryLimitExceeded;
        return err;
    };
}

fn warmUp(source: Source, parameters: Parameters) bool {
    return parameters.strategy == .btultra2 and source.block.len > 8 and source.prefixLen() == 0 and
        !parameters.entropy.initialized and parameters.entropy.origin == .predefined;
}
fn run(allocator: std.mem.Allocator, budget: *resources.WorkingAllocator, source: Source, parameters: Parameters) !Plan {
    if (!warmUp(source, parameters)) return dp.plan(allocator, budget, source, parameters, tree.Matcher);
    var pass_parameters = parameters;
    pass_parameters.strategy = .btultra;
    var first = try dp.plan(allocator, budget, source, pass_parameters, tree.Matcher);
    errdefer first.deinit(allocator);
    const initial_cost = first.estimated_cost;
    const refined = parameters.entropy.refined(&first.statistics);
    var measure_parameters = parameters;
    measure_parameters.entropy = &refined;
    measure_parameters.profile = null;
    try resources.finish(&first, source, parameters.initial_repeated_offsets, measure_parameters);
    const baseline_cost = first.estimated_cost;
    if (parameters.profile) |profile| profile.add("refinement_passes", 1);
    pass_parameters.entropy = &refined;
    const second = try dp.plan(allocator, budget, source, pass_parameters, tree.Matcher);
    // Both candidates are evaluated with the same refined entropy model. The
    // second pass is actual work even if its bounded beam loses to the baseline.
    var result: Plan = undefined;
    if (second.estimated_cost <= baseline_cost) {
        first.deinit(allocator);
        result = second;
    } else {
        second.deinit(allocator);
        result = first;
    }
    result.passes = 2;
    result.used_refinement = true;
    result.first_pass_cost = initial_cost;
    result.refined_first_pass_cost = baseline_cost;
    result.peak_working_memory = budget.peak;
    return result;
}

test {
    _ = @import("hq_parser/tests.zig");
}
