const std = @import("std");
const Source = @import("../hq_types.zig").Source;
const types = @import("types.zig");
const view = @import("view.zig");
pub const Need = struct { metadata: view.Metadata, heads2: usize, heads3: usize, heads4: usize, nodes: usize, candidates: usize };

pub fn need(source: Source, search: types.Search) !Need {
    const metadata = try view.validate(source);
    const active = @min(metadata.total_len, try add(metadata.window_len, 1));
    var nodes: usize = if (active >= 2) 1 else 0;
    while (nodes != 0 and nodes < active) nodes = try multiply(nodes, 2);
    return .{ .metadata = metadata, .heads2 = if (metadata.total_len >= 2) types.hash_size else 0, .heads3 = if (metadata.total_len >= 3) types.hash_size else 0, .heads4 = if (metadata.total_len >= 4) types.hash_size else 0, .nodes = nodes, .candidates = if (metadata.input_len >= 2) @min(metadata.input_len - 1, @as(usize, search.search_depth) * 2 + 1) else 0 };
}
pub fn sizes(needed: Need) ![5]usize {
    return .{ try multiply(needed.heads2, 4), try multiply(needed.heads3, 4), try multiply(needed.heads4, 4), try multiply(needed.nodes, @sizeOf(types.Node)), try multiply(needed.candidates, @sizeOf(types.Match)) };
}
pub fn cold(needed: Need) !usize {
    var bytes: usize = 0;
    for (try sizes(needed)) |n| bytes = try add(bytes, n);
    return bytes;
}
pub fn growth(current: [5]usize, required: [5]usize) !usize {
    var resident: usize = 0;
    for (current) |n| resident = try add(resident, n);
    var peak = resident;
    for (current, required) |old, new| if (new > old) {
        peak = @max(peak, try add(resident, new));
        resident = try add(resident - old, new);
    };
    return peak;
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
