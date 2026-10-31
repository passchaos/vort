//! A reference dynamic block whose 64-bit reservoir exposed 32-bit narrowing.
const std = @import("std");
pub fn check(comptime Deflate: type) !void {
    const input = @embedFile("testdata/osdb-zlib6-64k.deflate");
    const storage = try std.testing.allocator.alloc(u8, 65536 + 64);
    defer std.testing.allocator.free(storage);
    @memset(storage, 0xa5);
    const output = storage[32..][0..65536];
    const result = try Deflate.decodeRawAuto(input, output);
    try std.testing.expectEqual(input.len, result.input_read);
    try std.testing.expectEqual(output.len, result.output_written);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(output, &digest, .{});
    const actual = std.fmt.bytesToHex(digest, .lower);
    try std.testing.expectEqualStrings("f8fe629325a07588118ba0b65880a87ded43ef249ccbc91f0e977bbacae0c125", &actual);
    for (storage[0..32]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    for (storage[65536 + 32 ..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}
