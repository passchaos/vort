const std = @import("std");
const br = @import("../br.zig");
const parser = @import("../br/encoder/hq_parser.zig");
const h = @import("br_complete_lengths_helpers.zig");
const a = std.testing.allocator;

test "Brotli complete lengths public search limit restores emitted counters and caller output before retry" {
    const input = "abcdefghabcdefghXabcdefgh";
    var profile: br.HqProfile = .{};
    var options: br.PlannedEncodeOptions = .{ .quality = 10, .hq = .{ .copy_lengths = .complete, .parse_mode = .whole_block, .beam_width = 2, .iterations = 1, .profile = &profile } };
    const baseline = try br.encodePlannedStreamWithOptionsAlloc(a, input, options);
    defer a.free(baseline);
    const cap = profile.max_plan_price_evaluations;
    const emitted = profile.emitted();
    try std.testing.expect(cap > 0 and profile.price_evaluations > cap);
    options.hq.?.max_price_evaluations = 0;
    var destination: [1024]u8 = @splat(0xa5);
    try std.testing.expectError(error.SearchLimitExceeded, br.encodePlannedStreamWithOptionsInto(input, &destination, options));
    try h.untouched(&destination);
    try std.testing.expectEqualDeep(emitted, profile.emitted());
    options.hq.?.max_price_evaluations = cap - 1;
    try std.testing.expectError(error.SearchLimitExceeded, br.encodePlannedStreamWithOptionsAlloc(a, input, options));
    try std.testing.expectEqualDeep(emitted, profile.emitted());
    options.hq.?.max_price_evaluations = cap;
    const retry = try br.encodePlannedStreamWithOptionsAlloc(a, input, options);
    defer a.free(retry);
    try std.testing.expectEqualSlices(u8, baseline, retry);
    try std.testing.expect(profile.price_evaluations > cap);
}

test "Brotli complete lengths incremental search denial preserves buffered input and repeats deterministically" {
    var profile: br.HqProfile = .{};
    var options: br.IncrementalPlannedStreamEncoder.Options = .{ .stream = .{ .quality = 10, .hq = .{ .copy_lengths = .complete, .max_price_evaluations = 0, .beam_width = 2, .iterations = 1, .profile = &profile } }, .block_len = 0 };
    var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(a, options);
    defer encoder.deinit();
    const accepted = try encoder.step(h.plain, &.{});
    try std.testing.expectEqual(h.plain.len, accepted.progress.input_read);
    try encoder.finish();
    const before = encoder.snapshot();
    const pending = try a.dupe(u8, encoder.pending.items);
    defer a.free(pending);
    for (0..2) |_| {
        var output: [128]u8 = @splat(0xa5);
        try std.testing.expectError(error.SearchLimitExceeded, encoder.step("", &output));
        try h.untouched(&output);
        try std.testing.expectEqualDeep(before, encoder.snapshot());
        try std.testing.expectEqualSlices(u8, pending, encoder.pending.items);
        try std.testing.expectEqual(@as(u64, 0), profile.emitted_metablocks);
    }
    options.stream.hq.?.max_price_evaluations = null;
    encoder.options = options;
    encoder.reset();
    const actual = try h.drive(a, &encoder, h.plain, 1, 1);
    defer a.free(actual);
    var fresh = options.stream;
    fresh.hq.?.profile = null;
    const expected = try br.encodePlannedStreamChunksWithOptionsAlloc(a, &.{h.plain}, fresh);
    defer a.free(expected);
    try std.testing.expectEqualSlices(u8, expected, actual);
}

const AllocationGraph = struct {
    pub fn run(backing: std.mem.Allocator) !void {
        var tracked = h.TrackingAllocator.init(backing);
        tracked.force_copy_reallocation = true;
        const source = try parser.Source.init("abcd", "abcdab", 10, 4);
        const model: parser.Model = .{};
        const parameters = try parser.Parameters.init(.{ .copy_lengths = .complete, .parse_mode = .whole_block, .beam_width = 2 }, 10, br.PlannedMode.generic);
        const plan = parser.planAlloc(tracked.allocator(), source, parameters, &model, null) catch |err| {
            try std.testing.expectEqual(@as(usize, 0), tracked.live);
            return err;
        };
        plan.deinit(tracked.allocator());
        try std.testing.expectEqual(@as(usize, 0), tracked.live);
    }
};

test "Brotli complete lengths allocation failures keep search errors separate and release command ownership" {
    try std.testing.checkAllAllocationFailures(a, AllocationGraph.run, .{});
}
