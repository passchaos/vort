const std = @import("std");
const zstd = @import("../../zstd.zig");
const h = @import("hq_test_helpers.zig");
const allocator = std.testing.allocator;
const parser = @import("../match/hq_parser.zig");
const tree = @import("../match/hq_tree.zig");

test "Zstd HQ resource planner exact peak and below cap use real requested heap including both passes" {
    const input = try h.corpusAlloc(allocator, .repetitive);
    defer allocator.free(input);
    var ledger = h.HeapLedger.init(allocator, 64 * 1024 * 1024);
    var profile: zstd.EncoderControlProfile = .{};
    const source = parser.Source.init("", "", input, 1024);
    const base = try parser.planAlloc(ledger.allocator(), source, .{ .strategy = .btultra2, .profile = &profile });
    var base_owned = true;
    defer if (base_owned) base.deinit(ledger.allocator());
    const peak = ledger.peak;
    try std.testing.expectEqual(peak, base.peak_working_memory);
    try std.testing.expectEqual(peak, profile.peak_working_memory);
    const saved = try allocator.dupe(@TypeOf(base.records[0]), base.records);
    defer allocator.free(saved);
    base.deinit(ledger.allocator());
    base_owned = false;
    try std.testing.expectEqual(@as(usize, 0), ledger.live);
    profile.reset();
    const exact = try parser.planAlloc(ledger.allocator(), source, .{ .strategy = .btultra2, .hq_options = .{ .max_working_memory = peak }, .profile = &profile });
    var exact_owned = true;
    defer if (exact_owned) exact.deinit(ledger.allocator());
    try std.testing.expectEqualDeep(saved, exact.records);
    exact.deinit(ledger.allocator());
    exact_owned = false;
    try std.testing.expectEqual(@as(usize, 0), ledger.live);
    const before = ledger.live;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, parser.planAlloc(ledger.allocator(), source, .{ .strategy = .btultra2, .hq_options = .{ .max_working_memory = peak - 1 } }));
    try std.testing.expectEqual(before, ledger.live);
    try std.testing.expectEqual(@as(usize, 0), ledger.denied_requests);
}

const PlanAllocationGraph = struct {
    pub fn run(backing: std.mem.Allocator, input: []const u8) !void {
        var profile: zstd.EncoderControlProfile = .{};
        var entropy: parser.EntropyModel = .{};
        const previous = entropy;
        const plan = parser.planAlloc(backing, parser.Source.init("", "", input, 1024), .{ .strategy = .btultra2, .entropy = &entropy, .profile = &profile }) catch |err| {
            try std.testing.expectEqualDeep(previous, entropy);
            try std.testing.expectEqualDeep(zstd.EncoderControlProfile.Emitted{}, profile.emitted());
            return err;
        };
        defer plan.deinit(backing);
        try std.testing.expectEqualDeep(previous, entropy);
        try std.testing.expectEqualDeep(zstd.EncoderControlProfile.Emitted{}, profile.emitted());
        try h.verifyPlan(allocator, "", input, .{ 1, 4, 8 }, plan);
    }
};

test "Zstd HQ resource every short planner OOM preserves scorer and publishes no wire statistics" {
    const input = try h.corpusAlloc(allocator, .repetitive);
    defer allocator.free(input);
    try std.testing.checkAllAllocationFailures(allocator, PlanAllocationGraph.run, .{input});
}

test "Zstd HQ resource tree full prefix owned move fork and traversal remain independent" {
    const dictionary = try h.farDictionary(allocator);
    defer allocator.free(dictionary);
    const input = dictionary[16..528];
    var ledger = h.HeapLedger.init(allocator, 64 * 1024 * 1024);
    var profile: zstd.EncoderControlProfile = .{};
    var original = try tree.Matcher.init(ledger.allocator(), tree.Source.init(dictionary, "", input, 128 * 1024), .{}, &profile);
    try std.testing.expectEqual(@as(u64, dictionary.len), profile.dictionary_seed_positions);
    const live = ledger.live;
    try std.testing.expectEqual(original.workingBytes(), live);
    var moved = original;
    original = undefined;
    var moved_owned = true;
    defer if (moved_owned) moved.deinit(ledger.allocator());
    {
        var clone = try moved.fork(ledger.allocator(), live * 2, null);
        defer clone.deinit(ledger.allocator());
        const left = try moved.getMatches();
        const right = try clone.getMatches();
        try std.testing.expectEqualDeep(left.slice(), right.slice());
        try std.testing.expectEqual(input.len, left.best().length);
        try std.testing.expect(left.best().distance > 65535);
        var iterator = left.iterator();
        var previous_length: usize = 0;
        while (iterator.next()) |match| {
            try std.testing.expect(match.length > previous_length);
            previous_length = match.length;
            const begin = dictionary.len - match.distance;
            for (0..match.length) |index| try std.testing.expectEqual(input[index], dictionary[begin + index]);
        }
        try std.testing.expectEqual(@as(usize, 1), moved.position());
        try std.testing.expectEqual(@as(usize, 1), clone.position());
    }
    moved.deinit(ledger.allocator());
    moved_owned = false;
    try std.testing.expectEqual(@as(usize, 0), ledger.live);
    try std.testing.expectEqual(@as(usize, 0), ledger.denied_requests);
}

test "Zstd HQ resource invalid level negative and conflicting controls preserve outputs before heap use" {
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    var output: [1024]u8 = @splat(0xa5);
    const cases = [_]struct { level: c_int, options: zstd.FrameOptions }{
        .{ .level = 0, .options = .{ .strategy = .btopt } },
        .{ .level = -1, .options = .{ .strategy = .btultra2 } },
        .{ .level = 3, .options = .{ .strategy = .auto, .hq = .{} } },
        .{ .level = 3, .options = .{ .strategy = .lazy, .hq = .{} } },
        .{ .level = 3, .options = .{ .strategy = .btopt, .fast_acceleration = 1 } },
        .{ .level = 3, .options = .{ .strategy = .btopt, .hq = .{ .search_depth = 0 } } },
    };
    for (cases) |case| {
        try std.testing.expectError(error.InvalidBlockPlan, zstd.encodeFrameIntoSliceWithLevelAndOptions(failing.allocator(), "HQ rejected options", case.level, case.options, &output));
        try h.sentinel(&output);
    }
    for ([_]zstd.NativeFrameOptions{
        .{ .strategy = .btopt, .selection = .raw_or_rle },
        .{ .strategy = .btopt, .rep_beam_search = true },
        .{ .strategy = .lazy2, .match_search_budget = 511 },
    }) |options| {
        try std.testing.expectError(error.InvalidBlockPlan, zstd.encodeNativeFrameIntoSlice(failing.allocator(), "HQ rejected options", options, &output));
        try h.sentinel(&output);
    }
    try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
    try std.testing.expect(!failing.has_induced_failure);
}

test "Zstd HQ resource caller alias and short destination roll back only emitted profile fields" {
    const input = try h.corpusAlloc(allocator, .repetitive);
    defer allocator.free(input);
    var profile: zstd.EncoderControlProfile = .{};
    const options: zstd.NativeFrameOptions = .{ .strategy = .btultra2, .control_profile = &profile };
    const expected = try zstd.encodeNativeFrameWithOptionsAlloc(allocator, input, options);
    defer allocator.free(expected.frame);
    const emitted = profile.emitted();
    var encoder = zstd.NativeFrameEncoder.init(allocator);
    defer encoder.deinit();
    var output: [1024]u8 = @splat(0xa5);
    @memcpy(output[0..input.len], input);
    const original = output;
    try std.testing.expectError(error.OutputTooSmall, encoder.encodeIntoSlice(output[0..input.len], options, output[0 .. expected.frame.len - 1]));
    try std.testing.expectEqualSlices(u8, &original, &output);
    try std.testing.expectEqualDeep(emitted, profile.emitted());
    const result = try encoder.encodeIntoSlice(output[0..input.len], options, &output);
    try std.testing.expectEqualSlices(u8, expected.frame, output[0..result.written]);
    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, input);
    _ = try zstd.encodeNativeFrameAppend(allocator, &appended, appended.items, options);
    try std.testing.expectEqualSlices(u8, input, appended.items[0..input.len]);
    try std.testing.expectEqualSlices(u8, expected.frame, appended.items[input.len..]);
    var limited = options;
    limited.hq = .{ .max_working_memory = 0 };
    @memset(&output, 0xa5);
    const before_limit = profile.emitted();
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.encodeIntoSlice(input, limited, &output));
    try h.sentinel(&output);
    try std.testing.expectEqualDeep(before_limit, profile.emitted());
}

const FrameAllocationGraph = struct {
    pub fn run(backing: std.mem.Allocator, input: []const u8, expected: []const u8) !void {
        var profile: zstd.EncoderControlProfile = .{};
        const options: zstd.FrameOptions = .{ .strategy = .btultra2, .content_checksum = true, .control_profile = &profile };
        var output = std.ArrayList(u8).fromOwnedSlice(try backing.dupe(u8, input));
        defer output.deinit(backing);
        const previous = profile.emitted();
        _ = zstd.encodeFrameAppendWithLevelAndOptions(backing, &output, output.items, 3, options) catch |err| {
            try std.testing.expectEqualSlices(u8, input, output.items);
            try std.testing.expectEqualDeep(previous, profile.emitted());
            return err;
        };
        try std.testing.expectEqualSlices(u8, input, output.items[0..input.len]);
        try std.testing.expectEqualSlices(u8, expected, output.items[input.len..]);
    }
};

test "Zstd HQ resource every small frame allocation failure preserves caller alias and wire counters" {
    const all_input = try h.corpusAlloc(allocator, .repetitive);
    defer allocator.free(all_input);
    const input = all_input[0..64];
    const expected = try zstd.encodeFrameWithLevelAndOptionsAlloc(allocator, input, 3, .{ .strategy = .btultra2, .content_checksum = true });
    defer allocator.free(expected);
    try std.testing.checkAllAllocationFailures(allocator, FrameAllocationGraph.run, .{ input, expected });
}

test "Zstd HQ resource header growth snapshots an exact capacity borrowed append input" {
    const all_input = try h.corpusAlloc(allocator, .repetitive);
    defer allocator.free(all_input);
    const input = all_input[0..64];
    const options: zstd.NativeFrameOptions = .{ .strategy = .btultra2 };
    const expected = try zstd.encodeNativeFrameWithOptionsAlloc(allocator, input, options);
    defer allocator.free(expected.frame);
    var ledger = h.HeapLedger.init(allocator, 64 * 1024 * 1024);
    ledger.force_moving_growth = true;
    {
        var output = std.ArrayList(u8).fromOwnedSlice(try ledger.allocator().dupe(u8, input));
        defer output.deinit(ledger.allocator());
        try std.testing.expectEqual(output.items.len, output.capacity);
        const before_pointer = output.items.ptr;
        _ = try zstd.encodeNativeFrameAppend(ledger.allocator(), &output, output.items, options);
        try std.testing.expect(before_pointer != output.items.ptr);
        try std.testing.expectEqualSlices(u8, input, output.items[0..input.len]);
        try std.testing.expectEqualSlices(u8, expected.frame, output.items[input.len..]);
    }
    try std.testing.expectEqual(@as(usize, 0), ledger.live);
}

const FinishAllocationGraph = struct {
    pub fn run(backing: std.mem.Allocator, input: []const u8, expected: []const u8) !void {
        var profile: zstd.EncoderControlProfile = .{};
        var encoder = try zstd.NativeIncrementalFrameEncoder.initExactSize(backing, .{ .strategy = .btultra2, .block_size_max = 128, .content_checksum = true, .control_profile = &profile }, input.len);
        defer encoder.deinit();
        var prefix: std.ArrayList(u8) = .empty;
        defer prefix.deinit(allocator);
        var header: [31]u8 = undefined;
        const failure: ?anyerror = blk: {
            const start = encoder.step("", &header) catch |err| break :blk err;
            try prefix.appendSlice(allocator, header[0..start.progress.output_written]);
            _ = encoder.step(input, &.{}) catch |err| break :blk err;
            encoder.finish();
            _ = encoder.step("", &.{}) catch |err| break :blk err;
            break :blk null;
        };
        if (failure) |err| {
            if (err != error.OutOfMemory) return err;
            const failing: *std.testing.FailingAllocator = @ptrCast(@alignCast(backing.ptr));
            failing.fail_index = std.math.maxInt(usize);
            failing.resize_fail_index = std.math.maxInt(usize);
        }
        const remaining = try h.driveEncoder(allocator, &encoder, input, 17, 31, null);
        defer allocator.free(remaining);
        try prefix.appendSlice(allocator, remaining);
        try std.testing.expectEqualSlices(u8, expected, prefix.items);
        try std.testing.expectEqual(@as(u64, 1), profile.raw_blocks + profile.rle_blocks + profile.compressed_blocks);
        if (failure) |err| return err;
    }
};

test "Zstd HQ resource every tiny finish allocation failure retries one last block and checksum" {
    const all_input = try h.corpusAlloc(allocator, .repetitive);
    defer allocator.free(all_input);
    const input = all_input[0..64];
    const expected = try zstd.encodeNativeFrameWithOptionsAlloc(allocator, input, .{ .strategy = .btultra2, .block_size_max = 128, .content_checksum = true });
    defer allocator.free(expected.frame);
    try std.testing.checkAllAllocationFailures(allocator, FinishAllocationGraph.run, .{ input, expected.frame });
}

test "Zstd HQ resource incremental budget retry keeps buffered input repeat state and profile commit" {
    const input = try h.corpusAlloc(allocator, .repetitive);
    defer allocator.free(input);
    var profile: zstd.EncoderControlProfile = .{};
    const options: zstd.NativeFrameOptions = .{ .strategy = .btultra2, .block_size_max = 512, .hq = .{ .max_working_memory = 0 }, .control_profile = &profile };
    var original = try zstd.NativeIncrementalFrameEncoder.initExactSize(allocator, options, input.len);
    var transferred = false;
    defer if (!transferred) original.deinit();
    var header: [31]u8 = undefined;
    const started = try original.step("", &header);
    const header_len = started.progress.output_written;
    _ = try original.step(input, &.{});
    original.finish();
    const before = original.snapshot();
    const emitted = profile.emitted();
    const repeats = original.codec_state.sequence_state.repeated_offsets;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, original.step("", &.{}));
    try std.testing.expectEqual(before.input_read, original.snapshot().input_read);
    try std.testing.expectEqual(input.len, original.snapshot().buffered_input);
    try std.testing.expectEqual(@as(usize, 0), original.snapshot().pending_output);
    try std.testing.expectEqual(repeats, original.codec_state.sequence_state.repeated_offsets);
    try std.testing.expectEqualDeep(emitted, profile.emitted());
    original.options.hq = .{};
    const rest = try h.driveEncoder(allocator, &original, input, 1, 1, null);
    defer allocator.free(rest);
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(allocator);
    try actual.appendSlice(allocator, header[0..header_len]);
    try actual.appendSlice(allocator, rest);
    var successful = options;
    successful.hq = .{};
    successful.control_profile = null;
    const expected = try zstd.encodeNativeFrameWithOptionsAlloc(allocator, input, successful);
    defer allocator.free(expected.frame);
    try std.testing.expectEqualSlices(u8, expected.frame, actual.items);
    original.reset();
    var moved = original;
    original = undefined;
    transferred = true;
    defer moved.deinit();
    const repeated = try h.driveEncoder(allocator, &moved, input, 17, 31, null);
    defer allocator.free(repeated);
    try std.testing.expectEqualSlices(u8, expected.frame, repeated);
}

test "Zstd HQ resource empty frame updates latest config without fictional parser work" {
    const input = try h.corpusAlloc(allocator, .repetitive);
    defer allocator.free(input);
    var profile: zstd.EncoderControlProfile = .{};
    const first = try zstd.encodeNativeFrameWithOptionsAlloc(allocator, input, .{ .strategy = .btopt, .control_profile = &profile });
    defer allocator.free(first.frame);
    const previous = profile;
    const empty = try zstd.encodeNativeFrameWithOptionsAlloc(allocator, "", .{ .strategy = .btlazy2, .hq = .{ .search_depth = 7, .nice_len = 16, .min_match = 4, .max_working_memory = 0 }, .control_profile = &profile });
    defer allocator.free(empty.frame);
    try std.testing.expectEqual(zstd.Strategy.btlazy2, profile.resolved_strategy);
    try std.testing.expectEqual(@as(u32, 7), profile.effective_hq_search_depth);
    try std.testing.expectEqual(@as(u32, 16), profile.effective_hq_nice_len);
    try std.testing.expectEqual(@as(u8, 4), profile.effective_hq_min_match);
    try std.testing.expectEqual(@as(usize, 0), profile.effective_hq_max_working_memory);
    try std.testing.expectEqual(previous.hq_passes, profile.hq_passes);
    try std.testing.expectEqual(previous.refinement_passes, profile.refinement_passes);
    try std.testing.expectEqual(previous.tree_nodes, profile.tree_nodes);
    try std.testing.expectEqual(previous.price_evaluations, profile.price_evaluations);
    try std.testing.expectEqual(previous.peak_working_memory, profile.peak_working_memory);
}
