const std = @import("std");

const Policy = enum { zero_cap, unlimited_cap, profile, both };

fn options(comptime B: type, policy: Policy, profile: *B.DecodeMemoryProfile) B.DecodeOptions {
    return .{
        .max_total_working_memory = switch (policy) {
            .zero_cap, .both => 0,
            .unlimited_cap => std.math.maxInt(usize),
            .profile => null,
        },
        .memory_profile = if (policy == .profile or policy == .both) profile else null,
    };
}

fn Decoder(comptime B: type, comptime owned: bool) type {
    return if (owned) B.IncrementalStreamDecoder else B.IncrementalCopyStreamDecoder;
}

fn init(comptime B: type, comptime owned: bool, allocator: std.mem.Allocator, history: []u8, decode: B.DecodeOptions) Decoder(B, owned) {
    const settings = Decoder(B, owned).Options{ .expected_output_len = 5, .decode = decode };
    return if (owned)
        Decoder(B, owned).initWithOptions(allocator, settings)
    else
        Decoder(B, owned).initWithOptions(history, settings);
}

fn expectNoAllocation(failing: *const std.testing.FailingAllocator) !void {
    try std.testing.expectEqual(@as(usize, 0), failing.allocations);
    try std.testing.expectEqual(@as(usize, 0), failing.resize_index);
    try std.testing.expect(!failing.has_induced_failure);
}

fn expectZeroFailure(comptime B: type, decoder: anytype, err: B.Error) !void {
    const snap = decoder.snapshot();
    try std.testing.expectEqual(@as(B.Counter, 0), snap.total_compressed);
    try std.testing.expectEqual(@as(B.Counter, 0), snap.total_output);
    try std.testing.expectEqual(@as(usize, 0), snap.last_step_progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), snap.last_step_progress.output_written);
    try std.testing.expectEqual(@as(?B.Counter, 0), snap.error_input_offset);
    try std.testing.expectEqual(@as(?B.Counter, 0), snap.error_output_offset);
    try std.testing.expectEqual(err, decoder.fatal_error.?);
    try std.testing.expectEqualStrings(@errorName(err), decoder.diagnostics().last_error_name);
    if (@hasDecl(@TypeOf(decoder.*), "workingMemoryBytes")) {
        try std.testing.expectEqual(@as(usize, 0), decoder.workingMemoryBytes());
        try std.testing.expectEqual(@as(usize, 0), decoder.peakWorkingMemoryBytes());
    }
}

fn drain(decoder: anytype, wire: []const u8) !void {
    var output: [5]u8 = undefined;
    var read: usize = 0;
    var written: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const stepped = try decoder.step(wire[read..@min(wire.len, read + 1)], output[written..@min(output.len, written + 1)]);
        read += stepped.progress.input_read;
        written += stepped.progress.output_written;
        try std.testing.expect(stepped.status == .done or stepped.progress.input_read != 0 or stepped.progress.output_written != 0);
    }
    try decoder.finish();
    try std.testing.expectEqual(wire.len, read);
    try std.testing.expectEqual(output.len, written);
    try std.testing.expectEqualSlices(u8, "hello", &output);
}

// Each case owns one large decoder. Keeping its lifecycle in a separate frame
// prevents comptime coverage loops from multiplying WASI stack requirements.
noinline fn initialRefusalCase(comptime B: type, comptime owned: bool, wire: []const u8, decode: B.DecodeOptions, err: B.Error, finish_first: bool) !void {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    var history: [5]u8 = @splat(0x9b);
    var decoder = init(B, owned, failing.allocator(), &history, decode);
    defer if (owned) decoder.deinit();
    try expectNoAllocation(&failing);
    var output: [5]u8 = @splat(0xa5);
    if (finish_first) {
        // A ready prefix makes finish's former preparation path allocate
        // history unless policy is checked first.
        if (owned) {
            decoder.window_prefix[0] = wire[0];
            decoder.window_prefix_len = 1;
        }
        try std.testing.expectError(err, decoder.finish());
        if (owned) try std.testing.expect(!decoder.input_finished);
    } else {
        try std.testing.expectError(err, decoder.step(wire, &output));
    }
    try expectZeroFailure(B, &decoder, err);
    try expectNoAllocation(&failing);
    try std.testing.expectEqualSlices(u8, &([_]u8{0xa5} ** 5), &output);
    try std.testing.expectEqualSlices(u8, &([_]u8{0x9b} ** 5), &history);
    try std.testing.expectError(err, decoder.step(wire, &output));
    try std.testing.expectError(err, decoder.finish());
    decoder.reset();
    try std.testing.expectError(err, decoder.finish());
    try expectZeroFailure(B, &decoder, err);
    try expectNoAllocation(&failing);
}

fn initialRefusal(comptime B: type, wire: []const u8) !void {
    for (std.enums.values(Policy)) |policy| {
        var profile: B.DecodeMemoryProfile = .{};
        profile.record(31, 41);
        const before_profile = profile;
        const decode = options(B, policy, &profile);
        inline for (.{ false, true }) |owned| {
            for ([_]bool{ false, true }) |finish_first|
                try initialRefusalCase(B, owned, wire, decode, error.UnsupportedBrotliFeature, finish_first);
        }
        try std.testing.expectEqualDeep(before_profile, profile);
    }
}

noinline fn transactionalReconfigurationCase(comptime B: type, comptime owned: bool, wire: []const u8, decode: B.DecodeOptions, err: B.Error) !void {
    var tracker = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var history: [5]u8 = undefined;
    var decoder = init(B, owned, tracker.allocator(), &history, .{});
    defer if (owned) decoder.deinit();
    try drain(&decoder, wire);
    const before = decoder.snapshot();
    const before_options = decoder.options;
    const before_history = history;
    const allocations = tracker.allocations;
    const deallocations = tracker.deallocations;
    const resizes = tracker.resize_index;
    var requested = decoder.options;
    requested.decode = decode;
    requested.max_total_output_len = 99;
    try std.testing.expectError(err, decoder.nextFrame(requested));
    try std.testing.expectEqualDeep(before, decoder.snapshot());
    try std.testing.expectEqualDeep(before_options, decoder.options);
    if (owned) {
        try std.testing.expectError(err, decoder.resetWithOptions(requested));
        try std.testing.expectEqualDeep(before, decoder.snapshot());
        try std.testing.expectEqualDeep(before_options, decoder.options);
    }
    try std.testing.expectEqual(allocations, tracker.allocations);
    try std.testing.expectEqual(deallocations, tracker.deallocations);
    try std.testing.expectEqual(resizes, tracker.resize_index);
    if (!owned) try std.testing.expectEqualSlices(u8, &before_history, &history);
    // Rejected frame options do not poison the completed operation.
    try decoder.finish();
    try decoder.nextFrame(.{ .expected_output_len = 5 });
    try drain(&decoder, wire);
    if (!owned) {
        // The copy facade's existing void reset records configuration;
        // its first operation must reject it without touching storage.
        decoder.resetWithOptions(requested);
        var output: [5]u8 = @splat(0xa5);
        try std.testing.expectError(err, decoder.step(wire, &output));
        try expectZeroFailure(B, &decoder, err);
        try std.testing.expectEqualSlices(u8, &([_]u8{0xa5} ** 5), &output);
    }
    if (owned)
        try decoder.resetWithOptions(.{ .expected_output_len = 5 })
    else
        decoder.resetWithOptions(.{ .expected_output_len = 5 });
    try drain(&decoder, wire);
}

fn transactionalReconfiguration(comptime B: type, wire: []const u8, decode: B.DecodeOptions, err: B.Error) !void {
    inline for (.{ false, true }) |owned|
        try transactionalReconfigurationCase(B, owned, wire, decode, err);
}

fn invalidDictionaryPrecedence(comptime B: type, wire: []const u8) !void {
    const too_many: [16][]const u8 = @splat("");
    const sentinel: [*]const u8 = @ptrFromInt(1);
    const overflowing = [_][]const u8{ sentinel[0..std.math.maxInt(usize)], sentinel[0..1] };
    const invalid = [_]B.SharedDictionary{
        .{ .raw_prefixes = &too_many },
        .{ .raw_prefixes = &overflowing },
    };
    for (invalid, [_]B.Error{ error.CorruptFrame, error.IntegerOverflow }) |dictionary, err| {
        var profile: B.DecodeMemoryProfile = .{};
        var decode = options(B, .both, &profile);
        decode.shared_dictionary = dictionary;
        inline for (.{ false, true }) |owned| {
            for ([_]bool{ false, true }) |finish_first|
                try initialRefusalCase(B, owned, wire, decode, err, finish_first);
        }
        try transactionalReconfiguration(B, wire, decode, err);
        try std.testing.expectEqualDeep(B.DecodeMemoryProfile{}, profile);
    }
}

noinline fn defaultPolicy(comptime B: type, comptime owned: bool, wire: []const u8) !void {
    var history: [5]u8 = undefined;
    var decoder = init(B, owned, std.testing.allocator, &history, .{});
    defer if (owned) decoder.deinit();
    try drain(&decoder, wire);
}

pub fn contracts(comptime B: type) !void {
    const wire = try B.IncrementalTestSupport.encodeStored(std.testing.allocator, "hello");
    defer std.testing.allocator.free(wire);
    try initialRefusal(B, wire);
    for (std.enums.values(Policy)) |policy| {
        var profile: B.DecodeMemoryProfile = .{};
        profile.record(31, 41);
        const before = profile;
        try transactionalReconfiguration(B, wire, options(B, policy, &profile), error.UnsupportedBrotliFeature);
        try std.testing.expectEqualDeep(before, profile);
    }
    try invalidDictionaryPrecedence(B, wire);
    const compressed = try B.IncrementalTestSupport.encodeCompressedHello(std.testing.allocator);
    defer std.testing.allocator.free(compressed);
    inline for (.{ false, true }) |owned|
        try defaultPolicy(B, owned, compressed);
}
