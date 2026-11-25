const std = @import("std");
const core = @import("../../core.zig");
const testing = std.testing;
const Count = core.StreamCount;
const policies = [_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame };
const header_len = 8;

pub fn contracts(comptime Zstd: type) !void {
    const Decoder = Zstd.NativeIncrementalFrameDecoder;
    for (policies) |policy| {
        try fragmented(Decoder, policy);
        try stopAndResume(Zstd, policy);
        try truncatedAndMalformed(Decoder, policy);
        try headerAdmission(Decoder, policy);
    }
}

fn header(id: u4, len: u32) [header_len]u8 {
    var bytes: [header_len]u8 = undefined;
    std.mem.writeInt(u32, bytes[0..4], 0x184d2a50 + @as(u32, id), .little);
    std.mem.writeInt(u32, bytes[4..8], len, .little);
    return bytes;
}

const Frame = struct {
    id: u4,
    frame_offset: Count,
    payload: []const u8,
    // Set for a valid header whose body will never be fed in full.
    declared_len: ?u32 = null,
};

fn Recorder(comptime Decoder: type) type {
    return struct {
        expected: []const Frame,
        starts: usize = 0,
        offset: usize = 0,
        failure: ?anyerror = null,

        const Self = @This();

        fn observer(self: *Self) Decoder.SkippableObserver {
            return .{ .context = self, .on_event = onEvent };
        }

        fn onEvent(context: ?*anyopaque, event: Decoder.SkippableObservation) void {
            const self: *Self = @ptrCast(@alignCast(context.?));
            if (self.failure == null) self.record(event) catch |err| {
                self.failure = err;
            };
        }

        fn record(self: *Self, event: Decoder.SkippableObservation) !void {
            switch (event) {
                .start => |start| {
                    try testing.expect(self.starts < self.expected.len);
                    if (self.starts != 0)
                        try testing.expectEqual(self.expected[self.starts - 1].payload.len, self.offset);
                    const frame = self.expected[self.starts];
                    try testing.expectEqual(@as(Count, self.starts), start.skippable_index);
                    try testing.expectEqual(frame.id, start.id);
                    try testing.expectEqual(frame.frame_offset, start.frame_offset);
                    try testing.expectEqual(frame.declared_len orelse @as(u32, @intCast(frame.payload.len)), start.payload_len);
                    self.starts += 1;
                    self.offset = 0;
                },
                .chunk => |chunk| {
                    try testing.expect(self.starts != 0);
                    const frame = self.expected[self.starts - 1];
                    try testing.expectEqual(@as(Count, self.starts - 1), chunk.skippable_index);
                    try testing.expectEqual(frame.id, chunk.id);
                    try testing.expectEqual(@as(u32, @intCast(self.offset)), chunk.offset);
                    try testing.expect(chunk.bytes.len != 0 and chunk.bytes.len <= frame.payload.len - self.offset);
                    // Inspect borrowed bytes during the callback; do not retain
                    // pointers or assume any particular split within a step.
                    try testing.expectEqualSlices(u8, frame.payload[self.offset..][0..chunk.bytes.len], chunk.bytes);
                    self.offset += chunk.bytes.len;
                },
            }
        }

        fn seen(self: *const Self, starts: usize, offset: usize) !void {
            if (self.failure) |err| return err;
            try testing.expectEqual(starts, self.starts);
            try testing.expectEqual(offset, self.offset);
        }
    };
}

fn metadataStep(decoder: anytype, input: []const u8, status: core.StepResult.Status) !void {
    const step = try decoder.step(input, &.{});
    try testing.expectEqual(status, step.status);
    try testing.expectEqual(core.Progress{ .input_read = input.len }, step.progress);
}

fn fragmented(comptime Decoder: type, policy: core.CompressedInputPolicy) !void {
    const a = testing.allocator;
    const large = try a.alloc(u8, 128 * 1024 + 17);
    defer a.free(large);
    for (large, 0..) |*byte, i| byte.* = @truncate(i ^ (i >> 8));

    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    var expected: [16]Frame = undefined;
    for (&expected, 0..) |*frame, i| {
        const id: u4 = @intCast(i);
        const payload: []const u8 = switch (id) {
            1 => large,
            15 => "end",
            else => "",
        };
        frame.* = .{ .id = id, .frame_offset = wire.items.len, .payload = payload };
        try wire.appendSlice(a, &header(id, @intCast(payload.len)));
        try wire.appendSlice(a, payload);
    }

    var log: Recorder(Decoder) = .{ .expected = &expected };
    var decoder = Decoder.initWithOptions(a, .{
        .input_policy = policy,
        .max_compressed_buffer_len = header_len,
        .max_output_len = 0,
        .max_decoded_buffer_len = 0,
        .expected_output_len = 0,
        .skippable_observer = log.observer(),
    });
    defer decoder.deinit();

    for (0..header_len - 1) |i| {
        try metadataStep(&decoder, wire.items[i..][0..1], .need_input);
        try log.seen(0, 0);
    }
    try metadataStep(&decoder, wire.items[header_len - 1 .. header_len], .done);
    try log.seen(1, 0);
    const body_start = 2 * header_len;
    try metadataStep(&decoder, wire.items[header_len..body_start], .need_input);
    try log.seen(2, 0);
    try metadataStep(&decoder, wire.items[body_start..][0..1], .need_input);
    try log.seen(2, 1);
    try metadataStep(&decoder, wire.items[body_start + 1 ..][0..4097], .need_input);
    try log.seen(2, 4098);
    try testing.expectEqual(@as(usize, 0), decoder.compressedBufferedBytes());
    try testing.expect(decoder.compressedBufferCapacity() <= header_len);

    // The remainder carries the end of the large payload and multiple frames.
    try metadataStep(&decoder, wire.items[body_start + 4098 ..], .done);
    try log.seen(expected.len, expected[15].payload.len);
    try decoder.finish();
    try metadataStep(&decoder, &.{}, .done);
    try log.seen(expected.len, expected[15].payload.len);
    const snap = decoder.snapshot();
    try testing.expectEqual(@as(Count, 0), snap.output_written);
    try testing.expectEqual(@as(Count, wire.items.len), snap.input_received);
    try expectCapture(snap, 0, large.len + expected[15].payload.len, expected.len, 0);
}

fn stopAndResume(comptime Zstd: type, policy: core.CompressedInputPolicy) !void {
    const Decoder = Zstd.NativeIncrementalFrameDecoder;
    const a = testing.allocator;
    const plain = "first member plaintext";
    const before = header(13, 1) ++ "L".*;
    const payload = "buffered prefix then caller bytes";
    const after = header(9, payload.len) ++ payload.*;
    const empty = header(2, 0);
    const data = try Zstd.encodeRawOrRleFrameWithOptionsAlloc(a, plain, .{ .content_checksum = false });
    defer a.free(data);
    const wire = try std.mem.concat(a, u8, &.{ &before, data, &after, &empty });
    defer a.free(wire);
    const after_offset = before.len + data.len;
    const expected = [_]Frame{
        .{ .id = 13, .frame_offset = 0, .payload = "L" },
        .{ .id = 9, .frame_offset = after_offset, .payload = payload },
        .{ .id = 2, .frame_offset = after_offset + after.len, .payload = "" },
    };
    var log: Recorder(Decoder) = .{ .expected = &expected };
    const buffered_body = 3;
    const buffered = after[0 .. header_len + buffered_body];
    var decoder = Decoder.initWithOptions(a, .{
        .input_policy = policy,
        .stop_after_first_frame = true,
        .max_compressed_buffer_len = data.len + buffered.len,
        .max_output_len = plain.len,
        .expected_output_len = plain.len,
        .skippable_observer = log.observer(),
    });
    defer decoder.deinit();

    const blocked = try decoder.step(wire, &.{});
    try testing.expectEqual(.need_output, blocked.status);
    try testing.expectEqual(@as(usize, 0), blocked.progress.output_written);
    var read = blocked.progress.input_read;
    if (policy == .prevalidated_frame)
        try testing.expectEqual(after_offset + buffered.len, read)
    else
        try testing.expect(read <= after_offset);
    try log.seen(1, 1);
    const still_blocked = try decoder.step(wire[read..], &.{});
    try testing.expectEqual(.need_output, still_blocked.status);
    try testing.expectEqual(core.Progress{}, still_blocked.progress);
    try log.seen(1, 1);

    var output: [plain.len]u8 = undefined;
    const stopped = try decoder.step(wire[read..], &output);
    read += stopped.progress.input_read;
    try testing.expectEqual(.done, stopped.status);
    try testing.expectEqual(plain.len, stopped.progress.output_written);
    try testing.expectEqualSlices(u8, plain, &output);
    try testing.expectEqualSlices(u8, if (policy == .prevalidated_frame) buffered else &.{}, decoder.trailingInput());
    const paused = try decoder.step(wire[read..], &.{});
    try testing.expectEqual(.done, paused.status);
    try testing.expectEqual(core.Progress{}, paused.progress);
    try decoder.finish();
    try log.seen(1, 1);

    try decoder.nextStream();
    try log.seen(1, 1);
    if (policy == .prevalidated_frame) {
        // These bytes were counted during preflight of the previous member.
        // They are observed only now, even with no new caller input.
        try metadataStep(&decoder, &.{}, .need_input);
        try log.seen(2, buffered_body);
    } else {
        try testing.expectEqual(after_offset, read);
    }
    try metadataStep(&decoder, wire[read..], .done);
    try decoder.finish();
    try log.seen(3, 0);
    const snap = decoder.snapshot();
    try testing.expectEqual(@as(Count, wire.len), snap.input_received);
    try testing.expectEqual(@as(Count, plain.len), snap.output_written);
    try testing.expectEqual(@as(Count, 1), snap.data_frame_count);
}

fn expectCapture(snap: anytype, written: usize, total: Count, events: Count, captured: usize) !void {
    try testing.expectEqual(written, snap.skippable_written);
    try testing.expectEqual(total, snap.skippable_total);
    try testing.expectEqual(written != total, snap.skippable_truncated);
    try testing.expectEqual(events, snap.skippable_event_count);
    try testing.expectEqual(captured, snap.skippable_events_captured);
}

fn truncatedAndMalformed(comptime Decoder: type, policy: core.CompressedInputPolicy) !void {
    const first = header(4, 2) ++ "ab".*;
    const second = header(12, 5) ++ "CDEFG".*;
    const third = header(7, 2) ++ "hi".*;
    const malformed = [_]u8{ 0x60, 0x2a, 0x4d, 0x18, 0, 0, 0, 0 } ++ header(10, 0);
    const expected = [_]Frame{
        .{ .id = 4, .frame_offset = 0, .payload = "ab" },
        .{ .id = 12, .frame_offset = first.len, .payload = "CDEFG" },
        .{ .id = 7, .frame_offset = first.len + second.len, .payload = "hi" },
    };
    var log: Recorder(Decoder) = .{ .expected = &expected };
    var capture: [3]u8 = undefined;
    const sentinel: Decoder.SkippableEvent = .{ .id = 15, .payload_len = 99 };
    var events = [_]Decoder.SkippableEvent{sentinel} ** 2;
    var decoder = Decoder.initWithOptions(testing.allocator, .{
        .input_policy = policy,
        .max_compressed_buffer_len = header_len,
        .skippable_observer = log.observer(),
        .skippable_output = &capture,
        .skippable_events = &events,
    });
    defer decoder.deinit();
    try metadataStep(&decoder, &first, .done);
    try log.seen(1, 2);
    try expectCapture(decoder.snapshot(), 2, 2, 1, 1);
    try testing.expectEqual(Decoder.SkippableEvent{ .id = 4, .payload_len = 2 }, events[0]);

    try metadataStep(&decoder, second[0 .. header_len - 1], .need_input);
    try testing.expectError(error.TruncatedFrame, decoder.finish());
    try log.seen(1, 2);
    try metadataStep(&decoder, second[header_len - 1 .. header_len], .need_input);
    try log.seen(2, 0);
    try metadataStep(&decoder, second[header_len..][0..2], .need_input);
    try log.seen(2, 2);
    try testing.expectError(error.TruncatedFrame, decoder.finish());
    try testing.expectError(error.TruncatedFrame, decoder.finish());
    try metadataStep(&decoder, &.{}, .need_input);
    try log.seen(2, 2);
    // The callback has seen a prefix. Legacy counters and entries describe only
    // the completed first frame; uncommitted capture bytes are not inspected.
    try expectCapture(decoder.snapshot(), 2, 2, 1, 1);
    try testing.expectEqual(sentinel, events[1]);

    try metadataStep(&decoder, second[header_len + 2 ..], .done);
    try log.seen(2, 5);
    try expectCapture(decoder.snapshot(), 3, 7, 2, 2);
    try testing.expectEqual(Decoder.SkippableEvent{ .id = 12, .payload_len = 5 }, events[1]);
    try metadataStep(&decoder, &third, .done);
    try log.seen(3, 2);
    try expectCapture(decoder.snapshot(), 3, 9, 3, 2);
    try testing.expectEqualSlices(u8, "abC", &capture);

    try testing.expectError(error.InvalidMagic, decoder.step(&malformed, &.{}));
    try testing.expectError(error.InvalidMagic, decoder.step(&first, &.{}));
    try log.seen(3, 2);
    try expectCapture(decoder.snapshot(), 3, 9, 3, 2);
    decoder.reset();
    try log.seen(3, 2);
    log = .{ .expected = expected[0..1] };
    try expectCapture(decoder.snapshot(), 0, 0, 0, 0);
    try metadataStep(&decoder, &first, .done);
    try decoder.finish();
    try log.seen(1, 2);
}

fn headerAdmission(comptime Decoder: type, policy: core.CompressedInputPolicy) !void {
    const wide_len = std.math.maxInt(u32);
    const wide = header(15, wide_len) ++ "xy".*;
    const empty = header(0, 0);
    const expected = [_]Frame{.{ .id = 15, .frame_offset = 0, .payload = "xy", .declared_len = wide_len }};
    var log: Recorder(Decoder) = .{ .expected = &expected };
    var options: Decoder.Options = .{
        .input_policy = policy,
        .max_compressed_buffer_len = header_len - 1,
        .skippable_observer = log.observer(),
    };
    var decoder = Decoder.initWithOptions(testing.allocator, options);
    defer decoder.deinit();
    try testing.expectError(error.OutputLimitExceeded, decoder.step(&wide, &.{}));
    try log.seen(0, 0);

    options.max_compressed_buffer_len = header_len;
    try decoder.resetWithOptions(options);
    try metadataStep(&decoder, wide[0..header_len], .need_input);
    try log.seen(1, 0);
    try metadataStep(&decoder, wide[header_len..], .need_input);
    try log.seen(1, 2);
    try testing.expectError(error.TruncatedFrame, decoder.finish());
    try expectCapture(decoder.snapshot(), 0, 0, 0, 0);
    decoder.reset();
    try log.seen(1, 2);
    const fresh = [_]Frame{.{ .id = 0, .frame_offset = 0, .payload = "" }};
    log = .{ .expected = &fresh };
    try metadataStep(&decoder, &empty, .done);
    try log.seen(1, 0);
}
