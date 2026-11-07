pub fn contracts(comptime Z: type) !void {
    try @import("frames.zig").contracts(Z);
    try @import("publication.zig").contracts(Z);
    try @import("aliases.zig").contracts(Z);
    try @import("lifecycle.zig").contracts(Z);
    try @import("memory.zig").contracts(Z);
}
