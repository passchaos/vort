//! Borrowed serialized dictionaries on the two progressive decoder facades.
const std = @import("std");
const br = @import("../../br.zig");
const fixture = @import("../decode/tests/fixtures.zig");
const shared = @import("../shared_dictionary.zig");
const testing = std.testing;

fn Decoder(comptime owned: bool) type {
    return if (owned) br.IncrementalStreamDecoder else br.IncrementalCopyStreamDecoder;
}

fn init(comptime owned: bool, allocator: std.mem.Allocator, history: []u8, options: Decoder(owned).Options) Decoder(owned) {
    return if (owned)
        Decoder(owned).initWithOptions(allocator, options)
    else
        Decoder(owned).initWithOptions(history, options);
}

fn expectEmptyPoll(decoder: anytype) !void {
    const poll = try decoder.step(&.{}, &.{});
    try testing.expectEqual(.need_input, poll.status);
    try testing.expectEqual(@as(usize, 0), poll.progress.input_read);
    try testing.expectEqual(@as(usize, 0), poll.progress.output_written);
}

fn expectRefusal(decoder: anytype, expected: anyerror, view: *const br.SerializedSharedDictionary) !void {
    const before = decoder.snapshot();
    try testing.expectError(expected, decoder.attachSerializedDictionary(view));
    try testing.expectEqualDeep(before, decoder.snapshot());
}

fn expectRawRefusal(decoder: anytype, expected: anyerror, raw: []const u8) !void {
    const before = decoder.snapshot();
    try testing.expectError(expected, decoder.attachRawDictionary(raw));
    try testing.expectEqualDeep(before, decoder.snapshot());
}

fn expectFrame(decoder: anytype, wire: []const u8, comptime expected: []const u8) !void {
    var output: [expected.len]u8 = undefined;
    var read: usize = 0;
    var written: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const step = try decoder.step(wire[read..@min(read + 1, wire.len)], output[written..@min(written + 1, output.len)]);
        read += step.progress.input_read;
        written += step.progress.output_written;
        try testing.expect(step.status == .done or step.progress.input_read != 0 or step.progress.output_written != 0);
    }
    try testing.expectEqual(wire.len, read);
    try testing.expectEqual(output.len, written);
    try testing.expectEqualStrings(expected, &output);
    try decoder.finish();
}

// Isolate decoder storage for each specialization, including in Debug WASI.
noinline fn staticAttachment(comptime owned: bool, wire: []const u8) !void {
    const view = try br.parseSerializedSharedDictionary(&fixture.serialized);
    const empty = try br.parseSerializedSharedDictionary(&.{ 0x91, 0, 0, 0, 0 });
    var heap = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 0 });
    var history: [5]u8 = undefined;
    var decoder = init(owned, heap.allocator(), &history, .{ .expected_output_len = 5 });
    defer if (owned) decoder.deinit();

    try expectEmptyPoll(&decoder);
    const before = decoder.snapshot();
    try decoder.attachSerializedDictionary(&view);
    try testing.expectEqualDeep(before, decoder.snapshot());
    try expectEmptyPoll(&decoder);
    try expectRefusal(&decoder, error.InvalidStreamState, &view);
    try expectRefusal(&decoder, error.InvalidStreamState, &empty);
    try testing.expectEqual(@as(usize, 0), heap.allocations);
    try testing.expect(!heap.has_induced_failure);
    heap.fail_index = std.math.maxInt(usize);
    // The fixture's only command is a custom static reference, not literals
    // or a copy of the serialized dictionary's three-byte RAW prefix.
    try expectFrame(&decoder, wire, "hello");
}

test "Brotli stream contracts serialized attachment decodes a custom static word without allocating at admission" {
    const wire = try fixture.serializedWire(br);
    defer testing.allocator.free(wire);
    inline for (.{ false, true }) |owned| try staticAttachment(owned, wire);
}

const raw_tail = fixture.raw_plain[13..];
const raw_tail_wire = [_]u8{ 0x91, 0, raw_tail.len } ++ raw_tail.* ++ [_]u8{ 0, 0 };

noinline fn rawComposition(comptime owned: bool, comptime serialized_first: bool) !void {
    const view = try br.parseSerializedSharedDictionary(&raw_tail_wire);
    // Thirteen configured slots, one staged RAW slot, and one serialized slot.
    const configured = [_][]const u8{fixture.raw_plain[0..7]} ++ [_][]const u8{""} ** (shared.max_raw_prefixes - 3);
    var history: [fixture.raw_plain.len]u8 = undefined;
    var decoder = init(owned, testing.allocator, &history, .{
        .expected_output_len = fixture.raw_plain.len,
        .decode = .{ .shared_dictionary = .{ .raw_prefixes = &configured } },
    });
    defer if (owned) decoder.deinit();

    if (serialized_first) try decoder.attachSerializedDictionary(&view);
    try decoder.attachRawDictionary(fixture.raw_plain[7..13]);
    if (!serialized_first) try decoder.attachSerializedDictionary(&view);
    try expectRawRefusal(&decoder, error.CorruptFrame, "extra slot");
    try expectFrame(&decoder, &fixture.raw, fixture.raw_plain);
}

test "Brotli stream contracts serialized attachment follows configured and staged RAW in either order" {
    inline for (.{ false, true }) |owned| {
        inline for (.{ false, true }) |serialized_first| try rawComposition(owned, serialized_first);
    }
}

noinline fn exhaustedSlots(comptime owned: bool) !void {
    const tail = try br.parseSerializedSharedDictionary(&raw_tail_wire);
    const no_tail = try br.parseSerializedSharedDictionary(&.{ 0x91, 0, 0, 0, 0 });
    const configured = [_][]const u8{fixture.raw_plain[0..7]} ++ [_][]const u8{""} ** (shared.max_raw_prefixes - 2);
    var history: [fixture.raw_plain.len]u8 = undefined;
    var decoder = init(owned, testing.allocator, &history, .{
        .expected_output_len = fixture.raw_plain.len,
        .decode = .{ .shared_dictionary = .{ .raw_prefixes = &configured } },
    });
    defer if (owned) decoder.deinit();

    try decoder.attachRawDictionary(fixture.raw_plain[7..]);
    try expectRefusal(&decoder, error.CorruptFrame, &tail);
    // An empty serialized tail consumes no RAW slot. The failed admission
    // must not occupy the single serialized binding, either.
    try decoder.attachSerializedDictionary(&no_tail);
    try expectFrame(&decoder, &fixture.raw, fixture.raw_plain);
}

test "Brotli stream contracts serialized attachment counts nonempty tails against exhausted RAW slots" {
    inline for (.{ false, true }) |owned| try exhaustedSlots(owned);
}

noinline fn rawSizeLimit(comptime owned: bool, comptime serialized_first: bool) !void {
    const tail = try br.parseSerializedSharedDictionary(&raw_tail_wire);
    const no_tail = try br.parseSerializedSharedDictionary(&.{ 0x91, 0, 0, 0, 0 });
    var decoder = init(owned, testing.allocator, &.{}, .{
        .expected_output_len = 0,
        .decode = .{ .shared_dictionary = .{ .raw_prefixes = &.{"x"} } },
    });
    defer if (owned) decoder.deinit();
    // This descriptor-only extent is never read by the empty frame. Place it
    // off the receiver, including when the x86 stack is near the address limit.
    const start = @intFromPtr(&decoder);
    const sentinel: [*]const u8 = @ptrFromInt(if (start >= shared.max_raw_size) 1 else start + @sizeOf(Decoder(owned)));
    const full = sentinel[0 .. shared.max_raw_size - 1];

    if (serialized_first) {
        try decoder.attachSerializedDictionary(&tail);
        try expectRawRefusal(&decoder, error.CorruptFrame, full);
        try decoder.attachRawDictionary(full[tail.raw_prefix.len..]);
    } else {
        try decoder.attachRawDictionary(full);
        try expectRefusal(&decoder, error.CorruptFrame, &tail);
        try decoder.attachSerializedDictionary(&no_tail);
    }
    try expectFrame(&decoder, &.{0x06}, "");
}

test "Brotli stream contracts serialized attachment shares the total RAW byte cap in either order" {
    inline for (.{ false, true }) |owned| {
        inline for (.{ false, true }) |serialized_first| try rawSizeLimit(owned, serialized_first);
    }
}

noinline fn invalidViews(comptime owned: bool, wire: []const u8) !void {
    const view = try br.parseSerializedSharedDictionary(&fixture.serialized);
    var view_in_scratch = view;
    var metadata = fixture.serialized;
    var lengths: [16]usize = @splat(0);
    const length_bytes = std.mem.sliceAsBytes(lengths[0..]);
    var history: [5]u8 = @splat(0xa5);
    var decoder = init(owned, testing.allocator, &history, .{
        .expected_output_len = 5,
        .compressed_header_scratch = std.mem.asBytes(&view_in_scratch),
        .metadata_output = &metadata,
        .metadata_block_lengths = &lengths,
    });
    defer if (owned) decoder.deinit();

    try expectRefusal(&decoder, error.InvalidBlockPlan, &view_in_scratch);
    var invalid = view;
    // Isolate encoded backing from all of the nested slices.
    invalid.encoded = &metadata;
    try expectRefusal(&decoder, error.InvalidBlockPlan, &invalid);
    invalid.encoded = std.mem.asBytes(&decoder)[0..1];
    try expectRefusal(&decoder, error.InvalidBlockPlan, &invalid);

    // Each active nested borrow must be checked even when encoded is disjoint.
    const Nested = enum { raw_prefix, words, affixes, transforms, params };
    for (std.enums.values(Nested)) |field| {
        invalid = view;
        switch (field) {
            .raw_prefix => {
                if (owned) {
                    @memcpy(length_bytes[0..view.raw_prefix.len], view.raw_prefix);
                    invalid.raw_prefix = length_bytes[0..view.raw_prefix.len];
                } else {
                    @memcpy(history[0..view.raw_prefix.len], view.raw_prefix);
                    invalid.raw_prefix = history[0..view.raw_prefix.len];
                }
            },
            .words => {
                const data = view.word_lists[0].data;
                @memcpy(length_bytes[0..data.len], data);
                invalid.word_lists[0].data = length_bytes[0..data.len];
            },
            .affixes => invalid.transform_lists[0].prefix_suffix = length_bytes[0..1],
            .transforms => invalid.transform_lists[0].transforms = length_bytes[0..3],
            .params => {
                invalid.transform_lists[0].transforms = &.{ 0, 21, 0 };
                invalid.transform_lists[0].params = length_bytes[0..2];
            },
        }
        try expectRefusal(&decoder, error.InvalidBlockPlan, &invalid);
        @memset(length_bytes, 0);
    }

    inline for (.{ "word_list_count", "transform_list_count", "dictionary_count" }) |field| {
        invalid = view;
        @field(invalid, field) = @intCast(view.context_map.len + 1);
        try expectRefusal(&decoder, error.CorruptFrame, &invalid);
    }
    try testing.expectEqualSlices(u8, &fixture.serialized, &metadata);
    try decoder.attachSerializedDictionary(&view);
    try expectFrame(&decoder, wire, "hello");
}

test "Brotli stream contracts serialized attachment rejects writer aliases and malformed nested counts transactionally" {
    const wire = try fixture.serializedWire(br);
    defer testing.allocator.free(wire);
    inline for (.{ false, true }) |owned| try invalidViews(owned, wire);
}

noinline fn frameLifecycle(comptime owned: bool, wire: []const u8) !void {
    const view = try br.parseSerializedSharedDictionary(&fixture.serialized);
    var alternate_encoded = fixture.serialized;
    const word_offset = comptime std.mem.find(u8, &fixture.serialized, "helloworld").?;
    @memcpy(alternate_encoded[word_offset..][0..5], "world");
    const alternate = try br.parseSerializedSharedDictionary(&alternate_encoded);
    var history: [fixture.external_plain.len]u8 = undefined;
    var decoder = init(owned, testing.allocator, &history, .{
        .decode = .{ .shared_dictionary = .{ .serialized = &view } },
    });
    defer if (owned) decoder.deinit();

    try expectRefusal(&decoder, error.InvalidStreamState, &alternate);
    try expectFrame(&decoder, wire, "hello");
    try decoder.nextFrame(.{});
    if (owned) {
        // An inactive retained ring remains writable in the next frame.
        try testing.expectEqual(@as(usize, 0), decoder.history.items.len);
        const retained = decoder.history.allocatedSlice();
        try testing.expect(retained.len != 0);
        var aliased = view;
        aliased.encoded = retained[retained.len - 1 ..];
        try expectRefusal(&decoder, error.InvalidBlockPlan, &aliased);
    }
    const first = try decoder.step(fixture.external[0..1], &.{});
    try testing.expectEqual(@as(usize, 1), first.progress.input_read);
    try testing.expectEqual(@as(usize, 0), first.progress.output_written);
    try expectRefusal(&decoder, error.InvalidStreamState, &alternate);
    try expectFrame(&decoder, fixture.external[1..], fixture.external_plain);
    try expectRefusal(&decoder, error.InvalidStreamState, &alternate);

    try decoder.nextFrame(.{});
    try expectEmptyPoll(&decoder);
    try decoder.attachSerializedDictionary(&alternate);
    try expectFrame(&decoder, wire, "world");
    try testing.expectEqual(@as(br.Counter, 3), decoder.snapshot().frame_count);

    try decoder.nextFrame(.{});
    try decoder.attachSerializedDictionary(&view);
    try expectFrame(&decoder, wire, "hello");
    try testing.expectEqual(@as(br.Counter, 4), decoder.snapshot().frame_count);

    decoder.reset();
    try decoder.attachSerializedDictionary(&alternate);
    try expectFrame(&decoder, wire, "world");
    try testing.expectEqual(@as(br.Counter, 1), decoder.snapshot().frame_count);

    decoder.reset();
    try testing.expectError(error.TruncatedFrame, decoder.finish());
    try expectRefusal(&decoder, error.InvalidStreamState, &alternate);
}

test "Brotli stream contracts serialized attachment is frame local and refuses configured duplicates or late calls" {
    const wire = try fixture.serializedWire(br);
    defer testing.allocator.free(wire);
    inline for (.{ false, true }) |owned| try frameLifecycle(owned, wire);
}
