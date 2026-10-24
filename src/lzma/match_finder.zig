const std = @import("std");
const settings = @import("encode_options.zig");
pub const Source = @import("match_finder/source.zig").Source;
pub const MatchOptions = settings.MatchOptions;
pub const MatchFinder = settings.MatchFinder;
pub const max_window_len = settings.max_dictionary_size;
pub const max_match_len: usize = settings.max_match_len;
pub const max_candidates: usize = max_match_len - 1;
const hash_size = 1 << 16;
const empty = std.math.maxInt(usize);

/// Distances are ordinary one-based byte distances. The range writer converts
/// them into the LZMA wire representation; the matcher never emits dist-1.
pub const Match = struct { length: u16 = 0, distance: u32 = 0 };
pub const Matches = struct {
    items: [max_candidates]Match = undefined,
    len: usize = 0,

    pub fn slice(self: *const Matches) []const Match {
        return self.items[0..self.len];
    }

    pub fn best(self: *const Matches) Match {
        return if (self.len == 0) .{} else self.items[self.len - 1];
    }

    fn add(self: *Matches, length: usize, distance: usize) void {
        if (length < 2 or length <= self.best().length) return;
        std.debug.assert(self.len < self.items.len);
        self.items[self.len] = .{ .length = @intCast(length), .distance = @intCast(distance) };
        self.len += 1;
    }
};

const ChainNode = struct { position: usize = empty, previous: usize = empty };
const TreeNode = struct { position: usize = empty, left: usize = empty, right: usize = empty };
const Operation = enum { find, skip, seed };

/// Predict requested matcher heap bytes without allocating or reading samples.
/// The actual source length clips the requested dictionary ring, so a large
/// dictionary setting alone never causes a large node allocation.
pub fn requiredWorkingMemory(source: Source, options: MatchOptions) !usize {
    try options.validate();
    if (source.window_len == 0 or source.window_len > max_window_len or source.dictionary.len > source.window_len)
        return error.InvalidLzmaOptions;
    const total = try source.checkedTotalLen();
    if (total < 2) return 0;
    const cycle_size = @min(total, try add(source.window_len, 1));
    const tables: usize = options.finder.hashBytes() - 1;
    const head_bytes = try multiply(try multiply(hash_size, tables), @sizeOf(usize));
    const node_bytes = try multiply(cycle_size, if (options.finder.isBinaryTree()) @sizeOf(TreeNode) else @sizeOf(ChainNode));
    return add(head_bytes, node_bytes);
}

/// Monotonic HC3/HC4 or BT2/BT3/BT4 over a borrowed virtual source. Hash heads
/// and links contain absolute usize positions; ring nodes validate their exact
/// generation before following a link. Heap use is bounded by the window,
/// independently of how large the input becomes. No allocator/self pointer is
/// retained, so moving this owner is safe; samples must remain immutable.
pub const Matcher = struct {
    source: Source,
    options: MatchOptions,
    head2: []usize = &.{},
    head3: []usize = &.{},
    head4: []usize = &.{},
    chain: []ChainNode = &.{},
    tree: []TreeNode = &.{},
    next_position: usize = 0,
    cycle_size: usize = 0,

    pub fn init(allocator: std.mem.Allocator, source: Source, options: MatchOptions) !Matcher {
        const required = try requiredWorkingMemory(source, options);
        if (required > options.max_working_memory) return error.WorkingMemoryLimitExceeded;
        const total = try source.checkedTotalLen();
        var result: Matcher = .{ .source = source, .options = options };
        errdefer result.deinit(allocator);
        const width = options.finder.hashBytes();
        if (total >= 2) {
            result.cycle_size = @min(total, try add(source.window_len, 1));
            result.head2 = try allocator.alloc(usize, hash_size);
            @memset(result.head2, empty);
            if (width >= 3) {
                result.head3 = try allocator.alloc(usize, hash_size);
                @memset(result.head3, empty);
            }
            if (width >= 4) {
                result.head4 = try allocator.alloc(usize, hash_size);
                @memset(result.head4, empty);
            }
            if (options.finder.isBinaryTree()) {
                result.tree = try allocator.alloc(TreeNode, result.cycle_size);
                @memset(result.tree, .{});
            } else {
                result.chain = try allocator.alloc(ChainNode, result.cycle_size);
                @memset(result.chain, .{});
            }
        }
        if (options.profile) |p| {
            p.finder = options.finder;
            p.effective_nice_len = options.effectiveNiceLen();
            p.effective_depth = options.effectiveDepth();
            p.mf_peak_working_memory = @max(p.mf_peak_working_memory, result.workingBytes());
            p.peak_working_memory = @max(p.peak_working_memory, result.workingBytes());
        }
        var discard: Matches = .{};
        while (result.next_position < source.dictionary.len) result.process(&discard, .seed);
        return result;
    }

    pub fn deinit(self: *Matcher, allocator: std.mem.Allocator) void {
        allocator.free(self.tree);
        allocator.free(self.chain);
        allocator.free(self.head4);
        allocator.free(self.head3);
        allocator.free(self.head2);
        self.* = .{ .source = Source.init("", "", 1), .options = .{} };
    }

    pub fn workingBytes(self: *const Matcher) usize {
        return (self.head2.len + self.head3.len + self.head4.len) * @sizeOf(usize) + self.chain.len * @sizeOf(ChainNode) + self.tree.len * @sizeOf(TreeNode);
    }

    pub fn position(self: *const Matcher) usize {
        return self.next_position - self.source.prefixLen();
    }

    pub fn getMatches(self: *Matcher, matches: *Matches) !void {
        if (self.next_position >= self.source.totalLen()) return error.InvalidBlockPlan;
        self.process(matches, .find);
    }

    pub fn find(self: *Matcher) !Matches {
        var matches: Matches = .{};
        try self.getMatches(&matches);
        return matches;
    }

    pub fn skip(self: *Matcher, amount: usize) !void {
        if (amount > self.source.totalLen() - self.next_position) return error.InvalidBlockPlan;
        var discard: Matches = .{};
        for (0..amount) |_| self.process(&discard, .skip);
    }

    pub fn advanceTo(self: *Matcher, input_position: usize) !void {
        if (input_position > self.source.input.len or input_position < self.position()) return error.InvalidBlockPlan;
        try self.skip(input_position - self.position());
    }

    fn count(self: *const Matcher, comptime field: []const u8, amount: usize) void {
        if (self.options.profile) |p| @field(p, field) +|= @as(u64, @intCast(amount));
    }

    fn valid(self: *const Matcher, candidate: usize, current: usize) bool {
        if (candidate == empty or candidate >= current or current - candidate > self.source.window_len) return false;
        const slot = candidate % self.cycle_size;
        return if (self.options.finder.isBinaryTree()) self.tree[slot].position == candidate else self.chain[slot].position == candidate;
    }

    fn extension(self: *const Matcher, candidate: usize, current: usize, start: usize, limit: usize) usize {
        var compared: usize = 0;
        const length = self.source.extend(candidate, current, start, limit, &compared);
        self.count("mf_compared_bytes", compared);
        return length;
    }

    fn process(self: *Matcher, matches: *Matches, operation: Operation) void {
        matches.len = 0;
        const current = self.next_position;
        self.next_position += 1;
        self.count("mf_positions", 1);
        if (operation == .seed) self.count("mf_seed_positions", 1);
        if (operation == .skip) self.count("mf_skipped_positions", 1);
        const available = self.source.totalLen() - current;
        if (available < 2) return;
        const width = self.options.finder.hashBytes();
        const limit = @min(available, self.options.effectiveNiceLen());
        const collect = operation == .find;
        const key2 = @as(usize, self.source.byteAt(current)) | (@as(usize, self.source.byteAt(current + 1)) << 8);
        const candidate2 = self.head2[key2];
        self.head2[key2] = current;
        self.count("mf_hash_probes", 1);
        var primary = candidate2;
        if (width >= 3 and available >= 3) {
            const key3 = hash(self.source, current, 3);
            primary = self.head3[key3];
            self.head3[key3] = current;
            self.count("mf_hash_probes", 1);
        }
        const candidate3 = primary;
        if (width >= 4 and available >= 4) {
            const key4 = hash(self.source, current, 4);
            primary = self.head4[key4];
            self.head4[key4] = current;
            self.count("mf_hash_probes", 1);
        }
        // Validate candidates before recycling the current ring slot.
        if (collect and width >= 3) self.auxiliary(matches, candidate2, current, limit);
        if (collect and width >= 4 and candidate3 != candidate2 and available >= 3) self.auxiliary(matches, candidate3, current, limit);
        if (self.options.finder.isBinaryTree()) {
            self.treeInsert(matches, primary, current, limit, collect);
        } else {
            self.chain[current % self.cycle_size] = .{ .position = current, .previous = if (available >= width) primary else empty };
            if (collect and available >= width) self.chainSearch(matches, primary, current, limit);
        }
        if (collect and matches.len > 0) {
            const best = &matches.items[matches.len - 1];
            if (best.length == limit and limit < @min(available, max_match_len))
                best.length = @intCast(self.extension(current - best.distance, current, limit, @min(available, max_match_len)));
            self.count("mf_matches", matches.len);
        }
    }

    fn auxiliary(self: *Matcher, matches: *Matches, candidate: usize, current: usize, limit: usize) void {
        if (candidate == empty) return;
        self.count("mf_candidate_probes", 1);
        if (!self.valid(candidate, current)) return;
        matches.add(self.extension(candidate, current, 0, limit), current - candidate);
    }

    fn chainSearch(self: *Matcher, matches: *Matches, first: usize, current: usize, limit: usize) void {
        if (matches.best().length == limit) {
            self.count("nice_stops", 1);
            return;
        }
        var candidate = first;
        var depth = self.options.effectiveDepth();
        while (candidate != empty) {
            if (depth == 0) {
                self.count("depth_stops", 1);
                return;
            }
            depth -= 1;
            self.count("mf_chain_steps", 1);
            self.count("mf_candidate_probes", 1);
            if (!self.valid(candidate, current)) return;
            const length = self.extension(candidate, current, 0, limit);
            matches.add(length, current - candidate);
            if (length == limit) {
                self.count("nice_stops", 1);
                return;
            }
            candidate = self.chain[candidate % self.cycle_size].previous;
        }
    }

    fn treeInsert(self: *Matcher, matches: *Matches, first: usize, current: usize, limit: usize, collect: bool) void {
        const node = &self.tree[current % self.cycle_size];
        node.* = .{ .position = current };
        var lower = &node.left;
        var upper = &node.right;
        var lower_length: usize = 0;
        var upper_length: usize = 0;
        var candidate = first;
        var depth = self.options.effectiveDepth();
        while (candidate != empty) {
            if (depth == 0) {
                self.count("depth_stops", 1);
                break;
            }
            depth -= 1;
            self.count("mf_tree_steps", 1);
            self.count("mf_candidate_probes", 1);
            if (!self.valid(candidate, current)) break;
            const other = &self.tree[candidate % self.cycle_size];
            const length = self.extension(candidate, current, @min(lower_length, upper_length), limit);
            if (collect) matches.add(length, current - candidate);
            if (length == limit) {
                lower.* = other.left;
                upper.* = other.right;
                self.count("nice_stops", 1);
                return;
            }
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
        lower.* = empty;
        upper.* = empty;
    }
};

fn hash(source: Source, position: usize, width: usize) usize {
    var word: u32 = 0;
    for (0..width) |i| word |= @as(u32, source.byteAt(position + i)) << @intCast(i * 8);
    return (word *% 2654435761) >> 16;
}

fn add(a: usize, b: usize) !usize {
    return std.math.add(usize, a, b) catch error.WorkingMemoryLimitExceeded;
}

fn multiply(a: usize, b: usize) !usize {
    return std.math.mul(usize, a, b) catch error.WorkingMemoryLimitExceeded;
}

test {
    _ = @import("match_finder/tests.zig");
}
