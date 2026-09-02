//! Sequence-state retention policy at compressed-block boundaries.
//!
//! Zstandard Repeat_Mode may consume entropy tables and repeat offsets only in
//! a later block of the same frame. Keeping this decision explicit prevents
//! terminal blocks from materializing the comparatively large FSE table state
//! while preserving the state transition whenever a successor block exists.

pub const Context = enum {
    terminal,
    followed_by_block,

    pub fn retainsState(self: Context) bool {
        return self == .followed_by_block;
    }
};

pub fn forLastBlock(last: bool) Context {
    return if (last) .terminal else .followed_by_block;
}

test "terminal sequence blocks do not retain continuation state" {
    try @import("std").testing.expect(!forLastBlock(true).retainsState());
    try @import("std").testing.expect(forLastBlock(false).retainsState());
}
