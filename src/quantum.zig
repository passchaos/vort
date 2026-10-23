const std = @import("std");
const codec = @import("cab/quantum.zig");
const encoder = @import("cab/quantum/encoder.zig");
const decoder = @import("cab/quantum/decoder.zig");

pub const Error = encoder.Error || codec.Error;
pub const Options = encoder.Options;
pub const Strategy = encoder.Strategy;
pub const Encoder = encoder.Encoder;
pub const PlanEncoder = codec.PlanEncoder;
pub const EncodeItem = codec.EncodeItem;
pub const EncodeSummary = encoder.Summary;
pub const Encoded = encoder.Encoded;
pub const LiteralEncoder = codec.LiteralEncoder;
pub const encodeAlloc = encoder.encodeAlloc;
pub const encodeWithSummaryAlloc = encoder.encodeWithSummaryAlloc;
pub const encodeInto = encoder.encodeInto;
pub const encodeAppend = encoder.encodeAppend;
pub const decodeAlloc = decoder.decodeAlloc;
pub const decodeInto = decoder.decodeInto;

pub fn decodeAllocLimited(allocator: std.mem.Allocator, input: []const u8, expected_output_len: usize, max_output_len: usize, window_bits: u5) Error![]u8 {
    if (expected_output_len > max_output_len) return error.OutputLimitExceeded;
    return decodeAlloc(allocator, input, expected_output_len, window_bits);
}

pub fn encodeLiteralAlloc(allocator: std.mem.Allocator, input: []const u8, window_bits: u5) Error![]u8 {
    return encodeAlloc(allocator, input, .{ .window_bits = window_bits, .strategy = .literals });
}

test {
    _ = codec;
    _ = encoder;
}

test "Quantum caller-owned decode and allocation limits share the codec" {
    const allocator = std.testing.allocator;
    const input = "Quantum caller-owned decoded output\n" ** 80;
    const encoded = try encodeAlloc(allocator, input, .{});
    defer allocator.free(encoded);
    var output: [input.len]u8 = undefined;
    try decodeInto(encoded, &output, 18);
    try std.testing.expectEqualSlices(u8, input, &output);
    try std.testing.expectError(error.OutputLimitExceeded, decodeAllocLimited(allocator, encoded, input.len, input.len - 1, 18));
}
