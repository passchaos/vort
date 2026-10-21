const std = @import("std");
const archive = @import("archive.zig");

const fixture_text = @embedFile("testdata/unarc-rs-license-garble.arj.b64");
const expected_sha256_hex = "c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4";

fn fixtureAlloc(allocator: std.mem.Allocator) ![]u8 {
    const decoder = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const bytes = try allocator.alloc(
        u8,
        decoder.calcSizeUpperBound(fixture_text.len),
    );
    errdefer allocator.free(bytes);
    const len = try decoder.decode(bytes, fixture_text);
    return allocator.realloc(bytes, len);
}

test "ARJ Garble decrypts the independent unarc-rs fixture" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(allocator);
    defer allocator.free(bytes);
    const parsed = try archive.parse(bytes);
    try std.testing.expectEqual(@as(usize, 1), parsed.entry_count);
    try std.testing.expectEqual(@as(u8, 1), parsed.encryption_version);
    const entry = try parsed.entryAt(0);
    try std.testing.expectEqual(archive.Encryption.garble, entry.encryption.?);
    try std.testing.expectEqual(@as(u8, 0xbd), entry.password_modifier);
    try std.testing.expect(entry.name.eql("LICENSE"));
    try std.testing.expectError(
        error.EncryptedArjEntry,
        parsed.extractAlloc(allocator, entry),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        parsed.extractAllocWithOptions(
            allocator,
            entry,
            .{ .password = "secret", .max_output_len = entry.uncompressed_size - 1 },
        ),
    );
    const decoded = try parsed.extractAllocWithOptions(
        allocator,
        entry,
        .{ .password = "secret" },
    );
    defer allocator.free(decoded);
    var expected_sha256: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected_sha256, expected_sha256_hex);
    var actual_sha256: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(decoded, &actual_sha256, .{});
    try std.testing.expectEqualSlices(u8, &expected_sha256, &actual_sha256);

    if (parsed.extractAllocWithOptions(
        allocator,
        entry,
        .{ .password = "wrong" },
    )) |wrong| {
        allocator.free(wrong);
        return error.TestUnexpectedResult;
    } else |_| {}
}

test "ARJ Garble extraction releases every allocation failure" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(allocator);
    defer allocator.free(bytes);
    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator, input: []const u8) !void {
            const parsed = try archive.parse(input);
            const decoded = try parsed.extractAllocWithOptions(
                failing_allocator,
                try parsed.entryAt(0),
                .{ .password = "secret" },
            );
            defer failing_allocator.free(decoded);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{bytes});
}
