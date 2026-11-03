//! Exact local and incoming-incumbent arbitration for distance parameters.
//! Models remain caller-owned until the selected wire has been emitted.
const std = @import("std");
const command_plan = @import("command_plan.zig");
const prepared_common = @import("prepared_command_distance.zig");
const prepared_literal = @import("prepared_literal.zig");
const parameter_distance = @import("prepared_parameter_distance.zig");

pub fn against(comptime S: type, comptime traced: bool, trace: anytype, allocator: std.mem.Allocator, input: []const u8, commands: []const command_plan.Command, stats: *S.Stats, options: S.Options, incumbent: []const u8) S.Error!?[]u8 {
    if (options.distance_parameters.npostfix != 0 or
        options.distance_parameters.ndirect_high != 0 or !options.use_recent_distances or
        options.distance_split != null or options.adaptive_distance_split != null)
    {
        var failure = trace.begin(.distance_parameters, input.len, commands.len);
        defer failure.finish();
        failure.failure(error.InvalidBlockPlan);
        return error.InvalidBlockPlan;
    }
    var common = prepared_common.Prepared.init(options, commands);
    if (!prepared_common.supported(options, common.has_exact_commands) or
        !prepared_literal.supported(options))
    {
        var fallback_stats = stats.*;
        const wire = try S.physicalPair(traced, trace, allocator, input, commands, true, &fallback_stats, options);
        if (!trace.prefer(wire, incumbent)) {
            S.free(traced, trace, allocator, wire);
            stats.* = fallback_stats;
            return null;
        }
        stats.* = fallback_stats;
        return wire;
    }
    var scope = trace.begin(.distance_parameters, input.len, commands.len);
    defer scope.finish();
    errdefer |err| scope.failure(err);
    trace.parameterPair();

    const initial_stats = stats.*;
    var base_stats = initial_stats;
    var literal: prepared_literal.State = .{};
    const base_ref = try S.prepareBase(traced, trace, allocator, input, commands, &base_stats, options, &common, &literal);
    trace.parameterCounted();
    const alternative = try S.choose(allocator, commands, options);
    var alternate_options = options;
    var alternate_stats = initial_stats;
    var alternate: parameter_distance.State = .{};
    var selected_ref = base_ref;
    var selected_alternate = false;
    if (alternative) |parameters| {
        alternate_options.distance_parameters = parameters;
        alternate_options.optimize_same_last_distance = false;
        const alternate_ref = try S.prepareAlt(traced, trace, allocator, input, commands, &alternate_stats, alternate_options, &common, &literal, &alternate);
        trace.parameterCounted();
        if (trace.preferReferences(alternate_ref, base_ref)) {
            selected_ref = alternate_ref;
            selected_alternate = true;
        }
    }
    if (!trace.preferReferences(selected_ref, trace.reference(incumbent))) {
        trace.parameterSkipped();
        stats.* = if (selected_alternate) alternate_stats else base_stats;
        return null;
    }
    var selected_stats = if (selected_alternate) alternate_stats else base_stats;
    const wire = if (selected_alternate)
        try S.emitAlt(traced, trace, allocator, input, commands, &selected_stats, alternate_options, &common, &literal, &alternate, selected_ref)
    else
        try S.emitBase(traced, trace, allocator, input, commands, &selected_stats, options, &common, &literal, selected_ref);
    trace.parameterEmitted();
    stats.* = selected_stats;
    return wire;
}
