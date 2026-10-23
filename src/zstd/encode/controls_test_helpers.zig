const std = @import("std");
const zstd = @import("../../zstd.zig");
pub const allocator = std.testing.allocator;

// Captured from the committed 2cd7e82c Zig implementation before controls were
// added. All legacy levels 0...22 were encoded independently in that snapshot.
// Level 0's exact frame is the recorded 10-byte raw prefix plus legacyInput().
// Level 1 SHA-256: 8df2130afe5428f59ea609ed5f183fe57c97e075a7e5936c753be8c94c307e25.
// Levels 2...22 SHA-256: 95d99e0eb74cf9c608a97c7e0e597aca6b948269fce02e3d0852effe88e8dd0e.
const level_one_hex =
    "28b52ffd60000f553c005474d3a6017f07aa82954e21566a20671bdb058723240fad72bce093ec62da6d69656e636f646520636f6e74726f" ++
    "6c73207265706561746564206b6579c970d2cdde6eac0906c52f0f22e9b47e7ff889455f45f44d6362282c8efe7c41bb285605a7cea16dfe" ++
    "8fc5ab012868a8b32383ffb38882631bb07ea31491d7caf9069b033cc2698fb67ecbe2167d84e964530cbdbd0e90d8563e5ff1455da2b835" ++
    "e8b8e2f4c8a947f3c682f5253f917be351cfd3a725f9ade21e15fe2b0d77178fb476b0c8386a999540e1cb034a67e346e98bcbe8b6fc5b52" ++
    "3af3afc01fff305df3875caf834cc4355862f46636703860a8337001e7916f3dc7b28be764f16236b3a3fcca44f4c2fdcc6a01ad4cc0b189" ++
    "c6bfe3dc9300ebcaa6d8270c1333e975fb9ab066ac7cfeee3ed444842daa9971d1392a60ceb79fa5b70ee5319afb124829685062a7f212e5" ++
    "eef5f889158c219e915bd40f1bba0d61768615ad6b18c37f2536b752189b695d8308166b420c93a9900bd6857b4c1217290aad9d48c87602" ++
    "2886d28d6e70df195e39af82154221225729f787ae6e37caa7dee19f03a3a8b70157a803ef436038f211ab85e498b22367d5b532c0745e1a" ++
    "4cc08dc0a7fdd83bcf6932f3eb666b436da4760ac22fbdcbcecadb40cdfa928b799ac75d705934a81ec2979117541eb3e4093e0c38ad1665" ++
    "b47c73933c378470ee38fbab934b8ad6a748ec553bba020c521695fc8e42d6283271b86ae39e9d21a42116d1fa259224340a2dcf20306a6a" ++
    "13f4456e6d99bfb6ccc7a0c648e78ec10359ab793e0f88b6d04c4c1aff854f452aada018c273194c722e0fa8827fb190d3f4afc7fd1ebc84" ++
    "6ff5f74c93795aaed61f3bf20b3e10d7e4666524c65993b86bf3cc35b18aac26cc14f6beb7c26c90f530f7e8f0549aa691bdd7cbeaed8605" ++
    "f6bd4ef0ce252df6eedbd1d24999a8445208e87980a6ba61cc5e4656994cc84771028d8c5c9a8bf9f13bdc14a3c5494a3252d58048ae6fa0" ++
    "95e7530a0c9abf18ffabf7fd4a73c8c3bcaf083880a1b3ee2c40afc2a8675c773fbe2b6fd5a28017d08690134b0580d9ccbebc9e200362a4" ++
    "c60699e55f45c7772743d753d6c1035b7112d9d1ec356d92abceedc5373306dbb120d910f1bf67bd4428b330367b645b5c802f08bfb67c81" ++
    "0747b179e321e43851993cfd2a1d121e8d87d645381ae26b2363b374f4943e9e1eff4c0cbedc1d348b78beef726ac871a68f7f7145c17b39" ++
    "db9e60e7478d94dd93e15e8e8d54b98b3b6d1c5f49dd3b07b8b7f58741a9e9fe9140d6d59e7043f5bdef1d25392048f497934dd5bc659d4b" ++
    "a9f81f528ccdfb603f8bd7ad8d6bf5933287c60e6b701d3af75b8770e12e122e83d0036f4ee295b836df3cfcc1a8900521af6541e65ab814" ++
    "15516c19c1ca08f07e0be5872ea48df41638344e3bc67f2861b5168d4c4cb0d55931b38b952c5dd05ad307462c970ca8be105c4b57035fd9" ++
    "c6297eef370d9f80816c651dbbf1168c3c3e6a503d99a901d1acd69ef036d442b592bdcd2073e479e74d113167532e8ae941cf949bb0cfc9" ++
    "267ba5e6cc1ac4dfc6903576177ba40d21984e9c8f248ef36c03f6a5798e24461665d3da51b6d39cf4d0db8a9ff7724144c2572f9f8827e8" ++
    "8f6db043aab2c9eb0efed56108ebed23333b5f17d7a7f7f89a3e995dd1849e4508e2b24f992e13fd5f407ba5dae91ff765c6703d35b19eb5" ++
    "5cde10affee0394a681d8cfdc1776fc7c33f874793d915391b79d91ba010d09a140d30c8aef38861f12994eed96b63efebbbc67448b94ac6" ++
    "11c31f02b549add2f72ac498c5159ec432322929299c4079a8ceb62b544a9b5f7b4120005ed93151b49fd1123a2abf912201301fdc0206d0" ++
    "e0e947933b9bbd2b0348fc83f4b43669e00d9db3b330484b264eb8b2773e99efbdfb48019d17e388afd9eb2d8d1a1dea82e5940a044c2c2f" ++
    "390cd8433ab0e421a2af9ee4f0e91801995efb88d21c943d70a29d5b77466b3b175c7a2b40208d2f1bb1d185f593b707788780fb5b99b0ef" ++
    "042cc3b1ed9b704f1be5c3a337620414af318d7407f4dbebd25ba400483dd3376b49a6d8299662d0008b51c85db1a330687ea4a8224998e2" ++
    "693499a0cbfb76cdb82567184e3501ca47550ae8e7452e1ef68ec6ff1c44249438d1134b83948fb48b5ad3b36aeb4300be39df930d865550" ++
    "7d7c720d60009cb5a171a043d1ac35599bee27de5bce1d571e9273c6ba60e14fb113dcf009b5eefe6fe76b4322b045e89885ec86d8846f0d" ++
    "ec2b515dfc0ccab5bff72ee2f70013dd4eb7e2b4afec18fae7612042a00dab1348e17ef4603e4465a2aefbf8eba209e0f02e1aa21b174ccc" ++
    "1bab4bd2002e6177f5d8a66af5b7c1f4fae5f7dc9572b938cae5a78c454775eae775177fccbc425ef288eece8feb370b8e3b1854dc50ae7a" ++
    "4e28f04636eb265df99c799240f767b69249f8576e2f0113399dd35d929e15d5de033f2677a04ac83be8219aeb890c918a95b0e23132b5b2" ++
    "5b883dd5ae680639b86071c97d21bdddc27f24946079bd9f2eef4558360e3841449dd4240d9bf68f75e8ea5ebbeeeb6fa7c78bcf0162a7cc" ++
    "522ba140fc2741f37e0db3a78646ad17e081af7fbd8f7b64201fa850e2ff15c1f003a073531e10feffd1caff1cf90111b0ff802800a1a20a" ++
    "d2c6ebbcfffc9f7b1f0081f80f40b1505414148be262a1585c148b8ba262011140a29f02";
const level_two_plus_hex =
    "28b52ffd60000f453c003474d3a6017f07aa82954e21566a20671bdb058723240fad72bce093ec62da6d69656e636f646520636f6e74726f" ++
    "6c73207265706561746564206b6579c970d2cdde6eac0906c52f0f22e9b47e7ff889455f45f44d6362282c8efe7c41bb285605a7cea16dfe" ++
    "8fc5ab012868a8b32383ffb38882631bb07ea31491d7caf9069b033cc2698fb67ecbe2167d84e964530cbdbd0e90d8563e5ff1455da2b835" ++
    "e8b8e2f4c8a947f3c682f5253f917be351cfd3a725f9ade21e15fe2b0d77178fb476b0c8386a999540e1cb034a67e346e98bcbe8b6fc5b52" ++
    "3af3afc01fff305df3875caf834cc4355862f46636703860a8337001e7916f3dc7b28be764f16236b3a3fcca44f4c2fdcc6a01ad4cc0b189" ++
    "c6bfe3dc9300ebcaa6d8270c1333e975fb9ab066ac7cfeee3ed444842daa9971d1392a60ceb79fa5b70ee5319afb124829685062a7f212e5" ++
    "eef5f889158c219e915bd40f1bba0d61768615ad6b18c37f2536b752189b695d8308166b420c93a9900bd6857b4c1217290aad9d48c87602" ++
    "2886d28d6e70df195e39af82154221225729f787ae6e37caa7dee19f03a3a8b70157a803ef436038f211ab85e498b22367d5b532c0745e1a" ++
    "4cc08dc0a7fdd83bcf6932f3eb666b436da4760ac22fbdcbcecadb40cdfa928b799ac75d705934a81ec2979117541eb3e4093e0c38ad1665" ++
    "b47c73933c378470ee38fbab934b8ad6a748ec553bba020c521695fc8e42d6283271b86ae39e9d21a42116d1fa259224340a2dcf20306a6a" ++
    "13f4456e6d99bfb6ccc7a0c648e78ec10359ab793e0f88b6d04c4c1aff854f452aada018c273194c722e0fa8827fb190d3f4afc7fd1ebc84" ++
    "6ff5f74c93795aaed61f3bf20b3e10d7e4666524c65993b86bf3cc35b18aac26cc14f6beb7c26c90f530f7e8f0549aa691bdd7cbeaed8605" ++
    "f6bd4ef0ce252df6eedbd1d24999a8445208e87980a6ba61cc5e4656994cc84771028d8c5c9a8bf9f13bdc14a3c5494a3252d58048ae6fa0" ++
    "95e7530a0c9abf18ffabf7fd4a73c8c3bcaf083880a1b3ee2c40afc2a8675c773fbe2b6fd5a28017d08690134b0580d9ccbebc9e200362a4" ++
    "c60699e55f45c7772743d753d6c1035b7112d9d1ec356d92abceedc5373306dbb120d910f1bf67bd4428b330367b645b5c802f08bfb67c81" ++
    "0747b179e321e43851993cfd2a1d121e8d87d645381ae26b2363b374f4943e9e1eff4c0cbedc1d348b78beef726ac871a68f7f7145c17b39" ++
    "db9e60e7478d94dd93e15e8e8d54b98b3b6d1c5f49dd3b07b8b7f58741a9e9fe9140d6d59e7043f5bdef1d25392048f497934dd5bc659d4b" ++
    "a9f81f528ccdfb603f8bd7ad8d6bf5933287c60e6b701d3af75b8770e12e122e83d0036f4ee295b836df3cfcc1a8900521af6541e65ab814" ++
    "15516c19c1ca08f07e0be5872ea48df41638344e3bc67f2861b5168d4c4cb0d55931b38b952c5dd05ad307462c970ca8be105c4b57035fd9" ++
    "c6297eef370d9f80816c651dbbf1168c3c3e6a503d99a901d1acd69ef036d442b592bdcd2073e479e74d113167532e8ae941cf949bb0cfc9" ++
    "267ba5e6cc1ac4dfc6903576177ba40d21984e9c8f248ef36c03f6a5798e24461665d3da51b6d39cf4d0db8a9ff7724144c2572f9f8827e8" ++
    "8f6db043aab2c9eb0efed56108ebed23333b5f17d7a7f7f89a3e995dd1849e4508e2b24f992e13fd5f407ba5dae91ff765c6703d35b19eb5" ++
    "5cde10affee0394a681d8cfdc1776fc7c33f874793d915391b79d91ba010d09a140d30c8aef38861f12994eed96b63efebbbc67448b94ac6" ++
    "11c31f02b549add2f72ac498c5159ec432322929299c4079a8ceb62b544a9b5f7b4120005ed93151b49fd1123a2abf912201301fdc0206d0" ++
    "e0e947933b9bbd2b0348fc83f4b43669e00d9db3b330484b264eb8b2773e99efbdfb48019d17e388afd9eb2d8d1a1dea82e5940a044c2c2f" ++
    "390cd8433ab0e421a2af9ee4f0e91801995efb88d21c943d70a29d5b77466b3b175c7a2b40208d2f1bb1d185f593b707788780fb5b99b0ef" ++
    "042cc3b1ed9b704f1be5c3a337620414af318d7407f4dbebd25ba400483dd3376b49a6d8299662d0008b51c85db1a330687ea4a8224998e2" ++
    "693499a0cbfb76cdb82567184e3501ca47550ae8e7452e1ef68ec6ff1c44249438d1134b83948fb48b5ad3b36aeb4300be39df930d865550" ++
    "7d7c720d60009cb5a171a043d1ac35599bee27de5bce1d571e9273c6ba60e14fb113dcf009b5eefe6fe76b4322b045e89885ec86d8846f0d" ++
    "ec2b515dfc0ccab5bff72ee2f70013dd4eb7e2b4afec18fae7612042a00dab1348e17ef4603e4465a2aefbf8eba209e0f02e1aa21b174ccc" ++
    "1bab4bd2002e6177f5d8a66af5b7c1f4fae5f7dc9572b938cae5a78c454775eae775177fccbc425ef288eece8feb370b8e3b1854dc50ae7a" ++
    "4e28f04636eb265df99c799240f767b69249f8576e2f0113399dd35d929e15d5de033f2677a04ac83be8219aeb890c918a95b0e23132b5b2" ++
    "5b883dd5ae680639b86071c97d21bdddc27f24946079bd9f2eef4558360e3841449dd4240d9bf68f75e8ea5ebbeeeb6fa7c78bcf0162a7cc" ++
    "522ba140fc2741f37e0db3a78646ad17e081af7fbd8f7b1fa850e2ff15c1f003a073531e10feffd1caff1cfb011190ff802800a1a20ad2c6" ++
    "ebbcfbfc9ffb1f0081f80f40b1505414148be262a1585c148b8ba262011140a29f02";

pub fn fromHex(comptime text: []const u8) [text.len / 2]u8 {
    var bytes: [text.len / 2]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, text) catch unreachable;
    return bytes;
}
pub fn legacyInput() [4096]u8 {
    var input: [4096]u8 = undefined;
    fillRandom(&input, 0x19a4beef);
    for (0..38) |i| {
        const start = 31 + i * 97;
        @memcpy(input[start..][0.."encode controls repeated key".len], "encode controls repeated key");
    }
    @memcpy(input[2048..3072], input[0..1024]);
    @memcpy(input[3584..4096], input[1024..1536]);
    return input;
}
pub fn expectLegacy(level: c_int, frame: []const u8) !void {
    const input = legacyInput();
    if (level == 0) {
        const prefix = [_]u8{ 0x28, 0xb5, 0x2f, 0xfd, 0x60, 0x00, 0x0f, 0x01, 0x80, 0x00 };
        try std.testing.expectEqual(@as(usize, prefix.len + input.len), frame.len);
        try std.testing.expectEqualSlices(u8, &prefix, frame[0..prefix.len]);
        try std.testing.expectEqualSlices(u8, &input, frame[prefix.len..]);
    } else if (level == 1) {
        const expected = fromHex(level_one_hex);
        try std.testing.expectEqualSlices(u8, &expected, frame);
    } else {
        const expected = fromHex(level_two_plus_hex);
        try std.testing.expectEqualSlices(u8, &expected, frame);
    }
}
pub fn fillRandom(bytes: []u8, seed: u32) void {
    var state = seed;
    for (bytes) |*byte| {
        state = state *% 1664525 +% 1013904223;
        byte.* = @truncate(state >> 24);
    }
}
pub fn dictionary() [96 * 1024]u8 {
    var bytes: [96 * 1024]u8 = @splat(0xff);
    fillRandom(bytes[0..1024], 0x705e42d1);
    return bytes;
}
pub fn crossBlock() [8192]u8 {
    var bytes: [8192]u8 = undefined;
    fillRandom(bytes[0..4096], 0x618239ed);
    @memcpy(bytes[4096..], bytes[0..4096]);
    return bytes;
}
pub fn lazyTrap() [512]u8 {
    var bytes: [512]u8 = undefined;
    fillRandom(&bytes, 0x14b870ad);
    const short = "ABCD#";
    const long = "BCD0123456789abcdefghijklmnopqrstuv";
    const probe = "ABCD0123456789abcdefghijklmnopqrstuv";
    @memcpy(bytes[16..][0..short.len], short);
    @memcpy(bytes[96..][0..long.len], long);
    @memcpy(bytes[320..][0..probe.len], probe);
    return bytes;
}
// de Bruijn B(32,3): every three-byte window is unique, so this corpus has no
// legal repeated match of length three or more. Low-alphabet entropy remains.
pub fn matchFree() [32 * 1024]u8 {
    var bytes: [32 * 1024]u8 = undefined;
    var symbols: [4]u8 = @splat(0);
    var written: usize = 0;
    deBruijn(&bytes, &written, &symbols, 1, 1);
    std.debug.assert(written == bytes.len);
    return bytes;
}
fn deBruijn(out: *[32 * 1024]u8, written: *usize, symbols: *[4]u8, t: usize, period: usize) void {
    if (t > 3) {
        if (3 % period == 0) for (symbols[1..][0..period]) |byte| {
            out[written.*] = byte;
            written.* += 1;
        };
        return;
    }
    symbols[t] = symbols[t - period];
    deBruijn(out, written, symbols, t + 1, period);
    var value: u8 = symbols[t - period] + 1;
    while (value < 32) : (value += 1) {
        symbols[t] = value;
        deBruijn(out, written, symbols, t + 1, t);
    }
}
pub fn roundTrip(frame: []const u8, expected: []const u8) !void {
    const decoded = try zstd.decodeNativeFrameAlloc(allocator, frame);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
    const header = try zstd.inspectNativeFrameHeader(frame);
    if (header.dictionary_id == 0 and header.window_size <= 128 * 1024) {
        const reference = try stdDecode(frame);
        defer allocator.free(reference);
        try std.testing.expectEqualSlices(u8, expected, reference);
    }
}
pub fn stdDecode(frame: []const u8) ![]u8 {
    var input: std.Io.Reader = .fixed(frame);
    var output: std.Io.Writer.Allocating = .init(allocator);
    defer output.deinit();
    var reference: std.compress.zstd.Decompress = .init(&input, &.{}, .{ .window_len = 128 * 1024 });
    _ = try reference.reader.streamRemaining(&output.writer);
    return output.toOwnedSlice();
}
pub fn sentinel(bytes: []const u8) !void {
    for (bytes) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}
/// Remove preceding history without adding a content-size mismatch or a
/// missing dictionary ID. The first block must be raw, so there is no inherited
/// entropy state to account for; only the final block's match history is lost.
pub fn standaloneSecond(frame: []const u8) ![]u8 {
    const header = try zstd.inspectNativeFrameHeader(frame);
    const first = try zstd.inspectNativeFrameBlockAt(frame, header.payload_offset);
    try std.testing.expectEqual(zstd.NativeBlockType.raw, first.block_type);
    try std.testing.expect(!first.last);
    const second = try zstd.inspectNativeFrameBlockAt(frame, first.next_header_offset);
    try std.testing.expect(second.last);
    const bytes = try allocator.alloc(u8, 6 + second.next_header_offset - second.header_offset);
    @memcpy(bytes[0..6], &[_]u8{ 0x28, 0xb5, 0x2f, 0xfd, 0, 24 });
    @memcpy(bytes[6..], frame[second.header_offset..second.next_header_offset]);
    bytes[6] |= 1;
    return bytes;
}
pub fn incremental(allocator_arg: std.mem.Allocator, options_arg: zstd.NativeFrameOptions, input: []const u8, input_chunk: usize, output_chunk: usize, flush_at: ?usize, dictionary_arg: ?zstd.NativeDictionary) ![]u8 {
    var options = options_arg;
    options.dictionary_id = if (dictionary_arg) |dict| dict.id else 0;
    var encoder = if (options.include_content_size)
        if (dictionary_arg) |dict|
            try zstd.NativeIncrementalFrameEncoder.initExactSizeWithPresetDictionary(allocator_arg, options, input.len, dict)
        else
            try zstd.NativeIncrementalFrameEncoder.initExactSize(allocator_arg, options, input.len)
    else if (dictionary_arg) |dict|
        try zstd.NativeIncrementalFrameEncoder.initWithPresetDictionary(allocator_arg, options, dict)
    else
        try zstd.NativeIncrementalFrameEncoder.init(allocator_arg, options);
    defer encoder.deinit();
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator_arg);
    var scratch: [512]u8 = undefined;
    var read: usize = 0;
    var flushed = flush_at == null;
    while (read < input.len) {
        if (!flushed and read == flush_at.?) {
            encoder.flush();
            try drainFlush(&encoder, allocator_arg, &output, scratch[0..output_chunk]);
            flushed = true;
        }
        var end = @min(input.len, read + input_chunk);
        if (!flushed) end = @min(end, flush_at.?);
        const step = try encoder.step(input[read..end], scratch[0..output_chunk]);
        read += step.progress.input_read;
        try output.appendSlice(allocator_arg, scratch[0..step.progress.output_written]);
        try std.testing.expect(step.progress.input_read != 0 or step.progress.output_written != 0);
    }
    encoder.finish();
    while (true) {
        const step = try encoder.step(&.{}, scratch[0..output_chunk]);
        try output.appendSlice(allocator_arg, scratch[0..step.progress.output_written]);
        if (step.status == .done) break;
        try std.testing.expect(step.progress.output_written != 0);
    }
    return output.toOwnedSlice(allocator_arg);
}
fn drainFlush(encoder: *zstd.NativeIncrementalFrameEncoder, allocator_arg: std.mem.Allocator, output: *std.ArrayList(u8), scratch: []u8) !void {
    while (true) {
        const step = try encoder.step(&.{}, scratch);
        try output.appendSlice(allocator_arg, scratch[0..step.progress.output_written]);
        if (step.status == .need_input) return;
        try std.testing.expect(step.progress.output_written != 0);
    }
}
