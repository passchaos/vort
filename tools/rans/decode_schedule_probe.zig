//! Single-host diagnostic: does scalar lockstep scheduling expose ILP?
//!
//! Zig 0.16 cannot do a portable dynamic-index gather, so no table-driven SIMD
//! rANS decoder exists yet. This probe measures the one ILP lever that IS
//! available without gather: whether advancing the independent lanes in
//! lockstep rounds (adjacent dependency chains) lets a superscalar core overlap
//! them, compared with draining one lane fully before the next.
//!
//! Both schedules call the identical scalar per-lane `next` the same number of
//! times on the same encoded block; only the ordering differs. The probe is a
//! diagnostic, NOT an adoption gate: single host, single binary, no CPU pinning
//! or paired-interleave protocol. Any throughput decision still requires the
//! section-8 paired A/B. Buffers are preallocated outside the timed region and
//! outputs are cross-checked once per lane count.
const std = @import("std");
const rans = @import("rans");
const InterleavedEncoder = rans.InterleavedEncoder;
const Table = rans.Table;

const lane_choices = [_]u8{ 1, 2, 4, 8 };
const message_len: usize = 1 << 20; // ~1M symbols per block
const log2_scale: u8 = 12;
const alphabet_size: usize = 24;
const warmup_iters: usize = 2;
const timed_iters: usize = 9; // median is robust to one noisy batch

const Clock = std.Io.Clock;

/// Elapsed durations from a monotonic clock are always non-negative, so the
/// signed nanosecond value converts safely to u64 for timing arithmetic.
fn toNs(duration: anytype) u64 {
    return @intCast(duration.toNanoseconds());
}

fn buildModel(allocator: std.mem.Allocator) !Table {
    // Geometric-skew histogram keeps all 24 symbols active.
    var counts: [alphabet_size]u32 = undefined;
    for (&counts, 0..) |*c, index| {
        const shift: u5 = @intCast(@min(index, 5));
        c.* = @max(1, 4096 / (@as(u32, 1) << shift));
    }
    return rans.normalize(allocator, &counts, log2_scale);
}

fn buildSymbols(allocator: std.mem.Allocator) ![]u16 {
    var prng = std.Random.DefaultPrng.init(0xdec0_de);
    const random = prng.random();
    const symbols = try allocator.alloc(u16, message_len);
    for (symbols) |*s| s.* = @intCast(random.intRangeAtMost(usize, 0, alphabet_size - 1));
    return symbols;
}

/// Build one scalar decoder per lane from the stream. Both schedules use the
/// exact same decoder array and per-lane contiguous scratch, so the only
/// varying factor is the order in which lanes are visited.
fn buildLaneDecoders(stream: rans.InterleavedStream) [rans.max_lanes]rans.Decoder {
    var decoders: [rans.max_lanes]rans.Decoder = undefined;
    var lane: usize = 0;
    while (lane < stream.lane_count) : (lane += 1) {
        decoders[lane] = rans.Decoder.init(
            stream.laneState(lane),
            stream.laneBytes(lane),
            stream.log2_scale,
        );
    }
    return decoders;
}

/// Per-lane contiguous offsets into the shared scratch buffer.
fn laneOffsets(stream: rans.InterleavedStream, offsets: *[rans.max_lanes + 1]usize) void {
    offsets[0] = 0;
    var lane: usize = 0;
    while (lane < stream.lane_count) : (lane += 1) {
        offsets[lane + 1] = offsets[lane] +
            rans.laneSymbolCount(message_len, stream.lane_count, lane);
    }
}

/// Nested schedule: fully drain each lane before starting the next. Within a
/// lane the steps form one dependent chain; chains are not interleaved.
fn runNested(stream: rans.InterleavedStream, model: Table, scratch: []u16) !void {
    const n: usize = stream.lane_count;
    var decoders = buildLaneDecoders(stream);
    var offsets: [rans.max_lanes + 1]usize = undefined;
    laneOffsets(stream, &offsets);

    var lane: usize = 0;
    while (lane < n) : (lane += 1) {
        const count = rans.laneSymbolCount(message_len, n, lane);
        var step: usize = 0;
        while (step < count) : (step += 1) {
            scratch[offsets[lane] + step] = try decoders[lane].next(model);
        }
    }
}

/// Lockstep schedule: every round, advance each still-active lane by one step.
/// Adjacent steps belong to different independent lanes, the superscalar-ILP
/// access pattern. Output addressing is identical to `runNested` (each lane
/// writes its own contiguous slice at a running index).
fn runLockstep(stream: rans.InterleavedStream, model: Table, scratch: []u16) !void {
    const n: usize = stream.lane_count;
    var decoders = buildLaneDecoders(stream);
    var offsets: [rans.max_lanes + 1]usize = undefined;
    laneOffsets(stream, &offsets);

    var round: usize = 0;
    while (true) {
        var any_active = false;
        var lane: usize = 0;
        while (lane < n) : (lane += 1) {
            const count = rans.laneSymbolCount(message_len, n, lane);
            if (round < count) {
                any_active = true;
                scratch[offsets[lane] + round] = try decoders[lane].next(model);
            }
        }
        if (!any_active) break;
        round += 1;
    }
}

/// Reconstruct forward-order symbols from per-lane contiguous (reverse-order)
/// output and verify against the canonical input. Used once per lane count, not
/// inside the timed loop.
fn verifyLaneOutput(stream: rans.InterleavedStream, scratch: []u16, symbols: []const u16) !void {
    const n: usize = stream.lane_count;
    var offsets: [rans.max_lanes + 1]usize = undefined;
    laneOffsets(stream, &offsets);
    var lane: usize = 0;
    while (lane < n) : (lane += 1) {
        const count = rans.laneSymbolCount(message_len, n, lane);
        var k: usize = 0;
        while (k < count) : (k += 1) {
            const position = lane + (count - 1 - k) * n;
            if (scratch[offsets[lane] + k] != symbols[position]) return error.LaneOutputMismatch;
        }
    }
}

fn medianOf(values: []u64) u64 {
    // Small fixed-size insertion sort; timed_iters is tiny.
    var copy: [timed_iters]u64 = undefined;
    for (values, 0..) |v, i| copy[i] = v;
    var i: usize = 1;
    while (i < copy.len) : (i += 1) {
        const key = copy[i];
        var j = i;
        while (j > 0 and copy[j - 1] > key) : (j -= 1) {
            copy[j] = copy[j - 1];
        }
        copy[j] = key;
    }
    return copy[copy.len / 2];
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    var model = try buildModel(allocator);
    defer model.deinit();
    const symbols = try buildSymbols(allocator);
    defer allocator.free(symbols);

    const scratch = try allocator.alloc(u16, message_len);
    defer allocator.free(scratch);
    const lockstep_scratch = try allocator.alloc(u16, message_len);
    defer allocator.free(lockstep_scratch);

    var stdout_buffer: [512]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("lanes,schedule,median_ns,ns_per_symbol_milli,speedup_vs_nested_milli\n", .{});

    for (lane_choices) |lane_count| {
        var enc = try InterleavedEncoder.init(allocator, log2_scale, lane_count);
        defer enc.deinit();
        for (symbols) |s| try enc.encodeSymbol(model, s);
        var stream = try enc.finishOwned();
        defer stream.deinit();

        // Correctness cross-check (outside timing): both schedules produce the
        // same per-lane output and reconstruct the canonical symbols.
        try runNested(stream, model, scratch);
        try runLockstep(stream, model, lockstep_scratch);
        if (!std.mem.eql(u16, scratch, lockstep_scratch)) return error.ScheduleMismatch;
        try verifyLaneOutput(stream, scratch, symbols);

        var nested_samples: [timed_iters]u64 = undefined;
        var lockstep_samples: [timed_iters]u64 = undefined;

        var iter: usize = 0;
        while (iter < warmup_iters + timed_iters) : (iter += 1) {
            // Alternate which schedule runs first so neither is always measured
            // in the second (warm-cache) position; samples are keyed by schedule.
            if (iter % 2 == 0) {
                const t0 = Clock.awake.now(init.io);
                try runNested(stream, model, scratch);
                const t1 = Clock.awake.now(init.io);
                try runLockstep(stream, model, lockstep_scratch);
                const t2 = Clock.awake.now(init.io);
                if (iter >= warmup_iters) {
                    nested_samples[iter - warmup_iters] = toNs(t0.durationTo(t1));
                    lockstep_samples[iter - warmup_iters] = toNs(t1.durationTo(t2));
                }
            } else {
                const t0 = Clock.awake.now(init.io);
                try runLockstep(stream, model, lockstep_scratch);
                const t1 = Clock.awake.now(init.io);
                try runNested(stream, model, scratch);
                const t2 = Clock.awake.now(init.io);
                if (iter >= warmup_iters) {
                    lockstep_samples[iter - warmup_iters] = toNs(t0.durationTo(t1));
                    nested_samples[iter - warmup_iters] = toNs(t1.durationTo(t2));
                }
            }
        }

        const nested_median = medianOf(&nested_samples);
        const lockstep_median = medianOf(&lockstep_samples);
        const nested_milli: u64 = (nested_median * 1000) / message_len;
        const lockstep_milli: u64 = (lockstep_median * 1000) / message_len;
        // Fixed-point speedup (milli-x): nested_time / lockstep_time.
        const speedup_milli: u64 = (nested_median * 1000) / lockstep_median;

        try stdout.print("{d},nested,{d},{d},\n", .{ lane_count, nested_median, nested_milli });
        try stdout.print("{d},lockstep,{d},{d},{d}\n", .{ lane_count, lockstep_median, lockstep_milli, speedup_milli });
    }
    try stdout.flush();
}
