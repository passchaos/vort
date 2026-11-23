const std = @import("std");
const br = @import("../../../br.zig");
const core = @import("../../../core.zig");

const a = std.testing.allocator;
const expect = std.testing.expect;
const equal = std.testing.expectEqual;
const equalBytes = std.testing.expectEqualSlices;
const encoders = .{
    br.IncrementalStoredStreamEncoder,
    br.IncrementalPlannedStreamEncoder,
    br.IncrementalStaticDictionaryStreamEncoder,
};
const max_metadata_len: usize = 1 << 24;
const scratch_len = 509;

fn feedPlain(encoder: anytype, plain: []const u8, wire: *std.ArrayList(u8), stride: usize) !void {
    var scratch: [scratch_len]u8 = undefined;
    var offset: usize = 0;
    while (offset < plain.len) {
        const step = try encoder.step(plain[offset..], scratch[0..stride]);
        try expect(step.progress.input_read != 0 or step.progress.output_written != 0);
        offset += step.progress.input_read;
        try wire.appendSlice(a, scratch[0..step.progress.output_written]);
    }
    try equal(plain.len, offset);
}

fn drain(encoder: anytype, wire: *std.ArrayList(u8), stride: usize, end: core.StepResult.Status) !void {
    var scratch: [scratch_len]u8 = undefined;
    while (true) {
        const step = try encoder.step("", scratch[0..stride]);
        try equal(@as(usize, 0), step.progress.input_read);
        try wire.appendSlice(a, scratch[0..step.progress.output_written]);
        if (step.status == end) return;
        try equal(.need_output, step.status);
        try expect(step.progress.output_written != 0);
    }
}

fn stepMetadata(encoder: anytype, input: []const u8, output: []u8) !core.StepResult {
    const before = encoder.snapshot();
    try expect(before.metadata_pending and before.metadata_streaming);
    const step = try encoder.stepMetadata(input, output);
    const after = encoder.snapshot();
    const read = step.progress.input_read;
    const written = step.progress.output_written;
    try expect(read <= input.len and read <= before.metadata_bytes);
    try expect(written <= output.len);
    try equal(before.metadata_bytes - read, after.metadata_bytes);
    try equal(after.metadata_pending, after.metadata_streaming);
    try equal(before.input_read, after.input_read);
    try equal(before.stream_input, after.stream_input);
    try equal(before.output_written + written, after.output_written);
    try equal(before.stream_output + written, after.stream_output);
    try expect(step.status == .need_input or step.status == .need_output);
    if (step.status == .need_input) try equal(input.len, read);
    if (step.status == .need_output and output.len != 0) try expect(read != 0 or written != 0);
    return step;
}

fn streamBody(encoder: anytype, body: []const u8, wire: *std.ArrayList(u8), stride: usize) !void {
    try equal(body.len, encoder.snapshot().metadata_bytes);
    const blocked = try stepMetadata(encoder, body[0..@min(body.len, 1)], &.{});
    try equal(.need_output, blocked.status);
    try equal(@as(usize, 0), blocked.progress.input_read);
    try equal(@as(usize, 0), blocked.progress.output_written);

    var scratch: [scratch_len]u8 = undefined;
    var offset: usize = 0;
    var end = @min(body.len, stride + 2);
    while (true) {
        const step = try stepMetadata(encoder, body[offset..end], scratch[0..stride]);
        offset += step.progress.input_read;
        try wire.appendSlice(a, scratch[0..step.progress.output_written]);
        if (step.status == .need_input) {
            if (!encoder.snapshot().metadata_pending) {
                try equal(body.len, offset);
                return;
            }
            try expect(offset < body.len);
            // Leave some fragments only partly consumed by output backpressure.
            end = offset + @min(body.len - offset, stride + 1 + offset % 23);
        }
    }
}

const Layout = enum { fresh, buffered, full_block, pending_output, pending_prefix, chunk_boundary, flush_requested };
const lead = "The quick brown fox jumps over the lazy dog. " ** 2;
const following = "The quick brown fox continues.";
const prefix_metadata = "preamble";

fn prepare(encoder: anytype, layout: Layout, plain: []const u8, wire: *std.ArrayList(u8), stride: usize) !void {
    try feedPlain(encoder, plain, wire, stride);
    switch (layout) {
        .pending_output, .pending_prefix => {
            if (layout == .pending_output) encoder.endChunk();
            try equal(.need_output, (try encoder.step("", &.{})).status);
            try expect(encoder.snapshot().pending_output != 0);
        },
        .chunk_boundary => {
            encoder.endChunk();
            try drain(encoder, wire, stride, .need_input);
        },
        .flush_requested => encoder.flush(),
        .buffered => try equal(plain.len, encoder.snapshot().buffered_input),
        else => {},
    }
}

fn checkCapture(wire: []const u8, first: []const u8, following_plain: []const u8, prefix: []const u8, body: []const u8) !void {
    var history: [128]u8 = undefined;
    var decoded: [128]u8 = undefined;
    var lengths: [2]usize = undefined;
    const captured = try a.alloc(u8, prefix.len + body.len);
    defer a.free(captured);
    var decoder = br.IncrementalCopyStreamDecoder.initWithOptions(&history, .{
        .expected_output_len = first.len + following_plain.len,
        .metadata_output = captured,
        .metadata_block_lengths = &lengths,
    });
    const step = try decoder.step(wire, &decoded);
    try equal(.done, step.status);
    try equal(wire.len, step.progress.input_read);
    try equal(first.len + following_plain.len, step.progress.output_written);
    try equalBytes(u8, first, decoded[0..first.len]);
    try equalBytes(u8, following_plain, decoded[first.len..step.progress.output_written]);
    const prefix_blocks: usize = @intFromBool(prefix.len != 0);
    const snapshot = decoder.snapshot();
    try equal(@as(br.Counter, 1 + prefix_blocks), snapshot.metadata_block_count);
    try equal(@as(br.Counter, captured.len), snapshot.metadata_total);
    if (prefix_blocks != 0) try equal(prefix.len, lengths[0]);
    try equal(body.len, lengths[prefix_blocks]);
    try equalBytes(u8, prefix, captured[0..prefix.len]);
    try equalBytes(u8, body, captured[prefix.len..]);
}

fn checkWire(comptime Encoder: type, layout: Layout, body: []const u8, stride: usize) !void {
    const plain = switch (layout) {
        .fresh, .pending_prefix => "",
        .full_block => lead[0..64],
        else => lead[0..55],
    };
    const tail = if (layout == .fresh) "" else following;
    const prefix = if (layout == .pending_prefix) prefix_metadata else "";
    var options: Encoder.Options = .{
        .stream = .{ .metadata = prefix },
        .block_len = 64,
        .max_input_len = plain.len + tail.len,
    };
    if (layout == .fresh) options.stream.window_bits = 16;
    if (comptime Encoder == br.IncrementalPlannedStreamEncoder) options.stream.quality = 4;
    var streamed = Encoder.initWithOptions(a, options);
    defer streamed.deinit();
    var legacy = Encoder.initWithOptions(a, options);
    defer legacy.deinit();
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(a);
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(a);
    try prepare(&streamed, layout, plain, &actual, stride);
    try prepare(&legacy, layout, plain, &expected, stride);
    try streamed.beginMetadata(body.len);
    if (body.len == 0) {
        // Zero body bytes does not mean that the metadata header was drained.
        const before = streamed.snapshot();
        try expect(before.metadata_pending and before.metadata_streaming);
        try std.testing.expectError(error.InvalidStreamState, streamed.finish());
        try equal(before, streamed.snapshot());
    }
    try streamBody(&streamed, body, &actual, stride);
    try legacy.writeMetadata(body);
    try drain(&legacy, &expected, stride, .need_input);
    try feedPlain(&streamed, tail, &actual, stride);
    try feedPlain(&legacy, tail, &expected, stride);
    try streamed.finish();
    try legacy.finish();
    try drain(&streamed, &actual, stride, .done);
    try drain(&legacy, &expected, stride, .done);
    try equalBytes(u8, expected.items, actual.items);
    const snapshot = streamed.snapshot();
    try expect(!snapshot.metadata_pending and !snapshot.metadata_streaming);
    try equal(@as(Encoder.Counter, plain.len + tail.len), snapshot.input_read);
    try equal(@as(Encoder.Counter, actual.items.len), snapshot.output_written);
    try checkCapture(actual.items, plain, tail, prefix, body);
}

test "Brotli streamed metadata matches legacy wire at block boundaries and metadata lengths" {
    const patterned = try a.alloc(u8, 65537);
    defer a.free(patterned);
    for (patterned, 0..) |*byte, i| byte.* = @truncate(i ^ (i >> 3));
    inline for (encoders) |Encoder| {
        for (std.enums.values(Layout)) |layout| {
            for ([_]usize{ 0, 1, 256, 257 }) |len| try checkWire(Encoder, layout, patterned[0..len], 1);
        }
        try checkWire(Encoder, .chunk_boundary, patterned[0..65536], scratch_len);
        try checkWire(Encoder, .pending_prefix, patterned, scratch_len);
    }
}

fn rejectMetadata(encoder: anytype, err: anyerror, input: []const u8, output: []u8) !void {
    const before = encoder.snapshot();
    const memory = encoder.memorySnapshot();
    const retained = encoder.retainedCapacity();
    const source = try a.dupe(u8, input);
    defer a.free(source);
    const dest = try a.dupe(u8, output);
    defer a.free(dest);
    try std.testing.expectError(err, encoder.stepMetadata(input, output));
    try equal(before, encoder.snapshot());
    try equal(memory, encoder.memorySnapshot());
    try equal(retained, encoder.retainedCapacity());
    try equalBytes(u8, source, input);
    try equalBytes(u8, dest, output);
}

fn checkGuards(comptime Encoder: type) !void {
    var prefix: [1]u8 = .{'P'};
    const options: Encoder.Options = .{ .stream = .{ .metadata = &prefix }, .block_len = 8 };
    var encoder = Encoder.initWithOptions(a, options);
    defer encoder.deinit();
    var legacy = Encoder.initWithOptions(a, options);
    defer legacy.deinit();
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(a);
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(a);
    var dest: [16]u8 = @splat(0xa5);
    const untouched = dest;

    const fresh = encoder.snapshot();
    try std.testing.expectError(error.InvalidBlockPlan, encoder.beginMetadata(max_metadata_len + 1));
    try equal(fresh, encoder.snapshot());
    try rejectMetadata(&encoder, error.InvalidStreamState, "", &dest);
    try encoder.writeMetadata("old");
    const queued = encoder.snapshot();
    try expect(queued.metadata_pending and !queued.metadata_streaming);
    try std.testing.expectError(error.InvalidStreamState, encoder.beginMetadata(4));
    try equal(queued, encoder.snapshot());
    try legacy.writeMetadata("old");
    try drain(&encoder, &actual, 3, .need_input);
    try drain(&legacy, &expected, 3, .need_input);

    try encoder.beginMetadata(4);
    const active = encoder.snapshot();
    try std.testing.expectError(error.InvalidStreamState, encoder.step("plain", &dest));
    try std.testing.expectError(error.InvalidStreamState, encoder.step("", &dest));
    try std.testing.expectError(error.InvalidStreamState, encoder.finish());
    try std.testing.expectError(error.InvalidStreamState, encoder.beginMetadata(0));
    try std.testing.expectError(error.InvalidBlockPlan, encoder.writeMetadata(""));
    try equal(active, encoder.snapshot());
    try equalBytes(u8, &untouched, &dest);
    try rejectMetadata(&encoder, error.SizeMismatch, "ABCDE", dest[0..0]);
    try rejectMetadata(&encoder, error.SizeMismatch, "ABCDE", &dest);
    try rejectMetadata(&encoder, error.InvalidBlockPlan, "", &prefix);
    try rejectMetadata(&encoder, error.InvalidBlockPlan, std.mem.asBytes(&encoder.done), &dest);
    try rejectMetadata(&encoder, error.InvalidBlockPlan, "", encoder.pending.allocatedSlice()[0..1]);
    var offer: [4]u8 = "Axyz".*;
    try rejectMetadata(&encoder, error.InvalidBlockPlan, &offer, offer[3..]);

    // Publish the header before offering body so any short copy is body only.
    while (true) {
        const header = try stepMetadata(&encoder, "", dest[0..1]);
        try actual.appendSlice(a, dest[0..header.progress.output_written]);
        if (header.status == .need_input) break;
    }
    try equal(@as(usize, 4), encoder.snapshot().metadata_bytes);
    const blocked = try stepMetadata(&encoder, &offer, &.{});
    try equal(.need_output, blocked.status);
    const first = try stepMetadata(&encoder, &offer, dest[0..1]);
    try equal(@as(usize, 1), first.progress.input_read);
    try equalBytes(u8, "A", dest[0..first.progress.output_written]);
    try actual.append(a, dest[0]);
    try rejectMetadata(&encoder, error.SizeMismatch, "BCDE", &dest);
    const partial = encoder.snapshot();
    try equal(@as(usize, 3), partial.metadata_bytes);
    try std.testing.expectError(error.InvalidStreamState, encoder.finish());
    try equal(partial, encoder.snapshot());

    // The unaccepted suffix may be replaced, even reusing its old storage as output.
    const rest = try stepMetadata(&encoder, "BCD", offer[1..]);
    try equal(@as(usize, 3), rest.progress.input_read);
    try equalBytes(u8, "ABCD", offer[0 .. 1 + rest.progress.output_written]);
    try actual.appendSlice(a, offer[1..]);
    if (rest.status == .need_output) {
        const ack = try encoder.stepMetadata("", &dest);
        try equal(.need_input, ack.status);
        try equal(@as(usize, 0), ack.progress.output_written);
    }
    try expect(!encoder.snapshot().metadata_pending);
    try legacy.writeMetadata("ABCD");
    try streamBodyAfterReuse(&encoder, &legacy, &actual, &expected, options);
}

fn streamBodyAfterReuse(encoder: anytype, legacy: @TypeOf(encoder), actual: *std.ArrayList(u8), expected: *std.ArrayList(u8), options: @TypeOf(encoder.options)) !void {
    try encoder.finish();
    try legacy.finish();
    try drain(encoder, actual, 1, .done);
    try drain(legacy, expected, 1, .done);
    try equalBytes(u8, expected.items, actual.items);
    try std.testing.expectError(error.InvalidStreamState, encoder.beginMetadata(1));

    // A subsequent stream is independent, while public output totals continue.
    const first_wire_len = actual.items.len;
    try encoder.nextStream(options);
    try legacy.nextStream(options);
    try encoder.beginMetadata(2);
    try streamBody(encoder, "M2", actual, 1);
    try legacy.writeMetadata("M2");
    try encoder.finish();
    try legacy.finish();
    try drain(encoder, actual, 1, .done);
    try drain(legacy, expected, 1, .done);
    try equalBytes(u8, expected.items, actual.items);
    try equal(@as(br.Counter, 2), encoder.snapshot().stream_count);
    try equal(@as(br.Counter, 0), encoder.snapshot().input_read);
    try equal(@as(br.Counter, actual.items.len), encoder.snapshot().output_written);
    try equal(@as(br.Counter, actual.items.len - first_wire_len), encoder.snapshot().stream_output);
}

test "Brotli streamed metadata guards preserve exact state and retry wire" {
    inline for (encoders) |Encoder| try checkGuards(Encoder);
}

fn checkMaximum(comptime Encoder: type) !void {
    var backing: [4096]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&backing);
    var encoder = Encoder.initWithOptions(fixed.allocator(), .{
        .stream = .{ .window_bits = 16, .max_total_working_memory = backing.len },
        .max_input_len = 0,
    });
    defer encoder.deinit();
    try encoder.beginMetadata(max_metadata_len);

    // WBITS=16, MSKIPBYTES=3, MSKIPLEN=0xffffff, then zero padding.
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    var output: [4093]u8 = undefined;
    while (true) {
        const header = try stepMetadata(&encoder, "", &output);
        try wire.appendSlice(a, output[0..header.progress.output_written]);
        if (header.status == .need_input) break;
    }
    try equalBytes(u8, "\xec\xff\xff\x7f", wire.items);
    try equal(max_metadata_len, encoder.snapshot().metadata_bytes);

    var chunk: [4096]u8 = undefined;
    for (&chunk, 0..) |*byte, i| byte.* = @truncate(i ^ (i >> 4));
    for (0..max_metadata_len / chunk.len) |index| {
        chunk[0] = @truncate(index ^ (index >> 8));
        var offset: usize = 0;
        while (offset < chunk.len) {
            const step = try stepMetadata(&encoder, chunk[offset..], &output);
            const n = step.progress.input_read;
            try expect(n != 0);
            try equalBytes(u8, chunk[offset..][0..n], output[0..step.progress.output_written]);
            offset += n;
        }
    }
    try expect(!encoder.snapshot().metadata_pending);
    try equal(@as(Encoder.Counter, 0), encoder.snapshot().input_read);
    try std.testing.expectError(error.OutputLimitExceeded, encoder.step("x", &output));
    try encoder.finish();
    try drain(&encoder, &wire, 1, .done);
    try equalBytes(u8, "\xec\xff\xff\x7f\x03", wire.items);
    try equal(@as(Encoder.Counter, max_metadata_len + wire.items.len), encoder.snapshot().output_written);
    try expect(encoder.retainedCapacity() <= backing.len);
    try expect(encoder.memorySnapshot().peak_requested_bytes <= backing.len);
}

test "Brotli streamed metadata accepts 16 MiB without retaining a body or using plaintext quota" {
    inline for (encoders) |Encoder| try checkMaximum(Encoder);
}
