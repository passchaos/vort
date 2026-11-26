const std = @import("std");
const cache = @import("owner.zig");
const model = @import("model.zig");
const context = @import("../literal_context_split.zig");
const commands = @import("../command_plan.zig");
const budget = @import("../total_budget.zig");
const a = std.testing.allocator;

const Options = struct {
    write_stream_prefix: bool = true,
    final_meta_block: bool = true,
    metadata: []const u8 = "",
    large_window: bool = false,
    literal_split: ?usize = null,
    adaptive_literal_split: ?usize = null,
    literal_entropy_plan: ?usize = null,
    literal_context_candidate: ?context.Candidate = null,
    use_utf8_text_contexts: bool = false,
    utf8_context_cutoff: u6 = 56,
    literal_context_mode: u2 = 0,
    optimize_literal_tree_wire: bool = false,
    initial_previous: [2]u8 = .{ 0, 0 },
    use_recent_distances: bool = false,
    disable_literal_context_modeling: bool = false,
};

fn alphabet() model.Alphabet {
    var value: model.Alphabet = undefined;
    value.len = 2;
    value.symbols[0] = 'a';
    value.symbols[1] = 'b';
    return value;
}

fn one(owner: *cache.Owner, allocator: std.mem.Allocator, input: []const u8, group: []const commands.Command, options: Options) !?*const model.Model {
    const alphabets = [_]model.Alphabet{alphabet()};
    const lengths = [_][256]u4{@splat(2)};
    var literal_count: usize = 0;
    for (group) |command| literal_count += command.insert_len;
    return owner.capture(allocator, input, group, options, null, &alphabets, &lengths, literal_count, literal_count * 2);
}

test "literal model keys include immutable group identity and literal-only options" {
    var input = [_]u8{ 'a', 'b', 'a', 'b' };
    var other_input = input;
    const group = [_]commands.Command{.{ .insert_start = 0, .insert_len = 2 }};
    const other_group = [_]commands.Command{.{ .insert_start = 1, .insert_len = 2 }};
    var owner = cache.Owner.init(&input, &group);
    defer owner.deinit(a);
    const ready = (try one(&owner, a, &input, &group, .{})).?;
    try std.testing.expectEqual(ready, owner.lookup(&input, &group, Options{}).?);
    try std.testing.expect(owner.lookup(&other_input, &group, Options{}) == null);
    try std.testing.expect(owner.lookup(input[0..3], &group, Options{}) == null);
    try std.testing.expect(owner.lookup(&input, &other_group, Options{}) == null);
    try std.testing.expect(owner.lookup(&input, group[0..0], Options{}) == null);
    for ([_]Options{
        .{ .initial_previous = .{ 1, 0 } },                                   .{ .initial_previous = .{ 0, 1 } },
        .{ .use_utf8_text_contexts = true },                                  .{ .utf8_context_cutoff = 40 },
        .{ .literal_context_mode = 1 },                                       .{ .optimize_literal_tree_wire = true },
        .{ .literal_context_candidate = context.Candidate.suffix(2, 56, 0) },
    }) |options| try std.testing.expect(owner.lookup(&input, &group, options) == null);
    try std.testing.expectEqual(ready, owner.lookup(&input, &group, Options{ .use_recent_distances = true }).?);
    try std.testing.expectEqual(ready, owner.lookup(&input, &group, Options{ .disable_literal_context_modeling = true, .literal_context_candidate = context.Candidate.suffix(2, 56, 0), .use_utf8_text_contexts = true }).?);
}

test "literal model compares complete context maps and preserves normalized context" {
    const input = "abab";
    const group = [_]commands.Command{.{ .insert_start = 0, .insert_len = input.len }};
    const proposal = context.Candidate.suffix(2, 40, 123);
    var options: Options = .{ .literal_context_candidate = proposal, .use_utf8_text_contexts = true, .initial_previous = .{ 0xe3, 0x80 } };
    const alphabets = [_]model.Alphabet{ alphabet(), alphabet() };
    const lengths = [_][256]u4{ @splat(1), @splat(3) };
    var owner = cache.Owner.init(input, &group);
    defer owner.deinit(a);
    const ready = (try owner.capture(a, input, &group, options, proposal, &alphabets, &lengths, 4, 8)).?;
    options.literal_context_candidate.?.savings_bits += 1;
    try std.testing.expectEqual(ready, owner.lookup(input, &group, options).?);
    options.literal_context_candidate.?.context_map[0] = 1;
    try std.testing.expect(owner.lookup(input, &group, options) == null);
    options.literal_context_candidate = proposal;
    options.literal_context_candidate.?.tree_count = 3;
    try std.testing.expect(owner.lookup(input, &group, options) == null);
    try std.testing.expect(context.Candidate.eql(proposal, ready.normalized_context.?));
    try std.testing.expectEqual(@as(usize, 4), ready.symbolCount());
    try std.testing.expectEqualSlices(u4, &lengths[1], &ready.lengths[1]);
}

test "literal model rejects unsupported shapes before any allocation" {
    const input = "abab";
    const group = [_]commands.Command{.{ .insert_start = 0, .insert_len = input.len }};
    var owner = cache.Owner.init(input, &group);
    var heap = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
    for ([_]Options{
        .{ .large_window = true },      .{ .metadata = "x" },    .{ .write_stream_prefix = false },
        .{ .final_meta_block = false }, .{ .literal_split = 1 }, .{ .adaptive_literal_split = 1 },
        .{ .literal_entropy_plan = 1 },
    }) |options| try std.testing.expect((try one(&owner, heap.allocator(), input, &group, options)) == null);
    const too_many: [65]model.Alphabet = undefined;
    const too_many_lengths: [65][256]u4 = undefined;
    try std.testing.expectError(error.InvalidBlockPlan, owner.capture(heap.allocator(), input, &group, Options{}, null, &too_many, &too_many_lengths, 4, 8));
    try std.testing.expectEqual(@as(usize, 0), heap.alloc_index);
    try std.testing.expect(!heap.has_induced_failure);
    try std.testing.expectEqual(@as(usize, 0), owner.len);
}

test "literal model HQ output excludes hits and capture without allocating" {
    const input = "abab";
    const group = [_]commands.Command{.{ .insert_start = 0, .insert_len = input.len }};
    var heap = std.testing.FailingAllocator.init(a, .{});
    var owner = cache.Owner.init(input, &group);
    defer owner.deinit(heap.allocator());
    const ready = (try one(&owner, heap.allocator(), input, &group, .{})).?;
    const requests = heap.alloc_index;
    heap.fail_index = requests;
    var hq_output: usize = 17;
    var options = .{
        .write_stream_prefix = true,
        .final_meta_block = true,
        .metadata = @as([]const u8, ""),
        .large_window = false,
        .literal_split = @as(?usize, null),
        .adaptive_literal_split = @as(?usize, null),
        .literal_entropy_plan = @as(?usize, null),
        .literal_context_candidate = @as(?context.Candidate, null),
        .use_utf8_text_contexts = false,
        .utf8_context_cutoff = @as(u6, 56),
        .literal_context_mode = @as(u2, 0),
        .optimize_literal_tree_wire = false,
        .initial_previous = @as([2]u8, .{ 0, 0 }),
        .use_recent_distances = false,
        .disable_literal_context_modeling = false,
        .hq_model_output = @as(?*usize, &hq_output),
    };
    try std.testing.expect(!cache.supported(options));
    try std.testing.expect(owner.lookup(input, &group, options) == null);
    const alphabets = [_]model.Alphabet{alphabet()};
    const lengths = [_][256]u4{@splat(2)};
    try std.testing.expect((try owner.capture(heap.allocator(), input, &group, options, null, &alphabets, &lengths, 4, 8)) == null);
    try std.testing.expectEqual(requests, heap.alloc_index);
    try std.testing.expect(!heap.has_induced_failure);
    try std.testing.expectEqual(@as(usize, 17), hq_output);
    options.hq_model_output = null;
    try std.testing.expect(cache.supported(options));
    try std.testing.expectEqual(ready, owner.lookup(input, &group, options).?);
}

test "literal model two allocation failures clean up and publish atomically" {
    const input = "abab";
    const group = [_]commands.Command{.{ .insert_start = 0, .insert_len = input.len }};
    for (0..2) |ordinal| {
        var owner = cache.Owner.init(input, &group);
        var heap = std.testing.FailingAllocator.init(a, .{ .fail_index = ordinal });
        try std.testing.expectError(error.OutOfMemory, one(&owner, heap.allocator(), input, &group, .{}));
        try std.testing.expect(heap.has_induced_failure);
        try std.testing.expectEqual(@as(usize, 0), owner.len);
        try std.testing.expectEqual(@as(usize, 0), owner.counters.builds);
        try std.testing.expect(owner.lookup(input, &group, Options{}) == null);
        try std.testing.expectEqual(heap.allocated_bytes, heap.freed_bytes);
        heap.fail_index = std.math.maxInt(usize);
        heap.has_induced_failure = false;
        _ = (try one(&owner, heap.allocator(), input, &group, .{})).?;
        try std.testing.expectEqual(@as(usize, 1), owner.len);
        owner.deinit(heap.allocator());
        try std.testing.expectEqual(heap.allocated_bytes, heap.freed_bytes);
    }
}

test "literal model stable five slots include metadata in the bounded heap formula" {
    const input = "abab";
    const group = [_]commands.Command{.{ .insert_start = 0, .insert_len = input.len }};
    var heap = std.testing.FailingAllocator.init(a, .{});
    var owner = cache.Owner.init(input, &group);
    var alphabets: [64]model.Alphabet = undefined;
    for (&alphabets) |*value| value.* = alphabet();
    const lengths: [64][256]u4 = @splat(@splat(2));
    var proposal: context.Candidate = .{ .mode = 2, .tree_count = 64, .context_map = undefined, .savings_bits = 0 };
    for (&proposal.context_map, 0..) |*tree, index| tree.* = @intCast(index);
    var pointers: [5]*const model.Model = undefined;
    for (&pointers, 0..) |*pointer, index| {
        const options: Options = .{ .literal_context_candidate = proposal, .initial_previous = .{ 0, @intCast(index) } };
        pointer.* = (try owner.capture(heap.allocator(), input, &group, options, proposal, &alphabets, &lengths, 4, 8)).?;
        for (pointers[0 .. index + 1], 0..) |previous, prior| {
            try std.testing.expectEqual(previous, owner.lookup(input, &group, Options{ .literal_context_candidate = proposal, .initial_previous = .{ 0, @intCast(prior) } }).?);
            try std.testing.expectEqual(@as(usize, 64), previous.alphabets.len);
        }
    }
    const requests = heap.alloc_index;
    const duplicate = try owner.capture(heap.allocator(), input, &group, Options{ .literal_context_candidate = proposal }, null, &.{}, &.{}, 0, 0);
    try std.testing.expectEqual(pointers[0], duplicate.?);
    const sixth = try owner.capture(heap.allocator(), input, &group, Options{ .literal_context_candidate = proposal, .initial_previous = .{ 0, 5 } }, proposal, &alphabets, &lengths, 4, 8);
    try std.testing.expect(sixth == null);
    try std.testing.expectEqual(requests, heap.alloc_index);
    try std.testing.expectEqual(@as(usize, 1), owner.counters.capacity_misses);
    try std.testing.expectEqual(@sizeOf(cache.Owner) + heap.allocated_bytes - heap.freed_bytes, try owner.requestedBytes());
    try std.testing.expect((try owner.requestedBytes()) <= cache.memory_limit);
    const maximum_trees = (cache.memory_limit - @sizeOf(cache.Owner)) / cache.tree_bytes;
    try std.testing.expect((try cache.requestedBytesForTrees(maximum_trees)) <= cache.memory_limit);
    try std.testing.expect((try cache.requestedBytesForTrees(maximum_trees + 1)) > cache.memory_limit);
    try std.testing.expectError(error.IntegerOverflow, cache.requestedBytesForTrees(std.math.maxInt(usize)));
    std.debug.print("literal_model sizeofOwner={d} sizeofModel={d} treeBytes={d} activeTrees={d} requestedBytes={d} cap={d}\n", .{
        @sizeOf(cache.Owner), @sizeOf(model.Model), cache.tree_bytes, owner.counters.captured_trees, try owner.requestedBytes(), cache.memory_limit,
    });
    owner.deinit(heap.allocator());
    try std.testing.expectEqual(heap.allocated_bytes, heap.freed_bytes);
}

test "literal model copies only valid alphabet prefix and stores pure literal bits" {
    const input = "abcabc";
    const group = [_]commands.Command{
        .{ .insert_start = 0, .insert_len = 2, .has_copy = true, .copy_len = 1, .distance = 1 },
        .{ .insert_start = 3, .insert_len = 3 },
    };
    var alphabets = [_]model.Alphabet{alphabet()};
    alphabets[0].len = 3;
    alphabets[0].symbols[2] = 'c';
    var lengths = [_][256]u4{@splat(0)};
    lengths[0]['a'] = 2;
    lengths[0]['b'] = 3;
    lengths[0]['c'] = 4;
    var literals: usize = 0;
    var bits: usize = 0;
    for (group) |command| for (input[command.insert_start..][0..command.insert_len]) |byte| {
        literals += 1;
        bits += lengths[0][byte];
    };
    var owner = cache.Owner.init(input, &group);
    defer owner.deinit(a);
    const ready = (try owner.capture(a, input, &group, Options{}, null, &alphabets, &lengths, literals, bits)).?;
    alphabets[0].symbols[0] = 'z';
    lengths[0]['a'] = 9;
    try std.testing.expectEqualSlices(u16, &.{ 'a', 'b', 'c' }, ready.alphabets[0].symbols[0..ready.alphabets[0].len]);
    try std.testing.expectEqual(@as(usize, 3), ready.symbolCount());
    try std.testing.expectEqual(@as(usize, 5), ready.literal_count);
    try std.testing.expectEqual(@as(usize, 14), ready.literal_payload_bits);
    try std.testing.expectEqual(@as(u4, 2), ready.lengths[0]['a']);
    try std.testing.expect(!@hasField(model.Model, "header_bits") and !@hasField(model.Model, "wire_len"));
}

test "literal model tracked quota propagates and reset drops same-address old group" {
    var input = [_]u8{ 'a', 'b', 'a', 'b' };
    var group = [_]commands.Command{.{ .insert_start = 0, .insert_len = input.len }};
    var heap = std.testing.FailingAllocator.init(a, .{});
    var profile: budget.EncodeMemoryProfile = .{};
    var lease = try budget.Lease.init(heap.allocator(), budget.control_bytes + @sizeOf(model.Alphabet), &profile, 0);
    var owner = cache.Owner.init(&input, &group);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, one(&owner, lease.allocator(), &input, &group, .{}));
    try std.testing.expectEqual(@as(usize, 0), owner.len);
    try std.testing.expectEqual(budget.control_bytes, profile.live_requested_bytes);
    lease.beginOperation();
    try lease.setLimit(budget.control_bytes + cache.tree_bytes);
    _ = (try one(&owner, lease.allocator(), &input, &group, .{})).?;
    owner.deinit(lease.allocator());
    input[0] = 'b';
    group[0].insert_start = 1;
    group[0].insert_len = 3;
    owner.reset(lease.allocator(), &input, &group);
    try std.testing.expect(owner.lookup(&input, &group, Options{}) == null);
    _ = (try one(&owner, lease.allocator(), &input, &group, .{})).?;
    owner.deinit(lease.allocator());
    lease.deinit();
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    try std.testing.expectEqual(heap.allocated_bytes, heap.freed_bytes);

    var denied = std.testing.FailingAllocator.init(a, .{ .fail_index = 2 });
    profile = .{};
    var backend = try budget.Lease.init(denied.allocator(), budget.control_bytes + cache.tree_bytes, &profile, 0);
    owner.reset(backend.allocator(), &input, &group);
    try std.testing.expectError(error.OutOfMemory, one(&owner, backend.allocator(), &input, &group, .{}));
    try std.testing.expect(denied.has_induced_failure);
    try std.testing.expect(!backend.snapshot().last_failure_was_limit);
    try std.testing.expectEqual(budget.control_bytes, profile.live_requested_bytes);
    try std.testing.expectEqual(@as(usize, 0), owner.len);
    denied.fail_index = std.math.maxInt(usize);
    denied.has_induced_failure = false;
    _ = (try one(&owner, backend.allocator(), &input, &group, .{})).?;
    owner.deinit(backend.allocator());
    backend.deinit();
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    try std.testing.expectEqual(denied.allocated_bytes, denied.freed_bytes);
}
