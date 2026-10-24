const std = @import("std");

pub const allocator = std.testing.allocator;
pub const small_plain = "bounded one-shot dictionary wrap 0123456789\n" ** 31;
pub const known_plain = "Known-size no-EOS independent liblzma resource contract.\n" ** 7;
pub const large_unit = "dictionary wrap bounded workspace\n";
pub const large_len = 2 * 1024 * 1024;
pub const micro_plain = @embedFile("../../lzms/testdata/lzms-small.txt");

// EOS samples: system Python lzma/liblzma, dictionary=4096, pb=2,
// lc/lp respectively 3/0, 4/0 and 2/2. Python independently decoded all.
// Large sample is exactly 2 MiB of large_unit, truncated at large_len;
// compressed SHA f18225c273d159de763fff378e95e763720b188ff286d022f2eb4d01126db8aa.
// Proper known-size streams: liblzma 5.8.4 LZMA1EXT flags=0 (no EOS),
// independently decoded by Python/liblzma 5.2.5 and xz 5.2.5.
const small_hex =
    "5d00100000ffffffffffffffff00311bcb119b05063cd32c199b494962993f3c92cff5e7c10b736176ff58d228974b1b" ++
    "1f15b316da46d43b568cbf6b1e77f3845dbbc36108b3f7ffff98b60000";
const wide_hex =
    "5e00100000ffffffffffffffff00311bcb11546b1f34461850e545f0aacd628bcc722d4848a02a6216e0ac355d367c12" ++
    "7c1c92c191be050f9de13a25ad24b1d618e95f35ad507b3afffffaa87000";
const lp_hex =
    "6e00100000ffffffffffffffff00311bcaa6e33ab47930eaa5d4d671411eca83e82555463e9c17b4e9d8ac621c464d03" ++
    "1c02a73c3a51399f89ce60aa92d44ef615af6abcd4794b53b9b3fffefdbc00";
const large_hex =
    "5d00100000ffffffffffffffff00321a488e8b077a0dc3a2574451f5b0692c69b80fcce1d15119bfea4b75dbc4edb0e3" ++
    "2e19e65becddaef60e888a3d98ad9b813d7dbea4f3530ff16304745642dfe10825fe8dbce99cf61f6162a507158eaaef" ++
    "a3a54e07520ecdf853f6c4ca90d7ed5773123d01488c2883560b04824e15747bef4da25383b3ec732b272eb7f944b660" ++
    "eda670de4e5e77289a0a98546ed78bca883f5f31fbc84fe8133db7e380ba23a8f8068bd9f57fd60d1b3f7d77ab831421" ++
    "6ed1d57af33e14536276ac59e4e55b0508f9c7daadfcfb522b74cd1e5b2042f9dd533df82964093b80cb2a6cdfb53bf0" ++
    "c4bd2e5faa0f3e4b664290130eff1093f8717859f80bcdff9528460fa9fc7cdefb9a302e56c08f85f38381c065c42553" ++
    "f8f591363105a5b0ee6fc1704d470cd19111aaad601dbaceb127185c5986e9665258bee976ac59e4e55b0508f9c7daad" ++
    "fcfb522b74cd1e5b2042f9dd533df82964093b80cb2a6cdfb53bf0c4bd2e5faa0f3e4b664290130eff1093f8717859f8" ++
    "0bcdff9528460fa9fc7cdefb9a302e56c08f85f38381c065c369e7f467deffffd24e4000";
const known_hex =
    "5d001000008f0100000000000000259b89e7aae77eef2b4678ab26a216c74aff542f278000a3df75abc5b0229d9cd5ea" ++
    "8f6b71021bd3a96e76a325560d865dd5e6e32c33c1c983867dbea90000";
const known_wide_hex =
    "5e001000008f0100000000000000259b89e7aac3642226f3a69772aaf75a997d56ac0b17697902781fdd0dbf00eb3a78" ++
    "10e223024da4875f68851e3574242b5adb71c1ab50d3644d03eeac2cfd0000";

pub fn fromHex(comptime encoded: []const u8) [encoded.len / 2]u8 {
    var bytes: [encoded.len / 2]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, encoded) catch unreachable;
    return bytes;
}
pub fn smallEos() [small_hex.len / 2]u8 {
    return fromHex(small_hex);
}
pub fn wideEos() [wide_hex.len / 2]u8 {
    return fromHex(wide_hex);
}
pub fn lpEos() [lp_hex.len / 2]u8 {
    return fromHex(lp_hex);
}
pub fn largeEos() [large_hex.len / 2]u8 {
    return fromHex(large_hex);
}
pub fn known() [known_hex.len / 2]u8 {
    return fromHex(known_hex);
}
pub fn knownWide() [known_wide_hex.len / 2]u8 {
    return fromHex(known_wide_hex);
}

pub fn micro() [208]u8 {
    const text = @embedFile("../testdata/microlzma-small.bin.b64");
    const base64 = std.base64.standard.decoderWithIgnore(" \r\n\t");
    var bytes: [208]u8 = undefined;
    const len = base64.decode(&bytes, text) catch unreachable;
    std.debug.assert(len == bytes.len);
    return bytes;
}
pub fn zipFromAlone(encoded: []const u8) ![]u8 {
    const bytes = try allocator.alloc(u8, 9 + encoded.len - 13);
    @memcpy(bytes[0..4], &[_]u8{ 9, 4, 5, 0 });
    @memcpy(bytes[4..9], encoded[0..5]);
    @memcpy(bytes[9..], encoded[13..]);
    return bytes;
}
pub fn sentinel(bytes: []const u8) !void {
    for (bytes) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}
pub fn fillLarge(bytes: []u8) void {
    for (bytes, 0..) |*byte, index| byte.* = large_unit[index % large_unit.len];
}
pub fn expectLarge(bytes: []const u8) !void {
    try std.testing.expectEqual(@as(usize, large_len), bytes.len);
    for (bytes, 0..) |byte, index| try std.testing.expectEqual(large_unit[index % large_unit.len], byte);
}
