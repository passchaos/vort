const std = @import("std");
const framing = @import("../../snappy_framing.zig");
const snappy = @import("../../snappy.zig");
const core = @import("../../core.zig");
const fixtures = @import("contracts_tests.zig");
const Format = @import("../incremental_decoder.zig").Format;
const allocator = std.testing.allocator;
const decoders = .{ .{ framing.XerialIncrementalDecoder, Format.xerial }, .{ framing.HadoopIncrementalDecoder, Format.hadoop } };

fn expectBudget(decoder: anytype) !void {
    const snap = decoder.snapshot();
    try std.testing.expectEqual(@as(usize, 0), snap.retained_decoded_capacity);
    try std.testing.expectEqual(snap.retained_compressed_capacity + snap.retained_history_capacity, snap.working_bytes);
    try std.testing.expectEqual(snap.working_bytes, decoder.workingMemoryBytes());
    try std.testing.expectEqual(snap.peak_working_bytes, decoder.peakWorkingMemoryBytes());
    try std.testing.expect(snap.peak_working_bytes >= snap.working_bytes);
    try std.testing.expect(snap.peak_working_bytes <= decoder.options.max_working_memory);
}

fn pair(comptime format: Format, first: []const u8, second: []const u8, decoded_len: usize) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    if (format == .xerial) try out.appendSlice(allocator, &framing.xerial_header) else try fixtures.appendU32(&out, decoded_len);
    try fixtures.appendU32(&out, first.len);
    try out.appendSlice(allocator, first);
    try fixtures.appendU32(&out, second.len);
    try out.appendSlice(allocator, second);
    return out.toOwnedSlice(allocator);
}

/// Deny in-place resizing and remapping so fallback replacement must charge
/// its old and new allocations simultaneously, independent of host allocator.
const NoRemap = struct {
    backing: std.mem.Allocator,
    resize_calls: usize = 0,
    remap_calls: usize = 0,

    fn allocator(self: *NoRemap) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn alloc(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, ret: usize) ?[*]u8 {
        const self: *NoRemap = @ptrCast(@alignCast(raw));
        return self.backing.rawAlloc(len, alignment, ret);
    }
    fn resize(raw: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) bool {
        const self: *NoRemap = @ptrCast(@alignCast(raw));
        self.resize_calls += 1;
        return false;
    }
    fn remap(raw: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) ?[*]u8 {
        const self: *NoRemap = @ptrCast(@alignCast(raw));
        self.remap_calls += 1;
        return null;
    }
    fn free(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, ret: usize) void {
        const self: *NoRemap = @ptrCast(@alignCast(raw));
        self.backing.rawFree(bytes, alignment, ret);
    }
};

test "Snappy framing contracts resources COPY4 exact requested peak agrees for GPA and fixed backing" {
    const distance = 70_000;
    const raw = try fixtures.farRaw(distance);
    defer allocator.free(raw);
    const expected = try snappy.decodeBlockAlloc(allocator, raw);
    defer allocator.free(expected);
    inline for (decoders) |case| {
        const wire = try fixtures.envelope(case[1], raw, expected.len);
        defer allocator.free(wire);
        var baseline = case[0].init(allocator);
        defer baseline.deinit();
        const original = try fixtures.drive(&baseline, wire, expected, wire.len, 257);
        try fixtures.expectComplete(original, wire.len, expected.len);
        try expectBudget(&baseline);
        const peak = baseline.peakWorkingMemoryBytes();
        try std.testing.expectEqual(raw.len + distance, peak);
        try std.testing.expectEqual(@as(usize, distance), baseline.snapshot().retained_history_capacity);
        inline for (.{ false, true }) |fixed| {
            inline for (.{ false, true }) |below| {
                var storage: [256 * 1024]u8 = undefined;
                var backing = std.heap.FixedBufferAllocator.init(&storage);
                var decoder = case[0].initWithOptions(if (fixed) backing.allocator() else allocator, .{ .max_working_memory = peak - @intFromBool(below) });
                defer decoder.deinit();
                const trace = try fixtures.drive(&decoder, wire, expected, wire.len, 257);
                try expectBudget(&decoder);
                if (below) {
                    try std.testing.expectEqual(@as(?anyerror, error.WorkingMemoryLimitExceeded), trace.failure);
                    try std.testing.expectEqual(@as(usize, 0), trace.output_written);
                    try std.testing.expectEqual(raw.len, decoder.workingMemoryBytes());
                    try fixtures.sticky(&decoder, error.WorkingMemoryLimitExceeded);
                } else {
                    try fixtures.expectComplete(trace, wire.len, expected.len);
                    try std.testing.expectEqual(peak, trace.peak);
                    try std.testing.expectEqual(@as(usize, distance), decoder.snapshot().retained_history_capacity);
                }
            }
        }
    }
}

test "Snappy framing contracts resources fallback history replacement includes both live rings" {
    const first_distance = 32 * 1024;
    const second_distance = 70_000;
    const first = try fixtures.farRaw(first_distance);
    defer allocator.free(first);
    const second = try fixtures.farRaw(second_distance);
    defer allocator.free(second);
    const first_plain = try snappy.decodeBlockAlloc(allocator, first);
    defer allocator.free(first_plain);
    const second_plain = try snappy.decodeBlockAlloc(allocator, second);
    defer allocator.free(second_plain);
    const expected = try allocator.alloc(u8, first_plain.len + second_plain.len);
    defer allocator.free(expected);
    @memcpy(expected[0..first_plain.len], first_plain);
    @memcpy(expected[first_plain.len..], second_plain);
    inline for (decoders) |case| {
        const wire = try pair(case[1], first, second, expected.len);
        defer allocator.free(wire);
        var backing: NoRemap = .{ .backing = allocator };
        var baseline = case[0].init(backing.allocator());
        defer baseline.deinit();
        try fixtures.expectComplete(try fixtures.drive(&baseline, wire, expected, wire.len, 257), wire.len, expected.len);
        try expectBudget(&baseline);
        const peak = second.len + first_distance + second_distance;
        try std.testing.expectEqual(peak, baseline.peakWorkingMemoryBytes());
        try std.testing.expectEqual(second.len + second_distance, baseline.workingMemoryBytes());
        inline for (.{ false, true }) |below| {
            var decoder = case[0].initWithOptions(backing.allocator(), .{ .max_working_memory = peak - @intFromBool(below) });
            defer decoder.deinit();
            const trace = try fixtures.drive(&decoder, wire, expected, wire.len, 257);
            try expectBudget(&decoder);
            if (below) {
                try std.testing.expectEqual(@as(?anyerror, error.WorkingMemoryLimitExceeded), trace.failure);
                try std.testing.expectEqual(first_plain.len, trace.output_written);
                try std.testing.expectEqual(first_distance, decoder.snapshot().retained_history_capacity);
                try std.testing.expectEqual(@as(usize, second_distance), decoder.snapshot().required_history_len);
                if (case[1] == .hadoop) {
                    try std.testing.expectEqual(expected.len, decoder.snapshot().hadoop_block_decoded);
                    try std.testing.expectEqual(first_plain.len, decoder.snapshot().output_written);
                }
                try fixtures.sticky(&decoder, error.WorkingMemoryLimitExceeded);
            } else {
                try fixtures.expectComplete(trace, wire.len, expected.len);
                try std.testing.expectEqual(peak, trace.peak);
            }
        }
    }
}

test "Snappy framing contracts resources resize and allocation denial retain the published failing prefix" {
    const first = [_]u8{ 3, 8, 'A', 'B', 'C' };
    const second = try fixtures.repeatedRaw(32 * 1024);
    defer allocator.free(second);
    const expected = try allocator.alloc(u8, 3 + 32 * 1024);
    defer allocator.free(expected);
    @memcpy(expected[0..3], "ABC");
    @memset(expected[3..], 'A');
    inline for (decoders) |case| {
        const wire = try pair(case[1], &first, second, expected.len);
        defer allocator.free(wire);
        var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 1 });
        var backing: NoRemap = .{ .backing = failing.allocator() };
        {
            var decoder = case[0].init(backing.allocator());
            defer decoder.deinit();
            try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
            var output: [17]u8 = @splat(0xa5);
            try std.testing.expectError(error.OutOfMemory, decoder.step(wire, &output));
            const consumed = (if (case[1] == .xerial) framing.xerial_header.len else 4) + 4 + first.len + 4;
            const snap = decoder.snapshot();
            try std.testing.expectEqualDeep(core.Progress{ .input_read = consumed, .output_written = 3 }, snap.last_step_progress);
            try std.testing.expectEqual(@as(?usize, consumed), snap.error_input_offset);
            try std.testing.expectEqual(@as(?usize, 3), snap.error_output_offset);
            try std.testing.expectEqualDeep(snap.last_step_progress, decoder.diagnostics().last_step_progress.?);
            try std.testing.expectEqualSlices(u8, "ABC", output[0..3]);
            for (output[3..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
            try std.testing.expect(backing.resize_calls + backing.remap_calls != 0);
            try expectBudget(&decoder);
            try fixtures.sticky(&decoder, error.OutOfMemory);
            const live = decoder.workingMemoryBytes();
            failing.fail_index = std.math.maxInt(usize);
            decoder.reset();
            try std.testing.expectEqual(live, decoder.workingMemoryBytes());
            try std.testing.expectEqual(live, decoder.peakWorkingMemoryBytes());
            try fixtures.expectComplete(try fixtures.drive(&decoder, wire, expected, 37, 257), wire.len, expected.len);
            try expectBudget(&decoder);
        }
        try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
    }
}
