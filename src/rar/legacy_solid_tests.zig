const std = @import("std");
const archive_mod = @import("archive.zig");
const rar15 = @import("rar15.zig");
const rar20 = @import("rar20.zig");

test "RAR15 solid session honors archive-level continuation" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(allocator, @embedFile("testdata/rar15-solid.rar.b64"));
    defer allocator.free(bytes);
    const archive = try archive_mod.parse(bytes);
    try std.testing.expect(archive.solid);
    const entries = try entriesAlloc(allocator, archive);
    defer allocator.free(entries);
    try std.testing.expectEqual(@as(usize, 2), entries.len);
    try std.testing.expectEqual(archive_mod.Method.rar15, entries[0].method);
    try std.testing.expect(!entries[0].solid);
    try std.testing.expect(!entries[1].solid);
    try std.testing.expectError(
        error.UnsupportedRarFeature,
        archive.extractAlloc(allocator, entries[1]),
    );

    const selected = try archive.extractByNameAllocLimited(
        allocator,
        "b.txt",
        4096,
    );
    defer allocator.free(selected);
    try expectSha256(selected, "b67d4a6c25ae43db95a1113fb854eb30de44f6dcc4c735e35f0c321d668cdf57");

    var session = archive.extractSession(allocator, .{ .max_output_len = 4096 });
    defer session.deinit();
    const first = (try session.nextAlloc()).?;
    defer allocator.free(first.data);
    const second = (try session.nextAlloc()).?;
    defer allocator.free(second.data);
    try std.testing.expect((try session.nextAlloc()) == null);
    try std.testing.expectEqualStrings("a.txt", first.entry.name.bytes);
    try std.testing.expectEqualStrings("b.txt", second.entry.name.bytes);
    try std.testing.expectEqualSlices(u8, first.data, second.data);

    var missing = rar15.Session.init(allocator);
    defer missing.deinit();
    const packed_data = packedBytes(bytes, entries[1]);
    const output = try allocator.alloc(u8, entries[1].uncompressed_size);
    defer allocator.free(output);
    try std.testing.expectError(
        error.MissingRar15SolidState,
        missing.decodeMemberInto(packed_data, output, true),
    );
}

test "RAR20 solid session carries tables audio state and history" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(allocator, @embedFile("testdata/rar20-solid.rar.b64"));
    defer allocator.free(bytes);
    const archive = try archive_mod.parse(bytes);
    try std.testing.expect(archive.solid);
    const entries = try entriesAlloc(allocator, archive);
    defer allocator.free(entries);
    try std.testing.expectEqual(@as(usize, 2), entries.len);
    try std.testing.expectEqual(archive_mod.Method.rar20, entries[0].method);
    try std.testing.expect(!entries[0].solid);
    try std.testing.expect(entries[1].solid);
    try std.testing.expectError(
        error.UnsupportedRarFeature,
        archive.extractAlloc(allocator, entries[1]),
    );

    const selected = try archive.extractByNameAllocLimited(
        allocator,
        "SOLID2.TXT",
        32 * 1024,
    );
    defer allocator.free(selected);
    try expectSha256(selected, "548a9e748a8a7ced5c4872a87a4e47e12902c9f1f634e21952a7424b0b67a209");

    var session = archive.extractSession(allocator, .{ .max_output_len = 32 * 1024 });
    defer session.deinit();
    const first = (try session.nextAlloc()).?;
    defer allocator.free(first.data);
    const second = (try session.nextAlloc()).?;
    defer allocator.free(second.data);
    try std.testing.expect((try session.nextAlloc()) == null);
    try expectSha256(first.data, "728a75735f7b98ed13c6416c03a60c6436593944ba47b91deee84771ce5619f2");
    try std.testing.expectEqualSlices(u8, selected, second.data);

    var missing = rar20.Session.init(allocator);
    defer missing.deinit();
    const packed_data = packedBytes(bytes, entries[1]);
    const output = try allocator.alloc(u8, entries[1].uncompressed_size);
    defer allocator.free(output);
    try std.testing.expectError(
        error.MissingRar20SolidState,
        missing.decodeMemberInto(
            packed_data,
            output,
            entries[1].dictionary_size.?,
            true,
        ),
    );
}

test "RAR legacy solid replay is allocation failure safe" {
    const AllocationTest = struct {
        fn run(allocator: std.mem.Allocator, encoded: []const u8) !void {
            const archive = try archive_mod.parse(encoded);
            const output = try archive.extractByNameAllocLimited(
                allocator,
                "SOLID2.TXT",
                32 * 1024,
            );
            defer allocator.free(output);
            try expectSha256(output, "548a9e748a8a7ced5c4872a87a4e47e12902c9f1f634e21952a7424b0b67a209");
        }
    };
    const bytes = try fixtureAlloc(
        std.testing.allocator,
        @embedFile("testdata/rar20-solid.rar.b64"),
    );
    defer std.testing.allocator.free(bytes);
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        AllocationTest.run,
        .{bytes},
    );
}

test "RAR legacy solid sessions poison after malformed members" {
    const allocator = std.testing.allocator;
    const rar15_bytes = try fixtureAlloc(
        allocator,
        @embedFile("testdata/rar15-solid.rar.b64"),
    );
    defer allocator.free(rar15_bytes);
    const rar15_archive = try archive_mod.parse(rar15_bytes);
    const rar15_entries = try entriesAlloc(allocator, rar15_archive);
    defer allocator.free(rar15_entries);
    var rar15_session = rar15.Session.init(allocator);
    defer rar15_session.deinit();
    const rar15_output = try allocator.alloc(u8, rar15_entries[0].uncompressed_size);
    defer allocator.free(rar15_output);
    try std.testing.expectError(
        error.TruncatedFrame,
        rar15_session.decodeMemberInto(
            packedBytes(rar15_bytes, rar15_entries[0])[0..1],
            rar15_output,
            false,
        ),
    );
    try std.testing.expectError(
        error.Rar15DecoderPoisoned,
        rar15_session.decodeMemberInto(
            packedBytes(rar15_bytes, rar15_entries[1]),
            rar15_output,
            true,
        ),
    );

    const rar20_bytes = try fixtureAlloc(
        allocator,
        @embedFile("testdata/rar20-solid.rar.b64"),
    );
    defer allocator.free(rar20_bytes);
    const rar20_archive = try archive_mod.parse(rar20_bytes);
    const rar20_entries = try entriesAlloc(allocator, rar20_archive);
    defer allocator.free(rar20_entries);
    var rar20_session = rar20.Session.init(allocator);
    defer rar20_session.deinit();
    const rar20_output = try allocator.alloc(u8, rar20_entries[0].uncompressed_size);
    defer allocator.free(rar20_output);
    try std.testing.expectError(
        error.TruncatedFrame,
        rar20_session.decodeMemberInto(
            packedBytes(rar20_bytes, rar20_entries[0])[0..1],
            rar20_output,
            rar20_entries[0].dictionary_size.?,
            false,
        ),
    );
    try std.testing.expectError(
        error.Rar20DecoderPoisoned,
        rar20_session.decodeMemberInto(
            packedBytes(rar20_bytes, rar20_entries[1]),
            rar20_output[0..rar20_entries[1].uncompressed_size],
            rar20_entries[1].dictionary_size.?,
            true,
        ),
    );
}

fn fixtureAlloc(allocator: std.mem.Allocator, encoded: []const u8) ![]u8 {
    const decoder = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const bytes = try allocator.alloc(u8, decoder.calcSizeUpperBound(encoded.len));
    errdefer allocator.free(bytes);
    const written = try decoder.decode(bytes, encoded);
    return allocator.realloc(bytes, written);
}

fn entriesAlloc(
    allocator: std.mem.Allocator,
    archive: archive_mod.Archive,
) ![]archive_mod.Entry {
    const entries = try allocator.alloc(archive_mod.Entry, archive.entry_count);
    errdefer allocator.free(entries);
    var iterator = archive.iterator();
    var count: usize = 0;
    while (try iterator.next()) |entry| {
        entries[count] = entry;
        count += 1;
    }
    if (count != entries.len) return error.InvalidRarArchive;
    return entries;
}

fn packedBytes(bytes: []const u8, entry: archive_mod.Entry) []const u8 {
    return bytes[entry.data_offset..][0..entry.compressed_size];
}

fn expectSha256(bytes: []const u8, expected_text: []const u8) !void {
    var actual: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &actual, .{});
    var expected: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, expected_text);
    try std.testing.expectEqual(expected, actual);
}
