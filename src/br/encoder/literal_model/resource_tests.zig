//! Public allocation and quota contracts on immutable literal-model gold.
const std = @import("std");
const a = std.testing.allocator;

const Fixture = struct { name: []const u8, input: []const u8, wire: []const u8, sweep: bool };
const fixtures = [_]Fixture{
    .{ .name = "mozilla", .input = @embedFile("testdata/mozilla-64k.plain"), .wire = @embedFile("testdata/mozilla-64k.br"), .sweep = true },
    .{ .name = "xray", .input = @embedFile("testdata/xray-64k.plain"), .wire = @embedFile("testdata/xray-64k.br"), .sweep = false },
};
const Summary = struct { wire_bytes: usize, groups: usize, hits: usize, builds: usize, misses: usize };

/// Count physical attempts without introducing a quota or allocating storage.
const Physical = struct {
    failing: std.testing.FailingAllocator,
    alloc_attempts: usize = 0,
    resize_attempts: usize = 0,
    remap_attempts: usize = 0,

    fn init(config: std.testing.FailingAllocator.Config) Physical {
        return .{ .failing = .init(a, config) };
    }
    fn allocator(self: *Physical) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &vtable };
    }
    const vtable: std.mem.Allocator.VTable = .{ .alloc = alloc, .resize = resize, .remap = remap, .free = free };
    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *Physical = @ptrCast(@alignCast(ctx));
        self.alloc_attempts += 1;
        return self.failing.allocator().rawAlloc(len, alignment, ra);
    }
    fn resize(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, ra: usize) bool {
        const self: *Physical = @ptrCast(@alignCast(ctx));
        self.resize_attempts += 1;
        return self.failing.allocator().rawResize(memory, alignment, len, ra);
    }
    fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, ra: usize) ?[*]u8 {
        const self: *Physical = @ptrCast(@alignCast(ctx));
        self.remap_attempts += 1;
        return self.failing.allocator().rawRemap(memory, alignment, len, ra);
    }
    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ra: usize) void {
        const self: *Physical = @ptrCast(@alignCast(ctx));
        self.failing.allocator().rawFree(memory, alignment, ra);
    }
};

pub fn run(comptime Api: type) !void {
    for (fixtures) |fixture| try corpus(Api, fixture);
}

fn options(comptime Api: type, memory: *Api.MemoryProfile, limit: ?usize) Api.PublicOptions {
    return .{ .quality = 8, .mode = .generic, .window_bits = 16, .memory_profile = memory, .max_total_working_memory = limit };
}

fn balanced(physical: *const Physical) !void {
    try std.testing.expectEqual(physical.failing.allocated_bytes, physical.failing.freed_bytes);
}

fn observe(comptime Api: type, fixture: Fixture, stage: []const u8, memory: Api.MemoryProfile, physical: *const Physical, summary: ?Summary) void {
    std.debug.print("literal_model_resource stage={s} corpus={s} limit={?d} peak={d} live={d} allocated_bytes={d} freed_bytes={d} allocations={d} backing_alloc_attempts={d} backing_resize_attempts={d} backing_remap_attempts={d} wire_bytes={?d} groups={?d} hits={?d} builds={?d} misses={?d}\n", .{
        stage,                               fixture.name,                            memory.limit,                        memory.peak_requested_bytes,       memory.live_requested_bytes,
        physical.failing.allocated_bytes,    physical.failing.freed_bytes,            physical.failing.alloc_index,        physical.alloc_attempts,           physical.resize_attempts,
        physical.remap_attempts,             if (summary) |s| s.wire_bytes else null, if (summary) |s| s.groups else null, if (summary) |s| s.hits else null, if (summary) |s| s.builds else null,
        if (summary) |s| s.misses else null,
    });
}

fn success(comptime Api: type, fixture: Fixture, physical: *Physical, memory: *Api.MemoryProfile, limit: ?usize, disabled: bool) !Summary {
    const result = try Api.encodePublic(physical.allocator(), fixture.input, options(Api, memory, limit), disabled);
    defer physical.allocator().free(result.wire);
    try std.testing.expectEqualSlices(u8, fixture.wire, result.wire);
    try std.testing.expect(memory.available);
    try std.testing.expectEqual(limit, memory.limit);
    try std.testing.expectEqual(@as(usize, 0), memory.live_requested_bytes);
    try std.testing.expect(memory.peak_requested_bytes > 0);
    if (limit) |cap| try std.testing.expect(memory.peak_requested_bytes <= cap);
    try std.testing.expect(!physical.failing.has_induced_failure);
    try std.testing.expectEqual(result.wire.len, physical.failing.allocated_bytes - physical.failing.freed_bytes);
    if (disabled) {
        try std.testing.expectEqual(@as(usize, 0), result.groups);
        inline for (comptime std.meta.fieldNames(@TypeOf(result.counters))) |field|
            try std.testing.expectEqual(@as(usize, 0), @field(result.counters, field));
    } else {
        try std.testing.expect(result.groups > 0);
        try std.testing.expect(result.counters.hits > 0);
    }
    return .{ .wire_bytes = result.wire.len, .groups = result.groups, .hits = result.counters.hits, .builds = result.counters.builds, .misses = result.counters.misses };
}

fn corpus(comptime Api: type, fixture: Fixture) !void {
    try std.testing.expectEqual(@as(usize, 65536), fixture.input.len);
    var baseline = Physical.init(.{});
    var baseline_memory: Api.MemoryProfile = .{};
    const old = try success(Api, fixture, &baseline, &baseline_memory, null, true);
    try balanced(&baseline);
    observe(Api, fixture, "disabled-probe", baseline_memory, &baseline, old);

    var enabled = Physical.init(.{});
    var enabled_memory: Api.MemoryProfile = .{};
    const shared = try success(Api, fixture, &enabled, &enabled_memory, null, false);
    try balanced(&enabled);
    observe(Api, fixture, "enabled-probe", enabled_memory, &enabled, shared);
    // Architecture 10.3's default five percent requested-heap growth ceiling.
    try std.testing.expect(@as(u128, enabled_memory.peak_requested_bytes) * 100 <= @as(u128, baseline_memory.peak_requested_bytes) * 105);
    const peak = enabled_memory.peak_requested_bytes;
    const allocation_ordinals = enabled.failing.alloc_index;
    try std.testing.expect(allocation_ordinals > 0);

    var exact = Physical.init(.{});
    var exact_memory: Api.MemoryProfile = .{};
    const exact_result = try success(Api, fixture, &exact, &exact_memory, peak, false);
    try balanced(&exact);
    observe(Api, fixture, "exact-D", exact_memory, &exact, exact_result);
    try quotaAndRetry(Api, fixture, peak);
    if (fixture.sweep) try allocationFailures(Api, fixture, allocation_ordinals);
}

fn quotaAndRetry(comptime Api: type, fixture: Fixture, peak: usize) !void {
    var physical = Physical.init(.{});
    var memory: Api.MemoryProfile = .{};
    if (Api.encodePublic(physical.allocator(), fixture.input, options(Api, &memory, peak - 1), false)) |result| {
        physical.allocator().free(result.wire);
        observe(Api, fixture, "unexpected-D-minus-one-success", memory, &physical, .{
            .wire_bytes = result.wire.len,
            .groups = result.groups,
            .hits = result.counters.hits,
            .builds = result.counters.builds,
            .misses = result.counters.misses,
        });
        try balanced(&physical);
        return error.TestUnexpectedResult;
    } else |err| {
        try std.testing.expectEqual(error.WorkingMemoryLimitExceeded, err);
    }
    try std.testing.expect(memory.available);
    try std.testing.expectEqual(@as(?usize, peak - 1), memory.limit);
    try std.testing.expectEqual(@as(usize, 0), memory.live_requested_bytes);
    try std.testing.expect(memory.peak_requested_bytes <= peak - 1);
    try std.testing.expect(!physical.failing.has_induced_failure);
    try balanced(&physical);
    observe(Api, fixture, "D-minus-one-refused", memory, &physical, null);

    memory = .{};
    const retry = try success(Api, fixture, &physical, &memory, null, false);
    try balanced(&physical);
    observe(Api, fixture, "quota-unlimited-retry", memory, &physical, retry);
}

fn allocationFailures(comptime Api: type, fixture: Fixture, allocation_ordinals: usize) !void {
    var failures: usize = 0;
    var retries: usize = 0;
    var retry_groups: usize = 0;
    var retry_hits: usize = 0;
    var backing_attempts: usize = 0;
    var allocated_bytes: u128 = 0;
    var freed_bytes: u128 = 0;
    for (0..allocation_ordinals) |ordinal| {
        var physical = Physical.init(.{ .fail_index = ordinal });
        var memory: Api.MemoryProfile = .{};
        if (Api.encodePublic(physical.allocator(), fixture.input, options(Api, &memory, null), false)) |result| {
            physical.allocator().free(result.wire);
            observe(Api, fixture, "unexpected-allocation-success", memory, &physical, .{
                .wire_bytes = result.wire.len,
                .groups = result.groups,
                .hits = result.counters.hits,
                .builds = result.counters.builds,
                .misses = result.counters.misses,
            });
            std.debug.print("literal_model_resource stage=unexpected-allocation-success ordinal={d} induced_failure={any}\n", .{ ordinal, physical.failing.has_induced_failure });
            try balanced(&physical);
            return error.TestUnexpectedResult;
        } else |err| {
            if (err != error.OutOfMemory) std.debug.print("literal_model_resource stage=unexpected-allocation-error ordinal={d} error={s}\n", .{ ordinal, @errorName(err) });
            try std.testing.expectEqual(error.OutOfMemory, err);
        }
        try std.testing.expect(physical.failing.has_induced_failure);
        try std.testing.expectEqual(ordinal, physical.failing.alloc_index);
        try std.testing.expect(memory.available);
        try std.testing.expectEqual(@as(?usize, null), memory.limit);
        try std.testing.expectEqual(@as(usize, 0), memory.live_requested_bytes);
        try balanced(&physical);
        failures += 1;

        physical.failing.fail_index = std.math.maxInt(usize);
        physical.failing.has_induced_failure = false;
        memory = .{};
        const retry = try success(Api, fixture, &physical, &memory, null, false);
        try balanced(&physical);
        retries += 1;
        retry_groups += retry.groups;
        retry_hits += retry.hits;
        backing_attempts += physical.alloc_attempts;
        allocated_bytes += physical.failing.allocated_bytes;
        freed_bytes += physical.failing.freed_bytes;
    }
    try std.testing.expectEqual(allocation_ordinals, failures);
    try std.testing.expectEqual(allocation_ordinals, retries);
    try std.testing.expectEqual(allocated_bytes, freed_bytes);
    std.debug.print("literal_model_resource stage=sweep corpus={s} allocation_ordinals={d} observed_OOMs={d} retries={d} retry_groups={d} retry_hits={d} backing_alloc_attempts={d} allocated_bytes={d} freed_bytes={d}\n", .{
        fixture.name, allocation_ordinals, failures, retries, retry_groups, retry_hits, backing_attempts, allocated_bytes, freed_bytes,
    });
}
