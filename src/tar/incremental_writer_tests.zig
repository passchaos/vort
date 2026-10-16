const std = @import("std");
const incremental = @import("incremental_writer.zig");
const tar = @import("../tar.zig");

const TestEntry = struct {
    options: incremental.EntryOptions,
    data: []const u8,
};

fn encodeEntries(
    allocator: std.mem.Allocator,
    entries: []const TestEntry,
    options: incremental.Options,
    input_chunk: usize,
    output_chunk: usize,
) ![]u8 {
    var writer = incremental.Writer.initWithOptions(allocator, options);
    defer writer.deinit();
    var archive: std.ArrayList(u8) = .empty;
    errdefer archive.deinit(allocator);
    const output = try allocator.alloc(u8, output_chunk);
    defer allocator.free(output);
    for (entries) |entry| {
        try writer.beginEntry(entry.options);
        var input_offset: usize = 0;
        while (input_offset < entry.data.len) {
            const input_end = @min(entry.data.len, input_offset + input_chunk);
            while (input_offset < input_end) {
                const stepped = try writer.step(entry.data[input_offset..input_end], output);
                input_offset += stepped.input_read;
                try archive.appendSlice(allocator, output[0..stepped.output_written]);
                if (stepped.input_read == 0 and stepped.output_written == 0)
                    return error.TestUnexpectedResult;
            }
        }
        try writer.finishEntry();
        while (true) {
            const stepped = try writer.step("", output);
            try archive.appendSlice(allocator, output[0..stepped.output_written]);
            if (stepped.status == .entry_done) break;
            if (stepped.output_written == 0) return error.TestUnexpectedResult;
        }
    }
    try writer.finishArchive();
    while (true) {
        const stepped = try writer.step("", output);
        try archive.appendSlice(allocator, output[0..stepped.output_written]);
        if (stepped.status == .done) break;
        if (stepped.output_written == 0) return error.TestUnexpectedResult;
    }
    return archive.toOwnedSlice(allocator);
}

test "TAR incremental writer is byte-exact across regular PAX and sparse entries" {
    const allocator = std.testing.allocator;
    const long_name = "nested/" ++ "long-component-" ** 12 ++ "file.txt";
    var pax_sparse: [8192]u8 = @splat(0);
    @memcpy(pax_sparse[0..4], "HEAD");
    @memcpy(pax_sparse[4096..4102], "MIDDLE");
    @memcpy(pax_sparse[8188..], "TAIL");
    var old_sparse: [8192]u8 = @splat(0);
    @memcpy(old_sparse[0..4], "OLDH");
    @memcpy(old_sparse[8188..], "OLDT");
    const pax_layout = [_]incremental.SparseExtent{
        .{ .offset = 0, .len = 4 },
        .{ .offset = 4096, .len = 6 },
        .{ .offset = 8188, .len = 4 },
    };
    const old_layout = [_]incremental.SparseExtent{
        .{ .offset = 0, .len = 4 },
        .{ .offset = 8188, .len = 4 },
    };
    const entries = [_]TestEntry{
        .{ .options = .{ .name = "plain.txt", .size = 5, .mode = 0o640 }, .data = "plain" },
        .{ .options = .{ .name = long_name, .size = 9 }, .data = "long path" },
        .{ .options = .{ .name = "folder/", .kind = .directory }, .data = "" },
        .{
            .options = .{ .name = "link", .kind = .symbolic_link, .link_name = long_name },
            .data = "",
        },
        .{
            .options = .{
                .name = "pax-sparse.bin",
                .sparse = .{ .logical_size = pax_sparse.len, .extents = &pax_layout },
            },
            .data = &pax_sparse,
        },
        .{
            .options = .{
                .name = "old-sparse.bin",
                .sparse = .{
                    .logical_size = old_sparse.len,
                    .extents = &old_layout,
                    .format = .gnu_old,
                },
            },
            .data = &old_sparse,
        },
    };
    const tiny = try encodeEntries(allocator, &entries, .{}, 1, 1);
    defer allocator.free(tiny);
    const wide = try encodeEntries(allocator, &entries, .{}, 257, 4096);
    defer allocator.free(wide);
    try std.testing.expectEqualSlices(u8, wide, tiny);

    const pax_data_extents = [_]tar.SparseDataExtent{
        .{ .offset = 0, .data = pax_sparse[0..4] },
        .{ .offset = 4096, .data = pax_sparse[4096..4102] },
        .{ .offset = 8188, .data = pax_sparse[8188..] },
    };
    const old_data_extents = [_]tar.SparseDataExtent{
        .{ .offset = 0, .data = old_sparse[0..4] },
        .{ .offset = 8188, .data = old_sparse[8188..] },
    };
    const expected = try tar.encodeAlloc(allocator, &.{
        .{ .name = "plain.txt", .data = "plain", .mode = 0o640 },
        .{ .name = long_name, .data = "long path" },
        .{ .name = "folder/", .kind = .directory },
        .{ .name = "link", .kind = .symbolic_link, .link_name = long_name },
        .{
            .name = "pax-sparse.bin",
            .sparse = .{ .logical_size = pax_sparse.len, .extents = &pax_data_extents },
        },
        .{
            .name = "old-sparse.bin",
            .sparse = .{
                .logical_size = old_sparse.len,
                .extents = &old_data_extents,
                .format = .gnu_old,
            },
        },
    });
    defer allocator.free(expected);
    try std.testing.expectEqualSlices(u8, expected, tiny);

    const parsed = try tar.parse(tiny);
    const pax_decoded = try parsed.extractByNameAlloc(allocator, "pax-sparse.bin");
    defer allocator.free(pax_decoded);
    try std.testing.expectEqualSlices(u8, &pax_sparse, pax_decoded);
    const old_decoded = try parsed.extractByNameAlloc(allocator, "old-sparse.bin");
    defer allocator.free(old_decoded);
    try std.testing.expectEqualSlices(u8, &old_sparse, old_decoded);
}

test "TAR incremental writer rejects nonzero declared holes and poisons step" {
    const allocator = std.testing.allocator;
    var writer = incremental.Writer.init(allocator);
    defer writer.deinit();
    const layout = [_]incremental.SparseExtent{.{ .offset = 0, .len = 1 }};
    try writer.beginEntry(.{
        .name = "sparse.bin",
        .sparse = .{ .logical_size = 1024, .extents = &layout },
    });
    var output: [4096]u8 = undefined;
    _ = try writer.step("", &output);
    var input: [1024]u8 = @splat(0);
    input[0] = 'A';
    input[600] = 'X';
    try std.testing.expectError(error.NonZeroSparseHole, writer.step(&input, &output));
    try std.testing.expectError(error.TarWriterPoisoned, writer.step("", &output));
}

test "TAR incremental writer enforces state limits and allocation cleanup" {
    const allocator = std.testing.allocator;
    var limited = incremental.Writer.initWithOptions(allocator, .{
        .max_logical_entry_size = 3,
    });
    defer limited.deinit();
    try std.testing.expectError(
        error.OutputLimitExceeded,
        limited.beginEntry(.{ .name = "too-large", .size = 4 }),
    );

    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator) !void {
            var writer = incremental.Writer.init(failing_allocator);
            defer writer.deinit();
            const layout = [_]incremental.SparseExtent{.{ .offset = 0, .len = 4 }};
            try writer.beginEntry(.{
                .name = "sparse.bin",
                .sparse = .{ .logical_size = 4096, .extents = &layout },
            });
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{});
}
