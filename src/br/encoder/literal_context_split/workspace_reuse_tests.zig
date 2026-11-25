const std = @import("std");
const contexts = @import("../literal_context_split.zig");
const command_plan = @import("../command_plan.zig");
const total_budget = @import("../total_budget.zig");

fn periodicInput() [512]u8 {
    var input: [512]u8 = undefined;
    for (&input, 0..) |*byte, index| byte.* = @intCast(index % 64);
    return input;
}

fn commands(distance: usize) [2]command_plan.Command {
    return .{
        .{ .insert_start = 0, .insert_len = 256, .copy_len = 128, .distance = distance, .has_copy = true },
        .{ .insert_start = 384, .insert_len = 128 },
    };
}

fn expectValidCopy(input: []const u8, plan: *const [2]command_plan.Command) !void {
    const copy_start = plan[0].insert_len;
    try std.testing.expectEqual(input.len, copy_start + plan[0].copy_len + plan[1].insert_len);
    try std.testing.expectEqual(copy_start + plan[0].copy_len, plan[1].insert_start);
    try std.testing.expect(plan[0].distance <= copy_start);
    for (copy_start..copy_start + plan[0].copy_len) |position|
        try std.testing.expectEqual(input[position], input[position - plan[0].distance]);
}

fn expectProps(expected: contexts.Proposals, actual: contexts.Proposals) !void {
    inline for (.{ "suffix", "up_to_16", "full" }) |field| {
        if (@field(expected, field)) |candidate| {
            const value = @field(actual, field) orelse return error.TestUnexpectedResult;
            try std.testing.expect(contexts.Candidate.eql(candidate, value));
            try std.testing.expectEqual(candidate.savings_bits, value.savings_bits);
        } else try std.testing.expect(@field(actual, field) == null);
    }
}

test "context proposal actual different valid distances reuse complete literal proposals" {
    const allocator = std.testing.allocator;
    var input = periodicInput();
    const near = commands(64);
    const far = commands(128);
    try expectValidCopy(&input, &near);
    try expectValidCopy(&input, &far);
    try std.testing.expect(near[0].distance != far[0].distance);
    const reference = try contexts.chooseProposals(allocator, &input, &near);
    try expectProps(reference, try contexts.chooseProposalsReference(allocator, &input, &near));
    try expectProps(reference, try contexts.chooseProposals(allocator, &input, &far));
    // A non-null proposal makes all semantic-field comparisons substantive.
    try std.testing.expect(reference.full != null);
    var owner = contexts.ProposalWorkspace.init();
    defer owner.deinit(allocator);
    try expectProps(reference, try contexts.chooseProposalsWithWorkspace(allocator, &input, &near, &owner));
    const first_pointer = owner.retained.?;
    try expectProps(reference, try contexts.chooseProposalsWithWorkspace(allocator, &input, &far, &owner));
    try std.testing.expect(owner.retained == first_pointer);

    input[1] ^= 1;
    try expectValidCopy(&input, &near);
    const changed_input = try contexts.chooseProposals(allocator, &input, &near);
    try expectProps(changed_input, try contexts.chooseProposalsWithWorkspace(allocator, &input, &near, &owner));
    const second_pointer = owner.retained.?;
    try std.testing.expect(second_pointer != first_pointer);
    try expectProps(changed_input, try contexts.chooseProposalsWithWorkspace(allocator, &input, &far, &owner));
    try std.testing.expect(owner.retained == second_pointer);

    var changed_spans = near;
    changed_spans[0].insert_len = 255;
    changed_spans[0].copy_len = 129;
    try expectValidCopy(&input, &changed_spans);
    const changed_span = try contexts.chooseProposals(allocator, &input, &changed_spans);
    try expectProps(changed_span, try contexts.chooseProposalsWithWorkspace(allocator, &input, &changed_spans, &owner));
    const third_pointer = owner.retained.?;
    try std.testing.expect(third_pointer != second_pointer);
    try std.testing.expectEqual(@as(usize, 383), third_pointer.literal_count);
    try expectProps(changed_span, try contexts.chooseProposalsWithWorkspace(allocator, &input, &changed_spans, &owner));
    try std.testing.expect(owner.retained == third_pointer);
}

test "context proposal actual fresh and scoring OOM preserve the old owned slot" {
    var heap = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    const allocator = heap.allocator();
    const input = periodicInput();
    const plan = commands(64);
    var owner = contexts.ProposalWorkspace.init();
    defer owner.deinit(allocator);
    const expected = try contexts.chooseProposalsWithWorkspace(allocator, &input, &plan, &owner);
    const retained = owner.retained.?;
    const analysis_bytes = @sizeOf(@TypeOf(retained.*));
    const allocated = heap.allocated_bytes;
    const freed = heap.freed_bytes;

    heap.fail_index = heap.alloc_index;
    try std.testing.expectError(error.OutOfMemory, contexts.chooseProposalsWithWorkspace(allocator, &input, &plan, &owner));
    try std.testing.expect(heap.has_induced_failure);
    try std.testing.expect(owner.retained == retained);
    try expectProps(expected, owner.cached.?);
    try std.testing.expectEqual(allocated, heap.allocated_bytes);
    try std.testing.expectEqual(freed, heap.freed_bytes);

    var changed = input;
    changed[0] ^= 1;
    heap.has_induced_failure = false;
    heap.fail_index = heap.alloc_index + 1;
    try std.testing.expectError(error.OutOfMemory, contexts.chooseProposalsWithWorkspace(allocator, &changed, &plan, &owner));
    try std.testing.expect(heap.has_induced_failure);
    try std.testing.expect(owner.retained == retained);
    try expectProps(expected, owner.cached.?);
    try std.testing.expectEqual(allocated + analysis_bytes, heap.allocated_bytes);
    try std.testing.expectEqual(freed + analysis_bytes, heap.freed_bytes);
    heap.fail_index = std.math.maxInt(usize);
    try expectProps(expected, try contexts.chooseProposalsWithWorkspace(allocator, &input, &plan, &owner));
    try std.testing.expect(owner.retained == retained);
    owner.deinit(allocator);
    try std.testing.expectEqual(heap.allocated_bytes, heap.freed_bytes);
}

test "context proposal actual short and invalid literal spans retain prior cache" {
    var heap = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    const allocator = heap.allocator();
    const input = periodicInput();
    const plan = commands(64);
    var owner = contexts.ProposalWorkspace.init();
    defer owner.deinit(allocator);
    const expected = try contexts.chooseProposalsWithWorkspace(allocator, &input, &plan, &owner);
    const retained = owner.retained.?;
    const before_allocated = heap.allocated_bytes;
    const before_freed = heap.freed_bytes;
    const short = [_]command_plan.Command{.{ .insert_start = 0, .insert_len = 127 }};
    try expectProps(.{}, try contexts.chooseProposalsWithWorkspace(allocator, input[0..127], &short, &owner));
    try std.testing.expectEqual(before_allocated, heap.allocated_bytes);
    try std.testing.expectEqual(before_freed, heap.freed_bytes);
    try std.testing.expect(owner.retained == retained);
    try expectProps(expected, owner.cached.?);

    var invalid = plan;
    invalid[1].insert_start = 500;
    try expectProps(.{}, try contexts.chooseProposals(allocator, &input, &invalid));
    const before_invalid_allocated = heap.allocated_bytes;
    const before_invalid_freed = heap.freed_bytes;
    try expectProps(.{}, try contexts.chooseProposalsWithWorkspace(allocator, &input, &invalid, &owner));
    const analysis_bytes = @sizeOf(@TypeOf(retained.*));
    try std.testing.expectEqual(before_invalid_allocated + analysis_bytes, heap.allocated_bytes);
    try std.testing.expectEqual(before_invalid_freed + analysis_bytes, heap.freed_bytes);
    try std.testing.expect(owner.retained == retained);
    try expectProps(expected, owner.cached.?);
    owner.deinit(allocator);
    try std.testing.expectEqual(heap.allocated_bytes, heap.freed_bytes);
}

test "context proposal actual total lease classifies fresh quota refusal and recovers" {
    var heap = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var memory: total_budget.EncodeMemoryProfile = .{};
    var lease = try total_budget.Lease.init(heap.allocator(), null, &memory, 0);
    defer lease.deinit();
    const allocator = lease.allocator();
    try std.testing.expect(total_budget.isTracked(allocator));
    const input = periodicInput();
    const near = commands(64);
    const far = commands(128);
    var owner = contexts.ProposalWorkspace.init();
    defer owner.deinit(allocator);
    const expected = try contexts.chooseProposalsWithWorkspace(allocator, &input, &near, &owner);
    const retained = owner.retained.?;
    const live = lease.snapshot().live_requested_bytes;
    try std.testing.expectEqual(total_budget.control_bytes + @sizeOf(@TypeOf(retained.*)), live);
    try lease.setLimit(live);
    const before_allocated = heap.allocated_bytes;
    try std.testing.expectError(error.OutOfMemory, contexts.chooseProposalsWithWorkspace(allocator, &input, &far, &owner));
    try std.testing.expectEqual(error.WorkingMemoryLimitExceeded, lease.translateError(error.OutOfMemory));
    try std.testing.expect(lease.snapshot().last_failure_was_limit);
    try std.testing.expectEqual(live, lease.snapshot().live_requested_bytes);
    try std.testing.expectEqual(before_allocated, heap.allocated_bytes);
    try std.testing.expect(owner.retained == retained);
    try expectProps(expected, owner.cached.?);

    try lease.setLimit(null);
    try std.testing.expect(lease.snapshot().last_failure_was_limit);
    lease.beginOperation();
    try std.testing.expect(!lease.snapshot().last_failure_was_limit);
    try std.testing.expect(lease.snapshot().hit_limit);
    try std.testing.expectEqual(error.OutOfMemory, lease.translateError(error.OutOfMemory));
    try expectProps(expected, try contexts.chooseProposalsWithWorkspace(allocator, &input, &far, &owner));
    try std.testing.expect(owner.retained == retained);
    try std.testing.expectEqual(live, lease.snapshot().live_requested_bytes);
    owner.deinit(allocator);
    try std.testing.expectEqual(total_budget.control_bytes, lease.snapshot().live_requested_bytes);
    lease.deinit();
    try std.testing.expectEqual(@as(usize, 0), memory.live_requested_bytes);
    try std.testing.expectEqual(@as(usize, 0), lease.snapshot().live_requested_bytes);
    try std.testing.expectEqual(heap.allocated_bytes, heap.freed_bytes);
}

test "context proposal actual profile hit retains shape with zero scorer work" {
    const allocator = std.testing.allocator;
    const input = periodicInput();
    const near = commands(64);
    const far = commands(128);
    const reference = try contexts.chooseProposals(allocator, &input, &near);
    var owner = contexts.ProposalWorkspace.init();
    defer owner.deinit(allocator);
    var miss_profile: contexts.Profile = .{};
    try expectProps(reference, try contexts.chooseProposalsProfiledWithWorkspace(allocator, &input, &near, std.testing.io, &miss_profile, &owner));
    const retained = owner.retained.?;
    try std.testing.expectEqual(@as(usize, 0), miss_profile.proposal_reuses);
    try std.testing.expect(miss_profile.tree_score_calls > 0);
    var profile: contexts.Profile = .{};
    const hit = try contexts.chooseProposalsProfiledWithWorkspace(allocator, &input, &far, std.testing.io, &profile, &owner);
    try expectProps(reference, hit);
    try std.testing.expect(owner.retained == retained);
    try std.testing.expectEqual(@as(usize, 1), profile.iterations);
    try std.testing.expectEqual(@as(usize, 512), profile.input_bytes);
    try std.testing.expectEqual(@as(usize, 384), profile.literal_count);
    try std.testing.expectEqual(@as(usize, 64), profile.active_symbols);
    try std.testing.expectEqual(@as(usize, 1), profile.proposal_reuses);
    inline for (.{ "tree_score_calls", "tree_score_uncached_calls", "tree_score_cache_hits", "tree_score_cache_misses", "suffix_payload_scores", "cluster_trials", "assignment_comparisons", "small_huffman_calls", "complex_prefix_calls" }) |field|
        try std.testing.expectEqual(@as(usize, 0), @field(profile, field));
    inline for (.{ "baseline_ns", "suffix_ns", "sparse_ns", "cluster_ns" }) |field|
        try std.testing.expectEqual(@as(u64, 0), @field(profile, field));
    inline for (.{ "suffix", "up_to_16", "full" }) |field| {
        if (@field(reference, field)) |candidate| {
            try std.testing.expectEqual(candidate.tree_count, @field(profile, field ++ "_tree_count"));
            try std.testing.expectEqual(candidate.mode, @field(profile, field ++ "_mode"));
            try std.testing.expectEqual(candidate.savings_bits, @field(profile, field ++ "_savings_bits"));
        } else {
            try std.testing.expectEqual(@as(u7, 0), @field(profile, field ++ "_tree_count"));
            try std.testing.expectEqual(@as(u64, 0), @field(profile, field ++ "_savings_bits"));
        }
    }
}
