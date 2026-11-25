//! Standalone scalar rANS codec for the native Vort entropy stage.
//!
//! This module is the portable correctness oracle described in
//! `docs/formats/native-entropy-design.md`. It performs no frame I/O and freezes
//! no wire bytes; it only provides deterministic frequency normalization plus a
//! byte-renormalized rANS encoder/decoder, with independent reference decoders
//! in the tests. Interleaving and native frame wiring are separate milestones.
const std = @import("std");

pub const table = @import("rans/table.zig");
pub const encoder = @import("rans/encoder.zig");
pub const decoder = @import("rans/decoder.zig");
pub const interleaved = @import("rans/interleaved.zig");
pub const block = @import("rans/block.zig");
pub const fuzz = @import("rans/fuzz.zig");

pub const Table = table.Table;
pub const normalize = table.normalize;
pub const tableFromNormalized = table.fromNormalized;
pub const Encoder = encoder.Encoder;
pub const Decoder = decoder.Decoder;
pub const initialState = encoder.initialState;
pub const InterleavedEncoder = interleaved.InterleavedEncoder;
pub const InterleavedDecoder = interleaved.InterleavedDecoder;
pub const InterleavedStream = interleaved.Stream;
pub const laneSymbolCount = interleaved.laneSymbolCount;
pub const max_lanes = interleaved.max_lanes;

pub const Error = table.Error || encoder.Error || decoder.Error;

// Reference every submodule so the test runner includes their inline tests,
// including declarations that are otherwise lazily unreferenced.
test {
    _ = table;
    _ = encoder;
    _ = decoder;
    _ = interleaved;
    _ = block;
    _ = fuzz;
}

// Hand-derived rANS golden vector.
//
// Fixed lower bound `B = 1 << 23`; model `L = 4`, `f = {1, 3}`, `b = {0, 1}`.
// Starting from `x = B`, both symbols stay below their flush threshold so no
// renormalization byte is emitted.
//   encode 0 (f=1,b=0): x_max = (B/4)*256, no flush; x = (B/1)*4 = 4B
//   encode 1 (f=3,b=1): x_max = (B/4)*256*3, no flush;
//                       floor(4B/3)*4 + (4B mod 3) + 1 = 44739243
// Decoding returns `[1, 0]` (rANS reverse order), consumes no bytes and
// restores the state to exactly `B`. These are frozen expected values, not
// recomputed from the encoder, so any arithmetic drift fails the test.
test "hand-computed rANS golden vector without renormalization" {
    const log2_scale: u8 = 2;
    const b = encoder.lower_bound;
    var model = try tableFromNormalized(std.testing.allocator, &.{ 1, 3 }, log2_scale);
    defer model.deinit();
    try std.testing.expectEqualSlices(u16, &.{ 0, 1, 1, 1 }, model.lookup);

    var enc = Encoder.init(std.testing.allocator, log2_scale);
    defer enc.deinit();
    try enc.encodeSymbol(model, 0);
    try enc.encodeSymbol(model, 1);
    const finished = try enc.finishOwned();
    defer std.testing.allocator.free(finished.bytes);

    try std.testing.expectEqual(@as(u32, 44739243), finished.state);
    try std.testing.expectEqual(@as(usize, 0), finished.bytes.len);

    var dec = Decoder.init(finished.state, finished.bytes, log2_scale);
    try std.testing.expectEqual(@as(u16, 1), try dec.next(model));
    try std.testing.expectEqual(@as(u16, 0), try dec.next(model));
    try std.testing.expectEqual(b, dec.state);
    try std.testing.expectEqual(@as(usize, 0), dec.remainingBytes());
}

test "round trip restores every symbol across distributions and scales" {
    var prng = std.Random.DefaultPrng.init(0x0bad_f00d);
    const random = prng.random();

    const scales = [_]u8{ 4, 8, 12 };
    for (scales) |log2_scale| {
        const slot_count: usize = @as(usize, 1) << @intCast(log2_scale);
        const max_alphabet = @min(@as(usize, 32), slot_count);
        var iteration: usize = 0;
        while (iteration < 40) : (iteration += 1) {
            const alphabet_size = random.intRangeAtMost(usize, 1, max_alphabet);
            var counts: [32]u32 = undefined;
            for (counts[0..alphabet_size]) |*c| c.* = random.intRangeAtMost(u32, 1, 5000);

            var model = try normalize(std.testing.allocator, counts[0..alphabet_size], log2_scale);
            defer model.deinit();

            // Generate a message biased toward low-index symbols so repeated
            // renormalization paths are exercised.
            const message_len = random.intRangeAtMost(usize, 1, 400);
            const symbols = try std.testing.allocator.alloc(u16, message_len);
            defer std.testing.allocator.free(symbols);
            for (symbols) |*s| s.* = @intCast(random.intRangeAtMost(usize, 0, alphabet_size - 1));

            var enc = Encoder.init(std.testing.allocator, log2_scale);
            defer enc.deinit();
            for (symbols) |s| try enc.encodeSymbol(model, s);
            const finished = try enc.finishOwned();
            defer std.testing.allocator.free(finished.bytes);

            // Decode yields symbols in reverse; both the dense-table decoder and
            // the independent linear decoder must reproduce that exact order.
            var dense = Decoder.init(finished.state, finished.bytes, log2_scale);
            var linear = Decoder.init(finished.state, finished.bytes, log2_scale);
            var index: usize = message_len;
            while (index > 0) {
                index -= 1;
                const from_dense = try dense.next(model);
                const from_linear = try decoder.nextLinear(&linear, model);
                try std.testing.expectEqual(symbols[index], from_dense);
                try std.testing.expectEqual(symbols[index], from_linear);
            }
            try std.testing.expectEqual(@as(usize, 0), dense.remainingBytes());
            try std.testing.expectEqual(@as(usize, 0), linear.remainingBytes());
            try std.testing.expectEqual(initialState(), dense.state);
        }
    }
}

test "renormalization emits and consumes bytes on long multi-symbol messages" {
    // A single-symbol alphabet would encode as the identity (no information,
    // zero renorm bytes), so use a skewed two-symbol model: the rare symbol
    // forces repeated flush/refill events that must cancel exactly.
    const counts = [_]u32{ 1000, 3 };
    var model = try normalize(std.testing.allocator, &counts, 12);
    defer model.deinit();

    var enc = Encoder.init(std.testing.allocator, 12);
    defer enc.deinit();
    const message_len: usize = 500;
    const symbols = try std.testing.allocator.alloc(u16, message_len);
    defer std.testing.allocator.free(symbols);
    for (symbols, 0..) |*s, idx| s.* = if (idx % 17 == 0) 1 else 0;
    for (symbols) |s| try enc.encodeSymbol(model, s);
    const finished = try enc.finishOwned();
    defer std.testing.allocator.free(finished.bytes);
    try std.testing.expect(finished.bytes.len > 0);

    // Decode yields symbols in reverse encoding order.
    var dec = Decoder.init(finished.state, finished.bytes, 12);
    var decoded: usize = 0;
    while (decoded < message_len) : (decoded += 1) {
        try std.testing.expectEqual(symbols[message_len - 1 - decoded], try dec.next(model));
    }
    try std.testing.expectEqual(@as(usize, 0), dec.remainingBytes());
    try std.testing.expectEqual(initialState(), dec.state);
}

test "single-symbol stream is the identity and needs no renormalization" {
    // Documents the degenerate case: with one symbol f = L, encoding leaves the
    // state unchanged and emits nothing, and decoding restores every symbol.
    const counts = [_]u32{1};
    var model = try normalize(std.testing.allocator, &counts, 8);
    defer model.deinit();

    var enc = Encoder.init(std.testing.allocator, 8);
    defer enc.deinit();
    var i: usize = 0;
    while (i < 500) : (i += 1) try enc.encodeSymbol(model, 0);
    const finished = try enc.finishOwned();
    defer std.testing.allocator.free(finished.bytes);
    try std.testing.expectEqual(@as(usize, 0), finished.bytes.len);
    try std.testing.expectEqual(initialState(), finished.state);

    var dec = Decoder.init(finished.state, finished.bytes, 8);
    var decoded: usize = 0;
    while (decoded < 500) : (decoded += 1) {
        try std.testing.expectEqual(@as(u16, 0), try dec.next(model));
    }
}

test "truncated renormalization stream is rejected, not silently decoded" {
    const counts = [_]u32{ 7, 3 };
    var model = try normalize(std.testing.allocator, &counts, 8);
    defer model.deinit();

    var enc = Encoder.init(std.testing.allocator, 8);
    defer enc.deinit();
    var i: usize = 0;
    while (i < 200) : (i += 1) try enc.encodeSymbol(model, @intCast(i % 2));
    const finished = try enc.finishOwned();
    defer std.testing.allocator.free(finished.bytes);

    // Drop the final renorm byte; the decoder must hit TruncatedStream.
    try std.testing.expect(finished.bytes.len > 1);
    var dec = Decoder.init(finished.state, finished.bytes[0 .. finished.bytes.len - 1], 8);
    var hit_truncation = false;
    while (true) {
        _ = dec.next(model) catch |err| switch (err) {
            error.TruncatedStream => {
                hit_truncation = true;
                break;
            },
            else => return err,
        };
    }
    try std.testing.expect(hit_truncation);
}

test "interleaved round trip agrees across every lane count and alignment" {
    var prng = std.Random.DefaultPrng.init(0x1357_2468);
    const random = prng.random();
    const allocator = std.testing.allocator;

    // Message lengths deliberately sweep the N boundary so some lanes get one
    // more symbol than others and the M < N case (empty trailing lanes) occurs.
    const message_lengths = [_]usize{ 0, 1, 2, 3, 5, 7, 8, 9, 17, 31, 64, 100, 257 };

    for (message_lengths) |message_len| {
        const log2_scale: u8 = 10;
        const alphabet_size: usize = 13;
        var counts: [13]u32 = undefined;
        for (&counts) |*c| c.* = random.intRangeAtMost(u32, 1, 4000);
        var model = try normalize(allocator, &counts, log2_scale);
        defer model.deinit();

        const symbols = try allocator.alloc(u16, message_len);
        defer allocator.free(symbols);
        for (symbols) |*s| s.* = @intCast(random.intRangeAtMost(usize, 0, alphabet_size - 1));

        var lane_count: u8 = 1;
        while (lane_count <= max_lanes) : (lane_count += 1) {
            var enc = try InterleavedEncoder.init(allocator, log2_scale, lane_count);
            defer enc.deinit();
            for (symbols) |s| try enc.encodeSymbol(model, s);
            var stream = try enc.finishOwned();
            defer stream.deinit();

            // The packed offsets must partition the byte buffer once.
            try std.testing.expectEqual(@as(usize, 0), stream.offsets[0]);
            try std.testing.expectEqual(stream.bytes.len, stream.offsets[lane_count]);

            // Strategy A: sequential interleaved walk, then undo rANS reverse.
            var sequential = InterleavedDecoder.init(stream);
            const reversed = try sequential.decodeReversed(model, allocator);
            defer allocator.free(reversed);
            const sequential_out = try allocator.alloc(u16, message_len);
            defer allocator.free(sequential_out);
            for (reversed, 0..) |symbol, reverse_index| {
                sequential_out[message_len - 1 - reverse_index] = symbol;
            }
            try std.testing.expectEqualSlices(u16, symbols, sequential_out);
            try std.testing.expect(sequential.allBytesConsumed());
            try std.testing.expect(sequential.allStatesAtLowerBound());

            // Strategy B: decode each lane independently, then place symbols at
            // positions lane, lane+N, lane+2N, ... (the parallel-friendly form).
            var parallel = InterleavedDecoder.init(stream);
            const parallel_out = try allocator.alloc(u16, message_len);
            defer allocator.free(parallel_out);
            const lane_total: usize = lane_count;
            var lane: usize = 0;
            while (lane < lane_count) : (lane += 1) {
                const count = laneSymbolCount(message_len, lane_total, lane);
                const lane_symbols = try allocator.alloc(u16, count);
                defer allocator.free(lane_symbols);
                try parallel.decodeLaneInto(model, lane, lane_symbols);
                // Lane symbols decode in reverse position order.
                for (lane_symbols, 0..) |symbol, k| {
                    const position = lane + (count - 1 - k) * lane_total;
                    parallel_out[position] = symbol;
                }
            }
            try std.testing.expectEqualSlices(u16, symbols, parallel_out);
            try std.testing.expect(parallel.allBytesConsumed());
            try std.testing.expect(parallel.allStatesAtLowerBound());

            // Strategy C: lockstep structure-of-arrays rounds (the SIMD-precursor
            // schedule), writing forward-order positions directly.
            var lockstep = InterleavedDecoder.init(stream);
            const lockstep_out = try allocator.alloc(u16, message_len);
            defer allocator.free(lockstep_out);
            try lockstep.decodeLockstepInto(model, lockstep_out);
            try std.testing.expectEqualSlices(u16, symbols, lockstep_out);
            try std.testing.expect(lockstep.allBytesConsumed());
            try std.testing.expect(lockstep.allStatesAtLowerBound());

            // All three strategies must reconstruct identical positions.
            try std.testing.expectEqualSlices(u16, sequential_out, parallel_out);
            try std.testing.expectEqualSlices(u16, sequential_out, lockstep_out);
        }
    }
}

test "interleaved single lane is equivalent to the scalar stream" {
    const allocator = std.testing.allocator;
    const counts = [_]u32{ 90, 7, 3 };
    var model = try normalize(allocator, &counts, 11);
    defer model.deinit();

    const symbols = [_]u16{ 0, 1, 0, 2, 0, 0, 1, 2, 0, 1, 0, 0 };

    var scalar_enc = Encoder.init(allocator, 11);
    defer scalar_enc.deinit();
    for (symbols) |s| try scalar_enc.encodeSymbol(model, s);
    const scalar_finished = try scalar_enc.finishOwned();
    defer allocator.free(scalar_finished.bytes);

    var inter_enc = try InterleavedEncoder.init(allocator, 11, 1);
    defer inter_enc.deinit();
    for (symbols) |s| try inter_enc.encodeSymbol(model, s);
    var stream = try inter_enc.finishOwned();
    defer stream.deinit();

    // One lane must reproduce the scalar state and byte stream byte-for-byte.
    try std.testing.expectEqual(scalar_finished.state, stream.laneState(0));
    try std.testing.expectEqualSlices(u8, scalar_finished.bytes, stream.laneBytes(0));

    var dec = InterleavedDecoder.init(stream);
    const reversed = try dec.decodeReversed(model, allocator);
    defer allocator.free(reversed);
    var index: usize = symbols.len;
    for (reversed) |symbol| {
        index -= 1;
        try std.testing.expectEqual(symbols[index], symbol);
    }
}

test "independent lane decode rejects a mismatched output buffer" {
    const allocator = std.testing.allocator;
    var enc = try InterleavedEncoder.init(allocator, 8, 4);
    defer enc.deinit();
    const counts = [_]u32{ 5, 5 };
    var model = try normalize(allocator, &counts, 8);
    defer model.deinit();
    var i: usize = 0;
    while (i < 10) : (i += 1) try enc.encodeSymbol(model, @intCast(i % 2));
    var stream = try enc.finishOwned();
    defer stream.deinit();

    var dec = InterleavedDecoder.init(stream);
    var wrong = [_]u16{0} ** 2;
    // Lane 0 owns 3 of 10 symbols, so a 2-slot buffer must be rejected.
    try std.testing.expectError(error.OutputTooSmall, dec.decodeLaneInto(model, 0, &wrong));
    try std.testing.expectError(error.InvalidLaneCount, dec.decodeLaneInto(model, 4, &wrong));
}

test "lockstep decode rejects a buffer that does not match the symbol count" {
    const allocator = std.testing.allocator;
    var enc = try InterleavedEncoder.init(allocator, 8, 4);
    defer enc.deinit();
    const counts = [_]u32{ 5, 5 };
    var model = try normalize(allocator, &counts, 8);
    defer model.deinit();
    var i: usize = 0;
    while (i < 10) : (i += 1) try enc.encodeSymbol(model, @intCast(i % 2));
    var stream = try enc.finishOwned();
    defer stream.deinit();

    var dec = InterleavedDecoder.init(stream);
    var undersized = [_]u16{0} ** 9;
    try std.testing.expectError(error.OutputTooSmall, dec.decodeLockstepInto(model, &undersized));

    // A correctly sized buffer decodes and restores every state and byte.
    var exact: [10]u16 = undefined;
    try dec.decodeLockstepInto(model, &exact);
    try std.testing.expect(dec.allBytesConsumed());
    try std.testing.expect(dec.allStatesAtLowerBound());
}
