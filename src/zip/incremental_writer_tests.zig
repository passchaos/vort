const std = @import("std");
const core = @import("../core.zig");
const zip = @import("../zip.zig");
const incremental = @import("incremental_writer.zig");
const wire = @import("wire.zig");

const TestEntry = struct {
    name: []const u8,
    data: []const u8,
    method: zip.CompressionMethod,
    expected_size: ?u64,
    comment: []const u8 = "",
};

test "ZIP incremental writer round trips known and unknown Stored and Deflate entries" {
    const allocator = std.testing.allocator;
    const repetitive = "incremental raw deflate data\n" ** 96;
    const entries = [_]TestEntry{
        .{ .name = "known-stored.bin", .data = "stored payload", .method = .stored, .expected_size = 14, .comment = "known" },
        .{ .name = "unknown-stored.bin", .data = "unknown stored", .method = .stored, .expected_size = null },
        .{ .name = "known-deflate.txt", .data = repetitive, .method = .deflate, .expected_size = repetitive.len },
        .{ .name = "unknown-deflate.txt", .data = "unknown deflate payload" ** 50, .method = .deflate, .expected_size = null },
        .{ .name = "empty", .data = "", .method = .stored, .expected_size = 0 },
    };
    const bytes = try encodeEntries(allocator, &entries, .{ .archive_comment = "streamed" }, 7, 5);
    defer allocator.free(bytes);

    const archive = try zip.parse(bytes);
    try std.testing.expectEqual(@as(usize, entries.len), archive.entry_count);
    try std.testing.expectEqualStrings("streamed", archive.comment);
    for (entries, 0..) |expected, index| {
        const entry = try archive.entryAt(index);
        try std.testing.expectEqualStrings(expected.name, entry.name);
        try std.testing.expectEqual(expected.method, entry.method);
        try std.testing.expect(entry.flags & wire.descriptor_flag != 0);
        const decoded = try archive.extractAlloc(allocator, entry);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, expected.data, decoded);
    }
}

test "ZIP incremental writer handles one-byte input and output and is deterministic" {
    const allocator = std.testing.allocator;
    var random: [2048]u8 = undefined;
    var prng = std.Random.DefaultPrng.init(0x5a49_505f_494e_4352);
    prng.random().bytes(&random);
    const entries = [_]TestEntry{
        .{ .name = "one-byte.bin", .data = &random, .method = .stored, .expected_size = random.len },
        .{ .name = "deflate.txt", .data = "deterministic stream" ** 200, .method = .deflate, .expected_size = null },
    };
    const tiny = try encodeEntries(allocator, &entries, .{}, 1, 1);
    defer allocator.free(tiny);
    const coalesced = try encodeEntries(allocator, &entries, .{}, 4096, 8192);
    defer allocator.free(coalesced);
    try std.testing.expectEqualSlices(u8, coalesced, tiny);

    const archive = try zip.parse(tiny);
    for (entries, 0..) |expected, index| {
        const decoded = try archive.extractAlloc(allocator, try archive.entryAt(index));
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, expected.data, decoded);
    }
}

test "ZIP incremental writer applies zero-output backpressure" {
    var writer = try incremental.Writer.init(std.testing.allocator);
    defer writer.deinit();
    try writer.beginEntry(.{
        .name = "blocked.bin",
        .method = .stored,
        .expected_size = 7,
    });
    const header_blocked = try writer.step("payload", &.{});
    try std.testing.expectEqual(core.StepResult.Status.need_output, header_blocked.status);
    try std.testing.expectEqual(@as(usize, 0), header_blocked.progress.input_read);
    try std.testing.expectEqual(@as(u64, 0), writer.snapshot().input_read);

    var scratch: [128]u8 = undefined;
    var input_offset: usize = 0;
    while (input_offset != 7) {
        const stepped = try writer.step("payload"[input_offset..], &scratch);
        input_offset += stepped.progress.input_read;
    }
    const data_blocked = try writer.step("", &.{});
    try std.testing.expectEqual(core.StepResult.Status.need_input, data_blocked.status);
    try std.testing.expectEqual(@as(u64, 7), writer.snapshot().input_read);
    try writer.finishEntry();
    const finish_blocked = try writer.step("", &.{});
    try std.testing.expectEqual(core.StepResult.Status.need_output, finish_blocked.status);
}

test "ZIP incremental writer emits precise ZIP32 and conservative ZIP64 layouts" {
    const allocator = std.testing.allocator;
    const entries = [_]TestEntry{
        .{ .name = "known", .data = "abc", .method = .stored, .expected_size = 3 },
        .{ .name = "unknown", .data = "xy", .method = .stored, .expected_size = null },
        .{ .name = "deflated", .data = "aaaaaaaa", .method = .deflate, .expected_size = 8 },
    };
    const bytes = try encodeEntries(allocator, &entries, .{}, 2, 3);
    defer allocator.free(bytes);
    const archive = try zip.parse(bytes);
    const known = try archive.entryAt(0);
    const unknown = try archive.entryAt(1);
    const deflated = try archive.entryAt(2);
    try std.testing.expect(!known.zip64);
    try std.testing.expect(unknown.zip64);
    try std.testing.expect(deflated.zip64);

    try std.testing.expectEqual(@as(u32, 0), readU32(bytes, known.local_header_offset + 18));
    try std.testing.expectEqual(@as(u16, 0), readU16(bytes, known.local_header_offset + 28));
    try std.testing.expectEqual(std.math.maxInt(u32), readU32(bytes, unknown.local_header_offset + 18));
    try std.testing.expectEqual(std.math.maxInt(u32), readU32(bytes, unknown.local_header_offset + 22));
    try std.testing.expectEqual(@as(u16, 20), readU16(bytes, unknown.local_header_offset + 28));
    const unknown_extra = unknown.local_header_offset + wire.local_file_header_len + entries[1].name.len;
    try std.testing.expectEqual(wire.zip64_extra_id, readU16(bytes, unknown_extra));
    try std.testing.expectEqual(@as(u64, 0), readU64(bytes, unknown_extra + 4));
    try std.testing.expectEqual(@as(u64, 0), readU64(bytes, unknown_extra + 12));

    const unknown_data = unknown.local_header_offset + wire.local_file_header_len + entries[1].name.len + 20;
    const unknown_descriptor = unknown_data + entries[1].data.len;
    try std.testing.expectEqual(wire.data_descriptor_signature, readU32(bytes, unknown_descriptor));
    try std.testing.expectEqual(@as(u64, entries[1].data.len), readU64(bytes, unknown_descriptor + 8));
    try std.testing.expectEqual(@as(u64, entries[1].data.len), readU64(bytes, unknown_descriptor + 16));
}

test "ZIP incremental writer supports ZIP64 always, ZIP32 never, and initial offsets" {
    const allocator = std.testing.allocator;
    const entry = [_]TestEntry{.{
        .name = "payload",
        .data = "prefixed",
        .method = .stored,
        .expected_size = null,
    }};

    const forced = try encodeEntries(allocator, &entry, .{ .zip64 = .always }, 8, 8);
    defer allocator.free(forced);
    const forced_archive = try zip.parse(forced);
    try std.testing.expect(forced_archive.zip64);
    try std.testing.expect((try forced_archive.entryAt(0)).zip64);

    const never = try encodeEntries(allocator, &entry, .{ .zip64 = .never }, 8, 8);
    defer allocator.free(never);
    const never_archive = try zip.parse(never);
    try std.testing.expect(!never_archive.zip64);
    try std.testing.expect(!(try never_archive.entryAt(0)).zip64);

    const prefix = "MZ-prefix";
    const prefixed_archive_bytes = try encodeEntries(allocator, &entry, .{
        .initial_offset = prefix.len,
        .zip64 = .never,
    }, 8, 8);
    defer allocator.free(prefixed_archive_bytes);
    var prefixed: std.ArrayList(u8) = .empty;
    defer prefixed.deinit(allocator);
    try prefixed.appendSlice(allocator, prefix);
    try prefixed.appendSlice(allocator, prefixed_archive_bytes);
    const parsed = try zip.parse(prefixed.items);
    try std.testing.expectEqual(prefix.len, (try parsed.entryAt(0)).local_header_offset);

    try std.testing.expectError(
        error.Zip32LimitExceeded,
        incremental.Writer.initWithOptions(allocator, .{
            .initial_offset = std.math.maxInt(u32),
            .zip64 = .never,
        }),
    );
}

test "ZIP incremental writer emits empty ZIP32 and ZIP64 archives" {
    const allocator = std.testing.allocator;
    const empty_entries = [_]TestEntry{};
    const zip32 = try encodeEntries(allocator, &empty_entries, .{}, 1, 1);
    defer allocator.free(zip32);
    try std.testing.expectEqual(@as(usize, wire.end_of_central_len), zip32.len);
    try std.testing.expect(!(try zip.parse(zip32)).zip64);

    const zip64 = try encodeEntries(allocator, &empty_entries, .{ .zip64 = .always }, 1, 1);
    defer allocator.free(zip64);
    const archive = try zip.parse(zip64);
    try std.testing.expect(archive.zip64);
    try std.testing.expectEqual(@as(usize, 0), archive.entry_count);
}

test "ZIP incremental writer validates state and recovers from a short finish request" {
    var writer = try incremental.Writer.init(std.testing.allocator);
    defer writer.deinit();
    try std.testing.expectError(error.InvalidZipWriterState, writer.finishEntry());
    try writer.beginEntry(.{ .name = "short", .method = .stored, .expected_size = 4 });
    try std.testing.expectError(error.InvalidZipWriterState, writer.beginEntry(.{ .name = "other" }));
    try std.testing.expectError(error.InvalidZipWriterState, writer.finishArchive());

    var scratch: [128]u8 = undefined;
    var offset: usize = 0;
    while (offset != 3) {
        const stepped = try writer.step("abc"[offset..], &scratch);
        offset += stepped.progress.input_read;
    }
    try std.testing.expectError(error.SizeMismatch, writer.finishEntry());
    try std.testing.expectEqual(incremental.Phase.entry_data, writer.snapshot().phase);
    const completed = try writer.step("d", &scratch);
    try std.testing.expectEqual(@as(usize, 1), completed.progress.input_read);
    try writer.finishEntry();
    while (writer.snapshot().phase != .ready) _ = try writer.step("", &scratch);

    try writer.beginEntry(.{ .name = "overflow", .method = .stored, .expected_size = 1 });
    try std.testing.expectError(error.SizeMismatch, writer.step("too much", &scratch));
    try std.testing.expectEqual(incremental.Phase.poisoned, writer.snapshot().phase);
    try std.testing.expectError(error.ZipWriterPoisoned, writer.step("", &scratch));
    try std.testing.expectError(error.ZipWriterPoisoned, writer.beginEntry(.{ .name = "late" }));
}

test "ZIP incremental writer enforces method and metadata limits" {
    var unsupported = try incremental.Writer.init(std.testing.allocator);
    defer unsupported.deinit();
    try std.testing.expectError(
        error.UnsupportedZipCompressionMethod,
        unsupported.beginEntry(.{ .name = "bad", .method = .bzip2 }),
    );
    try std.testing.expectEqual(incremental.Phase.ready, unsupported.snapshot().phase);
    try unsupported.beginEntry(.{ .name = "retry", .method = .stored, .expected_size = 0 });

    var metadata_limited = try incremental.Writer.initWithOptions(std.testing.allocator, .{
        .max_central_directory_size = 3,
    });
    defer metadata_limited.deinit();
    try std.testing.expectError(
        error.OutputLimitExceeded,
        metadata_limited.beginEntry(.{ .name = "four" }),
    );
    try std.testing.expectEqual(incremental.Phase.ready, metadata_limited.snapshot().phase);

    var entry_limited = try incremental.Writer.initWithOptions(std.testing.allocator, .{
        .max_entries = 0,
    });
    defer entry_limited.deinit();
    try std.testing.expectError(
        error.OutputLimitExceeded,
        entry_limited.beginEntry(.{ .name = "entry" }),
    );
}

test "ZIP incremental writer preflights Deflate configuration before headers" {
    var invalid = try incremental.Writer.initWithOptions(std.testing.allocator, .{
        .deflate_options = .{ .block_len = 0 },
    });
    defer invalid.deinit();
    try std.testing.expectError(
        error.InvalidBlockPlan,
        invalid.beginEntry(.{ .name = "bad-deflate", .method = .deflate }),
    );
    try std.testing.expectEqual(incremental.Phase.ready, invalid.snapshot().phase);
    try std.testing.expectEqual(@as(u64, 0), invalid.snapshot().output_written);
    try invalid.beginEntry(.{ .name = "stored-retry", .method = .stored, .expected_size = 0 });

    var bounded = try incremental.Writer.initWithOptions(std.testing.allocator, .{
        .deflate_options = .{ .block_len = 64 * 1024 },
        .max_deflate_buffer_size = 32 * 1024,
    });
    defer bounded.deinit();
    try std.testing.expectError(
        error.OutputLimitExceeded,
        bounded.beginEntry(.{ .name = "too-wide", .method = .deflate }),
    );
    try std.testing.expectEqual(incremental.Phase.ready, bounded.snapshot().phase);

    var input_limited = try incremental.Writer.initWithOptions(std.testing.allocator, .{
        .deflate_options = .{ .max_input_len = 3 },
    });
    defer input_limited.deinit();
    try std.testing.expectError(
        error.OutputLimitExceeded,
        input_limited.beginEntry(.{
            .name = "too-long",
            .method = .deflate,
            .expected_size = 4,
        }),
    );
    try std.testing.expectEqual(incremental.Phase.ready, input_limited.snapshot().phase);
}

test "ZIP incremental writer preflights archive finish and output limits" {
    var finish_limited = try incremental.Writer.initWithOptions(std.testing.allocator, .{
        .archive_comment = "comment",
        .max_archive_size = 1,
    });
    defer finish_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, finish_limited.finishArchive());
    try std.testing.expectEqual(incremental.Phase.ready, finish_limited.snapshot().phase);

    const name = "x";
    const local_header_len = wire.local_file_header_len + name.len;
    var payload_limited = try incremental.Writer.initWithOptions(std.testing.allocator, .{
        .zip64 = .never,
        .max_archive_size = local_header_len,
    });
    defer payload_limited.deinit();
    try payload_limited.beginEntry(.{ .name = name, .method = .stored });
    var header: [local_header_len]u8 = undefined;
    const drained = try payload_limited.step("", &header);
    try std.testing.expectEqual(local_header_len, drained.progress.output_written);
    var scratch: [1]u8 = .{0xa5};
    try std.testing.expectError(error.OutputLimitExceeded, payload_limited.step("z", &scratch));
    try std.testing.expectEqual(@as(u8, 0xa5), scratch[0]);
    try std.testing.expectEqual(incremental.Phase.poisoned, payload_limited.snapshot().phase);
}

test "ZIP incremental writer keeps beginEntry allocation failure recoverable" {
    var writer = try incremental.Writer.init(std.testing.allocator);
    defer writer.deinit();
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    writer.allocator = failing.allocator();
    try std.testing.expectError(
        error.OutOfMemory,
        writer.beginEntry(.{ .name = "allocation-retry", .method = .stored, .expected_size = 0 }),
    );
    try std.testing.expectEqual(incremental.Phase.ready, writer.snapshot().phase);

    writer.allocator = std.testing.allocator;
    try writer.beginEntry(.{ .name = "allocation-retry", .method = .stored, .expected_size = 0 });
    try std.testing.expectEqual(incremental.Phase.entry_header, writer.snapshot().phase);
}

test "ZIP incremental writer releases every allocation failure" {
    const Test = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const entries = [_]TestEntry{
                .{ .name = "stored", .data = "small", .method = .stored, .expected_size = null },
                .{ .name = "deflated", .data = "allocation-safe deflate" ** 80, .method = .deflate, .expected_size = null },
            };
            const encoded = try encodeEntries(allocator, &entries, .{ .archive_comment = "oom" }, 17, 19);
            defer allocator.free(encoded);
            const archive = try zip.parse(encoded);
            const decoded = try archive.extractAlloc(allocator, try archive.entryAt(1));
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, entries[1].data, decoded);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{});
}

fn encodeEntries(
    allocator: std.mem.Allocator,
    entries: []const TestEntry,
    options: incremental.Options,
    input_chunk_len: usize,
    output_chunk_len: usize,
) ![]u8 {
    var writer = try incremental.Writer.initWithOptions(allocator, options);
    defer writer.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(allocator);
    const scratch = try allocator.alloc(u8, output_chunk_len);
    defer allocator.free(scratch);

    for (entries) |entry| {
        try writer.beginEntry(.{
            .name = entry.name,
            .comment = entry.comment,
            .method = entry.method,
            .expected_size = entry.expected_size,
        });
        var input_offset: usize = 0;
        while (input_offset < entry.data.len) {
            const input_end = @min(entry.data.len, input_offset + input_chunk_len);
            const stepped = try writer.step(entry.data[input_offset..input_end], scratch);
            input_offset += stepped.progress.input_read;
            try encoded.appendSlice(allocator, scratch[0..stepped.progress.output_written]);
        }
        try writer.finishEntry();
        while (writer.snapshot().phase != .ready) {
            const stepped = try writer.step("", scratch);
            try encoded.appendSlice(allocator, scratch[0..stepped.progress.output_written]);
        }
    }
    try writer.finishArchive();
    while (true) {
        const stepped = try writer.step("", scratch);
        try encoded.appendSlice(allocator, scratch[0..stepped.progress.output_written]);
        if (stepped.status == .done) break;
    }
    return encoded.toOwnedSlice(allocator);
}

fn readU16(bytes: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, bytes[offset..][0..2], .little);
}

fn readU32(bytes: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, bytes[offset..][0..4], .little);
}

fn readU64(bytes: []const u8, offset: usize) u64 {
    return std.mem.readInt(u64, bytes[offset..][0..8], .little);
}
