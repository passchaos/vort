const std = @import("std");
const h = @import("helpers.zig");
const t = h.t;

fn proposed(encoder: anytype, comptime D: type, comptime variant: h.Variant, comptime field: []const u8, borrow: []const u8, caller: []const u8) !void {
    var options = try h.validOptions(D, @TypeOf(encoder.*), h.external);
    if (@hasField(@TypeOf(encoder.options), "header")) {
        @field(options.header, field) = borrow;
        try h.reject(encoder, variant, options, "", borrow, caller);
    } else {
        try h.reject(encoder, variant, options, borrow, borrow, caller);
    }
}

fn one(comptime D: type, comptime E: type, comptime variant: h.Variant, comptime field: []const u8) !void {
    var caller: [256]u8 = @splat(0xa5);
    const old = caller[16..][0..h.external.len];
    const replacement = caller[128..][0..h.external.len];
    @memcpy(old, h.external);
    @memcpy(replacement, h.external);
    var encoder = try h.initFirst(D, E, variant, old);
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(t.allocator);
    try h.h.feed(&encoder, h.h.prefix, &wire);
    try h.h.finish(&encoder, &wire);
    try t.expect(encoder.done);
    try t.expect(encoder.raw.history.items.len != 0);
    const spans = h.Spans.collect(&encoder);
    // Clone the real completed state before any refusal. It receives the same
    // external replacement later and supplies independent continuation wire.
    var oracle = try encoder.clone(t.allocator);
    defer oracle.deinit();
    try proposed(&encoder, D, variant, field, std.mem.asBytes(&encoder.done), &caller);
    try proposed(&encoder, D, variant, field, std.mem.asBytes(&encoder), &caller);
    try proposed(&encoder, D, variant, field, std.mem.asBytes(&encoder.raw), &caller);
    var full_count: usize = 0;
    var spare_count: usize = 0;
    for (spans.entries[0..spans.len]) |entry| {
        if (entry.full.len != 0) {
            full_count += 1;
            try proposed(&encoder, D, variant, field, entry.full, &caller);
            try proposed(&encoder, D, variant, field, entry.full[entry.full.len - 1 ..], &caller);
        }
        if (entry.spare.len != 0) {
            spare_count += 1;
            try proposed(&encoder, D, variant, field, entry.spare, &caller);
        }
    }
    try t.expect(full_count != 0 and spare_count != 0);
    // The same completed receiver can immediately accept a corrected borrow.
    try h.retry(D, &encoder, &oracle, variant, &wire, replacement, old);
    try t.expectEqualSlices(u8, h.external, old);
    try t.expectEqualSlices(u8, h.external, replacement);
    for (caller[0..16]) |byte| try t.expectEqual(@as(u8, 0xa5), byte);
    for (caller[128 + h.external.len ..]) |byte| try t.expectEqual(@as(u8, 0xa5), byte);
}

pub fn contracts(comptime D: type) !void {
    inline for (.{ D.ZlibIncrementalFixedEncoder, D.ZlibIncrementalBestEncoder }) |E| {
        inline for (.{ h.Variant.zlib, h.Variant.zlib_exact }) |variant|
            try one(D, E, variant, "dictionary");
    }
    inline for (.{ D.GzipIncrementalFixedEncoder, D.GzipIncrementalBestEncoder }) |E| {
        inline for (.{ h.Variant.gzip, h.Variant.gzip_options, h.Variant.gzip_exact, h.Variant.gzip_exact_options }) |variant| {
            inline for (.{ "extra", "filename", "comment" }) |field|
                try one(D, E, variant, field);
        }
    }
}
