const std = @import("std");
const controls = @import("../../encode/controls.zig");
const types = @import("types.zig");
const view = @import("view.zig");
const resources = @import("resources.zig");
const policy = @import("policy.zig");

pub const Source = @import("../controlled_source.zig").Source;
pub const HqOptions = @import("../../encode/hq_options.zig").HqOptions;
pub const Match = types.Match;
pub const Matches = types.Matches;
pub const Iterator = types.Iterator;
const invalid = types.invalid;
const Operation = enum { find, skip, seed };

/// Adaptive BT4/short3 matcher for local optimal parsing. Every retained prefix
/// position is indexed. Long block skips sample each eighth position and index
/// the last 64 positions densely; this is an explicit quality/effort heuristic.
/// Borrowed sources stay immutable and compact generations validate all links.
/// Active hash masks are independent of retained allocation capacities.
pub fn MatcherImpl(comptime sized_heads: bool, comptime sparse_skip: bool) type {
    return struct {
        const Self = @This();

        source: Source = Source.init("", "", "", 1),
        options: HqOptions = .{},
        profile: ?*controls.Profile = null,
        short_heads: []u32 = &.{},
        long_heads: []u32 = &.{},
        nodes: []types.Node = &.{},
        candidates: []Match = &.{},
        metadata: policy.Metadata(sized_heads) = .{ .prefix = 0, .total = 0 },
        cycle_size: usize = 0,
        cursor: usize = 0,
        candidate_count: usize = 0,
        indexed_positions: usize = 0,
        ready: bool = false,

        pub fn requiredWorkingMemory(source: Source, options: HqOptions) !usize {
            return (try policy.requirements(source, options, sized_heads)).bytes();
        }

        pub fn init(allocator: std.mem.Allocator, source: Source, options: HqOptions, profile: ?*controls.Profile) !Self {
            var result: Self = .{};
            errdefer result.deinit(allocator);
            try result.prepare(allocator, source, options, profile);
            return result;
        }

        /// Failed validation/allocation preserves the previous logical checkpoint.
        /// Successful prepare invalidates prior views and rebuilds the full prefix;
        /// retained capacities, replacements and old/new coexistence count in quota.
        pub fn prepare(self: *Self, allocator: std.mem.Allocator, source: Source, options: HqOptions, profile: ?*controls.Profile) !void {
            const needed = try policy.requirements(source, options, sized_heads);
            const old_bytes = self.allocationBytes();
            const new_bytes = try requiredAllocationBytes(needed);
            const peak = try resources.growthPeak(old_bytes, new_bytes);
            try resources.check(peak, options.max_working_memory);
            if (profile) |p| p.recordPeakWorkingMemory(self.workingBytes());
            try self.grow(u32, &self.short_heads, needed.short_heads, allocator, profile);
            try self.grow(u32, &self.long_heads, needed.long_heads, allocator, profile);
            try self.grow(types.Node, &self.nodes, needed.nodes, allocator, profile);
            try self.grow(Match, &self.candidates, needed.matches, allocator, profile);
            // Everything after storage growth is non-fallible on validated metadata.
            self.source = source;
            self.options = options;
            self.profile = profile;
            self.metadata = policy.metadata(needed, sized_heads);
            self.cycle_size = needed.nodes;
            self.cursor = 0;
            self.candidate_count = 0;
            self.indexed_positions = 0;
            self.ready = true;
            @memset(self.short_heads[0..needed.short_heads], invalid);
            @memset(self.long_heads[0..needed.long_heads], invalid);
            @memset(self.nodes[0..self.cycle_size], .{});
            self.recordSettings();
            while (self.cursor < self.metadata.prefix) self.process(.seed);
        }

        pub fn find(self: *Self) !Matches {
            return self.getMatches();
        }
        pub fn getMatches(self: *Self) !Matches {
            if (!self.ready or self.cursor >= self.metadata.total) return error.InvalidBlockPlan;
            self.process(.find);
            return .{ .items = self.candidates[0..self.candidate_count] };
        }
        pub fn position(self: *const Self) usize {
            return if (self.ready) self.cursor - self.metadata.prefix else 0;
        }
        pub fn skip(self: *Self, amount: usize) !void {
            if (!self.ready or amount > self.metadata.total - self.cursor) return error.InvalidBlockPlan;
            if (!sparse_skip or self.metadata.prefix != 0 or amount <= 128) {
                for (0..amount) |_| self.process(.skip);
                return;
            }
            // Logical input progress and skip accounting cover the full span. Only
            // block insertion becomes sparse, with the final 64 bytes kept dense.
            const end = self.cursor + amount;
            const dense_start = end - 64;
            while (self.cursor < dense_start) {
                self.process(.skip);
                const omitted = @min(@as(usize, 7), dense_start - self.cursor);
                self.cursor += omitted;
                self.count("skipped_positions", omitted);
            }
            while (self.cursor < end) self.process(.skip);
        }
        pub fn advanceTo(self: *Self, block_position: usize) !void {
            if (!self.ready or block_position < self.position() or block_position > self.source.block.len) return error.InvalidBlockPlan;
            try self.skip(block_position - self.position());
        }

        /// Clone a read-only checkpoint into independent mutable storage. The
        /// supplied quota includes source and clone simultaneously; an outer caller
        /// allocator can additionally account for parser and other live owners.
        pub fn fork(self: *const Self, allocator: std.mem.Allocator, max_working_memory: usize, profile: ?*controls.Profile) !Self {
            if (!self.ready) return error.InvalidBlockPlan;
            const needed = try policy.requirements(self.source, self.options, sized_heads);
            const peak = try resources.add(self.workingBytes(), try needed.bytes());
            try resources.check(peak, max_working_memory);
            var result: Self = .{};
            errdefer result.deinit(allocator);
            try result.grow(u32, &result.short_heads, needed.short_heads, allocator, null);
            if (profile) |p| p.recordPeakWorkingMemory(self.workingBytes() + result.workingBytes());
            try result.grow(u32, &result.long_heads, needed.long_heads, allocator, null);
            if (profile) |p| p.recordPeakWorkingMemory(self.workingBytes() + result.workingBytes());
            try result.grow(types.Node, &result.nodes, needed.nodes, allocator, null);
            if (profile) |p| p.recordPeakWorkingMemory(self.workingBytes() + result.workingBytes());
            try result.grow(Match, &result.candidates, needed.matches, allocator, null);
            if (profile) |p| p.recordPeakWorkingMemory(self.workingBytes() + result.workingBytes());
            @memcpy(result.short_heads, self.short_heads[0..needed.short_heads]);
            @memcpy(result.long_heads, self.long_heads[0..needed.long_heads]);
            @memcpy(result.nodes, self.nodes[0..needed.nodes]);
            @memcpy(result.candidates[0..self.candidate_count], self.candidates[0..self.candidate_count]);
            result.source = self.source;
            result.options = self.options;
            result.options.max_working_memory = max_working_memory;
            result.profile = profile;
            result.metadata = self.metadata;
            result.cycle_size = self.cycle_size;
            result.cursor = self.cursor;
            result.candidate_count = self.candidate_count;
            result.indexed_positions = self.indexed_positions;
            result.ready = true;
            result.recordSettings();
            if (profile) |p| {
                p.recordPeakWorkingMemory(peak);
                if (self.indexed_positions != 0) p.add("shared_seed_reuses", 1);
            }
            return result;
        }

        pub fn workingBytes(self: *const Self) usize {
            var total: usize = 0;
            for (self.allocationBytes()) |bytes| total += bytes;
            return total;
        }
        pub fn reset(self: *Self) void {
            self.source = Source.init("", "", "", 1);
            self.profile = null;
            self.metadata = .{ .prefix = 0, .total = 0 };
            self.cursor = 0;
            self.cycle_size = 0;
            self.candidate_count = 0;
            self.indexed_positions = 0;
            self.ready = false;
        }
        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            allocator.free(self.candidates);
            allocator.free(self.nodes);
            allocator.free(self.long_heads);
            allocator.free(self.short_heads);
            self.* = .{};
        }

        fn allocationBytes(self: *const Self) [4]usize {
            return .{ self.short_heads.len * @sizeOf(u32), self.long_heads.len * @sizeOf(u32), self.nodes.len * @sizeOf(types.Node), self.candidates.len * @sizeOf(Match) };
        }
        fn grow(self: *Self, comptime T: type, allocation: *[]T, required: usize, allocator: std.mem.Allocator, profile: ?*controls.Profile) !void {
            if (allocation.len >= required) return;
            const before = self.workingBytes();
            const replacement = try allocator.alloc(T, required);
            if (profile) |p| p.recordPeakWorkingMemory(before + replacement.len * @sizeOf(T));
            @memcpy(replacement[0..allocation.len], allocation.*);
            allocator.free(allocation.*);
            allocation.* = replacement;
        }
        fn recordSettings(self: *const Self) void {
            if (self.profile) |p| {
                p.available = true;
                p.controls_used = true;
                p.recordEffectiveHq(self.options);
                p.recordPeakWorkingMemory(self.workingBytes());
            }
        }
        fn count(self: *const Self, comptime field: []const u8, amount: usize) void {
            if (self.profile) |p| p.add(field, amount);
        }
        fn valid(self: *const Self, candidate: u32, current: usize) bool {
            if (candidate == invalid or candidate >= current or current - candidate > self.source.window_len) return false;
            return self.nodes[candidate % self.cycle_size].position == candidate;
        }
        fn extend(self: *const Self, candidate: usize, current: usize, start: usize, limit: usize) usize {
            var compared: usize = 0;
            const result = view.extend(self.source, candidate, current, start, limit, &compared);
            self.count("byte_comparisons", compared);
            return result;
        }
        fn addMatch(self: *Self, length: usize, distance: usize) void {
            if (length < self.options.min_match) return;
            if (self.candidate_count != 0) {
                const last = &self.candidates[self.candidate_count - 1];
                if (length < last.length) return;
                if (length == last.length) {
                    last.distance = @min(last.distance, distance);
                    return;
                }
            }
            std.debug.assert(self.candidate_count < self.candidates.len);
            self.candidates[self.candidate_count] = .{ .length = length, .distance = distance };
            self.candidate_count += 1;
        }

        fn process(self: *Self, operation: Operation) void {
            self.candidate_count = 0;
            const current = self.cursor;
            self.cursor += 1;
            switch (operation) {
                .find => self.count("positions_tested", 1),
                .skip => self.count("skipped_positions", 1),
                .seed => {
                    if (current < self.source.dictionary.len) self.count("dictionary_seed_positions", 1) else self.count("history_seed_positions", 1);
                },
            }
            const available = self.metadata.total - current;
            if (available < 3) return;
            const short_key = hash(self.source, current, 3) & (if (sized_heads) self.metadata.short_mask else types.hash_size - 1);
            const short_candidate = self.short_heads[short_key];
            self.short_heads[short_key] = @intCast(current);
            const node = &self.nodes[current % self.cycle_size];
            node.* = .{ .position = @intCast(current), .short_previous = short_candidate };
            self.indexed_positions += 1;
            const collect = operation == .find and available >= self.options.min_match;
            const limit = @min(available, @max(@as(usize, 4), self.options.nice_len));
            if (collect) self.shortSearch(short_candidate, current, limit);
            if (available >= 4) {
                const long_key = hash(self.source, current, 4) & (if (sized_heads) self.metadata.long_mask else types.hash_size - 1);
                const first = self.long_heads[long_key];
                self.long_heads[long_key] = @intCast(current);
                self.count("long_hash_probes", 1);
                self.treeInsert(first, current, limit, collect);
            }
            if (collect and self.candidate_count != 0) {
                const last = &self.candidates[self.candidate_count - 1];
                if (last.length >= self.options.nice_len and last.length < available)
                    last.length = self.extend(current - last.distance, current, last.length, available);
            }
        }

        fn shortSearch(self: *Self, first: u32, current: usize, limit: usize) void {
            var candidate = first;
            var remaining = self.options.search_depth;
            while (candidate != invalid and remaining != 0) {
                remaining -= 1;
                self.count("short_hash_probes", 1);
                self.count("candidate_checks", 1);
                if (!self.valid(candidate, current)) return;
                const prefix_length = self.extend(candidate, current, 0, 3);
                const length = if (prefix_length == 3) self.extend(candidate, current, 3, limit) else prefix_length;
                if (length >= 3) {
                    self.addMatch(length, current - candidate);
                    return;
                }
                candidate = self.nodes[candidate % self.cycle_size].short_previous;
            }
        }

        fn treeInsert(self: *Self, first: u32, current: usize, limit: usize, collect: bool) void {
            const node = &self.nodes[current % self.cycle_size];
            var lower = &node.left;
            var upper = &node.right;
            var lower_length: usize = 0;
            var upper_length: usize = 0;
            var candidate = first;
            var remaining = self.options.search_depth;
            while (candidate != invalid) {
                if (remaining == 0) {
                    self.count("depth_stops", 1);
                    break;
                }
                remaining -= 1;
                self.count("tree_nodes", 1);
                self.count("candidate_checks", 1);
                if (!self.valid(candidate, current)) break;
                const other = &self.nodes[candidate % self.cycle_size];
                const length = self.extend(candidate, current, @min(lower_length, upper_length), limit);
                if (collect) self.addMatch(length, current - candidate);
                if (length == limit) {
                    lower.* = other.left;
                    upper.* = other.right;
                    self.count("nice_stops", 1);
                    return;
                }
                self.count("byte_comparisons", 1);
                if (self.source.byteAt(candidate + length) < self.source.byteAt(current + length)) {
                    lower.* = candidate;
                    lower = &other.right;
                    candidate = lower.*;
                    lower_length = length;
                } else {
                    upper.* = candidate;
                    upper = &other.left;
                    candidate = upper.*;
                    upper_length = length;
                }
            }
            lower.* = invalid;
            upper.* = invalid;
        }
    };
}

fn requiredAllocationBytes(needed: resources.Requirements) ![4]usize {
    return .{ try resources.multiply(needed.short_heads, @sizeOf(u32)), try resources.multiply(needed.long_heads, @sizeOf(u32)), try resources.multiply(needed.nodes, @sizeOf(types.Node)), try resources.multiply(needed.matches, @sizeOf(Match)) };
}

fn hash(source: Source, position: usize, width: usize) usize {
    var word: u32 = 0;
    for (0..width) |index| word |= @as(u32, source.byteAt(position + index)) << @intCast(index * 8);
    return (word *% 2654435761) >> 16;
}
