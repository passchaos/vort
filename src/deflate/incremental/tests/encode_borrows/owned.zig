const std = @import("std");
const h = @import("helpers.zig");
const t = h.t;

fn receiver(comptime D: type, comptime E: type) !void {
    var encoder = try h.init(D, E);
    defer encoder.deinit();
    var caller: [128]u8 = @splat(0xa5);
    const bytes = std.mem.asBytes(&encoder);
    try h.reject(&encoder, bytes[0..1], &caller, &caller);
    try h.reject(&encoder, bytes[bytes.len - 1 ..], &caller, &caller);
    try h.reject(&encoder, bytes[0..1], caller[0..0], &caller);
    try h.reject(&encoder, h.suffix, bytes[0..1], &caller);
    try h.reject(&encoder, h.suffix, bytes[bytes.len - 1 ..], &caller);
    try h.reject(&encoder, "", bytes, &caller);
    if (@hasField(E, "raw")) {
        // The embedded raw receiver belongs to the outer encoder too.
        const raw_bytes = std.mem.asBytes(&encoder.raw);
        try h.reject(&encoder, raw_bytes[0..1], &caller, &caller);
        try h.reject(&encoder, h.suffix, raw_bytes[raw_bytes.len - 1 ..], &caller);
    }
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(t.allocator);
    try h.retry(D, &encoder, h.suffix, &wire, h.suffix, "");
}

fn capacities(comptime D: type, comptime E: type, comptime after_reset: bool) !void {
    var encoder = try h.init(D, E);
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(t.allocator);
    try h.feed(&encoder, h.prefix, &wire);
    if (after_reset) {
        try h.finish(&encoder, &wire);
        try h.verify(D, E, wire.items, h.prefix, "");
        encoder.reset();
        wire.clearRetainingCapacity();
    }
    try h.reserveAll(&encoder);
    const owned = h.Owned.collect(&encoder);
    var caller: [128]u8 = @splat(0xa5);
    for (owned.entries[0..owned.len]) |bytes| {
        try t.expect(bytes.len != 0);
        // First and last capacity bytes cover live storage and spare storage;
        // all allocations are compared after each refusal, not only this one.
        try h.reject(&encoder, bytes[0..1], &caller, &caller);
        try h.reject(&encoder, bytes[bytes.len - 1 ..], &caller, &caller);
        try h.reject(&encoder, bytes[bytes.len - 1 ..], caller[0..0], &caller);
        try h.reject(&encoder, h.suffix, bytes[0..1], &caller);
        try h.reject(&encoder, h.suffix, bytes[bytes.len - 1 ..], &caller);
        try h.reject(&encoder, "", bytes[bytes.len - 1 ..], &caller);
    }
    try h.retry(D, &encoder, h.suffix, &wire, if (after_reset) h.suffix else h.prefix ++ h.suffix, "");
}

pub fn contracts(comptime D: type, comptime E: type) !void {
    try receiver(D, E);
    try capacities(D, E, false);
    try capacities(D, E, true);
}
