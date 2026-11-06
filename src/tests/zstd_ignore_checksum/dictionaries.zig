const std = @import("std");
const h = @import("helpers.zig");
const a = h.a;

pub fn contracts(comptime Z: type) !void {
    const dictionary = Z.NativeDictionary.init(42, h.plain);
    const entries = [_]Z.NativeDictionary{ dictionary, Z.NativeDictionary.init(77, "unselected") };
    const set = Z.NativeDictionarySet.init(&entries);
    for ([_]Z.FrameFormat{ .standard, .magicless }) |format| {
        const encoded = try Z.encodeNativeFrameWithDictionaryAlloc(a, h.plain ** 2, .{ .format = format, .content_checksum = true, .strategy = .fast }, dictionary);
        defer a.free(encoded.frame);
        for ([_]Z.FrameDecodeOptions{
            .{ .format = format, .dictionary = dictionary },
            .{ .format = format, .dictionary_set = set },
        }) |options| {
            try @import("publication.zig").sampleContracts(Z, encoded.frame, h.plain ** 2, options);
            try @import("reusable.zig").sampleContracts(Z, encoded.frame, h.plain ** 2, options);
            try @import("incremental.zig").dictionaryContracts(Z, encoded.frame, h.plain ** 2, options);
        }
        const bad = try h.corrupt(encoded.frame);
        defer a.free(bad);
        try std.testing.expectError(error.NeedDictionary, Z.decodeFrameAllocWithOptions(a, bad, .{ .format = format, .ignore_content_checksum = true }));
        try std.testing.expectError(error.NeedDictionary, Z.decodeFrameAllocWithOptions(a, bad, .{ .format = format, .ignore_content_checksum = true, .dictionary = entries[1] }));
        try std.testing.expectError(error.NeedDictionary, Z.decodeFrameAllocWithOptions(a, bad, .{ .format = format, .ignore_content_checksum = true, .dictionary_set = Z.NativeDictionarySet.init(entries[1..]) }));
        try std.testing.expectError(error.InvalidBlockPlan, Z.decodeFrameAllocWithOptions(a, bad, .{ .format = format, .ignore_content_checksum = true, .dictionary = dictionary, .dictionary_set = set }));
    }
}
