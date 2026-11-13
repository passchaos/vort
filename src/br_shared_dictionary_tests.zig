//! Public Brotli RAW shared-prefix dictionary contracts. The dictionary is an
//! explicit decoder parameter under RFC 7932: a wire emitted against a prefix
//! must reproduce its source only when the same prefix is attached, and the
//! no-dictionary decode path must not silently succeed on dictionary-backed
//! references.
const std = @import("std");
const a = std.testing.allocator;

const dictionary_text = "vort shared brotli prefix dictionary phrase alpha beta gamma delta";

fn overlappingPayload(allocator: std.mem.Allocator) ![]u8 {
    const payload = try allocator.alloc(u8, dictionary_text.len * 3);
    for (payload, 0..) |*byte, index| {
        byte.* = dictionary_text[index % dictionary_text.len];
    }
    return payload;
}

pub fn contracts(comptime Br: type) !void {
    const payload = try overlappingPayload(a);
    defer a.free(payload);

    for ([_]u4{ 0, 5, 11 }) |quality| {
        const wire = try Br.encodePlannedStreamWithOptionsAlloc(a, payload, .{
            .quality = quality,
            .shared_dictionary = .{ .raw_prefixes = &.{dictionary_text} },
        });
        defer a.free(wire);

        // Attached prefix: exact-size and plain decode both reproduce the source.
        const decoded = try Br.decodeStreamAllocExactSizeWithOptions(a, wire, payload.len, .{
            .shared_dictionary = .{ .raw_prefixes = &.{dictionary_text} },
        });
        defer a.free(decoded);
        try std.testing.expectEqualSlices(u8, payload, decoded);

        const plain = Br.decodeStreamAllocWithOptions(a, wire, .{
            .shared_dictionary = .{ .raw_prefixes = &.{dictionary_text} },
        }) catch |err| {
            std.debug.print("quality={d} attached decode failed: {s}\n", .{ quality, @errorName(err) });
            return err;
        };
        defer a.free(plain);
        try std.testing.expectEqualSlices(u8, payload, plain);

        // Without the prefix the stream must fail: accepting it would mean the
        // encoder did not actually need the advertised dictionary. The exact
        // error depends on whether the first dictionary-backed distance is
        // rejected as an unsupported external reference or surfaces as a
        // corrupt frame, so accept the documented dictionary-distance errors.
        const no_prefix = Br.decodeStreamAllocExactSize(a, wire, payload.len);
        if (no_prefix) |unexpected| {
            a.free(unexpected);
            return error.UnexpectedSuccess;
        } else |err| switch (err) {
            error.CorruptFrame, error.UnsupportedBrotliFeature => {},
            else => return err,
        }
    }
}
