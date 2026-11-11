//! Chunk joining must reject destructive output aliases before writing scratch.
const std = @import("std");
const h = @import("helpers.zig");
const f = @import("fixtures.zig");
const budget = @import("../budget.zig");
const Mode = enum { full, limited, exact, prefix, prefix_limited, prefix_exact };
const Policy = enum { legacy, defaults, profile, cap_zero, cap_zero_profile, cap_max_profile };
const Location = enum { items, spare, empty };
const tail = f.external ++ [_]u8{ 0xff, 't', 'a', 'i', 'l' };

pub fn contracts(comptime B: type) !void {
    inline for (std.enums.values(Mode)) |mode| {
        inline for (std.enums.values(Policy)) |policy| {
            inline for (std.enums.values(Location)) |location| try append(B, mode, policy, location);
        }
        try inherited(B, mode);
        inline for (.{ false, true }) |legacy| try into(B, mode, legacy);
    }
    try joinedSpan(B);
    try eager(B);
}

fn prefix(comptime mode: Mode) bool {
    return mode == .prefix or mode == .prefix_limited or mode == .prefix_exact;
}

fn optionsFor(comptime B: type, comptime policy: Policy, profile: *B.DecodeMemoryProfile) B.DecodeOptions {
    return .{
        .memory_profile = if (policy == .profile or policy == .cap_zero_profile or policy == .cap_max_profile) profile else null,
        .max_total_working_memory = switch (policy) {
            .cap_zero, .cap_zero_profile => 0,
            .cap_max_profile => std.math.maxInt(usize),
            else => null,
        },
    };
}

noinline fn append(comptime B: type, comptime mode: Mode, comptime policy: Policy, comptime location: Location) !void {
    errdefer std.debug.print("Brotli chunk scratch alias: {s}, {s}, {s}\n", .{ @tagName(mode), @tagName(policy), @tagName(location) });
    var tracker = h.CountingAllocator.init(h.a);
    const heap = tracker.allocator();
    var out = std.ArrayList(u8).fromOwnedSlice(try heap.alloc(u8, 192));
    defer out.deinit(heap);
    @memset(out.allocatedSlice(), 0xa5);
    const initial_len: usize = if (location == .empty) 0 else 48;
    out.items.len = initial_len;
    const before = try h.a.dupe(u8, out.allocatedSlice());
    defer h.a.free(before);
    const pointer = out.items.ptr;
    const capacity = out.capacity;
    const wire: []const u8 = if (prefix(mode)) &tail else &f.external;
    const chunks = [_][]const u8{ "", wire[0..1], wire[1..], "" };
    const start: usize = if (location == .spare) initial_len else 0;
    const alias = out.allocatedSlice()[start..][0..wire.len];
    var profile: B.DecodeMemoryProfile = .{};
    const options = optionsFor(B, policy, &profile);
    tracker.begin();
    try std.testing.expectError(error.InvalidBlockPlan, callAppend(B, mode, policy == .legacy, heap, &out, &chunks, alias, options));
    try unchanged(&out, pointer, capacity, initial_len, before);
    try std.testing.expectEqual(@as(usize, 0), tracker.attempts);
    try std.testing.expectEqual(capacity, tracker.live);
    if (options.memory_profile != null) try h.zeroProfile(profile, options.max_total_working_memory);

    // Scratch shortage keeps its earlier precedence, including when the
    // undersized span lies within published output or spare capacity.
    try std.testing.expectError(error.OutputTooSmall, callAppend(B, mode, policy == .legacy, heap, &out, &chunks, alias[0 .. alias.len - 1], options));
    try unchanged(&out, pointer, capacity, initial_len, before);
    try std.testing.expectEqual(@as(usize, 0), tracker.attempts);

    var scratch: [tail.len]u8 = undefined;
    const retried = callAppend(B, mode, policy == .legacy, heap, &out, &chunks, &scratch, options);
    if (policy == .cap_zero or policy == .cap_zero_profile) {
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, retried);
        try unchanged(&out, pointer, capacity, initial_len, before);
        try std.testing.expectEqual(@as(usize, 0), tracker.attempts);
    } else {
        const result = try retried;
        try std.testing.expectEqual(f.external.len, result.input_read);
        try std.testing.expectEqual(f.external_plain.len, result.output_written);
        try std.testing.expectEqualSlices(u8, before[0..initial_len], out.items[0..initial_len]);
        try std.testing.expectEqualStrings(f.external_plain, out.items[initial_len..]);
        try std.testing.expectEqual(pointer, out.items.ptr);
        try std.testing.expectEqual(capacity, out.capacity);
    }
    try std.testing.expectEqual(capacity, tracker.live);
    if (options.memory_profile != null) try h.profileMatches(profile, &tracker);
}

fn unchanged(out: *std.ArrayList(u8), pointer: [*]u8, capacity: usize, len: usize, before: []const u8) !void {
    try std.testing.expectEqual(pointer, out.items.ptr);
    try std.testing.expectEqual(capacity, out.capacity);
    try std.testing.expectEqual(len, out.items.len);
    try std.testing.expectEqualSlices(u8, before, out.allocatedSlice());
}

fn callAppend(comptime B: type, comptime mode: Mode, comptime legacy: bool, heap: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, scratch: []u8, options: B.DecodeOptions) B.Error!B.DecodePrefixResult {
    if (prefix(mode)) return switch (mode) {
        .prefix => if (legacy) B.decodeStreamPrefixChunksAppend(heap, out, chunks, scratch) else B.decodeStreamPrefixChunksAppendWithOptions(heap, out, chunks, scratch, options),
        .prefix_limited => if (legacy) B.decodeStreamPrefixChunksAppendLimited(heap, out, chunks, scratch, f.external_plain.len) else B.decodeStreamPrefixChunksAppendLimitedWithOptions(heap, out, chunks, scratch, f.external_plain.len, options),
        .prefix_exact => if (legacy) B.decodeStreamPrefixChunksAppendExactSize(heap, out, chunks, scratch, f.external_plain.len) else B.decodeStreamPrefixChunksAppendExactSizeWithOptions(heap, out, chunks, scratch, f.external_plain.len, options),
        else => unreachable,
    };
    const written = try switch (mode) {
        .full => if (legacy) B.decodeStreamChunksAppend(heap, out, chunks, scratch) else B.decodeStreamChunksAppendWithOptions(heap, out, chunks, scratch, options),
        .limited => if (legacy) B.decodeStreamChunksAppendLimited(heap, out, chunks, scratch, f.external_plain.len) else B.decodeStreamChunksAppendLimitedWithOptions(heap, out, chunks, scratch, f.external_plain.len, options),
        .exact => if (legacy) B.decodeStreamChunksAppendExactSize(heap, out, chunks, scratch, f.external_plain.len) else B.decodeStreamChunksAppendExactSizeWithOptions(heap, out, chunks, scratch, f.external_plain.len, options),
        else => unreachable,
    };
    return .{ .input_read = f.external.len, .output_written = written };
}

fn inherited(comptime B: type, comptime mode: Mode) !void {
    var tracker = h.CountingAllocator.init(h.a);
    defer std.debug.assert(tracker.live == 0);
    var profile: B.DecodeMemoryProfile = .{};
    var lease = try budget.Lease.init(tracker.allocator(), null, &profile, 0);
    defer lease.deinit();
    const parent = lease.allocator();
    // Disjoint retries require growth, so both the inherited quota refusal and
    // the later physical OOM exercise a real allocator request.
    var out = std.ArrayList(u8).fromOwnedSlice(try parent.alloc(u8, 48));
    defer out.deinit(parent);
    @memset(out.allocatedSlice(), 0xa5);
    out.items.len = 48;
    const before = try h.a.dupe(u8, out.allocatedSlice());
    defer h.a.free(before);
    const pointer = out.items.ptr;
    const capacity = out.capacity;
    const wire: []const u8 = if (prefix(mode)) &tail else &f.external;
    const chunks = [_][]const u8{ wire[0..1], wire[1..] };
    try lease.setLimit(tracker.live);
    lease.beginOperation();
    try std.testing.expectError(error.OutOfMemory, parent.alloc(u8, 1));
    const snapshot = lease.snapshot();
    const original_profile = profile;
    try std.testing.expect(snapshot.last_failure_was_limit);
    tracker.begin();
    const outer: B.DecodeOptions = .{ .max_total_working_memory = snapshot.limit, .memory_profile = &profile };
    inline for (.{ false, true }) |forwarded| {
        const options = if (forwarded) budget.forward(outer) else outer;
        try std.testing.expectError(error.InvalidBlockPlan, callAppend(B, mode, false, parent, &out, &chunks, out.items[0..wire.len], options));
        try std.testing.expectEqual(snapshot, lease.snapshot());
        try std.testing.expectEqual(original_profile, profile);
        try unchanged(&out, pointer, capacity, 48, before);
        try std.testing.expectEqual(@as(usize, 0), tracker.attempts);
    }
    var scratch: [tail.len]u8 = undefined;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, callAppend(B, mode, false, parent, &out, &chunks, &scratch, .{}));
    try unchanged(&out, pointer, capacity, 48, before);
    try std.testing.expectEqual(@as(usize, 0), tracker.attempts);
    try lease.setLimit(std.math.maxInt(usize));
    lease.beginOperation();
    tracker.fail_at = 0;
    try std.testing.expectError(error.OutOfMemory, callAppend(B, mode, false, parent, &out, &chunks, &scratch, .{}));
    try std.testing.expect(!lease.snapshot().last_failure_was_limit);
    try unchanged(&out, pointer, capacity, 48, before);
    tracker.fail_at = null;
    lease.beginOperation();
    _ = try callAppend(B, mode, false, parent, &out, &chunks, &scratch, .{});
    try std.testing.expectEqualSlices(u8, before[0..48], out.items[0..48]);
    try std.testing.expectEqualStrings(f.external_plain, out.items[48..]);
}

fn into(comptime B: type, comptime mode: Mode, comptime legacy: bool) !void {
    inline for (.{ false, true }) |malformed| {
        var output: [128]u8 = @splat(0xa5);
        const before = output;
        const wire: []const u8 = if (malformed) f.external[0..2] else if (prefix(mode)) &tail else &f.external;
        const chunks = [_][]const u8{ wire[0..1], "", wire[1..] };
        var profile: B.DecodeMemoryProfile = .{};
        const options: B.DecodeOptions = .{ .max_total_working_memory = 0, .memory_profile = &profile };
        try std.testing.expectError(error.InvalidBlockPlan, callInto(B, mode, legacy, &chunks, output[0..wire.len], &output, options));
        try std.testing.expectEqualSlices(u8, &before, &output);
        try std.testing.expectError(error.OutputTooSmall, callInto(B, mode, legacy, &chunks, output[0 .. wire.len - 1], &output, options));
        try std.testing.expectEqualSlices(u8, &before, &output);
        var scratch: [tail.len]u8 = undefined;
        const retried = callInto(B, mode, legacy, &chunks, &scratch, &output, options);
        if (malformed) {
            try std.testing.expectError(error.TruncatedFrame, retried);
            try std.testing.expectEqualSlices(u8, &before, &output);
        } else {
            const result = try retried;
            try std.testing.expectEqual(f.external.len, result.input_read);
            try std.testing.expectEqual(f.external_plain.len, result.output_written);
            try std.testing.expectEqualStrings(f.external_plain, output[0..result.output_written]);
        }
        if (!legacy) try h.zeroProfile(profile, 0);
    }
}

fn callInto(comptime B: type, comptime mode: Mode, comptime legacy: bool, chunks: []const []const u8, scratch: []u8, output: []u8, options: B.DecodeOptions) B.Error!B.DecodePrefixResult {
    if (prefix(mode)) return switch (mode) {
        .prefix => if (legacy) B.decodeStreamPrefixChunksInto(chunks, scratch, output) else B.decodeStreamPrefixChunksIntoWithOptions(chunks, scratch, output, options),
        .prefix_limited => if (legacy) B.decodeStreamPrefixChunksIntoLimited(chunks, scratch, output, f.external_plain.len) else B.decodeStreamPrefixChunksIntoLimitedWithOptions(chunks, scratch, output, f.external_plain.len, options),
        .prefix_exact => if (legacy) B.decodeStreamPrefixChunksIntoExactSize(chunks, scratch, output, f.external_plain.len) else B.decodeStreamPrefixChunksIntoExactSizeWithOptions(chunks, scratch, output, f.external_plain.len, options),
        else => unreachable,
    };
    const written = try switch (mode) {
        .full => if (legacy) B.decodeStreamChunksInto(chunks, scratch, output) else B.decodeStreamChunksIntoWithOptions(chunks, scratch, output, options),
        .limited => if (legacy) B.decodeStreamChunksIntoLimited(chunks, scratch, output, f.external_plain.len) else B.decodeStreamChunksIntoLimitedWithOptions(chunks, scratch, output, f.external_plain.len, options),
        .exact => if (legacy) B.decodeStreamChunksIntoExactSize(chunks, scratch, output, f.external_plain.len) else B.decodeStreamChunksIntoExactSizeWithOptions(chunks, scratch, output, f.external_plain.len, options),
        else => unreachable,
    };
    return .{ .input_read = f.external.len, .output_written = written };
}

fn joinedSpan(comptime B: type) !void {
    // Only the actual join write is excluded. Larger unused scratch may reach
    // output, and half-open ranges touching at their boundary are disjoint.
    inline for (.{ @as(usize, f.external.len - 1), f.external.len, f.external.len + 1 }) |leading_len| {
        var backing: [1024]u8 = @splat(0xa5);
        var fixed = std.heap.FixedBufferAllocator.init(&backing);
        const heap = fixed.allocator();
        _ = try heap.alloc(u8, leading_len);
        var out = std.ArrayList(u8).fromOwnedSlice(try heap.alloc(u8, 128));
        defer out.deinit(heap);
        out.items.len = 8;
        // Allocator.alloc may poison fresh storage in safety modes. Capture
        // the codec's pre-call bytes after completing allocator setup.
        @memset(&backing, 0xa5);
        const before = backing;
        const chunks = [_][]const u8{&f.external};
        const result = B.decodeStreamPrefixChunksAppend(heap, &out, &chunks, &backing);
        if (leading_len < f.external.len) {
            try std.testing.expectError(error.InvalidBlockPlan, result);
            try std.testing.expectEqualSlices(u8, &before, &backing);
        } else {
            try std.testing.expectEqual(f.external_plain.len, (try result).output_written);
            try std.testing.expectEqualSlices(u8, &f.external, backing[0..f.external.len]);
            try std.testing.expectEqualSlices(u8, before[leading_len..][0..8], out.items[0..8]);
            try std.testing.expectEqualStrings(f.external_plain, out.items[8..]);
        }
    }
    var output: [128]u8 = @splat(0xa5);
    const before = output;
    try std.testing.expectError(error.TruncatedFrame, B.decodeStreamChunksInto(&.{ "", "" }, &output, &output));
    try std.testing.expectEqualSlices(u8, &before, &output);
}

fn eager(comptime B: type) !void {
    inline for (.{ Mode.full, Mode.limited, Mode.exact }) |mode| {
        inline for (.{ false, true }) |legacy| {
            var output: [128]u8 = @splat(0xa5);
            const before = output;
            const chunks = [_][]const u8{ f.external[0..1], f.external[1..] };
            var profile: B.DecodeMemoryProfile = .{};
            const options: B.DecodeOptions = .{ .max_total_working_memory = 0, .memory_profile = &profile };
            const initialized = switch (mode) {
                .full => if (legacy) B.StreamDecoder.initFromChunks(&chunks, output[0..f.external.len], &output) else B.StreamDecoder.initFromChunksWithOptions(&chunks, output[0..f.external.len], &output, options),
                .limited => if (legacy) B.StreamDecoder.initFromChunksLimited(&chunks, output[0..f.external.len], &output, f.external_plain.len) else B.StreamDecoder.initFromChunksLimitedWithOptions(&chunks, output[0..f.external.len], &output, f.external_plain.len, options),
                .exact => if (legacy) B.StreamDecoder.initFromChunksExactSize(&chunks, output[0..f.external.len], &output, f.external_plain.len) else B.StreamDecoder.initFromChunksExactSizeWithOptions(&chunks, output[0..f.external.len], &output, f.external_plain.len, options),
                else => unreachable,
            };
            try std.testing.expectError(error.InvalidBlockPlan, initialized);
            try std.testing.expectEqualSlices(u8, &before, &output);
            var decoder: B.StreamDecoder = .{};
            try std.testing.expectError(error.InvalidBlockPlan, resetEager(B, mode, legacy, &decoder, &chunks, output[0..f.external.len], &output, options));
            try std.testing.expectEqualStrings("InvalidBlockPlan", decoder.snapshot().last_error_name);
            try std.testing.expectEqualSlices(u8, &before, &output);
            var scratch: [f.external.len]u8 = undefined;
            try resetEager(B, mode, legacy, &decoder, &chunks, &scratch, &output, options);
            try std.testing.expectEqual(f.external_plain.len, decoder.snapshot().expected_output_len);
            try std.testing.expectEqualStrings(f.external_plain, output[0..f.external_plain.len]);
            try std.testing.expectEqualStrings("", decoder.snapshot().last_error_name);
            if (!legacy) try h.zeroProfile(profile, 0);
        }
    }
}

fn resetEager(comptime B: type, comptime mode: Mode, comptime legacy: bool, decoder: *B.StreamDecoder, chunks: []const []const u8, scratch: []u8, output: []u8, options: B.DecodeOptions) B.Error!void {
    return switch (mode) {
        .full => if (legacy) decoder.resetFromChunks(chunks, scratch, output) else decoder.resetFromChunksWithOptions(chunks, scratch, output, options),
        .limited => if (legacy) decoder.resetFromChunksLimited(chunks, scratch, output, f.external_plain.len) else decoder.resetFromChunksLimitedWithOptions(chunks, scratch, output, f.external_plain.len, options),
        .exact => if (legacy) decoder.resetFromChunksExactSize(chunks, scratch, output, f.external_plain.len) else decoder.resetFromChunksExactSizeWithOptions(chunks, scratch, output, f.external_plain.len, options),
        else => unreachable,
    };
}
