const std = @import("std");
const core = @import("core.zig");
const snappy = @import("snappy.zig");
const incremental_decoder = @import("snappy_framing/incremental_decoder.zig");

pub const Error = core.Error || snappy.Error || std.mem.Allocator.Error || error{
    InvalidXerialSnappyStream,
    InvalidHadoopSnappyStream,
};

pub const xerial_magic = [_]u8{ 0x82, 'S', 'N', 'A', 'P', 'P', 'Y', 0 };
pub const xerial_header = xerial_magic ++ [_]u8{ 0, 0, 0, 1, 0, 0, 0, 1 };

const IncrementalCodec = struct {
    pub const Error = snappy_framing.Error;
    pub const xerial_header = snappy_framing.xerial_header;

    pub fn decodedBlockSize(input: []const u8) snappy_framing.Error!usize {
        return snappy.decodedBlockSize(input);
    }

    pub fn decodeBlockIntoExactSize(input: []const u8, output: []u8, expected_output_len: usize) snappy_framing.Error!usize {
        return snappy.decodeBlockIntoExactSize(input, output, expected_output_len);
    }
};

const snappy_framing = @This();
pub const XerialIncrementalDecoder = incremental_decoder.Decoder(IncrementalCodec, .xerial);
pub const HadoopIncrementalDecoder = incremental_decoder.Decoder(IncrementalCodec, .hadoop);

pub const XerialOptions = struct {
    block_size: usize = 32 * 1024,
};

pub const HadoopOptions = struct {
    block_size: usize = 256 * 1024,
    chunk_size: usize = 64 * 1024,
};

pub const XerialChunk = struct {
    offset: usize,
    data_offset: usize,
    compressed_size: usize,
    uncompressed_size: usize,
    next_offset: usize,
};

pub const XerialArchive = struct {
    bytes: []const u8,
    chunk_count: usize,
    decoded_size: usize,

    pub fn iterator(self: XerialArchive) XerialIterator {
        return .{ .archive = self };
    }
};

pub const XerialIterator = struct {
    archive: XerialArchive,
    offset: usize = xerial_header.len,

    pub fn next(self: *XerialIterator) Error!?XerialChunk {
        if (self.offset == self.archive.bytes.len) return null;
        const chunk = try parseXerialChunk(self.archive.bytes, self.offset);
        self.offset = chunk.next_offset;
        return chunk;
    }
};

pub const HadoopChunk = struct {
    offset: usize,
    data_offset: usize,
    compressed_size: usize,
    uncompressed_size: usize,
    next_offset: usize,
};

pub const HadoopBlock = struct {
    offset: usize,
    uncompressed_size: usize,
    chunk_count: usize,
    next_offset: usize,
};

pub const HadoopArchive = struct {
    bytes: []const u8,
    block_count: usize,
    chunk_count: usize,
    decoded_size: usize,
};

pub fn parseXerial(input: []const u8) Error!XerialArchive {
    if (input.len < xerial_header.len or
        !std.mem.eql(u8, input[0..xerial_header.len], &xerial_header))
        return error.InvalidMagic;
    var offset: usize = xerial_header.len;
    var chunk_count: usize = 0;
    var decoded_size: usize = 0;
    while (offset < input.len) {
        const chunk = try parseXerialChunk(input, offset);
        chunk_count = std.math.add(usize, chunk_count, 1) catch
            return error.IntegerOverflow;
        decoded_size = std.math.add(usize, decoded_size, chunk.uncompressed_size) catch
            return error.IntegerOverflow;
        offset = chunk.next_offset;
    }
    return .{ .bytes = input, .chunk_count = chunk_count, .decoded_size = decoded_size };
}

pub fn parseXerialChunk(input: []const u8, offset: usize) Error!XerialChunk {
    const data_offset = try checkedEnd(offset, 4, input.len);
    const compressed_size: usize = std.mem.readInt(u32, input[offset..][0..4], .big);
    if (compressed_size == 0) return error.InvalidXerialSnappyStream;
    const next_offset = try checkedEnd(data_offset, compressed_size, input.len);
    const uncompressed_size = try snappy.decodedBlockSize(input[data_offset..next_offset]);
    return .{
        .offset = offset,
        .data_offset = data_offset,
        .compressed_size = compressed_size,
        .uncompressed_size = uncompressed_size,
        .next_offset = next_offset,
    };
}

pub fn encodeXerialAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: XerialOptions,
) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeXerialAppend(allocator, &output, input, options);
    return output.toOwnedSlice(allocator);
}

pub fn encodeXerialAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    options: XerialOptions,
) !usize {
    if (options.block_size == 0 or options.block_size > std.math.maxInt(u32))
        return error.InvalidXerialSnappyStream;
    const start = output.items.len;
    errdefer output.items.len = start;
    try output.appendSlice(allocator, &xerial_header);
    var encoder = snappy.Encoder.init(allocator);
    defer encoder.deinit();
    var position: usize = 0;
    while (position < input.len) {
        const length = @min(options.block_size, input.len - position);
        const compressed = try encoder.encodeBlockAlloc(input[position..][0..length]);
        defer allocator.free(compressed);
        try appendBe32(allocator, output, std.math.cast(u32, compressed.len) orelse
            return error.IntegerOverflow);
        try output.appendSlice(allocator, compressed);
        position += length;
    }
    return output.items.len - start;
}

pub fn decodeXerialAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
) ![]u8 {
    return decodeXerialAllocLimited(allocator, input, std.math.maxInt(usize));
}

pub fn decodeXerialAllocLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    max_output_len: usize,
) ![]u8 {
    const archive = try parseXerial(input);
    if (archive.decoded_size > max_output_len) return error.OutputLimitExceeded;
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.ensureTotalCapacity(allocator, archive.decoded_size);
    var iterator_value = archive.iterator();
    while (try iterator_value.next()) |chunk| {
        _ = try snappy.decodeBlockAppendExactSize(
            allocator,
            &output,
            input[chunk.data_offset..][0..chunk.compressed_size],
            chunk.uncompressed_size,
        );
    }
    return output.toOwnedSlice(allocator);
}

pub fn decodeXerialInto(input: []const u8, output: []u8) !usize {
    const archive = try parseXerial(input);
    if (output.len < archive.decoded_size) return error.OutputTooSmall;
    var output_offset: usize = 0;
    var iterator_value = archive.iterator();
    while (try iterator_value.next()) |chunk| {
        _ = try snappy.decodeBlockIntoExactSize(
            input[chunk.data_offset..][0..chunk.compressed_size],
            output[output_offset..][0..chunk.uncompressed_size],
            chunk.uncompressed_size,
        );
        output_offset += chunk.uncompressed_size;
    }
    return output_offset;
}

pub fn encodeXerialInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: XerialOptions,
    output: []u8,
) !usize {
    const encoded = try encodeXerialAlloc(allocator, input, options);
    defer allocator.free(encoded);
    if (output.len < encoded.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

pub fn parseHadoop(input: []const u8) Error!HadoopArchive {
    var offset: usize = 0;
    var block_count: usize = 0;
    var chunk_count: usize = 0;
    var decoded_size: usize = 0;
    while (offset < input.len) {
        const block = try parseHadoopBlock(input, offset);
        block_count = std.math.add(usize, block_count, 1) catch
            return error.IntegerOverflow;
        chunk_count = std.math.add(usize, chunk_count, block.chunk_count) catch
            return error.IntegerOverflow;
        decoded_size = std.math.add(usize, decoded_size, block.uncompressed_size) catch
            return error.IntegerOverflow;
        offset = block.next_offset;
    }
    return .{
        .bytes = input,
        .block_count = block_count,
        .chunk_count = chunk_count,
        .decoded_size = decoded_size,
    };
}

pub fn parseHadoopBlock(input: []const u8, offset: usize) Error!HadoopBlock {
    var position = try checkedEnd(offset, 4, input.len);
    const expected_size: usize = std.mem.readInt(u32, input[offset..][0..4], .big);
    if (expected_size == 0) return error.InvalidHadoopSnappyStream;
    var decoded_size: usize = 0;
    var chunk_count: usize = 0;
    while (decoded_size < expected_size) {
        const data_offset = try checkedEnd(position, 4, input.len);
        const compressed_size: usize = std.mem.readInt(u32, input[position..][0..4], .big);
        if (compressed_size == 0) return error.InvalidHadoopSnappyStream;
        const next_offset = try checkedEnd(data_offset, compressed_size, input.len);
        const chunk_size = try snappy.decodedBlockSize(input[data_offset..next_offset]);
        const next_decoded = std.math.add(usize, decoded_size, chunk_size) catch
            return error.IntegerOverflow;
        if (next_decoded > expected_size)
            return error.InvalidHadoopSnappyStream;
        decoded_size = next_decoded;
        chunk_count = std.math.add(usize, chunk_count, 1) catch
            return error.IntegerOverflow;
        position = next_offset;
    }
    if (decoded_size != expected_size) return error.InvalidHadoopSnappyStream;
    return .{
        .offset = offset,
        .uncompressed_size = expected_size,
        .chunk_count = chunk_count,
        .next_offset = position,
    };
}

pub fn encodeHadoopAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: HadoopOptions,
) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeHadoopAppend(allocator, &output, input, options);
    return output.toOwnedSlice(allocator);
}

pub fn encodeHadoopAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    options: HadoopOptions,
) !usize {
    if (options.block_size == 0 or options.chunk_size == 0 or
        options.block_size > std.math.maxInt(u32) or
        options.chunk_size > std.math.maxInt(u32))
        return error.InvalidHadoopSnappyStream;
    const start = output.items.len;
    errdefer output.items.len = start;
    var encoder = snappy.Encoder.init(allocator);
    defer encoder.deinit();
    var block_start: usize = 0;
    while (block_start < input.len) {
        const block_len = @min(options.block_size, input.len - block_start);
        try appendBe32(allocator, output, @intCast(block_len));
        var chunk_start: usize = 0;
        while (chunk_start < block_len) {
            const chunk_len = @min(options.chunk_size, block_len - chunk_start);
            const plain = input[block_start + chunk_start ..][0..chunk_len];
            const compressed = try encoder.encodeBlockAlloc(plain);
            defer allocator.free(compressed);
            try appendBe32(allocator, output, std.math.cast(u32, compressed.len) orelse
                return error.IntegerOverflow);
            try output.appendSlice(allocator, compressed);
            chunk_start += chunk_len;
        }
        block_start += block_len;
    }
    return output.items.len - start;
}

pub fn decodeHadoopAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
) ![]u8 {
    return decodeHadoopAllocLimited(allocator, input, std.math.maxInt(usize));
}

pub fn decodeHadoopAllocLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    max_output_len: usize,
) ![]u8 {
    const archive = try parseHadoop(input);
    if (archive.decoded_size > max_output_len) return error.OutputLimitExceeded;
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.ensureTotalCapacity(allocator, archive.decoded_size);
    var position: usize = 0;
    while (position < input.len) {
        const expected_size: usize = std.mem.readInt(u32, input[position..][0..4], .big);
        position += 4;
        const block_end = std.math.add(usize, output.items.len, expected_size) catch
            return error.IntegerOverflow;
        while (output.items.len < block_end) {
            const compressed_size: usize = std.mem.readInt(u32, input[position..][0..4], .big);
            position += 4;
            _ = try snappy.decodeBlockAppendLimited(
                allocator,
                &output,
                input[position..][0..compressed_size],
                block_end - output.items.len,
            );
            position += compressed_size;
        }
        if (output.items.len != block_end) return error.InvalidHadoopSnappyStream;
    }
    return output.toOwnedSlice(allocator);
}

pub fn decodeHadoopInto(input: []const u8, output: []u8) !usize {
    const archive = try parseHadoop(input);
    if (output.len < archive.decoded_size) return error.OutputTooSmall;
    var position: usize = 0;
    var output_offset: usize = 0;
    while (position < input.len) {
        const expected_size: usize = std.mem.readInt(u32, input[position..][0..4], .big);
        position += 4;
        const block_end = std.math.add(usize, output_offset, expected_size) catch
            return error.IntegerOverflow;
        while (output_offset < block_end) {
            const compressed_size: usize = std.mem.readInt(u32, input[position..][0..4], .big);
            position += 4;
            const chunk_size = try snappy.decodedBlockSize(input[position..][0..compressed_size]);
            if (chunk_size > block_end - output_offset) return error.InvalidHadoopSnappyStream;
            _ = try snappy.decodeBlockIntoExactSize(
                input[position..][0..compressed_size],
                output[output_offset..][0..chunk_size],
                chunk_size,
            );
            position += compressed_size;
            output_offset += chunk_size;
        }
    }
    return output_offset;
}

pub fn encodeHadoopInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: HadoopOptions,
    output: []u8,
) !usize {
    const encoded = try encodeHadoopAlloc(allocator, input, options);
    defer allocator.free(encoded);
    if (output.len < encoded.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

fn appendBe32(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: u32,
) Error!void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .big);
    try output.appendSlice(allocator, &bytes);
}

fn checkedEnd(start: usize, size: usize, limit: usize) Error!usize {
    const end = std.math.add(usize, start, size) catch return error.IntegerOverflow;
    if (end > limit) return error.TruncatedFrame;
    return end;
}

fn expectIncrementalDecode(
    comptime DecoderType: type,
    encoded: []const u8,
    expected: []const u8,
    input_step: usize,
    output_step: usize,
) !DecoderType.Snapshot {
    return expectIncrementalDecodeWithAllocator(
        DecoderType,
        std.testing.allocator,
        encoded,
        expected,
        input_step,
        output_step,
    );
}

fn expectIncrementalDecodeWithAllocator(
    comptime DecoderType: type,
    allocator: std.mem.Allocator,
    encoded: []const u8,
    expected: []const u8,
    input_step: usize,
    output_step: usize,
) !DecoderType.Snapshot {
    std.debug.assert(input_step != 0 and output_step != 0);
    var decoder = DecoderType.initWithOptions(allocator, .{
        .max_compressed_chunk_len = 1024 * 1024,
        .max_decoded_chunk_len = 1024 * 1024,
        .max_output_len = expected.len,
        .expected_output_len = expected.len,
    });
    defer decoder.deinit();
    const output = try allocator.alloc(u8, expected.len);
    defer allocator.free(output);
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (input_offset < encoded.len) {
        const input_end = @min(encoded.len, input_offset + input_step);
        const output_end = @min(output.len, output_offset + output_step);
        const step = try decoder.step(encoded[input_offset..input_end], output[output_offset..output_end]);
        try std.testing.expect(step.progress.input_read != 0 or step.progress.output_written != 0);
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
    }
    try decoder.finish();
    while (decoder.snapshot().phase != .done) {
        const output_end = @min(output.len, output_offset + output_step);
        const step = try decoder.step("", output[output_offset..output_end]);
        try std.testing.expect(step.progress.output_written != 0 or step.status == .done);
        output_offset += step.progress.output_written;
    }
    try std.testing.expectEqual(encoded.len, input_offset);
    try std.testing.expectEqual(expected.len, output_offset);
    try std.testing.expectEqualSlices(u8, expected, output);
    return decoder.snapshot();
}

test "Xerial Snappy writer round trips multiple independent blocks" {
    const allocator = std.testing.allocator;
    const input = "Xerial Snappy payload alpha beta gamma\n" ** 4096;
    const encoded = try encodeXerialAlloc(allocator, input, .{ .block_size = 4096 });
    defer allocator.free(encoded);
    const archive = try parseXerial(encoded);
    try std.testing.expect(archive.chunk_count > 1);
    const decoded = try decodeXerialAlloc(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "Hadoop Snappy writer round trips nested blocks and chunks" {
    const allocator = std.testing.allocator;
    const input = "Hadoop Snappy payload alpha beta gamma\n" ** 8192;
    const encoded = try encodeHadoopAlloc(allocator, input, .{
        .block_size = 32 * 1024,
        .chunk_size = 4096,
    });
    defer allocator.free(encoded);
    const archive = try parseHadoop(encoded);
    try std.testing.expect(archive.block_count > 1);
    try std.testing.expect(archive.chunk_count > archive.block_count);
    const decoded = try decodeHadoopAlloc(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "Xerial Snappy incremental decoder accepts fragmented input and output" {
    const allocator = std.testing.allocator;
    const input = "Xerial incremental payload alpha beta gamma\n" ** 1024;
    const encoded = try encodeXerialAlloc(allocator, input, .{ .block_size = 4096 });
    defer allocator.free(encoded);
    const archive = try parseXerial(encoded);
    const snapshot = try expectIncrementalDecode(XerialIncrementalDecoder, encoded, input, 3, 7);
    try std.testing.expectEqual(archive.chunk_count, snapshot.chunk_count);
    try std.testing.expectEqual(archive.chunk_count, snapshot.block_count);
    try std.testing.expectEqual(input.len, snapshot.output_written);
    try std.testing.expect(snapshot.retained_compressed_capacity <= 1024 * 1024);
    try std.testing.expect(snapshot.retained_decoded_capacity <= 1024 * 1024);
}

test "Hadoop Snappy incremental decoder accepts nested fragmented chunks" {
    const allocator = std.testing.allocator;
    const input = "Hadoop incremental payload alpha beta gamma\n" ** 2048;
    const encoded = try encodeHadoopAlloc(allocator, input, .{
        .block_size = 16 * 1024,
        .chunk_size = 2048,
    });
    defer allocator.free(encoded);
    const archive = try parseHadoop(encoded);
    const snapshot = try expectIncrementalDecode(HadoopIncrementalDecoder, encoded, input, 5, 11);
    try std.testing.expectEqual(archive.block_count, snapshot.block_count);
    try std.testing.expectEqual(archive.chunk_count, snapshot.chunk_count);
    try std.testing.expectEqual(input.len, snapshot.output_written);
    try std.testing.expectEqual(@as(usize, 0), snapshot.hadoop_block_expected);
    try std.testing.expectEqual(@as(usize, 0), snapshot.hadoop_block_decoded);
}

test "Snappy ecosystem incremental decoders handle backpressure reset and limits" {
    const allocator = std.testing.allocator;
    const payload = "incremental backpressure payload" ** 32;
    const xerial = try encodeXerialAlloc(allocator, payload, .{ .block_size = payload.len });
    defer allocator.free(xerial);

    var xerial_decoder = XerialIncrementalDecoder.initWithOptions(allocator, .{
        .max_compressed_chunk_len = xerial.len,
        .max_decoded_chunk_len = payload.len,
        .expected_output_len = payload.len,
    });
    defer xerial_decoder.deinit();
    const blocked = try xerial_decoder.step(xerial, &.{});
    try std.testing.expectEqual(core.StepResult.Status.need_output, blocked.status);
    try std.testing.expectEqual(xerial.len, blocked.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), blocked.progress.output_written);
    try xerial_decoder.finish();
    var xerial_output: [payload.len]u8 = undefined;
    const drained = try xerial_decoder.step("", &xerial_output);
    try std.testing.expectEqual(core.StepResult.Status.done, drained.status);
    try std.testing.expectEqualSlices(u8, payload, &xerial_output);
    const retained = xerial_decoder.snapshot();
    xerial_decoder.reset();
    try std.testing.expectEqual(XerialIncrementalDecoder.Phase.stream_header, xerial_decoder.snapshot().phase);
    try std.testing.expectEqual(retained.retained_compressed_capacity, xerial_decoder.snapshot().retained_compressed_capacity);
    try std.testing.expectEqual(retained.retained_decoded_capacity, xerial_decoder.snapshot().retained_decoded_capacity);

    var compressed_limited = XerialIncrementalDecoder.initWithOptions(allocator, .{ .max_compressed_chunk_len = 1 });
    defer compressed_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, compressed_limited.step(xerial, &.{}));
    try std.testing.expectEqualStrings("OutputLimitExceeded", compressed_limited.diagnostics().last_error_name);

    var decoded_limited = XerialIncrementalDecoder.initWithOptions(allocator, .{ .max_decoded_chunk_len = payload.len - 1 });
    defer decoded_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, decoded_limited.step(xerial, &.{}));

    const hadoop = try encodeHadoopAlloc(allocator, payload, .{ .block_size = payload.len, .chunk_size = payload.len });
    defer allocator.free(hadoop);
    var hadoop_limited = HadoopIncrementalDecoder.initWithOptions(allocator, .{ .max_output_len = payload.len - 1 });
    defer hadoop_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, hadoop_limited.step(hadoop, &.{}));
}

test "Snappy ecosystem incremental decoders reject truncation and size mismatch" {
    const allocator = std.testing.allocator;
    const payload = "truncation payload" ** 16;
    const xerial = try encodeXerialAlloc(allocator, payload, .{});
    defer allocator.free(xerial);
    var xerial_decoder = XerialIncrementalDecoder.init(allocator);
    defer xerial_decoder.deinit();
    _ = try xerial_decoder.step(xerial[0 .. xerial.len - 1], &.{});
    try std.testing.expectError(error.TruncatedFrame, xerial_decoder.finish());
    try std.testing.expectEqualStrings("truncated_input", xerial_decoder.diagnostics().recoverability_hint_name);

    var bad_magic = XerialIncrementalDecoder.init(allocator);
    defer bad_magic.deinit();
    var corrupt_header = xerial_header;
    corrupt_header[0] ^= 1;
    try std.testing.expectError(error.InvalidMagic, bad_magic.step(&corrupt_header, &.{}));

    const hadoop = try encodeHadoopAlloc(allocator, payload, .{ .block_size = payload.len, .chunk_size = 64 });
    defer allocator.free(hadoop);
    var hadoop_decoder = HadoopIncrementalDecoder.init(allocator);
    defer hadoop_decoder.deinit();
    var output: [payload.len]u8 = undefined;
    _ = try hadoop_decoder.step(hadoop[0 .. hadoop.len - 1], &output);
    try std.testing.expectError(error.TruncatedFrame, hadoop_decoder.finish());

    const bad_outer = try allocator.dupe(u8, hadoop);
    defer allocator.free(bad_outer);
    std.mem.writeInt(u32, bad_outer[0..4], payload.len - 1, .big);
    var outer_mismatch = HadoopIncrementalDecoder.init(allocator);
    defer outer_mismatch.deinit();
    try std.testing.expectError(error.InvalidHadoopSnappyStream, outer_mismatch.step(bad_outer, &output));

    var size_mismatch = HadoopIncrementalDecoder.initWithOptions(allocator, .{ .expected_output_len = payload.len + 1 });
    defer size_mismatch.deinit();
    const step = try size_mismatch.step(hadoop, &output);
    try std.testing.expectEqual(hadoop.len, step.progress.input_read);
    try std.testing.expectError(error.SizeMismatch, size_mismatch.finish());
}

test "Snappy ecosystem incremental decoders accept empty streams" {
    const allocator = std.testing.allocator;
    var xerial_decoder = XerialIncrementalDecoder.initWithOptions(allocator, .{ .expected_output_len = 0 });
    defer xerial_decoder.deinit();
    const xerial_step = try xerial_decoder.step(&xerial_header, &.{});
    try std.testing.expectEqual(xerial_header.len, xerial_step.progress.input_read);
    try xerial_decoder.finish();
    try std.testing.expectEqual(XerialIncrementalDecoder.Phase.done, xerial_decoder.snapshot().phase);
    try std.testing.expectError(error.TrailingData, xerial_decoder.step("x", &.{}));

    var hadoop_decoder = HadoopIncrementalDecoder.initWithOptions(allocator, .{ .expected_output_len = 0 });
    defer hadoop_decoder.deinit();
    try hadoop_decoder.finish();
    try std.testing.expectEqual(HadoopIncrementalDecoder.Phase.done, hadoop_decoder.snapshot().phase);
}

test "Snappy ecosystem incremental decoders clean up allocation failures" {
    const allocator = std.testing.allocator;
    const xerial_payload = "xerial allocation failure payload" ** 32;
    const xerial = try encodeXerialAlloc(allocator, xerial_payload, .{ .block_size = 256 });
    defer allocator.free(xerial);
    const HadoopTest = struct {
        fn run(active: std.mem.Allocator, encoded: []const u8, expected: []const u8) !void {
            _ = try expectIncrementalDecodeWithAllocator(
                HadoopIncrementalDecoder,
                active,
                encoded,
                expected,
                encoded.len,
                13,
            );
        }
    };
    const XerialTest = struct {
        fn run(active: std.mem.Allocator, encoded: []const u8, expected: []const u8) !void {
            _ = try expectIncrementalDecodeWithAllocator(
                XerialIncrementalDecoder,
                active,
                encoded,
                expected,
                encoded.len,
                13,
            );
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, XerialTest.run, .{ xerial, xerial_payload });

    const hadoop_payload = "hadoop allocation failure payload" ** 32;
    const hadoop = try encodeHadoopAlloc(allocator, hadoop_payload, .{ .block_size = 512, .chunk_size = 128 });
    defer allocator.free(hadoop);
    try std.testing.checkAllAllocationFailures(allocator, HadoopTest.run, .{ hadoop, hadoop_payload });
}

test "Snappy framing rejects bad magic truncation and output limits" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.InvalidMagic, parseXerial(""));
    const xerial = try encodeXerialAlloc(allocator, "payload", .{});
    defer allocator.free(xerial);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        decodeXerialAllocLimited(allocator, xerial, 6),
    );
    try std.testing.expectError(error.TruncatedFrame, parseXerial(xerial[0 .. xerial.len - 1]));
    const hadoop = try encodeHadoopAlloc(allocator, "payload", .{});
    defer allocator.free(hadoop);
    try std.testing.expectError(error.TruncatedFrame, parseHadoop(hadoop[0 .. hadoop.len - 1]));
}
