const std = @import("std");
const h = @import("helpers.zig");
const t = h.t;

fn one(comptime D: type, comptime E: type, comptime variant: h.Variant, comptime cap: usize) !void {
    var heap = t.FailingAllocator.init(t.allocator, .{});
    var initial = try h.encode.options(D, E);
    // Header-only nextMemberExactSize inherits the active raw cap. Other
    // exact APIs must check the proposed cap rather than the old one.
    const first: []const u8 = if (variant == .gzip_exact) (if (cap == 0) "" else "abc") else h.encode.prefix;
    if (variant == .gzip_exact) initial.raw.max_input_len = cap;
    if (@hasField(E.Options, "header")) initial.header = .{ .filename = "first.gz", .header_crc = true };
    var encoder = E.initExactSize(heap.allocator(), initial, @intCast(first.len));
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(t.allocator);
    try h.encode.feed(&encoder, first, &wire);
    try h.encode.finish(&encoder, &wire);
    h.markRetainedSpare(&encoder);
    var oracle = try encoder.clone(t.allocator);
    defer oracle.deinit();
    var caller: [64]u8 = @splat(0xa5);
    @memcpy(caller[16..19], "xyz");
    var options = try h.encode.options(D, E);
    options.raw.block_len = 17;
    options.raw.max_input_len = cap;
    if (@hasField(E.Options, "header"))
        options.header = .{ .filename = "", .comment = "", .extra = caller[16..16], .header_crc = true, .xfl = 0, .os = 0 };
    try h.reject(&encoder, &heap, variant, options, "", cap + 1, error.OutputLimitExceeded, &caller);
    // Exact cap boundaries are satisfiable: cap=0 permits an empty second
    // stream, and cap=3 permits three bytes regardless of the first pledge.
    const second: []const u8 = if (cap == 0) caller[16..16] else caller[16..19];
    const before = caller;
    try h.retry(D, &encoder, &oracle, variant, options, &wire, first, second, "");
    try t.expectEqualSlices(u8, &before, &caller);
}

pub fn contracts(comptime D: type) !void {
    inline for (.{ D.ZlibIncrementalFixedEncoder, D.ZlibIncrementalBestEncoder }) |E| {
        try one(D, E, .zlib_exact, 0);
        try one(D, E, .zlib_exact, 3);
    }
    inline for (.{ D.GzipIncrementalFixedEncoder, D.GzipIncrementalBestEncoder }) |E| {
        inline for (.{ h.Variant.gzip_exact, h.Variant.gzip_exact_options }) |variant| {
            try one(D, E, variant, 0);
            try one(D, E, variant, 3);
        }
    }
}
