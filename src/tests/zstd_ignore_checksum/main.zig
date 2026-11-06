//! Public contracts: ignoring the content checksum changes comparison only.
pub fn contracts(comptime Z: type) !void {
    try @import("publication.zig").contracts(Z);
    try @import("reusable.zig").contracts(Z);
    try @import("dictionaries.zig").contracts(Z);
    try @import("incremental.zig").contracts(Z);
}
