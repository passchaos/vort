const std = @import("std");
const xz = @import("../../xz.zig");
const h = @import("test_helpers.zig");
const a = std.testing.allocator;

test "XZ parallel persistent ordered pool matches serial checks filters and parsers" {
    const input = try h.fixtureAlloc(a, 512, 13);
    defer a.free(input);
    const chain = [_]xz.Filter{ xz.Filter.x86(7), try xz.Filter.delta(4) };
    for ([_]xz.Check{ .none, .crc32, .crc64, .sha256 }) |check| {
        for ([_]xz.Parser{ .literal_only, .greedy, .lazy, .fast, .normal }) |parser| {
            errdefer std.debug.print("XZ parallel check={s} parser={s}\n", .{ @tagName(check), @tagName(parser) });
            var serial_work: xz.EncodeWorkProfile = .{};
            var parallel_work: xz.EncodeWorkProfile = .{};
            var opts = h.options();
            opts.check = check;
            opts.parser = parser;
            opts.filters = &chain;
            if (parser == .fast or parser == .normal) {
                opts.match_options.?.finder = if (parser == .normal) .bt4 else .hc4;
                opts.match_options.?.profile = &serial_work;
            } else opts.match_options = null;
            const serial = try xz.encodeAlloc(a, input, opts);
            defer a.free(serial);
            var profile: xz.ParallelProfile = .{};
            opts.parallel = h.parallel(&profile);
            if (opts.match_options) |*match| match.profile = &parallel_work;
            const actual = try xz.encodeAlloc(a, input, opts);
            defer a.free(actual);
            try std.testing.expectEqualSlices(u8, serial, actual);
            try h.checkWire(actual, input, opts);
            try h.complete(profile, 14, opts.parallel.?);
            if (h.threadedTarget()) {
                try std.testing.expect(!profile.serial_fallback);
                try std.testing.expectEqual(@as(usize, 2), profile.workers_started);
                try std.testing.expect(profile.peak_active_workers != 0);
            } else try std.testing.expect(profile.serial_fallback);
            if (opts.match_options != null) {
                try std.testing.expectEqualDeep(serial_work, parallel_work);
                try std.testing.expectEqual(@as(u64, input.len), parallel_work.literals + parallel_work.matched_bytes);
            }
        }
    }
}

test "XZ parallel alloc append Into Stored and Lazy share complete serial wire" {
    const input = try h.fixtureAlloc(a, 512, 9);
    defer a.free(input);
    for ([_]h.Api{ .compressed, .stored, .lazy }) |api| {
        var opts = h.options();
        const serial = try h.encodeAlloc(api, a, input, opts);
        defer a.free(serial);
        var profile: xz.ParallelProfile = .{};
        opts.parallel = h.parallel(&profile);
        const actual = try h.encodeAlloc(api, a, input, opts);
        defer a.free(actual);
        try std.testing.expectEqualSlices(u8, serial, actual);
        try h.checkWire(actual, input, opts);
        try h.complete(profile, 10, opts.parallel.?);
        const output = try a.alloc(u8, serial.len + 17);
        defer a.free(output);
        @memset(output, 0xa5);
        profile = .{};
        try std.testing.expectEqual(serial.len, try h.encodeInto(api, a, input, output[0..serial.len], opts));
        try std.testing.expectEqualSlices(u8, serial, output[0..serial.len]);
        try h.untouched(output[serial.len..]);
        try h.complete(profile, 10, opts.parallel.?);
        var appended = std.ArrayList(u8).fromOwnedSlice(try a.dupe(u8, "caller-prefix"));
        defer appended.deinit(a);
        profile = .{};
        try std.testing.expectEqual(serial.len, try h.encodeAppend(api, a, &appended, input, opts));
        try std.testing.expectEqualStrings("caller-prefix", appended.items[0..13]);
        try std.testing.expectEqualSlices(u8, serial, appended.items[13..]);
        try h.complete(profile, 10, opts.parallel.?);
    }
}

test "XZ parallel few slots and byte admission bound active ordered jobs" {
    const input = try h.fixtureAlloc(a, 512, 9);
    defer a.free(input);
    var opts = h.options();
    const serial = try xz.encodeAlloc(a, input, opts);
    defer a.free(serial);
    for ([_]struct { slots: usize, bytes: usize }{ .{ .slots = 2, .bytes = 1024 }, .{ .slots = 4, .bytes = 512 } }) |cap| {
        var profile: xz.ParallelProfile = .{};
        var parallel = h.parallel(&profile);
        parallel.worker_count = 4;
        parallel.max_inflight_blocks = cap.slots;
        parallel.max_inflight_bytes = cap.bytes;
        opts.parallel = parallel;
        const actual = try xz.encodeAlloc(a, input, opts);
        defer a.free(actual);
        try std.testing.expectEqualSlices(u8, serial, actual);
        try h.complete(profile, 10, parallel);
        try std.testing.expect(profile.peak_active_workers <= @min(cap.slots, cap.bytes / 512));
        if (!profile.serial_fallback) try std.testing.expect(profile.workers_started <= 4);
    }
}

test "XZ parallel empty single block and worker one use profiled serial fallback" {
    const multi = try h.fixtureAlloc(a, 64, 4);
    defer a.free(multi);
    for ([_][]const u8{ "", "single block", multi }) |input| {
        var opts = h.options();
        opts.block_size = if (input.ptr == multi.ptr) 64 else 512;
        const serial = try xz.encodeAlloc(a, input, opts);
        defer a.free(serial);
        var profile: xz.ParallelProfile = .{};
        opts.parallel = h.parallel(&profile);
        if (input.ptr == multi.ptr) opts.parallel.?.worker_count = 1;
        const actual = try xz.encodeAlloc(a, input, opts);
        defer a.free(actual);
        try std.testing.expectEqualSlices(u8, serial, actual);
        try std.testing.expect(profile.serial_fallback);
        try std.testing.expectEqual(@as(usize, 0), profile.workers_started);
        try h.complete(profile, h.blockCount(input.len, opts.block_size), opts.parallel.?);
    }
}

test "XZ parallel all twenty presets preserve serial parameters and complete wire" {
    const input = try h.fixtureAlloc(a, 128, 8);
    defer a.free(input);
    for (0..10) |level| {
        for ([_]bool{ false, true }) |extreme| {
            errdefer std.debug.print("XZ parallel preset level={d} extreme={any}\n", .{ level, extreme });
            var opts = try xz.EncodeOptions.fromPreset(@intCast(level), extreme);
            opts.block_size = 128;
            opts.chunk_size = 128;
            const serial = try xz.encodeAlloc(a, input, opts);
            defer a.free(serial);
            var profile: xz.ParallelProfile = .{};
            opts.parallel = h.parallel(&profile);
            const actual = try xz.encodeAlloc(a, input, opts);
            defer a.free(actual);
            try std.testing.expectEqualSlices(u8, serial, actual);
            try h.checkWire(actual, input, opts);
            try h.complete(profile, 9, opts.parallel.?);
            if (h.threadedTarget()) try std.testing.expectEqual(@as(usize, 2), profile.workers_started);
        }
    }
}
