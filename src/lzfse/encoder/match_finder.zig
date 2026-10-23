const std = @import("std");
const block_plan = @import("block_plan.zig");
const encode_options = @import("../encode_options.zig");

pub const Plan = block_plan.Plan;
pub const Error = block_plan.Error;
const missing = std.math.maxInt(u32);
const Bucket = struct { anchor: u32 = missing, latest: u32 = missing };
const Match = struct { length: usize = 0, distance: u32 = 0 };
const min_match_length: usize = 4;

/// Plan one FSE candidate using borrowed history and a fixed-size hash table.
/// Counts, rather than raw block size, determine cuts. raw_size is the exact
/// recorded input prefix, so callers may retry the unconsumed suffix.
pub fn planAlloc(allocator: std.mem.Allocator, input: []const u8, start: usize, end: usize, options: encode_options.Options) Error!Plan {
    try options.validate();
    if (start >= end or end > input.len) return error.InvalidLzfseStream;
    const distance_limit = options.historyLimit();
    const history_start = start - @min(start, distance_limit);
    const scan_end = start + @min(end - start, encode_options.max_plan_raw_size);
    const content = input[history_start..scan_end];
    const frame_start = start - history_start;
    var result = Plan.init(frame_start);
    errdefer result.deinit(allocator);
    const buckets = try allocator.alloc(Bucket, @as(usize, 1) << @intCast(options.hash_log));
    defer allocator.free(buckets);
    @memset(buckets, .{});

    for (0..frame_start) |position| index(content, position, buckets, options.hash_log, distance_limit);
    var position = frame_start;
    var pending_start = frame_start;
    while (position < content.len and result.records.items.len < block_plan.max_records) {
        const pending = content[pending_start..position];
        if (result.literals.items.len + pending.len == block_plan.max_literals) break;
        var best = Match{};
        if (content.len - position >= min_match_length) {
            const bucket = &buckets[hash4(content[position..][0..4], options.hash_log)];
            refresh(bucket, position, distance_limit);
            if (bucket.anchor != missing) consider(content, position, bucket.anchor, distance_limit, &best);
            if (bucket.latest != missing and bucket.latest != bucket.anchor)
                consider(content, position, bucket.latest, distance_limit, &best);
        }
        if (best.length != 0) {
            try result.append(allocator, pending, best.length, best.distance);
            for (position..position + best.length) |covered| index(content, covered, buckets, options.hash_log, distance_limit);
            position += best.length;
            pending_start = position;
        } else {
            // Keep at most one literal record pending. Flushing before a new
            // literal reserves the final record for all already-scanned bytes.
            if (pending.len == encode_options.max_literal_length) {
                try result.appendLiterals(allocator, pending);
                pending_start = position;
                if (result.records.items.len == block_plan.max_records) break;
            }
            index(content, position, buckets, options.hash_log, distance_limit);
            position += 1;
        }
    }
    if (pending_start != position) try result.appendLiterals(allocator, content[pending_start..position]);
    try result.validate();
    std.debug.assert(result.raw_size == position - frame_start);
    return result;
}

fn consider(input: []const u8, position: usize, previous: usize, distance_limit: usize, best: *Match) void {
    if (previous >= position) return;
    const distance = position - previous;
    if (distance > distance_limit) return;
    const limit = @min(encode_options.max_match_length, input.len - position);
    var length: usize = 0;
    while (length < limit and input[previous + length] == input[position + length]) : (length += 1) {}
    if (length < min_match_length or length < best.length or
        (length == best.length and best.distance != 0 and distance >= best.distance)) return;
    best.* = .{ .length = length, .distance = @intCast(distance) };
}

fn index(input: []const u8, position: usize, buckets: []Bucket, hash_log: u8, distance_limit: usize) void {
    if (input.len - position < min_match_length) return;
    const bucket = &buckets[hash4(input[position..][0..4], hash_log)];
    refresh(bucket, position, distance_limit);
    if (bucket.anchor == missing) bucket.anchor = @intCast(position);
    bucket.latest = @intCast(position);
}

fn refresh(bucket: *Bucket, position: usize, distance_limit: usize) void {
    const oldest = position - @min(position, distance_limit);
    if (bucket.latest != missing and bucket.latest < oldest) bucket.latest = missing;
    if (bucket.anchor != missing and bucket.anchor < oldest) bucket.anchor = bucket.latest;
}

fn hash4(bytes: *const [4]u8, hash_log: u8) usize {
    const value = std.mem.readInt(u32, bytes, .little);
    return @intCast((value *% 0x1e35_a7bd) >> @intCast(32 - hash_log));
}

test {
    _ = @import("match_finder_tests.zig");
}
