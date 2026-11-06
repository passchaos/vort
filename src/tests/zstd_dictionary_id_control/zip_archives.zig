//! Called from root tests, where the ZIP crypto module dependency is available.
const std = @import("std");
const h = @import("helpers.zig");
const a = h.a;

pub fn contracts(comptime Zip: type, comptime Z: type) !void {
    const dictionary = Z.NativeDictionary.init(h.id, h.plain);
    const entries = [_]Zip.EncodeEntry{.{ .name = "dictionary.zst", .method = .zstandard, .data = h.plain }};
    const kept = try Zip.encodeAlloc(a, &entries, .{ .zstd_level = -3, .zstd_dictionary = dictionary });
    defer a.free(kept);
    const omitted = try Zip.encodeAlloc(a, &entries, .{ .zstd_level = -3, .zstd_dictionary = dictionary, .zstd_options = .{ .include_dictionary_id = false } });
    defer a.free(omitted);
    const before = try Zip.parse(kept);
    const after = try Zip.parse(omitted);
    const first = try before.entryAt(0);
    const second = try after.entryAt(0);
    try h.pair(try before.compressedData(first), try after.compressedData(second), Z.FrameFormat.standard, dictionary.id);
    try std.testing.expectEqual(first.uncompressed_size, second.uncompressed_size);
    try std.testing.expectEqual(first.crc32, second.crc32);
    const payload = try after.extractAllocWithOptions(a, second, .{ .zstd_dictionary = dictionary });
    defer a.free(payload);
    try std.testing.expectEqualSlices(u8, h.plain, payload);
}
