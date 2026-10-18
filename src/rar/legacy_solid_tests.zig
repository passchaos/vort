const std = @import("std");
const archive_mod = @import("archive.zig");
const checksum = @import("../checksum.zig");
const legacy_common = @import("legacy_common.zig");
const legacy_solid = @import("legacy_solid.zig");
const rar15 = @import("rar15.zig");
const rar20 = @import("rar20.zig");
const volume_set = @import("volume_set.zig");

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

test "RAR15 and RAR20 generations alternate in one solid session" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(
        allocator,
        @embedFile("testdata/rar15-rar20-mixed-solid.rar.b64"),
    );
    defer allocator.free(bytes);
    const archive = try archive_mod.parse(bytes);
    const entries = try entriesAlloc(allocator, archive);
    defer allocator.free(entries);
    try std.testing.expect(archive.solid);
    try std.testing.expectEqual(@as(usize, 3), entries.len);
    try std.testing.expectEqual(archive_mod.Method.rar15, entries[0].method);
    try std.testing.expectEqual(archive_mod.Method.rar20, entries[1].method);
    try std.testing.expectEqual(archive_mod.Method.rar15, entries[2].method);
    try std.testing.expectError(
        error.UnsupportedRarFeature,
        archive.extractAlloc(allocator, entries[1]),
    );

    const selected = try archive.extractByNameAllocLimited(
        allocator,
        "rar15-c.bin",
        1024,
    );
    defer allocator.free(selected);
    try expectSha256(selected, "a67c4ea4c604b4f8e5119c4b80d822be899aaa209c38c03cdf286935683ec822");

    const hashes = [_][]const u8{
        "107423cba4eb7f6b35e79710819acad7b8bd14c727ff09a4f4aab786ec49fb38",
        "0db94d3524e8e32f63c8e6af92006de43329dc3fe9ff5c45f3c8edfcc1bc8036",
        "a67c4ea4c604b4f8e5119c4b80d822be899aaa209c38c03cdf286935683ec822",
    };
    var session = archive.extractSession(allocator, .{ .max_output_len = 1024 });
    defer session.deinit();
    for (hashes) |hash| {
        const decoded = (try session.nextAlloc()).?;
        defer allocator.free(decoded.data);
        try expectSha256(decoded.data, hash);
    }
    try std.testing.expect((try session.nextAlloc()) == null);

    var raw = legacy_solid.Session.init(allocator);
    defer raw.deinit();
    for (entries, 0..) |entry, index| {
        const output = try allocator.alloc(u8, entry.uncompressed_size);
        defer allocator.free(output);
        try raw.decodeMemberInto(
            if (entry.method == .rar15) .rar15 else .rar20,
            packedBytes(bytes, entry),
            output,
            entry.dictionary_size.?,
            index != 0,
        );
        try expectSha256(output, hashes[index]);
    }

    var growing = legacy_solid.Session.init(allocator);
    defer growing.deinit();
    var first_output: [800]u8 = undefined;
    try growing.decodeMemberInto(
        .rar15,
        packedBytes(bytes, entries[0]),
        &first_output,
        entries[0].dictionary_size.?,
        false,
    );
    var second_output: [800]u8 = undefined;
    try std.testing.expectError(
        error.InvalidRarLegacySolidDictionary,
        growing.decodeMemberInto(
            .rar20,
            packedBytes(bytes, entries[1]),
            &second_output,
            512 * 1024,
            true,
        ),
    );
}

test "mixed legacy solid replay composes across RAR4 volumes" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(
        allocator,
        @embedFile("testdata/rar15-rar20-mixed-solid.rar.b64"),
    );
    defer allocator.free(bytes);
    var volumes = try mixedVolumesAlloc(allocator, bytes);
    defer volumes.deinit();
    var set = try volume_set.VolumeSet.parseAlloc(allocator, volumes.items);
    defer set.deinit();
    try std.testing.expectEqual(@as(usize, 3), set.entries.len);
    const decoded = try set.extractByNameAllocLimited(
        allocator,
        "rar15-c.bin",
        1024,
    );
    defer allocator.free(decoded);
    try expectSha256(decoded, "a67c4ea4c604b4f8e5119c4b80d822be899aaa209c38c03cdf286935683ec822");
}

test "legacy generation transitions translate shared distance registers" {
    const common = legacy_common.CommonState{
        .recent_distances = .{ 11, 22, 33, 44 },
        .last_distance = 55,
        .last_length = 66,
    };
    const history = [_]u8{1} ** (70 * 1024);
    var rar15_session = rar15.Session.init(std.testing.allocator);
    defer rar15_session.deinit();
    try rar15_session.synchronizeSolid(&history, common);
    try std.testing.expectEqual(common, rar15_session.commonState());

    var rar20_session = rar20.Session.init(std.testing.allocator);
    defer rar20_session.deinit();
    try rar20_session.synchronizeSolid(
        &history,
        rar15_session.commonState(),
        256 * 1024,
    );
    try std.testing.expectEqual(common, rar20_session.commonState());
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

test "mixed legacy solid replay is allocation failure safe" {
    const AllocationTest = struct {
        fn run(allocator: std.mem.Allocator, encoded: []const u8) !void {
            const archive = try archive_mod.parse(encoded);
            const output = try archive.extractByNameAllocLimited(
                allocator,
                "rar15-c.bin",
                1024,
            );
            defer allocator.free(output);
            try expectSha256(output, "a67c4ea4c604b4f8e5119c4b80d822be899aaa209c38c03cdf286935683ec822");
        }
    };
    const bytes = try fixtureAlloc(
        std.testing.allocator,
        @embedFile("testdata/rar15-rar20-mixed-solid.rar.b64"),
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

    const mixed_bytes = try fixtureAlloc(
        allocator,
        @embedFile("testdata/rar15-rar20-mixed-solid.rar.b64"),
    );
    defer allocator.free(mixed_bytes);
    const mixed_archive = try archive_mod.parse(mixed_bytes);
    const mixed_entries = try entriesAlloc(allocator, mixed_archive);
    defer allocator.free(mixed_entries);
    var mixed = legacy_solid.Session.init(allocator);
    defer mixed.deinit();
    var mixed_output: [800]u8 = undefined;
    try mixed.decodeMemberInto(
        .rar15,
        packedBytes(mixed_bytes, mixed_entries[0]),
        &mixed_output,
        mixed_entries[0].dictionary_size.?,
        false,
    );
    try std.testing.expectError(
        error.TruncatedFrame,
        mixed.decodeMemberInto(
            .rar20,
            packedBytes(mixed_bytes, mixed_entries[1])[0..1],
            &mixed_output,
            mixed_entries[1].dictionary_size.?,
            true,
        ),
    );
    try std.testing.expectError(
        error.RarLegacySessionPoisoned,
        mixed.decodeMemberInto(
            .rar20,
            packedBytes(mixed_bytes, mixed_entries[1]),
            &mixed_output,
            mixed_entries[1].dictionary_size.?,
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

const MixedVolumes = struct {
    allocator: std.mem.Allocator,
    items: [][]u8,

    fn deinit(self: *MixedVolumes) void {
        for (self.items) |bytes| self.allocator.free(bytes);
        self.allocator.free(self.items);
        self.* = undefined;
    }
};

fn mixedVolumesAlloc(allocator: std.mem.Allocator, source: []const u8) !MixedVolumes {
    const archive = try archive_mod.parse(source);
    const entries = try entriesAlloc(allocator, archive);
    defer allocator.free(entries);
    var volumes: std.ArrayList([]u8) = .empty;
    errdefer {
        for (volumes.items) |bytes| allocator.free(bytes);
        volumes.deinit(allocator);
    }
    for (entries, 0..) |entry, index| {
        var bytes: std.ArrayList(u8) = .empty;
        errdefer bytes.deinit(allocator);
        try bytes.appendSlice(allocator, source[0..archive.entries_offset]);
        const main_offset = archive.prefix_size + 7;
        const flags = std.mem.readInt(u16, bytes.items[main_offset + 3 ..][0..2], .little) | 1;
        std.mem.writeInt(u16, bytes.items[main_offset + 3 ..][0..2], flags, .little);
        const main_size = std.mem.readInt(u16, bytes.items[main_offset + 5 ..][0..2], .little);
        const main_end = main_offset + main_size;
        const main_crc: u16 = @truncate(checksum.crc32(bytes.items[main_offset + 2 .. main_end]));
        std.mem.writeInt(u16, bytes.items[main_offset..][0..2], main_crc, .little);
        try bytes.appendSlice(allocator, source[entry.header_offset..entry.next_offset]);
        try appendEndBlock(allocator, &bytes, index + 1 != entries.len);
        const owned = try bytes.toOwnedSlice(allocator);
        volumes.append(allocator, owned) catch |err| {
            allocator.free(owned);
            return err;
        };
    }
    return .{ .allocator = allocator, .items = try volumes.toOwnedSlice(allocator) };
}

fn appendEndBlock(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    has_next: bool,
) !void {
    const start = output.items.len;
    try output.appendNTimes(allocator, 0, 2);
    try output.append(allocator, 0x7b);
    var flags: [2]u8 = undefined;
    std.mem.writeInt(u16, &flags, 0x4000 | @as(u16, @intFromBool(has_next)), .little);
    try output.appendSlice(allocator, &flags);
    try output.appendSlice(allocator, &.{ 7, 0 });
    const crc: u16 = @truncate(checksum.crc32(output.items[start + 2 ..]));
    std.mem.writeInt(u16, output.items[start..][0..2], crc, .little);
}
