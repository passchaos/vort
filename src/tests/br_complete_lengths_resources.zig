const std = @import("std");
const br = @import("../br.zig");
const parser = @import("../br/encoder/hq_parser.zig");
const h = @import("br_complete_lengths_helpers.zig");
const a = std.testing.allocator;

test "Brotli complete lengths independent three admitted command choices enforce per plan zero exact and one below" {
    // One two-byte match at distance4 has short0 implicit opcode0, short0
    // explicit opcode128, and regular distance19 explicit opcode128: three
    // legal exact evaluations, independently counted from RFC704 semantics.
    const source = try parser.Source.init("abcd", "ab", 10, 4);
    const model: parser.Model = .{};
    var profile: br.HqProfile = .{};
    var parameters = try parser.Parameters.init(.{ .copy_lengths = .complete, .parse_mode = .whole_block, .beam_width = 1, .profile = &profile, .max_price_evaluations = 0 }, 10, br.PlannedMode.generic);
    try std.testing.expectError(error.SearchLimitExceeded, parser.planAlloc(a, source, parameters, &model, null));
    try std.testing.expectEqual(@as(u64, 0), profile.price_evaluations);
    try std.testing.expectEqual(@as(u64, 0), profile.max_plan_price_evaluations);
    try std.testing.expectEqual(@as(usize, 0), profile.max_copy_length_considered);
    parameters.resolved.max_price_evaluations = 3;
    const exact = try parser.planAlloc(a, source, parameters, &model, null);
    defer exact.deinit(a);
    try std.testing.expectEqual(@as(u64, 3), profile.max_plan_price_evaluations);
    try std.testing.expectEqual(@as(u64, 3), profile.price_evaluations);
    try std.testing.expectEqual(@as(usize, 2), profile.max_copy_length_considered);
    // The same caller profile already contains three evaluations. A second
    // successful plan still gets its own three-admission cap, giving six total.
    const again = try parser.planAlloc(a, source, parameters, &model, null);
    defer again.deinit(a);
    try std.testing.expectEqual(@as(u64, 6), profile.price_evaluations);
    try std.testing.expectEqual(@as(u64, 3), profile.max_plan_price_evaluations);
    parameters.resolved.max_price_evaluations = 2;
    profile.reset();
    try std.testing.expectError(error.SearchLimitExceeded, parser.planAlloc(a, source, parameters, &model, null));
    try std.testing.expectEqual(@as(u64, 2), profile.price_evaluations);
    try std.testing.expectEqual(@as(u64, 2), profile.max_plan_price_evaluations);
    parameters.resolved.max_price_evaluations = 0;
    profile.reset();
    const literals = try parser.planAlloc(a, try parser.Source.init("", "qz", 10, 0), parameters, &model, null);
    defer literals.deinit(a);
    try std.testing.expectEqual(@as(u64, 0), profile.max_plan_price_evaluations);
    try std.testing.expectEqual(@as(u64, 0), profile.price_evaluations);
}

test "Brotli complete lengths dynamic command heap exact and one below remain independent of search quota" {
    const input = "abcabcX" ** 16;
    const source = try parser.Source.init("", input, 10, 0);
    const model: parser.Model = .{};
    var tracked = h.TrackingAllocator.init(a);
    tracked.force_copy_reallocation = true;
    var profile: br.HqProfile = .{};
    var parameters = try parser.Parameters.init(.{ .copy_lengths = .complete, .parse_mode = .whole_block, .beam_width = 2, .profile = &profile }, 10, br.PlannedMode.generic);
    const plan = try parser.planAlloc(tracked.allocator(), source, parameters, &model, null);
    const peak = tracked.peak;
    const admissions = profile.max_plan_price_evaluations;
    const cost = plan.estimated_cost;
    try std.testing.expectEqual(peak, profile.peak_working_memory);
    try std.testing.expect(admissions > 0);
    plan.deinit(tracked.allocator());
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
    parameters.resolved.max_working_memory = peak;
    parameters.resolved.max_price_evaluations = admissions;
    profile.reset();
    tracked.beginMeasurement();
    const exact = try parser.planAlloc(tracked.allocator(), source, parameters, &model, null);
    try std.testing.expectEqual(cost, exact.estimated_cost);
    try std.testing.expectEqual(peak, tracked.peak);
    exact.deinit(tracked.allocator());
    parameters.resolved.max_working_memory = peak - 1;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, parser.planAlloc(tracked.allocator(), source, parameters, &model, null));
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
    parameters.resolved.max_working_memory = std.math.maxInt(usize);
    parameters.resolved.max_price_evaluations = admissions - 1;
    try std.testing.expectError(error.SearchLimitExceeded, parser.planAlloc(tracked.allocator(), source, parameters, &model, null));
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
    try std.testing.expectEqual(tracked.allocated_bytes, tracked.freed_bytes);
}
