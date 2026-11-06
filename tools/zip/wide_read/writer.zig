const std = @import("std");
const h = @import("common.zig");
const zip = h.zip;
const Crc = @FieldType(zip.IncrementalEntryDecoder, "crc");

pub fn archive(init: std.process.Init, path: []const u8, count: u64, method: zip.CompressionMethod) !struct { input_read: u64, output_written: u64, crc32: u32, calls: u64, completed: bool, metadata: @import("reader.zig").Metadata } {
    var writer = try zip.IncrementalWriter.initWithOptions(init.gpa, .{
        .zip64 = .always,
        .max_uncompressed_size = count,
        .deflate64_options = .{ .max_input_len = count, .block_len = h.chunk_len, .compression = .fixed, .max_chain = 8 },
        .deflate_options = .{ .max_input_len = count, .block_len = h.chunk_len, .compression = .{ .parser = .hash } },
        .zstd_options = .{ .window_log = 16, .block_size_max = h.chunk_len, .selection = .raw_or_rle, .content_checksum = true },
    });
    defer writer.deinit();
    try writer.beginEntry(.{ .name = "wide.bin", .method = method, .expected_size = count });
    const file = try std.Io.Dir.cwd().createFile(init.io, path, .{});
    defer file.close(init.io);
    var file_buffer: [h.chunk_len]u8 = undefined;
    var sink = file.writerStreaming(init.io, &file_buffer);
    var output: [h.chunk_len]u8 = undefined;
    var accepted: u64 = 0;
    var published: u64 = 0;
    var calls: u64 = 0;
    var crc = Crc.init();
    while (accepted < count) {
        const len: usize = @intCast(@min(count - accepted, h.chunk_len));
        const before = writer.snapshot();
        const result = try writer.step(h.repeated[0..len], &output);
        accepted += result.progress.input_read;
        published += result.progress.output_written;
        calls += 1;
        crc.update(h.repeated[0..result.progress.input_read]);
        try sink.interface.writeAll(output[0..result.progress.output_written]);
        try h.require(writer.snapshot().input_read == before.input_read + result.progress.input_read and writer.snapshot().output_written == before.output_written + result.progress.output_written);
        try h.require(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
    try writer.finishEntry();
    while (writer.snapshot().phase != .ready) {
        const result = try writer.step(&.{}, &output);
        published += result.progress.output_written;
        calls += 1;
        try sink.interface.writeAll(output[0..result.progress.output_written]);
        try h.require(result.progress.output_written != 0 or writer.snapshot().phase == .ready);
    }
    try writer.finishArchive();
    while (writer.snapshot().phase != .done) {
        const result = try writer.step(&.{}, &output);
        published += result.progress.output_written;
        calls += 1;
        try sink.interface.writeAll(output[0..result.progress.output_written]);
        try h.require(result.progress.output_written != 0 or result.status == .done);
    }
    try sink.interface.flush();
    try h.require(accepted == count and writer.snapshot().input_read == count and writer.snapshot().output_written == published);
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
    defer init.gpa.free(bytes);
    const parsed = try zip.parse(bytes);
    const entry = try parsed.entryAt(0);
    try h.require(entry.method == method and entry.uncompressed_size == count and entry.crc32 == crc.digest() and entry.compressed_size < count);
    const data = try parsed.compressedData(entry);
    if (method == .deflate64) try h.require((data[0] >> 1) & 3 == 1);
    return .{ .input_read = accepted, .output_written = published, .crc32 = crc.digest(), .calls = calls, .completed = true, .metadata = .{ .method = entry.method, .compressed_size = @intCast(entry.compressed_size), .uncompressed_size = entry.uncompressed_size, .crc32 = entry.crc32, .metadata_count_bits = @bitSizeOf(@TypeOf(entry.uncompressed_size)), .zip64 = entry.zip64, .canonical_parse = true } };
}
