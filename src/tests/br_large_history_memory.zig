//! Actual-history memory admission, retry and publication contracts.
const std = @import("std");
const h = @import("br_large_history_helpers.zig");
const tracking = @import("br_total_memory_helpers.zig");
const a = std.testing.allocator;

pub fn contracts(comptime Br: type) !void {
    const Cases = Suite(Br);
    try Cases.tinyAdvertisedWindow();
    try Cases.exactBudgetAndReset();
    try Cases.historyGrowthRefusal();
}

fn Suite(comptime Br: type) type {
    return struct {
        fn options(profile: ?*Br.EncodeMemoryProfile, limit: ?usize) Br.IncrementalPlannedStreamEncoder.Options {
            return .{ .stream = .{ .quality = 2, .large_window = true, .window_bits = 30, .block_len = 32768, .adaptive_blocks = false, .memory_profile = profile, .max_total_working_memory = limit }, .block_len = 0 };
        }

        fn tinyAdvertisedWindow() !void {
            errdefer std.debug.print("large-history tiny window30 memory\n", .{});
            var ledger = tracking.TrackingAllocator.init(a);
            ledger.force_moving_growth = true;
            var memory: Br.EncodeMemoryProfile = .{};
            var opts = options(&memory, null);
            opts.stream.block_len = 32;
            var encoder = Br.IncrementalPlannedStreamEncoder.initWithOptions(ledger.allocator(), opts);
            var alive = true;
            defer if (alive) encoder.deinit();
            const input = "tiny advertised window retains actual accepted history only";
            const wire = try h.drive(a, &encoder, input);
            defer a.free(wire);
            try h.expectHistory(&encoder, input, 30, true);
            try std.testing.expect(encoder.codec_state.history.capacity < 1024 * 1024);
            try std.testing.expect(memory.peak_requested_bytes < 16 * 1024 * 1024);
            try std.testing.expectEqual(ledger.peak, memory.peak_requested_bytes);
            try std.testing.expectEqual(ledger.live, encoder.memorySnapshot().live_requested_bytes);
            _ = try h.checkWire(Br, a, wire, input, 30, true);
            encoder.deinit();
            alive = false;
            try std.testing.expectEqual(@as(usize, 0), ledger.live);
            try std.testing.expectEqual(@as(usize, 0), memory.live_requested_bytes);
        }

        fn exactBudgetAndReset() !void {
            errdefer std.debug.print("large-history exact/below requested-byte budget\n", .{});
            const prefix = try h.prefixAlloc(a, 70000);
            defer a.free(prefix);
            const input = try h.repeatedAlloc(a, prefix, h.anchor_len);
            defer a.free(input);
            var measured = tracking.TrackingAllocator.init(a);
            measured.force_moving_growth = true;
            var measured_memory: Br.EncodeMemoryProfile = .{};
            var measured_encoder = Br.IncrementalPlannedStreamEncoder.initWithOptions(measured.allocator(), options(&measured_memory, null));
            var measured_alive = true;
            defer if (measured_alive) measured_encoder.deinit();
            const expected = try h.drive(a, &measured_encoder, input);
            defer a.free(expected);
            const peak = measured_memory.peak_requested_bytes;
            try std.testing.expect(peak > 0);
            try std.testing.expectEqual(measured.peak, peak);
            try h.expectHistory(&measured_encoder, input, 30, true);
            const summary = try h.checkWire(Br, a, expected, input, 30, true);
            try std.testing.expectEqual(prefix.len, summary.max_lz77_distance);
            measured_encoder.deinit();
            measured_alive = false;
            try std.testing.expectEqual(@as(usize, 0), measured.live);

            for ([_]bool{ true, false }) |exact| {
                var ledger = tracking.TrackingAllocator.init(a);
                ledger.force_moving_growth = true;
                var memory: Br.EncodeMemoryProfile = .{};
                var encoder = Br.IncrementalPlannedStreamEncoder.initWithOptions(ledger.allocator(), options(&memory, if (exact) peak else peak - 1));
                var alive = true;
                defer if (alive) encoder.deinit();
                if (exact) {
                    const wire = try h.drive(a, &encoder, input);
                    defer a.free(wire);
                    try std.testing.expectEqualSlices(u8, expected, wire);
                    try h.expectHistory(&encoder, input, 30, true);
                    try std.testing.expectEqual(peak, memory.peak_requested_bytes);
                } else {
                    try std.testing.expectError(error.WorkingMemoryLimitExceeded, h.drive(a, &encoder, input));
                    const snapshot = encoder.snapshot();
                    try std.testing.expect(snapshot.input_read <= input.len);
                    try std.testing.expect(snapshot.buffered_input <= snapshot.input_read);
                    const committed: usize = @intCast(snapshot.input_read - snapshot.buffered_input);
                    try h.expectHistory(&encoder, input[0..committed], 30, true);
                    try std.testing.expect(memory.peak_requested_bytes <= peak - 1);
                    // Already reported progress remains valid. Reset starts a
                    // new frame after removing the failed call's quota.
                    encoder.options.stream.max_total_working_memory = null;
                    encoder.reset();
                    try h.expectHistory(&encoder, "", 30, true);
                    const recovered = try h.drive(a, &encoder, input);
                    defer a.free(recovered);
                    try std.testing.expectEqualSlices(u8, expected, recovered);
                }
                try std.testing.expectEqual(ledger.live, encoder.memorySnapshot().live_requested_bytes);
                encoder.deinit();
                alive = false;
                try std.testing.expectEqual(@as(usize, 0), ledger.live);
                try std.testing.expectEqual(@as(usize, 0), memory.live_requested_bytes);
            }
        }

        fn historyGrowthRefusal() !void {
            errdefer std.debug.print("large-history targeted history-growth refusal\n", .{});
            const prefix = try h.prefixAlloc(a, 70000);
            defer a.free(prefix);
            const input = try h.repeatedAlloc(a, prefix, h.anchor_len);
            defer a.free(input);
            var ledger = tracking.TrackingAllocator.init(a);
            ledger.force_moving_growth = true;
            var growth: h.TargetedGrowthAllocator = .{ .backing = ledger.allocator() };
            const allocator = growth.allocator();
            var encoder = Br.IncrementalPlannedStreamEncoder.initWithOptions(allocator, options(null, null));
            var alive = true;
            defer if (alive) encoder.deinit();
            var wire: std.ArrayList(u8) = .empty;
            defer wire.deinit(a);
            try h.feed(a, &encoder, &wire, prefix, 4093, 4096);
            encoder.flush();
            try h.drain(a, &encoder, &wire, .need_input, 4096);
            try h.expectHistory(&encoder, prefix, 30, true);
            // Keep the same initialized history bytes in an exact allocation;
            // the next block now reaches the real history-reservation grow.
            const compact = try allocator.dupe(u8, encoder.codec_state.history.items);
            encoder.codec_state.history.deinit(allocator);
            encoder.codec_state.history = std.ArrayList(u8).fromOwnedSlice(compact);
            try h.feed(a, &encoder, &wire, input[prefix.len..], 7, 257);
            encoder.flush();
            const before = encoder.snapshot();
            const old_pending = try a.dupe(u8, encoder.pending.items);
            defer a.free(old_pending);
            const old_pointer = encoder.codec_state.history.items.ptr;
            const old_capacity = encoder.codec_state.history.capacity;
            const old_wire_state = encoder.codec_state.wire_state;
            const old_bit_index = encoder.codec_state.bit_index;
            const delivered = wire.items.len;
            growth.target = old_pointer;
            var output: [4096]u8 = @splat(0xa5);
            try std.testing.expectError(error.OutOfMemory, encoder.step("", &output));
            try std.testing.expect(growth.refused != 0);
            try h.untouched(&output);
            try std.testing.expectEqual(before.input_read, encoder.snapshot().input_read);
            try std.testing.expectEqual(before.output_written, encoder.snapshot().output_written);
            try std.testing.expectEqual(before.buffered_input, encoder.snapshot().buffered_input);
            try std.testing.expectEqual(delivered, wire.items.len);
            try std.testing.expectEqualSlices(u8, old_pending, encoder.pending.items);
            try std.testing.expectEqual(old_pointer, encoder.codec_state.history.items.ptr);
            try std.testing.expectEqual(old_capacity, encoder.codec_state.history.capacity);
            try std.testing.expectEqual(old_bit_index, encoder.codec_state.bit_index);
            try std.testing.expectEqual(old_wire_state, encoder.codec_state.wire_state);
            try h.expectHistory(&encoder, prefix, 30, true);
            growth.target = null;
            growth.fallback_len = null;
            try h.drain(a, &encoder, &wire, .need_input, 4096);
            try h.expectHistory(&encoder, input, 30, true);
            try encoder.finish();
            try h.drain(a, &encoder, &wire, .done, 4096);
            const summary = try h.checkWire(Br, a, wire.items, input, 30, true);
            try std.testing.expectEqual(prefix.len, summary.max_lz77_distance);
            encoder.deinit();
            alive = false;
            try std.testing.expectEqual(@as(usize, 0), ledger.live);
        }
    };
}
