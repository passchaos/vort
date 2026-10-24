const std = @import("std");
const core = @import("../../core.zig");
const snappy = @import("../../snappy.zig");
const allocator = std.testing.allocator;
const Decoder = snappy.IncrementalFrameDecoder;

fn appendVarint(out: *std.ArrayList(u8), raw: usize) !void {
    var value: u32 = @intCast(raw);
    while (value >= 128) {
        try out.append(allocator, @as(u8, @truncate(value)) | 0x80);
        value >>= 7;
    }
    try out.append(allocator, @intCast(value));
}
pub fn literalBlock(bytes: []const u8, extra_copy: bool) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try appendVarint(&out, bytes.len + if (extra_copy) @as(usize, 64) else 0);
    if (bytes.len != 0) {
        const length = bytes.len - 1;
        if (length < 60) try out.append(allocator, @as(u8, @intCast(length << 2))) else {
            var width: usize = 1;
            while (width < 4 and length >> @intCast(width * 8) != 0) width += 1;
            try out.append(allocator, @intCast((59 + width) << 2));
            for (0..width) |i| try out.append(allocator, @truncate(length >> @intCast(i * 8)));
        }
        try out.appendSlice(allocator, bytes);
    }
    if (extra_copy) {
        try out.append(allocator, 0xff);
        var offset: [4]u8 = undefined;
        std.mem.writeInt(u32, &offset, @intCast(bytes.len), .little);
        try out.appendSlice(allocator, &offset);
    }
    return out.toOwnedSlice(allocator);
}
fn masked(bytes: []const u8) u32 {
    const crc = std.hash.crc.Crc32Iscsi.hash(bytes);
    return ((crc >> 15) | (crc << 17)) +% 0xa282_ead8;
}
pub fn appendChunk(out: *std.ArrayList(u8), kind: u8, bytes: []const u8) !void {
    const size: u24 = @intCast(bytes.len);
    var header: [4]u8 = .{ kind, @truncate(size), @truncate(size >> 8), @truncate(size >> 16) };
    try out.appendSlice(allocator, &header);
    try out.appendSlice(allocator, bytes);
}
pub fn appendData(out: *std.ArrayList(u8), block: []const u8, plaintext: []const u8, compressed: bool) !void {
    var payload: std.ArrayList(u8) = .empty;
    defer payload.deinit(allocator);
    var crc: [4]u8 = undefined;
    std.mem.writeInt(u32, &crc, masked(plaintext), .little);
    try payload.appendSlice(allocator, &crc);
    try payload.appendSlice(allocator, block);
    try appendChunk(out, if (compressed) 0 else 1, payload.items);
}
pub fn framed(block: []const u8, plaintext: []const u8, compressed: bool) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try appendChunk(&out, 0xff, "sNaPpY");
    try appendData(&out, block, plaintext, compressed);
    return out.toOwnedSlice(allocator);
}
pub fn drain(decoder: *Decoder, input: []const u8, output: []u8, read_start: usize, written_start: usize) !void {
    var read = read_start;
    var written = written_start;
    var finished = false;
    while (true) {
        if (read == input.len and !finished) {
            try decoder.finish();
            finished = true;
        }
        const end = @min(output.len, written + 17);
        const step = try decoder.step(input[read..], output[written..end]);
        read += step.progress.input_read;
        written += step.progress.output_written;
        try std.testing.expectEqualDeep(step.progress, decoder.snapshot().last_step_progress);
        try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().retained_decoded_capacity);
        try std.testing.expectEqual(decoder.chunk.capacity + decoder.cursor.historyCapacity(), decoder.workingMemoryBytes());
        if (step.status == .done) break;
        try std.testing.expect(step.progress.input_read != 0 or step.progress.output_written != 0);
    }
    try std.testing.expectEqual(input.len, read);
    try std.testing.expectEqual(output.len, written);
}

test "Snappy stream contracts ring indexing stays representable at usize limits" {
    const max = std.math.maxInt(usize);
    try std.testing.expectEqual(@as(usize, 0), snappy.BlockCursor.ringIndex(max, 1, max - 1));
    try std.testing.expectEqual(max - 1, snappy.BlockCursor.ringIndex(max, max - 1, 0));
    try std.testing.expectEqual(@as(usize, 1), snappy.BlockCursor.ringIndex(max, max - 1, 2));
    for (1..32) |capacity| for (0..capacity) |start| for (0..capacity) |displacement| {
        try std.testing.expectEqual((start + displacement) % capacity, snappy.BlockCursor.ringIndex(capacity, start, displacement));
    };
}

test "Snappy stream contracts raw cursor matches copy kinds overlap and output seed splits" {
    const cases = [_][]const u8{
        &.{ 12, 4, 'h', 'i', 0x19, 2 },
        &.{ 17, 8, 'a', 'b', 'c', 0x36, 3, 0 },
        &.{ 68, 28, '0', '1', '2', '3', '4', '5', '6', '7', 0xef, 8, 0, 0, 0 },
        &.{ 2, 0, 'a', 2, 1, 0 },
        &.{ 2, 0, 'a', 3, 1, 0, 0, 0 },
        &.{ 1, 0xfc, 0, 0, 0, 0, 'z' },
        &.{ 0x80, 0x80, 0x80, 0x80, 0 },
    };
    for (cases) |block| {
        const plan = try snappy.planBlock(block);
        const reference = try snappy.decodeBlockAlloc(allocator, block);
        defer allocator.free(reference);
        for ([_]usize{ 1, 2, 3, 7, 8, 15, 60, 256 }) |chunk| {
            var cursor = snappy.BlockCursor.init(plan);
            defer cursor.deinit(allocator);
            const output = try allocator.alloc(u8, plan.decoded_len);
            defer allocator.free(output);
            var written: usize = 0;
            while (true) {
                const end = @min(output.len, written + chunk);
                const step = try cursor.step(allocator, block, output[written..end]);
                written += step.output_written;
                if (step.done) break;
                try std.testing.expect(step.output_written != 0);
            }
            try std.testing.expectEqual(plan.decoded_len, written);
            try std.testing.expectEqualSlices(u8, reference, output);
            try std.testing.expect(cursor.historyCapacity() <= plan.max_offset);
        }
    }
    try std.testing.expectError(error.InvalidMatch, snappy.planBlock(&.{ 4, 0x0e, 0, 0 }));
    try std.testing.expectError(error.TrailingData, snappy.planBlock(&.{ 0, 0 }));
    try std.testing.expectError(error.TruncatedFrame, snappy.planBlock(&.{ 3, 8, 'a' }));
    const large_literal: []const u8 = &.{ 0xff, 0xff, 0xff, 0xff, 0x0f, 0xfc, 0xff, 0xff, 0xff, 0xff };
    try std.testing.expectError(if (@sizeOf(usize) == 4) error.IntegerOverflow else error.SizeMismatch, snappy.planBlock(large_literal));
}

test "Snappy stream contracts raw COPY4 retains the true distance above 64 KiB" {
    const seed = try allocator.alloc(u8, 65537);
    defer allocator.free(seed);
    for (seed, 0..) |*byte, i| byte.* = @intCast(i % 251);
    const block = try literalBlock(seed, true);
    defer allocator.free(block);
    const plan = try snappy.planBlock(block);
    try std.testing.expectEqual(@as(usize, 65537), plan.max_offset);
    const expected = try std.mem.concat(allocator, u8, &.{ seed, seed[0..64] });
    defer allocator.free(expected);
    const output = try allocator.alloc(u8, expected.len);
    defer allocator.free(output);
    var cursor = snappy.BlockCursor.init(plan);
    defer cursor.deinit(allocator);
    var written: usize = 0;
    while (true) {
        const step = try cursor.step(allocator, block, output[written..][0..@min(@as(usize, 31), output.len - written)]);
        written += step.output_written;
        if (step.done) break;
    }
    try std.testing.expectEqualSlices(u8, expected, output);
    const native = try framed(block, expected, true);
    defer allocator.free(native);
    var decoder = Decoder.init(allocator);
    defer decoder.deinit();
    try std.testing.expectError(error.CorruptFrame, decoder.step(native, &.{}));
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().output_written);
}

test "Snappy stream contracts native CRC and malformed body precede publication without decoded heap" {
    var plaintext: [4096]u8 = undefined;
    for (&plaintext, 0..) |*byte, i| byte.* = @truncate(i * 47);
    const block = try literalBlock(&plaintext, false);
    defer allocator.free(block);
    const frame = try framed(block, &plaintext, true);
    defer allocator.free(frame);
    var decoder = Decoder.init(allocator);
    defer decoder.deinit();
    const first = try decoder.step(frame, &.{});
    try std.testing.expectEqual(core.StepResult.Status.need_output, first.status);
    try std.testing.expectEqual(@as(usize, 0), first.progress.output_written);
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().history_capacity);
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().retained_decoded_capacity);
    try std.testing.expectEqual(decoder.chunk.capacity, decoder.workingMemoryBytes());
    var output: [plaintext.len]u8 = undefined;
    try drain(&decoder, frame, &output, first.progress.input_read, 0);
    try std.testing.expectEqualSlices(u8, &plaintext, &output);
    const corrupt = try allocator.dupe(u8, frame);
    defer allocator.free(corrupt);
    corrupt[14] ^= 1;
    decoder.reset();
    @memset(&output, 0xa5);
    try std.testing.expectError(error.ChecksumMismatch, decoder.step(corrupt, &output));
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().last_step_progress.output_written);
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    try std.testing.expectError(error.ChecksumMismatch, decoder.step(frame, &output));
    decoder.reset();
    const invalid = try framed(&.{ 4, 0x0e, 0, 0 }, "aaaa", true);
    defer allocator.free(invalid);
    try std.testing.expectError(error.InvalidMatch, decoder.step(invalid, &output));
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().output_written);
    // Keep the previous native error precedence for unknown unskippable
    // chunks, including streams that have not identified themselves yet.
    var startup = Decoder.initWithOptions(allocator, .{ .max_working_memory = 0 });
    defer startup.deinit();
    try std.testing.expectError(error.UnsupportedSnappyFeature, startup.step(&.{ 2, 0, 0, 0 }, &.{}));
    try std.testing.expectEqual(@as(usize, 0), startup.workingMemoryBytes());
}

test "Snappy stream contracts nondata streams under zero heap and commits captures only after completion" {
    var decoder = Decoder.initWithOptions(allocator, .{ .max_working_memory = 0, .max_total_output_len = 0, .expected_output_len = 0 });
    defer decoder.deinit();
    const identifier: []const u8 = &.{ 0xff, 6, 0, 0, 's', 'N', 'a', 'P', 'p', 'Y' };
    try std.testing.expectEqual(identifier.len, (try decoder.step(identifier, &.{})).progress.input_read);
    var capture: [11]u8 = undefined;
    var events: [1]Decoder.SkippableEvent = undefined;
    decoder.skippable_output = &capture;
    decoder.skippable_events = &events;
    const length: usize = 0x00ff_ffff;
    const header: []const u8 = &.{ 0xfe, 0xff, 0xff, 0xff };
    _ = try decoder.step(header, &.{});
    var scratch: [4096]u8 = @splat(0x42);
    _ = try decoder.step(scratch[0..7], &.{});
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().skippable_event_count);
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().skippable_written);
    try std.testing.expectError(error.TruncatedFrame, decoder.finish());
    var received: usize = 7;
    while (received < length) {
        const n = @min(scratch.len, length - received);
        _ = try decoder.step(scratch[0..n], &.{});
        received += n;
    }
    try decoder.finish();
    try std.testing.expectEqual(length, decoder.snapshot().skippable_total);
    try std.testing.expectEqual(@as(usize, 1), decoder.snapshot().skippable_event_count);
    try std.testing.expectEqual(@as(usize, 0), decoder.workingMemoryBytes());
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().retained_chunk_capacity);
    try std.testing.expectEqualStrings("", decoder.snapshot().last_error_name);
    try std.testing.expectEqualStrings("none", decoder.diagnostics().recoverability_hint_name);
    try std.testing.expectEqual(@as(?usize, null), decoder.snapshot().error_input_offset);
    try std.testing.expectEqual(@as(usize, length + 14), decoder.snapshot().total_input_read);
}

test "Snappy stream contracts next member preserves historical peak under a narrower future budget" {
    const first_plain: [65]u8 = @splat('a');
    var second_plain: [3000]u8 = @splat(0xab);
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(allocator);
    try appendChunk(&frame, 0xff, "sNaPpY");
    try appendData(&frame, &.{ 65, 0, 'a', 0xff, 1, 0, 0, 0 }, &first_plain, true);
    try appendData(&frame, &second_plain, &second_plain, false);
    var tracking = std.testing.FailingAllocator.init(allocator, .{ .resize_fail_index = 0 });
    var decoder = Decoder.initWithOptions(tracking.allocator(), .{ .max_total_output_len = 10000 });
    defer decoder.deinit();
    var output: [3065]u8 = undefined;
    try drain(&decoder, frame.items, &output, 0, 0);
    const peak = decoder.peakWorkingMemoryBytes();
    const live = decoder.workingMemoryBytes();
    try std.testing.expect(peak > live);
    try decoder.nextStream(.{ .max_working_memory = live, .max_output_len = 1, .expected_output_len = 1 });
    try std.testing.expectEqual(peak, decoder.peakWorkingMemoryBytes());
    try std.testing.expectEqual(live, decoder.options.max_working_memory);
    const next = try snappy.encodeFrameAlloc(allocator, "b");
    defer allocator.free(next);
    var next_output: [1]u8 = undefined;
    try drain(&decoder, next, &next_output, 0, 0);
    try decoder.nextStream(.{});
    try std.testing.expectEqual(live, decoder.options.max_working_memory);
    try std.testing.expectEqual(peak, decoder.peakWorkingMemoryBytes());
    var large_plain: [5000]u8 = @splat('x');
    const larger = try framed(&large_plain, &large_plain, false);
    defer allocator.free(larger);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, decoder.step(larger, &.{}));
    try std.testing.expectEqual(peak, decoder.peakWorkingMemoryBytes());
    try std.testing.expectEqual(@as(usize, 3066), decoder.snapshot().total_output);
}

test "Snappy stream contracts finish errors permit input repair and successful steps clear diagnostics" {
    const plain = "soft-boundary";
    const frame = try snappy.encodeFrameAlloc(allocator, plain);
    defer allocator.free(frame);
    var decoder = Decoder.initWithOptions(allocator, .{ .expected_output_len = plain.len });
    defer decoder.deinit();
    _ = try decoder.step(frame[0 .. frame.len - 1], &.{});
    try std.testing.expectError(error.TruncatedFrame, decoder.finish());
    try std.testing.expect(!decoder.input_finished);
    var output: [plain.len]u8 = undefined;
    _ = try decoder.step(frame[frame.len - 1 ..], &output);
    try std.testing.expectEqualStrings("", decoder.snapshot().last_error_name);
    try std.testing.expectEqualStrings("none", decoder.diagnostics().recoverability_hint_name);
    try std.testing.expectEqual(@as(?usize, null), decoder.snapshot().error_input_offset);
    try std.testing.expectEqual(@as(?usize, null), decoder.snapshot().error_output_offset);
    try decoder.finish();
    try std.testing.expectEqualSlices(u8, plain, &output);
    try decoder.resetWithOptions(.{ .expected_output_len = plain.len + 2 });
    _ = try decoder.step(frame, &output);
    try std.testing.expectError(error.SizeMismatch, decoder.finish());
    try std.testing.expect(!decoder.input_finished);
    const extra = try snappy.encodeFrameAlloc(allocator, "!!");
    defer allocator.free(extra);
    var extra_output: [2]u8 = undefined;
    _ = try decoder.step(extra, &extra_output);
    try decoder.finish();
    try std.testing.expectEqualStrings("", decoder.snapshot().last_error_name);
    try std.testing.expectEqualSlices(u8, "!!", &extra_output);
}
