const std = @import("std");
pub const memory = @import("../zstd_decode_memory/helpers.zig");
pub const wire = @import("../zstd_magicless_helpers.zig");
pub const a = std.testing.allocator;
pub const prefix = "abcdefghijklmnop-0123456789-prefix-history-that-remains-external\n" ** 4;
pub const payload = prefix;

pub fn frame(comptime Z: type, format: Z.FrameFormat) ![]u8 {
    const result = try Z.encodeNativeFrameWithDictionaryAlloc(a, payload, .{ .format = format, .dictionary_usage = .prefix, .include_dictionary_id = false, .selection = .literal_only }, Z.NativeDictionary.initRawContent(prefix));
    return result.frame;
}

pub fn joined(first: []const u8, second: []const u8) ![]u8 {
    const result = try a.alloc(u8, first.len + second.len);
    @memcpy(result[0..first.len], first);
    @memcpy(result[first.len..], second);
    return result;
}

pub fn pending(snapshot: anytype, id: u32, comptime full: bool) !void {
    try std.testing.expectEqual(.pending, snapshot.phase);
    try std.testing.expect(snapshot.pending and !snapshot.active);
    try std.testing.expectEqual(@as(?u32, id), snapshot.dictionary_id);
    try std.testing.expectEqual(if (full) .full else .raw, snapshot.content_type.?);
    try std.testing.expectEqual(.none, snapshot.used_for);
}

pub fn active(snapshot: anytype, purpose: anytype) !void {
    try std.testing.expectEqual(.active, snapshot.phase);
    try std.testing.expect(snapshot.active and !snapshot.pending and !snapshot.setter_eligible);
    try std.testing.expectEqual(purpose, snapshot.used_for);
}

pub fn cleared(snapshot: anytype) !void {
    try std.testing.expectEqual(.none, snapshot.phase);
    try std.testing.expect(!snapshot.pending and !snapshot.active);
    try std.testing.expect(snapshot.dictionary_id == null and snapshot.content_type == null);
}

pub fn missing(comptime Z: type, frame_bytes: []const u8, format: Z.FrameFormat) !void {
    try missingAlloc(Z.decodeFrameAllocWithOptions(a, frame_bytes, .{ .format = format }));
}

pub fn missingAlloc(result: anytype) !void {
    if (result) |unexpected| {
        a.free(unexpected);
        return error.ExpectedPrefixDependency;
    } else |err| try missingError(err);
}

pub fn missingDriven(result: anytype) !void {
    if (result) |unexpected| {
        a.free(unexpected.output);
        return error.ExpectedPrefixDependency;
    } else |err| try missingError(err);
}

fn missingError(err: anyerror) !void {
    try std.testing.expect(err == error.CorruptFrame or err == error.ChecksumMismatch or err == error.InvalidMatch);
}

pub fn check(comptime Z: type, frame_bytes: []const u8, expected: []const u8, options: Z.FrameDecodeOptions) !void {
    const result = try Z.decodeFrameAllocWithOptions(a, frame_bytes, options);
    defer a.free(result);
    try std.testing.expectEqualSlices(u8, expected, result);
}
