const std = @import("std");
const Adler32 = @import("../../../../checksum.zig").Adler32;

/// The word scan already proves whether this accepted batch contains only
/// zeros. Adler's a remains constant and b advances by n*a in that case.
/// n<=4096 and reduced a,b<65521 keep the unreduced expression within u32.
/// Other accepted data uses the mature portable/architecture-specific kernel.
pub inline fn accepted(adler: *Adler32, bytes: []const u8, all_zero: bool) void {
    if (all_zero) {
        std.debug.assert(bytes.len <= 4096);
        adler.b = (adler.b + adler.a * @as(u32, @intCast(bytes.len))) % 65521;
    } else {
        adler.update(bytes);
    }
}
