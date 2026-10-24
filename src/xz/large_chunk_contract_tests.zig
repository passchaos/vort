const std = @import("std");
const xz = @import("../xz.zig");
const h = @import("large_chunk_contract_helpers.zig");
const allocator = std.testing.allocator;

test "XZ large chunk old default raw and all twenty preset wire stay fixed" {
    const input = h.dictionary.legacyPlain();
    const expected = h.dictionary.hexBytes(h.default_hex);
    const encoded = try xz.encodeAlloc(allocator, &input, .{});
    defer allocator.free(encoded);
    try std.testing.expectEqualSlices(u8, &expected, encoded);
    var raw: std.ArrayList(u8) = .empty;
    defer raw.deinit(allocator);
    _ = try xz.encodeRawLzma2Append(allocator, &raw, &input);
    const raw_expected = h.dictionary.hexBytes(h.raw_default_hex);
    try std.testing.expectEqualSlices(u8, &raw_expected, raw.items);
    for (h.preset_wires) |sample| {
        const expected_wire = try h.dictionary.decodeWire(allocator, sample.hex);
        defer allocator.free(expected_wire);
        const options = try xz.EncodeOptions.fromPreset(sample.level, sample.extreme);
        const actual = try xz.encodeAlloc(allocator, h.dictionary.preset_plain, options);
        defer allocator.free(actual);
        try std.testing.expectEqualSlices(u8, expected_wire, actual);
    }
}

test "XZ large chunk large dictionary metadata and bounded tiny decode preserve caller requests" {
    try std.testing.expectEqual(@as(usize, h.dictionary.max_dictionary_size), xz.max_encode_dictionary_size);
    for (h.dictionary.dictionary_cases) |sample| {
        var ledger = h.dictionary.HeapLedger.init(allocator, 8 * 1024 * 1024);
        {
            const options: xz.EncodeOptions = .{ .dictionary_size = sample.requested, .parser = .literal_only, .chunk_size = h.max_chunk_size };
            const encoded = try xz.encodeAlloc(ledger.allocator(), h.dictionary.preset_plain, options);
            defer ledger.allocator().free(encoded);
            const block = try h.firstBlock(encoded);
            try std.testing.expectEqual(sample.property, block.dictionary_property);
            try std.testing.expectEqual(sample.advertised, block.advertised_dictionary_size);
            var output: [h.dictionary.preset_plain.len]u8 = undefined;
            _ = try xz.decodeInto(ledger.allocator(), encoded, &output);
            try std.testing.expectEqualSlices(u8, h.dictionary.preset_plain, &output);
            var raw: std.ArrayList(u8) = .empty;
            defer raw.deinit(ledger.allocator());
            _ = try xz.encodeRawLzma2AppendWithOptions(ledger.allocator(), &raw, h.dictionary.preset_plain, options.lzma2Options());
            try h.decodeRaw(ledger.allocator(), raw.items, h.dictionary.preset_plain, sample.property);
        }
        try std.testing.expectEqual(@as(usize, 0), ledger.live);
        try std.testing.expect(ledger.peak < 4 * 1024 * 1024 and ledger.largest_request < 4 * 1024 * 1024);
        try std.testing.expectEqual(@as(usize, 0), ledger.denied_requests);
    }
}

test "LZMA2 large chunk public limits defaults presets and explicit pending cap stay distinct" {
    try std.testing.expectEqual(h.max_chunk_size, xz.max_encode_chunk_size);
    try std.testing.expectEqual(h.max_compressed_payload_size, xz.max_compressed_payload_size);
    try std.testing.expectEqual(h.max_stored_chunk_size, xz.max_stored_chunk_size);
    try std.testing.expectEqual(@as(usize, 65536), (xz.EncodeOptions{}).chunk_size);
    try std.testing.expectEqual(@as(usize, 65552), try (xz.RawLzma2IncrementalEncoder.Options{}).effectiveMaxPendingOutputLen());
    for (h.preset_wires) |preset| {
        try std.testing.expectEqual(@as(usize, 65536), (try xz.EncodeOptions.fromPreset(preset.level, preset.extreme)).chunk_size);
        try std.testing.expectEqual(@as(usize, 65536), (try xz.RawLzma2EncodeOptions.fromPreset(preset.level, preset.extreme)).chunk_size);
        try std.testing.expectEqual(@as(usize, 65536), (try xz.RawLzma2IncrementalEncoder.Options.fromPreset(preset.level, preset.extreme)).chunk_size);
        try std.testing.expectEqual(@as(usize, 65536), (try xz.IncrementalEncoder.Options.fromPreset(preset.level, preset.extreme)).chunk_size);
    }
    const automatic: xz.RawLzma2IncrementalEncoder.Options = .{ .chunk_size = h.max_chunk_size };
    try std.testing.expectEqual(h.max_chunk_size + 3 * 32 + 13, try automatic.effectiveMaxPendingOutputLen());
    const explicit: xz.RawLzma2IncrementalEncoder.Options = .{ .chunk_size = h.max_chunk_size, .max_pending_output_len = 17 };
    try std.testing.expectEqual(@as(usize, 17), try explicit.effectiveMaxPendingOutputLen());
    try std.testing.expectEqual(@as(usize, 65536), (xz.RawLzma2IncrementalEncoder.Options{ .mode = .stored, .chunk_size = h.max_chunk_size }).inputGroupSize());
    for ([_]usize{ 0, h.max_chunk_size + 1, std.math.maxInt(usize) }) |invalid| {
        var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
        const backing = failing.allocator();
        try std.testing.expectError(error.InvalidBlockPlan, xz.encodeAlloc(backing, "invalid chunk", .{ .chunk_size = invalid }));
        try std.testing.expectError(error.InvalidBlockPlan, xz.RawLzma2IncrementalEncoder.init(backing, .{ .chunk_size = invalid }));
        try std.testing.expectError(error.InvalidBlockPlan, xz.IncrementalEncoder.initWithOptions(backing, .{ .chunk_size = invalid }));
        try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
        try std.testing.expect(!failing.has_induced_failure);
    }
    for ([_]usize{ 0, 4095, @as(usize, h.dictionary.max_dictionary_size) + 1, std.math.maxInt(usize) }) |invalid| {
        try std.testing.expectError(error.InvalidBlockPlan, (xz.EncodeOptions{ .dictionary_size = invalid }).validate());
        try std.testing.expectError(error.InvalidBlockPlan, (xz.RawLzma2EncodeOptions{ .dictionary_size = invalid }).validate());
    }
}

test "LZMA2 large chunk exact two MiB uses all high bits and one byte tail splits" {
    const input = try h.repetitive(allocator, h.max_chunk_size + 1);
    defer allocator.free(input);
    const options: xz.RawLzma2EncodeOptions = .{ .chunk_size = h.max_chunk_size, .parser = .fast, .match_options = .{ .finder = .hc4, .max_working_memory = 2 * 1024 * 1024 } };
    for ([_]usize{ h.max_chunk_size, h.max_chunk_size + 1 }) |length| {
        var raw: std.ArrayList(u8) = .empty;
        defer raw.deinit(allocator);
        _ = try xz.encodeRawLzma2AppendWithOptions(allocator, &raw, input[0..length], options);
        var packets = try h.packets(allocator, raw.items);
        defer packets.deinit(allocator);
        try std.testing.expectEqual(length, packets.plain_len);
        try std.testing.expectEqual(raw.items.len, packets.encoded_len);
        try std.testing.expectEqual(if (length == h.max_chunk_size) @as(usize, 1) else 2, packets.items.items.len);
        const first = packets.items.items[0];
        try std.testing.expectEqual(@as(u8, 0xff), first.control);
        try std.testing.expectEqual(h.max_chunk_size, first.plain_len);
        try std.testing.expect(first.compressed_len.? <= h.max_compressed_payload_size);
        try std.testing.expectEqual(@as(?u8, 0x5d), first.properties);
        if (length > h.max_chunk_size) {
            const tail = packets.items.items[1];
            try std.testing.expectEqual(@as(u8, 2), tail.control);
            try std.testing.expectEqual(@as(usize, 1), tail.plain_len);
        }
        try h.decodeRaw(allocator, raw.items, input[0..length], 0);
    }
    const encoded = try xz.encodeAlloc(allocator, input, .{ .block_size = input.len, .chunk_size = options.chunk_size, .parser = options.parser, .match_options = options.match_options });
    defer allocator.free(encoded);
    const block = try h.firstBlock(encoded);
    var packets = try h.packets(allocator, encoded[block.payload_offset..]);
    defer packets.deinit(allocator);
    try std.testing.expectEqual(@as(u8, 0xff), packets.items.items[0].control);
    const decoded = try xz.decodeAlloc(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "LZMA2 large chunk finished payload exact cap and one over arbitrate against every stored header" {
    for (h.payload_boundaries) |boundary| {
        const input = try h.payloadBoundaryPlain(allocator, boundary);
        defer allocator.free(input);
        var raw: std.ArrayList(u8) = .empty;
        defer raw.deinit(allocator);
        _ = try xz.encodeRawLzma2AppendWithOptions(allocator, &raw, input, .{ .chunk_size = h.max_chunk_size, .parser = .literal_only, .match_options = .{ .max_working_memory = 0 } });
        var packets = try h.packets(allocator, raw.items);
        defer packets.deinit(allocator);
        try std.testing.expectEqual(input.len, packets.plain_len);
        if (boundary.payload_len == h.max_compressed_payload_size) {
            try std.testing.expectEqual(@as(usize, 1), packets.items.items.len);
            const packet = packets.items.items[0];
            try std.testing.expectEqual(@as(u8, 0xe1), packet.control);
            try std.testing.expectEqual(@as(?usize, 65536), packet.compressed_len);
            try std.testing.expectEqual(input.len + 6, raw.items.len);
            var digest: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(raw.items[packet.payload_offset..][0..boundary.payload_len], &digest, .{});
            try std.testing.expectEqualSlices(u8, &boundary.payload_sha256, &digest);
        } else {
            try std.testing.expectEqual(@as(usize, 2), packets.items.items.len);
            try std.testing.expectEqual(@as(u8, 1), packets.items.items[0].control);
            try std.testing.expectEqual(@as(u8, 2), packets.items.items[1].control);
            try std.testing.expectEqual(input.len + 7, raw.items.len);
            for (packets.items.items) |packet| try std.testing.expectEqual(@as(?usize, null), packet.compressed_len);
        }
        try h.decodeRaw(allocator, raw.items, input, 0);
    }
}

test "LZMA2 large chunk literal two MiB fallback splits only stored packets and preserves source" {
    const input = try h.noise(allocator, h.max_chunk_size + 1);
    defer allocator.free(input);
    var raw: std.ArrayList(u8) = .empty;
    defer raw.deinit(allocator);
    _ = try xz.encodeRawLzma2AppendWithOptions(allocator, &raw, input, .{ .chunk_size = h.max_chunk_size, .parser = .literal_only, .match_options = .{ .max_working_memory = 0 } });
    var packets = try h.packets(allocator, raw.items);
    defer packets.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 33), packets.items.items.len);
    try std.testing.expectEqual(input.len, packets.plain_len);
    var source_offset: usize = 0;
    for (packets.items.items, 0..) |packet, index| {
        try std.testing.expectEqual(if (index == 0) @as(u8, 1) else 2, packet.control);
        try std.testing.expectEqual(@as(?usize, null), packet.compressed_len);
        try std.testing.expect(packet.plain_len <= h.max_stored_chunk_size);
        try std.testing.expectEqualSlices(u8, input[source_offset..][0..packet.plain_len], raw.items[packet.payload_offset..][0..packet.plain_len]);
        source_offset += packet.plain_len;
    }
    try std.testing.expectEqual(input.len, source_offset);
    try h.decodeRaw(allocator, raw.items, input, 0);
}

test "LZMA2 large chunk multi stored fallback retains history and chooses C0 A0 resets" {
    const group_len: usize = 131072;
    const tail_len: usize = 1024;
    const random = try h.noise(allocator, group_len);
    defer allocator.free(random);
    const repeated = try h.repetitive(allocator, group_len);
    defer allocator.free(repeated);
    for ([_]bool{ false, true }) |compressed_first| {
        var input: std.ArrayList(u8) = .empty;
        defer input.deinit(allocator);
        if (compressed_first) try input.appendSlice(allocator, repeated);
        try input.appendSlice(allocator, random);
        try input.appendSlice(allocator, random[0..tail_len]);
        var raw: std.ArrayList(u8) = .empty;
        defer raw.deinit(allocator);
        _ = try xz.encodeRawLzma2AppendWithOptions(allocator, &raw, input.items, .{ .chunk_size = group_len, .dictionary_size = 262144, .parser = .fast, .properties = .{ .lc = 2, .lp = 1, .pb = 1 }, .match_options = .{ .finder = .hc4, .max_working_memory = 8 * 1024 * 1024 } });
        var packets = try h.packets(allocator, raw.items);
        defer packets.deinit(allocator);
        try std.testing.expectEqual(if (compressed_first) @as(usize, 4) else 3, packets.items.items.len);
        const stored_offset: usize = @intFromBool(compressed_first);
        for (packets.items.items[stored_offset..][0..2], 0..) |packet, index| {
            try std.testing.expectEqual(@as(usize, 65536), packet.plain_len);
            try std.testing.expectEqual(if (!compressed_first and index == 0) @as(u8, 1) else 2, packet.control);
        }
        const tail = packets.items.items[packets.items.items.len - 1];
        try std.testing.expectEqual(if (compressed_first) @as(u8, 0xa0) else 0xc0, tail.control);
        try std.testing.expectEqual(tail_len, tail.plain_len);
        try std.testing.expectEqual(if (compressed_first) @as(?u8, null) else 56, tail.properties);
        try h.decodeRaw(allocator, raw.items, input.items, 12);
    }
}

test "LZMA2 large chunk compressed fragment output one owned move reset match one shot" {
    const input = try h.repetitive(allocator, h.max_chunk_size + 1);
    defer allocator.free(input);
    const options: xz.RawLzma2IncrementalEncoder.Options = .{ .chunk_size = h.max_chunk_size, .parser = .fast, .match_options = .{ .finder = .hc4, .max_working_memory = 2 * 1024 * 1024 } };
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);
    _ = try xz.encodeRawLzma2AppendWithOptions(allocator, &expected, input, options.chunkOptions());
    var original = try xz.RawLzma2IncrementalEncoder.initExactSize(allocator, options, input.len);
    var transferred = false;
    defer if (!transferred) original.deinit();
    const first = try h.drive(xz.RawLzma2IncrementalEncoder, allocator, &original, input, 257, 1);
    defer allocator.free(first);
    try std.testing.expectEqualSlices(u8, expected.items, first);
    try std.testing.expectEqual(input.len, original.snapshot().encoded_input);
    try std.testing.expectEqual(h.max_chunk_size, original.snapshot().input_group_size);
    try original.reset();
    var moved = original;
    original = undefined;
    transferred = true;
    defer moved.deinit();
    const second = try h.drive(xz.RawLzma2IncrementalEncoder, allocator, &moved, input, 17, 31);
    defer allocator.free(second);
    try std.testing.expectEqualSlices(u8, expected.items, second);
}

test "XZ large chunk complete blocks fragment output one and flush retain selected group size" {
    const input = try h.repetitive(allocator, 131073);
    defer allocator.free(input);
    const options: xz.IncrementalEncoder.Options = .{ .block_size = input.len * 2, .chunk_size = 131072, .parser = .fast, .match_options = .{ .finder = .hc4, .max_working_memory = 2 * 1024 * 1024 } };
    const expected = try xz.encodeAlloc(allocator, input, options.writerOptions());
    defer allocator.free(expected);
    var encoder = try xz.IncrementalEncoder.initExactSize(allocator, options, input.len);
    defer encoder.deinit();
    const actual = try h.drive(xz.IncrementalEncoder, allocator, &encoder, input, 1, 1);
    defer allocator.free(actual);
    try std.testing.expectEqualSlices(u8, expected, actual);
    encoder.reset();
    const header = try encoder.step("", &.{});
    try std.testing.expectEqual(@as(usize, 0), header.progress.input_read);
    var prefix: std.ArrayList(u8) = .empty;
    defer prefix.deinit(allocator);
    var output: [31]u8 = undefined;
    while (encoder.snapshot().pending_output != 0) {
        const step = try encoder.step("", &output);
        try prefix.appendSlice(allocator, output[0..step.progress.output_written]);
    }
    const accepted = try encoder.step(input, &.{});
    try std.testing.expectEqual(input.len, accepted.progress.input_read);
    encoder.flush();
    _ = try encoder.step("", &.{});
    try std.testing.expectEqual(@as(usize, 1), encoder.snapshot().block_count);
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().buffered_input);
    try std.testing.expect(!encoder.snapshot().finishing);
    const remaining = try h.drive(xz.IncrementalEncoder, allocator, &encoder, input, 257, 31);
    defer allocator.free(remaining);
    try prefix.appendSlice(allocator, remaining);
    try std.testing.expectEqualSlices(u8, expected, prefix.items);
}

test "LZMA2 large chunk explicit pending cap fails before commit then retries buffered input" {
    const input = try h.payloadBoundaryPlain(allocator, h.payload_boundaries[1]);
    defer allocator.free(input);
    const group_size = input.len + 6;
    const options: xz.RawLzma2IncrementalEncoder.Options = .{ .chunk_size = h.max_chunk_size, .parser = .literal_only, .max_pending_output_len = group_size - 1, .match_options = .{ .max_working_memory = 0 } };
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);
    _ = try xz.encodeRawLzma2AppendWithOptions(allocator, &expected, input, options.chunkOptions());
    var encoder = try xz.RawLzma2IncrementalEncoder.initExactSize(allocator, options, input.len);
    defer encoder.deinit();
    const accepted = try encoder.step(input, &.{});
    try std.testing.expectEqual(input.len, accepted.progress.input_read);
    encoder.finish();
    const before = encoder.snapshot();
    try std.testing.expectError(error.OutputLimitExceeded, encoder.step("", &.{}));
    const after = encoder.snapshot();
    try std.testing.expectEqual(before.input_read, after.input_read);
    try std.testing.expectEqual(before.buffered_input, after.buffered_input);
    try std.testing.expectEqual(@as(usize, 0), after.encoded_input);
    try std.testing.expectEqual(@as(usize, 0), after.pending_output);
    try std.testing.expectEqual(@as(usize, 0), after.buffered_history);
    try std.testing.expect(!after.model_valid and !after.properties_initialized);
    try std.testing.expectEqual(group_size - 1, try encoder.options.effectiveMaxPendingOutputLen());
    encoder.options.max_pending_output_len = group_size;
    const actual = try h.drive(xz.RawLzma2IncrementalEncoder, allocator, &encoder, input, 1, 1);
    defer allocator.free(actual);
    try std.testing.expectEqualSlices(u8, expected.items, actual);
}

test "LZMA2 large chunk empty size input limits and working budget never become stored fallback" {
    var raw = try xz.RawLzma2IncrementalEncoder.initExactSize(allocator, .{ .chunk_size = h.max_chunk_size, .parser = .fast }, 0);
    defer raw.deinit();
    const empty = try h.drive(xz.RawLzma2IncrementalEncoder, allocator, &raw, "", 1, 1);
    defer allocator.free(empty);
    try std.testing.expectEqualSlices(u8, &.{0}, empty);
    try std.testing.expectError(error.TrailingData, raw.step("x", &.{}));
    try std.testing.expectError(error.OutputLimitExceeded, xz.RawLzma2IncrementalEncoder.initExactSize(allocator, .{ .chunk_size = h.max_chunk_size, .max_input_len = 3 }, 4));
    var limited = try xz.RawLzma2IncrementalEncoder.init(allocator, .{ .chunk_size = h.max_chunk_size, .max_input_len = 3 });
    defer limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, limited.step("four", &.{}));
    try std.testing.expectEqual(@as(usize, 0), limited.snapshot().input_read);
    var short = try xz.RawLzma2IncrementalEncoder.initExactSize(allocator, .{ .chunk_size = h.max_chunk_size }, 4);
    defer short.deinit();
    _ = try short.step("abc", &.{});
    short.finish();
    try std.testing.expectError(error.SizeMismatch, short.step("", &.{}));
    try std.testing.expectEqual(@as(usize, 3), short.snapshot().buffered_input);
    try std.testing.expectEqual(@as(usize, 0), short.snapshot().encoded_input);
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    try output.appendSlice(allocator, "prefix:");
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, xz.encodeRawLzma2AppendWithOptions(allocator, &output, h.dictionary.preset_plain, .{ .chunk_size = h.max_chunk_size, .parser = .fast, .match_options = .{ .finder = .hc4, .max_working_memory = 0 } }));
    try std.testing.expectEqualStrings("prefix:", output.items);
}

test "XZ large chunk overlapping Into and raw append preserve source on short destination" {
    const input = try h.payloadBoundaryPlain(allocator, h.payload_boundaries[1]);
    defer allocator.free(input);
    const options: xz.EncodeOptions = .{ .chunk_size = h.max_chunk_size, .parser = .literal_only, .match_options = .{ .max_working_memory = 0 } };
    const expected = try xz.encodeAlloc(allocator, input, options);
    defer allocator.free(expected);
    const buffer = try allocator.alloc(u8, expected.len + 32);
    defer allocator.free(buffer);
    @memset(buffer, 0xa5);
    @memcpy(buffer[0..input.len], input);
    const before = try allocator.dupe(u8, buffer);
    defer allocator.free(before);
    try std.testing.expectError(error.OutputTooSmall, xz.encodeInto(allocator, buffer[0..input.len], buffer[0 .. expected.len - 1], options));
    try std.testing.expectEqualSlices(u8, before, buffer);
    _ = try xz.encodeInto(allocator, buffer[0..input.len], buffer, options);
    try std.testing.expectEqualSlices(u8, expected, buffer[0..expected.len]);
    try std.testing.expectEqualSlices(u8, before[expected.len..], buffer[expected.len..]);
    var raw_expected: std.ArrayList(u8) = .empty;
    defer raw_expected.deinit(allocator);
    _ = try xz.encodeRawLzma2AppendWithOptions(allocator, &raw_expected, input, options.lzma2Options());
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    try output.appendSlice(allocator, input);
    _ = try xz.encodeRawLzma2AppendWithOptions(allocator, &output, output.items, options.lzma2Options());
    try std.testing.expectEqualSlices(u8, input, output.items[0..input.len]);
    try std.testing.expectEqualSlices(u8, raw_expected.items, output.items[input.len..]);
}

fn AllocationGraph(comptime raw: bool) type {
    return struct {
        pub fn run(backing: std.mem.Allocator, input: []const u8, expected: []const u8) !void {
            var output: std.ArrayList(u8) = .empty;
            defer output.deinit(backing);
            try output.appendSlice(backing, input);
            const options: xz.EncodeOptions = .{ .chunk_size = h.max_chunk_size, .parser = .literal_only, .match_options = .{ .max_working_memory = 0 } };
            const result = if (raw) xz.encodeRawLzma2AppendWithOptions(backing, &output, output.items, options.lzma2Options()) else xz.encodeAppend(backing, &output, output.items, options);
            _ = result catch |err| {
                try std.testing.expectEqualSlices(u8, input, output.items);
                return err;
            };
            try std.testing.expectEqualSlices(u8, input, output.items[0..input.len]);
            try std.testing.expectEqualSlices(u8, expected, output.items[input.len..]);
        }
    };
}

test "XZ large chunk short allocation traces propagate real OOM even on payload overflow fallback" {
    const input = try h.payloadBoundaryPlain(allocator, h.payload_boundaries[1]);
    defer allocator.free(input);
    var raw: std.ArrayList(u8) = .empty;
    defer raw.deinit(allocator);
    _ = try xz.encodeRawLzma2AppendWithOptions(allocator, &raw, input, .{ .chunk_size = h.max_chunk_size, .parser = .literal_only, .match_options = .{ .max_working_memory = 0 } });
    const encoded = try xz.encodeAlloc(allocator, input, .{ .chunk_size = h.max_chunk_size, .parser = .literal_only, .match_options = .{ .max_working_memory = 0 } });
    defer allocator.free(encoded);
    try std.testing.checkAllAllocationFailures(allocator, AllocationGraph(true).run, .{ input, raw.items });
    try std.testing.checkAllAllocationFailures(allocator, AllocationGraph(false).run, .{ input, encoded });
}

test "LZMA2 large chunk real emission OOM retains group and succeeds after allocator recovery" {
    const input = try h.payloadBoundaryPlain(allocator, h.payload_boundaries[1]);
    defer allocator.free(input);
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);
    const options: xz.RawLzma2IncrementalEncoder.Options = .{ .chunk_size = h.max_chunk_size, .parser = .literal_only, .match_options = .{ .max_working_memory = 0 } };
    _ = try xz.encodeRawLzma2AppendWithOptions(allocator, &expected, input, options.chunkOptions());
    var failing = std.testing.FailingAllocator.init(allocator, .{});
    {
        var encoder = try xz.RawLzma2IncrementalEncoder.initExactSize(failing.allocator(), options, input.len);
        defer encoder.deinit();
        _ = try encoder.step(input, &.{});
        encoder.finish();
        failing.fail_index = failing.alloc_index;
        try std.testing.expectError(error.OutOfMemory, encoder.step("", &.{}));
        try std.testing.expectEqual(input.len, encoder.snapshot().buffered_input);
        try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().encoded_input);
        try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().pending_output);
        try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().buffered_history);
        failing.fail_index = std.math.maxInt(usize);
        const actual = try h.drive(xz.RawLzma2IncrementalEncoder, allocator, &encoder, input, 1, 31);
        defer allocator.free(actual);
        try std.testing.expectEqualSlices(u8, expected.items, actual);
    }
    try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
}

test "LZMA2 large chunk stored mode keeps legacy packets and one byte configured groups are valid" {
    const input = try h.payloadBoundaryPlain(allocator, h.payload_boundaries[1]);
    defer allocator.free(input);
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);
    _ = try xz.encodeRawLzma2StoredAppend(allocator, &expected, input);
    var encoder = try xz.RawLzma2IncrementalEncoder.initExactSize(allocator, .{ .mode = .stored, .chunk_size = h.max_chunk_size }, input.len);
    defer encoder.deinit();
    const actual = try h.drive(xz.RawLzma2IncrementalEncoder, allocator, &encoder, input, 257, 31);
    defer allocator.free(actual);
    try std.testing.expectEqualSlices(u8, expected.items, actual);
    try std.testing.expectEqual(@as(usize, 65536), encoder.snapshot().input_group_size);
    var tiny: std.ArrayList(u8) = .empty;
    defer tiny.deinit(allocator);
    _ = try xz.encodeRawLzma2AppendWithOptions(allocator, &tiny, "groups", .{ .chunk_size = 1, .parser = .literal_only, .match_options = .{ .max_working_memory = 0 } });
    var packets = try h.packets(allocator, tiny.items);
    defer packets.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 6), packets.items.items.len);
    for (packets.items.items) |packet| try std.testing.expectEqual(@as(usize, 1), packet.plain_len);
    try h.decodeRaw(allocator, tiny.items, "groups", 0);
}
