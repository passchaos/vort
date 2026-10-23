const std = @import("std");
const bzip2 = @import("../bzip2.zig");
const block_decoder = @import("decoder.zig");
const core = @import("../core.zig");

pub const python_payload = "hello hello hello\n" ** 20;
const python_frame_hex = "425a6831314159265359e2c777e0000054d100001040000244a00030c002950c9a55855e13c4c2ad157c5dc914e142438b1ddf80";
pub const randomized_payload = "a\n" ** 2500;
const randomized_frame_hex = "425a68313141592653597d0435b980077dc10000186000200050669a052534e42abb456c0d8856d02af5555da546c026d2ab6a889f1772453850907d0435b9";

// Python 3 bz2.compress(level=1), input[i] = (i*73 + i/251) mod 256,
// 100,321 bytes. Independent block markers occur at bits 32 and 8,662;
// the EOS marker starts at bit 12,518, so neither later marker is byte aligned.
const independent_multi_hex =
    "425a6831314159265359a58325ea0000067fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff" ++
    "ffffffe006df000000000000012600098000980000000000000000000000000000000000000000000000000000000093" ++
    "0004c0004c00000000000000000000000000000000000000000000000000000000498002600026000000000000000000" ++
    "0000000000000000000000000000000000000024c0013000130000000000000000000000000000000000000000000000" ++
    "000000000012600098000980000000000000000000000000000000000000000000000000000000014a5554681a34340d" ++
    "0c8064d0d3434189a34d0034608019034c419190310c400000d018990000341b400340000000000000034d02d02db7be" ++
    "52a9bb885bc5416f2816f4b1652a9bd885be085bec05bf2c58554dfea0b8010b8180b42b2b2954e0a217062170940b85" ++
    "ac594aa70d10b87885c4205c4d62c2aa7142171710b8ca05c6ac58554e3842e3c42e4102e4562c2aa724217262172881" ++
    "72ab1615539610b9710b9840b9958b0aa9cd541736217390173ab2b2954e7842e7ea0ba040ba158b2954e8842e8c42e9" ++
    "202e9562c2aa74c2174f10ba840ba9acaca553aa885d5885d6502eb6b1652a9d7442ebe217608176358b0aa9d9085d98" ++
    "85da205daac58554ed842edc42ee102ee562c2aa77421776217782168902f62216b4216b7016b8b1615535da82d7842f" ++
    "65017b359594aa7b410bdad417b640bdbac594aa7b810bdcc42f74816bf58b0aa9b0085eee217bc40bded65652a9efa2" ++
    "17bf10b61a05f02b1652a9b1442d8c42d9102f82b161553e1085f0c42f88816cab1615536610be2885f1842d9d02da04" ++
    "2f8f505f2102f92b1652a9f2842f96216d3016d4b1615536ba82f98217cd80be72caca5536c10b6d10b6ea05f3eb1652" ++
    "a9f42217d1885f4902fa758b0aa9f5042fab10beb205f5eb2b2954fb110bec885f6902fb6b161553ee085f7442fbc817" ++
    "df58b0aa9f8042fc2217e240bf1ac58554dbc42fc8217e580bf32caca553f3885fa2a0bf4a05b82c594aa6e2216e4217" ++
    "ea80b7358b0aa9ba5417eb10bf6205fb6b2b2954fdd10bf7885fc2817f1ac594aa7f2885fce217f440bfad62c2aa7f61" ++
    "0bfbc42ff0817f958b0aa9fe842ff6216ea817fc58b0aa9ff442ffc217ff40b7658b0aa9a010b7710b7880b7958b0aa9" ++
    "bd5416f6216f9016fab2b2954df842dfea0b8040b8158b2954d0885c1085a180b83ac58554e1042e162170c8170f5959" ++
    "4aa71110b8910b8aa05c5d62ca5538c885c6c42e3902e3d62c2aa720217222172481726b1615539410b9510b9640b975" ++
    "8b0aa9cc085cc885cd205cdac594aa7382173a2173d0173eb161553a0a82e8442e8a02e8d65652a9d2085d2d4174c817" ++
    "4f58b2954ea22175310baa40babac58554eb042eb62175c8175f59594aa76110bb110bb2a05d9ac58554ed042ed442ed" ++
    "902edd62c2aa770217722177481776b161553bc10b442168902ef4c50564994d678194b280000213ffffffffffffffff" ++
    "fffffffffffffffffffffffffffffffffffffffffffffffffffec0039541aaa13134c4c991809883269a64d310d34c4d" ++
    "3268343262643010309a0190c09a3230400d00c430268c830234c00069a000d3200000d31019084554d3130130002600" ++
    "0009a604c980000000004c8600008c264c0469804c00000000004c00026830008d302611a61260009800098000000000" ++
    "00000000000000000000000000000000000000000000001fd98ff09913426c4e09d13c27c500a114428e92969a9c8541" ++
    "1a9aaabacad15d5f61636567684ad4994b6b71702e45d0bb1782f45f0bf1803046161e262e363e46495ca2c5cc658ccc" ++
    "dcecfd0326b474b4f8bc6e382982a02a82b02b82c02c82d02d82e02eaf2fb030b131b232b333b43483535b636b779dbd" ++
    "c3d1e9f538b90398750ec3b43b63b81dc3c0790f41edf3bafbdeefbf3ff83c301030506213c5e3f2797cde7f47a7d50b" ++
    "ebf60f68920930940950960970f904c04c84d4dce4ecf4fd050d151d252d3053d454d555d656d757d858d959da05a85b" ++
    "09b1382744f09f1402841ed151d252d35390a823535557595a2babec2c6caced095a93296d6e2e05c8ba1762f05e8be1" ++
    "7e300608c2c3c4c5c6c7c8c92b9458b98cb1999b9d9fa064d68e969ffc5dc914e14242ad8d9dd4";

test "Bzip2 incremental decoder accepts byte input tiny output and concatenation" {
    const frame = pythonFrame();
    var concatenated: [frame.len * 2]u8 = undefined;
    @memcpy(concatenated[0..frame.len], &frame);
    @memcpy(concatenated[frame.len..], &frame);

    var decoder = bzip2.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = python_payload.len * 2,
        .max_output_len = python_payload.len * 2,
        .max_compressed_block_len = 256,
        .max_decoded_block_len = python_payload.len,
    });
    defer decoder.deinit();
    const decoded = try decodeSplit(&decoder, &concatenated, 1, 7);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, python_payload ++ python_payload, decoded);

    const snap = decoder.snapshot();
    try std.testing.expectEqual(bzip2.IncrementalDecoder.Phase.done, snap.phase);
    try std.testing.expectEqual(@as(usize, 2), snap.stream_count);
    try std.testing.expectEqual(@as(usize, 2), snap.block_count);
    try std.testing.expectEqual(python_payload.len * 2, snap.output_written);
    try std.testing.expect(snap.buffered_bit_offset < 8);

    decoder.reset();
    try std.testing.expectEqual(bzip2.IncrementalDecoder.Phase.header, decoder.snapshot().phase);
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().stream_count);
}

test "Bzip2 incremental decoder stops after first stream and exposes buffered suffix" {
    const frame = pythonFrame();
    const suffix = "ZIP descriptor and next header";
    const input = frame ++ suffix.*;
    var decoder = bzip2.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = python_payload.len,
        .max_output_len = python_payload.len,
        .stop_after_first_stream = true,
        .first_stream_retry_granularity = 12,
    });
    defer decoder.deinit();
    var decoded: [python_payload.len]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (true) {
        const stepped = try decoder.step(input[input_offset..], decoded[output_offset..]);
        input_offset += stepped.progress.input_read;
        output_offset += stepped.progress.output_written;
        if (stepped.status == .done) break;
    }
    try std.testing.expectEqualSlices(u8, python_payload, &decoded);
    var recovered_suffix: [suffix.len]u8 = undefined;
    const buffered = decoder.trailingInput();
    @memcpy(recovered_suffix[0..buffered.len], buffered);
    @memcpy(recovered_suffix[buffered.len..], input[input_offset..]);
    try std.testing.expectEqualSlices(u8, suffix, &recovered_suffix);
    try std.testing.expectEqual(buffered.len, decoder.snapshot().trailing_input_bytes);
}

test "Bzip2 incremental decoder crosses non-byte-aligned multi-block boundaries" {
    const input = try std.testing.allocator.alloc(u8, 100_321);
    defer std.testing.allocator.free(input);
    for (input, 0..) |*byte, index| byte.* = @truncate(index *% 73 +% index / 251);
    const encoded = independentMultiFrame();

    var decoder = bzip2.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = input.len,
        .max_output_len = input.len,
        .max_compressed_block_len = 4 * 1024 * 1024,
        .max_decoded_block_len = 100_000 * 259 / 5 + 4,
    });
    defer decoder.deinit();
    const decoded = try decodeSplit(&decoder, &encoded, 11, 17);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
    try std.testing.expect(decoder.snapshot().block_count >= 2);
    try std.testing.expectEqual(@as(usize, 1), decoder.snapshot().stream_count);
}

test "Bzip2 incremental decoder accepts legacy randomized blocks" {
    const frame = randomizedFrame();
    var decoder = bzip2.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = randomized_payload.len,
        .max_output_len = randomized_payload.len,
        .max_compressed_block_len = 256,
        .max_decoded_block_len = randomized_payload.len,
    });
    defer decoder.deinit();
    const decoded = try decodeSplit(&decoder, &frame, 1, 7);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, randomized_payload, decoded);
    try std.testing.expectEqual(@as(usize, 1), decoder.snapshot().block_count);
    try std.testing.expectEqual(@as(usize, 1), decoder.snapshot().stream_count);
}

test "Bzip2 incremental decoder honors zero-output backpressure" {
    const frame = pythonFrame();
    var decoder = bzip2.IncrementalDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    const accepted = try decoder.step(&frame, &.{});
    try std.testing.expectEqual(frame.len, accepted.progress.input_read);
    try std.testing.expectEqual(core.StepResult.Status.need_input, accepted.status);
    decoder.finish();

    const blocked = try decoder.step("", &.{});
    try std.testing.expectEqual(core.StepResult.Status.need_output, blocked.status);
    try std.testing.expectEqual(@as(usize, 0), blocked.progress.output_written);
    try std.testing.expectEqual(python_payload.len, decoder.snapshot().pending_output);

    var output: [python_payload.len]u8 = undefined;
    const done = try decoder.step("", &output);
    try std.testing.expectEqual(core.StepResult.Status.done, done.status);
    try std.testing.expectEqualSlices(u8, python_payload, &output);
}

test "Bzip2 incremental decoder verifies block CRC before output" {
    var corrupt = pythonFrame();
    corrupt[10] ^= 1;
    var output: [python_payload.len]u8 = @splat(0xcc);
    var decoder = bzip2.IncrementalDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    const accepted = try decoder.step(&corrupt, &output);
    try std.testing.expectEqual(core.StepResult.Status.need_input, accepted.status);
    decoder.finish();
    try std.testing.expectError(error.ChecksumMismatch, decoder.step("", &output));
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().output_written);
    try std.testing.expectEqualSlices(u8, &([_]u8{0xcc} ** python_payload.len), &output);
    try std.testing.expectEqualStrings("ChecksumMismatch", decoder.diagnostics().last_error_name);
}

test "Bzip2 incremental decoder verifies the member combined CRC" {
    var corrupt = pythonFrame();
    var transformed: std.ArrayList(u8) = .empty;
    defer transformed.deinit(std.testing.allocator);
    var decoded: std.ArrayList(u8) = .empty;
    defer decoded.deinit(std.testing.allocator);
    const part = try block_decoder.decodeIncrementalPart(
        std.testing.allocator,
        corrupt[4..],
        0,
        100_000,
        python_payload.len,
        &transformed,
        &decoded,
    );
    const block = switch (part) {
        .block => |value| value,
        .end => return error.TestUnexpectedResult,
    };
    const combined_crc_bit = block.next_bit_offset + 48;
    const crc_byte = 4 + combined_crc_bit / 8;
    const crc_shift: u3 = @intCast(7 - (combined_crc_bit & 7));
    corrupt[crc_byte] ^= @as(u8, 1) << crc_shift;
    try std.testing.expectError(error.ChecksumMismatch, bzip2.decodeAlloc(std.testing.allocator, &corrupt));

    var output: [python_payload.len]u8 = undefined;
    var decoder = bzip2.IncrementalDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    _ = try decoder.step(&corrupt, &output);
    decoder.finish();
    try std.testing.expectError(error.ChecksumMismatch, drainFinished(&decoder, &output));
    try std.testing.expectEqual(python_payload.len, decoder.snapshot().output_written);
    try std.testing.expectEqualSlices(u8, python_payload, &output);
}

test "Bzip2 incremental decoder enforces compressed decoded and total limits" {
    const frame = pythonFrame();
    var scratch: [python_payload.len]u8 = undefined;

    var compressed_limited = bzip2.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .max_compressed_block_len = 8,
    });
    defer compressed_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, compressed_limited.step(&frame, &scratch));

    var block_limited = bzip2.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .max_decoded_block_len = python_payload.len - 1,
    });
    defer block_limited.deinit();
    _ = try block_limited.step(&frame, &scratch);
    block_limited.finish();
    try std.testing.expectError(error.OutputLimitExceeded, block_limited.step("", &scratch));

    var output_limited = bzip2.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .max_output_len = python_payload.len - 1,
    });
    defer output_limited.deinit();
    _ = try output_limited.step(&frame, &scratch);
    output_limited.finish();
    try std.testing.expectError(error.OutputLimitExceeded, output_limited.step("", &scratch));

    var exact_short = bzip2.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = python_payload.len - 1,
    });
    defer exact_short.deinit();
    _ = try exact_short.step(&frame, &scratch);
    exact_short.finish();
    try std.testing.expectError(error.SizeMismatch, exact_short.step("", &scratch));

    var exact_long = bzip2.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = python_payload.len + 1,
    });
    defer exact_long.deinit();
    _ = try exact_long.step(&frame, &scratch);
    exact_long.finish();
    try std.testing.expectError(error.SizeMismatch, drainFinished(&exact_long, &scratch));
}

test "Bzip2 incremental decoder reports every truncated fixture prefix" {
    const frame = pythonFrame();
    var scratch: [31]u8 = undefined;
    for (0..frame.len) |cut| {
        var decoder = bzip2.IncrementalDecoder.init(std.testing.allocator);
        defer decoder.deinit();
        var offset: usize = 0;
        while (offset < cut) {
            const result = try decoder.step(frame[offset..cut], &scratch);
            offset += result.progress.input_read;
        }
        decoder.finish();
        try std.testing.expectError(error.TruncatedFrame, drainFinished(&decoder, &scratch));
        try std.testing.expectEqualStrings("truncated_input", decoder.diagnostics().recoverability_hint_name);
    }
}

test "Bzip2 incremental decoder releases every allocation failure" {
    const frame = pythonFrame();
    const Test = struct {
        fn run(allocator: std.mem.Allocator, encoded: []const u8) !void {
            var decoder = bzip2.IncrementalDecoder.initWithOptions(allocator, .{
                .expected_output_len = python_payload.len,
            });
            defer decoder.deinit();
            const output = try allocator.alloc(u8, python_payload.len);
            defer allocator.free(output);
            const accepted = try decoder.step(encoded, output);
            try std.testing.expectEqual(encoded.len, accepted.progress.input_read);
            decoder.finish();
            const done = try decoder.step("", output);
            try std.testing.expectEqual(core.StepResult.Status.done, done.status);
            try std.testing.expectEqualSlices(u8, python_payload, output);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{frame[0..]});
}

fn decodeSplit(
    decoder: *bzip2.IncrementalDecoder,
    encoded: []const u8,
    input_chunk_len: usize,
    output_chunk_len: usize,
) ![]u8 {
    var decoded: std.ArrayList(u8) = .empty;
    errdefer decoded.deinit(std.testing.allocator);
    const scratch = try std.testing.allocator.alloc(u8, output_chunk_len);
    defer std.testing.allocator.free(scratch);
    var input_offset: usize = 0;
    while (input_offset < encoded.len) {
        const input_end = @min(encoded.len, input_offset + input_chunk_len);
        const result = try decoder.step(encoded[input_offset..input_end], scratch);
        input_offset += result.progress.input_read;
        try decoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        try std.testing.expect(
            result.progress.input_read != 0 or
                result.progress.output_written != 0 or
                result.status == .need_input,
        );
    }
    decoder.finish();
    while (true) {
        const result = try decoder.step("", scratch);
        try decoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
        try std.testing.expectEqual(core.StepResult.Status.need_output, result.status);
    }
    return decoded.toOwnedSlice(std.testing.allocator);
}

fn drainFinished(decoder: *bzip2.IncrementalDecoder, output: []u8) !void {
    while (true) {
        const result = try decoder.step("", output);
        if (result.status == .done) return;
    }
}

pub fn pythonFrame() [python_frame_hex.len / 2]u8 {
    var bytes: [python_frame_hex.len / 2]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, python_frame_hex) catch unreachable;
    return bytes;
}

pub fn randomizedFrame() [randomized_frame_hex.len / 2]u8 {
    var bytes: [randomized_frame_hex.len / 2]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, randomized_frame_hex) catch unreachable;
    return bytes;
}

pub fn independentMultiFrame() [independent_multi_hex.len / 2]u8 {
    var bytes: [independent_multi_hex.len / 2]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, independent_multi_hex) catch unreachable;
    return bytes;
}
