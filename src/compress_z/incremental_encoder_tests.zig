const std = @import("std");
const compress_z = @import("../compress_z.zig");

fn encodeSchedule(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: compress_z.IncrementalEncoder.Options,
    input_chunk: usize,
    output_chunk: usize,
) ![]u8 {
    var encoder = try compress_z.IncrementalEncoder.initWithOptions(allocator, options);
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(allocator);
    const output = try allocator.alloc(u8, output_chunk);
    defer allocator.free(output);
    var input_offset: usize = 0;
    while (input_offset < input.len) {
        const input_end = @min(input.len, input_offset + input_chunk);
        while (input_offset < input_end) {
            const stepped = try encoder.step(input[input_offset..input_end], output);
            input_offset += stepped.progress.input_read;
            try encoded.appendSlice(allocator, output[0..stepped.progress.output_written]);
            if (stepped.progress.input_read == 0 and stepped.progress.output_written == 0)
                return error.TestUnexpectedResult;
        }
    }
    encoder.finish();
    while (true) {
        const stepped = try encoder.step("", output);
        try encoded.appendSlice(allocator, output[0..stepped.progress.output_written]);
        if (stepped.status == .done) break;
        if (stepped.progress.input_read == 0 and stepped.progress.output_written == 0)
            return error.TestUnexpectedResult;
    }
    return encoded.toOwnedSlice(allocator);
}

test "Unix compress incremental encoder is byte exact for all widths and modes" {
    const allocator = std.testing.allocator;
    var random: [96 * 1024]u8 = undefined;
    var prng = std.Random.DefaultPrng.init(0x5a_77_72_69_74_65);
    prng.random().bytes(&random);
    var max_bits: u5 = 9;
    while (max_bits <= 16) : (max_bits += 1) {
        inline for (.{ false, true }) |block_mode| {
            const expected = try compress_z.encodeAlloc(allocator, &random, .{
                .max_code_bits = max_bits,
                .block_mode = block_mode,
            });
            defer allocator.free(expected);
            const options: compress_z.IncrementalEncoder.Options = .{
                .max_code_bits = max_bits,
                .block_mode = block_mode,
            };
            const one = try encodeSchedule(allocator, &random, options, 1, 1);
            defer allocator.free(one);
            const micro = try encodeSchedule(allocator, &random, options, 257, 31);
            defer allocator.free(micro);
            try std.testing.expectEqualSlices(u8, expected, one);
            try std.testing.expectEqualSlices(u8, expected, micro);
        }
    }
}

test "Unix compress incremental encoder covers clear freeze width and empty states" {
    const allocator = std.testing.allocator;
    const empty = try encodeSchedule(allocator, "", .{}, 1, 1);
    defer allocator.free(empty);
    try std.testing.expectEqualSlices(u8, &.{ 0x1f, 0x9d, 0x90 }, empty);

    var random: [32 * 1024]u8 = undefined;
    var prng = std.Random.DefaultPrng.init(0xc1_ea_55_aa);
    prng.random().bytes(&random);
    var block = try compress_z.IncrementalEncoder.initWithOptions(allocator, .{
        .max_code_bits = 10,
        .block_mode = true,
    });
    defer block.deinit();
    var output: [257]u8 = undefined;
    var offset: usize = 0;
    while (offset < random.len) {
        const stepped = try block.step(random[offset..], &output);
        offset += stepped.progress.input_read;
    }
    block.finish();
    while ((try block.step("", &output)).status != .done) {}
    try std.testing.expect(block.snapshot().width_growth_count != 0);
    try std.testing.expect(block.snapshot().clear_count != 0);

    const frozen_wire = try encodeSchedule(allocator, &random, .{
        .max_code_bits = 9,
        .block_mode = false,
    }, 17, 19);
    defer allocator.free(frozen_wire);
    const decoded = try compress_z.decodeAlloc(allocator, frozen_wire);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &random, decoded);
}

test "Unix compress incremental encoder enforces exact size limits and backpressure" {
    const allocator = std.testing.allocator;
    var exact = try compress_z.IncrementalEncoder.initExactSize(allocator, .{}, 3);
    defer exact.deinit();
    var output: [64]u8 = undefined;
    _ = try exact.step("ab", &output);
    exact.finish();
    try std.testing.expectError(error.SizeMismatch, exact.step("", &output));

    var limited = try compress_z.IncrementalEncoder.initWithOptions(allocator, .{
        .max_input_len = 2,
    });
    defer limited.deinit();
    _ = try limited.step("ab", &output);
    try std.testing.expectError(error.OutputLimitExceeded, limited.step("c", &output));

    try std.testing.expectError(
        error.InvalidCompressHeader,
        compress_z.IncrementalEncoder.initWithOptions(allocator, .{
            .max_pending_output_len = 2,
        }),
    );

    var blocked = try compress_z.IncrementalEncoder.init(allocator);
    defer blocked.deinit();
    const first = try blocked.step("payload", &.{});
    try std.testing.expectEqual(@import("../core.zig").StepResult.Status.need_output, first.status);
    const second = try blocked.step("", &.{});
    try std.testing.expectEqual(@import("../core.zig").StepResult.Status.need_output, second.status);
}

test "Unix compress incremental encoder releases every allocation failure path" {
    const allocator = std.testing.allocator;
    const input = "allocation failure Unix compress encoder" ** 2048;
    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator, bytes: []const u8) !void {
            const encoded = try encodeSchedule(
                failing_allocator,
                bytes,
                .{ .max_code_bits = 12 },
                17,
                29,
            );
            defer failing_allocator.free(encoded);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{input});
}
