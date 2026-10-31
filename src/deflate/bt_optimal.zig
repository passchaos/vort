//! DEFLATE-only prepared covered binary-tree parser. This owner shares
//! immutable matches between fixed and modeled reverse suffix cost solves.
//! Per-distance prices must be constant inside each RFC1951 distance symbol;
//! arbitrary per-distance models continue to use generic lz77.PreparedOptimal.
pub const Prepared = @import("bt_optimal/owner.zig").Prepared;
pub const Tree = @import("bt_optimal/matcher.zig").Tree;
pub const min_input_len = @import("bt_optimal/matcher.zig").min_input_len;
pub const max_input_len = @import("bt_optimal/matcher.zig").max_input_len;
pub const coverage_threshold = @import("bt_optimal/matcher.zig").coverage_threshold;
pub const empty = @import("bt_optimal/matcher.zig").empty;
pub const hash_size = @import("bt_optimal/matcher.zig").hash_size;
pub const class_ends = @import("bt_optimal/matcher.zig").class_ends;
pub const distanceClass = @import("bt_optimal/matcher.zig").distanceClass;
pub const hashAt = @import("bt_optimal/matcher.zig").hashAt;
pub const extendPortable = @import("bt_optimal/matcher.zig").extendPortable;
pub const Record = @import("bt_optimal/evidence.zig").Record;
pub const pack = @import("bt_optimal/evidence.zig").pack;
pub const unpack = @import("bt_optimal/evidence.zig").unpack;

test {
    _ = @import("bt_optimal/tests.zig");
    _ = @import("bt_optimal/ownership_tests.zig");
    _ = @import("bt_optimal/layout_tests.zig");
}
