//! Configured legacy overrides must keep the whole-operation quota/profile.
const std = @import("std");
const h = @import("helpers.zig");
const a = h.a;
const Kind = enum { alloc, scratch, into, append };

pub fn contracts(comptime Z: type) !void {
    const dictionary = Z.NativeDictionary.init(42, h.plain);
    const entries = [_]Z.NativeDictionary{dictionary};
    const catalog = Z.NativeDictionarySet.init(&entries);
    const payload = h.plain ** 2;
    const encoded = try Z.encodeNativeFrameWithDictionaryAlloc(a, payload, .{ .format = .magicless, .content_checksum = true, .strategy = .fast }, dictionary);
    defer a.free(encoded.frame);
    const base: Z.FrameDecodeOptions = .{ .format = .magicless, .dictionary = dictionary };
    try check(Z, .alloc, "decodeAllocExactSize", .{payload.len}, encoded.frame, payload, base);
    try check(Z, .alloc, "decodeAllocLimited", .{payload.len}, encoded.frame, payload, base);
    try check(Z, .alloc, "decodeAllocWithDictionaryExactSize", .{ dictionary, payload.len }, encoded.frame, payload, base);
    try check(Z, .alloc, "decodeAllocWithDictionarySetExactSize", .{ catalog, payload.len }, encoded.frame, payload, base);
    try check(Z, .alloc, "decodeAllocLimitedWithDictionary", .{ payload.len, dictionary }, encoded.frame, payload, base);
    try check(Z, .alloc, "decodeAllocLimitedWithDictionarySet", .{ payload.len, catalog }, encoded.frame, payload, base);
    try check(Z, .scratch, "decodeScratchWithDictionary", .{dictionary}, encoded.frame, payload, base);
    try check(Z, .scratch, "decodeScratchWithDictionarySet", .{catalog}, encoded.frame, payload, base);
    try check(Z, .scratch, "decodeScratchLimited", .{payload.len}, encoded.frame, payload, base);
    try check(Z, .scratch, "decodeScratchLimitedWithDictionary", .{ payload.len, dictionary }, encoded.frame, payload, base);
    try check(Z, .scratch, "decodeScratchLimitedWithDictionarySet", .{ payload.len, catalog }, encoded.frame, payload, base);
    try check(Z, .into, "decodeIntoSliceLimited", .{payload.len}, encoded.frame, payload, base);
    try check(Z, .into, "decodeIntoSliceExactSize", .{payload.len}, encoded.frame, payload, base);
    try check(Z, .into, "decodeIntoSliceWithDictionaryLimited", .{ dictionary, payload.len }, encoded.frame, payload, base);
    try check(Z, .into, "decodeIntoSliceWithDictionaryExactSize", .{ dictionary, payload.len }, encoded.frame, payload, base);
    try check(Z, .into, "decodeIntoSliceWithDictionarySetLimited", .{ catalog, payload.len }, encoded.frame, payload, base);
    try check(Z, .into, "decodeIntoSliceWithDictionarySetExactSize", .{ catalog, payload.len }, encoded.frame, payload, base);
    try check(Z, .append, "decodeAppendExactSize", .{payload.len}, encoded.frame, payload, base);
    try check(Z, .append, "decodeAppendLimited", .{payload.len}, encoded.frame, payload, base);
    try check(Z, .append, "decodeAppendExactSizeWithDictionary", .{ dictionary, payload.len }, encoded.frame, payload, base);
    try check(Z, .append, "decodeAppendExactSizeWithDictionarySet", .{ catalog, payload.len }, encoded.frame, payload, base);
    try check(Z, .append, "decodeAppendLimitedWithDictionary", .{ payload.len, dictionary }, encoded.frame, payload, base);
    try check(Z, .append, "decodeAppendLimitedWithDictionarySet", .{ payload.len, catalog }, encoded.frame, payload, base);
}

fn check(comptime Z: type, comptime kind: Kind, comptime name: []const u8, extras: anytype, frame: []const u8, payload: []const u8, base: Z.FrameDecodeOptions) !void {
    errdefer std.debug.print("decode quota legacy {s}\n", .{name});
    var profile: Z.DecodeMemoryProfile = .{};
    var options = base;
    options.max_total_working_memory = 0;
    options.memory_profile = &profile;
    var decoder = Z.NativeFrameDecoder.initWithOptions(a, options);
    defer decoder.deinit();
    const output = try a.alloc(u8, payload.len + 17);
    defer a.free(output);
    @memset(output, 0xa5);
    var out = std.ArrayList(u8).fromOwnedSlice(try a.dupe(u8, "caller-prefix"));
    defer out.deinit(a);
    const pointer = out.items.ptr;
    const capacity = out.capacity;
    const args = switch (kind) {
        .alloc, .scratch => .{ &decoder, frame } ++ extras,
        .into => .{ &decoder, frame, output[0..payload.len] } ++ extras,
        .append => .{ &decoder, &out, frame } ++ extras,
    };
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, @call(.auto, @field(Z.NativeFrameDecoder, name), args));
    try h.untouched(output);
    try std.testing.expectEqual(pointer, out.items.ptr);
    try std.testing.expectEqual(capacity, out.capacity);
    try std.testing.expectEqualStrings("caller-prefix", out.items);
    try std.testing.expectEqual(@as(usize, 0), decoder.scratch.items.len);
    decoder.options.max_total_working_memory = null;
    profile.reset();
    const result = try @call(.auto, @field(Z.NativeFrameDecoder, name), args);
    switch (kind) {
        .alloc => {
            defer a.free(result);
            try std.testing.expectEqualSlices(u8, payload, result);
        },
        .scratch => try std.testing.expectEqualSlices(u8, payload, result),
        .into => {
            try std.testing.expectEqual(payload.len, result);
            try std.testing.expectEqualSlices(u8, payload, output[0..result]);
            try h.untouched(output[result..]);
        },
        .append => {
            try std.testing.expectEqual(payload.len, result);
            try std.testing.expectEqualSlices(u8, payload, out.items[13..]);
        },
    }
    try std.testing.expect(profile.available);
    try std.testing.expectEqual(@as(?usize, null), profile.limit);
    try std.testing.expectEqual(profile.live_requested_bytes, decoder.memorySnapshot().live_requested_bytes);
}
