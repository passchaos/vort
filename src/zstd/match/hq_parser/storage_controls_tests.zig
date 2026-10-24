const std = @import("std");
const hq = @import("../hq_parser.zig");
const lazy2 = @import("../lazy2.zig");
const tree = @import("../hq_tree.zig");
const source_mod = @import("../controlled_source.zig");
const controls = @import("../../encode/controls.zig");
const state = @import("state.zig");
const resources = @import("resources.zig");
const dp = @import("dp.zig");

test "Zstd HQ storage bounded node retains its original field layout" {
    const OriginalNode = struct {
        cost: u64 = std.math.maxInt(u64),
        repeats: hq.rep.Repeats = hq.rep.initial_repeats,
        literal_len: u32 = 0,
        previous_position: u16 = 0,
        previous_slot: u8 = 0,
        match_len: u32 = 0,
        distance: usize = 0,
        offset_value: u32 = 0,
    };
    try std.testing.expectEqual(@sizeOf(OriginalNode), @sizeOf(state.Node));
    try std.testing.expectEqual(@alignOf(OriginalNode), @alignOf(state.Node));
    inline for (comptime std.meta.fieldNames(OriginalNode)) |field|
        try std.testing.expectEqual(@offsetOf(OriginalNode, field), @offsetOf(state.Node, field));
    try std.testing.expect(@TypeOf(@as(state.Node, .{}).previous_position) == u16);
    try std.testing.expect(@TypeOf(@as(state.WholeNode, .{}).previous_position) == u32);
    const predecessor: state.WholeNode = .{ .previous_position = 128 * 1024 - 1 };
    try std.testing.expectEqual(@as(u32, 131071), predecessor.previous_position);
}

fn checkOrdering(comptime Node: type) !void {
    const base: Node = .{ .cost = 10, .literal_len = 2, .previous_position = 1, .match_len = 3, .distance = 7, .offset_value = 10 };
    try std.testing.expect(!state.less(base, base));
    inline for (.{ "cost", "literal_len", "offset_value", "distance", "previous_position", "previous_slot" }) |field| {
        var later = base;
        @field(later, field) += 1;
        try std.testing.expect(state.less(base, later));
        try std.testing.expect(!state.less(later, base));
    }
    var later = base;
    later.repeats[0] += 1;
    try std.testing.expect(state.less(base, later));
    later = base;
    later.match_len -= 1;
    try std.testing.expect(state.less(base, later));

    var row: [3]Node = @splat(.{});
    try std.testing.expect(state.insert(&row, base));
    later = base;
    later.previous_position += 1;
    try std.testing.expect(!state.insert(&row, later));
    var improved = base;
    improved.cost -= 1;
    try std.testing.expect(state.insert(&row, improved));
    var distinct = base;
    distinct.cost = 8;
    distinct.repeats[0] = 2;
    try std.testing.expect(state.insert(&row, distinct));
    try std.testing.expectEqual(distinct, row[0]);
    try std.testing.expectEqual(improved, row[1]);
    try std.testing.expectEqual(std.math.maxInt(u64), row[2].cost);
}

test "Zstd HQ storage both node types retain stable ordering and state coalescing" {
    try checkOrdering(state.Node);
    try checkOrdering(state.WholeNode);
    const earlier: state.WholeNode = .{ .cost = 1, .previous_position = 70000 };
    const later: state.WholeNode = .{ .cost = 1, .previous_position = 70001 };
    var row: [1]state.WholeNode = .{later};
    try std.testing.expect(state.less(earlier, later));
    try std.testing.expect(state.insert(&row, earlier));
    try std.testing.expectEqual(@as(u32, 70000), row[0].previous_position);
}

test "Zstd HQ storage layout charges the selected span and node type" {
    for ([_]usize{ 0, 2, 7, 4096, 4097, 128 * 1024 }) |length| {
        for ([_]usize{ 8, 16 }) |width| {
            inline for (.{ false, true }) |whole| {
                const layout = try resources.nodeLayout(length, width, whole);
                const expected_rows = (if (whole) length else @min(state.horizon, length)) + 1;
                try std.testing.expectEqual(expected_rows, layout.row_count);
                try std.testing.expectEqual(expected_rows * width, layout.node_count);
                try std.testing.expectEqual(layout.node_count * @sizeOf(state.NodeFor(whole)), layout.bytes);
            }
        }
    }
}

test "Zstd HQ storage layout checks row node and byte overflow before allocation" {
    const maximum = std.math.maxInt(usize);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, resources.nodeLayout(maximum, 8, true));
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, resources.nodeLayout(1, maximum, true));
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, resources.nodeLayout(0, maximum, true));
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, resources.nodeLayout(state.horizon, maximum, false));
    const bounded = try resources.nodeLayout(maximum, 16, false);
    try std.testing.expectEqual(state.horizon + 1, bounded.row_count);
}

test "Zstd HQ storage lazy parsers reject each new search control before heap use" {
    const options = [_]controls.HqOptions{
        .{ .parse_mode = .whole_block },
        .{ .match_lengths = .complete },
        .{ .max_price_evaluations = 0 },
    };
    for ([_]controls.Strategy{ .lazy2, .btlazy2 }) |strategy| {
        for (options) |option| {
            for ([_][]const u8{ "", "ab", "abcabcabc" }) |input| {
                const source = source_mod.Source.init("", "", input, 1024);
                const parameters: hq.Parameters = .{ .strategy = strategy, .hq_options = option };
                var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
                try std.testing.expectError(error.InvalidBlockPlan, hq.requiredWorkingMemory(source, parameters));
                try std.testing.expectError(error.InvalidBlockPlan, hq.planAlloc(failing.allocator(), source, parameters));
                if (strategy == .lazy2)
                    try std.testing.expectError(error.InvalidBlockPlan, lazy2.planAlloc(failing.allocator(), source, parameters))
                else
                    try std.testing.expectError(error.InvalidBlockPlan, lazy2.planWithMatcher(failing.allocator(), source, parameters, tree.Matcher));
                try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
                try std.testing.expect(!failing.has_induced_failure);
            }
        }
    }
    const source = source_mod.Source.init("", "", "abcabcabc", 1024);
    for ([_]controls.Strategy{ .btopt, .btultra, .btultra2 }) |strategy|
        for (options) |option| try resources.validate(source, .{ .strategy = strategy, .hq_options = option });
}

test "Zstd HQ storage whole block 128 KiB preflight counts actual workspace and retained results" {
    const input: [128 * 1024]u8 = @splat('a');
    for ([_][]const u8{ "", "a" }) |history| {
        const source = source_mod.Source.init("", history, &input, input.len);
        for ([_]controls.Strategy{ .btopt, .btultra, .btultra2 }) |strategy| {
            var parameters: hq.Parameters = .{ .strategy = strategy, .hq_options = .{ .parse_mode = .whole_block } };
            const layout = try resources.nodeLayout(input.len, dp.beamWidth(strategy), true);
            const result_bytes = input.len / parameters.hq_options.min_match * (@sizeOf(state.Record) + @sizeOf(u32));
            try std.testing.expectEqual(result_bytes, try resources.resultBytes(source, parameters.hq_options.min_match));
            try std.testing.expectEqual(layout.bytes + result_bytes, try dp.ownWorkingBytes(source, parameters));
            const matcher_bytes = try tree.Matcher.requiredWorkingMemory(source, parameters.hq_options);
            const retained_result = if (strategy == .btultra2 and history.len == 0) result_bytes else 0;
            const required = try hq.requiredWorkingMemory(source, parameters);
            try std.testing.expectEqual(layout.bytes + result_bytes + matcher_bytes + retained_result, required);
            parameters.hq_options.max_working_memory = required - 1;
            var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, hq.planAlloc(failing.allocator(), source, parameters));
            try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
            try std.testing.expect(!failing.has_induced_failure);
        }
    }
}

test "Zstd HQ storage each search layout exact requested budget remains sufficient on small plans" {
    for ([_][]const u8{ "", "abc" }) |history| {
        const source = source_mod.Source.init("", history, "abcabcabcabc", 1024);
        for ([_]controls.Strategy{ .btopt, .btultra, .btultra2 }) |strategy| {
            for ([_]controls.HqOptions{
                .{},
                .{ .parse_mode = .whole_block },
                .{ .parse_mode = .whole_block, .match_lengths = .complete },
                .{ .match_lengths = .complete },
            }) |option| {
                var parameters: hq.Parameters = .{ .strategy = strategy, .hq_options = option };
                const required = try hq.requiredWorkingMemory(source, parameters);
                parameters.hq_options.max_working_memory = required;
                const plan = try hq.planAlloc(std.testing.allocator, source, parameters);
                defer plan.deinit(std.testing.allocator);
                try std.testing.expectEqual(required, plan.peak_working_memory);
                try std.testing.expectEqual(source.block.len / parameters.hq_options.min_match, plan.record_storage.len);
                try std.testing.expectEqual(plan.record_storage.len, plan.offset_storage.len);
            }
        }
    }
}
