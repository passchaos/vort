//! A prefix binds to the first frame in a stateless seekable operation.
const std = @import("std");
const h = @import("helpers.zig");
const a = h.a;

pub fn contracts(comptime Z: type) !void {
    const options: Z.NativeSeekableOptions = .{ .frame_size = h.prefix.len, .frame_options = .{ .selection = .literal_only, .dictionary_usage = .prefix } };
    const input = h.prefix ** 2;
    const dictionary = Z.NativeDictionary.initRawContent(h.prefix);
    const stream = try Z.encodeNativeSeekableStreamWithDictionaryAlloc(a, input, options, dictionary);
    defer a.free(stream);
    const parallel = try Z.encodeNativeSeekableStreamParallelWithDictionaryAlloc(a, input, options, dictionary, 2);
    defer a.free(parallel);
    try std.testing.expectEqualSlices(u8, stream, parallel);
    var members = Z.iterateNativeStream(stream);
    const first = (try members.next()).?.frame;
    const second = (try members.next()).?.frame;
    try std.testing.expectEqual(@as(?u64, h.prefix.len), first.header.content_size);
    try std.testing.expectEqual(@as(?u64, h.prefix.len), second.header.content_size);
    try h.missing(Z, first.bytes, .standard);
    try h.check(Z, first.bytes, h.prefix, .{ .dictionary = dictionary });
    try h.check(Z, second.bytes, h.prefix, .{});
    const independent = try Z.encodeNativeFrameWithOptionsAlloc(a, h.prefix, .{ .selection = .literal_only });
    defer a.free(independent.frame);
    try std.testing.expectEqualSlices(u8, independent.frame, second.bytes);
    const table = try Z.inspectNativeSeekTable(stream);
    try std.testing.expectEqual(@as(u32, 2), table.entry_count);
    try std.testing.expectEqual(@as(u64, input.len), table.decompressed_size);
}
