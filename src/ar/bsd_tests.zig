const std = @import("std");
const archive = @import("archive.zig");
const writer = @import("writer.zig");

test "BSD ar symbol indexes map 32-bit 64-bit and sorted names to members" {
    const allocator = std.testing.allocator;
    const first_symbols = [_][]const u8{ "zeta", "alpha", "shared_a" };
    const second_symbols = [_][]const u8{ "beta", "shared_b", "calls_alpha" };
    const entries = [_]writer.EncodeEntry{
        .{
            .name = "first.o",
            .data = "first object bytes",
            .symbols = &first_symbols,
            .mode = 0o100600,
        },
        .{
            .name = "objects/very-long-second-object-name.o",
            .data = "second object bytes!",
            .symbols = &second_symbols,
        },
    };
    const cases = [_]struct {
        requested: writer.BsdSymbolIndexFormat,
        expected: archive.SymbolTableFormat,
        sorted: bool,
    }{
        .{ .requested = .bsd32, .expected = .bsd32, .sorted = false },
        .{ .requested = .bsd32_sorted, .expected = .bsd32_sorted, .sorted = true },
        .{ .requested = .bsd64, .expected = .bsd64, .sorted = false },
        .{ .requested = .bsd64_sorted, .expected = .bsd64_sorted, .sorted = true },
    };

    const automatic = try writer.encodeAlloc(allocator, &entries);
    defer allocator.free(automatic);
    const automatic_archive = try archive.parse(automatic);
    try std.testing.expectEqual(
        archive.SymbolTableFormat.bsd32,
        automatic_archive.symbol_table.?.format,
    );

    for (cases) |case| {
        const encoded = try writer.encodeAllocWithOptions(
            allocator,
            &entries,
            .{ .symbol_index_format = case.requested },
        );
        defer allocator.free(encoded);
        const parsed = try archive.parse(encoded);
        try std.testing.expectEqual(@as(usize, 6), parsed.symbolCount());
        try std.testing.expectEqual(case.expected, parsed.symbol_table.?.format);

        const expected_names = if (case.sorted)
            [_][]const u8{ "alpha", "beta", "calls_alpha", "shared_a", "shared_b", "zeta" }
        else
            [_][]const u8{ "zeta", "alpha", "shared_a", "beta", "shared_b", "calls_alpha" };
        var symbol_iterator = parsed.symbolIterator();
        for (expected_names) |expected_name| {
            const symbol = symbol_iterator.next().?;
            try std.testing.expectEqualStrings(expected_name, symbol.name);
            const entry = try parsed.entryForSymbol(symbol);
            const expected_entry = if (std.mem.eql(u8, expected_name, "zeta") or
                std.mem.eql(u8, expected_name, "alpha") or
                std.mem.eql(u8, expected_name, "shared_a"))
                entries[0]
            else
                entries[1];
            try std.testing.expectEqualStrings(expected_entry.name, entry.name);
        }
        try std.testing.expect(symbol_iterator.next() == null);

        for (entries, 0..) |expected, index| {
            const entry = try parsed.entryAt(index);
            try std.testing.expectEqualStrings(expected.name, entry.name);
            const data = try parsed.extractAlloc(allocator, entry);
            defer allocator.free(data);
            try std.testing.expectEqualSlices(u8, expected.data, data);
        }
    }
}

test "BSD ar options cover append into empty indexes and legacy compatibility" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.EncodeEntry{.{ .name = "member.o", .data = "payload" }};
    const legacy = try writer.encodeAlloc(allocator, &entries);
    defer allocator.free(legacy);
    try std.testing.expect(legacy[archive.signature.len] != '#');

    const encoded = try writer.encodeAllocWithOptions(
        allocator,
        &entries,
        .{ .symbol_index_format = .bsd32 },
    );
    defer allocator.free(encoded);
    const parsed = try archive.parse(encoded);
    try std.testing.expectEqual(@as(usize, 0), parsed.symbolCount());
    try std.testing.expectEqual(archive.SymbolTableFormat.bsd32, parsed.symbol_table.?.format);
    try std.testing.expect(encoded[archive.signature.len] == '#');

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix");
    try std.testing.expectEqual(
        encoded.len,
        try writer.encodeAppendWithOptions(
            allocator,
            &appended,
            &entries,
            .{ .symbol_index_format = .bsd32 },
        ),
    );
    try std.testing.expectEqualSlices(u8, encoded, appended.items["prefix".len..]);

    const into = try allocator.alloc(u8, encoded.len);
    defer allocator.free(into);
    try std.testing.expectEqual(
        encoded.len,
        try writer.encodeIntoWithOptions(
            allocator,
            &entries,
            .{ .symbol_index_format = .bsd32 },
            into,
        ),
    );
    try std.testing.expectEqualSlices(u8, encoded, into);
    try std.testing.expectError(
        error.OutputTooSmall,
        writer.encodeIntoWithOptions(
            allocator,
            &entries,
            .{ .symbol_index_format = .bsd32 },
            into[0 .. into.len - 1],
        ),
    );
}

test "BSD ar symbol tables reject malformed ranlib and padded names" {
    const allocator = std.testing.allocator;
    const symbols = [_][]const u8{ "alpha", "beta" };
    const entries = [_]writer.EncodeEntry{.{
        .name = "long-object-member-name.o",
        .data = "object",
        .symbols = &symbols,
    }};
    const encoded = try writer.encodeAllocWithOptions(
        allocator,
        &entries,
        .{ .symbol_index_format = .bsd32 },
    );
    defer allocator.free(encoded);
    const parsed = try archive.parse(encoded);
    const table_payload_offset = archive.signature.len + archive.header_size + 12;

    const bad_ranlib_size = try allocator.dupe(u8, encoded);
    defer allocator.free(bad_ranlib_size);
    std.mem.writeInt(u32, bad_ranlib_size[table_payload_offset..][0..4], 7, .little);
    try std.testing.expectError(error.InvalidArArchive, archive.parse(bad_ranlib_size));

    const bad_string_offset = try allocator.dupe(u8, encoded);
    defer allocator.free(bad_string_offset);
    std.mem.writeInt(u32, bad_string_offset[table_payload_offset + 4 ..][0..4], 999, .little);
    try std.testing.expectError(error.InvalidArArchive, archive.parse(bad_string_offset));

    const entry = try parsed.entryAt(0);
    const stored_name_len = entry.data_offset - (entry.header_offset + archive.header_size);
    try std.testing.expect(stored_name_len >= entries[0].name.len + 2);
    const bad_name_padding = try allocator.dupe(u8, encoded);
    defer allocator.free(bad_name_padding);
    bad_name_padding[entry.header_offset + archive.header_size + entries[0].name.len + 1] = 'x';
    try std.testing.expectError(error.InvalidArArchive, archive.parse(bad_name_padding));

    const bad_symbol_names = [_][]const u8{"bad\x00symbol"};
    const invalid_entries = [_]writer.EncodeEntry{.{
        .name = "member.o",
        .data = "object",
        .symbols = &bad_symbol_names,
    }};
    try std.testing.expectError(
        error.InvalidArSymbolName,
        writer.encodeAlloc(allocator, &invalid_entries),
    );
}

test "BSD sorted ar writer releases every allocation failure path" {
    const AllocationTest = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const entries = [_]writer.EncodeEntry{
                .{
                    .name = "first.o",
                    .data = "first",
                    .symbols = &.{ "zeta", "alpha" },
                },
                .{
                    .name = "objects/second-long-name.o",
                    .data = "second",
                    .symbols = &.{ "beta", "calls_alpha" },
                },
            };
            const encoded = try writer.encodeAllocWithOptions(
                allocator,
                &entries,
                .{ .symbol_index_format = .bsd64_sorted },
            );
            defer allocator.free(encoded);
            const parsed = try archive.parse(encoded);
            try std.testing.expectEqual(@as(usize, 4), parsed.symbolCount());
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        AllocationTest.run,
        .{},
    );
}
