const std = @import("std");
const archive_mod = @import("archive.zig");
const writer = @import("writer.zig");

test "RAR4 Unicode writer exposes preferred and ANSI fallback names" {
    const allocator = std.testing.allocator;
    const name = "目录/данные/😀.txt";
    const entries = [_]writer.EncodeEntry{.{
        .name = name,
        .data = "RAR4 Unicode payload",
    }};
    const encoded = try writer.encodeAlloc(allocator, &entries, .{ .version = .rar4 });
    defer allocator.free(encoded);
    const borrowed = try archive_mod.parse(encoded);
    const raw_entry = try borrowed.entryAt(0);
    try std.testing.expect(raw_entry.rar4_unicode_data != null);
    try std.testing.expect(raw_entry.rar4_ansi_name != null);
    try std.testing.expect(!raw_entry.name.eql(name));

    var owned = try archive_mod.parseOwnedHeadersAllocWithOptions(allocator, encoded, .{});
    defer owned.deinit();
    const entry = try owned.archive.entryAt(0);
    try std.testing.expect(entry.name.eql(name));
    try std.testing.expect(entry.rar4_ansi_name != null);
    try std.testing.expect(entry.rar4_unicode_data == null);
    const found = (try owned.archive.find(name)).?;
    const decoded = try owned.archive.extractAlloc(allocator, found);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, entries[0].data, decoded);
}

test "RAR4 Unicode archive ownership releases every allocation failure" {
    const Test = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const entries = [_]writer.EncodeEntry{.{
                .name = "目录/данные.txt",
                .data = "allocation-safe Unicode name",
            }};
            const encoded = try writer.encodeAlloc(allocator, &entries, .{ .version = .rar4 });
            defer allocator.free(encoded);
            var owned = try archive_mod.parseOwnedHeadersAllocWithOptions(allocator, encoded, .{});
            defer owned.deinit();
            try std.testing.expect((try owned.archive.find(entries[0].name)) != null);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{});
}
