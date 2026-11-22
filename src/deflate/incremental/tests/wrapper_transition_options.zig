const std = @import("std");
const h = @import("encode_borrows/helpers.zig");
const t = std.testing;
const headers = @import("wrapper_transition_options/headers.zig");
const pledges = @import("wrapper_transition_options/pledges.zig");

/// Ordinary next* APIs must reject a deterministic header/configuration error
/// while the old stream is still done and can accept a corrected transition.
pub fn before(comptime D: type) !void {
    inline for (.{ D.GzipIncrementalFixedEncoder, D.GzipIncrementalBestEncoder }) |E| {
        var encoder = try h.init(D, E);
        defer encoder.deinit();
        var wire: std.ArrayList(u8) = .empty;
        defer wire.deinit(t.allocator);
        try h.feed(&encoder, h.prefix, &wire);
        try h.finish(&encoder, &wire);
        var saved = try h.Saved.init(&encoder);
        defer saved.deinit();
        try t.expectError(error.BadGzipHeader, encoder.nextMember(.{ .filename = "a\x00b" }));
        try saved.expectUnchanged(&encoder);
    }
    inline for (.{ D.ZlibIncrementalFixedEncoder, D.ZlibIncrementalBestEncoder }) |E| {
        var options = try h.options(D, E);
        options.raw.max_input_len = 3;
        var encoder = E.initWithOptions(t.allocator, options);
        defer encoder.deinit();
        var wire: std.ArrayList(u8) = .empty;
        defer wire.deinit(t.allocator);
        try h.feed(&encoder, "abc", &wire);
        try h.finish(&encoder, &wire);
        var saved = try h.Saved.init(&encoder);
        defer saved.deinit();
        try t.expectError(error.OutputLimitExceeded, encoder.nextStreamExactSize(options, "", 4));
        try saved.expectUnchanged(&encoder);
    }
}

pub fn contracts(comptime D: type) !void {
    try before(D);
    try headers.contracts(D);
    try pledges.contracts(D);
}
