const std = @import("std");
const small = @import("small");
pub fn main() void {
    var frequencies: [34]u32 = undefined;
    frequencies[0] = 1;
    frequencies[1] = 1;
    for (2..34) |i| frequencies[i] = frequencies[i-1] + frequencies[i-2];
    std.mem.sort(u32, &frequencies, {}, std.sort.desc(u32));
    var lengths: [64]u4 = @splat(15);
    const success = small.build(64, &frequencies, &lengths);
    std.debug.print("natural_depth_33_success={any}\n", .{success});
}
