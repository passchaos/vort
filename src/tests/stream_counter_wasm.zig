//! Public Wasm counter consumers. Repeated-prefix/checksum cases explicitly
//! use validated logical models; their physical input and output stay small.
const std = @import("std");
const vort = @import("vort");
const Count = vort.StreamCount;
const boundary: Count = @as(Count, 1) << 32;
const pattern = "ABCDEFGHIJKLMNOP";
const first_stored = [_]u8{ 0xf0, 0x00, 0x10 } ++ pattern.*;
const next_stored = [_]u8{ 0x78, 0x00, 0x08 } ++ pattern.*;
var values: [32]u64 = @splat(0);

fn require(condition: bool) error{InvalidCounterConsumer}!void {
    if (!condition) return error.InvalidCounterConsumer;
}

export fn streamCounterReport(index: u32) u64 {
    return if (index < values.len) values[index] else 0;
}

export fn streamCounterTypes() u32 {
    require(Count == u64 and @bitSizeOf(usize) == 32) catch return 101;
    require(@FieldType(vort.Progress, "input_read") == usize and @FieldType(vort.Progress, "output_written") == usize) catch return 102;
    require(@FieldType(vort.StreamingDiagnostics, "output_written") == Count and @FieldType(vort.StreamingDiagnostics, "expected_output_len") == ?Count) catch return 103;
    values[0] = boundary + 17;
    values[1] = @bitSizeOf(usize);
    values[2] = @bitSizeOf(Count);
    values[3] = @bitSizeOf(@FieldType(vort.Progress, "input_read"));
    return 0;
}

fn installStoredModel(decoder: *vort.BrotliIncrementalCopyStreamDecoder, repetitions: Count) !void {
    var first_output: [pattern.len]u8 = undefined;
    const first = try decoder.step(&first_stored, &first_output);
    try require(first.progress.input_read == first_stored.len and first.progress.output_written == pattern.len);
    try require(std.mem.eql(u8, pattern, &first_output) and decoder.phase == .trailer);
    try require(decoder.staged_bit_count == 0 and decoder.stream_bits == 24 and decoder.total_input == first_stored.len and decoder.total_output == pattern.len);
    // A repeated byte-aligned stored block contributes exactly 19 input bytes,
    // 16 output bytes and 24 coded header bits. Payload does not enter Reader.
    decoder.total_input = repetitions * first_stored.len;
    decoder.total_output = repetitions * pattern.len;
    decoder.stream_bits = @truncate(@as(u128, repetitions) * 24);
    for (0..decoder.history.len) |i| {
        const absolute = decoder.total_output - decoder.history.len + i;
        decoder.history[@intCast(absolute % decoder.history.len)] = pattern[@intCast(absolute % pattern.len)];
    }
    decoder.previous = .{ pattern[pattern.len - 2], pattern[pattern.len - 1] };
}

fn brotliModel() !void {
    var history: [3]u8 = undefined;
    var decoder = vort.BrotliIncrementalCopyStreamDecoder.init(&history);
    const repetitions = boundary / pattern.len - 1;
    try installStoredModel(&decoder, repetitions);
    decoder.options.expected_output_len = boundary;
    const old_input = decoder.total_input;
    const old_bits = decoder.stream_bits;
    var output: [pattern.len]u8 = @splat(0xa5);
    var read: usize = 0;
    var written: usize = 0;
    for (0..64) |_| {
        if (read == next_stored.len and written == output.len) break;
        const result = try decoder.step(next_stored[read..@min(next_stored.len, read + 2)], output[written..@min(output.len, written + 3)]);
        try require(result.progress.input_read <= 2 and result.progress.output_written <= 3);
        try require(result.progress.input_read != 0 or result.progress.output_written != 0);
        read += result.progress.input_read;
        written += result.progress.output_written;
    }
    try require(read == next_stored.len and written == pattern.len and std.mem.eql(u8, pattern, &output));
    try require(decoder.total_output == boundary and decoder.total_input == old_input + next_stored.len);
    try require(decoder.stream_bits == old_bits +% 24 and decoder.staged_bit_count == 0);
    for (0..history.len) |i| {
        const absolute = boundary - history.len + i;
        try require(history[@intCast(absolute % history.len)] == pattern[@intCast(absolute % pattern.len)]);
    }
    const done = try decoder.step(&.{0x03}, &.{});
    try require(done.status == .done and done.progress.input_read == 1 and done.progress.output_written == 0);
    try decoder.finish();
    const snapshot = decoder.snapshot();
    try require(snapshot.output_written == boundary and decoder.diagnostics().expected_output_len == boundary);
    values[4] = snapshot.output_written;
    values[5] = snapshot.input_read;
    values[6] = read;
    values[7] = written;
    values[8] = history.len;

    // A separate legitimate repeated-block checkpoint reaches the coded-bit
    // boundary. An actual partial header updates its reader reservoir, then a
    // copied decoder checkpoint replays the full header from the same state.
    var bit_history: [3]u8 = undefined;
    var bit_decoder = vort.BrotliIncrementalCopyStreamDecoder.init(&bit_history);
    const bit_repetitions: Count = boundary / 24;
    try installStoredModel(&bit_decoder, bit_repetitions);
    const bit_checkpoint = bit_decoder;
    const partial = try bit_decoder.step(next_stored[0..1], &.{});
    try require(partial.progress.input_read == 1 and partial.progress.output_written == 0);
    bit_decoder = bit_checkpoint;
    const bit_step = try bit_decoder.step(&next_stored, &output);
    try require(bit_step.progress.input_read == next_stored.len and bit_step.progress.output_written == pattern.len);
    try require(bit_decoder.stream_bits == @as(usize, @truncate(@as(u128, bit_repetitions + 1) * 24)) and bit_decoder.stream_bits % 8 == 0);
    values[9] = bit_decoder.stream_bits;
    values[10] = partial.progress.input_read;
    values[11] = bit_step.progress.input_read;
}

export fn streamCounterBrotliModel() u32 {
    brotliModel() catch return 201;
    return 0;
}

fn contentSize(bytes: []const u8) !u64 {
    try require(bytes.len >= 14 and std.mem.eql(u8, bytes[0..4], &.{ 0x28, 0xb5, 0x2f, 0xfd }));
    try require(bytes[4] >> 6 == 3 and bytes[4] & 0x23 == 0);
    return std.mem.readInt(u64, bytes[6..][0..8], .little);
}

fn wideRlePreflight() !void {
    const allocator = std.heap.page_allocator;
    const pledge = boundary + 1;
    const full_blocks: usize = 32768;
    const wire = try allocator.alloc(u8, 14 + full_blocks * 4 + 4);
    defer allocator.free(wire);
    @memcpy(wire[0..4], &[_]u8{ 0x28, 0xb5, 0x2f, 0xfd });
    wire[4] = 0xc0; // u64 FCS, nonsingle segment, no dictionary/checksum.
    wire[5] = 0x50; // Window_Log 20, maximum block remains 128 KiB.
    std.mem.writeInt(u64, wire[6..][0..8], pledge, .little);
    for (0..full_blocks) |i| {
        const at = 14 + i * 4;
        @memcpy(wire[at..][0..4], &[_]u8{ 0x02, 0x00, 0x10, 'R' });
    }
    @memcpy(wire[wire.len - 4 ..], &[_]u8{ 0x0b, 0x00, 0x00, 'R' });
    try require(try contentSize(wire) == pledge);
    const header = try vort.zstd.inspectNativeFrameHeader(wire);
    try require(header.content_size == pledge and header.window_size == 1 << 20);
    for ([_]vort.core.CompressedInputPolicy{ .block_stream, .prevalidated_frame }, 0..) |policy, i| {
        var decoder = vort.ZstdNativeIncrementalFrameDecoder.initWithOptions(allocator, .{
            .input_policy = policy,
            .max_output_len = pledge,
            .expected_output_len = pledge,
            .max_decoded_buffer_len = pledge,
            .max_compressed_buffer_len = wire.len,
            .max_working_memory = 1024 * 1024,
        });
        defer decoder.deinit();
        var output = [_]u8{0xa5};
        const result = try decoder.step(wire, &output);
        try require(result.progress.output_written == 1 and output[0] == 'R' and result.status == .need_output);
        const snapshot = decoder.snapshot();
        try require(snapshot.output_written == 1 and decoder.diagnostics().expected_output_len == pledge);
        try require(decoder.workingMemoryBytes() <= 1024 * 1024);
        if (policy == .prevalidated_frame) {
            try require(snapshot.decoded_len == pledge and result.progress.input_read == wire.len);
            values[13] = snapshot.decoded_len.?;
        } else values[13] = pledge; // Independent sum of real wire RLE lengths.
        values[14 + i * 3] = snapshot.input_received;
        values[15 + i * 3] = snapshot.output_written;
        values[16 + i * 3] = decoder.workingMemoryBytes();
    }
    values[12] = wire.len;
    values[20] = pledge;
}

export fn streamCounterZstdWidePreflight() u32 {
    wideRlePreflight() catch return 301;
    return 0;
}

fn widePledge() !void {
    const allocator = std.heap.page_allocator;
    const pledge = boundary + 7;
    var encoder = try vort.zstd.NativeIncrementalFrameEncoder.initExactSize(allocator, .{ .selection = .raw_or_rle, .content_checksum = true, .window_log = 10 }, pledge);
    defer encoder.deinit();
    var header: [64]u8 = undefined;
    const first = try encoder.step("", &header);
    try require(first.progress.input_read == 0 and first.progress.output_written == 14 and try contentSize(header[0..14]) == pledge);
    encoder.finish();
    var output: [8]u8 = @splat(0xa5);
    if (encoder.step("", &output)) |_| return error.ExpectedSizeMismatch else |err| try require(err == error.SizeMismatch);
    for (output) |byte| try require(byte == 0xa5);
    for ([_]vort.core.CompressedInputPolicy{ .block_stream, .prevalidated_frame }) |policy| {
        var decoder = vort.ZstdNativeIncrementalFrameDecoder.initWithOptions(allocator, .{ .input_policy = policy, .expected_output_len = pledge, .max_output_len = pledge, .max_working_memory = 4096 });
        defer decoder.deinit();
        const read = try decoder.step(header[0..14], &.{});
        try require(read.progress.input_read == 14 and read.progress.output_written == 0 and decoder.diagnostics().expected_output_len == pledge);
        if (decoder.finish()) |_| return error.ExpectedTruncatedFrame else |err| try require(err == error.TruncatedFrame);
    }
    values[21] = pledge;
    values[22] = first.progress.output_written;
    values[23] = 1; // Exact pledge fails with SizeMismatch and untouched output.

    // Frozen independent C-checked vector from checksum/xxh64_stream/vectors.zig.
    // Kept inline so this public consumer imports only the Vort root module.
    const vector: struct { seed: u64, stripe: [32]u8, before: u64, after: u64 } = .{
        .seed = @as(u64, 0),
        .stripe = [_]u8{ 0x00, 0x22, 0x6c, 0x1d, 0x6f, 0x85, 0x6e, 0xd8, 0x49, 0x21, 0x4c, 0xe4, 0x35, 0x06, 0xb4, 0xaf, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x9a, 0xb3, 0x52, 0xb0, 0xac, 0x87, 0xb8, 0xf8 },
        .before = @as(u64, 0xdf58cf37dc00b095),
        .after = @as(u64, 0xc0269e70681841e6),
    };
    var hash = vort.checksum.XxHash64Stream.init(vector.seed);
    const lanes = hash.lanes;
    hash.update(&vector.stripe);
    try require(std.mem.eql(u64, &lanes, &hash.lanes) and hash.tail_len == 0 and hash.large_input);
    // This independent vector is a fixed point under actual stripe updates.
    // Repeating the valid stripe leaves identical lanes; only length changes.
    hash.total_len = (@as(u64, 1) << 32) - 32;
    const tail = "abcdefghijklmnopqrstuvwxyz0123456";
    hash.update(tail[0..31]);
    try require(hash.total_len == 0xffffffff and hash.final() == vector.before);
    values[24] = hash.final();
    hash.update(tail[31..]);
    try require(hash.total_len == 0x100000001 and hash.final() == vector.after);
    values[25] = hash.final();
    values[26] = hash.total_len;
    values[27] = @as(u32, @truncate(hash.final()));
    values[28] = vector.before;
    values[29] = vector.after;
}

export fn streamCounterZstdPledge() u32 {
    widePledge() catch return 401;
    return 0;
}
