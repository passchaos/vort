const std = @import("std");
const writer = @import("micro_writer.zig");
const decoder = @import("decoder.zig");

test "MicroLZMA writer round trips empty tiny random and dictionary-wrapping input" {
    const allocator = std.testing.allocator;
    var random: [12 * 1024]u8 = undefined;
    var prng = std.Random.DefaultPrng.init(0x4d49_4352_4f);
    prng.random().bytes(&random);
    inline for (.{ "", "x", "MicroLZMA repeated payload\n" ** 1000 }) |input| {
        inline for (.{ .literal_only, .greedy, .lazy }) |mode| {
            const encoded = try writer.encodeAlloc(allocator, input, .{
                .mode = mode,
                .dictionary_size = 4096,
            });
            defer allocator.free(encoded);
            try std.testing.expectEqual(@as(u8, ~@as(u8, 0x5d)), encoded[0]);
            const decoded = try decoder.decodeMicroAllocExactSize(allocator, encoded, input.len, 4096);
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, input, decoded);
        }
    }
    inline for (.{
        writer.Options{ .properties = .{ .lc = 0, .lp = 4, .pb = 0 }, .dictionary_size = 4096 },
        writer.Options{ .properties = .{ .lc = 4, .lp = 0, .pb = 4 }, .dictionary_size = 128 * 1024 },
        writer.Options{ .properties = .{ .lc = 0, .lp = 4, .pb = 0 }, .dictionary_size = 65536, .mode = .lazy },
        writer.Options{ .dictionary_size = 128 * 1024, .mode = .lazy },
    }) |options| {
        const encoded = try writer.encodeAlloc(allocator, &random, options);
        defer allocator.free(encoded);
        const decoded = try decoder.decodeMicroAllocExactSize(allocator, encoded, random.len, options.dictionary_size);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, &random, decoded);
    }
}

test "MicroLZMA wide lazy writer preserves long distance matches" {
    const allocator = std.testing.allocator;
    const prefix_len = 80 * 1024;
    const repeated_len = 8192;
    const input = try allocator.alloc(u8, prefix_len + repeated_len);
    defer allocator.free(input);
    var prng = std.Random.DefaultPrng.init(0x5749_4445_4c41_5a59);
    prng.random().bytes(input[0..prefix_len]);
    @memcpy(input[prefix_len..], input[0..repeated_len]);
    const encoded = try writer.encodeAlloc(allocator, input, .{
        .dictionary_size = 128 * 1024,
        .mode = .lazy,
    });
    defer allocator.free(encoded);
    const decoded = try decoder.decodeMicroAllocExactSize(allocator, encoded, input.len, 128 * 1024);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
    try std.testing.expectError(error.InvalidLzmaStream, decoder.decodeMicroAllocExactSize(allocator, encoded, input.len, 4096));
}

test "MicroLZMA writer validates options and preserves output on errors" {
    const allocator = std.testing.allocator;
    var output: [256]u8 = @splat(0xa5);
    try std.testing.expectError(error.OutputTooSmall, writer.encodeInto(allocator, "payload", output[0..1], .{}));
    try std.testing.expectEqualSlices(u8, &([_]u8{0xa5} ** 256), &output);
    inline for (.{
        writer.Options{ .dictionary_size = 4095 },
        writer.Options{ .dictionary_size = std.math.maxInt(u32) },
        writer.Options{ .properties = .{ .lc = 4, .lp = 1 } },
        writer.Options{ .properties = .{ .pb = 5 } },
    }) |options| {
        try std.testing.expectError(error.InvalidLzmaOptions, writer.encodeInto(allocator, "payload", &output, options));
        try std.testing.expectEqualSlices(u8, &([_]u8{0xa5} ** 256), &output);
    }
    const length = try writer.encodeInto(allocator, "payload", &output, .{});
    const decoded = try decoder.decodeMicroAllocExactSize(allocator, output[0..length], 7, 32 * 1024);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings("payload", decoded);
    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    const appended_length = try writer.encodeAppend(allocator, &appended, "payload", .{});
    try std.testing.expectEqualSlices(u8, output[0..length], appended.items[7..]);
    try std.testing.expectEqual(length, appended_length);
}

test "MicroLZMA writer handles every allocation failure transactionally" {
    const Test = struct {
        fn run(allocator: std.mem.Allocator, options: writer.Options) !void {
            var output: std.ArrayList(u8) = .empty;
            defer output.deinit(allocator);
            try output.appendSlice(allocator, "prefix:");
            _ = writer.encodeAppend(allocator, &output, "allocation payload\n" ** 100, options) catch |err| {
                try std.testing.expectEqualStrings("prefix:", output.items);
                return err;
            };
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{writer.Options{}});
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{writer.Options{ .mode = .lazy, .dictionary_size = 128 * 1024 }});
}
