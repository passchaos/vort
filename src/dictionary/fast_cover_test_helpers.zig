const std = @import("std");
const types = @import("fast_cover/types.zig");
pub const allocator = std.testing.allocator;

pub const training = [_][]const u8{
    "service=alpha region=north method=get resource=/items status=ok message=first stable phrase",
    "service=alpha region=south method=get resource=/items status=ok message=second stable phrase",
    "service=beta region=west method=post resource=/events status=retry message=third stable phrase",
    "service=beta region=east method=post resource=/events status=retry message=fourth stable phrase",
    "service=gamma region=central method=get resource=/items status=ok message=fifth stable phrase",
    "service=gamma region=north method=post resource=/events status=retry message=sixth stable phrase",
};
pub const validation = [_][]const u8{
    "service=alpha region=north method=get resource=/items status=ok message=held out stable phrase",
    "service=beta region=east method=post resource=/events status=retry message=held out stable phrase",
};
pub fn randomCorpus() [5][67]u8 {
    var samples: [5][67]u8 = undefined;
    var state: u32 = 0x704ae91c;
    for (&samples, 0..) |*sample, index| for (sample, 0..) |*byte, offset| {
        state = state *% 1664525 +% 1013904223;
        byte.* = @truncate((state >> 24) ^ (index * 37 + offset / 7));
    };
    return samples;
}
pub fn views(samples: *const [5][67]u8) [5][]const u8 {
    return .{ &samples[0], &samples[1], &samples[2], &samples[3], &samples[4] };
}

/// Byte-by-byte little-endian assembly independently implements the published
/// multiplicative hash, without the production wide-load or selection helpers.
pub fn hash(sample: []const u8, offset: usize, d: usize, f: u8) usize {
    var word: u64 = 0;
    for (sample[offset..][0..d], 0..) |byte, index| word |= @as(u64, byte) << @intCast(index * 8);
    const mixed = if (d == 6) (word << 16) *% 227718039650203 else word *% 0xcf1bbcdcb7a56463;
    return @intCast(mixed >> @intCast(64 - f));
}
pub fn dmerCount(len: usize, d: usize) usize {
    return if (len < d) 0 else len - d + 1;
}

pub const Segment = struct { sample_index: usize, begin: usize, length: usize, score: u64 };
pub const SlowResult = struct {
    bytes: []u8,
    base_frequencies: []u32,
    remaining_frequencies: []u32,
    segments: std.ArrayList(Segment),
    frequency_observations: usize,
    epochs: usize,

    pub fn deinit(self: *SlowResult) void {
        allocator.free(self.bytes);
        allocator.free(self.base_frequencies);
        allocator.free(self.remaining_frequencies);
        self.segments.deinit(allocator);
        self.* = undefined;
    }
};

/// Exhaustive oracle: enumerate every prefix/window at every eligible sample
/// position and recompute distinct hashes from scratch. It shares no rolling
/// active-count logic or binary-search sample dispatch with the trainer.
pub fn slow(samples: []const []const u8, options: types.TrainOptions) !SlowResult {
    const table_len = @as(usize, 1) << @intCast(options.hash_log);
    const base = try allocator.alloc(u32, table_len);
    errdefer allocator.free(base);
    @memset(base, 0);
    var observations: usize = 0;
    for (samples) |sample| {
        var offset: usize = 0;
        while (offset < dmerCount(sample.len, 8)) : (offset += options.acceleration) {
            base[hash(sample, offset, options.dmer_size, options.hash_log)] += 1;
            observations += 1;
        }
    }
    const frequencies = try allocator.dupe(u32, base);
    errdefer allocator.free(frequencies);
    const offsets = try allocator.alloc(usize, samples.len + 1);
    defer allocator.free(offsets);
    offsets[0] = 0;
    for (samples, 0..) |sample, index| offsets[index + 1] = offsets[index] + dmerCount(sample.len, options.dmer_size);
    const k = options.segment_size orelse @min(options.target_size, 64);
    var count = @max(@as(usize, 1), options.target_size / k);
    var size = offsets[samples.len] / count;
    if (size < k * 10) {
        size = @min(k * 10, offsets[samples.len]);
        count = offsets[samples.len] / size;
    }
    var segments: std.ArrayList(Segment) = .empty;
    errdefer segments.deinit(allocator);
    const scratch = try allocator.alloc(u8, options.target_size);
    defer allocator.free(scratch);
    const seen = try allocator.alloc(bool, table_len);
    defer allocator.free(seen);
    var tail = scratch.len;
    var epoch: usize = 0;
    var zero_run: usize = 0;
    while (tail != 0) {
        const first = epoch * size;
        const last = if (epoch + 1 == count) offsets[samples.len] else first + size;
        epoch = (epoch + 1) % count;
        var best: ?Segment = null;
        for (samples, 0..) |sample, sample_index| {
            const begin = @max(first, offsets[sample_index]);
            const end = @min(last, offsets[sample_index + 1]);
            if (begin >= end) continue;
            const local_first = begin - offsets[sample_index];
            const local_last = end - offsets[sample_index];
            for (local_first + 1..local_last + 1) |window_end| {
                const window_begin = @max(local_first, window_end -| (k - options.dmer_size + 1));
                @memset(seen, false);
                var window_score: u64 = 0;
                for (window_begin..window_end) |offset| {
                    const bucket = hash(sample, offset, options.dmer_size, options.hash_log);
                    if (!seen[bucket]) {
                        seen[bucket] = true;
                        window_score += frequencies[bucket];
                    }
                }
                if (window_score > if (best) |value| value.score else 0) best = .{
                    .sample_index = sample_index,
                    .begin = window_begin,
                    .length = window_end - window_begin + options.dmer_size - 1,
                    .score = window_score,
                };
            }
        }
        if (best == null) {
            zero_run += 1;
            if (zero_run >= count) break;
            continue;
        }
        zero_run = 0;
        var selected = best.?;
        selected.length = @min(selected.length, tail);
        if (selected.length < options.dmer_size) break;
        tail -= selected.length;
        @memcpy(scratch[tail..][0..selected.length], samples[selected.sample_index][selected.begin..][0..selected.length]);
        for (selected.begin..selected.begin + selected.length - options.dmer_size + 1) |offset|
            frequencies[hash(samples[selected.sample_index], offset, options.dmer_size, options.hash_log)] = 0;
        try segments.append(allocator, selected);
    }
    return .{
        .bytes = try allocator.dupe(u8, scratch[tail..]),
        .base_frequencies = base,
        .remaining_frequencies = frequencies,
        .segments = segments,
        .frequency_observations = observations,
        .epochs = count,
    };
}

pub fn sentinel(bytes: []const u8) !void {
    for (bytes) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

pub const Score = @import("fast_cover_optimize/types.zig").Score;
/// Independent longest-prefix dictionary matcher. Charges dictionary bytes
/// once, literal bytes at eight bits, a four-bit match tag and offset bit width.
pub fn score(content: []const u8, samples: []const []const u8, minimum: usize) !Score {
    var result: Score = .{ .estimated_bits = content.len * 8, .dictionary_bytes = content.len };
    for (samples) |sample| {
        var position: usize = 0;
        while (position < sample.len) {
            var length: usize = 0;
            var offset: usize = 0;
            for (0..content.len) |candidate| {
                var matched: usize = 0;
                while (matched < sample.len - position and matched < content.len - candidate and sample[position + matched] == content[candidate + matched]) matched += 1;
                if (matched > length) {
                    length = matched;
                    offset = candidate;
                }
            }
            if (length >= minimum) {
                const bits = std.math.log2_int(usize, offset + 1) + 1;
                result.covered_bytes += length;
                result.matches += 1;
                result.distance_bits += bits;
                result.estimated_bits += bits + 4;
                position += length;
            } else {
                result.estimated_bits += 8;
                position += 1;
            }
        }
    }
    return result;
}
pub const PlainScorer = struct {
    pub fn init(_: std.mem.Allocator, _: void, _: []const []const u8, _: []const []const u8, _: @import("fast_cover_optimize/types.zig").OptimizeOptions) !PlainScorer {
        return .{};
    }
    pub fn score(_: *PlainScorer, content: []const u8, samples: []const []const u8, minimum: usize, _: types.TrainOptions) !Score {
        return @import("fast_cover_test_helpers.zig").score(content, samples, minimum);
    }
    pub fn deinit(_: *PlainScorer) void {}
};
pub fn better(a: Score, a_len: usize, a_serial: usize, b: Score, b_len: usize, b_serial: usize) bool {
    if (a.estimated_bits != b.estimated_bits) return a.estimated_bits < b.estimated_bits;
    if (a.covered_bytes != b.covered_bytes) return a.covered_bytes > b.covered_bytes;
    if (a.matches != b.matches) return a.matches < b.matches;
    if (a.distance_bits != b.distance_bits) return a.distance_bits < b.distance_bits;
    if (a_len != b_len) return a_len < b_len;
    return a_serial < b_serial;
}
