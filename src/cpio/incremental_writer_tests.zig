const std = @import("std");
const archive = @import("archive.zig");
const incremental = @import("incremental_writer.zig");
const writer = @import("writer.zig");

const TestEntry = struct {
    one_shot: writer.EncodeEntry,
    inode: ?u32 = null,
    link_count: u32 = 1,
};

fn encodeIncremental(
    allocator: std.mem.Allocator,
    entries: []const TestEntry,
    options: incremental.Options,
    input_chunk: usize,
    output_chunk: usize,
) ![]u8 {
    var stream = try incremental.Writer.initWithOptions(allocator, options);
    defer stream.deinit();
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);

    for (entries) |test_entry| {
        const entry = test_entry.one_shot;
        try stream.beginEntry(.{
            .name = entry.name,
            .size = entry.data.len,
            .kind = entry.kind,
            .permissions = entry.permissions,
            .inode = test_entry.inode,
            .link_count = test_entry.link_count,
            .uid = entry.uid,
            .gid = entry.gid,
            .mtime = entry.mtime,
            .device_major = entry.device_major,
            .device_minor = entry.device_minor,
            .rdevice_major = entry.rdevice_major,
            .rdevice_minor = entry.rdevice_minor,
            .checksum = if (options.format == .crc) archive.byteSum(entry.data) else null,
        });
        var input_offset: usize = 0;
        while (input_offset != entry.data.len) {
            var scratch: [257]u8 = undefined;
            const offered = entry.data[input_offset..][0..@min(
                input_chunk,
                entry.data.len - input_offset,
            )];
            const stepped = try stream.step(offered, scratch[0..@min(output_chunk, scratch.len)]);
            input_offset += stepped.input_read;
            try output.appendSlice(allocator, scratch[0..stepped.output_written]);
            if (stepped.input_read == 0 and stepped.output_written == 0)
                return error.TestUnexpectedResult;
        }
        try stream.finishEntry();
        while (true) {
            var scratch: [257]u8 = undefined;
            const stepped = try stream.step("", scratch[0..@min(output_chunk, scratch.len)]);
            try output.appendSlice(allocator, scratch[0..stepped.output_written]);
            if (stepped.status == .entry_done) break;
            if (stepped.output_written == 0) return error.TestUnexpectedResult;
        }
    }

    try stream.finishArchive();
    while (true) {
        var scratch: [257]u8 = undefined;
        const stepped = try stream.step("", scratch[0..@min(output_chunk, scratch.len)]);
        try output.appendSlice(allocator, scratch[0..stepped.output_written]);
        if (stepped.status == .done) break;
        if (stepped.output_written == 0) return error.TestUnexpectedResult;
    }
    return output.toOwnedSlice(allocator);
}

test "CPIO incremental writer is byte exact for every header format" {
    const allocator = std.testing.allocator;
    var random: [1025]u8 = undefined;
    var prng = std.Random.DefaultPrng.init(0x4350_494f_5354_524d);
    prng.random().bytes(&random);
    const entries = [_]TestEntry{
        .{ .one_shot = .{ .name = "plain.txt", .data = "streamed CPIO payload", .permissions = 0o640 } },
        .{ .one_shot = .{ .name = "folder", .kind = .directory } },
        .{ .one_shot = .{ .name = "folder/random.bin", .data = &random, .permissions = 0o600 } },
        .{ .one_shot = .{ .name = "link", .kind = .symlink, .data = "folder/random.bin" } },
        .{ .one_shot = .{ .name = "block", .kind = .block_device, .rdevice_minor = 7 } },
        .{ .one_shot = .{ .name = "character", .kind = .character_device, .rdevice_minor = 8 } },
        .{ .one_shot = .{ .name = "fifo", .kind = .fifo } },
        .{ .one_shot = .{ .name = "socket", .kind = .socket } },
        .{ .one_shot = .{ .name = "empty" } },
    };
    var flat_entries: [entries.len]writer.EncodeEntry = undefined;
    for (entries, 0..) |entry, index| flat_entries[index] = entry.one_shot;

    inline for (std.meta.tags(archive.Format)) |format| {
        inline for (.{ @as(usize, 0), 1, 7, 512 }) |block_size| {
            const expected = try writer.encodeAlloc(
                allocator,
                &flat_entries,
                .{ .format = format, .block_size = block_size },
            );
            defer allocator.free(expected);
            const tiny = try encodeIncremental(
                allocator,
                &entries,
                .{ .format = format, .block_size = block_size },
                1,
                1,
            );
            defer allocator.free(tiny);
            const micro = try encodeIncremental(
                allocator,
                &entries,
                .{ .format = format, .block_size = block_size },
                17,
                31,
            );
            defer allocator.free(micro);
            try std.testing.expectEqualSlices(u8, expected, tiny);
            try std.testing.expectEqualSlices(u8, expected, micro);

            const parsed = try archive.parse(tiny);
            try std.testing.expectEqual(format, parsed.format);
            try std.testing.expectEqual(entries.len, parsed.entry_count);
            for (entries, 0..) |expected_entry, index| {
                const actual = try parsed.entryAt(index);
                try std.testing.expectEqualStrings(expected_entry.one_shot.name, actual.name);
                try std.testing.expectEqual(expected_entry.one_shot.kind, actual.kind);
            }
        }
    }
}

test "CPIO incremental writer applies output backpressure and CRC validation" {
    var stream = try incremental.Writer.initWithOptions(
        std.testing.allocator,
        .{ .format = .crc, .block_size = 0 },
    );
    defer stream.deinit();
    const payload = "checksum payload";
    try std.testing.expectError(
        error.InvalidCpioOptions,
        stream.beginEntry(.{ .name = "missing", .size = payload.len }),
    );
    try stream.beginEntry(.{
        .name = "payload",
        .size = payload.len,
        .checksum = archive.byteSum(payload),
    });
    const blocked = try stream.step(payload, &.{});
    try std.testing.expectEqual(incremental.Status.need_output, blocked.status);
    try std.testing.expectEqual(@as(usize, 0), blocked.input_read);
    try std.testing.expectEqual(@as(u64, 0), stream.snapshot().input_read);

    var scratch: [256]u8 = undefined;
    var input_offset: usize = 0;
    while (input_offset != payload.len) {
        const stepped = try stream.step(payload[input_offset..], &scratch);
        input_offset += stepped.input_read;
    }
    try stream.finishEntry();
    while ((try stream.step("", &scratch)).status != .entry_done) {}

    var bad = try incremental.Writer.initWithOptions(
        std.testing.allocator,
        .{ .format = .crc },
    );
    defer bad.deinit();
    try bad.beginEntry(.{ .name = "bad", .size = 3, .checksum = 1 });
    var bad_offset: usize = 0;
    while (bad_offset != 3) {
        const stepped = try bad.step("abc"[bad_offset..], &scratch);
        bad_offset += stepped.input_read;
    }
    try std.testing.expectError(error.ChecksumMismatch, bad.finishEntry());
    try std.testing.expectEqual(incremental.Phase.poisoned, bad.snapshot().phase);
    try std.testing.expectError(error.CpioWriterPoisoned, bad.step("", &scratch));
}

test "CPIO incremental writer preserves explicit hard-link groups" {
    const allocator = std.testing.allocator;
    const entries = [_]TestEntry{
        .{
            .one_shot = .{ .name = "hard-a" },
            .inode = 7,
            .link_count = 2,
        },
        .{
            .one_shot = .{ .name = "hard-b", .data = "shared hard-link payload" },
            .inode = 7,
            .link_count = 2,
        },
    };
    const encoded = try encodeIncremental(
        allocator,
        &entries,
        .{ .format = .newc, .block_size = 0 },
        2,
        3,
    );
    defer allocator.free(encoded);
    const parsed = try archive.parse(encoded);
    const first = try parsed.entryAt(0);
    const second = try parsed.entryAt(1);
    try std.testing.expectEqual(@as(u32, 7), first.inode);
    try std.testing.expectEqual(@as(u32, 2), first.link_count);
    try std.testing.expectEqual(first.inode, second.inode);
    const content = try parsed.extractAlloc(allocator, first);
    defer allocator.free(content);
    try std.testing.expectEqualStrings("shared hard-link payload", content);
}

test "CPIO incremental writer enforces state sizes and archive limits" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(
        error.InvalidCpioOptions,
        incremental.Writer.initWithOptions(allocator, .{ .block_size = 1024 * 1024 + 1 }),
    );
    var no_memory: [0]u8 = .{};
    var fixed = std.heap.FixedBufferAllocator.init(&no_memory);
    var control_limited = try incremental.Writer.initWithOptions(
        fixed.allocator(),
        .{ .max_control_record_size = 1 },
    );
    defer control_limited.deinit();
    try std.testing.expectError(
        error.OutputLimitExceeded,
        control_limited.beginEntry(.{ .name = "header" }),
    );

    var stream = try incremental.Writer.initWithOptions(allocator, .{
        .max_entries = 1,
        .max_entry_size = 3,
        .max_total_input = 3,
    });
    defer stream.deinit();
    try std.testing.expectError(
        error.OutputLimitExceeded,
        stream.beginEntry(.{ .name = "large", .size = 4 }),
    );
    try std.testing.expectError(
        error.InvalidCpioEntryName,
        stream.beginEntry(.{ .name = "../escape" }),
    );
    try std.testing.expectError(
        error.InvalidCpioOptions,
        stream.beginEntry(.{ .name = "dir", .kind = .directory, .size = 1 }),
    );
    try stream.beginEntry(.{ .name = "ok", .size = 3 });
    try std.testing.expectError(error.SizeMismatch, stream.finishEntry());
    var scratch: [256]u8 = undefined;
    var input_offset: usize = 0;
    while (input_offset != 3) {
        const stepped = try stream.step("abc"[input_offset..], &scratch);
        input_offset += stepped.input_read;
    }
    try stream.finishEntry();
    while ((try stream.step("", &scratch)).status != .entry_done) {}
    try std.testing.expectError(
        error.OutputLimitExceeded,
        stream.beginEntry(.{ .name = "second" }),
    );

    var input_limited = try incremental.Writer.initWithOptions(
        allocator,
        .{ .max_total_input = 2 },
    );
    defer input_limited.deinit();
    try input_limited.beginEntry(.{ .name = "limited", .size = 3 });
    try std.testing.expectError(error.OutputLimitExceeded, input_limited.step("abc", &scratch));
    try std.testing.expectEqual(incremental.Phase.poisoned, input_limited.snapshot().phase);

    const empty = [_]TestEntry{};
    const exact = try writer.encodeAlloc(allocator, &.{}, .{});
    defer allocator.free(exact);
    const bounded = try encodeIncremental(allocator, &empty, .{
        .max_archive_size = exact.len,
    }, 1, 7);
    defer allocator.free(bounded);
    try std.testing.expectEqualSlices(u8, exact, bounded);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        encodeIncremental(allocator, &empty, .{ .max_archive_size = exact.len - 1 }, 1, 7),
    );
}

test "CPIO incremental writer releases every allocation failure" {
    const Test = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const entries = [_]TestEntry{
                .{ .one_shot = .{ .name = "payload", .data = "allocation failure payload" } },
                .{ .one_shot = .{ .name = "directory", .kind = .directory } },
            };
            const encoded = try encodeIncremental(
                allocator,
                &entries,
                .{ .format = .crc },
                3,
                5,
            );
            defer allocator.free(encoded);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{});
}
