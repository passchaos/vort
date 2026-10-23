const std = @import("std");
const Decoder = @import("../lzma2_incremental_decoder.zig").Decoder;

test "LZMA2 progressive dictionary reserve supports the full u32 window" {
    const capacity = @import("dictionary_capacity.zig");
    const limit = std.math.maxInt(u32);
    try std.testing.expectEqual(limit, capacity.needed(u32, limit, limit, 273));
    try std.testing.expectEqual(limit, capacity.needed(u32, limit - 1, limit, 273));
    try std.testing.expectEqual(@as(u32, 274), capacity.needed(u32, 1, limit, 273));
}

test "LZMA2 progressive cumulative input rejects overflow before fresh IO" {
    var decoder = try Decoder.init(std.testing.allocator, .{ .dictionary_property = 0 });
    defer decoder.deinit();
    decoder.input_read = std.math.maxInt(usize);
    var output: [1]u8 = .{0xa5};
    try std.testing.expectError(error.IntegerOverflow, decoder.step("a", &output));
    try std.testing.expectEqual(@import("../../core.zig").Progress{}, decoder.last_step_progress);
    try std.testing.expectEqual(std.math.maxInt(usize), decoder.input_read);
    try std.testing.expectEqual(@as(usize, 0), decoder.output_written);
    try std.testing.expectEqual(@as(u8, 0), decoder.control);
    try std.testing.expectEqual(@as(u8, 0xa5), output[0]);
    try std.testing.expectEqual(@as(usize, 0), decoder.workingMemoryBytes());
}

fn decodeFragmented(
    allocator: std.mem.Allocator,
    encoded: []const u8,
    expected: []const u8,
    input_chunk: usize,
    output_chunk: usize,
) !void {
    var decoder = try Decoder.init(allocator, .{
        .dictionary_property = @import("../lzma2_writer.zig").dictionary_property,
        .expected_output_len = expected.len,
        .max_output_len = expected.len,
    });
    defer decoder.deinit();
    const output = try allocator.alloc(u8, expected.len);
    defer allocator.free(output);
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (true) {
        const input_end = @min(encoded.len, input_offset + input_chunk);
        if (input_offset == encoded.len) decoder.finish();
        const output_end = @min(output.len, output_offset + output_chunk);
        const stepped = try decoder.step(
            encoded[input_offset..input_end],
            output[output_offset..output_end],
        );
        input_offset += stepped.progress.input_read;
        output_offset += stepped.progress.output_written;
        if (stepped.status == .done) break;
    }
    try std.testing.expectEqual(encoded.len, input_offset);
    try std.testing.expectEqual(expected.len, output_offset);
    try std.testing.expectEqualSlices(u8, expected, output);
}

test "raw LZMA2 incremental decoder handles stored and compressed chunks" {
    const writer = @import("../lzma2_writer.zig");
    const stored_input = "stored LZMA2 chunks\n" ** 4096;
    var stored: std.ArrayList(u8) = .empty;
    defer stored.deinit(std.testing.allocator);
    _ = try writer.appendStoredPayload(std.testing.allocator, &stored, stored_input);
    try decodeFragmented(std.testing.allocator, stored.items, stored_input, 1, 3);

    const compressed_input = "compressed LZMA2 chunks retain state and dictionary\n" ** 4096;
    var compressed: std.ArrayList(u8) = .empty;
    defer compressed.deinit(std.testing.allocator);
    _ = try writer.appendCompressedPayload(
        std.testing.allocator,
        &compressed,
        compressed_input,
    );
    try decodeFragmented(std.testing.allocator, compressed.items, compressed_input, 7, 5);
}

test "raw LZMA2 incremental decoder enforces limits truncation and OOM" {
    const writer = @import("../lzma2_writer.zig");
    const input = "raw LZMA2 allocation failure\n" ** 128;
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    _ = try writer.appendCompressedPayload(std.testing.allocator, &encoded, input);

    try std.testing.expectError(
        error.OutputLimitExceeded,
        Decoder.init(std.testing.allocator, .{
            .dictionary_property = writer.dictionary_property,
            .max_dictionary_size = 4095,
        }),
    );
    var missing_resets = try std.testing.allocator.dupe(u8, encoded.items);
    defer std.testing.allocator.free(missing_resets);
    missing_resets[0] = 0x80 | (missing_resets[0] & 0x1f);
    var invalid = try Decoder.init(std.testing.allocator, .{
        .dictionary_property = writer.dictionary_property,
        .expected_output_len = input.len,
    });
    defer invalid.deinit();
    var invalid_output: [input.len]u8 = undefined;
    try std.testing.expectError(
        error.InvalidLzma2Stream,
        invalid.step(missing_resets, &invalid_output),
    );

    var truncated = try Decoder.init(std.testing.allocator, .{
        .dictionary_property = writer.dictionary_property,
        .expected_output_len = input.len,
    });
    defer truncated.deinit();
    _ = try truncated.step(encoded.items[0..1], &.{});
    truncated.finish();
    try std.testing.expectError(error.TruncatedFrame, truncated.step("", &.{}));

    const FailureTest = struct {
        fn run(allocator: std.mem.Allocator, payload: []const u8, expected: []const u8) !void {
            try decodeFragmented(allocator, payload, expected, 11, 13);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        FailureTest.run,
        .{ encoded.items, input },
    );
}

fn encodedFixture(comptime name: []const u8) ![]u8 {
    const encoded = std.mem.trim(u8, @embedFile(name), " \r\n");
    const bytes = try std.testing.allocator.alloc(u8, encoded.len / 2);
    errdefer std.testing.allocator.free(bytes);
    _ = try std.fmt.hexToBytes(bytes, encoded);
    return bytes;
}

fn largeChunkPayload() ![]u8 {
    const payload = try std.testing.allocator.alloc(u8, 65536);
    var random = std.Random.DefaultPrng.init(0x175a_42bb);
    random.random().bytes(payload[0..8192]);
    for (payload[8192..], 8192..) |*byte, index| byte.* = payload[4096 + index % 4096];
    return payload;
}

fn encode(payload: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(std.testing.allocator);
    _ = try @import("../lzma2_writer.zig").appendCompressedPayload(std.testing.allocator, &out, payload);
    return out.toOwnedSlice(std.testing.allocator);
}

fn pump(decoder: *Decoder, encoded: []const u8, output: []u8, input_chunk: usize, output_chunk: usize) !void {
    var read: usize = 0;
    var written: usize = 0;
    while (true) {
        const step = try decoder.step(encoded[read..@min(encoded.len, read + input_chunk)], output[written..@min(output.len, written + output_chunk)]);
        read += step.progress.input_read;
        written += step.progress.output_written;
        try std.testing.expectEqual(step.progress, decoder.snapshot().last_step_progress);
        try std.testing.expect(decoder.snapshot().retained_compressed_capacity <= decoder.options.max_compressed_buffer_len);
        try std.testing.expect(decoder.snapshot().pending_output <= 273);
        try std.testing.expectEqual(@as(usize, 273), decoder.snapshot().retained_output_capacity);
        try std.testing.expect(decoder.peakWorkingMemoryBytes() >= decoder.workingMemoryBytes());
        if (step.status == .done) break;
        try std.testing.expect(step.progress.input_read != 0 or step.progress.output_written != 0);
        if (step.status == .need_input) try std.testing.expect(read < encoded.len);
        if (step.status == .need_output) try std.testing.expect(written < output.len);
    }
    try std.testing.expectEqual(encoded.len, read);
    try std.testing.expectEqual(output.len, written);
}

fn expectSticky(decoder: *Decoder, expected: anyerror) !void {
    const before = decoder.snapshot();
    var output: [5]u8 = @splat(0xa5);
    try std.testing.expectError(expected, decoder.step("unused input", &output));
    const after = decoder.snapshot();
    try std.testing.expectEqual(before.input_read, after.input_read);
    try std.testing.expectEqual(before.output_written, after.output_written);
    try std.testing.expectEqual(before.error_input_offset, after.error_input_offset);
    try std.testing.expectEqual(before.error_output_offset, after.error_output_offset);
    try std.testing.expectEqual(@import("../../core.zig").Progress{}, after.last_step_progress);
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

test "LZMA2 progressive guard postpones range mutation and emits before compressed chunk end" {
    const payload = try largeChunkPayload();
    defer std.testing.allocator.free(payload);
    const encoded = try encode(payload);
    defer std.testing.allocator.free(encoded);
    try std.testing.expect(encoded[0] >= 0xe0);
    const packed_len = @as(usize, std.mem.readInt(u16, encoded[3..5], .big)) + 1;
    try std.testing.expect(packed_len > 69);
    var decoder = try Decoder.init(std.testing.allocator, .{ .dictionary_property = 0, .expected_output_len = payload.len });
    defer decoder.deinit();
    var first_output: [1]u8 = undefined;
    const prefix = try decoder.step(encoded[0..11], &first_output); // Six-byte chunk header and range prefix.
    try std.testing.expectEqual(@import("../../core.zig").StepResult.Status.need_input, prefix.status);
    const range_before = decoder.range_decoder.?;
    const match_probabilities = decoder.lzma.?.is_match;
    const partial = try decoder.step(encoded[11..74], &first_output);
    try std.testing.expectEqual(@import("../../core.zig").StepResult.Status.need_input, partial.status);
    try std.testing.expectEqual(@as(usize, 0), partial.progress.output_written);
    try std.testing.expectEqual(range_before, decoder.range_decoder.?);
    try std.testing.expectEqualSlices(u16, &match_probabilities, &decoder.lzma.?.is_match);
    const emitted = try decoder.step(encoded[74..75], &first_output);
    try std.testing.expectEqual(@as(usize, 1), emitted.progress.output_written);
    try std.testing.expectEqual(payload[0], first_output[0]);
    try std.testing.expect(decoder.input_read < 6 + packed_len);
    try std.testing.expect(decoder.compressedBufferCapacity() <= 64);
    const output = try std.testing.allocator.alloc(u8, payload.len);
    defer std.testing.allocator.free(output);
    output[0] = first_output[0];
    try pump(&decoder, encoded[75..], output[1..], encoded.len, 137);
    try std.testing.expectEqualSlices(u8, payload, output);
}

test "LZMA2 progressive decodes a two MiB symbol stream with bounded input and output scratch" {
    // Python liblzma FORMAT_RAW, dictionary 4096, lc3/lp0/pb2. One compressed
    // chunk approaches the two MiB maximum; the final short chunk reuses state.
    const encoded = try encodedFixture("two_mib.hex");
    defer std.testing.allocator.free(encoded);
    const pattern = "LZMA2 progressive symbols and bounded dictionary\n";
    const payload = try std.testing.allocator.alloc(u8, 2 * 1024 * 1024);
    defer std.testing.allocator.free(payload);
    for (payload, 0..) |*byte, index| byte.* = pattern[index % pattern.len];
    try std.testing.expect(((@as(usize, encoded[0] & 31) << 16) | std.mem.readInt(u16, encoded[1..3], .big)) + 1 > 2 * 1024 * 1024 - 273);
    const output = try std.testing.allocator.alloc(u8, payload.len);
    defer std.testing.allocator.free(output);
    var decoder = try Decoder.init(std.testing.allocator, .{ .dictionary_property = 0, .expected_output_len = payload.len, .max_output_len = payload.len, .max_working_memory = 32 * 1024 });
    defer decoder.deinit();
    const first = try decoder.step(encoded, output[0..1]);
    try std.testing.expectEqual(@as(usize, 1), first.progress.output_written);
    const packed_end = 6 + @as(usize, std.mem.readInt(u16, encoded[3..5], .big)) + 1;
    try std.testing.expect(first.progress.input_read < packed_end);
    try pump(&decoder, encoded[first.progress.input_read..], output[1..], 7, 1021);
    try std.testing.expectEqualSlices(u8, payload, output);
    try std.testing.expect(decoder.peakWorkingMemoryBytes() <= 32 * 1024);
    try std.testing.expectEqual(payload.len, decoder.decoded_total);
}

test "LZMA2 progressive end marker stops before suffix and default rejects trailing data" {
    const stream = [_]u8{ 1, 0, 2, 'a', 'b', 'c', 0, 'X', 'Z' };
    var decoder = try Decoder.init(std.testing.allocator, .{ .dictionary_property = 0, .stop_after_end_marker = true, .max_compressed_buffer_len = 0 });
    defer decoder.deinit();
    var output: [3]u8 = undefined;
    const step = try decoder.step(&stream, &output);
    try std.testing.expectEqual(@import("../../core.zig").StepResult.Status.done, step.status);
    try std.testing.expectEqual(@as(usize, 7), step.progress.input_read);
    try std.testing.expectEqualStrings("abc", &output);
    try std.testing.expectEqual(@as(usize, 0), decoder.compressedBufferCapacity());
    const after = try decoder.step("more suffix", &output);
    try std.testing.expectEqual(@as(usize, 0), after.progress.input_read);
    try decoder.resetWithOptions(.{ .dictionary_property = 0 });
    try std.testing.expectError(error.TrailingData, decoder.step(&stream, &output));
    try std.testing.expectEqual(@as(usize, 7), decoder.last_step_progress.input_read);
    try std.testing.expectEqual(@as(usize, 3), decoder.last_step_progress.output_written);
    try expectSticky(&decoder, error.TrailingData);
}

test "LZMA2 progressive compressed guard cap does not constrain stored chunks" {
    const payload = try largeChunkPayload();
    defer std.testing.allocator.free(payload);
    const encoded = try encode(payload);
    defer std.testing.allocator.free(encoded);
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    var decoder = try Decoder.init(failing.allocator(), .{ .dictionary_property = 0, .max_compressed_buffer_len = 63 });
    defer decoder.deinit();
    try std.testing.expectEqual(@as(usize, 0), failing.allocations);
    var output: [1]u8 = undefined;
    try std.testing.expectError(error.CompressedBufferLimitExceeded, decoder.step(encoded, &output));
    try std.testing.expectEqual(@as(usize, 6), decoder.input_read);
    try std.testing.expectEqual(@as(usize, 0), failing.allocations);
    try expectSticky(&decoder, error.CompressedBufferLimitExceeded);
}

test "LZMA2 progressive preserves dictionary state and property reset controls" {
    const payload = [_]u8{ 1, 2, 3, 4 } ** 128;
    const original = try encode(&payload);
    defer std.testing.allocator.free(original);
    try std.testing.expect(original[0] >= 0xe0);
    const chunk_end = 6 + @as(usize, std.mem.readInt(u16, original[3..5], .big)) + 1;
    try std.testing.expectEqual(original.len - 1, chunk_end);
    for ([_]u8{ 0xa0, 0xc0, 0xe0 }) |reset_control| {
        var stream: std.ArrayList(u8) = .empty;
        defer stream.deinit(std.testing.allocator);
        try stream.appendSlice(std.testing.allocator, original[0..chunk_end]);
        try stream.append(std.testing.allocator, reset_control | (original[0] & 31));
        try stream.appendSlice(std.testing.allocator, original[1..5]);
        if (reset_control >= 0xc0) try stream.append(std.testing.allocator, original[5]);
        try stream.appendSlice(std.testing.allocator, original[6..]);
        var decoder = try Decoder.init(std.testing.allocator, .{ .dictionary_property = 0, .expected_output_len = 2 * payload.len });
        defer decoder.deinit();
        var output: [2 * payload.len]u8 = undefined;
        try pump(&decoder, stream.items, &output, 3, 1);
        try std.testing.expectEqualSlices(u8, &payload, output[0..payload.len]);
        try std.testing.expectEqualSlices(u8, &payload, output[payload.len..]);
    }
    var missing_properties = try std.testing.allocator.dupe(u8, original);
    defer std.testing.allocator.free(missing_properties);
    missing_properties[0] = 0x80 | (original[0] & 31);
    var invalid = try Decoder.init(std.testing.allocator, .{ .dictionary_property = 0 });
    defer invalid.deinit();
    var out: [payload.len]u8 = undefined;
    try std.testing.expectError(error.InvalidLzma2Stream, invalid.step(missing_properties, &out));
    try expectSticky(&invalid, error.InvalidLzma2Stream);
    invalid.reset();
    missing_properties[0] = original[0];
    missing_properties[5] = 225;
    try std.testing.expectError(error.InvalidLzma2Stream, invalid.step(missing_properties, &out));
}

test "LZMA2 progressive working budget exact below retained reset and configuration" {
    const encoded = try encodedFixture("two_mib.hex");
    defer std.testing.allocator.free(encoded);
    const output = try std.testing.allocator.alloc(u8, 2 * 1024 * 1024);
    defer std.testing.allocator.free(output);
    var decoder = try Decoder.init(std.testing.allocator, .{ .dictionary_property = 0 });
    defer decoder.deinit();
    try std.testing.expectEqual(@as(usize, 0), decoder.workingMemoryBytes());
    try pump(&decoder, encoded, output, 11, 511);
    const peak = decoder.peakWorkingMemoryBytes();
    const live = decoder.workingMemoryBytes();
    try std.testing.expect(live > 12288 and peak >= live);
    const before = decoder.snapshot();
    try std.testing.expectError(error.InvalidLzma2Stream, decoder.resetWithOptions(.{ .dictionary_property = 41 }));
    try std.testing.expectEqual(before, decoder.snapshot());
    decoder.reset();
    try std.testing.expectEqual(live, decoder.workingMemoryBytes());
    try std.testing.expectEqual(live, decoder.peakWorkingMemoryBytes());
    try std.testing.expectEqual(@as(usize, 0), decoder.input_read);
    try std.testing.expectEqual(@as(usize, 0), decoder.output_written);
    try pump(&decoder, encoded, output, 11, 511);
    try std.testing.expectEqual(live, decoder.peakWorkingMemoryBytes());
    try decoder.resetWithOptions(.{ .dictionary_property = 0, .max_working_memory = peak });
    try std.testing.expectEqual(@as(usize, 0), decoder.workingMemoryBytes());
    try pump(&decoder, encoded, output, 11, 511);
    try std.testing.expectEqual(peak, decoder.peakWorkingMemoryBytes());
    try decoder.resetWithOptions(.{ .dictionary_property = 0, .max_working_memory = peak - 1 });
    var read: usize = 0;
    var written: usize = 0;
    while (true) {
        const step = decoder.step(encoded[read..@min(encoded.len, read + 11)], output[written..@min(output.len, written + 511)]) catch |err| {
            try std.testing.expectEqual(error.WorkingMemoryLimitExceeded, err);
            break;
        };
        read += step.progress.input_read;
        written += step.progress.output_written;
        try std.testing.expect(step.status != .done);
    }
    try std.testing.expect(decoder.peakWorkingMemoryBytes() <= peak - 1);
    try expectSticky(&decoder, error.WorkingMemoryLimitExceeded);
}

test "LZMA2 progressive allocation failure matrix records published prefix and reset retries" {
    const pattern = "allocator failure symbol progress\n";
    const payload = pattern ** 64;
    const encoded = try encode(payload);
    defer std.testing.allocator.free(encoded);
    var baseline = std.testing.FailingAllocator.init(std.testing.allocator, .{ .resize_fail_index = 0 });
    {
        var decoder = try Decoder.init(baseline.allocator(), .{ .dictionary_property = 0, .expected_output_len = payload.len });
        defer decoder.deinit();
        var output: [payload.len]u8 = undefined;
        try pump(&decoder, encoded, &output, 11, 7);
    }
    try std.testing.expectEqual(baseline.allocated_bytes, baseline.freed_bytes);
    try std.testing.expect(baseline.allocations > 2 and baseline.allocations < 128);
    for (0..baseline.allocations) |fail_index| {
        var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = fail_index, .resize_fail_index = 0 });
        var decoder = try Decoder.init(failing.allocator(), .{ .dictionary_property = 0, .expected_output_len = payload.len });
        var decoder_live = true;
        defer if (decoder_live) decoder.deinit();
        try std.testing.expectEqual(@as(usize, 0), failing.allocations);
        var output: [payload.len]u8 = @splat(0xa5);
        var read: usize = 0;
        var written: usize = 0;
        while (true) {
            const before = decoder.snapshot();
            const step = decoder.step(encoded[read..@min(encoded.len, read + 11)], output[written..@min(output.len, written + 7)]) catch |err| {
                try std.testing.expectEqual(error.OutOfMemory, err);
                const failure = decoder.snapshot();
                const progress = failure.last_step_progress;
                try std.testing.expectEqual(failure.input_read - before.input_read, progress.input_read);
                try std.testing.expectEqual(failure.output_written - before.output_written, progress.output_written);
                const published = written + progress.output_written;
                try std.testing.expectEqual(published, failure.output_written);
                try std.testing.expectEqual(@as(?usize, failure.input_read), failure.error_input_offset);
                try std.testing.expectEqual(@as(?usize, published), failure.error_output_offset);
                try std.testing.expectEqualSlices(u8, payload[0..published], output[0..published]);
                for (output[published..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
                try expectSticky(&decoder, error.OutOfMemory);
                break;
            };
            read += step.progress.input_read;
            written += step.progress.output_written;
            try std.testing.expect(step.status != .done);
        }
        failing.fail_index = std.math.maxInt(usize);
        decoder.reset();
        try pump(&decoder, encoded, &output, 11, 7);
        try std.testing.expectEqualSlices(u8, payload, &output);
        decoder.deinit();
        decoder_live = false;
        try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
    }
}

test "LZMA2 progressive declared chunk length never borrows next control bytes" {
    const payload = "chunk length boundary\n" ** 128;
    const encoded = try encode(payload);
    defer std.testing.allocator.free(encoded);
    const packed_len = std.mem.readInt(u16, encoded[3..5], .big);
    try std.testing.expect(packed_len > 5);
    var short = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(short);
    std.mem.writeInt(u16, short[3..5], packed_len - 1, .big);
    var decoder = try Decoder.init(std.testing.allocator, .{ .dictionary_property = 0 });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    if (decoder.step(short, &output)) |_| return error.TestUnexpectedResult else |err| {
        try std.testing.expectEqual(error.TruncatedFrame, err);
        try std.testing.expect(decoder.input_read <= 6 + @as(usize, packed_len));
        try std.testing.expectEqual(@as(?usize, decoder.input_read), decoder.error_input_offset);
        try std.testing.expectEqual(@as(?usize, decoder.output_written), decoder.error_output_offset);
        try expectSticky(&decoder, err);
    }
    var long = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(long);
    std.mem.writeInt(u16, long[3..5], packed_len + 1, .big);
    decoder.reset();
    try std.testing.expectError(error.SizeMismatch, decoder.step(long, &output));
    try expectSticky(&decoder, error.SizeMismatch);
    decoder.reset();
    const first = try decoder.step(encoded[0 .. encoded.len - 1], &output);
    try std.testing.expectEqual(@import("../../core.zig").StepResult.Status.need_input, first.status);
    try std.testing.expectEqual(payload.len, first.progress.output_written);
    decoder.finish();
    try std.testing.expectError(error.TruncatedFrame, decoder.step("", &.{}));
    try std.testing.expectEqual(@import("../../core.zig").Progress{}, decoder.last_step_progress);
    try expectSticky(&decoder, error.TruncatedFrame);
}
