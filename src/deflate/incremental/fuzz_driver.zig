//! Deterministic bounded fuzz driver for the incremental Deflate decoders.
//!
//! Mirrors the Zstd and Brotli drivers against Deflate's caller-owned-history
//! contract: each decoder is constructed over a fixed 32 KiB history slice (the
//! RFC maximum window) rather than an allocator, and each seed selects a zlib or
//! gzip wrapper, a stored/fixed/best wire, a mutation, decoder options and a
//! caller step schedule. On every step the driver checks:
//!
//!   * local progress never exceeds the offered input/output slices and the
//!     reported per-step progress matches the decoder snapshot;
//!   * caller output beyond `output_written` keeps its canary fill;
//!   * documented decode errors are surfaced cleanly, carry diagnostics,
//!     reproduce on a fresh decoder, and clear after `reset`;
//!   * accepted runs replay identically under a different schedule and, when
//!     the one-shot decoder also accepts the wire, match its output;
//!   * truncated wires terminate as an explicit incomplete result instead of
//!     a no-progress stall.
//!
//! `drive` takes an opaque seed so the same entry backs in-graph tests, a
//! standalone smoke executable and a future coverage-guided runner. The
//! decoders never allocate on the hot path and their error set is the closed
//! `deflate.Error` (core errors), so every non-success result is a documented
//! rejection rather than an unexpected allocation failure.
const std = @import("std");
const deflate = @import("../../deflate.zig");
const core = @import("../../core.zig");

const Allocator = std.mem.Allocator;
const Count = core.StreamCount;

const canary_byte: u8 = 0xa5;
const max_steps: usize = 200_000;
const output_slack: usize = 64;
/// RFC 1951 maximum back-reference window; covers every supported stream and
/// stays on the stack like the existing incremental decoder tests.
const history_len: usize = 32 * 1024;

const Wrapper = enum { zlib, gzip };
const WireKind = enum { stored, fixed, best };
const Regime = enum { valid, truncate, flip, suffix };
const PayloadKind = enum { empty, tiny, text, repetitive, structured, multiblock };
const Pledge = enum { none, exact, short };

const wrappers = [_]Wrapper{ .zlib, .gzip };
const wire_kinds = [_]WireKind{ .stored, .fixed, .best };
const input_chunks = [_]usize{ 1, 2, 3, 5, 8, 13, 31, 64, 257 };
// A fixed zero-output schedule could never finish a non-empty decode in one
// pass; 1-byte output still exercises maximal backpressure while completing.
const output_chunks = [_]usize{ 1, 2, 7, 17, 64, 257 };

/// Everything derived from a seed, frozen before any decoder call so reuse and
/// reset reproduce the exact wire and schedule.
const Scenario = struct {
    payload_kind: PayloadKind,
    wrapper: Wrapper,
    wire_kind: WireKind,
    regime: Regime,
    pledge: Pledge,
    allow_trailing: bool,
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

/// Wire-deciding fields drawn before encoding so decoder options match bytes.
const WireShape = struct {
    payload_kind: PayloadKind,
    wrapper: Wrapper,
    wire_kind: WireKind,
    suffix_len: usize,
};

fn drawWireShape(rng: *Rng) WireShape {
    return .{
        .payload_kind = rng.bounded(PayloadKind, std.enums.values(PayloadKind)),
        .wrapper = rng.bounded(Wrapper, &wrappers),
        .wire_kind = rng.bounded(WireKind, &wire_kinds),
        .suffix_len = 1 + @as(usize, @intCast(rng.next() % 4)),
    };
}

/// Schedule and mutation fields drawn after the wire exists.
fn drawSchedule(rng: *Rng, frame_len: usize, plaintext_len: usize) Scenario {
    const regime = rng.bounded(Regime, std.enums.values(Regime));
    const pledge_base = rng.bounded(Pledge, std.enums.values(Pledge));
    return .{
        .payload_kind = undefined,
        .wrapper = undefined,
        .wire_kind = undefined,
        .regime = regime,
        // A zero-length plaintext cannot be one byte short; keep such rows exact.
        .pledge = if (pledge_base == .short and plaintext_len == 0) .none else pledge_base,
        // Appended suffix bytes are modeled as an outer-container remainder, so
        // they must be tolerated; otherwise completion timing would make the
        // trailing-data decision depend on the chunk schedule.
        .allow_trailing = regime == .suffix or (rng.next() & 1) == 0,
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
    scenario.wrapper = shape.wrapper;
    scenario.wire_kind = shape.wire_kind;
    scenario.suffix_len = shape.suffix_len;
}

fn buildPayload(allocator: Allocator, kind: PayloadKind) ![]u8 {
    return switch (kind) {
        .empty => try allocator.alloc(u8, 0),
        .tiny => try allocator.dupe(u8, "z"),
        .text => try allocator.dupe(u8, "deflate incremental fuzz driver text payload"),
        .repetitive => try allocator.dupe(u8, "abc" ** 48),
        .structured => blk: {
            const line = "{\"service\":\"vort\",\"status\":\"repeated\"}\n";
            const out = try allocator.alloc(u8, line.len * 12);
            for (0..12) |i| @memcpy(out[i * line.len ..][0..line.len], line);
            break :blk out;
        },
        // Larger than the small block tests so multiple blocks emit.
        .multiblock => blk: {
            const out = try allocator.alloc(u8, 4096 + 17);
            for (out, 0..) |*byte, i| {
                byte.* = if (i % 97 == 0) @truncate(i / 97) else @as(u8, @truncate('a' + (i % 23)));
            }
            break :blk out;
        },
    };
}

fn encodeFrame(allocator: Allocator, scenario: Scenario, plaintext: []const u8) ![]u8 {
    if (scenario.wrapper == .zlib) {
        return switch (scenario.wire_kind) {
            .stored => try deflate.encodeZlibStoredAlloc(allocator, plaintext),
            .fixed => try deflate.encodeZlibFixedAlloc(allocator, plaintext),
            .best => try deflate.encodeZlibBestAlloc(allocator, plaintext, deflate.optionsForLevel(.default)),
        };
    }
    return switch (scenario.wire_kind) {
        .stored => try deflate.encodeGzipStoredAlloc(allocator, plaintext),
        .fixed => try deflate.encodeGzipFixedAlloc(allocator, plaintext),
        .best => try deflate.encodeGzipBestAlloc(allocator, plaintext, deflate.optionsForLevel(.default)),
    };
}

fn buildWire(allocator: Allocator, shape: WireShape, scenario: Scenario, plaintext: []const u8) !struct { frame: []u8, wire: []u8 } {
    const frame = try encodeFrame(allocator, scenario, plaintext);
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
    /// or a suffix whose remainder is not completed in this run.
    incomplete: struct { read: usize, written: usize },
    rejected: anyerror,
};

/// A type-erased handle over the zlib/gzip decoders, which share the same
/// method surface but are distinct generic instantiations.
const Handle = union(enum) {
    zlib: *deflate.ZlibIncrementalDecoder,
    gzip: *deflate.GzipIncrementalDecoder,

    fn step(self: Handle, input: []const u8, output: []u8) deflate.Error!core.StepResult {
        return switch (self) {
            .zlib => |d| d.step(input, output),
            .gzip => |d| d.step(input, output),
        };
    }

    fn reset(self: Handle) void {
        switch (self) {
            .zlib => |d| d.reset(),
            .gzip => |d| d.reset(),
        }
    }

    fn snapshotProgress(self: Handle) core.Progress {
        return switch (self) {
            .zlib => |d| d.snapshot().last_step_progress,
            .gzip => |d| d.snapshot().last_step_progress,
        };
    }

    fn totalOutput(self: Handle) Count {
        return switch (self) {
            .zlib => |d| d.snapshot().total_output,
            .gzip => |d| d.snapshot().total_output,
        };
    }

    fn errorName(self: Handle) []const u8 {
        return switch (self) {
            .zlib => |d| d.snapshot().last_error_name,
            .gzip => |d| d.snapshot().last_error_name,
        };
    }

    fn diagnosticsName(self: Handle) []const u8 {
        return switch (self) {
            .zlib => |d| d.diagnostics().last_error_name,
            .gzip => |d| d.diagnostics().last_error_name,
        };
    }
};

fn checkProgress(
    handle: Handle,
    totals: *Totals,
    progress: core.Progress,
    offered_input: []const u8,
    offered_output: []const u8,
) !void {
    try std.testing.expect(progress.input_read <= offered_input.len);
    try std.testing.expect(progress.output_written <= offered_output.len);
    totals.read += progress.input_read;
    totals.written += progress.output_written;
    try std.testing.expectEqual(progress, handle.snapshotProgress());
}

fn decoderOptions(scenario: Scenario, plaintext_len: usize) struct { zlib: deflate.ZlibIncrementalDecoder.Options, gzip: deflate.GzipIncrementalDecoder.Options } {
    const expected: ?Count = switch (scenario.pledge) {
        .none => null,
        .exact => @intCast(plaintext_len),
        .short => @intCast(plaintext_len - 1),
    };
    return .{
        .zlib = .{
            .expected_output_len = expected,
            .allow_trailing_data = scenario.allow_trailing,
        },
        .gzip = .{
            .expected_output_len = expected,
            .allow_trailing_data = scenario.allow_trailing,
        },
    };
}

/// Drive one caller-owned decoder through a canonical bounded schedule. The
/// input slice naturally becomes an empty finalization poll once all offered
/// bytes are consumed; empty polls are never injected while input remains.
fn runOnce(handle: Handle, scenario: Scenario, offered: []const u8, capture: []u8) !Outcome {
    @memset(capture, canary_byte);

    var totals = Totals{};
    var in_pos: usize = 0;
    var out_pos: usize = 0;
    var steps: usize = 0;
    while (steps < max_steps) : (steps += 1) {
        const input = offered[in_pos..@min(offered.len, in_pos + scenario.input_chunk)];
        const out_end = @min(capture.len, out_pos + scenario.output_chunk);
        const output = capture[out_pos..out_end];

        const result = handle.step(input, output) catch |err| {
            try checkProgress(handle, &totals, handle.snapshotProgress(), input, output);
            return .{ .rejected = err };
        };
        try checkProgress(handle, &totals, result.progress, input, output);
        in_pos += result.progress.input_read;
        out_pos += result.progress.output_written;
        for (capture[out_pos..]) |byte| try std.testing.expectEqual(canary_byte, byte);

        if (result.status == .done) {
            try std.testing.expectEqual(@as(usize, @intCast(handle.totalOutput())), totals.written);
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

/// A rejection must carry diagnostics, reproduce on a fresh decoder, and clear
/// after reset. Deflate reports errors through last_error_name rather than a
/// separate fatal flag, so the contract is checked via snapshots and reset.
fn checkRejectionAndReset(
    allocator: Allocator,
    history: []u8,
    scenario: Scenario,
    offered: []const u8,
    plaintext_len: usize,
    first: anyerror,
) !void {
    const options = decoderOptions(scenario, plaintext_len);
    const capture = try allocator.alloc(u8, plaintext_len + output_slack);
    defer allocator.free(capture);

    // Reproduce the same rejection on a fresh decoder that alone owns the
    // caller history slice for this check.
    var zlib_decoder: deflate.ZlibIncrementalDecoder = undefined;
    var gzip_decoder: deflate.GzipIncrementalDecoder = undefined;
    const fresh: Handle = switch (scenario.wrapper) {
        .zlib => blk: {
            zlib_decoder = try deflate.ZlibIncrementalDecoder.init(options.zlib, history);
            break :blk .{ .zlib = &zlib_decoder };
        },
        .gzip => blk: {
            gzip_decoder = try deflate.GzipIncrementalDecoder.init(options.gzip, history);
            break :blk .{ .gzip = &gzip_decoder };
        },
    };
    const initial = try runOnce(fresh, scenario, offered, capture);
    try std.testing.expect(initial == .rejected);
    const err = switch (initial) {
        .rejected => |e| e,
        else => unreachable,
    };
    try std.testing.expectEqual(first, err);
    try std.testing.expectEqualStrings(@errorName(err), fresh.errorName());
    try std.testing.expectEqualStrings(@errorName(err), fresh.diagnosticsName());

    // Reset clears the recorded error and reproduces the rejection again.
    fresh.reset();
    try std.testing.expectEqualStrings("", fresh.errorName());
    const again = try runOnce(fresh, scenario, offered, capture);
    try std.testing.expect(again == .rejected);
}

fn oneShotDecode(allocator: Allocator, scenario: Scenario, bytes: []const u8) !?[]u8 {
    const result = if (scenario.wrapper == .zlib)
        deflate.decodeZlibAlloc(allocator, bytes)
    else
        deflate.decodeGzipAlloc(allocator, bytes);
    return result catch null;
}

/// High-level first-pass classification reported by smoke runners.
pub const SeedResult = enum { accepted, incomplete, rejected };

/// A single live decoder over caller-owned history. Only the selected wrapper
/// is constructed, so the history slice is never aliased by two decoders.
const DecoderSlot = union(enum) {
    zlib: deflate.ZlibIncrementalDecoder,
    gzip: deflate.GzipIncrementalDecoder,

    fn init(wrapper: Wrapper, history: []u8, scenario: Scenario, plaintext_len: usize) !DecoderSlot {
        const options = decoderOptions(scenario, plaintext_len);
        return switch (wrapper) {
            .zlib => .{ .zlib = try deflate.ZlibIncrementalDecoder.init(options.zlib, history) },
            .gzip => .{ .gzip = try deflate.GzipIncrementalDecoder.init(options.gzip, history) },
        };
    }

    fn handle(self: *DecoderSlot) Handle {
        return switch (self.*) {
            .zlib => |*d| .{ .zlib = d },
            .gzip => |*d| .{ .gzip = d },
        };
    }
};

/// Drive one seed end to end, releasing all temporary storage before returning.
pub fn drive(allocator: Allocator, seed: []const u8) anyerror!SeedResult {
    var rng = seedRng(seed);

    const shape = drawWireShape(&rng);
    const plaintext = try buildPayload(allocator, shape.payload_kind);
    defer allocator.free(plaintext);

    // Build a scenario whose wire fields come from the shape; the frame is
    // encoded with those exact wrapper/wire-kind choices.
    var frame_scenario = drawSchedule(&rng, 0, plaintext.len);
    applyWireShape(&frame_scenario, shape);
    const built = try buildWire(allocator, shape, frame_scenario, plaintext);
    defer allocator.free(built.frame);
    defer allocator.free(built.wire);

    var scenario = drawSchedule(&rng, built.frame.len, plaintext.len);
    applyWireShape(&scenario, shape);
    const view = offeredView(scenario, built.frame, built.wire);

    const capture = try allocator.alloc(u8, plaintext.len + output_slack);
    defer allocator.free(capture);
    const history = try allocator.alloc(u8, history_len);
    defer allocator.free(history);
    var slot = try DecoderSlot.init(scenario.wrapper, history, scenario, plaintext.len);
    const first = try runOnce(slot.handle(), scenario, view, capture);

    switch (first) {
        .incomplete => return .incomplete,
        .accepted => |summary| {
            // A clean, untampered frame without a deliberately short pledge
            // must fully decode.
            const strict = scenario.regime == .valid and scenario.pledge != .short;
            if (strict) {
                try std.testing.expectEqual(view.len, summary.read);
                try std.testing.expectEqual(plaintext.len, summary.written);
                try std.testing.expectEqualSlices(u8, plaintext, capture[0..summary.written]);
            }

            if (try oneShotDecode(allocator, scenario, view)) |reference| {
                defer allocator.free(reference);
                try std.testing.expectEqualSlices(u8, reference, capture[0..summary.written]);
            } else if (strict) {
                return error.DriverReferenceMismatch;
            }

            // A different schedule must yield identical output. A fresh decoder
            // reuses the history slice once the first run no longer needs it.
            var rescheduled = scenario;
            rescheduled.input_chunk = input_chunks[(scenario.input_chunk + 3) % input_chunks.len];
            rescheduled.output_chunk = output_chunks[(scenario.output_chunk + 2) % output_chunks.len];
            var rescheduled_slot = try DecoderSlot.init(scenario.wrapper, history, rescheduled, plaintext.len);
            const second_capture = try allocator.alloc(u8, plaintext.len + output_slack);
            defer allocator.free(second_capture);
            const second = try runOnce(rescheduled_slot.handle(), rescheduled, view, second_capture);
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
            // A clean frame may only be rejected by the deliberately short pledge.
            if (scenario.regime == .valid) {
                try std.testing.expectEqual(error.SizeMismatch, err);
                try std.testing.expectEqual(Pledge.short, scenario.pledge);
            }
            try checkRejectionAndReset(allocator, history, scenario, view, plaintext.len, err);
            return .rejected;
        },
    }
}

/// Fixed, reproducible seed set covering every wrapper, regime, wire kind and
/// payload shape across many independent schedules.
pub const smoke_seeds = blk: {
    var list: [48][8]u8 = undefined;
    for (&list, 0..) |*entry, i| {
        var rng = Rng{ .state = 0x1234_5678_9abc_def0 ^ (@as(u64, i) *% 0x9e3779b97f4a7c15) };
        for (entry) |*byte| byte.* = @truncate(rng.next());
    }
    break :blk list;
};

test "deflate incremental fuzz driver honors every deterministic seed without leaks" {
    for (smoke_seeds) |seed| {
        _ = try drive(std.testing.allocator, &seed);
    }
}

test "deflate incremental fuzz driver is deterministic across repeats" {
    const first = try drive(std.testing.allocator, "vort-deflate-incremental-fuzz-multiblock");
    const second = try drive(std.testing.allocator, "vort-deflate-incremental-fuzz-multiblock");
    try std.testing.expectEqual(first, second);
}

test "deflate incremental fuzz driver pins trailing-data rejection and tolerance" {
    const a = std.testing.allocator;
    const plaintext = "deflate trailing data boundary contract";
    inline for (.{ Wrapper.zlib, Wrapper.gzip }) |wrapper| {
        const frame = switch (wrapper) {
            .zlib => try deflate.encodeZlibFixedAlloc(a, plaintext),
            .gzip => try deflate.encodeGzipFixedAlloc(a, plaintext),
        };
        defer a.free(frame);
        const wrapped = try std.mem.concat(a, u8, &.{ frame, "outer-footer" });
        defer a.free(wrapped);
        var history: [history_len]u8 = undefined;

        // With trailing data disallowed, completing the frame then feeding more
        // bytes is a TrailingData error that reset clears.
        {
            var decoder = switch (wrapper) {
                .zlib => try deflate.ZlibIncrementalDecoder.init(.{}, &history),
                .gzip => try deflate.GzipIncrementalDecoder.init(.{}, &history),
            };
            var capture: [plaintext.len]u8 = undefined;
            const first = switch (wrapper) {
                .zlib => try decoder.step(frame, &capture),
                .gzip => try decoder.step(frame, &capture),
            };
            try std.testing.expectEqual(core.StepResult.Status.done, first.status);
            try std.testing.expectEqualSlices(u8, plaintext, &capture);
            const reject = switch (wrapper) {
                .zlib => decoder.step("x", &.{}),
                .gzip => decoder.step("x", &.{}),
            };
            try std.testing.expectError(error.TrailingData, reject);
            try std.testing.expectEqualStrings("TrailingData", decoder.snapshot().last_error_name);
            decoder.reset();
            try std.testing.expectEqualStrings("", decoder.snapshot().last_error_name);
        }

        // Allowing trailing data decodes the frame and reaches done despite the
        // appended suffix, matching an outer container that owns the remainder.
        {
            var decoder = switch (wrapper) {
                .zlib => try deflate.ZlibIncrementalDecoder.init(.{ .allow_trailing_data = true }, &history),
                .gzip => try deflate.GzipIncrementalDecoder.init(.{ .allow_trailing_data = true }, &history),
            };
            var capture: [plaintext.len]u8 = undefined;
            const result = switch (wrapper) {
                .zlib => try decoder.step(wrapped, &capture),
                .gzip => try decoder.step(wrapped, &capture),
            };
            try std.testing.expectEqual(core.StepResult.Status.done, result.status);
            try std.testing.expectEqualSlices(u8, plaintext, &capture);
        }
    }
}

test "deflate incremental fuzz driver pins short-pledge size mismatch" {
    const a = std.testing.allocator;
    const plaintext = "pledge mismatch payload that has enough bytes";
    const frame = try deflate.encodeZlibFixedAlloc(a, plaintext);
    defer a.free(frame);
    var history: [history_len]u8 = undefined;
    var decoder = try deflate.ZlibIncrementalDecoder.init(.{ .expected_output_len = plaintext.len - 1 }, &history);
    var capture: [plaintext.len]u8 = undefined;
    try std.testing.expectError(error.SizeMismatch, decoder.step(frame, &capture));
    try std.testing.expectEqualStrings("SizeMismatch", decoder.snapshot().last_error_name);
}
