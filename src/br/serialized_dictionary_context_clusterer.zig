const std = @import("std");
const literal_context = @import("encoder/literal_context.zig");

pub const context_count: usize = 64;
pub const signature_bins: usize = 64;
pub const max_positions_per_context: usize = 64 * 1024;

pub const Options = struct {
    phrase_len: u5,
    target_clusters: u7,
    max_positions_per_context: usize = 4096,
};

pub const Error = error{
    InvalidTrainingOptions,
    IntegerOverflow,
};

pub const Result = struct {
    context_map: [context_count]u6,
    cluster_count: u7,
    observed_context_count: u7,
};

const Cluster = struct {
    active: bool = false,
    members: u64 = 0,
    min_context: u6 = 0,
    total: u64 = 0,
    bins: [signature_bins]u64 = @splat(0),
};

const Distance = struct {
    numerator: u128,
    denominator: u128,
};

/// Learn one arbitrary RFC literal-context map without heap allocation.
/// Signatures hash the next `phrase_len` bytes at positions selected by each
/// context. Agglomerative clustering merges the smallest normalized L1 pair;
/// all ties use the lowest member contexts, yielding stable maps.
pub fn learn(
    samples: []const []const u8,
    mode: u2,
    options: Options,
) Error!?Result {
    try validateOptions(mode, options);
    if (samples.len == 0) return null;

    var clusters: [context_count]Cluster = @splat(.{});
    var observed_count: usize = 0;
    for (samples) |sample| {
        if (sample.len < options.phrase_len) continue;
        for (0..sample.len - options.phrase_len + 1) |position| {
            const context = trainingContext(sample, position, mode);
            const cluster = &clusters[context];
            if (cluster.total >= options.max_positions_per_context) continue;
            if (!cluster.active) {
                cluster.active = true;
                cluster.members = @as(u64, 1) << @intCast(context);
                cluster.min_context = @intCast(context);
                observed_count += 1;
            }
            const phrase = sample[position..][0..options.phrase_len];
            const bin = phraseHash(phrase) & (signature_bins - 1);
            cluster.bins[bin] += 1;
            cluster.total += 1;
        }
    }
    if (observed_count < 2) return null;

    var active_count = observed_count;
    const target = @min(active_count, @as(usize, options.target_clusters));
    while (active_count > target) {
        var best_left: ?usize = null;
        var best_right: usize = undefined;
        var best_distance: Distance = undefined;
        for (0..context_count) |left| {
            if (!clusters[left].active) continue;
            for (left + 1..context_count) |right| {
                if (!clusters[right].active) continue;
                const distance = clusterDistance(&clusters[left], &clusters[right]);
                if (best_left == null or distanceLess(distance, best_distance) or
                    (distanceEqual(distance, best_distance) and pairLess(
                        &clusters[left],
                        &clusters[right],
                        &clusters[best_left.?],
                        &clusters[best_right],
                    )))
                {
                    best_left = left;
                    best_right = right;
                    best_distance = distance;
                }
            }
        }
        const left = best_left orelse return error.InvalidTrainingOptions;
        mergeClusters(&clusters[left], &clusters[best_right]);
        active_count -= 1;
    }

    var ordered: [context_count]usize = undefined;
    var ordered_count: usize = 0;
    for (&clusters, 0..) |*cluster, index| {
        if (!cluster.active) continue;
        var insertion = ordered_count;
        while (insertion != 0 and
            cluster.min_context < clusters[ordered[insertion - 1]].min_context)
        {
            ordered[insertion] = ordered[insertion - 1];
            insertion -= 1;
        }
        ordered[insertion] = index;
        ordered_count += 1;
    }
    std.debug.assert(ordered_count == active_count);

    var result = Result{
        .context_map = @splat(0),
        .cluster_count = @intCast(active_count),
        .observed_context_count = @intCast(observed_count),
    };
    var assigned: [context_count]bool = @splat(false);
    for (ordered[0..ordered_count], 0..) |cluster_index, cluster_id| {
        const members = clusters[cluster_index].members;
        for (0..context_count) |context| {
            if (members & (@as(u64, 1) << @intCast(context)) == 0) continue;
            result.context_map[context] = @intCast(cluster_id);
            assigned[context] = true;
        }
    }
    for (&result.context_map, &assigned, 0..) |*cluster_id, was_assigned, context| {
        if (was_assigned) continue;
        cluster_id.* = nearestClusterId(context, ordered[0..ordered_count], &clusters);
    }
    return result;
}

fn validateOptions(mode: u2, options: Options) Error!void {
    if (mode > literal_context.mode_signed or
        options.phrase_len < 4 or
        options.phrase_len > 31 or
        options.target_clusters < 2 or
        options.target_clusters > context_count or
        options.max_positions_per_context == 0 or
        options.max_positions_per_context > max_positions_per_context)
    {
        return error.InvalidTrainingOptions;
    }
}

fn trainingContext(sample: []const u8, position: usize, mode: u2) usize {
    const previous = if (position == 0) 0 else sample[position - 1];
    const second_previous = if (position < 2) 0 else sample[position - 2];
    return literal_context.value(mode, previous, second_previous);
}

fn phraseHash(bytes: []const u8) usize {
    var hash: u64 = 0xcbf2_9ce4_8422_2325;
    for (bytes) |byte| {
        hash ^= byte;
        hash *%= 0x0000_0100_0000_01b3;
    }
    return @truncate(hash);
}

fn clusterDistance(a: *const Cluster, b: *const Cluster) Distance {
    var numerator: u128 = 0;
    for (a.bins, b.bins) |a_count, b_count| {
        const scaled_a = @as(u128, a_count) * b.total;
        const scaled_b = @as(u128, b_count) * a.total;
        numerator += if (scaled_a >= scaled_b)
            scaled_a - scaled_b
        else
            scaled_b - scaled_a;
    }
    return .{
        .numerator = numerator,
        .denominator = @as(u128, a.total) * b.total,
    };
}

fn distanceLess(a: Distance, b: Distance) bool {
    return a.numerator * b.denominator < b.numerator * a.denominator;
}

fn distanceEqual(a: Distance, b: Distance) bool {
    return a.numerator * b.denominator == b.numerator * a.denominator;
}

fn pairLess(
    a: *const Cluster,
    b: *const Cluster,
    current_a: *const Cluster,
    current_b: *const Cluster,
) bool {
    const a_low = @min(a.min_context, b.min_context);
    const a_high = @max(a.min_context, b.min_context);
    const current_low = @min(current_a.min_context, current_b.min_context);
    const current_high = @max(current_a.min_context, current_b.min_context);
    return a_low < current_low or
        (a_low == current_low and a_high < current_high);
}

fn mergeClusters(a: *Cluster, b: *Cluster) void {
    a.members |= b.members;
    a.min_context = @min(a.min_context, b.min_context);
    a.total += b.total;
    for (&a.bins, b.bins) |*destination, source| destination.* += source;
    b.* = .{};
}

fn nearestClusterId(
    context: usize,
    ordered: []const usize,
    clusters: *const [context_count]Cluster,
) u6 {
    var best_id: usize = 0;
    var best_distance: usize = context_count;
    for (ordered, 0..) |cluster_index, cluster_id| {
        const members = clusters[cluster_index].members;
        var distance = context_count;
        for (0..context_count) |member| {
            if (members & (@as(u64, 1) << @intCast(member)) == 0) continue;
            const candidate = if (context >= member)
                context - member
            else
                member - context;
            distance = @min(distance, candidate);
        }
        if (distance < best_distance) {
            best_distance = distance;
            best_id = cluster_id;
        }
    }
    return @intCast(best_id);
}

test "serialized context clusterer learns non-contiguous phrase groups" {
    const words_a = [_][]const u8{ "a0000000", "a1111111" };
    const words_b = [_][]const u8{ "b0000000", "b1111111" };
    const markers = [_]u8{ 8, 32, 16, 40 };
    var storage: [32][9]u8 = undefined;
    var samples: [storage.len][]const u8 = undefined;
    for (&storage, &samples, 0..) |*item, *sample, index| {
        const group = (index / 8) / 2;
        const marker_index = (index / 8) % 2;
        const words = if (group == 0) &words_a else &words_b;
        item[0] = markers[group * 2 + marker_index];
        @memcpy(item[1..], words[index % words.len]);
        sample.* = item;
    }
    const first = (try learn(&samples, literal_context.mode_lsb6, .{
        .phrase_len = 8,
        .target_clusters = 3,
        .max_positions_per_context = 64,
    })).?;
    const second = (try learn(&samples, literal_context.mode_lsb6, .{
        .phrase_len = 8,
        .target_clusters = 3,
        .max_positions_per_context = 64,
    })).?;
    try std.testing.expectEqual(first, second);
    try std.testing.expectEqual(@as(u7, 3), first.cluster_count);
    try std.testing.expectEqual(first.context_map[8], first.context_map[32]);
    try std.testing.expectEqual(first.context_map[16], first.context_map[40]);
    try std.testing.expect(first.context_map[8] != first.context_map[16]);
    try std.testing.expect(first.context_map[0] != first.context_map[8]);
    try std.testing.expect(first.context_map[0] != first.context_map[16]);
}

test "serialized context clusterer validates options and sparse evidence" {
    try std.testing.expectError(
        error.InvalidTrainingOptions,
        learn(&.{"sample"}, literal_context.mode_lsb6, .{
            .phrase_len = 3,
            .target_clusters = 2,
        }),
    );
    try std.testing.expectError(
        error.InvalidTrainingOptions,
        learn(&.{"sample"}, literal_context.mode_lsb6, .{
            .phrase_len = 4,
            .target_clusters = 1,
        }),
    );
    try std.testing.expectEqual(
        @as(?Result, null),
        try learn(&.{"only-one-context"}, literal_context.mode_lsb6, .{
            .phrase_len = 16,
            .target_clusters = 2,
        }),
    );
}
