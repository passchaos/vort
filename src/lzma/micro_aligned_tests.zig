const std = @import("std");
const writer = @import("micro_writer.zig");
const decoder = @import("decoder.zig");

test "MicroLZMA aligned prefixes split matches and remain terminated at every capacity" {
    const allocator = std.testing.allocator;
    var random: [513]u8 = undefined;
    var prng = std.Random.DefaultPrng.init(0x414c_4947_4e45_4450);
    prng.random().bytes(&random);
    const inputs = [_][]const u8{ &random, "abc" ** 600, "tiny", "" };
    const settings = [_]writer.Options{
        .{ .mode = .literal_only, .properties = .{ .lc = 0, .lp = 4, .pb = 0 } },
        .{ .mode = .greedy, .dictionary_size = 4096 },
        .{ .mode = .lazy, .dictionary_size = 128 * 1024 },
    };
    for (settings) |options| {
        for (inputs) |input| {
            for ([_]usize{ 2, 3, 7, 256 }) |alignment| {
                var previous_consumed: usize = 0;
                for (6..65) |capacity| {
                    var output: [80]u8 = @splat(0xa5);
                    const result = try writer.encodeAlignedDestSizeInto(allocator, input, output[0..capacity], alignment, options);
                    try std.testing.expect(result.consumed <= input.len);
                    try std.testing.expect(result.consumed == input.len or result.consumed % alignment == 0);
                    try std.testing.expect(result.consumed >= previous_consumed);
                    previous_consumed = result.consumed;
                    const decoded = try decoder.decodeMicroAllocExactSize(allocator, output[0..result.written], result.consumed, options.dictionary_size);
                    defer allocator.free(decoded);
                    try std.testing.expectEqualSlices(u8, input[0..result.consumed], decoded);
                    for (output[result.written..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
                }
            }
        }
    }
}

test "MicroLZMA aligned prefixes permit complete tails and report no fitting block" {
    const allocator = std.testing.allocator;
    var output: [128]u8 = @splat(0xa5);
    const tiny = "complete unaligned tail";
    const complete = try writer.encodeAlignedDestSizeInto(allocator, tiny, &output, 4096, .{});
    try std.testing.expectEqual(tiny.len, complete.consumed);
    const decoded = try decoder.decodeMicroAllocExactSize(allocator, output[0..complete.written], tiny.len, 32 * 1024);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings(tiny, decoded);
    const none = try writer.encodeAlignedDestSizeInto(allocator, tiny, output[0..6], 4096, .{});
    try std.testing.expectEqual(@as(usize, 0), none.consumed);
    const empty = try decoder.decodeMicroAllocExactSize(allocator, output[0..none.written], 0, 32 * 1024);
    defer allocator.free(empty);
    try std.testing.expectEqual(@as(usize, 0), empty.len);
    @memset(&output, 0xa5);
    try std.testing.expectError(error.InvalidLzmaOptions, writer.encodeAlignedDestSizeInto(allocator, tiny, &output, 0, .{}));
    try std.testing.expectError(error.OutputTooSmall, writer.encodeAlignedDestSizeInto(allocator, tiny, output[0..5], 4096, .{}));
    try std.testing.expectEqualSlices(u8, &([_]u8{0xa5} ** 128), &output);
}

test "MicroLZMA aligned prefix encoder releases every allocation failure" {
    const Test = struct {
        fn run(allocator: std.mem.Allocator, options: writer.Options) !void {
            const input = "aligned allocation payload\n" ** 400;
            var output: [48]u8 = @splat(0xa5);
            const result = writer.encodeAlignedDestSizeInto(allocator, input, &output, 512, options) catch |err| {
                try std.testing.expectEqualSlices(u8, &([_]u8{0xa5} ** 48), &output);
                return err;
            };
            try std.testing.expect(result.consumed == input.len or result.consumed % 512 == 0);
            const decoded = try decoder.decodeMicroAllocExactSize(allocator, output[0..result.written], result.consumed, options.dictionary_size);
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, input[0..result.consumed], decoded);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{writer.Options{}});
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{writer.Options{ .mode = .lazy, .dictionary_size = 128 * 1024 }});
}
