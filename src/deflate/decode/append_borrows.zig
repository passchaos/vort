//! Growable output must consume aliased read borrows before allocation or
//! append can relocate/overwrite them. All staging uses the caller allocator.
const std = @import("std");
const alias = @import("../decoder/output_alias.zig");

pub fn needsStaging(out: *const std.ArrayList(u8), input: []const u8, dictionary: []const u8) bool {
    const allocation = out.allocatedSlice();
    const descriptor = std.mem.asBytes(out);
    return alias.overlaps(input, allocation) or
        alias.overlaps(dictionary, allocation) or
        alias.overlaps(input, descriptor) or
        alias.overlaps(dictionary, descriptor);
}

/// Takes ownership even if output growth fails.
pub fn publishOwned(allocator: std.mem.Allocator, out: *std.ArrayList(u8), decoded: []u8) !usize {
    defer allocator.free(decoded);
    try out.appendSlice(allocator, decoded);
    return decoded.len;
}
