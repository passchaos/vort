//! Public Brotli metadata full-range and transition contracts. Header fields
//! are checked by a separate LSB oracle, not by production size formulas.
const std = @import("std");
const core = @import("core.zig");
const oracle = @import("br/encoder/metadata_wire_tests.zig");
const tracking = @import("tests/br_total_memory_helpers.zig");
const a = std.testing.allocator;
const large_length: usize = 65537;
const maximum: usize = 16777216;
const plain = "Brotli metadata leaves plaintext intact abcdefghabcdefgh-tail";

test {
    _ = oracle;
}

pub fn contracts(comptime Br: type) !void {
    const Cases = Suite(Br);
    try Cases.storedLengths();
    try Cases.maximumCapture();
    try Cases.plannedSurfaces();
    try Cases.afterFlush();
    try Cases.oversized();
    try Cases.truncated();
    try Cases.aliasesAndFailures();
    try Cases.staticSurfaces();
    try Cases.staticSourceAliases();
    try Cases.quotaAndReset();
}

fn Suite(comptime Br: type) type {
    return struct {
        const br = Br;
        fn metadataAlloc(length: usize) ![]u8 {
            const bytes = try a.alloc(u8, length);
            for (bytes, 0..) |*byte, index| byte.* = @truncate(index *% 37 +% index / 251 +% 19);
            return bytes;
        }
        fn hash(bytes: []const u8) [32]u8 {
            var digest: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
            return digest;
        }
        fn checkPrefix(wire: []const u8, metadata: []const u8) !void {
            const parsed = try oracle.prefix(wire);
            try std.testing.expectEqual(metadata.len, parsed.length);
            const count: u2 = if (metadata.len == 0) 0 else if (metadata.len <= 256) 1 else if (metadata.len <= 65536) 2 else 3;
            try std.testing.expectEqual(count, parsed.mskipbytes);
            try std.testing.expect(parsed.payload_offset <= wire.len and metadata.len <= wire.len - parsed.payload_offset);
            try std.testing.expectEqualSlices(u8, metadata, wire[parsed.payload_offset..][0..metadata.len]);
            try std.testing.expectEqual(hash(metadata), hash(wire[parsed.payload_offset..][0..metadata.len]));
        }
        fn decode(wire: []const u8, expected: []const u8) !void {
            const decoded = try br.decodeStreamAllocExactSize(a, wire, expected.len);
            defer a.free(decoded);
            try std.testing.expectEqualSlices(u8, expected, decoded);
        }
        fn drain(encoder: anytype, wire: *std.ArrayList(u8), expected: core.StepResult.Status, quota: usize) !void {
            var output: [65536]u8 = undefined;
            for (0..maximum + 4096) |_| {
                const before = encoder.snapshot();
                @memset(output[0..quota], 0xa5);
                const step = try encoder.step("", output[0..quota]);
                const after = encoder.snapshot();
                try std.testing.expectEqual(@as(core.StreamCount, step.progress.input_read), after.input_read - before.input_read);
                try std.testing.expectEqual(@as(core.StreamCount, step.progress.output_written), after.output_written - before.output_written);
                try tracking.untouched(output[step.progress.output_written..quota]);
                try wire.appendSlice(a, output[0..step.progress.output_written]);
                if (step.status == expected) return;
                try std.testing.expectEqual(.need_output, step.status);
            }
            return error.TestUnexpectedResult;
        }
        fn complete(encoder: anytype, input: []const u8, quota: usize) ![]u8 {
            var wire: std.ArrayList(u8) = .empty;
            errdefer wire.deinit(a);
            var output: [65536]u8 = undefined;
            var offset: usize = 0;
            for (0..input.len * 4 + maximum + 4096) |_| {
                const before = encoder.snapshot();
                @memset(output[0..quota], 0xa5);
                const end = @min(input.len, offset + 7);
                const step = try encoder.step(input[offset..end], output[0..quota]);
                const after = encoder.snapshot();
                try std.testing.expectEqual(@as(core.StreamCount, step.progress.input_read), after.input_read - before.input_read);
                try std.testing.expectEqual(@as(core.StreamCount, step.progress.output_written), after.output_written - before.output_written);
                try tracking.untouched(output[step.progress.output_written..quota]);
                offset += step.progress.input_read;
                try wire.appendSlice(a, output[0..step.progress.output_written]);
                if (offset == input.len and step.status == .need_input) break;
            }
            try std.testing.expectEqual(input.len, offset);
            try encoder.finish();
            try drain(encoder, &wire, .done, quota);
            return wire.toOwnedSlice(a);
        }
        fn captureStored(wire: []const u8, metadata: []const u8, plaintext: []const u8, quota: usize) !void {
            const captured = try a.alloc(u8, metadata.len + 16);
            defer a.free(captured);
            @memset(captured, 0xa5);
            var lengths: [2]usize = @splat(std.math.maxInt(usize));
            var decoder = br.IncrementalStoredStreamDecoder.initWithOptions(.{ .metadata_output = captured[0..metadata.len], .metadata_block_lengths = &lengths });
            var output: [256]u8 = undefined;
            var offset: usize = 0;
            var decoded: std.ArrayList(u8) = .empty;
            defer decoded.deinit(a);
            for (0..wire.len + 4096) |_| {
                const end = @min(wire.len, offset + quota);
                const before = decoder.snapshot();
                @memset(&output, 0xa5);
                const step = try decoder.step(wire[offset..end], &output);
                const after = decoder.snapshot();
                try std.testing.expectEqual(@as(core.StreamCount, step.progress.input_read), after.input_read - before.input_read);
                try std.testing.expectEqual(@as(core.StreamCount, step.progress.output_written), after.output_written - before.output_written);
                offset += step.progress.input_read;
                try decoded.appendSlice(a, output[0..step.progress.output_written]);
                try tracking.untouched(output[step.progress.output_written..]);
                if (step.status == .done) break;
            }
            try decoder.finish();
            try std.testing.expectEqual(wire.len, offset);
            try std.testing.expectEqualSlices(u8, plaintext, decoded.items);
            try std.testing.expectEqualSlices(u8, metadata, captured[0..metadata.len]);
            try tracking.untouched(captured[metadata.len..]);
            try std.testing.expectEqual(@as(core.StreamCount, metadata.len), decoder.snapshot().metadata_total);
            try std.testing.expectEqual(@as(core.StreamCount, 1), decoder.snapshot().metadata_block_count);
            try std.testing.expectEqual(metadata.len, lengths[0]);
            try std.testing.expect(!decoder.snapshot().metadata_truncated);
        }

        fn storedLengths() !void {
            const metadata = try metadataAlloc(large_length);
            defer a.free(metadata);
            const lengths = [_]usize{ 1, 255, 256, 257, 65535, 65536, 65537 };
            for (lengths) |length| {
                const options: br.StoredStreamOptions = .{ .metadata = metadata[0..length] };
                const bound = try br.encodedStoredStreamBoundWithOptions(plain.len, options);
                const bytes = try br.encodeStoredStreamWithOptionsAlloc(a, plain, options);
                defer a.free(bytes);
                try std.testing.expectEqual(bound, bytes.len);
                try checkPrefix(bytes, metadata[0..length]);
                try decode(bytes, plain);
            }
            var encoder = br.IncrementalStoredStreamEncoder.init(a);
            defer encoder.deinit();
            try encoder.writeMetadata("");
            const empty = try complete(&encoder, "", 3);
            defer a.free(empty);
            try checkPrefix(empty, "");
            try captureStored(empty, "", "", 1);
        }

        fn maximumCapture() !void {
            const metadata = try metadataAlloc(maximum);
            defer a.free(metadata);
            const expected_hash = hash(metadata);
            const options: br.StoredStreamOptions = .{ .metadata = metadata };
            const bound = try br.encodedStoredStreamBoundWithOptions(1, options);
            const output = try a.alloc(u8, bound + 16);
            defer a.free(output);
            @memset(output, 0xa5);
            const written = try br.encodeStoredStreamWithOptionsInto("x", output[0..bound], options);
            try std.testing.expectEqual(bound, written);
            try tracking.untouched(output[written..]);
            const prefix = try oracle.prefix(output[0..written]);
            try std.testing.expectEqual(@as(u2, 3), prefix.mskipbytes);
            try std.testing.expectEqual(maximum, prefix.length);
            try std.testing.expectEqual(expected_hash, hash(output[prefix.payload_offset..][0..metadata.len]));
            try std.testing.expectEqual(metadata[0], output[prefix.payload_offset]);
            try std.testing.expectEqual(metadata[metadata.len - 1], output[prefix.payload_offset + metadata.len - 1]);
            try captureStored(output[0..written], metadata, "x", 65536);
        }

        fn plannedSurfaces() !void {
            const metadata = try metadataAlloc(large_length);
            defer a.free(metadata);
            const chunks = [_][]const u8{ plain[0..7], "", plain[7..] };
            for (0..12) |quality| {
                const options: br.PlannedEncodeOptions = .{ .quality = @intCast(quality), .window_bits = 16, .metadata = metadata };
                const bytes = try br.encodePlannedStreamWithOptionsAlloc(a, plain, options);
                defer a.free(bytes);
                try checkPrefix(bytes, metadata);
                try decode(bytes, plain);
                const chunk_options: br.PlannedStreamChunksOptions = .{ .quality = @intCast(quality), .window_bits = 16, .metadata = metadata, .adaptive_blocks = false };
                const chunked = try br.encodePlannedStreamChunksWithOptionsAlloc(a, &chunks, chunk_options);
                defer a.free(chunked);
                try checkPrefix(chunked, metadata);
                try decode(chunked, plain);
            }
            for ([_]u4{ 10, 11 }) |quality| {
                const options: br.PlannedStreamChunksOptions = .{ .quality = quality, .hq = .{}, .window_bits = 16, .metadata = metadata };
                var encoder = br.PlannedStreamEncoder.init(a);
                defer encoder.deinit();
                const bytes = try encoder.encodeChunksWithOptionsAlloc(a, &chunks, options);
                defer a.free(bytes);
                try checkPrefix(bytes, metadata);
                try decode(bytes, plain);
                var incremental = br.IncrementalPlannedStreamEncoder.initWithOptions(a, .{ .stream = options });
                defer incremental.deinit();
                const streamed = try complete(&incremental, plain, 31);
                defer a.free(streamed);
                try checkPrefix(streamed, metadata);
                try decode(streamed, plain);
                try std.testing.expectEqual(@as(core.StreamCount, plain.len), incremental.snapshot().input_read);
            }
            var stored = br.StoredStreamEncoder.init(a);
            defer stored.deinit();
            const bytes = try stored.encodeChunksWithOptionsAlloc(&chunks, .{ .metadata = metadata });
            defer a.free(bytes);
            try checkPrefix(bytes, metadata);
            try decode(bytes, plain);
        }

        fn afterFlush() !void {
            const metadata = try metadataAlloc(large_length);
            defer a.free(metadata);
            var encoder = br.IncrementalStoredStreamEncoder.init(a);
            defer encoder.deinit();
            var first: [256]u8 = undefined;
            const accepted = try encoder.step("ab", &first);
            try std.testing.expectEqual(@as(usize, 2), accepted.progress.input_read);
            var wire: std.ArrayList(u8) = .empty;
            defer wire.deinit(a);
            try wire.appendSlice(a, first[0..accepted.progress.output_written]);
            try encoder.writeMetadata(metadata);
            try drain(&encoder, &wire, .need_input, 31);
            try std.testing.expectEqual(@as(core.StreamCount, 2), encoder.snapshot().input_read);
            try std.testing.expect(!encoder.snapshot().metadata_pending);
            const rest = try complete(&encoder, "cd", 31);
            defer a.free(rest);
            try wire.appendSlice(a, rest);
            const parsed = try oracle.afterStored(wire.items);
            try std.testing.expectEqual(metadata.len, parsed.length);
            try std.testing.expectEqualSlices(u8, metadata, wire.items[parsed.payload_offset..][0..metadata.len]);
            try decode(wire.items, "abcd");
            try captureStored(wire.items, metadata, "abcd", 1);
            try std.testing.expectEqual(@as(core.StreamCount, 4), encoder.snapshot().input_read);
        }

        fn oversized() !void {
            const anchor = [_]u8{0x51};
            const oversized_metadata = anchor[0..].ptr[0 .. maximum + 1]; // Length-only immutable sentinel, never read.
            var heap = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
            const allocator = heap.allocator();
            try std.testing.expectError(error.InvalidBlockPlan, br.encodedStoredStreamBoundWithOptions(0, .{ .metadata = oversized_metadata }));
            try std.testing.expectError(error.InvalidBlockPlan, br.encodeStoredStreamWithOptionsAlloc(allocator, "", .{ .metadata = oversized_metadata }));
            var output: [128]u8 = @splat(0xa5);
            try std.testing.expectError(error.InvalidBlockPlan, br.encodeStoredStreamWithOptionsInto("", &output, .{ .metadata = oversized_metadata }));
            try tracking.untouched(&output);
            try std.testing.expectError(error.InvalidBlockPlan, br.encodePlannedStreamWithOptionsAlloc(allocator, plain, .{ .quality = 0, .metadata = oversized_metadata }));
            try std.testing.expectError(error.InvalidBlockPlan, br.encodePlannedStreamWithOptionsAlloc(allocator, plain, .{ .quality = 10, .hq = .{}, .metadata = oversized_metadata }));
            var incremental = br.IncrementalStoredStreamEncoder.init(allocator);
            defer incremental.deinit();
            try std.testing.expectError(error.InvalidBlockPlan, incremental.writeMetadata(oversized_metadata));
            try std.testing.expect(!incremental.snapshot().metadata_pending);
            try std.testing.expectEqual(@as(usize, 0), heap.alloc_index);
            try std.testing.expect(!heap.has_induced_failure);
        }

        fn truncated() !void {
            const metadata = try metadataAlloc(large_length);
            defer a.free(metadata);
            const bytes = try br.encodeStoredStreamWithOptionsAlloc(a, "", .{ .metadata = metadata });
            defer a.free(bytes);
            const prefix = try oracle.prefix(bytes);
            for ([_]usize{ 1, prefix.payload_offset - 1, prefix.payload_offset + metadata.len - 1 }) |cut| {
                var decoder = br.IncrementalStoredStreamDecoder.init();
                const step = try decoder.step(bytes[0..cut], &.{});
                try std.testing.expectEqual(.need_input, step.status);
                try std.testing.expectError(error.TruncatedFrame, decoder.finish());
                try std.testing.expectEqual(@as(core.StreamCount, 0), decoder.snapshot().output_written);
            }
        }

        fn aliasesAndFailures() !void {
            const metadata = try metadataAlloc(large_length);
            defer a.free(metadata);
            var heap = std.testing.FailingAllocator.init(a, .{ .resize_fail_index = 0 });
            var appended = std.ArrayList(u8).fromOwnedSlice(try heap.allocator().dupe(u8, "caller prefix"));
            defer appended.deinit(heap.allocator());
            const pointer = appended.items.ptr;
            const capacity = appended.capacity;
            heap.fail_index = heap.alloc_index;
            try std.testing.expectError(error.OutOfMemory, br.encodeStoredStreamWithOptionsAppend(heap.allocator(), &appended, plain, .{ .metadata = metadata }));
            try std.testing.expectEqualStrings("caller prefix", appended.items);
            try std.testing.expectEqual(pointer, appended.items.ptr);
            try std.testing.expectEqual(capacity, appended.capacity);
            var encoder = br.StoredStreamEncoder.init(a);
            defer encoder.deinit();
            const first = try encoder.encodeScratchWithOptions("x", .{ .metadata = metadata });
            const prefix = try oracle.prefix(first);
            const borrowed = first[prefix.payload_offset..][0..metadata.len];
            const second = try encoder.encodeScratchWithOptions(plain, .{ .metadata = borrowed });
            try checkPrefix(second, metadata);
            try decode(second, plain);
            const third = try encoder.encodeScratchWithOptions("z", .{ .metadata = metadata });
            try checkPrefix(third, metadata);
            try decode(third, "z");
        }

        fn staticSurfaces() !void {
            const metadata = try metadataAlloc(large_length);
            defer a.free(metadata);
            const chunks = [_][]const u8{ plain[0..7], "", plain[7..] };
            var heap = std.testing.FailingAllocator.init(a, .{ .resize_fail_index = 0 });
            var encoder = br.StaticDictionaryStreamEncoder.init(heap.allocator());
            defer encoder.deinit();
            const first = try encoder.encodeChunksScratchWithOptions(&chunks, .{ .stream = .{ .metadata = metadata } });
            try checkPrefix(first, metadata);
            try decode(first, plain);
            const prefix = try oracle.prefix(first);
            const borrowed_metadata = first[prefix.payload_offset..][0..metadata.len];
            const large_options: br.StaticDictionaryStreamOptions = .{ .stream = .{ .large_window = true, .window_bits = 25, .metadata = borrowed_metadata } };
            const second = try encoder.encodeChunksScratchWithOptions(&chunks, large_options);
            var window: oracle.Cursor = .{ .input = second };
            try std.testing.expectEqual(@as(u5, 25), try oracle.readWindow(&window));
            try checkPrefix(second, metadata);
            const decoded = try br.decodeStreamAllocWithOptions(a, second, .{ .allow_large_window = true });
            defer a.free(decoded);
            try std.testing.expectEqualSlices(u8, plain, decoded);
            const old = try a.dupe(u8, second);
            defer a.free(old);
            const old_pointer = encoder.output.items.ptr;
            const old_capacity = encoder.output.capacity;
            const anchor = [_]u8{0x51};
            const invalid_metadata = anchor[0..].ptr[0 .. maximum + 1]; // Preflight length only.
            const before_allocations = heap.alloc_index;
            try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeChunksScratchWithOptions(&chunks, .{ .stream = .{ .large_window = true, .window_bits = 25, .metadata = invalid_metadata } }));
            try std.testing.expectEqual(before_allocations, heap.alloc_index);
            try std.testing.expectEqual(old_pointer, encoder.output.items.ptr);
            try std.testing.expectEqual(old_capacity, encoder.output.capacity);
            try std.testing.expectEqualSlices(u8, old, encoder.output.items);

            var no_allocations = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
            var invalid = br.StaticDictionaryStreamEncoder.init(no_allocations.allocator());
            defer invalid.deinit();
            try std.testing.expectError(error.InvalidBlockPlan, invalid.encodeChunksScratchWithOptions(&chunks, .{ .stream = .{ .metadata = invalid_metadata } }));
            try std.testing.expectEqual(@as(usize, 0), no_allocations.alloc_index);
            try std.testing.expect(!no_allocations.has_induced_failure);
            try std.testing.expectEqual(@as(usize, 0), invalid.output.items.len);

            // Metadata may alias an existing append prefix. A fresh pending
            // allocation refusal must not publish bytes into that prefix;
            // this does not assume any reusable metadata snapshot mechanism.
            var refused = std.testing.FailingAllocator.init(a, .{ .resize_fail_index = 0 });
            var preserved = std.ArrayList(u8).fromOwnedSlice(try refused.allocator().dupe(u8, metadata));
            defer preserved.deinit(refused.allocator());
            const preserved_pointer = preserved.items.ptr;
            const preserved_capacity = preserved.capacity;
            refused.fail_index = refused.alloc_index;
            try std.testing.expectError(error.OutOfMemory, br.encodePlannedStreamStaticDictionaryChunksWithOptionsAppend(refused.allocator(), &preserved, &chunks, .{ .stream = .{ .large_window = true, .window_bits = 25, .metadata = preserved.items } }));
            try std.testing.expect(refused.has_induced_failure);
            try std.testing.expectEqual(preserved_pointer, preserved.items.ptr);
            try std.testing.expectEqual(preserved_capacity, preserved.capacity);
            try std.testing.expectEqualSlices(u8, metadata, preserved.items);

            // Complete public static conveniences share the same format
            // validation and metadata writer, independently of reuse aliases.
            const complete_options: br.StaticDictionaryStreamOptions = .{ .stream = .{ .large_window = true, .window_bits = 25, .metadata = metadata } };
            const allocated = try br.encodePlannedStreamStaticDictionaryChunksWithOptionsAlloc(a, &chunks, complete_options);
            defer a.free(allocated);
            try checkPrefix(allocated, metadata);
            const output = try a.alloc(u8, allocated.len + 16);
            defer a.free(output);
            @memset(output, 0xa5);
            const written = try br.encodePlannedStreamStaticDictionaryChunksWithOptionsInto(&chunks, output, complete_options);
            try std.testing.expectEqualSlices(u8, allocated, output[0..written]);
            try tracking.untouched(output[written..]);
            var appended: std.ArrayList(u8) = .empty;
            defer appended.deinit(a);
            try appended.appendSlice(a, "caller prefix");
            try br.encodePlannedStreamStaticDictionaryChunksWithOptionsAppend(a, &appended, &chunks, complete_options);
            try std.testing.expectEqualStrings("caller prefix", appended.items[0..13]);
            try std.testing.expectEqualSlices(u8, allocated, appended.items[13..]);
        }

        fn staticSourceAliases() !void {
            for ([_]bool{ false, true }) |borrow_descriptors| {
                const metadata = try metadataAlloc(large_length);
                defer a.free(metadata);
                @memcpy(metadata[0..plain.len], plain);
                const ordinary_chunks = [_][]const u8{ plain[0..7], "", plain[7..] };
                var heap = std.testing.FailingAllocator.init(a, .{ .resize_fail_index = 0 });
                var encoder = br.StaticDictionaryStreamEncoder.init(heap.allocator());
                defer encoder.deinit();
                const first = try encoder.encodeChunksScratchWithOptions(&ordinary_chunks, .{ .stream = .{ .metadata = metadata } });
                try checkPrefix(first, metadata);
                try decode(first, plain);

                // Retain the exact first wire allocation so the larger window
                // must move output while all old source borrows are live.
                const compact = try heap.allocator().dupe(u8, first);
                encoder.output.deinit(heap.allocator());
                encoder.output = std.ArrayList(u8).fromOwnedSlice(compact);
                const prefix = try oracle.prefix(encoder.output.items);
                try std.testing.expectEqual(@as(usize, 4), prefix.payload_offset);
                try std.testing.expectEqualSlices(u8, &.{ 0x6c, 0, 0x80, 0 }, encoder.output.items[0..prefix.payload_offset]);
                const borrowed_metadata = encoder.output.items[prefix.payload_offset..][0..metadata.len];
                const source_chunks = [_][]const u8{ borrowed_metadata[0..7], borrowed_metadata[7..7], borrowed_metadata[7..plain.len] };
                var chunks: []const []const u8 = &source_chunks;
                if (borrow_descriptors) {
                    // The descriptors themselves also occupy initialized old
                    // output bytes, after the complete plaintext source.
                    const source_end = @intFromPtr(borrowed_metadata[plain.len..].ptr);
                    const descriptor_offset = plain.len + std.mem.alignForward(usize, source_end, @alignOf([]const u8)) - source_end;
                    const descriptors: *[3][]const u8 = @ptrCast(@alignCast(borrowed_metadata[descriptor_offset..].ptr));
                    descriptors.* = source_chunks;
                    chunks = descriptors;
                    @memcpy(metadata, borrowed_metadata);
                }
                const old = try a.dupe(u8, encoder.output.items);
                defer a.free(old);
                const old_pointer = encoder.output.items.ptr;
                const old_capacity = encoder.output.capacity;
                const old_state = encoder.incremental.snapshot();
                const options: br.StaticDictionaryStreamOptions = .{ .stream = .{ .large_window = true, .window_bits = 25, .metadata = borrowed_metadata } };

                // Each of the descriptor, source-data and metadata snapshots
                // can refuse before output clearing or incremental reset.
                for (0..3) |fail_after| {
                    const before_live = heap.allocated_bytes - heap.freed_bytes;
                    heap.fail_index = heap.alloc_index + fail_after;
                    try std.testing.expectError(error.OutOfMemory, encoder.encodeChunksScratchWithOptions(chunks, options));
                    try std.testing.expect(heap.has_induced_failure);
                    try std.testing.expectEqual(before_live, heap.allocated_bytes - heap.freed_bytes);
                    try std.testing.expectEqual(old_pointer, encoder.output.items.ptr);
                    try std.testing.expectEqual(old_capacity, encoder.output.capacity);
                    try std.testing.expectEqualSlices(u8, old, encoder.output.items);
                    try std.testing.expectEqual(old_state, encoder.incremental.snapshot());
                }
                heap.fail_index = std.math.maxInt(usize);
                const independent_options: br.StaticDictionaryStreamOptions = .{ .stream = .{ .large_window = true, .window_bits = 25, .metadata = metadata } };
                const expected = try br.encodePlannedStreamStaticDictionaryChunksWithOptionsAlloc(a, &ordinary_chunks, independent_options);
                defer a.free(expected);
                try std.testing.expect(expected.len > old_capacity);
                const second = try encoder.encodeChunksScratchWithOptions(chunks, options);
                try std.testing.expect(old_pointer != encoder.output.items.ptr);
                try std.testing.expectEqualSlices(u8, expected, second);
                const next_prefix = try oracle.prefix(second);
                try std.testing.expectEqual(prefix.payload_offset + 2, next_prefix.payload_offset);
                try std.testing.expectEqualSlices(u8, &.{ 0x11, 0x99, 0x0d, 0, 0x10, 0 }, second[0..next_prefix.payload_offset]);
                try checkPrefix(second, metadata);
                const decoded = try br.decodeStreamAllocWithOptions(a, second, .{ .allow_large_window = true });
                defer a.free(decoded);
                try std.testing.expectEqualSlices(u8, plain, decoded);

                // Warm ordinary inputs have no aliases to snapshot and need
                // no new allocation through the same reusable public API.
                const before_allocations = heap.alloc_index;
                heap.fail_index = before_allocations;
                const repeated = try encoder.encodeChunksScratchWithOptions(&ordinary_chunks, independent_options);
                try std.testing.expectEqual(before_allocations, heap.alloc_index);
                try std.testing.expectEqualSlices(u8, expected, repeated);
            }
        }

        fn quotaAndReset() !void {
            const metadata = try metadataAlloc(large_length);
            defer a.free(metadata);
            var ledger = tracking.TrackingAllocator.init(a);
            ledger.force_moving_growth = true;
            var profile: br.EncodeMemoryProfile = .{};
            var measured = br.IncrementalStoredStreamEncoder.initWithOptions(ledger.allocator(), .{ .stream = .{ .metadata = metadata, .memory_profile = &profile } });
            const expected = try complete(&measured, plain, 31);
            defer a.free(expected);
            const peak = profile.peak_requested_bytes;
            try std.testing.expectEqual(ledger.peak, peak);
            try std.testing.expectEqual(ledger.live, measured.memorySnapshot().live_requested_bytes);
            measured.deinit();
            try std.testing.expectEqual(@as(usize, 0), ledger.live);
            for ([_]bool{ false, true }) |exact| {
                var heap = tracking.TrackingAllocator.init(a);
                heap.force_moving_growth = true;
                var memory: br.EncodeMemoryProfile = .{};
                var encoder = br.IncrementalStoredStreamEncoder.initWithOptions(heap.allocator(), .{ .stream = .{ .metadata = metadata, .memory_profile = &memory, .max_total_working_memory = if (exact) peak else peak - 1 } });
                defer encoder.deinit();
                if (exact) {
                    const actual = try complete(&encoder, plain, 31);
                    defer a.free(actual);
                    try std.testing.expectEqualSlices(u8, expected, actual);
                } else {
                    try std.testing.expectError(error.WorkingMemoryLimitExceeded, complete(&encoder, plain, 31));
                    try std.testing.expect(memory.peak_requested_bytes <= peak - 1);
                    encoder.options.stream.max_total_working_memory = null;
                    encoder.reset();
                    const recovered = try complete(&encoder, plain, 31);
                    defer a.free(recovered);
                    try std.testing.expectEqualSlices(u8, expected, recovered);
                }
            }
        }
    };
}
