const std = @import("std");
const controls = @import("controls.zig");
const guard = @import("hq_safeguard.zig");
const ledger_mod = @import("../../tests/zstd_stream_counter_helpers.zig");

const Codec = struct {
    pub const Error = anyerror;
    pub const Dictionary = void;
    pub const SequenceScratch = struct {};
    pub const BlockScratch = struct {};
    pub const Options = struct {
        hq: ?controls.HqOptions,
        control_profile: ?*controls.Profile = null,
        requested_len: usize = 9,
        baseline_len: usize = 7,
        fail_requested: bool = false,
        fail_baseline: bool = false,

        pub fn validate(self: Options) Error!void {
            try self.hq.?.validate();
        }
    };
};

/// Mock format emission isolates publication from parser policy. The wire is a
/// complete frame candidate, and each callback verifies the unchanged limits.
fn encodeSingle(comptime is_baseline: bool, allocator: std.mem.Allocator, output: *std.ArrayList(u8), _: []const u8, options: Codec.Options, _: ?Codec.Dictionary, _: *std.ArrayList(u8), _: *Codec.SequenceScratch, _: *Codec.BlockScratch) Codec.Error!void {
    const hq = options.hq.?;
    try std.testing.expectEqual(@as(?u64, 31), hq.max_price_evaluations);
    try std.testing.expectEqual(@as(u32, 7), hq.search_depth);
    try std.testing.expectEqual(@as(u32, 17), hq.nice_len);
    try std.testing.expectEqual(@as(usize, 1234), hq.max_working_memory);
    try std.testing.expectEqual(if (is_baseline) controls.HqParseMode.bounded else .whole_block, hq.parse_mode);
    try std.testing.expectEqual(if (is_baseline) controls.HqMatchLengthPolicy.sampled else .complete, hq.match_lengths);
    if (options.control_profile) |profile| {
        profile.add("hq_passes", 1);
        if (is_baseline) profile.add("baseline_searches", 1);
        profile.recordEffectiveHq(hq);
    }
    if (if (is_baseline) options.fail_baseline else options.fail_requested) {
        if (options.control_profile) |profile| profile.add("price_limit_refusals", 1);
        return error.SearchLimitExceeded;
    }
    const len = if (is_baseline) options.baseline_len else options.requested_len;
    try output.resize(allocator, len);
    @memset(output.items, if (is_baseline) 'B' else 'R');
    if (options.control_profile) |profile| profile.add("compressed_blocks", 1);
}

fn settings(profile: ?*controls.Profile) Codec.Options {
    return .{ .hq = .{ .parse_mode = .whole_block, .match_lengths = .complete, .max_price_evaluations = 31, .search_depth = 7, .nice_len = 17, .max_working_memory = 1234 }, .control_profile = profile };
}

fn append(allocator: std.mem.Allocator, out: *std.ArrayList(u8), options: Codec.Options) !void {
    var records: std.ArrayList(u8) = .empty;
    defer records.deinit(allocator);
    var scratch: Codec.SequenceScratch = .{};
    var blocks: Codec.BlockScratch = .{};
    try guard.appendFrame(Codec, encodeSingle, allocator, out, "input", options, null, &records, &scratch, &blocks);
}

test "Zstd HQ safeguard complete frames publish only shortest winner and preserve requested metadata" {
    for ([_]bool{ false, true }) |tie| {
        var profile: controls.Profile = .{ .compressed_blocks = 3 };
        var options = settings(&profile);
        if (tie) options.requested_len = options.baseline_len;
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(std.testing.allocator);
        try out.appendSlice(std.testing.allocator, "prefix:");
        try append(std.testing.allocator, &out, options);
        try std.testing.expectEqualSlices(u8, "prefix:BBBBBBB", out.items);
        try std.testing.expectEqual(@as(u64, 2), profile.hq_passes);
        try std.testing.expectEqual(@as(u64, 1), profile.baseline_searches);
        try std.testing.expectEqual(@as(u64, 1), profile.guarded_frames);
        try std.testing.expectEqual(@as(u64, 4), profile.compressed_blocks);
        try std.testing.expectEqual(@as(u64, 1), profile.baseline_selected_frames);
        try std.testing.expectEqual(@as(?controls.HqParseMode, .whole_block), profile.effective_hq_parse_mode);
        try std.testing.expectEqual(@as(?controls.HqMatchLengthPolicy, .complete), profile.effective_hq_match_lengths);
    }
}

test "Zstd HQ safeguard requested and baseline search failures preserve output and emitted counters" {
    for ([_]bool{ false, true }) |fail_requested| {
        var profile: controls.Profile = .{ .compressed_blocks = 3, .baseline_selected_frames = 2 };
        var options = settings(&profile);
        options.fail_requested = fail_requested;
        options.fail_baseline = !fail_requested;
        const before = profile.emitted();
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(std.testing.allocator);
        try out.appendSlice(std.testing.allocator, "prefix:");
        const old_pointer = out.items.ptr;
        const old_capacity = out.capacity;
        try std.testing.expectError(error.SearchLimitExceeded, append(std.testing.allocator, &out, options));
        try std.testing.expectEqualSlices(u8, "prefix:", out.items);
        try std.testing.expect(out.items.ptr == old_pointer);
        try std.testing.expectEqual(old_capacity, out.capacity);
        try std.testing.expectEqual(before, profile.emitted());
        try std.testing.expectEqual(@as(u64, if (fail_requested) 1 else 2), profile.hq_passes);
        try std.testing.expectEqual(@as(u64, @intFromBool(!fail_requested)), profile.baseline_searches);
        try std.testing.expectEqual(@as(u64, 1), profile.price_limit_refusals);
        try std.testing.expectEqual(@as(u64, 1), profile.guarded_frames);
        try std.testing.expectEqual(@as(?controls.HqParseMode, .whole_block), profile.effective_hq_parse_mode);
    }
}

test "Zstd HQ safeguard charges both frame candidates and releases loser before publication" {
    var ledger = ledger_mod.TrackingAllocator.init(std.testing.allocator);
    ledger.force_copy_reallocation = true;
    var out: std.ArrayList(u8) = .empty;
    {
        defer out.deinit(ledger.allocator());
        var options = settings(null);
        options.requested_len = 600;
        options.baseline_len = 400;
        try append(ledger.allocator(), &out, options);
        try std.testing.expectEqual(@as(usize, 400), out.items.len);
        try std.testing.expect(ledger.peak >= options.requested_len + options.baseline_len);
        try std.testing.expectEqual(out.capacity, ledger.live);
        for (out.items) |byte| try std.testing.expectEqual(@as(u8, 'B'), byte);
    }
    try std.testing.expectEqual(@as(usize, 0), ledger.live);
    try std.testing.expectEqual(ledger.allocated_bytes, ledger.freed_bytes);
}
