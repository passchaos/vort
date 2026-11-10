const std = @import("std");
const budget = @import("../total_budget.zig");
const Counting = @import("counting_allocator.zig").CountingAllocator;
const allocator = std.testing.allocator;
const payload = "deflate budget: repeated text; entropy models and dictionary history.\n" ** 48;
const dictionary = "dictionary history.\ndeflate budget: repeated text; entropy models and ";
const Mode = enum { fixed, dynamic, best, split, adaptive, dictionary_fixed, dictionary_dynamic, dictionary_best, dictionary_split, dictionary_adaptive };
const Wrapper = enum { raw, zlib, gzip };

fn encode(comptime C: type, a: std.mem.Allocator, bytes: []const u8, options: C.CompressionOptions, mode: Mode, wrapper: Wrapper) ![]u8 {
    const split: C.AdaptiveSplitOptions = .{ .min_block_len = 256, .max_block_len = 1024, .sample_len = 128, .search_step = 256 };
    return switch (wrapper) {
        .raw => switch (mode) {
            .fixed => C.encodeRawFixedWithOptionsAlloc(a, bytes, options),
            .dynamic => C.encodeRawDynamicWithOptionsAlloc(a, bytes, options),
            .best => C.encodeRawBestAlloc(a, bytes, options),
            .split => C.encodeRawBestSplitAlloc(a, bytes, 512, options),
            .adaptive => C.encodeRawBestAdaptiveSplitAlloc(a, bytes, options, split),
            .dictionary_fixed => C.encodeRawFixedWithDictionaryAlloc(a, bytes, dictionary, options),
            .dictionary_dynamic => C.encodeRawDynamicWithDictionaryAlloc(a, bytes, dictionary, options),
            .dictionary_best => C.encodeRawBestWithDictionaryAlloc(a, bytes, dictionary, options),
            .dictionary_split => C.encodeRawBestSplitWithDictionaryAlloc(a, bytes, dictionary, 512, options),
            .dictionary_adaptive => C.encodeRawBestAdaptiveSplitWithDictionaryAlloc(a, bytes, dictionary, options, split),
        },
        .zlib => switch (mode) {
            .fixed => C.encodeZlibFixedWithOptionsAlloc(a, bytes, options),
            .dynamic => C.encodeZlibDynamicWithOptionsAlloc(a, bytes, options),
            .best => C.encodeZlibBestAlloc(a, bytes, options),
            .split => C.encodeZlibBestSplitAlloc(a, bytes, 512, options),
            .adaptive => C.encodeZlibBestAdaptiveSplitAlloc(a, bytes, options, split),
            .dictionary_fixed => C.encodeZlibFixedWithDictionaryAlloc(a, bytes, dictionary, options),
            .dictionary_dynamic => C.encodeZlibDynamicWithDictionaryAlloc(a, bytes, dictionary, options),
            .dictionary_best => C.encodeZlibBestWithDictionaryAlloc(a, bytes, dictionary, options),
            .dictionary_split => C.encodeZlibBestSplitWithDictionaryAlloc(a, bytes, dictionary, 512, options),
            .dictionary_adaptive => C.encodeZlibBestAdaptiveSplitWithDictionaryAlloc(a, bytes, dictionary, options, split),
        },
        .gzip => switch (mode) {
            .fixed, .dictionary_fixed => C.encodeGzipFixedWithHeaderAlloc(a, bytes, options, .{ .filename = "budget.txt", .header_crc = true }),
            .dynamic, .dictionary_dynamic => C.encodeGzipDynamicWithHeaderAlloc(a, bytes, options, .{ .filename = "budget.txt", .header_crc = true }),
            .best, .dictionary_best => C.encodeGzipBestWithHeaderAlloc(a, bytes, options, .{ .filename = "budget.txt", .header_crc = true }),
            .split, .dictionary_split => C.encodeGzipBestSplitWithHeaderAlloc(a, bytes, 512, options, .{ .filename = "budget.txt", .header_crc = true }),
            .adaptive, .dictionary_adaptive => C.encodeGzipBestAdaptiveSplitWithHeaderAlloc(a, bytes, options, split, .{ .filename = "budget.txt", .header_crc = true }),
        },
    };
}

fn exact(comptime C: type, bytes: []const u8, original: C.CompressionOptions, mode: Mode, wrapper: Wrapper) !void {
    const plain = try encode(C, allocator, bytes, original, mode, wrapper);
    defer allocator.free(plain);
    var count: Counting = .{ .backing = allocator };
    var profile: C.EncodeMemoryProfile = .{};
    var options = original;
    options.memory_profile = &profile;
    const observed = try encode(C, count.allocator(), bytes, options, mode, wrapper);
    try std.testing.expectEqualSlices(u8, plain, observed);
    try std.testing.expectEqual(count.peak, profile.peak_requested_bytes);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    try std.testing.expectEqual(observed.len, count.live);
    count.allocator().free(observed);
    try std.testing.expectEqual(@as(usize, 0), count.live);
    const required = profile.peak_requested_bytes;
    profile.reset();
    options.max_total_working_memory = required;
    const accepted = try encode(C, allocator, bytes, options, mode, wrapper);
    defer allocator.free(accepted);
    try std.testing.expectEqualSlices(u8, plain, accepted);
    try std.testing.expectEqual(required, profile.peak_requested_bytes);
    profile.reset();
    options.max_total_working_memory = required - 1;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, encode(C, allocator, bytes, options, mode, wrapper));
    try std.testing.expect(profile.peak_requested_bytes <= required - 1);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
}

fn Failure(comptime C: type) type {
    return struct {
        fn run(a: std.mem.Allocator) !void {
            var profile: C.EncodeMemoryProfile = .{};
            var options = try C.optionsForZlibLevel(8);
            options.memory_profile = &profile;
            const bytes = try C.encodeRawBestAlloc(a, payload, options);
            a.free(bytes);
        }
    };
}

pub fn contracts(comptime C: type) !void {
    try @import("reusable_refusal_tests.zig").contracts(C);
    const options = try C.optionsForZlibLevel(8);
    inline for (std.meta.tags(Wrapper)) |wrapper| {
        inline for (std.meta.tags(Mode)) |mode| try exact(C, payload, options, mode, wrapper);
    }
    // Exercise the large-input refined-history candidate where failed allocation
    // historically discarded a candidate. Small repeated data bounds test time.
    try exact(C, "abacabadabacaba " ** 4600, options, .best, .raw);
    try appendAndScratch(C);
    try exactAppend(C);
    inline for (.{ C.RawDeflateEncoder, C.ZlibEncoder, C.GzipEncoder }) |Owner| try warmOwner(C, Owner);
    inline for (.{ C.CompressionStrategy.filtered, C.CompressionStrategy.huffman_only, C.CompressionStrategy.rle }) |strategy| {
        var specialized = options;
        specialized.strategy = strategy;
        try exact(C, payload, specialized, .best, .raw);
    }
    inline for (.{ "", "x", "tiny deflate payload" }) |tiny| try exact(C, tiny, options, .best, .raw);
    try frameContracts(C);
    try warmFrame(C);
    try inheritedContracts(C);
    try refusals(C);
    try historyCandidateOom(C);
    try scalarPreflight(C);
    var stats_profile: C.EncodeMemoryProfile = .{};
    var stats_count: Counting = .{ .backing = allocator };
    const stats = try C.dynamicPlanStatsAlloc(stats_count.allocator(), payload, .{ .memory_profile = &stats_profile });
    const default_stats = try C.dynamicPlanStatsAlloc(allocator, payload, .{});
    try std.testing.expectEqualDeep(default_stats, stats);
    try std.testing.expectEqual(stats_count.peak, stats_profile.peak_requested_bytes);
    try std.testing.expectEqual(@as(usize, 0), stats_count.live);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, C.dynamicPlanStatsAlloc(allocator, payload, .{ .max_total_working_memory = stats_profile.peak_requested_bytes - 1 }));
    try std.testing.checkAllAllocationFailures(allocator, Failure(C).run, .{});
}

fn appendAndScratch(comptime C: type) !void {
    var count: Counting = .{ .backing = allocator };
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(count.allocator());
    try output.appendSlice(count.allocator(), "prefix");
    var profile: C.EncodeMemoryProfile = .{};
    var options = try C.optionsForZlibLevel(3);
    options.memory_profile = &profile;
    _ = try C.encodeZlibBestAppend(count.allocator(), &output, payload, options);
    try std.testing.expectEqual(count.peak, profile.peak_requested_bytes);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    output.shrinkRetainingCapacity(6);
    options.max_total_working_memory = output.capacity + budget.control_bytes - 1;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, C.encodeZlibBestAppend(count.allocator(), &output, payload, options));
    try std.testing.expectEqualSlices(u8, "prefix", output.items);
    var owner = C.RawDeflateEncoder.init(count.allocator());
    defer owner.deinit();
    const old = try owner.encodeBestScratch(payload, .{ .parser = .hash });
    const saved = try allocator.dupe(u8, old);
    defer allocator.free(saved);
    profile.reset();
    options.max_total_working_memory = owner.scratch.capacity + budget.control_bytes - 1;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, owner.encodeBestScratch("different plaintext", options));
    try std.testing.expectEqualSlices(u8, saved, owner.scratch.items);
    try std.testing.expectEqual(owner.scratch.capacity, profile.peak_requested_bytes);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    profile.reset();
    options.max_total_working_memory = null;
    count.peak = count.live;
    _ = try owner.encodeBestScratch(payload, options);
    // The other retained output list belongs to caller and is not used by this
    // operation. Independent peak subtracts that unrelated list's capacity.
    try std.testing.expectEqual(count.peak - output.capacity, profile.peak_requested_bytes);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
}

fn frameContracts(comptime C: type) !void {
    inline for (std.meta.tags(C.ZlibEncodeMode)) |mode| {
        inline for (.{ @as(u8, 9), @as(u8, 15) }) |bits| {
            var options: C.ZlibEncodeOptions = .{ .mode = mode, .window_bits = bits, .dictionary = dictionary };
            const plain = try C.encodeZlibFrameAlloc(allocator, payload, options);
            defer allocator.free(plain);
            var count: Counting = .{ .backing = allocator };
            var profile: C.EncodeMemoryProfile = .{};
            options.memory_profile = &profile;
            const observed = try C.encodeZlibFrameAlloc(count.allocator(), payload, options);
            try std.testing.expectEqualSlices(u8, plain, observed);
            try std.testing.expectEqual(count.peak, profile.peak_requested_bytes);
            count.allocator().free(observed);
            const required = profile.peak_requested_bytes;
            options.max_total_working_memory = required;
            const accepted = try C.encodeZlibFrameAlloc(allocator, payload, options);
            allocator.free(accepted);
            options.max_total_working_memory = required - 1;
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, C.encodeZlibFrameAlloc(allocator, payload, options));
        }
    }
    var profile: C.EncodeMemoryProfile = .{};
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    var output: [8192]u8 = @splat(0xc7);
    const options: C.ZlibEncodeOptions = .{ .mode = .stored, .max_total_working_memory = 0, .memory_profile = &profile };
    _ = try C.encodeZlibFrameInto(failing.allocator(), payload, &output, options);
    try std.testing.expectEqual(@as(usize, 0), profile.peak_requested_bytes);
    try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
    var owner = try C.ZlibFrameEncoder.init(failing.allocator(), options);
    defer owner.deinit();
    _ = try owner.encodeStoredChunksInto(&.{ payload[0..100], payload[100..] }, &output);
    try std.testing.expectEqual(@as(usize, 0), profile.peak_requested_bytes);
    var second_profile: C.EncodeMemoryProfile = .{};
    try std.testing.expectError(error.InvalidBlockPlan, C.ZlibFrameEncoder.init(allocator, .{ .max_total_working_memory = 1000, .compression = .{ .max_total_working_memory = 999 } }));
    try std.testing.expectError(error.InvalidBlockPlan, C.ZlibFrameEncoder.init(allocator, .{ .memory_profile = &profile, .compression = .{ .memory_profile = &second_profile } }));
    // Same nested settings resolve into one policy; nested-only must govern stored.
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, C.encodeZlibFrameAlloc(allocator, payload, .{ .mode = .stored, .compression = .{ .max_total_working_memory = 0 } }));
    @memset(&output, 0xc7);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, C.encodeZlibFrameInto(allocator, payload, &output, .{ .mode = .best, .max_total_working_memory = 0 }));
    try std.testing.expect(std.mem.allEqual(u8, &output, 0xc7));
}

fn inheritedContracts(comptime C: type) !void {
    var profile: C.EncodeMemoryProfile = .{};
    var lease = try budget.Lease.init(allocator, null, &profile, 0);
    const before = profile.live_requested_bytes;
    const wire = try C.encodeZlibBestAlloc(lease.allocator(), payload, .{});
    try std.testing.expectEqual(before + wire.len, profile.live_requested_bytes);
    lease.allocator().free(wire);
    try std.testing.expectEqual(before, profile.live_requested_bytes);
    var stored: [8192]u8 = undefined;
    _ = try C.encodeZlibFrameInto(lease.allocator(), payload, &stored, .{ .mode = .stored, .memory_profile = &profile });
    try std.testing.expectEqual(before, profile.live_requested_bytes);
    try std.testing.expectError(error.InvalidBlockPlan, C.encodeZlibBestAlloc(lease.allocator(), payload, .{ .max_total_working_memory = 1 }));
    lease.deinit();
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
}

fn refusals(comptime C: type) !void {
    var profile: C.EncodeMemoryProfile = .{};
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutOfMemory, C.encodeRawBestAlloc(failing.allocator(), payload, .{ .memory_profile = &profile }));
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, C.encodeRawBestAlloc(failing.allocator(), payload, .{ .max_total_working_memory = 0 }));
    var sync = C.RawFixedSyncFlushEncoder.init(allocator);
    defer sync.deinit();
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    try output.appendSlice(allocator, "prefix");
    try std.testing.expectError(error.InvalidBlockPlan, sync.encodeAppend(&output, payload, .{ .memory_profile = &profile }));
    try std.testing.expectEqualSlices(u8, "prefix", output.items);
    var raw = C.RawDeflateIncrementalBestEncoder.initWithOptions(allocator, .{ .compression = .{ .max_total_working_memory = 0 } });
    defer raw.deinit();
    var bytes: [64]u8 = @splat(0xaf);
    try std.testing.expectError(error.InvalidBlockPlan, raw.step(payload, &bytes));
    try std.testing.expect(std.mem.allEqual(u8, &bytes, 0xaf));
    raw.done = true;
    try std.testing.expectError(error.InvalidBlockPlan, raw.step("", &bytes));
    inline for (.{ C.ZlibIncrementalBestEncoder, C.GzipIncrementalBestEncoder }) |WrapperEncoder| {
        var wrapper = WrapperEncoder.initWithOptions(allocator, .{ .raw = .{ .compression = .{ .memory_profile = &profile } } });
        defer wrapper.deinit();
        try std.testing.expectError(error.InvalidBlockPlan, wrapper.step(payload, &bytes));
        try std.testing.expect(std.mem.allEqual(u8, &bytes, 0xaf));
        wrapper.raw.options.compression.memory_profile = null;
        wrapper.options.raw.compression.memory_profile = null;
        wrapper.options.raw.compression.max_total_working_memory = 0;
        wrapper.done = true;
        try std.testing.expectError(error.InvalidBlockPlan, wrapper.step("", &bytes));
    }
}

fn appendWire(comptime C: type, a: std.mem.Allocator, output: *std.ArrayList(u8), options: C.CompressionOptions, wrapper: Wrapper) !usize {
    return switch (wrapper) {
        .raw => C.encodeRawBestAppend(a, output, payload, options),
        .zlib => C.encodeZlibBestAppend(a, output, payload, options),
        .gzip => C.encodeGzipBestWithHeaderAppend(a, output, payload, options, .{ .filename = "budget.txt", .header_crc = true }),
    };
}

fn exactAppend(comptime C: type) !void {
    inline for (std.meta.tags(Wrapper)) |wrapper| {
        var count: Counting = .{ .backing = allocator };
        var observed: std.ArrayList(u8) = .empty;
        try observed.appendSlice(count.allocator(), "prefix");
        var profile: C.EncodeMemoryProfile = .{};
        var options = try C.optionsForZlibLevel(8);
        options.memory_profile = &profile;
        _ = try appendWire(C, count.allocator(), &observed, options, wrapper);
        try std.testing.expectEqual(count.peak, profile.peak_requested_bytes);
        const required = profile.peak_requested_bytes;
        inline for (.{ false, true }) |deny| {
            var output: std.ArrayList(u8) = .empty;
            defer output.deinit(allocator);
            try output.appendSlice(allocator, "prefix");
            profile.reset();
            options.max_total_working_memory = required - @intFromBool(deny);
            if (deny) {
                try std.testing.expectError(error.WorkingMemoryLimitExceeded, appendWire(C, allocator, &output, options, wrapper));
                try std.testing.expectEqualSlices(u8, "prefix", output.items);
            } else {
                _ = try appendWire(C, allocator, &output, options, wrapper);
                try std.testing.expectEqualSlices(u8, observed.items, output.items);
            }
            try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
        }
        observed.deinit(count.allocator());
        try std.testing.expectEqual(@as(usize, 0), count.live);
    }
    inline for (.{ false, true }) |chunks| {
        var count: Counting = .{ .backing = allocator };
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(count.allocator());
        try output.appendSlice(count.allocator(), "prefix");
        var profile: C.EncodeMemoryProfile = .{};
        const options: C.CompressionOptions = .{ .parser = .hash, .memory_profile = &profile };
        if (chunks) {
            const other = try allocator.dupe(u8, payload[1000..]);
            defer allocator.free(other);
            _ = try C.encodeRawFixedSyncFlushChunksAppend(count.allocator(), &output, &.{ payload[0..1000], other }, options);
        } else _ = try C.encodeRawFixedSyncFlushAppend(count.allocator(), &output, payload, options);
        try std.testing.expectEqual(count.peak, profile.peak_requested_bytes);
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
        output.shrinkRetainingCapacity(6);
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, C.encodeRawFixedSyncFlushAppend(count.allocator(), &output, payload, .{ .max_total_working_memory = output.capacity + budget.control_bytes }));
        try std.testing.expectEqualSlices(u8, "prefix", output.items);
    }
}

fn warmOwner(comptime C: type, comptime Owner: type) !void {
    var count: Counting = .{ .backing = allocator };
    var owner = Owner.init(count.allocator());
    var options = try C.optionsForZlibLevel(3);
    const old = try owner.encodeBestScratch(payload, options);
    const expected = try allocator.dupe(u8, old);
    defer allocator.free(expected);
    var profile: C.EncodeMemoryProfile = .{};
    options.memory_profile = &profile;
    count.peak = count.live;
    const observed = try owner.encodeBestScratch(payload, options);
    try std.testing.expectEqualSlices(u8, expected, observed);
    try std.testing.expectEqual(count.peak, profile.peak_requested_bytes);
    const required = profile.peak_requested_bytes;
    options.max_total_working_memory = required;
    _ = try owner.encodeBestScratch(payload, options);
    options.max_total_working_memory = required - 1;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, owner.encodeBestScratch(payload, options));
    try std.testing.expectEqualSlices(u8, expected, owner.scratch.items);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    owner.deinit();
    try std.testing.expectEqual(@as(usize, 0), count.live);
}

fn warmFrame(comptime C: type) !void {
    var count: Counting = .{ .backing = allocator };
    var options: C.ZlibEncodeOptions = .{ .window_bits = 9, .mode = .best, .compression = try C.optionsForZlibLevel(3) };
    var owner = try C.ZlibFrameEncoder.init(count.allocator(), options);
    const old = try owner.encodeScratch(payload);
    const expected = try allocator.dupe(u8, old);
    defer allocator.free(expected);
    var profile: C.EncodeMemoryProfile = .{};
    options.memory_profile = &profile;
    count.peak = count.live;
    try owner.setOptions(options);
    _ = try owner.encodeScratch(payload);
    try std.testing.expectEqual(count.peak, profile.peak_requested_bytes);
    const required = profile.peak_requested_bytes;
    options.max_total_working_memory = required;
    try owner.setOptions(options);
    _ = try owner.encodeScratch(payload);
    options.max_total_working_memory = required - 1;
    try owner.setOptions(options);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, owner.encodeScratch(payload));
    try std.testing.expectEqualSlices(u8, expected, owner.scratch.items);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    options.mode = .stored;
    options.max_total_working_memory = 0;
    profile.reset();
    try owner.setOptions(options);
    var untouched: [8192]u8 = @splat(0x93);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, owner.encodeInto(payload, &untouched));
    try std.testing.expect(std.mem.allEqual(u8, &untouched, 0x93));
    try std.testing.expectEqual(owner.scratch.capacity, profile.peak_requested_bytes);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, owner.encodeStoredChunksInto(&.{ payload[0..100], payload[100..] }, &untouched));
    try std.testing.expect(std.mem.allEqual(u8, &untouched, 0x93));
    owner.deinit();
    try std.testing.expectEqual(@as(usize, 0), count.live);

    // The legacy literal-only/PNG/stored backends do not accept compression
    // options. The outer frame ledger must still cover every allocation.
    inline for (.{ C.ZlibEncodeMode.dynamic_literal, C.ZlibEncodeMode.png_ultrafast, C.ZlibEncodeMode.stored }) |mode| {
        var clean_count: Counting = .{ .backing = allocator };
        profile.reset();
        const wire = try C.encodeZlibFrameAlloc(clean_count.allocator(), payload, .{ .mode = mode, .memory_profile = &profile });
        try std.testing.expectEqual(clean_count.peak, profile.peak_requested_bytes);
        clean_count.allocator().free(wire);
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, C.encodeZlibFrameAlloc(allocator, payload, .{ .mode = mode, .max_total_working_memory = profile.peak_requested_bytes - 1 }));
    }
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    try output.appendSlice(allocator, "prefix");
    var stored_owner = try C.ZlibFrameEncoder.init(allocator, .{ .mode = .stored, .max_total_working_memory = output.capacity + budget.control_bytes });
    defer stored_owner.deinit();
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, stored_owner.encodeStoredChunksAppend(&output, &.{ payload[0..100], payload[100..] }));
    try std.testing.expectEqualSlices(u8, "prefix", output.items);
    // Matching top/nested zero controls succeed through the direct no-heap path.
    var direct_output: [8192]u8 = undefined;
    _ = try C.encodeZlibFrameInto(allocator, payload, &direct_output, .{
        .mode = .stored,
        .max_total_working_memory = 0,
        .memory_profile = &profile,
        .compression = .{ .max_total_working_memory = 0, .memory_profile = &profile },
    });
}

fn scalarPreflight(comptime C: type) !void {
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    var profile: C.EncodeMemoryProfile = .{};
    const options: C.CompressionOptions = .{ .max_total_working_memory = 0, .memory_profile = &profile };
    try std.testing.expectError(error.InvalidBlockPlan, C.encodeRawBestSplitAlloc(failing.allocator(), payload, 0, options));
    try std.testing.expectError(error.InvalidBlockPlan, C.encodeRawFixedSplitAlloc(failing.allocator(), payload, 0, options));
    try std.testing.expectError(error.InvalidBlockPlan, C.encodeRawDynamicSplitAlloc(failing.allocator(), payload, 0, options));
    try std.testing.expectError(error.InvalidBlockPlan, C.encodeRawBestAdaptiveSplitAlloc(failing.allocator(), payload, options, .{ .min_block_len = 0 }));
    var output: std.ArrayList(u8) = .empty;
    try std.testing.expectError(error.InvalidBlockPlan, C.encodeZlibBestSplitAppend(failing.allocator(), &output, payload, 0, options));
    var owner = C.RawDeflateEncoder.init(failing.allocator());
    defer owner.deinit();
    try std.testing.expectError(error.InvalidBlockPlan, owner.encodeBestSplitScratch(payload, 0, options));
    var frame: [8192]u8 = @splat(0x92);
    try std.testing.expectError(error.InvalidBlockPlan, C.encodeZlibFrameInto(failing.allocator(), payload, &frame, .{ .block_len = 0, .max_total_working_memory = 0, .memory_profile = &profile }));
    try std.testing.expect(std.mem.allEqual(u8, &frame, 0x92));
    try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
    try std.testing.expect(!profile.available);
}

fn historyCandidateOom(comptime C: type) !void {
    const large = "abacabadabacaba " ** 4600;
    const original = try C.optionsForZlibLevel(8);
    // The 32-KiB counts allocation belongs to the first refined-history
    // candidate. It is after the original complete one-shot wire exists.
    var default_count: Counting = .{ .backing = allocator, .reject_allocation_size = 32 * 1024 };
    const old_fallback = try C.encodeRawBestAlloc(default_count.allocator(), large, original);
    try std.testing.expect(default_count.rejected != 0);
    default_count.allocator().free(old_fallback);
    try std.testing.expectEqual(@as(usize, 0), default_count.live);
    var tracked_count: Counting = .{ .backing = allocator, .reject_allocation_size = 32 * 1024 };
    var profile: C.EncodeMemoryProfile = .{};
    var instrumented = original;
    instrumented.memory_profile = &profile;
    try std.testing.expectError(error.OutOfMemory, C.encodeRawBestAlloc(tracked_count.allocator(), large, instrumented));
    try std.testing.expect(tracked_count.rejected != 0);
    try std.testing.expectEqual(@as(usize, 0), tracked_count.live);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
}
