const std = @import("std");
const encode_options = @import("encode_options.zig");
const item_stream = @import("item_stream.zig");
const tables = @import("tables.zig");

const missing = std.math.maxInt(u32);
const max_match_length = 259;
const Bucket = struct { anchor: u32 = missing, latest: u32 = missing };
const Match = struct { length: u16 = 0, offset: u32 = 0, cost: usize = 0 };

pub const Plan = struct {
    items: std.ArrayList(item_stream.Item) = .empty,

    pub fn deinit(self: *Plan, allocator: std.mem.Allocator) void {
        self.items.deinit(allocator);
    }
};

/// Greedy, deterministic matching with two candidates per three-byte hash.
/// The caller retains ownership of the input and preceding history. The table
/// size depends only on hash_log; positions refer to the selected history
/// suffix and this frame, never to an input-sized chain or a copied window.
pub fn planAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    start: usize,
    end: usize,
    options: encode_options.Options,
) !Plan {
    try options.validate();
    if (start >= end or end > input.len or end - start > tables.frame_size)
        return error.InvalidBlockPlan;

    var result = Plan{};
    errdefer result.deinit(allocator);
    if (options.strategy == .literals) {
        for (input[start..end]) |byte| try result.items.append(allocator, .{ .literal = byte });
        return result;
    }

    const distance_limit = options.historyLimit();
    const history_start = start - @min(start, distance_limit);
    const content = input[history_start..end];
    const frame_start = start - history_start;
    const buckets = try allocator.alloc(Bucket, @as(usize, 1) << @intCast(options.hash_log));
    defer allocator.free(buckets);
    @memset(buckets, .{});

    for (0..frame_start) |position|
        index(content, position, buckets, options.hash_log, distance_limit);

    var position = frame_start;
    while (position < content.len) {
        var best = Match{};
        if (content.len - position >= 3) {
            const bucket = &buckets[hash3(content[position..][0..3], options.hash_log)];
            refresh(bucket, position, distance_limit);
            if (bucket.anchor != missing)
                consider(content, position, bucket.anchor, options.window_bits, distance_limit, &best);
            if (bucket.latest != missing and bucket.latest != bucket.anchor)
                consider(content, position, bucket.latest, options.window_bits, distance_limit, &best);
        }
        const length: usize = if (best.length == 0) 1 else best.length;
        try result.items.append(allocator, if (best.length == 0)
            .{ .literal = content[position] }
        else
            .{ .match = .{ .length = best.length, .offset = best.offset } });

        // Index every covered byte so the latest candidate remains useful
        // after a long overlapping match and after small windows roll forward.
        for (position..position + length) |covered|
            index(content, covered, buckets, options.hash_log, distance_limit);
        position += length;
    }
    return result;
}

fn consider(
    input: []const u8,
    position: usize,
    previous: usize,
    window_bits: u5,
    distance_limit: usize,
    best: *Match,
) void {
    if (previous >= position) return;
    const offset = position - previous;
    if (offset > distance_limit) return;
    const limit = @min(max_match_length, input.len - position);
    var length: usize = 0;
    while (length < limit and input[previous + length] == input[position + length]) : (length += 1) {}
    if (length < 3) return;

    const match_length: u16 = @intCast(length);
    const match_offset: u32 = @intCast(offset);
    const entries = item_stream.positionEntries(window_bits, match_length);
    // Fixed lengths have smaller distance alphabets than variable matches.
    // A short far match is discarded instead of emitting an illegal selector.
    const position_slot = tables.positionSlot(match_offset, entries) catch return;
    var cost: usize = 3 + symbolBits(entries) + @as(usize, tables.position_extra[position_slot]);
    if (length >= 5) {
        const length_slot = tables.lengthSlot(match_length) catch return;
        cost += 5 + @as(usize, tables.length_extra[length_slot]);
    }
    // Static initial-alphabet estimates: selector=3 and literal=6 bits.
    // Adaptive model costs are deliberately outside this bounded matcher.
    if (cost >= length * 9 or length < best.length or
        (length == best.length and (cost > best.cost or (cost == best.cost and offset >= best.offset)))) return;
    best.* = .{ .length = match_length, .offset = match_offset, .cost = cost };
}

fn index(input: []const u8, position: usize, buckets: []Bucket, hash_log: u8, distance_limit: usize) void {
    if (input.len - position < 3) return;
    const bucket = &buckets[hash3(input[position..][0..3], hash_log)];
    refresh(bucket, position, distance_limit);
    if (bucket.anchor == missing) bucket.anchor = @intCast(position);
    bucket.latest = @intCast(position);
}

fn refresh(bucket: *Bucket, position: usize, distance_limit: usize) void {
    const oldest = position - @min(position, distance_limit);
    if (bucket.latest != missing and bucket.latest < oldest) bucket.latest = missing;
    if (bucket.anchor != missing and bucket.anchor < oldest) bucket.anchor = bucket.latest;
}

fn hash3(bytes: *const [3]u8, hash_log: u8) usize {
    const value = @as(u32, bytes[0]) | (@as(u32, bytes[1]) << 8) | (@as(u32, bytes[2]) << 16);
    return @intCast((value *% 0x1e35_a7bd) >> @intCast(32 - hash_log));
}

fn symbolBits(entries: usize) usize {
    return std.math.log2_int_ceil(usize, entries);
}

test {
    _ = @import("match_finder_tests.zig");
}
