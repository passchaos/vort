//! Independent synthetic decision/ownership oracle for counted primaries.
//! Strategy state owns no heap; only physical primary, emit and plain allocate.
const std = @import("std");
const contexts = @import("literal_context_split.zig");
const profile = @import("quality_profile.zig");

const Kind = enum { primary, emitted, plain, unknown };
const Fault = enum { initial, proposal_0, proposal_1, proposal_2, proposals, plain, emit };

const Heap = struct {
    const Slot = struct { memory: []u8, alignment: std.mem.Alignment, kind: Kind = .unknown, frees: usize = 0 };
    slots: [8]Slot = undefined,
    len: usize = 0,
    allocation_calls: usize = 0,
    invalid_frees: usize = 0,
    failure_count: usize = 0,
    fail_next: bool = false,

    fn allocator(self: *Heap) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = allocate, .resize = resize, .remap = remap, .free = release } };
    }
    fn allocate(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *Heap = @ptrCast(@alignCast(raw));
        self.allocation_calls += 1;
        if (self.fail_next) {
            self.fail_next = false;
            self.failure_count += 1;
            return null;
        }
        if (self.len == self.slots.len) return null;
        const memory = std.testing.allocator.rawAlloc(len, alignment, ra) orelse return null;
        self.slots[self.len] = .{ .memory = memory[0..len], .alignment = alignment };
        self.len += 1;
        return memory;
    }
    fn resize(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) bool {
        return false;
    }
    fn remap(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) ?[*]u8 {
        return null;
    }
    fn release(raw: *anyopaque, memory: []u8, _: std.mem.Alignment, _: usize) void {
        const self: *Heap = @ptrCast(@alignCast(raw));
        const slot = self.find(memory) orelse {
            self.invalid_frees += 1;
            return;
        };
        slot.frees += 1;
    }
    fn find(self: *Heap, memory: []const u8) ?*Slot {
        for (self.slots[0..self.len]) |*slot| {
            if (slot.memory.ptr == memory.ptr and slot.memory.len == memory.len) return slot;
        }
        return null;
    }
    fn live(self: *const Heap, kind: Kind) bool {
        for (self.slots[0..self.len]) |slot| if (slot.kind == kind and slot.frees == 0) return true;
        return false;
    }
    fn returned(self: *Heap, memory: []u8, kind: Kind) !void {
        const selected = self.find(memory) orelse return error.TestUnexpectedResult;
        try std.testing.expectEqual(kind, selected.kind);
        try std.testing.expectEqual(@as(usize, 0), selected.frees);
        self.allocator().free(memory);
        try self.closed();
    }
    fn closed(self: *const Heap) !void {
        try std.testing.expectEqual(@as(usize, 0), self.invalid_frees);
        for (self.slots[0..self.len]) |slot| try std.testing.expectEqual(@as(usize, 1), slot.frees);
    }
    fn deinit(self: *Heap) void {
        // Delay physical releases so addresses remain unique and a double free
        // is diagnosed by the ledger instead of corrupting the backing heap.
        for (self.slots[0..self.len]) |slot| std.testing.allocator.rawFree(slot.memory, slot.alignment, @returnAddress());
    }
};

const Config = struct {
    widths: [4]usize = .{ 100, 90, 80, 70 },
    plain: usize = 120,
    input_len: usize = 100,
    explicit: ?bool = null,
    mask: u3 = 7,
    primary: enum { utf8, plain, other_mode, duplicate_first } = .utf8,
    duplicates: enum { none, repeat_first, primary_all } = .none,
    fault: ?Fault = null,
    failure: error{ SyntheticFailure, OutOfMemory } = error.SyntheticFailure,
};

const Scenario = struct {
    config: Config,
    primary_context: ?contexts.Candidate,
    proposals: contexts.Proposals,
    primary_calls: usize = 0,
    prepare_calls: [4]usize = @splat(0),
    initial_stats: [4]u8 = @splat(0xff),
    seed_stats: [4]u32 = @splat(0),
    physical_live: [4]bool = @splat(false),
    primary_prepare_allocations: ?usize = null,
    proposal_calls: usize = 0,
    copy_slots: [3]u8 = @splat(0xff),
    copies: usize = 0,
    emit_calls: usize = 0,
    emitted_slot: ?u8 = null,
    emit_primary_live: bool = false,
    emit_plain_live: bool = false,
    plain_calls: usize = 0,
    plain_initial: u8 = 0xff,
    reached_faults: usize = 0,

    fn init(config: Config) Scenario {
        const candidates = [_]contexts.Candidate{
            contexts.Candidate.suffix(2, 24, 101),
            contexts.Candidate.suffix(0, 40, 102),
            contexts.Candidate.suffix(3, 52, 103),
        };
        const primary_context: ?contexts.Candidate = switch (config.primary) {
            .utf8 => contexts.Candidate.suffix(2, 56, 100),
            .plain => null,
            .other_mode => contexts.Candidate.suffix(0, 56, 100),
            .duplicate_first => candidates[0],
        };
        var proposals: contexts.Proposals = .{};
        inline for (.{ "suffix", "up_to_16", "full" }, 0..) |field, index| {
            if (config.mask & (@as(u3, 1) << @intCast(index)) != 0) {
                @field(proposals, field) = switch (config.duplicates) {
                    .none => candidates[index],
                    .repeat_first => candidates[0],
                    .primary_all => primary_context orelse candidates[0],
                };
            }
        }
        return .{ .config = config, .primary_context = primary_context, .proposals = proposals };
    }
    fn slotFor(self: *const Scenario, candidate: ?contexts.Candidate) u8 {
        if (candidate == null) return 0;
        if (self.primary_context) |primary| if (contexts.Candidate.eql(primary, candidate.?)) return 0;
        const originals = [_]contexts.Candidate{
            contexts.Candidate.suffix(2, 24, 101),
            contexts.Candidate.suffix(0, 40, 102),
            contexts.Candidate.suffix(3, 52, 103),
        };
        for (originals, 0..) |value, index| if (contexts.Candidate.eql(value, candidate.?)) return @intCast(index + 1);
        @panic("unknown synthetic context");
    }
    fn fail(self: *Scenario, stage: Fault) Strategy.Error!void {
        if (self.config.fault == stage) {
            self.reached_faults += 1;
            return self.config.failure;
        }
    }
};

const Strategy = struct {
    pub const Error = error{ OutOfMemory, SyntheticFailure, InvalidBlockPlan };
    pub const Stats = struct { marker: u8 = 7, seed: u32 = 0xa1b2_c3d4, bytes: usize = 999 };
    pub const Options = struct { literal_context_candidate: ?contexts.Candidate = null };
    pub const UserOptions = struct { try_literal_contexts: ?bool = null };
    pub const Result = struct {
        encoded: []u8,
        use_recent_distances: bool,
        literal_context_candidate: ?contexts.Candidate = null,
        alternate_literal_context_candidates: [3]contexts.Candidate = undefined,
        alternate_literal_context_count: u2 = 0,
        alternate_plain_literals: bool = false,
        literal_split_utf8_cutoff: ?u6 = null,
    };
    pub const State = struct {
        owner: *Scenario,
        slot: u8,
        bytes: usize,
        marker: u8,
        seed: u32,

        pub fn copyFrom(self: *State, other: *const State) void {
            std.debug.assert(other.owner.copies < other.owner.copy_slots.len);
            other.owner.copy_slots[other.owner.copies] = other.slot;
            other.owner.copies += 1;
            self.* = other.*;
        }
    };
    fn heap(allocator: std.mem.Allocator) *Heap {
        return @ptrCast(@alignCast(allocator.ptr));
    }
    fn wire(allocator: std.mem.Allocator, bytes: usize, kind: Kind, marker: u8) Error![]u8 {
        const memory = try allocator.alloc(u8, bytes);
        for (memory, 0..) |*byte, index| byte.* = marker + @as(u8, @intCast(index % 3));
        heap(allocator).find(memory).?.kind = kind;
        return memory;
    }
    pub fn primary(comptime traced: bool, _: profile.Recorder(traced), allocator: std.mem.Allocator, _: []const u8, scenario: *Scenario, _: ?std.Io, stats: *Stats, _: Options) Error![]u8 {
        scenario.primary_calls += 1;
        scenario.initial_stats[0] = stats.marker;
        scenario.seed_stats[0] = stats.seed;
        try scenario.fail(.initial);
        const memory = try wire(allocator, scenario.config.widths[0], .primary, 1);
        stats.marker = 1;
        stats.bytes = memory.len;
        return memory;
    }
    pub fn prepare(comptime traced: bool, _: profile.Recorder(traced), allocator: std.mem.Allocator, _: []const u8, scenario: *Scenario, _: ?std.Io, stats: *Stats, options: Options, state: *State) Error!profile.CandidateRef {
        const slot = scenario.slotFor(options.literal_context_candidate);
        scenario.prepare_calls[slot] += 1;
        scenario.initial_stats[slot] = stats.marker;
        scenario.seed_stats[slot] = stats.seed;
        scenario.physical_live[slot] = heap(allocator).live(.primary);
        if (slot == 0) scenario.primary_prepare_allocations = heap(allocator).allocation_calls;
        try scenario.fail(switch (slot) {
            0 => .initial,
            1 => .proposal_0,
            2 => .proposal_1,
            3 => .proposal_2,
            else => unreachable,
        });
        state.* = .{ .owner = scenario, .slot = slot, .bytes = scenario.config.widths[slot], .marker = slot + 1, .seed = stats.seed };
        stats.marker = slot + 1;
        stats.bytes = state.bytes;
        return .{ .bytes = state.bytes, .id = slot };
    }
    pub fn proposals(comptime traced: bool, _: profile.Recorder(traced), _: std.mem.Allocator, _: []const u8, scenario: *Scenario) Error!contexts.Proposals {
        scenario.proposal_calls += 1;
        try scenario.fail(.proposals);
        return scenario.proposals;
    }
    pub fn emit(comptime traced: bool, _: profile.Recorder(traced), allocator: std.mem.Allocator, _: []const u8, scenario: *Scenario, _: ?std.Io, stats: *Stats, options: Options, state: *const State, reference: profile.CandidateRef) Error![]u8 {
        scenario.emit_calls += 1;
        scenario.emitted_slot = state.slot;
        scenario.emit_primary_live = heap(allocator).live(.primary);
        scenario.emit_plain_live = heap(allocator).live(.plain);
        if (state.owner != scenario or state.slot != scenario.slotFor(options.literal_context_candidate) or reference.bytes != state.bytes or
            stats.marker != state.marker or stats.seed != state.seed or stats.bytes != state.bytes) return error.InvalidBlockPlan;
        if (scenario.config.fault == .emit) heap(allocator).fail_next = true;
        return wire(allocator, state.bytes, .emitted, state.marker);
    }
    pub fn plain(comptime traced: bool, _: profile.Recorder(traced), allocator: std.mem.Allocator, _: []const u8, scenario: *Scenario, _: ?std.Io, stats: *Stats, _: UserOptions) Error![]u8 {
        scenario.plain_calls += 1;
        scenario.plain_initial = stats.marker;
        if (scenario.config.fault == .plain) heap(allocator).fail_next = true;
        const memory = try wire(allocator, scenario.config.plain, .plain, 9);
        stats.marker = 9;
        stats.bytes = memory.len;
        return memory;
    }
    pub fn free(comptime traced: bool, _: profile.Recorder(traced), allocator: std.mem.Allocator, memory: []u8) void {
        allocator.free(memory);
    }
    pub fn ratioAtMost(bytes: usize, input_bytes: usize, percent: usize) bool {
        return @as(u128, bytes) * 100 <= @as(u128, input_bytes) * percent;
    }
};

const Expected = struct {
    slot: u8 = 0,
    width: usize,
    context: ?contexts.Candidate,
    preparations: [4]usize = @splat(0),
    copy_slots: [3]u8 = @splat(0xff),
    copies: usize = 0,
    plain: bool = false,
    recent: bool = true,
    cutoff: ?u6,
    count_primary: bool = false,
};

fn decisionOracle(scenario: *const Scenario) Expected {
    const candidates = [_]?contexts.Candidate{ scenario.proposals.suffix, scenario.proposals.up_to_16, scenario.proposals.full };
    var expected: Expected = .{ .width = scenario.config.widths[0], .context = scenario.primary_context, .cutoff = null };
    // Every distinct option is visited once. A global seen set, independent of
    // the controller's incumbent/alternate storage, determines deduplication.
    for (candidates, 0..) |candidate, position| {
        if (candidate) |value| {
            var seen = if (scenario.primary_context) |primary| contexts.Candidate.eql(primary, value) else false;
            for (candidates[0..position]) |prior| if (prior) |previous| {
                seen = seen or contexts.Candidate.eql(previous, value);
            };
            if (!seen) {
                expected.count_primary = true;
                const slot = scenario.slotFor(value);
                expected.preparations[slot] = 1;
                if (scenario.config.widths[slot] < expected.width) {
                    expected.slot = slot;
                    expected.width = scenario.config.widths[slot];
                    expected.context = value;
                    expected.copy_slots[expected.copies] = slot;
                    expected.copies += 1;
                }
            }
        }
        if (position == 0) expected.cutoff = if (expected.context) |value| if (value.mode == 2) value.suffixCutoff() else null else null;
    }
    expected.plain = (scenario.config.explicit orelse false) or @as(u128, expected.width) * 100 > @as(u128, scenario.config.input_len) * 80;
    if (expected.plain and scenario.config.plain <= expected.width) {
        expected.width = scenario.config.plain;
        expected.recent = false;
        expected.context = null;
        expected.cutoff = null;
    }
    return expected;
}

fn invoke(comptime Group: type, comptime counted: bool, scenario: *Scenario, heap: *Heap, stats: *Strategy.Stats) Strategy.Error!Strategy.Result {
    const input = [_]u8{0x53} ** 200;
    const encode = if (counted) Group.encodePreparedPrimary else Group.encode;
    return encode(Strategy, false, .{}, heap.allocator(), input[0..scenario.config.input_len], scenario, null, stats, .{ .try_literal_contexts = scenario.config.explicit }, .{ .literal_context_candidate = scenario.primary_context });
}

fn equalCandidate(expected: ?contexts.Candidate, actual: ?contexts.Candidate) !void {
    try std.testing.expectEqualDeep(expected, actual);
}

fn equalResult(expected: Strategy.Result, actual: Strategy.Result) !void {
    try std.testing.expectEqualSlices(u8, expected.encoded, actual.encoded);
    try std.testing.expectEqual(expected.use_recent_distances, actual.use_recent_distances);
    try equalCandidate(expected.literal_context_candidate, actual.literal_context_candidate);
    try std.testing.expectEqual(expected.alternate_literal_context_count, actual.alternate_literal_context_count);
    for (expected.alternate_literal_context_candidates[0..expected.alternate_literal_context_count], actual.alternate_literal_context_candidates[0..actual.alternate_literal_context_count]) |first, second| {
        try std.testing.expectEqualDeep(first, second);
    }
    try std.testing.expectEqual(expected.alternate_plain_literals, actual.alternate_plain_literals);
    try std.testing.expectEqual(expected.literal_split_utf8_cutoff, actual.literal_split_utf8_cutoff);
}

fn successCase(comptime Group: type, config: Config) !void {
    var old = Scenario.init(config);
    var counted = Scenario.init(config);
    const expected = decisionOracle(&old);
    var old_heap: Heap = .{};
    defer old_heap.deinit();
    var counted_heap: Heap = .{};
    defer counted_heap.deinit();
    var old_stats: Strategy.Stats = .{};
    var counted_stats: Strategy.Stats = .{};
    const initial = old_stats;
    const physical = try invoke(Group, false, &old, &old_heap, &old_stats);
    const prepared = try invoke(Group, true, &counted, &counted_heap, &counted_stats);
    try equalResult(physical, prepared);
    try std.testing.expectEqualDeep(old_stats, counted_stats);
    try std.testing.expectEqual(expected.width, prepared.encoded.len);
    try std.testing.expectEqual(expected.recent, prepared.use_recent_distances);
    try equalCandidate(expected.context, prepared.literal_context_candidate);
    try std.testing.expectEqual(expected.cutoff, prepared.literal_split_utf8_cutoff);
    try std.testing.expectEqual(@as(u8, if (expected.recent) expected.slot + 1 else 9), counted_stats.marker);
    try std.testing.expectEqual(initial.seed, counted_stats.seed);
    try std.testing.expectEqual(expected.width, counted_stats.bytes);
    try std.testing.expectEqual(@as(usize, 1), old.primary_calls);
    try std.testing.expectEqual(@as(usize, @intFromBool(!expected.count_primary)), counted.primary_calls);
    try std.testing.expectEqual(@as(usize, 0), old.prepare_calls[0]);
    try std.testing.expectEqual(@as(usize, @intFromBool(expected.count_primary)), counted.prepare_calls[0]);
    try std.testing.expectEqual(if (expected.count_primary) @as(?usize, 0) else null, counted.primary_prepare_allocations);
    try std.testing.expectEqual(@as(usize, 1), counted.proposal_calls);
    for (1..4) |slot| {
        try std.testing.expectEqual(expected.preparations[slot], old.prepare_calls[slot]);
        try std.testing.expectEqual(expected.preparations[slot], counted.prepare_calls[slot]);
        try std.testing.expect(!counted.physical_live[slot]);
    }
    for (0..4) |slot| {
        if (slot == 0 or counted.prepare_calls[slot] != 0) {
            try std.testing.expectEqual(initial.marker, counted.initial_stats[slot]);
            try std.testing.expectEqual(initial.seed, counted.seed_stats[slot]);
            try std.testing.expectEqual(counted.initial_stats[slot], old.initial_stats[slot]);
            try std.testing.expectEqual(counted.seed_stats[slot], old.seed_stats[slot]);
        }
    }
    try std.testing.expectEqual(expected.copies, counted.copies);
    try std.testing.expectEqualSlices(u8, expected.copy_slots[0..expected.copies], counted.copy_slots[0..counted.copies]);
    try std.testing.expectEqual(old.copies, counted.copies);
    try std.testing.expectEqual(@as(usize, @intFromBool(expected.plain)), counted.plain_calls);
    if (expected.plain) try std.testing.expectEqual(initial.marker, counted.plain_initial);
    try std.testing.expectEqual(@as(usize, @intFromBool(expected.recent and expected.count_primary)), counted.emit_calls);
    try std.testing.expectEqual(@as(usize, @intFromBool(expected.recent and expected.slot != 0)), old.emit_calls);
    try std.testing.expectEqual(if (expected.recent and expected.count_primary) @as(?u8, expected.slot) else null, counted.emitted_slot);
    try std.testing.expect(!counted.emit_plain_live and !counted.emit_primary_live);
    try std.testing.expectEqual(@as(usize, 1) + @intFromBool(expected.plain) + @intFromBool(expected.recent and expected.slot != 0), old_heap.allocation_calls);
    try std.testing.expectEqual(@as(usize, @intFromBool(!expected.count_primary)) + @intFromBool(expected.plain) + @intFromBool(expected.recent and expected.count_primary), counted_heap.allocation_calls);
    try std.testing.expectEqualDeep(config, old.config);
    try std.testing.expectEqualDeep(config, counted.config);
    try old_heap.returned(physical.encoded, if (!expected.recent) .plain else if (expected.slot == 0) .primary else .emitted);
    try counted_heap.returned(prepared.encoded, if (!expected.recent) .plain else if (expected.count_primary) .emitted else .primary);
}

fn faultCase(comptime Group: type, config: Config) !void {
    inline for (.{ false, true }) |counted| {
        var scenario = Scenario.init(config);
        var heap: Heap = .{};
        defer heap.deinit();
        var stats: Strategy.Stats = .{};
        const initial = stats;
        const expected_error = if (config.fault == .plain or config.fault == .emit) error.OutOfMemory else config.failure;
        try std.testing.expectError(expected_error, invoke(Group, counted, &scenario, &heap, &stats));
        try std.testing.expectEqualDeep(initial, stats);
        try heap.closed();
        if (config.fault == .proposals) {
            // Early proposal failure occurs before any primary storage is
            // initialized on the new route, including zero-alternate input.
            try std.testing.expectEqual(@as(usize, 1), scenario.proposal_calls);
            try std.testing.expectEqual(@as(usize, if (counted) 0 else 1), heap.allocation_calls);
            try std.testing.expectEqual(@as(usize, if (counted) 0 else 1), scenario.primary_calls);
            try std.testing.expectEqualSlices(usize, &.{ 0, 0, 0, 0 }, &scenario.prepare_calls);
            try std.testing.expectEqual(@as(usize, 0), scenario.emit_calls);
            try std.testing.expectEqual(@as(usize, 0), scenario.plain_calls);
        }
        if (config.fault == .plain or config.fault == .emit) {
            try std.testing.expectEqual(@as(usize, 1), heap.failure_count);
        } else {
            try std.testing.expectEqual(@as(usize, 1), scenario.reached_faults);
        }
    }
}

pub fn check(comptime Group: type) !void {
    const fixed = [_]Config{
        .{},
        .{ .primary = .plain },
        .{ .primary = .other_mode },
        .{ .widths = .{ 70, 70, 80, 90 } },
        .{ .widths = .{ 100, 90, 90, 90 } },
        .{ .widths = .{ 100, 120, 80, 80 } },
        .{ .widths = .{ 100, 120, 110, 70 } },
        .{ .widths = .{ 80, 81, 81, 81 }, .mask = 0 },
        .{ .widths = .{ 81, 90, 90, 90 }, .mask = 0 },
        .{ .widths = .{ 79, 90, 90, 90 }, .mask = 0, .explicit = false },
        .{ .widths = .{ 80, 90, 90, 90 }, .mask = 0, .explicit = true },
        .{ .widths = .{ 80, 90, 90, 90 }, .plain = 80, .mask = 0, .explicit = true },
        .{ .plain = 70, .explicit = true },
        .{ .plain = 69, .explicit = true },
        .{ .duplicates = .repeat_first },
        .{ .duplicates = .primary_all },
        .{ .primary = .duplicate_first },
        .{ .primary = .plain, .mask = 0 },
        .{ .primary = .other_mode, .mask = 6 },
        .{ .primary = .plain, .mask = 6 },
    };
    for (fixed) |config| try successCase(Group, config);
    var random = std.Random.DefaultPrng.init(0x7072_696d_6172_7901);
    for (0..32) |round| {
        var config: Config = .{ .explicit = if (round & 1 == 0) true else null, .mask = @truncate(round), .primary = if (round % 3 == 0) .plain else .utf8 };
        for (&config.widths) |*width| width.* = 60 + random.random().uintLessThan(usize, 61);
        config.plain = 60 + random.random().uintLessThan(usize, 61);
        try successCase(Group, config);
    }
    var failures: usize = 0;
    for ([_]Fault{ .initial, .proposal_0, .proposal_1, .proposal_2, .proposals, .plain, .emit }) |fault| {
        for ([_]error{ SyntheticFailure, OutOfMemory }{ error.SyntheticFailure, error.OutOfMemory }) |failure| {
            try faultCase(Group, .{ .fault = fault, .failure = failure, .explicit = true });
            failures += 1;
        }
    }
    for ([_]error{ SyntheticFailure, OutOfMemory }{ error.SyntheticFailure, error.OutOfMemory }) |failure| {
        try faultCase(Group, .{ .mask = 0, .fault = .proposals, .failure = failure, .explicit = true });
        failures += 1;
    }
    std.debug.print("primary_count success_cases={d} fault_configs={d} paired_paths={d}\n", .{ fixed.len + 32, failures, (fixed.len + 32 + failures) * 2 });
}
