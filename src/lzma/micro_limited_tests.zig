const std = @import("std");
const writer = @import("micro_writer.zig");
const decoder = @import("decoder.zig");

test "MicroLZMA destination limits terminate at every small capacity" {
    const allocator = std.testing.allocator;
    var random: [512]u8 = undefined;
    var prng = std.Random.DefaultPrng.init(0x4445_5354_5349_5a45);
    prng.random().bytes(&random);
    const inputs = [_][]const u8{ &random, "repeated capacity payload\n" ** 100, "tiny", "" };
    const options = [_]writer.Options{
        .{ .mode = .literal_only, .properties = .{ .lc = 0, .lp = 4, .pb = 0 } },
        .{ .mode = .greedy, .dictionary_size = 4096 },
        .{ .mode = .lazy, .dictionary_size = 128 * 1024, .properties = .{ .lc = 4, .pb = 4 } },
    };
    for (options) |settings| {
        for (inputs) |input| {
            var previous_consumed: usize = 0;
            for (6..97) |capacity| {
                var output: [112]u8 = @splat(0xa5);
                const result = try writer.encodeDestSizeInto(allocator, input, output[0..capacity], settings);
                try std.testing.expect(result.written <= capacity);
                try std.testing.expect(result.consumed <= input.len);
                try std.testing.expect(input.len == 0 or result.consumed != 0);
                try std.testing.expect(result.consumed >= previous_consumed);
                previous_consumed = result.consumed;
                const decoded = try decoder.decodeMicroAllocExactSize(allocator, output[0..result.written], result.consumed, settings.dictionary_size);
                defer allocator.free(decoded);
                try std.testing.expectEqualSlices(u8, input[0..result.consumed], decoded);
                for (output[result.written..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
                var allocated = try writer.encodeDestSizeAlloc(allocator, input, capacity, settings);
                defer allocated.deinit(allocator);
                try std.testing.expectEqual(result.consumed, allocated.consumed);
                try std.testing.expectEqualSlices(u8, output[0..result.written], allocated.bytes);
            }
        }
    }
}

test "MicroLZMA sufficient destination capacity preserves complete-stream wire" {
    const allocator = std.testing.allocator;
    const input = "{\"service\":\"vort\",\"message\":\"capacity bounded MicroLZMA\"}\n" ** 100;
    const options = [_]writer.Options{
        .{ .mode = .literal_only },
        .{ .mode = .greedy },
        .{ .mode = .lazy },
        .{ .mode = .greedy, .dictionary_size = 128 * 1024 },
        .{ .mode = .lazy, .dictionary_size = 128 * 1024 },
    };
    for (options) |settings| {
        const complete = try writer.encodeAlloc(allocator, input, settings);
        defer allocator.free(complete);
        var limited = try writer.encodeDestSizeAlloc(allocator, input, complete.len, settings);
        defer limited.deinit(allocator);
        try std.testing.expectEqual(input.len, limited.consumed);
        try std.testing.expectEqualSlices(u8, complete, limited.bytes);
    }
}

test "MicroLZMA limited writer validates minimum capacity and keeps destinations" {
    const allocator = std.testing.allocator;
    var output: [8]u8 = @splat(0xa5);
    for (0..6) |capacity| {
        for ([_][]const u8{ "", "payload" }) |input| {
            try std.testing.expectError(error.OutputTooSmall, writer.encodeDestSizeInto(allocator, input, output[0..capacity], .{}));
            try std.testing.expectEqualSlices(u8, &([_]u8{0xa5} ** 8), &output);
        }
    }
    try std.testing.expectError(error.InvalidLzmaOptions, writer.encodeDestSizeInto(allocator, "payload", &output, .{ .dictionary_size = 4095 }));
    try std.testing.expectEqualSlices(u8, &([_]u8{0xa5} ** 8), &output);
}

test "MicroLZMA limited writer releases every allocation failure" {
    const Test = struct {
        fn run(allocator: std.mem.Allocator, settings: writer.Options) !void {
            var output: [32]u8 = @splat(0xa5);
            const result = writer.encodeDestSizeInto(allocator, "bounded allocation payload\n" ** 100, &output, settings) catch |err| {
                try std.testing.expectEqualSlices(u8, &([_]u8{0xa5} ** 32), &output);
                return err;
            };
            try std.testing.expect(result.consumed > 0);
            try std.testing.expect(result.written <= output.len);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{writer.Options{}});
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{writer.Options{ .mode = .lazy, .dictionary_size = 128 * 1024 }});
}
