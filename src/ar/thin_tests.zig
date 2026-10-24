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

test "thin ar symbol indexes map GNU 32-bit and 64-bit names to members" {
    const allocator = std.testing.allocator;
    const first_symbols = [_][]const u8{ "alpha", "shared_a" };
    const second_symbols = [_][]const u8{ "beta", "calls_alpha" };
    const entries = [_]writer.ThinEncodeEntry{
        .{ .name = "first.o", .size = 123, .symbols = &first_symbols },
        .{
            .name = "objects/very-long-second-member.o",
            .size = 456,
            .symbols = &second_symbols,
        },
    };
    for ([_]writer.ThinSymbolIndexFormat{ .gnu32, .gnu64 }) |format| {
        const encoded = try writer.encodeThinAllocWithOptions(
            allocator,
            &entries,
            .{ .symbol_index_format = format },
        );
        defer allocator.free(encoded);
        const parsed = try archive.parse(encoded);
        try std.testing.expectEqual(@as(usize, 4), parsed.symbolCount());
        try std.testing.expectEqual(
            if (format == .gnu32) archive.SymbolTableFormat.gnu32 else .gnu64,
            parsed.symbol_table.?.format,
        );

        const alpha = parsed.findSymbol("alpha").?;
        const first = try parsed.entryForSymbol(alpha);
        try std.testing.expectEqualStrings(entries[0].name, first.name);
        try std.testing.expectEqualDeep(first, (try parsed.findEntryBySymbol("shared_a")).?);
        const beta = try parsed.symbolAt(2);
        try std.testing.expectEqualStrings("beta", beta.name);
        const second = try parsed.entryForSymbol(beta);
        try std.testing.expectEqualStrings(entries[1].name, second.name);
        try std.testing.expect(parsed.findSymbol("missing") == null);
        try std.testing.expect((try parsed.findEntryBySymbol("missing")) == null);
        try std.testing.expectError(error.RangeOutOfBounds, parsed.symbolAt(4));
        try std.testing.expectError(
            error.InvalidArArchive,
            parsed.entryForSymbol(.{
                .name = alpha.name,
                .member_header_offset = alpha.member_header_offset + 1,
            }),
        );

        var symbol_iterator = parsed.symbolIterator();
        var symbol_count: usize = 0;
        while (symbol_iterator.next()) |_| symbol_count += 1;
        try std.testing.expectEqual(parsed.symbolCount(), symbol_count);

        if (format == .gnu32) {
            var appended: std.ArrayList(u8) = .empty;
            defer appended.deinit(allocator);
            try appended.appendSlice(allocator, "prefix");
            try std.testing.expectEqual(
                encoded.len,
                try writer.encodeThinAppendWithOptions(
                    allocator,
                    &appended,
                    &entries,
                    .{ .symbol_index_format = format },
                ),
            );
            try std.testing.expectEqualSlices(u8, encoded, appended.items["prefix".len..]);
            const into = try allocator.alloc(u8, encoded.len);
            defer allocator.free(into);
            try std.testing.expectEqual(
                encoded.len,
                try writer.encodeThinIntoWithOptions(
                    allocator,
                    &entries,
                    .{ .symbol_index_format = format },
                    into,
                ),
            );
            try std.testing.expectEqualSlices(u8, encoded, into);
            try std.testing.expectError(
                error.OutputTooSmall,
                writer.encodeThinIntoWithOptions(
                    allocator,
                    &entries,
                    .{ .symbol_index_format = format },
                    into[0 .. into.len - 1],
                ),
            );
        }
    }
}

test "thin ar symbol indexes reject malformed wire and symbol names" {
    const allocator = std.testing.allocator;
    const symbols = [_][]const u8{"alpha"};
    const entries = [_]writer.ThinEncodeEntry{.{
        .name = "first.o",
        .size = 4,
        .symbols = &symbols,
    }};
    const encoded = try writer.encodeThinAlloc(allocator, &entries);
    defer allocator.free(encoded);

    const bad_offset = try allocator.dupe(u8, encoded);
    defer allocator.free(bad_offset);
    @memset(bad_offset[archive.thin_signature.len + archive.header_size ..][0..4], 0);
    try std.testing.expectError(error.InvalidArArchive, archive.parse(bad_offset));

    const bad_count = try allocator.dupe(u8, encoded);
    defer allocator.free(bad_count);
    std.mem.writeInt(
        u32,
        bad_count[archive.thin_signature.len + archive.header_size ..][0..4],
        2,
        .big,
    );
    try std.testing.expectError(error.InvalidArArchive, archive.parse(bad_count));

    const bad_name = [_][]const u8{"bad\x00symbol"};
    const invalid_entries = [_]writer.ThinEncodeEntry{.{
        .name = "first.o",
        .size = 4,
        .symbols = &bad_name,
    }};
    try std.testing.expectError(
        error.InvalidArSymbolName,
        writer.encodeThinAlloc(allocator, &invalid_entries),
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
                .{ .name = "first.o", .size = 5, .symbols = &.{"first_symbol"} },
                .{
                    .name = "objects/second-long-name.o",
                    .size = 4,
                    .symbols = &.{ "second_symbol", "second_alias" },
                },
            };
            const encoded = try writer.encodeThinAllocWithOptions(
                allocator,
                &entries,
                .{ .symbol_index_format = .gnu64 },
            );
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
