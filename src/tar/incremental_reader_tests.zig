const std = @import("std");
const reader_mod = @import("incremental_reader.zig");
const sparse = @import("sparse.zig");
const tar = @import("../tar.zig");
const wire = @import("wire.zig");

const ExpectedEntry = struct {
    name: []const u8,
    data: []const u8,
    kind: tar.Kind = .file,
    sparse_format: ?sparse.Format = null,
};

fn decodeAndCheck(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    expected: []const ExpectedEntry,
    input_chunk: usize,
    output_chunk: usize,
) !void {
    var reader = reader_mod.Reader.init(allocator);
    defer reader.deinit();
    const output = try allocator.alloc(u8, output_chunk);
    defer allocator.free(output);
    var entry_data: std.ArrayList(u8) = .empty;
    defer entry_data.deinit(allocator);
    var input_offset: usize = 0;
    var entry_index: usize = 0;
    var done = false;
    var iterations: usize = 0;
    while (!done) {
        iterations += 1;
        if (iterations > bytes.len * 8 + 1024) return error.TestUnexpectedResult;
        const input_end = @min(bytes.len, input_offset + input_chunk);
        const stepped = try reader.step(bytes[input_offset..input_end], output);
        input_offset += stepped.input_read;
        try entry_data.appendSlice(allocator, output[0..stepped.output_written]);
        switch (stepped.status) {
            .entry_header => {
                if (entry_index >= expected.len) return error.TestUnexpectedResult;
                const info = reader.currentEntry() orelse return error.TestUnexpectedResult;
                try std.testing.expectEqualStrings(expected[entry_index].name, info.name);
                try std.testing.expectEqual(expected[entry_index].kind, info.kind);
                try std.testing.expectEqual(expected[entry_index].data.len, info.size);
                try std.testing.expectEqual(expected[entry_index].sparse_format, info.sparse_format);
                entry_data.clearRetainingCapacity();
            },
            .entry_done => {
                if (entry_index >= expected.len) return error.TestUnexpectedResult;
                try std.testing.expectEqualSlices(u8, expected[entry_index].data, entry_data.items);
                entry_index += 1;
            },
            .done => done = true,
            .need_input => if (input_offset == bytes.len) return error.TestUnexpectedResult,
            .need_output => {},
        }
        if (stepped.input_read == 0 and stepped.output_written == 0 and
            stepped.status != .entry_header and stepped.status != .entry_done)
            return error.TestUnexpectedResult;
    }
    try std.testing.expectEqual(bytes.len, input_offset);
    try std.testing.expectEqual(expected.len, entry_index);
    try std.testing.expectEqual(expected.len, reader.snapshot().entry_count);
}

test "TAR incremental reader streams regular PAX and GNU sparse entries with tiny buffers" {
    const allocator = std.testing.allocator;
    const long_name = "nested/" ++ "long-component-" ** 12 ++ "file.txt";
    var pax_sparse: [8192]u8 = @splat(0);
    @memcpy(pax_sparse[0..4], "HEAD");
    @memcpy(pax_sparse[4096..4102], "MIDDLE");
    @memcpy(pax_sparse[8188..], "TAIL");
    var old_sparse: [8192]u8 = @splat(0);
    @memcpy(old_sparse[0..4], "OLDH");
    @memcpy(old_sparse[8188..], "OLDT");
    const pax_extents = [_]tar.SparseDataExtent{
        .{ .offset = 0, .data = pax_sparse[0..4] },
        .{ .offset = 4096, .data = pax_sparse[4096..4102] },
        .{ .offset = 8188, .data = pax_sparse[8188..] },
    };
    const old_extents = [_]tar.SparseDataExtent{
        .{ .offset = 0, .data = old_sparse[0..4] },
        .{ .offset = 8188, .data = old_sparse[8188..] },
    };
    const encoded = try tar.encodeAlloc(allocator, &.{
        .{ .name = "plain.txt", .data = "plain", .mode = 0o640 },
        .{ .name = long_name, .data = "long path" },
        .{ .name = "folder/", .kind = .directory },
        .{ .name = "link", .kind = .symbolic_link, .link_name = long_name },
        .{
            .name = "pax-sparse.bin",
            .sparse = .{ .logical_size = pax_sparse.len, .extents = &pax_extents },
        },
        .{
            .name = "old-sparse.bin",
            .sparse = .{
                .logical_size = old_sparse.len,
                .extents = &old_extents,
                .format = .gnu_old,
            },
        },
    });
    defer allocator.free(encoded);
    const expected = [_]ExpectedEntry{
        .{ .name = "plain.txt", .data = "plain" },
        .{ .name = long_name, .data = "long path" },
        .{ .name = "folder/", .data = "", .kind = .directory },
        .{ .name = "link", .data = "", .kind = .symbolic_link },
        .{ .name = "pax-sparse.bin", .data = &pax_sparse, .sparse_format = .pax_1_0 },
        .{ .name = "old-sparse.bin", .data = &old_sparse, .sparse_format = .gnu_old },
    };
    try decodeAndCheck(allocator, encoded, &expected, 1, 1);
    try decodeAndCheck(allocator, encoded, &expected, 997, 4096);
}

test "TAR incremental reader reconstructs GNU PAX sparse 0.0 and 0.1" {
    const allocator = std.testing.allocator;
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try appendLegacySparse(allocator, &encoded, "sparse-00.bin", .pax_0_0);
    try appendLegacySparse(allocator, &encoded, "sparse-01.bin", .pax_0_1);
    try encoded.appendNTimes(allocator, 0, 2 * wire.block_size);

    var logical: [20]u8 = @splat(0);
    @memcpy(logical[0..4], "HEAD");
    @memcpy(logical[12..15], "MID");
    const expected = [_]ExpectedEntry{
        .{ .name = "sparse-00.bin", .data = &logical, .sparse_format = .pax_0_0 },
        .{ .name = "sparse-01.bin", .data = &logical, .sparse_format = .pax_0_1 },
    };
    try decodeAndCheck(allocator, encoded.items, &expected, 1, 2);
}

test "TAR incremental reader enforces limits and poisons malformed streams" {
    const allocator = std.testing.allocator;
    const regular = try tar.encodeAlloc(allocator, &.{.{ .name = "plain", .data = "hello" }});
    defer allocator.free(regular);

    var limited = reader_mod.Reader.initWithOptions(allocator, .{ .max_logical_entry_size = 4 });
    defer limited.deinit();
    var output: [16]u8 = undefined;
    try std.testing.expectError(error.OutputLimitExceeded, limited.step(regular, &output));
    try std.testing.expectError(error.TarReaderPoisoned, limited.step("", &output));

    const Limit = struct {
        fn expect(options: reader_mod.Options, bytes: []const u8) !void {
            var reader = reader_mod.Reader.initWithOptions(std.testing.allocator, options);
            defer reader.deinit();
            var storage: [8192]u8 = undefined;
            try std.testing.expectError(error.OutputLimitExceeded, reader.step(bytes, &storage));
        }
    };
    try Limit.expect(.{ .max_entries = 0 }, regular);
    try Limit.expect(.{ .max_total_output_size = 4 }, regular);
    try Limit.expect(.{ .max_archive_size = 511 }, regular);

    var truncated = reader_mod.Reader.init(allocator);
    defer truncated.deinit();
    const partial = try truncated.step(regular[0..100], &output);
    try std.testing.expectEqual(reader_mod.Status.need_input, partial.status);
    try std.testing.expectError(error.TruncatedFrame, truncated.finish());
    try std.testing.expectError(error.TarReaderPoisoned, truncated.step("", &output));

    const long_name = "long-component-" ** 20;
    const with_pax = try tar.encodeAlloc(allocator, &.{.{ .name = long_name, .data = "x" }});
    defer allocator.free(with_pax);
    var control_limited = reader_mod.Reader.initWithOptions(allocator, .{
        .max_control_record_size = 8,
    });
    defer control_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, control_limited.step(with_pax, &output));
    try Limit.expect(.{ .max_metadata_size = 8 }, with_pax);

    const extents = [_]tar.SparseDataExtent{.{ .offset = 0, .data = "A" }};
    const sparse_archive = try tar.encodeAlloc(allocator, &.{.{
        .name = "sparse.bin",
        .sparse = .{ .logical_size = 4096, .extents = &extents },
    }});
    defer allocator.free(sparse_archive);
    try Limit.expect(.{ .max_sparse_extents = 0 }, sparse_archive);
}

test "TAR incremental reader finish accepts clean boundaries and preserves trailing input" {
    const allocator = std.testing.allocator;
    const encoded = try tar.encodeAlloc(allocator, &.{.{ .name = "plain", .data = "hello" }});
    defer allocator.free(encoded);
    var output: [16]u8 = undefined;

    for ([_]usize{ 1024, 512 }) |removed| {
        const prefix = encoded[0 .. encoded.len - removed];
        var reader = reader_mod.Reader.init(allocator);
        defer reader.deinit();
        var input_offset: usize = 0;
        while (true) {
            const stepped = try reader.step(prefix[input_offset..], &output);
            input_offset += stepped.input_read;
            if (stepped.status == .need_input and input_offset == prefix.len) break;
            if (stepped.input_read == 0 and stepped.output_written == 0 and
                stepped.status != .entry_header and stepped.status != .entry_done)
                return error.TestUnexpectedResult;
        }
        try reader.finish();
        try std.testing.expectEqual(reader_mod.Status.done, (try reader.step("", &output)).status);
    }

    var with_trailing = try allocator.alloc(u8, encoded.len + 1);
    defer allocator.free(with_trailing);
    @memcpy(with_trailing[0..encoded.len], encoded);
    with_trailing[encoded.len] = 'X';
    var reader = reader_mod.Reader.init(allocator);
    defer reader.deinit();
    var input_offset: usize = 0;
    while (true) {
        const stepped = try reader.step(with_trailing[input_offset..], &output);
        input_offset += stepped.input_read;
        if (stepped.status == .done) break;
    }
    try std.testing.expectEqual(encoded.len, input_offset);
    try std.testing.expectEqual(@as(u8, 'X'), with_trailing[input_offset]);
}

test "TAR incremental reader rejects nonzero PAX 1.0 map padding" {
    const allocator = std.testing.allocator;
    const extents = [_]tar.SparseDataExtent{.{ .offset = 0, .data = "A" }};
    const encoded_const = try tar.encodeAlloc(allocator, &.{.{
        .name = "sparse.bin",
        .sparse = .{ .logical_size = 4096, .extents = &extents },
    }});
    defer allocator.free(encoded_const);
    var encoded = try allocator.dupe(u8, encoded_const);
    defer allocator.free(encoded);
    const parsed = try tar.parse(encoded);
    const entry = (try parsed.find("sparse.bin")).?;
    encoded[entry.data_offset - 1] = 1;

    var reader = reader_mod.Reader.init(allocator);
    defer reader.deinit();
    var output: [4096]u8 = undefined;
    var input_offset: usize = 0;
    while (true) {
        const stepped = reader.step(encoded[input_offset..], &output) catch |err| {
            try std.testing.expectEqual(error.InvalidTarHeader, err);
            break;
        };
        input_offset += stepped.input_read;
        if (stepped.status == .done) return error.TestUnexpectedResult;
    }
    try std.testing.expectError(error.TarReaderPoisoned, reader.step("", &output));
}

test "TAR incremental reader releases every allocation failure path" {
    const allocator = std.testing.allocator;
    const long_name = "nested/" ++ "long-component-" ** 12 ++ "file.txt";
    const encoded = try tar.encodeAlloc(allocator, &.{.{ .name = long_name, .data = "payload" }});
    defer allocator.free(encoded);

    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator, bytes: []const u8) !void {
            var reader = reader_mod.Reader.init(failing_allocator);
            defer reader.deinit();
            var output: [32]u8 = undefined;
            var input_offset: usize = 0;
            while (true) {
                const stepped = try reader.step(bytes[input_offset..], &output);
                input_offset += stepped.input_read;
                if (stepped.status == .done) break;
            }
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{encoded});
}

fn appendLegacySparse(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    format: sparse.Format,
) !void {
    var pax: std.ArrayList(u8) = .empty;
    defer pax.deinit(allocator);
    try wire.appendPaxRecord(allocator, &pax, "GNU.sparse.size", "20");
    try wire.appendPaxRecord(allocator, &pax, "GNU.sparse.numblocks", "3");
    switch (format) {
        .pax_0_0 => {
            try wire.appendPaxRecord(allocator, &pax, "GNU.sparse.offset", "0");
            try wire.appendPaxRecord(allocator, &pax, "GNU.sparse.numbytes", "4");
            try wire.appendPaxRecord(allocator, &pax, "GNU.sparse.offset", "12");
            try wire.appendPaxRecord(allocator, &pax, "GNU.sparse.numbytes", "3");
            try wire.appendPaxRecord(allocator, &pax, "GNU.sparse.offset", "20");
            try wire.appendPaxRecord(allocator, &pax, "GNU.sparse.numbytes", "0");
        },
        .pax_0_1 => try wire.appendPaxRecord(
            allocator,
            &pax,
            "GNU.sparse.map",
            "0,4,12,3,20,0",
        ),
        else => return error.TestUnexpectedResult,
    }
    try wire.appendPaxRecord(allocator, &pax, "path", name);
    try wire.appendUstarHeader(allocator, output, .{
        .name = "PaxHeaders.X/vort",
        .mode = 0o644,
        .mtime = 0,
        .size = pax.items.len,
        .type_flag = 'x',
    });
    try output.appendSlice(allocator, pax.items);
    try wire.appendPadding(allocator, output, pax.items.len);
    try wire.appendUstarHeader(allocator, output, .{
        .name = "sparse-placeholder",
        .mode = 0o644,
        .mtime = 0,
        .size = 7,
        .type_flag = '0',
    });
    try output.appendSlice(allocator, "HEADMID");
    try wire.appendPadding(allocator, output, 7);
}
