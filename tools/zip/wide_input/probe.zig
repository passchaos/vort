//! Real ZIP64 wide-input receipts. Reuse one 64 KiB plaintext chunk, publish
//! archive bytes directly to a file, and never seed the writer's counters.
const std = @import("std");
const builtin = @import("builtin");
const codec = @import("codec");

const chunk_len = 64 * 1024;
const repeated: [chunk_len]u8 = @splat('R');
const Format = enum { deflate, zstd };
const Config = struct { format: Format, count: u64, output: []const u8 };
const Receipt = struct {
    schema: []const u8 = "vort.zip.wide-input.v1",
    format: Format,
    pointer_bits: usize = @bitSizeOf(usize),
    stream_count_bits: usize = @bitSizeOf(@FieldType(codec.IncrementalWriter.Snapshot, "input_read")),
    progress_bits: usize = @bitSizeOf(usize),
    count: u64,
    input_read: u64 = 0,
    output_written: u64 = 0,
    compressed_size: u64 = 0,
    uncompressed_size: u64 = 0,
    crc32: u32 = 0,
    completed: bool = false,
    input_chunk_bytes: usize = chunk_len,
    output_chunk_bytes: usize = chunk_len,
    calls: u64 = 0,
    entry_count: u64 = 0,
    zip64: bool = false,
    build_mode: []const u8 = @tagName(builtin.mode),
    target_arch: []const u8 = @tagName(builtin.cpu.arch),
    target_os: []const u8 = @tagName(builtin.os.tag),
    all_input_bytes_submitted: bool = false,
    crc: std.hash.Crc32 = std.hash.Crc32.init(),
};

pub fn main(init: std.process.Init) !void {
    const config = try readConfig(init);
    defer init.gpa.free(config.output);
    var settings: codec.IncrementalWriterOptions = .{
        .zip64 = .always,
        .deflate_options = .{
            .max_input_len = config.count,
            .block_len = chunk_len,
            .compression = .{ .parser = .hash },
        },
        .zstd_options = .{
            .window_log = 16,
            .block_size_max = chunk_len,
            .selection = .raw_or_rle,
            .content_checksum = true,
        },
    };
    // A wide codec limit is intentional even on x86. Archive accounting and
    // pledge enforcement must independently observe every accepted byte.
    settings.max_uncompressed_size = config.count;
    var writer = try codec.IncrementalWriter.initWithOptions(init.gpa, settings);
    defer writer.deinit();
    const file = try std.Io.Dir.cwd().createFile(init.io, config.output, .{ .read = true });
    defer file.close(init.io);
    const method: codec.CompressionMethod = if (config.format == .deflate) .deflate else .zstandard;
    try writer.beginEntry(.{ .name = "wide.bin", .method = method, .expected_size = config.count });
    var receipt: Receipt = .{ .format = config.format, .count = config.count };
    var output: [chunk_len]u8 = undefined;
    while (receipt.input_read < config.count) {
        const offered_len: usize = @intCast(@min(config.count - receipt.input_read, repeated.len));
        try emit(init.io, file, &writer, repeated[0..offered_len], &output, &receipt);
    }
    receipt.all_input_bytes_submitted = receipt.input_read == config.count;
    try writer.finishEntry();
    while (writer.snapshot().phase != .ready)
        try emit(init.io, file, &writer, "", &output, &receipt);
    try writer.finishArchive();
    while (!receipt.completed)
        try emit(init.io, file, &writer, "", &output, &receipt);

    if (writer.snapshot().input_read != config.count or writer.snapshot().entry_count != 1)
        return error.WrongWriterReceipt;
    if (try file.length(init.io) != receipt.output_written) return error.WrongFileLength;
    receipt.crc32 = receipt.crc.final();

    // The one-shot ZIP reader validates whether complete plaintext can fit a
    // local slice. A wide streaming writer needs no such materialization.
    // Read only its small ZIP64 central record here; Python independently
    // checks all archive records and decodes the complete raw member.
    const metadata = try readMetadata(init.io, file, writer.final_central_offset, method, config.count, receipt.crc32);
    receipt.compressed_size = metadata.compressed_size;
    receipt.uncompressed_size = metadata.uncompressed_size;
    receipt.entry_count = writer.snapshot().entry_count;
    receipt.zip64 = writer.final_archive_zip64;
    if (!receipt.zip64) return error.WrongZipMetadata;
    var stdout_buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    try std.json.Stringify.value(.{
        .schema = receipt.schema,
        .format = receipt.format,
        .pointer_bits = receipt.pointer_bits,
        .stream_count_bits = receipt.stream_count_bits,
        .progress_bits = receipt.progress_bits,
        .count = receipt.count,
        .input_read = receipt.input_read,
        .output_written = receipt.output_written,
        .compressed_size = receipt.compressed_size,
        .uncompressed_size = receipt.uncompressed_size,
        .crc32 = receipt.crc32,
        .completed = receipt.completed,
        .input_chunk_bytes = receipt.input_chunk_bytes,
        .output_chunk_bytes = receipt.output_chunk_bytes,
        .calls = receipt.calls,
        .entry_count = receipt.entry_count,
        .zip64 = receipt.zip64,
        .build_mode = receipt.build_mode,
        .target_arch = receipt.target_arch,
        .target_os = receipt.target_os,
        .all_input_bytes_submitted = receipt.all_input_bytes_submitted,
        .plaintext_source = "reused 64 KiB all-R caller input; no seeded counters",
        .metadata_read_bytes = @as(usize, 82),
    }, .{}, &stdout.interface);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}

fn readMetadata(io: std.Io, file: std.Io.File, offset: u64, method: codec.CompressionMethod, count: u64, crc32: u32) !struct { compressed_size: u64, uncompressed_size: u64 } {
    // Fixed central header + "wide.bin" + ZIP64 sizes and local offset.
    var bytes: [46 + 8 + 28]u8 = undefined;
    if (try file.readPositionalAll(io, &bytes, offset) != bytes.len)
        return error.TruncatedZipMetadata;
    if (readInt(u32, &bytes, 0) != 0x02014b50 or
        readInt(u16, &bytes, 10) != @intFromEnum(method) or
        readInt(u32, &bytes, 16) != crc32 or
        readInt(u32, &bytes, 20) != std.math.maxInt(u32) or
        readInt(u32, &bytes, 24) != std.math.maxInt(u32) or
        readInt(u16, &bytes, 28) != 8 or readInt(u16, &bytes, 30) != 28 or
        readInt(u16, &bytes, 32) != 0 or
        readInt(u32, &bytes, 42) != std.math.maxInt(u32) or
        !std.mem.eql(u8, bytes[46..54], "wide.bin") or
        readInt(u16, &bytes, 54) != 1 or readInt(u16, &bytes, 56) != 24 or
        readInt(u64, &bytes, 58) != count or readInt(u64, &bytes, 74) != 0)
        return error.WrongZipMetadata;
    return .{ .compressed_size = readInt(u64, &bytes, 66), .uncompressed_size = readInt(u64, &bytes, 58) };
}

fn readInt(comptime T: type, bytes: []const u8, offset: usize) T {
    return std.mem.readInt(T, bytes[offset..][0..(@bitSizeOf(T) / 8)], .little);
}

fn emit(io: std.Io, file: std.Io.File, writer: *codec.IncrementalWriter, input: []const u8, output: []u8, receipt: *Receipt) !void {
    const before = writer.snapshot();
    const stepped = try writer.step(input, output);
    const progress = stepped.progress;
    receipt.progress_bits = @bitSizeOf(@TypeOf(progress.input_read));
    if (progress.input_read > input.len or progress.output_written > output.len)
        return error.InvalidProgress;
    if (progress.input_read == 0 and progress.output_written == 0 and stepped.status != .done)
        return error.NoProgress;
    receipt.crc.update(input[0..progress.input_read]);
    receipt.input_read = try std.math.add(u64, receipt.input_read, progress.input_read);
    receipt.output_written = try std.math.add(u64, receipt.output_written, progress.output_written);
    receipt.calls = try std.math.add(u64, receipt.calls, 1);
    const after = writer.snapshot();
    if (after.input_read != before.input_read + progress.input_read or
        after.output_written != before.output_written + progress.output_written or
        after.input_read != receipt.input_read or after.output_written != receipt.output_written)
        return error.SnapshotProgressMismatch;
    try file.writeStreamingAll(io, output[0..progress.output_written]);
    receipt.completed = stepped.status == .done;
}

fn readConfig(init: std.process.Init) !Config {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    var format: ?Format = null;
    var count: ?u64 = null;
    var output: ?[]const u8 = null;
    errdefer if (output) |owned| init.gpa.free(owned);
    while (args.next()) |flag| {
        const value = args.next() orelse return error.MissingArgumentValue;
        if (std.mem.eql(u8, flag, "--format")) {
            if (format != null) return error.DuplicateArgument;
            format = std.meta.stringToEnum(Format, value) orelse return error.InvalidFormat;
        } else if (std.mem.eql(u8, flag, "--count")) {
            if (count != null) return error.DuplicateArgument;
            count = try std.fmt.parseInt(u64, value, 10);
        } else if (std.mem.eql(u8, flag, "--output")) {
            if (output != null) return error.DuplicateArgument;
            output = try init.gpa.dupe(u8, value);
        } else return error.UnknownArgument;
    }
    return .{
        .format = format orelse return error.MissingFormat,
        .count = count orelse return error.MissingCount,
        .output = output orelse return error.MissingOutput,
    };
}
