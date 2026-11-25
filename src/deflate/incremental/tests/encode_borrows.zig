const std = @import("std");
const t = std.testing;
const h = @import("encode_borrows/helpers.zig");
const caller_tests = @import("encode_borrows/caller.zig");
const owned_tests = @import("encode_borrows/owned.zig");
const immutable_tests = @import("encode_borrows/immutable.zig");

/// The first regression exercises a real mutation: gzip used to publish its
/// header over offered input before the raw encoder had copied that input.
pub fn headerOverwrite(comptime D: type) !void {
    inline for (.{ D.GzipIncrementalFixedEncoder, D.GzipIncrementalBestEncoder }) |E| {
        var encoder = E.init(t.allocator);
        defer encoder.deinit();
        var caller: [192]u8 = @splat(0xa5);
        const plain = "the gzip header must never overwrite unread input";
        @memcpy(caller[16..][0..plain.len], plain);
        const receiver_before = try t.allocator.dupe(u8, std.mem.asBytes(&encoder));
        defer t.allocator.free(receiver_before);
        const caller_before = caller;
        try t.expectError(error.InvalidBlockPlan, encoder.step(caller[16..][0..plain.len], caller[16..]));
        try t.expectEqualSlices(u8, receiver_before, std.mem.asBytes(&encoder));
        try t.expectEqualSlices(u8, &caller_before, &caller);
        var wire: std.ArrayList(u8) = .empty;
        defer wire.deinit(t.allocator);
        try h.retry(D, &encoder, caller[16..][0..plain.len], &wire, plain, "");
    }
}

pub fn contracts(comptime D: type) !void {
    try headerOverwrite(D);
    inline for (.{
        D.RawDeflateIncrementalStoredEncoder,
        D.RawDeflateIncrementalFixedEncoder,
        D.RawDeflateIncrementalBestEncoder,
        D.ZlibIncrementalFixedEncoder,
        D.ZlibIncrementalBestEncoder,
        D.GzipIncrementalFixedEncoder,
        D.GzipIncrementalBestEncoder,
    }) |E| {
        try caller_tests.contracts(D, E);
        try owned_tests.contracts(D, E);
    }
    try immutable_tests.contracts(D);
}
