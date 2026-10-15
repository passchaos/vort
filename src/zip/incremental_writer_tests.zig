const std = @import("std");
const core = @import("../core.zig");
const dcl = @import("dcl_implode.zig");
const reduce = @import("reduce.zig");
const zip = @import("../zip.zig");
const zstd = @import("../zstd.zig");
const incremental = @import("incremental_writer.zig");
const ppmd8 = @import("../ppmd8.zig");
const wire = @import("wire.zig");
const xz = @import("../xz.zig");

const TestEntry = struct {
    name: []const u8,
    data: []const u8,
    method: zip.CompressionMethod,
    expected_size: ?u64,
    comment: []const u8 = "",
};

test "ZIP incremental writer round trips known and unknown common codec entries" {
    const allocator = std.testing.allocator;
    const repetitive = "incremental raw deflate data\n" ** 96;
    const entries = [_]TestEntry{
        .{ .name = "known-stored.bin", .data = "stored payload", .method = .stored, .expected_size = 14, .comment = "known" },
        .{ .name = "unknown-stored.bin", .data = "unknown stored", .method = .stored, .expected_size = null },
        .{ .name = "known-deflate.txt", .data = repetitive, .method = .deflate, .expected_size = repetitive.len },
        .{ .name = "unknown-deflate.txt", .data = "unknown deflate payload" ** 50, .method = .deflate, .expected_size = null },
        .{ .name = "known-bzip2.txt", .data = "known bzip2 payload" ** 73, .method = .bzip2, .expected_size = ("known bzip2 payload" ** 73).len },
        .{ .name = "unknown-bzip2.txt", .data = "unknown bzip2 payload" ** 61, .method = .bzip2, .expected_size = null },
        .{ .name = "known-zstd.txt", .data = "known zstd payload" ** 83, .method = .zstandard, .expected_size = ("known zstd payload" ** 83).len },
        .{ .name = "unknown-zstd-legacy.txt", .data = "unknown legacy zstd payload" ** 59, .method = .zstandard_legacy, .expected_size = null },
        .{ .name = "known-lzma.txt", .data = "known lzma payload" ** 71, .method = .lzma, .expected_size = ("known lzma payload" ** 71).len },
        .{ .name = "unknown-lzma.txt", .data = "unknown lzma payload" ** 57, .method = .lzma, .expected_size = null },
        .{ .name = "known-xz.txt", .data = "known xz payload" ** 79, .method = .xz, .expected_size = ("known xz payload" ** 79).len },
        .{ .name = "unknown-xz.txt", .data = "unknown xz payload" ** 63, .method = .xz, .expected_size = null },
        .{ .name = "known-deflate64.bin", .data = "known deflate64 payload" ** 77, .method = .deflate64, .expected_size = ("known deflate64 payload" ** 77).len },
        .{ .name = "unknown-deflate64.bin", .data = "unknown deflate64 payload" ** 61, .method = .deflate64, .expected_size = null },
        .{ .name = "known-ppmd.txt", .data = "known ppmd payload" ** 73, .method = .ppmd, .expected_size = ("known ppmd payload" ** 73).len },
        .{ .name = "unknown-ppmd.txt", .data = "unknown ppmd payload" ** 59, .method = .ppmd, .expected_size = null },
        .{ .name = "known-shrink.txt", .data = "known shrink payload" ** 71, .method = .shrink, .expected_size = ("known shrink payload" ** 71).len },
        .{ .name = "unknown-shrink.txt", .data = "unknown shrink payload" ** 57, .method = .shrink, .expected_size = null },
        .{ .name = "known-dcl.txt", .data = "known dcl implode payload" ** 71, .method = .dcl_implode, .expected_size = ("known dcl implode payload" ** 71).len },
        .{ .name = "unknown-dcl.txt", .data = "unknown dcl implode payload" ** 57, .method = .dcl_implode, .expected_size = null },
        .{ .name = "reduce-1.txt", .data = "known reduce factor one payload" ** 43, .method = .reduce_1, .expected_size = ("known reduce factor one payload" ** 43).len },
        .{ .name = "reduce-2.txt", .data = "known reduce factor two payload" ** 47, .method = .reduce_2, .expected_size = ("known reduce factor two payload" ** 47).len },
        .{ .name = "reduce-3.txt", .data = "known reduce factor three payload" ** 53, .method = .reduce_3, .expected_size = ("known reduce factor three payload" ** 53).len },
        .{ .name = "reduce-4.txt", .data = "known reduce factor four payload" ** 59, .method = .reduce_4, .expected_size = ("known reduce factor four payload" ** 59).len },
        .{ .name = "unknown-reduce-4.txt", .data = "unknown reduce factor four payload" ** 61, .method = .reduce_4, .expected_size = null },
        .{ .name = "empty", .data = "", .method = .stored, .expected_size = 0 },
        .{ .name = "empty-bzip2", .data = "", .method = .bzip2, .expected_size = 0 },
        .{ .name = "empty-zstd", .data = "", .method = .zstandard, .expected_size = 0 },
        .{ .name = "empty-lzma", .data = "", .method = .lzma, .expected_size = 0 },
        .{ .name = "empty-xz", .data = "", .method = .xz, .expected_size = 0 },
        .{ .name = "empty-deflate64", .data = "", .method = .deflate64, .expected_size = 0 },
        .{ .name = "empty-ppmd", .data = "", .method = .ppmd, .expected_size = 0 },
        .{ .name = "empty-shrink", .data = "", .method = .shrink, .expected_size = 0 },
        .{ .name = "empty-dcl", .data = "", .method = .dcl_implode, .expected_size = 0 },
        .{ .name = "empty-reduce", .data = "", .method = .reduce_1, .expected_size = 0 },
    };
    const bytes = try encodeEntries(allocator, &entries, .{
        .archive_comment = "streamed",
        .ppmd_options = .{ .properties = .{ .memory_size = 1024 * 1024 } },
    }, 7, 5);
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
        .{ .name = "bzip2.txt", .data = "deterministic Bzip2 stream" ** 79, .method = .bzip2, .expected_size = null },
        .{ .name = "zstd.txt", .data = "deterministic Zstd stream" ** 91, .method = .zstandard, .expected_size = null },
        .{ .name = "lzma.txt", .data = "deterministic LZMA stream" ** 67, .method = .lzma, .expected_size = null },
        .{ .name = "xz.txt", .data = "deterministic XZ stream" ** 73, .method = .xz, .expected_size = null },
        .{ .name = "deflate64.bin", .data = "deterministic Deflate64 stream" ** 83, .method = .deflate64, .expected_size = null },
        .{ .name = "ppmd.txt", .data = "deterministic PPMd stream" ** 61, .method = .ppmd, .expected_size = null },
        .{ .name = "shrink.txt", .data = "deterministic Shrink stream" ** 79, .method = .shrink, .expected_size = null },
        .{ .name = "dcl.txt", .data = "deterministic DCL Implode stream" ** 79, .method = .dcl_implode, .expected_size = null },
        .{ .name = "reduce.txt", .data = "deterministic Reduce stream" ** 79, .method = .reduce_4, .expected_size = null },
    };
    const tiny = try encodeEntries(allocator, &entries, .{
        .ppmd_options = .{ .properties = .{ .memory_size = 1024 * 1024 } },
    }, 1, 1);
    defer allocator.free(tiny);
    const coalesced = try encodeEntries(allocator, &entries, .{
        .ppmd_options = .{ .properties = .{ .memory_size = 1024 * 1024 } },
    }, 4096, 8192);
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
        .{ .name = "bzip2", .data = "bbbbbbbb", .method = .bzip2, .expected_size = 8 },
        .{ .name = "zstd", .data = "zzzzzzzz", .method = .zstandard, .expected_size = 8 },
        .{ .name = "lzma", .data = "llllllll", .method = .lzma, .expected_size = 8 },
        .{ .name = "xz", .data = "xxxxxxxx", .method = .xz, .expected_size = 8 },
        .{ .name = "deflate64", .data = "dddddddd", .method = .deflate64, .expected_size = 8 },
        .{ .name = "ppmd", .data = "pppppppp", .method = .ppmd, .expected_size = 8 },
        .{ .name = "shrink", .data = "ssssssss", .method = .shrink, .expected_size = 8 },
        .{ .name = "dcl", .data = "iiiiiiii", .method = .dcl_implode, .expected_size = 8 },
        .{ .name = "reduce", .data = "rrrrrrrr", .method = .reduce_1, .expected_size = 8 },
    };
    const bytes = try encodeEntries(allocator, &entries, .{}, 2, 3);
    defer allocator.free(bytes);
    const archive = try zip.parse(bytes);
    const known = try archive.entryAt(0);
    const unknown = try archive.entryAt(1);
    const deflated = try archive.entryAt(2);
    const bzip2_entry = try archive.entryAt(3);
    const zstd_entry = try archive.entryAt(4);
    const lzma_entry = try archive.entryAt(5);
    const xz_entry = try archive.entryAt(6);
    const deflate64_entry = try archive.entryAt(7);
    const ppmd_entry = try archive.entryAt(8);
    const shrink_entry = try archive.entryAt(9);
    const dcl_entry = try archive.entryAt(10);
    const reduce_entry = try archive.entryAt(11);
    try std.testing.expect(!known.zip64);
    try std.testing.expect(unknown.zip64);
    try std.testing.expect(deflated.zip64);
    try std.testing.expect(bzip2_entry.zip64);
    try std.testing.expect(zstd_entry.zip64);
    try std.testing.expect(lzma_entry.zip64);
    try std.testing.expect(xz_entry.zip64);
    try std.testing.expect(deflate64_entry.zip64);
    try std.testing.expect(ppmd_entry.zip64);
    try std.testing.expect(shrink_entry.zip64);
    try std.testing.expect(dcl_entry.zip64);
    try std.testing.expect(reduce_entry.zip64);

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
        unsupported.beginEntry(.{ .name = "bad", .method = .implode }),
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

test "ZIP incremental writer preflights codec configuration before headers" {
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

    var invalid_bzip2 = try incremental.Writer.initWithOptions(std.testing.allocator, .{
        .bzip2_options = .{ .block_size_100k = 0 },
    });
    defer invalid_bzip2.deinit();
    try std.testing.expectError(
        error.InvalidBzip2Header,
        invalid_bzip2.beginEntry(.{ .name = "bad-bzip2", .method = .bzip2 }),
    );
    try std.testing.expectEqual(incremental.Phase.ready, invalid_bzip2.snapshot().phase);

    var bounded_bzip2 = try incremental.Writer.initWithOptions(std.testing.allocator, .{
        .bzip2_options = .{ .max_pending_output_len = 0 },
    });
    defer bounded_bzip2.deinit();
    try std.testing.expectError(
        error.OutputLimitExceeded,
        bounded_bzip2.beginEntry(.{ .name = "bounded-bzip2", .method = .bzip2 }),
    );
    try std.testing.expectEqual(incremental.Phase.ready, bounded_bzip2.snapshot().phase);

    var input_limited_bzip2 = try incremental.Writer.initWithOptions(std.testing.allocator, .{
        .bzip2_options = .{ .max_input_len = 3 },
    });
    defer input_limited_bzip2.deinit();
    try std.testing.expectError(
        error.OutputLimitExceeded,
        input_limited_bzip2.beginEntry(.{
            .name = "long-bzip2",
            .method = .bzip2,
            .expected_size = 4,
        }),
    );
    try std.testing.expectEqual(incremental.Phase.ready, input_limited_bzip2.snapshot().phase);

    var invalid_zstd = try incremental.Writer.initWithOptions(std.testing.allocator, .{
        .zstd_options = .{ .block_size_max = 0 },
    });
    defer invalid_zstd.deinit();
    try std.testing.expectError(
        error.InvalidBlockPlan,
        invalid_zstd.beginEntry(.{ .name = "bad-zstd", .method = .zstandard }),
    );
    try std.testing.expectEqual(incremental.Phase.ready, invalid_zstd.snapshot().phase);

    var dictionary_zstd = try incremental.Writer.initWithOptions(std.testing.allocator, .{
        .zstd_options = .{ .dictionary_id = 7 },
    });
    defer dictionary_zstd.deinit();
    try std.testing.expectError(
        error.InvalidBlockPlan,
        dictionary_zstd.beginEntry(.{ .name = "dictionary-zstd", .method = .zstandard }),
    );
    try std.testing.expectEqual(incremental.Phase.ready, dictionary_zstd.snapshot().phase);

    var invalid_lzma = try incremental.Writer.initWithOptions(std.testing.allocator, .{
        .lzma_options = .{ .dictionary_size = 1024 },
    });
    defer invalid_lzma.deinit();
    try std.testing.expectError(
        error.InvalidLzmaOptions,
        invalid_lzma.beginEntry(.{ .name = "bad-lzma", .method = .lzma }),
    );
    try std.testing.expectEqual(incremental.Phase.ready, invalid_lzma.snapshot().phase);

    var input_limited_lzma = try incremental.Writer.initWithOptions(std.testing.allocator, .{
        .lzma_options = .{ .max_input_len = 3 },
    });
    defer input_limited_lzma.deinit();
    try std.testing.expectError(
        error.OutputLimitExceeded,
        input_limited_lzma.beginEntry(.{
            .name = "long-lzma",
            .method = .lzma,
            .expected_size = 4,
        }),
    );
    try std.testing.expectEqual(incremental.Phase.ready, input_limited_lzma.snapshot().phase);

    var invalid_xz = try incremental.Writer.initWithOptions(std.testing.allocator, .{
        .xz_options = .{ .block_size = 0 },
    });
    defer invalid_xz.deinit();
    try std.testing.expectError(
        error.InvalidBlockPlan,
        invalid_xz.beginEntry(.{ .name = "bad-xz", .method = .xz }),
    );
    try std.testing.expectEqual(incremental.Phase.ready, invalid_xz.snapshot().phase);

    var dictionary_xz = try incremental.Writer.initWithOptions(std.testing.allocator, .{
        .xz_options = .{ .dictionary_size = 1024 },
    });
    defer dictionary_xz.deinit();
    try std.testing.expectError(
        error.InvalidBlockPlan,
        dictionary_xz.beginEntry(.{ .name = "dictionary-xz", .method = .xz }),
    );
    try std.testing.expectEqual(incremental.Phase.ready, dictionary_xz.snapshot().phase);

    var invalid_deflate64 = try incremental.Writer.initWithOptions(std.testing.allocator, .{
        .deflate64_options = .{ .block_len = 0 },
    });
    defer invalid_deflate64.deinit();
    try std.testing.expectError(
        error.InvalidBlockPlan,
        invalid_deflate64.beginEntry(.{ .name = "bad-deflate64", .method = .deflate64 }),
    );
    try std.testing.expectEqual(incremental.Phase.ready, invalid_deflate64.snapshot().phase);

    var invalid_ppmd = try incremental.Writer.initWithOptions(std.testing.allocator, .{
        .ppmd_options = .{ .properties = .{ .order = 1, .memory_size = 1024 * 1024 } },
    });
    defer invalid_ppmd.deinit();
    try std.testing.expectError(
        error.InvalidPpmdProperties,
        invalid_ppmd.beginEntry(.{ .name = "bad-ppmd", .method = .ppmd }),
    );
    try std.testing.expectEqual(incremental.Phase.ready, invalid_ppmd.snapshot().phase);

    var pending_ppmd = try incremental.Writer.initWithOptions(std.testing.allocator, .{
        .ppmd_options = .{
            .properties = .{ .memory_size = 1024 * 1024 },
            .max_pending_output_len = 0,
        },
    });
    defer pending_ppmd.deinit();
    try std.testing.expectError(
        error.OutputLimitExceeded,
        pending_ppmd.beginEntry(.{ .name = "pending-ppmd", .method = .ppmd }),
    );
    try std.testing.expectEqual(incremental.Phase.ready, pending_ppmd.snapshot().phase);

    var pending_shrink = try incremental.Writer.initWithOptions(std.testing.allocator, .{
        .shrink_options = .{ .max_pending_output_len = 0 },
    });
    defer pending_shrink.deinit();
    try std.testing.expectError(
        error.OutputLimitExceeded,
        pending_shrink.beginEntry(.{ .name = "pending-shrink", .method = .shrink }),
    );
    try std.testing.expectEqual(incremental.Phase.ready, pending_shrink.snapshot().phase);

    var invalid_dcl = try incremental.Writer.initWithOptions(std.testing.allocator, .{
        .dcl_implode_options = .{ .max_chain = 0 },
    });
    defer invalid_dcl.deinit();
    try std.testing.expectError(
        error.InvalidDclOptions,
        invalid_dcl.beginEntry(.{ .name = "invalid-dcl", .method = .dcl_implode }),
    );
    try std.testing.expectEqual(incremental.Phase.ready, invalid_dcl.snapshot().phase);

    var input_limited_dcl = try incremental.Writer.initWithOptions(std.testing.allocator, .{
        .dcl_implode_options = .{ .max_input_len = 3 },
    });
    defer input_limited_dcl.deinit();
    try std.testing.expectError(
        error.OutputLimitExceeded,
        input_limited_dcl.beginEntry(.{
            .name = "long-dcl",
            .method = .dcl_implode,
            .expected_size = 4,
        }),
    );
    try std.testing.expectEqual(incremental.Phase.ready, input_limited_dcl.snapshot().phase);

    var invalid_reduce = try incremental.Writer.initWithOptions(std.testing.allocator, .{
        .reduce_options = .{ .max_chain = 0 },
    });
    defer invalid_reduce.deinit();
    try std.testing.expectError(
        error.InvalidReduceOptions,
        invalid_reduce.beginEntry(.{ .name = "invalid-reduce", .method = .reduce_1 }),
    );
    try std.testing.expectEqual(incremental.Phase.ready, invalid_reduce.snapshot().phase);

    var input_limited_reduce = try incremental.Writer.initWithOptions(std.testing.allocator, .{
        .reduce_options = .{ .max_input_len = 3 },
    });
    defer input_limited_reduce.deinit();
    try std.testing.expectError(
        error.OutputLimitExceeded,
        input_limited_reduce.beginEntry(.{
            .name = "long-reduce",
            .method = .reduce_4,
            .expected_size = 4,
        }),
    );
    try std.testing.expectEqual(incremental.Phase.ready, input_limited_reduce.snapshot().phase);
}

test "ZIP incremental writer emits multi-block Bzip2 payloads" {
    const allocator = std.testing.allocator;
    const payload = try allocator.alloc(u8, 101_321);
    defer allocator.free(payload);
    for (payload, 0..) |*byte, index| byte.* = @truncate(index *% 73 +% index / 251);
    @memset(payload[49_900..50_700], 0xa5);
    const entries = [_]TestEntry{.{
        .name = "multi-block.bz2",
        .data = payload,
        .method = .bzip2,
        .expected_size = payload.len,
    }};
    const bytes = try encodeEntries(allocator, &entries, .{
        .zip64 = .never,
        .bzip2_options = .{ .block_size_100k = 1 },
    }, 257, 11);
    defer allocator.free(bytes);
    const archive = try zip.parse(bytes);
    const entry = try archive.entryAt(0);
    try std.testing.expect(!entry.zip64);
    const decoded = try archive.extractAlloc(allocator, entry);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "ZIP incremental writer emits multi-block Zstandard frames" {
    const allocator = std.testing.allocator;
    const payload = ("multi-block incremental Zstandard payload\n" ** 257) ++
        ([_]u8{ 0, 1, 2, 3, 4, 5, 0xfe, 0xff } ** 311);
    const entries = [_]TestEntry{.{
        .name = "multi-block.zst",
        .data = payload,
        .method = .zstandard,
        .expected_size = payload.len,
    }};
    const bytes = try encodeEntries(allocator, &entries, .{
        .zip64 = .never,
        .zstd_options = .{
            .content_checksum = true,
            .block_size_max = 4096,
            .selection = .raw_or_rle,
        },
    }, 211, 13);
    defer allocator.free(bytes);
    const archive = try zip.parse(bytes);
    const entry = try archive.entryAt(0);
    try std.testing.expect(!entry.zip64);
    const compressed = try archive.compressedData(entry);
    const header = try zstd.inspectNativeFrameHeader(compressed);
    try std.testing.expectEqual(@as(?u64, payload.len), header.content_size);
    try std.testing.expect(header.has_checksum);
    const decoded = try archive.extractAlloc(allocator, entry);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "ZIP incremental writer emits ZIP LZMA prefix and end marker" {
    const allocator = std.testing.allocator;
    const payload = "ZIP method-14 incremental LZMA payload\n" ** 113;
    const entries = [_]TestEntry{.{
        .name = "payload.lzma",
        .data = payload,
        .method = .lzma,
        .expected_size = payload.len,
    }};
    const bytes = try encodeEntries(allocator, &entries, .{
        .zip64 = .never,
        .lzma_options = .{
            .dictionary_size = 4096,
            .mode = .literal_only,
            .input_buffer_len = 4096,
        },
    }, 37, 7);
    defer allocator.free(bytes);
    const archive = try zip.parse(bytes);
    const entry = try archive.entryAt(0);
    try std.testing.expect(!entry.zip64);
    try std.testing.expect(entry.flags & wire.lzma_end_marker_flag != 0);
    const compressed = try archive.compressedData(entry);
    try std.testing.expect(compressed.len > 9);
    try std.testing.expectEqualSlices(u8, &.{ 9, 4, 5, 0 }, compressed[0..4]);
    try std.testing.expectEqual(@as(u32, 4096), std.mem.readInt(u32, compressed[5..9], .little));
    const decoded = try archive.extractAlloc(allocator, entry);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "ZIP incremental writer emits filtered multi-block XZ streams" {
    const allocator = std.testing.allocator;
    const payload = ("filtered multi-block incremental XZ payload\n" ** 193) ++
        ([_]u8{ 0x90, 0xe8, 0x10, 0, 0, 0, 0xe9, 0xf0, 0xff, 0xff, 0xff, 0x90 } ** 211);
    const filters = [_]xz.Filter{
        xz.Filter.x86(0),
        try xz.Filter.delta(4),
    };
    const entries = [_]TestEntry{.{
        .name = "filtered.xz",
        .data = payload,
        .method = .xz,
        .expected_size = payload.len,
    }};
    const bytes = try encodeEntries(allocator, &entries, .{
        .zip64 = .never,
        .xz_options = .{
            .check = .sha256,
            .block_size = 1024,
            .dictionary_size = 4096,
            .filters = &filters,
        },
    }, 173, 17);
    defer allocator.free(bytes);
    const archive = try zip.parse(bytes);
    const entry = try archive.entryAt(0);
    try std.testing.expect(!entry.zip64);
    const decoded = try archive.extractAlloc(allocator, entry);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "ZIP incremental writer emits multi-block Deflate64 stored streams" {
    const allocator = std.testing.allocator;
    const payload = try allocator.alloc(u8, std.math.maxInt(u16) + 17);
    defer allocator.free(payload);
    for (payload, 0..) |*byte, index| byte.* = @truncate(index *% 73 +% index / 251);
    const entries = [_]TestEntry{.{
        .name = "multi-block.deflate64",
        .data = payload,
        .method = .deflate64,
        .expected_size = payload.len,
    }};
    const bytes = try encodeEntries(allocator, &entries, .{
        .zip64 = .never,
        .deflate64_options = .{ .block_len = 4096 },
    }, 257, 11);
    defer allocator.free(bytes);
    const archive = try zip.parse(bytes);
    const entry = try archive.entryAt(0);
    try std.testing.expect(!entry.zip64);
    const compressed = try archive.compressedData(entry);
    try std.testing.expectEqual(@as(u3, 0b000), @as(u3, @truncate(compressed[0])));
    const decoded = try archive.extractAlloc(allocator, entry);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "ZIP incremental writer emits PPMd restart and cut-off properties" {
    const allocator = std.testing.allocator;
    const payload = "ZIP method-98 incremental PPMd payload\n" ** 97;
    inline for (.{ ppmd8.RestoreMethod.restart, .cut_off }) |restore_method| {
        const entries = [_]TestEntry{.{
            .name = "payload.ppmd",
            .data = payload,
            .method = .ppmd,
            .expected_size = payload.len,
        }};
        const bytes = try encodeEntries(allocator, &entries, .{
            .zip64 = .never,
            .ppmd_options = .{
                .properties = .{
                    .order = 12,
                    .memory_size = 1024 * 1024,
                    .restore_method = restore_method,
                },
            },
        }, 29, 7);
        defer allocator.free(bytes);
        const archive = try zip.parse(bytes);
        const entry = try archive.entryAt(0);
        try std.testing.expect(!entry.zip64);
        const compressed = try archive.compressedData(entry);
        const properties = try ppmd8.parseZipProperties(compressed);
        try std.testing.expectEqual(@as(u8, 12), properties.order);
        try std.testing.expectEqual(@as(u32, 1024 * 1024), properties.memory_size);
        try std.testing.expectEqual(restore_method, properties.restore_method);
        const decoded = try archive.extractAlloc(allocator, entry);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, payload, decoded);
    }
}

test "ZIP incremental writer grows and freezes the Shrink dictionary" {
    const allocator = std.testing.allocator;
    const payload = try allocator.alloc(u8, 32 * 1024);
    defer allocator.free(payload);
    var random_state: u32 = 0x5a17_c9e3;
    for (payload) |*byte| {
        random_state = random_state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(random_state >> 24);
    }
    const entries = [_]TestEntry{.{
        .name = "full-dictionary.shrink",
        .data = payload,
        .method = .shrink,
        .expected_size = payload.len,
    }};
    const bytes = try encodeEntries(allocator, &entries, .{ .zip64 = .never }, 31, 7);
    defer allocator.free(bytes);
    const archive = try zip.parse(bytes);
    const entry = try archive.entryAt(0);
    try std.testing.expect(!entry.zip64);
    const decoded = try archive.extractAlloc(allocator, entry);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "ZIP incremental writer emits byte-exact DCL Implode modes" {
    const allocator = std.testing.allocator;
    const prefix_len = 3000;
    const payload = try allocator.alloc(u8, prefix_len * 2 + 1);
    defer allocator.free(payload);
    var random_state: u32 = 0xdca1_0010;
    for (payload[0..prefix_len]) |*byte| {
        random_state = random_state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(random_state >> 24);
    }
    payload[prefix_len] = 0x42;
    @memcpy(payload[prefix_len + 1 ..], payload[0..prefix_len]);

    inline for (.{ false, true }) |literal_coded| {
        inline for (std.meta.tags(dcl.Dictionary)) |dictionary| {
            const entries = [_]TestEntry{.{
                .name = "payload.dcl",
                .data = payload,
                .method = .dcl_implode,
                .expected_size = payload.len,
            }};
            const bytes = try encodeEntries(allocator, &entries, .{
                .zip64 = .never,
                .dcl_implode_options = .{
                    .literal_coded = literal_coded,
                    .dictionary = dictionary,
                },
            }, 3, 1);
            defer allocator.free(bytes);
            const archive = try zip.parse(bytes);
            const entry = try archive.entryAt(0);
            try std.testing.expect(!entry.zip64);
            try std.testing.expectEqual(@as(u16, 20), readU16(bytes, entry.local_header_offset + 4));
            const compressed = try archive.compressedData(entry);
            const expected = try dcl.encodeAlloc(allocator, payload, .{
                .literal_coded = literal_coded,
                .dictionary = dictionary,
            });
            defer allocator.free(expected);
            try std.testing.expectEqualSlices(u8, expected, compressed);
            const decoded = try archive.extractAlloc(allocator, entry);
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, payload, decoded);
        }
    }
}

test "ZIP incremental writer emits trained byte-exact Reduce factors" {
    const allocator = std.testing.allocator;
    const prefix_len = 3000;
    const payload = try allocator.alloc(u8, prefix_len * 2 + 3);
    defer allocator.free(payload);
    var random_state: u32 = 0x4050_6074;
    for (payload[0..prefix_len]) |*byte| {
        random_state = random_state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(random_state >> 24);
    }
    payload[prefix_len] = reduce.dle;
    payload[prefix_len + 1] = 0x42;
    payload[prefix_len + 2] = reduce.dle;
    @memcpy(payload[prefix_len + 3 ..], payload[0..prefix_len]);
    const methods = [_]zip.CompressionMethod{
        .reduce_1,
        .reduce_2,
        .reduce_3,
        .reduce_4,
    };

    inline for (std.meta.tags(reduce.Factor), methods) |factor, method| {
        const followers = try reduce.trainFollowerTable(allocator, payload, factor, .{});
        const entries = [_]TestEntry{.{
            .name = "payload.reduce",
            .data = payload,
            .method = method,
            .expected_size = payload.len,
        }};
        const bytes = try encodeEntries(allocator, &entries, .{
            .zip64 = .never,
            .reduce_options = .{ .followers = followers },
        }, 3, 1);
        defer allocator.free(bytes);
        const archive = try zip.parse(bytes);
        const entry = try archive.entryAt(0);
        try std.testing.expect(!entry.zip64);
        try std.testing.expectEqual(@as(u16, 20), readU16(bytes, entry.local_header_offset + 4));
        const compressed = try archive.compressedData(entry);
        const expected = try reduce.encodeAlloc(allocator, payload, factor, .{});
        defer allocator.free(expected);
        try std.testing.expectEqualSlices(u8, expected, compressed);
        const decoded = try archive.extractAlloc(allocator, entry);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, payload, decoded);
    }
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
                .{ .name = "bzip2", .data = "allocation-safe bzip2" ** 47, .method = .bzip2, .expected_size = null },
                .{ .name = "zstd", .data = "allocation-safe zstd" ** 53, .method = .zstandard, .expected_size = null },
                .{ .name = "lzma", .data = "allocation-safe lzma" ** 41, .method = .lzma, .expected_size = null },
                .{ .name = "xz", .data = "allocation-safe xz" ** 43, .method = .xz, .expected_size = null },
                .{ .name = "deflate64", .data = "allocation-safe deflate64" ** 37, .method = .deflate64, .expected_size = null },
                .{ .name = "ppmd", .data = "allocation-safe ppmd" ** 31, .method = .ppmd, .expected_size = null },
                .{ .name = "shrink", .data = "allocation-safe shrink" ** 47, .method = .shrink, .expected_size = null },
                .{ .name = "dcl", .data = "allocation-safe dcl implode" ** 47, .method = .dcl_implode, .expected_size = null },
                .{ .name = "reduce", .data = "allocation-safe reduce" ** 47, .method = .reduce_4, .expected_size = null },
            };
            const encoded = try encodeEntries(allocator, &entries, .{
                .archive_comment = "oom",
                .ppmd_options = .{ .properties = .{ .memory_size = 1024 * 1024 } },
            }, 17, 19);
            defer allocator.free(encoded);
            const archive = try zip.parse(encoded);
            const decoded = try archive.extractAlloc(allocator, try archive.entryAt(10));
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, entries[10].data, decoded);
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
