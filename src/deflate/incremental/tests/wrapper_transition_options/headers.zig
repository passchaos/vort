const std = @import("std");
const h = @import("helpers.zig");
const t = h.t;

fn one(comptime D: type, comptime E: type, comptime variant: h.Variant, comptime empty_fields: bool) !void {
    var heap = t.FailingAllocator.init(t.allocator, .{});
    var initial = try h.encode.options(D, E);
    initial.header = .{ .filename = "first.gz", .comment = "first member", .extra = "old", .header_crc = true };
    var encoder = E.initWithOptions(heap.allocator(), initial);
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(t.allocator);
    try h.encode.feed(&encoder, h.encode.prefix, &wire);
    try h.encode.finish(&encoder, &wire);
    h.markRetainedSpare(&encoder);
    var oracle = try encoder.clone(t.allocator);
    defer oracle.deinit();
    const caller = try t.allocator.alloc(u8, 65536 + 64);
    defer t.allocator.free(caller);
    @memset(caller, 0xa5);
    @memcpy(caller[16..19], "a\x00b");
    var valid = try h.encode.options(D, E);
    valid.raw.block_len = 19;
    valid.raw.compression = try D.optionsForZlibLevel(6);
    valid.header = if (empty_fields)
        .{ .filename = "", .comment = "", .extra = caller[32..32], .header_crc = true, .mtime = 0, .xfl = 0, .os = 0 }
    else
        .{ .filename = "accepted.gz", .comment = "accepted member", .extra = "new", .header_crc = true, .mtime = 9876, .xfl = 2, .os = 3 };
    var invalid = valid;
    invalid.header.filename = caller[16..19];
    try h.reject(&encoder, &heap, variant, invalid, "", h.encode.suffix.len, error.BadGzipHeader, caller);
    invalid = valid;
    invalid.header.comment = caller[16..19];
    try h.reject(&encoder, &heap, variant, invalid, "", h.encode.suffix.len, error.BadGzipHeader, caller);
    invalid = valid;
    invalid.header.extra = caller[32..][0..65536];
    try h.reject(&encoder, &heap, variant, invalid, "", h.encode.suffix.len, error.IntegerOverflow, caller);
    // Filename/comment validation retains its normal precedence over XLEN.
    invalid.header.filename = caller[16..19];
    try h.reject(&encoder, &heap, variant, invalid, "", h.encode.suffix.len, error.BadGzipHeader, caller);
    const before = try t.allocator.dupe(u8, caller);
    defer t.allocator.free(before);
    try h.retry(D, &encoder, &oracle, variant, valid, &wire, h.encode.prefix, h.encode.suffix, "");
    try t.expectEqualSlices(u8, before, caller);
    if (variant == .gzip_options or variant == .gzip_exact_options)
        try t.expectEqualDeep(valid.raw.compression, encoder.raw.options.compression);
}

pub fn contracts(comptime D: type) !void {
    inline for (.{ D.GzipIncrementalFixedEncoder, D.GzipIncrementalBestEncoder }) |E| {
        inline for (.{ h.Variant.gzip, h.Variant.gzip_options, h.Variant.gzip_exact, h.Variant.gzip_exact_options }) |variant| {
            try one(D, E, variant, false);
            try one(D, E, variant, true);
        }
    }
}
