const std = @import("std");
const archive = @import("archive.zig");
const writer = @import("writer.zig");

test "thin ar parses GNU names and requires explicit external bytes" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.ThinEncodeEntry{
        .{ .name = "short.o", .size = 5 },
        .{ .name = "objects/very-long-member-name.o", .size = 4 },
        .{ .name = "../unsafe.o", .size = 3 },
    };
    const encoded = try writer.encodeThinAlloc(allocator, &entries);
    defer allocator.free(encoded);
    const parsed = try archive.parse(encoded);
    try std.testing.expect(parsed.thin);
    try std.testing.expectEqual(entries.len, parsed.entry_count);

    const short = try parsed.entryAt(0);
    try std.testing.expect(short.external);
    try std.testing.expect(short.safe_path);
    try std.testing.expectEqual(@as(usize, 0), short.stored_size);
    try std.testing.expectError(
        error.ArEntryRequiresResolver,
        parsed.extractAlloc(allocator, short),
    );
    try std.testing.expectError(
        error.SizeMismatch,
        parsed.extractThinAllocLimited(allocator, short, "tiny", 5),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        parsed.extractThinAllocLimited(allocator, short, "alpha suffix", 4),
    );
    const output = try parsed.extractThinAllocLimited(
        allocator,
        short,
        "alpha suffix",
        5,
    );
    defer allocator.free(output);
    try std.testing.expectEqualStrings("alpha", output);

    var caller_output: [5]u8 = undefined;
    try std.testing.expectEqual(
        @as(usize, caller_output.len),
        try parsed.extractThinInto(short, "alpha suffix", &caller_output),
    );
    try std.testing.expectEqualStrings("alpha", &caller_output);
    var too_small: [4]u8 = undefined;
    try std.testing.expectError(
        error.OutputTooSmall,
        parsed.extractThinInto(short, "alpha suffix", &too_small),
    );

    const long = try parsed.entryAt(1);
    try std.testing.expectEqualStrings(entries[1].name, long.name);
    const unsafe = try parsed.entryAt(2);
    try std.testing.expect(!unsafe.safe_path);
}

test "thin resolver rejects inline archive members" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.EncodeEntry{.{ .name = "inline.txt", .data = "data" }};
    const encoded = try writer.encodeAlloc(allocator, &entries);
    defer allocator.free(encoded);
    const parsed = try archive.parse(encoded);
    try std.testing.expectError(
        error.ArEntryNotExternal,
        parsed.extractThinAlloc(allocator, try parsed.entryAt(0), "data"),
    );
}

test "thin ar rejects invalid GNU references and unsupported BSD inline names" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.ThinEncodeEntry{.{ .name = "member.o", .size = 4 }};
    const encoded = try writer.encodeThinAlloc(allocator, &entries);
    defer allocator.free(encoded);
    const parsed = try archive.parse(encoded);
    const entry = try parsed.entryAt(0);

    const bad_offset = try allocator.dupe(u8, encoded);
    defer allocator.free(bad_offset);
    @memset(bad_offset[entry.header_offset..][0..16], ' ');
    @memcpy(bad_offset[entry.header_offset..][0..4], "/999");
    try std.testing.expectError(error.InvalidArArchive, archive.parse(bad_offset));

    const bsd_name = try allocator.dupe(u8, encoded);
    defer allocator.free(bsd_name);
    @memset(bsd_name[entry.header_offset..][0..16], ' ');
    @memcpy(bsd_name[entry.header_offset..][0..4], "#1/4");
    try std.testing.expectError(error.UnsupportedArFeature, archive.parse(bsd_name));

    try std.testing.expectError(
        error.TruncatedFrame,
        archive.parse(archive.thin_signature ++ "short"),
    );
}

test "thin ar writer and resolver release every allocation failure path" {
    const AllocationTest = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const entries = [_]writer.ThinEncodeEntry{
                .{ .name = "first.o", .size = 5 },
                .{ .name = "objects/second-long-name.o", .size = 4 },
            };
            const encoded = try writer.encodeThinAlloc(allocator, &entries);
            defer allocator.free(encoded);
            const parsed = try archive.parse(encoded);
            const output = try parsed.extractThinByNameAllocLimited(
                allocator,
                "first.o",
                "alpha trailing bytes",
                5,
            );
            defer allocator.free(output);
            try std.testing.expectEqualStrings("alpha", output);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        AllocationTest.run,
        .{},
    );
}
