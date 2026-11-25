const std = @import("std");
const vort = @import("vort");

pub fn hexToOwnedBytes(allocator: std.mem.Allocator, hex: []const u8) ![]u8 {
    if ((hex.len & 1) != 0) return error.InvalidHexInput;
    const bytes = try allocator.alloc(u8, hex.len / 2);
    errdefer allocator.free(bytes);
    var i: usize = 0;
    while (i < bytes.len) : (i += 1) {
        bytes[i] = try std.fmt.parseInt(u8, hex[i * 2 .. i * 2 + 2], 16);
    }
    return bytes;
}

pub fn printDecoded(stdout: *std.Io.Writer, label: []const u8, compressed_len: usize, decoded: []const u8) !void {
    try stdout.print("{s}_compressed_bytes={d} decoded_bytes={d} crc32={d} text={s}\n", .{
        label,
        compressed_len,
        decoded.len,
        vort.crc32(decoded),
        decoded,
    });
}
