//! Dictionary identity remains real while its wire ID can be omitted.
pub fn contracts(comptime Z: type) !void {
    try @import("native.zig").contracts(Z);
    try @import("streaming.zig").contracts(Z);
    try @import("consumers.zig").contracts(Z);
    try @import("resources.zig").contracts(Z);
}

pub fn zipContracts(comptime Zip: type, comptime Z: type) !void {
    try @import("zip_archives.zig").contracts(Zip, Z);
}
