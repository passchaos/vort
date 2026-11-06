const std = @import("std");
const core = @import("../../../core.zig");
const fixtures = @import("rolling_semantic/fixtures.zig");
const oracle = @import("rolling_semantic/oracle.zig");
const allocator = std.testing.allocator;
const output_cycle = [_]usize{ 0, 1, 257, 258, 4096 };

const Schedule = struct {
    input_chunks: []const usize = &.{std.math.maxInt(usize)},
    output_chunks: []const usize = &output_cycle,
    stop_at_limit: bool = false,
};
const Termination = struct {
    err: ?core.Error = null,
    status: core.StepResult.Status,
};

fn drive(rig: *oracle.Rig, input: []const u8, payload: []const u8, dictionary: []const u8, schedule: Schedule) !Termination {
    var calls: usize = 0;
    while (calls < 10000) : (calls += 1) {
        const offset = try core.stream_count.toLocal(rig.linear.total_input);
        try std.testing.expect(offset <= input.len);
        const input_len = @min(input.len - offset, schedule.input_chunks[calls % schedule.input_chunks.len]);
        const output_len = schedule.output_chunks[calls % schedule.output_chunks.len];
        const outcome = try rig.invoke(input[offset..][0..input_len], output_len, dictionary, payload);
        switch (outcome) {
            .failure => |err| return .{ .err = err, .status = .need_input },
            .step => |step| {
                if (step.status == .done) {
                    return .{ .err = try rig.finish(dictionary, payload), .status = .done };
                }
                if (schedule.stop_at_limit and step.status == .need_output and
                    rig.linear.total_output == rig.linear.options.max_output_len)
                {
                    return .{ .status = .need_output };
                }
                if (step.status == .need_input and rig.linear.total_input == input.len) {
                    return .{ .err = try rig.finish(dictionary, payload), .status = .need_input };
                }
            },
        }
    }
    return error.TestUnexpectedResult;
}

fn expectDone(rig: *oracle.Rig, fixture: fixtures.Fixture, schedule: Schedule, dictionary: []const u8) !void {
    const terminal = try drive(rig, fixture.encoded, fixture.payload, dictionary, schedule);
    try std.testing.expectEqual(@as(?core.Error, null), terminal.err);
    try std.testing.expectEqual(core.StepResult.Status.done, terminal.status);
    try std.testing.expectEqual(fixture.body_len, rig.linear.total_input);
    try std.testing.expectEqual(fixture.payload.len, rig.linear.total_output);
    try std.testing.expectEqualSlices(u8, &fixtures.suffix, fixture.encoded[(try core.stream_count.toLocal(rig.linear.total_input))..]);
}

test "rolling semantic four routes preserve every step across multiple private windows" {
    const fixture = try fixtures.multiWindow(allocator, 0);
    defer fixture.deinit(allocator);
    var rig: oracle.Rig = undefined;
    try rig.init(.{ .expected_output_len = fixture.payload.len, .allow_trailing_data = true }, &.{});
    const prepared = try rig.invoke(fixture.encoded, 0, &.{}, fixture.payload);
    try std.testing.expectEqual(core.StepResult.Status.need_output, prepared.step.status);
    try std.testing.expect(rig.rolling.phase == .fast_dynamic_block);
    try std.testing.expect(rig.rolling.semantic_generated_end > rig.rolling.semantic_delivered);
    try expectDone(&rig, fixture, .{}, &.{});
    const linear_work = rig.observed_linear.semanticWork();
    const rolling_work = rig.observed_rolling.semanticWork();
    try std.testing.expectEqual(@as(u64, @intCast(fixture.payload.len)), rolling_work.generated_bytes);
    try std.testing.expectEqual(rolling_work.generated_bytes, rolling_work.delivered_bytes);
    try std.testing.expectEqual(@as(u64, 0), rolling_work.discarded_bytes);
    try std.testing.expect(rolling_work.generation_wraps > 0);
    try std.testing.expect(rolling_work.drain_wraps > 0);
    try std.testing.expect(rolling_work.normalization_bytes < linear_work.normalization_bytes);
    try std.testing.expectEqual(@as(usize, 1), rig.rolling.semanticBlocksCompleted());
    // Ordinary production state has zero-sized accounting storage.
    try std.testing.expectEqual(@as(usize, 0), @sizeOf(@TypeOf(rig.rolling.semantic_work)));
    try std.testing.expect(@sizeOf(@TypeOf(rig.observed_rolling.semantic_work)) > 0);
}

test "rolling semantic dynamic fixed stored transitions preserve distance 32768 and suffix" {
    const fixture = try fixtures.transitions(allocator);
    defer fixture.deinit(allocator);
    var rig: oracle.Rig = undefined;
    try rig.init(.{ .expected_output_len = fixture.payload.len, .allow_trailing_data = true }, &.{});
    try expectDone(&rig, fixture, .{}, &.{});
    try std.testing.expectEqual(@as(usize, 1), rig.rolling.semanticBlocksStarted());
    try std.testing.expectEqual(@as(usize, 1), rig.rolling.semanticBlocksCompleted());
    try std.testing.expect(rig.observed_rolling.semanticWork().normalization_bytes != 0);
}

test "rolling semantic fragmented transactions discard private output before compact fallback" {
    const fixture = try fixtures.multiWindow(allocator, 0);
    defer fixture.deinit(allocator);
    var rig: oracle.Rig = undefined;
    try rig.init(.{ .expected_output_len = fixture.payload.len, .allow_trailing_data = true }, &.{});
    const fallback = try rig.invoke(fixture.encoded[0..8192], 0, &.{}, fixture.payload);
    try std.testing.expectEqual(core.StepResult.Status.need_output, fallback.step.status);
    try std.testing.expect(rig.rolling.phase == .symbols);
    try std.testing.expectEqual(@as(usize, 0), rig.rolling.total_output);
    try std.testing.expectEqual(@as(usize, 1), rig.rolling.semanticBlocksStarted());
    try std.testing.expect(rig.observed_rolling.semanticWork().discarded_bytes > 0);
    try expectDone(&rig, fixture, .{ .input_chunks = &.{ 1, 7, 31, 257 } }, &.{});
    try std.testing.expectEqual(@as(usize, 0), rig.rolling.semanticBlocksCompleted());
}

test "rolling semantic all short dynamic prefixes and transaction boundary truncations agree" {
    const short = try fixtures.shortDynamic(allocator);
    defer short.deinit(allocator);
    var rig: oracle.Rig = undefined;
    try rig.init(.{ .expected_output_len = short.payload.len, .allow_trailing_data = true }, &.{});
    try expectDone(&rig, short, .{ .output_chunks = &.{1} }, &.{});
    for (0..short.body_len) |cut| {
        try rig.init(.{ .expected_output_len = short.payload.len, .allow_trailing_data = true }, &.{});
        const terminal = try drive(&rig, short.encoded[0..cut], short.payload, &.{}, .{});
        try std.testing.expectEqual(@as(?core.Error, error.TruncatedFrame), terminal.err);
        try std.testing.expectEqual(cut, rig.linear.total_input);
    }
    const large = try fixtures.multiWindow(allocator, 0);
    defer large.deinit(allocator);
    for ([_]usize{ 4095, 4096, 8191, 8192, large.body_len - 2, large.body_len - 1 }) |cut| {
        try rig.init(.{ .expected_output_len = large.payload.len, .allow_trailing_data = true }, &.{});
        const terminal = try drive(&rig, large.encoded[0..cut], large.payload, &.{}, .{});
        try std.testing.expectEqual(@as(?core.Error, error.TruncatedFrame), terminal.err);
        try std.testing.expectEqual(cut, rig.linear.total_input);
    }
}

test "rolling semantic dictionary prefixes preserve zero-copy chronological bootstrap" {
    var dictionary: [32768 + 29]u8 = undefined;
    for (&dictionary, 0..) |*byte, index| byte.* = @truncate(index *% 17 ^ index >> 9);
    for ([_]usize{ 1, 32768, dictionary.len }) |len| {
        const source = dictionary[0..len];
        const fixture = try fixtures.dictionaryDynamic(allocator, source);
        defer fixture.deinit(allocator);
        var rig: oracle.Rig = undefined;
        try rig.init(.{ .expected_output_len = fixture.payload.len, .allow_trailing_data = true }, source);
        try expectDone(&rig, fixture, .{}, source);
        try std.testing.expectEqual(@as(usize, 1), rig.rolling.semanticBlocksCompleted());
        try std.testing.expectEqual(@as(u64, 0), rig.observed_rolling.semanticWork().bootstrap_bytes);
        try std.testing.expectEqual(2 * @as(u64, @intCast(@min(len, 32768))), rig.observed_linear.semanticWork().bootstrap_bytes);
    }
}

test "rolling semantic rotated compact ring bootstrap stays chronological before multiple windows" {
    const fixture = try fixtures.multiWindow(allocator, 32768 + 17);
    defer fixture.deinit(allocator);
    var rig: oracle.Rig = undefined;
    try rig.init(.{ .expected_output_len = fixture.payload.len, .allow_trailing_data = true }, &.{});
    try expectDone(&rig, fixture, .{}, &.{});
    try std.testing.expectEqual(@as(u64, 65536), rig.observed_rolling.semanticWork().bootstrap_bytes);
    try std.testing.expectEqual(rig.observed_linear.semanticWork().bootstrap_bytes, rig.observed_rolling.semanticWork().bootstrap_bytes);
}

test "rolling semantic limits diagnostics and reset preserve ordinary observed parity" {
    const fixture = try fixtures.multiWindow(allocator, 0);
    defer fixture.deinit(allocator);
    const Case = struct { options: oracle.Options, err: core.Error };
    const common: oracle.Options = .{ .allow_trailing_data = true };
    const cases = [_]Case{
        .{ .options = .{ .allow_trailing_data = common.allow_trailing_data, .max_output_len = fixture.payload.len - 1 }, .err = error.OutputLimitExceeded },
        .{ .options = .{ .allow_trailing_data = true, .expected_output_len = fixture.payload.len - 1 }, .err = error.SizeMismatch },
        .{ .options = .{ .allow_trailing_data = true, .expected_output_len = fixture.payload.len + 1 }, .err = error.SizeMismatch },
        .{ .options = .{ .allow_trailing_data = true, .max_distance = 0 }, .err = error.InvalidMatch },
    };
    var rig: oracle.Rig = undefined;
    for (cases) |case| {
        try rig.init(case.options, &.{});
        const terminal = try drive(&rig, fixture.encoded, fixture.payload, &.{}, .{});
        try std.testing.expectEqual(@as(?core.Error, case.err), terminal.err);
        try std.testing.expectEqualStrings(@errorName(case.err), rig.rolling.diagnostics().last_error_name);
        try rig.reset(&.{});
        const repeated = try drive(&rig, fixture.encoded, fixture.payload, &.{}, .{});
        try std.testing.expectEqual(@as(?core.Error, case.err), repeated.err);
    }
    try rig.init(.{ .allow_trailing_data = true, .max_output_len = 1001, .stop_at_output_limit = true }, &.{});
    const stopped = try drive(&rig, fixture.encoded, fixture.payload, &.{}, .{ .stop_at_limit = true });
    try std.testing.expectEqual(@as(?core.Error, null), stopped.err);
    try std.testing.expectEqual(core.StepResult.Status.need_output, stopped.status);
    try std.testing.expectEqual(@as(usize, 1001), rig.rolling.total_output);
    try std.testing.expectEqual(@as(usize, 0), rig.rolling.semanticBlocksStarted());
    try rig.init(.{ .expected_output_len = fixture.payload.len, .allow_trailing_data = true }, &.{});
    try expectDone(&rig, fixture, .{}, &.{});
    try rig.reset(&.{});
    try expectDone(&rig, fixture, .{ .output_chunks = &.{ 257, 258, 4096 } }, &.{});
}

test "rolling semantic public capacity regression pauses after packed pair and single literal" {
    const fixture = try fixtures.capacityRegression(allocator);
    defer fixture.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 32835), fixture.payload.len);
    try std.testing.expect(fixture.body_len > 4096);
    try std.testing.expectEqualSlices(u8, "BCA", fixture.payload[32510..32513]);
    var rig: oracle.Rig = undefined;
    try rig.init(.{ .expected_output_len = fixture.payload.len, .allow_trailing_data = true }, &.{});
    const prepared = try rig.invoke(fixture.encoded, 0, &.{}, fixture.payload);
    try std.testing.expectEqual(core.StepResult.Status.need_output, prepared.step.status);
    try std.testing.expectEqual(@as(usize, 0), prepared.step.progress.output_written);
    try std.testing.expect(rig.rolling.phase == .fast_dynamic_block);
    try std.testing.expectEqual(@as(usize, 1), rig.rolling.semanticBlocksStarted());
    try std.testing.expectEqual(@as(usize, 32513), rig.rolling.semantic_generated_end);
    try std.testing.expectEqual(@as(usize, 0), rig.rolling.semantic_delivered);
    try std.testing.expectEqual(@as(u64, 32513), rig.observed_rolling.semanticWork().generated_bytes);
    try expectDone(&rig, fixture, .{}, &.{});
    try std.testing.expectEqual(@as(usize, 1), rig.rolling.semanticBlocksCompleted());
    try std.testing.expectEqual(@as(u64, 32835), rig.observed_rolling.semanticWork().generated_bytes);
    try std.testing.expectEqual(@as(u64, 32835), rig.observed_rolling.semanticWork().delivered_bytes);
    try std.testing.expectEqual(@as(u64, 0), rig.observed_rolling.semanticWork().discarded_bytes);
}

test "rolling semantic invalid singleton distance preserves advanced committed prefix on fallback" {
    const fixture = try fixtures.invalidSingletonAfterWindows(allocator);
    defer fixture.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 136452), fixture.payload.len);
    var rig: oracle.Rig = undefined;
    // No expected length: the semantic decoder must reach the illegal token.
    try rig.init(.{ .allow_trailing_data = true }, &.{});
    const prepared = try rig.invoke(fixture.encoded, 0, &.{}, fixture.payload);
    try std.testing.expectEqual(core.StepResult.Status.need_output, prepared.step.status);
    var snapshot: [32768]u8 = undefined;
    var checked_fallback = false;
    var calls: usize = 0;
    while (!checked_fallback and calls < 128) : (calls += 1) {
        try std.testing.expect(rig.rolling.phase == .fast_dynamic_block);
        const pending = rig.rolling.semantic_generated_end - rig.rolling.semantic_delivered;
        try std.testing.expect(pending != 0);
        const n = @min(pending, 4096);
        const previous_work = rig.observed_rolling.semanticWork();
        const previous_base = rig.rolling.semantic_prefix_start;
        const previous_output = rig.rolling.total_output;
        if (n == pending and rig.rolling.semantic_generated_end >= snapshot.len) {
            const start = rig.rolling.semantic_generated_end - snapshot.len;
            const source = (previous_base + start) % 65536;
            const first = @min(snapshot.len, 65536 - source);
            @memcpy(snapshot[0..first], rig.rolling.semantic_scratch[source..][0..first]);
            @memcpy(snapshot[first..], rig.rolling.semantic_scratch[0 .. snapshot.len - first]);
        }
        const outcome = try rig.invoke(fixture.encoded[(try core.stream_count.toLocal(rig.linear.total_input))..], n, &.{}, fixture.payload);
        try std.testing.expectEqual(core.StepResult.Status.need_output, outcome.step.status);
        const work = rig.observed_rolling.semanticWork();
        if (work.discarded_bytes > previous_work.discarded_bytes) {
            try std.testing.expectEqual(pending, n);
            try std.testing.expect(previous_work.generated_bytes >= 3 * 32768);
            try std.testing.expect(previous_base != 0);
            try std.testing.expect(work.normalization_bytes > previous_work.normalization_bytes);
            try std.testing.expectEqual(previous_output + n, rig.rolling.total_output);
            // Exactly the previous generation was published. The failed
            // private generation remains discarded before compact decoding.
            inline for (.{ "linear", "rolling", "observed_linear", "observed_rolling" }) |name| {
                const current = &@field(rig, name);
                try std.testing.expect(current.phase == .symbols);
                try std.testing.expectEqual(@as(usize, 0), current.semantic_prefix_start);
                try std.testing.expectEqual(snapshot.len, current.history_len);
                try std.testing.expectEqual(@as(usize, 0), current.history_pos);
                try std.testing.expectEqualSlices(u8, &snapshot, current.history[0..snapshot.len]);
            }
            try std.testing.expect(std.mem.indexOfScalar(u8, &snapshot, 'B') != null);
            try std.testing.expect(std.mem.indexOfScalar(u8, &snapshot, 'C') != null);
            checked_fallback = true;
        }
    }
    try std.testing.expect(checked_fallback);
    const terminal = try drive(&rig, fixture.encoded, fixture.payload, &.{}, .{});
    try std.testing.expectEqual(@as(?core.Error, error.InvalidHuffmanCode), terminal.err);
    try std.testing.expectEqualStrings("InvalidHuffmanCode", rig.rolling.diagnostics().last_error_name);
    try std.testing.expectEqual(fixture.payload.len, rig.rolling.total_output);
    try std.testing.expect(rig.rolling.total_input < fixture.body_len);
    try std.testing.expectEqual(@as(usize, 0), rig.rolling.semantic_prefix_start);
    try std.testing.expect(rig.observed_rolling.semanticWork().discarded_bytes > 0);
    try std.testing.expect(rig.observed_rolling.semanticWork().normalization_bytes > 0);
    try std.testing.expectEqual(@as(usize, 0), rig.rolling.semanticBlocksCompleted());
}
