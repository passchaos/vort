//! Whole-operation requested-heap contracts through public Zstd decode APIs.
pub fn contracts(comptime Z: type) !void {
    try @import("publication.zig").contracts(Z);
    try @import("reusable.zig").contracts(Z);
    try @import("dictionaries.zig").contracts(Z);
    try @import("legacy.zig").contracts(Z);
    try @import("inheritance.zig").contracts(Z);
    try @import("failures.zig").contracts(Z);
}

test {
    _ = @import("helpers.zig");
}
