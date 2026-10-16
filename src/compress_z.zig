const decoder = @import("compress_z/decoder.zig");
const encoder = @import("compress_z/encoder.zig");
const incremental_decoder = @import("compress_z/incremental_decoder.zig");
const incremental_tests = @import("compress_z/incremental_tests.zig");

pub const Error = decoder.Error || encoder.Error || incremental_decoder.Decoder.Error;
pub const Header = decoder.Header;
pub const EncodeOptions = encoder.EncodeOptions;
pub const IncrementalDecoder = incremental_decoder.Decoder;
pub const parseHeader = decoder.parseHeader;
pub const decodeInto = decoder.decodeInto;
pub const decodeAlloc = decoder.decodeAlloc;
pub const decodeAllocLimited = decoder.decodeAllocLimited;
pub const decodedSize = decoder.decodedSize;
pub const decodedSizeLimited = decoder.decodedSizeLimited;
pub const encodeAlloc = encoder.encodeAlloc;
pub const encodeAppend = encoder.encodeAppend;
pub const encodeInto = encoder.encodeInto;

test {
    _ = decoder;
    _ = encoder;
    _ = incremental_decoder;
    _ = incremental_tests;
}

test "Unix compress encoder round trips width growth block clears and non-block mode" {
    const std = @import("std");
    const allocator = std.testing.allocator;
    var random_bytes: [12 * 1024]u8 = undefined;
    var prng = std.Random.DefaultPrng.init(0xc0_6d_70_72_65_73_73);
    prng.random().bytes(&random_bytes);
    const cases = [_]struct {
        input: []const u8,
        options: EncodeOptions,
    }{
        .{ .input = "", .options = .{} },
        .{ .input = "TOBEORNOTTOBEORTOBEORNOT", .options = .{ .block_mode = false, .max_code_bits = 12 } },
        .{ .input = "compress-z repetitive payload " ** 256, .options = .{} },
        .{ .input = &random_bytes, .options = .{ .max_code_bits = 10 } },
        .{ .input = &random_bytes, .options = .{ .max_code_bits = 9 } },
    };

    for (cases) |case| {
        const encoded = try encodeAlloc(allocator, case.input, case.options);
        defer allocator.free(encoded);
        const decoded = try decodeAlloc(allocator, encoded);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, case.input, decoded);
        try std.testing.expectEqual(case.input.len, try decodedSize(allocator, encoded));
        if (case.input.len != 0)
            try std.testing.expectError(
                error.OutputLimitExceeded,
                decodeAllocLimited(allocator, encoded, case.input.len - 1),
            );
    }
}

test "Unix compress decoder accepts an ncompress 5.0 stream" {
    const std = @import("std");
    const encoded_hex = "1f9d8c549e0829f2448a932754020e2ca890a04184";
    var encoded: [encoded_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&encoded, encoded_hex);
    const decoded = try decodeAlloc(std.testing.allocator, &encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "TOBEORNOTTOBEORTOBEORNOT", decoded);

    const reencoded = try encodeAlloc(std.testing.allocator, decoded, .{ .max_code_bits = 12 });
    defer std.testing.allocator.free(reencoded);
    try std.testing.expectEqualSlices(u8, &encoded, reencoded);
}

test "Unix compress caller-owned and append APIs are transactional" {
    const std = @import("std");
    const allocator = std.testing.allocator;
    const input = "caller-owned Unix compress output " ** 64;
    const encoded = try encodeAlloc(allocator, input, .{});
    defer allocator.free(encoded);

    const output = try allocator.alloc(u8, encoded.len);
    defer allocator.free(output);
    try std.testing.expectEqual(encoded.len, try encodeInto(allocator, input, output, .{}));
    try std.testing.expectEqualSlices(u8, encoded, output);
    try std.testing.expectError(error.OutputTooSmall, encodeInto(allocator, input, output[0 .. output.len - 1], .{}));

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    const prefix_len = appended.items.len;
    try std.testing.expectEqual(encoded.len, try encodeAppend(allocator, &appended, input, .{}));
    try std.testing.expectEqualSlices(u8, "prefix:", appended.items[0..prefix_len]);
    try std.testing.expectEqualSlices(u8, encoded, appended.items[prefix_len..]);

    const before = try allocator.dupe(u8, appended.items);
    defer allocator.free(before);
    try std.testing.expectError(
        error.InvalidCompressHeader,
        encodeAppend(allocator, &appended, input, .{ .max_code_bits = 8 }),
    );
    try std.testing.expectEqualSlices(u8, before, appended.items);
}

test "Unix compress decoder rejects invalid codes and enforces caller buffers" {
    const std = @import("std");
    const allocator = std.testing.allocator;
    const invalid = [_]u8{ 0x1f, 0x9d, 0x90, 0x00, 0x03 };
    try std.testing.expectError(error.InvalidCompressStream, decodeAlloc(allocator, &invalid));

    const input = "bounded output" ** 32;
    const encoded = try encodeAlloc(allocator, input, .{});
    defer allocator.free(encoded);
    var output: [32]u8 = undefined;
    try std.testing.expectError(error.OutputTooSmall, decodeInto(allocator, encoded, &output));
}
