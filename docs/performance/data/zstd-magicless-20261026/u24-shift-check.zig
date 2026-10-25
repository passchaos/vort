const std = @import("std");
noinline fn check(length: usize, last: bool) void {
    const value: u24 = @intCast((length << 3) | @intFromBool(last));
    var bytes: [3]u8 = undefined;
    std.mem.writeInt(u24, &bytes, value, .little);
    std.debug.print("length={d} last={any} value={x} bytes={x}\n", .{ length, last, value, bytes });
}
pub fn main() void {
    check(131072, false);
    check(3, true);
}
