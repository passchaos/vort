//! Exact candidate evaluation within one immutable preferred-command group.
//! The reference retains the primary wire; the prepared-primary route retains
//! its counted state and emits only the selected group winner.
const std = @import("std");
const contexts = @import("literal_context_split.zig");
const literal_context = @import("literal_context.zig");
const profile = @import("quality_profile.zig");

pub noinline fn encode(comptime S: type, comptime traced: bool, trace: profile.Recorder(traced), allocator: std.mem.Allocator, input: []const u8, commands: anytype, io: ?std.Io, stats: *S.Stats, options: S.UserOptions, primary_options: S.Options) S.Error!S.Result {
    return encodeCore(S, false, traced, trace, allocator, input, commands, io, stats, options, primary_options, null);
}

pub noinline fn encodePreparedPrimary(comptime S: type, comptime traced: bool, trace: profile.Recorder(traced), allocator: std.mem.Allocator, input: []const u8, commands: anytype, io: ?std.Io, stats: *S.Stats, options: S.UserOptions, primary_options: S.Options) linksection(".vort_br_counted_context") S.Error!S.Result {
    const proposals = try S.proposals(traced, trace, allocator, input, commands);
    const count_primary = blk: {
        for ([3]?contexts.Candidate{ proposals.suffix, proposals.up_to_16, proposals.full }) |optional| {
            const candidate = optional orelse continue;
            const same = if (primary_options.literal_context_candidate) |primary| contexts.Candidate.eql(candidate, primary) else false;
            if (!same) break :blk true;
        }
        break :blk false;
    };
    if (!count_primary)
        return encodeCore(S, false, traced, trace, allocator, input, commands, io, stats, options, primary_options, &proposals);
    return encodeCore(S, true, traced, trace, allocator, input, commands, io, stats, options, primary_options, &proposals);
}

noinline fn encodeCore(comptime S: type, comptime prepare_primary: bool, comptime traced: bool, trace: profile.Recorder(traced), allocator: std.mem.Allocator, input: []const u8, commands: anytype, io: ?std.Io, stats: *S.Stats, options: S.UserOptions, primary_options: S.Options, precomputed: ?*const contexts.Proposals) linksection(".vort_br_counted_context") S.Error!S.Result {
    const initial_stats = stats.*;
    var primary_stats = initial_stats;
    var selected_state: S.State = undefined;
    var selected_wire: ?[]u8 = if (prepare_primary) null else try S.primary(traced, trace, allocator, input, commands, io, &primary_stats, primary_options);
    errdefer if (selected_wire) |wire| S.free(traced, trace, allocator, wire);
    var selected_ref = if (prepare_primary)
        try S.prepare(traced, trace, allocator, input, commands, io, &primary_stats, primary_options, &selected_state)
    else
        trace.reference(selected_wire.?);
    var selected_stats = primary_stats;
    var selected_context = primary_options.literal_context_candidate;
    var selected_options = primary_options;
    var scratch: S.State = undefined;
    var alternates: [3]contexts.Candidate = undefined;
    var alternate_count: usize = 0;
    var alternate_plain = false;
    var cutoff: ?u6 = if (selected_context) |candidate| candidate.suffixCutoff() else null;
    const proposals = if (precomputed) |value| value.* else try S.proposals(traced, trace, allocator, input, commands);
    for ([3]?contexts.Candidate{ proposals.suffix, proposals.up_to_16, proposals.full }, 0..) |proposal, index| {
        if (proposal) |candidate| {
            var duplicate = if (selected_context) |current| contexts.Candidate.eql(candidate, current) else false;
            for (alternates[0..alternate_count]) |previous|
                duplicate = duplicate or contexts.Candidate.eql(candidate, previous);
            if (!duplicate) {
                var candidate_options = primary_options;
                candidate_options.literal_context_candidate = candidate;
                var candidate_stats = initial_stats;
                const candidate_ref = try S.prepare(traced, trace, allocator, input, commands, io, &candidate_stats, candidate_options, &scratch);
                if (trace.preferReferences(candidate_ref, selected_ref)) {
                    if (selected_wire) |wire| S.free(traced, trace, allocator, wire);
                    selected_wire = null;
                    selected_state.copyFrom(&scratch);
                    selected_options = candidate_options;
                    selected_stats = candidate_stats;
                    selected_ref = candidate_ref;
                    if (selected_context) |previous| {
                        if (alternate_count >= alternates.len) return error.InvalidBlockPlan;
                        alternates[alternate_count] = previous;
                        alternate_count += 1;
                    } else alternate_plain = true;
                    selected_context = candidate;
                } else {
                    if (alternate_count >= alternates.len) return error.InvalidBlockPlan;
                    alternates[alternate_count] = candidate;
                    alternate_count += 1;
                }
            }
        }
        // Preserve the proposal-zero snapshot used by later split planning.
        if (index == 0) cutoff = if (selected_context) |candidate|
            if (candidate.mode == literal_context.mode_utf8) candidate.suffixCutoff() else null
        else
            null;
    }
    if (!(options.try_literal_contexts orelse false) and S.ratioAtMost(selected_ref.bytes, input.len, 80)) {
        const encoded = selected_wire orelse try S.emit(traced, trace, allocator, input, commands, io, &selected_stats, selected_options, &selected_state, selected_ref);
        selected_wire = null;
        stats.* = selected_stats;
        return .{ .encoded = encoded, .use_recent_distances = true, .literal_context_candidate = selected_context, .alternate_literal_context_candidates = alternates, .alternate_literal_context_count = @intCast(alternate_count), .alternate_plain_literals = alternate_plain, .literal_split_utf8_cutoff = cutoff };
    }
    var baseline_stats = initial_stats;
    var baseline: ?[]u8 = try S.plain(traced, trace, allocator, input, commands, io, &baseline_stats, options);
    errdefer if (baseline) |wire| S.free(traced, trace, allocator, wire);
    // Equality chooses the explicit baseline, matching the materialized policy.
    if (trace.preferReferences(selected_ref, trace.reference(baseline.?))) {
        S.free(traced, trace, allocator, baseline.?);
        baseline = null;
        const encoded = selected_wire orelse try S.emit(traced, trace, allocator, input, commands, io, &selected_stats, selected_options, &selected_state, selected_ref);
        selected_wire = null;
        stats.* = selected_stats;
        return .{ .encoded = encoded, .use_recent_distances = true, .literal_context_candidate = selected_context, .alternate_literal_context_candidates = alternates, .alternate_literal_context_count = @intCast(alternate_count), .alternate_plain_literals = alternate_plain, .literal_split_utf8_cutoff = cutoff };
    }
    if (selected_wire) |wire| S.free(traced, trace, allocator, wire);
    selected_wire = null;
    stats.* = baseline_stats;
    return .{ .encoded = baseline.?, .use_recent_distances = false };
}
