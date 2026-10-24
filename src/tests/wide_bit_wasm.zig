//! Public wide-bit geometry and actual small reader consumers for WebAssembly.
//! Numeric geometry does not allocate or read the corresponding large input.
const std = @import("std");
const vort = @import("vort");
const bits = vort.bitstream;
const geometry = bits.bit_count;
const Count = bits.BitCount;
var values: [40]u64 = @splat(0);
const source = [_]u8{ 0xad, 0x3f, 0x91, 0x27, 0xe6, 0x58, 0x0c, 0xf3, 0x41, 0x9b, 0x75, 0x22, 0xcd, 0x06, 0x8a, 0xf0 };

fn require(condition: bool) error{WideBitConsumerMismatch}!void {
    if (!condition) return error.WideBitConsumerMismatch;
}
fn oracle(input: []const u8, logical: usize, start: usize, width: u6) u64 {
    var result: u64 = 0;
    for (0..width) |i| {
        const at = start + i;
        if (at >= logical) break;
        result |= @as(u64, (input[at / 8] >> @intCast(at % 8)) & 1) << @intCast(i);
    }
    return result;
}
export fn wideBitReport(index: u32) u64 {
    return if (index < values.len) values[index] else 0;
}

fn bitGeometry() !void {
    try require(@bitSizeOf(usize) == 32 and Count == u64 and vort.BitCount == Count);
    const bytes = [_]usize{ (1 << 29) - 1, 1 << 29, (1 << 29) + 1, std.math.maxInt(u32) };
    const expected = [_]u64{ 4294967288, 4294967296, 4294967304, 34359738360 };
    for (bytes, expected, 0..) |length, wanted, i| {
        const actual = try geometry.fromBytes(length);
        try require(actual == wanted and geometry.fromBytesAssumeBounded(length) == actual);
        try require(try geometry.floorBytes(actual) == length and try geometry.ceilBytes(actual) == length);
        try require(try geometry.position(length, 7) == actual + 7);
        values[i] = actual;
    }
    if (geometry.toLocal(@as(Count, 1) << 32)) |_| return error.ExpectedNarrowingRefusal else |err| try require(err == error.IntegerOverflow);
    if (geometry.ceilBytes(values[3] + 1)) |_| return error.ExpectedCeilRefusal else |err| try require(err == error.IntegerOverflow);
    try require(geometry.bounded(std.math.maxInt(Count), 63) == 63);
    values[4] = geometry.max_addressable_bytes;
    values[5] = try geometry.position(std.math.maxInt(u32), 7);
    values[6] = 2;
    values[7] = @bitSizeOf(Count);
}
export fn wideBitGeometry() u32 {
    bitGeometry() catch return 101;
    return 0;
}

fn checkReader(reader: anytype) !void {
    try reader.skipBits(2);
    const checkpoint = reader.*;
    const expected = oracle(&source, 128, 2, 63);
    try require(try reader.peekBits(u64, 63) == expected and reader.bitPosition() == 2);
    try require(try reader.readBits(u64, 63) == expected and reader.bitPosition() == 65);
    try require(try reader.readBits(u1, 1) == oracle(&source, 128, 65, 1) and reader.bitPosition() == 66);
    reader.* = checkpoint;
    try require(reader.peekBitsPadded(u64, 63) == expected);
    reader.advanceBitsStagedAssumeAvailable(63);
    try require(reader.bitPosition() == 65 and try reader.readBits(u1, 1) == oracle(&source, 128, 65, 1));
    reader.* = checkpoint;
    try require(reader.peekBitsPadded(u64, 63) == expected);
    reader.advanceBitsAssumeAvailable(63);
    try require(reader.bitPosition() == 65 and try reader.readBits(u1, 1) == oracle(&source, 128, 65, 1));
    try require(reader.bitPosition() == 66 and reader.byteOffset() == 9);
}
fn smallReaders() !void {
    var scalar = bits.BitReader.init(&source);
    var buffered = bits.BufferedBitReader.init(&source);
    const chunks = [_][]const u8{ source[0..1], "", source[1..3], source[3..4], "", source[4..9], source[9..] };
    var chunked = try bits.ChunkedBitReader.init(&chunks);
    var span = try bits.ChunkedSpanBitReader.init(&chunks);
    try checkReader(&scalar);
    try checkReader(&buffered);
    try checkReader(&chunked);
    try checkReader(&span);
    values[8] = oracle(&source, 128, 2, 63);
    values[9] = scalar.bitPosition();
    values[10] = buffered.bitPosition();
    values[11] = chunked.bitPosition();
    values[12] = span.bitPosition();
    values[13] = span.byteOffset();
    const dirty = [_]u8{ 0xad, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff };
    var partial = bits.BitReader.initBitLength(&dirty, 13);
    try partial.skipBits(2);
    const checkpoint = partial;
    const padded = partial.peekBitsPadded(u64, 63);
    try require(padded == oracle(&dirty, 13, 2, 63));
    try require(std.meta.eql(checkpoint, partial));
    if (partial.readBits(u64, 12)) |_| return error.ExpectedPartialRefusal else |err| try require(err == error.TruncatedFrame);
    try require(std.meta.eql(checkpoint, partial));
    try require(try partial.readBits(u16, 11) == padded and partial.bitPosition() == 13);
    values[14] = padded;
    values[15] = partial.bitPosition();
    values[16] = source.len;
    values[17] = 4;
    values[18] = @bitSizeOf(@FieldType(bits.BufferedBitReader, "bit_count"));
}
export fn wideBitSmallReaders() u32 {
    smallReaders() catch return 201;
    return 0;
}

fn storedBounds() !void {
    const lengths = [_]usize{ (1 << 29) - 1, 1 << 29, (1 << 29) + 1 };
    const overheads = [_]usize{ 129, 129, 132 };
    for (lengths, overheads, 0..) |length, overhead, i| {
        // Each complete 16 MiB stored block needs four aligned header bytes;
        // the tiny remainder uses three, followed by the final marker byte.
        const wanted = @as(u64, length) + overhead;
        const actual = try vort.brEncodedStoredStreamBound(length);
        try require(actual == wanted);
        try require(try vort.brEncodedStoredStreamBoundWithOptions(length, .{ .large_window = true, .window_bits = 25 }) == wanted + 2);
        try require(try vort.brEncodedStoredStreamBoundWithOptions(length, .{ .metadata = "xyz" }) == wanted + 5);
        values[20 + i] = actual;
    }
    if (vort.brEncodedStoredStreamBound(std.math.maxInt(usize))) |_| return error.ExpectedBoundOverflow else |err| try require(err == error.IntegerOverflow);
    var input: [128]u8 = undefined;
    for (&input, 0..) |*byte, i| byte.* = @truncate(i *% 29 + 7);
    var output: [256]u8 = @splat(0xa5);
    var profile: vort.BrotliEncodeMemoryProfile = .{};
    const written = try vort.brEncodeStoredStreamWithOptionsInto(&input, &output, .{ .max_total_working_memory = 0, .memory_profile = &profile, .metadata = "bit-meta" });
    try require(profile.available and profile.peak_requested_bytes == 0 and profile.live_requested_bytes == 0);
    for (output[written..]) |byte| try require(byte == 0xa5);
    const decoded = try vort.brDecodeStreamAllocExactSize(std.heap.page_allocator, output[0..written], input.len);
    defer std.heap.page_allocator.free(decoded);
    try require(std.mem.eql(u8, &input, decoded));
    values[23] = written;
    values[24] = input.len;
    values[25] = try geometry.fromBytes(written);
    values[26] = profile.peak_requested_bytes;
    values[27] = profile.live_requested_bytes;
    values[28] = 1;
}
export fn wideBitStoredBounds() u32 {
    storedBounds() catch return 301;
    return 0;
}
