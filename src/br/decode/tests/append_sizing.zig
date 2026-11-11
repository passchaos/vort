//! Impossible append lengths fail before allocating, staging or publishing.
const std = @import("std");
const h = @import("helpers.zig");
const f = @import("fixtures.zig");
const budget = @import("../budget.zig");

const Mode = enum { full, prefix, full_chunks, prefix_chunks };
const Policy = enum { defaults, profile, cap_zero, cap_zero_profile, cap_max_profile, cold };

fn optionsFor(comptime B: type, policy: Policy, profile: *B.DecodeMemoryProfile) B.DecodeOptions {
    return .{
        .memory_profile = switch (policy) {
            .profile, .cap_zero_profile, .cap_max_profile => profile,
            else => null,
        },
        .max_total_working_memory = switch (policy) {
            .cap_zero, .cap_zero_profile => 0,
            .cap_max_profile => std.math.maxInt(usize),
            else => null,
        },
        .allow_large_window = policy == .cold,
    };
}

fn call(comptime B: type, comptime mode: Mode, comptime legacy: bool, heap: std.mem.Allocator, out: *std.ArrayList(u8), wire: []const u8, scratch: []u8, expected: usize, options: B.DecodeOptions) B.Error!usize {
    const chunks = [_][]const u8{ wire[0..1], "", wire[1..] };
    return switch (mode) {
        .full => if (legacy) B.decodeStreamAppendExactSize(heap, out, wire, expected) else B.decodeStreamAppendExactSizeWithOptions(heap, out, wire, expected, options),
        .prefix => (if (legacy) try B.decodeStreamPrefixAppendExactSize(heap, out, wire, expected) else try B.decodeStreamPrefixAppendExactSizeWithOptions(heap, out, wire, expected, options)).output_written,
        .full_chunks => if (legacy) B.decodeStreamChunksAppendExactSize(heap, out, &chunks, scratch, expected) else B.decodeStreamChunksAppendExactSizeWithOptions(heap, out, &chunks, scratch, expected, options),
        .prefix_chunks => (if (legacy) try B.decodeStreamPrefixChunksAppendExactSize(heap, out, &chunks, scratch, expected) else try B.decodeStreamPrefixChunksAppendExactSizeWithOptions(heap, out, &chunks, scratch, expected, options)).output_written,
    };
}

fn unchanged(out: *const std.ArrayList(u8), pointer: [*]u8, len: usize, before: []const u8) !void {
    try std.testing.expectEqual(pointer, out.items.ptr);
    try std.testing.expectEqual(before.len, out.capacity);
    try std.testing.expectEqual(len, out.items.len);
    try std.testing.expectEqualSlices(u8, before, out.allocatedSlice());
}

fn rejected(comptime B: type, comptime mode: Mode, comptime legacy: bool, policy: Policy, start: usize, aliased_input: bool) !void {
    errdefer std.debug.print("append size: mode={s}, legacy={any}, policy={s}, start={d}, alias={any}\n", .{ @tagName(mode), legacy, @tagName(policy), start, aliased_input });
    var tracker = h.CountingAllocator.init(h.a);
    defer std.debug.assert(tracker.live == 0);
    const heap = tracker.allocator();
    var out = std.ArrayList(u8).fromOwnedSlice(try heap.alloc(u8, 128));
    defer out.deinit(heap);
    @memset(out.allocatedSlice(), 0xa5);
    out.items.len = start;
    if (aliased_input) @memcpy(out.allocatedSlice()[32..][0..f.external.len], &f.external);
    const wire = if (aliased_input) out.allocatedSlice()[32..][0..f.external.len] else &f.external;
    const before = try h.a.dupe(u8, out.allocatedSlice());
    defer h.a.free(before);
    const pointer = out.items.ptr;
    tracker.begin();
    tracker.fail_at = 0;
    var profile: B.DecodeMemoryProfile = .{};
    const options = optionsFor(B, policy, &profile);
    var scratch: [f.external.len]u8 = undefined;
    const expected = std.math.maxInt(usize) - (start - 1);
    try std.testing.expectError(error.IntegerOverflow, call(B, mode, legacy, heap, &out, wire, &scratch, expected, options));
    try unchanged(&out, pointer, start, before);
    try std.testing.expectEqual(@as(usize, 0), tracker.attempts);
    try std.testing.expectEqual(@as(usize, 0), tracker.failures);
    if (!legacy and options.memory_profile != null) try h.zeroProfile(profile, options.max_total_working_memory);
    tracker.fail_at = null;
    const written = try call(B, mode, true, heap, &out, wire, &scratch, f.external_plain.len, .{});
    try std.testing.expectEqual(f.external_plain.len, written);
    try std.testing.expectEqualSlices(u8, before[0..start], out.items[0..start]);
    try std.testing.expectEqualStrings(f.external_plain, out.items[start..]);
}

fn representableBoundary(comptime B: type, comptime mode: Mode, policy: Policy) !void {
    var tracker = h.CountingAllocator.init(h.a);
    defer std.debug.assert(tracker.live == 0);
    const heap = tracker.allocator();
    var out = std.ArrayList(u8).fromOwnedSlice(try heap.alloc(u8, 128));
    defer out.deinit(heap);
    @memset(out.allocatedSlice(), 0xa5);
    out.items.len = 1;
    const pointer = out.items.ptr;
    tracker.begin();
    tracker.fail_at = 0;
    var profile: B.DecodeMemoryProfile = .{};
    const options = optionsFor(B, policy, &profile);
    var scratch: [f.external.len]u8 = undefined;
    const result = call(B, mode, false, heap, &out, &f.external, &scratch, std.math.maxInt(usize) - 1, options);
    if (policy == .cap_zero or policy == .cap_zero_profile) {
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, result);
        try std.testing.expectEqual(@as(usize, 0), tracker.attempts);
    } else {
        try std.testing.expectError(error.OutOfMemory, result);
        try std.testing.expect(tracker.failures != 0);
    }
    try std.testing.expectEqual(pointer, out.items.ptr);
    try std.testing.expectEqual(@as(usize, 128), out.capacity);
    try std.testing.expectEqual(@as(usize, 1), out.items.len);
    try std.testing.expect(std.mem.allEqual(u8, out.allocatedSlice(), 0xa5));
}

fn preflightPriority(comptime B: type, comptime mode: Mode) !void {
    var tracker = h.CountingAllocator.init(h.a);
    tracker.fail_at = 0;
    var buffer: [128]u8 = @splat(0xa5);
    var out: std.ArrayList(u8) = .{ .items = buffer[0..1], .capacity = buffer.len };
    var profile: B.DecodeMemoryProfile = .{};
    var scratch: [f.external.len]u8 = undefined;
    const invalid = [_][]const u8{""} ** 16;
    try std.testing.expectError(error.CorruptFrame, call(B, mode, false, tracker.allocator(), &out, &f.external, &scratch, std.math.maxInt(usize), .{ .max_total_working_memory = 0, .memory_profile = &profile, .shared_dictionary = .{ .raw_prefixes = &invalid } }));
    try h.zeroProfile(profile, 0);
    try std.testing.expectEqual(@as(usize, 0), tracker.attempts);
    try std.testing.expect(std.mem.allEqual(u8, &buffer, 0xa5));
    // Scalar header failures retain their precedence over size and quota.
    try std.testing.expectError(error.TruncatedFrame, call(B, mode, false, tracker.allocator(), &out, f.external[0..1], &scratch, std.math.maxInt(usize), .{ .max_total_working_memory = 0, .memory_profile = &profile }));
    try h.zeroProfile(profile, 0);
    try std.testing.expectEqual(@as(usize, 0), tracker.attempts);
    try std.testing.expectError(error.TruncatedFrame, call(B, mode, true, tracker.allocator(), &out, f.external[0..1], &scratch, std.math.maxInt(usize), .{}));
    try std.testing.expectEqual(@as(usize, 0), tracker.attempts);
}

fn inherited(comptime B: type, comptime mode: Mode, already_refused: bool) !void {
    var tracker = h.CountingAllocator.init(h.a);
    defer std.debug.assert(tracker.live == 0);
    var profile: B.DecodeMemoryProfile = .{};
    var lease = try budget.Lease.init(tracker.allocator(), null, &profile, 0);
    defer lease.deinit();
    const parent = lease.allocator();
    var out = std.ArrayList(u8).fromOwnedSlice(try parent.alloc(u8, 128));
    defer out.deinit(parent);
    @memset(out.allocatedSlice(), 0xa5);
    out.items.len = 1;
    if (already_refused) {
        try lease.setLimit(tracker.live);
        lease.beginOperation();
        try std.testing.expectError(error.OutOfMemory, parent.alloc(u8, 1));
    }
    const snapshot = lease.snapshot();
    const observed = profile;
    var scratch: [f.external.len]u8 = undefined;
    tracker.begin();
    tracker.fail_at = 0;
    const explicit: B.DecodeOptions = .{ .max_total_working_memory = snapshot.limit, .memory_profile = &profile };
    for ([_]B.DecodeOptions{ explicit, budget.forward(explicit) }) |options| {
        try std.testing.expectError(error.IntegerOverflow, call(B, mode, false, parent, &out, &f.external, &scratch, std.math.maxInt(usize), options));
        try std.testing.expectEqual(snapshot, lease.snapshot());
        try std.testing.expectEqual(observed, profile);
        try std.testing.expectEqual(@as(usize, 0), tracker.attempts);
        try std.testing.expect(std.mem.allEqual(u8, out.allocatedSlice(), 0xa5));
    }
}

fn nullScope() !void {
    var tracker = h.CountingAllocator.init(h.a);
    defer std.debug.assert(tracker.live == 0);
    var buffer: [16]u8 = @splat(0xa5);
    var out: std.ArrayList(u8) = .{ .items = buffer[0..1], .capacity = buffer.len };
    var lease = try budget.Lease.init(tracker.allocator(), null, null, 0);
    defer lease.deinit();
    var scope = try budget.AppendScope.init(lease, tracker.allocator(), &out);
    defer scope.deinit();
    const unreadable: [*]const u8 = @ptrFromInt(4096);
    try std.testing.expectError(error.IntegerOverflow, scope.append(unreadable[0..std.math.maxInt(usize)]));
    try std.testing.expectEqual(@as(usize, 0), tracker.attempts);
    try std.testing.expect(std.mem.allEqual(u8, &buffer, 0xa5));
}

pub fn contracts(comptime B: type) !void {
    try nullScope();
    inline for (std.enums.values(Mode)) |mode| {
        for (std.enums.values(Policy)) |policy| {
            for ([_]usize{ 1, 2, 13 }) |start| {
                try rejected(B, mode, false, policy, start, false);
                try rejected(B, mode, false, policy, start, true);
            }
            try representableBoundary(B, mode, policy);
        }
        inline for (.{ false, true }) |aliased| try rejected(B, mode, true, .defaults, 1, aliased);
        try preflightPriority(B, mode);
        try inherited(B, mode, false);
        try inherited(B, mode, true);
    }
}
