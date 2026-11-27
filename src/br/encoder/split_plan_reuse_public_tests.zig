//! Public split-plan contracts. Both routes retain the current literal-model
//! and ChoiceWitness production behavior; disabled is not a historical source.
const std = @import("std");
const a = std.testing.allocator;

const Fixture = struct {
    name: []const u8,
    input: []const u8,
    wire: []const u8,
    input_sha256: []const u8,
    wire_sha256: []const u8,
};
const fixtures = [_]Fixture{
    .{
        .name = "mozilla",
        .input = @embedFile("literal_model/testdata/mozilla-64k.plain"),
        .wire = @embedFile("literal_model/testdata/mozilla-64k.br"),
        .input_sha256 = "b0050240663f54371d372303eeaba0a59ab0758bcd565f4f639d06561e6bc996",
        .wire_sha256 = "29686649968e0dadd3dec91675d545298aa37fbbb58c00e3b6277881f9a6d2eb",
    },
    .{
        .name = "xray",
        .input = @embedFile("literal_model/testdata/xray-64k.plain"),
        .wire = @embedFile("literal_model/testdata/xray-64k.br"),
        .input_sha256 = "b5a07146616bcd7c2d10071d41e07d204de0ac629c4ca37d8e867ff00574d0d8",
        .wire_sha256 = "53c68176c0cb8c2ffd1759afa6f786fc277750d1108fe12037c822e0d19df288",
    },
    .{
        .name = "nci",
        .input = @embedFile("literal_model/testdata/nci-64k.plain"),
        .wire = @embedFile("literal_model/testdata/nci-64k.br"),
        .input_sha256 = "b01b411ac3b5ce2fbf37242c0c59d2d236d2f7039937c1b1a0f18f4cc02549fe",
        .wire_sha256 = "5e82ff1682e22f8b9e9bbe0f06f49e43b6679bcc736f691a24261295a1d13615",
    },
    .{
        .name = "xml",
        .input = @embedFile("literal_model/testdata/xml-64k.plain"),
        .wire = @embedFile("literal_model/testdata/xml-64k.br"),
        .input_sha256 = "e32aff2bebf00105a17dd57f5490c1986d17543cee837b42eb56b3e0e6f8e7f1",
        .wire_sha256 = "e6446e2083669a87277a22328ceae0f3a3b4e227129c401c10bde2f110d28658",
    },
};

pub fn run(comptime Api: type) !void {
    try publicGoldAndRepeatedCalls(Api);
    try excludedScopes(Api);
    try publicSearchedNull(Api);
    // Complete both resource screens before starting any quota or OOM sweep.
    const screens = try resourceScreens(Api);
    for (screens, 0..) |screen, i| try quotaAndRecovery(Api, fixtures[i], screen.peak);
    const sweep_index: usize = if (screens[0].hits > 0) 0 else 1;
    try std.testing.expect(screens[sweep_index].hits > 0);
    try allocationFailureSweep(Api, fixtures[sweep_index], screens[sweep_index].allocation_ordinals);
}

fn hits(counters: anytype) usize {
    return counters.literal_hits + counters.joint_hits + counters.symbol_hits;
}

fn nullHits(counters: anytype) usize {
    return counters.literal_null_hits + counters.joint_null_hits + counters.symbol_empty_hits;
}

fn noCounters(counters: anytype) !void {
    inline for (comptime std.meta.fieldNames(@TypeOf(counters))) |field|
        try std.testing.expectEqual(@as(usize, 0), @field(counters, field));
}

fn equalCounters(expected: anytype, actual: @TypeOf(expected)) !void {
    inline for (comptime std.meta.fieldNames(@TypeOf(expected))) |field|
        try std.testing.expectEqual(@field(expected, field), @field(actual, field));
}

fn validCounters(groups: usize, counters: anytype) !void {
    try std.testing.expect(counters.literal_null_hits <= counters.literal_hits);
    try std.testing.expect(counters.joint_null_hits <= counters.joint_hits);
    try std.testing.expect(counters.symbol_empty_hits <= counters.symbol_hits);
    try std.testing.expect(counters.literal_captures <= groups);
    try std.testing.expect(counters.joint_captures <= groups);
    try std.testing.expect(@as(u128, counters.symbol_captures) <= @as(u128, groups) * 2);
    // Owner's internal limit includes metadata; the public heap profile counts
    // real supplied-allocator requests, so these are deliberately not equated.
    try std.testing.expect(counters.retained_payload_bytes <= counters.retained_requested_bytes);
    try std.testing.expect(@as(u128, counters.retained_requested_bytes) <= @as(u128, groups) * 64 * 1024);
    if (groups == 0) try noCounters(counters);
}

fn sha(bytes: []const u8, hex: []const u8) !void {
    var expected: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, hex);
    var actual: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &actual, .{});
    try std.testing.expectEqualSlices(u8, &expected, &actual);
}

fn roundTrip(comptime Api: type, input: []const u8, wire: []const u8) !void {
    const decoded = try Api.decode(a, wire);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

fn publicGoldAndRepeatedCalls(comptime Api: type) !void {
    const options: Api.PublicOptions = .{ .quality = 8, .window_bits = 16 };
    var saved: [fixtures.len]Api.Counters = undefined;
    var saved_groups: [fixtures.len]usize = undefined;
    var active_hits: usize = 0;
    for (fixtures, 0..) |fixture, i| {
        try std.testing.expectEqual(@as(usize, 65536), fixture.input.len);
        try sha(fixture.input, fixture.input_sha256);
        try sha(fixture.wire, fixture.wire_sha256);
        const disabled = try Api.encodePublic(a, fixture.input, options, true);
        defer a.free(disabled.wire);
        const enabled = try Api.encodePublic(a, fixture.input, options, false);
        defer a.free(enabled.wire);
        try std.testing.expectEqualSlices(u8, fixture.wire, disabled.wire);
        try std.testing.expectEqualSlices(u8, fixture.wire, enabled.wire);
        try std.testing.expectEqual(@as(usize, 0), disabled.groups);
        try noCounters(disabled.counters);
        try validCounters(enabled.groups, enabled.counters);
        for ([_][]const u8{ fixture.wire, disabled.wire, enabled.wire }) |wire|
            try roundTrip(Api, fixture.input, wire);
        try sha(fixture.input, fixture.input_sha256);
        saved[i] = enabled.counters;
        saved_groups[i] = enabled.groups;
        active_hits += hits(enabled.counters);
        std.debug.print("split_plan_public stage=gold corpus={s} wire_bytes={d} groups={d} counters={any}\n", .{
            fixture.name, enabled.wire.len, enabled.groups, enabled.counters,
        });
    }
    try std.testing.expect(active_hits > 0);
    // Repeated allocating calls use the same allocator after other inputs.
    // This tests scope/reset isolation; it is not a warmed persistent context.
    for ([_]usize{ 1, 0, 3, 1 }) |i| {
        const fixture = fixtures[i];
        const repeated = try Api.encodePublic(a, fixture.input, options, false);
        defer a.free(repeated.wire);
        try std.testing.expectEqualSlices(u8, fixture.wire, repeated.wire);
        try std.testing.expectEqual(saved_groups[i], repeated.groups);
        try equalCounters(saved[i], repeated.counters);
        try roundTrip(Api, fixture.input, repeated.wire);
        try sha(fixture.input, fixture.input_sha256);
        std.debug.print("split_plan_public stage=repeated corpus={s} groups={d} counters={any}\n", .{
            fixture.name, repeated.groups, repeated.counters,
        });
    }
}

fn excluded(comptime Api: type, label: []const u8, input: []const u8, options: Api.PublicOptions, decode: bool) !void {
    const disabled = try Api.encodePublic(a, input, options, true);
    defer a.free(disabled.wire);
    const enabled = try Api.encodePublic(a, input, options, false);
    defer a.free(enabled.wire);
    try std.testing.expectEqualSlices(u8, disabled.wire, enabled.wire);
    try std.testing.expectEqual(@as(usize, 0), disabled.groups);
    try std.testing.expectEqual(@as(usize, 0), enabled.groups);
    try noCounters(disabled.counters);
    try noCounters(enabled.counters);
    if (decode) try roundTrip(Api, input, enabled.wire);
    std.debug.print("split_plan_public stage=excluded case={s} input_bytes={d} wire_bytes={d} groups=0\n", .{
        label, input.len, enabled.wire.len,
    });
}

fn excludedScopes(comptime Api: type) !void {
    const input = fixtures[0].input[0..8192];
    try excluded(Api, "quality4", input, .{ .quality = 4, .window_bits = 16 }, true);
    try excluded(Api, "quality11-cap8", input, .{ .quality = 11, .window_bits = 16, .command_state_max_input_kib = 8 }, true);
    try excluded(Api, "ratio", input, .{ .level = .ratio, .window_bits = 16 }, true);
    try excluded(Api, "implicit-window", input, .{ .quality = 8 }, true);
    try excluded(Api, "window15", input, .{ .quality = 8, .window_bits = 15 }, true);
    try excluded(Api, "window17", input, .{ .quality = 8, .window_bits = 17 }, true);
    try excluded(Api, "metadata", input, .{ .quality = 8, .window_bits = 16, .metadata = "split plan scope" }, true);
    try excluded(Api, "disabled-contexts", input, .{ .quality = 8, .window_bits = 16, .disable_literal_context_modeling = true }, true);
    try excluded(Api, "text-mode", input, .{ .quality = 8, .window_bits = 16, .mode = .text }, true);
    // The supplied decoder keeps the standard-window policy. Extension scope
    // is checked by complete old/new wire equality without a false round trip.
    try excluded(Api, "large-window", input, .{ .quality = 8, .window_bits = 16, .large_window = true }, false);
    var ascii: [8192]u8 = undefined;
    const phrase = "split plan shared dictionary exclusion\n";
    for (&ascii, 0..) |*byte, i| byte.* = phrase[i % phrase.len];
    // This zero RAW prefix cannot match the nonzero ASCII input.
    try excluded(Api, "raw-dictionary", &ascii, .{ .quality = 8, .window_bits = 16, .shared_dictionary = .{ .raw_prefixes = &.{"\x00"} } }, true);
    try excluded(Api, "empty", "", .{ .quality = 8, .window_bits = 16 }, true);
    try excluded(Api, "below8k", input[0..4096], .{ .quality = 8, .window_bits = 16 }, true);
}

fn publicSearchedNull(comptime Api: type) !void {
    var input: [8192]u8 = @splat(' ');
    for (0..input.len / 64) |row| {
        var line_buffer: [64]u8 = undefined;
        const line = try std.fmt.bufPrint(&line_buffer, "split-plan item {d:0>4} alpha beta gamma shared uniform text\n", .{row});
        @memcpy(input[row * 64 ..][0..line.len], line);
    }
    const options: Api.PublicOptions = .{ .quality = 8, .window_bits = 16 };
    const disabled = try Api.encodePublic(a, &input, options, true);
    defer a.free(disabled.wire);
    const enabled = try Api.encodePublic(a, &input, options, false);
    defer a.free(enabled.wire);
    try std.testing.expectEqualSlices(u8, disabled.wire, enabled.wire);
    try std.testing.expectEqual(@as(usize, 0), disabled.groups);
    try noCounters(disabled.counters);
    try validCounters(enabled.groups, enabled.counters);
    try roundTrip(Api, &input, enabled.wire);
    std.debug.print("split_plan_public stage=searched-null input_bytes={d} groups={d} counters={any}\n", .{
        input.len, enabled.groups, enabled.counters,
    });
    // Dedicated getters count only successful ready/key matches whose actual
    // cached nullable result is null (or the entire SymbolPlans is empty).
    // Aggregate reuse hits alone cannot establish this contract.
    try std.testing.expect(enabled.groups > 0);
    try std.testing.expect(nullHits(enabled.counters) > 0);
}

/// Independent requested-byte ledger over the std allocator failure oracle.
/// Growing resize/remap refuses in-place growth on both routes. Shrinks use
/// the backing allocator normally, so frees retain its physical ownership.
const Ledger = struct {
    failing: std.testing.FailingAllocator,
    live: usize = 0,
    peak: usize = 0,
    allocated: usize = 0,
    freed: usize = 0,
    active_allocations: usize = 0,
    alloc_attempts: usize = 0,
    resize_attempts: usize = 0,
    remap_attempts: usize = 0,
    forced_growth_refusals: usize = 0,

    fn init(fail_index: usize) Ledger {
        return .{ .failing = .init(a, .{ .fail_index = fail_index }) };
    }
    fn allocator(self: *Ledger) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &vtable };
    }
    fn replace(self: *Ledger, old: usize, new: usize) void {
        std.debug.assert(self.live >= old);
        if (new >= old) self.allocated += new - old else self.freed += old - new;
        self.live = self.live - old + new;
        self.peak = @max(self.peak, self.live);
    }
    const vtable: std.mem.Allocator.VTable = .{ .alloc = alloc, .resize = resize, .remap = remap, .free = free };
    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *Ledger = @ptrCast(@alignCast(ctx));
        self.alloc_attempts += 1;
        const pointer = self.failing.allocator().rawAlloc(len, alignment, ra) orelse return null;
        self.active_allocations += 1;
        self.replace(0, len);
        return pointer;
    }
    fn resize(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, ra: usize) bool {
        const self: *Ledger = @ptrCast(@alignCast(ctx));
        self.resize_attempts += 1;
        if (len > memory.len) {
            self.forced_growth_refusals += 1;
            return false;
        }
        if (!self.failing.allocator().rawResize(memory, alignment, len, ra)) return false;
        self.replace(memory.len, len);
        return true;
    }
    fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, ra: usize) ?[*]u8 {
        const self: *Ledger = @ptrCast(@alignCast(ctx));
        self.remap_attempts += 1;
        if (len > memory.len) {
            self.forced_growth_refusals += 1;
            return null;
        }
        const pointer = self.failing.allocator().rawRemap(memory, alignment, len, ra) orelse return null;
        self.replace(memory.len, len);
        return pointer;
    }
    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ra: usize) void {
        const self: *Ledger = @ptrCast(@alignCast(ctx));
        self.failing.allocator().rawFree(memory, alignment, ra);
        std.debug.assert(self.active_allocations != 0);
        self.active_allocations -= 1;
        self.replace(memory.len, 0);
    }
};

fn balanced(ledger: *const Ledger) !void {
    try std.testing.expectEqual(@as(usize, 0), ledger.live);
    try std.testing.expectEqual(@as(usize, 0), ledger.active_allocations);
    try std.testing.expectEqual(ledger.allocated, ledger.freed);
    try std.testing.expectEqual(ledger.allocated, ledger.failing.allocated_bytes);
    try std.testing.expectEqual(ledger.freed, ledger.failing.freed_bytes);
}

fn resourceOptions(comptime Api: type, profile: *Api.MemoryProfile, cap: ?usize) Api.PublicOptions {
    return .{ .quality = 8, .window_bits = 16, .memory_profile = profile, .max_total_working_memory = cap };
}

fn ResourceSummary(comptime Api: type) type {
    return struct { wire_bytes: usize, groups: usize, counters: Api.Counters };
}

fn success(comptime Api: type, fixture: Fixture, ledger: *Ledger, profile: *Api.MemoryProfile, cap: ?usize, disabled: bool) !ResourceSummary(Api) {
    const result = try Api.encodePublic(ledger.allocator(), fixture.input, resourceOptions(Api, profile, cap), disabled);
    defer ledger.allocator().free(result.wire);
    try std.testing.expectEqualSlices(u8, fixture.wire, result.wire);
    try std.testing.expect(profile.available);
    try std.testing.expectEqual(cap, profile.limit);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    try std.testing.expect(profile.peak_requested_bytes > 0);
    try std.testing.expectEqual(profile.peak_requested_bytes, ledger.peak);
    try std.testing.expectEqual(result.wire.len, ledger.live);
    try std.testing.expectEqual(@as(usize, 1), ledger.active_allocations);
    try std.testing.expect(!ledger.failing.has_induced_failure);
    if (cap) |limit| try std.testing.expect(profile.peak_requested_bytes <= limit);
    try validCounters(result.groups, result.counters);
    if (disabled) {
        try std.testing.expectEqual(@as(usize, 0), result.groups);
        try noCounters(result.counters);
    } else try std.testing.expect(result.groups > 0);
    return .{ .wire_bytes = result.wire.len, .groups = result.groups, .counters = result.counters };
}

fn observe(comptime Api: type, fixture: Fixture, stage: []const u8, profile: Api.MemoryProfile, ledger: *const Ledger, result: ?ResourceSummary(Api)) void {
    std.debug.print("split_plan_resource stage={s} corpus={s} limit={?d} profile_peak={d} allocator_peak={d} profile_live={d} live={d} active={d} allocated={d} freed={d} alloc_attempts={d} successful_ordinals={d} resize_attempts={d} remap_attempts={d} forced_growth_refusals={d} wire_bytes={?d} groups={?d} counters={any}\n", .{
        stage,                                          fixture.name,                               profile.limit,                                profile.peak_requested_bytes, ledger.peak, profile.live_requested_bytes, ledger.live, ledger.active_allocations, ledger.allocated, ledger.freed, ledger.alloc_attempts, ledger.failing.alloc_index, ledger.resize_attempts, ledger.remap_attempts, ledger.forced_growth_refusals,
        if (result) |value| value.wire_bytes else null, if (result) |value| value.groups else null, if (result) |value| value.counters else null,
    });
}

const Screen = struct { peak: usize, allocation_ordinals: usize, hits: usize };

fn resourceScreens(comptime Api: type) ![2]Screen {
    var screens: [2]Screen = undefined;
    for (fixtures[0..2], 0..) |fixture, i| {
        var disabled = Ledger.init(std.math.maxInt(usize));
        var disabled_profile: Api.MemoryProfile = .{};
        const old = try success(Api, fixture, &disabled, &disabled_profile, null, true);
        try balanced(&disabled);
        observe(Api, fixture, "disabled-unlimited", disabled_profile, &disabled, old);
        var enabled = Ledger.init(std.math.maxInt(usize));
        var enabled_profile: Api.MemoryProfile = .{};
        const shared = try success(Api, fixture, &enabled, &enabled_profile, null, false);
        try balanced(&enabled);
        observe(Api, fixture, "enabled-unlimited", enabled_profile, &enabled, shared);
        if (@as(u128, enabled_profile.peak_requested_bytes) * 100 > @as(u128, disabled_profile.peak_requested_bytes) * 105) {
            std.debug.print("split_plan_resource stage=SCREEN-REJECTED corpus={s} disabled_peak={d} enabled_peak={d} limit_percent=105 quota_and_OOM_sweeps_not_started=true\n", .{
                fixture.name, disabled_profile.peak_requested_bytes, enabled_profile.peak_requested_bytes,
            });
            return error.ResourceScreenRejected;
        }
        try std.testing.expect(enabled.failing.alloc_index > 0);
        screens[i] = .{ .peak = enabled_profile.peak_requested_bytes, .allocation_ordinals = enabled.failing.alloc_index, .hits = hits(shared.counters) };
    }
    std.debug.print("split_plan_resource stage=SCREENS-PASS rows=2 quota_and_OOM_sweeps_authorized_by_resource_result=true\n", .{});
    return screens;
}

fn quotaAndRecovery(comptime Api: type, fixture: Fixture, peak: usize) !void {
    var exact = Ledger.init(std.math.maxInt(usize));
    var exact_profile: Api.MemoryProfile = .{};
    const result = try success(Api, fixture, &exact, &exact_profile, peak, false);
    try balanced(&exact);
    observe(Api, fixture, "exactpeak", exact_profile, &exact, result);
    var retry = Ledger.init(std.math.maxInt(usize));
    var profile: Api.MemoryProfile = .{};
    if (Api.encodePublic(retry.allocator(), fixture.input, resourceOptions(Api, &profile, peak - 1), false)) |unexpected| {
        retry.allocator().free(unexpected.wire);
        observe(Api, fixture, "unexpected-peakminus1-success", profile, &retry, .{ .wire_bytes = unexpected.wire.len, .groups = unexpected.groups, .counters = unexpected.counters });
        try balanced(&retry);
        return error.TestUnexpectedResult;
    } else |err| {
        if (err != error.WorkingMemoryLimitExceeded)
            std.debug.print("split_plan_resource stage=unexpected-quota-error corpus={s} error={s}\n", .{ fixture.name, @errorName(err) });
        try std.testing.expectEqual(error.WorkingMemoryLimitExceeded, err);
    }
    try std.testing.expect(profile.available);
    try std.testing.expectEqual(@as(?usize, peak - 1), profile.limit);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    try std.testing.expect(profile.peak_requested_bytes <= peak - 1);
    try std.testing.expectEqual(profile.peak_requested_bytes, retry.peak);
    try std.testing.expect(!retry.failing.has_induced_failure);
    try balanced(&retry);
    observe(Api, fixture, "peakminus1-refused", profile, &retry, null);
    profile = .{};
    const recovered = try success(Api, fixture, &retry, &profile, null, false);
    try balanced(&retry);
    observe(Api, fixture, "quota-unlimited-recovery", profile, &retry, recovered);
    try std.testing.expectEqual(result.groups, recovered.groups);
    try equalCounters(result.counters, recovered.counters);
}

fn allocationFailureSweep(comptime Api: type, fixture: Fixture, ordinals: usize) !void {
    var failures: usize = 0;
    var active_retries: usize = 0;
    var retry_groups: usize = 0;
    var retry_hits: usize = 0;
    var allocated: u128 = 0;
    var freed: u128 = 0;
    for (0..ordinals) |ordinal| {
        var ledger = Ledger.init(ordinal);
        var profile: Api.MemoryProfile = .{};
        if (Api.encodePublic(ledger.allocator(), fixture.input, resourceOptions(Api, &profile, null), false)) |unexpected| {
            ledger.allocator().free(unexpected.wire);
            observe(Api, fixture, "unexpected-backing-success", profile, &ledger, .{ .wire_bytes = unexpected.wire.len, .groups = unexpected.groups, .counters = unexpected.counters });
            std.debug.print("split_plan_resource unexpected_ordinal={d} induced_failure={any}\n", .{ ordinal, ledger.failing.has_induced_failure });
            try balanced(&ledger);
            return error.TestUnexpectedResult;
        } else |err| {
            if (err != error.OutOfMemory)
                std.debug.print("split_plan_resource unexpected_ordinal={d} error={s}\n", .{ ordinal, @errorName(err) });
            try std.testing.expectEqual(error.OutOfMemory, err);
        }
        try std.testing.expect(ledger.failing.has_induced_failure);
        try std.testing.expectEqual(ordinal, ledger.failing.alloc_index);
        try std.testing.expect(profile.available);
        try std.testing.expectEqual(@as(?usize, null), profile.limit);
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
        try balanced(&ledger);
        failures += 1;
        // Retry on this same backing ledger after disabling its actual fault.
        ledger.failing.fail_index = std.math.maxInt(usize);
        ledger.failing.has_induced_failure = false;
        profile = .{};
        const recovered = try success(Api, fixture, &ledger, &profile, null, false);
        try balanced(&ledger);
        try std.testing.expect(recovered.groups > 0 and hits(recovered.counters) > 0);
        active_retries += 1;
        retry_groups += recovered.groups;
        retry_hits += hits(recovered.counters);
        allocated += ledger.allocated;
        freed += ledger.freed;
    }
    try std.testing.expectEqual(ordinals, failures);
    try std.testing.expectEqual(ordinals, active_retries);
    try std.testing.expectEqual(allocated, freed);
    std.debug.print("split_plan_resource stage=backing-sweep corpus={s} actual_successful_ordinals={d} observed_OutOfMemory={d} active_retries={d} retry_groups={d} retry_getter_hits={d} allocated={d} freed={d}\n", .{
        fixture.name, ordinals, failures, active_retries, retry_groups, retry_hits, allocated, freed,
    });
}
