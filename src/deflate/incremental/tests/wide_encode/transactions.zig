const std = @import("std");
const h = @import("helpers.zig");

fn buffers(encoder: anytype) [3]u64 {
    const raw = h.rawOf(encoder);
    return .{
        std.hash.Wyhash.hash(0, raw.plain.items),
        std.hash.Wyhash.hash(0, raw.pending.items),
        if (@hasField(@TypeOf(raw.*), "history")) std.hash.Wyhash.hash(0, raw.history.items) else 0,
    };
}

fn expectGuard(guard: []const u8) !void {
    for (guard) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

fn inputOverflow(comptime Encoder: type) !void {
    var encoder = Encoder.initWithOptions(h.allocator, if (@hasField(Encoder, "raw")) .{ .raw = .{ .block_len = 64 } } else .{ .block_len = 64 });
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(h.allocator);
    try h.feed(&encoder, "accepted-state", &wire, 14, 128);
    var guard: [8]u8 = @splat(0xa5);
    inline for (if (@hasField(Encoder, "raw")) .{ "total_input", "stream_input" } else .{"total_input"}) |field| {
        const saved = @field(encoder, field);
        @field(encoder, field) = h.max_count - 1;
        const before = encoder.snapshot();
        const contents = buffers(&encoder);
        const state = h.rawOf(&encoder).state;
        try std.testing.expectError(error.IntegerOverflow, encoder.step("ab", &guard));
        try std.testing.expectEqualDeep(before, encoder.snapshot());
        try std.testing.expectEqualDeep(contents, buffers(&encoder));
        try std.testing.expectEqualDeep(state, h.rawOf(&encoder).state);
        try expectGuard(&guard);
        @field(encoder, field) = saved;
    }
    const raw = h.rawOf(&encoder);
    raw.expected_input_len = h.boundary + 1;
    raw.options.max_input_len = h.boundary;
    const before = encoder.snapshot();
    // Public wrapper preflight reuses raw cap validation before draining any
    // pending output. Its buffered input remains unchanged.
    try std.testing.expectError(error.OutputLimitExceeded, encoder.step("", &guard));
    try std.testing.expectEqualDeep(before, encoder.snapshot());
    try expectGuard(&guard);
}

fn outputOverflow(comptime Encoder: type) !void {
    var encoder = Encoder.init(h.allocator);
    defer encoder.deinit();
    _ = try h.step(&encoder, "abc", &.{});
    if (!@hasField(Encoder, "raw")) {
        encoder.finish();
        _ = try h.step(&encoder, "", &.{});
    }
    try std.testing.expect(encoder.pending.items.len >= 2);
    const first = encoder.pending.items[encoder.pending_offset];
    encoder.total_output = h.max_count - 1;
    if (@hasField(Encoder, "stream_output")) encoder.stream_output = h.max_count - 1;
    var guard: [8]u8 = @splat(0xa5);
    const result = try h.step(&encoder, "", &guard);
    try std.testing.expectEqual(h.core.StepResult.Status.need_output, result.status);
    try std.testing.expectEqual(@as(usize, 1), result.progress.output_written);
    try std.testing.expectEqual(@as(usize, 0), result.progress.input_read);
    try std.testing.expectEqual(first, guard[0]);
    try expectGuard(guard[1..]);
    try std.testing.expectEqual(h.max_count, encoder.total_output);
    const before = encoder.snapshot();
    const contents = buffers(&encoder);
    const offset = encoder.pending_offset;
    guard = @splat(0xa5);
    try std.testing.expectError(error.IntegerOverflow, encoder.step("", &guard));
    try std.testing.expectEqualDeep(before, encoder.snapshot());
    try std.testing.expectEqualDeep(contents, buffers(&encoder));
    try std.testing.expectEqual(offset, encoder.pending_offset);
    try expectGuard(&guard);
}

fn memberOverflow(comptime Encoder: type, comptime gzip: bool) !void {
    var encoder = Encoder.init(std.testing.failing_allocator);
    defer encoder.deinit();
    const field = if (gzip) "member_count" else "stream_count";
    @field(encoder, field) = h.max_count;
    var guard: [8]u8 = @splat(0xa5);
    const before = encoder.snapshot();
    try std.testing.expectError(error.IntegerOverflow, encoder.step("", &guard));
    try std.testing.expectEqualDeep(before, encoder.snapshot());
    try std.testing.expectEqual(@as(usize, 0), encoder.pending.items.len);
    try expectGuard(&guard);
    // Completion state was reached by a real empty member with real wire.
    @field(encoder, field) = 0;
    encoder.allocator = h.allocator;
    encoder.raw.allocator = h.allocator;
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(h.allocator);
    try h.finish(&encoder, &wire, 128);
    @field(encoder, field) = h.max_count;
    const completed = encoder.snapshot();
    if (gzip)
        try std.testing.expectError(error.IntegerOverflow, encoder.nextMemberExactSize(.{}, h.boundary + 1))
    else
        try std.testing.expectError(error.IntegerOverflow, encoder.nextStreamExactSize(.{}, "dict", h.boundary + 1));
    try std.testing.expectEqualDeep(completed, encoder.snapshot());
    try std.testing.expectEqual(@as(?h.Count, null), encoder.raw.expected_input_len);
}

fn paramsOverflow(comptime Encoder: type) !void {
    var encoder = Encoder.init(h.allocator);
    defer encoder.deinit();
    try encoder.requestParams(.{ .level = 1 });
    const raw = h.rawOf(&encoder);
    try std.testing.expectEqual(h.Count, @FieldType(@TypeOf(raw.*), "params_change_count"));
    raw.params_change_count = h.max_count;
    const before = encoder.snapshot();
    try std.testing.expectError(error.IntegerOverflow, encoder.requestParams(.{ .level = 2 }));
    try std.testing.expectEqualDeep(before, encoder.snapshot());
    try encoder.requestParams(.{ .level = 1 });
    raw.params_change_count = h.max_count - 1;
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(h.allocator);
    try h.feed(&encoder, "a", &wire, 1, 128);
    try encoder.requestParams(.{ .level = 6 });
    raw.params_change_count = h.max_count;
    var guard: [8]u8 = @splat(0xa5);
    const boundary_before = encoder.snapshot();
    const matcher_before = raw.matchFinderSnapshot();
    const contents = buffers(&encoder);
    try std.testing.expectError(error.IntegerOverflow, encoder.step("", &guard));
    try std.testing.expectEqualDeep(boundary_before, encoder.snapshot());
    try std.testing.expectEqualDeep(matcher_before, raw.matchFinderSnapshot());
    try std.testing.expectEqualDeep(contents, buffers(&encoder));
    try expectGuard(&guard);
}

fn matcherOverflow(comptime Encoder: type) !void {
    var encoder = Encoder.initWithDictionary(std.testing.failing_allocator, .{}, "dictionary");
    defer encoder.deinit();
    encoder.match_finder.absolute_position = h.max_count;
    const before = encoder.snapshot();
    const matcher_before = encoder.matchFinderSnapshot();
    var guard: [8]u8 = @splat(0xa5);
    try std.testing.expectError(error.IntegerOverflow, encoder.step("a", &guard));
    try std.testing.expectEqualDeep(before, encoder.snapshot());
    try std.testing.expectEqualDeep(matcher_before, encoder.matchFinderSnapshot());
    try std.testing.expectEqual(@as(usize, 0), encoder.history.items.len);
    try expectGuard(&guard);
}

fn wrapperMatcherOverflow(comptime Encoder: type) !void {
    // Reject before even allocating or publishing the outer header.
    var empty = Encoder.init(std.testing.failing_allocator);
    defer empty.deinit();
    empty.raw.match_finder.absolute_position = h.max_count;
    var guard: [128]u8 = @splat(0xa5);
    const empty_before = empty.snapshot();
    try std.testing.expectError(error.IntegerOverflow, empty.step("a", &guard));
    try std.testing.expectEqualDeep(empty_before, empty.snapshot());
    try std.testing.expect(!empty.header_written);
    try std.testing.expectEqual(@as(usize, 0), empty.pending.items.len);
    try expectGuard(&guard);

    // Also preserve a real, already accepted plain buffer and checksum.
    var buffered = Encoder.init(h.allocator);
    defer buffered.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(h.allocator);
    try h.feed(&buffered, "accepted", &wire, 8, 128);
    buffered.raw.match_finder.absolute_position = h.max_count - 1;
    const before = buffered.snapshot();
    const contents = buffers(&buffered);
    const matcher_before = buffered.raw.matchFinderSnapshot();
    const checksum_before = if (@hasField(Encoder, "crc")) buffered.crc.digest() else buffered.adler.digest();
    try std.testing.expectError(error.IntegerOverflow, buffered.step("a", &guard));
    try std.testing.expectEqualDeep(before, buffered.snapshot());
    try std.testing.expectEqualDeep(contents, buffers(&buffered));
    try std.testing.expectEqualDeep(matcher_before, buffered.raw.matchFinderSnapshot());
    try std.testing.expectEqual(checksum_before, if (@hasField(Encoder, "crc")) buffered.crc.digest() else buffered.adler.digest());
    try expectGuard(&guard);
}

fn oomRetry(comptime D: type, comptime Encoder: type) !void {
    var encoder = Encoder.init(h.allocator);
    defer encoder.deinit();
    const payload = "OOM keeps accepted input available for retry";
    _ = try h.step(&encoder, payload, &.{});
    encoder.finish();
    // The first wire allocation must fail without discarding the retained
    // payload. Retry uses retained capacities; matcher reseeding may choose a
    // different valid wire after OOM, so validate decoded content.
    encoder.allocator = std.testing.failing_allocator;
    var guard: [128]u8 = @splat(0xa5);
    try std.testing.expectError(error.OutOfMemory, encoder.step("", &guard));
    try expectGuard(&guard);
    try std.testing.expectEqualSlices(u8, payload, encoder.plain.items);
    encoder.allocator = h.allocator;
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(h.allocator);
    try h.drain(&encoder, &wire, 7, true);
    var output: [payload.len]u8 = undefined;
    _ = try D.decodeRawAuto(wire.items, &output);
    try std.testing.expectEqualSlices(u8, payload, &output);
}

pub fn contracts(comptime D: type) !void {
    inline for (.{ D.RawDeflateIncrementalStoredEncoder, D.RawDeflateIncrementalFixedEncoder, D.RawDeflateIncrementalBestEncoder, D.ZlibIncrementalFixedEncoder, D.ZlibIncrementalBestEncoder, D.GzipIncrementalFixedEncoder, D.GzipIncrementalBestEncoder }) |Encoder| {
        try inputOverflow(Encoder);
        try outputOverflow(Encoder);
    }
    inline for (.{ D.ZlibIncrementalFixedEncoder, D.ZlibIncrementalBestEncoder }) |Encoder|
        try memberOverflow(Encoder, false);
    inline for (.{ D.GzipIncrementalFixedEncoder, D.GzipIncrementalBestEncoder }) |Encoder|
        try memberOverflow(Encoder, true);
    inline for (.{ D.RawDeflateIncrementalBestEncoder, D.ZlibIncrementalBestEncoder, D.GzipIncrementalBestEncoder }) |Encoder|
        try paramsOverflow(Encoder);
    inline for (.{ D.RawDeflateIncrementalFixedEncoder, D.RawDeflateIncrementalBestEncoder }) |Encoder|
        try matcherOverflow(Encoder);
    inline for (.{ D.ZlibIncrementalFixedEncoder, D.ZlibIncrementalBestEncoder, D.GzipIncrementalFixedEncoder, D.GzipIncrementalBestEncoder }) |Encoder|
        try wrapperMatcherOverflow(Encoder);
    inline for (.{ D.RawDeflateIncrementalStoredEncoder, D.RawDeflateIncrementalFixedEncoder, D.RawDeflateIncrementalBestEncoder }) |Encoder|
        try oomRetry(D, Encoder);
}
