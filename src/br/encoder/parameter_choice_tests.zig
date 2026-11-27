//! Choice witnesses are value-only results of an already completed search.
//! Fake writers isolate controller ordering/ownership from codec wire policy.
const std = @import("std");
const pair = @import("parameter_pair.zig");
const distance = @import("distance.zig");
const command = @import("command_plan.zig");
const common = @import("prepared_command_distance.zig");
const literal = @import("prepared_literal.zig");
const alternate = @import("prepared_parameter_distance.zig");
const quality = @import("quality_profile.zig");
const a = std.testing.allocator;

const Origin = enum { initial, base, alternative, fallback };
const TestStats = struct { value: usize = 100, origin: Origin = .initial, emitted_bytes: usize = 0 };
const Phase = enum { none, base_prepare, choose, alternate_prepare, base_emit, alternate_emit, fallback, free };
const Scenario = struct {
    base_len: usize = 12,
    alternate_len: usize = 7,
    fallback_len: usize = 4,
    selected_parameters: ?distance.Parameters = distance.Parameters.init(1, 3),
    failure: Phase = .none,
    failure_error: anyerror = error.OutOfMemory,
    base_calls: usize = 0,
    choose_calls: usize = 0,
    alternate_calls: usize = 0,
    base_emits: usize = 0,
    alternate_emits: usize = 0,
    fallback_calls: usize = 0,
    produced: usize = 0,
    freed: usize = 0,
    live: usize = 0,
    order: [16]Phase = undefined,
    order_len: usize = 0,

    fn enter(self: *Scenario, phase: Phase) !void {
        self.order[self.order_len] = phase;
        self.order_len += 1;
        if (phase == self.failure) return self.failure_error;
    }
};

const TestOptions = struct {
    scenario: *Scenario,
    distance_parameters: distance.Parameters = distance.Parameters.init(0, 0),
    use_recent_distances: bool = true,
    optimize_same_last_distance: bool = true,
    window_bits: u5 = 16,
    large_window: bool = false,
    compound_dictionary_size: usize = 0,
    initial_output_pos: u64 = 0,
    starting_last_distances: [4]usize = .{ 16, 15, 11, 4 },
    hq_model_output: ?u8 = null,
    final_wire_state: ?u8 = null,
    command_split: ?u8 = null,
    adaptive_command_split: ?u8 = null,
    distance_split: ?u8 = null,
    adaptive_distance_split: ?u8 = null,
    literal_split: ?u8 = null,
    adaptive_literal_split: ?u8 = null,
    literal_entropy_plan: ?u8 = null,
    write_stream_prefix: bool = true,
    final_meta_block: bool = true,
    metadata: []const u8 = "",
};

fn Trace(comptime enabled: bool) type {
    return struct {
        const Self = @This();
        recorder: quality.Recorder(enabled),
        scenario: *Scenario,
        pub fn begin(self: Self, stage: quality.Stage, input: usize, count: usize) if (enabled) quality.Scope else quality.EmptyScope {
            return self.recorder.begin(stage, input, count);
        }
        pub fn reference(self: Self, wire: []const u8) quality.CandidateRef {
            return self.recorder.reference(wire);
        }
        pub fn prefer(self: Self, candidate: []const u8, incumbent: []const u8) bool {
            return self.recorder.prefer(candidate, incumbent);
        }
        pub fn preferReferences(self: Self, candidate: quality.CandidateRef, incumbent: quality.CandidateRef) bool {
            return self.recorder.preferReferences(candidate, incumbent);
        }
        pub fn parameterPair(self: Self) void {
            self.recorder.parameterPair();
        }
        pub fn parameterCounted(self: Self) void {
            self.recorder.parameterCounted();
        }
        pub fn parameterEmitted(self: Self) void {
            self.recorder.parameterEmitted();
        }
        pub fn parameterSkipped(self: Self) void {
            self.recorder.parameterSkipped();
        }
    };
}

const Fake = struct {
    pub const Error = anyerror;
    pub const Stats = TestStats;
    pub const Options = TestOptions;

    pub fn prepareBase(comptime traced: bool, trace: anytype, _: std.mem.Allocator, input: []const u8, commands: []const command.Command, stats: *Stats, options: Options, prepared: *common.Prepared, state: *literal.State) !quality.CandidateRef {
        _ = traced;
        var scope = trace.begin(.evaluate, input.len, commands.len);
        defer scope.finish();
        errdefer |err| scope.failure(err);
        options.scenario.base_calls += 1;
        try options.scenario.enter(.base_prepare);
        prepared.ready = true;
        state.ready = true;
        stats.* = .{ .value = 110, .origin = .base };
        return scope.evaluated(options.scenario.base_len);
    }

    pub fn choose(_: std.mem.Allocator, _: []const command.Command, options: Options) !?distance.Parameters {
        const scenario = options.scenario;
        scenario.choose_calls += 1;
        try std.testing.expectEqual(@as(usize, 1), scenario.base_calls);
        try std.testing.expectEqual(@as(usize, 1), scenario.choose_calls);
        try scenario.enter(.choose);
        return scenario.selected_parameters;
    }

    pub fn prepareAlt(comptime traced: bool, trace: anytype, _: std.mem.Allocator, input: []const u8, commands: []const command.Command, stats: *Stats, options: Options, prepared: *common.Prepared, literals: *literal.State, state: *alternate.State) !quality.CandidateRef {
        _ = traced;
        var scope = trace.begin(.evaluate, input.len, commands.len);
        defer scope.finish();
        errdefer |err| scope.failure(err);
        try std.testing.expect(prepared.ready and literals.ready);
        try std.testing.expectEqualDeep(options.scenario.selected_parameters.?, options.distance_parameters);
        try std.testing.expect(!options.optimize_same_last_distance);
        options.scenario.alternate_calls += 1;
        try options.scenario.enter(.alternate_prepare);
        state.ready = true;
        stats.* = .{ .value = 120, .origin = .alternative };
        return scope.evaluated(options.scenario.alternate_len);
    }

    pub fn emitBase(comptime traced: bool, trace: anytype, allocator: std.mem.Allocator, input: []const u8, commands: []const command.Command, stats: *Stats, options: Options, prepared: *common.Prepared, literals: *literal.State, reference: quality.CandidateRef) ![]u8 {
        _ = traced;
        try std.testing.expect(prepared.ready and literals.ready);
        options.scenario.base_emits += 1;
        try options.scenario.enter(.base_emit);
        return emit(trace, allocator, input, commands, stats, options.scenario, reference, 0xb0);
    }

    pub fn emitAlt(comptime traced: bool, trace: anytype, allocator: std.mem.Allocator, input: []const u8, commands: []const command.Command, stats: *Stats, options: Options, prepared: *common.Prepared, literals: *literal.State, state: *alternate.State, reference: quality.CandidateRef) ![]u8 {
        _ = traced;
        try std.testing.expect(prepared.ready and literals.ready and state.ready);
        try std.testing.expectEqualDeep(options.scenario.selected_parameters.?, options.distance_parameters);
        try std.testing.expect(!options.optimize_same_last_distance);
        options.scenario.alternate_emits += 1;
        try options.scenario.enter(.alternate_emit);
        return emit(trace, allocator, input, commands, stats, options.scenario, reference, 0xa1);
    }

    pub fn physicalPair(comptime traced: bool, trace: anytype, allocator: std.mem.Allocator, input: []const u8, commands: []const command.Command, recent: bool, stats: *Stats, options: Options) ![]u8 {
        _ = traced;
        try std.testing.expect(recent);
        options.scenario.fallback_calls += 1;
        try options.scenario.enter(.fallback);
        stats.* = .{ .value = 130, .origin = .fallback };
        return emit(trace, allocator, input, commands, stats, options.scenario, .{ .bytes = options.scenario.fallback_len }, 0xf0);
    }

    fn emit(trace: anytype, allocator: std.mem.Allocator, input: []const u8, commands: []const command.Command, stats: *Stats, scenario: *Scenario, reference: quality.CandidateRef, byte: u8) ![]u8 {
        var scope = trace.begin(.wire, input.len, commands.len);
        defer scope.finish();
        errdefer |err| scope.failure(err);
        if (stats.origin != .fallback) scope.emissionOf(reference);
        const wire = try allocator.alloc(u8, reference.bytes);
        @memset(wire, byte);
        scenario.produced += 1;
        scenario.live += 1;
        stats.value += 1;
        stats.emitted_bytes = wire.len;
        scope.wire(wire);
        return wire;
    }

    pub fn free(comptime traced: bool, trace: anytype, allocator: std.mem.Allocator, wire: []u8) void {
        _ = traced;
        trace.recorder.forgetWire(wire);
        const scenario = trace.scenario;
        std.debug.assert(scenario.live != 0);
        scenario.order[scenario.order_len] = .free;
        scenario.order_len += 1;
        scenario.live -= 1;
        scenario.freed += 1;
        allocator.free(wire);
    }
};

const fixture_input = "aaaa";
const fixture_commands = [_]command.Command{.{ .insert_start = 0, .insert_len = fixture_input.len }};

fn searched(choice: pair.Choice, expected: ?distance.Parameters) !void {
    switch (choice) {
        .unsearched => return error.TestUnexpectedResult,
        .searched => |actual| try std.testing.expectEqualDeep(expected, actual),
    }
}

test "parameter choice searched null survives incumbent rejection and legacy wrapper" {
    var scenario: Scenario = .{ .base_len = 8, .selected_parameters = null };
    var profile: quality.Profile = .{};
    const trace: Trace(true) = .{ .recorder = .{ .io = std.testing.io, .profile = &profile }, .scenario = &scenario };
    var stats: TestStats = .{};
    const result = try pair.againstWithChoice(Fake, true, trace, a, fixture_input, &fixture_commands, &stats, .{ .scenario = &scenario }, "12345678");
    try searched(result.choice, null);
    try std.testing.expect(result.wire == null);
    try std.testing.expectEqualDeep(TestStats{ .value = 110, .origin = .base }, stats);
    try std.testing.expectEqualSlices(Phase, &.{ .base_prepare, .choose }, scenario.order[0..scenario.order_len]);
    try std.testing.expectEqual(@as(usize, 1), profile.parameter_pairs);
    try std.testing.expectEqual(@as(usize, 1), profile.parameter_counted_candidates);
    try std.testing.expectEqual(@as(usize, 1), profile.parameter_skipped_pair_emits);
    try std.testing.expectEqual(@as(usize, 0), profile.wire_attempts);
    scenario = .{ .base_len = 8, .selected_parameters = null };
    profile.reset();
    stats = .{};
    try std.testing.expect((try pair.against(Fake, true, trace, a, fixture_input, &fixture_commands, &stats, .{ .scenario = &scenario }, "12345678")) == null);
    try std.testing.expectEqual(@as(usize, 1), scenario.choose_calls);
    try std.testing.expectEqualDeep(TestStats{ .value = 110, .origin = .base }, stats);
    scenario = .{ .base_len = 8, .selected_parameters = null };
    profile.reset();
    stats = .{};
    const accepted = try pair.againstWithChoice(Fake, true, trace, a, fixture_input, &fixture_commands, &stats, .{ .scenario = &scenario }, "123456789");
    try searched(accepted.choice, null);
    const accepted_wire = accepted.wire orelse return error.TestUnexpectedResult;
    Fake.free(true, trace, a, accepted_wire);
    try std.testing.expectEqual(@as(usize, 1), scenario.choose_calls);
    try std.testing.expectEqual(@as(usize, 1), scenario.base_emits);
    try std.testing.expectEqual(@as(usize, 1), scenario.freed);
    try std.testing.expectEqualDeep(TestStats{ .value = 111, .origin = .base, .emitted_bytes = 8 }, stats);
    scenario = .{ .base_len = 8, .selected_parameters = null };
    profile.reset();
    stats = .{};
    const legacy_wire = (try pair.against(Fake, true, trace, a, fixture_input, &fixture_commands, &stats, .{ .scenario = &scenario }, "123456789")) orelse return error.TestUnexpectedResult;
    Fake.free(true, trace, a, legacy_wire);
    try std.testing.expectEqual(@as(usize, 1), scenario.choose_calls);
    try std.testing.expectEqualDeep(TestStats{ .value = 111, .origin = .base, .emitted_bytes = 8 }, stats);
}

test "parameter choice baseline tie retains alternative witness and emits first evaluation" {
    var scenario: Scenario = .{ .base_len = 8, .alternate_len = 8 };
    var profile: quality.Profile = .{};
    const trace: Trace(true) = .{ .recorder = .{ .io = std.testing.io, .profile = &profile }, .scenario = &scenario };
    var stats: TestStats = .{};
    const result = try pair.againstWithChoice(Fake, true, trace, a, fixture_input, &fixture_commands, &stats, .{ .scenario = &scenario }, "123456789");
    try searched(result.choice, scenario.selected_parameters);
    const wire = result.wire orelse return error.TestUnexpectedResult;
    defer Fake.free(true, trace, a, wire);
    try std.testing.expectEqualSlices(u8, &@as([8]u8, @splat(0xb0)), wire);
    try std.testing.expectEqualDeep(TestStats{ .value = 111, .origin = .base, .emitted_bytes = 8 }, stats);
    try std.testing.expectEqualSlices(Phase, &.{ .base_prepare, .choose, .alternate_prepare, .base_emit }, scenario.order[0..scenario.order_len]);
    try std.testing.expectEqual(@as(usize, 2), profile.parameter_counted_candidates);
    try std.testing.expectEqual(@as(usize, 1), profile.parameter_physical_emits);
    try std.testing.expectEqual(@as(usize, 1), profile.wire_attempts);
    var emission: ?usize = null;
    for (profile.recordedEvents()) |event| {
        if (event.stage == .selection and event.incumbent_bytes == 8) try std.testing.expectEqual(@as(?bool, false), event.accepted);
        if (event.stage == .wire) emission = event.evaluation_event_id;
    }
    try std.testing.expectEqual(@as(?usize, 1), emission);
}

test "parameter choice selected alternative survives every strict incumbent outcome" {
    for ([_]usize{ 6, 7, 8 }) |incumbent_len| {
        var scenario: Scenario = .{};
        const trace: Trace(false) = .{ .recorder = .{}, .scenario = &scenario };
        var stats: TestStats = .{};
        const guarded = [_]u8{ 0x73, 0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x91 };
        const incumbent = guarded[1..][0..incumbent_len];
        const result = try pair.againstWithChoice(Fake, false, trace, a, fixture_input, &fixture_commands, &stats, .{ .scenario = &scenario }, incumbent);
        try searched(result.choice, scenario.selected_parameters);
        try std.testing.expectEqual(@as(usize, 1), scenario.choose_calls);
        try std.testing.expectEqual(@as(usize, 1), scenario.alternate_calls);
        if (result.wire) |wire| {
            try std.testing.expectEqual(@as(usize, 8), incumbent_len);
            try std.testing.expectEqualSlices(u8, &@as([7]u8, @splat(0xa1)), wire);
            try std.testing.expect(wire.ptr != incumbent.ptr);
            try std.testing.expectEqualDeep(TestStats{ .value = 121, .origin = .alternative, .emitted_bytes = 7 }, stats);
            Fake.free(false, trace, a, wire);
        } else {
            try std.testing.expect(incumbent_len <= 7);
            try std.testing.expectEqualDeep(TestStats{ .value = 120, .origin = .alternative }, stats);
            try std.testing.expectEqual(@as(usize, 0), scenario.produced);
        }
        try std.testing.expectEqual(@as(u8, 0x73), guarded[0]);
        try std.testing.expectEqual(@as(u8, 0x91), guarded[9]);
        for (incumbent) |byte| try std.testing.expectEqual(@as(u8, 0x33), byte);
        try std.testing.expectEqual(@as(usize, 0), scenario.live);
        try std.testing.expectEqual(scenario.produced, scenario.freed);
    }
}

test "parameter choice unsupported physical fallback stays unsearched and frees only owned wire" {
    for ([_]usize{ 4, 5 }) |incumbent_len| {
        var scenario: Scenario = .{ .failure = .choose, .failure_error = error.InvalidBlockPlan };
        var profile: quality.Profile = .{};
        const trace: Trace(true) = .{ .recorder = .{ .io = std.testing.io, .profile = &profile }, .scenario = &scenario };
        var stats: TestStats = .{};
        const result = try pair.againstWithChoice(Fake, true, trace, a, fixture_input, &fixture_commands, &stats, .{ .scenario = &scenario, .metadata = "unsupported" }, "12345"[0..incumbent_len]);
        switch (result.choice) {
            .unsearched => {},
            .searched => return error.TestUnexpectedResult,
        }
        try std.testing.expectEqual(@as(usize, 0), scenario.choose_calls);
        try std.testing.expectEqual(@as(usize, 0), scenario.base_calls);
        try std.testing.expectEqual(@as(usize, 1), scenario.fallback_calls);
        try std.testing.expectEqual(@as(usize, 0), profile.parameter_pairs);
        try std.testing.expectEqual(@as(usize, 0), profile.evaluation_attempts);
        try std.testing.expectEqual(@as(usize, 1), profile.wire_attempts);
        try std.testing.expectEqualDeep(TestStats{ .value = 131, .origin = .fallback, .emitted_bytes = 4 }, stats);
        if (result.wire) |wire| {
            try std.testing.expectEqual(@as(usize, 5), incumbent_len);
            Fake.free(true, trace, a, wire);
        } else try std.testing.expectEqual(@as(usize, 4), incumbent_len);
        try std.testing.expectEqual(@as(usize, 1), scenario.produced);
        try std.testing.expectEqual(@as(usize, 1), scenario.freed);
        try std.testing.expectEqual(@as(usize, 0), scenario.live);
    }
}

test "parameter choice stage errors never publish a guessed witness or selected stats" {
    for ([_]Phase{ .base_prepare, .choose, .alternate_prepare, .base_emit, .alternate_emit, .fallback }) |phase| {
        for ([_]anyerror{ error.OutOfMemory, error.InvalidBlockPlan }) |failure| {
            var scenario: Scenario = .{ .failure = phase, .failure_error = failure };
            if (phase == .base_emit) scenario.selected_parameters = null;
            const trace: Trace(false) = .{ .recorder = .{}, .scenario = &scenario };
            const options: TestOptions = .{ .scenario = &scenario, .metadata = if (phase == .fallback) "unsupported" else "" };
            var stats: TestStats = .{};
            var published: ?pair.Result = null;
            if (pair.againstWithChoice(Fake, false, trace, a, fixture_input, &fixture_commands, &stats, options, "1234567890123456")) |result| {
                if (result.wire) |wire| Fake.free(false, trace, a, wire);
                published = result;
            } else |err| try std.testing.expectEqual(failure, err);
            try std.testing.expect(published == null);
            try std.testing.expectEqualDeep(TestStats{}, stats);
            try std.testing.expectEqual(@as(usize, 0), scenario.produced);
            try std.testing.expectEqual(@as(usize, 0), scenario.live);
            try std.testing.expectEqual(@as(usize, if (phase == .base_prepare or phase == .fallback) 0 else 1), scenario.choose_calls);
        }
    }
    var scenario: Scenario = .{};
    const trace: Trace(false) = .{ .recorder = .{}, .scenario = &scenario };
    var stats: TestStats = .{};
    try std.testing.expectError(error.InvalidBlockPlan, pair.againstWithChoice(Fake, false, trace, a, fixture_input, &fixture_commands, &stats, .{ .scenario = &scenario, .use_recent_distances = false }, "1234567890123456"));
    try std.testing.expectEqual(@as(usize, 0), scenario.order_len);
    try std.testing.expectEqualDeep(TestStats{}, stats);
}

test "parameter choice backing allocation failures preserve errors and allow reuse retry" {
    var heap = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
    var scenario: Scenario = .{};
    const trace: Trace(false) = .{ .recorder = .{}, .scenario = &scenario };
    var stats: TestStats = .{};
    try std.testing.expectError(error.OutOfMemory, pair.againstWithChoice(Fake, false, trace, heap.allocator(), fixture_input, &fixture_commands, &stats, .{ .scenario = &scenario }, "1234567890123456"));
    try std.testing.expect(heap.has_induced_failure);
    try std.testing.expectEqual(@as(usize, 1), scenario.choose_calls);
    try std.testing.expectEqualDeep(TestStats{}, stats);
    try std.testing.expectEqual(heap.allocated_bytes, heap.freed_bytes);
    heap.fail_index = std.math.maxInt(usize);
    heap.has_induced_failure = false;
    scenario = .{};
    const result = try pair.againstWithChoice(Fake, false, trace, heap.allocator(), fixture_input, &fixture_commands, &stats, .{ .scenario = &scenario }, "1234567890123456");
    try searched(result.choice, scenario.selected_parameters);
    const wire = result.wire orelse return error.TestUnexpectedResult;
    Fake.free(false, trace, heap.allocator(), wire);
    try std.testing.expectEqual(heap.allocated_bytes, heap.freed_bytes);
    const Sweep = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var state: Scenario = .{};
            const active: Trace(false) = .{ .recorder = .{}, .scenario = &state };
            var output_stats: TestStats = .{};
            const chosen = try pair.againstWithChoice(Fake, false, active, allocator, fixture_input, &fixture_commands, &output_stats, .{ .scenario = &state }, "1234567890123456");
            const owned = chosen.wire orelse return error.TestUnexpectedResult;
            defer Fake.free(false, active, allocator, owned);
            try searched(chosen.choice, state.selected_parameters);
            try std.testing.expectEqual(@as(usize, 1), state.choose_calls);
        }
    };
    try std.testing.checkAllAllocationFailures(a, Sweep.run, .{});
}
