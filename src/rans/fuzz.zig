//! Deterministic structure-aware fuzzing for the experimental rANS block.
//!
//! There is no external reference decoder for the native block, so the safety
//! invariant is stronger than byte matching: every mutated block must either be
//! rejected with an error or decode to exactly the canonical symbol sequence.
//! A successful decode that returns different symbols is a failure. The whole
//! campaign uses a fixed-seed PRNG (no time or OS randomness) and is bounded so
//! it runs identically on native targets and under 32-bit WASI.
const std = @import("std");
const block_mod = @import("block.zig");
const max_lanes = @import("interleaved.zig").max_lanes;

const encodeOwned = block_mod.encodeOwned;
const decodeBounded = block_mod.decodeBounded;

const flip_masks = [_]u8{ 0x01, 0x80, 0x5a, 0xff };
/// Keep each campaign small enough for the WASM test runner while still
/// covering every region of every generated block.
const max_mutations_per_block: usize = 64;

pub const Stats = struct {
    valid_blocks: usize = 0,
    mutations: usize = 0,
    rejected: usize = 0,
    identical: usize = 0,
};

const scales = [_]u8{ 4, 8, 10, 12 };

const FuzzError = block_mod.Error || DivergentOutput;

const Outcome = enum { rejected, identical };

/// A mutated block decoded successfully but returned different symbols than the
/// canonical input. This is the one outcome the invariant forbids; ordinary
/// decoder rejections are expected. Keeping it separate means a call site can
/// never swallow it with a broad `catch {}`.
pub const DivergentOutput = error{DivergentOutput};

/// Decode one mutation and enforce the reject-or-equal invariant. Decoder
/// rejections are counted and returned as `.rejected`; a successful decode must
/// reproduce `baseline` exactly or this fails with `DivergentOutput`.
fn checkMutation(
    allocator: std.mem.Allocator,
    mutated: []const u8,
    baseline: []const u16,
    max_symbol_count: u32,
    stats: *Stats,
) DivergentOutput!Outcome {
    stats.mutations += 1;
    const decoded = decodeBounded(allocator, mutated, max_symbol_count) catch {
        stats.rejected += 1;
        return .rejected;
    };
    defer allocator.free(decoded);
    if (!std.mem.eql(u16, decoded, baseline)) return error.DivergentOutput;
    stats.identical += 1;
    return .identical;
}

/// Build one valid block from deterministic random parameters, prove it
/// round-trips, then replay truncation and byte-flip mutations.
fn fuzzOneBlock(
    allocator: std.mem.Allocator,
    random: std.Random,
    stats: *Stats,
) FuzzError!void {
    const log2_scale = scales[random.intRangeAtMost(usize, 0, scales.len - 1)];
    const slot_count: usize = @as(usize, 1) << @intCast(log2_scale);
    const lane_count: u8 = @intCast(random.intRangeAtMost(usize, 1, max_lanes));
    const alphabet_size = random.intRangeAtMost(usize, 1, @min(@as(usize, 32), slot_count));
    const message_len = random.intRangeAtMost(usize, 0, 192);

    var counts: [32]u32 = undefined;
    for (counts[0..alphabet_size]) |*c| c.* = random.intRangeAtMost(u32, 1, 4000);

    const symbols = allocator.alloc(u16, message_len) catch return error.OutOfMemory;
    defer allocator.free(symbols);
    for (symbols) |*s| s.* = @intCast(random.intRangeAtMost(usize, 0, alphabet_size - 1));

    const canonical = try encodeOwned(allocator, counts[0..alphabet_size], symbols, log2_scale, lane_count);
    defer allocator.free(canonical);

    // The unmutated block must decode to the exact input symbols.
    const baseline = try decodeBounded(allocator, canonical, block_mod.max_default_symbol_count);
    defer allocator.free(baseline);
    if (!std.mem.eql(u16, baseline, symbols)) return error.CorruptFrame;
    stats.valid_blocks += 1;

    // A bound comfortably above the real message so legitimate blocks pass but
    // a corrupted oversized declaration is still capped.
    const fuzz_max: u32 = @intCast(@max(message_len, 1) * 8 + 64);

    // Truncation: sample cut points across the whole block including the header
    // boundary and the final byte. Decoder rejections are counted inside
    // checkMutation; only a divergent successful decode escapes as an error.
    const cut_step: usize = @max(1, canonical.len / max_mutations_per_block);
    var cut: usize = 0;
    while (cut < canonical.len) : (cut += cut_step) {
        _ = try checkMutation(allocator, canonical[0..cut], baseline, fuzz_max, stats);
    }
    _ = try checkMutation(allocator, canonical[0 .. canonical.len - 1], baseline, fuzz_max, stats);
    _ = try checkMutation(allocator, canonical[0..block_mod.header_len], baseline, fuzz_max, stats);

    // Single-byte flips spread across header, model, states, offsets and renorm.
    const pos_step: usize = @max(1, canonical.len / max_mutations_per_block);
    var position: usize = 0;
    while (position < canonical.len) : (position += pos_step) {
        const mask = flip_masks[(position / pos_step) % flip_masks.len];
        var flipped = allocator.alloc(u8, canonical.len) catch return error.OutOfMemory;
        defer allocator.free(flipped);
        @memcpy(flipped, canonical);
        flipped[position] ^= mask;
        _ = try checkMutation(allocator, flipped, baseline, fuzz_max, stats);
    }
}

/// Run a fixed-seed campaign. Returns aggregate counts; the reject-or-equal
/// invariant is enforced inside, so a divergent successful decode surfaces as
/// an error rather than merely a statistic.
pub fn runCampaign(allocator: std.mem.Allocator, seed: u64, rounds: usize) FuzzError!Stats {
    var prng = std.Random.DefaultPrng.init(seed);
    const random = prng.random();
    var stats = Stats{};
    var round: usize = 0;
    while (round < rounds) : (round += 1) {
        try fuzzOneBlock(allocator, random, &stats);
    }
    return stats;
}

test "mutation campaign never returns divergent output and bounds allocations" {
    const allocator = std.testing.allocator;
    const stats = try runCampaign(allocator, 0x5eed_c0de, 24);
    // The campaign must have exercised real blocks and a substantial matrix.
    try std.testing.expect(stats.valid_blocks == 24);
    try std.testing.expect(stats.mutations > 0);
    // Every mutation is accounted for exactly once.
    try std.testing.expectEqual(stats.mutations, stats.rejected + stats.identical);
}

test "corrupted declared symbol count is capped before allocation" {
    const allocator = std.testing.allocator;
    const counts = [_]u32{ 7, 3 };
    const symbols = [_]u16{ 0, 1, 0, 0, 1, 0, 1, 0 };
    const canonical = try encodeOwned(allocator, &counts, &symbols, 8, 2);
    defer allocator.free(canonical);

    var oversized = try allocator.dupe(u8, canonical);
    defer allocator.free(oversized);
    // symbol_count lives at header bytes 10..14 (little-endian u32).
    std.mem.writeInt(u32, oversized[10..14], std.math.maxInt(u32), .little);

    // A tight caller budget rejects it before any symbol-output allocation.
    try std.testing.expectError(
        error.OutputLimitExceeded,
        decodeBounded(allocator, oversized, 1024),
    );
    // The default bounded entry also caps the hostile value, so no giant alloc.
    try std.testing.expectError(
        error.OutputLimitExceeded,
        block_mod.decodeOwned(allocator, oversized),
    );
}

test "within-bound symbol count tamper is caught by the header-covering CRC" {
    // Regression for the gap the mutation campaign found: a single-symbol block
    // emits zero renorm bytes and pins the state at the lower bound, so a
    // corrupted symbol_count cannot be detected by the post-decode checks. The
    // payload CRC must cover the semantic header and reject it instead of
    // returning a successful decode with a wrong symbol count.
    const allocator = std.testing.allocator;
    const counts = [_]u32{1};
    const symbols = [_]u16{0} ** 16;
    const canonical = try encodeOwned(allocator, &counts, &symbols, 8, 1);
    defer allocator.free(canonical);

    var tampered = try allocator.dupe(u8, canonical);
    defer allocator.free(tampered);
    // Bump the declared count but keep it inside any reasonable output budget,
    // so the bounded-allocation check does not fire first.
    std.mem.writeInt(u32, tampered[10..14], symbols.len + 1, .little);

    try std.testing.expectError(
        error.ChecksumMismatch,
        decodeBounded(allocator, tampered, block_mod.max_default_symbol_count),
    );
}
