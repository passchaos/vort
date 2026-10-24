const std = @import("std");

/// State shared by the RAR15 and RAR20 decoders in one legacy solid chain.
/// Distances are stored newest-first, matching the logical view of unrar's
/// circular `OldDist` array.
pub const CommonState = struct {
    recent_distances: [4]usize = @splat(std.math.maxInt(usize)),
    last_distance: usize = std.math.maxInt(usize),
    last_length: usize = 0,
};
