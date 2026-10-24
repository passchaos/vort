const std = @import("std");
const controls = @import("../../encode/controls.zig");
const source_mod = @import("../controlled_source.zig");
const resources = @import("resources.zig");
const hash_size = 1 << 16;
const empty = std.math.maxInt(usize);
const Node = struct { position: usize = empty, previous: usize = empty };
pub const Match = source_mod.Match;
/// Borrowed frontier, valid until the next find or owner destruction.
pub const Matches = struct {
    items: []const Match,
    len: usize = 0,
    pub fn slice(self: *const Matches) []const Match {
        return self.items[0..self.len];
    }
};

/// Monotonic three-byte hash chain over every retained prefix position. Links
/// carry absolute generations, so recycled ring entries cannot become matches.
pub const Matcher = struct {
    source: source_mod.Source,
    options: controls.HqOptions,
    profile: ?*controls.Profile,
    head: []usize,
    nodes: []Node,
    candidates: []Match,
    next: usize,

    pub fn requiredWorkingMemory(source: source_mod.Source, options: controls.HqOptions) !usize {
        try options.validate();
        const total = try source.checkedTotalLen();
        if (source.window_len == 0 or source.window_len > std.math.maxInt(u32) - 3 or try source.checkedPrefixLen() > source.window_len)
            return error.InvalidBlockPlan;
        const ring = @max(1, @min(total, try resources.add(source.window_len, 1)));
        const index = try resources.add(try resources.multiply(hash_size, @sizeOf(usize)), try resources.multiply(ring, @sizeOf(Node)));
        return resources.add(index, try resources.multiply(candidateCapacity(source, options), @sizeOf(Match)));
    }
    pub fn init(allocator: std.mem.Allocator, source: source_mod.Source, options: controls.HqOptions, profile: ?*controls.Profile) !Matcher {
        if (try requiredWorkingMemory(source, options) > options.max_working_memory) return error.WorkingMemoryLimitExceeded;
        const head = try allocator.alloc(usize, hash_size);
        errdefer allocator.free(head);
        @memset(head, empty);
        const total = try source.checkedTotalLen();
        const ring = @max(1, @min(total, try resources.add(source.window_len, 1)));
        const nodes = try allocator.alloc(Node, ring);
        errdefer allocator.free(nodes);
        @memset(nodes, .{});
        const candidates = try allocator.alloc(Match, candidateCapacity(source, options));
        var result: Matcher = .{ .source = source, .options = options, .profile = profile, .head = head, .nodes = nodes, .candidates = candidates, .next = 0 };
        const prefix = try source.checkedPrefixLen();
        while (result.next < prefix) : (result.next += 1) {
            result.insert(result.next);
            if (profile) |p| {
                if (result.next < source.dictionary.len) p.add("dictionary_seed_positions", 1) else p.add("history_seed_positions", 1);
            }
        }
        return result;
    }
    pub fn deinit(self: *Matcher, allocator: std.mem.Allocator) void {
        allocator.free(self.candidates);
        allocator.free(self.nodes);
        allocator.free(self.head);
    }
    pub fn workingBytes(self: *const Matcher) usize {
        return self.head.len * @sizeOf(usize) + self.nodes.len * @sizeOf(Node) + self.candidates.len * @sizeOf(Match);
    }
    pub fn position(self: *const Matcher) usize {
        return self.next - self.source.prefixLen();
    }
    pub fn advanceTo(self: *Matcher, target: usize) !void {
        if (target < self.position() or target > self.source.block.len) return error.InvalidBlockPlan;
        while (self.position() < target) : (self.next += 1) {
            self.insert(self.next);
            if (self.profile) |p| p.add("skipped_positions", 1);
        }
    }
    pub fn find(self: *Matcher) !Matches {
        if (self.position() == self.source.block.len) return error.InvalidBlockPlan;
        var result: Matches = .{ .items = self.candidates };
        const current = self.next;
        if (self.profile) |p| p.add("positions_tested", 1);
        if (self.source.totalLen() - current >= 3) {
            const key = self.hash(current);
            var candidate = self.head[key];
            var depth: usize = self.options.search_depth;
            while (candidate != empty and candidate < current and current - candidate <= self.source.window_len) {
                if (depth == 0) {
                    if (self.profile) |p| p.add("depth_stops", 1);
                    break;
                }
                depth -= 1;
                const node = self.nodes[candidate % self.nodes.len];
                if (node.position != candidate) break;
                if (self.profile) |p| {
                    p.add("candidate_checks", 1);
                    p.add("short_hash_probes", 1);
                }
                const length = resources.matchLength(self.source, self.position(), current - candidate, self.source.block.len - self.position(), self.profile);
                if (length >= self.options.min_match) {
                    if (result.len == 0 or length > result.items[result.len - 1].length) {
                        // At most one record per visited node and one per
                        // possible match length; init reserves both bounds.
                        std.debug.assert(result.len < self.candidates.len);
                        self.candidates[result.len] = .{ .length = length, .distance = current - candidate };
                        result.len += 1;
                    }
                    if (length >= self.options.nice_len) {
                        if (self.profile) |p| p.add("nice_stops", 1);
                        break;
                    }
                }
                candidate = node.previous;
            }
            self.insert(current);
        }
        self.next += 1;
        result.items = self.candidates[0..result.len];
        return result;
    }
    fn candidateCapacity(source: source_mod.Source, options: controls.HqOptions) usize {
        return @min(@as(usize, options.search_depth), source.block.len -| (options.min_match - 1));
    }
    fn insert(self: *Matcher, absolute: usize) void {
        if (self.source.totalLen() - absolute < 3) return;
        const key = self.hash(absolute);
        self.nodes[absolute % self.nodes.len] = .{ .position = absolute, .previous = self.head[key] };
        self.head[key] = absolute;
    }
    fn hash(self: *const Matcher, at: usize) usize {
        const word = @as(u32, self.source.byteAt(at)) | (@as(u32, self.source.byteAt(at + 1)) << 8) | (@as(u32, self.source.byteAt(at + 2)) << 16);
        return (word *% 2654435761) >> 16;
    }
};
