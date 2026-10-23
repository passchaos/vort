const std = @import("std");
const decoder = @import("cab/lzx.zig");
const encoder = @import("cab/lzx/encoder.zig");

pub const Error = decoder.Error || encoder.Error;
pub const StreamFormat = decoder.StreamFormat;
pub const Options = struct { window_bits: u5 = 15, format: StreamFormat = .cabinet };
pub const CabinetEncoder = encoder.CabinetEncoder;
pub const EncodedBlock = encoder.EncodedBlock;
pub const EncodeSummary = encoder.Summary;
pub const BlockType = encoder.BlockType;
pub const decodeAlloc = decoder.decodeAlloc;
pub const decodeAllocWithFormat = decoder.decodeAllocWithFormat;
pub const decodeInto = decoder.decodeInto;
pub const encodeWimChunkAlloc = encoder.encodeWimChunkAlloc;
pub const encodeWimReferenceChunkAlloc = encoder.encodeWimReferenceChunkAlloc;

pub fn decodeAllocLimited(allocator: std.mem.Allocator, input: []const u8, expected_output_len: usize, max_output_len: usize, options: Options) Error![]u8 {
    if (expected_output_len > max_output_len) return error.OutputLimitExceeded;
    return decodeAllocWithFormat(allocator, input, expected_output_len, options.window_bits, options.format);
}

pub fn encodeAlloc(allocator: std.mem.Allocator, input: []const u8, options: Options) Error![]u8 {
    var state = try CabinetEncoder.init(options.window_bits);
    if (options.format == .wim) return encodeWimChunkAlloc(allocator, input, options.window_bits);
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    var start: usize = 0;
    while (start < input.len) {
        const end = start + @min(input.len - start, 32768);
        const block = try state.encodeBlockAlloc(allocator, input, start, end);
        defer allocator.free(block);
        try output.appendSlice(allocator, block);
        start = end;
    }
    return output.toOwnedSlice(allocator);
}

pub fn encodeInto(allocator: std.mem.Allocator, input: []const u8, output: []u8, options: Options) Error!usize {
    const encoded = try encodeAlloc(allocator, input, options);
    defer allocator.free(encoded);
    if (encoded.len > output.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

pub fn encodeAppend(allocator: std.mem.Allocator, output: *std.ArrayList(u8), input: []const u8, options: Options) Error!usize {
    const encoded = try encodeAlloc(allocator, input, options);
    defer allocator.free(encoded);
    try output.appendSlice(allocator, encoded);
    return encoded.len;
}

test {
    _ = decoder;
    _ = encoder;
}

test "LZX public caller buffers and output limits preserve explicit ownership" {
    const allocator = std.testing.allocator;
    const input = "LZX public allocating and caller buffer surfaces\n" ** 200;
    const encoded = try encodeAlloc(allocator, input, .{});
    defer allocator.free(encoded);
    var output: [input.len]u8 = undefined;
    try decodeInto(encoded, &output, 15, .cabinet);
    try std.testing.expectEqualSlices(u8, input, &output);
    try std.testing.expectError(error.OutputLimitExceeded, decodeAllocLimited(allocator, encoded, input.len, input.len - 1, .{}));
    var small: [1]u8 = .{0xa5};
    try std.testing.expectError(error.OutputTooSmall, encodeInto(allocator, input, &small, .{}));
    try std.testing.expectEqual(@as(u8, 0xa5), small[0]);
    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix");
    try std.testing.expectEqual(encoded.len, try encodeAppend(allocator, &appended, input, .{}));
    try std.testing.expectEqualSlices(u8, encoded, appended.items[6..]);
    try std.testing.expectError(error.InvalidBlockPlan, encodeAlloc(allocator, input, .{ .window_bits = 14 }));
    try std.testing.expectError(error.InvalidBlockPlan, encodeAlloc(allocator, "", .{ .format = .wim }));
}
