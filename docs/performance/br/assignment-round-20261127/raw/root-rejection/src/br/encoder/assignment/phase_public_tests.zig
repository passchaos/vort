//! Same-source public grouped-u64 versus tile assignment contracts.
const std = @import("std");
const contexts = @import("../literal_context_split.zig");
const a = std.testing.allocator;
const Fixture = struct { name: []const u8, input: []const u8, wire: []const u8 };
const fixtures = [_]Fixture{
    .{ .name = "mozilla", .input = @embedFile("../literal_model/testdata/mozilla-64k.plain"), .wire = @embedFile("../literal_model/testdata/mozilla-64k.br") },
    .{ .name = "xray", .input = @embedFile("../literal_model/testdata/xray-64k.plain"), .wire = @embedFile("../literal_model/testdata/xray-64k.br") },
    .{ .name = "nci", .input = @embedFile("../literal_model/testdata/nci-64k.plain"), .wire = @embedFile("../literal_model/testdata/nci-64k.br") },
    .{ .name = "xml", .input = @embedFile("../literal_model/testdata/xml-64k.plain"), .wire = @embedFile("../literal_model/testdata/xml-64k.br") },
};

fn encode(comptime Br: type, allocator: std.mem.Allocator, input: []const u8, options: Br.PlannedEncodeOptions, disabled: bool) ![]u8 {
    const previous = contexts.test_disable_assignment_phase;
    contexts.test_disable_assignment_phase = disabled;
    defer contexts.test_disable_assignment_phase = previous;
    return Br.encodePlannedStreamWithOptionsAlloc(allocator, input, options);
}

fn profileEncode(comptime Br: type, input: []const u8, options: Br.PlannedEncodeOptions, profile: *Br.QualityQ8Profile, disabled: bool) ![]u8 {
    const previous = contexts.test_disable_assignment_phase;
    contexts.test_disable_assignment_phase = disabled;
    defer contexts.test_disable_assignment_phase = previous;
    return Br.benchmarkQualityProfileAlloc(a, input, std.testing.io, options, profile);
}

pub fn run(comptime Br: type) !void {
    const previous = contexts.test_disable_assignment_phase;
    var narrow: usize = 0;
    for (fixtures, 0..) |fixture, i| {
        try std.testing.expectEqual(@as(usize, 65536), fixture.input.len);
        try wirePair(Br, fixture.name, fixture.input, .{ .quality = 8, .window_bits = 16 }, fixture.wire);
        const count = try profilePair(Br, fixture.name, fixture.input, .{ .quality = 8, .window_bits = 16 }, fixture.wire);
        if (i < 2) narrow += count;
    }
    try std.testing.expect(narrow > 0);
    for ([_]usize{ 1, 0, 3, 1 }) |i|
        try wirePair(Br, "repeated-after-other-input", fixtures[i].input, .{ .quality = 8, .window_bits = 16 }, fixtures[i].wire);
    try otherCallers(Br);
    // Every screen completes before any quota or injected backing failure.
    var peaks: [2]usize = undefined;
    var sites: [2][3]usize = undefined;
    for (fixtures[0..2], 0..) |fixture, i| {
        const screen = try resources(Br, fixture);
        peaks[i] = screen.peak;
        sites[i] = screen.sites;
    }
    for (fixtures[0..2], 0..) |fixture, i| {
        try quota(Br, fixture, peaks[i]);
        try backingFailures(Br, fixture, sites[i]);
    }
    try std.testing.expectEqual(previous, contexts.test_disable_assignment_phase);
}

fn decode(comptime Br: type, input: []const u8, wire: []const u8) !void {
    const plain = try Br.decodeStreamAlloc(a, wire);
    defer a.free(plain);
    try std.testing.expectEqualSlices(u8, input, plain);
}

fn wirePair(comptime Br: type, label: []const u8, input: []const u8, options: Br.PlannedEncodeOptions, gold: ?[]const u8) !void {
    const old = try encode(Br, a, input, options, true);
    defer a.free(old);
    const tile = try encode(Br, a, input, options, false);
    defer a.free(tile);
    try std.testing.expectEqualSlices(u8, old, tile);
    if (gold) |wire| try std.testing.expectEqualSlices(u8, wire, tile);
    try decode(Br, input, old);
    try decode(Br, input, tile);
    std.debug.print("assignment_public stage=wire case={s} input_bytes={d} wire_bytes={d}\n", .{ label, input.len, tile.len });
}

fn classField(comptime name: []const u8) bool {
    return std.mem.eql(u8, name, "assignment_narrow_contexts") or std.mem.eql(u8, name, "assignment_wide_contexts") or std.mem.eql(u8, name, "assignment_light_contexts");
}

fn semanticEqual(old: anytype, tile: @TypeOf(old)) !void {
    inline for (std.meta.fields(@TypeOf(old))) |field| {
        if (comptime !std.mem.endsWith(u8, field.name, "_ns") and !classField(field.name))
            try std.testing.expectEqualDeep(@field(old, field.name), @field(tile, field.name));
    }
}

fn zero(value: anytype) !void {
    switch (@typeInfo(@TypeOf(value))) {
        .int => try std.testing.expectEqual(@as(@TypeOf(value), 0), value),
        .array => for (value) |element| try zero(element),
        .@"struct" => inline for (std.meta.fields(@TypeOf(value))) |field| try zero(@field(value, field.name)),
        else => @compileError("unexpected proposal work counter type"),
    }
}

fn retainedShape(comptime name: []const u8) bool {
    inline for (.{ "iterations", "input_bytes", "literal_count", "proposal_reuses", "active_symbols", "suffix_tree_count", "suffix_mode", "suffix_savings_bits", "up_to_16_tree_count", "up_to_16_mode", "up_to_16_savings_bits", "full_tree_count", "full_mode", "full_savings_bits" }) |field|
        if (comptime std.mem.eql(u8, name, field)) return true;
    return false;
}

fn cachedZeroWork(profile: contexts.Profile) !void {
    @setEvalBranchQuota(20000);
    if (profile.proposal_reuses == 0) return;
    try std.testing.expectEqual(@as(usize, 1), profile.proposal_reuses);
    inline for (std.meta.fields(contexts.Profile)) |field| {
        if (comptime !std.mem.endsWith(u8, field.name, "_ns") and !retainedShape(field.name))
            try zero(@field(profile, field.name));
    }
}

fn profilePair(comptime Br: type, label: []const u8, input: []const u8, options: Br.PlannedEncodeOptions, gold: ?[]const u8) !usize {
    var old: Br.QualityQ8Profile = .{};
    var tile: Br.QualityQ8Profile = .{};
    const old_wire = try profileEncode(Br, input, options, &old, true);
    defer a.free(old_wire);
    const tile_wire = try profileEncode(Br, input, options, &tile, false);
    defer a.free(tile_wire);
    try std.testing.expectEqualSlices(u8, old_wire, tile_wire);
    if (gold) |wire| try std.testing.expectEqualSlices(u8, wire, tile_wire);
    try decode(Br, input, tile_wire);
    inline for (.{ "event_count", "events_total", "events_truncated", "wire_attempts", "evaluation_attempts", "parameter_pairs", "parameter_counted_candidates", "parameter_physical_emits", "parameter_skipped_pair_emits", "wire_attempt_coverage_complete", "returned_wire_bytes", "returned_wire_event_id", "context_detail_count", "context_details_truncated" }) |field|
        try std.testing.expectEqualDeep(@field(old, field), @field(tile, field));
    try std.testing.expectEqualStrings("", old.error_name);
    try std.testing.expectEqualStrings("", tile.error_name);
    for (old.recordedEvents(), tile.recordedEvents()) |left, right| try semanticEqual(left, right);
    var narrow: usize = 0;
    var cache_hits: usize = 0;
    for (old.recordedContextDetails(), tile.recordedContextDetails()) |left, right| {
        try std.testing.expectEqualDeep(left.event_id, right.event_id);
        try std.testing.expectEqualDeep(left.origin, right.origin);
        try std.testing.expectEqualDeep(left.variant, right.variant);
        try std.testing.expectEqualDeep(left.command_count, right.command_count);
        try semanticEqual(left.profile, right.profile);
        const stats = right.profile;
        try std.testing.expectEqual(@as(usize, 0), left.profile.assignment_narrow_contexts + left.profile.assignment_wide_contexts + left.profile.assignment_light_contexts);
        try std.testing.expectEqual(stats.assignment_contexts, stats.assignment_narrow_contexts + stats.assignment_wide_contexts + stats.assignment_light_contexts);
        try cachedZeroWork(left.profile);
        try cachedZeroWork(stats);
        narrow += stats.assignment_narrow_contexts;
        cache_hits += stats.proposal_reuses;
        std.debug.print("assignment_public stage=context case={s} contexts={d} comparisons={d} rounds={d} narrow={d} wide={d} light={d} proposal_reuses={d} shape={d}/{d}/{d}\n", .{
            label, stats.assignment_contexts, stats.assignment_comparisons, stats.cluster_rounds, stats.assignment_narrow_contexts, stats.assignment_wide_contexts, stats.assignment_light_contexts, stats.proposal_reuses, stats.suffix_tree_count, stats.up_to_16_tree_count, stats.full_tree_count,
        });
    }
    std.debug.print("assignment_public stage=profile case={s} narrow={d} actual_proposal_cache_hits={d} times_not_compared=true\n", .{ label, narrow, cache_hits });
    return narrow;
}

fn otherCallers(comptime Br: type) !void {
    const input = fixtures[0].input[0..4096];
    for ([_]u4{ 4, 6, 10, 11 }) |quality| {
        var options: Br.PlannedEncodeOptions = .{ .quality = quality, .window_bits = 16 };
        if (quality >= 10) options.command_state_max_input_kib = 8;
        try wirePair(Br, "other-quality-pruned-caller", input, options, null);
        _ = try profilePair(Br, "other-quality-pruned-caller", input, options, null);
    }
    try wirePair(Br, "ratio", input, .{ .level = .ratio, .window_bits = 16 }, null);
    for ([_]u5{ 10, 16, 22 }) |window|
        try wirePair(Br, "window", input, .{ .quality = 8, .window_bits = window }, null);
    try wirePair(Br, "metadata", input, .{ .quality = 8, .window_bits = 16, .metadata = "assignment phase" }, null);
    const repetitive = [_]u8{'R'} ** 4096;
    try wirePair(Br, "repetitive", &repetitive, .{ .quality = 8, .window_bits = 16 }, null);
    var opaque_bytes: [4096]u8 = undefined;
    var state: u32 = 0x924a11ce;
    for (&opaque_bytes) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }
    try wirePair(Br, "opaque", &opaque_bytes, .{ .quality = 8, .window_bits = 16 }, null);
}

/// Requested heap only. Fixed request provenance storage uses no codec heap.
const Ledger = struct {
    const Request = struct { ordinal: usize, len: usize, ra: usize };
    failing: std.testing.FailingAllocator,
    requests: [4096]Request = undefined,
    live: usize = 0,
    peak: usize = 0,
    peak_ordinal: usize = 0,
    active: usize = 0,
    attempts: usize = 0,
    growth_refusals: usize = 0,
    fn init(fail_index: usize) Ledger {
        return .{ .failing = .init(a, .{ .fail_index = fail_index }) };
    }
    fn allocator(self: *Ledger) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &vtable };
    }
    fn balanced(self: *const Ledger) !void {
        try std.testing.expectEqual(@as(usize, 0), self.live);
        try std.testing.expectEqual(@as(usize, 0), self.active);
        try std.testing.expectEqual(self.failing.allocated_bytes, self.failing.freed_bytes);
    }
    const vtable: std.mem.Allocator.VTable = .{ .alloc = alloc, .resize = resize, .remap = remap, .free = free };
    fn alloc(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        self.attempts += 1;
        const ordinal = self.failing.alloc_index;
        const pointer = self.failing.allocator().rawAlloc(len, alignment, ra) orelse return null;
        std.debug.assert(ordinal < self.requests.len);
        self.requests[ordinal] = .{ .ordinal = ordinal, .len = len, .ra = ra };
        self.live += len;
        self.active += 1;
        if (self.live > self.peak) {
            self.peak = self.live;
            self.peak_ordinal = ordinal;
        }
        return pointer;
    }
    fn resize(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, ra: usize) bool {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        if (len > memory.len) {
            self.growth_refusals += 1;
            return false;
        }
        if (!self.failing.allocator().rawResize(memory, alignment, len, ra)) return false;
        self.live -= memory.len - len;
        return true;
    }
    fn remap(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, ra: usize) ?[*]u8 {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        if (len > memory.len) {
            self.growth_refusals += 1;
            return null;
        }
        const pointer = self.failing.allocator().rawRemap(memory, alignment, len, ra) orelse return null;
        self.live -= memory.len - len;
        return pointer;
    }
    fn free(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ra: usize) void {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        self.failing.allocator().rawFree(memory, alignment, ra);
        self.live -= memory.len;
        self.active -= 1;
    }
};

fn success(comptime Br: type, fixture: Fixture, ledger: *Ledger, profile: *Br.EncodeMemoryProfile, cap: ?usize, disabled: bool) !void {
    const wire = try encode(Br, ledger.allocator(), fixture.input, .{ .quality = 8, .window_bits = 16, .memory_profile = profile, .max_total_working_memory = cap }, disabled);
    defer ledger.allocator().free(wire);
    try std.testing.expectEqualSlices(u8, fixture.wire, wire);
    try std.testing.expect(profile.available);
    try std.testing.expectEqual(cap, profile.limit);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    try std.testing.expectEqual(profile.peak_requested_bytes, ledger.peak);
    if (cap) |limit| try std.testing.expect(profile.peak_requested_bytes <= limit);
    try std.testing.expectEqual(wire.len, ledger.live);
    try std.testing.expectEqual(@as(usize, 1), ledger.active);
    try std.testing.expect(!ledger.failing.has_induced_failure);
}

fn observe(comptime Br: type, label: []const u8, fixture: Fixture, ledger: *const Ledger, profile: Br.EncodeMemoryProfile) void {
    std.debug.print("assignment_resource stage={s} corpus={s} limit={?d} peak={d} allocator_peak={d} live={d} profile_live={d} active={d} attempts={d} ordinals={d} allocated={d} freed={d} moving_refusals={d}\n", .{
        label, fixture.name, profile.limit, profile.peak_requested_bytes, ledger.peak, ledger.live, profile.live_requested_bytes, ledger.active, ledger.attempts, ledger.failing.alloc_index, ledger.failing.allocated_bytes, ledger.failing.freed_bytes, ledger.growth_refusals,
    });
}

fn resources(comptime Br: type, fixture: Fixture) !struct { peak: usize, sites: [3]usize } {
    var old = Ledger.init(std.math.maxInt(usize));
    var old_profile: Br.EncodeMemoryProfile = .{};
    try success(Br, fixture, &old, &old_profile, null, true);
    try old.balanced();
    observe(Br, "grouped-u64", fixture, &old, old_profile);
    var tile = Ledger.init(std.math.maxInt(usize));
    var tile_profile: Br.EncodeMemoryProfile = .{};
    try success(Br, fixture, &tile, &tile_profile, null, false);
    try tile.balanced();
    observe(Br, "tile", fixture, &tile, tile_profile);
    if (@as(u128, tile.peak) * 100 > @as(u128, old.peak) * 105) return error.ResourceScreenRejected;
    try std.testing.expectEqual(old.peak, tile.peak);
    try std.testing.expectEqual(old.attempts, tile.attempts);
    try std.testing.expectEqual(old.failing.alloc_index, tile.failing.alloc_index);
    try std.testing.expectEqual(old.failing.allocated_bytes, tile.failing.allocated_bytes);
    try std.testing.expectEqual(old.growth_refusals, tile.growth_refusals);
    for (old.requests[0..old.failing.alloc_index], tile.requests[0..tile.failing.alloc_index]) |left, right|
        try std.testing.expectEqual(left.len, right.len);
    // These are measured request sites, not historical N or claimed semantic
    // header/transfer stages. Their actual failure stack supplies provenance.
    const sites = [3]usize{ 0, tile.peak_ordinal, tile.failing.alloc_index - 1 };
    for (sites) |site| {
        const request = tile.requests[site];
        std.debug.print("assignment_resource stage=selected-actual-site corpus={s} ordinal={d} request_len={d} caller_ra={x} phase_label_unproven=true\n", .{ fixture.name, request.ordinal, request.len, request.ra });
    }
    return .{ .peak = tile.peak, .sites = sites };
}

fn quota(comptime Br: type, fixture: Fixture, peak: usize) !void {
    var exact = Ledger.init(std.math.maxInt(usize));
    var profile: Br.EncodeMemoryProfile = .{};
    try success(Br, fixture, &exact, &profile, peak, false);
    try exact.balanced();
    observe(Br, "exactpeak", fixture, &exact, profile);
    var retry = Ledger.init(std.math.maxInt(usize));
    profile = .{};
    try failure(Br, fixture, &retry, &profile, peak - 1, error.WorkingMemoryLimitExceeded);
    try retry.balanced();
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    try std.testing.expect(profile.available);
    try std.testing.expectEqual(@as(?usize, peak - 1), profile.limit);
    try std.testing.expect(profile.peak_requested_bytes <= peak - 1);
    try std.testing.expectEqual(profile.peak_requested_bytes, retry.peak);
    try std.testing.expect(!retry.failing.has_induced_failure);
    observe(Br, "peakminus1", fixture, &retry, profile);
    profile = .{};
    try success(Br, fixture, &retry, &profile, null, false);
    try retry.balanced();
    observe(Br, "quota-unlimited-retry", fixture, &retry, profile);
}

fn failure(comptime Br: type, fixture: Fixture, ledger: *Ledger, profile: *Br.EncodeMemoryProfile, cap: ?usize, expected: anyerror) !void {
    if (encode(Br, ledger.allocator(), fixture.input, .{ .quality = 8, .window_bits = 16, .memory_profile = profile, .max_total_working_memory = cap }, false)) |wire| {
        ledger.allocator().free(wire);
        observe(Br, "unexpected-success", fixture, ledger, profile.*);
        try ledger.balanced();
        return error.TestUnexpectedResult;
    } else |err| {
        if (err != expected) std.debug.print("assignment_resource unexpected_error={s} expected={s}\n", .{ @errorName(err), @errorName(expected) });
        try std.testing.expect(err == expected);
    }
}

fn backingFailures(comptime Br: type, fixture: Fixture, sites: [3]usize) !void {
    var tested: usize = 0;
    for (sites, 0..) |ordinal, i| {
        var duplicate = false;
        for (sites[0..i]) |previous| duplicate = duplicate or previous == ordinal;
        if (duplicate) continue;
        var ledger = Ledger.init(ordinal);
        var profile: Br.EncodeMemoryProfile = .{};
        try failure(Br, fixture, &ledger, &profile, null, error.OutOfMemory);
        try std.testing.expect(ledger.failing.has_induced_failure);
        try std.testing.expectEqual(ordinal, ledger.failing.alloc_index);
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
        try ledger.balanced();
        std.debug.print("assignment_resource stage=actual-backing-OOM corpus={s} ordinal={d} semantic_phase_not_assumed=true\n", .{ fixture.name, ordinal });
        if (comptime std.debug.sys_can_stack_trace) {
            const trace = ledger.failing.getStackTrace();
            std.debug.dumpStackTrace(&trace);
        }
        ledger.failing.fail_index = std.math.maxInt(usize);
        ledger.failing.has_induced_failure = false;
        profile = .{};
        try success(Br, fixture, &ledger, &profile, null, false);
        try ledger.balanced();
        observe(Br, "backing-unlimited-retry", fixture, &ledger, profile);
        tested += 1;
    }
    std.debug.print("assignment_resource stage=sampled-OOM-complete corpus={s} actual_unique_sites={d} full_sweep_repeated=false\n", .{ fixture.name, tested });
}
