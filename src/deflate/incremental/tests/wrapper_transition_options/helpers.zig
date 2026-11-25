const std = @import("std");
pub const encode = @import("../encode_borrows/helpers.zig");
const transition = @import("../encoder_transition_borrows/helpers.zig");
pub const t = std.testing;
pub const Variant = enum { gzip, gzip_options, gzip_exact, gzip_exact_options, zlib_exact };

pub fn isExact(comptime variant: Variant) bool {
    return variant == .gzip_exact or variant == .gzip_exact_options or variant == .zlib_exact;
}

pub fn next(encoder: anytype, comptime variant: Variant, options: @TypeOf(encoder.options), dictionary: []const u8, pledge: @TypeOf(encoder.total_input)) !void {
    if (comptime variant == .gzip) {
        try encoder.nextMember(options.header);
    } else if (comptime variant == .gzip_options) {
        try encoder.nextMemberWithOptions(options);
    } else if (comptime variant == .gzip_exact) {
        try encoder.nextMemberExactSize(options.header, pledge);
    } else if (comptime variant == .gzip_exact_options) {
        try encoder.nextMemberExactSizeWithOptions(options, pledge);
    } else {
        try encoder.nextStreamExactSize(options, dictionary, pledge);
    }
}

pub fn markRetainedSpare(encoder: anytype) void {
    _ = transition.Spans.collect(encoder);
}

fn counters(heap: *const t.FailingAllocator) [6]usize {
    return .{ heap.alloc_index, heap.resize_index, heap.allocated_bytes, heap.freed_bytes, heap.allocations, heap.deallocations };
}

pub fn reject(encoder: anytype, heap: *t.FailingAllocator, comptime variant: Variant, options: @TypeOf(encoder.options), dictionary: []const u8, pledge: @TypeOf(encoder.total_input), expected_error: anyerror, caller: []const u8) !void {
    const old_fail = heap.fail_index;
    const old_resize_fail = heap.resize_fail_index;
    heap.fail_index = heap.alloc_index;
    heap.resize_fail_index = heap.resize_index;
    defer {
        heap.fail_index = old_fail;
        heap.resize_fail_index = old_resize_fail;
    }
    var saved = try encode.Saved.init(encoder);
    defer saved.deinit();
    const heap_before = counters(heap);
    const failure_before = heap.has_induced_failure;
    const caller_before = try t.allocator.dupe(u8, caller);
    defer t.allocator.free(caller_before);
    try t.expectError(expected_error, next(encoder, variant, options, dictionary, pledge));
    try saved.expectUnchanged(encoder);
    try t.expectEqualDeep(heap_before, counters(heap));
    try t.expectEqual(failure_before, heap.has_induced_failure);
    try t.expectEqualSlices(u8, caller_before, caller);
}

/// The oracle was cloned before invalid transition attempts. Both receivers
/// enter a new member directly, then emit matching independently owned wire.
pub fn retry(comptime D: type, encoder: anytype, oracle: anytype, comptime variant: Variant, options: @TypeOf(encoder.options), wire: *std.ArrayList(u8), first: []const u8, second: []const u8, dictionary: []const u8) !void {
    const second_offset = wire.items.len;
    const pledge: @TypeOf(encoder.total_input) = @intCast(second.len);
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(t.allocator);
    try expected.appendSlice(t.allocator, wire.items);
    try next(encoder, variant, options, dictionary, pledge);
    try next(oracle, variant, options, dictionary, pledge);
    try t.expect(!encoder.done);
    try t.expectEqual(@as(@TypeOf(encoder.total_input), 0), encoder.total_input);
    try t.expectEqual(@as(@TypeOf(encoder.stream_input), first.len), encoder.stream_input);
    if (isExact(variant))
        try t.expectEqual(@as(@TypeOf(encoder.raw.expected_input_len), pledge), encoder.raw.expected_input_len);
    try encode.feed(encoder, second, wire);
    try encode.feed(oracle, second, &expected);
    try encode.finish(encoder, wire);
    try encode.finish(oracle, &expected);
    try t.expectEqualSlices(u8, expected.items, wire.items);
    try t.expectEqual(@as(@TypeOf(encoder.total_input), @intCast(second.len)), encoder.total_input);
    try t.expectEqual(@as(@TypeOf(encoder.stream_input), @intCast(first.len + second.len)), encoder.stream_input);
    const count = if (@hasField(@TypeOf(encoder.*), "member_count")) encoder.member_count else encoder.stream_count;
    try t.expectEqual(@as(@TypeOf(count), 2), count);
    const decoded = if (@hasField(@TypeOf(encoder.options), "header"))
        try D.decodeGzipConcatenatedAlloc(t.allocator, wire.items)
    else
        try D.decodeZlibConcatenatedAllocWithDictionary(t.allocator, wire.items, dictionary);
    defer t.allocator.free(decoded);
    try t.expectEqual(first.len + second.len, decoded.len);
    try t.expectEqualSlices(u8, first, decoded[0..first.len]);
    try t.expectEqualSlices(u8, second, decoded[first.len..]);
    if (@hasField(@TypeOf(encoder.options), "header")) {
        const header = try D.parseGzipHeaderInfo(wire.items[second_offset..]);
        try t.expectEqual(options.header.mtime, header.mtime);
        try t.expectEqual(options.header.xfl, header.xfl);
        try t.expectEqual(options.header.os, header.os);
        try t.expectEqual(options.header.header_crc, header.header_crc != null);
        inline for (.{ "extra", "filename", "comment" }) |field| {
            const proposed = @field(options.header, field);
            const written = @field(header, field);
            try t.expectEqual(proposed != null, written != null);
            if (proposed) |bytes| try t.expectEqualSlices(u8, bytes, written.?);
        }
    }
}
