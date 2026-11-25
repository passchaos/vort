const std = @import("std");
const br = @import("../../br.zig");
const shared = @import("../shared_dictionary.zig");
const testing = std.testing;

// Frozen libbrotli 1.2.0 wire. The entire output comes from a RAW copy.
const wire = [_]u8{ 0x1b, 0x3e, 0x00, 0x00, 0x24, 0x00, 0xe2, 0x98, 0xc0, 0x52, 0x00 };
const plain = "private-context-token: q9Vg6Pj8aQk4T0zY3xWB1hD2yZU7NCMvR5sFEaL0";

fn Decoder(comptime owned: bool) type {
    return if (owned) br.IncrementalStreamDecoder else br.IncrementalCopyStreamDecoder;
}

fn init(comptime owned: bool, history: []u8, options: Decoder(owned).Options) Decoder(owned) {
    return if (owned)
        Decoder(owned).initWithOptions(testing.allocator, options)
    else
        Decoder(owned).initWithOptions(history, options);
}

fn expectEmptyPoll(decoder: anytype) !void {
    const poll = try decoder.step(&.{}, &.{});
    try testing.expectEqual(.need_input, poll.status);
    try testing.expectEqual(@as(usize, 0), poll.progress.input_read);
    try testing.expectEqual(@as(usize, 0), poll.progress.output_written);
}

fn expectRefusal(decoder: anytype, err: anyerror, source: []const u8) !void {
    const before = decoder.snapshot();
    try testing.expectError(err, decoder.attachRawDictionary(source));
    try testing.expectEqualDeep(before, decoder.snapshot());
}

fn drain(decoder: anytype, input: []const u8, output: []u8) !void {
    var read: usize = 0;
    var written: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const step = try decoder.step(input[read..@min(read + 1, input.len)], output[written..@min(written + 1, output.len)]);
        read += step.progress.input_read;
        written += step.progress.output_written;
        try testing.expect(step.status == .done or step.progress.input_read != 0 or step.progress.output_written != 0);
    }
    try testing.expectEqual(input.len, read);
    try testing.expectEqual(output.len, written);
}

fn expectFrame(decoder: anytype, expected: []const u8) !void {
    var output: [plain.len]u8 = undefined;
    try drain(decoder, &wire, &output);
    try testing.expectEqualStrings(expected, &output);
}

// Keep each decoder owner in a separate stack frame, including in Debug WASI.
noinline fn splitComposition(comptime owned: bool) !void {
    const raw_tail = plain[54..];
    const serialized_wire = [_]u8{ 0x91, 0x00, raw_tail.len } ++ raw_tail.* ++ [_]u8{ 0, 0 };
    const serialized = try br.parseSerializedSharedDictionary(&serialized_wire);
    // Include configured empty slots: 12 configured + 2 attached + 1 serialized.
    const configured = [_][]const u8{plain[0..11]} ++ [_][]const u8{""} ** (shared.max_raw_prefixes - 4);
    var history: [plain.len]u8 = undefined;
    var decoder = init(owned, &history, .{
        .expected_output_len = plain.len,
        .decode = .{ .shared_dictionary = .{ .raw_prefixes = &configured, .serialized = &serialized } },
    });
    defer if (owned) decoder.deinit();

    try expectEmptyPoll(&decoder);
    try decoder.attachRawDictionary(plain[11..24]);
    try expectEmptyPoll(&decoder);
    try decoder.attachRawDictionary(plain[24..54]);
    const full = decoder.snapshot();
    try decoder.attachRawDictionary("");
    try testing.expectEqualDeep(full, decoder.snapshot());
    try expectRefusal(&decoder, error.CorruptFrame, "extra slot");
    if (owned) try testing.expectEqual(@as(usize, 0), decoder.workingMemoryBytes());
    try expectFrame(&decoder, plain);
    try decoder.finish();
}

test "Brotli stream contracts RAW attachment composes after empty polls and retries after slot refusal" {
    inline for (.{ false, true }) |owned| try splitComposition(owned);
}

noinline fn sizeAndAliasRefusals(comptime owned: bool) !void {
    const header_scratch = try testing.allocator.alloc(u8, br.IncrementalCopyStreamDecoder.embedded_compressed_header_capacity + 1);
    defer testing.allocator.free(header_scratch);
    var history: [plain.len]u8 = undefined;
    var metadata: [3]u8 = undefined;
    var lengths: [2]usize = undefined;
    var decoder = init(owned, &history, .{
        .expected_output_len = plain.len,
        .compressed_header_scratch = header_scratch,
        .metadata_output = &metadata,
        .metadata_block_lengths = &lengths,
    });
    defer if (owned) decoder.deinit();

    try decoder.attachRawDictionary(plain[0..1]);
    // Use high synthetic extents to exercise length checks without a writer
    // alias. No bytes from these slices may be read.
    const invalid: [*]const u8 = @ptrFromInt(std.math.maxInt(usize) - shared.max_raw_size - 1);
    try expectRefusal(&decoder, error.CorruptFrame, invalid[0 .. shared.max_raw_size + 1]);
    // Exactly the maximum still exceeds the limit together with the first byte.
    try expectRefusal(&decoder, error.CorruptFrame, invalid[0..shared.max_raw_size]);
    try expectRefusal(&decoder, error.IntegerOverflow, invalid[0..std.math.maxInt(usize)]);
    try expectRefusal(&decoder, error.InvalidBlockPlan, std.mem.asBytes(&decoder)[0..1]);
    if (!owned) try expectRefusal(&decoder, error.InvalidBlockPlan, history[1..2]);
    try expectRefusal(&decoder, error.InvalidBlockPlan, header_scratch[header_scratch.len - 1 ..]);
    try expectRefusal(&decoder, error.InvalidBlockPlan, metadata[1..2]);
    try expectRefusal(&decoder, error.InvalidBlockPlan, std.mem.asBytes(&lengths[1])[0..1]);
    try decoder.attachRawDictionary(plain[1..]);
    try expectFrame(&decoder, plain);
    try decoder.finish();
}

test "Brotli stream contracts RAW attachment rejects size overflow and writer aliases transactionally" {
    inline for (.{ false, true }) |owned| try sizeAndAliasRefusals(owned);
}

noinline fn stateGate(comptime owned: bool) !void {
    var history: [plain.len]u8 = undefined;
    var decoder = init(owned, &history, .{ .expected_output_len = plain.len });
    defer if (owned) decoder.deinit();

    try testing.expectError(error.TruncatedFrame, decoder.finish());
    try expectRefusal(&decoder, error.InvalidStreamState, plain);
    try expectRefusal(&decoder, error.InvalidStreamState, "");
    decoder.reset();
    try decoder.attachRawDictionary(plain);

    const first = try decoder.step(wire[0..1], &.{});
    try testing.expectEqual(@as(usize, 1), first.progress.input_read);
    try testing.expectEqual(@as(usize, 0), first.progress.output_written);
    try expectRefusal(&decoder, error.InvalidStreamState, "late");
    try expectRefusal(&decoder, error.InvalidStreamState, "");
    var output: [plain.len]u8 = undefined;
    try drain(&decoder, wire[1..], &output);
    try testing.expectEqualStrings(plain, &output);
    // Completion alone closes admission; finish need not have been called.
    try expectRefusal(&decoder, error.InvalidStreamState, "late");
    try expectRefusal(&decoder, error.InvalidStreamState, "");
    try decoder.finish();
}

test "Brotli stream contracts RAW attachment closes on input failure or completion" {
    inline for (.{ false, true }) |owned| try stateGate(owned);
}

noinline fn frameLifecycle(comptime owned: bool) !void {
    const options: Decoder(owned).Options = .{
        .expected_output_len = plain.len,
        .decode = .{ .shared_dictionary = .{ .raw_prefixes = &.{plain} } },
    };
    var history: [plain.len]u8 = undefined;
    var decoder = init(owned, &history, options);
    defer if (owned) decoder.deinit();

    try decoder.attachRawDictionary("first");
    try expectFrame(&decoder, plain[5..] ++ "first");
    try decoder.nextFrame(options);
    if (owned) {
        // The retained ring is still a writer even though this frame has not
        // activated it. Protect all of the allocation, not just items.len.
        try testing.expectEqual(@as(usize, 0), decoder.history.items.len);
        const retained = decoder.history.allocatedSlice();
        try testing.expectEqual(plain.len, retained.len);
        try expectRefusal(&decoder, error.InvalidBlockPlan, retained[retained.len - 1 ..]);
    }
    try expectFrame(&decoder, plain);
    try decoder.nextFrame(options);
    try expectEmptyPoll(&decoder);
    try decoder.attachRawDictionary("next");
    try expectFrame(&decoder, plain[4..] ++ "next");
    try testing.expectEqual(@as(br.Counter, 3), decoder.snapshot().frame_count);

    decoder.reset();
    try expectFrame(&decoder, plain);
    try testing.expectEqual(@as(br.Counter, 1), decoder.snapshot().frame_count);
    try decoder.finish();
}

test "Brotli stream contracts RAW attachment is per frame and rejects retained history after nextFrame" {
    inline for (.{ false, true }) |owned| try frameLifecycle(owned);
}

noinline fn moveDuringCopy(comptime owned: bool) !void {
    var history: [plain.len]u8 = undefined;
    var decoder: Decoder(owned) = undefined;
    var output: [plain.len]u8 = undefined;
    const first = step: {
        var source = init(owned, &history, .{ .expected_output_len = plain.len });
        errdefer if (owned) source.deinit();
        try source.attachRawDictionary(plain[0..1]);
        try source.attachRawDictionary(plain[1..23]);
        try source.attachRawDictionary(plain[23..]);
        const first = try source.step(&wire, output[0..1]);
        try testing.expectEqual(.need_output, first.status);
        try testing.expectEqual(@as(usize, 1), first.progress.output_written);
        const phase = if (owned) source.progressive.?.snapshot().phase else source.snapshot().phase;
        try testing.expectEqual(.dictionary, phase);

        decoder = source;
        // A plain `source = undefined` can leave the old descriptors intact.
        std.crypto.secureZero(u8, std.mem.asBytes(&source));
        break :step first;
    };
    defer if (owned) decoder.deinit();
    try drain(&decoder, wire[first.progress.input_read..], output[1..]);
    try testing.expectEqualStrings(plain, &output);
    try decoder.finish();
}

test "Brotli stream contracts RAW attachment survives a move mid-copy with one-byte output" {
    inline for (.{ false, true }) |owned| try moveDuringCopy(owned);
}
