const std = @import("std");
const checksum = @import("../../../checksum.zig");
const deflate = @import("../../../deflate.zig");

const Params = deflate.DeflateParams;

fn expectParams(expected: Params, actual: ?Params) !void {
    try std.testing.expect(actual != null);
    try std.testing.expectEqual(expected, actual.?);
}

fn feedChunked(
    encoder: anytype,
    input: []const u8,
    input_chunk_len: usize,
    encoded: *std.ArrayList(u8),
    scratch: []u8,
) !void {
    std.debug.assert(input_chunk_len != 0);
    std.debug.assert(scratch.len != 0);
    var offset: usize = 0;
    while (offset < input.len) {
        const end = @min(input.len, offset + input_chunk_len);
        const result = try encoder.step(input[offset..end], scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        offset += result.progress.input_read;
        if (result.progress.input_read == 0 and result.progress.output_written == 0)
            return error.TestUnexpectedResult;
    }
}

fn drainBoundary(encoder: anytype, encoded: *std.ArrayList(u8), scratch: []u8) !void {
    std.debug.assert(scratch.len != 0);
    while (true) {
        const result = try encoder.step("", scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        switch (result.status) {
            .need_input => return,
            .need_output => if (result.progress.output_written == 0) return error.TestUnexpectedResult,
            .done => return error.TestUnexpectedResult,
        }
    }
}

fn drainDone(encoder: anytype, encoded: *std.ArrayList(u8), scratch: []u8) !void {
    std.debug.assert(scratch.len != 0);
    while (true) {
        const result = try encoder.step("", scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        switch (result.status) {
            .done => return,
            .need_output => if (result.progress.output_written == 0) return error.TestUnexpectedResult,
            .need_input => return error.TestUnexpectedResult,
        }
    }
}

fn finishStream(encoder: anytype, encoded: *std.ArrayList(u8), scratch: []u8) !void {
    encoder.finish();
    try drainDone(encoder, encoded, scratch);
}

fn expectRawRoundTrip(wire: []const u8, expected: []const u8) !void {
    const decoded = try deflate.decodeRawAutoAlloc(std.testing.allocator, wire);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

fn expectStoredBlocks(wire: []const u8, expected: []const u8) !usize {
    var wire_offset: usize = 0;
    var plain_offset: usize = 0;
    var block_count: usize = 0;
    while (true) {
        if (wire_offset >= wire.len) return error.TestUnexpectedResult;
        const header = wire[wire_offset];
        wire_offset += 1;
        const final = (header & 1) != 0;
        try std.testing.expectEqual(@as(u8, 0), (header >> 1) & 0x3);
        if (wire.len - wire_offset < 4) return error.TestUnexpectedResult;
        const len = std.mem.readInt(u16, wire[wire_offset..][0..2], .little);
        const nlen = std.mem.readInt(u16, wire[wire_offset + 2 ..][0..2], .little);
        wire_offset += 4;
        try std.testing.expectEqual(~len, nlen);
        if (wire.len - wire_offset < len or expected.len - plain_offset < len)
            return error.TestUnexpectedResult;
        try std.testing.expectEqualSlices(
            u8,
            expected[plain_offset..][0..len],
            wire[wire_offset..][0..len],
        );
        wire_offset += len;
        plain_offset += len;
        block_count += 1;
        if (final) break;
    }
    try std.testing.expectEqual(expected.len, plain_offset);
    try std.testing.expectEqual(wire.len, wire_offset);
    return block_count;
}

test "incremental best request params covers levels zero through nine" {
    const payload = "numeric level round trip with repeated alpha beta gamma 0123456789\n" ** 7;
    inline for (0..10) |level_usize| {
        const params: Params = .{ .level = @intCast(level_usize) };
        var encoder = deflate.RawDeflateIncrementalBestEncoder.init(std.testing.allocator);
        defer encoder.deinit();
        try encoder.requestParams(params);
        try expectParams(params, encoder.snapshot().active_params);
        try std.testing.expect(encoder.snapshot().requested_params == null);

        var wire: std.ArrayList(u8) = .empty;
        defer wire.deinit(std.testing.allocator);
        var scratch: [13]u8 = undefined;
        try feedChunked(&encoder, payload, 11, &wire, &scratch);
        try finishStream(&encoder, &wire, &scratch);
        try expectRawRoundTrip(wire.items, payload);

        if (level_usize == 0) {
            try std.testing.expect(encoder.snapshot().stored_only);
            try std.testing.expectEqual(deflate.RawDeflateBlockType.stored, (try deflate.parseRawDeflateHeaderInfo(wire.items)).block_type);
        } else {
            try std.testing.expect(!encoder.snapshot().stored_only);
        }
    }
}

test "incremental best request params covers all five strategies" {
    const payload = ("AAAAAAAAAAAAAAAA\n" ** 8) ++
        ("filtered-short-patterns-0123456789\n" ** 8) ++
        ("fixed strategy must not emit a dynamic block\n" ** 8);
    const strategies = [_]Params.Strategy{
        .default,
        .filtered,
        .huffman_only,
        .rle,
        .fixed,
    };
    inline for (strategies) |strategy| {
        const params: Params = .{ .level = 6, .strategy = strategy };
        var encoder = deflate.RawDeflateIncrementalBestEncoder.initWithOptions(std.testing.allocator, .{
            .block_len = payload.len + 1,
        });
        defer encoder.deinit();
        try encoder.requestParams(params);

        var wire: std.ArrayList(u8) = .empty;
        defer wire.deinit(std.testing.allocator);
        var scratch: [17]u8 = undefined;
        try feedChunked(&encoder, payload, 23, &wire, &scratch);
        try finishStream(&encoder, &wire, &scratch);
        try expectRawRoundTrip(wire.items, payload);
        try expectParams(params, encoder.snapshot().active_params);
        if (strategy == .fixed)
            try std.testing.expectEqual(deflate.RawDeflateBlockType.fixed, (try deflate.parseRawDeflateHeaderInfo(wire.items)).block_type);
    }
}

test "incremental stored params split data beyond the stored block limit" {
    var payload: [std.math.maxInt(u16) + 257]u8 = undefined;
    for (&payload, 0..) |*byte, i| byte.* = @intCast((i * 73 + i / 17) % 251);

    var encoder = deflate.RawDeflateIncrementalBestEncoder.initWithOptions(std.testing.allocator, .{
        .block_len = deflate.max_stored_block_len,
    });
    defer encoder.deinit();
    const params: Params = .{ .level = 0 };
    try encoder.requestParams(params);

    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(std.testing.allocator);
    var scratch: [127]u8 = undefined;
    try feedChunked(&encoder, &payload, 4093, &wire, &scratch);
    try finishStream(&encoder, &wire, &scratch);
    try std.testing.expectEqual(@as(usize, 2), try expectStoredBlocks(wire.items, &payload));
    try expectRawRoundTrip(wire.items, &payload);
}

fn encodeCrossFamily(manual_boundary: bool) ![]u8 {
    const first = "old slow-family buffered bytes abracadabra abracadabra\n" ** 9;
    const second = "new fast-family bytes after the params boundary\n" ** 11;
    const old_params: Params = .{ .level = 6 };
    const new_params: Params = .{ .level = 1 };
    var encoder = deflate.RawDeflateIncrementalBestEncoder.initWithOptions(std.testing.allocator, .{
        .block_len = 4096,
    });
    defer encoder.deinit();
    try encoder.requestParams(old_params);
    var wire: std.ArrayList(u8) = .empty;
    errdefer wire.deinit(std.testing.allocator);
    var scratch: [19]u8 = undefined;
    try feedChunked(&encoder, first, 29, &wire, &scratch);
    if (manual_boundary) {
        encoder.blockFlush();
        try drainBoundary(&encoder, &wire, &scratch);
        try encoder.requestParams(new_params);
        try drainBoundary(&encoder, &wire, &scratch);
    } else {
        try encoder.requestParams(new_params);
        try std.testing.expect(encoder.snapshot().params_boundary_pending);
        try drainBoundary(&encoder, &wire, &scratch);
    }
    try expectParams(new_params, encoder.snapshot().active_params);
    try std.testing.expect(encoder.snapshot().requested_params == null);
    try feedChunked(&encoder, second, 17, &wire, &scratch);
    try finishStream(&encoder, &wire, &scratch);
    return wire.toOwnedSlice(std.testing.allocator);
}

test "cross-family request params matches an explicit block boundary" {
    const automatic = try encodeCrossFamily(false);
    defer std.testing.allocator.free(automatic);
    const manual = try encodeCrossFamily(true);
    defer std.testing.allocator.free(manual);
    try std.testing.expectEqualSlices(u8, manual, automatic);
    try expectRawRoundTrip(
        automatic,
        ("old slow-family buffered bytes abracadabra abracadabra\n" ** 9) ++
            ("new fast-family bytes after the params boundary\n" ** 11),
    );
}

fn encodeSameFamily(initial: Params, replacement: Params, request_midstream: bool) ![]u8 {
    const first = "same-family bytes remain in the current planning block\n" ** 7;
    const second = "same-family bytes accepted after the immediate change\n" ** 6;
    var encoder = deflate.RawDeflateIncrementalBestEncoder.initWithOptions(std.testing.allocator, .{
        .block_len = 4096,
    });
    defer encoder.deinit();
    try encoder.requestParams(initial);
    if (!request_midstream) try encoder.requestParams(replacement);
    var wire: std.ArrayList(u8) = .empty;
    errdefer wire.deinit(std.testing.allocator);
    var scratch: [23]u8 = undefined;
    try feedChunked(&encoder, first, 31, &wire, &scratch);
    if (request_midstream) {
        const before = encoder.snapshot();
        try encoder.requestParams(replacement);
        const after = encoder.snapshot();
        try expectParams(replacement, after.active_params);
        try std.testing.expect(after.requested_params == null);
        try std.testing.expect(!after.params_boundary_pending);
        try std.testing.expectEqual(before.buffered_input, after.buffered_input);
        try std.testing.expectEqual(before.pending_output, after.pending_output);
    }
    try feedChunked(&encoder, second, 13, &wire, &scratch);
    try finishStream(&encoder, &wire, &scratch);
    return wire.toOwnedSlice(std.testing.allocator);
}

test "same-family level changes do not force a block boundary" {
    inline for (.{
        .{ Params{ .level = 1 }, Params{ .level = 3 } },
        .{ Params{ .level = 4 }, Params{ .level = 9 } },
    }) |pair| {
        const changed = try encodeSameFamily(pair[0], pair[1], true);
        defer std.testing.allocator.free(changed);
        const direct = try encodeSameFamily(pair[0], pair[1], false);
        defer std.testing.allocator.free(direct);
        try std.testing.expectEqualSlices(u8, direct, changed);
    }
}

test "pre-input parameter replacement never queues an empty boundary" {
    const payload = "first bytes after a pre-input parameter replacement";
    inline for (.{
        deflate.RawDeflateIncrementalBestEncoder,
        deflate.ZlibIncrementalBestEncoder,
        deflate.GzipIncrementalBestEncoder,
    }) |Encoder| {
        var encoder = Encoder.init(std.testing.allocator);
        defer encoder.deinit();
        try encoder.requestParams(.{ .level = 6, .strategy = .default });
        const replacement: Params = .{ .level = 1, .strategy = .fixed };
        try encoder.requestParams(replacement);
        try expectParams(replacement, encoder.snapshot().active_params);
        try std.testing.expect(encoder.snapshot().requested_params == null);
        try std.testing.expect(!encoder.snapshot().params_boundary_pending);
        const fresh_count = encoder.snapshot().params_change_count;
        try encoder.requestParams(replacement);
        try std.testing.expectEqual(fresh_count, encoder.snapshot().params_change_count);

        var scratch: [4096]u8 = undefined;
        const first = try encoder.step(payload, &scratch);
        try std.testing.expectEqual(payload.len, first.progress.input_read);

        encoder.finish();
        var ignored: std.ArrayList(u8) = .empty;
        defer ignored.deinit(std.testing.allocator);
        try ignored.appendSlice(std.testing.allocator, scratch[0..first.progress.output_written]);
        try drainDone(&encoder, &ignored, &scratch);

        encoder.reset();
        const reset_count = encoder.snapshot().params_change_count;
        try encoder.requestParams(replacement);
        try std.testing.expectEqual(reset_count, encoder.snapshot().params_change_count);
        const reset_replacement: Params = .{ .level = 9, .strategy = .huffman_only };
        try encoder.requestParams(reset_replacement);
        try expectParams(reset_replacement, encoder.snapshot().active_params);
        try std.testing.expect(!encoder.snapshot().params_boundary_pending);
        const after_reset = try encoder.step(payload, &scratch);
        try std.testing.expectEqual(payload.len, after_reset.progress.input_read);
    }
}

test "parameter requests are idempotent replaceable and cancellable" {
    const active: Params = .{ .level = 6 };
    const first_request: Params = .{ .level = 1 };
    const replacement: Params = .{ .level = 0 };
    var encoder = deflate.RawDeflateIncrementalBestEncoder.init(std.testing.allocator);
    defer encoder.deinit();
    try encoder.requestParams(active);
    var scratch: [31]u8 = undefined;
    _ = try encoder.step("buffered input whose requested target will be replaced", &scratch);

    try encoder.requestParams(first_request);
    const first = encoder.snapshot();
    try expectParams(first_request, first.requested_params);
    try std.testing.expect(first.params_boundary_pending);
    try encoder.requestParams(first_request);
    const duplicate = encoder.snapshot();
    try std.testing.expectEqual(first.params_change_count, duplicate.params_change_count);
    try expectParams(first_request, duplicate.requested_params);

    try encoder.requestParams(replacement);
    try expectParams(replacement, encoder.snapshot().requested_params);
    try encoder.requestParams(replacement);
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(std.testing.allocator);
    try drainBoundary(&encoder, &wire, &scratch);
    try expectParams(replacement, encoder.snapshot().active_params);
    try std.testing.expectEqual(first.params_change_count + 1, encoder.snapshot().params_change_count);

    encoder.reset();
    const after_reset = encoder.snapshot();
    try expectParams(replacement, after_reset.active_params);
    try std.testing.expect(after_reset.stored_only);
    _ = try encoder.step("this buffered data survives only until reset", &scratch);
    try encoder.requestParams(active);
    try std.testing.expect(encoder.snapshot().params_boundary_pending);
    try encoder.requestParams(replacement);
    const cancelled = encoder.snapshot();
    try expectParams(replacement, cancelled.active_params);
    try std.testing.expect(cancelled.requested_params == null);
    try std.testing.expect(!cancelled.params_boundary_pending);
    encoder.reset();
    const reset = encoder.snapshot();
    try expectParams(replacement, reset.active_params);
    try std.testing.expect(reset.requested_params == null);
    try std.testing.expect(!reset.params_boundary_pending);
    try std.testing.expectEqual(@as(usize, 0), reset.params_change_count);
    try std.testing.expectEqual(@as(usize, 0), reset.buffered_input);

    wire.clearRetainingCapacity();
    const payload = "reset keeps the active stored-only parameter set";
    try feedChunked(&encoder, payload, 7, &wire, &scratch);
    try finishStream(&encoder, &wire, &scratch);
    _ = try expectStoredBlocks(wire.items, payload);
}

test "direct compression option mutation invalidates managed params identity" {
    var encoder = deflate.RawDeflateIncrementalBestEncoder.init(std.testing.allocator);
    defer encoder.deinit();
    const managed: Params = .{ .level = 6 };
    try encoder.requestParams(managed);
    try expectParams(managed, encoder.snapshot().active_params);

    encoder.options.compression = deflate.optionsForLevel(.fastest);
    try std.testing.expect(encoder.snapshot().active_params == null);
    const before = encoder.snapshot().params_change_count;
    try encoder.requestParams(managed);
    try expectParams(managed, encoder.snapshot().active_params);
    try std.testing.expectEqual(before + 1, encoder.snapshot().params_change_count);
    try std.testing.expectEqual(
        deflate.optionsForLevel(.default),
        encoder.options.compression,
    );
}

test "wrapped direct raw mutation cancels stale queued params before input" {
    inline for (.{
        deflate.ZlibIncrementalBestEncoder,
        deflate.GzipIncrementalBestEncoder,
    }) |Encoder| {
        var encoder = Encoder.init(std.testing.allocator);
        defer encoder.deinit();
        try encoder.requestParams(.{ .level = 6 });
        var scratch: [4096]u8 = undefined;
        const first = try encoder.step("old buffered bytes", &scratch);
        try std.testing.expectEqual(@as(usize, "old buffered bytes".len), first.progress.input_read);

        try encoder.requestParams(.{ .level = 1 });
        try std.testing.expect(encoder.snapshot().params_boundary_pending);
        encoder.raw.options.compression = deflate.optionsForLevel(.fastest);
        const invalidated = encoder.snapshot();
        try std.testing.expect(invalidated.active_params == null);
        try std.testing.expect(invalidated.requested_params == null);
        try std.testing.expect(!invalidated.params_boundary_pending);
        try std.testing.expect(!invalidated.flushing);
        const next = try encoder.step("new", &scratch);
        try std.testing.expectEqual(@as(usize, 3), next.progress.input_read);
    }

    try std.testing.expect(!deflate.RawDeflateIncrementalFixedEncoder.supports_runtime_params);
    try std.testing.expect(!deflate.ZlibIncrementalFixedEncoder.supports_runtime_params);
    try std.testing.expect(!deflate.GzipIncrementalFixedEncoder.supports_runtime_params);
    try std.testing.expect(deflate.RawDeflateIncrementalBestEncoder.supports_runtime_params);
    try std.testing.expect(deflate.ZlibIncrementalBestEncoder.supports_runtime_params);
    try std.testing.expect(deflate.GzipIncrementalBestEncoder.supports_runtime_params);
}

test "parameter boundary commits under zero and one-byte output backpressure" {
    const first = "zero-output params boundary retains exactly one old block\n" ** 7;
    const second = "one-byte output drains the old block before new input\n" ** 5;
    const old_params: Params = .{ .level = 6 };
    const new_params: Params = .{ .level = 1 };
    var encoder = deflate.RawDeflateIncrementalBestEncoder.init(std.testing.allocator);
    defer encoder.deinit();
    try encoder.requestParams(old_params);
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(std.testing.allocator);
    var feed_scratch: [17]u8 = undefined;
    try feedChunked(&encoder, first, 19, &wire, &feed_scratch);
    try encoder.requestParams(new_params);

    var result = try encoder.step("", &.{});
    try std.testing.expectEqual(.need_output, result.status);
    try std.testing.expectEqual(@as(usize, 0), result.progress.output_written);
    const committed = encoder.snapshot();
    try expectParams(new_params, committed.active_params);
    try std.testing.expect(committed.requested_params == null);
    try std.testing.expect(!committed.params_boundary_pending);
    try std.testing.expect(committed.pending_output != 0);

    result = try encoder.step("", &.{});
    try std.testing.expectEqual(.need_output, result.status);
    try std.testing.expectEqual(committed.params_change_count, encoder.snapshot().params_change_count);
    try std.testing.expectEqual(committed.pending_output, encoder.snapshot().pending_output);

    var one: [1]u8 = undefined;
    try drainBoundary(&encoder, &wire, &one);
    try feedChunked(&encoder, second, 1, &wire, &one);
    try finishStream(&encoder, &wire, &one);
    try expectRawRoundTrip(wire.items, first ++ second);
}

test "pending parameter changes compose with sync and full flush" {
    const first = "params plus flush preserve checksum and match history 0123456789\n" ** 12;
    const second = "data after the combined boundary 0123456789\n" ** 9;
    const old_params: Params = .{ .level = 6 };
    const new_params: Params = .{ .level = 1 };
    var scratch: [7]u8 = undefined;

    var synced = deflate.RawDeflateIncrementalBestEncoder.init(std.testing.allocator);
    defer synced.deinit();
    try synced.requestParams(old_params);
    var sync_wire: std.ArrayList(u8) = .empty;
    defer sync_wire.deinit(std.testing.allocator);
    try feedChunked(&synced, first, 17, &sync_wire, &scratch);
    try synced.requestParams(new_params);
    synced.flush();
    try drainBoundary(&synced, &sync_wire, &scratch);
    try expectParams(new_params, synced.snapshot().active_params);
    try std.testing.expect(!synced.snapshot().flushing);
    try std.testing.expect(synced.matchFinderSnapshot().absolute_position != 0);
    try feedChunked(&synced, second, 13, &sync_wire, &scratch);
    try finishStream(&synced, &sync_wire, &scratch);
    try expectRawRoundTrip(sync_wire.items, first ++ second);

    var full = deflate.RawDeflateIncrementalBestEncoder.init(std.testing.allocator);
    defer full.deinit();
    try full.requestParams(old_params);
    var full_wire: std.ArrayList(u8) = .empty;
    defer full_wire.deinit(std.testing.allocator);
    try feedChunked(&full, first, 17, &full_wire, &scratch);
    try full.requestParams(new_params);
    full.fullFlush();
    try drainBoundary(&full, &full_wire, &scratch);
    try expectParams(new_params, full.snapshot().active_params);
    try std.testing.expectEqual(@as(usize, 0), full.matchFinderSnapshot().absolute_position);
    const suffix_offset = full_wire.items.len;
    try feedChunked(&full, second, 13, &full_wire, &scratch);
    try finishStream(&full, &full_wire, &scratch);
    try expectRawRoundTrip(full_wire.items, first ++ second);
    const suffix = try deflate.decodeRawAutoAlloc(std.testing.allocator, full_wire.items[suffix_offset..]);
    defer std.testing.allocator.free(suffix);
    try std.testing.expectEqualSlices(u8, second, suffix);
}

fn encodePendingFinish(manual_boundary: bool) ![]u8 {
    const payload = "finish honors a queued parameter boundary\n" ** 13;
    var encoder = deflate.RawDeflateIncrementalBestEncoder.init(std.testing.allocator);
    defer encoder.deinit();
    try encoder.requestParams(.{ .level = 6 });
    var wire: std.ArrayList(u8) = .empty;
    errdefer wire.deinit(std.testing.allocator);
    var scratch: [5]u8 = undefined;
    try feedChunked(&encoder, payload, 11, &wire, &scratch);
    if (manual_boundary) {
        encoder.blockFlush();
        try drainBoundary(&encoder, &wire, &scratch);
        try encoder.requestParams(.{ .level = 1 });
    } else {
        try encoder.requestParams(.{ .level = 1 });
    }
    try finishStream(&encoder, &wire, &scratch);
    try expectParams(.{ .level = 1 }, encoder.snapshot().active_params);
    return wire.toOwnedSlice(std.testing.allocator);
}

test "finish honors a pending parameter boundary exactly once" {
    const pending = try encodePendingFinish(false);
    defer std.testing.allocator.free(pending);
    const explicit = try encodePendingFinish(true);
    defer std.testing.allocator.free(explicit);
    try std.testing.expectEqualSlices(u8, explicit, pending);
    try expectRawRoundTrip(pending, "finish honors a queued parameter boundary\n" ** 13);
}

fn fillDeterministic(bytes: []u8, seed: *u32) void {
    for (bytes) |*byte| {
        seed.* ^= seed.* << 13;
        seed.* ^= seed.* >> 17;
        seed.* ^= seed.* << 5;
        byte.* = @truncate(seed.*);
    }
}

test "parameter boundaries retain history and preset dictionary" {
    var dictionary: [1024]u8 = undefined;
    var seed: u32 = 0x1234_5678;
    fillDeterministic(&dictionary, &seed);
    const first = dictionary[0..512];
    const second = dictionary[512..];
    var scratch: [29]u8 = undefined;

    var retained = deflate.RawDeflateIncrementalBestEncoder.initWithDictionary(
        std.testing.allocator,
        .{ .block_len = 4096 },
        &dictionary,
    );
    defer retained.deinit();
    try retained.requestParams(.{ .level = 6 });
    var retained_wire: std.ArrayList(u8) = .empty;
    defer retained_wire.deinit(std.testing.allocator);
    try feedChunked(&retained, first, 37, &retained_wire, &scratch);
    try retained.requestParams(.{ .level = 1 });
    try drainBoundary(&retained, &retained_wire, &scratch);
    try std.testing.expectEqual(dictionary.len + first.len, retained.matchFinderSnapshot().absolute_position);
    try feedChunked(&retained, second, 41, &retained_wire, &scratch);
    try finishStream(&retained, &retained_wire, &scratch);
    const decoded = try deflate.decodeRawAutoAllocWithDictionary(std.testing.allocator, retained_wire.items, &dictionary);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &dictionary, decoded);

    var dropped = deflate.RawDeflateIncrementalBestEncoder.initWithDictionary(
        std.testing.allocator,
        .{ .block_len = 4096 },
        &dictionary,
    );
    defer dropped.deinit();
    try dropped.requestParams(.{ .level = 6 });
    var dropped_wire: std.ArrayList(u8) = .empty;
    defer dropped_wire.deinit(std.testing.allocator);
    try feedChunked(&dropped, first, 37, &dropped_wire, &scratch);
    dropped.fullFlush();
    try drainBoundary(&dropped, &dropped_wire, &scratch);
    try dropped.requestParams(.{ .level = 1 });
    try drainBoundary(&dropped, &dropped_wire, &scratch);
    try feedChunked(&dropped, second, 41, &dropped_wire, &scratch);
    try finishStream(&dropped, &dropped_wire, &scratch);
    try std.testing.expect(retained_wire.items.len + second.len / 2 < dropped_wire.items.len);
}

const schedule_first = "wrapper params first default segment alpha beta gamma 0123456789\n" ** 5;
const schedule_second = "wrapper params second filtered fast segment abcabcabcabc\n" ** 7;
const schedule_third = "stored segment deliberately carries literal bytes 9876543210\n" ** 4;
const schedule_fourth = "fixed final segment QWERTYQWERTYQWERTY\n" ** 6;
const schedule_payload = schedule_first ++ schedule_second ++ schedule_third ++ schedule_fourth;

fn encodeWrapperSchedule(
    comptime Encoder: type,
    comptime output_chunk_len: usize,
    input_chunk_len: usize,
) ![]u8 {
    var encoder = Encoder.init(std.testing.allocator);
    defer encoder.deinit();
    try encoder.requestParams(.{ .level = 6, .strategy = .default });
    var wire: std.ArrayList(u8) = .empty;
    errdefer wire.deinit(std.testing.allocator);
    var scratch: [output_chunk_len]u8 = undefined;

    try feedChunked(&encoder, schedule_first, input_chunk_len, &wire, &scratch);
    try encoder.requestParams(.{ .level = 1, .strategy = .filtered });
    try drainBoundary(&encoder, &wire, &scratch);
    try feedChunked(&encoder, schedule_second, input_chunk_len, &wire, &scratch);
    try encoder.requestParams(.{ .level = 0, .strategy = .default });
    try drainBoundary(&encoder, &wire, &scratch);
    try feedChunked(&encoder, schedule_third, input_chunk_len, &wire, &scratch);
    try encoder.requestParams(.{ .level = 9, .strategy = .fixed });
    try drainBoundary(&encoder, &wire, &scratch);
    try feedChunked(&encoder, schedule_fourth, input_chunk_len, &wire, &scratch);
    try finishStream(&encoder, &wire, &scratch);
    return wire.toOwnedSlice(std.testing.allocator);
}

test "raw zlib and gzip params wires ignore chunking and preserve wrapper checksums" {
    const raw_one = try encodeWrapperSchedule(deflate.RawDeflateIncrementalBestEncoder, 1, 1);
    defer std.testing.allocator.free(raw_one);
    const raw_wide = try encodeWrapperSchedule(deflate.RawDeflateIncrementalBestEncoder, 97, 31);
    defer std.testing.allocator.free(raw_wide);
    try std.testing.expectEqualSlices(u8, raw_wide, raw_one);
    try expectRawRoundTrip(raw_one, schedule_payload);

    const zlib_one = try encodeWrapperSchedule(deflate.ZlibIncrementalBestEncoder, 1, 1);
    defer std.testing.allocator.free(zlib_one);
    const zlib_wide = try encodeWrapperSchedule(deflate.ZlibIncrementalBestEncoder, 97, 31);
    defer std.testing.allocator.free(zlib_wide);
    try std.testing.expectEqualSlices(u8, zlib_wide, zlib_one);
    const zlib_decoded = try deflate.decodeZlibAlloc(std.testing.allocator, zlib_one);
    defer std.testing.allocator.free(zlib_decoded);
    try std.testing.expectEqualSlices(u8, schedule_payload, zlib_decoded);
    try std.testing.expectEqual(
        checksum.adler32(schedule_payload),
        std.mem.readInt(u32, zlib_one[zlib_one.len - 4 ..][0..4], .big),
    );

    const gzip_one = try encodeWrapperSchedule(deflate.GzipIncrementalBestEncoder, 1, 1);
    defer std.testing.allocator.free(gzip_one);
    const gzip_wide = try encodeWrapperSchedule(deflate.GzipIncrementalBestEncoder, 97, 31);
    defer std.testing.allocator.free(gzip_wide);
    try std.testing.expectEqualSlices(u8, gzip_wide, gzip_one);
    const gzip_decoded = try deflate.decodeGzipAlloc(std.testing.allocator, gzip_one);
    defer std.testing.allocator.free(gzip_decoded);
    try std.testing.expectEqualSlices(u8, schedule_payload, gzip_decoded);
    try std.testing.expectEqual(
        checksum.crc32(schedule_payload),
        std.mem.readInt(u32, gzip_one[gzip_one.len - 8 ..][0..4], .little),
    );
    try std.testing.expectEqual(
        @as(u32, @truncate(schedule_payload.len)),
        std.mem.readInt(u32, gzip_one[gzip_one.len - 4 ..][0..4], .little),
    );
}

const WrappedFormat = enum { zlib, gzip };

fn expectWrappedReset(comptime Encoder: type, comptime format: WrappedFormat) !void {
    const stored: Params = .{ .level = 0 };
    var encoder = Encoder.init(std.testing.allocator);
    defer encoder.deinit();
    try encoder.requestParams(stored);
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(std.testing.allocator);
    var scratch: [23]u8 = undefined;
    try feedChunked(&encoder, "discarded stream before wrapper reset", 9, &wire, &scratch);
    try encoder.requestParams(.{ .level = 6 });
    try std.testing.expect(encoder.snapshot().params_boundary_pending);

    encoder.reset();
    const reset = encoder.snapshot();
    try expectParams(stored, reset.active_params);
    try std.testing.expect(reset.requested_params == null);
    try std.testing.expect(!reset.params_boundary_pending);
    try std.testing.expect(reset.stored_only);
    try std.testing.expectEqual(@as(usize, 0), reset.params_change_count);
    try std.testing.expectEqual(@as(usize, 0), reset.input_read);

    wire.clearRetainingCapacity();
    const payload = "wrapper reset retains its active stored-only parameters";
    try feedChunked(&encoder, payload, 7, &wire, &scratch);
    try finishStream(&encoder, &wire, &scratch);
    const decoded = switch (format) {
        .zlib => try deflate.decodeZlibAlloc(std.testing.allocator, wire.items),
        .gzip => try deflate.decodeGzipAlloc(std.testing.allocator, wire.items),
    };
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    const raw_offset = switch (format) {
        .zlib => (try deflate.parseZlibHeaderInfo(wire.items)).data_offset,
        .gzip => (try deflate.parseGzipHeaderInfo(wire.items)).data_offset,
    };
    try std.testing.expectEqual(
        deflate.RawDeflateBlockType.stored,
        (try deflate.parseRawDeflateHeaderInfo(wire.items[raw_offset..])).block_type,
    );
}

test "zlib and gzip reset preserve active params and cancel queued changes" {
    try expectWrappedReset(deflate.ZlibIncrementalBestEncoder, .zlib);
    try expectWrappedReset(deflate.GzipIncrementalBestEncoder, .gzip);
}

test "invalid and terminal parameter requests do not mutate encoder state" {
    var encoder = deflate.RawDeflateIncrementalBestEncoder.init(std.testing.allocator);
    defer encoder.deinit();
    const initial = encoder.snapshot();
    try std.testing.expectError(error.InvalidCompressionLevel, encoder.requestParams(.{ .level = 10 }));
    try std.testing.expectEqual(initial.params_change_count, encoder.snapshot().params_change_count);
    try std.testing.expect(encoder.snapshot().active_params == null);
    try std.testing.expect(encoder.snapshot().requested_params == null);

    encoder.finish();
    try std.testing.expectError(error.InvalidEncoderState, encoder.requestParams(.{ .level = 1 }));
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(std.testing.allocator);
    var scratch: [8]u8 = undefined;
    try drainDone(&encoder, &wire, &scratch);
    try std.testing.expectError(error.InvalidEncoderState, encoder.requestParams(.{ .level = 1 }));

    var fixed = deflate.RawDeflateIncrementalFixedEncoder.init(std.testing.allocator);
    defer fixed.deinit();
    try std.testing.expectError(error.UnsupportedOperation, fixed.requestParams(.{ .level = 1 }));
}
