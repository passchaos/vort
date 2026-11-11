//! Native whole-operation requested-memory contracts, invoked by br.zig.
const std = @import("std");
const h = @import("tests/helpers.zig");
const f = @import("tests/fixtures.zig");

pub fn contracts(comptime B: type) !void {
    try @import("tests/chunk_alias.zig").contracts(B);
    try h.observerContract();
    const stored = try B.encodeStoredStreamAlloc(h.a, f.stored_plain);
    defer h.a.free(stored);
    const rle = try B.encodeRleStreamAlloc(h.a, f.repeated);
    defer h.a.free(rle);
    const multi = try f.multi(B);
    defer h.a.free(multi);
    const dictionary = try B.parseSerializedSharedDictionary(&f.serialized);
    const serialized = try f.serializedWire(B);
    defer h.a.free(serialized);

    const samples = [_]h.Sample(B){
        .{ .name = "stored", .wire = stored, .plain = f.stored_plain },
        .{ .name = "rle", .wire = rle, .plain = f.repeated },
        .{ .name = "external", .wire = &f.external, .plain = f.external_plain },
        .{ .name = "multi-metablock", .wire = multi, .plain = f.multi_plain },
        .{ .name = "large-window", .wire = &f.large, .plain = f.large_plain, .options = .{ .allow_large_window = true } },
        .{ .name = "RAW dictionary", .wire = &f.raw, .plain = f.raw_plain, .options = .{ .shared_dictionary = .{ .raw_prefixes = &.{ f.raw_plain[0..13], f.raw_plain[13..] } } } },
        .{ .name = "serialized dictionary", .wire = serialized, .plain = "hello", .options = .{ .shared_dictionary = .{ .serialized = &dictionary } } },
    };
    for (samples) |sample| {
        errdefer std.debug.print("Brotli total-memory fixture: {s}\n", .{sample.name});
        try @import("tests/owned.zig").contracts(B, sample);
        try @import("tests/zero_heap.zig").contracts(B, sample);
        try @import("tests/append.zig").contracts(B, sample);
    }
    try @import("tests/zero_heap.zig").empty(B);
    try @import("tests/failures.zig").contracts(B, samples[0], samples[2]);
    try @import("tests/summary.zig").contracts(B);
    try @import("tests/dictionary_alias.zig").contracts(B, serialized);
    try @import("tests/inheritance.zig").contracts(B, samples[0]);
    try @import("tests/preflight_observation.zig").contracts(B, samples[0]);
}
