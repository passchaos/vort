const std = @import("std");
const tables = @import("tables.zig");

pub const main_symbols = 656;
pub const length_symbols = 249;
pub const max_match_len = 257;
const hash_size = 32768;
const missing = std.math.maxInt(u32);
const Bucket = struct { anchor: u32 = missing, latest: u32 = missing };

pub const Item = struct {
    literal: u8 = 0,
    len: u16 = 1,
    slot: u8 = 0,
    extra: u32 = 0,

    pub fn mainSymbol(self: Item) usize {
        return if (self.len == 1) self.literal else 256 + @as(usize, self.slot) * 8 + @min(self.len - 2, 7);
    }
};

pub const Plan = struct {
    items: std.ArrayList(Item) = .empty,
    main_frequencies: [main_symbols]u32 = @splat(0),
    length_frequencies: [length_symbols]u32 = @splat(0),
    aligned_frequencies: [8]u32 = @splat(0),
    reps: [3]u32,
    matched_bytes: usize = 0,
    repeat_matches: usize = 0,
    max_offset: usize = 0,

    pub fn deinit(self: *Plan, allocator: std.mem.Allocator) void {
        self.items.deinit(allocator);
    }

    /// History is borrowed from the caller; indexing and item storage are
    /// bounded by the chosen window and current block, never the whole stream.
    pub fn init(allocator: std.mem.Allocator, input: []const u8, start: usize, end: usize, window_bits: u5, initial_reps: [3]u32) !Plan {
        if (start >= end or end > input.len or end - start > 32768 or window_bits < 15 or window_bits > 21)
            return error.InvalidBlockPlan;
        const window_size = @as(usize, 1) << window_bits;
        const history_start = start - @min(start, window_size - 3);
        const content = input[history_start..end];
        const block_start = start - history_start;
        const buckets = try allocator.alloc(Bucket, hash_size);
        defer allocator.free(buckets);
        @memset(buckets, .{});
        const short_heads = try allocator.alloc(u32, 65536);
        defer allocator.free(short_heads);
        @memset(short_heads, missing);
        var result: Plan = .{ .reps = initial_reps };
        errdefer result.deinit(allocator);
        for (0..block_start) |position| index(content, position, buckets, short_heads);
        var position = block_start;
        const slots = tables.positionSlotCount(window_bits);
        while (position < content.len) {
            var best = Match{};
            for (result.reps) |offset| {
                if (offset != 0 and offset <= position) consider(content, position, position - offset, slots, result.reps, &best);
            }
            if (content.len - position >= 3) {
                const bucket = buckets[hash3(content[position..][0..3])];
                if (bucket.anchor != missing) consider(content, position, bucket.anchor, slots, result.reps, &best);
                if (bucket.latest != missing and bucket.latest != bucket.anchor) consider(content, position, bucket.latest, slots, result.reps, &best);
            }
            if (content.len - position >= 2) {
                const previous = short_heads[hash2(content[position..][0..2])];
                if (previous != missing) consider(content, position, previous, slots, result.reps, &best);
            }
            const item: Item = if (best.len >= 2)
                .{ .len = best.len, .slot = best.slot, .extra = best.extra }
            else
                .{ .literal = content[position] };
            try result.items.append(allocator, item);
            result.main_frequencies[item.mainSymbol()] += 1;
            if (item.len >= 9) result.length_frequencies[item.len - 9] += 1;
            if (item.len >= 2) {
                if (item.slot < 3) result.repeat_matches += 1;
                if (tables.positionExtraBits(item.slot) >= 3) result.aligned_frequencies[item.extra & 7] += 1;
                result.matched_bytes += item.len;
                result.max_offset = @max(result.max_offset, best.offset);
                updateReps(&result.reps, item.slot, best.offset);
            }
            for (position..position + item.len) |covered| index(content, covered, buckets, short_heads);
            position += item.len;
        }
        return result;
    }
};

const Match = struct { len: u16 = 0, slot: u8 = 0, extra: u32 = 0, offset: u32 = 0, cost: usize = 0 };

fn consider(input: []const u8, position: usize, previous: usize, slot_count: usize, reps: [3]u32, best: *Match) void {
    if (previous >= position) return;
    const offset = position - previous;
    var slot: usize = slot_count;
    for (reps, 0..) |repeat, rank| if (repeat == offset) {
        slot = rank;
        break;
    };
    if (slot == slot_count) {
        for (3..slot_count) |candidate| {
            const base = tables.positionBase(candidate);
            if (offset >= base and offset - base < @as(usize, 1) << @intCast(tables.positionExtraBits(candidate))) {
                slot = candidate;
                break;
            }
        }
    }
    if (slot == slot_count) return;
    const limit = @min(max_match_len, input.len - position);
    var len: usize = 0;
    while (len < limit and input[previous + len] == input[position + len]) : (len += 1) {}
    if (len < 2) return;
    const cost = 9 + tables.positionExtraBits(slot) + @as(usize, if (len >= 9) 8 else 0);
    if (cost >= len * 9 or len < best.len or (len == best.len and best.len != 0 and cost >= best.cost)) return;
    best.* = .{
        .len = @intCast(len),
        .slot = @intCast(slot),
        .extra = if (slot < 3) 0 else @intCast(offset - tables.positionBase(slot)),
        .offset = @intCast(offset),
        .cost = cost,
    };
}

pub fn updateReps(reps: *[3]u32, slot: usize, offset: u32) void {
    switch (slot) {
        0 => {},
        1 => std.mem.swap(u32, &reps[0], &reps[1]),
        2 => std.mem.swap(u32, &reps[0], &reps[2]),
        else => {
            const old = reps.*;
            reps.* = .{ offset, old[0], old[1] };
        },
    }
}

fn index(input: []const u8, position: usize, buckets: []Bucket, short_heads: []u32) void {
    if (input.len - position >= 2) short_heads[hash2(input[position..][0..2])] = @intCast(position);
    if (input.len - position < 3) return;
    const bucket = &buckets[hash3(input[position..][0..3])];
    if (bucket.anchor == missing) bucket.anchor = @intCast(position);
    bucket.latest = @intCast(position);
}

fn hash2(bytes: *const [2]u8) usize {
    return std.mem.readInt(u16, bytes, .little);
}

fn hash3(bytes: *const [3]u8) usize {
    const value = @as(u32, bytes[0]) | (@as(u32, bytes[1]) << 8) | (@as(u32, bytes[2]) << 16);
    return @intCast((value *% 0x1e35_a7bd) >> 17);
}
