//! Experimental rANS entropy-block container (not a native frame yet).
//!
//! This is the versioned, golden-vectorable wrapper around the interleaved
//! rANS codec from step 4 of `docs/formats/native-entropy-design.md`. It is
//! intentionally self-contained and is NOT imported by the production native
//! parser (`src/store.zig`), so its bytes cannot become a compatibility promise
//! by accident. A later milestone decides whether and how to embed this block
//! behind an experimental native frame version.
//!
//! Wire layout (all multi-byte integers little-endian, no alignment assumed):
//!
//! ```text
//! fixed header
//!   magic[4]            "VRB1"
//!   version  u8         block_version
//!   log2_scale u8
//!   lane_count u8       1..=max_lanes
//!   reserved u8         must be zero
//!   alphabet_size u16   active model span
//!   symbol_count u32    declared decoded symbol count
//!   model_crc u32       CRC-32 over the frequency table
//!   payload_crc u32     CRC-32 over the semantic header (log2_scale through
//!                       symbol_count) plus states + offsets + renorm bytes, so
//!                       a tampered declared count cannot slip past the checks
//! frequency table       alphabet_size * u32 normalized frequencies (sum = L)
//! lane states           lane_count * u32
//! lane offsets          (lane_count + 1) * u32 prefix byte offsets
//! renorm bytes          the packed per-lane renormalization spans
//! ```
const std = @import("std");
const checksum = @import("../checksum.zig");
const table_mod = @import("table.zig");
const interleaved = @import("interleaved.zig");

const Table = table_mod.Table;
const InterleavedEncoder = interleaved.InterleavedEncoder;
const InterleavedDecoder = interleaved.InterleavedDecoder;
const Stream = interleaved.Stream;
const max_lanes = interleaved.max_lanes;

/// Experimental block magic and version. Bumping the version invalidates old
/// golden vectors rather than silently reinterpreting them.
pub const magic = [_]u8{ 'V', 'R', 'B', '1' };
pub const block_version: u8 = 1;

pub const header_len: usize = 22;

/// Byte range of the semantic header fields that influence decoding
/// (`log2_scale`, `lane_count`, reserved, `alphabet_size`, `symbol_count`).
/// Magic/version are validated explicitly and the two CRC fields cannot cover
/// themselves, so this span is folded into the payload CRC instead.
const semantic_header_start: usize = 5;
const semantic_header_end: usize = 14;

/// CRC over the semantic header and the states/offsets/renorm payload. Covering
/// the header is what makes a corrupted `symbol_count` fail closed: without it,
/// a single-symbol block (zero renorm bytes, state pinned at the lower bound)
/// has no other signal that the declared count is wrong.
fn computePayloadCrc(semantic_header: []const u8, payload: []const u8) u32 {
    var crc = checksum.Crc32.init();
    crc.update(semantic_header);
    crc.update(payload);
    return crc.digest();
}

/// Default bound on decoded symbols when a caller does not supply one. It keeps
/// a corrupted header's `symbol_count` from driving an unbounded allocation;
/// callers with a known output budget should use `decodeBounded`.
pub const max_default_symbol_count: u32 = 64 * 1024 * 1024;

pub const Error = error{
    InvalidMagic,
    UnsupportedVersion,
    CorruptFrame,
    TruncatedFrame,
    SizeMismatch,
    ChecksumMismatch,
    InvalidLaneCount,
    OutputLimitExceeded,
    OutOfMemory,
};

const Header = struct {
    log2_scale: u8,
    lane_count: u8,
    alphabet_size: u16,
    symbol_count: u32,
    model_crc: u32,
    payload_crc: u32,
};

fn writeU16(buf: []u8, value: u16) void {
    std.mem.writeInt(u16, buf[0..2], value, .little);
}

fn writeU32(buf: []u8, value: u32) void {
    std.mem.writeInt(u32, buf[0..4], value, .little);
}

fn readU16(buf: []const u8) u16 {
    return std.mem.readInt(u16, buf[0..2], .little);
}

fn readU32(buf: []const u8) u32 {
    return std.mem.readInt(u32, buf[0..4], .little);
}

/// Encode `symbols` into an owned experimental block. `counts` is the raw
/// symbol histogram used to build the normalized model. The output is fully
/// self-describing and bounded by the declared counts.
pub fn encodeOwned(
    allocator: std.mem.Allocator,
    counts: []const u32,
    symbols: []const u16,
    log2_scale: u8,
    lane_count: u8,
) Error![]u8 {
    if (lane_count == 0 or lane_count > max_lanes) return error.InvalidLaneCount;
    if (log2_scale == 0 or log2_scale > table_mod.max_log2_scale) return error.CorruptFrame;
    if (counts.len > std.math.maxInt(u16) or symbols.len > std.math.maxInt(u32))
        return error.CorruptFrame;

    var model = table_mod.normalize(allocator, counts, log2_scale) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.CorruptFrame,
    };
    defer model.deinit();

    var encoder = InterleavedEncoder.init(allocator, log2_scale, lane_count) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidLaneCount,
    };
    defer encoder.deinit();
    for (symbols) |symbol| {
        encoder.encodeSymbol(model, symbol) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return error.CorruptFrame,
        };
    }
    var stream = encoder.finishOwned() catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.CorruptFrame,
    };
    defer stream.deinit();

    const alphabet_size: u16 = @intCast(counts.len);
    const freq_bytes_len: usize = @as(usize, alphabet_size) * 4;
    const states_len: usize = @as(usize, lane_count) * 4;
    const offsets_len: usize = (@as(usize, lane_count) + 1) * 4;
    const total = header_len + freq_bytes_len + states_len + offsets_len + stream.bytes.len;

    var out = allocator.alloc(u8, total) catch return error.OutOfMemory;
    errdefer allocator.free(out);

    // Frequency table section.
    const freq_start = header_len;
    for (0..alphabet_size) |index| {
        writeU32(out[freq_start + index * 4 ..][0..4], model.freq[index]);
    }
    const model_crc = checksum.Crc32.hash(out[freq_start .. freq_start + freq_bytes_len]);

    // Payload section: states, offsets, then renorm bytes.
    const payload_start = freq_start + freq_bytes_len;
    var cursor: usize = payload_start;
    var lane: usize = 0;
    while (lane < lane_count) : (lane += 1) {
        writeU32(out[cursor..][0..4], stream.states[lane]);
        cursor += 4;
    }
    lane = 0;
    while (lane <= lane_count) : (lane += 1) {
        const offset = stream.offsets[lane];
        if (offset > std.math.maxInt(u32)) return error.CorruptFrame;
        writeU32(out[cursor..][0..4], @intCast(offset));
        cursor += 4;
    }
    @memcpy(out[cursor .. cursor + stream.bytes.len], stream.bytes);
    const payload_end = cursor + stream.bytes.len;

    // Write the semantic header fields first so the payload CRC covers their
    // actual on-wire values; the two CRC fields themselves are filled in after.
    out[5] = log2_scale;
    out[6] = lane_count;
    out[7] = 0; // reserved
    writeU16(out[8..10], alphabet_size);
    writeU32(out[10..14], @intCast(symbols.len));
    const payload_crc = computePayloadCrc(out[semantic_header_start..semantic_header_end], out[payload_start..payload_end]);

    // Fixed header and CRC fields.
    @memcpy(out[0..4], &magic);
    out[4] = block_version;
    writeU32(out[14..18], model_crc);
    writeU32(out[18..22], payload_crc);

    std.debug.assert(payload_end == total);
    return out;
}

fn parseHeader(input: []const u8) Error!Header {
    if (input.len < header_len) return error.TruncatedFrame;
    if (!std.mem.eql(u8, input[0..4], &magic)) return error.InvalidMagic;
    if (input[4] != block_version) return error.UnsupportedVersion;
    if (input[7] != 0) return error.CorruptFrame;

    const log2_scale = input[5];
    const lane_count = input[6];
    if (log2_scale == 0 or log2_scale > table_mod.max_log2_scale) return error.CorruptFrame;
    if (lane_count == 0 or lane_count > max_lanes) return error.InvalidLaneCount;

    return .{
        .log2_scale = log2_scale,
        .lane_count = lane_count,
        .alphabet_size = readU16(input[8..10]),
        .symbol_count = readU32(input[10..14]),
        .model_crc = readU32(input[14..18]),
        .payload_crc = readU32(input[18..22]),
    };
}

/// Decode an experimental block using the default symbol bound. See
/// `decodeBounded` for the validation contract.
pub fn decodeOwned(allocator: std.mem.Allocator, input: []const u8) Error![]u16 {
    return decodeBounded(allocator, input, max_default_symbol_count);
}

/// Decode an experimental block into forward-order symbols, rejecting any
/// block whose declared symbol count exceeds `max_symbol_count` before the
/// output buffer is allocated. All structural and checksum validation happens
/// before any decoded symbol is returned.
pub fn decodeBounded(
    allocator: std.mem.Allocator,
    input: []const u8,
    max_symbol_count: u32,
) Error![]u16 {
    const header = try parseHeader(input);

    // Enforce the caller's output budget before the declared count can drive an
    // allocation. The payload CRC also covers this header field, but checking
    // the bound here fails fast and keeps a hostile but CRC-consistent block
    // from requesting an oversized buffer.
    if (header.symbol_count > max_symbol_count) return error.OutputLimitExceeded;

    const freq_start = header_len;
    const freq_bytes_len: usize = @as(usize, header.alphabet_size) * 4;
    const states_len: usize = @as(usize, header.lane_count) * 4;
    const offsets_len: usize = (@as(usize, header.lane_count) + 1) * 4;
    const payload_start = freq_start + freq_bytes_len;

    // Every section must be fully present before its CRC is checked.
    const needed = payload_start + states_len + offsets_len;
    if (input.len < needed) return error.TruncatedFrame;

    if (checksum.Crc32.hash(input[freq_start..payload_start]) != header.model_crc)
        return error.ChecksumMismatch;

    const freq = allocator.alloc(u32, header.alphabet_size) catch return error.OutOfMemory;
    defer allocator.free(freq);
    for (freq, 0..) |*f, index| f.* = readU32(input[freq_start + index * 4 ..][0..4]);

    var model = table_mod.fromNormalized(allocator, freq, header.log2_scale) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.CorruptFrame,
    };
    defer model.deinit();

    var cursor: usize = payload_start;
    var states: [max_lanes]u32 = std.mem.zeroes([max_lanes]u32);
    var lane: usize = 0;
    while (lane < header.lane_count) : (lane += 1) {
        states[lane] = readU32(input[cursor..][0..4]);
        cursor += 4;
    }
    var offsets: [max_lanes + 1]usize = std.mem.zeroes([max_lanes + 1]usize);
    lane = 0;
    while (lane <= header.lane_count) : (lane += 1) {
        offsets[lane] = readU32(input[cursor..][0..4]);
        cursor += 4;
    }

    // Offsets must be monotonic and describe exactly the remaining bytes.
    if (offsets[0] != 0) return error.CorruptFrame;
    lane = 0;
    while (lane < header.lane_count) : (lane += 1) {
        if (offsets[lane + 1] < offsets[lane]) return error.CorruptFrame;
    }
    const renorm_len = offsets[header.lane_count];
    if (input.len != cursor + renorm_len) return error.SizeMismatch;
    const renorm = input[cursor .. cursor + renorm_len];

    if (computePayloadCrc(input[semantic_header_start..semantic_header_end], input[payload_start .. cursor + renorm_len]) != header.payload_crc)
        return error.ChecksumMismatch;

    // Rebuild a borrowed Stream view; no renorm bytes are copied.
    const stream = Stream{
        .allocator = allocator,
        .log2_scale = header.log2_scale,
        .lane_count = header.lane_count,
        .symbol_count = header.symbol_count,
        .states = states,
        .offsets = offsets,
        .bytes = renorm,
    };

    var decoder = InterleavedDecoder.init(stream);
    const reversed = decoder.decodeReversed(model, allocator) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.CorruptFrame,
    };
    defer allocator.free(reversed);

    if (reversed.len != header.symbol_count) return error.SizeMismatch;
    if (!decoder.allBytesConsumed()) return error.CorruptFrame;
    if (!decoder.allStatesAtLowerBound()) return error.CorruptFrame;

    const forward = allocator.alloc(u16, header.symbol_count) catch return error.OutOfMemory;
    errdefer allocator.free(forward);
    for (reversed, 0..) |symbol, reverse_index| {
        forward[header.symbol_count - 1 - reverse_index] = symbol;
    }
    return forward;
}

test "block round trip restores forward-order symbols" {
    const allocator = std.testing.allocator;
    const counts = [_]u32{ 40, 12, 7, 3, 1 };
    const symbols = [_]u16{ 0, 1, 0, 2, 4, 3, 0, 1, 2, 0, 0, 3, 1, 0, 2 };

    const block = try encodeOwned(allocator, &counts, &symbols, 10, 4);
    defer allocator.free(block);
    const decoded = try decodeOwned(allocator, block);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u16, &symbols, decoded);
}

test "block rejects magic, version, truncation and checksum corruption" {
    const allocator = std.testing.allocator;
    const counts = [_]u32{ 9, 4 };
    const symbols = [_]u16{ 0, 1, 0, 0, 1, 0 };
    const block = try encodeOwned(allocator, &counts, &symbols, 8, 2);
    defer allocator.free(block);

    var bad_magic = try allocator.dupe(u8, block);
    defer allocator.free(bad_magic);
    bad_magic[0] = 'X';
    try std.testing.expectError(error.InvalidMagic, decodeOwned(allocator, bad_magic));

    var bad_version = try allocator.dupe(u8, block);
    defer allocator.free(bad_version);
    bad_version[4] = 99;
    try std.testing.expectError(error.UnsupportedVersion, decodeOwned(allocator, bad_version));

    try std.testing.expectError(error.TruncatedFrame, decodeOwned(allocator, block[0 .. block.len - 1]));
    try std.testing.expectError(error.TruncatedFrame, decodeOwned(allocator, block[0..10]));

    // Flip a lane-state byte (payload section). It cannot change the
    // size-defining offsets, so the payload CRC must be the check that fires.
    const payload_start = header_len + counts.len * 4;
    var corrupted = try allocator.dupe(u8, block);
    defer allocator.free(corrupted);
    corrupted[payload_start] ^= 0x5a;
    try std.testing.expectError(error.ChecksumMismatch, decodeOwned(allocator, corrupted));

    // Flip a frequency byte; the model CRC must catch it.
    var model_corrupt = try allocator.dupe(u8, block);
    defer allocator.free(model_corrupt);
    model_corrupt[header_len] ^= 0x01;
    try std.testing.expectError(error.ChecksumMismatch, decodeOwned(allocator, model_corrupt));
}

fn hexNibble(character: u8) error{CorruptFrame}!u8 {
    return switch (character) {
        '0'...'9' => character - '0',
        'a'...'f' => character - 'a' + 10,
        'A'...'F' => character - 'A' + 10,
        else => error.CorruptFrame,
    };
}

fn parseHex(hex: []const u8, out: []u8) error{CorruptFrame}![]u8 {
    if (hex.len % 2 != 0 or out.len < hex.len / 2) return error.CorruptFrame;
    for (0..hex.len / 2) |index| {
        const high = try hexNibble(hex[index * 2]);
        const low = try hexNibble(hex[index * 2 + 1]);
        out[index] = (high << 4) | low;
    }
    return out[0 .. hex.len / 2];
}

// Frozen golden block for counts {50,30,15,5}, symbols
// {0,1,2,0,3,1,0,2,1,0,0,3}, log2_scale 10, four lanes. These bytes are an
// intentional compatibility anchor for the experimental (not yet framed)
// block: any encoder drift fails here instead of silently changing the wire.
test "frozen golden block decodes and re-encodes byte-identically" {
    const allocator = std.testing.allocator;
    const golden_hex =
        "56524231010a040004000c0000009155013b2dc85fa0ff010000330100009a00000034000000" ++
        "b3f2cf41fabd250b54d0590deb3383000000000000000000000000000000000001000000c4";
    const expected_symbols = [_]u16{ 0, 1, 2, 0, 3, 1, 0, 2, 1, 0, 0, 3 };
    const counts = [_]u32{ 50, 30, 15, 5 };

    var buffer: [128]u8 = undefined;
    const golden = try parseHex(golden_hex, &buffer);
    try std.testing.expectEqual(@as(usize, 75), golden.len);

    const decoded = try decodeOwned(allocator, golden);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u16, &expected_symbols, decoded);

    const reencoded = try encodeOwned(allocator, &counts, &expected_symbols, 10, 4);
    defer allocator.free(reencoded);
    try std.testing.expectEqualSlices(u8, golden, reencoded);
}
