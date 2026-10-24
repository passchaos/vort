//! Create a real >64 MiB public-input fixture with an indexed far anchor.
const std = @import("std");

fn hash4(bytes: *const [4]u8) u32 {
    return (std.mem.readInt(u32, bytes, .little) *% 0x9e3779b1) >> 16;
}

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const path = args.next() orelse return error.MissingOutput;
    const prefix_len: usize = 64 * 1024 * 1024 + 8;
    const repeat_len: usize = 2048;
    const bytes = try init.gpa.alloc(u8, prefix_len + repeat_len);
    defer init.gpa.free(bytes);
    var random: u64 = 0x1723d8ac96504;
    for (bytes[0..prefix_len]) |*byte| {
        random = random *% 6364136223846793005 +% 1442695040888963407;
        byte.* = 1 + @as(u8, @intCast((random >> 32) % 255));
    }
    bytes[0] = 0;
    const target = hash4(bytes[0..4]);
    var rejected: usize = 0;
    for (4..prefix_len) |end| {
        while (hash4(bytes[end - 3 ..][0..4]) == target) {
            random = random *% 6364136223846793005 +% 1442695040888963407;
            bytes[end] = 1 + @as(u8, @intCast((random >> 32) % 255));
            rejected += 1;
        }
    }
    @memcpy(bytes[prefix_len..], bytes[0..repeat_len]);
    // The controlled hasher also inserts anchors spanning retained history and
    // current input. Protect its three boundary probes, plus the changed last
    // ordinary prefix anchor, without touching the source anchor at zero.
    while (true) {
        var collision = false;
        for (1..5) |back| collision = collision or hash4(bytes[prefix_len - back ..][0..4]) == target;
        if (!collision) break;
        random = random *% 6364136223846793005 +% 1442695040888963407;
        bytes[prefix_len - 1] = 1 + @as(u8, @intCast((random >> 32) % 255));
        rejected += 1;
    }
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = bytes });
    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    try stdout.interface.print("{{\"input_path\":\"{s}\",\"prefix_bytes\":{d},\"repeat_bytes\":{d},\"expected_distance\":{d},\"short_hash_bucket\":{d},\"rejected_collisions\":{d},\"long_sample_first_byte\":0}}\n", .{ path, prefix_len, repeat_len, prefix_len, target, rejected });
    try stdout.interface.flush();
}
