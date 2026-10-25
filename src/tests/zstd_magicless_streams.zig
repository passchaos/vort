//! Explicit-format encoder/decoder progress, concatenation and reset contracts.
const std = @import("std");
const core = @import("../core.zig");
const h = @import("zstd_magicless_helpers.zig");
const a = std.testing.allocator;
const policies = [_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame };

pub fn contracts(comptime Z: type) !void {
    const Cases = Suite(Z);
    try Cases.encoderAndDecoder();
    try Cases.members();
    try Cases.errorsAndSmallBuffer();
    try Cases.skippableIdentity();
}
fn Suite(comptime Z: type) type {
    return struct {
        fn encoderAndDecoder() !void {
            const payload = h.plain ** 4;
            for ([_]bool{ true, false }) |exact| {
                const opts: Z.NativeFrameOptions = .{ .format = .magicless, .selection = .literal_only, .content_checksum = true, .include_content_size = exact, .block_size_max = 64, .window_log = 10 };
                var encoder = if (exact) try Z.NativeIncrementalFrameEncoder.initExactSize(a, opts, payload.len) else try Z.NativeIncrementalFrameEncoder.init(a, opts);
                defer encoder.deinit();
                const wire = try h.encodeDrive(a, &encoder, payload);
                defer a.free(wire);
                var normal_opts = opts;
                normal_opts.format = .standard;
                var normal_encoder = if (exact) try Z.NativeIncrementalFrameEncoder.initExactSize(a, normal_opts, payload.len) else try Z.NativeIncrementalFrameEncoder.init(a, normal_opts);
                defer normal_encoder.deinit();
                const normal = try h.encodeDrive(a, &normal_encoder, payload);
                defer a.free(normal);
                try std.testing.expectEqualSlices(u8, normal[4..], wire);
                try std.testing.expectEqual(@as(core.StreamCount, wire.len), encoder.snapshot().output_written);
                try std.testing.expectEqual(encoder.snapshot().output_written + 4, normal_encoder.snapshot().output_written);
                try std.testing.expectEqual(if (exact) @as(?u64, payload.len) else null, (try h.header(wire, true)).content_size);
                for (policies) |policy| {
                    var decoder = Z.NativeIncrementalFrameDecoder.initWithOptions(a, .{ .format = .magicless, .input_policy = policy, .expected_output_len = payload.len, .max_compressed_buffer_len = wire.len });
                    defer decoder.deinit();
                    const idle = try decoder.step("", &.{});
                    try std.testing.expectEqual(core.Progress{}, idle.progress);
                    try std.testing.expectEqual(.need_input, idle.status);
                    const decoded = try h.drive(a, &decoder, wire, payload.len, 1, 1);
                    defer a.free(decoded.output);
                    try std.testing.expectEqual(wire.len, decoded.consumed);
                    try std.testing.expectEqualSlices(u8, payload, decoded.output);
                    try std.testing.expectEqual(@as(core.StreamCount, wire.len), decoder.snapshot().input_received);
                    try std.testing.expectEqual(@as(core.StreamCount, payload.len), decoder.snapshot().output_written);
                    try decoder.finish();
                }
                const decode_opts: Z.FrameDecodeOptions = .{ .format = .magicless, .expected_output_len = payload.len, .max_output_len = payload.len };
                var reusable = Z.NativeFrameDecoder.initWithOptions(a, decode_opts);
                defer reusable.deinit();
                try std.testing.expectEqualSlices(u8, payload, try reusable.decodeScratch(wire));
                try std.testing.expectEqual(payload.len, try reusable.decodedSize(wire));
                var output: [payload.len + 17]u8 = @splat(0xa5);
                try std.testing.expectEqual(payload.len, try reusable.decodeIntoSlice(wire, &output));
                try std.testing.expectEqualSlices(u8, payload, output[0..payload.len]);
                try h.untouched(output[payload.len..]);
                var appended: std.ArrayList(u8) = .empty;
                defer appended.deinit(a);
                try std.testing.expectEqual(payload.len, try reusable.decodeAppendWithOptions(&appended, wire, decode_opts));
                try std.testing.expectEqualSlices(u8, payload, appended.items);
                try std.testing.expectEqualSlices(u8, payload, try reusable.decodeScratchWithOptions(normal, .{ .expected_output_len = payload.len }));
            }
        }

        fn members() !void {
            const first = try h.rawAlloc(a, "first", false);
            defer a.free(first);
            const last = try h.rawAlloc(a, "last", true);
            defer a.free(last);
            const joined = try std.mem.concat(a, u8, &.{ first, last });
            defer a.free(joined);
            try h.check(Z, a, joined, "firstlast", .{ .format = .magicless, .expected_output_len = 9 });
            const normal_first = try h.standardAlloc(a, first);
            defer a.free(normal_first);
            const normal_last = try h.standardAlloc(a, last);
            defer a.free(normal_last);
            const skip = try Z.encodeSkippableFrameAlloc(a, 0, "meta");
            defer a.free(skip);
            const normal_joined = try std.mem.concat(a, u8, &.{ normal_first, skip, normal_last });
            defer a.free(normal_joined);
            try h.check(Z, a, normal_joined, "firstlast", .{ .expected_output_len = 9 });
            const mixed = try std.mem.concat(a, u8, &.{ first, normal_last });
            defer a.free(mixed);
            try std.testing.expectError(error.CorruptFrame, Z.decodeFrameAllocWithOptions(a, mixed, .{ .format = .magicless }));
            const wrong_standard = try std.mem.concat(a, u8, &.{ normal_first, last });
            defer a.free(wrong_standard);
            try std.testing.expectError(error.InvalidMagic, Z.decodeFrameAllocWithOptions(a, wrong_standard, .{}));
            for (policies) |policy| {
                var decoder = Z.NativeIncrementalFrameDecoder.initWithOptions(a, .{ .format = .magicless, .input_policy = policy, .stop_after_first_frame = true, .max_compressed_buffer_len = joined.len });
                defer decoder.deinit();
                const one = try h.drive(a, &decoder, joined, 9, joined.len, 1);
                defer a.free(one.output);
                try std.testing.expectEqualStrings("first", one.output);
                try std.testing.expectEqual(first.len + decoder.trailingInput().len, one.consumed);
                try std.testing.expectEqualSlices(u8, joined[first.len..one.consumed], decoder.trailingInput());
                try decoder.nextStream();
                const two = try h.drive(a, &decoder, joined[one.consumed..], 4, joined.len, 1);
                defer a.free(two.output);
                try std.testing.expectEqualStrings("last", two.output);
                try std.testing.expectEqual(@as(core.StreamCount, joined.len), decoder.snapshot().input_received);
                try std.testing.expectEqual(@as(core.StreamCount, 9), decoder.snapshot().output_written);
                try std.testing.expectEqual(@as(core.StreamCount, 2), decoder.snapshot().data_frame_count);
                try std.testing.expectEqual(@as(usize, 0), decoder.trailingInput().len);
                try decoder.finish();
                decoder.reset();
                const reset = try h.drive(a, &decoder, first, 5, 1, 1);
                defer a.free(reset.output);
                try std.testing.expectEqualStrings("first", reset.output);
                try std.testing.expectEqual(@as(core.StreamCount, first.len), decoder.snapshot().input_received);
                try decoder.finish();
            }
        }

        fn errorsAndSmallBuffer() !void {
            const wire = try h.rawAlloc(a, h.plain, true);
            defer a.free(wire);
            for (policies) |policy| {
                for ([_]usize{ 1, 4, wire.len - 5, wire.len - 1 }) |cut| {
                    var decoder = Z.NativeIncrementalFrameDecoder.initWithOptions(a, .{ .format = .magicless, .input_policy = policy, .expected_output_len = h.plain.len });
                    defer decoder.deinit();
                    var output: [h.plain.len + 17]u8 = @splat(0xa5);
                    const step = try decoder.step(wire[0..cut], &output);
                    try std.testing.expectEqual(.need_input, step.status);
                    try std.testing.expectEqual(cut, step.progress.input_read);
                    try h.untouched(output[step.progress.output_written..]);
                    try std.testing.expectError(error.TruncatedFrame, decoder.finish());
                }
                const corrupt = try a.dupe(u8, wire);
                defer a.free(corrupt);
                corrupt[corrupt.len - 1] ^= 1;
                var bad = Z.NativeIncrementalFrameDecoder.initWithOptions(a, .{ .format = .magicless, .input_policy = policy, .expected_output_len = h.plain.len });
                defer bad.deinit();
                try std.testing.expectError(error.ChecksumMismatch, h.drive(a, &bad, corrupt, h.plain.len, 3, 1));
                const stopped = bad.snapshot();
                var output: [17]u8 = @splat(0xa5);
                try std.testing.expectError(error.ChecksumMismatch, bad.step("", &output));
                try std.testing.expectEqual(stopped.input_received, bad.snapshot().input_received);
                try std.testing.expectEqual(stopped.output_written, bad.snapshot().output_written);
                try h.untouched(&output);
            }
            const payload = try a.alloc(u8, 128 * 1024 + 3);
            defer a.free(payload);
            for (payload, 0..) |*byte, index| byte.* = @truncate(index *% 37 +% index / 251);
            const large = try h.rawAlloc(a, payload, true);
            defer a.free(large);
            var bounded = Z.NativeIncrementalFrameDecoder.initWithOptions(a, .{ .format = .magicless, .input_policy = .block_stream, .expected_output_len = payload.len, .max_compressed_buffer_len = 16, .max_working_memory = 512 * 1024 });
            defer bounded.deinit();
            const decoded = try h.drive(a, &bounded, large, payload.len, 4096, 257);
            defer a.free(decoded.output);
            try std.testing.expectEqual(large.len, decoded.consumed);
            try std.testing.expectEqualSlices(u8, payload, decoded.output);
            try std.testing.expect(bounded.compressedBufferCapacity() <= 16);
            try std.testing.expect(bounded.peakWorkingMemoryBytes() <= 512 * 1024);
            try bounded.finish();
        }

        fn skippableIdentity() !void {
            var heap = std.testing.FailingAllocator.init(a, .{});
            var encoder = try Z.NativeIncrementalFrameEncoder.initExactSize(heap.allocator(), .{ .format = .magicless, .selection = .raw_or_rle, .content_checksum = false }, 1);
            defer encoder.deinit();
            const wire = try h.encodeDrive(a, &encoder, "x");
            defer a.free(wire);
            const before = encoder.snapshot();
            const allocations = heap.alloc_index;
            heap.fail_index = allocations;
            try std.testing.expectError(error.InvalidBlockPlan, encoder.writeSkippable(8, "meta"));
            try std.testing.expectEqual(allocations, heap.alloc_index);
            try std.testing.expect(!heap.has_induced_failure);
            try std.testing.expectEqual(before, encoder.snapshot());
            const skip = try Z.encodeSkippableFrameAlloc(a, 8, "meta");
            defer a.free(skip);
            var decoder = Z.NativeIncrementalFrameDecoder.initWithOptions(a, .{ .format = .magicless });
            defer decoder.deinit();
            try std.testing.expectError(error.CorruptFrame, decoder.step(skip, &.{}));
            try std.testing.expectEqual(@as(core.StreamCount, 0), decoder.snapshot().skippable_event_count);
            try std.testing.expectEqual(@as(core.StreamCount, 0), decoder.snapshot().output_written);
        }
    };
}
