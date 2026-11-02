//! Strict wire selection and borrowed/owned lifetime contracts. Selection is
//! checked against an independent earliest-minimum oracle, including empty wire.
const std = @import("std");
const profile = @import("quality_profile.zig");

const Stats = struct { id: u8, seed: u32 = 0xa1b2_c3d4, bytes: usize };
const baseline_id: u8 = 0xff;

const Ledger = struct {
    const Slot = struct {
        backing: []u8,
        visible_len: usize,
        alignment: std.mem.Alignment,
        releases: usize = 0,
        transfers: usize = 0,
    };
    slots: [24]Slot = undefined,
    len: usize = 0,
    requests: usize = 0,
    failed_requests: usize = 0,
    fail_at: ?usize = null,
    invalid_releases: usize = 0,
    callback_count: usize = 0,

    fn allocator(self: *Ledger) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = allocate, .resize = resize, .remap = remap, .free = free } };
    }
    fn allocate(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        const request = self.requests;
        self.requests += 1;
        if (self.fail_at == request) {
            self.failed_requests += 1;
            return null;
        }
        if (self.len == self.slots.len) return null;
        const pointer = std.testing.allocator.rawAlloc(len, alignment, ra) orelse return null;
        self.slots[self.len] = .{ .backing = pointer[0..len], .visible_len = len, .alignment = alignment };
        self.len += 1;
        return pointer;
    }
    fn resize(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) bool {
        return false;
    }
    fn remap(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) ?[*]u8 {
        return null;
    }
    fn free(raw: *anyopaque, memory: []u8, _: std.mem.Alignment, _: usize) void {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        const slot = self.find(memory) orelse {
            self.invalid_releases += 1;
            return;
        };
        slot.releases += 1;
    }
    fn find(self: *Ledger, memory: []const u8) ?*Slot {
        for (self.slots[0..self.len]) |*slot| {
            if (slot.backing.ptr == memory.ptr and slot.visible_len == memory.len) return slot;
        }
        return null;
    }
    fn candidate(self: *Ledger, width: usize, id: u8) ![]u8 {
        // Give zero-length wires distinct real backing storage. Both candidate
        // consumption and caller transfer remain visible to the release hook.
        const backing = try self.allocator().alloc(u8, @max(width, 1));
        self.slots[self.len - 1].visible_len = width;
        for (backing, 0..) |*byte, index| byte.* = id + @as(u8, @intCast(index % 3));
        return backing[0..width];
    }
    fn releaseWire(self: *Ledger, memory: []const u8) void {
        self.callback_count += 1;
        free(self, @constCast(memory), .@"1", @returnAddress());
    }
    fn transfer(self: *Ledger, memory: []u8) !void {
        const slot = self.find(memory) orelse return error.TestUnexpectedResult;
        try std.testing.expectEqual(@as(usize, 0), slot.releases);
        try std.testing.expectEqual(@as(usize, 0), slot.transfers);
        slot.transfers += 1;
    }
    fn expectFrontier(self: *Ledger, retained: ?[]const u8) !void {
        try std.testing.expectEqual(@as(usize, 0), self.invalid_releases);
        for (self.slots[0..self.len]) |slot| {
            const live = if (retained) |wire| slot.backing.ptr == wire.ptr else false;
            try std.testing.expectEqual(@as(usize, if (live) 0 else 1), slot.releases);
            try std.testing.expectEqual(@as(usize, 0), slot.transfers);
        }
    }
    fn closed(self: *const Ledger) !void {
        try std.testing.expectEqual(@as(usize, 0), self.invalid_releases);
        for (self.slots[0..self.len]) |slot| {
            try std.testing.expectEqual(@as(usize, 1), slot.releases);
            try std.testing.expect(slot.transfers <= 1);
        }
    }
    fn deinit(self: *Ledger) void {
        // Physical addresses stay unique until the whole scenario ends, so
        // repeated releases are observable without corrupting the backing heap.
        for (self.slots[0..self.len]) |slot| std.testing.allocator.rawFree(slot.backing, slot.alignment, @returnAddress());
    }
};

fn release(comptime traced: bool, trace: profile.Recorder(traced), allocator: std.mem.Allocator, memory: anytype) void {
    const ledger: *Ledger = @ptrCast(@alignCast(allocator.ptr));
    trace.forgetWire(memory);
    ledger.releaseWire(memory);
}

fn minimum(baseline: usize, widths: []const usize) ?usize {
    var best = baseline;
    var selected: ?usize = null;
    for (widths, 0..) |width, index| {
        if (width < best) {
            best = width;
            selected = index;
        }
    }
    return selected;
}

fn expectWinner(owner: anytype, baseline: []const u8, baseline_stats: Stats, widths: []const usize, wires: []const []u8) !void {
    const winner = minimum(baseline.len, widths);
    const expected = if (winner) |index| @as([]const u8, wires[index]) else baseline;
    try std.testing.expect(owner.current().ptr == expected.ptr);
    try std.testing.expectEqualSlices(u8, expected, owner.current());
    try std.testing.expectEqualDeep(if (winner) |index| Stats{ .id = @intCast(index + 1), .bytes = widths[index] } else baseline_stats, owner.stats);
}

fn selectionCase(comptime Module: type, baseline_width: usize, widths: []const usize, take: bool) !void {
    var baseline_storage: [128]u8 = @splat(0xa7);
    const baseline_before = baseline_storage;
    const baseline = baseline_storage[0..baseline_width];
    const baseline_stats: Stats = .{ .id = baseline_id, .bytes = baseline_width };
    const stats_before = baseline_stats;
    var ledger: Ledger = .{};
    defer ledger.deinit();
    var owner = Module.Owner(Stats).init(baseline, baseline_stats);
    var wires: [24][]u8 = undefined;
    try expectWinner(&owner, baseline, baseline_stats, &.{}, wires[0..0]);
    try std.testing.expect(owner.take() == null);
    for (widths, 0..) |width, index| {
        wires[index] = try ledger.candidate(width, @intCast(index + 1));
        const input_before = try std.testing.allocator.dupe(u8, wires[index]);
        defer std.testing.allocator.free(input_before);
        const stats: Stats = .{ .id = @intCast(index + 1), .bytes = width };
        owner.consider(false, .{}, ledger.allocator(), wires[index], stats, release);
        try expectWinner(&owner, baseline, baseline_stats, widths[0 .. index + 1], wires[0 .. index + 1]);
        const winner = minimum(baseline_width, widths[0 .. index + 1]);
        try ledger.expectFrontier(if (winner) |selected| wires[selected] else null);
        try std.testing.expectEqualSlices(u8, input_before, wires[index]);
        try std.testing.expectEqualSlices(u8, &baseline_before, &baseline_storage);
    }
    const winner = minimum(baseline_width, widths);
    if (take) {
        const selected = owner.take();
        try std.testing.expectEqual(winner == null, selected == null);
        try std.testing.expect(owner.take() == null);
        owner.deinit(false, .{}, ledger.allocator(), release);
        owner.deinit(false, .{}, ledger.allocator(), release);
        try std.testing.expect(owner.current().ptr == baseline.ptr);
        if (selected) |owned| {
            try std.testing.expect(owned.wire.ptr == wires[winner.?].ptr);
            try std.testing.expectEqualDeep(Stats{ .id = @intCast(winner.? + 1), .bytes = widths[winner.?] }, owned.stats);
            try ledger.transfer(owned.wire);
            release(false, .{}, ledger.allocator(), owned.wire);
        }
    } else {
        owner.deinit(false, .{}, ledger.allocator(), release);
        try std.testing.expect(owner.take() == null);
        owner.deinit(false, .{}, ledger.allocator(), release);
        try std.testing.expect(owner.current().ptr == baseline.ptr);
    }
    try ledger.closed();
    try std.testing.expectEqual(widths.len, ledger.callback_count);
    try std.testing.expectEqual(widths.len, ledger.requests);
    try std.testing.expectEqualSlices(u8, &baseline_before, &baseline_storage);
    try std.testing.expectEqualDeep(stats_before, baseline_stats);
}

fn failureCase(comptime Module: type, baseline_width: usize, widths: []const usize, fail_at: usize, synthetic: bool) !void {
    var baseline_storage: [128]u8 = @splat(0xa7);
    const before = baseline_storage;
    const baseline = baseline_storage[0..baseline_width];
    var ledger: Ledger = .{ .fail_at = if (synthetic) null else fail_at };
    defer ledger.deinit();
    var owner = Module.Owner(Stats).init(baseline, .{ .id = baseline_id, .bytes = baseline_width });
    const Run = struct {
        fn produce(selection: anytype, heap: *Ledger, requested: []const usize, frontier: usize, inject_error: bool) !void {
            for (requested, 0..) |width, index| {
                if (inject_error and index == frontier) return error.SyntheticFailure;
                const candidate = try heap.candidate(width, @intCast(index + 1));
                selection.consider(false, .{}, heap.allocator(), candidate, Stats{ .id = @intCast(index + 1), .bytes = width }, release);
            }
        }
    };
    try std.testing.expectError(if (synthetic) error.SyntheticFailure else error.OutOfMemory, Run.produce(&owner, &ledger, widths, fail_at, synthetic));
    const selected = minimum(baseline_width, widths[0..fail_at]);
    const retained: ?[]const u8 = if (selected) |index| ledger.slots[index].backing[0..widths[index]] else null;
    try ledger.expectFrontier(retained);
    if (retained) |wire| try std.testing.expect(owner.current().ptr == wire.ptr) else try std.testing.expect(owner.current().ptr == baseline.ptr);
    try std.testing.expectEqualDeep(if (selected) |index| Stats{ .id = @intCast(index + 1), .bytes = widths[index] } else Stats{ .id = baseline_id, .bytes = baseline_width }, owner.stats);
    owner.deinit(false, .{}, ledger.allocator(), release);
    owner.deinit(false, .{}, ledger.allocator(), release);
    try std.testing.expect(owner.take() == null);
    try ledger.closed();
    try std.testing.expectEqual(fail_at, ledger.callback_count);
    try std.testing.expectEqual(@as(usize, if (synthetic) 0 else 1), ledger.failed_requests);
    try std.testing.expectEqualSlices(u8, &before, &baseline_storage);
}

fn tracedCase(comptime Module: type) !void {
    const baseline = [_]u8{0xa7} ** 128;
    var diagnostics: profile.Profile = .{};
    const trace: profile.Active = .{ .io = std.testing.io, .profile = &diagnostics };
    var baseline_scope = trace.begin(.wire, 128, 0);
    baseline_scope.wire(&baseline);
    baseline_scope.finish();
    var ledger: Ledger = .{};
    defer ledger.deinit();
    var owner = Module.Owner(Stats).init(&baseline, .{ .id = baseline_id, .bytes = baseline.len });
    const widths = [_]usize{ 90, 90, 80 };
    var expected_incumbent: usize = 0;
    for (widths, 0..) |width, index| {
        const candidate = try ledger.candidate(width, @intCast(index + 1));
        var scope = trace.begin(.wire, 128, 0);
        scope.wire(candidate);
        scope.finish();
        const candidate_id = diagnostics.event_count - 1;
        owner.consider(true, trace, ledger.allocator(), candidate, Stats{ .id = @intCast(index + 1), .bytes = width }, release);
        const event = diagnostics.events[diagnostics.event_count - 1];
        try std.testing.expectEqual(profile.Stage.selection, event.stage);
        try std.testing.expectEqual(@as(?usize, candidate_id), event.candidate_event_id);
        try std.testing.expectEqual(@as(?usize, expected_incumbent), event.incumbent_event_id);
        try std.testing.expectEqual(@as(?bool, index != 1), event.accepted);
        if (index != 1) expected_incumbent = candidate_id;
    }
    const selected = owner.take().?;
    try std.testing.expectEqual(@as(u8, 3), selected.stats.id);
    try std.testing.expectEqual(@as(usize, 80), selected.wire.len);
    trace.returned(selected.wire);
    try std.testing.expectEqual(@as(?usize, expected_incumbent), diagnostics.returned_wire_event_id);
    try std.testing.expect(diagnostics.wire_live[0]);
    try ledger.transfer(selected.wire);
    release(true, trace, ledger.allocator(), selected.wire);
    owner.deinit(true, trace, ledger.allocator(), release);
    try ledger.closed();
    try std.testing.expect(diagnostics.wire_live[0]);
}

pub fn check(comptime Module: type) !void {
    const patterns = [_][]const usize{
        &.{},                        &.{ 129, 130, 200 },   &.{ 128, 128, 128 }, &.{ 100, 90, 80, 70 },
        &.{ 100, 120, 90, 110, 80 }, &.{ 90, 90, 100, 90 }, &.{ 1, 1, 0, 0 },    &.{ 0, 0 },
    };
    var selections: usize = 0;
    for ([_]usize{ 0, 1, 128 }) |baseline| {
        for (patterns) |widths| {
            for ([_]bool{ false, true }) |take| {
                try selectionCase(Module, baseline, widths, take);
                selections += 1;
            }
        }
    }
    var random = std.Random.DefaultPrng.init(0x7769_7265_6f77_6e01);
    var widths: [12]usize = undefined;
    for (0..16) |round| {
        for (&widths) |*width| width.* = random.random().uintLessThan(usize, 160);
        try selectionCase(Module, 128, &widths, round & 1 == 0);
        selections += 1;
    }
    const failing_widths = [_]usize{ 140, 100, 120, 90, 90, 80 };
    var failures: usize = 0;
    for (0..failing_widths.len) |frontier| {
        for ([_]bool{ false, true }) |synthetic| {
            try failureCase(Module, 128, &failing_widths, frontier, synthetic);
            failures += 1;
        }
    }
    try tracedCase(Module);
    std.debug.print("entropy_selection selection_cases={d} failure_frontiers={d} traced_cases=1\n", .{ selections, failures });
}
