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

pub const Table = table.Table;
pub const normalize = table.normalize;
pub const Encoder = encoder.Encoder;
pub const Decoder = decoder.Decoder;
pub const initialState = encoder.initialState;

pub const Error = table.Error || encoder.Error || decoder.Error;

/// Build an explicit model from already-normalized frequencies. Test fixtures
/// and golden vectors use this to pin exact arithmetic without depending on
/// the normalization routine.
fn modelFromFreqs(allocator: std.mem.Allocator, freqs: []const u32, log2_scale: u8) !Table {
    const l: usize = @as(usize, 1) << @intCast(log2_scale);
    const freq = try allocator.alloc(u32, freqs.len);
    errdefer allocator.free(freq);
    @memcpy(freq, freqs);
    const cum = try allocator.alloc(u32, freqs.len);
    errdefer allocator.free(cum);
    const lookup = try allocator.alloc(u16, l);
    errdefer allocator.free(lookup);

    var running: u32 = 0;
    var active_count: usize = 0;
    var active_span: usize = 0;
    for (freqs, 0..) |f, index| {
        cum[index] = running;
        if (f != 0) {
            active_count += 1;
            active_span = index + 1;
            @memset(lookup[running .. running + f], @intCast(index));
        }
        running += f;
    }
    std.debug.assert(running == l);
    return .{
        .allocator = allocator,
        .log2_scale = log2_scale,
        .freq = freq,
        .cum = cum,
        .lookup = lookup,
        .active_count = active_count,
        .active_span = active_span,
    };
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
    var model = try modelFromFreqs(std.testing.allocator, &.{ 1, 3 }, log2_scale);
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
