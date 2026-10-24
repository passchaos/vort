const std = @import("std");
const raw = @import("lzma2_incremental_encoder.zig");
const stream = @import("incremental_encoder.zig");
const raw_writer = @import("lzma2_writer.zig");
const writer = @import("writer.zig");
const container = @import("container.zig");
const helpers = @import("large_chunk_stream_helpers.zig");
const a = helpers.allocator;
const large = helpers.large;

test "XZ large chunk stream raw 21 bit compressed group final tail and output one round trip" {
    const input = try a.alloc(u8, large + 257);
    defer a.free(input);
    @memset(input[0..large], 'A');
    @memset(input[large..], 'B');
    var encoder = try raw.Encoder.initExactSize(a, .{ .chunk_size = large }, input.len);
    defer encoder.deinit();
    const encoded = try helpers.rawEncode(&encoder, input, 4093, 1);
    defer a.free(encoded);
    const envelope = try helpers.inspect(encoded, 0, true);
    try std.testing.expectEqual(@as(usize, 2), envelope.compressed);
    try std.testing.expectEqual(@as(usize, 0), envelope.stored);
    try std.testing.expectEqual(large, envelope.largest_plain);
    try std.testing.expectEqual(@as(u8, 0xff), envelope.first_control);
    try std.testing.expectEqual(input.len, envelope.plain);
    try std.testing.expectEqual(input.len, encoder.snapshot().encoded_input);
    try helpers.decodeRaw(encoded, input, encoder.options.dictionary_size);
    var baseline: std.ArrayList(u8) = .empty;
    defer baseline.deinit(a);
    _ = try raw_writer.appendCompressedPayloadWithAdvancedOptions(a, &baseline, input, encoder.options.chunkOptions());
    try std.testing.expectEqualSlices(u8, baseline.items, encoded);
}

test "XZ large chunk stream raw complete stored fallback is bounded and reset deterministic" {
    const input = try a.alloc(u8, large);
    defer a.free(input);
    helpers.noise(input);
    var encoder = try raw.Encoder.initExactSize(a, .{ .chunk_size = large }, input.len);
    defer encoder.deinit();
    const encoded = try helpers.rawEncode(&encoder, input, large, 8192);
    defer a.free(encoded);
    const envelope = try helpers.inspect(encoded, 0, true);
    try std.testing.expectEqual(@as(usize, 32), envelope.stored);
    try std.testing.expectEqual(@as(usize, 0), envelope.compressed);
    try std.testing.expectEqual(@as(u8, 1), envelope.first_control);
    try std.testing.expectEqual(large + 96 + 1, encoded.len);
    try std.testing.expect(encoder.candidate.items.len <= 65536);
    try helpers.decodeRaw(encoded, input, 4096);
    try encoder.reset();
    const repeated = try helpers.rawEncode(&encoder, input, 65521, 8192);
    defer a.free(repeated);
    try std.testing.expectEqualSlices(u8, encoded, repeated);
}

test "XZ large chunk stream tiny group validation auto caps default golden and options propagation" {
    try std.testing.expectEqual(@as(usize, 65552), try (raw.Encoder.Options{}).effectiveMaxPendingOutputLen());
    try std.testing.expectEqual(@as(usize, large + 96 + 13), try (raw.Encoder.Options{ .chunk_size = large }).effectiveMaxPendingOutputLen());
    try std.testing.expectEqual(@as(usize, 65552), try (raw.Encoder.Options{ .chunk_size = large, .max_pending_output_len = 65552 }).effectiveMaxPendingOutputLen());
    try std.testing.expectError(error.InvalidBlockPlan, raw.Encoder.init(a, .{ .chunk_size = 0 }));
    try std.testing.expectError(error.InvalidBlockPlan, raw.Encoder.init(a, .{ .chunk_size = large + 1 }));
    try std.testing.expectError(error.InvalidBlockPlan, raw.Encoder.init(a, .{ .max_pending_output_len = 65538 }));
    try std.testing.expectError(error.InvalidBlockPlan, stream.Encoder.initWithOptions(a, .{ .chunk_size = 0 }));
    for ([_]usize{ 1, 65536, large }) |size| {
        const raw_options = raw.Encoder.Options{ .chunk_size = size };
        const xz_options = stream.Encoder.Options{ .chunk_size = size };
        try std.testing.expectEqual(size, raw_options.chunkOptions().chunk_size);
        try std.testing.expectEqual(size, xz_options.writerOptions().chunk_size);
    }
    for (0..10) |level| {
        try std.testing.expectEqualDeep(try raw_writer.EncodeOptions.fromPreset(@intCast(level), false), (try raw.Encoder.Options.fromPreset(@intCast(level), false)).chunkOptions());
        try std.testing.expectEqualDeep(try writer.EncodeOptions.fromPreset(@intCast(level), false), (try stream.Encoder.Options.fromPreset(@intCast(level), false)).writerOptions());
    }
    var tiny = try raw.Encoder.initExactSize(a, .{ .chunk_size = 1, .max_pending_output_len = 4 }, 3);
    defer tiny.deinit();
    const bytes = try helpers.rawEncode(&tiny, "abc", 1, 1);
    defer a.free(bytes);
    try std.testing.expectEqualSlices(u8, &.{ 1, 0, 0, 'a', 2, 0, 0, 'b', 2, 0, 0, 'c', 0 }, bytes);
    var defaults = try raw.Encoder.init(a, .{});
    defer defaults.deinit();
    const golden = try helpers.rawEncode(&defaults, "abc", 1, 1);
    defer a.free(golden);
    try std.testing.expectEqualSlices(u8, &.{ 1, 0, 2, 'a', 'b', 'c', 0 }, golden);
    // Fixed from the format's empty Index and Header/Footer CRC rules.
    const empty_xz_hex = "fd377a585a000004e6d6b446000000001cdf44211fb6f37d010000000004595a";
    var empty_xz_golden: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&empty_xz_golden, empty_xz_hex);
    var empty_xz = try stream.Encoder.init(a);
    defer empty_xz.deinit();
    const empty_xz_bytes = try helpers.xzEncode(&empty_xz, "", 1, 1);
    defer a.free(empty_xz_bytes);
    try std.testing.expectEqualSlices(u8, &empty_xz_golden, empty_xz_bytes);

    // Format-only Null controls permit the legacy dictionary ceiling without
    // allocating that history when the input is empty or only three bytes.
    var huge_dictionary = try raw.Encoder.init(a, .{ .mode = .stored, .dictionary_size = 1536 * 1024 * 1024, .chunk_size = large });
    defer huge_dictionary.deinit();
    const huge_dictionary_bytes = try helpers.rawEncode(&huge_dictionary, "abc", 1, 1);
    defer a.free(huge_dictionary_bytes);
    try std.testing.expectEqualSlices(u8, golden, huge_dictionary_bytes);
    try std.testing.expectEqual(@as(usize, 3), huge_dictionary.history.items.len);
}

test "XZ large chunk stream explicit cap failure preserves committed raw state and retries same wire" {
    const input = try a.alloc(u8, large);
    defer a.free(input);
    inline for (.{ false, true }) |stored_fallback| {
        if (stored_fallback) helpers.noise(input) else @memset(input, 'A');
        var encoder = try raw.Encoder.initExactSize(a, .{ .chunk_size = large, .max_pending_output_len = 65552 }, input.len);
        defer encoder.deinit();
        if (!stored_fallback) encoder.options.max_pending_output_len = 50;
        const initial_model = encoder.chunk_state;
        try std.testing.expectError(error.OutputLimitExceeded, encoder.step(input, &.{}));
        try std.testing.expectEqualDeep(initial_model, encoder.chunk_state);
        try std.testing.expectEqual(@as(usize, 0), encoder.history.items.len);
        try std.testing.expectEqual(@as(usize, 0), encoder.encoded_input);
        try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().pending_output);
        try std.testing.expectEqual(input.len, encoder.snapshot().input_read);
        try std.testing.expectEqual(input.len, encoder.snapshot().buffered_input);
        encoder.options.max_pending_output_len = null;
        const recovered = try helpers.rawEncode(&encoder, "", 1, 8192);
        defer a.free(recovered);
        var expected: std.ArrayList(u8) = .empty;
        defer expected.deinit(a);
        _ = try raw_writer.appendCompressedPayloadWithAdvancedOptions(a, &expected, input, encoder.options.chunkOptions());
        try std.testing.expectEqualSlices(u8, expected.items, recovered);
        try helpers.decodeRaw(recovered, input, 4096);
    }
}

test "XZ large chunk stream XZ group flag and cap recovery flush partial block" {
    const input = try a.alloc(u8, large);
    defer a.free(input);
    @memset(input, 'A');
    const options = stream.Encoder.Options{ .chunk_size = large, .block_size = large };
    var encoder = try stream.Encoder.initExactSize(a, options, input.len);
    defer encoder.deinit();
    const encoded = try helpers.xzEncode(&encoder, input, 4093, 1);
    defer a.free(encoded);
    const raw_start = 12 + (@as(usize, encoded[12]) + 1) * 4;
    const envelope = try helpers.inspect(encoded, raw_start, false);
    try std.testing.expectEqual(large, envelope.largest_plain);
    try std.testing.expectEqual(@as(usize, 1), envelope.compressed);
    const expected = try writer.encodeAlloc(a, input, options.writerOptions());
    defer a.free(expected);
    try std.testing.expectEqualSlices(u8, expected, encoded);
    const decoded = try container.decodeAlloc(a, encoded);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);

    var limited = try stream.Encoder.initExactSize(a, .{ .chunk_size = large, .block_size = large, .max_pending_output_len = 12 }, input.len);
    defer limited.deinit();
    var header: [12]u8 = undefined;
    _ = try limited.step("", &header);
    try std.testing.expectError(error.OutputLimitExceeded, limited.step(input, &.{}));
    try std.testing.expectEqual(@as(usize, 0), limited.records.items.len);
    try std.testing.expectEqual(@as(usize, 0), limited.block_count);
    try std.testing.expectEqual(@as(usize, 0), limited.snapshot().pending_output);
    try std.testing.expectEqual(input.len, limited.plain.items.len);
    limited.options.max_pending_output_len = 16 * 1024 * 1024;
    var first: [8192]u8 = undefined;
    const retried = try helpers.checkedStep(&limited, "", &first);
    try std.testing.expectEqual(@as(usize, 0), limited.plain.items.len);
    try std.testing.expectEqual(@as(usize, 1), limited.block_count);
    const ending = try helpers.xzEncode(&limited, "", 1, 8192);
    defer a.free(ending);
    var recovered: std.ArrayList(u8) = .empty;
    defer recovered.deinit(a);
    try recovered.appendSlice(a, &header);
    try recovered.appendSlice(a, first[0..retried.progress.output_written]);
    try recovered.appendSlice(a, ending);
    try std.testing.expectEqualSlices(u8, expected, recovered.items);

    const first_part = "large chunk options also apply to a flushed partial block/" ** 16;
    const second_part = "after flush the next independent block starts normally/" ** 12;
    var flushing = try stream.Encoder.initExactSize(a, .{ .chunk_size = large, .block_size = large }, first_part.len + second_part.len);
    defer flushing.deinit();
    var flushed: std.ArrayList(u8) = .empty;
    defer flushed.deinit(a);
    try helpers.feedXz(&flushing, &flushed, first_part);
    flushing.flush();
    try helpers.drainFlush(&flushing, &flushed);
    try helpers.feedXz(&flushing, &flushed, second_part);
    flushing.flush();
    try helpers.drainFlush(&flushing, &flushed);
    const final_bytes = try helpers.xzEncode(&flushing, "", 1, 7);
    defer a.free(final_bytes);
    try flushed.appendSlice(a, final_bytes);
    try std.testing.expectEqual(@as(usize, 2), flushing.block_count);
    const flushed_plain = try container.decodeAlloc(a, flushed.items);
    defer a.free(flushed_plain);
    try std.testing.expectEqualSlices(u8, first_part ++ second_part, flushed_plain);
}

test "XZ large chunk stream wide dictionary retains matches across a multi packet stored group" {
    const input = try a.alloc(u8, large + 1024);
    defer a.free(input);
    helpers.noise(input[0..large]);
    @memcpy(input[large..], input[large - 70000 ..][0..1024]);
    var wide = try raw.Encoder.initExactSize(a, .{ .chunk_size = large, .dictionary_size = 128 * 1024 }, input.len);
    defer wide.deinit();
    const encoded = try helpers.rawEncode(&wide, input, large, 8192);
    defer a.free(encoded);
    const envelope = try helpers.inspect(encoded, 0, true);
    try std.testing.expectEqual(@as(usize, 32), envelope.stored);
    try std.testing.expectEqual(@as(usize, 1), envelope.compressed);
    try helpers.decodeRaw(encoded, input, 128 * 1024);
    var narrow = try raw.Encoder.initExactSize(a, .{ .chunk_size = large, .dictionary_size = 65536 }, input.len);
    defer narrow.deinit();
    const narrow_encoded = try helpers.rawEncode(&narrow, input, large, 8192);
    defer a.free(narrow_encoded);
    try std.testing.expect(encoded.len < narrow_encoded.len);
    try helpers.decodeRaw(narrow_encoded, input, 65536);
}

test "XZ large chunk stream final size mismatch and real working denial do not commit a group" {
    var raw_exact = try raw.Encoder.initExactSize(a, .{ .chunk_size = large }, 4);
    defer raw_exact.deinit();
    _ = try raw_exact.step("abc", &.{});
    const raw_model = raw_exact.chunk_state;
    raw_exact.finish();
    try std.testing.expectError(error.SizeMismatch, raw_exact.step("", &.{}));
    try std.testing.expectEqual(@as(usize, 0), raw_exact.encoded_input);
    try std.testing.expectEqualDeep(raw_model, raw_exact.chunk_state);

    var xz_exact = try stream.Encoder.initExactSize(a, .{ .chunk_size = large }, 4);
    defer xz_exact.deinit();
    var header: [12]u8 = undefined;
    _ = try xz_exact.step("", &header);
    _ = try xz_exact.step("abc", &.{});
    xz_exact.finish();
    try std.testing.expectError(error.SizeMismatch, xz_exact.step("", &.{}));
    try std.testing.expectEqual(@as(usize, 0), xz_exact.block_count);
    try std.testing.expectEqual(@as(usize, 3), xz_exact.plain.items.len);

    var no_working = try raw.Encoder.init(a, .{ .chunk_size = 17, .parser = .fast, .match_options = .{ .max_working_memory = 0 } });
    defer no_working.deinit();
    const untouched = no_working.chunk_state;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, no_working.step("abcdefghijklmnopq", &.{}));
    try std.testing.expectEqualDeep(untouched, no_working.chunk_state);
    try std.testing.expectEqual(@as(usize, 0), no_working.encoded_input);
    try std.testing.expectEqual(@as(usize, 0), no_working.history.items.len);
}

test "XZ large chunk stream every raw emission allocation failure preserves prior group and releases buffers" {
    try std.testing.checkAllAllocationFailures(a, allocationCase, .{});
}

fn allocationCase(allocator: std.mem.Allocator) !void {
    const first = [_]u8{'A'} ** 257;
    const second = [_]u8{'B'} ** 117;
    var encoder = try raw.Encoder.initExactSize(allocator, .{ .chunk_size = 257 }, first.len + second.len);
    defer encoder.deinit();
    const initial_model = encoder.chunk_state;
    var output: [2048]u8 = undefined;
    _ = encoder.step(&first, &output) catch |err| {
        try std.testing.expectEqualDeep(initial_model, encoder.chunk_state);
        try std.testing.expectEqual(@as(usize, 0), encoder.encoded_input);
        try std.testing.expectEqual(@as(usize, 0), encoder.history.items.len);
        return err;
    };
    const committed = encoder.chunk_state;
    _ = try encoder.step(&second, &.{});
    encoder.finish();
    @memset(&output, 0xa5);
    _ = encoder.step("", &output) catch |err| {
        try std.testing.expectEqualDeep(committed, encoder.chunk_state);
        try std.testing.expectEqual(first.len, encoder.encoded_input);
        try std.testing.expectEqualSlices(u8, &first, encoder.history.items);
        try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().pending_output);
        for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
        return err;
    };
}
