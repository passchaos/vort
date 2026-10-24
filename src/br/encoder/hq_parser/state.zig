const std = @import("std");
const options = @import("../hq_options.zig");
const types = @import("../hq_types.zig");
const command_plan = @import("../command_plan.zig");
const tree = @import("../hq_tree.zig");
const prices = @import("prices.zig");
pub const Budget = @import("../../../io/working_allocator.zig").WorkingAllocator;
pub const horizon: usize = 4096;
pub fn horizonFor(input_len: usize, parse_mode: anytype) usize {
    return if (parse_mode == .whole_block) input_len else @min(horizon, input_len);
}

pub const default_resolved: options.Resolved = .{ .quality = 10, .search_depth = 64, .nice_len = 128, .beam_width = 8, .iterations = 1, .max_working_memory = std.math.maxInt(usize), .block_len = 256 * 1024, .distance_parameters = @import("../distance.zig").Parameters.init(0, 0) };
pub const Parameters = struct {
    resolved: options.Resolved = default_resolved,
    profile: ?*options.HqProfile = null,
    initial_recent_distances: ?[4]usize = null,
    previous: [2]u8 = .{ 0, 0 },
    matcher: ?*tree.Matcher = null,
    /// The supplied allocator must be this budget's allocator. Dictionary
    /// providers share it so indices, frontiers and all live plans are charged.
    /// Borrowed matchers and dynamic model tables must already be charged here.
    budget: ?*Budget = null,

    pub fn init(raw: options.HqOptions, quality: u8, mode: anytype) !Parameters {
        return .{ .resolved = try raw.resolve(quality, mode), .profile = raw.profile };
    }
    pub fn initWithFormat(raw: options.HqOptions, quality: u8, mode: anytype, format: @import("../distance.zig").Format) !Parameters {
        return .{ .resolved = try raw.resolveForFormat(quality, mode, format), .profile = raw.profile };
    }
};

pub const Node = struct {
    cost: u64 = std.math.maxInt(u64),
    recent: [4]usize = types.initial_recent,
    pending_insert: usize = 0,
    previous_position: u32 = 0,
    previous_slot: u8 = 0,
    copy_len: usize = 0,
    output_len: usize = 0,
    physical_distance: usize = 0,
    dictionary_address: usize = 0,
    source: command_plan.Source = .lz77,
    encoding: types.ExactEncoding = .{ .command_symbol = 0 },
};
pub const Spill = struct {
    node: Node = .{},
    end_position: usize = 0,
    continuation_cost: u64 = std.math.maxInt(u64),
};
pub const MatchMemo = struct { distance: usize, length: usize };

pub const Plan = struct {
    commands: []command_plan.Command,
    /// Exact allocation returned by the builder at successful finalization.
    /// Before transfer, commands is only a view and this owner remains empty.
    command_storage: []command_plan.Command,
    distance_parameters: @import("../distance.zig").Parameters,
    format: @import("../distance.zig").Format = .standard,
    final_recent_distances: [4]usize,
    final_previous: [2]u8,
    pending_insert: usize = 0,
    consumed: usize = 0,
    statistics: prices.Statistics,
    estimated_cost: u64 = 0,
    peak_working_memory: usize = 0,

    pub fn deinit(self: *const Plan, allocator: std.mem.Allocator) void {
        allocator.free(self.command_storage);
    }
};

pub fn less(left: Node, right: Node) bool {
    if (left.cost != right.cost) return left.cost < right.cost;
    if (left.pending_insert != right.pending_insert) return left.pending_insert < right.pending_insert;
    for (left.recent, right.recent) |a, b| if (a != b) return a < b;
    if (left.output_len != right.output_len) return left.output_len > right.output_len;
    if (left.encoding.command_symbol != right.encoding.command_symbol) return left.encoding.command_symbol < right.encoding.command_symbol;
    if (left.encoding.distance_code != right.encoding.distance_code) return left.encoding.distance_code < right.encoding.distance_code;
    if (left.physical_distance != right.physical_distance) return left.physical_distance < right.physical_distance;
    if (left.dictionary_address != right.dictionary_address) return left.dictionary_address < right.dictionary_address;
    if (left.previous_position != right.previous_position) return left.previous_position < right.previous_position;
    return left.previous_slot < right.previous_slot;
}
pub fn insert(row: []Node, candidate: Node) void {
    var replace = row.len - 1;
    for (row, 0..) |previous, slot| {
        if (previous.cost != std.math.maxInt(u64) and previous.pending_insert == candidate.pending_insert and std.mem.eql(usize, &previous.recent, &candidate.recent)) {
            if (!less(candidate, previous)) return;
            replace = slot;
            break;
        }
    }
    if (!less(candidate, row[replace])) return;
    row[replace] = candidate;
    while (replace > 0 and less(row[replace], row[replace - 1])) : (replace -= 1)
        std.mem.swap(Node, &row[replace], &row[replace - 1]);
}
