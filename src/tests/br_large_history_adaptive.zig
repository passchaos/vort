//! Adaptive Large Window branches with real retained history and atomic retry.
//! The caller supplies Br; this module does not import the codec root.
const std = @import("std");
const h = @import("br_large_history_helpers.zig");
const tracking = @import("br_total_memory_helpers.zig");
const a = std.testing.allocator;
const prefix_len: usize = 70000;
const block_len: usize = 65536;

pub fn contracts(comptime Br: type) !void {
    const prefix = try h.prefixAlloc(a, prefix_len);
    defer a.free(prefix);
    const input = try a.alloc(u8, prefix_len + block_len);
    defer a.free(input);
    @memcpy(input[0..prefix_len], prefix);
    for (input[prefix_len..], 0..) |*byte, index| {
        const quarter = index / (block_len / 4);
        byte.* = if (quarter & 1 == 0) @intCast(index & 15) else @intCast(240 + (index & 15));
    }
    // A profitable far copy starts in history from earlier emitted blocks.
    @memcpy(input[prefix_len..][0..h.anchor_len], prefix[0..h.anchor_len]);
    const Cases = Suite(Br);
    const expected = try Cases.measure(input);
    defer a.free(expected.wire);
    try Cases.budgets(input, expected.wire, expected.peak);
    try Cases.growthRefusals(input, expected.wire);
}

fn Suite(comptime Br: type) type {
    return struct {
        fn options(profile: ?*Br.EncodeMemoryProfile, limit: ?usize) Br.IncrementalPlannedStreamEncoder.Options {
            return .{ .stream = .{ .quality = 2, .large_window = true, .window_bits = 25, .block_len = block_len, .adaptive_blocks = true, .memory_profile = profile, .max_total_working_memory = limit }, .block_len = 0 };
        }

        fn prefix(encoder: anytype, wire: *std.ArrayList(u8), input: []const u8) !void {
            try h.feed(a, encoder, wire, input[0..prefix_len], 4093, 4096);
            encoder.flush();
            try h.drain(a, encoder, wire, .need_input, 4096);
            try h.expectHistory(encoder, input[0..prefix_len], 25, true);
            try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().buffered_input);
            try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().pending_output);
            try std.testing.expectEqual(@as(Br.IncrementalPlannedStreamEncoder.Counter, prefix_len), encoder.codec_state.wire_state.output_pos);
        }

        fn checkBranches(encoder: anytype, input: []const u8) !void {
            try h.expectHistory(encoder, input, 25, true);
            // These populated independent histories prove that the actual
            // adaptive snapshot, halves and grid paths were evaluated.
            try std.testing.expectEqualSlices(u8, input[0..prefix_len], encoder.codec_state.history_snapshot.items);
            try std.testing.expectEqualSlices(u8, input, encoder.codec_state.adaptive_split_history.items);
            try std.testing.expectEqualSlices(u8, input, encoder.codec_state.adaptive_grid_history.items);
            try std.testing.expectEqual(@as(Br.IncrementalPlannedStreamEncoder.Counter, input.len), encoder.codec_state.wire_state.output_pos);
        }

        fn finish(encoder: anytype, wire: *std.ArrayList(u8), input: []const u8) !void {
            try checkBranches(encoder, input);
            try encoder.finish();
            try h.drain(a, encoder, wire, .done, 4096);
            try checkBranches(encoder, input);
            const summary = try h.checkWire(Br, a, wire.items, input, 25, true);
            try std.testing.expect(summary.max_lz77_distance >= prefix_len);
        }

        fn run(encoder: anytype, input: []const u8) ![]u8 {
            var wire: std.ArrayList(u8) = .empty;
            errdefer wire.deinit(a);
            try prefix(encoder, &wire, input);
            try h.feed(a, encoder, &wire, input[prefix_len..], block_len, 4096);
            try finish(encoder, &wire, input);
            return wire.toOwnedSlice(a);
        }

        const Measured = struct { wire: []u8, peak: usize };
        fn measure(input: []const u8) !Measured {
            errdefer std.debug.print("large-history adaptive actual-history baseline\n", .{});
            var ledger = tracking.TrackingAllocator.init(a);
            ledger.force_moving_growth = true;
            var profile: Br.EncodeMemoryProfile = .{};
            var encoder = Br.IncrementalPlannedStreamEncoder.initWithOptions(ledger.allocator(), options(&profile, null));
            var alive = true;
            defer if (alive) encoder.deinit();
            const wire = try run(&encoder, input);
            errdefer a.free(wire);
            const peak = profile.peak_requested_bytes;
            try std.testing.expect(peak > 0);
            try std.testing.expectEqual(ledger.peak, peak);
            try std.testing.expectEqual(ledger.live, encoder.memorySnapshot().live_requested_bytes);
            encoder.deinit();
            alive = false;
            try std.testing.expectEqual(@as(usize, 0), ledger.live);
            try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
            return .{ .wire = wire, .peak = peak };
        }

        fn budgets(input: []const u8, expected: []const u8, peak: usize) !void {
            for ([_]bool{ true, false }) |exact| {
                errdefer std.debug.print("large-history adaptive exact-budget={any}\n", .{exact});
                var ledger = tracking.TrackingAllocator.init(a);
                ledger.force_moving_growth = true;
                var profile: Br.EncodeMemoryProfile = .{};
                var encoder = Br.IncrementalPlannedStreamEncoder.initWithOptions(ledger.allocator(), options(&profile, if (exact) peak else peak - 1));
                var alive = true;
                defer if (alive) encoder.deinit();
                if (exact) {
                    const wire = try run(&encoder, input);
                    defer a.free(wire);
                    try std.testing.expectEqualSlices(u8, expected, wire);
                    try std.testing.expectEqual(peak, profile.peak_requested_bytes);
                } else {
                    try std.testing.expectError(error.WorkingMemoryLimitExceeded, run(&encoder, input));
                    const snapshot = encoder.snapshot();
                    try std.testing.expect(snapshot.input_read <= input.len);
                    try std.testing.expect(snapshot.buffered_input <= snapshot.input_read);
                    const committed: usize = @intCast(snapshot.input_read - snapshot.buffered_input);
                    try h.expectHistory(&encoder, input[0..committed], 25, true);
                    try std.testing.expect(profile.peak_requested_bytes <= peak - 1);
                    encoder.options.stream.max_total_working_memory = null;
                    encoder.reset();
                    try h.expectHistory(&encoder, "", 25, true);
                    const recovered = try run(&encoder, input);
                    defer a.free(recovered);
                    try std.testing.expectEqualSlices(u8, expected, recovered);
                }
                encoder.deinit();
                alive = false;
                try std.testing.expectEqual(@as(usize, 0), ledger.live);
                try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
            }
        }

        const Target = enum { history, snapshot, branch_snapshot };
        fn growthRefusals(input: []const u8, expected: []const u8) !void {
            for ([_]Target{ .history, .snapshot, .branch_snapshot }) |variant| {
                errdefer std.debug.print("large-history adaptive growth target={s}\n", .{@tagName(variant)});
                var ledger = tracking.TrackingAllocator.init(a);
                ledger.force_moving_growth = true;
                var growth: h.TargetedGrowthAllocator = .{ .backing = ledger.allocator() };
                const allocator = growth.allocator();
                var encoder = Br.IncrementalPlannedStreamEncoder.initWithOptions(allocator, options(null, null));
                var alive = true;
                defer if (alive) encoder.deinit();
                var wire: std.ArrayList(u8) = .empty;
                defer wire.deinit(a);
                try prefix(&encoder, &wire, input);
                const target: *std.ArrayList(u8) = switch (variant) {
                    .history => &encoder.codec_state.history,
                    .snapshot => &encoder.codec_state.history_snapshot,
                    .branch_snapshot => &encoder.codec_state.adaptive_split_history,
                };
                // Give the selected container a known allocation, so refusal
                // is identified by its real pointer rather than request order.
                const compact = try allocator.dupe(u8, if (variant == .history) target.items else &.{0xb7});
                target.deinit(allocator);
                target.* = std.ArrayList(u8).fromOwnedSlice(compact);
                const old_target = try a.dupe(u8, target.items);
                defer a.free(old_target);
                const old_target_pointer = target.items.ptr;
                const old_target_capacity = target.capacity;
                const old_pending = try a.dupe(u8, encoder.pending.items);
                defer a.free(old_pending);
                const old_wire = try a.dupe(u8, wire.items);
                defer a.free(old_wire);
                const before = encoder.snapshot();
                const old_bit_index = encoder.codec_state.bit_index;
                const old_wire_state = encoder.codec_state.wire_state;
                const old_previous = encoder.codec_state.context_previous;
                growth.target = old_target_pointer;
                var output: [4096]u8 = @splat(0xa5);
                try std.testing.expectError(error.OutOfMemory, encoder.step(input[prefix_len..], &output));
                try std.testing.expect(growth.refused != 0);
                try h.untouched(&output);
                // Source acceptance remains visible; the entire adaptive
                // block is buffered while prior committed output/history stay.
                try std.testing.expectEqual(@as(Br.IncrementalPlannedStreamEncoder.Counter, input.len), encoder.snapshot().input_read);
                try std.testing.expectEqual(block_len, encoder.snapshot().buffered_input);
                try std.testing.expectEqual(before.output_written, encoder.snapshot().output_written);
                try std.testing.expectEqualSlices(u8, input[prefix_len..], encoder.plain.items);
                try std.testing.expectEqualSlices(u8, old_wire, wire.items);
                try std.testing.expectEqualSlices(u8, old_pending, encoder.pending.items);
                try std.testing.expectEqual(old_bit_index, encoder.codec_state.bit_index);
                try std.testing.expectEqual(old_wire_state, encoder.codec_state.wire_state);
                try std.testing.expectEqual(old_previous, encoder.codec_state.context_previous);
                try h.expectHistory(&encoder, input[0..prefix_len], 25, true);
                try std.testing.expectEqual(old_target_pointer, target.items.ptr);
                try std.testing.expectEqual(old_target_capacity, target.capacity);
                try std.testing.expectEqualSlices(u8, old_target, target.items);
                growth.target = null;
                growth.fallback_len = null;
                try h.drain(a, &encoder, &wire, .need_input, 4096);
                try finish(&encoder, &wire, input);
                try std.testing.expectEqualSlices(u8, expected, wire.items);
                encoder.deinit();
                alive = false;
                try std.testing.expectEqual(@as(usize, 0), ledger.live);
            }
        }
    };
}
