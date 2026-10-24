const std = @import("std");
const Source = @import("../controlled_source.zig").Source;
const HqOptions = @import("../../encode/hq_options.zig").HqOptions;
const types = @import("types.zig");
const view = @import("view.zig");

pub const Requirements = struct {
    metadata: view.Metadata,
    short_heads: usize,
    long_heads: usize,
    nodes: usize,
    matches: usize,

    pub fn bytes(self: Requirements) !usize {
        return add(try add(try multiply(self.short_heads + self.long_heads, @sizeOf(u32)), try multiply(self.nodes, @sizeOf(types.Node))), try multiply(self.matches, @sizeOf(types.Match)));
    }
};

pub fn requirements(source: Source, options: HqOptions) !Requirements {
    try options.validate();
    const metadata = try view.validate(source);
    return .{
        .metadata = metadata,
        .short_heads = if (metadata.total >= 3) types.hash_size else 0,
        .long_heads = if (metadata.total >= 4) types.hash_size else 0,
        .nodes = if (metadata.total >= 3) @min(metadata.total, source.window_len + 1) else 0,
        .matches = if (source.block.len >= options.min_match) @min(@as(usize, options.search_depth) + 1, source.block.len - options.min_match + 1) else 0,
    };
}

pub fn add(a: usize, b: usize) !usize {
    return std.math.add(usize, a, b) catch error.WorkingMemoryLimitExceeded;
}
pub fn multiply(a: usize, b: usize) !usize {
    return std.math.mul(usize, a, b) catch error.WorkingMemoryLimitExceeded;
}
pub fn check(bytes: usize, maximum: usize) !void {
    if (bytes > maximum) return error.WorkingMemoryLimitExceeded;
}

/// Every growth retains the previous allocation until the replacement exists.
/// This models the exact requested-byte peak for the chosen growth sequence.
pub fn growthPeak(current: [4]usize, required: [4]usize) !usize {
    var resident: usize = 0;
    for (current) |bytes| resident = try add(resident, bytes);
    var peak = resident;
    for (current, required) |old, new| if (new > old) {
        peak = @max(peak, try add(resident, new));
        resident = try add(resident - old, new);
    };
    return peak;
}
