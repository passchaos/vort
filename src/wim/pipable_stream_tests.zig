const std = @import("std");
const core = @import("../core.zig");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");
const metadata = @import("metadata.zig");
const pipable = @import("pipable.zig");
const stream = @import("pipable_stream.zig");

const PathExtractor = stream.PathExtractor;

fn fixtureAlloc(allocator: std.mem.Allocator, encoded_base64: []const u8) ![]u8 {
    const decoder = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const bytes = try allocator.alloc(
        u8,
        decoder.calcSizeUpperBound(encoded_base64.len),
    );
    errdefer allocator.free(bytes);
    const written = try decoder.decode(bytes, encoded_base64);
    return allocator.realloc(bytes, written);
}

fn extractFixtureAlloc(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    input_step: usize,
    output_step: usize,
) ![]u8 {
    var extractor = PathExtractor.init(allocator, .{
        .path = "/nested/payload.txt",
        .max_output_len = 4096,
    });
    defer extractor.deinit();
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    const scratch = try allocator.alloc(u8, output_step);
    defer allocator.free(scratch);
    var input_offset: usize = 0;
    while (true) {
        const input_end = @min(bytes.len, input_offset + input_step);
        const stepped = try extractor.step(bytes[input_offset..input_end], scratch);
        input_offset += stepped.progress.input_read;
        try output.appendSlice(allocator, scratch[0..stepped.progress.output_written]);
        if (stepped.status == .done) break;
        if (stepped.status == .need_input and input_offset == bytes.len) {
            try extractor.finish();
            return error.TestUnexpectedResult;
        }
        if (stepped.progress.input_read == 0 and stepped.progress.output_written == 0 and
            stepped.status != .need_output)
            return error.TestUnexpectedResult;
    }
    try std.testing.expect(input_offset < bytes.len);
    return output.toOwnedSlice(allocator);
}

test "WIM pipable stream extracts a path across one-byte input cuts" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(
        allocator,
        @embedFile("testdata/pipable-xpress.wim.b64"),
    );
    defer allocator.free(bytes);
    const output = try extractFixtureAlloc(allocator, bytes, 1, 3);
    defer allocator.free(output);
    try std.testing.expectEqualStrings(
        @embedFile("../lzms/testdata/lzms-small.txt"),
        output,
    );
}

test "WIM pipable stream honors output backpressure and limits" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(
        allocator,
        @embedFile("testdata/pipable-xpress.wim.b64"),
    );
    defer allocator.free(bytes);
    var extractor = PathExtractor.init(allocator, .{
        .path = "/nested/payload.txt",
        .max_output_len = 4096,
    });
    defer extractor.deinit();
    const blocked = try extractor.step(bytes, &.{});
    try std.testing.expectEqual(core.StepResult.Status.need_output, blocked.status);
    try std.testing.expect(blocked.progress.input_read < bytes.len);

    var limited = PathExtractor.init(allocator, .{
        .path = "/nested/payload.txt",
        .max_output_len = 694,
    });
    defer limited.deinit();
    var scratch: [1024]u8 = undefined;
    try std.testing.expectError(
        error.OutputLimitExceeded,
        limited.step(bytes, &scratch),
    );

    var metadata_limited = PathExtractor.init(allocator, .{
        .path = "/nested/payload.txt",
        .max_output_len = 4096,
        .limits = .{ .max_metadata_bytes = 1 },
    });
    defer metadata_limited.deinit();
    try std.testing.expectError(
        error.OutputLimitExceeded,
        metadata_limited.step(bytes, &scratch),
    );

    var chunk_limited = PathExtractor.init(allocator, .{
        .path = "/nested/payload.txt",
        .max_output_len = 4096,
        .limits = .{ .max_chunk_bytes = 1 },
    });
    defer chunk_limited.deinit();
    try std.testing.expectError(
        error.OutputLimitExceeded,
        chunk_limited.step(bytes, &scratch),
    );

    var bad_image = PathExtractor.init(allocator, .{
        .image_index = 2,
        .path = "/nested/payload.txt",
        .max_output_len = 4096,
    });
    defer bad_image.deinit();
    try std.testing.expectError(
        error.WimImageNotFound,
        bad_image.step(bytes, &scratch),
    );
}

test "WIM pipable stream reports truncation and missing target blob" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(
        allocator,
        @embedFile("testdata/pipable-xpress.wim.b64"),
    );
    defer allocator.free(bytes);
    var truncated = PathExtractor.init(allocator, .{
        .path = "/nested/payload.txt",
        .max_output_len = 4096,
    });
    defer truncated.deinit();
    var scratch: [1024]u8 = undefined;
    _ = try truncated.step(bytes[0..100], &scratch);
    try std.testing.expectError(error.TruncatedFrame, truncated.finish());

    const archive = try archive_mod.Archive.init(bytes);
    var lookup = try archive.readLookupTableAlloc(allocator, 16, 4096);
    defer lookup.deinit();
    const hash: [20]u8 = .{
        0xd5, 0x92, 0x98, 0x58, 0xeb, 0xff, 0xe1, 0x96, 0x3c, 0xa1,
        0xe2, 0x6d, 0xd1, 0x89, 0xcc, 0x32, 0xc6, 0xce, 0x29, 0x14,
    };
    const entry = lookup.find(&hash).?;
    const chunk_header: usize = @intCast(entry.resource.offset_in_wim);
    const saved_chunk_size = format.readU32(bytes, chunk_header);
    std.mem.writeInt(u32, bytes[chunk_header..][0..4], 0, .little);
    var corrupt_chunk = PathExtractor.init(allocator, .{
        .path = "/nested/payload.txt",
        .max_output_len = 4096,
    });
    defer corrupt_chunk.deinit();
    try std.testing.expectError(
        error.InvalidWim,
        corrupt_chunk.step(bytes, &scratch),
    );
    std.mem.writeInt(u32, bytes[chunk_header..][0..4], saved_chunk_size, .little);

    const blob_header: usize = @intCast(entry.resource.offset_in_wim - pipable.blob_header_size);
    bytes[blob_header + 16] ^= 1;
    defer bytes[blob_header + 16] ^= 1;
    var missing = PathExtractor.init(allocator, .{
        .path = "/nested/payload.txt",
        .max_output_len = 4096,
    });
    defer missing.deinit();
    var input_offset: usize = 0;
    while (input_offset < bytes.len) {
        const stepped = try missing.step(bytes[input_offset..], &scratch);
        input_offset += stepped.progress.input_read;
        if (stepped.status == .done) return error.TestUnexpectedResult;
        if (stepped.status == .need_output) return error.TestUnexpectedResult;
    }
    try std.testing.expectError(error.WimResourceNotFound, missing.finish());
}

test "WIM pipable stream path extraction releases every allocation failure" {
    const bytes = try fixtureAlloc(
        std.testing.allocator,
        @embedFile("testdata/pipable-xpress.wim.b64"),
    );
    defer std.testing.allocator.free(bytes);
    const FailureTest = struct {
        fn run(allocator: std.mem.Allocator, fixture: []const u8) !void {
            const output = try extractFixtureAlloc(allocator, fixture, 7, 11);
            defer allocator.free(output);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        FailureTest.run,
        .{bytes},
    );
}

fn appendUncompressedBlob(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    payload: []const u8,
    flags: u32,
) !void {
    var header: [pipable.blob_header_size]u8 = @splat(0);
    std.mem.writeInt(u64, header[0..8], pipable.blob_magic, .little);
    std.mem.writeInt(u64, header[8..16], payload.len, .little);
    std.crypto.hash.Sha1.hash(payload, header[16..36], .{});
    std.mem.writeInt(u32, header[36..40], flags, .little);
    try output.appendSlice(allocator, &header);
    try output.appendSlice(allocator, payload);
}

test "WIM pipable stream exports opaque EFSRPC raw data explicitly" {
    const allocator = std.testing.allocator;
    const fixture = try fixtureAlloc(
        allocator,
        @embedFile("testdata/pipable-xpress.wim.b64"),
    );
    defer allocator.free(fixture);
    const archive = try archive_mod.Archive.init(fixture);
    var image = try archive.readImageMetadataAlloc(allocator, 1, .{
        .max_metadata_bytes = 4096,
        .max_lookup_entries = 16,
        .max_lookup_bytes = 4096,
        .max_directory_entries = 16,
        .max_path_depth = 8,
    });
    defer image.deinit();
    const dentry = try image.lookup(allocator, "/nested/payload.txt", 16, 8);
    const raw = "opaque MS-EFSR raw stream";
    var raw_hash: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash(raw, &raw_hash, .{});
    std.mem.writeInt(
        u32,
        image.bytes[dentry.offset + 8 ..][0..4],
        dentry.attributes | metadata.file_attribute_encrypted,
        .little,
    );
    @memcpy(image.bytes[dentry.offset + 64 ..][0..20], &raw_hash);

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try encoded.appendSlice(allocator, fixture[0..format.header_size]);
    try appendUncompressedBlob(allocator, &encoded, "<WIM/>", 0x02);
    try appendUncompressedBlob(allocator, &encoded, image.bytes, 0x02);
    try appendUncompressedBlob(allocator, &encoded, raw, 0);

    var extractor = PathExtractor.init(allocator, .{
        .path = "/nested/payload.txt",
        .stream = .encrypted_raw,
        .max_output_len = 1024,
    });
    defer extractor.deinit();
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    var scratch: [2]u8 = undefined;
    var input_offset: usize = 0;
    while (true) {
        const input_end = @min(encoded.items.len, input_offset + 1);
        const stepped = try extractor.step(
            encoded.items[input_offset..input_end],
            &scratch,
        );
        input_offset += stepped.progress.input_read;
        try output.appendSlice(allocator, scratch[0..stepped.progress.output_written]);
        if (stepped.status == .done) break;
    }
    try std.testing.expectEqualStrings(raw, output.items);

    var plaintext = PathExtractor.init(allocator, .{
        .path = "/nested/payload.txt",
        .max_output_len = 1024,
    });
    defer plaintext.deinit();
    try std.testing.expectError(
        error.UnsupportedWimFile,
        plaintext.step(encoded.items, &scratch),
    );
}
