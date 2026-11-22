const shapes = @import("tests/shapes.zig");
const one_shot = @import("tests/one_shot.zig");
const incremental = @import("tests/incremental.zig");
const deflate64 = @import("tests/deflate64.zig");
pub fn contracts(comptime D: type) !void {
    try shapes.contracts();
    try one_shot.contracts(D);
    try incremental.contracts(D);
    try deflate64.contracts();
}
