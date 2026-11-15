//! Deterministic bounded fuzz driver for the owned incremental Brotli decoder.
//!
//! Mirrors the Zstd incremental driver but follows Brotli's contract: there is
//! no frame format or compressed-input policy dimension, trailing bytes after
//! a completed stream are rejected unless `allow_trailing_data` is set, and the
//! generated wire is either a planned stream or an RFC stored stream. Each seed
//! selects a generated wire, a mutation, decoder options and a caller step
//! schedule, then checks on every step:
//!
//!   * local progress never exceeds the offered input/output slices and the
//!     reported per-step progress matches the decoder snapshot;
//!   * caller output beyond `output_written` keeps its canary fill;
//!   * documented decode errors are sticky until `reset`, carry diagnostics,
//!     and reproduce after reuse;
//!   * working-memory and retained compressed-input caps hold throughout;
//!   * accepted runs replay identically under a different schedule and, when
//!     the one-shot decoder also accepts the wire, match its output;
//!   * truncated wires terminate as an explicit incomplete result instead of
//!     a no-progress stall.
//!
//! `drive` takes an opaque seed so the same entry backs in-graph tests, a
//! standalone smoke executable and a future coverage-guided runner. Real
//! `OutOfMemory` always propagates; every other Brotli error is a documented
//! rejection the decoder is expected to surface cleanly.
const std = @import("std");
const br = @import("../../br.zig");
const core = @import("../../core.zig");

const Allocator = std.mem.Allocator;
const Decoder = br.IncrementalStreamDecoder;
const Counter = br.Counter;

const canary_byte: u8 = 0xa5;
const max_steps: usize = 200_000;
const output_slack: usize = 64;

const Regime = enum { valid, truncate, flip, suffix };
const PayloadKind = enum { empty, tiny, text, repetitive, structured, multiblock };
const WireKind = enum { planned, stored };
const Pledge = enum { none, exact, short };

const input_chunks = [_]usize{ 1, 2, 3, 5, 8, 13, 31, 64, 257 };
// A fixed zero-output schedule could never finish a non-empty decode in one
// pass; 1-byte output still exercises maximal backpressure while completing.
const output_chunks = [_]usize{ 1, 2, 7, 17, 64, 257 };
const wire_kinds = [_]WireKind{ .planned, .stored };

/// Everything derived from a seed, frozen before any decoder call so reuse and
/// reset reproduce the exact wire and schedule.
const Scenario = struct {
    payload_kind: PayloadKind,
    wire_kind: WireKind,
    regime: Regime,
    pledge: Pledge,
    allow_trailing: bool,
    tight_cap: bool,
    input_chunk: usize,
    output_chunk: usize,
    cut: usize,
    flip_pos: usize,
    flip_delta: u8,
    suffix_len: usize,
};

const Rng = struct {
    state: u64,

    fn next(self: *Rng) u64 {
        self.state +%= 0x9e3779b97f4a7c15;
        var z = self.state;
        z = (z ^ (z >> 30)) *% 0xbf58476d1ce4e5b9;
        z = (z ^ (z >> 27)) *% 0x94d049bb133111eb;
        return z ^ (z >> 31);
    }

    fn bounded(self: *Rng, comptime T: type, values: []const T) T {
        return values[@as(usize, @intCast(self.next() % values.len))];
    }

    fn index(self: *Rng, len: usize) usize {
        return @intCast(self.next() % @as(u64, @intCast(len)));
    }
};

fn seedRng(seed: []const u8) Rng {
    var hash: u64 = 0xcbf29ce484222325;
    for (seed) |byte| {
        hash ^= byte;
        hash *%= 0x100000001b3;
    }
    hash ^= @as(u64, @intCast(seed.len)) *% 0x9e3779b97f4a7c15;
    return .{ .state = hash };
}

/// Wire-deciding fields; wire_kind is legal for the already-built payload.
const WireShape = struct {
    wire_kind: WireKind,
    suffix_len: usize,
};

fn drawWireShape(rng: *Rng, plaintext_len: usize) WireShape {
    // The planned encoder rejects inputs shorter than five bytes; empty and
    // tiny payloads are therefore always produced as RFC stored streams.
    const wire_kind: WireKind = if (plaintext_len < 5)
        .stored
    else
        rng.bounded(WireKind, &wire_kinds);
    return .{
        .wire_kind = wire_kind,
        .suffix_len = 1 + @as(usize, @intCast(rng.next() % 4)),
    };
}

/// Schedule and mutation fields drawn after the wire exists.
fn drawSchedule(rng: *Rng, frame_len: usize, plaintext_len: usize) Scenario {
    const regime = rng.bounded(Regime, std.enums.values(Regime));
    const pledge_base = rng.bounded(Pledge, std.enums.values(Pledge));
    return .{
        .payload_kind = undefined,
        .wire_kind = undefined,
        .regime = regime,
        // A zero-length plaintext cannot be one byte short; keep such rows exact.
        .pledge = if (pledge_base == .short and plaintext_len == 0) .none else pledge_base,
        // Appended suffix bytes are modeled as bytes retained for an outer
        // container, so they must be tolerated; otherwise frame completion
        // timing would make TrailingData depend on the chunk schedule.
        .allow_trailing = regime == .suffix or (rng.next() & 1) == 0,
        .tight_cap = (rng.next() & 7) == 0,
        .input_chunk = rng.bounded(usize, &input_chunks),
        .output_chunk = rng.bounded(usize, &output_chunks),
        .cut = if (frame_len == 0) 0 else rng.index(frame_len + 1),
        .flip_pos = if (frame_len == 0) 0 else rng.index(frame_len),
        .flip_delta = @intCast(1 + (rng.next() % 255)),
        .suffix_len = 0,
    };
}

fn applyWireShape(scenario: *Scenario, shape: WireShape) void {
    scenario.wire_kind = shape.wire_kind;
    scenario.suffix_len = shape.suffix_len;
}

fn buildPayload(allocator: Allocator, kind: PayloadKind) ![]u8 {
    return switch (kind) {
        .empty => try allocator.alloc(u8, 0),
        .tiny => try allocator.dupe(u8, "z"),
        .text => try allocator.dupe(u8, "brotli incremental fuzz driver text payload"),
        .repetitive => try allocator.dupe(u8, "abc" ** 48),
        .structured => blk: {
            const line = "{\"service\":\"vort\",\"status\":\"repeated\"}\n";
            const out = try allocator.alloc(u8, line.len * 12);
            for (0..12) |i| @memcpy(out[i * line.len ..][0..line.len], line);
            break :blk out;
        },
        // Larger than the small test windows so multiple meta-blocks emit.
        .multiblock => blk: {
            const out = try allocator.alloc(u8, 4096 + 17);
            for (out, 0..) |*byte, i| {
                byte.* = if (i % 97 == 0) @truncate(i / 97) else @as(u8, @truncate('a' + (i % 23)));
            }
            break :blk out;
        },
    };
}

fn buildWire(allocator: Allocator, shape: WireShape, plaintext: []const u8) !struct { frame: []u8, wire: []u8 } {
    const frame = switch (shape.wire_kind) {
        .planned => try br.encodePlannedStreamAlloc(allocator, plaintext),
        .stored => try br.IncrementalTestSupport.encodeStored(allocator, plaintext),
    };
    errdefer allocator.free(frame);
    const wire = try allocator.alloc(u8, frame.len + shape.suffix_len);
    @memcpy(wire[0..frame.len], frame);
    for (wire[frame.len..]) |*byte| byte.* = @truncate(0x5a +% @as(u8, @intCast(frame.len % 26)));
    return .{ .frame = frame, .wire = wire };
}

/// The byte range actually offered for the selected regime. Flip mutates the
/// suffix-bearing wire in place before borrowing the frame-length prefix.
fn offeredView(scenario: Scenario, frame: []const u8, wire: []u8) []const u8 {
    return switch (scenario.regime) {
        .valid => frame,
        .truncate => frame[0..scenario.cut],
        .flip => blk: {
            wire[scenario.flip_pos % frame.len] ^= scenario.flip_delta;
            break :blk wire[0..frame.len];
        },
        .suffix => wire,
    };
}

const Totals = struct { read: usize = 0, written: usize = 0 };

const Outcome = union(enum) {
    accepted: struct { read: usize, written: usize, steps: usize },
    /// All offered bytes were consumed without reaching done: a truncated wire
    /// or a suffix whose trailing stream is not completed in this run.
    incomplete: struct { read: usize, written: usize },
    rejected: anyerror,
};

fn checkProgress(
    decoder: *Decoder,
    totals: *Totals,
    progress: core.Progress,
    offered_input: []const u8,
    offered_output: []const u8,
) !void {
    try std.testing.expect(progress.input_read <= offered_input.len);
    try std.testing.expect(progress.output_written <= offered_output.len);
    totals.read += progress.input_read;
    totals.written += progress.output_written;
    const snap = decoder.snapshot();
    try std.testing.expectEqual(progress, snap.last_step_progress);
    // Cumulative accounting never regresses and covers every consumed byte.
    try std.testing.expect(@as(usize, @intCast(snap.total_compressed)) >= totals.read);
    try std.testing.expect(@as(usize, @intCast(snap.total_output)) >= totals.written);
}

fn decoderOptions(scenario: Scenario, plaintext_len: usize) Decoder.Options {
    var options: Decoder.Options = .{
        // Brotli rejects post-done trailing bytes unless explicitly allowed.
        .allow_trailing_data = scenario.allow_trailing,
        .max_working_memory = if (scenario.tight_cap) @as(usize, 4096) else 1 << 24,
        .max_compressed_len = if (scenario.tight_cap) @as(Counter, @intCast(@max(plaintext_len, 256))) else std.math.maxInt(Counter),
        .max_output_len = if (scenario.tight_cap) @as(Counter, @intCast(@max(plaintext_len, 1))) else std.math.maxInt(Counter),
        .max_total_output_len = if (scenario.tight_cap) @as(Counter, @intCast(@max(plaintext_len, 1))) else std.math.maxInt(Counter),
    };
    options.expected_output_len = switch (scenario.pledge) {
        .none => null,
        .exact => @intCast(plaintext_len),
        .short => @intCast(plaintext_len - 1),
    };
    return options;
}

/// Drive a caller-owned decoder through one canonical bounded schedule. The
/// input slice naturally becomes an empty finalization poll once all offered
/// bytes are consumed; empty polls are never injected while input remains.
fn runOnce(decoder: *Decoder, scenario: Scenario, offered: []const u8, plaintext_len: usize, capture: []u8) !Outcome {
    @memset(capture, canary_byte);

    var totals = Totals{};
    var in_pos: usize = 0;
    var out_pos: usize = 0;
    var steps: usize = 0;
    while (steps < max_steps) : (steps += 1) {
        const input = offered[in_pos..@min(offered.len, in_pos + scenario.input_chunk)];
        const out_end = @min(capture.len, out_pos + scenario.output_chunk);
        const output = capture[out_pos..out_end];

        const result = decoder.step(input, output) catch |err| {
            const snap = decoder.snapshot();
            try checkProgress(decoder, &totals, snap.last_step_progress, input, output);
            try std.testing.expect(err != error.OutOfMemory);
            return .{ .rejected = err };
        };
        try checkProgress(decoder, &totals, result.progress, input, output);
        in_pos += result.progress.input_read;
        out_pos += result.progress.output_written;
        for (capture[out_pos..]) |byte| try std.testing.expectEqual(canary_byte, byte);

        const cap = decoderOptions(scenario, plaintext_len).max_working_memory;
        try std.testing.expect(decoder.workingMemoryBytes() <= cap);
        try std.testing.expect(decoder.peakWorkingMemoryBytes() <= cap);
        try std.testing.expect(decoder.snapshot().retained_input_bytes <= decoderOptions(scenario, plaintext_len).max_compressed_len);

        if (result.status == .done) {
            try std.testing.expectEqual(@as(usize, @intCast(decoder.snapshot().total_output)), totals.written);
            return .{ .accepted = .{ .read = totals.read, .written = totals.written, .steps = steps + 1 } };
        }

        if (result.progress.input_read == 0 and result.progress.output_written == 0) {
            if (output.len == 0) return error.DriverCaptureTooSmall;
            if (in_pos == offered.len) return .{ .incomplete = .{ .read = totals.read, .written = totals.written } };
            return error.DriverStalled;
        }
    }
    return error.DriverStalled;
}

/// A rejection must be sticky, carry diagnostics, clear on reset, and reproduce.
fn checkStickyAndReset(
    allocator: Allocator,
    scenario: Scenario,
    offered: []const u8,
    plaintext_len: usize,
    first: anyerror,
) !void {
    var decoder = Decoder.initWithOptions(allocator, decoderOptions(scenario, plaintext_len));
    defer decoder.deinit();
    const capture = try allocator.alloc(u8, plaintext_len + output_slack);
    defer allocator.free(capture);

    const initial = try runOnce(&decoder, scenario, offered, plaintext_len, capture);
    try std.testing.expect(initial == .rejected);
    const err = switch (initial) {
        .rejected => |e| e,
        else => unreachable,
    };
    try std.testing.expectEqual(first, err);
    try std.testing.expectEqualStrings(@errorName(err), decoder.snapshot().last_error_name);
    // Sticky across further calls until an explicit reset.
    try std.testing.expectError(err, decoder.step(&.{}, &.{}));
    try std.testing.expectEqualStrings(@errorName(err), decoder.diagnostics().last_error_name);

    decoder.reset();
    try std.testing.expectEqualStrings("", decoder.snapshot().last_error_name);
    const again = try runOnce(&decoder, scenario, offered, plaintext_len, capture);
    try std.testing.expect(again == .rejected);
}

fn oneShotDecode(allocator: Allocator, bytes: []const u8) !?[]u8 {
    return br.decodeStreamAlloc(allocator, bytes) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => null,
    };
}

/// High-level first-pass classification reported by smoke runners.
pub const SeedResult = enum { accepted, incomplete, rejected };

/// Drive one seed end to end, releasing all temporary storage before returning.
pub fn drive(allocator: Allocator, seed: []const u8) anyerror!SeedResult {
    var rng = seedRng(seed);

    const payload_kind = rng.bounded(PayloadKind, std.enums.values(PayloadKind));
    const plaintext = try buildPayload(allocator, payload_kind);
    defer allocator.free(plaintext);
    const shape = drawWireShape(&rng, plaintext.len);
    const built = try buildWire(allocator, shape, plaintext);
    defer allocator.free(built.frame);
    defer allocator.free(built.wire);

    var scenario = drawSchedule(&rng, built.frame.len, plaintext.len);
    scenario.payload_kind = payload_kind;
    applyWireShape(&scenario, shape);
    const view = offeredView(scenario, built.frame, built.wire);

    const capture = try allocator.alloc(u8, plaintext.len + output_slack);
    defer allocator.free(capture);
    var decoder = Decoder.initWithOptions(allocator, decoderOptions(scenario, plaintext.len));
    defer decoder.deinit();
    const first = try runOnce(&decoder, scenario, view, plaintext.len, capture);

    switch (first) {
        .incomplete => return .incomplete,
        .accepted => |summary| {
            // A clean, untampered, non-cap-limited frame must fully decode.
            const strict = scenario.regime == .valid and !scenario.tight_cap and scenario.pledge != .short;
            if (strict) {
                try std.testing.expectEqual(view.len, summary.read);
                try std.testing.expectEqual(plaintext.len, summary.written);
                try std.testing.expectEqualSlices(u8, plaintext, capture[0..summary.written]);
            }

            if (try oneShotDecode(allocator, view)) |reference| {
                defer allocator.free(reference);
                try std.testing.expectEqualSlices(u8, reference, capture[0..summary.written]);
            } else if (strict) {
                return error.DriverReferenceMismatch;
            }

            // A different schedule must yield identical output.
            var rescheduled = scenario;
            rescheduled.input_chunk = input_chunks[(scenario.input_chunk + 3) % input_chunks.len];
            rescheduled.output_chunk = output_chunks[(scenario.output_chunk + 2) % output_chunks.len];
            var rescheduled_decoder = Decoder.initWithOptions(allocator, decoderOptions(rescheduled, plaintext.len));
            defer rescheduled_decoder.deinit();
            const second_capture = try allocator.alloc(u8, plaintext.len + output_slack);
            defer allocator.free(second_capture);
            const second = try runOnce(&rescheduled_decoder, rescheduled, view, plaintext.len, second_capture);
            try std.testing.expect(second == .accepted);
            const second_written = switch (second) {
                .accepted => |s| s.written,
                else => unreachable,
            };
            try std.testing.expectEqual(summary.written, second_written);
            try std.testing.expectEqualSlices(u8, capture[0..summary.written], second_capture[0..second_written]);
            return .accepted;
        },
        .rejected => |err| {
            try std.testing.expect(err != error.OutOfMemory);
            // A clean frame may only be rejected by the deliberately short pledge.
            if (scenario.regime == .valid and !scenario.tight_cap) {
                try std.testing.expectEqual(error.SizeMismatch, err);
                try std.testing.expectEqual(Pledge.short, scenario.pledge);
            }
            try checkStickyAndReset(allocator, scenario, view, plaintext.len, err);
            return .rejected;
        },
    }
}

/// Fixed, reproducible seed set covering every regime, wire kind and payload.
pub const smoke_seeds = blk: {
    var list: [48][8]u8 = undefined;
    for (&list, 0..) |*entry, i| {
        var rng = Rng{ .state = 0x1234_5678_9abc_def0 ^ (@as(u64, i) *% 0x9e3779b97f4a7c15) };
        for (entry) |*byte| byte.* = @truncate(rng.next());
    }
    break :blk list;
};

test "brotli incremental fuzz driver honors every deterministic seed without leaks" {
    for (smoke_seeds) |seed| {
        _ = try drive(std.testing.allocator, &seed);
    }
}

test "brotli incremental fuzz driver is deterministic across repeats" {
    const first = try drive(std.testing.allocator, "vort-brotli-incremental-fuzz-multiblock");
    const second = try drive(std.testing.allocator, "vort-brotli-incremental-fuzz-multiblock");
    try std.testing.expectEqual(first, second);
}

test "brotli incremental fuzz driver pins trailing-data rejection and tolerance" {
    const a = std.testing.allocator;
    const plaintext = "trailing data boundary contract";
    const frame = try br.encodePlannedStreamAlloc(a, plaintext);
    defer a.free(frame);
    const wrapped = try std.mem.concat(a, u8, &.{ frame, "outer-footer" });
    defer a.free(wrapped);

    // With trailing data disallowed, completing the frame then feeding more
    // bytes is a sticky TrailingData error that reset clears.
    {
        var decoder = Decoder.initWithOptions(a, .{ .allow_trailing_data = false });
        defer decoder.deinit();
        var capture: [plaintext.len]u8 = undefined;
        const first = try decoder.step(frame, &capture);
        try std.testing.expectEqual(core.StepResult.Status.done, first.status);
        try std.testing.expectEqualSlices(u8, plaintext, &capture);
        try std.testing.expectError(error.TrailingData, decoder.step("x", &.{}));
        try std.testing.expectError(error.TrailingData, decoder.step(&.{}, &.{}));
        try std.testing.expectEqualStrings("TrailingData", decoder.diagnostics().last_error_name);
        decoder.reset();
        const again = try decoder.step(frame, &capture);
        try std.testing.expectEqual(core.StepResult.Status.done, again.status);
    }

    // Allowing trailing data decodes the frame and parks at done despite the
    // appended suffix, matching an outer container that owns the remainder.
    {
        var decoder = Decoder.initWithOptions(a, .{ .allow_trailing_data = true });
        defer decoder.deinit();
        var capture: [plaintext.len]u8 = undefined;
        const result = try decoder.step(wrapped, &capture);
        try std.testing.expectEqual(core.StepResult.Status.done, result.status);
        try std.testing.expectEqualSlices(u8, plaintext, &capture);
    }
}
