//! Decision and ownership contracts for the real candidate-group controller.
const std = @import("std");
const group = @import("context_candidate_group.zig");
const contexts = @import("literal_context_split.zig");
const profile = @import("quality_profile.zig");

const Kind = enum { unlabelled, primary, scratch, plain, emitted };
const Operation = enum { primary, prepare_0, prepare_1, prepare_2, plain, emit };

/// Addresses are never reused during a scenario. A repeated free remains
/// observable in the ledger instead of crashing in the backing allocator.
const TrackingAllocator = struct {
    const Slot = struct {
        memory: []u8,
        kind: Kind = .unlabelled,
        frees: usize = 0,
        transfers: usize = 0,
    };

    arena: [2048]u8 = undefined,
    cursor: usize = 0,
    slots: [16]Slot = undefined,
    slot_count: usize = 0,
    alloc_calls: usize = 0,
    fail_at: ?usize = null,
    induced_failures: usize = 0,
    invalid_frees: usize = 0,

    fn allocator(self: *TrackingAllocator) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = allocate, .resize = resize, .remap = remap, .free = release } };
    }

    fn allocate(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, _: usize) ?[*]u8 {
        const self: *TrackingAllocator = @ptrCast(@alignCast(raw));
        const call = self.alloc_calls;
        self.alloc_calls += 1;
        if (self.fail_at == call) {
            self.induced_failures += 1;
            return null;
        }
        const origin = @intFromPtr(&self.arena);
        const first = std.mem.alignForward(usize, origin + self.cursor, alignment.toByteUnits()) - origin;
        if (first > self.arena.len or len > self.arena.len - first or self.slot_count == self.slots.len) return null;
        const memory = self.arena[first..][0..len];
        self.slots[self.slot_count] = .{ .memory = memory };
        self.slot_count += 1;
        self.cursor = first + len;
        return memory.ptr;
    }

    fn resize(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) bool {
        return false;
    }

    fn remap(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) ?[*]u8 {
        return null;
    }

    fn release(raw: *anyopaque, memory: []u8, _: std.mem.Alignment, _: usize) void {
        const self: *TrackingAllocator = @ptrCast(@alignCast(raw));
        const slot = self.find(memory) orelse {
            self.invalid_frees += 1;
            return;
        };
        slot.frees += 1;
    }

    fn find(self: *TrackingAllocator, memory: []const u8) ?*Slot {
        for (self.slots[0..self.slot_count]) |*slot|
            if (slot.memory.ptr == memory.ptr and slot.memory.len == memory.len) return slot;
        return null;
    }

    fn label(self: *TrackingAllocator, memory: []u8, kind: Kind) void {
        self.find(memory).?.kind = kind;
    }

    fn live(self: *const TrackingAllocator, kind: Kind) bool {
        for (self.slots[0..self.slot_count]) |slot|
            if (slot.kind == kind and slot.frees == 0) return true;
        return false;
    }

    fn freeCount(self: *const TrackingAllocator, kind: Kind) usize {
        var count: usize = 0;
        for (self.slots[0..self.slot_count]) |slot| {
            if (slot.kind == kind) count += slot.frees;
        }
        return count;
    }

    fn returned(self: *TrackingAllocator, memory: []u8, kind: Kind) !void {
        const selected = self.find(memory) orelse return error.TestUnexpectedResult;
        try std.testing.expectEqual(kind, selected.kind);
        try std.testing.expectEqual(@as(usize, 0), selected.frees);
        try std.testing.expectEqual(@as(usize, 0), selected.transfers);
        for (self.slots[0..self.slot_count]) |*slot| {
            if (slot == selected) continue;
            try std.testing.expectEqual(@as(usize, 1), slot.frees);
            try std.testing.expectEqual(@as(usize, 0), slot.transfers);
        }
        selected.transfers += 1;
        self.allocator().free(memory);
        try self.closed();
    }

    fn closed(self: *const TrackingAllocator) !void {
        try std.testing.expectEqual(@as(usize, 0), self.invalid_frees);
        for (self.slots[0..self.slot_count]) |slot| {
            try std.testing.expectEqual(@as(usize, 1), slot.frees);
            try std.testing.expect(slot.transfers <= 1);
        }
    }
};

const Scenario = struct {
    primary_bytes: usize,
    primary_context: ?contexts.Candidate = contexts.Candidate.suffix(2, 56, 99),
    candidate_bytes: [3]?usize,
    plain_bytes: usize,
    proposals: contexts.Proposals = .{},
    fail: ?Operation = null,
    primary_calls: usize = 0,
    proposal_calls: usize = 0,
    prepare_calls: [3]usize = @splat(0),
    prepare_primary_live: [3]bool = @splat(false),
    prepare_initial_stats: [3]u8 = @splat(0),
    plain_calls: usize = 0,
    plain_initial_stats: u8 = 0,
    emit_calls: usize = 0,
    emitted_slot: ?usize = null,
    emit_primary_live: bool = false,
    emit_plain_live: bool = false,

    fn init(primary_bytes: usize, candidate_bytes: [3]?usize, plain_bytes: usize) Scenario {
        var self: Scenario = .{ .primary_bytes = primary_bytes, .candidate_bytes = candidate_bytes, .plain_bytes = plain_bytes };
        const modes: [3]u2 = .{ 2, 0, 3 };
        const cutoffs: [3]u6 = .{ 24, 40, 52 };
        inline for (.{ "suffix", "up_to_16", "full" }, 0..) |field, index| {
            if (candidate_bytes[index] != null)
                @field(self.proposals, field) = contexts.Candidate.suffix(modes[index], cutoffs[index], 100 + index);
        }
        return self;
    }

    fn arm(self: *const Scenario, heap: *TrackingAllocator, operation: Operation) void {
        if (self.fail == operation) heap.fail_at = heap.alloc_calls;
    }
};

const MockStrategy = struct {
    pub const Error = std.mem.Allocator.Error || error{InvalidBlockPlan};
    pub const Stats = struct { selected: u8 = 7, seed: u8 = 42 };
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
        slot: usize,
        bytes: usize,

        pub fn copyFrom(self: *State, other: *const State) void {
            self.* = other.*;
        }
    };

    fn heap(allocator: std.mem.Allocator) *TrackingAllocator {
        return @ptrCast(@alignCast(allocator.ptr));
    }

    fn wire(allocator: std.mem.Allocator, bytes: usize, kind: Kind, selected: u8) Error![]u8 {
        const memory = try allocator.alloc(u8, bytes);
        @memset(memory, selected);
        heap(allocator).label(memory, kind);
        return memory;
    }

    pub fn primary(comptime traced: bool, _: profile.Recorder(traced), allocator: std.mem.Allocator, _: []const u8, scenario: *Scenario, _: ?std.Io, stats: *Stats, _: Options) Error![]u8 {
        scenario.primary_calls += 1;
        scenario.arm(heap(allocator), .primary);
        const memory = try wire(allocator, scenario.primary_bytes, .primary, 1);
        stats.selected = 1;
        return memory;
    }

    pub fn proposals(comptime traced: bool, _: profile.Recorder(traced), _: std.mem.Allocator, _: []const u8, scenario: *Scenario) Error!contexts.Proposals {
        scenario.proposal_calls += 1;
        return scenario.proposals;
    }

    pub fn prepare(comptime traced: bool, _: profile.Recorder(traced), allocator: std.mem.Allocator, _: []const u8, scenario: *Scenario, _: ?std.Io, stats: *Stats, options: Options, state: *State) Error!profile.CandidateRef {
        const slot: usize = @intCast(options.literal_context_candidate.?.savings_bits - 100);
        scenario.prepare_calls[slot] += 1;
        scenario.prepare_primary_live[slot] = heap(allocator).live(.primary);
        scenario.prepare_initial_stats[slot] = stats.selected;
        const operation: Operation = switch (slot) {
            0 => .prepare_0,
            1 => .prepare_1,
            2 => .prepare_2,
            else => return error.InvalidBlockPlan,
        };
        scenario.arm(heap(allocator), operation);
        // Only tiny temporary preparation storage is materialized. The group
        // must compare CandidateRefs and emit the selected state once at most.
        const temporary = try wire(allocator, 1, .scratch, 0);
        defer allocator.free(temporary);
        const bytes = scenario.candidate_bytes[slot].?;
        state.* = .{ .slot = slot, .bytes = bytes };
        stats.selected = @intCast(2 + slot);
        return .{ .bytes = bytes };
    }

    pub fn emit(comptime traced: bool, _: profile.Recorder(traced), allocator: std.mem.Allocator, _: []const u8, scenario: *Scenario, _: ?std.Io, stats: *Stats, options: Options, state: *const State, reference: profile.CandidateRef) Error![]u8 {
        scenario.emit_calls += 1;
        scenario.emitted_slot = state.slot;
        scenario.emit_primary_live = heap(allocator).live(.primary);
        scenario.emit_plain_live = heap(allocator).live(.plain);
        if (reference.bytes != state.bytes or options.literal_context_candidate.?.savings_bits != 100 + state.slot or stats.selected != 2 + state.slot)
            return error.InvalidBlockPlan;
        scenario.arm(heap(allocator), .emit);
        return wire(allocator, state.bytes, .emitted, stats.selected);
    }

    pub fn plain(comptime traced: bool, _: profile.Recorder(traced), allocator: std.mem.Allocator, _: []const u8, scenario: *Scenario, _: ?std.Io, stats: *Stats, _: UserOptions) Error![]u8 {
        scenario.plain_calls += 1;
        scenario.plain_initial_stats = stats.selected;
        scenario.arm(heap(allocator), .plain);
        const memory = try wire(allocator, scenario.plain_bytes, .plain, 9);
        stats.selected = 9;
        return memory;
    }

    pub fn free(comptime traced: bool, _: profile.Recorder(traced), allocator: std.mem.Allocator, memory: []u8) void {
        allocator.free(memory);
    }

    pub fn ratioAtMost(bytes: usize, input_bytes: usize, percent: usize) bool {
        return @as(u128, bytes) * 100 <= @as(u128, input_bytes) * percent;
    }
};

fn invoke(scenario: *Scenario, heap: *TrackingAllocator, input_bytes: usize, explicit: ?bool, stats: *MockStrategy.Stats) MockStrategy.Error!MockStrategy.Result {
    const input: [1000]u8 = @splat(0);
    return group.encode(MockStrategy, false, .{}, heap.allocator(), input[0..input_bytes], scenario, null, stats, .{ .try_literal_contexts = explicit }, .{ .literal_context_candidate = scenario.primary_context });
}

pub fn run() !void {
    try incumbentAndSnapshot();
    try onlyFinalWinnerEmits();
    try ratioAndExplicitPlain();
    try plainEqualityWins();
    try failures();
}

fn incumbentAndSnapshot() !void {
    var heap: TrackingAllocator = .{};
    var scenario = Scenario.init(100, .{ 100, 90, 90 }, 150);
    var stats: MockStrategy.Stats = .{};
    const result = try invoke(&scenario, &heap, 200, null, &stats);
    try std.testing.expectEqualSlices(usize, &.{ 1, 1, 1 }, &scenario.prepare_calls);
    try std.testing.expectEqualSlices(bool, &.{ true, true, false }, &scenario.prepare_primary_live);
    try std.testing.expectEqualSlices(u8, &.{ 7, 7, 7 }, &scenario.prepare_initial_stats);
    try std.testing.expectEqual(@as(u8, 3), stats.selected);
    try std.testing.expectEqual(@as(u8, 42), stats.seed);
    try std.testing.expectEqual(@as(?usize, 1), scenario.emitted_slot);
    try std.testing.expect(contexts.Candidate.eql(scenario.proposals.up_to_16.?, result.literal_context_candidate.?));
    try std.testing.expectEqual(@as(?u6, 56), result.literal_split_utf8_cutoff);
    try std.testing.expectEqual(@as(usize, 1), heap.freeCount(.primary));
    try std.testing.expectEqual(@as(usize, 0), scenario.plain_calls);
    try std.testing.expectEqual(@as(usize, 1), scenario.emit_calls);
    try heap.returned(result.encoded, .emitted);

    heap = .{};
    scenario = Scenario.init(100, .{ 100, 120, 100 }, 150);
    stats = .{};
    const tied = try invoke(&scenario, &heap, 200, false, &stats);
    try std.testing.expectEqual(@as(u8, 1), stats.selected);
    try std.testing.expectEqualSlices(bool, &.{ true, true, true }, &scenario.prepare_primary_live);
    try std.testing.expectEqual(@as(usize, 0), heap.freeCount(.primary));
    try std.testing.expectEqual(@as(usize, 0), scenario.emit_calls);
    try std.testing.expectEqual(@as(usize, 0), scenario.plain_calls);
    try heap.returned(tied.encoded, .primary);
}

fn onlyFinalWinnerEmits() !void {
    for ([_]bool{ false, true }) |plain_primary| {
        var heap: TrackingAllocator = .{};
        var scenario = Scenario.init(100, .{ 90, 80, 70 }, 120);
        if (plain_primary) scenario.primary_context = null;
        var stats: MockStrategy.Stats = .{};
        const result = try invoke(&scenario, &heap, 100, null, &stats);
        try std.testing.expectEqual(@as(usize, 1), scenario.emit_calls);
        try std.testing.expectEqual(@as(?usize, 2), scenario.emitted_slot);
        try std.testing.expectEqual(@as(u8, 4), stats.selected);
        try std.testing.expectEqual(@as(usize, 70), result.encoded.len);
        try std.testing.expectEqual(@as(?u6, 24), result.literal_split_utf8_cutoff);
        try std.testing.expectEqual(@as(u2, if (plain_primary) 2 else 3), result.alternate_literal_context_count);
        try std.testing.expectEqual(plain_primary, result.alternate_plain_literals);
        try std.testing.expectEqualSlices(bool, &.{ true, false, false }, &scenario.prepare_primary_live);
        try std.testing.expectEqual(@as(usize, 0), scenario.plain_calls);
        try heap.returned(result.encoded, .emitted);
    }
}

fn ratioAndExplicitPlain() !void {
    var heap: TrackingAllocator = .{};
    var scenario = Scenario.init(80, .{ null, null, null }, 100);
    var stats: MockStrategy.Stats = .{};
    const equality = try invoke(&scenario, &heap, 100, null, &stats);
    try std.testing.expectEqual(@as(usize, 0), scenario.plain_calls);
    try std.testing.expectEqual(@as(usize, 0), scenario.emit_calls);
    try std.testing.expect(equality.use_recent_distances);
    try heap.returned(equality.encoded, .primary);

    heap = .{};
    scenario = Scenario.init(80, .{ null, null, null }, 100);
    stats = .{};
    const explicit = try invoke(&scenario, &heap, 100, true, &stats);
    try std.testing.expectEqual(@as(usize, 1), scenario.plain_calls);
    try std.testing.expectEqual(@as(u8, 7), scenario.plain_initial_stats);
    try std.testing.expectEqual(@as(usize, 1), heap.freeCount(.plain));
    try std.testing.expect(explicit.use_recent_distances);
    try heap.returned(explicit.encoded, .primary);

    heap = .{};
    scenario = Scenario.init(81, .{ null, null, null }, 100);
    stats = .{};
    const above = try invoke(&scenario, &heap, 100, false, &stats);
    try std.testing.expectEqual(@as(usize, 1), scenario.plain_calls);
    try heap.returned(above.encoded, .primary);

    heap = .{};
    scenario = Scenario.init(100, .{ 80, null, null }, 90);
    stats = .{};
    const prepared = try invoke(&scenario, &heap, 100, true, &stats);
    try std.testing.expectEqual(@as(usize, 1), scenario.plain_calls);
    try std.testing.expectEqual(@as(usize, 1), scenario.emit_calls);
    try std.testing.expect(!scenario.emit_plain_live);
    try std.testing.expect(prepared.use_recent_distances);
    try heap.returned(prepared.encoded, .emitted);
}

fn plainEqualityWins() !void {
    for ([_]bool{ false, true }) |prepared_winner| {
        var heap: TrackingAllocator = .{};
        var scenario = Scenario.init(if (prepared_winner) 100 else 80, .{ if (prepared_winner) 80 else null, null, null }, 80);
        var stats: MockStrategy.Stats = .{};
        const result = try invoke(&scenario, &heap, 100, true, &stats);
        try std.testing.expect(!result.use_recent_distances);
        try std.testing.expect(result.literal_context_candidate == null);
        try std.testing.expectEqual(@as(u8, 9), stats.selected);
        try std.testing.expectEqual(@as(usize, 1), scenario.plain_calls);
        try std.testing.expectEqual(@as(usize, 0), scenario.emit_calls);
        try std.testing.expectEqual(@as(usize, 1), heap.freeCount(.primary));
        try heap.returned(result.encoded, .plain);
    }
}

fn failures() !void {
    for ([_]Operation{ .primary, .prepare_0, .prepare_1, .prepare_2 }) |operation| {
        var heap: TrackingAllocator = .{};
        var scenario = Scenario.init(100, .{ 90, 85, 80 }, 120);
        scenario.fail = operation;
        var stats: MockStrategy.Stats = .{};
        try std.testing.expectError(error.OutOfMemory, invoke(&scenario, &heap, 100, false, &stats));
        try std.testing.expectEqual(@as(usize, 1), heap.induced_failures);
        try std.testing.expectEqual(@as(usize, 0), scenario.emit_calls);
        try std.testing.expectEqual(@as(usize, 0), scenario.plain_calls);
        try std.testing.expectEqual(@as(u8, 7), stats.selected);
        try heap.closed();
    }
    for ([_]bool{ false, true }) |prepared_winner| {
        var heap: TrackingAllocator = .{};
        var scenario = Scenario.init(100, .{ if (prepared_winner) 80 else null, null, null }, 120);
        scenario.fail = .plain;
        var stats: MockStrategy.Stats = .{};
        try std.testing.expectError(error.OutOfMemory, invoke(&scenario, &heap, 100, true, &stats));
        try std.testing.expectEqual(@as(usize, 1), heap.induced_failures);
        try std.testing.expectEqual(@as(usize, 1), scenario.plain_calls);
        try std.testing.expectEqual(@as(usize, 0), scenario.emit_calls);
        try heap.closed();
    }
    for ([_]bool{ false, true }) |with_plain| {
        var heap: TrackingAllocator = .{};
        var scenario = Scenario.init(100, .{ 80, null, null }, 90);
        scenario.fail = .emit;
        var stats: MockStrategy.Stats = .{};
        try std.testing.expectError(error.OutOfMemory, invoke(&scenario, &heap, 100, with_plain, &stats));
        try std.testing.expectEqual(@as(usize, 1), heap.induced_failures);
        try std.testing.expectEqual(@as(usize, 1), scenario.emit_calls);
        try std.testing.expectEqual(@as(usize, @intFromBool(with_plain)), scenario.plain_calls);
        try std.testing.expect(!scenario.emit_primary_live);
        try std.testing.expect(!scenario.emit_plain_live);
        try std.testing.expectEqual(@as(usize, 1), heap.freeCount(.primary));
        try std.testing.expectEqual(@as(usize, @intFromBool(with_plain)), heap.freeCount(.plain));
        // In particular, the explicit baseline has already been freed before
        // emit fails. Its errdefer must not release the same wire a second time.
        try heap.closed();
    }
}
