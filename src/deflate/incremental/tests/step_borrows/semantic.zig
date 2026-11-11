//! Reuse independent RFC fixtures; do not borrow production match planning.
const std = @import("std");
const h = @import("helpers.zig");
const fixtures = @import("../rolling_semantic/fixtures.zig");
const checksum = @import("../../../../checksum.zig");
const allocator = std.testing.allocator;

fn wrap(comptime D: type, fixture: fixtures.Fixture) ![]u8 {
    const prefix: usize = if (D == h.Raw) 0 else if (D == h.Zlib) 2 else 10;
    const suffix: usize = if (D == h.Raw) 0 else if (D == h.Zlib) 4 else 8;
    const wire = try allocator.alloc(u8, prefix + fixture.body_len + suffix);
    if (D == h.Zlib) @memcpy(wire[0..2], &[_]u8{ 0x78, 0x01 });
    if (D == h.Gzip) @memcpy(wire[0..10], &[_]u8{ 0x1f, 0x8b, 8, 0, 0, 0, 0, 0, 0, 3 });
    @memcpy(wire[prefix..][0..fixture.body_len], fixture.encoded[0..fixture.body_len]);
    const footer = prefix + fixture.body_len;
    if (D == h.Zlib) std.mem.writeInt(u32, wire[footer..][0..4], checksum.Adler32.hash(fixture.payload), .big);
    if (D == h.Gzip) {
        std.mem.writeInt(u32, wire[footer..][0..4], checksum.Crc32.hash(fixture.payload), .little);
        std.mem.writeInt(u32, wire[footer + 4 ..][0..4], @intCast(fixture.payload.len), .little);
    }
    return wire;
}

fn drive(decoder: anytype, wire: []const u8, output: []u8, payload: []const u8) !void {
    var consumed: usize = 0;
    var written: usize = 0;
    for (0..1024) |_| {
        const result = try decoder.step(wire[consumed..], output);
        consumed += result.progress.input_read;
        const n = result.progress.output_written;
        try std.testing.expectEqualSlices(u8, payload[written..][0..n], output[0..n]);
        written += n;
        if (result.status == .done) {
            try std.testing.expectEqual(wire.len, consumed);
            try std.testing.expectEqual(payload.len, written);
            return;
        }
        try std.testing.expect(result.progress.input_read != 0 or n != 0);
    }
    return error.TestUnexpectedResult;
}

fn optional(comptime D: type, fixture: fixtures.Fixture, input_in_scratch: bool, output_in_scratch: bool, input_in_workspace: bool) !void {
    const wire = try wrap(D, fixture);
    defer allocator.free(wire);
    var history: [65536]u8 = @splat(0x5a);
    var decoder = try h.init(D, &history);
    var workspace: h.Raw.SemanticWorkspace = undefined;
    const tables = std.mem.asBytes(&workspace);
    @memset(tables, 0x6a);
    try h.raw(&decoder).attachSemanticWorkspace(&workspace);
    const input = if (input_in_scratch) history[32768..][0..wire.len] else if (input_in_workspace) tables[0..wire.len] else wire;
    if (input.ptr != wire.ptr) @memcpy(input, wire);
    const before = try allocator.dupe(u8, tables);
    defer allocator.free(before);
    var independent: [257]u8 = undefined;
    const output = if (output_in_scratch) history[49152..][0..257] else &independent;
    try drive(&decoder, input, output, fixture.payload);
    try std.testing.expectEqualSlices(u8, wire, input);
    try std.testing.expectEqualSlices(u8, before, tables);
    try std.testing.expectEqual(@as(u64, 0), h.raw(&decoder).semanticBlocksStarted());
    try std.testing.expect(h.raw(&decoder).semantic_decoder == &workspace);
}

fn outputWorkspace(comptime D: type, fixture: fixtures.Fixture) !void {
    const wire = try wrap(D, fixture);
    defer allocator.free(wire);
    var history: [65536]u8 = @splat(0x5a);
    var decoder = try h.init(D, &history);
    var workspace: h.Raw.SemanticWorkspace = undefined;
    @memset(std.mem.asBytes(&workspace), 0x6a);
    try h.raw(&decoder).attachSemanticWorkspace(&workspace);
    try drive(&decoder, wire, std.mem.asBytes(&workspace)[0..257], fixture.payload);
    try std.testing.expectEqual(@as(u64, 0), h.raw(&decoder).semanticBlocksStarted());
    try std.testing.expect(h.raw(&decoder).semantic_decoder == &workspace);
}

fn receiverWorkspace(comptime D: type, fixture: fixtures.Fixture) !void {
    const wire = try wrap(D, fixture);
    defer allocator.free(wire);
    const alignment = @max(@alignOf(D), @alignOf(h.Raw.SemanticWorkspace));
    const backing = try allocator.alignedAlloc(u8, .fromByteUnits(alignment), @sizeOf(D) + @sizeOf(h.Raw.SemanticWorkspace));
    defer allocator.free(backing);
    @memset(backing, 0x6a);
    const decoder: *D = @ptrCast(backing.ptr);
    var history: [65536]u8 = @splat(0x5a);
    decoder.* = try h.init(D, &history);
    // For wrappers place the workspace after raw, in live wrapper metadata.
    // Raw's own preflight alone cannot see that parent receiver collision.
    const offset = if (D == h.Raw) 0 else std.mem.alignForward(usize, @offsetOf(D, "header"), alignment);
    const workspace: *h.Raw.SemanticWorkspace = @ptrCast(@alignCast(backing[offset..].ptr));
    try h.raw(decoder).attachSemanticWorkspace(workspace);
    var output: [257]u8 = undefined;
    try drive(decoder, wire, &output, fixture.payload);
    try std.testing.expectEqual(@as(u64, 0), h.raw(decoder).semanticBlocksStarted());
    try std.testing.expect(h.raw(decoder).semantic_decoder == workspace);
}

fn active(comptime D: type, fixture: fixtures.Fixture) !void {
    const wire = try wrap(D, fixture);
    defer allocator.free(wire);
    var history: [65536]u8 = @splat(0x5a);
    var decoder = try h.init(D, &history);
    var workspace: h.Raw.SemanticWorkspace = undefined;
    @memset(std.mem.asBytes(&workspace), 0x6a);
    try h.raw(&decoder).attachSemanticWorkspace(&workspace);
    const first = try decoder.step(wire, &.{});
    try std.testing.expectEqual(.need_output, first.status);
    try std.testing.expectEqual(h.Raw.Phase.fast_dynamic_block, h.raw(&decoder).phase);
    const history_before = history;
    const tables_before = try allocator.dupe(u8, std.mem.asBytes(&workspace));
    defer allocator.free(tables_before);
    var output: [257]u8 = @splat(0x81);
    const remaining = wire[first.progress.input_read..];
    inline for (.{ false, true }) |boundary| {
        try h.reject(&decoder, history[65535..], &output, boundary);
        try h.reject(&decoder, remaining, history[49152..][0..257], boundary);
        try h.reject(&decoder, std.mem.asBytes(&workspace)[0..1], &output, boundary);
        try h.reject(&decoder, remaining, std.mem.asBytes(&workspace)[0..257], boundary);
        // Empty caller output does not make private generation storage inactive.
        try h.reject(&decoder, history[65535..], &.{}, boundary);
        try std.testing.expectEqualSlices(u8, &history_before, &history);
        try std.testing.expectEqualSlices(u8, tables_before, std.mem.asBytes(&workspace));
    }
    try drive(&decoder, remaining, &output, fixture.payload);
    // This exact-body fixture may finish its short tail through compact
    // fallback; the refusal must preserve the already-started generation.
    try std.testing.expectEqual(@as(u64, 1), h.raw(&decoder).semanticBlocksStarted());
}

test "incremental step borrows keep colliding optional semantic storage inactive" {
    const fixture = try fixtures.capacityRegression(allocator);
    defer fixture.deinit(allocator);
    inline for (.{ h.Raw, h.Zlib, h.Gzip }) |D| {
        try optional(D, fixture, true, false, false);
        try optional(D, fixture, false, true, false);
        try optional(D, fixture, false, false, true);
        try outputWorkspace(D, fixture);
        try receiverWorkspace(D, fixture);
    }
}

test "incremental step borrows protect active semantic generations and retry" {
    const fixture = try fixtures.capacityRegression(allocator);
    defer fixture.deinit(allocator);
    inline for (.{ h.Raw, h.Zlib, h.Gzip }) |D| try active(D, fixture);
}

test "zlib incremental step borrows keep semantic storage disjoint from retained dictionaries" {
    const fixture = try fixtures.capacityRegression(allocator);
    defer fixture.deinit(allocator);
    const wire = try wrap(h.Zlib, fixture);
    defer allocator.free(wire);
    inline for (.{ false, true }) |in_workspace| {
        var history: [65536]u8 = @splat(0x5a);
        var workspace: h.Raw.SemanticWorkspace = undefined;
        const tables = std.mem.asBytes(&workspace);
        @memset(tables, 0x6a);
        const dictionary = if (in_workspace) tables[0..8] else history[49152..][0..8];
        const entries = [_]h.deflate.ZlibDictionaryEntry{h.deflate.ZlibDictionarySet.entry(dictionary)};
        inline for (.{ false, true }) |set| {
            var decoder = if (set)
                try h.Zlib.initWithDictionarySet(.{}, &history, h.deflate.ZlibDictionarySet.fromEntries(&entries))
            else
                try h.Zlib.initWithDictionary(.{}, &history, dictionary);
            try decoder.raw.attachSemanticWorkspace(&workspace);
            const dictionary_before = dictionary[0..8].*;
            const tables_before = try allocator.dupe(u8, tables);
            defer allocator.free(tables_before);
            var output: [257]u8 = undefined;
            try drive(&decoder, wire, &output, fixture.payload);
            try std.testing.expectEqualSlices(u8, &dictionary_before, dictionary);
            try std.testing.expectEqualSlices(u8, tables_before, tables);
            try std.testing.expectEqual(@as(u64, 0), decoder.raw.semanticBlocksStarted());
            try std.testing.expect(decoder.raw.semantic_decoder == &workspace);
        }
    }

    var history: [65536]u8 = @splat(0x5a);
    var decoder = try h.Zlib.initWithDictionary(.{}, &history, "independent dictionary");
    var workspace: h.Raw.SemanticWorkspace = undefined;
    @memset(std.mem.asBytes(&workspace), 0x6a);
    try decoder.raw.attachSemanticWorkspace(&workspace);
    const first = try decoder.step(wire, &.{});
    try std.testing.expectEqual(h.Raw.Phase.fast_dynamic_block, decoder.raw.phase);
    const dictionary = decoder.dictionary;
    const history_before = history;
    const tables_before = try allocator.dupe(u8, std.mem.asBytes(&workspace));
    defer allocator.free(tables_before);
    var output: [257]u8 = undefined;
    decoder.dictionary = history[49152..][0..8];
    try h.reject(&decoder, wire[first.progress.input_read..], &output, false);
    try h.reject(&decoder, wire[first.progress.input_read..], &output, true);
    try std.testing.expectEqualSlices(u8, &history_before, &history);
    try std.testing.expectEqualSlices(u8, tables_before, std.mem.asBytes(&workspace));
    decoder.dictionary = dictionary;
    try drive(&decoder, wire[first.progress.input_read..], &output, fixture.payload);
}
