const std = @import("std");
const format = @import("../../format.zig");
const archive_module = @import("../../archive.zig");
const source_archive = @import("../../source_archive.zig");
const configuration = @import("../configuration.zig");
const helpers = @import("helpers.zig");
const dual = @import("dual_algorithm_helpers.zig");
const writer = @import("../../writer.zig");
const codec = @import("../../codec.zig");

fn expectInitError(image: []const u8, expected: anyerror) !void {
    try std.testing.expectError(expected, archive_module.Archive.init(image));
    var input = helpers.Input{ .bytes = image };
    try std.testing.expectError(expected, source_archive.SourceArchive.init(std.testing.allocator, input.source(), .{}));
}

test "EROFS configuration rejects unknown algorithms short records and invalid known fields" {
    const allocator = std.testing.allocator;
    const Mutation = struct { algorithm: format.Compression, offset: usize, bytes: []const u8, err: anyerror };
    for ([_]Mutation{
        .{ .algorithm = .lz4, .offset = 1108, .bytes = &.{ 1, 128 }, .err = error.UnsupportedErofsCompression },
        .{ .algorithm = .lz4, .offset = 1152, .bytes = &.{ 0, 0 }, .err = error.InvalidErofs },
        .{ .algorithm = .lz4, .offset = 1152, .bytes = &.{ 13, 0 }, .err = error.InvalidErofs },
        .{ .algorithm = .lz4, .offset = 1156, .bytes = &.{ 1, 1 }, .err = error.InvalidErofs },
        .{ .algorithm = .lzma, .offset = 1152, .bytes = &.{ 1, 0 }, .err = error.InvalidErofs },
        .{ .algorithm = .lzma, .offset = 1154, .bytes = &.{ 0, 0, 0, 0 }, .err = error.InvalidErofs },
        .{ .algorithm = .lzma, .offset = 1154, .bytes = &.{ 1, 0, 128, 0 }, .err = error.InvalidErofs },
        .{ .algorithm = .lzma, .offset = 1158, .bytes = &.{ 1, 0 }, .err = error.UnsupportedErofsCompression },
        .{ .algorithm = .deflate, .offset = 1152, .bytes = &.{ 5, 0 }, .err = error.InvalidErofs },
        .{ .algorithm = .deflate, .offset = 1154, .bytes = &.{7}, .err = error.InvalidErofs },
        .{ .algorithm = .deflate, .offset = 1154, .bytes = &.{16}, .err = error.InvalidErofs },
        .{ .algorithm = .zstandard, .offset = 1152, .bytes = &.{ 5, 0 }, .err = error.InvalidErofs },
        .{ .algorithm = .zstandard, .offset = 1154, .bytes = &.{1}, .err = error.UnsupportedErofsCompression },
        .{ .algorithm = .zstandard, .offset = 1155, .bytes = &.{11}, .err = error.InvalidErofs },
    }) |mutation| {
        const image = try dual.build(allocator, mutation.algorithm, mutation.algorithm, .full);
        defer allocator.free(image);
        @memcpy(image[mutation.offset..][0..mutation.bytes.len], mutation.bytes);
        dual.refresh(image);
        try expectInitError(image, mutation.err);
    }
}

test "EROFS configuration parsing is allocation free across aligned cross-block extensions" {
    const allocator = std.testing.allocator;
    const image = try allocator.alloc(u8, 8192);
    defer allocator.free(image);
    @memset(image, 0);
    const seed = try dual.build(allocator, .lz4, .deflate, .full);
    defer allocator.free(seed);
    var header = try format.parseSuperblock(seed);
    header.block_count = 2;
    header.available_compression_algorithms = 0x0f;
    const record_size: usize = 2943;
    std.mem.writeInt(u16, image[1152..1154], record_size, .little);
    std.mem.writeInt(u16, image[1154..1156], 20, .little);
    // max_pclusterblks zero is the standard reserved single-block default.
    @memset(image[1168..4097], 0x7d);
    std.mem.writeInt(u16, image[4100..4102], 14, .little);
    std.mem.writeInt(u32, image[4102..4106], 4096, .little);
    std.mem.writeInt(u16, image[4116..4118], 6, .little);
    image[4118] = 8;
    std.mem.writeInt(u16, image[4124..4126], 6, .little);
    image[4127] = 0;
    const slice = try configuration.read(.{ .slice = image }, header);
    try std.testing.expectEqual(@as(u16, 15), slice.available_algorithms);
    try std.testing.expectEqual(@as(usize, 20), slice.options.lz4_max_distance);
    try std.testing.expectEqual(@as(usize, 1), slice.lz4_max_pcluster_blocks);
    try std.testing.expectEqual(@as(u32, 4096), slice.options.lzma_dictionary_size);
    try std.testing.expectEqual(@as(usize, 256), slice.options.deflate_max_distance);
    try std.testing.expectEqual(@as(u64, 1024), slice.options.zstandard_max_window_size);
    var input = helpers.Input{ .bytes = image };
    try std.testing.expectEqualDeep(slice, try configuration.read(.{ .source = input.source() }, header));
    try std.testing.expect(input.max_request <= 31);
    input.fail_from_offset = 2048;
    try std.testing.expectError(error.SourceReadFailed, configuration.read(.{ .source = input.source() }, header));
    input.fail_from_offset = null;
    try std.testing.expectEqualDeep(slice, try configuration.read(.{ .source = input.source() }, header));
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    const normal = try dual.build(allocator, .deflate, .lz4, .full);
    defer allocator.free(normal);
    var normal_source = helpers.Input{ .bytes = normal };
    var source = try source_archive.SourceArchive.init(failing.allocator(), normal_source.source(), .{ .max_working_memory = 0 });
    defer source.deinit();
    try std.testing.expectEqual(@as(usize, 0), source.working.live);
}

test "EROFS truncated configuration ranges obey declared image size and Source error classes" {
    const allocator = std.testing.allocator;
    const image = try dual.build(allocator, .lz4, .lz4, .full);
    defer allocator.free(image);
    std.mem.writeInt(u16, image[1152..1154], 65535, .little);
    dual.refresh(image);
    try expectInitError(image, error.TruncatedFrame);
    std.mem.writeInt(u16, image[1152..1154], 14, .little);
    dual.refresh(image);
    var header = try format.parseSuperblock(image);
    header.super_size = 3068;
    header.block_count = 1;
    std.mem.writeInt(u16, image[4092..4094], 14, .little);
    try std.testing.expectError(error.TruncatedFrame, configuration.read(.{ .slice = image }, header));
    // A tiny declared image cannot be extended by trailing resident bytes.
    header.super_size = 128;
    header.block_count = 0;
    try std.testing.expectError(error.TruncatedFrame, configuration.read(.{ .slice = image }, header));
    var input = helpers.Input{ .bytes = image, .fail_from_offset = 1152 };
    try std.testing.expectError(error.SourceReadFailed, source_archive.SourceArchive.init(allocator, input.source(), .{}));
}

test "EROFS actual codec selection requires declared algorithms without rejecting unused slots" {
    const allocator = std.testing.allocator;
    const image = try dual.build(allocator, .deflate, .lz4, .full);
    defer allocator.free(image);
    // Remove LZ4 from the declared mask, moving Deflate to the first record.
    @memcpy(image[1152..1160], image[1168..1176]);
    std.mem.writeInt(u16, image[1108..1110], 4, .little);
    dual.refresh(image);
    const slice = try archive_module.Archive.init(image);
    const value = try slice.inode(dual.file_nid);
    var source_input = helpers.Input{ .bytes = image };
    var source = try source_archive.SourceArchive.init(allocator, source_input.source(), .{});
    defer source.deinit();
    var reader = try source.initExtractor(value, .{ .max_output_len = 8192 });
    defer reader.deinit();
    var output: [4096]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 4096), (try reader.read(&output)).output_written);
    @memset(&output, 0xa5);
    try std.testing.expectError(error.InvalidErofs, reader.read(&output));
    try std.testing.expectError(error.InvalidErofs, reader.read(&output));
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    try std.testing.expectEqual(@as(usize, 4096), reader.position());
    try std.testing.expectEqual(@as(usize, 0), source.working.live);
    const only_first = try slice.initRangeExtractor(allocator, value, 0, 1, .{ .max_output_len = 1 });
    var first_reader = only_first;
    defer first_reader.deinit();
    try std.testing.expectEqual(@as(usize, 1), (try first_reader.read(output[0..1])).output_written);
    try std.testing.expectEqual(.done, (try first_reader.read(output[0..0])).status);
    std.mem.writeInt(u16, image[1108..1110], 0, .little);
    dual.refresh(image);
    const no_algorithms = try archive_module.Archive.init(image);
    try std.testing.expectError(error.InvalidErofs, no_algorithms.readFlatAllocLimited(allocator, value, 8192));
}

test "EROFS configuration applies codec windows dictionaries and physical LZ4 limits" {
    const allocator = std.testing.allocator;
    for (dual.algorithms) |algorithm| {
        const image = try dual.build(allocator, algorithm, algorithm, .full);
        defer allocator.free(image);
        // Valid minimum fields still decode their independent reference blocks.
        switch (algorithm) {
            .lz4 => std.mem.writeInt(u16, image[1156..1158], 0, .little),
            .lzma => std.mem.writeInt(u32, image[1154..1158], 4096, .little),
            .deflate => image[1154] = 8,
            .zstandard => image[1155] = 2,
        }
        dual.refresh(image);
        const slice = try archive_module.Archive.init(image);
        const output = try slice.extractByPathAllocLimited(allocator, "file", 8192, 4096);
        defer allocator.free(output);
        try std.testing.expectEqualStrings(dual.first[0..4096], output[0..4096]);
        try std.testing.expectEqualStrings(dual.second[0..4096], output[4096..]);
        if (algorithm == .lz4) {
            std.mem.writeInt(u16, image[1154..1156], 1, .little);
            dual.refresh(image);
            const limited = try archive_module.Archive.init(image);
            try std.testing.expectError(error.InvalidMatch, limited.extractByPathAllocLimited(allocator, "file", 8192, 4096));
        } else if (algorithm == .zstandard) {
            image[1155] = 0;
            dual.refresh(image);
            const limited = try archive_module.Archive.init(image);
            try std.testing.expectError(error.InvalidErofs, limited.extractByPathAllocLimited(allocator, "file", 8192, 4096));
        }
    }
    const compressed = try writer.encodeAlloc(allocator, &.{.{ .path = "file", .data = "large lz4 extent\n" ** 800 }}, .{ .compression = .lz4, .compression_extent_size = 32768 });
    defer allocator.free(compressed);
    std.mem.writeInt(u16, compressed[1156..1158], 0, .little);
    dual.refresh(compressed);
    const limited = try archive_module.Archive.init(compressed);
    const value = try limited.lookup(allocator, "file", 32768, 4096);
    var config = limited.compression_configuration;
    try std.testing.expectError(error.InvalidErofs, config.require(.lz4, 8192, 4096));
    try config.require(.lz4, 4096, 4096);
    try std.testing.expect(value.file_size > 4096);
}

test "EROFS old LZ4 superblock distance fields keep legacy and stored behavior" {
    const allocator = std.testing.allocator;
    for ([_]writer.Compression{ .stored, .lz4 }) |compression| {
        const image = try writer.encodeAlloc(allocator, &.{.{ .path = "file", .data = "old header payload\n" ** 300 }}, .{ .compression = compression });
        defer allocator.free(image);
        var input = helpers.Input{ .bytes = image };
        var source = try source_archive.SourceArchive.init(allocator, input.source(), .{});
        defer source.deinit();
        try std.testing.expectEqual(@as(u16, if (compression == .stored) 0 else 1), source.compression_configuration.available_algorithms);
        const bytes = try source.extractByPathAllocLimited(allocator, "file", 8192, 4096);
        defer allocator.free(bytes);
        try std.testing.expectEqualStrings("old header payload\n" ** 300, bytes);
    }
}

fn decodedFixture(allocator: std.mem.Allocator, encoded: []const u8) ![]u8 {
    const decoder = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const bytes = try allocator.alloc(u8, decoder.calcSizeUpperBound(encoded.len));
    errdefer allocator.free(bytes);
    return allocator.realloc(bytes, try decoder.decode(bytes, encoded));
}

test "EROFS declared Deflate and MicroLZMA histories reject far matches in full and prefix modes" {
    const allocator = std.testing.allocator;
    const expected = try decodedFixture(allocator, @embedFile("../../testdata/config-long-distance.bin.b64"));
    defer allocator.free(expected);
    for ([_]struct { algorithm: format.Compression, data: []const u8, options: codec.DecodeOptions, err: anyerror }{
        .{ .algorithm = .deflate, .data = @embedFile("../../testdata/config-long-distance.deflate.b64"), .options = .{ .deflate_max_distance = 4096 }, .err = error.InvalidMatch },
        .{ .algorithm = .lzma, .data = @embedFile("../../testdata/config-long-distance.microlzma.b64"), .options = .{ .lzma_dictionary_size = 4096 }, .err = error.InvalidLzmaStream },
    }) |case| {
        const wire = try decodedFixture(allocator, case.data);
        defer allocator.free(wire);
        const complete = try codec.decodeExtentWithOptionsAlloc(allocator, case.algorithm, wire, expected.len, false, false, .{});
        defer allocator.free(complete);
        try std.testing.expectEqualSlices(u8, expected, complete);
        const before_match = try codec.decodeExtentWithOptionsAlloc(allocator, case.algorithm, wire, 8192, false, true, case.options);
        defer allocator.free(before_match);
        try std.testing.expectEqualSlices(u8, expected[0..8192], before_match);
        try std.testing.expectError(case.err, codec.decodeExtentWithOptionsAlloc(allocator, case.algorithm, wire, expected.len, false, false, case.options));
        try std.testing.expectError(case.err, codec.decodeExtentWithOptionsAlloc(allocator, case.algorithm, wire, 9000, false, true, case.options));
    }
}

test "EROFS restricted history decoding releases every allocation failure" {
    const allocator = std.testing.allocator;
    const Test = struct {
        fn run(work: std.mem.Allocator, image: []const u8, source_mode: bool) !void {
            if (source_mode) {
                var input = helpers.Input{ .bytes = image };
                var source = try source_archive.SourceArchive.init(work, input.source(), .{});
                defer source.deinit();
                const result = try source.extractByPathAllocLimited(work, "file", 8192, 4096);
                defer work.free(result);
                try std.testing.expectEqualStrings(dual.first[0..4096], result[0..4096]);
            } else {
                const slice = try archive_module.Archive.init(image);
                const result = try slice.extractByPathAllocLimited(work, "file", 8192, 4096);
                defer work.free(result);
                try std.testing.expectEqualStrings(dual.first[0..4096], result[0..4096]);
            }
        }
    };
    const image = try dual.build(allocator, .deflate, .deflate, .full);
    defer allocator.free(image);
    image[1154] = 8;
    dual.refresh(image);
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{ image, false });
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{ image, true });
}
