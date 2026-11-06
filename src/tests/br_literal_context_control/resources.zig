const std = @import("std");
const observer = @import("observer.zig");
const api = @import("api.zig");
const f = @import("fixtures.zig");
const existing = @import("../br_total_memory_helpers.zig");
const a = std.testing.allocator;

pub fn contracts(comptime D: type, stats: *observer.Stats) !void {
    try falseProfilesAndHeap(D, stats);
    try limitsAndAliases(D, stats);
    try std.testing.expectEqual(if (@bitSizeOf(usize) < 64) u64 else usize, D.IncrementalPlannedStreamEncoder.Counter);
    try std.testing.expectEqual(if (@bitSizeOf(usize) < 64) u64 else usize, D.IncrementalCopyStreamDecoder.Counter);
    var denied = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
    const invalid: D.PlannedEncodeOptions = .{ .quality = 12, .disable_literal_context_modeling = true };
    var output: [128]u8 = @splat(0xa5);
    try std.testing.expectError(error.InvalidBlockPlan, D.encodePlannedStreamWithOptionsAlloc(denied.allocator(), "quality", invalid));
    try std.testing.expectError(error.InvalidBlockPlan, D.encodePlannedStreamWithOptionsInto("quality", &output, invalid));
    try f.guards(&output);
    try std.testing.expectEqual(@as(usize, 0), denied.alloc_index);
}

fn falseProfilesAndHeap(comptime D: type, stats: *observer.Stats) !void {
    for ([_]bool{ false, true }) |hq| {
        var implicit_heap = existing.TrackingAllocator.init(a);
        var explicit_heap = existing.TrackingAllocator.init(a);
        var implicit_profile: D.HqProfile = .{};
        var explicit_profile: D.HqProfile = .{};
        var implicit_memory: D.EncodeMemoryProfile = .{};
        var explicit_memory: D.EncodeMemoryProfile = .{};
        const original: D.PlannedEncodeOptions = .{
            .quality = if (hq) 10 else 8,
            .memory_profile = &implicit_memory,
            .hq = if (hq) .{ .beam_width = 2, .iterations = 1, .profile = &implicit_profile } else null,
        };
        var explicit = original;
        explicit.disable_literal_context_modeling = false;
        explicit.memory_profile = &explicit_memory;
        if (hq) {
            explicit.hq.?.profile = &explicit_profile;
            explicit.hq.?.disable_literal_context_modeling = false;
        }
        const implicit_wire = try D.encodePlannedStreamWithOptionsAlloc(implicit_heap.allocator(), f.text ** 3, original);
        defer implicit_heap.allocator().free(implicit_wire);
        const explicit_wire = try D.encodePlannedStreamWithOptionsAlloc(explicit_heap.allocator(), f.text ** 3, explicit);
        defer explicit_heap.allocator().free(explicit_wire);
        try std.testing.expectEqualSlices(u8, implicit_wire, explicit_wire);
        try std.testing.expectEqualDeep(implicit_profile, explicit_profile);
        try std.testing.expectEqualDeep(implicit_memory, explicit_memory);
        inline for (.{ "peak", "live", "allocated_bytes", "freed_bytes", "alloc_attempts", "resize_attempts", "remap_attempts" }) |field|
            try std.testing.expectEqual(@field(implicit_heap, field), @field(explicit_heap, field));
        stats.add(try observer.check(D, implicit_wire, f.text ** 3, false, .{}));
        stats.add(try observer.check(D, explicit_wire, f.text ** 3, false, .{}));
    }
}

fn limitsAndAliases(comptime D: type, stats: *observer.Stats) !void {
    var profile: D.HqProfile = .{};
    const options: D.PlannedEncodeOptions = .{
        .quality = 10,
        .disable_literal_context_modeling = true,
        .hq = .{ .beam_width = 2, .iterations = 1, .profile = &profile },
    };
    const input = f.text ** 3;
    const baseline = try D.encodePlannedStreamWithOptionsAlloc(a, input, options);
    defer a.free(baseline);
    stats.add(try observer.check(D, baseline, input, true, .{}));
    const peak = profile.peak_working_memory;
    try std.testing.expect(peak != 0);
    var limited = options;
    limited.hq.?.max_working_memory = peak;
    profile.reset();
    const exact = try D.encodePlannedStreamWithOptionsAlloc(a, input, limited);
    defer a.free(exact);
    try std.testing.expectEqualSlices(u8, baseline, exact);
    stats.add(try observer.check(D, exact, input, true, .{}));
    limited.hq.?.max_working_memory = peak - 1;
    var output: [1024]u8 = @splat(0xa5);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, D.encodePlannedStreamWithOptionsInto(input, &output, limited));
    try f.guards(&output);

    var reusable = D.PlannedStreamEncoder.init(a);
    defer reusable.deinit();
    const first = try reusable.encodeScratchWithOptions(input, options);
    const alias = try a.dupe(u8, first);
    defer a.free(alias);
    stats.add(try observer.check(D, first, input, true, .{}));
    const next = try reusable.encodeScratchWithOptions(first, options);
    stats.add(try observer.check(D, next, alias, true, .{}));
    // Caller-owned append storage may itself contain the input and dictionary.
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(a);
    try out.appendSlice(a, input);
    var stream = api.streamOptions(D, options, 512);
    const prefixes = [_][]const u8{out.items};
    stream.shared_dictionary = .{ .raw_prefixes = &prefixes };
    const chunks = [_][]const u8{out.items};
    try D.encodePlannedStreamChunksWithOptionsAppend(a, &out, &chunks, stream);
    try std.testing.expectEqualSlices(u8, input, out.items[0..input.len]);
    stats.add(try observer.check(D, out.items[input.len..], input, true, .{ .shared_dictionary = .{ .raw_prefixes = &.{input} } }));
}
