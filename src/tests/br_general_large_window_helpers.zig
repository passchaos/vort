//! Independent archived standard wires and small shared QA utilities.
const std = @import("std");
const br = @import("../br.zig");
const existing = @import("br_large_window_helpers.zig");
pub const plain = "general large window: time value abcdefghabcdefghXabcdefgh tail!\n" ** 2;
pub const TrackingAllocator = existing.TrackingAllocator;
pub const drive = existing.drive;
pub const extensionWindow = existing.extensionWindow;
pub const ordinaryWindow = existing.ordinaryWindow;
pub const untouched = existing.untouched;
pub const Golden = struct { quality: ?u4 = null, mode: br.PlannedMode = .generic, level: br.PlannedCompressionLevel = .fast, stored_window: ?u5 = null, hex: []const u8 };
// Captured by the public one-shot API from git archive fa35a843, before this
// branch's production changes. Original source and probe are retained in /tmp.
pub const goldens = [_]Golden{
    .{ .quality = 0, .mode = .generic, .hex = "1008000000a95b1ea38ab12885ed737d923292653080ffeedf7fd7de734ea29ae4fe18f617370e0e0e1e3c38733e896af0e2c587c562b18e49bfaac562b1582c160b10ea8c484569140e0bed247b4ff0dd0506263735cf00ed1af6ee8b563da09ffb03b1a8c1238f07bf4f86292dae3e8f483e72" },
    .{ .quality = 0, .mode = .text, .hex = "1008000000a95b1ea38ab12885ed737d923292653080ffeedf7fd7de734ea29ae4fe18f617370e0e0e1e3c38733e896af0e2c587c562b18e49bfaac562b1582c160b10ea8c484569140e0bed247b4ff0dd0506263735cf00ed1af6ee8b563da09ffb03b1a8c1238f07bf4f86292dae3e8f483e72" },
    .{ .quality = 0, .mode = .font, .hex = "1008000000a95b1ea38ab12885ed737d923292653080ffeedf7fd7de734ea29ae4fe18f617370e0e0e1e3c38733e896af0e2c587c562b18e49bfaac562b1582c160b10ea8c484569140e0bed247b4ff0dd0506263735cf00ed1af6ee8b563da09ffb03b1a8c1238f07bf4f86292dae3e8f483e72" },
    .{ .quality = 1, .mode = .generic, .hex = "1008000000aa9bc7a8622c4a610b2f63c938c9b37fb00127b1cf1a4e38200e1b70035fd0cfd43518080e13ca7bfbeb40fa272cc61478dd4d8fbd1f4f6091f4d8b74872" },
    .{ .quality = 1, .mode = .text, .hex = "1008000000aa9bc7a8622c4a610b2f63c938c9b37fb00127b1cf1a4e38200e1b70035fd0cfd43518080e13ca7bfbeb40fa272cc61478dd4d8fbd1f4f6091f4d8b74872" },
    .{ .quality = 1, .mode = .font, .hex = "1008000000aa9bc7a8622c4a610b2f63c938c9b37fb00127b1cf1a4e38200e1b70035fd0cfd43518080e13ca7bfbeb40fa272cc61478dd4d8fbd1f4f6091f4d8b74872" },
    .{ .quality = 2, .mode = .generic, .hex = "1008003c009d8cba92a84df51e9b0836e080fd5e479c7570c8091650fadd8b62c009bf0923150010631e598d49b59ffcb627845a0d" },
    .{ .quality = 2, .mode = .text, .hex = "1008003c009d8cba92a84df51e9b0836e080fd5e479c7570c8091650fadd8b62c009bf0923150010631e598d49b59ffcb627845a0d" },
    .{ .quality = 2, .mode = .font, .hex = "1008003c009d8cba92a84df51e9b0836e080fd5e479c7570c8091650fadd8b62c009bf0923150010631e598d49b59ffcb627845a0d" },
    .{ .quality = 3, .mode = .generic, .hex = "1008003c002d0e3da1524bbf31eec260030ed8ef75c45507879c6001a5dfbd28069cf09b3052010031308fac9e54fbcb8f3da1d5" },
    .{ .quality = 3, .mode = .text, .hex = "1008003c002d0e3da1524bbf31eec260030ed8ef75c45507879c6001a5dfbd28069cf09b3052010031308fac9e54fbcb8f3da1d5" },
    .{ .quality = 3, .mode = .font, .hex = "1008003c002d0e3da1524bbf31eec260030ed8ef75c45507879c6001a5dfbd28069cf09b3052010031308fac9e54fbcb8f3da1d5" },
    .{ .quality = 4, .mode = .generic, .hex = "2210003c002d0e3da1524bbf31eec260030ed8ef75c45507879c6001a5dfbd28069cf09b3052010031308fac9e54fbcb8f3da115" },
    .{ .quality = 4, .mode = .text, .hex = "2210003c002d0e3da1524bbf31eec260030ed8ef75c45507879c6001a5dfbd28069cf09b3052010031308fac9e54fbcb8f3da115" },
    .{ .quality = 4, .mode = .font, .hex = "2210003c002d0e3da1524bbf31eec260030ed8ef75c45507879c6001a5dfbd28069cf09b3052010031308fac9e54fbcb8f3da115" },
    .{ .quality = 5, .mode = .generic, .hex = "2210003c002d0e3da1524bbf31eec260030ed8ef75c45507879c6001a5dfbd28069cf09b3052010031308fac9e54fbcb8f3da115" },
    .{ .quality = 5, .mode = .text, .hex = "2210003c002d0e3da1524bbf31eec260030ed8ef75c45507879c6001a5dfbd28069cf09b3052010031308fac9e54fbcb8f3da115" },
    .{ .quality = 5, .mode = .font, .hex = "2210003c002d0e3da1524bbf31eec260030ed8ef75c45507879c6001a5dfbd28069cf09b3052010031308fac9e54fbcb8f3da115" },
    .{ .quality = 6, .mode = .generic, .hex = "2210003c002d0e3da1524bbf31eec260030ed8ef75c45507879c6001a5dfbd28069cf09b3052010031308fac9e54fbcb8f3da115" },
    .{ .quality = 6, .mode = .text, .hex = "2210003c002d0e3da1524bbf31eec260030ed8ef75c45507879c6001a5dfbd28069cf09b3052010031308fac9e54fbcb8f3da115" },
    .{ .quality = 6, .mode = .font, .hex = "2210003c002d0e3da1524bbf31eec260030ed8ef75c45507879c6001a5dfbd28069cf09b3052010031308fac9e54fbcb8f3da115" },
    .{ .quality = 7, .mode = .generic, .hex = "2210003c002d0e3da1524bbf31eec260030ed8ef75c45507879c6001a5dfbd28069cf09b3052010031308fac9e54fbcb8f3da115" },
    .{ .quality = 7, .mode = .text, .hex = "2210003c002d0e3da1524bbf31eec260030ed8ef75c45507879c6001a5dfbd28069cf09b3052010031308fac9e54fbcb8f3da115" },
    .{ .quality = 7, .mode = .font, .hex = "2210003c002d0e3da1524bbf31eec260030ed8ef75c45507879c6001a5dfbd28069cf09b3052010031308fac9e54fbcb8f3da115" },
    .{ .quality = 8, .mode = .generic, .hex = "2210003c002d0e3da1524bbf31eec260030ed8ef75c45507879c6001a5dfbd28069cf09b3052010031308fac9e54fbcb8f3da115" },
    .{ .quality = 8, .mode = .text, .hex = "2210003c002d0e3da1524bbf31eec260030ed8ef75c45507879c6001a5dfbd28069cf09b3052010031308fac9e54fbcb8f3da115" },
    .{ .quality = 8, .mode = .font, .hex = "2210003c002d0e3da1524bbf31eec260030ed8ef75c45507879c6001a5dfbd28069cf09b3052010031308fac9e54fbcb8f3da115" },
    .{ .quality = 9, .mode = .generic, .hex = "2210003c002d0e3da1524bbf31eec260030ed8ef75c45507879c6001a5dfbd28069cf09b3052010031308fac9e54fbcb8f3da115" },
    .{ .quality = 9, .mode = .text, .hex = "2210003c002d0e3da1524bbf31eec260030ed8ef75c45507879c6001a5dfbd28069cf09b3052010031308fac9e54fbcb8f3da115" },
    .{ .quality = 9, .mode = .font, .hex = "2210003c002d0e3da1524bbf31eec260030ed8ef75c45507879c6001a5dfbd28069cf09b3052010031308fac9e54fbcb8f3da115" },
    .{ .quality = 10, .mode = .generic, .hex = "2210003c002d0e3da1524bbf31eec260030ed8ef75c45507879c6001a5dfbd28069cf09b3052010031308fac9e54fbcb8f3da115" },
    .{ .quality = 10, .mode = .text, .hex = "2210003c002d0e3da1524bbf31eec260030ed8ef75c45507879c6001a5dfbd28069cf09b3052010031308fac9e54fbcb8f3da115" },
    .{ .quality = 10, .mode = .font, .hex = "2210003c002d0e3da1524bbf31eec260030ed8ef75c45507879c6001a5dfbd28069cf09b3052010031308fac9e54fbcb8f3da115" },
    .{ .quality = 11, .mode = .generic, .hex = "2210003c002d0e3da1524bbf31eec260030ed8ef75c45507879c6001a5dfbd28069cf09b3052010031308fac9e54fbcb8f3da115" },
    .{ .quality = 11, .mode = .text, .hex = "2210003c002d0e3da1524bbf31eec260030ed8ef75c45507879c6001a5dfbd28069cf09b3052010031308fac9e54fbcb8f3da115" },
    .{ .quality = 11, .mode = .font, .hex = "2210003c002d0e3da1524bbf31eec260030ed8ef75c45507879c6001a5dfbd28069cf09b3052010031308fac9e54fbcb8f3da115" },
    .{ .level = .fast, .hex = "2210003c00e9667e46dd8c9d52b3b77194260512c2938edc63525e30a6cfd43418080e138eb7d4cf83e955d88c25f0fb93b215deba98f4b8af0b" },
    .{ .level = .balanced, .hex = "2210003c00e9667e46dd8c9d52b3b77194260512c2938edc63525e30a6cfd43418080e138eb7d4cf83e955d88c25f0fb93b215deba98f4b8af0b" },
    .{ .level = .ratio, .hex = "2210003c002d0e3da1524bbf31eec260030ed8ef75c45507879c6001a5dfbd28069cf09b3052010031308fac9e54fbcb8f3da115" },
    .{ .stored_window = 16, .hex = "10081067656e6572616c206c617267652077696e646f773a2074696d652076616c75652061626364656667686162636465666768586162636465666768207461696c210a67656e6572616c206c617267652077696e646f773a2074696d652076616c75652061626364656667686162636465666768586162636465666768207461696c210a03" },
    .{ .stored_window = 24, .hex = "8f408067656e6572616c206c617267652077696e646f773a2074696d652076616c75652061626364656667686162636465666768586162636465666768207461696c210a67656e6572616c206c617267652077696e646f773a2074696d652076616c75652061626364656667686162636465666768586162636465666768207461696c210a03" },
};
pub fn goldenAlloc(a: std.mem.Allocator, golden: Golden) ![]u8 {
    const bytes = try a.alloc(u8, golden.hex.len / 2);
    errdefer a.free(bytes);
    _ = try std.fmt.hexToBytes(bytes, golden.hex);
    return bytes;
}
pub fn checkExtended(a: std.mem.Allocator, wire: []const u8, input: []const u8, width: u5, shared: br.SharedDictionary) !br.StreamSummary {
    try std.testing.expectEqual(width, try extensionWindow(wire));
    try std.testing.expectError(error.CorruptFrame, br.decodeStreamAllocExactSizeWithOptions(a, wire, input.len, .{ .shared_dictionary = shared }));
    const options = br.DecodeOptions{ .allow_large_window = true, .shared_dictionary = shared };
    const decoded = try br.decodeStreamAllocExactSizeWithOptions(a, wire, input.len, options);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
    const summary = try br.summarizeStreamAllocLimitedWithOptions(a, wire, input.len, options);
    try std.testing.expect(summary.large_window);
    try std.testing.expectEqual(width, summary.window_bits);
    try std.testing.expectEqual(input.len, summary.decoded_bytes);
    try std.testing.expect(summary.max_lz77_distance <= (@as(usize, 1) << width) - 16);
    return summary;
}
pub fn feed(a: std.mem.Allocator, encoder: anytype, wire: *std.ArrayList(u8), input: []const u8) !void {
    var scratch: [3]u8 = undefined;
    var offset: usize = 0;
    while (offset != input.len) {
        const result = try encoder.step(input[offset..@min(input.len, offset + 7)], &scratch);
        offset += result.progress.input_read;
        try wire.appendSlice(a, scratch[0..result.progress.output_written]);
        try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
}
pub fn drain(a: std.mem.Allocator, encoder: anytype, wire: *std.ArrayList(u8), status: @import("../core.zig").StepResult.Status) !void {
    var scratch: [3]u8 = undefined;
    while (true) {
        const result = try encoder.step("", &scratch);
        try wire.appendSlice(a, scratch[0..result.progress.output_written]);
        if (result.status == status) return;
        try std.testing.expectEqual(.need_output, result.status);
        try std.testing.expect(result.progress.output_written != 0);
    }
}
