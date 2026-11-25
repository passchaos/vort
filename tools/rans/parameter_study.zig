//! Deterministic rANS parameter study (ratio/overhead only).
//!
//! Sweeps the two open design parameters — interleaving lane count N and model
//! precision L — across representative symbol distributions and message sizes,
//! encoding an experimental VRB1 block for every combination. It emits one CSV
//! row per configuration with the byte breakdown and a fixed-point
//! bits-per-symbol figure, and asserts each block decodes back to the exact
//! input (so the binary also serves as a configuration-matrix smoke test).
//!
//! This deliberately measures compressed SIZE and framing overhead, not decode
//! throughput: the current decoder runs lanes scalarly, so N-dependent
//! instruction-level parallelism cannot be observed until a parallel/SIMD
//! executor exists. Treat these numbers as ratio/overhead evidence only.
const std = @import("std");
const rans = @import("rans");
const block = rans.block;

const lane_choices = [_]u8{ 1, 2, 4, 8 };
const log2_choices = [_]u8{ 8, 10, 12, 14, 16 };
const message_sizes = [_]usize{ 16, 256, 4096 };
const max_alphabet: usize = 32;

const Distribution = enum {
    uniform,
    skewed,
    binary_dominant,
    single,
    mixed,

    fn name(self: Distribution) []const u8 {
        return @tagName(self);
    }
};

/// Build a deterministic histogram for the distribution over `alphabet_size`.
fn buildCounts(random: std.Random, distribution: Distribution, alphabet_size: usize, counts: []u32) void {
    switch (distribution) {
        .single => {
            counts[0] = 1000;
            for (counts[1..alphabet_size]) |*c| c.* = 0;
        },
        .uniform => {
            for (counts[0..alphabet_size]) |*c| c.* = 1000;
        },
        .binary_dominant => {
            counts[0] = 100_000;
            if (alphabet_size > 1) counts[1] = 7 else counts[0] += 7;
            for (counts[2..alphabet_size]) |*c| c.* = 0;
        },
        .skewed => {
            // Geometric decay so a few symbols dominate but all stay active.
            for (counts[0..alphabet_size], 0..) |*c, index| {
                const shift: u5 = @intCast(@min(index, 5));
                const scale: u32 = @as(u32, 1) << shift;
                c.* = @max(1, 2048 / scale);
            }
        },
        .mixed => {
            for (counts[0..alphabet_size]) |*c| c.* = random.intRangeAtMost(u32, 1, 4000);
        },
    }
}

/// Draw one symbol index weighted by the histogram using inverse-CDF sampling.
fn sampleSymbol(random: std.Random, counts: []const u32, total: u64) u16 {
    const pick = random.intRangeAtMost(u64, 1, total);
    var cumulative: u64 = 0;
    for (counts, 0..) |count, index| {
        cumulative += count;
        if (pick <= cumulative) return @intCast(index);
    }
    return 0;
}

fn activeAlphabet(distribution: Distribution) usize {
    return switch (distribution) {
        .single => 1,
        .binary_dominant => 2,
        else => max_alphabet,
    };
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    var prng = std.Random.DefaultPrng.init(0x7a57_a511);
    const random = prng.random();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print(
        "distribution,message_len,alphabet_size,log2_scale,L,lanes,total_bytes,header_bytes,model_bytes,frame_bytes,renorm_bytes,bps_milli,roundtrip\n",
        .{},
    );

    const distributions = [_]Distribution{ .uniform, .skewed, .binary_dominant, .single, .mixed };

    for (distributions) |distribution| {
        const alphabet_size = activeAlphabet(distribution);
        var counts: [max_alphabet]u32 = undefined;
        @memset(&counts, 0);
        buildCounts(random, distribution, alphabet_size, &counts);

        var histogram_total: u64 = 0;
        for (counts[0..alphabet_size]) |c| histogram_total += c;

        for (message_sizes) |message_len| {
            const symbols = try allocator.alloc(u16, message_len);
            defer allocator.free(symbols);
            for (symbols) |*s| s.* = sampleSymbol(random, &counts, histogram_total);

            for (log2_choices) |log2_scale| {
                // Precision must offer at least one slot per active symbol.
                const slot_count: usize = @as(usize, 1) << @intCast(log2_scale);
                if (alphabet_size > slot_count) continue;

                for (lane_choices) |lane_count| {
                    const block_bytes = try block.encodeOwned(
                        allocator,
                        counts[0..alphabet_size],
                        symbols,
                        log2_scale,
                        lane_count,
                    );
                    defer allocator.free(block_bytes);

                    const decoded = try block.decodeOwned(allocator, block_bytes);
                    defer allocator.free(decoded);
                    const roundtrip = std.mem.eql(u16, decoded, symbols);
                    if (!roundtrip) return error.RoundTripMismatch;

                    const header_bytes: usize = block.header_len;
                    const model_bytes: usize = alphabet_size * 4;
                    const frame_bytes: usize = (@as(usize, lane_count) + (@as(usize, lane_count) + 1)) * 4;
                    const renorm_bytes = block_bytes.len - header_bytes - model_bytes - frame_bytes;
                    // Millibits per symbol keeps the metric integer and exact.
                    const bps_milli: usize = if (message_len == 0)
                        0
                    else
                        (block_bytes.len * 8 * 1000) / message_len;

                    try stdout.print(
                        "{s},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{s}\n",
                        .{
                            distribution.name(),
                            message_len,
                            alphabet_size,
                            log2_scale,
                            slot_count,
                            lane_count,
                            block_bytes.len,
                            header_bytes,
                            model_bytes,
                            frame_bytes,
                            renorm_bytes,
                            bps_milli,
                            if (roundtrip) "ok" else "fail",
                        },
                    );
                }
            }
        }
    }
    try stdout.flush();
}
