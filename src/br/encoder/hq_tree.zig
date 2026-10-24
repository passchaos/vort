const std = @import("std");
const shared = @import("hq_options.zig");
const types = @import("hq_tree/types.zig");
const view = @import("hq_tree/view.zig");
const resources = @import("hq_tree/resources.zig");
const forest = @import("hq_tree/forest.zig");
pub const Source = @import("hq_types.zig").Source;
pub const HqOptions = shared.HqOptions;
pub const HqProfile = shared.HqProfile;
pub const Match = types.Match;
pub const Matches = types.Matches;
pub const Iterator = types.Iterator;
pub const Matcher = OwnedMatcher;
pub const store_lookahead = types.store_lookahead;

pub fn requiredWorkingMemory(source: Source, options: anytype) !usize {
    return resources.cold(try resources.need(source, try types.Search.from(options)));
}

/// Persistent ordinary-history BT. Dictionary providers and recent-distance
/// caches are deliberately outside this owner. All source views stay borrowed;
/// detach before changing their storage, then rebind before querying again.
/// Node references are u32 offsets from a u64 epoch, never truncated absolutes.
pub const OwnedMatcher = struct {
    source: Source = .{ .history = "", .input = "", .window_len = 1, .frame_offset = 0 },
    metadata: view.Metadata = .{ .begin = 0, .input_begin = 0, .end = 0, .history_len = 0, .input_len = 0, .total_len = 0, .window_len = 1 },
    options: types.Search = .{ .search_depth = 64, .nice_len = 128, .max_working_memory = std.math.maxInt(usize) },
    profile: ?*HqProfile = null,
    heads2: []u32 = &.{},
    heads3: []u32 = &.{},
    heads4: []u32 = &.{},
    nodes: []types.Node = &.{},
    candidates: []Match = &.{},
    candidate_count: usize = 0,
    candidate_capacity: usize = 0,
    cycle: usize = 0,
    epoch: u64 = 0,
    cursor: u64 = 0,
    next_main: u64 = 0,
    next_short2: u64 = 0,
    next_short3: u64 = 0,
    ready: bool = false,
    bound: bool = false,

    pub fn requiredWorkingMemory(source: Source, options: anytype) !usize {
        return resources.cold(try resources.need(source, try types.Search.from(options)));
    }
    pub fn init(allocator: std.mem.Allocator, source: Source, options: anytype, profile: ?*HqProfile) !OwnedMatcher {
        var result: OwnedMatcher = .{};
        errdefer result.deinit(allocator);
        try result.prepare(allocator, source, options, profile);
        return result;
    }

    /// Fresh stream/index preparation. Growth can retain larger allocations,
    /// and failed storage growth preserves the previous numeric checkpoint.
    pub fn prepare(self: *OwnedMatcher, allocator: std.mem.Allocator, source: Source, options: anytype, profile: ?*HqProfile) !void {
        const search = try types.Search.from(options);
        const needed = try resources.need(source, search);
        const selected_profile = resolveProfile(options, profile);
        try resources.check(try resources.growth(self.allocationBytes(), try resources.sizes(needed)), search.max_working_memory);
        try self.reserve(allocator, needed, selected_profile);
        self.source = source;
        self.metadata = needed.metadata;
        self.options = search;
        self.profile = selected_profile;
        self.cycle = needed.nodes;
        self.candidate_capacity = needed.candidates;
        self.candidate_count = 0;
        self.epoch = needed.metadata.begin;
        self.cursor = needed.metadata.begin;
        self.next_main = self.cursor;
        self.next_short2 = self.cursor;
        self.next_short3 = self.cursor;
        self.ready = true;
        self.bound = true;
        @memset(self.heads2[0..needed.heads2], types.invalid);
        @memset(self.heads3[0..needed.heads3], types.invalid);
        @memset(self.heads4[0..needed.heads4], types.invalid);
        @memset(self.nodes[0..self.cycle], .{});
        while (self.cursor < self.metadata.input_begin) self.process(false, true);
    }

    /// Continue at the exact processed position. No old history/input byte is
    /// ever read here. Failure leaves a detached numeric checkpoint that can
    /// retry rebind; source views/previous candidate views are invalidated.
    pub fn rebindSource(self: *OwnedMatcher, allocator: std.mem.Allocator, source: Source, options: anytype, profile: ?*HqProfile) !void {
        if (!self.ready) return error.InvalidBlockPlan;
        self.detachSource();
        const search = try types.Search.from(options);
        var needed = try resources.need(source, search);
        if (needed.metadata.input_begin != self.cursor or needed.metadata.window_len != self.metadata.window_len or needed.metadata.format != self.metadata.format or needed.metadata.begin < self.metadata.begin) return error.InvalidBlockPlan;
        const normalize_by = try normalizationAmount(self.epoch, needed.metadata);
        needed.nodes = @max(needed.nodes, self.cycle);
        const selected_profile = resolveProfile(options, profile);
        try resources.check(try resources.growth(self.allocationBytes(), try resources.sizes(needed)), search.max_working_memory);
        try self.reserve(allocator, needed, selected_profile);
        if (needed.nodes > self.cycle) self.expandCycle(needed.nodes);
        self.source = source;
        self.metadata = needed.metadata;
        self.options = search;
        self.profile = selected_profile;
        self.candidate_capacity = needed.candidates;
        self.bound = true;
        self.normalizeIfNeeded(normalize_by);
        self.stitch();
    }

    pub fn detachSource(self: *OwnedMatcher) void {
        self.source = .{ .history = "", .input = "", .window_len = 1, .frame_offset = 0 };
        self.candidate_count = 0;
        self.bound = false;
    }
    pub fn position(self: *const OwnedMatcher) usize {
        return if (self.ready) @intCast(self.cursor - self.metadata.input_begin) else 0;
    }
    pub fn getMatches(self: *OwnedMatcher) !Matches {
        if (!self.ready or !self.bound or self.cursor >= self.metadata.end) return error.InvalidBlockPlan;
        self.process(true, false);
        return .{ .items = self.candidates[0..self.candidate_count] };
    }
    pub fn find(self: *OwnedMatcher) !Matches {
        return self.getMatches();
    }
    pub fn skip(self: *OwnedMatcher, amount: usize) !void {
        if (!self.ready or !self.bound or amount > self.metadata.end - self.cursor) return error.InvalidBlockPlan;
        for (0..amount) |_| self.process(false, false);
    }
    pub fn advanceTo(self: *OwnedMatcher, input_position: usize) !void {
        if (!self.ready or !self.bound or input_position > self.metadata.input_len or input_position < self.position()) return error.InvalidBlockPlan;
        try self.skip(input_position - self.position());
    }

    pub fn workingBytes(self: *const OwnedMatcher) usize {
        var n: usize = 0;
        for (self.allocationBytes()) |bytes| n += bytes;
        return n;
    }
    pub fn reset(self: *OwnedMatcher) void {
        self.detachSource();
        self.metadata = .{ .begin = 0, .input_begin = 0, .end = 0, .history_len = 0, .input_len = 0, .total_len = 0, .window_len = 1 };
        self.profile = null;
        self.ready = false;
        self.cursor = 0;
        self.epoch = 0;
        self.cycle = 0;
        self.candidate_capacity = 0;
        self.next_main = 0;
        self.next_short2 = 0;
        self.next_short3 = 0;
    }
    pub fn deinit(self: *OwnedMatcher, allocator: std.mem.Allocator) void {
        allocator.free(self.candidates);
        allocator.free(self.nodes);
        allocator.free(self.heads4);
        allocator.free(self.heads3);
        allocator.free(self.heads2);
        self.* = .{};
    }

    /// Clone into separate mutable storage without replaying history. Caller
    /// quota includes original plus clone; outer allocators account other owners.
    pub fn fork(self: *const OwnedMatcher, allocator: std.mem.Allocator, maximum: usize, profile: ?*HqProfile) !OwnedMatcher {
        if (!self.ready) return error.InvalidBlockPlan;
        const total = try resources.add(self.workingBytes(), self.workingBytes());
        try resources.check(total, maximum);
        var result = self.*;
        result.heads2 = &.{};
        result.heads3 = &.{};
        result.heads4 = &.{};
        result.nodes = &.{};
        result.candidates = &.{};
        result.profile = profile;
        errdefer result.deinit(allocator);
        try result.grow(u32, &result.heads2, self.heads2.len, allocator, null);
        if (profile) |p| p.recordPeak(self.workingBytes() + result.workingBytes());
        try result.grow(u32, &result.heads3, self.heads3.len, allocator, null);
        if (profile) |p| p.recordPeak(self.workingBytes() + result.workingBytes());
        try result.grow(u32, &result.heads4, self.heads4.len, allocator, null);
        if (profile) |p| p.recordPeak(self.workingBytes() + result.workingBytes());
        try result.grow(types.Node, &result.nodes, self.nodes.len, allocator, null);
        if (profile) |p| p.recordPeak(self.workingBytes() + result.workingBytes());
        try result.grow(Match, &result.candidates, self.candidates.len, allocator, null);
        if (profile) |p| p.recordPeak(self.workingBytes() + result.workingBytes());
        @memcpy(result.heads2, self.heads2);
        @memcpy(result.heads3, self.heads3);
        @memcpy(result.heads4, self.heads4);
        @memcpy(result.nodes[0..self.cycle], self.nodes[0..self.cycle]);
        @memcpy(result.candidates[0..self.candidate_count], self.candidates[0..self.candidate_count]);
        result.options.max_working_memory = maximum;
        if (profile) |p| p.recordPeak(total);
        return result;
    }

    fn allocationBytes(self: *const OwnedMatcher) [5]usize {
        return .{ self.heads2.len * 4, self.heads3.len * 4, self.heads4.len * 4, self.nodes.len * @sizeOf(types.Node), self.candidates.len * @sizeOf(Match) };
    }
    fn reserve(self: *OwnedMatcher, allocator: std.mem.Allocator, needed: resources.Need, profile: ?*HqProfile) !void {
        if (profile) |p| p.recordPeak(self.workingBytes());
        try self.grow(u32, &self.heads2, needed.heads2, allocator, profile);
        try self.grow(u32, &self.heads3, needed.heads3, allocator, profile);
        try self.grow(u32, &self.heads4, needed.heads4, allocator, profile);
        try self.grow(types.Node, &self.nodes, needed.nodes, allocator, profile);
        try self.grow(Match, &self.candidates, needed.candidates, allocator, profile);
    }
    fn grow(self: *OwnedMatcher, comptime T: type, storage: *[]T, required: usize, allocator: std.mem.Allocator, profile: ?*HqProfile) !void {
        if (storage.len >= required) return;
        const prior = self.workingBytes();
        const bytes = try allocator.alloc(T, required);
        if (T == u32) @memset(bytes, types.invalid);
        if (profile) |p| p.recordPeak(prior + bytes.len * @sizeOf(T));
        @memcpy(bytes[0..storage.len], storage.*);
        allocator.free(storage.*);
        storage.* = bytes;
    }
    fn expandCycle(self: *OwnedMatcher, next_cycle: usize) void {
        @memset(self.nodes[self.cycle..next_cycle], .{});
        for (0..self.cycle) |old_slot| {
            const node = self.nodes[old_slot];
            if (node.position == types.invalid) continue;
            const absolute = self.epoch + node.position;
            const slot: usize = @intCast(absolute & (next_cycle - 1));
            if (slot != old_slot) {
                // Power-of-two growth maps moved nodes outside the old range.
                std.debug.assert(slot >= self.cycle);
                self.nodes[slot] = node;
                self.nodes[old_slot] = .{};
            }
        }
        self.cycle = next_cycle;
    }
    fn normalizeIfNeeded(self: *OwnedMatcher, amount: ?u32) void {
        const sub = amount orelse return;
        for (self.heads2) |*reference| reference.* = normalized(reference.*, sub);
        for (self.heads3) |*reference| reference.* = normalized(reference.*, sub);
        for (self.heads4) |*reference| reference.* = normalized(reference.*, sub);
        for (self.nodes[0..self.cycle]) |*node| {
            node.position = normalized(node.position, sub);
            node.left = normalized(node.left, sub);
            node.right = normalized(node.right, sub);
            node.short_previous = normalized(node.short_previous, sub);
        }
        self.epoch = self.metadata.begin;
        self.count("normalizations", 1);
    }
    fn context(self: *OwnedMatcher) forest.Context {
        return .{ .source = self.source, .metadata = self.metadata, .epoch = self.epoch, .cycle = self.cycle, .nodes = self.nodes, .options = self.options, .profile = self.profile };
    }
    fn count(self: *const OwnedMatcher, comptime field: []const u8, n: usize) void {
        if (self.profile) |p| p.add(field, n);
    }
    fn ensureNode(self: *OwnedMatcher, absolute: u64) *types.Node {
        const node = &self.nodes[@as(usize, @intCast(absolute & (self.cycle - 1)))];
        const relative: u32 = @intCast(absolute - self.epoch);
        if (node.position != relative) node.* = .{ .position = relative };
        return node;
    }
    fn register2(self: *OwnedMatcher, absolute: u64) u32 {
        _ = self.ensureNode(absolute);
        const key = view.hash2(self.source, self.metadata, absolute);
        const prior = self.heads2[key];
        self.heads2[key] = @intCast(absolute - self.epoch);
        return prior;
    }
    fn register3(self: *OwnedMatcher, absolute: u64) u32 {
        const node = self.ensureNode(absolute);
        const key = view.hash(self.source, self.metadata, absolute, 3);
        const prior = self.heads3[key];
        node.short_previous = prior;
        self.heads3[key] = node.position;
        return prior;
    }
    fn storeMain(self: *OwnedMatcher, absolute: u64) void {
        const node = self.ensureNode(absolute);
        node.left = types.invalid;
        node.right = types.invalid;
        const key = view.hash(self.source, self.metadata, absolute, 4);
        const prior = self.heads4[key];
        self.heads4[key] = node.position;
        self.context().walk(prior, absolute, types.store_lookahead, true, false, .{ .buffer = self.candidates, .count = &self.candidate_count });
        self.count("indexed_positions", 1);
    }
    fn stitch(self: *OwnedMatcher) void {
        self.next_main = @max(self.next_main, self.metadata.begin);
        self.next_short2 = @max(self.next_short2, self.metadata.begin);
        self.next_short3 = @max(self.next_short3, self.metadata.begin);
        var at = @min(self.next_main, @min(self.next_short2, self.next_short3));
        while (at < self.cursor) : (at += 1) {
            const available = self.metadata.end - at;
            var updated = false;
            if (at >= self.next_short2 and available >= 2) {
                _ = self.register2(at);
                self.next_short2 = at + 1;
                updated = true;
            }
            if (at >= self.next_short3 and available >= 3) {
                _ = self.register3(at);
                self.next_short3 = at + 1;
                updated = true;
            }
            if (at >= self.next_main and available >= types.store_lookahead) {
                self.storeMain(at);
                self.next_main = at + 1;
                updated = true;
            }
            if (updated) self.count("stitch_positions", 1);
        }
    }

    fn process(self: *OwnedMatcher, collect: bool, seed: bool) void {
        self.candidate_count = 0;
        const current = self.cursor;
        self.cursor += 1;
        if (seed) self.count("history_seed_positions", 1);
        const available: usize = @intCast(self.metadata.end - current);
        const frontier = types.Frontier{ .buffer = self.candidates, .count = &self.candidate_count };
        if (available >= 2) {
            const previous = self.register2(current);
            self.next_short2 = current + 1;
            if (collect and previous != types.invalid) {
                self.count("short_hash_probes", 1);
                self.count("match_probes", 1);
                const ctx = self.context();
                if (ctx.valid(previous, current)) frontier.add(ctx.extend(self.epoch + previous, current, 0, available), @intCast(current - self.epoch - previous));
            }
        }
        if (available >= 3) {
            const previous = self.register3(current);
            self.next_short3 = current + 1;
            if (collect and frontier.best().length < @min(available, self.options.nice_len)) self.shortSearch(previous, current, available, frontier);
        }
        const store = available >= types.store_lookahead;
        if (available >= 4) {
            const node = self.ensureNode(current);
            const key = view.hash(self.source, self.metadata, current, 4);
            const previous = self.heads4[key];
            if (store) {
                node.left = types.invalid;
                node.right = types.invalid;
                self.heads4[key] = node.position;
                self.next_main = current + 1;
                self.count("indexed_positions", 1);
            }
            if (store or collect) self.context().walk(previous, current, if (collect) available else types.store_lookahead, store, collect and frontier.best().length < @min(available, self.options.nice_len), frontier);
        }
    }
    fn shortSearch(self: *OwnedMatcher, first: u32, current: u64, maximum: usize, frontier: types.Frontier) void {
        const ctx = self.context();
        var candidate = first;
        var remaining = self.options.search_depth;
        while (candidate != types.invalid and remaining != 0) {
            remaining -= 1;
            ctx.count("short_hash_probes", 1);
            ctx.count("match_probes", 1);
            if (!ctx.valid(candidate, current)) return;
            const absolute = self.epoch + candidate;
            const prefix = ctx.extend(absolute, current, 0, 3);
            if (prefix == 3) {
                const length = ctx.extend(absolute, current, 3, maximum);
                frontier.add(length, @intCast(current - absolute));
                if (length == maximum or length >= self.options.nice_len) return;
            }
            candidate = self.nodes[ctx.slot(absolute)].short_previous;
        }
    }
};

/// Validate the relative checkpoint before allocating or changing the ring.
/// Normalization leaves at most history + one meta-block inside the new epoch.
fn normalizationAmount(epoch: u64, metadata: view.Metadata) !?u32 {
    if (metadata.begin < epoch or metadata.end < epoch) return error.InvalidBlockPlan;
    if (metadata.end - epoch < @as(u64, types.invalid) - types.max_source_len) return null;
    const amount = std.math.cast(u32, metadata.begin - epoch) orelse return error.InvalidBlockPlan;
    return amount;
}

fn normalized(reference: u32, sub: u32) u32 {
    return if (reference == types.invalid or reference < sub) types.invalid else reference - sub;
}
fn resolveProfile(options: anytype, profile: ?*HqProfile) ?*HqProfile {
    if (profile != null) return profile;
    return if (@hasField(@TypeOf(options), "profile")) options.profile else null;
}

test {
    _ = @import("hq_tree/large_window_tests.zig");
}
