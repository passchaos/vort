const std = @import("std");
const common = @import("common.zig");
const frame_executor = common.frame_executor;

const expected_output = "wxyzwxyz";

const Target = enum {
    retained_history,
    unused_history,
    spare_history,
    staged_bytes,
    drained_staging,
    unused_staging,
    dictionary_history,
    literal_page,
    sequence_page,
    state,
    history_binding,
    executor,
    destination_tail_history,
    destination_tail_staging,
    destination_tail_dictionary,
    destination_tail_literal_page,
    destination_tail_sequence_page,
};

fn fixture() common.Fixture {
    var result: common.Fixture = .{};
    common.appendHeader(&result, 0x04, 0x00, 0, null);
    common.appendRawBlock(&result, "wxyz", false);
    // No literals, one sequence, RLE tables: LL=0, OF=2, ML=1.
    // The bitstream selects distance four and match length four, so this
    // block reads the first block's retained history.
    const compressed = [_]u8{ 0x00, 0x01, 0x54, 0x00, 0x02, 0x01, 0x07 };
    common.appendBlockHeader(&result, .compressed, compressed.len, true);
    result.appendSlice(&compressed);
    common.appendChecksum(&result, expected_output);
    return result;
}

fn Preserved(comptime Support: type) type {
    return struct {
        const Self = @This();
        const Runner = common.Runner(Support);

        snapshot: frame_executor.Snapshot,
        state: Support.State,
        source_calls: usize,
        copies: [8][]u8 = @splat(&.{}),

        fn regions(runner: *const Runner, dictionary_storage: []const u8) [8][]const u8 {
            return .{
                std.mem.asBytes(&runner.executor),
                std.mem.asBytes(&runner.state),
                std.mem.asBytes(&runner.history),
                runner.history_storage,
                runner.staging_guard,
                runner.literal_guard,
                runner.sequence_guard,
                dictionary_storage,
            };
        }

        fn capture(runner: *const Runner, dictionary_storage: []const u8) !Self {
            var result: Self = .{
                .snapshot = runner.executor.snapshot(),
                .state = runner.state,
                .source_calls = runner.source.calls,
            };
            errdefer result.deinit();
            for (regions(runner, dictionary_storage), 0..) |region, index|
                result.copies[index] = try std.testing.allocator.dupe(u8, region);
            return result;
        }

        fn deinit(self: *Self) void {
            for (&self.copies) |*copy| {
                if (copy.len != 0) std.testing.allocator.free(copy.*);
                copy.* = &.{};
            }
        }

        fn expectUnchanged(self: *const Self, runner: *const Runner, dictionary_storage: []const u8) !void {
            try std.testing.expectEqualDeep(self.snapshot, runner.executor.snapshot());
            try Support.expectStateEqual(&self.state, &runner.state);
            try std.testing.expectEqual(self.source_calls, runner.source.calls);
            for (self.copies, regions(runner, dictionary_storage)) |before, after|
                try std.testing.expectEqualSlices(u8, before, after);
            try std.testing.expectEqualStrings("wxyz", try runner.executor.committedBytes());
        }
    };
}

fn destination(
    comptime Support: type,
    runner: *common.Runner(Support),
    dictionary_storage: []u8,
    target: Target,
) []u8 {
    return switch (target) {
        .retained_history => runner.history.storage[0..2],
        .unused_history => runner.history.storage[64..66],
        .spare_history => runner.history.storage[runner.history.limit..][0..2],
        .staged_bytes => runner.executor.staging[3..4],
        .drained_staging => runner.executor.staging[0..2],
        .unused_staging => runner.executor.staging[32..34],
        .dictionary_history => dictionary_storage[4..6],
        .literal_page => runner.executor.literal_page[0..2],
        .sequence_page => runner.executor.sequence_page[0..2],
        .state => std.mem.asBytes(&runner.state.frame_decoded)[0..2],
        .history_binding => std.mem.asBytes(&runner.history)[0..2],
        .executor => std.mem.asBytes(&runner.executor)[0..2],
        // One byte remains to drain. These destinations have an independent
        // first byte, but their second byte overlaps the borrowed workspace.
        .destination_tail_history => runner.history_storage[3..5],
        .destination_tail_staging => runner.staging_guard[0..2],
        .destination_tail_dictionary => dictionary_storage[3..5],
        .destination_tail_literal_page => runner.literal_guard[0..2],
        .destination_tail_sequence_page => runner.sequence_guard[0..2],
    };
}

fn expectHistory(comptime Support: type, runner: *common.Runner(Support), dictionary_len: usize) !void {
    const shadow_storage = try std.testing.allocator.alloc(u8, runner.history.storage.len);
    defer std.testing.allocator.free(shadow_storage);
    @memset(shadow_storage, 0xa7);
    var shadow = try common.history_workspace.Binding.init(shadow_storage);
    try shadow.beginFrame(runner.frame.header.window_size, dictionary_len);
    shadow.append(expected_output);
    try common.expectHistoryEqual(shadow, runner.history);
    try std.testing.expectEqualSlices(u8, &@as([4]u8, @splat(0xa7)), runner.history_storage[0..4]);
}

fn rejectAndRetry(comptime Support: type, bytes: []const u8, target: Target) !void {
    errdefer std.debug.print("frame drain alias target: {s}\n", .{@tagName(target)});
    var dictionary_storage: [12]u8 = "----DICTDATA".*;
    const dictionary = dictionary_storage[4..];
    var runner: common.Runner(Support) = undefined;
    try runner.init(
        std.testing.allocator,
        bytes,
        Support.initialState(),
        dictionary,
        0,
        .{},
        17,
        256,
    );
    defer runner.deinit();

    // Keep a prefix outside history and spare capacity beyond its active
    // limit. Recreate the executor after replacing Runner's empty history;
    // every borrowed address then stays stable through the tested lifetime.
    const oversized = try std.testing.allocator.alloc(u8, runner.history_storage.len + 16);
    @memset(oversized, 0xa7);
    std.testing.allocator.free(runner.history_storage);
    runner.history_storage = oversized;
    runner.history.storage = oversized[4..];
    runner.executor = try @TypeOf(runner.executor).init(
        runner.frame,
        &runner.state,
        &runner.history,
        dictionary,
        0,
        runner.executor.staging,
        runner.executor.literal_page,
        runner.executor.sequence_page,
        .{},
    );

    try runner.executor.execute();
    var output: [9]u8 = @splat(0x6b);
    const prefix = try runner.executor.drain(output[0..3]);
    try std.testing.expectEqual(@as(usize, 3), prefix.written);
    try std.testing.expectEqual(frame_executor.DrainResult.Status.need_output, prefix.status);
    try std.testing.expectEqualStrings("wxy", output[0..3]);

    var preserved = try Preserved(Support).capture(&runner, &dictionary_storage);
    defer preserved.deinit();
    const aliased = destination(Support, &runner, &dictionary_storage, target);

    // An empty slice at any borrowed address is still a no-progress call.
    const empty = try runner.executor.drain(aliased[0..0]);
    try std.testing.expectEqual(@as(usize, 0), empty.written);
    try std.testing.expectEqual(frame_executor.DrainResult.Status.need_output, empty.status);
    try preserved.expectUnchanged(&runner, &dictionary_storage);

    try std.testing.expectError(error.InvalidBlockPlan, runner.executor.drain(aliased));
    try preserved.expectUnchanged(&runner, &dictionary_storage);

    // The rejected destination does not consume or poison the block lease.
    const retry = try runner.executor.drain(output[3..4]);
    try std.testing.expectEqual(@as(usize, 1), retry.written);
    try std.testing.expectEqual(frame_executor.DrainResult.Status.block_drained, retry.status);
    try std.testing.expectEqualStrings("wxyz", output[0..4]);
    try runner.executor.execute();
    try std.testing.expectEqualStrings("wxyz", try runner.executor.committedBytes());
    const tail = try runner.executor.drain(output[4..]);
    try std.testing.expectEqual(@as(usize, 4), tail.written);
    try std.testing.expectEqual(frame_executor.DrainResult.Status.block_drained, tail.status);
    try std.testing.expectEqualStrings(expected_output, output[0..8]);
    try std.testing.expectEqual(@as(u8, 0x6b), output[8]);
    try runner.executor.execute();
    try std.testing.expectEqual(frame_executor.Phase.done, runner.executor.snapshot().phase);
    try std.testing.expectEqual(@as(u64, @intCast(bytes.len)), try runner.executor.frameEndOffset());
    try std.testing.expectEqual(@as(u64, expected_output.len), runner.state.frame_decoded);
    try runner.expectGuards();
    try expectHistory(Support, &runner, dictionary.len);
    try std.testing.expectEqualStrings("----DICTDATA", &dictionary_storage);
}

pub fn contracts(comptime Support: type) !void {
    const frame = fixture();
    const oracle = try Support.decodeFrameOracle(std.testing.allocator, frame.bytes());
    defer std.testing.allocator.free(oracle);
    try std.testing.expectEqualStrings(expected_output, oracle);
    for (std.enums.values(Target)) |target|
        try rejectAndRetry(Support, frame.bytes(), target);
}
