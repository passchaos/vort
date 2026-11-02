//! Four-byte candidate traversal preserving the original three-bucket quota.
const std = @import("std");

pub const empty = std.math.maxInt(u32);

pub const Admission = struct {
    pairs: usize = 0,
    different: usize = 0,

    pub inline fn record(self: *Admission, input: []const u8, position: usize, previous: u32, window: usize) void {
        if (previous == empty or position + 4 > input.len or position - previous > window) return;
        self.pairs += 1;
        self.different += @intFromBool(std.mem.readInt(u32, input[position..][0..4], .little) != std.mem.readInt(u32, input[previous..][0..4], .little));
    }

    pub fn useful(self: Admission, input_len: usize) bool {
        return input_len >= 4 and self.different > (input_len - 3) / 4;
    }

    /// Visit one offset per eight-byte group, rotating through all eight
    /// alignments over sixty-four bytes. This bounds admission work without
    /// always sampling the same byte of fixed-width input records.
    pub fn usefulSampled(self: Admission, input_len: usize) bool {
        if (input_len < 4) return false;
        const positions = input_len - 3;
        const tail = positions % 64;
        const samples = positions / 64 * 8 + if (tail == 0) @as(usize, 0) else 1 + (tail - 1) / 9;
        return self.different > samples / 4;
    }
};

/// Keep original three-byte predecessor discovery and optional admission
/// statistics in one pass. The caller supplies the established hash policy.
pub fn buildThree(
    comptime observe: bool,
    comptime head_size: usize,
    allocator: std.mem.Allocator,
    input: []const u8,
    head: *std.ArrayList(u32),
    prev: *std.ArrayList(u32),
    initialized: *[head_size / 64]u64,
    window: usize,
    comptime hashAt: anytype,
) !Admission {
    if (input.len > empty) return error.InvalidBlockPlan;
    try head.resize(allocator, head_size);
    try prev.resize(allocator, input.len);
    @memset(initialized, 0);
    var admission: Admission = .{};
    for (0..input.len) |position| {
        const hash = hashAt(input, position, head.items.len) orelse continue;
        const mask = @as(u64, 1) << @intCast(hash & 63);
        const word = &initialized[hash / 64];
        prev.items[position] = if (word.* & mask == 0) empty else head.items[hash];
        if (observe and (position & 7) == ((position >> 3) & 7)) admission.record(input, position, prev.items[position], window);
        head.items[hash] = @intCast(position);
        word.* |= mask;
    }
    return admission;
}

pub const Scratch = struct {
    ordinals: std.ArrayList(u16) = .empty,
    four_prev: std.ArrayList(u16) = .empty,

    pub fn deinit(self: *Scratch, allocator: std.mem.Allocator) void {
        self.ordinals.deinit(allocator);
        self.four_prev.deinit(allocator);
        self.* = .{};
    }

    /// The original predecessor order is complete before this pass. Each
    /// ordinal counts every old three-bucket node, including false prefixes.
    pub fn prepare(self: *Scratch, allocator: std.mem.Allocator, three_prev: []const u32) !void {
        if (three_prev.len > 65536) return error.InvalidBlockPlan;
        try self.ordinals.resize(allocator, three_prev.len);
        try self.four_prev.resize(allocator, three_prev.len);
        const stop = three_prev.len -| 2;
        for (0..stop) |position| {
            const previous = three_prev[position];
            self.ordinals.items[position] = if (previous == empty) 1 else self.ordinals.items[previous] + 1;
        }
    }

    /// Reuse the old head workspace after its predecessor links are retained.
    pub fn buildFour(self: *Scratch, input: []const u8, head: []u32, initialized: []u64, comptime hashAt: anytype) void {
        std.debug.assert(input.len <= 65536 and self.four_prev.items.len == input.len);
        @memset(initialized, 0);
        for (0..input.len) |position| {
            const hash = hashAt(input, position, head.len) orelse continue;
            const mask = @as(u64, 1) << @intCast(hash & 63);
            const word = &initialized[hash / 64];
            self.four_prev.items[position] = if (word.* & mask == 0) std.math.maxInt(u16) else @intCast(head[hash]);
            head[hash] = @intCast(position);
            word.* |= mask;
        }
    }
};

test "ordinal index candidate and admission contracts" {
    try @import("ordinal_index_tests.zig").check(@This());
}

pub const Cursor = struct {
    three_prev: []const u32,
    four_prev: []const u16,
    ordinals: []const u16,
    position: usize,
    max_chain: usize,
    window: usize,
    current: u32,
    physical: usize = 0,
    fallback: bool = false,
    fallback_visited: usize = 0,
    last_four: usize,
    prefix: u32,
    chain_nodes: usize = 0,
    prefix_rejections: usize = 0,
    prefix_mismatch_histogram: [4]usize = @splat(0),
    fallback_switches: usize = 0,
    window_stops: usize = 0,

    pub fn init(three_prev: []const u32, four_prev: []const u16, ordinals: []const u16, input: []const u8, position: usize, max_chain: usize, window: usize) Cursor {
        return .{
            .three_prev = three_prev,
            .four_prev = four_prev,
            .ordinals = ordinals,
            .position = position,
            .max_chain = max_chain,
            .window = window,
            .current = if (four_prev[position] == std.math.maxInt(u16)) empty else four_prev[position],
            .last_four = position,
            .prefix = std.mem.readInt(u32, input[position..][0..4], .little),
        };
    }

    /// Foreign four-hash collisions do not consume the old quota. At most
    /// max_chain of them are visited before falling back to the original
    /// chain. Replay skips already visited coordinates, then resumes all
    /// remaining old candidates. Thus collision controls cannot turn the
    /// new walk into an unbounded scan or lose a formerly reachable match.
    pub inline fn next(self: *Cursor, input: []const u8) ?u32 {
        if (self.max_chain == 0) return null;
        while (self.current != empty) {
            if (self.fallback and self.fallback_visited >= self.max_chain) return null;
            if (!self.fallback and self.physical == self.max_chain) {
                self.fallback = true;
                self.fallback_switches += 1;
                self.current = self.three_prev[self.position];
                continue;
            }
            const candidate = self.current;
            const distance = self.position - candidate;
            if (distance > self.window) {
                self.window_stops += 1;
                self.current = empty;
                return null;
            }
            if (self.fallback) {
                self.current = self.three_prev[candidate];
                self.fallback_visited += 1;
                // Four-chain traversal is nearest-first. All matching
                // coordinates at or above this frontier were already seen.
                if (candidate >= self.last_four) continue;
            } else {
                const next_four = self.four_prev[candidate];
                self.current = if (next_four == std.math.maxInt(u16)) empty else next_four;
                self.last_four = candidate;
                self.physical += 1;
            }
            self.chain_nodes += 1;
            const prefix = std.mem.readInt(u32, input[candidate..][0..4], .little);
            if (prefix != self.prefix) {
                self.prefix_rejections += 1;
                self.prefix_mismatch_histogram[@ctz(prefix ^ self.prefix) / 8] += 1;
                continue;
            }
            // Full four-byte equality implies equal old three-byte hashes,
            // so only now is the ordinal subtraction a membership-safe rank.
            const old_rank = self.ordinals[self.position] - self.ordinals[candidate];
            std.debug.assert(old_rank != 0);
            if (old_rank > self.max_chain) return null;
            return candidate;
        }
        return null;
    }
};
