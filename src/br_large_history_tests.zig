//! Public actual-history contracts for general Large Window Brotli encoders.
//! Stream routes use earlier emitted blocks; one-shot routes use physically
//! present far sources at earlier input positions, even in one meta-block.
const std = @import("std");
const h = @import("tests/br_large_history_helpers.zig");
const a = std.testing.allocator;

pub fn contracts(comptime Br: type) !void {
    const Cases = Suite(Br);
    try Cases.qualityAndLegacy();
    try Cases.blockBoundaries();
    try Cases.expiration();
    try Cases.metadataAndFrames();
    try @import("tests/br_large_history_memory.zig").contracts(Br);
    try @import("tests/br_large_history_adaptive.zig").contracts(Br);
}

fn Suite(comptime Br: type) type {
    return struct {
        fn options(quality: u4, block_len: usize, window_bits: u5) Br.IncrementalPlannedStreamEncoder.Options {
            return .{ .stream = .{ .quality = quality, .block_len = block_len, .window_bits = window_bits, .large_window = true, .adaptive_blocks = false }, .block_len = 0 };
        }

        fn checkFar(wire: []const u8, input: []const u8, distance: usize) !void {
            const summary = try h.checkWire(Br, a, wire, input, 25, true);
            try std.testing.expectEqual(distance, summary.max_lz77_distance);
            try std.testing.expect(summary.lz77_copy_bytes >= h.anchor_len);
        }

        fn qualityAndLegacy() !void {
            const distance: usize = 65536 + 3;
            const prefix = try h.prefixAlloc(a, distance);
            defer a.free(prefix);
            const input = try h.repeatedAlloc(a, prefix, h.anchor_len);
            defer a.free(input);
            const chunks = [_][]const u8{ prefix, "", input[distance..] };
            var reusable = Br.PlannedStreamEncoder.init(a);
            defer reusable.deinit();
            var q10_one_shot_len: ?usize = null;
            var q10_reusable_len: ?usize = null;
            for (0..12) |quality| {
                errdefer std.debug.print("large-history quality route q{d}\n", .{quality});
                const stream = options(@intCast(quality), 32768, 25).stream;
                const wire = try Br.encodePlannedStreamChunksWithOptionsAlloc(a, &chunks, stream);
                defer a.free(wire);
                const summary = try h.checkWire(Br, a, wire, input, 25, true);
                if (quality >= 2) {
                    try std.testing.expectEqual(distance, summary.max_lz77_distance);
                    try std.testing.expect(summary.lz77_copy_bytes >= h.anchor_len);
                    const one_shot_options: Br.PlannedEncodeOptions = .{ .quality = @intCast(quality), .large_window = true, .window_bits = 25 };
                    const one_shot = try Br.encodePlannedStreamWithOptionsAlloc(a, input, one_shot_options);
                    defer a.free(one_shot);
                    try checkFar(one_shot, input, distance);
                    if (quality == 10) q10_one_shot_len = one_shot.len;
                    if (quality == 11) try std.testing.expect(one_shot.len <= (q10_one_shot_len orelse return error.TestUnexpectedResult));
                    // q10 supplies the reference for the q11 size envelope.
                    if (quality == 2 or quality == 4 or quality == 8 or quality == 10 or quality == 11) {
                        const reused = try reusable.encodeWithOptionsAlloc(a, input, one_shot_options);
                        defer a.free(reused);
                        try checkFar(reused, input, distance);
                        if (quality == 10) q10_reusable_len = reused.len;
                        if (quality == 11) try std.testing.expect(reused.len <= (q10_reusable_len orelse return error.TestUnexpectedResult));
                    }
                } else {
                    try std.testing.expect(summary.max_lz77_distance <= 65520);
                    var encoder = Br.IncrementalPlannedStreamEncoder.initWithOptions(a, options(@intCast(quality), 32768, 25));
                    defer encoder.deinit();
                    const streamed = try h.drive(a, &encoder, input);
                    defer a.free(streamed);
                    try h.expectHistory(&encoder, input, 25, false);
                    _ = try h.checkWire(Br, a, streamed, input, 25, true);
                }
            }
            for ([_]Br.PlannedCompressionLevel{ .fast, .balanced, .ratio }) |level| {
                errdefer std.debug.print("large-history legacy route {s}\n", .{@tagName(level)});
                const stream: Br.PlannedStreamChunksOptions = .{ .level = level, .block_len = 32768, .large_window = true, .window_bits = 25, .adaptive_blocks = false };
                var encoder = Br.PlannedStreamEncoder.init(a);
                defer encoder.deinit();
                const wire = try encoder.encodeChunksWithOptionsAlloc(a, &chunks, stream);
                defer a.free(wire);
                const summary = try h.checkWire(Br, a, wire, input, 25, true);
                try std.testing.expectEqual(distance, summary.max_lz77_distance);
                try std.testing.expectEqualSlices(u8, input, encoder.stream_state.history.items);
                const one_shot_options: Br.PlannedEncodeOptions = .{ .level = level, .large_window = true, .window_bits = 25 };
                const one_shot = try Br.encodePlannedStreamWithOptionsAlloc(a, input, one_shot_options);
                defer a.free(one_shot);
                try checkFar(one_shot, input, distance);
                const reused = try reusable.encodeWithOptionsAlloc(a, input, one_shot_options);
                defer a.free(reused);
                try checkFar(reused, input, distance);
            }
            // Explicit standard format retains its established 16-bit limit.
            var standard = options(4, 32768, 16).stream;
            standard.large_window = false;
            const standard_wire = try Br.encodePlannedStreamChunksWithOptionsAlloc(a, &chunks, standard);
            defer a.free(standard_wire);
            const standard_summary = try h.checkWire(Br, a, standard_wire, input, 16, false);
            try std.testing.expect(standard_summary.max_lz77_distance <= 65520);
            // The extension's 16-bit identity does not enlarge that distance.
            const extended_wire = try Br.encodePlannedStreamChunksWithOptionsAlloc(a, &chunks, options(4, 32768, 16).stream);
            defer a.free(extended_wire);
            const extended_summary = try h.checkWire(Br, a, extended_wire, input, 16, true);
            try std.testing.expect(extended_summary.max_lz77_distance <= 65520);
            try fastFullBlock(input, distance);
        }

        fn fastFullBlock(input: []const u8, distance: usize) !void {
            const chunks = [_][]const u8{ input[0..distance], "", input[distance..] };
            for ([_]u5{ 17, 25, 30 }) |width| {
                errdefer std.debug.print("large-history legacy fast 65536 window={d}\n", .{width});
                const stream: Br.PlannedStreamChunksOptions = .{ .level = .fast, .block_len = 65536, .large_window = true, .window_bits = width, .adaptive_blocks = false };
                // The initial 65,536-byte block has no match history and must
                // use a full-size near planner before the later far source.
                const wire = try Br.encodePlannedStreamChunksWithOptionsAlloc(a, &chunks, stream);
                defer a.free(wire);
                const summary = try h.checkWire(Br, a, wire, input, width, true);
                try std.testing.expectEqual(distance, summary.max_lz77_distance);
                try std.testing.expect(summary.lz77_copy_bytes >= h.anchor_len);
                var reusable = Br.PlannedStreamEncoder.init(a);
                defer reusable.deinit();
                const reused = try reusable.encodeChunksWithOptionsAlloc(a, &chunks, stream);
                defer a.free(reused);
                try std.testing.expectEqualSlices(u8, wire, reused);
                const reused_summary = try h.checkWire(Br, a, reused, input, width, true);
                try std.testing.expectEqual(distance, reused_summary.max_lz77_distance);
                try std.testing.expectEqualSlices(u8, input, reusable.stream_state.history.items);

                var incremental = Br.IncrementalPlannedStreamEncoder.initWithOptions(a, .{ .stream = stream, .block_len = 0 });
                defer incremental.deinit();
                var streamed: std.ArrayList(u8) = .empty;
                defer streamed.deinit(a);
                try h.feed(a, &incremental, &streamed, input[0..distance], 4093, 4096);
                incremental.flush();
                try h.drain(a, &incremental, &streamed, .need_input, 4096);
                try h.expectHistory(&incremental, input[0..distance], width, true);
                try h.feed(a, &incremental, &streamed, input[distance..], 7, 257);
                try incremental.finish();
                try h.drain(a, &incremental, &streamed, .done, 4096);
                try h.expectHistory(&incremental, input, width, true);
                const streamed_summary = try h.checkWire(Br, a, streamed.items, input, width, true);
                try std.testing.expectEqual(distance, streamed_summary.max_lz77_distance);
            }

            const standard: Br.PlannedStreamChunksOptions = .{ .level = .fast, .block_len = 65536, .window_bits = 16, .adaptive_blocks = false };
            const standard_wire = try Br.encodePlannedStreamChunksWithOptionsAlloc(a, &chunks, standard);
            defer a.free(standard_wire);
            const standard_summary = try h.checkWire(Br, a, standard_wire, input, 16, false);
            try std.testing.expect(standard_summary.max_lz77_distance <= 65520);

            // With IO and history capacity already admitted, refuse the first
            // full-size planning allocation after the source was accepted.
            var heap = std.testing.FailingAllocator.init(a, .{ .resize_fail_index = 0 });
            const opts: Br.IncrementalPlannedStreamEncoder.Options = .{ .stream = .{ .level = .fast, .block_len = 65536, .large_window = true, .window_bits = 25, .adaptive_blocks = false }, .block_len = 0 };
            var incremental = Br.IncrementalPlannedStreamEncoder.initWithOptions(heap.allocator(), opts);
            var alive = true;
            defer if (alive) incremental.deinit();
            var recovered: std.ArrayList(u8) = .empty;
            defer recovered.deinit(a);
            try h.feed(a, &incremental, &recovered, "", 4093, 4096);
            try incremental.plain.ensureTotalCapacity(heap.allocator(), 65536);
            try incremental.codec_state.history.ensureTotalCapacity(heap.allocator(), 65536);
            const before = incremental.snapshot();
            const pending = try a.dupe(u8, incremental.pending.items);
            defer a.free(pending);
            heap.fail_index = heap.alloc_index;
            var output: [4096]u8 = @splat(0xa5);
            try std.testing.expectError(error.OutOfMemory, incremental.step(input[0..65536], &output));
            try std.testing.expect(heap.has_induced_failure);
            try h.untouched(&output);
            try std.testing.expectEqual(@as(Br.IncrementalPlannedStreamEncoder.Counter, 65536), incremental.snapshot().input_read);
            try std.testing.expectEqual(@as(usize, 65536), incremental.snapshot().buffered_input);
            try std.testing.expectEqual(before.output_written, incremental.snapshot().output_written);
            try std.testing.expectEqualSlices(u8, input[0..65536], incremental.plain.items);
            try std.testing.expectEqualSlices(u8, pending, incremental.pending.items);
            try h.expectHistory(&incremental, "", 25, true);
            heap.fail_index = std.math.maxInt(usize);
            try h.drain(a, &incremental, &recovered, .need_input, 4096);
            try h.expectHistory(&incremental, input[0..65536], 25, true);
            try h.feed(a, &incremental, &recovered, input[65536..], 7, 257);
            try incremental.finish();
            try h.drain(a, &incremental, &recovered, .done, 4096);
            try h.expectHistory(&incremental, input, 25, true);
            var fresh = Br.IncrementalPlannedStreamEncoder.initWithOptions(a, opts);
            defer fresh.deinit();
            const expected = try h.drive(a, &fresh, input);
            defer a.free(expected);
            try std.testing.expectEqualSlices(u8, expected, recovered.items);
            const recovered_summary = try h.checkWire(Br, a, recovered.items, input, 25, true);
            try std.testing.expectEqual(distance, recovered_summary.max_lz77_distance);
            incremental.deinit();
            alive = false;
            try std.testing.expectEqual(heap.allocated_bytes, heap.freed_bytes);
        }

        fn blockBoundaries() !void {
            const prefix = try h.prefixAlloc(a, 70000);
            defer a.free(prefix);
            for ([_]usize{ 4096, 32768, 65536 }) |block_len| {
                for ([_]usize{ 65535, 65536, 70000 }) |distance| {
                    errdefer std.debug.print("large-history block={d} distance={d}\n", .{ block_len, distance });
                    const input = try h.repeatedAlloc(a, prefix[0..distance], 64);
                    defer a.free(input);
                    var encoder = Br.IncrementalPlannedStreamEncoder.initWithOptions(a, options(6, block_len, 25));
                    defer encoder.deinit();
                    var wire: std.ArrayList(u8) = .empty;
                    defer wire.deinit(a);
                    try h.feed(a, &encoder, &wire, input[0..distance], 4093, 4096);
                    encoder.flush();
                    try h.drain(a, &encoder, &wire, .need_input, 257);
                    try h.expectHistory(&encoder, input[0..distance], 25, true);
                    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().buffered_input);
                    try h.feed(a, &encoder, &wire, input[distance..], 7, 31);
                    try encoder.finish();
                    try h.drain(a, &encoder, &wire, .done, 257);
                    try h.expectHistory(&encoder, input, 25, true);
                    const summary = try h.checkWire(Br, a, wire.items, input, 25, true);
                    try std.testing.expectEqual(distance, summary.max_lz77_distance);
                }
            }
        }

        fn expiration() !void {
            const limit: usize = (1 << 17) - 16;
            const prefix = try h.prefixAlloc(a, limit + 1);
            defer a.free(prefix);
            for ([_]usize{ limit, limit + 1 }) |distance| {
                errdefer std.debug.print("large-history expiry distance={d}\n", .{distance});
                const input = try h.repeatedAlloc(a, prefix[0..distance], h.anchor_len);
                defer a.free(input);
                var encoder = Br.IncrementalPlannedStreamEncoder.initWithOptions(a, options(4, 32768, 17));
                defer encoder.deinit();
                var wire: std.ArrayList(u8) = .empty;
                defer wire.deinit(a);
                try h.feed(a, &encoder, &wire, input[0..distance], 4093, 4096);
                encoder.flush();
                try h.drain(a, &encoder, &wire, .need_input, 4096);
                try h.expectHistory(&encoder, input[0..distance], 17, true);
                const sealed_prefix = try h.sealPrefix(a, &encoder, wire.items);
                defer a.free(sealed_prefix);
                const before = try h.checkWire(Br, a, sealed_prefix, input[0..distance], 17, true);
                try h.feed(a, &encoder, &wire, input[distance..], 7, 257);
                try encoder.finish();
                try h.drain(a, &encoder, &wire, .done, 4096);
                try h.expectHistory(&encoder, input, 17, true);
                const after = try h.checkWire(Br, a, wire.items, input, 17, true);
                if (distance == limit) {
                    try std.testing.expectEqual(limit, after.max_lz77_distance);
                    try std.testing.expect(after.lz77_copy_bytes - before.lz77_copy_bytes >= h.anchor_len);
                } else {
                    // Every matching anchor position has the expired distance;
                    // no other prefix or target position has an anchor trigram.
                    try std.testing.expectEqual(before.lz77_copy_bytes, after.lz77_copy_bytes);
                }
            }
        }

        fn metadataAndFrames() !void {
            const prefix = try h.prefixAlloc(a, 70000);
            defer a.free(prefix);
            const input = try h.repeatedAlloc(a, prefix, h.anchor_len);
            defer a.free(input);
            const metadata = "metadata does not enter LZ77 history";
            for ([_]u4{ 4, 11 }) |quality| {
                errdefer std.debug.print("large-history metadata/frame q{d}\n", .{quality});
                const opts = options(quality, 32768, 25);
                var encoder = Br.IncrementalPlannedStreamEncoder.initWithOptions(a, opts);
                defer encoder.deinit();
                var wire: std.ArrayList(u8) = .empty;
                defer wire.deinit(a);
                try h.feed(a, &encoder, &wire, prefix, 4093, 4096);
                encoder.flush();
                try h.drain(a, &encoder, &wire, .need_input, 4096);
                try h.expectHistory(&encoder, prefix, 25, true);
                const history = try a.dupe(u8, encoder.codec_state.history.items);
                defer a.free(history);
                try encoder.writeMetadata(metadata);
                try h.drain(a, &encoder, &wire, .need_input, 31);
                try std.testing.expectEqualSlices(u8, history, encoder.codec_state.history.items);
                try std.testing.expectEqual(@as(coreCount(Br), prefix.len), encoder.snapshot().input_read);
                try h.feed(a, &encoder, &wire, input[prefix.len..], 7, 257);
                try encoder.finish();
                try h.drain(a, &encoder, &wire, .done, 4096);
                const summary = try h.checkWire(Br, a, wire.items, input, 25, true);
                try std.testing.expectEqual(prefix.len, summary.max_lz77_distance);
                try std.testing.expectEqual(@as(usize, 1), summary.metadata_meta_block_count);
                try std.testing.expectEqual(metadata.len, summary.metadata_bytes);

                try encoder.nextStream(opts);
                try h.expectHistory(&encoder, "", 25, true);
                const next = try h.drive(a, &encoder, input[prefix.len..]);
                defer a.free(next);
                var fresh = Br.IncrementalPlannedStreamEncoder.initWithOptions(a, opts);
                defer fresh.deinit();
                const expected = try h.drive(a, &fresh, input[prefix.len..]);
                defer a.free(expected);
                try std.testing.expectEqualSlices(u8, expected, next);
                const next_summary = try h.checkWire(Br, a, next, input[prefix.len..], 25, true);
                try std.testing.expect(next_summary.max_lz77_distance <= h.anchor_len);

                encoder.reset();
                wire.clearRetainingCapacity();
                try h.feed(a, &encoder, &wire, prefix, 4093, 4096);
                encoder.flush();
                try h.drain(a, &encoder, &wire, .need_input, 4096);
                try h.expectHistory(&encoder, prefix, 25, true);
                encoder.reset();
                try h.expectHistory(&encoder, "", 25, true);
                const reset = try h.drive(a, &encoder, input[prefix.len..]);
                defer a.free(reset);
                try std.testing.expectEqualSlices(u8, expected, reset);
            }
        }

        fn coreCount(comptime Namespace: type) type {
            return Namespace.IncrementalPlannedStreamEncoder.Counter;
        }
    };
}
