//! Once-usage prefix behavior through the public codecs, not binding internals.
pub fn contracts(comptime Z: type) !void {
    try @import("stateless.zig").contracts(Z);
    try @import("reusable.zig").contracts(Z);
    try @import("incremental_decode.zig").contracts(Z);
    try @import("incremental_encode.zig").contracts(Z);
    try @import("failures.zig").contracts(Z);
    try @import("source.zig").contracts(Z);
    try @import("facades.zig").contracts(Z);
    try @import("seekable.zig").contracts(Z);
}
