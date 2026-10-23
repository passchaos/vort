const std = @import("std");
const lzfse = @import("../lzfse.zig");
const format = @import("format.zig");
const tail_sizes = @import("incremental/fse_cursor.zig");
const header_writer = @import("encoder/header.zig");
const working = @import("../io/working_allocator.zig");
const core = @import("../core.zig");
const allocator = std.testing.allocator;
const Decoder = lzfse.IncrementalDecoder;

const Observed = struct {
    snapshot: Decoder.Snapshot,
    first_output_input: ?usize = null,
    compressed_capacity: usize = 0,
};

fn checkStep(before: Decoder.Snapshot, after: Decoder.Snapshot, offered: usize, storage: []const u8, capacity: usize, expected: []const u8, emitted: usize) !void {
    const progress = after.last_step_progress;
    try std.testing.expectEqual(after.input_read - before.input_read, progress.input_read);
    try std.testing.expectEqual(after.output_written - before.output_written, progress.output_written);
    try std.testing.expect(progress.input_read <= offered and progress.output_written <= capacity);
    try std.testing.expect(emitted <= expected.len);
    try std.testing.expect(progress.output_written <= expected.len - emitted);
    try std.testing.expectEqualSlices(u8, expected[emitted..][0..progress.output_written], storage[1..][0..progress.output_written]);
    try std.testing.expectEqual(@as(u8, 0xcc), storage[0]);
    for (storage[1 + progress.output_written .. 1 + capacity]) |byte| try std.testing.expectEqual(@as(u8, 0xcc), byte);
    try std.testing.expectEqual(@as(u8, 0xcc), storage[1 + capacity]);
}

// No one-shot decoder participates: every expected byte is compared directly
// with the prefix published by the public step call, including failed calls.
fn drive(decoder: *Decoder, wire: []const u8, expected: []const u8, input_split: usize, output_split: usize, zero_output: bool) !Observed {
    var offset = decoder.snapshot().stream_input_read;
    var emitted = decoder.snapshot().stream_output_written;
    var observed = Observed{ .snapshot = decoder.snapshot() };
    var calls: usize = 0;
    while (decoder.snapshot().phase != .done) {
        try std.testing.expect(calls < 3 * (wire.len + expected.len) + 32);
        if (offset == wire.len) decoder.finish();
        const take = @min(input_split, wire.len - offset);
        const capacity = if (zero_output and calls % 5 == 0) 0 else @min(output_split, 4096);
        var output: [4098]u8 = @splat(0xcc);
        const before = decoder.snapshot();
        const result = decoder.step(wire[offset..][0..take], output[1..][0..capacity]) catch |err| {
            const failed = decoder.snapshot();
            try checkStep(before, failed, take, &output, capacity, expected, emitted);
            try std.testing.expectEqual(failed.input_read, failed.error_input_offset.?);
            try std.testing.expectEqual(failed.output_written, failed.error_output_offset.?);
            return err;
        };
        const after = decoder.snapshot();
        try checkStep(before, after, take, &output, capacity, expected, emitted);
        try std.testing.expectEqualDeep(result.progress, after.last_step_progress);
        offset += result.progress.input_read;
        emitted += result.progress.output_written;
        if (result.progress.output_written != 0 and observed.first_output_input == null)
            observed.first_output_input = after.stream_input_read;
        observed.compressed_capacity = @max(observed.compressed_capacity, after.retained_compressed_capacity);
        if (result.status != .done and capacity != 0 and take != 0)
            try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
        calls += 1;
    }
    try std.testing.expectEqual(wire.len, offset);
    try std.testing.expectEqual(expected.len, emitted);
    observed.snapshot = decoder.snapshot();
    return observed;
}

fn rawBlock(output: *std.ArrayList(u8), input: []const u8) !void {
    var header: [8]u8 = undefined;
    std.mem.writeInt(u32, header[0..4], format.uncompressed_magic, .little);
    std.mem.writeInt(u32, header[4..8], @intCast(input.len), .little);
    try output.appendSlice(allocator, &header);
    try output.appendSlice(allocator, input);
}

fn lzvnBlock(output: *std.ArrayList(u8), payload: []const u8, raw_size: usize) !void {
    var header: [12]u8 = undefined;
    std.mem.writeInt(u32, header[0..4], format.compressed_lzvn_magic, .little);
    std.mem.writeInt(u32, header[4..8], @intCast(raw_size), .little);
    std.mem.writeInt(u32, header[8..12], @intCast(payload.len), .little);
    try output.appendSlice(allocator, &header);
    try output.appendSlice(allocator, payload);
}

fn literalLzvn(input: []const u8) ![]u8 {
    var payload: std.ArrayList(u8) = .empty;
    defer payload.deinit(allocator);
    var offset: usize = 0;
    while (offset < input.len) {
        const take = @min(271, input.len - offset);
        if (take < 16) try payload.append(allocator, 0xe0 | @as(u8, @intCast(take))) else {
            try payload.appendSlice(allocator, &.{ 0xe0, @intCast(take - 16) });
        }
        try payload.appendSlice(allocator, input[offset..][0..take]);
        offset += take;
    }
    try payload.appendSlice(allocator, &.{ 0x06, 0, 0, 0, 0, 0, 0, 0 });
    var wire: std.ArrayList(u8) = .empty;
    errdefer wire.deinit(allocator);
    try lzvnBlock(&wire, payload.items, input.len);
    try wire.appendSlice(allocator, "bvx$");
    return wire.toOwnedSlice(allocator);
}

fn fseHistoryStream(prefix: []const u8, length: usize, distance: u32, version: lzfse.FseVersion) ![]u8 {
    var plan = lzfse.EncodePlan.init(prefix.len);
    defer plan.deinit(allocator);
    try plan.append(allocator, "", length, distance);
    var block = try lzfse.encodeFsePlanAlloc(allocator, &plan, version);
    defer block.deinit(allocator);
    var wire: std.ArrayList(u8) = .empty;
    errdefer wire.deinit(allocator);
    if (prefix.len != 0) try rawBlock(&wire, prefix);
    try wire.appendSlice(allocator, block.bytes);
    try wire.appendSlice(allocator, "bvx$");
    return wire.toOwnedSlice(allocator);
}

test "LZFSE incremental decoder steps every block kind through tiny input and output splits" {
    const input = "abcdefgh" ** 128;
    for ([_]struct { strategy: lzfse.Strategy, version: lzfse.FseVersion, kind: lzfse.BlockKind }{
        .{ .strategy = .stored, .version = .v2, .kind = .uncompressed },
        .{ .strategy = .lzvn, .version = .v2, .kind = .lzvn },
        .{ .strategy = .fse, .version = .v1, .kind = .compressed_v1 },
        .{ .strategy = .fse, .version = .v2, .kind = .compressed_v2 },
    }) |case| {
        const wire = try lzfse.encodeAlloc(allocator, input, .{ .strategy = case.strategy, .fse_version = case.version });
        defer allocator.free(wire);
        try std.testing.expectEqual(case.kind, (try lzfse.parseBlock(wire, 0)).kind);
        for ([_]usize{ 1, 3, 7, 31 }) |input_split| {
            for ([_]usize{ 1, 3, 17 }) |output_split| {
                var decoder = Decoder.initWithOptions(allocator, .{ .max_history_len = 8, .expected_output_len = input.len, .max_output_len = input.len });
                defer decoder.deinit();
                const observed = try drive(&decoder, wire, input, input_split, output_split, true);
                try std.testing.expectEqual(@as(usize, 1), observed.snapshot.stream_count);
                try std.testing.expectEqual(@as(usize, 1), observed.snapshot.blocks_completed);
                try std.testing.expect(observed.snapshot.history_len <= 8);
            }
        }
    }
}

test "LZFSE incremental decoder raw and LZVN emit early with zero payload and work buffers" {
    for ([_]usize{ 16384, 131072 }) |size| {
        const input = try allocator.alloc(u8, size);
        defer allocator.free(input);
        for (input, 0..) |*byte, index| byte.* = @truncate(index * 73);
        const raw = try lzfse.encodeAlloc(allocator, input, .{ .strategy = .stored, .block_size = size });
        defer allocator.free(raw);
        const lzvn = try literalLzvn(input);
        defer allocator.free(lzvn);
        for ([_][]const u8{ raw, lzvn }) |wire| {
            var decoder = Decoder.initWithOptions(allocator, .{ .max_history_len = 0, .max_compressed_buffer_len = 0, .max_working_memory = 0 });
            defer decoder.deinit();
            const observed = try drive(&decoder, wire, input, 257, 127, true);
            try std.testing.expect(observed.first_output_input.? < (try lzfse.parseBlock(wire, 0)).next_offset);
            try std.testing.expectEqual(@as(usize, 0), observed.snapshot.peak_working_bytes);
            try std.testing.expectEqual(@as(usize, 0), observed.compressed_capacity);
            try std.testing.expectEqual(@as(usize, 0), observed.snapshot.history_capacity);
        }
    }
}

fn readHex(text: []const u8) ![]u8 {
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);
    var high: ?u8 = null;
    for (text) |byte| {
        if (std.ascii.isWhitespace(byte)) continue;
        const digit = try std.fmt.charToDigit(byte, 16);
        if (high) |value| {
            try bytes.append(allocator, value * 16 + digit);
            high = null;
        } else high = digit;
    }
    return bytes.toOwnedSlice(allocator);
}

fn inflateFse(wire: []const u8, extra: usize, version: lzfse.FseVersion) ![]u8 {
    var header = try format.parseCompressedHeader(wire);
    const literal_end = header.header_size + header.literal_payload_size;
    const payload_end = literal_end + header.lmd_payload_size;
    header.literal_payload_size += extra;
    header.lmd_payload_size += extra;
    const encoded_header = try header_writer.encodeAlloc(allocator, header, version);
    defer allocator.free(encoded_header);
    const padding = try allocator.alloc(u8, extra);
    defer allocator.free(padding);
    @memset(padding, 0xe7);
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendSlice(allocator, encoded_header);
    try output.appendSlice(allocator, padding);
    try output.appendSlice(allocator, wire[header.header_size..literal_end]);
    try output.appendSlice(allocator, padding);
    try output.appendSlice(allocator, wire[literal_end..payload_end]);
    try output.appendSlice(allocator, "bvx$");
    return output.toOwnedSlice(allocator);
}

test "LZFSE incremental decoder retains bounded FSE tails for Apple streams and huge unused prefixes" {
    const zeros: [100000]u8 = @splat(0);
    for ([_][]const u8{ @embedFile("testdata/apple-zero-100k-v1.lzfse.hex"), @embedFile("testdata/apple-zero-100k-v2.lzfse.hex") }) |text| {
        const wire = try readHex(text);
        defer allocator.free(wire);
        var decoder = Decoder.initWithOptions(allocator, .{ .max_history_len = 1, .max_compressed_buffer_len = 117502 });
        defer decoder.deinit();
        const observed = try drive(&decoder, wire, &zeros, 7, 3, true);
        try std.testing.expect(observed.compressed_capacity <= 117502);
        try std.testing.expect(observed.snapshot.peak_working_bytes < 100000);
    }
    const input = zeros[0..1024];
    for ([_]lzfse.FseVersion{ .v1, .v2 }) |version| {
        const wire = try lzfse.encodeAlloc(allocator, input, .{ .strategy = .fse, .fse_version = version });
        defer allocator.free(wire);
        const inflated = try inflateFse(wire, 256 * 1024, version);
        defer allocator.free(inflated);
        const retained = try tail_sizes.retainedSizes(try format.parseCompressedHeader(inflated));
        var decoder = Decoder.initWithOptions(allocator, .{ .max_history_len = 1, .max_compressed_buffer_len = retained.literal + retained.lmd, .max_working_memory = 4096 });
        defer decoder.deinit();
        const observed = try drive(&decoder, inflated, input, 257, 31, true);
        try std.testing.expect(observed.snapshot.payload_prefix_skipped >= 2 * 256 * 1024);
        try std.testing.expectEqual(retained.literal + retained.lmd, observed.compressed_capacity);
        try std.testing.expect(observed.snapshot.peak_working_bytes < 4096);
    }
}

test "LZFSE incremental decoder carries raw history into FSE and LZVN through ring wrap" {
    const prefix = try allocator.alloc(u8, 262139);
    defer allocator.free(prefix);
    for (prefix, 0..) |*byte, index| byte.* = @truncate(index * 73);
    const expected = try allocator.alloc(u8, prefix.len + 2359);
    defer allocator.free(expected);
    @memcpy(expected[0..prefix.len], prefix);
    @memcpy(expected[prefix.len..], prefix[0..2359]);
    const wire = try fseHistoryStream(prefix, 2359, 262139, .v2);
    defer allocator.free(wire);
    var decoder = Decoder.initWithOptions(allocator, .{ .max_history_len = 262139 });
    defer decoder.deinit();
    const observed = try drive(&decoder, wire, expected, 4096, 4096, false);
    try std.testing.expectEqual(@as(usize, 262139), observed.snapshot.history_len);
    try std.testing.expectEqual(@as(usize, 2), observed.snapshot.blocks_completed);
    try decoder.resetWithOptions(.{ .max_history_len = 262138 });
    try std.testing.expectError(error.HistoryLimitExceeded, drive(&decoder, wire, expected, 257, 4096, false));
    try std.testing.expectEqual(prefix.len, decoder.snapshot().error_output_offset.?);

    var mixed: std.ArrayList(u8) = .empty;
    defer mixed.deinit(allocator);
    try rawBlock(&mixed, "abcdefgh");
    // Zero literals, three bytes at distance eight, then a long repeat match.
    try lzvnBlock(&mixed, &.{ 0x07, 8, 0, 0xf0, 84, 0x06, 0, 0, 0, 0, 0, 0, 0 }, 103);
    try mixed.appendSlice(allocator, "bvx$");
    // The repeated match keeps distance eight: compute the expected periodic
    // sequence directly rather than asking a decoder to manufacture it.
    var correct: [111]u8 = undefined;
    for (&correct, 0..) |*byte, index| byte.* = "abcdefgh"[index % 8];
    try decoder.resetWithOptions(.{ .max_history_len = 8, .max_compressed_buffer_len = 0 });
    _ = try drive(&decoder, mixed.items, &correct, 1, 3, true);
}

test "LZFSE incremental decoder output history compressed and working limits have exact boundaries" {
    const input = "abcdefgh" ** 128;
    const wire = try lzfse.encodeAlloc(allocator, input, .{ .strategy = .fse });
    defer allocator.free(wire);
    var decoder = Decoder.initWithOptions(allocator, .{ .max_output_len = input.len, .expected_output_len = input.len, .max_history_len = 8 });
    defer decoder.deinit();
    const baseline = try drive(&decoder, wire, input, 7, 3, true);
    const cap = baseline.compressed_capacity;
    const peak = baseline.snapshot.peak_working_bytes;
    try std.testing.expect(cap != 0 and peak != 0);
    try decoder.resetWithOptions(.{ .max_output_len = input.len, .expected_output_len = input.len, .max_history_len = 8, .max_compressed_buffer_len = cap, .max_working_memory = peak });
    _ = try drive(&decoder, wire, input, 7, 3, true);
    try decoder.resetWithOptions(.{ .max_history_len = 8, .max_compressed_buffer_len = cap - 1 });
    try std.testing.expectError(error.CompressedBufferLimitExceeded, drive(&decoder, wire, input, 7, 3, true));
    try decoder.resetWithOptions(.{ .max_history_len = 8, .max_compressed_buffer_len = cap, .max_working_memory = peak - 1 });
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, drive(&decoder, wire, input, 7, 3, true));
    try decoder.resetWithOptions(.{ .max_history_len = 7 });
    try std.testing.expectError(error.HistoryLimitExceeded, drive(&decoder, wire, input, 7, 3, true));
    try decoder.resetWithOptions(.{ .max_output_len = input.len - 1 });
    try std.testing.expectError(error.OutputLimitExceeded, drive(&decoder, wire, input, 7, 3, true));
    try decoder.resetWithOptions(.{ .expected_output_len = input.len - 1 });
    try std.testing.expectError(error.SizeMismatch, drive(&decoder, wire, input, 7, 3, true));
    try decoder.resetWithOptions(.{ .expected_output_len = input.len + 1 });
    try std.testing.expectError(error.SizeMismatch, drive(&decoder, wire, input, 7, 3, true));
    try std.testing.expectEqual(input.len, decoder.snapshot().output_written);
}

test "LZFSE incremental decoder finish truncation and trailing errors preserve actual progress" {
    const wire = try lzfse.encodeAlloc(allocator, "abc", .{ .strategy = .stored });
    defer allocator.free(wire);
    var decoder = Decoder.init(allocator);
    defer decoder.deinit();
    var output: [16]u8 = @splat(0xcc);
    const partial = try decoder.step(wire[0..10], &output);
    try std.testing.expectEqualDeep(core.Progress{ .input_read = 10, .output_written = 2 }, partial.progress);
    decoder.finish();
    try std.testing.expectError(error.TruncatedFrame, decoder.step("", &output));
    try std.testing.expectEqual(@as(usize, 10), decoder.snapshot().error_input_offset.?);
    try std.testing.expectEqual(@as(usize, 2), decoder.snapshot().error_output_offset.?);
    try std.testing.expectEqual(Decoder.Phase.raw, decoder.snapshot().last_error_phase);
    decoder.reset();
    decoder.finish();
    try std.testing.expectError(error.TrailingData, decoder.step(wire, &output));
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().input_read);
    decoder.reset();
    var trailing: std.ArrayList(u8) = .empty;
    defer trailing.deinit(allocator);
    try trailing.appendSlice(allocator, wire);
    try trailing.append(allocator, 'x');
    try std.testing.expectError(error.TrailingData, decoder.step(trailing.items, &output));
    const failed = decoder.snapshot();
    try std.testing.expectEqualDeep(core.Progress{ .input_read = wire.len, .output_written = 3 }, failed.last_step_progress);
    try std.testing.expectEqual(wire.len, failed.error_input_offset.?);
    try std.testing.expectEqualStrings("abc", output[0..3]);
    try std.testing.expectError(error.TrailingData, decoder.step("nope", &output));
    try std.testing.expectEqualDeep(core.Progress{}, decoder.snapshot().last_step_progress);
    try std.testing.expectEqual(failed.error_input_offset, decoder.snapshot().error_input_offset);
}

test "LZFSE incremental decoder nextStream preserves cumulative quota and clears history" {
    const first = try lzfse.encodeAlloc(allocator, "abc", .{ .strategy = .stored });
    defer allocator.free(first);
    const second = try lzfse.encodeAlloc(allocator, "XYZ", .{ .strategy = .stored });
    defer allocator.free(second);
    var joined: std.ArrayList(u8) = .empty;
    defer joined.deinit(allocator);
    try joined.appendSlice(allocator, first);
    try joined.appendSlice(allocator, second);
    for ([_]usize{ 6, 5 }) |quota| {
        var decoder = Decoder.initWithOptions(allocator, .{ .stop_after_end_marker = true, .max_output_len = quota, .expected_output_len = 3 });
        defer decoder.deinit();
        try std.testing.expectError(error.InvalidLzfseStream, decoder.nextStream());
        var output: [16]u8 = @splat(0xcc);
        const stopped = try decoder.step(joined.items, &output);
        try std.testing.expect(stopped.status == .done);
        try std.testing.expectEqual(first.len, stopped.progress.input_read);
        try std.testing.expectEqualStrings("abc", output[0..3]);
        decoder.finish();
        try decoder.nextStream();
        const reset = decoder.snapshot();
        try std.testing.expectEqual(@as(usize, 0), reset.history_len);
        try std.testing.expectEqual(@as(usize, 0), reset.stream_input_read);
        try std.testing.expectEqual(@as(usize, 0), reset.stream_output_written);
        try std.testing.expectEqual(first.len, reset.input_read);
        try std.testing.expectEqual(@as(usize, 3), reset.output_written);
        try std.testing.expect(!reset.input_finished);
        if (quota == 5) {
            try std.testing.expectError(error.OutputLimitExceeded, decoder.step(joined.items[first.len..], &output));
            try std.testing.expectEqualDeep(core.Progress{ .input_read = 8 }, decoder.snapshot().last_step_progress);
        } else {
            const next = try decoder.step(joined.items[first.len..], &output);
            try std.testing.expect(next.status == .done);
            try std.testing.expectEqualStrings("XYZ", output[0..3]);
            try std.testing.expectEqual(@as(usize, 6), decoder.snapshot().output_written);
            try std.testing.expectEqual(joined.items.len, decoder.snapshot().input_read);
            try std.testing.expectEqual(@as(usize, 2), decoder.snapshot().stream_count);
            try std.testing.expectEqual(@as(usize, 2), decoder.snapshot().blocks_completed);
        }
    }
    const with_prefix = try fseHistoryStream("abc", 6, 3, .v2);
    defer allocator.free(with_prefix);
    var decoder = Decoder.initWithOptions(allocator, .{ .stop_after_end_marker = true });
    defer decoder.deinit();
    var output: [16]u8 = undefined;
    _ = try decoder.step(first, &output);
    try decoder.nextStream();
    try std.testing.expectError(error.InvalidLzfseStream, decoder.step(with_prefix[11..], &output));
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().history_len);
    try std.testing.expectEqual(@as(usize, 3), decoder.snapshot().error_output_offset.?);
    decoder.reset();
    _ = try decoder.step(first, &output);
    try decoder.resetWithOptions(.{});
    _ = try decoder.step(first, &output);
    try std.testing.expectError(error.InvalidLzfseStream, decoder.nextStream());
}

test "LZFSE incremental decoder FSE padding errors expose published prefix and sticky diagnostics" {
    var plan = lzfse.EncodePlan.init(0);
    defer plan.deinit(allocator);
    try plan.appendLiterals(allocator, "abc");
    var block = try lzfse.encodeFsePlanAlloc(allocator, &plan, .v2);
    defer block.deinit(allocator);
    var header = try format.parseCompressedHeader(block.bytes);
    header.literal_bits = -2;
    const encoded_header = try header_writer.encodeAlloc(allocator, header, .v2);
    defer allocator.free(encoded_header);
    var bad: std.ArrayList(u8) = .empty;
    defer bad.deinit(allocator);
    try bad.appendSlice(allocator, encoded_header);
    try bad.appendSlice(allocator, block.bytes[header.header_size..]);
    try bad.appendSlice(allocator, "bvx$");
    var decoder = Decoder.initWithOptions(allocator, .{ .max_history_len = 3 });
    defer decoder.deinit();
    var output: [16]u8 = @splat(0xcc);
    try std.testing.expectError(error.InvalidLzfseStream, decoder.step(bad.items, &output));
    const failed = decoder.snapshot();
    try std.testing.expectEqualDeep(core.Progress{ .input_read = bad.items.len - 4, .output_written = 3 }, failed.last_step_progress);
    try std.testing.expectEqualStrings("abc", output[0..3]);
    try std.testing.expectEqual(Decoder.Phase.fse_output, failed.last_error_phase);
    const diagnostic = decoder.diagnostics();
    try std.testing.expectEqualDeep(failed.last_step_progress, diagnostic.last_step_progress);
    try std.testing.expectEqualStrings("payload_corrupt", diagnostic.recoverability_hint_name);
    try std.testing.expectError(error.InvalidLzfseStream, decoder.step("bvx$", &output));
    try std.testing.expectEqualDeep(core.Progress{}, decoder.snapshot().last_step_progress);
    try std.testing.expectEqual(failed.error_input_offset, decoder.snapshot().error_input_offset);
    decoder.reset();
    try std.testing.expectEqualStrings("", decoder.snapshot().last_error_name);
}

test "LZFSE incremental decoder constructors and option reset preserve explicit buffer ownership" {
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    var invalid = Decoder.initWithOptions(failing.allocator(), .{ .max_history_len = 262140 });
    defer invalid.deinit();
    try std.testing.expectEqual(@as(usize, 0), invalid.snapshot().working_bytes);
    try std.testing.expectError(error.InvalidLzfseStream, invalid.step("bvx$", &.{}));
    try std.testing.expectEqual(@as(usize, 0), invalid.snapshot().input_read);
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
    try invalid.resetWithOptions(.{ .max_output_len = 0, .expected_output_len = 0, .max_history_len = 0, .max_compressed_buffer_len = 0, .max_working_memory = 0 });
    const empty = try lzfse.encodeAlloc(allocator, "", .{});
    defer allocator.free(empty);
    _ = try drive(&invalid, empty, "", 1, 1, true);
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);

    const input = "abcdefgh" ** 128;
    const wire = try lzfse.encodeAlloc(allocator, input, .{ .strategy = .fse });
    defer allocator.free(wire);
    var observer = working.WorkingAllocator.init(allocator, std.math.maxInt(usize));
    {
        var decoder = Decoder.initWithOptions(observer.allocator(), .{ .max_history_len = 8 });
        defer decoder.deinit();
        try std.testing.expectEqual(@as(usize, 0), observer.live);
        _ = try drive(&decoder, wire, input, 7, 3, true);
        const retained = decoder.snapshot();
        try std.testing.expectEqual(observer.live, retained.working_bytes);
        try std.testing.expect(observer.live != 0);
        try std.testing.expectError(error.InvalidLzfseStream, decoder.resetWithOptions(.{ .expected_output_len = 2, .max_output_len = 1 }));
        try std.testing.expectEqualDeep(retained, decoder.snapshot());
        decoder.reset();
        try std.testing.expectEqual(retained.retained_compressed_capacity, decoder.snapshot().retained_compressed_capacity);
        try std.testing.expectEqual(retained.history_capacity, decoder.snapshot().history_capacity);
        try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().history_len);
        _ = try drive(&decoder, wire, input, 7, 3, true);
        try decoder.resetWithOptions(.{ .max_history_len = 0, .max_compressed_buffer_len = 0, .max_working_memory = 0 });
        try std.testing.expectEqual(@as(usize, 0), observer.live);
        try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().retained_compressed_capacity);
        try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().history_capacity);
        _ = try drive(&decoder, empty, "", 1, 1, true);
    }
    try std.testing.expectEqual(@as(usize, 0), observer.live);
}

fn allocationDecode(decoder: *Decoder, wire: []const u8, expected: []const u8, adapted: bool) !void {
    if (adapted) {
        var output: [4]u8 = undefined;
        const partial = try decoder.step(wire[0..12], &output);
        try std.testing.expectEqualDeep(core.Progress{ .input_read = 12, .output_written = 4 }, partial.progress);
        try std.testing.expectEqualStrings("abcd", &output);
        try std.testing.expect(decoder.snapshot().history_len != 0);
    }
    _ = try drive(decoder, wire, expected, 7, 3, true);
}

fn allocationFailure(test_allocator: std.mem.Allocator, wire: []const u8, expected: []const u8, adapted: bool) !void {
    var decoder = Decoder.initWithOptions(test_allocator, .{ .max_history_len = 8 });
    defer decoder.deinit();
    allocationDecode(&decoder, wire, expected, adapted) catch |err| {
        if (err != error.OutOfMemory) return err;
        try std.testing.expectEqualStrings("OutOfMemory", decoder.snapshot().last_error_name);
        // Keep allocation/free accounting on the same wrapper while restoring
        // its backing availability; return the injected failure to the checker.
        const controller: *std.testing.FailingAllocator = @ptrCast(@alignCast(test_allocator.ptr));
        controller.fail_index = std.math.maxInt(usize);
        controller.resize_fail_index = std.math.maxInt(usize);
        decoder.reset();
        try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().input_read);
        try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().history_len);
        _ = try drive(&decoder, wire, expected, 7, 3, true);
        return err;
    };
}

test "LZFSE incremental decoder retries every initial and partially adapted allocation failure after reset" {
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(allocator);
    try rawBlock(&wire, "abcdefgh");
    try lzvnBlock(&wire, &.{ 0x07, 8, 0, 0x06, 0, 0, 0, 0, 0, 0, 0 }, 3);
    var plan = lzfse.EncodePlan.init(11);
    defer plan.deinit(allocator);
    try plan.append(allocator, "", 600, 3);
    var block = try lzfse.encodeFsePlanAlloc(allocator, &plan, .v2);
    defer block.deinit(allocator);
    try wire.appendSlice(allocator, block.bytes);
    try wire.appendSlice(allocator, "bvx$");
    const expected = "abcdefghabc" ++ ("abc" ** 200);
    try std.testing.checkAllAllocationFailures(allocator, allocationFailure, .{ wire.items, expected, false });
    try std.testing.checkAllAllocationFailures(allocator, allocationFailure, .{ wire.items, expected, true });
}
