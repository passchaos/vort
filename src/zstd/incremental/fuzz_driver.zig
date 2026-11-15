//! Deterministic bounded fuzz driver for the native incremental Zstd decoder.
//!
//! Each seed string deterministically selects a generated wire, a mutated form
//! of that wire, decoder options, and a caller-driven step schedule. The driver
//! exercises both compressed-input policies and both frame formats under tiny
//! caller buffers and checks, on every step:
//!
//!   * local progress never exceeds the offered input/output slices, and the
//!     cumulative snapshot advances by exactly the reported progress;
//!   * caller output bytes beyond `output_written` keep their canary fill;
//!   * documented decode errors are sticky until `reset`, carry diagnostics,
//!     and reproduce after reuse;
//!   * resource caps and retained compressed buffers stay within their budgets;
//!   * accepted runs replay identically under a different call schedule and,
//!     when the one-shot decoder also accepts the same wire, match its output;
//!   * truncated or uncompleted-suffix wires terminate as an explicit
//!     incomplete result instead of a no-progress stall.
//!
//! `drive` takes an opaque seed byte string, so the same entry backs the in-graph
//! deterministic tests, a standalone smoke executable, and a future
//! coverage-guided runner that supplies arbitrary bytes. All malformed-input
//! behavior is treated as a documented rejection except real `OutOfMemory`,
//! which always propagates to the caller.
const std = @import("std");
const zstd = @import("../../zstd.zig");
const core = @import("../../core.zig");

const Allocator = std.mem.Allocator;
const Decoder = zstd.NativeIncrementalFrameDecoder;
const StreamCount = core.StreamCount;

const canary_byte: u8 = 0xa5;
const max_steps: usize = 200_000;
const output_slack: usize = 64;

const Regime = enum { valid, truncate, flip, suffix };
const PayloadKind = enum { empty, tiny, text, repetitive, structured, multiblock };
const Pledge = enum { none, exact, short };

const input_chunks = [_]usize{ 1, 2, 3, 5, 8, 13, 31, 64, 257 };
// A fixed zero-output schedule could never finish a non-empty decode in one
// pass; 1-byte output still exercises maximal backpressure while completing.
// Explicit zero-output backpressure is covered directly in decoder_tests.
const output_chunks = [_]usize{ 1, 2, 7, 17, 64, 257 };
const formats = [_]zstd.FrameFormat{ .standard, .magicless };
const selections = [_]zstd.NativeFrameSelection{ .raw_or_rle, .literal_only };
const policies = [_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame };

/// Everything derived from a seed, frozen before any decoder call so reuse and
/// reset reproduce the exact wire and schedule.
const Scenario = struct {
    payload_kind: PayloadKind,
    format: zstd.FrameFormat,
    selection: zstd.NativeFrameSelection,
    checksum: bool,
    known_size: bool,
    regime: Regime,
    policy: core.CompressedInputPolicy,
    pledge: Pledge,
    stop_after_first: bool,
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
    // A short constant seed still produces a useful spread; mix in the length so
    // empty and single-byte seeds do not collapse onto the same scenario.
    hash ^= @as(u64, @intCast(seed.len)) *% 0x9e3779b97f4a7c15;
    return .{ .state = hash };
}

/// Fields that decide the generated wire; drawn before encoding so the decoder
/// options always match the bytes actually on the wire.
const WireShape = struct {
    payload_kind: PayloadKind,
    format: zstd.FrameFormat,
    selection: zstd.NativeFrameSelection,
    checksum: bool,
    known_size: bool,
    suffix_len: usize,
};

fn drawWireShape(rng: *Rng) WireShape {
    return .{
        .payload_kind = rng.bounded(PayloadKind, std.enums.values(PayloadKind)),
        .format = rng.bounded(zstd.FrameFormat, &formats),
        .selection = rng.bounded(zstd.NativeFrameSelection, &selections),
        .checksum = (rng.next() & 1) == 0,
        .known_size = (rng.next() & 1) == 0,
        .suffix_len = 1 + @as(usize, @intCast(rng.next() % 4)),
    };
}

/// Schedule and mutation fields drawn after the wire exists, so length-derived
/// cut/flip indices stay in bounds.
fn drawSchedule(rng: *Rng, frame_len: usize, plaintext_len: usize) Scenario {
    const regime = rng.bounded(Regime, std.enums.values(Regime));
    const pledge_base = rng.bounded(Pledge, std.enums.values(Pledge));
    return .{
        .payload_kind = undefined,
        .format = undefined,
        .selection = undefined,
        .checksum = undefined,
        .known_size = undefined,
        .regime = regime,
        .policy = rng.bounded(core.CompressedInputPolicy, &policies),
        // A zero-length plaintext cannot be one byte short; keep such rows exact.
        .pledge = if (pledge_base == .short and plaintext_len == 0) .none else pledge_base,
        .stop_after_first = (rng.next() & 1) == 0,
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
    scenario.payload_kind = shape.payload_kind;
    scenario.format = shape.format;
    scenario.selection = shape.selection;
    scenario.checksum = shape.checksum;
    scenario.known_size = shape.known_size;
    scenario.suffix_len = shape.suffix_len;
}

fn buildPayload(allocator: Allocator, kind: PayloadKind) ![]u8 {
    return switch (kind) {
        .empty => try allocator.alloc(u8, 0),
        .tiny => try allocator.dupe(u8, "z"),
        .text => try allocator.dupe(u8, "zstd incremental fuzz driver text payload"),
        .repetitive => try allocator.dupe(u8, "abc" ** 48),
        .structured => blk: {
            const line = "{\"service\":\"vort\",\"status\":\"repeated\"}\n";
            const out = try allocator.alloc(u8, line.len * 12);
            for (0..12) |i| @memcpy(out[i * line.len ..][0..line.len], line);
            break :blk out;
        },
        // Larger than the small default test windows so multiple blocks emit.
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
    const encoded = try zstd.encodeNativeFrameWithOptionsAlloc(allocator, plaintext, .{
        .format = shape.format,
        .selection = shape.selection,
        .content_checksum = shape.checksum,
        .include_content_size = shape.known_size,
        .block_size_max = 128,
        .window_log = 10,
    });
    defer allocator.free(encoded.frame);
    const wire = try allocator.alloc(u8, encoded.frame.len + shape.suffix_len);
    @memcpy(wire[0..encoded.frame.len], encoded.frame);
    for (wire[encoded.frame.len..]) |*byte| byte.* = @truncate(0x5a +% @as(u8, @intCast(encoded.frame.len % 26)));
    return .{ .frame = try allocator.dupe(u8, encoded.frame), .wire = wire };
}

/// The byte range actually offered to the decoder for the selected regime.
/// The flip regime mutates the suffix-bearing wire in place before borrowing.
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
    /// or a suffix that begins another member the driver never completes.
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
    try std.testing.expectEqual(@as(StreamCount, totals.read), snap.input_received);
    try std.testing.expectEqual(@as(StreamCount, totals.written), snap.output_written);
    try std.testing.expectEqual(progress, snap.last_step_progress);
}

fn decoderOptions(scenario: Scenario, plaintext_len: usize) Decoder.Options {
    var options: Decoder.Options = .{
        .format = scenario.format,
        .input_policy = scenario.policy,
        .stop_after_first_frame = scenario.stop_after_first,
        // Every scenario gets a finite budget so accounting is always exercised.
        .max_working_memory = if (scenario.tight_cap) @as(usize, 4096) else 1 << 24,
        .max_compressed_buffer_len = if (scenario.tight_cap) @as(usize, 256) else 1 << 20,
        .max_output_len = if (scenario.tight_cap) @as(StreamCount, @intCast(@max(plaintext_len, 1))) else std.math.maxInt(StreamCount),
    };
    options.expected_output_len = switch (scenario.pledge) {
        .none => null,
        .exact => @intCast(plaintext_len),
        .short => @intCast(plaintext_len - 1),
    };
    return options;
}

/// Drive a caller-owned decoder through one complete schedule. The decoder is
/// reusable via `reset`; the capture buffer is refilled with canaries here.
///
/// The schedule follows the canonical bounded-stream contract: feed the next
/// real input slice each step, which naturally becomes an empty finalization
/// poll once every offered byte is consumed. Empty polls are never injected
/// while input remains, matching the reference `drain`/`feed` test helpers and
/// avoiding non-canonical states the public contract does not promise.
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
        // Every byte the decoder did not write must retain the canary fill.
        for (capture[out_pos..]) |byte| try std.testing.expectEqual(canary_byte, byte);

        const cap = decoderOptions(scenario, plaintext_len).max_working_memory;
        try std.testing.expect(decoder.workingMemoryBytes() <= cap);
        try std.testing.expect(decoder.peakWorkingMemoryBytes() <= cap);
        try std.testing.expect(decoder.compressedBufferCapacity() <= std.compress.zstd.block_size_max or scenario.tight_cap);

        if (result.status == .done) {
            try std.testing.expectEqual(@as(StreamCount, totals.written), decoder.snapshot().output_written);
            return .{ .accepted = .{ .read = totals.read, .written = totals.written, .steps = steps + 1 } };
        }

        if (result.progress.input_read == 0 and result.progress.output_written == 0) {
            // No output room means the caller capture was undersized, a driver
            // defect rather than a decoder rejection.
            if (output.len == 0) return error.DriverCaptureTooSmall;
            // Every offered byte is already consumed: the decoder can only be
            // waiting on input that will never arrive in this run, so the wire
            // is truncated or begins an uncompleted next member.
            if (in_pos == offered.len) return .{ .incomplete = .{ .read = totals.read, .written = totals.written } };
            // A real feed with output room that moves nothing is a true stall.
            return error.DriverStalled;
        }
    }
    return error.DriverStalled;
}

/// Verify a rejection is sticky, carries diagnostics, and clears on reset, then
/// reproduces the same rejection on the reused decoder.
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
    const snap = decoder.snapshot();
    try std.testing.expectEqualStrings(@errorName(err), snap.last_error_name);
    // The failure is sticky across further calls until an explicit reset.
    try std.testing.expectError(err, decoder.step(&.{}, &.{}));
    try std.testing.expectEqualStrings(@errorName(err), decoder.diagnostics().last_error_name);

    decoder.reset();
    try std.testing.expectEqualStrings("", decoder.snapshot().last_error_name);
    const again = try runOnce(&decoder, scenario, offered, plaintext_len, capture);
    try std.testing.expect(again == .rejected);
}

fn oneShotDecode(allocator: Allocator, scenario: Scenario, bytes: []const u8) !?[]u8 {
    return zstd.decodeFrameAllocWithOptions(allocator, bytes, .{ .format = scenario.format }) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => null,
    };
}

/// High-level classification of a seed's first decoder pass, reported so smoke
/// runners can summarize the mix without weakening any internal invariant.
pub const SeedResult = enum { accepted, incomplete, rejected };

/// Drive one seed end to end, including mutation, differential, sticky and reuse
/// contracts. All temporary storage is released before returning.
pub fn drive(allocator: Allocator, seed: []const u8) anyerror!SeedResult {
    var rng = seedRng(seed);

    // First draw the wire-deciding shape and encode it, then draw the schedule
    // against the real frame length so every derived index stays in bounds and
    // the decoder options match the generated bytes.
    const shape = drawWireShape(&rng);
    const plaintext = try buildPayload(allocator, shape.payload_kind);
    defer allocator.free(plaintext);
    const built = try buildWire(allocator, shape, plaintext);
    defer allocator.free(built.frame);
    defer allocator.free(built.wire);

    var scenario = drawSchedule(&rng, built.frame.len, plaintext.len);
    applyWireShape(&scenario, shape);
    const view = offeredView(scenario, built.frame, built.wire);

    const capture = try allocator.alloc(u8, plaintext.len + output_slack);
    defer allocator.free(capture);
    var decoder = Decoder.initWithOptions(allocator, decoderOptions(scenario, plaintext.len));
    defer decoder.deinit();
    const first = try runOnce(&decoder, scenario, view, plaintext.len, capture);

    switch (first) {
        .incomplete => {
            // Truncated wires and unfinished suffix members end here; the loop
            // already enforced progress, canary and resource invariants.
            return .incomplete;
        },
        .accepted => |summary| {
            // Strict rows must fully consume a clean, unmutated frame.
            const strict = scenario.regime == .valid and !scenario.tight_cap and scenario.pledge != .short;
            if (strict) {
                try std.testing.expectEqual(view.len, summary.read);
                try std.testing.expectEqual(plaintext.len, summary.written);
                try std.testing.expectEqualSlices(u8, plaintext, capture[0..summary.written]);
            }

            if (try oneShotDecode(allocator, scenario, view)) |reference| {
                defer allocator.free(reference);
                try std.testing.expectEqualSlices(u8, reference, capture[0..summary.written]);
            } else if (strict) {
                // The one-shot decoder must accept every strict valid wire.
                return error.DriverReferenceMismatch;
            }

            // A second, deliberately different schedule must produce identical
            // output, proving the result is independent of the call schedule.
            var rescheduled = scenario;
            rescheduled.input_chunk = input_chunks[(scenario.input_chunk + 3) % input_chunks.len];
            rescheduled.output_chunk = output_chunks[(scenario.output_chunk + 2) % output_chunks.len];
            var rescheduled_decoder = Decoder.initWithOptions(allocator, decoderOptions(rescheduled, plaintext.len));
            defer rescheduled_decoder.deinit();
            const second_capture = try allocator.alloc(u8, plaintext.len + output_slack);
            defer allocator.free(second_capture);
            const second = try runOnce(&rescheduled_decoder, rescheduled, view, plaintext.len, second_capture);
            // Schedule independence is only guaranteed when chunk boundaries
            // cannot change how far the decoder walks into extra bytes. A suffix
            // on a non-stopping decoder is a real concatenated-member attempt:
            // a different chunking may legitimately parse deeper into the random
            // suffix and reject it, so only the frame-bounded regimes must match.
            const schedule_independent = scenario.regime != .suffix or scenario.stop_after_first;
            if (schedule_independent) {
                try std.testing.expect(second == .accepted);
                const second_written = switch (second) {
                    .accepted => |s| s.written,
                    else => unreachable,
                };
                try std.testing.expectEqual(summary.written, second_written);
                try std.testing.expectEqualSlices(u8, capture[0..summary.written], second_capture[0..second_written]);
            }
            return .accepted;
        },
        .rejected => |err| {
            try std.testing.expect(err != error.OutOfMemory);
            // Valid frames may only be rejected by the deliberately short pledge.
            if (scenario.regime == .valid and !scenario.tight_cap) {
                try std.testing.expectEqual(error.SizeMismatch, err);
                try std.testing.expectEqual(Pledge.short, scenario.pledge);
            }
            try checkStickyAndReset(allocator, scenario, view, plaintext.len, err);
            return .rejected;
        },
    }
}

/// Fixed, reproducible seed set covering every regime, format, policy and
/// payload shape across many independent schedules.
pub const smoke_seeds = blk: {
    var list: [48][8]u8 = undefined;
    for (&list, 0..) |*entry, i| {
        var rng = Rng{ .state = 0x1234_5678_9abc_def0 ^ (@as(u64, i) *% 0x9e3779b97f4a7c15) };
        for (entry) |*byte| byte.* = @truncate(rng.next());
    }
    break :blk list;
};

test "incremental fuzz driver honors every deterministic seed without leaks" {
    for (smoke_seeds) |seed| {
        _ = try drive(std.testing.allocator, &seed);
    }
}

test "incremental fuzz driver survives a broad deterministic seed sweep" {
    // Wider than the fixed matrix to keep schedule-dependent edge cases (such
    // as suffix concatenation depth) covered without an external fuzz engine.
    var seed: [12]u8 = undefined;
    for (0..256) |i| {
        for (&seed, 0..) |*byte, j| byte.* = @truncate((i *% 31 +% j *% 17) >> @intCast(j % 8));
        _ = try drive(std.testing.allocator, &seed);
    }
}

test "incremental fuzz driver is deterministic across repeats and keeps canary discipline" {
    // A hand-built seed path that reaches the multiblock payload exercises the
    // widest canary buffer; repeated runs stay byte-for-byte deterministic.
    const first = try drive(std.testing.allocator, "vort-incremental-fuzz-multiblock");
    const second = try drive(std.testing.allocator, "vort-incremental-fuzz-multiblock");
    try std.testing.expectEqual(first, second);
}

test "incremental fuzz driver stopped prevalidated decoder retains its suffix" {
    // Trailing-byte retention is only promised for a prevalidated decoder that
    // stops after the first frame; mirror the supported single-feed contract.
    const a = std.testing.allocator;
    const plaintext = "stop-after-first-frame suffix";
    const encoded = try zstd.encodeNativeFrameWithOptionsAlloc(a, plaintext, .{
        .selection = .literal_only,
        .content_checksum = false,
        .include_content_size = true,
    });
    defer a.free(encoded.frame);
    const suffix = "outer-container-footer";
    const wrapped = try std.mem.concat(a, u8, &.{ encoded.frame, suffix });
    defer a.free(wrapped);

    var decoder = Decoder.initWithOptions(a, .{
        .input_policy = .prevalidated_frame,
        .stop_after_first_frame = true,
    });
    defer decoder.deinit();
    var capture: [plaintext.len]u8 = undefined;
    const result = try decoder.step(wrapped, &capture);
    try std.testing.expectEqual(core.StepResult.Status.done, result.status);
    try std.testing.expectEqualSlices(u8, suffix, decoder.trailingInput());
    try std.testing.expectEqualSlices(u8, plaintext, &capture);
}

test "incremental fuzz driver decodes a valid two-frame concatenation" {
    const a = std.testing.allocator;
    const first_plain = "first concatenated member alpha beta";
    const second_plain = "second concatenated member gamma";
    const first = try zstd.encodeNativeFrameWithOptionsAlloc(a, first_plain, .{
        .selection = .literal_only,
        .content_checksum = false,
        .include_content_size = true,
    });
    defer a.free(first.frame);
    const second = try zstd.encodeNativeFrameWithOptionsAlloc(a, second_plain, .{
        .selection = .raw_or_rle,
        .content_checksum = true,
        .include_content_size = false,
    });
    defer a.free(second.frame);
    const stream = try std.mem.concat(a, u8, &.{ first.frame, second.frame });
    defer a.free(stream);
    const expected = try std.mem.concat(a, u8, &.{ first_plain, second_plain });
    defer a.free(expected);

    // A non-stopping decoder walks from the first frame straight into the next
    // member; drive it one byte at a time to cover every phase transition.
    var decoder = Decoder.initWithOptions(a, .{
        .input_policy = .block_stream,
        .stop_after_first_frame = false,
        .expected_output_len = expected.len,
    });
    defer decoder.deinit();
    const capture = try a.alloc(u8, expected.len);
    defer a.free(capture);
    var in_pos: usize = 0;
    var out_pos: usize = 0;
    var rounds: usize = 0;
    while (in_pos < stream.len or out_pos < expected.len) : (rounds += 1) {
        try std.testing.expect(rounds < max_steps);
        const result = try decoder.step(
            stream[in_pos..@min(stream.len, in_pos + 1)],
            capture[out_pos..@min(capture.len, out_pos + 3)],
        );
        in_pos += result.progress.input_read;
        out_pos += result.progress.output_written;
        if (result.status == .done) break;
    }
    try decoder.finish();
    try std.testing.expectEqual(stream.len, in_pos);
    try std.testing.expectEqual(expected.len, out_pos);
    try std.testing.expectEqualSlices(u8, expected, capture[0..out_pos]);
    try std.testing.expectEqual(@as(core.StreamCount, 2), decoder.snapshot().data_frame_count);
}

test "incremental fuzz driver round-trips a raw-content dictionary frame" {
    const a = std.testing.allocator;
    // Reuse a long phrase so the encoder can reference dictionary history.
    const dictionary = zstd.NativeDictionary.initRawContent("the quick brown fox jumps over the lazy dog repeatedly");
    const plaintext = "the quick brown fox jumps over the lazy dog repeatedly again";
    const encoded = try zstd.encodeNativeFrameWithDictionaryAlloc(a, plaintext, .{
        .selection = .raw_or_rle,
        .content_checksum = true,
        .include_content_size = true,
    }, dictionary);
    defer a.free(encoded.frame);

    // With the dictionary attached, a one-byte-at-a-time schedule reproduces
    // the plaintext exactly.
    var decoder = Decoder.initWithDictionary(a, dictionary);
    defer decoder.deinit();
    const capture = try a.alloc(u8, plaintext.len);
    defer a.free(capture);
    var in_pos: usize = 0;
    var out_pos: usize = 0;
    var rounds: usize = 0;
    while (in_pos < encoded.frame.len or out_pos < plaintext.len) : (rounds += 1) {
        try std.testing.expect(rounds < max_steps);
        const result = try decoder.step(
            encoded.frame[in_pos..@min(encoded.frame.len, in_pos + 1)],
            capture[out_pos..@min(capture.len, out_pos + 3)],
        );
        in_pos += result.progress.input_read;
        out_pos += result.progress.output_written;
        if (result.status == .done) break;
    }
    try decoder.finish();
    try std.testing.expectEqual(plaintext.len, out_pos);
    try std.testing.expectEqualSlices(u8, plaintext, capture[0..out_pos]);
}
