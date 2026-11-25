const std = @import("std");
const h = @import("helpers.zig");
const t = h.t;

fn dictionary(comptime D: type, comptime E: type) !void {
    var caller: [512]u8 = @splat(0xa5);
    const payload = "immutable dictionary input repeats immutable dictionary input";
    const dict = caller[32..][0..payload.len];
    @memcpy(dict, payload);
    var encoder = E.initWithDictionary(t.allocator, try h.options(D, E), dict);
    defer encoder.deinit();
    // Wrappers and the embedded core normally borrow the same dictionary.
    // Separate equal dictionaries exercise both retained pointers explicitly.
    const raw_dict = caller[192..][0..payload.len];
    if (@hasField(E, "raw")) {
        @memcpy(raw_dict, payload);
        encoder.raw.dictionary = raw_dict;
    }
    try h.reject(&encoder, h.suffix, dict[0..1], &caller);
    try h.reject(&encoder, h.suffix, dict[dict.len - 1 ..], &caller);
    try h.reject(&encoder, "", dict, &caller);
    if (@hasField(E, "raw")) try h.reject(&encoder, h.suffix, raw_dict[raw_dict.len - 1 ..], &caller);

    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(t.allocator);
    // Immutable input and dictionary may share every byte. This also seeds
    // history and marks dictionary_available false before the second refusal.
    try h.feed(&encoder, dict, &wire);
    try t.expectEqualSlices(u8, payload, dict);
    try h.reserveAll(&encoder);
    try h.reject(&encoder, h.suffix, dict[dict.len - 1 ..], &caller);
    if (@hasField(E, "raw")) try h.reject(&encoder, h.suffix, raw_dict[0..1], &caller);
    try h.retry(D, &encoder, h.suffix, &wire, payload ++ h.suffix, dict);
    try h.allowDone(&encoder, dict, &caller);
    if (@hasField(E, "raw")) try h.allowDone(&encoder, raw_dict, &caller);
}

fn dictionaryAdjacent(comptime D: type, comptime E: type) !void {
    var caller: [512]u8 = @splat(0xa5);
    const payload = "adjacent dictionary can remain immutable caller input";
    const dict = caller[32..][0..payload.len];
    @memcpy(dict, payload);
    var encoder = E.initWithDictionary(t.allocator, try h.options(D, E), dict);
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(t.allocator);
    try h.feedWithOutput(&encoder, dict, caller[32 + payload.len ..][0..256], &wire);
    try h.finish(&encoder, &wire);
    try h.verify(D, E, wire.items, payload, dict);
    try t.expectEqualSlices(u8, payload, dict);
}

fn metadata(comptime D: type, comptime E: type, comptime field: []const u8) !void {
    var caller: [512]u8 = @splat(0xa5);
    const payload = "immutable gzip metadata may also be offered as plain input";
    const borrowed = caller[32..][0..payload.len];
    @memcpy(borrowed, payload);
    var options = try h.options(D, E);
    @field(options.header, field) = borrowed;
    options.header.header_crc = true;
    var encoder = E.initWithOptions(t.allocator, options);
    defer encoder.deinit();
    try h.reject(&encoder, h.suffix, borrowed[0..1], &caller);
    try h.reject(&encoder, h.suffix, borrowed[borrowed.len - 1 ..], &caller);
    try h.reject(&encoder, "", borrowed, &caller);
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(t.allocator);
    // Header serialization and raw parsing only read this borrowed range.
    try h.feed(&encoder, borrowed, &wire);
    try t.expectEqualSlices(u8, payload, borrowed);
    try h.reserveAll(&encoder);
    // Header publication must not discard the retained metadata contract.
    try h.reject(&encoder, h.suffix, borrowed[borrowed.len - 1 ..], &caller);
    try h.retry(D, &encoder, h.suffix, &wire, payload ++ h.suffix, "");
    try h.allowDone(&encoder, borrowed, &caller);
}

fn metadataAdjacentAndEmpty(comptime D: type, comptime E: type) !void {
    inline for (.{ false, true }) |empty_metadata| {
        var caller: [512]u8 = @splat(0xa5);
        const payload = "gzip metadata and output can meet at their boundary";
        const input = caller[32..][0..payload.len];
        @memcpy(input, payload);
        const borrowed = input[0..if (empty_metadata) 0 else input.len];
        var options = try h.options(D, E);
        options.header = .{ .extra = borrowed, .filename = borrowed, .comment = borrowed, .header_crc = true };
        var encoder = E.initWithOptions(t.allocator, options);
        defer encoder.deinit();
        var wire: std.ArrayList(u8) = .empty;
        defer wire.deinit(t.allocator);
        try h.feedWithOutput(&encoder, input, caller[32 + payload.len ..][0..256], &wire);
        try h.finish(&encoder, &wire);
        try h.verify(D, E, wire.items, payload, "");
        try t.expectEqualSlices(u8, payload, input);
    }
}

pub fn contracts(comptime D: type) !void {
    inline for (.{ D.RawDeflateIncrementalFixedEncoder, D.RawDeflateIncrementalBestEncoder, D.ZlibIncrementalFixedEncoder, D.ZlibIncrementalBestEncoder }) |E| {
        try dictionary(D, E);
        try dictionaryAdjacent(D, E);
    }
    inline for (.{ D.GzipIncrementalFixedEncoder, D.GzipIncrementalBestEncoder }) |E| {
        inline for (.{ "extra", "filename", "comment" }) |field| try metadata(D, E, field);
        try metadataAdjacentAndEmpty(D, E);
    }
}
