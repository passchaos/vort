//! Direct chunk preflight and replay contracts on the long-copy fixture.
const std = @import("std");
const h = @import("helpers.zig");
const t = std.testing;
const guard = 0xa5;

pub fn contracts(comptime B: type, wire: []u8, plain: []const u8, history: []u8) !void {
    const W = B.DirectChunkPreflightWorkspace;
    const workspace = try h.a.create(W);
    defer h.a.destroy(workspace);

    const split = wire.len - 2;
    const head = [_][]const u8{ "", wire[0..1], wire[1..history.len], "", wire[history.len..split] };
    var chunks = head ++ [_][]const u8{ wire[split..], "" };
    const truncated = head ++ [_][]const u8{ wire[split..][0..1], "" };
    const boundary = chunks ++ [_][]const u8{ "ta", "", "il" };
    // The final compressed byte is inside a chunk and the suffix spans chunks.
    const mixed = [4]u8{ wire[split], wire[split + 1], 't', 'a' };
    const interior = head ++ [_][]const u8{ &mixed, "", "il", "" };

    const n = plain.len;
    const backing = try h.a.alloc(u8, n + 2);
    defer h.a.free(backing);
    const output = backing[1..];
    @memset(backing, guard);
    @memset(history, guard);
    var profile: B.DecodeMemoryProfile = .{};
    const opts: W.Options = .{ .preflight = .{
        .history = history,
        .max_output_len = n,
        .expected_output_len = n,
        .decode = .{ .max_total_working_memory = 0, .memory_profile = &profile },
    } };
    const header_scratch = try h.a.alloc(u8, B.default_incremental_compressed_header_bytes + 1);
    defer h.a.free(header_scratch);
    @memset(header_scratch, guard);
    var with_scratch = opts;
    with_scratch.compressed_header_scratch = header_scratch;
    try borrowContracts(B, workspace, wire, &chunks, output, with_scratch);

    var refused = opts;
    refused.preflight.history = history[0 .. history.len - 1];
    try t.expectError(error.PreflightHistoryTooSmall, workspace.decodedSize(&chunks, refused));
    try t.expectError(error.PreflightHistoryTooSmall, workspace.decodeInto(&chunks, output, refused));
    try t.expectEqual(@as(u8, guard), history[history.len - 1]);
    refused = opts;
    refused.preflight.max_output_len = n - 1; // The final meta-block exceeds the cap.
    try t.expectError(error.OutputLimitExceeded, workspace.decodeInto(&chunks, output, refused));
    refused = opts;
    refused.preflight.expected_output_len = n + 1;
    try t.expectError(error.SizeMismatch, workspace.decodedPrefixSize(&interior, refused));
    try t.expectError(error.SizeMismatch, workspace.decodePrefixInto(&interior, output, refused));
    try t.expectError(error.OutputTooSmall, workspace.decodeInto(&chunks, output[0 .. n - 1], opts));
    try t.expectError(error.TruncatedFrame, workspace.decodeInto(&truncated, output, opts));
    try t.expectError(error.TrailingData, workspace.decodedSize(&interior, opts));
    try t.expectError(error.TrailingData, workspace.decodeInto(&boundary, output, opts));
    try t.expectError(error.TrailingData, workspace.decodeInto(&interior, output, opts));
    try t.expect(std.mem.allEqual(u8, backing, guard));

    profile.reset();
    try t.expectEqual(@as(B.Counter, n), try workspace.decodedSize(&chunks, opts));
    try h.zeroProfile(profile, 0);
    for ([_][]const []const u8{ &boundary, &interior }) |prefixed| {
        profile.reset();
        const size = try workspace.decodedPrefixSize(prefixed, opts);
        try t.expectEqual(wire.len, size.input_read);
        try t.expectEqual(@as(B.Counter, n), size.decoded_bytes);
        try h.zeroProfile(profile, 0);
    }

    profile.reset();
    const replayed = try workspace.decodePrefixInto(&interior, output, with_scratch);
    try t.expectEqual(wire.len, replayed.input_read);
    try t.expectEqual(n, replayed.output_written);
    try t.expectEqualSlices(u8, plain, output[0..n]);
    try t.expectEqual(@as(u8, guard), output[n]);
    try h.zeroProfile(profile, 0);

    // Reuse the same workspace again, switching back to embedded header storage.
    @memset(output, guard);
    profile.reset();
    try t.expectEqual(n, try workspace.decodeInto(&chunks, output[0..n], opts));
    try t.expectEqualSlices(u8, plain, output[0..n]);
    try t.expectEqual(@as(u8, guard), backing[0]);
    try t.expectEqual(@as(u8, guard), output[n]);
    try h.zeroProfile(profile, 0);
    try formatContracts(B, workspace);
}

fn formatContracts(comptime B: type, workspace: *B.DirectChunkPreflightWorkspace) !void {
    const empty = [_][]const u8{ "", &.{0x06}, "" };
    try t.expectEqual(@as(usize, 0), try workspace.decodeInto(&empty, &.{}, .{
        .preflight = .{ .history = &.{}, .max_output_len = 0, .expected_output_len = 0 },
    }));

    const wire = try B.encodeStoredStreamWithOptionsAlloc(h.a, "abc", .{ .large_window = true, .window_bits = 25 });
    defer h.a.free(wire);
    const pieces = [_][]const u8{ wire[0..1], wire[1..2], wire[2..] };
    var history: [1]u8 = undefined;
    var output: [3]u8 = @splat(guard);
    var options: B.DirectChunkPreflightWorkspace.Options = .{ .preflight = .{ .history = &history } };
    try t.expectError(error.CorruptFrame, workspace.decodeInto(&pieces, &output, options));
    options.preflight.decode.allow_large_window = true;
    options.preflight.history = &.{};
    try t.expectError(error.PreflightHistoryTooSmall, workspace.decodeInto(&pieces, &output, options));
    try t.expect(std.mem.allEqual(u8, &output, guard));
    options.preflight.history = &history;
    try t.expectEqual(output.len, try workspace.decodeInto(&pieces, &output, options));
    try t.expectEqualStrings("abc", &output);
}

fn borrowContracts(comptime B: type, workspace: *B.DirectChunkPreflightWorkspace, wire: []u8, chunks: [][]const u8, output: []u8, opts: B.DirectChunkPreflightWorkspace.Options) !void {
    const history = opts.preflight.history;
    const profile = opts.preflight.decode.memory_profile.?;
    const profile_bytes = std.mem.asBytes(profile);
    const workspace_bytes = std.mem.asBytes(workspace);
    // Guard the raw storage to verify that admission precedes workspace writes.
    @memset(workspace_bytes, guard);
    const table = std.mem.sliceAsBytes(chunks);
    const wire_before = try h.a.dupe(u8, wire);
    defer h.a.free(wire_before);
    const table_before = try h.a.dupe(u8, table);
    defer h.a.free(table_before);

    for ([_][]u8{ wire, table, workspace_bytes, profile_bytes }) |span| {
        var refused = opts;
        refused.preflight.history = span;
        try t.expectError(error.InvalidBlockPlan, workspace.decodedSize(chunks, refused));
        try t.expectError(error.InvalidBlockPlan, workspace.decodeInto(chunks, output, refused));
    }
    for ([_][]u8{ wire, table, history, workspace_bytes, profile_bytes }) |span| {
        try t.expectError(error.InvalidBlockPlan, workspace.decodeInto(chunks, span, opts));
    }
    for ([_][]u8{ wire, table, output, history, workspace_bytes, profile_bytes }) |span| {
        var refused = opts;
        refused.compressed_header_scratch = span;
        try t.expectError(error.InvalidBlockPlan, workspace.decodeInto(chunks, output, refused));
    }
    // Prefix mode still protects the ignored suffix against writable borrows.
    for ([_][]const u8{ output, history, workspace_bytes, profile_bytes, opts.compressed_header_scratch }) |span| {
        try t.expectError(error.InvalidBlockPlan, workspace.decodePrefixInto(&.{ wire, span }, output, opts));
    }
    var refused = opts;
    // Size-only calls have no output borrow; this overlap applies to decode.
    refused.preflight.history = output;
    try t.expectError(error.InvalidBlockPlan, workspace.decodeInto(chunks, output, refused));
    refused = opts;
    const aliased_profile: *B.DecodeMemoryProfile = @ptrCast(@alignCast(workspace_bytes.ptr));
    refused.preflight.decode.memory_profile = aliased_profile;
    try t.expectError(error.InvalidBlockPlan, workspace.decodedSize(chunks, refused));

    try t.expectEqualSlices(u8, wire_before, wire);
    try t.expectEqualSlices(u8, table_before, table);
    try t.expect(std.mem.allEqual(u8, output, guard));
    try t.expect(std.mem.allEqual(u8, history, guard));
    try t.expect(std.mem.allEqual(u8, workspace_bytes, guard));
    try t.expect(std.mem.allEqual(u8, opts.compressed_header_scratch, guard));
    try t.expectEqual(B.DecodeMemoryProfile{}, profile.*);
}
