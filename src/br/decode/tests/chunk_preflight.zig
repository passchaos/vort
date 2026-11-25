//! Borrow and progress contracts for chunked preflight on the long-copy fixture.
const std = @import("std");
const h = @import("helpers.zig");
const t = std.testing;
const guard = 0xa5;

pub fn contracts(comptime B: type, wire: []u8, plain: []const u8, history: []u8) !void {
    const n = plain.len;
    const copy_split = wire.len - 2;
    const head = [_][]const u8{ "", wire[0..1], wire[1..history.len], "", wire[history.len..copy_split] };
    var chunks = head ++ [_][]const u8{ wire[copy_split..], "" };
    // The first stream ends *inside* a descriptor, and the suffix spans two.
    var last_chunk = [5]u8{ 0, 0, 't', 'a', 'i' };
    @memcpy(last_chunk[0..2], wire[copy_split..]);
    const prefixed = head ++ [_][]const u8{ &last_chunk, "", "l" };
    const joined_len = wire.len + "tail".len;
    const backing = try h.a.alloc(u8, 1 + joined_len + 1 + @max(n, wire.len) + 1);
    defer h.a.free(backing);
    @memset(backing, guard);
    @memset(history, guard);
    // The unused suffix of compressed scratch is allowed to overlap output.
    const scratch = backing[1..];
    const output = scratch[joined_len + 1 ..];
    var profile: B.DecodeMemoryProfile = .{};
    const opts: B.DecodePreflightOptions = .{
        .history = history,
        .max_output_len = n,
        .expected_output_len = n,
        .decode = .{ .max_total_working_memory = 0, .memory_profile = &profile },
    };

    try borrowContracts(B, wire, &chunks, scratch, output, opts, &profile);
    try t.expectError(error.OutputTooSmall, B.decodeStreamPrefixChunksIntoWithPreflight(&prefixed, scratch[0 .. joined_len - 1], output, opts));
    try t.expect(std.mem.allEqual(u8, backing, guard));
    try t.expect(std.mem.allEqual(u8, history, guard));
    try t.expectEqual(B.DecodeMemoryProfile{}, profile);

    try t.expectError(error.UnsupportedBrotliFeature, B.decodedStreamChunksSizeLimited(&chunks, scratch, n));
    try t.expectError(error.UnsupportedBrotliFeature, B.decodeStreamChunksIntoLimited(&chunks, scratch, output, n));
    var refused = opts;
    refused.history = history[0 .. history.len - 1];
    try t.expectError(error.PreflightHistoryTooSmall, B.decodedStreamChunksSizeWithPreflight(&chunks, scratch, refused));
    try t.expectError(error.PreflightHistoryTooSmall, B.decodeStreamChunksIntoWithPreflight(&chunks, scratch, output, refused));
    try t.expectEqual(@as(u8, guard), history[history.len - 1]);
    refused = opts;
    refused.max_output_len -= 1;
    try t.expectError(error.OutputLimitExceeded, B.decodeStreamChunksIntoWithPreflight(&chunks, scratch, output, refused));
    refused = opts;
    refused.expected_output_len = n + 1;
    try t.expectError(error.SizeMismatch, B.decodedStreamPrefixChunksSizeWithPreflight(&prefixed, scratch, refused));
    try t.expectError(error.OutputTooSmall, B.decodeStreamChunksIntoWithPreflight(&chunks, scratch, output[0 .. n - 1], opts));
    try t.expectError(error.TrailingData, B.decodedStreamChunksSizeWithPreflight(&prefixed, scratch, opts));
    try t.expectError(error.TrailingData, B.decodeStreamChunksIntoWithPreflight(&prefixed, scratch, output, opts));
    try t.expect(std.mem.allEqual(u8, output, guard));

    profile.reset();
    try t.expectEqual(@as(B.Counter, n), try B.decodedStreamChunksSizeWithPreflight(&chunks, scratch, opts));
    try h.zeroProfile(profile, 0);
    profile.reset();
    const size = try B.decodedStreamPrefixChunksSizeWithPreflight(&prefixed, scratch, opts);
    try t.expectEqual(wire.len, size.input_read);
    try t.expectEqual(@as(B.Counter, n), size.decoded_bytes);
    try h.zeroProfile(profile, 0);
    profile.reset();
    const decoded = try B.decodeStreamPrefixChunksIntoWithPreflight(&prefixed, scratch, output, opts);
    try t.expectEqual(wire.len, decoded.input_read);
    try t.expectEqual(n, decoded.output_written);
    try t.expectEqualSlices(u8, wire, scratch[0..wire.len]);
    try t.expectEqualStrings("tail", scratch[wire.len..joined_len]);
    try t.expectEqualSlices(u8, plain, output[0..n]);
    try h.zeroProfile(profile, 0);

    // An all-identity join may alias the chunk backing exactly.
    @memset(output, guard);
    profile.reset();
    try t.expectEqual(n, try B.decodeStreamChunksIntoWithPreflight(&chunks, wire, output, opts));
    try t.expectEqualSlices(u8, plain, output[0..n]);
    try h.zeroProfile(profile, 0);
    try eagerContracts(B, &chunks, wire.len, plain, scratch, output, opts, &profile);
    try t.expectEqual(@as(u8, guard), backing[0]);
    try t.expectEqual(@as(u8, guard), scratch[joined_len]);
    try t.expect(std.mem.allEqual(u8, output[n..], guard));
}

fn borrowContracts(comptime B: type, wire: []u8, chunks: [][]const u8, scratch: []u8, output: []u8, opts: B.DecodePreflightOptions, profile: *B.DecodeMemoryProfile) !void {
    const input_before = try h.a.dupe(u8, wire);
    defer h.a.free(input_before);
    const table_before = try h.a.dupe([]const u8, chunks);
    defer h.a.free(table_before);
    const table = std.mem.sliceAsBytes(chunks);
    const profile_bytes = std.mem.asBytes(profile);
    var raw_prefix = [_]u8{guard} ** 8;
    var checked = opts;
    checked.decode.shared_dictionary = .{ .raw_prefixes = &.{&raw_prefix} };

    for ([_][]u8{ wire, table, scratch[wire.len - 1 ..][0..1], profile_bytes, &raw_prefix }) |span| {
        var refused = checked;
        refused.history = span;
        try t.expectError(error.InvalidBlockPlan, B.decodedStreamChunksSizeWithPreflight(chunks, scratch, refused));
        try t.expectError(error.InvalidBlockPlan, B.decodeStreamChunksIntoWithPreflight(chunks, scratch, output, refused));
    }
    for ([_][]u8{ wire, table, scratch[wire.len - 1 ..][0..1], profile_bytes, &raw_prefix, opts.history }) |span| {
        try t.expectError(error.InvalidBlockPlan, B.decodeStreamChunksIntoWithPreflight(chunks, scratch, span, checked));
    }
    // An observer embedded in chunk backing must not be recorded either.
    const observed = [_][]const u8{ wire, profile_bytes };
    try t.expectError(error.InvalidBlockPlan, B.decodedStreamPrefixChunksSizeWithPreflight(&observed, scratch, opts));
    try t.expectEqualSlices(u8, input_before, wire);
    for (table_before, chunks) |before, after| {
        try t.expectEqual(before.ptr, after.ptr);
        try t.expectEqual(before.len, after.len);
    }
    try t.expect(std.mem.allEqual(u8, &raw_prefix, guard));
}

fn eagerContracts(comptime B: type, chunks: []const []const u8, wire_len: usize, plain: []const u8, scratch: []u8, output: []u8, opts: B.DecodePreflightOptions, profile: *B.DecodeMemoryProfile) !void {
    profile.reset();
    var decoder = try B.StreamDecoder.initFromChunksWithPreflight(chunks, scratch, output, opts);
    try h.zeroProfile(profile.*, 0);
    var emitted: [3]u8 = undefined;
    @memset(scratch[0..wire_len], guard);
    @memset(opts.history, guard); // Eager init retains only the decoded output.
    try t.expectEqual(emitted.len, (try decoder.step(&emitted)).progress.output_written);
    try t.expectEqualSlices(u8, plain[0..emitted.len], &emitted);

    var refused = opts;
    refused.expected_output_len = plain.len + 1;
    try t.expectError(error.SizeMismatch, decoder.resetFromChunksWithPreflight(chunks, scratch, output, refused));
    const snapshot = decoder.snapshot();
    const diagnostics = decoder.diagnostics();
    try t.expectEqual(emitted.len, snapshot.output_written);
    try t.expectEqualStrings("SizeMismatch", diagnostics.last_error_name);
    @memset(scratch[0..wire_len], guard);
    profile.reset();
    refused = opts;
    refused.history = output[0..1]; // Already drained, but still protected.
    try t.expectError(error.InvalidBlockPlan, decoder.resetFromChunksWithPreflight(chunks, scratch, &.{}, refused));
    try t.expectError(error.InvalidBlockPlan, decoder.resetFromChunksWithPreflight(chunks, output[0..wire_len], &.{}, opts));
    try t.expectError(error.InvalidBlockPlan, decoder.resetFromChunksWithPreflight(chunks, scratch, std.mem.asBytes(&decoder), opts));
    try t.expectEqualDeep(snapshot, decoder.snapshot());
    try t.expectEqualDeep(diagnostics, decoder.diagnostics());
    try t.expectEqual(B.DecodeMemoryProfile{}, profile.*);
    try t.expect(std.mem.allEqual(u8, scratch[0..wire_len], guard));
    try t.expectEqualSlices(u8, plain, output[0..plain.len]);
    try t.expectEqual(emitted.len, (try decoder.step(&emitted)).progress.output_written);
    try t.expectEqualSlices(u8, plain[emitted.len..][0..emitted.len], &emitted);

    try decoder.resetFromChunksWithPreflight(chunks, scratch, output, opts);
    try h.zeroProfile(profile.*, 0);
    try t.expectEqual(@as(usize, 0), decoder.snapshot().output_written);
    try t.expectEqualStrings("", decoder.diagnostics().last_error_name);
    try t.expectEqualSlices(u8, plain, output[0..plain.len]);
}
