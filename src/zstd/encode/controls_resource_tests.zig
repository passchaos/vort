const std = @import("std");
const zstd = @import("../../zstd.zig");
const controls = @import("controls.zig");
const working = @import("../../io/working_allocator.zig");
const fixtures = @import("controls_test_helpers.zig");
const allocator = fixtures.allocator;
const strategies = [_]controls.Strategy{ .fast, .double_fast, .greedy, .lazy, .optimal };

test "Zstd encode controls invalid levels and conflicting options fail before caller writes or allocation" {
    const cases = [_]struct { level: c_int, options: zstd.FrameOptions = .{} }{
        .{ .level = std.math.minInt(c_int) },
        .{ .level = -131073 },
        .{ .level = 23 },
        .{ .level = 0, .options = .{ .strategy = .fast } },
        .{ .level = -2, .options = .{ .fast_acceleration = 1 } },
        .{ .level = 1, .options = .{ .fast_acceleration = 0 } },
        .{ .level = 1, .options = .{ .fast_acceleration = 131073 } },
        .{ .level = 1, .options = .{ .strategy = .greedy, .fast_acceleration = 1 } },
        .{ .level = -1, .options = .{ .strategy = .lazy } },
        .{ .level = 1, .options = .{ .max_match_history_len = 1024 } },
    };
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    var encoder = zstd.LevelFrameEncoder.init(failing.allocator());
    defer encoder.deinit();
    var output: [1024]u8 = @splat(0xa5);
    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix");
    for (cases) |case| {
        try std.testing.expectError(error.InvalidBlockPlan, zstd.encodedFrameBoundWithLevelAndOptions(128, case.level, case.options));
        try std.testing.expectError(error.InvalidBlockPlan, zstd.encodeFrameIntoSliceWithLevelAndOptions(failing.allocator(), "parameter validation", case.level, case.options, &output));
        try fixtures.sentinel(&output);
        try std.testing.expectError(error.InvalidBlockPlan, zstd.encodeFrameAppendWithLevelAndOptions(failing.allocator(), &appended, "parameter validation", case.level, case.options));
        try std.testing.expectEqualStrings("prefix", appended.items);
        try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeIntoWithOptions("parameter validation", case.level, case.options, &output));
        try fixtures.sentinel(&output);
    }
    try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
    const native_cases = [_]zstd.NativeFrameOptions{
        .{ .strategy = .fast, .selection = .raw_or_rle },
        .{ .strategy = .double_fast, .selection = .literal_only },
        .{ .strategy = .fast, .rep_beam_search = true },
        .{ .strategy = .fast, .match_search_budget = 511 },
        .{ .strategy = .greedy, .match_search_budget = 513 },
        .{ .strategy = .optimal, .fast_acceleration = 8 },
    };
    const dictionary = zstd.NativeDictionary.init(73, "validated dictionary");
    const set = zstd.NativeDictionarySet.init(&.{dictionary});
    for (native_cases) |options| {
        try std.testing.expectError(error.InvalidBlockPlan, zstd.encodedNativeFrameBoundWithOptions(128, options));
        try std.testing.expectError(error.InvalidBlockPlan, zstd.encodeNativeFrameIntoSlice(failing.allocator(), "parameter validation", options, &output));
        try fixtures.sentinel(&output);
        try std.testing.expectError(error.InvalidBlockPlan, zstd.encodeNativeFrameAppend(failing.allocator(), &appended, "parameter validation", options));
        try std.testing.expectEqualStrings("prefix", appended.items);
        try std.testing.expectError(error.InvalidBlockPlan, zstd.encodeNativeFrameIntoSliceWithDictionarySet(failing.allocator(), "parameter validation", options, set, 73, &output));
        try std.testing.expectError(error.InvalidBlockPlan, zstd.NativeIncrementalFrameEncoder.initExactSize(failing.allocator(), options, 128));
        const seek_options: zstd.NativeSeekableOptions = .{ .frame_options = options };
        try std.testing.expectError(error.InvalidBlockPlan, zstd.encodedNativeSeekableStreamBound(128, seek_options));
        try std.testing.expectError(error.InvalidBlockPlan, zstd.encodeNativeSeekableStreamAppend(failing.allocator(), &appended, "parameter validation", seek_options));
        try std.testing.expectEqualStrings("prefix", appended.items);
    }
    try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
}

test "Zstd encode controls public raw and literal subsets reject explicit engines without modifying output" {
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix");
    var output: [1024]u8 = @splat(0xa5);
    for (strategies) |strategy| {
        const options: zstd.NativeFrameOptions = .{ .strategy = strategy };
        try std.testing.expectError(error.InvalidBlockPlan, zstd.encodeRawOrRleFrameAppend(failing.allocator(), &appended, "raw subset", options));
        try std.testing.expectError(error.InvalidBlockPlan, zstd.encodeLiteralOnlyFrameAppend(failing.allocator(), &appended, "literal subset", options));
        try std.testing.expectEqualStrings("prefix", appended.items);
        try std.testing.expectError(error.InvalidBlockPlan, zstd.encodeRawOrRleFrameIntoSlice(failing.allocator(), "raw subset", options, &output));
        try std.testing.expectError(error.InvalidBlockPlan, zstd.encodeLiteralOnlyFrameIntoSlice(failing.allocator(), "literal subset", options, &output));
        try fixtures.sentinel(&output);
    }
    try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
}

test "Zstd encode controls supported header flags windows and output bounds remain valid" {
    const input = fixtures.legacyInput();
    for ([_]u6{ 10, 14, 23, 41 }) |window| {
        inline for (.{ false, true }) |known| {
            inline for (.{ false, true }) |checksum| {
                const options: zstd.FrameOptions = .{ .strategy = .fast, .window_log = window, .include_content_size = known, .content_checksum = checksum };
                const encoded = try zstd.encodeFrameWithLevelAndOptionsAlloc(allocator, &input, -8, options);
                defer allocator.free(encoded);
                const header = try zstd.inspectNativeFrameHeader(encoded);
                try std.testing.expectEqual(checksum, header.has_checksum);
                try std.testing.expectEqual(if (known) @as(?u64, input.len) else null, header.content_size);
                try std.testing.expect(header.window_size <= @as(u64, 1) << window);
                try std.testing.expect(encoded.len <= try zstd.encodedFrameBoundWithLevelAndOptions(input.len, -8, options));
                if (checksum) try std.testing.expectEqual(@as(u32, @truncate(std.hash.XxHash64.hash(0, &input))), std.mem.readInt(u32, encoded[encoded.len - 4 ..][0..4], .little));
                if (header.window_size <= 128 * 1024) try fixtures.roundTrip(encoded, &input);
            }
        }
    }
    try std.testing.expectError(error.IntegerOverflow, zstd.encodedFrameBoundWithLevel(std.math.maxInt(usize), -1));
}

test "Zstd encode controls all engines honor external working peak and release every owned buffer" {
    const input = fixtures.lazyTrap();
    for (strategies) |strategy| {
        const options: zstd.NativeFrameOptions = .{ .strategy = strategy };
        var budget = working.WorkingAllocator.init(allocator, std.math.maxInt(usize));
        var output: [1024]u8 = @splat(0xa5);
        const baseline = try zstd.encodeNativeFrameIntoSlice(budget.allocator(), &input, options, &output);
        try std.testing.expectEqual(@as(usize, 0), budget.live);
        try fixtures.roundTrip(output[0..baseline.written], &input);
        const expected = try allocator.dupe(u8, output[0..baseline.written]);
        defer allocator.free(expected);
        const peak = budget.peak;
        try std.testing.expect(peak != 0);
        inline for (.{ false, true }) |below| {
            var limited = working.WorkingAllocator.init(allocator, peak - @intFromBool(below));
            @memset(&output, 0xa5);
            if (below) {
                try std.testing.expectError(error.OutOfMemory, zstd.encodeNativeFrameIntoSlice(limited.allocator(), &input, options, &output));
                try std.testing.expect(limited.last_failure_was_limit);
                try fixtures.sentinel(&output);
            } else {
                const encoded = try zstd.encodeNativeFrameIntoSlice(limited.allocator(), &input, options, &output);
                try std.testing.expectEqualSlices(u8, expected, output[0..encoded.written]);
                try std.testing.expectEqual(peak, limited.peak);
            }
            try std.testing.expectEqual(@as(usize, 0), limited.live);
            try std.testing.expect(limited.peak <= limited.limit);
        }
    }
}

fn AllocationCase(comptime strategy: controls.Strategy) type {
    return struct {
        pub fn run(gpa: std.mem.Allocator, input: []const u8, dictionary_bytes: []const u8) !void {
            var profile: controls.Profile = .{};
            const before = profile.emitted();
            var encoder = zstd.NativeFrameEncoder.init(gpa);
            defer encoder.deinit();
            var output: [1024]u8 = @splat(0xa5);
            const result = encoder.encodeIntoSliceWithDictionary(input, .{ .strategy = strategy, .include_content_size = false, .window_log = 17, .control_profile = &profile }, zstd.NativeDictionary.initRawContent(dictionary_bytes), &output) catch |err| {
                try fixtures.sentinel(&output);
                try std.testing.expectEqualDeep(before, profile.emitted());
                return err;
            };
            try std.testing.expect(profile.dictionary_sequences != 0);
            const decoded = try zstd.decodeNativeFrameAllocWithDictionary(allocator, output[0..result.written], zstd.NativeDictionary.initRawContent(dictionary_bytes));
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, input, decoded);
        }
    };
}
fn LevelAllocationCase() type {
    return struct {
        pub fn run(gpa: std.mem.Allocator, input: []const u8) !void {
            var out: std.ArrayList(u8) = .empty;
            defer out.deinit(gpa);
            try out.appendSlice(gpa, "prefix");
            var encoder = zstd.LevelFrameEncoder.init(gpa);
            defer encoder.deinit();
            var profile: controls.Profile = .{};
            const before = profile.emitted();
            _ = encoder.encodeAppendWithOptions(&out, input, -2, .{ .strategy = .double_fast, .control_profile = &profile }) catch |err| {
                try std.testing.expectEqualStrings("prefix", out.items);
                try std.testing.expectEqualDeep(before, profile.emitted());
                return err;
            };
            try fixtures.roundTrip(out.items[6..], input);
        }
    };
}

test "Zstd encode controls every allocation failure is caller atomic and rolls back emitted references" {
    const bytes = fixtures.dictionary();
    inline for (strategies) |strategy|
        try std.testing.checkAllAllocationFailures(allocator, AllocationCase(strategy).run, .{ bytes[16..528], bytes[0..] });
    const mixed = fixtures.legacyInput();
    try std.testing.checkAllAllocationFailures(allocator, LevelAllocationCase().run, .{mixed[0..]});
}

test "Zstd encode controls parallel seekable profiles merge privately deterministically and saturate" {
    const first = fixtures.legacyInput();
    const input = first ++ first;
    var serial_profile: controls.Profile = .{};
    var parallel_profile: controls.Profile = .{};
    var options: zstd.NativeSeekableOptions = .{
        .frame_size = 2048,
        .frame_options = .{ .strategy = .double_fast, .fast_acceleration = 2, .window_log = 13, .control_profile = &serial_profile },
        .seek_checksums = true,
    };
    const serial = try zstd.encodeNativeSeekableStreamAlloc(allocator, &input, options);
    defer allocator.free(serial);
    options.frame_options.control_profile = &parallel_profile;
    const parallel = try zstd.encodeNativeSeekableStreamParallelAlloc(allocator, &input, options, 3);
    defer allocator.free(parallel);
    try std.testing.expectEqualSlices(u8, serial, parallel);
    try std.testing.expectEqualDeep(serial_profile, parallel_profile);
    options.frame_options.control_profile = null;
    const unprofiled = try zstd.encodeNativeSeekableStreamParallelAlloc(allocator, &input, options, 3);
    defer allocator.free(unprofiled);
    try std.testing.expectEqualSlices(u8, serial, unprofiled);
    var saturated: controls.Profile = .{
        .positions_tested = std.math.maxInt(u64) - 1,
        .short_hash_probes = std.math.maxInt(u64) - 1,
        .raw_blocks = std.math.maxInt(u64),
        .rle_blocks = std.math.maxInt(u64),
        .compressed_blocks = std.math.maxInt(u64),
    };
    options.frame_options.control_profile = &saturated;
    const once = try zstd.encodeNativeSeekableStreamParallelAlloc(allocator, &input, options, 3);
    defer allocator.free(once);
    try std.testing.expectEqualSlices(u8, serial, once);
    try std.testing.expectEqual(std.math.maxInt(u64), saturated.positions_tested);
    try std.testing.expectEqual(std.math.maxInt(u64), saturated.short_hash_probes);
    try std.testing.expectEqual(std.math.maxInt(u64), saturated.raw_blocks);
    try std.testing.expectEqual(std.math.maxInt(u64), saturated.rle_blocks);
    try std.testing.expectEqual(std.math.maxInt(u64), saturated.compressed_blocks);
}
