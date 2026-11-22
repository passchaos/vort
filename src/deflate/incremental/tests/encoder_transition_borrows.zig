const std = @import("std");
const h = @import("encode_borrows/helpers.zig");
const t = std.testing;
const matrix = @import("encoder_transition_borrows/matrix.zig");
const shared = @import("encoder_transition_borrows/shared.zig");

/// Minimal reproducer: a completed encoder's done flag becomes a proposed
/// immutable dictionary/header borrow, but next* itself would overwrite it.
pub fn beforeFour(comptime D: type) !void {
    inline for (.{ D.ZlibIncrementalFixedEncoder, D.ZlibIncrementalBestEncoder, D.GzipIncrementalFixedEncoder, D.GzipIncrementalBestEncoder }) |E| {
        var encoder = try h.init(D, E);
        defer encoder.deinit();
        var wire: std.ArrayList(u8) = .empty;
        defer wire.deinit(t.allocator);
        try h.feed(&encoder, h.prefix, &wire);
        try h.finish(&encoder, &wire);
        const receiver_borrow = std.mem.asBytes(&encoder.done);
        var saved = try h.Saved.init(&encoder);
        defer saved.deinit();
        if (@hasField(E.Options, "header"))
            try t.expectError(error.InvalidBlockPlan, encoder.nextMember(.{ .extra = receiver_borrow }))
        else
            try t.expectError(error.InvalidBlockPlan, encoder.nextStream(encoder.options, receiver_borrow));
        try saved.expectUnchanged(&encoder);
    }
}

pub fn contracts(comptime D: type) !void {
    try beforeFour(D);
    try matrix.contracts(D);
    try shared.contracts(D);
}
