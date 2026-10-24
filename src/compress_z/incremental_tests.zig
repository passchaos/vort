const std = @import("std");
const compress_z = @import("../compress_z.zig");

const ncompress_hex = "1f9d8c549e0829f2448a932754020e2ca890a04184";
const ncompress_payload = "TOBEORNOTTOBEORTOBEORNOT";

fn decodeSchedule(
    allocator: std.mem.Allocator,
    encoded: []const u8,
    input_chunk: usize,
    output_chunk: usize,
    options: compress_z.IncrementalDecoder.Options,
) ![]u8 {
    var decoder = compress_z.IncrementalDecoder.initWithOptions(allocator, options);
    defer decoder.deinit();
    var decoded: std.ArrayList(u8) = .empty;
    errdefer decoded.deinit(allocator);
    const output = try allocator.alloc(u8, output_chunk);
    defer allocator.free(output);
    var input_offset: usize = 0;
    var finish_sent = false;
    var iterations: usize = 0;
    while (true) {
        iterations += 1;
        if (iterations > encoded.len * 64 + 4096) return error.TestUnexpectedResult;
        const input_end = @min(encoded.len, input_offset + input_chunk);
        const stepped = try decoder.step(encoded[input_offset..input_end], output);
        input_offset += stepped.progress.input_read;
        try decoded.appendSlice(allocator, output[0..stepped.progress.output_written]);
        if (stepped.status == .done) break;
        var just_finished = false;
        if (!finish_sent and input_offset == encoded.len) {
            decoder.finish();
            finish_sent = true;
            just_finished = true;
        }
        if (stepped.progress.input_read == 0 and stepped.progress.output_written == 0 and
            !(stepped.status == .need_input and (!finish_sent or just_finished)))
            return error.TestUnexpectedResult;
    }
    try std.testing.expectEqual(encoded.len, input_offset);
    return decoded.toOwnedSlice(allocator);
}

test "Unix compress incremental decoder accepts ncompress and tiny schedules" {
    const allocator = std.testing.allocator;
    var encoded: [ncompress_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&encoded, ncompress_hex);
    const one = try decodeSchedule(allocator, &encoded, 1, 1, .{});
    defer allocator.free(one);
    const micro = try decodeSchedule(allocator, &encoded, 5, 7, .{});
    defer allocator.free(micro);
    try std.testing.expectEqualSlices(u8, ncompress_payload, one);
    try std.testing.expectEqualSlices(u8, ncompress_payload, micro);

    const empty = try decodeSchedule(allocator, &.{ 0x1f, 0x9d, 0x90 }, 1, 1, .{});
    defer allocator.free(empty);
    try std.testing.expectEqual(@as(usize, 0), empty.len);
}

test "Unix compress incremental decoder covers every width clear and freeze" {
    const allocator = std.testing.allocator;
    var random: [96 * 1024]u8 = undefined;
    var prng = std.Random.DefaultPrng.init(0x5a_69_70_2e_4c_5a_57);
    prng.random().bytes(&random);
    var max_bits: u5 = 9;
    while (max_bits <= 16) : (max_bits += 1) {
        const encoded = try compress_z.encodeAlloc(allocator, &random, .{
            .max_code_bits = max_bits,
            .block_mode = true,
        });
        defer allocator.free(encoded);
        const decoded = try decodeSchedule(allocator, encoded, 17, 31, .{
            .expected_output_len = random.len,
        });
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, &random, decoded);
    }

    const frozen = try compress_z.encodeAlloc(allocator, &random, .{
        .max_code_bits = 9,
        .block_mode = false,
    });
    defer allocator.free(frozen);
    var decoder = compress_z.IncrementalDecoder.initWithOptions(allocator, .{
        .expected_output_len = random.len,
    });
    defer decoder.deinit();
    var output: [257]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (input_offset < frozen.len) {
        const stepped = try decoder.step(frozen[input_offset..], &output);
        input_offset += stepped.progress.input_read;
        output_offset += stepped.progress.output_written;
    }
    decoder.finish();
    while (true) {
        const stepped = try decoder.step("", &output);
        output_offset += stepped.progress.output_written;
        if (stepped.status == .done) break;
    }
    const snapshot = decoder.snapshot();
    try std.testing.expectEqual(random.len, output_offset);
    try std.testing.expectEqual(@as(usize, 0), snapshot.clear_count);
    try std.testing.expectEqual(@as(usize, 512), snapshot.next_code);
}

test "Unix compress incremental decoder records width growth and block clears" {
    const allocator = std.testing.allocator;
    var random: [32 * 1024]u8 = undefined;
    var prng = std.Random.DefaultPrng.init(0xc1_ea_12_34);
    prng.random().bytes(&random);
    const encoded = try compress_z.encodeAlloc(allocator, &random, .{
        .max_code_bits = 10,
        .block_mode = true,
    });
    defer allocator.free(encoded);
    var decoder = compress_z.IncrementalDecoder.initWithOptions(allocator, .{
        .expected_output_len = random.len,
    });
    defer decoder.deinit();
    var output: [113]u8 = undefined;
    var input_offset: usize = 0;
    while (input_offset < encoded.len) {
        const stepped = try decoder.step(encoded[input_offset..], &output);
        input_offset += stepped.progress.input_read;
    }
    decoder.finish();
    while (true) {
        const stepped = try decoder.step("", &output);
        if (stepped.status == .done) break;
    }
    const snapshot = decoder.snapshot();
    try std.testing.expect(snapshot.width_growth_count != 0);
    try std.testing.expect(snapshot.clear_count != 0);
}

test "Unix compress incremental decoder enforces limits backpressure and malformed tails" {
    const allocator = std.testing.allocator;
    const input = "bounded Unix compress output " ** 128;
    const encoded = try compress_z.encodeAlloc(allocator, input, .{});
    defer allocator.free(encoded);

    var limited = compress_z.IncrementalDecoder.initWithOptions(allocator, .{
        .max_output_len = input.len - 1,
    });
    defer limited.deinit();
    try expectDecodeError(&limited, encoded, error.OutputLimitExceeded);

    var exact = compress_z.IncrementalDecoder.initWithOptions(allocator, .{
        .expected_output_len = input.len + 1,
    });
    defer exact.deinit();
    try expectDecodeError(&exact, encoded, error.SizeMismatch);

    var truncated = compress_z.IncrementalDecoder.init(allocator);
    defer truncated.deinit();
    var scratch: [16]u8 = undefined;
    const header = [_]u8{ 0x1f, 0x9d, 0x90, 0x00 };
    _ = try truncated.step(&header, &scratch);
    truncated.finish();
    try std.testing.expectError(error.TruncatedFrame, truncated.step("", &scratch));

    var invalid = compress_z.IncrementalDecoder.init(allocator);
    defer invalid.deinit();
    const invalid_code = [_]u8{ 0x1f, 0x9d, 0x90, 0x00, 0x03 };
    try std.testing.expectError(
        error.InvalidCompressStream,
        invalid.step(&invalid_code, &scratch),
    );

    var after_finish = compress_z.IncrementalDecoder.init(allocator);
    defer after_finish.deinit();
    after_finish.finish();
    try std.testing.expectError(
        error.TrailingData,
        after_finish.step(&invalid_code, &scratch),
    );

    var blocked = compress_z.IncrementalDecoder.init(allocator);
    defer blocked.deinit();
    const blocked_first = try blocked.step(encoded, &.{});
    try std.testing.expectEqual(
        @import("../core.zig").StepResult.Status.need_output,
        blocked_first.status,
    );
    const zero = try blocked.step("", &.{});
    try std.testing.expectEqual(
        @import("../core.zig").StepResult.Status.need_output,
        zero.status,
    );
}

test "Unix compress incremental decoder releases every allocation failure path" {
    const allocator = std.testing.allocator;
    const input = "allocation failure Unix compress" ** 2048;
    const encoded = try compress_z.encodeAlloc(allocator, input, .{});
    defer allocator.free(encoded);
    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator, bytes: []const u8) !void {
            const decoded = try decodeSchedule(failing_allocator, bytes, 13, 19, .{});
            defer failing_allocator.free(decoded);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{encoded});
}

fn expectDecodeError(
    decoder: *compress_z.IncrementalDecoder,
    encoded: []const u8,
    expected: anyerror,
) !void {
    var output: [127]u8 = undefined;
    var input_offset: usize = 0;
    var finish_sent = false;
    while (true) {
        const stepped = decoder.step(encoded[input_offset..], &output) catch |err| {
            try std.testing.expectEqual(expected, err);
            return;
        };
        input_offset += stepped.progress.input_read;
        if (!finish_sent and input_offset == encoded.len) {
            decoder.finish();
            finish_sent = true;
        }
        if (stepped.status == .done) return error.TestUnexpectedResult;
    }
}
