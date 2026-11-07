//! A compact exercise of the public RAW prefix conveniences.
const std = @import("std");
const h = @import("helpers.zig");
const a = h.a;

pub fn contracts(comptime Z: type) !void {
    const options: Z.NativeFrameOptions = .{ .selection = .literal_only };
    const encoded = try Z.encodeNativeFrameWithPrefixAlloc(a, h.payload, options, h.prefix);
    defer a.free(encoded.frame);
    try std.testing.expect(encoded.frame.len <= try Z.encodedNativeFrameBoundWithPrefix(h.payload.len, options, h.prefix));
    try h.missing(Z, encoded.frame, .standard);
    const decode_options: Z.FrameDecodeOptions = .{ .expected_output_len = h.payload.len, .dictionary = Z.NativeDictionary.init(42, "replaced persistent history") };
    const decoded = try Z.decodeFrameAllocWithPrefix(a, encoded.frame, decode_options, h.prefix);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, h.payload, decoded);
    try std.testing.expectEqual(h.payload.len, try Z.decodedFrameSizeWithPrefix(encoded.frame, decode_options, h.prefix));
    var output: [h.payload.len + 17]u8 = @splat(0xa5);
    const decoded_len = try Z.decodeFrameIntoWithPrefix(a, encoded.frame, output[0..h.payload.len], decode_options, h.prefix);
    try std.testing.expectEqualSlices(u8, h.payload, output[0..decoded_len]);
    try h.wire.untouched(output[decoded_len..]);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(a);
    try out.appendSlice(a, "caller-prefix");
    try std.testing.expectEqual(h.payload.len, try Z.decodeFrameAppendWithPrefix(a, &out, encoded.frame, decode_options, h.prefix));
    try std.testing.expectEqualSlices(u8, h.payload, out.items[13..]);
    out.shrinkRetainingCapacity(13);
    try Z.encodeNativeFrameAppendWithPrefix(a, &out, h.payload, options, h.prefix);
    try std.testing.expectEqualSlices(u8, encoded.frame, out.items[13..]);
    const wire_output = try a.alloc(u8, encoded.frame.len + 17);
    defer a.free(wire_output);
    @memset(wire_output, 0xa5);
    const encoded_into = try Z.encodeNativeFrameIntoSliceWithPrefix(a, h.payload, options, h.prefix, wire_output);
    try std.testing.expectEqualSlices(u8, encoded.frame, wire_output[0..encoded_into.written]);
    try h.wire.untouched(wire_output[encoded_into.written..]);

    const default_frame = try Z.encodeFrameWithPrefixAlloc(a, h.payload, h.prefix);
    defer a.free(default_frame);
    const configured = try Z.encodeFrameWithOptionsAndPrefixAlloc(a, h.payload, .{}, h.prefix);
    defer a.free(configured);
    try std.testing.expectEqualSlices(u8, default_frame, configured);
    const signed = try Z.encodeFrameWithLevelAndOptionsAndPrefixAlloc(a, h.payload, -3, .{ .content_checksum = true }, h.prefix);
    defer a.free(signed);
    const signed_payload = try Z.decodeFrameAllocWithPrefix(a, signed, .{}, h.prefix);
    defer a.free(signed_payload);
    try std.testing.expectEqualSlices(u8, h.payload, signed_payload);
}
