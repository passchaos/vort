const std = @import("std");
const br = @import("../br.zig");
const parser = @import("../br/encoder/hq_parser.zig");
const h = @import("br_whole_block_helpers.zig");
const a = std.testing.allocator;

test "Brotli whole block raw static length four advances transformed five bytes across four and sixty four KiB" {
    const builder = @import("../br/serialized_dictionary_builder.zig");
    const serialized = @import("../br/serialized_dictionary.zig");
    const dictionary = @import("../br/encoder/hq_dictionary.zig");
    var sizes: [32]u8 = @splat(0);
    sizes[4] = 1;
    const encoded_dictionary = try builder.serializeAlloc(a, .{
        .word_lists = &.{.{ .size_bits_by_length = sizes, .data = "cat!dog!" }},
        .transform_lists = &.{.{ .prefix_suffix = &.{ 1, ' ', 0 }, .transforms = &.{ 1, 0, 0 } }},
        .dictionaries = &.{.{ .word_list_index = 0, .transform_list_index = 0 }},
    });
    defer a.free(encoded_dictionary);
    const parsed = try serialized.parse(encoded_dictionary);
    for ([_]usize{ 4095, 65535 }) |position| {
        const input = try a.alloc(u8, position + 5);
        defer a.free(input);
        @memset(input[0..position], 'x');
        @memcpy(input[position..], "cat! ");
        var budget = parser.Budget.init(a, 64 * 1024 * 1024);
        var provider = try dictionary.Provider.init(&budget, .{ .serialized = &parsed }, null);
        defer provider.deinit();
        var model: parser.Model = .{};
        for (&model.literal_prices) |*row| {
            @memset(row, 64 * 256);
            row['x'] = 0;
        }
        @memset(&model.command_prices, 256);
        @memset(&model.distance_prices, 256);
        const source = try parser.Source.init("", input, 17, 0);
        var parameters = try parser.Parameters.init(.{ .parse_mode = .whole_block, .beam_width = 1, .search_depth = 1, .nice_len = 2, .block_len = input.len }, 10, br.PlannedMode.generic);
        parameters.budget = &budget;
        const plan = try parser.planAlloc(budget.allocator(), source, parameters, &model, &provider);
        defer plan.deinit(budget.allocator());
        try std.testing.expectEqual(input.len, plan.consumed);
        try std.testing.expectEqual(@as(usize, 1), plan.commands.len);
        const command = plan.commands[0];
        try std.testing.expect(command.isStatic());
        try std.testing.expectEqual(position, command.insert_len);
        try std.testing.expectEqual(@as(usize, 4), command.copy_len);
        try std.testing.expectEqual(@as(usize, 5), command.dictionary_output_len);
        try std.testing.expectEqual(@as(usize, 0), command.dictionary_address);
        try std.testing.expectEqual(source.recent, plan.final_recent_distances);
        const wire = try br.IncrementalTestSupport.encodeHqCommandPlan(a, input, plan.commands, .{ .window_bits = 17 });
        defer a.free(wire.bytes);
        const actual = try h.singleCommandWire(wire.bytes, .{ 4, 11, 15, 16 });
        try std.testing.expectEqual(position, actual.insert_len);
        try std.testing.expectEqual(@as(usize, 4), actual.raw_copy_len);
        try std.testing.expectEqual(input.len, actual.meta_len);
        try std.testing.expectEqual(position + 1, actual.distance);
        try std.testing.expectEqual(source.recent, wire.last_distances);
        const decoded = try br.decodeStreamAllocWithOptions(a, wire.bytes, .{ .shared_dictionary = .{ .serialized = &parsed } });
        defer a.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }
}

test "Brotli whole block failed full meta allocation retries without changing committed input cache or selected mode" {
    for ([_]bool{ false, true }) |large| {
        var tracked = h.TrackingAllocator.init(a);
        tracked.force_moving_growth = true;
        var profile: br.HqProfile = .{};
        const stream: br.PlannedStreamChunksOptions = .{ .quality = 10, .large_window = large, .window_bits = if (large) 25 else 16, .hq = .{ .parse_mode = .whole_block, .beam_width = 2, .iterations = 1, .profile = &profile } };
        var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(tracked.allocator(), .{ .stream = stream, .block_len = 0 });
        defer encoder.deinit();
        var prefix: [1]u8 = undefined;
        const start = try encoder.step("", &prefix);
        const accepted = try encoder.step(h.plain, &.{});
        try std.testing.expectEqual(h.plain.len, accepted.progress.input_read);
        try encoder.finish();
        const before = encoder.snapshot();
        const pending = try a.dupe(u8, encoder.pending.items);
        defer a.free(pending);
        const emitted = profile.emitted();
        tracked.fail_alloc_after = tracked.alloc_attempts;
        var destination: [128]u8 = @splat(0xa5);
        try std.testing.expectError(error.OutOfMemory, encoder.step("", &destination));
        try h.untouched(&destination);
        try std.testing.expectEqualDeep(before, encoder.snapshot());
        try std.testing.expectEqualSlices(u8, pending, encoder.pending.items);
        try std.testing.expectEqualDeep(emitted, profile.emitted());
        tracked.clearFailures();
        const tail = try h.drive(a, &encoder, h.plain, 1, 1);
        defer a.free(tail);
        const bytes = try std.mem.concat(a, u8, &.{ prefix[0..start.progress.output_written], tail });
        defer a.free(bytes);
        try std.testing.expect(profile.whole_block_passes > 0);
        try std.testing.expectEqual(.whole_block, profile.effective.?.parse_mode);
        var fresh = stream;
        fresh.hq.?.profile = null;
        const expected = try br.encodePlannedStreamChunksWithOptionsAlloc(a, &.{h.plain}, fresh);
        defer a.free(expected);
        try std.testing.expectEqualSlices(u8, expected, bytes);
        const decoded = try br.decodeStreamAllocWithOptions(a, bytes, .{ .allow_large_window = large });
        defer a.free(decoded);
        try std.testing.expectEqualSlices(u8, h.plain, decoded);
    }
}

test "Brotli whole block next stream mode switch and reset use the requested parser from fresh state" {
    const whole: br.IncrementalPlannedStreamEncoder.Options = .{ .stream = .{ .quality = 10, .hq = .{ .parse_mode = .whole_block, .beam_width = 2, .iterations = 1, .block_len = 32 } }, .block_len = 0 };
    var bounded = whole;
    bounded.stream.hq.?.parse_mode = .bounded;
    var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(a, bounded);
    defer encoder.deinit();
    const first = try h.drive(a, &encoder, h.plain, 17, 1);
    defer a.free(first);
    try encoder.nextStream(whole);
    const second = try h.drive(a, &encoder, h.plain, 1, 1);
    defer a.free(second);
    const expected = try br.encodePlannedStreamChunksWithOptionsAlloc(a, &.{h.plain}, whole.stream);
    defer a.free(expected);
    try std.testing.expectEqualSlices(u8, expected, second);
    encoder.reset();
    const repeated = try h.drive(a, &encoder, h.plain, 31, 17);
    defer a.free(repeated);
    try std.testing.expectEqualSlices(u8, expected, repeated);
    try encoder.nextStream(bounded);
    const restored = try h.drive(a, &encoder, h.plain, 1, 1);
    defer a.free(restored);
    try std.testing.expectEqualSlices(u8, first, restored);
}

const PlanAllocationGraph = struct {
    pub fn run(backing: std.mem.Allocator) !void {
        var tracked = h.TrackingAllocator.init(backing);
        tracked.force_moving_growth = true;
        tracked.force_copy_reallocation = true;
        const input = "abcdab";
        const model: parser.Model = .{};
        const source = try parser.Source.init("abcd", input, 10, 4);
        const parameters = try parser.Parameters.init(.{ .parse_mode = .whole_block, .beam_width = 2 }, 10, br.PlannedMode.generic);
        const plan = parser.planAlloc(tracked.allocator(), source, parameters, &model, null) catch |err| {
            try std.testing.expectEqual(@as(usize, 0), tracked.live);
            try std.testing.expectEqualSlices(u8, "abcd", source.history);
            try std.testing.expectEqualSlices(u8, input, source.input);
            return err;
        };
        plan.deinit(tracked.allocator());
        try std.testing.expectEqual(@as(usize, 0), tracked.live);
        try std.testing.expectEqual(tracked.allocated_bytes, tracked.freed_bytes);
    }
};

test "Brotli whole block tiny full span allocation graph preserves source and releases every failed site" {
    try std.testing.checkAllAllocationFailures(a, PlanAllocationGraph.run, .{});
}
