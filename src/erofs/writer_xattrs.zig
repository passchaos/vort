const std = @import("std");
const tree = @import("writer_tree.zig");
const xattr = @import("xattr.zig");

pub const Error = tree.Error || xattr.Error;

const max_shared_per_inode: usize = std.math.maxInt(u8);

const Candidate = struct {
    attribute: xattr.Attribute,
    entry_size: usize,
    occurrence_count: usize,
    disabled: bool = false,
    reference_count: usize = 0,
    id: u32 = 0,

    fn profitable(self: Candidate, count: usize) bool {
        if (count < 2) return false;
        const inline_cost = @as(u128, count) * self.entry_size;
        const shared_cost = @as(u128, self.entry_size) + @as(u128, count) * 4;
        return shared_cost < inline_cost;
    }

    fn savings(self: Candidate) u128 {
        if (!self.profitable(self.occurrence_count)) return 0;
        return @as(u128, self.occurrence_count) * self.entry_size -
            (@as(u128, self.entry_size) + @as(u128, self.occurrence_count) * 4);
    }
};

const NodePlan = struct {
    references: []?u32,
};

pub const Plan = struct {
    allocator: std.mem.Allocator,
    candidates: []Candidate,
    nodes: []NodePlan,
    region_start: usize = 0,
    region_end: usize = 0,
    xattr_block: u32 = 0,
    placed: bool = false,

    pub fn deinit(self: *Plan) void {
        for (self.nodes) |node| self.allocator.free(node.references);
        self.allocator.free(self.nodes);
        self.allocator.free(self.candidates);
        self.* = undefined;
    }

    pub fn place(
        self: *Plan,
        start: usize,
        block_size: usize,
    ) Error!usize {
        if (self.placed or block_size == 0 or !std.math.isPowerOfTwo(block_size))
            return error.InvalidErofs;
        self.placed = true;
        if (!self.hasShared()) {
            self.region_start = start;
            self.region_end = start;
            return start;
        }

        const region_start = try align4(start);
        const block = region_start / block_size;
        if (block > std.math.maxInt(u32)) return error.InvalidErofs;
        const block_start = try checkedMul(block, block_size);
        var position = region_start;
        for (self.candidates) |*candidate| {
            if (!candidate.profitable(candidate.reference_count)) continue;
            const relative = position - block_start;
            if (relative & 3 != 0 or relative / 4 > std.math.maxInt(u32))
                return error.InvalidErofs;
            candidate.id = @intCast(relative / 4);
            position = try checkedAdd(position, candidate.entry_size);
        }
        self.region_start = region_start;
        self.region_end = position;
        self.xattr_block = @intCast(block);
        return position;
    }

    pub fn encodedIbodySize(
        self: Plan,
        node_index: usize,
        attributes: []const xattr.Attribute,
        long_prefixes: []const []const u8,
    ) Error!usize {
        const references = try self.nodeReferences(node_index, attributes.len);
        if (attributes.len == 0) return 0;
        var size: usize = 12;
        for (attributes, references) |attribute, reference| {
            size = try checkedAdd(
                size,
                if (reference != null)
                    4
                else
                    try xattr.encodedEntrySize(attribute, long_prefixes),
            );
        }
        _ = try xattr.ibodyIcount(size);
        return size;
    }

    pub fn writeIbody(
        self: Plan,
        output: []u8,
        node_index: usize,
        attributes: []const xattr.Attribute,
        long_prefixes: []const []const u8,
    ) Error!void {
        if (!self.placed or
            output.len != try self.encodedIbodySize(node_index, attributes, long_prefixes))
            return error.InvalidErofs;
        if (output.len == 0) return;
        const references = try self.nodeReferences(node_index, attributes.len);
        @memset(output, 0);
        var shared_count: usize = 0;
        for (references) |reference| if (reference != null) {
            shared_count += 1;
        };
        if (shared_count > max_shared_per_inode) return error.InvalidErofs;
        output[4] = @intCast(shared_count);

        var shared_position: usize = 12;
        var inline_position = try checkedAdd(12, try checkedMul(shared_count, 4));
        for (attributes, references) |attribute, reference| {
            if (reference) |candidate_index| {
                if (candidate_index >= self.candidates.len) return error.InvalidErofs;
                const candidate = self.candidates[candidate_index];
                if (!candidate.profitable(candidate.reference_count))
                    return error.InvalidErofs;
                std.mem.writeInt(
                    u32,
                    output[shared_position..][0..4],
                    candidate.id,
                    .little,
                );
                shared_position += 4;
            } else {
                const entry_size = try xattr.encodedEntrySize(attribute, long_prefixes);
                const entry_end = try checkedAdd(inline_position, entry_size);
                if (entry_end > output.len) return error.InvalidErofs;
                try xattr.writeEntry(
                    output[inline_position..entry_end],
                    attribute,
                    long_prefixes,
                );
                inline_position = entry_end;
            }
        }
        if (shared_position != 12 + shared_count * 4 or inline_position != output.len)
            return error.InvalidErofs;
    }

    pub fn writeRegion(
        self: Plan,
        image: []u8,
        long_prefixes: []const []const u8,
    ) Error!void {
        if (!self.placed or self.region_end > image.len) return error.InvalidErofs;
        var position = self.region_start;
        for (self.candidates) |candidate| {
            if (!candidate.profitable(candidate.reference_count)) continue;
            const end = try checkedAdd(position, candidate.entry_size);
            if (end > self.region_end) return error.InvalidErofs;
            try xattr.writeEntry(
                image[position..end],
                candidate.attribute,
                long_prefixes,
            );
            position = end;
        }
        if (position != self.region_end) return error.InvalidErofs;
    }

    pub fn hasShared(self: Plan) bool {
        for (self.candidates) |candidate|
            if (candidate.profitable(candidate.reference_count)) return true;
        return false;
    }

    fn nodeReferences(self: Plan, node_index: usize, attribute_count: usize) Error![]const ?u32 {
        if (node_index >= self.nodes.len or
            self.nodes[node_index].references.len != attribute_count)
            return error.InvalidErofs;
        return self.nodes[node_index].references;
    }
};

pub fn prepare(
    allocator: std.mem.Allocator,
    nodes: []const tree.Node,
    long_prefixes: []const []const u8,
) Error!Plan {
    _ = try xattr.prefixTableSize(long_prefixes);
    var candidates: std.ArrayList(Candidate) = .empty;
    defer candidates.deinit(allocator);

    const node_plans = try allocator.alloc(NodePlan, nodes.len);
    errdefer allocator.free(node_plans);
    var initialized_nodes: usize = 0;
    errdefer for (node_plans[0..initialized_nodes]) |node|
        allocator.free(node.references);

    for (nodes, 0..) |node, node_index| {
        _ = try xattr.encodedSize(node.xattrs, long_prefixes);
        const references = try allocator.alloc(?u32, node.xattrs.len);
        @memset(references, null);
        node_plans[node_index] = .{ .references = references };
        initialized_nodes += 1;

        for (node.xattrs) |attribute| {
            if (findCandidate(candidates.items, attribute)) |candidate_index| {
                candidates.items[candidate_index].occurrence_count = try checkedAdd(
                    candidates.items[candidate_index].occurrence_count,
                    1,
                );
            } else {
                if (candidates.items.len > std.math.maxInt(u32))
                    return error.InvalidErofs;
                try candidates.append(allocator, .{
                    .attribute = attribute,
                    .entry_size = try xattr.encodedEntrySize(attribute, long_prefixes),
                    .occurrence_count = 1,
                });
            }
        }
    }

    std.mem.sort(Candidate, candidates.items, {}, candidateLessThan);
    while (true) {
        for (candidates.items) |*candidate| candidate.reference_count = 0;
        for (node_plans) |node| @memset(node.references, null);

        for (nodes, node_plans) |node, node_plan| {
            var shared_count: usize = 0;
            for (candidates.items, 0..) |*candidate, candidate_index| {
                if (candidate.disabled or
                    !candidate.profitable(candidate.occurrence_count) or
                    shared_count == max_shared_per_inode)
                    continue;
                const attribute_index = findAttribute(node.xattrs, candidate.attribute) orelse
                    continue;
                node_plan.references[attribute_index] = @intCast(candidate_index);
                candidate.reference_count += 1;
                shared_count += 1;
            }
        }

        var changed = false;
        for (candidates.items) |*candidate| {
            if (candidate.disabled or !candidate.profitable(candidate.occurrence_count))
                continue;
            if (candidate.reference_count != 0 and
                !candidate.profitable(candidate.reference_count))
            {
                candidate.disabled = true;
                changed = true;
            }
        }
        if (!changed) break;
    }

    return .{
        .allocator = allocator,
        .candidates = try candidates.toOwnedSlice(allocator),
        .nodes = node_plans,
    };
}

fn findCandidate(candidates: []const Candidate, attribute: xattr.Attribute) ?usize {
    for (candidates, 0..) |candidate, index|
        if (sameAttribute(candidate.attribute, attribute)) return index;
    return null;
}

fn findAttribute(attributes: []const xattr.Attribute, target: xattr.Attribute) ?usize {
    for (attributes, 0..) |attribute, index|
        if (sameAttribute(attribute, target)) return index;
    return null;
}

fn sameAttribute(left: xattr.Attribute, right: xattr.Attribute) bool {
    return std.mem.eql(u8, left.name, right.name) and
        std.mem.eql(u8, left.value, right.value);
}

fn candidateLessThan(_: void, left: Candidate, right: Candidate) bool {
    const left_savings = left.savings();
    const right_savings = right.savings();
    if (left_savings != right_savings) return left_savings > right_savings;
    const name_order = std.mem.order(u8, left.attribute.name, right.attribute.name);
    if (name_order != .eq) return name_order == .lt;
    return std.mem.order(u8, left.attribute.value, right.attribute.value) == .lt;
}

fn align4(value: usize) Error!usize {
    return (try checkedAdd(value, 3)) & ~@as(usize, 3);
}

fn checkedAdd(left: anytype, right: anytype) Error!usize {
    return std.math.add(usize, @intCast(left), @intCast(right)) catch
        return error.IntegerOverflow;
}

fn checkedMul(left: anytype, right: anytype) Error!usize {
    return std.math.mul(usize, @intCast(left), @intCast(right)) catch
        return error.IntegerOverflow;
}
