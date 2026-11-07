const std = @import("std");
const core = @import("../../core.zig");
const h = @import("helpers.zig");
const a = h.a;

pub fn contracts(comptime Z: type) !void {
    const frame = try h.frame(Z, .standard);
    defer a.free(frame);
    try metadata(Z);
    try lateError(Z, frame);
    try heap(Z, frame);
    try reentrant(Z, frame);
}

fn metadata(comptime Z: type) !void {
    const bytes = try h.memory.hexAlloc(@embedFile("../../zstd/testdata/libzstd-trained-repeat.dict.hex"));
    defer a.free(bytes);
    const valid = (try Z.NativeDictionary.initFromStandardDictionary(bytes)).dictionary;
    var invalid = valid;
    invalid.id +%= 1; // The caller handle disagrees with the full dictionary header.
    const persistent = Z.NativeDictionary.init(42, h.prefix);
    const encoded = try Z.encodeNativeFrameWithDictionaryAlloc(a, h.payload, .{ .selection = .literal_only }, persistent);
    defer a.free(encoded.frame);
    var decoder = Z.NativeFrameDecoder.init(a);
    defer decoder.deinit();
    try decoder.setDictionary(persistent);
    try std.testing.expectError(error.InvalidDictionaryMetadata, decoder.setPrefixWithDictionary(invalid));
    try h.cleared(decoder.prefixSnapshot());
    try std.testing.expectError(error.NeedDictionary, decoder.decodeAlloc(encoded.frame));
    var incremental = Z.NativeIncrementalFrameDecoder.init(a);
    defer incremental.deinit();
    try incremental.setDictionary(persistent);
    try std.testing.expectError(error.InvalidDictionaryMetadata, incremental.setPrefixWithDictionary(invalid));
    try h.cleared(incremental.prefixSnapshot());
    try std.testing.expectError(error.NeedDictionary, incremental.step(encoded.frame, &.{}));
    // Encoders borrow advanced FULL handles and validate when encoding starts.
    var encoder = Z.NativeFrameEncoder.init(a);
    defer encoder.deinit();
    try encoder.setPrefixWithDictionary(invalid);
    try h.pending(encoder.prefixSnapshot(), invalid.id, true);
    try std.testing.expectError(error.InvalidDictionaryMetadata, encoder.encodeWithOptionsAlloc(h.payload, .{ .selection = .literal_only }));
    try h.cleared(encoder.prefixSnapshot());
}

fn lateError(comptime Z: type, frame: []const u8) !void {
    const bad = try a.dupe(u8, frame);
    defer a.free(bad);
    bad[bad.len - 1] ^= 1;
    for ([_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame }) |policy| {
        const corrupt = try a.dupe(u8, frame);
        defer a.free(corrupt);
        const header = try h.wire.header(corrupt, false);
        corrupt[header.payload_offset] |= 6;
        var payload_error = Z.NativeIncrementalFrameDecoder.initWithPrefixAndOptions(a, h.prefix, .{ .input_policy = policy });
        defer payload_error.deinit();
        try std.testing.expectError(error.CorruptFrame, payload_error.step(corrupt, &.{}));
        try h.cleared(payload_error.prefixSnapshot());
        var strict = Z.NativeIncrementalFrameDecoder.initWithPrefixAndOptions(a, h.prefix, .{ .input_policy = policy });
        defer strict.deinit();
        try std.testing.expectError(error.ChecksumMismatch, h.wire.drive(a, &strict, bad, h.payload.len, 1, 3));
        try h.cleared(strict.prefixSnapshot());
        strict.resetSession();
        try h.cleared(strict.prefixSnapshot());
        var ignore = Z.NativeIncrementalFrameDecoder.initWithPrefixAndOptions(a, h.prefix, .{ .input_policy = policy, .ignore_content_checksum = true });
        defer ignore.deinit();
        const decoded = try h.wire.drive(a, &ignore, bad, h.payload.len, 1, 3);
        defer a.free(decoded.output);
        try std.testing.expectEqualSlices(u8, h.payload, decoded.output);
        try ignore.finish();
        try h.cleared(ignore.prefixSnapshot());
    }
}

fn heap(comptime Z: type, frame: []const u8) !void {
    var tracker = h.memory.Tracker.init(a);
    var decoder = Z.NativeFrameDecoder.initWithOptions(tracker.allocator(), .{ .max_total_working_memory = 0 });
    defer decoder.deinit();
    const before = tracker.attempts;
    try decoder.setPrefix(h.prefix);
    try std.testing.expectEqual(before, tracker.attempts);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, decoder.decodeAlloc(frame));
    try h.cleared(decoder.prefixSnapshot());
    try std.testing.expectEqual(@as(usize, 0), tracker.live);
    var encoder = try Z.NativeIncrementalFrameEncoder.initWithPrefix(a, .{ .selection = .literal_only, .include_content_size = false }, h.prefix);
    defer encoder.deinit();
    encoder.options.max_total_working_memory = 0;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.step(&.{}, &.{}));
    try h.active(encoder.prefixSnapshot(), .frame);
    encoder.options.max_total_working_memory = null;
    const retried = try h.wire.encodeDrive(a, &encoder, h.payload);
    defer a.free(retried);
    try h.check(Z, retried, h.payload, .{ .dictionary = Z.NativeDictionary.initRawContent(h.prefix) });
    try h.cleared(encoder.prefixSnapshot());
}

fn Hook(comptime Decoder: type) type {
    return struct {
        decoder: ?*Decoder = null,
        attempted: bool = false,
        rejected: bool = false,
        const Self = @This();
        fn allocator(self: *Self) std.mem.Allocator {
            return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
        }
        fn alloc(ptr: *anyopaque, len: usize, alignment: std.mem.Alignment, ret: usize) ?[*]u8 {
            const self: *Self = @ptrCast(@alignCast(ptr));
            if (!self.attempted) if (self.decoder) |decoder| {
                self.attempted = true;
                if (decoder.setPrefix("reentrant replacement")) |_| {} else |err| self.rejected = err == error.InvalidStreamState;
            };
            return a.rawAlloc(len, alignment, ret);
        }
        fn resize(_: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) bool {
            return a.rawResize(bytes, alignment, len, ret);
        }
        fn remap(_: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) ?[*]u8 {
            return a.rawRemap(bytes, alignment, len, ret);
        }
        fn free(_: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, ret: usize) void {
            a.rawFree(bytes, alignment, ret);
        }
    };
}

fn reentrant(comptime Z: type, frame: []const u8) !void {
    var hook: Hook(Z.NativeFrameDecoder) = .{};
    var decoder = Z.NativeFrameDecoder.init(hook.allocator());
    defer decoder.deinit();
    hook.decoder = &decoder;
    try decoder.setPrefix(h.prefix);
    const result = try decoder.decodeAlloc(frame);
    defer hook.allocator().free(result);
    try std.testing.expect(hook.attempted and hook.rejected);
    try std.testing.expectEqualSlices(u8, h.payload, result);
    try h.cleared(decoder.prefixSnapshot());
}
