const std = @import("std");
const xz = @import("../../xz.zig");
const container = @import("../container.zig");
const writer = @import("../writer.zig");
const filters = @import("../filters.zig");
const core = @import("../../core.zig");
const allocator = std.testing.allocator;

// Python's system liblzma, FORMAT_XZ / CRC64 / LZMA2 dictionary=4096;
// decoded bytes are index % 251 for 65536 bytes. The first compressed chunk
// carries 306 payload bytes, so requiring that whole chunk cannot pass early IO.
const system_hex = "fd377a585a000004e6d6b4460200210100000000372797d6e0ffff01315d00000052500a84f99bb28021a969d627e03e065a5f048d53d404ba39570509c15524de9db871593160a19ff96f4973f2c8ea8cba1a8b29692180fe338366af466dec9e898a0b83f03c0e898e3fed5fe79e90d91cff32f4b2e03951b2d21415b4c571badb06e3799a9fbb38c1b000ac930baa0619031208155b9bc848f0322efe2da087c8f0a4e0d251eb8d675692b24d84c5f18631df6a625bc2792dd9f73c73ba747407d83ca9562224a166f85a845f3067d2f64b492e7f20ebdbf8100e947877c73f6befb4cd95e26ff6446e06cf0b821acbdb7af0578d98ff90c03ee6c1124175ee039ea8e87a0495d1bec07e67727ae0babd59ffcbddb3d2d3ec23f90b9e373dbfd583528a06ed41fd13fb85008dff3a8026808351ac2b6ea82b34ae5b39eabf86227c2c44f5bdd13ff055216b8500000000000039868691bb137d020001cd028080040068e2e37cb1c467fb020000000004595a";

pub const Trace = struct {
    failure: ?anyerror = null,
    input_read: usize = 0,
    output_written: usize = 0,
    first_output_input_offset: ?usize = null,
    max_compressed_capacity: usize = 0,
    max_decoded_capacity: usize = 0,
    peak_working_bytes: usize = 0,
};

pub fn systemFrame() [system_hex.len / 2]u8 {
    var bytes: [system_hex.len / 2]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, system_hex) catch unreachable;
    return bytes;
}

pub fn plainAlloc(length: usize) ![]u8 {
    const input = try allocator.alloc(u8, length);
    for (input, 0..) |*byte, index| byte.* = @intCast(index % 251);
    return input;
}

pub fn pump(decoder: *xz.IncrementalDecoder, encoded: []const u8, expected: []const u8, input_chunk: usize, output_chunk: usize) !Trace {
    std.debug.assert(input_chunk != 0 and output_chunk != 0 and output_chunk <= 4096);
    var trace = Trace{};
    var scratch: [4096]u8 = undefined;
    var finished = false;
    var calls: usize = 0;
    while (true) : (calls += 1) {
        try std.testing.expect(calls < (encoded.len + expected.len + 1) * 16 + 256);
        if (trace.input_read == encoded.len and !finished) {
            decoder.finish();
            finished = true;
        }
        const offered = encoded[trace.input_read..][0..@min(input_chunk, encoded.len - trace.input_read)];
        @memset(&scratch, 0xa5);
        const output = scratch[0..if (calls % 5 == 0) 0 else output_chunk];
        const before = decoder.snapshot();
        const stepped = decoder.step(offered, output) catch |err| {
            const after = decoder.snapshot();
            try account(&trace, decoder, before, after.last_step_progress, offered.len, output, expected);
            try std.testing.expectEqual(@as(?usize, after.input_read), after.error_input_offset);
            try std.testing.expectEqual(@as(?usize, after.output_written), after.error_output_offset);
            try std.testing.expectEqual(core.stream_count.fromOptionalLocal(after.error_input_offset), decoder.diagnostics().error_input_offset);
            try std.testing.expectEqual(core.stream_count.fromOptionalLocal(after.error_output_offset), decoder.diagnostics().error_output_offset);
            trace.failure = err;
            return trace;
        };
        try account(&trace, decoder, before, stepped.progress, offered.len, output, expected);
        if (stepped.status == .done) return trace;
    }
}

pub fn account(trace: *Trace, decoder: *const xz.IncrementalDecoder, before: xz.IncrementalDecoder.Snapshot, progress: core.Progress, offered: usize, output: []const u8, expected: []const u8) !void {
    const after = decoder.snapshot();
    try std.testing.expect(progress.input_read <= offered and progress.output_written <= output.len);
    try std.testing.expectEqual(after.input_read - before.input_read, progress.input_read);
    try std.testing.expectEqual(after.output_written - before.output_written, progress.output_written);
    try std.testing.expectEqualDeep(progress, after.last_step_progress);
    try std.testing.expectEqualDeep(progress, decoder.diagnostics().last_step_progress.?);
    try std.testing.expect(progress.output_written <= expected.len - trace.output_written);
    try std.testing.expectEqualSlices(u8, expected[trace.output_written..][0..progress.output_written], output[0..progress.output_written]);
    for (output[progress.output_written..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    trace.input_read += progress.input_read;
    trace.output_written += progress.output_written;
    if (trace.first_output_input_offset == null and progress.output_written != 0) trace.first_output_input_offset = after.input_read;
    trace.max_compressed_capacity = @max(trace.max_compressed_capacity, after.retained_compressed_capacity);
    trace.max_decoded_capacity = @max(trace.max_decoded_capacity, after.retained_decoded_capacity);
    trace.peak_working_bytes = @max(trace.peak_working_bytes, after.peak_working_bytes);
    try std.testing.expect(after.retained_compressed_capacity <= decoder.options.max_compressed_buffer_len);
    try std.testing.expect(after.retained_decoded_capacity <= decoder.options.max_decoded_buffer_len);
    try std.testing.expect(after.working_bytes <= decoder.options.max_working_memory);
    try std.testing.expect(after.peak_working_bytes <= decoder.options.max_working_memory);
    try std.testing.expectEqual(after.working_bytes, decoder.workingMemoryBytes());
    try std.testing.expectEqual(after.peak_working_bytes, decoder.peakWorkingMemoryBytes());
}

pub fn expectSuccess(trace: Trace, encoded_len: usize, raw_len: usize) !void {
    try std.testing.expectEqual(@as(?anyerror, null), trace.failure);
    try std.testing.expectEqual(encoded_len, trace.input_read);
    try std.testing.expectEqual(raw_len, trace.output_written);
}

fn firstChunkEnd(encoded: []const u8) !usize {
    const start = 12 + (@as(usize, encoded[12]) + 1) * 4;
    const control = encoded[start];
    try std.testing.expect(control >= 0x80);
    const header_len: usize = if ((control >> 5) & 3 >= 2) 6 else 5;
    return start + header_len + @as(usize, std.mem.readInt(u16, encoded[start + 3 ..][0..2], .big)) + 1;
}

fn indexStart(encoded: []const u8) usize {
    const backward = std.mem.readInt(u32, encoded[encoded.len - 8 ..][0..4], .little);
    return encoded.len - 12 - (@as(usize, backward) + 1) * 4;
}

pub fn expectSticky(decoder: *xz.IncrementalDecoder, err: anyerror) !void {
    const before = decoder.snapshot();
    var guard: [31]u8 = @splat(0xa5);
    try std.testing.expectError(err, decoder.step("unconsumed", &guard));
    const after = decoder.snapshot();
    try std.testing.expectEqual(before.input_read, after.input_read);
    try std.testing.expectEqual(before.output_written, after.output_written);
    try std.testing.expectEqualDeep(core.Progress{}, after.last_step_progress);
    try std.testing.expectEqual(@as([31]u8, @splat(0xa5)), guard);
}

fn readVli(input: []const u8, cursor: *usize) u64 {
    var value: u64 = 0;
    var shift: u6 = 0;
    while (true) {
        const byte = input[cursor.*];
        cursor.* += 1;
        value |= @as(u64, byte & 127) << shift;
        if (byte & 128 == 0) return value;
        shift += 7;
    }
}

fn appendVli(out: *std.ArrayList(u8), value_arg: u64) !void {
    var value = value_arg;
    while (value >= 128) : (value >>= 7) try out.append(allocator, @as(u8, @truncate(value)) | 128);
    try out.append(allocator, @intCast(value));
}

fn declaredFrame(packed_size: ?u64, unpacked_size: ?u64, wrong_index: bool) ![]u8 {
    const original = systemFrame();
    const body_start = 12 + (@as(usize, original[12]) + 1) * 4;
    const index_start = indexStart(&original);
    var index_cursor = index_start + 1;
    std.debug.assert(readVli(&original, &index_cursor) == 1);
    const unpadded = readVli(&original, &index_cursor);
    const raw_size = readVli(&original, &index_cursor);
    var header: std.ArrayList(u8) = .empty;
    defer header.deinit(allocator);
    try header.appendSlice(allocator, &.{ 0, (original[13] & 3) | @as(u8, if (packed_size != null) 64 else 0) | @as(u8, if (unpacked_size != null) 128 else 0) });
    if (packed_size) |size| try appendVli(&header, size);
    if (unpacked_size) |size| try appendVli(&header, size);
    try header.appendSlice(allocator, original[14 .. body_start - 4]);
    while ((header.items.len + 4) % 4 != 0) try header.append(allocator, 0);
    header.items[0] = @intCast((header.items.len + 4) / 4 - 1);
    var crc: [4]u8 = undefined;
    std.mem.writeInt(u32, &crc, std.hash.Crc32.hash(header.items), .little);
    try header.appendSlice(allocator, &crc);
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);
    try result.appendSlice(allocator, original[0..12]);
    try result.appendSlice(allocator, header.items);
    try result.appendSlice(allocator, original[body_start..index_start]);
    const record = writer.BlockRecord{
        .unpadded_size = unpadded + header.items.len - (body_start - 12),
        .uncompressed_size = raw_size + @intFromBool(wrong_index),
    };
    try writer.appendStreamEnd(allocator, &result, .crc64, &.{record});
    return result.toOwnedSlice(allocator);
}

fn instructionCorpusAlloc(length: usize) ![]u8 {
    const data = try plainAlloc(length);
    var base: usize = 0;
    while (base + 512 <= data.len) : (base += 512) {
        @memset(data[base + 32 ..][0..16], 0);
        data[base + 32] = 0x10;
        const instruction: u64 = (@as(u64, 5) << 37) | (@as(u64, 1) << 13);
        for (0..41) |bit| {
            const target = 87 + bit;
            data[base + 32 + target / 8] |= @as(u8, @intCast((instruction >> @intCast(bit)) & 1)) << @intCast(target % 8);
        }
        @memcpy(data[base + 64 ..][0..5], &[_]u8{ 0xe8, 1, 0, 0, 0 });
        @memcpy(data[base + 128 ..][0..4], &[_]u8{ 0x48, 0, 0, 5 });
        @memcpy(data[base + 192 ..][0..4], &[_]u8{ 1, 0, 0, 0xeb });
        @memcpy(data[base + 256 ..][0..4], &[_]u8{ 0, 0xf0, 0, 0xf8 });
        @memcpy(data[base + 320 ..][0..4], &[_]u8{ 0x40, 0, 0, 1 });
        @memcpy(data[base + 384 ..][0..4], &[_]u8{ 1, 0, 0, 0x94 });
        @memcpy(data[base + 416 ..][0..4], &[_]u8{ 0, 0, 0, 0x90 });
        @memcpy(data[base + 448 ..][0..4], &[_]u8{ 0xef, 0, 0x40, 0 });
    }
    return data;
}

test "XZ progressive default emits before a complete system compressed LZMA2 chunk and block" {
    const frame = systemFrame();
    const expected = try plainAlloc(65536);
    defer allocator.free(expected);
    const reference = try xz.decodeAlloc(allocator, &frame);
    defer allocator.free(reference);
    try std.testing.expectEqualSlices(u8, expected, reference);
    var decoder = xz.IncrementalDecoder.initWithOptions(allocator, .{
        .max_output_len = expected.len,
        .max_decoded_block_len = expected.len,
        .max_dictionary_size = 4096,
        .max_compressed_buffer_len = 4096,
        .max_decoded_buffer_len = 4096,
        .max_working_memory = 1024 * 1024,
    });
    defer decoder.deinit();
    const trace = try pump(&decoder, &frame, expected, 1, 17);
    try expectSuccess(trace, frame.len, expected.len);
    try std.testing.expect(trace.first_output_input_offset.? < try firstChunkEnd(&frame));
    try std.testing.expect(trace.first_output_input_offset.? < indexStart(&frame));
    try std.testing.expectEqual(@as(usize, 1), decoder.snapshot().block_count);
    try std.testing.expectEqual(expected.len, decoder.snapshot().validated_output);
}

test "XZ progressive huge single block keeps working and decoded storage independent of raw block size" {
    const expected = try plainAlloc(8 * 1024 * 1024);
    defer allocator.free(expected);
    const encoded = try xz.encodeAlloc(allocator, expected, .{ .block_size = expected.len, .dictionary_size = 4096 });
    defer allocator.free(encoded);
    var decoder = xz.IncrementalDecoder.initWithOptions(allocator, .{
        .max_output_len = expected.len,
        .max_decoded_block_len = expected.len,
        .max_dictionary_size = 4096,
        .max_compressed_buffer_len = 4096,
        .max_decoded_buffer_len = 4096,
        .max_working_memory = 1024 * 1024,
    });
    defer decoder.deinit();
    const trace = try pump(&decoder, encoded, expected, 37, 257);
    try expectSuccess(trace, encoded.len, expected.len);
    try std.testing.expect(trace.first_output_input_offset.? < try firstChunkEnd(encoded));
    try std.testing.expect(trace.peak_working_bytes < expected.len / 4);
    try std.testing.expect(trace.max_decoded_capacity <= 4096);
    try std.testing.expectEqual(@as(usize, 1), decoder.snapshot().block_count);
}

test "XZ progressive explicit prevalidation grows by actual unknown size bytes rather than MAX or every append" {
    const expected = try plainAlloc(70800);
    defer allocator.free(expected);
    const encoded = try xz.encodeAlloc(allocator, expected, .{ .block_size = expected.len, .dictionary_size = 4096 });
    defer allocator.free(encoded);
    const header_len = (@as(usize, encoded[12]) + 1) * 4;
    const header = try container.parseIncrementalBlockHeader(encoded[12..][0..header_len]);
    try std.testing.expectEqual(@as(?u64, null), header.unpacked_size);
    var decoder = xz.IncrementalDecoder.initWithOptions(allocator, .{
        .input_policy = .prevalidated_block,
        .max_decoded_block_len = std.math.maxInt(usize),
        .max_working_memory = 512 * 1024,
    });
    defer decoder.deinit();
    const trace = try pump(&decoder, encoded, expected, 7, 257);
    try expectSuccess(trace, encoded.len, expected.len);
    try std.testing.expect(trace.first_output_input_offset.? >= indexStart(encoded));
    try std.testing.expect(trace.peak_working_bytes <= 512 * 1024);
}

test "XZ progressive supports every BCJ and delta 256 chain with every check across block boundaries" {
    const expected = try instructionCorpusAlloc(4099);
    defer allocator.free(expected);
    const kinds = [_]filters.Kind{ .delta, .x86, .powerpc, .ia64, .arm, .arm_thumb, .sparc, .arm64, .riscv };
    for (kinds) |kind| {
        const first = filters.Filter{ .kind = kind, .parameter = if (kind == .delta) 1 else 256 };
        const changed = try allocator.dupe(u8, expected);
        defer allocator.free(changed);
        filters.encodeChain(changed, &.{first});
        try std.testing.expect(!std.mem.eql(u8, changed, expected));
        const chain = [_]xz.Filter{ first, try xz.Filter.delta(256), try xz.Filter.delta(3) };
        for ([_]xz.Check{ .none, .crc32, .crc64, .sha256 }) |check| {
            const encoded = try xz.encodeAlloc(allocator, expected, .{ .block_size = 1024, .filters = &chain, .check = check });
            defer allocator.free(encoded);
            for ([_]xz.IncrementalDecoder.InputPolicy{ .progressive_block, .prevalidated_block }) |policy| {
                var decoder = xz.IncrementalDecoder.initWithOptions(allocator, .{ .input_policy = policy, .max_decoded_buffer_len = 16 * 1024, .max_working_memory = 1024 * 1024 });
                defer decoder.deinit();
                const trace = try pump(&decoder, encoded, expected, 3, 13);
                try expectSuccess(trace, encoded.len, expected.len);
                try std.testing.expectEqual(@as(usize, 5), decoder.snapshot().block_count);
            }
        }
    }
}

test "XZ progressive packed unpacked declarations and Index records validate actual independent payload sizes" {
    const expected = try plainAlloc(65536);
    defer allocator.free(expected);
    const packed_size: u64 = 313;
    for (0..4) |flags| {
        const encoded = try declaredFrame(if (flags & 1 != 0) packed_size else null, if (flags & 2 != 0) expected.len else null, false);
        defer allocator.free(encoded);
        const reference = try xz.decodeAlloc(allocator, encoded);
        defer allocator.free(reference);
        try std.testing.expectEqualSlices(u8, expected, reference);
        for ([_]xz.IncrementalDecoder.InputPolicy{ .progressive_block, .prevalidated_block }) |policy| {
            var decoder = xz.IncrementalDecoder.initWithOptions(allocator, .{ .input_policy = policy });
            defer decoder.deinit();
            try expectSuccess(try pump(&decoder, encoded, expected, 1, 17), encoded.len, expected.len);
        }
    }
    for ([_]struct { packed_size: ?u64, unpacked_size: ?u64 }{
        .{ .packed_size = packed_size - 1, .unpacked_size = null },
        .{ .packed_size = packed_size + 1, .unpacked_size = null },
        .{ .packed_size = null, .unpacked_size = expected.len - 1 },
        .{ .packed_size = null, .unpacked_size = expected.len + 1 },
    }) |declared| {
        const encoded = try declaredFrame(declared.packed_size, declared.unpacked_size, false);
        defer allocator.free(encoded);
        var decoder = xz.IncrementalDecoder.init(allocator);
        defer decoder.deinit();
        const trace = try pump(&decoder, encoded, expected, 11, 31);
        try std.testing.expectEqual(@as(?anyerror, error.SizeMismatch), trace.failure);
        try expectSticky(&decoder, error.SizeMismatch);
    }
    const invalid_index = try declaredFrame(null, null, true);
    defer allocator.free(invalid_index);
    var decoder = xz.IncrementalDecoder.init(allocator);
    defer decoder.deinit();
    const trace = try pump(&decoder, invalid_index, expected, 5, 37);
    try std.testing.expectEqual(@as(?anyerror, error.InvalidXzStream), trace.failure);
    try std.testing.expectEqual(expected.len, trace.output_written);
    try std.testing.expectEqual(expected.len, decoder.snapshot().validated_output);
}

test "XZ progressive checksum failures publish real prefix while explicit prevalidation preserves atomic output" {
    var frame = systemFrame();
    frame[indexStart(&frame) - 1] ^= 1;
    const expected = try plainAlloc(65536);
    defer allocator.free(expected);
    for ([_]xz.IncrementalDecoder.InputPolicy{ .progressive_block, .prevalidated_block }) |policy| {
        var decoder = xz.IncrementalDecoder.initWithOptions(allocator, .{ .input_policy = policy, .max_decoded_buffer_len = expected.len * 4 });
        defer decoder.deinit();
        const trace = try pump(&decoder, &frame, expected, 13, 37);
        try std.testing.expectEqual(@as(?anyerror, error.ChecksumMismatch), trace.failure);
        try std.testing.expectEqual(if (policy == .progressive_block) expected.len else 0, trace.output_written);
        try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().block_count);
        try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().validated_output);
        try expectSticky(&decoder, error.ChecksumMismatch);
    }
}

test "XZ progressive all system fixture EOF prefixes fail exactly as truncated input" {
    const frame = systemFrame();
    const expected = try plainAlloc(65536);
    defer allocator.free(expected);
    for (0..frame.len) |cut| {
        var decoder = xz.IncrementalDecoder.initWithOptions(allocator, .{ .max_output_len = expected.len });
        defer decoder.deinit();
        const trace = try pump(&decoder, frame[0..cut], expected, 17, 4096);
        try std.testing.expectEqual(@as(?anyerror, error.TruncatedFrame), trace.failure);
        try std.testing.expectEqualStrings("truncated_input", decoder.diagnostics().recoverability_hint_name);
        try expectSticky(&decoder, error.TruncatedFrame);
    }
}

test "XZ progressive next stream preserves buffered and unconsumed input without double accounting" {
    const frame = systemFrame();
    const encoded = frame ++ [_]u8{ 0, 0, 0, 0 } ++ frame;
    const expected = try plainAlloc(65536);
    defer allocator.free(expected);
    for ([_]xz.IncrementalDecoder.InputPolicy{ .progressive_block, .prevalidated_block }) |policy| {
        var decoder = xz.IncrementalDecoder.initWithOptions(allocator, .{
            .input_policy = policy,
            .stop_after_first_stream = true,
            .max_output_len = 2 * expected.len,
            .max_decoded_buffer_len = expected.len * 4,
        });
        defer decoder.deinit();
        const first = try pump(&decoder, &encoded, expected, encoded.len, 7);
        try std.testing.expectEqual(@as(?anyerror, null), first.failure);
        try std.testing.expectEqual(expected.len, first.output_written);
        const before = decoder.snapshot();
        try decoder.nextStream();
        try std.testing.expectEqual(before.output_written, decoder.snapshot().output_written);
        const second = try pump(&decoder, encoded[first.input_read..], expected, 1, 17);
        try std.testing.expectEqual(@as(?anyerror, null), second.failure);
        try std.testing.expectEqual(expected.len, second.output_written);
        try std.testing.expectEqual(encoded.len, decoder.snapshot().input_read);
        try std.testing.expectEqual(@as(usize, 2), decoder.snapshot().stream_count);
        try std.testing.expectEqual(2 * expected.len, decoder.snapshot().output_written);
    }
}
