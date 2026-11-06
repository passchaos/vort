const std = @import("std");
const h = @import("helpers.zig");
const f = @import("fixtures.zig");
const storage = @import("decoder_storage.zig");

const Checkpoint = enum { header, match, semantic, footer };

fn checkpoint(comptime T: type, comptime Raw: type, allocator: std.mem.Allocator, fixture: f.Fixture, comptime gzip: bool, comptime point: Checkpoint) !void {
    const wire = try f.wrap(allocator, fixture, gzip);
    defer allocator.free(wire);
    const history_len = if (point == .semantic) Raw.recommended_history_len else Raw.required_history_len;
    const history = try allocator.alignedAlloc(u8, .@"8", history_len + 1);
    defer allocator.free(history);
    @memset(history, 0x59);
    const target_history = try allocator.alignedAlloc(u8, .@"8", history_len);
    defer allocator.free(target_history);
    @memset(target_history, 0xa5);
    const source = try allocator.create(T);
    defer allocator.destroy(source);
    source.* = try T.init(.{ .expected_output_len = fixture.plain.len }, history);
    const destination = try allocator.create(T);
    defer allocator.destroy(destination);
    destination.* = try T.init(.{}, target_history);
    const source_workspace: ?*Raw.SemanticWorkspace = if (point == .semantic) try allocator.create(Raw.SemanticWorkspace) else null;
    defer if (source_workspace) |workspace| allocator.destroy(workspace);
    const target_workspace: ?*Raw.SemanticWorkspace = if (point == .semantic) try allocator.create(Raw.SemanticWorkspace) else null;
    defer if (target_workspace) |workspace| allocator.destroy(workspace);
    if (source_workspace) |workspace| {
        @memset(std.mem.asBytes(workspace), 0x73);
        @memset(std.mem.asBytes(target_workspace.?), 0xa5);
        try source.raw.attachSemanticWorkspace(workspace);
    }
    const output = try allocator.alloc(u8, fixture.plain.len);
    defer allocator.free(output);
    const first_input = switch (point) {
        .header => wire[0..1],
        .footer => wire[0 .. wire.len - 3],
        else => wire,
    };
    const first = try source.step(first_input, output[0..switch (point) {
        .header => 2,
        .match => 2,
        .semantic => 1,
        .footer => output.len,
    }]);
    switch (point) {
        .header => {
            try std.testing.expectEqual(.header, source.phase);
            try std.testing.expectEqual(@as(usize, 1), source.header_received);
        },
        .match => try std.testing.expectEqual(.match_copy, source.raw.phase),
        .semantic => {
            try std.testing.expectEqual(.fast_dynamic_block, source.raw.phase);
            try std.testing.expect(source.raw.semantic_generated_end > source.raw.semantic_delivered);
        },
        .footer => {
            try std.testing.expectEqual(.footer, source.phase);
            try std.testing.expect(source.footer_received != 0);
            try std.testing.expectEqual(fixture.plain.len, first.progress.output_written);
        },
    }
    try storage.matrix(T, allocator, source, destination, target_history, history, target_workspace);
    const before = source.snapshot();
    try source.cloneInto(destination, .{ .history = target_history, .semantic_workspace = target_workspace });
    try std.testing.expectEqualDeep(before, source.snapshot());
    try std.testing.expectEqualDeep(before, destination.snapshot());
    try storage.expectRaw(&source.raw, &destination.raw);
    if (gzip) {
        try std.testing.expectEqualDeep(source.crc, destination.crc);
        try std.testing.expectEqualDeep(source.header_crc, destination.header_crc);
    } else try std.testing.expectEqualDeep(source.adler, destination.adler);
    const remaining_wire = wire[first.progress.input_read..];
    const remaining_plain = fixture.plain[first.progress.output_written..];
    if (point == .footer) {
        var corrupt: [3]u8 = undefined;
        @memcpy(&corrupt, remaining_wire);
        corrupt[0] ^= 0x80;
        if (source.step(&corrupt, &.{})) |_| return error.TestUnexpectedResult else |_| {}
        try std.testing.expect(source.last_error_name.len != 0);
        try std.testing.expectEqual(@as(usize, 0), destination.last_error_name.len);
    } else {
        try storage.continueDecoder(allocator, source, remaining_wire, remaining_plain, if (point == .semantic) wire.len else 1, 11);
        source.reset();
    }
    @memset(history, 0xdb);
    if (source_workspace) |workspace| @memset(std.mem.asBytes(workspace), 0xdb);
    try storage.continueDecoder(allocator, destination, remaining_wire, remaining_plain, if (point == .semantic) wire.len else 3, 257);
    if (gzip) {
        try std.testing.expectEqual(f.crc(fixture.plain), destination.crc.digest());
        try std.testing.expectEqual(@as(@FieldType(T, "member_count"), 1), destination.member_count);
    } else {
        try std.testing.expectEqual(f.adler(fixture.plain), destination.adler.digest());
        try std.testing.expectEqual(@as(@FieldType(T, "stream_count"), 1), destination.stream_count);
    }
}

fn dictionary(comptime D: type, allocator: std.mem.Allocator, comptime dictionary_set: bool) !void {
    const T = D.ZlibIncrementalDecoder;
    const Raw = D.RawDeflateIncrementalFixedLiteralDecoder;
    const fixture = try f.dictionaryMatch(allocator);
    defer fixture.deinit(allocator);
    const dictionary_bytes = "immutable dictionary ends with x";
    const wire = try f.wrapDictionary(allocator, fixture, dictionary_bytes);
    defer allocator.free(wire);
    const history = try allocator.alignedAlloc(u8, .@"8", Raw.required_history_len + 1);
    defer allocator.free(history);
    @memset(history, 0x59);
    const target_history = try allocator.alignedAlloc(u8, .@"8", Raw.required_history_len);
    defer allocator.free(target_history);
    @memset(target_history, 0xa5);
    const entries = [_]D.ZlibDictionaryEntry{.{ .id = f.adler(dictionary_bytes), .bytes = dictionary_bytes }};
    var source = if (dictionary_set)
        try T.initWithDictionarySet(.{}, history, D.ZlibDictionarySet.fromEntries(&entries))
    else
        try T.initWithDictionary(.{}, history, dictionary_bytes);
    var destination = try T.init(.{}, target_history);
    const first = try source.step(wire[0..4], &.{});
    try std.testing.expectEqual(@as(usize, 4), first.progress.input_read);
    try std.testing.expectEqual(.dictid, source.phase);
    try std.testing.expectEqual(@as(usize, 2), source.dictid_received);
    try source.cloneInto(&destination, .{ .history = target_history });
    try std.testing.expectEqual(source.dictionary.ptr, destination.dictionary.ptr);
    if (dictionary_set) try std.testing.expectEqual(source.dictionaries.?.entries.ptr, destination.dictionaries.?.entries.ptr);
    try storage.continueDecoder(allocator, &source, wire[4..], fixture.plain, 1, 1);
    @memset(history, 0xdb);
    try storage.continueDecoder(allocator, &destination, wire[4..], fixture.plain, 3, 17);
    // Reset preserves the borrow in both copies, so dictionary validation and
    // history seeding must still work after independent stream completion.
    source.reset();
    destination.reset();
    try storage.continueDecoder(allocator, &source, wire, fixture.plain, 1, 19);
    try storage.continueDecoder(allocator, &destination, wire, fixture.plain, 4, 23);

    source.reset();
    source.dictionary = target_history[17..49];
    try storage.reject(allocator, &source, &destination, .{ .history = target_history }, error.OverlappingCloneStorage);
    source.dictionary = dictionary_bytes;
    const overlapping_entry: *D.ZlibDictionaryEntry = @ptrCast(@alignCast(target_history.ptr));
    overlapping_entry.* = .{ .id = f.adler(dictionary_bytes), .bytes = dictionary_bytes };
    source.dictionaries = D.ZlibDictionarySet.fromEntries(@as([*]D.ZlibDictionaryEntry, @ptrCast(overlapping_entry))[0..1]);
    try storage.reject(allocator, &source, &destination, .{ .history = target_history }, error.OverlappingCloneStorage);
    const borrowed_entry = [_]D.ZlibDictionaryEntry{.{ .id = 0, .bytes = target_history[64..96] }};
    source.dictionaries = D.ZlibDictionarySet.fromEntries(&borrowed_entry);
    try storage.reject(allocator, &source, &destination, .{ .history = target_history }, error.OverlappingCloneStorage);
}

pub fn contracts(comptime D: type, allocator: std.mem.Allocator) !void {
    const Raw = D.RawDeflateIncrementalFixedLiteralDecoder;
    const fixed = try f.fixedMatch(allocator);
    defer fixed.deinit(allocator);
    const dynamic = try f.dynamicGenerations(allocator);
    defer dynamic.deinit(allocator);
    inline for (.{ .{ D.ZlibIncrementalDecoder, false }, .{ D.GzipIncrementalDecoder, true } }) |entry| {
        inline for (.{ Checkpoint.header, Checkpoint.match, Checkpoint.footer }) |point|
            try checkpoint(entry[0], Raw, allocator, fixed, entry[1], point);
        try checkpoint(entry[0], Raw, allocator, dynamic, entry[1], .semantic);
    }
    try dictionary(D, allocator, false);
    try dictionary(D, allocator, true);
}
