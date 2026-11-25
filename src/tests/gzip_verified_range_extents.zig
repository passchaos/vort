//! A valid replacement gzip member must still match the indexed extents.
const std = @import("std");
const t = std.testing;

const FixtureSource = struct {
    bytes: []const u8,

    fn readAt(raw: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
        const self: *FixtureSource = @ptrCast(@alignCast(raw));
        if (offset >= self.bytes.len or output.len == 0) return 0;
        output[0] = self.bytes[@intCast(offset)];
        return 1;
    }
};

pub fn contracts(comptime V: type) !void {
    const a = t.allocator;
    const wire = try V.encodeGzipStoredWithHeaderAlloc(a, "abcd", .{ .filename = "x" });
    defer a.free(wire);
    const shorter = try V.encodeGzipStoredWithHeaderAlloc(a, "abcd", .{});
    defer a.free(shorter);
    const less_plaintext = try V.encodeGzipStoredWithHeaderAlloc(a, "abc", .{ .filename = "xy" });
    defer a.free(less_plaintext);
    try t.expect(shorter.len < wire.len);
    try t.expectEqual(wire.len, less_plaintext.len);

    var source: FixtureSource = .{ .bytes = wire };
    var entries: [1]V.GzipSourceIndexEntry = undefined;
    var history: [32 * 1024]u8 = undefined;
    var page: [1]u8 = undefined;
    var discard: [2]u8 = undefined;
    const workspace: V.GzipSourceIndexWorkspace = .{ .history = &history, .input_page = &page, .discard = &discard };
    const index = try V.buildGzipSourceIndex(.{
        .context = &source,
        .len = wire.len,
        .read_at = FixtureSource.readAt,
    }, &entries, &.{}, workspace, .{});
    var output: [1]u8 = @splat(0xa5);
    var stage: [1]u8 = undefined;
    try t.expect(index.decodeVerifiedRangeInto(1, &output, workspace, &stage) == .complete);
    try t.expectEqualStrings("b", &output);

    // Simulate a backing source that returns a different but legal member.
    // A one-byte page exposes a short member end before any following bytes.
    for ([_][]const u8{ shorter, less_plaintext }) |replacement| {
        @memcpy(wire[0..replacement.len], replacement);
        output[0] = 0xa5;
        const result = index.decodeVerifiedRangeInto(1, &output, workspace, &stage);
        try t.expect(result == .failed);
        try t.expectEqual(error.SizeMismatch, result.failed.err);
        try t.expectEqual(@as(usize, 0), result.failed.progress.output_written);
        try t.expectEqual(@as(V.StreamCount, 1), result.failed.progress.next_decoded_offset);
        try t.expectEqual(@as(u8, 0xa5), output[0]);
    }
}
