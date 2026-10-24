const std = @import("std");
const types = @import("types.zig");
const resources = @import("resources.zig");

pub const Tables = struct {
    offsets: []usize,
    base: []u32,
    frequencies: []u32,
    active: []u32,
};

const Segment = struct {
    sample: usize = 0,
    begin: usize = 0,
    end: usize = 0,
    score: u64 = 0,
};

/// The hash constants and retained-bit widths are the Zstandard FastCover
/// d=6/8 hash family. Reading six bytes directly avoids an unnecessary overread.
fn hash(sample: []const u8, offset: usize, d: u8, f: u8) usize {
    const mixed: u64 = if (d == 6)
        (@as(u64, std.mem.readInt(u48, sample[offset..][0..6], .little)) << 16) *% 227_718_039_650_203
    else
        std.mem.readInt(u64, sample[offset..][0..8], .little) *% 0xcf1b_bcdc_b7a5_6463;
    return @intCast(mixed >> @intCast(64 - f));
}

/// Frequency observations use the reference read-width rule (eight bytes for
/// both d values) and restart sampling at every independent sample boundary.
pub fn collectFrequencies(samples: []const []const u8, options: types.TrainOptions, tables: Tables, profile: *types.Profile) void {
    @memset(tables.base, 0);
    profile.add("table_clear_bytes", tables.base.len * @sizeOf(u32));
    profile.add("frequency_passes", 1);
    tables.offsets[0] = 0;
    for (samples, 0..) |sample, index| {
        tables.offsets[index + 1] = tables.offsets[index] + resources.dmerCount(sample.len, options.dmer_size);
        const count = resources.dmerCount(sample.len, 8);
        var offset: usize = 0;
        var observations: usize = 0;
        while (offset < count) : (offset += @min(@as(usize, options.acceleration), count - offset)) {
            tables.base[hash(sample, offset, options.dmer_size, options.hash_log)] += 1;
            observations += 1;
        }
        profile.add("frequency_positions", count);
        profile.add("frequency_hashes", observations);
        profile.add("frequency_skipped_positions", count - observations);
    }
}

/// Distinct-hash sliding scores, frequency removal and cyclic epochs are the
/// FastCover selection model. Samples are independent, and the last epoch also
/// covers division remainders. An entire zero-score epoch cycle proves there is
/// no useful content left instead of stopping before later epochs are examined.
pub fn buildDictionary(samples: []const []const u8, tables: Tables, ring: []u32, output: []u8, segment_size: usize, d: u8, f: u8, profile: *types.Profile) []const u8 {
    @memcpy(tables.frequencies, tables.base);
    @memset(tables.active, 0);
    profile.add("frequency_restore_bytes", tables.base.len * @sizeOf(u32));
    profile.add("table_clear_bytes", tables.active.len * @sizeOf(u32));
    const total = tables.offsets[samples.len];
    const epochs = computeEpochs(output.len, total, segment_size);
    var epoch: usize = 0;
    var zeros: usize = 0;
    var tail = output.len;
    while (tail >= d) {
        const begin = epoch * epochs.size;
        const end = if (epoch + 1 == epochs.count) total else begin + epochs.size;
        const best = selectEpoch(samples, tables, ring, begin, end, segment_size, d, f, profile);
        profile.add("epoch_visits", 1);
        epoch = (epoch + 1) % epochs.count;
        if (best.score == 0) {
            profile.add("zero_score_epochs", 1);
            zeros += 1;
            if (zeros == epochs.count) break;
            continue;
        }
        zeros = 0;
        const bytes = @min(tail, best.end - best.begin + d - 1);
        std.debug.assert(bytes >= d);
        tail -= bytes;
        @memcpy(output[tail..][0..bytes], samples[best.sample][best.begin..][0..bytes]);
        profile.add("selected_segments", 1);
        profile.add("selected_bytes", bytes);
        // Only hashes actually copied into the result are cleared. The final
        // trimmed segment therefore has precisely the dictionary's coverage.
        for (best.begin..best.begin + bytes - d + 1) |offset| {
            const key = hash(samples[best.sample], offset, d, f);
            profile.add("frequency_clear_positions", 1);
            if (tables.frequencies[key] != 0) {
                tables.frequencies[key] = 0;
                profile.add("frequency_clears", 1);
            }
        }
    }
    return output[tail..];
}

fn computeEpochs(target: usize, total: usize, k: usize) struct { count: usize, size: usize } {
    var count = @max(@as(usize, 1), target / k);
    var size = total / count;
    const minimum = std.math.mul(usize, k, 10) catch std.math.maxInt(usize);
    if (size < minimum) {
        size = @min(total, minimum);
        count = total / size;
    }
    return .{ .count = count, .size = size };
}

fn selectEpoch(samples: []const []const u8, tables: Tables, ring: []u32, begin: usize, end: usize, k: usize, d: u8, f: u8, profile: *types.Profile) Segment {
    var best: Segment = .{};
    var low: usize = 0;
    var high = samples.len;
    while (low < high) {
        const middle = low + (high - low) / 2;
        if (tables.offsets[middle + 1] <= begin) low = middle + 1 else high = middle;
    }
    var sample = low;
    while (sample < samples.len and tables.offsets[sample] < end) : (sample += 1) {
        const range_begin = @max(begin, tables.offsets[sample]);
        const range_end = @min(end, tables.offsets[sample + 1]);
        if (range_begin == range_end) continue;
        const candidate = selectRange(samples[sample], sample, tables, ring, range_begin - tables.offsets[sample], range_end - tables.offsets[sample], k - d + 1, d, f, profile);
        if (candidate.score > best.score) best = candidate;
    }
    return best;
}

fn selectRange(sample: []const u8, sample_index: usize, tables: Tables, ring: []u32, begin: usize, end: usize, width: usize, d: u8, f: u8, profile: *types.Profile) Segment {
    var active: Segment = .{ .sample = sample_index, .begin = begin, .end = begin };
    var best: Segment = .{};
    var head: usize = 0;
    var count: usize = 0;
    for (begin..end) |offset| {
        // Cache each added hash. Removal and final active-table cleanup then
        // reuse the hash without hashing the same source bytes a second time.
        if (count == width) {
            const removed = ring[head];
            tables.active[removed] -= 1;
            if (tables.active[removed] == 0) active.score -= tables.frequencies[removed];
            head = nextRingIndex(head, ring.len);
            count -= 1;
            active.begin += 1;
            profile.add("active_removes", 1);
        }
        const added = hash(sample, offset, d, f);
        var added_slot = head + count;
        if (added_slot >= ring.len) added_slot -= ring.len;
        ring[added_slot] = @intCast(added);
        count += 1;
        if (tables.active[added] == 0) active.score += tables.frequencies[added];
        tables.active[added] += 1;
        active.end = offset + 1;
        profile.add("selection_hashes", 1);
        profile.add("active_adds", 1);
        profile.add("segment_windows", 1);
        if (active.score > best.score) best = active;
    }
    while (count > 0) : (count -= 1) {
        const key = ring[head];
        tables.active[key] -= 1;
        head = nextRingIndex(head, ring.len);
        profile.add("active_removes", 1);
    }
    return best;
}

fn nextRingIndex(index: usize, length: usize) usize {
    return if (index + 1 == length) 0 else index + 1;
}
