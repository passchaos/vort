const std = @import("std");
const br = @import("../br.zig");
const h = @import("br_stored_memory_helpers.zig");

test "Brotli stored memory default wires preserve archived contiguous chunks empty reusable and incremental formats" {
    const a = std.testing.allocator;
    const chunks = h.chunks();
    for (h.frozen_wires) |sample| {
        var options = h.options(sample.setting);
        if (sample.api == .empty) options.metadata = "";
        const actual = switch (sample.api) {
            .contiguous => try br.encodeStoredStreamWithOptionsAlloc(a, h.plain, options),
            .chunks => try br.encodeStoredStreamChunksWithOptionsAlloc(a, &chunks, options),
            .empty => try br.encodeStoredStreamWithOptionsAlloc(a, "", options),
            .reusable => blk: {
                var encoder = br.StoredStreamEncoder.init(a);
                defer encoder.deinit();
                break :blk try a.dupe(u8, try encoder.encodeScratchWithOptions(h.plain, options));
            },
            .incremental => blk: {
                var encoder = br.IncrementalStoredStreamEncoder.initWithOptions(a, .{ .stream = options });
                defer encoder.deinit();
                break :blk try h.drive(a, &encoder, h.plain, 31, 17);
            },
        };
        defer a.free(actual);
        try h.expectWire(actual, sample.setting, sample.api);
        try h.decode(actual, if (sample.api == .empty) "" else h.plain, options.large_window);
    }
}

test "Brotli stored memory all complete input output forms preserve frozen wires with instrumentation" {
    const a = std.testing.allocator;
    const chunks = h.chunks();
    for (std.enums.values(h.Setting)) |setting| {
        var profile: br.EncodeMemoryProfile = .{};
        var options = h.options(setting);
        options.memory_profile = &profile;
        for ([_]bool{ false, true }) |chunked| {
            const api: h.Api = if (chunked) .chunks else .contiguous;
            const expected = try h.frozenAlloc(a, h.frozen(setting, api));
            defer a.free(expected);
            var output: [512]u8 = @splat(0xa5);
            const written = if (chunked)
                try br.encodeStoredStreamChunksWithOptionsInto(&chunks, &output, options)
            else
                try br.encodeStoredStreamWithOptionsInto(h.plain, &output, options);
            try std.testing.expectEqualSlices(u8, expected, output[0..written]);
            try h.untouched(output[written..]);
            try std.testing.expect(profile.available);
            var appended: std.ArrayList(u8) = .empty;
            defer appended.deinit(a);
            try appended.appendSlice(a, "prefix|");
            if (chunked) try br.encodeStoredStreamChunksWithOptionsAppend(a, &appended, &chunks, options) else try br.encodeStoredStreamWithOptionsAppend(a, &appended, h.plain, options);
            try std.testing.expectEqualSlices(u8, "prefix|", appended.items[0..7]);
            try std.testing.expectEqualSlices(u8, expected, appended.items[7..]);
            var encoder = br.StoredStreamEncoder.init(a);
            defer encoder.deinit();
            const owned = if (chunked) try encoder.encodeChunksWithOptionsAlloc(&chunks, options) else try encoder.encodeWithOptionsAlloc(h.plain, options);
            defer a.free(owned);
            try std.testing.expectEqualSlices(u8, expected, owned);
            const scratch = if (chunked) try encoder.encodeChunksScratchWithOptions(&chunks, options) else try encoder.encodeScratchWithOptions(h.plain, options);
            try std.testing.expectEqualSlices(u8, expected, scratch);
            @memset(&output, 0xa5);
            const reused_len = if (chunked) try encoder.encodeChunksWithOptionsIntoSlice(&chunks, options, &output) else try encoder.encodeWithOptionsIntoSlice(h.plain, options, &output);
            try std.testing.expectEqualSlices(u8, expected, output[0..reused_len]);
            try h.untouched(output[reused_len..]);
            appended.clearRetainingCapacity();
            if (chunked) try encoder.encodeChunksWithOptionsAppend(&appended, &chunks, options) else try encoder.encodeWithOptionsAppend(&appended, h.plain, options);
            try std.testing.expectEqualSlices(u8, expected, appended.items);
        }
    }
}

test "Brotli stored memory default null policy adds no control allocation and boundary wires remain archived" {
    var tracked = h.TrackingAllocator.init(std.testing.allocator);
    const a = tracked.allocator();
    const wire = try br.encodeStoredStreamAlloc(a, h.plain);
    try std.testing.expectEqual(@as(usize, 1), tracked.alloc_attempts);
    try std.testing.expectEqual(wire.len, tracked.peak);
    a.free(wire);
    const input = h.boundaryInput();
    for (h.frozen_boundary) |sample| {
        const actual = if (sample.incremental) blk: {
            var encoder = br.IncrementalStoredStreamEncoder.init(a);
            defer encoder.deinit();
            const bytes = try h.drive(std.testing.allocator, &encoder, &input, 31, 17);
            try std.testing.expect(!encoder.memorySnapshot().available);
            break :blk bytes;
        } else try br.encodeStoredStreamAlloc(std.testing.allocator, &input);
        defer std.testing.allocator.free(actual);
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(actual, &digest, .{});
        const hex = std.fmt.bytesToHex(digest, .lower);
        try std.testing.expectEqual(sample.len, actual.len);
        try std.testing.expectEqualSlices(u8, sample.sha256, &hex);
        try h.decode(actual, &input, false);
    }
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
}

test "Brotli stored memory nonalias Into is a zero heap path for metadata chunks empty and LargeWindow" {
    const chunks = h.chunks();
    for (std.enums.values(h.Setting)) |setting| {
        for ([_]bool{ false, true }) |chunked| {
            var profile: br.EncodeMemoryProfile = .{};
            var options = h.options(setting);
            options.max_total_working_memory = 0;
            options.memory_profile = &profile;
            var output: [512]u8 = @splat(0xa5);
            const written = if (chunked) try br.encodeStoredStreamChunksWithOptionsInto(&chunks, &output, options) else try br.encodeStoredStreamWithOptionsInto(h.plain, &output, options);
            try h.expectWire(output[0..written], setting, if (chunked) .chunks else .contiguous);
            try h.untouched(output[written..]);
            try std.testing.expect(profile.available);
            try std.testing.expectEqual(@as(?usize, 0), profile.limit);
            try std.testing.expectEqual(@as(usize, 0), profile.peak_requested_bytes);
            try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
            options.metadata = "";
            const empty_len = try br.encodeStoredStreamWithOptionsInto("", &output, options);
            try h.expectWire(output[0..empty_len], setting, .empty);
            profile.reset();
            options.max_total_working_memory = null;
            _ = try br.encodeStoredStreamWithOptionsInto(h.plain, &output, options);
            try std.testing.expect(profile.available);
            try std.testing.expectEqual(@as(?usize, null), profile.limit);
            try std.testing.expectEqual(@as(usize, 0), profile.peak_requested_bytes);
            try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
            var tracked = h.TrackingAllocator.init(std.testing.allocator);
            tracked.fail_alloc_after = 0;
            var fresh = br.StoredStreamEncoder.init(tracked.allocator());
            defer fresh.deinit();
            profile.reset();
            options = h.options(setting);
            options.max_total_working_memory = 0;
            options.memory_profile = &profile;
            const fresh_len = if (chunked) try fresh.encodeChunksWithOptionsIntoSlice(&chunks, options, &output) else try fresh.encodeWithOptionsIntoSlice(h.plain, options, &output);
            try h.expectWire(output[0..fresh_len], setting, if (chunked) .chunks else .contiguous);
            try std.testing.expect(profile.available);
            try std.testing.expectEqual(@as(usize, 0), profile.peak_requested_bytes);
            try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
            try std.testing.expectEqual(@as(usize, 0), tracked.alloc_attempts);
        }
    }
}

test "Brotli stored memory invalid bounds and short destinations reject before allocator or caller writes" {
    var tracked = h.TrackingAllocator.init(std.testing.allocator);
    tracked.fail_alloc_after = 0;
    var profile: br.EncodeMemoryProfile = .{};
    const invalid: br.StoredStreamOptions = .{ .window_bits = 9, .max_total_working_memory = 0, .memory_profile = &profile };
    var output: [512]u8 = @splat(0xa5);
    try std.testing.expectError(error.InvalidBlockPlan, br.encodeStoredStreamWithOptionsAlloc(tracked.allocator(), h.plain, invalid));
    try std.testing.expectError(error.InvalidBlockPlan, br.encodeStoredStreamWithOptionsInto(h.plain, &output, invalid));
    try std.testing.expectEqual(@as(usize, 0), tracked.alloc_attempts);
    const needed = try br.encodedStoredStreamBoundWithOptions(h.plain.len, .{});
    try std.testing.expectError(error.OutOfMemory, br.encodeStoredStreamWithOptionsInto(h.plain, output[0 .. needed - 1], .{ .max_total_working_memory = 0, .memory_profile = &profile }));
    try h.untouched(&output);
    const chunks = h.chunks();
    const chunks_needed = try br.encodedStoredStreamChunksBoundWithOptions(&chunks, .{});
    try std.testing.expectError(error.OutOfMemory, br.encodeStoredStreamChunksWithOptionsInto(&chunks, output[0 .. chunks_needed - 1], .{}));
    try h.untouched(&output);
}
