//! Frame-level regression cover for the 64...128 KiB wide fast block parser.
//!
//! `zstd/match/double_fast/sequence_parser.zig` owns the production compact
//! sequence records used by speed-first levels on blocks above 64 KiB. The
//! parser-level differential tests keep its token stream exact against the
//! wide-token implementation; this file adds the complementary end-to-end
//! guard: a deterministic payload that fills exactly one maximum-size block
//! must keep its frozen plan and wire budget while still round-tripping at the
//! levels that consume wide blocks.

const std = @import("std");
const lz77 = @import("../lz77.zig");
const zstd = @import("../zstd.zig");
const double_fast = @import("../zstd/match/double_fast.zig");
const a = std.testing.allocator;

const payload_len = 128 * 1024;

const lorem =
    "lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor " ++
    "incididunt ut labore et dolore magna aliqua ut enim ad minim veniam quis " ++
    "nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat " ++
    "duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore " ++
    "eu fugiat nulla pariatur excepteur sint occaecat cupidatat non proident sunt " ++
    "in culpa qui officia deserunt mollit anim id est laborum";

/// Text-like payload: pseudo-random windows of repeated prose keep the long
/// match table busy with realistic short and medium matches instead of a
/// single trivial repetition. This shape separates the wide parser's hash
/// table widths, so a width regression moves both the plan and the wire.
fn buildPayload(buffer: []u8) void {
    var state: u32 = 0x9e37_79b9;
    var index: usize = 0;
    while (index < buffer.len) {
        state = state *% 1_664_525 +% 1_013_904_223;
        const start: usize = @intCast((state >> 8) % lorem.len);
        const take = @min(@as(usize, 24) + ((state >> 24) & 63), buffer.len - index);
        for (0..take) |offset| buffer[index + offset] = lorem[(start + offset) % lorem.len];
        index += take;
    }
}

test "Zstd wide fast compact records stay within their frozen 128 KiB plan" {
    var payload: [payload_len]u8 = undefined;
    buildPayload(&payload);
    // The wide parser reads only these three option fields; production passes
    // `zstdHashParserOptions(block.len)`, which resolves to the same values for
    // a maximum-size block.
    const options: lz77.GreedyOptions = .{
        .window_len = lz77.default_window_len,
        .min_match = 4,
        .max_match = lz77.max_match_len,
    };
    var records: std.ArrayList(double_fast.SequenceRecord) = .empty;
    defer records.deinit(a);
    const stats = try double_fast.planSequencesReuse(&records, a, &payload, options, false);
    try std.testing.expectEqual(@as(usize, 4292), stats.matches);
    try std.testing.expectEqual(@as(usize, 1121), stats.literals);
    try std.testing.expectEqual(@as(usize, 129_951), stats.matched_bytes);
    try std.testing.expectEqual(stats.matches, records.items.len);
    try std.testing.expectEqual(payload.len, stats.literals + stats.matched_bytes);
    // This payload exceeds the compact one-record-per-64-bytes reservation, so
    // the test also covers the caller-owned buffer growth path.
    try std.testing.expect(stats.matches > payload.len / 64);
    try std.testing.expect(records.capacity >= payload.len / 64);
}

test "Zstd wide fast level one and three round trip at the 128 KiB block bound" {
    var payload: [payload_len]u8 = undefined;
    buildPayload(&payload);
    // Ceilings are the current frozen wires. They are deliberately one-sided so
    // a real size improvement does not need to edit this guard, while any
    // growth (for example a narrower long-match hash table) fails.
    for ([_]struct { level: i32, max_encoded: usize }{
        .{ .level = 1, .max_encoded = 11_524 },
        .{ .level = 3, .max_encoded = 7_515 },
    }) |row| {
        const encoded = try zstd.encodeFrameWithLevelAndOptionsAlloc(a, &payload, row.level, .{});
        defer a.free(encoded);
        const decoded = try zstd.decodeFrameAlloc(a, encoded);
        defer a.free(decoded);
        try std.testing.expectEqualSlices(u8, &payload, decoded);
        try std.testing.expect(encoded.len <= row.max_encoded);
    }
}
