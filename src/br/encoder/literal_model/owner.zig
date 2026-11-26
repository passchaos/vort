//! Append-only stable literal models. Keep this owner at its final address
//! while any model is borrowed; input and command storage must stay immutable.
const std = @import("std");
const prepared = @import("../prepared_literal.zig");
const command_plan = @import("../command_plan.zig");
const context = @import("../literal_context_split.zig");
const bit_count = @import("../../../io/bit_count.zig");
const budget = @import("../total_budget.zig");
const model = @import("model.zig");

pub const Model = model.Model;
pub const Error = @import("../../../core.zig").Error || budget.Error;
pub const capacity = 5;
pub const memory_limit: usize = 256 * 1024;
pub const tree_bytes = @sizeOf(model.Alphabet) + @sizeOf([256]u4);
pub const Counters = struct {
    hits: usize = 0,
    misses: usize = 0,
    builds: usize = 0,
    capacity_misses: usize = 0,
    memory_misses: usize = 0,
    captured_trees: usize = 0,
};

pub const Owner = struct {
    input: []const u8,
    commands: []const command_plan.Command,
    slots: [capacity]Model = undefined,
    len: usize = 0,
    active_tree_count: usize = 0,
    counters: Counters = .{},

    pub fn init(input: []const u8, commands: []const command_plan.Command) Owner {
        return .{ .input = input, .commands = commands };
    }

    pub fn matchesGroup(self: *const Owner, input: []const u8, commands: []const command_plan.Command) bool {
        return self.input.ptr == input.ptr and self.input.len == input.len and
            self.commands.ptr == commands.ptr and self.commands.len == commands.len;
    }

    pub fn lookup(self: *Owner, input: []const u8, commands: []const command_plan.Command, options: anytype) ?*const Model {
        if (self.matchesGroup(input, commands) and supported(options)) {
            for (self.slots[0..self.len]) |*slot| {
                if (slot.key.matches(input, options)) {
                    self.counters.hits += 1;
                    return slot;
                }
            }
        }
        self.counters.misses += 1;
        return null;
    }

    pub fn capture(self: *Owner, allocator: std.mem.Allocator, input: []const u8, commands: []const command_plan.Command, options: anytype, normalized_context: ?context.Candidate, alphabets: []const model.Alphabet, lengths: []const [256]u4, literal_count: usize, pure_literal_bits: bit_count.BitCount) Error!?*const Model {
        if (!self.matchesGroup(input, commands) or !supported(options)) return null;
        for (self.slots[0..self.len]) |*slot| {
            if (slot.key.matches(input, options)) {
                self.counters.hits += 1;
                return slot;
            }
        }
        if (self.len == capacity) {
            self.counters.capacity_misses += 1;
            return null;
        }
        if (alphabets.len == 0 or alphabets.len > model.max_trees or alphabets.len != lengths.len) return error.InvalidBlockPlan;
        const trees = std.math.add(usize, self.active_tree_count, alphabets.len) catch return error.IntegerOverflow;
        if (try requestedBytesForTrees(trees) > memory_limit) {
            self.counters.memory_misses += 1;
            return null;
        }
        for (alphabets) |*alphabet| if (alphabet.len == 0 or alphabet.len > alphabet.symbols.len) return error.InvalidBlockPlan;
        if (normalized_context) |candidate| {
            if (candidate.tree_count != alphabets.len) return error.InvalidBlockPlan;
            for (candidate.context_map) |tree| if (tree >= candidate.tree_count) return error.InvalidBlockPlan;
        } else if (alphabets.len != 1) return error.InvalidBlockPlan;

        const owned_alphabets = try allocate(model.Alphabet, allocator, alphabets.len);
        errdefer allocator.free(owned_alphabets);
        const owned_lengths = try allocate([256]u4, allocator, lengths.len);
        errdefer allocator.free(owned_lengths);
        for (owned_alphabets, alphabets) |*destination, *source| {
            destination.len = source.len;
            @memcpy(destination.symbols[0..source.len], source.symbols[0..source.len]);
        }
        @memcpy(owned_lengths, lengths);
        const slot = &self.slots[self.len];
        slot.* = .{
            .alphabets = owned_alphabets,
            .lengths = owned_lengths,
            .key = prepared.Key.init(input, options),
            .normalized_context = normalized_context,
            .literal_count = literal_count,
            .literal_payload_bits = pure_literal_bits,
        };
        self.len += 1;
        self.active_tree_count = trees;
        self.counters.builds += 1;
        self.counters.captured_trees = trees;
        return slot;
    }

    pub fn requestedBytes(self: *const Owner) Error!usize {
        return requestedBytesForTrees(self.active_tree_count);
    }

    pub fn deinit(self: *Owner, allocator: std.mem.Allocator) void {
        for (self.slots[0..self.len]) |*slot| slot.deinit(allocator);
        self.len = 0;
        self.active_tree_count = 0;
        self.counters = .{};
    }

    /// Reset invalidates every previously borrowed model, including when caller
    /// storage is reused at the same input and command addresses.
    pub fn reset(self: *Owner, allocator: std.mem.Allocator, input: []const u8, commands: []const command_plan.Command) void {
        self.deinit(allocator);
        self.* = init(input, commands);
    }
};

pub fn requestedBytesForTrees(trees: usize) Error!usize {
    const payload = std.math.mul(usize, tree_bytes, trees) catch return error.IntegerOverflow;
    return std.math.add(usize, @sizeOf(Owner), payload) catch error.IntegerOverflow;
}

pub fn supported(options: anytype) bool {
    if (@hasField(@TypeOf(options), "hq_model_output")) {
        if (options.hq_model_output != null) return false;
    }
    return prepared.supported(options) and !options.large_window and
        options.literal_split == null and options.adaptive_literal_split == null and options.literal_entropy_plan == null;
}

fn allocate(comptime T: type, allocator: std.mem.Allocator, count: usize) Error![]T {
    return allocator.alloc(T, count) catch |err| {
        var lease = (try budget.Lease.fromAllocator(allocator)) orelse return err;
        defer lease.deinit();
        return lease.translateError(err);
    };
}
