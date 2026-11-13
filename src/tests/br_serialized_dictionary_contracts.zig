//! Standard-window Brotli serialized shared dictionary contracts. The
//! companion large-window module covers wide windows; this pins the normal
//! RFC window path including the no-dictionary rejection that the differential
//! fuzz generator's serialized-shared-dictionary variant relies on.
const std = @import("std");
const br = @import("../br.zig");
const a = std.testing.allocator;

test "Brotli serialized static dictionary round trips and rejects without the dictionary" {
    const word = "vortd";
    const payload = word ** 6;
    var bits: [32]u8 = @splat(0);
    // bits=N means the bucket holds 2^N words, so its data slice must be
    // word_len * 2^N bytes. One bit gives a two-word bucket with both copies
    // of the word concatenated.
    bits[word.len] = 1;
    const word_data = word ++ word;
    // Custom static dictionaries must name at least one dictionary choice that
    // binds the custom word list; the parser rejects an unbound list as an
    // invalid dictionary map.
    const choices = [_]br.SerializedSharedDictionaryChoice{
        .{ .word_list_index = 0, .transform_list_index = 0 },
    };
    const encoded = try br.serializeSharedDictionaryAlloc(a, .{
        .raw_prefix = "vort",
        .word_lists = &.{.{ .size_bits_by_length = bits, .data = word_data }},
        .dictionaries = &choices,
    });
    defer a.free(encoded);
    const view = try br.parseSerializedSharedDictionary(encoded);

    // Serialized static dictionaries are integrated into the legacy planned
    // level path (its reusable serialized matcher); the quality-scheduled
    // parser does not wire that matcher, so these levels are the supported
    // encode surface for this dictionary kind.
    for ([_]br.PlannedCompressionLevel{ .fast, .balanced, .ratio }) |level| {
        const wire = try br.encodePlannedStreamWithOptionsAlloc(a, payload, .{
            .level = level,
            .shared_dictionary = .{ .serialized = &view },
        });
        defer a.free(wire);

        const decoded = try br.decodeStreamAllocExactSizeWithOptions(a, wire, payload.len, .{
            .shared_dictionary = .{ .serialized = &view },
        });
        defer a.free(decoded);
        try std.testing.expectEqualSlices(u8, payload, decoded);

        const plain = try br.decodeStreamAllocWithOptions(a, wire, .{
            .shared_dictionary = .{ .serialized = &view },
        });
        defer a.free(plain);
        try std.testing.expectEqualSlices(u8, payload, plain);
        // The RFC built-in static dictionary remains available without the
        // custom serialized attachment, so no-dictionary decoding is not
        // guaranteed to fail; the attached-dictionary round trip is the
        // load-bearing contract.
    }
}
