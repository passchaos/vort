const std = @import("std");
const fast = @import("fast_cover.zig");
const working = @import("../io/working_allocator.zig");
const fixtures = @import("fast_cover_test_helpers.zig");
const allocator = fixtures.allocator;

fn exactPeak(samples: []const []const u8, options: fast.TrainOptions) !void {
    var ledger = working.WorkingAllocator.init(allocator, std.math.maxInt(usize));
    const baseline = try fast.trainAllocProfiled(ledger.allocator(), samples, options);
    const expected = try allocator.dupe(u8, baseline.bytes);
    defer allocator.free(expected);
    try std.testing.expectEqual(baseline.bytes.len, ledger.live);
    try std.testing.expectEqual(ledger.peak, baseline.profile.peak_working_memory);
    const peak = ledger.peak;
    baseline.deinit(ledger.allocator());
    try std.testing.expectEqual(@as(usize, 0), ledger.live);
    inline for (.{ false, true }) |below| {
        var limited = options;
        limited.max_working_memory = peak - @intFromBool(below);
        if (below) {
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, fast.trainAlloc(allocator, samples, limited));
        } else {
            const result = try fast.trainAlloc(allocator, samples, limited);
            defer allocator.free(result);
            try std.testing.expectEqualSlices(u8, expected, result);
        }
    }
}

test "FastCover resources exact live peak includes actual short result rather than target allowance" {
    const storage = fixtures.randomCorpus();
    const samples = fixtures.views(&storage);
    try exactPeak(&samples, .{ .target_size = 48, .segment_size = 8, .dmer_size = 8, .hash_log = 8 });
    const repeated = [_][]const u8{ "abcdefgh", "abcdefgh", "abcdefgh", "abcdefgh", "abcdefgh" };
    try exactPeak(&repeated, .{ .target_size = 8, .segment_size = 8, .dmer_size = 6, .hash_log = 8 });
    const underfilled = [_][]const u8{ "AAAAAAAAAAAAAAAA", "AAAAAAAAAAAAAAAA", "AAAAAAAAAAAAAAAA", "AAAAAAAAAAAAAAAA", "AAAAAAAAAAAAAAAA" };
    try exactPeak(&underfilled, .{ .target_size = 70_000, .segment_size = 70_000, .dmer_size = 6, .hash_log = 1 });
}

test "FastCover resources shared allocator charges retained outputs and cached workspace together" {
    const storage = fixtures.randomCorpus();
    const samples = fixtures.views(&storage);
    const options: fast.TrainOptions = .{ .target_size = 48, .segment_size = 8, .hash_log = 8 };
    var ledger = working.WorkingAllocator.init(allocator, std.math.maxInt(usize));
    var prepared = try fast.Prepared.init(ledger.allocator(), &samples, options);
    const first = try prepared.trainAlloc(ledger.allocator(), options);
    const original = try allocator.dupe(u8, first);
    defer allocator.free(original);
    try std.testing.expectEqual(prepared.workingBytes() + first.len, ledger.live);
    ledger.limit = ledger.live;
    try std.testing.expectError(error.OutOfMemory, prepared.trainAlloc(ledger.allocator(), options));
    try std.testing.expect(ledger.last_failure_was_limit);
    try std.testing.expectEqualSlices(u8, original, first);
    ledger.allocator().free(first);
    const second = try prepared.trainAlloc(ledger.allocator(), options);
    try std.testing.expectEqualSlices(u8, original, second);
    ledger.allocator().free(second);
    prepared.deinit(ledger.allocator());
    try std.testing.expectEqual(@as(usize, 0), ledger.live);
    try std.testing.expect(ledger.peak <= ledger.limit);
}

const AllocationCase = struct {
    pub fn run(gpa: std.mem.Allocator, samples: []const []const u8) !void {
        const options: fast.TrainOptions = .{ .target_size = 48, .segment_size = 8, .hash_log = 8 };
        var owner: ?fast.Prepared = try fast.Prepared.init(gpa, samples, options);
        defer if (owner) |*value| value.deinit(gpa);
        const first = try owner.?.trainAlloc(gpa, options);
        defer gpa.free(first);
        var fork = try owner.?.fork(gpa, options.max_working_memory);
        defer fork.deinit(gpa);
        const second = try fork.trainAlloc(gpa, options);
        defer gpa.free(second);
        try std.testing.expectEqualSlices(u8, first, second);
        var larger = options;
        larger.hash_log = 10;
        try owner.?.prepare(gpa, samples, larger);
        const third = try owner.?.trainAlloc(gpa, larger);
        defer gpa.free(third);
        var moved = owner.?;
        owner = null;
        defer moved.deinit(gpa);
        const fourth = try moved.trainAlloc(gpa, larger);
        defer gpa.free(fourth);
        try std.testing.expectEqualSlices(u8, third, fourth);
    }
};

test "FastCover resources every allocation path including forks and moves releases owned buffers" {
    const storage = fixtures.randomCorpus();
    const samples = fixtures.views(&storage);
    try std.testing.checkAllAllocationFailures(allocator, AllocationCase.run, .{samples[0..]});
    const result = try fast.trainAllocProfiled(allocator, &samples, .{ .target_size = 48, .segment_size = 8, .hash_log = 8 });
    defer result.deinit(allocator);
    try std.testing.expectEqual(result.bytes.len, result.profile.result_bytes);
}

test "FastCover resources failed final result or reprepare allocation leaves previous corpus reusable" {
    const storage = fixtures.randomCorpus();
    const samples = fixtures.views(&storage);
    const options: fast.TrainOptions = .{ .target_size = 48, .segment_size = 8, .hash_log = 8 };
    const expected = try fast.trainAlloc(allocator, &samples, options);
    defer allocator.free(expected);
    var failing = std.testing.FailingAllocator.init(allocator, .{});
    {
        var prepared = try fast.Prepared.init(failing.allocator(), &samples, options);
        defer prepared.deinit(failing.allocator());
        const base = try allocator.dupe(u32, prepared.baseFrequencies());
        defer allocator.free(base);
        // Ring and scratch succeed; the exact result allocation fails after
        // selection has modified the mutable frequency table.
        failing.fail_index = failing.alloc_index + 2;
        try std.testing.expectError(error.OutOfMemory, prepared.trainAlloc(failing.allocator(), options));
        try std.testing.expectEqualSlices(u32, base, prepared.baseFrequencies());
        failing.fail_index = std.math.maxInt(usize);
        const recovered = try prepared.trainAlloc(failing.allocator(), options);
        failing.allocator().free(recovered);
        var bigger = options;
        bigger.hash_log = 10;
        failing.fail_index = failing.alloc_index;
        try std.testing.expectError(error.OutOfMemory, prepared.prepare(failing.allocator(), &samples, bigger));
        try std.testing.expectEqualSlices(u32, base, prepared.baseFrequencies());
        // Same-shape training now needs only the separately owned result.
        failing.fail_index = std.math.maxInt(usize);
        const again = try prepared.trainAlloc(failing.allocator(), options);
        defer failing.allocator().free(again);
        try std.testing.expectEqualSlices(u8, expected, again);
    }
    try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
}

const optimize = @import("fast_cover_optimize.zig");
const ScorerLedger = struct { initialized: usize = 0, destroyed: usize = 0, calls: usize = 0 };
const AllocatingScorer = struct {
    gpa: std.mem.Allocator,
    ledger: *ScorerLedger,
    scratch: []u8,
    calls: usize = 0,

    pub fn init(gpa: std.mem.Allocator, ledger: *ScorerLedger, _: []const []const u8, _: []const []const u8, _: optimize.OptimizeOptions) !AllocatingScorer {
        const scratch = try gpa.alloc(u8, 128);
        ledger.initialized += 1;
        return .{ .gpa = gpa, .ledger = ledger, .scratch = scratch };
    }
    pub fn score(self: *AllocatingScorer, bytes: []const u8, samples: []const []const u8, minimum: usize, _: fast.TrainOptions) !optimize.Score {
        self.calls += 1;
        @memset(self.scratch, @truncate(bytes.len));
        return fixtures.score(bytes, samples, minimum);
    }
    pub fn mergeProfile(self: *const AllocatingScorer, ledger: *ScorerLedger) void {
        ledger.calls += self.calls;
    }
    pub fn deinit(self: *AllocatingScorer) void {
        self.gpa.free(self.scratch);
        self.ledger.destroyed += 1;
    }
};
const optimizer_options: optimize.OptimizeOptions = .{ .target_size = 64, .segment_sizes = &.{ 8, 16, 32 }, .dmer_sizes = &.{8}, .hash_logs = &.{8}, .shrink_dictionary = true, .shrink_min_size = 8 };

test "FastCover optimizer resources managed scorer candidate winner and exact result share one peak" {
    var outer = working.WorkingAllocator.init(allocator, std.math.maxInt(usize));
    var ledger: ScorerLedger = .{};
    const result = try optimize.trainAllocWithScorerFactory(outer.allocator(), &fixtures.training, &fixtures.validation, optimizer_options, &ledger, AllocatingScorer);
    const expected = try allocator.dupe(u8, result.bytes);
    defer allocator.free(expected);
    try std.testing.expectEqual(result.bytes.len, outer.live);
    try std.testing.expectEqual(outer.peak, result.profile.peak_working_memory);
    try std.testing.expectEqual(ledger.initialized, ledger.destroyed);
    try std.testing.expectEqual(ledger.calls, result.profile.scoring_calls);
    const peak = outer.peak;
    result.deinit(outer.allocator());
    try std.testing.expectEqual(@as(usize, 0), outer.live);
    inline for (.{ false, true }) |below| {
        var options = optimizer_options;
        options.max_working_memory = peak - @intFromBool(below);
        ledger = .{};
        if (below) {
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, optimize.trainAllocWithScorerFactory(allocator, &fixtures.training, &fixtures.validation, options, &ledger, AllocatingScorer));
        } else {
            const exact = try optimize.trainAllocWithScorerFactory(allocator, &fixtures.training, &fixtures.validation, options, &ledger, AllocatingScorer);
            defer exact.deinit(allocator);
            try std.testing.expectEqualSlices(u8, expected, exact.bytes);
            try std.testing.expectEqual(peak, exact.profile.peak_working_memory);
        }
        try std.testing.expectEqual(ledger.initialized, ledger.destroyed);
    }
}

const OptimizerAllocationCase = struct {
    pub fn run(gpa: std.mem.Allocator) !void {
        var ledger: ScorerLedger = .{};
        defer std.debug.assert(ledger.initialized == ledger.destroyed);
        const result = try optimize.trainAllocWithScorerFactory(gpa, &fixtures.training, &fixtures.validation, optimizer_options, &ledger, AllocatingScorer);
        defer result.deinit(gpa);
        try std.testing.expectEqualDeep(try fixtures.score(result.bytes, &fixtures.validation, 4), result.validation_score);
    }
};
test "FastCover optimizer resources every managed scorer and candidate allocation failure frees all storage" {
    try std.testing.checkAllAllocationFailures(allocator, OptimizerAllocationCase.run, .{});
}

test "FastCover optimizer resources a tiny native stack budget falls back without dropping candidates" {
    const options: optimize.OptimizeOptions = .{ .target_size = 64, .segment_sizes = &.{ 8, 16, 32 }, .dmer_sizes = &.{8}, .hash_logs = &.{1}, .max_working_memory = 1024, .threads = 2 };
    var parallel = try optimize.trainAllocWithScorerFactory(allocator, &fixtures.training, &fixtures.validation, options, {}, fixtures.PlainScorer);
    defer parallel.deinit(allocator);
    var serial_options = options;
    serial_options.threads = 1;
    var serial = try optimize.trainAllocWithScorerFactory(allocator, &fixtures.training, &fixtures.validation, serial_options, {}, fixtures.PlainScorer);
    defer serial.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 3), parallel.candidates_evaluated);
    try std.testing.expectEqualSlices(u8, serial.bytes, parallel.bytes);
    try std.testing.expectEqualDeep(serial.validation_score, parallel.validation_score);
    try std.testing.expect(parallel.profile.thread_spawn_fallbacks != 0);
    try std.testing.expectEqual(@as(usize, 1), parallel.profile.threads_used);
    try std.testing.expect(parallel.profile.peak_working_memory <= options.max_working_memory);
    try std.testing.expectEqual(@as(usize, 0), parallel.profile.thread_stack_reservation_peak);
}
