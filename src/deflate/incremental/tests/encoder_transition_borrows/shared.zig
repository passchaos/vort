const std = @import("std");
const h = @import("helpers.zig");
const t = h.t;

fn one(comptime D: type, comptime E: type, comptime variant: h.Variant, comptime empty_borrow: bool) !void {
    var caller: [128]u8 = @splat(0xa5);
    const borrowed = caller[16..][0..h.external.len];
    @memcpy(borrowed, h.external);
    var encoder = try h.initFirst(D, E, variant, borrowed);
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(t.allocator);
    try h.h.feed(&encoder, h.h.prefix, &wire);
    try h.h.finish(&encoder, &wire);
    var oracle = try encoder.clone(t.allocator);
    defer oracle.deinit();
    // Old/new immutable metadata or dictionaries may use the same external
    // storage. A zero-length receiver slice also creates no read borrow.
    const receiver = std.mem.asBytes(&encoder.done);
    const next_borrow: []const u8 = if (empty_borrow) receiver[0..0] else borrowed;
    const caller_before = caller;
    try h.retry(D, &encoder, &oracle, variant, &wire, next_borrow, borrowed);
    try t.expectEqualSlices(u8, &caller_before, &caller);
}

pub fn contracts(comptime D: type) !void {
    inline for (.{ D.ZlibIncrementalFixedEncoder, D.ZlibIncrementalBestEncoder }) |E| {
        inline for (.{ h.Variant.zlib, h.Variant.zlib_exact }) |variant| {
            try one(D, E, variant, false);
            try one(D, E, variant, true);
        }
    }
    inline for (.{ D.GzipIncrementalFixedEncoder, D.GzipIncrementalBestEncoder }) |E| {
        inline for (.{ h.Variant.gzip, h.Variant.gzip_options, h.Variant.gzip_exact, h.Variant.gzip_exact_options }) |variant| {
            try one(D, E, variant, false);
            try one(D, E, variant, true);
        }
    }
}
