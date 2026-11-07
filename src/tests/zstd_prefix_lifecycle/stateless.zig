const std = @import("std");
const h = @import("helpers.zig");
const a = h.a;

pub fn contracts(comptime Z: type) !void {
    try std.testing.expectEqual(.persistent, (Z.FrameDecodeOptions{}).dictionary_usage);
    try std.testing.expectEqual(.persistent, (Z.FrameOptions{}).dictionary_usage);
    try std.testing.expectEqual(.persistent, (Z.NativeFrameOptions{}).dictionary_usage);
    for ([_]Z.FrameFormat{ .standard, .magicless }) |format| {
        const frame = try h.frame(Z, format);
        defer a.free(frame);
        const dictionary = Z.NativeDictionary.initRawContent(h.prefix);
        try h.missing(Z, frame, format);
        const options: Z.FrameDecodeOptions = .{ .format = format, .dictionary_usage = .prefix, .dictionary = dictionary };
        try h.wire.check(Z, a, frame, h.payload, options);
        const twice = try h.joined(frame, frame);
        defer a.free(twice);
        // One stateless call keeps its selected prefix for the whole input.
        try h.check(Z, twice, h.payload ** 2, options);
        if (format == .standard) {
            const skip = try Z.encodeSkippableFrameAlloc(a, 3, "metadata");
            defer a.free(skip);
            const with_skip = try h.joined(skip, frame);
            defer a.free(with_skip);
            try h.check(Z, with_skip, h.payload, options);
        }
        const persistent = try Z.encodeNativeFrameWithDictionaryAlloc(a, h.payload, .{ .format = format, .selection = .literal_only, .include_dictionary_id = false }, dictionary);
        defer a.free(persistent.frame);
        try std.testing.expectEqualSlices(u8, persistent.frame, frame);
        // Level mapping must retain the usage policy independently of wire ID.
        const mapped = try Z.nativeFrameOptionsForLevel(-3, .{ .dictionary_usage = .prefix });
        try std.testing.expectEqual(.prefix, mapped.dictionary_usage);
    }
    try full(Z);
}

fn full(comptime Z: type) !void {
    const bytes = try h.memory.hexAlloc(@embedFile("../../zstd/testdata/libzstd-trained-repeat.dict.hex"));
    defer a.free(bytes);
    const frame = try h.memory.hexAlloc(@embedFile("../../zstd/testdata/libzstd-trained-repeat.frame.hex"));
    defer a.free(frame);
    const dictionary = (try Z.NativeDictionary.initFromStandardDictionary(bytes)).dictionary;
    var prepared = try Z.PreparedDecodeDictionary.init(dictionary);
    const expected = try Z.decodeFrameAllocWithOptions(a, frame, .{ .dictionary = dictionary });
    defer a.free(expected);
    for ([_]Z.FrameFormat{ .standard, .magicless }) |format| {
        const input = if (format == .standard) frame else frame[4..];
        try h.check(Z, input, expected, .{ .format = format, .dictionary_usage = .prefix, .dictionary = prepared.handle() });
        const encoded = try Z.encodeNativeFrameWithDictionaryAlloc(a, expected, .{ .format = format, .dictionary_usage = .prefix, .include_dictionary_id = false, .selection = .literal_only, .match_search_budget = 0 }, prepared.handle());
        defer a.free(encoded.frame);
        try std.testing.expectEqual(@as(u32, 0), (try h.wire.header(encoded.frame, format == .magicless)).dictionary_id);
        try h.check(Z, encoded.frame, expected, .{ .format = format, .dictionary_usage = .prefix, .dictionary = prepared.handle() });
        try std.testing.expectEqual(dictionary.id, prepared.handle().id);
        try std.testing.expectEqualSlices(u8, bytes, prepared.handle().standard_bytes.?);
    }
}
