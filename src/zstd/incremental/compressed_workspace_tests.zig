const std = @import("std");
const core = @import("../../core.zig");
const zstd = @import("../../zstd.zig");

const Decoder = zstd.NativeIncrementalFrameDecoder;
const required_len = Decoder.compressed_block_workspace_len;

fn compressedFrame(allocator: std.mem.Allocator, payload: []const u8) ![]u8 {
    const encoded = try zstd.encodeNativeFrameWithOptionsAlloc(allocator, payload, .{
        .selection = .fast_compressed,
        .block_size_max = 1024,
        .window_log = 10,
        .content_checksum = true,
        .include_content_size = false,
    });
    errdefer allocator.free(encoded.frame);
    const first = try zstd.inspectNativeFrameFirstBlock(encoded.frame);
    try std.testing.expectEqual(zstd.NativeBlockType.compressed, first.block_type);
    return encoded.frame;
}

fn maximumCompressedLiteralFrame(allocator: std.mem.Allocator, block_count: usize) !struct { frame: []u8, plain: []u8 } {
    const literal_len = required_len - 4;
    const plain = try allocator.alloc(u8, literal_len * block_count);
    errdefer allocator.free(plain);
    var random = std.Random.DefaultPrng.init(0xc011_a2ed);
    random.random().bytes(plain);
    var frame: std.ArrayList(u8) = .empty;
    errdefer frame.deinit(allocator);
    try frame.appendSlice(allocator, &.{ 0x28, 0xb5, 0x2f, 0xfd, 0, 0x38 });
    for (0..block_count) |index| {
        var block_header: [3]u8 = undefined;
        std.mem.writeInt(
            u24,
            &block_header,
            @intCast((required_len << 3) | 4 | @as(usize, @intFromBool(index + 1 == block_count))),
            .little,
        );
        try frame.appendSlice(allocator, &block_header);
        var literal_header: [3]u8 = undefined;
        std.mem.writeInt(u24, &literal_header, @intCast((literal_len << 4) | 12), .little);
        try frame.appendSlice(allocator, &literal_header);
        try frame.appendSlice(allocator, plain[index * literal_len ..][0..literal_len]);
        try frame.append(allocator, 0); // zero sequences
    }
    return .{ .frame = try frame.toOwnedSlice(allocator), .plain = plain };
}

fn drive(
    decoder: *Decoder,
    frame: []const u8,
    output: []u8,
    input_chunk: usize,
    output_chunk: usize,
) !void {
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const input_end = @min(frame.len, input_offset + input_chunk);
        const output_end = @min(output.len, output_offset + output_chunk);
        const result = try decoder.step(frame[input_offset..input_end], output[output_offset..output_end]);
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
        try std.testing.expect(result.progress.input_read != 0 or
            result.progress.output_written != 0 or result.status == .done);
    }
    try decoder.finish();
    try std.testing.expectEqual(frame.len, input_offset);
    try std.testing.expectEqual(output.len, output_offset);
}

fn driveStable(decoder: *Decoder, frame: []const u8, expected: []const u8) !void {
    var input_offset: usize = 0;
    var guard: usize = 0;
    while (decoder.snapshot().phase != .done) : (guard += 1) {
        if (guard > frame.len + expected.len + 1024) return error.TestUnexpectedResult;
        const input_end = @min(frame.len, input_offset + 1);
        const result = try decoder.stepStableLimited(frame[input_offset..input_end], 1);
        input_offset += result.progress.input_read;
        try std.testing.expect(result.progress.input_read != 0 or
            result.progress.output_written != 0 or result.status == .done);
    }
    try decoder.finish();
    try std.testing.expectEqual(frame.len, input_offset);
    try std.testing.expectEqualSlices(u8, expected, decoder.stableOutput());
}

test "Zstd compressed workspace validates size mode and aliases transactionally" {
    try std.testing.expectEqual(std.compress.zstd.block_size_max, Decoder.requiredCompressedBlockWorkspaceLen());
    var storage: [required_len + 17]u8 = @splat(0xa5);
    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    try std.testing.expectError(error.OutputTooSmall, decoder.bindCompressedBlockWorkspace(storage[0 .. required_len - 1]));
    try std.testing.expect(!decoder.usesCompressedBlockWorkspace());
    try decoder.bindCompressedBlockWorkspace(storage[1 .. required_len + 1]);
    try std.testing.expect(decoder.usesCompressedBlockWorkspace());
    try std.testing.expectEqual(required_len, decoder.compressedBufferCapacity());
    for (storage[required_len + 1 ..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);

    try std.testing.expectError(error.InvalidBlockPlan, decoder.resetWithOptions(.{ .input_policy = .prevalidated_frame }));
    try std.testing.expect(decoder.usesCompressedBlockWorkspace());
    try std.testing.expectEqual(core.CompressedInputPolicy.block_stream, decoder.options.input_policy);

    const payload = "workspace alias guard" ** 16;
    const frame = try compressedFrame(std.testing.allocator, payload);
    defer std.testing.allocator.free(frame);
    @memcpy(storage[1..][0..frame.len], frame);
    var output: [payload.len]u8 = undefined;
    const before = decoder.snapshot();
    try std.testing.expectError(error.InvalidBlockPlan, decoder.step(storage[1..][0..frame.len], &output));
    try std.testing.expectEqual(before.input_received, decoder.snapshot().input_received);
    try std.testing.expectError(error.InvalidBlockPlan, decoder.step(frame, storage[1..][0..payload.len]));
    try std.testing.expectError(error.InvalidBlockPlan, decoder.bindStableOutput(storage[1..][0..payload.len]));

    decoder.reset();
    try drive(&decoder, frame, &output, 5, 11);
    try std.testing.expectEqualSlices(u8, payload, &output);
    for (storage[required_len + 1 ..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    decoder.reset();
    _ = try decoder.step(frame[0..1], &.{});
    try std.testing.expectError(error.InvalidStreamState, decoder.clearCompressedBlockWorkspace());
    try std.testing.expectError(error.InvalidStreamState, decoder.bindCompressedBlockWorkspace(storage[1 .. required_len + 1]));
    decoder.reset();
    try decoder.clearCompressedBlockWorkspace();
    try std.testing.expect(!decoder.usesCompressedBlockWorkspace());
    try std.testing.expectEqual(@as(usize, 0), decoder.compressedBufferCapacity());
    try drive(&decoder, frame, &output, 3, 7);
    try std.testing.expectEqualSlices(u8, payload, &output);
    try std.testing.expect(decoder.compressedBufferCapacity() != 0);
}

test "Zstd compressed workspace and stable output decode sequences with zero owned memory" {
    const payload = "caller-owned compressed block and stable history " ** 128;
    const frame = try compressedFrame(std.testing.allocator, payload);
    defer std.testing.allocator.free(frame);
    var workspace: [required_len]u8 = undefined;
    var output: [payload.len]u8 = undefined;
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    var decoder = Decoder.initWithOptions(failing.allocator(), .{
        .max_working_memory = 0,
        .expected_output_len = payload.len,
    });
    defer decoder.deinit();
    try decoder.bindCompressedBlockWorkspace(&workspace);
    try decoder.bindStableOutput(&output);
    try driveStable(&decoder, frame, payload);
    try std.testing.expect(!failing.has_induced_failure);
    try std.testing.expectEqual(@as(usize, 0), decoder.workingMemoryBytes());
    try std.testing.expectEqual(@as(usize, 0), decoder.peakWorkingMemoryBytes());
    try std.testing.expect(decoder.streamedSequenceBlockCount() > 0);

    decoder.reset();
    try std.testing.expect(decoder.usesCompressedBlockWorkspace());
    try std.testing.expectEqual(required_len, decoder.compressedBufferCapacity());
    try driveStable(&decoder, frame, payload);

    try decoder.resetWithOptions(.{
        .max_working_memory = 0,
        .expected_output_len = payload.len,
    });
    try std.testing.expect(decoder.usesCompressedBlockWorkspace());
    try decoder.bindStableOutput(&output);
    try driveStable(&decoder, frame, payload);
}

test "Zstd compressed workspace retains one maximum compressed block across tiny output" {
    const fixture = try maximumCompressedLiteralFrame(std.testing.allocator, 3);
    defer std.testing.allocator.free(fixture.frame);
    defer std.testing.allocator.free(fixture.plain);
    const output = try std.testing.allocator.alloc(u8, fixture.plain.len);
    defer std.testing.allocator.free(output);
    var workspace: [required_len]u8 = undefined;
    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    try decoder.bindCompressedBlockWorkspace(&workspace);
    try drive(&decoder, fixture.frame, output, fixture.frame.len, 1023);
    try std.testing.expectEqualSlices(u8, fixture.plain, output);
    try std.testing.expectEqual(required_len, decoder.compressedBufferCapacity());
    try std.testing.expectEqual(@as(core.StreamCount, 3), decoder.streamedLiteralBlockCount());

    var capped_workspace: [required_len]u8 = undefined;
    var capped = Decoder.initWithOptions(std.testing.allocator, .{
        .max_compressed_buffer_len = required_len - 1,
    });
    defer capped.deinit();
    try capped.bindCompressedBlockWorkspace(&capped_workspace);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        drive(&capped, fixture.frame, output, fixture.frame.len, output.len),
    );
}

test "Zstd compressed workspace survives stopped member continuation" {
    const payload = "workspace next stream member " ** 64;
    const frame = try compressedFrame(std.testing.allocator, payload);
    defer std.testing.allocator.free(frame);
    const stream = try std.mem.concat(std.testing.allocator, u8, &.{ frame, frame });
    defer std.testing.allocator.free(stream);
    var workspace: [required_len]u8 = undefined;
    var first_output: [payload.len]u8 = undefined;
    var second_output: [payload.len]u8 = undefined;
    var decoder = Decoder.initWithOptions(std.testing.allocator, .{
        .stop_after_first_frame = true,
        .max_output_len = 2 * payload.len,
    });
    defer decoder.deinit();
    try decoder.bindCompressedBlockWorkspace(&workspace);
    try decoder.bindStableOutput(&first_output);
    var input_offset: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const result = try decoder.stepStable(stream[input_offset..]);
        input_offset += result.progress.input_read;
    }
    try std.testing.expectEqualSlices(u8, payload, decoder.stableOutput());
    try decoder.nextStreamWithStableOutput(&second_output);
    try std.testing.expect(decoder.usesCompressedBlockWorkspace());
    while (decoder.snapshot().phase != .done) {
        const result = try decoder.stepStable(stream[input_offset..]);
        input_offset += result.progress.input_read;
    }
    try decoder.finish();
    try std.testing.expectEqual(stream.len, input_offset);
    try std.testing.expectEqualSlices(u8, payload, decoder.stableOutput());
}

test "Zstd compressed workspace preserves history quota accounting" {
    const payload = "history quota with caller compressed workspace " ** 256;
    const frame = try compressedFrame(std.testing.allocator, payload);
    defer std.testing.allocator.free(frame);
    var workspace: [required_len]u8 = undefined;
    var measured_output: [payload.len]u8 = undefined;
    var measured = Decoder.init(std.testing.allocator);
    defer measured.deinit();
    try measured.bindCompressedBlockWorkspace(&workspace);
    try drive(&measured, frame, &measured_output, 7, 11);
    const peak = measured.peakWorkingMemoryBytes();
    try std.testing.expect(peak != 0);
    try std.testing.expect(peak < required_len);

    var exact_workspace: [required_len]u8 = undefined;
    var exact_output: [payload.len]u8 = undefined;
    var exact = Decoder.initWithOptions(std.testing.allocator, .{ .max_working_memory = peak });
    defer exact.deinit();
    try exact.bindCompressedBlockWorkspace(&exact_workspace);
    try drive(&exact, frame, &exact_output, 7, 11);
    try std.testing.expectEqualSlices(u8, payload, &exact_output);

    var below_workspace: [required_len]u8 = undefined;
    var below_output: [payload.len]u8 = undefined;
    var below = Decoder.initWithOptions(std.testing.allocator, .{ .max_working_memory = peak - 1 });
    defer below.deinit();
    try below.bindCompressedBlockWorkspace(&below_workspace);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, drive(&below, frame, &below_output, 7, 11));
}

test "Zstd compressed workspace rejects dictionary and capture aliases" {
    var storage: [required_len + 64]u8 = undefined;
    const dictionary = zstd.NativeDictionary.init(0x1234, storage[0..32]);
    var dictionary_decoder = Decoder.initWithDictionary(std.testing.allocator, dictionary);
    defer dictionary_decoder.deinit();
    try std.testing.expectError(error.InvalidBlockPlan, dictionary_decoder.bindCompressedBlockWorkspace(storage[0..required_len]));

    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    try decoder.bindCompressedBlockWorkspace(storage[0..required_len]);
    try std.testing.expectError(error.InvalidBlockPlan, decoder.setDictionary(dictionary));

    var capture_decoder = Decoder.initWithOptions(std.testing.allocator, .{
        .skippable_output = storage[required_len - 8 .. required_len + 8],
    });
    defer capture_decoder.deinit();
    try std.testing.expectError(error.InvalidBlockPlan, capture_decoder.bindCompressedBlockWorkspace(storage[0..required_len]));
}

test "Zstd compressed workspace resumes dictionary requests without owned heap" {
    const dictionary = zstd.NativeDictionary.init(0x5a17, "workspace dictionary prefix abcdefghijklmnop");
    const payload = "workspace dictionary prefix abcdefghijklmnop tail " ** 64;
    const encoded = try zstd.encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, payload, .{
        .selection = .fast_compressed,
        .block_size_max = 1024,
        .window_log = 10,
        .content_checksum = true,
        .include_content_size = false,
    }, dictionary);
    defer std.testing.allocator.free(encoded.frame);
    var workspace: [required_len]u8 = undefined;
    var output: [payload.len]u8 = undefined;
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    var decoder = Decoder.initWithOptions(failing.allocator(), .{
        .max_working_memory = 0,
        .expected_output_len = payload.len,
    });
    defer decoder.deinit();
    try decoder.bindCompressedBlockWorkspace(&workspace);
    try decoder.bindStableOutput(&output);
    try std.testing.expectError(error.NeedDictionary, decoder.stepStable(encoded.frame));
    try std.testing.expectEqual(@as(?u32, dictionary.id), decoder.requiredDictionaryId());
    const accepted = try core.stream_count.toLocal(decoder.snapshot().input_received);
    try decoder.provideDictionary(dictionary);
    try driveStable(&decoder, encoded.frame[accepted..], payload);
    try std.testing.expect(!failing.has_induced_failure);
    try std.testing.expectEqual(@as(usize, 0), decoder.peakWorkingMemoryBytes());
}

test "Zstd compressed workspace survives checksum failure and reset" {
    const payload = "workspace checksum lifecycle " ** 96;
    const frame = try compressedFrame(std.testing.allocator, payload);
    defer std.testing.allocator.free(frame);
    const corrupt = try std.testing.allocator.dupe(u8, frame);
    defer std.testing.allocator.free(corrupt);
    corrupt[corrupt.len - 1] ^= 0x80;
    var workspace: [required_len]u8 = undefined;
    var output: [payload.len]u8 = undefined;
    var decoder = Decoder.initWithOptions(std.testing.allocator, .{ .expected_output_len = payload.len });
    defer decoder.deinit();
    try decoder.bindCompressedBlockWorkspace(&workspace);
    try decoder.bindStableOutput(&output);
    var input_offset: usize = 0;
    while (true) {
        if (decoder.stepStable(corrupt[input_offset..])) |result| {
            input_offset += result.progress.input_read;
        } else |err| {
            try std.testing.expectEqual(error.ChecksumMismatch, err);
            break;
        }
    }
    try std.testing.expect(decoder.usesCompressedBlockWorkspace());
    decoder.reset();
    try driveStable(&decoder, frame, payload);
}

test "Zstd compressed workspace decodes magicless reverse payloads" {
    const payload = "magicless caller compressed workspace " ** 96;
    const standard = try compressedFrame(std.testing.allocator, payload);
    defer std.testing.allocator.free(standard);
    const magicless = standard[4..];
    var workspace: [required_len]u8 = undefined;
    var output: [payload.len]u8 = undefined;
    var decoder = Decoder.initWithOptions(std.testing.allocator, .{
        .format = .magicless,
        .max_working_memory = 0,
        .expected_output_len = payload.len,
    });
    defer decoder.deinit();
    try decoder.bindCompressedBlockWorkspace(&workspace);
    try decoder.bindStableOutput(&output);
    try driveStable(&decoder, magicless, payload);
    try std.testing.expectEqual(@as(usize, 0), decoder.peakWorkingMemoryBytes());
}

test "Zstd compressed workspace rejects reserved blocks before output" {
    const payload = "reserved block workspace guard " ** 32;
    const valid = try compressedFrame(std.testing.allocator, payload);
    defer std.testing.allocator.free(valid);
    const corrupt = try std.testing.allocator.dupe(u8, valid);
    defer std.testing.allocator.free(corrupt);
    const header = try zstd.inspectNativeFrameHeader(corrupt);
    var block_header = std.mem.readInt(u24, corrupt[header.payload_offset..][0..3], .little);
    block_header = (block_header & ~@as(u24, 0x6)) | 0x6;
    std.mem.writeInt(u24, corrupt[header.payload_offset..][0..3], block_header, .little);
    var workspace: [required_len]u8 = undefined;
    var output: [payload.len]u8 = @splat(0xa5);
    var decoder = Decoder.init(std.testing.allocator);
    defer decoder.deinit();
    try decoder.bindCompressedBlockWorkspace(&workspace);
    try std.testing.expectError(error.CorruptFrame, decoder.step(corrupt, &output));
    try std.testing.expectEqual(@as(core.StreamCount, 0), decoder.snapshot().output_written);
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}
