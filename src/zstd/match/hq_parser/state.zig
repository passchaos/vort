const std = @import("std");
const source_mod = @import("../controlled_source.zig");
const rep = @import("rep.zig");
const prices = @import("prices.zig");
const controls = @import("../../encode/controls.zig");

comptime {
    std.debug.assert(@typeInfo(rep.Repeats).array.len == 3);
}

const default_entropy: prices.EntropyModel = .{};
pub const Parameters = struct {
    strategy: controls.Strategy,
    hq_options: controls.HqOptions = .{},
    initial_repeated_offsets: rep.Repeats = rep.initial_repeats,
    entropy: *const prices.EntropyModel = &default_entropy,
    profile: ?*controls.Profile = null,
};

pub const horizon: usize = 4096;
pub const max_beam: usize = 16;
pub const Record = source_mod.Record;
/// Bounded parsing keeps its original compact predecessor coordinates. A
/// whole-block parse can point beyond u16.max within the 128 KiB format block.
pub fn NodeFor(comptime whole: bool) type {
    return struct {
        cost: u64 = std.math.maxInt(u64),
        repeats: rep.Repeats = rep.initial_repeats,
        literal_len: u32 = 0,
        previous_position: if (whole) u32 else u16 = 0,
        previous_slot: u8 = 0,
        match_len: u32 = 0,
        distance: usize = 0,
        offset_value: u32 = 0,
    };
}
pub const Node = NodeFor(false);
pub const WholeNode = NodeFor(true);

/// Owned result storage is included in the parser's requested working budget.
/// Used slices are separate from allocation slices to avoid an unbudgeted
/// shrink-copy on finalization. No allocator or movable-owner pointer is kept.
pub const Plan = struct {
    records: []Record,
    offset_values: []u32,
    final_repeated_offsets: rep.Repeats,
    statistics: prices.Statistics = .{},
    estimated_cost: u64 = 0,
    peak_working_memory: usize = 0,
    passes: u8 = 1,
    used_refinement: bool = false,
    first_pass_cost: u64 = 0,
    refined_first_pass_cost: u64 = 0,
    record_storage: []Record,
    offset_storage: []u32,

    pub fn deinit(self: *const Plan, allocator: std.mem.Allocator) void {
        allocator.free(self.offset_storage);
        allocator.free(self.record_storage);
    }
};

pub fn less(left: anytype, right: @TypeOf(left)) bool {
    if (left.cost != right.cost) return left.cost < right.cost;
    if (left.literal_len != right.literal_len) return left.literal_len < right.literal_len;
    for (left.repeats, right.repeats) |a, b| if (a != b) return a < b;
    if (left.match_len != right.match_len) return left.match_len > right.match_len;
    if (left.offset_value != right.offset_value) return left.offset_value < right.offset_value;
    if (left.distance != right.distance) return left.distance < right.distance;
    if (left.previous_position != right.previous_position) return left.previous_position < right.previous_position;
    return left.previous_slot < right.previous_slot;
}

pub fn insert(row: anytype, candidate: @TypeOf(row[0])) bool {
    var replace = row.len - 1;
    for (row, 0..) |old, slot| {
        // Keep the fixed-format repeat key as three word comparisons.
        if (old.cost != std.math.maxInt(u64) and old.literal_len == candidate.literal_len and
            old.repeats[0] == candidate.repeats[0] and
            old.repeats[1] == candidate.repeats[1] and
            old.repeats[2] == candidate.repeats[2])
        {
            if (!less(candidate, old)) return false;
            replace = slot;
            break;
        }
    }
    if (!less(candidate, row[replace])) return false;
    // Hold the candidate while each preceding node moves right once.
    while (replace > 0 and less(candidate, row[replace - 1])) : (replace -= 1)
        row[replace] = row[replace - 1];
    row[replace] = candidate;
    return true;
}

test "zstd hq state repeat keys preserve reference insertion and ordering" {
    try @import("state_tests.zig").contracts(@This());
}

test "zstd hq state shifts preserve frozen arbitrary rows and aliased candidates" {
    try @import("state_shift_tests.zig").contracts(@This());
}
