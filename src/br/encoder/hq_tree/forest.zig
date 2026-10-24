const Source = @import("../hq_types.zig").Source;
const Profile = @import("../hq_options.zig").HqProfile;
const types = @import("types.zig");
const view = @import("view.zig");

/// Temporary views only; no pointer into an owning matcher is retained.
pub const Context = struct {
    source: Source,
    metadata: view.Metadata,
    epoch: u64,
    cycle: usize,
    nodes: []types.Node,
    options: types.Search,
    profile: ?*Profile,

    pub fn slot(self: Context, absolute: u64) usize {
        return @intCast(absolute & (self.cycle - 1));
    }
    pub fn valid(self: Context, reference: u32, current: u64) bool {
        if (reference == types.invalid or reference >= current - self.epoch) return false;
        const absolute = self.epoch + reference;
        if (absolute < self.metadata.begin or current - absolute > self.metadata.window_len) return false;
        return self.nodes[self.slot(absolute)].position == reference;
    }
    pub fn count(self: Context, comptime field: []const u8, amount: usize) void {
        if (self.profile) |p| p.add(field, amount);
    }
    pub fn extend(self: Context, candidate: u64, current: u64, start: usize, limit: usize) usize {
        var compared: usize = 0;
        const length = view.extend(self.source, self.metadata, candidate, current, start, limit, &compared);
        self.count("byte_comparisons", compared);
        return length;
    }

    /// The 128-byte key controls ordering; full match lengths control the
    /// frontier. Incomplete tail searches never mutate roots or tree children.
    pub fn walk(self: Context, first: u32, current: u64, maximum: usize, store: bool, collect: bool, frontier: types.Frontier) void {
        const key_limit = @min(maximum, types.store_lookahead);
        const node = &self.nodes[self.slot(current)];
        var lower = &node.left;
        var upper = &node.right;
        var left_length: usize = 0;
        var right_length: usize = 0;
        var candidate = first;
        var remaining = self.options.search_depth;
        var gathering = collect;
        while (candidate != types.invalid and remaining != 0) {
            remaining -= 1;
            self.count("tree_nodes", 1);
            self.count("match_probes", 1);
            if (!self.valid(candidate, current)) break;
            const absolute = self.epoch + candidate;
            const other = &self.nodes[self.slot(absolute)];
            const prefix = self.extend(absolute, current, @min(left_length, right_length), key_limit);
            if (gathering) {
                const length = if (prefix == key_limit) self.extend(absolute, current, prefix, maximum) else prefix;
                frontier.add(length, @intCast(current - absolute));
                if (length >= self.options.nice_len or length == maximum) {
                    gathering = false;
                    if (!store) return;
                }
            }
            if (prefix == key_limit) {
                if (store) {
                    lower.* = other.left;
                    upper.* = other.right;
                }
                return;
            }
            self.count("byte_comparisons", 1);
            if (view.byteAt(self.source, self.metadata, absolute + prefix) < view.byteAt(self.source, self.metadata, current + prefix)) {
                if (store) lower.* = candidate;
                lower = &other.right;
                candidate = lower.*;
                left_length = prefix;
            } else {
                if (store) upper.* = candidate;
                upper = &other.left;
                candidate = upper.*;
                right_length = prefix;
            }
        }
        if (store) {
            lower.* = types.invalid;
            upper.* = types.invalid;
        }
    }
};
