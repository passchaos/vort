const std = @import("std");
pub const h = @import("../encode_borrows/helpers.zig");
pub const t = std.testing;
pub const external = "external immutable header and dictionary borrow";

pub const Variant = enum { zlib, zlib_exact, gzip, gzip_options, gzip_exact, gzip_exact_options };

pub fn isExact(comptime variant: Variant) bool {
    return variant == .zlib_exact or variant == .gzip_exact or variant == .gzip_exact_options;
}

pub fn next(encoder: anytype, comptime variant: Variant, options: @TypeOf(encoder.options), dictionary: []const u8) !void {
    if (comptime variant == .zlib) {
        try encoder.nextStream(options, dictionary);
    } else if (comptime variant == .zlib_exact) {
        try encoder.nextStreamExactSize(options, dictionary, h.suffix.len);
    } else if (comptime variant == .gzip) {
        try encoder.nextMember(options.header);
    } else if (comptime variant == .gzip_options) {
        try encoder.nextMemberWithOptions(options);
    } else if (comptime variant == .gzip_exact) {
        try encoder.nextMemberExactSize(options.header, h.suffix.len);
    } else {
        try encoder.nextMemberExactSizeWithOptions(options, h.suffix.len);
    }
}

pub fn initFirst(comptime D: type, comptime E: type, comptime variant: Variant, borrowed: []const u8) !E {
    var options = try h.options(D, E);
    if (@hasField(E.Options, "header")) {
        options.header = .{ .extra = borrowed, .filename = borrowed, .comment = borrowed, .header_crc = true };
        return if (isExact(variant))
            E.initExactSize(t.allocator, options, h.prefix.len)
        else
            E.initWithOptions(t.allocator, options);
    }
    return if (isExact(variant))
        E.initExactSizeWithDictionary(t.allocator, options, h.prefix.len, borrowed)
    else
        E.initWithDictionary(t.allocator, options, borrowed);
}

pub fn validOptions(comptime D: type, comptime E: type, borrowed: []const u8) !E.Options {
    var options = try h.options(D, E);
    options.raw.block_len = 23;
    if (@hasField(E.Options, "header"))
        options.header = .{ .extra = borrowed, .filename = borrowed, .comment = borrowed, .header_crc = true, .mtime = 1234 }
    else
        options.window_bits = 9;
    return options;
}

pub fn reject(encoder: anytype, comptime variant: Variant, options: @TypeOf(encoder.options), dictionary: []const u8, proposed_borrow: []const u8, caller: []const u8) !void {
    var saved = try h.Saved.init(encoder);
    defer saved.deinit();
    const borrow_before = try t.allocator.dupe(u8, proposed_borrow);
    defer t.allocator.free(borrow_before);
    const caller_before = try t.allocator.dupe(u8, caller);
    defer t.allocator.free(caller_before);
    try t.expectError(error.InvalidBlockPlan, next(encoder, variant, options, dictionary));
    try saved.expectUnchanged(encoder);
    try t.expectEqualSlices(u8, borrow_before, proposed_borrow);
    try t.expectEqualSlices(u8, caller_before, caller);
}

pub const Spans = struct {
    const Entry = struct { full: []u8, spare: []u8 };
    entries: [9]Entry = undefined,
    len: usize = 0,

    fn add(self: *Spans, list: anytype) void {
        const full = std.mem.sliceAsBytes(list.allocatedSlice());
        const spare = std.mem.sliceAsBytes(list.allocatedSlice()[list.items.len..]);
        // Only initialize naturally retained spare capacity. No test-created
        // allocation or enlarged capacity is needed for these borrow fixtures.
        @memset(spare, 0xa5);
        self.entries[self.len] = .{ .full = full, .spare = spare };
        self.len += 1;
    }

    pub fn collect(encoder: anytype) Spans {
        var spans: Spans = .{};
        spans.add(&encoder.raw.plain);
        spans.add(&encoder.raw.pending);
        spans.add(&encoder.raw.state.bytes);
        spans.add(&encoder.raw.history);
        spans.add(&encoder.raw.plan_tokens);
        spans.add(&encoder.raw.match_finder.head);
        spans.add(&encoder.raw.match_finder.head_epoch);
        spans.add(&encoder.raw.match_finder.prev);
        spans.add(&encoder.pending);
        return spans;
    }
};

fn verify(comptime D: type, encoder: anytype, wire: []const u8, second_offset: usize, dictionary: []const u8, new_borrow: []const u8) !void {
    const decoded = if (@hasField(@TypeOf(encoder.options), "header"))
        try D.decodeGzipConcatenatedAlloc(t.allocator, wire)
    else
        try D.decodeZlibConcatenatedAllocWithDictionary(t.allocator, wire, dictionary);
    defer t.allocator.free(decoded);
    try t.expectEqualSlices(u8, h.prefix ++ h.suffix, decoded);
    if (@hasField(@TypeOf(encoder.options), "header")) {
        const header = try D.parseGzipHeaderInfo(wire[second_offset..]);
        inline for (.{ "extra", "filename", "comment" }) |field|
            try t.expectEqualSlices(u8, new_borrow, @field(header, field).?);
    }
}

pub fn retry(comptime D: type, encoder: anytype, oracle: anytype, comptime variant: Variant, wire: *std.ArrayList(u8), new_borrow: []const u8, old_dictionary: []const u8) !void {
    const options = try validOptions(D, @TypeOf(encoder.*), new_borrow);
    const second_offset = wire.items.len;
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(t.allocator);
    try expected.appendSlice(t.allocator, wire.items);
    try next(encoder, variant, options, new_borrow);
    try next(oracle, variant, options, new_borrow);
    try t.expect(!encoder.done);
    try t.expectEqual(@as(@TypeOf(encoder.total_input), 0), encoder.total_input);
    try t.expectEqual(@as(@TypeOf(encoder.stream_input), h.prefix.len), encoder.stream_input);
    if (isExact(variant)) {
        try t.expectEqual(@as(@TypeOf(encoder.raw.expected_input_len), h.suffix.len), encoder.raw.expected_input_len);
        // Offered input is checked against this member's independent pledge
        // before publishing its new header or changing retained storage.
        var saved = try h.Saved.init(encoder);
        defer saved.deinit();
        var output: [64]u8 = @splat(0xa5);
        try t.expect(h.prefix.len > h.suffix.len);
        try t.expectError(error.SizeMismatch, encoder.step(h.prefix, &output));
        try saved.expectUnchanged(encoder);
        for (output) |byte| try t.expectEqual(@as(u8, 0xa5), byte);
    }
    try h.feed(encoder, h.suffix, wire);
    try h.feed(oracle, h.suffix, &expected);
    try h.finish(encoder, wire);
    try h.finish(oracle, &expected);
    try t.expectEqualSlices(u8, expected.items, wire.items);
    try t.expectEqual(@as(@TypeOf(encoder.total_input), h.suffix.len), encoder.total_input);
    try t.expectEqual(@as(@TypeOf(encoder.stream_input), h.prefix.len + h.suffix.len), encoder.stream_input);
    const count = if (@hasField(@TypeOf(encoder.*), "member_count")) encoder.member_count else encoder.stream_count;
    try t.expectEqual(@as(@TypeOf(count), 2), count);
    try verify(D, encoder, wire.items, second_offset, old_dictionary, new_borrow);
}
