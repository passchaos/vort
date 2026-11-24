const std = @import("std");
const codec = @import("codec");
const ref = @import("checkpoint_reference.zig");

const Raw = codec.RawDeflateIncrementalFixedLiteralDecoder;
const Auto = codec.ZlibOrGzipIncrementalDecoder;
const C = ref.C;
const sentinel: u8 = 0xa5;

const Schedule = struct { input_max: usize, output_max: usize, empty_every: usize = 0 };
const schedules = [_]Schedule{
    .{ .input_max = 1, .output_max = 1, .empty_every = 7 },
    .{ .input_max = 7, .output_max = 17, .empty_every = 5 },
    .{ .input_max = std.math.maxInt(usize), .output_max = 257, .empty_every = 7 },
    .{ .input_max = std.math.maxInt(usize), .output_max = std.math.maxInt(usize) },
};

const Counts = struct {
    reference_wires: usize = 0,
    runs: usize = 0,
    checkpoints: usize = 0,
    zero_progress_checkpoints: usize = 0,
    exact_limit_checkpoints: usize = 0,
    semantic_blocks: u64 = 0,
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const history = try allocator.alloc(u8, Raw.recommended_history_len);
    defer allocator.free(history);
    const semantic = try allocator.create(Raw.SemanticWorkspace);
    defer allocator.destroy(semantic);
    var counts: Counts = .{};
    const one_chunk = [_]u8{ 200, 201, 202, 203, 204, 205 };
    const chunk_len = 8 * 1024;
    var several_chunks: [3 * chunk_len]u8 = undefined;
    var rng = std.Random.DefaultPrng.init(0x8a3a_5ecc_b07b_2026);
    for (&several_chunks, 0..) |*byte, i| {
        // Wide printable literals induce dynamic codes without compressing
        // the input below the decoder's semantic admission threshold.
        byte.* = if (i >= chunk_len and i % chunk_len < 1024)
            several_chunks[i - chunk_len]
        else
            ' ' + rng.random().int(u8) % 95;
    }
    const fixtures = [_]struct { plain: []const u8, chunk_len: usize }{
        .{ .plain = &one_chunk, .chunk_len = one_chunk.len },
        .{ .plain = &several_chunks, .chunk_len = 8192 },
    };
    const formats = .{
        .{ ref.Wrapper.raw, Raw },
        .{ ref.Wrapper.zlib, codec.ZlibIncrementalDecoder },
        .{ ref.Wrapper.gzip, codec.GzipIncrementalDecoder },
    };
    inline for (formats) |format| {
        for (fixtures) |fixture| {
            for (std.enums.values(ref.Flush)) |flush| {
                for ([_]c_int{ C.Z_DEFAULT_STRATEGY, C.Z_FIXED }) |strategy| {
                    const wire = try ref.encode(allocator, format[0], fixture.plain, fixture.chunk_len, flush, strategy);
                    defer allocator.free(wire);
                    const trace = try ref.boundaries(allocator, format[0], wire, fixture.plain);
                    const expected = trace.checkpoints;
                    defer allocator.free(expected);
                    if (expected.len == 0 or expected[expected.len - 1].output != fixture.plain.len)
                        return error.MissingReferencePlateau;
                    if (flush == .mixed_tail) {
                        var plateau: usize = 0;
                        for (expected) |boundary| {
                            if (boundary.output == fixture.plain.len) plateau += 1;
                        }
                        if (plateau < 3) return error.MissingReferenceMixedTail;
                    }
                    counts.reference_wires += 1;
                    for (schedules) |schedule| {
                        check(format[1], allocator, history, wire, fixture.plain, trace, schedule, null, &counts) catch |err| {
                            logFailure(format[0], flush, strategy, fixture.plain.len, schedule, "compact");
                            return err;
                        };
                        if (format[0] != .raw) {
                            check(Auto, allocator, history, wire, fixture.plain, trace, schedule, null, &counts) catch |err| {
                                logFailure(format[0], flush, strategy, fixture.plain.len, schedule, "auto");
                                return err;
                            };
                        }
                        if (schedule.input_max == std.math.maxInt(usize)) {
                            check(format[1], allocator, history, wire, fixture.plain, trace, schedule, semantic, &counts) catch |err| {
                                logFailure(format[0], flush, strategy, fixture.plain.len, schedule, "semantic");
                                return err;
                            };
                        }
                    }
                }
            }
        }
    }
    if (counts.zero_progress_checkpoints == 0 or counts.exact_limit_checkpoints == 0 or counts.semantic_blocks == 0)
        return error.MissingCheckpointCoverage;
    var buffer: [1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try stdout.interface.print(
        "deflate_checkpoint_interop_ok zlib={s} wires={d} runs={d} checkpoints={d} zero_progress={d} at_output_limit={d} semantic_blocks={d}\n",
        .{ std.mem.span(C.zlibVersion()), counts.reference_wires, counts.runs, counts.checkpoints, counts.zero_progress_checkpoints, counts.exact_limit_checkpoints, counts.semantic_blocks },
    );
    try stdout.interface.flush();
}

fn rawState(decoder: anytype) *Raw {
    const Decoder = @TypeOf(decoder.*);
    if (Decoder == Raw) return decoder;
    if (Decoder == Auto) return switch (decoder.active) {
        .detecting => unreachable,
        .zlib => |*active| &active.raw,
        .gzip => |*active| &active.raw,
    };
    return &decoder.raw;
}

fn check(
    comptime Decoder: type,
    a: std.mem.Allocator,
    history: []u8,
    wire: []const u8,
    plain: []const u8,
    trace: ref.Trace,
    schedule: Schedule,
    semantic: ?*Raw.SemanticWorkspace,
    counts: *Counts,
) !void {
    const expected = trace.checkpoints;
    const options: Decoder.Options = .{ .expected_output_len = plain.len, .max_output_len = plain.len };
    var decoder = if (Decoder == Raw) try Raw.initWithHistory(options, history) else try Decoder.init(options, history);
    if (Decoder != Auto) {
        if (semantic) |workspace| try rawState(&decoder).attachSemanticWorkspace(workspace);
    }
    const guarded = try a.alloc(u8, plain.len + 2);
    defer a.free(guarded);
    @memset(guarded, sentinel);
    const output = guarded[1 .. guarded.len - 1];
    var read: usize = 0;
    var written: usize = 0;
    var checkpoint: usize = 0;
    for (0..(wire.len + plain.len) * 4 + 256) |call| {
        const supplied = wire[read..][0..@min(schedule.input_max, wire.len - read)];
        const pause_output = schedule.empty_every != 0 and call % schedule.empty_every == 0;
        const granted = output[written..][0..if (pause_output) 0 else @min(schedule.output_max, plain.len - written)];
        const r = try decoder.stepToBlockBoundary(supplied, granted);
        const p = r.progress;
        if (p.input_read > supplied.len or p.output_written > granted.len) return error.StepOutOfBounds;
        if (!std.mem.eql(u8, granted[0..p.output_written], plain[written..][0..p.output_written])) return error.PlaintextMismatch;
        read += p.input_read;
        written += p.output_written;
        if (r.block_boundary) {
            if (r.status != .need_input or !decoder.atBlockBoundary() or checkpoint == expected.len)
                return error.UnexpectedCheckpoint;
            const position = decoder.blockBoundaryPosition() orelse return error.MissingCheckpointPosition;
            const bits = @as(usize, @intCast(position.compressed_byte_offset)) * 8 + position.compressed_bit_offset;
            if (position.decoded_offset != written) return error.CheckpointOutputMismatch;
            const result: ref.Boundary = .{ .bits = bits, .output = written };
            if (!std.meta.eql(result, expected[checkpoint])) {
                std.log.err("checkpoint {d}: expected bits={d} output={d}, got bits={d} output={d}", .{ checkpoint, expected[checkpoint].bits, expected[checkpoint].output, bits, written });
                return error.CheckpointMismatch;
            }
            checkpoint += 1;
            counts.checkpoints += 1;
            if (p.input_read == 0 and p.output_written == 0) counts.zero_progress_checkpoints += 1;
            if (written == plain.len) counts.exact_limit_checkpoints += 1;
        } else if (r.status == .done) {
            try decoder.finish();
            if (checkpoint != expected.len or read != wire.len or written != plain.len)
                return error.UnexpectedCompletion;
            const position = decoder.blockBoundaryPosition() orelse return error.MissingCheckpointPosition;
            if (position.decoded_offset != written) return error.CheckpointOutputMismatch;
            if (Decoder == Raw) {
                const bits = @as(usize, @intCast(position.compressed_byte_offset)) * 8 + position.compressed_bit_offset;
                if (bits != trace.final_eob_bits) {
                    std.log.err("final EOB: expected bits={d}, got bits={d}", .{ trace.final_eob_bits, bits });
                    return error.CheckpointFinalEobMismatch;
                }
            } else if (position.compressed_byte_offset != read or position.compressed_bit_offset != 0) {
                return error.CheckpointFooterMismatch;
            }
            if (guarded[0] != sentinel or guarded[guarded.len - 1] != sentinel) return error.OutputGuardChanged;
            counts.runs += 1;
            counts.semantic_blocks += rawState(&decoder).semanticBlocksCompleted();
            return;
        } else if (p.input_read == 0 and p.output_written == 0 and !(pause_output and r.status == .need_output and written != plain.len)) {
            return error.DecoderNoProgress;
        }
    }
    return error.DecoderStepLimit;
}

fn logFailure(wrapper: ref.Wrapper, flush: ref.Flush, strategy: c_int, bytes: usize, schedule: Schedule, mode: []const u8) void {
    std.log.err("{s}/{s}/{s} strategy={d} plain={d} input_max={d} output_max={d} empty_every={d}", .{ @tagName(wrapper), @tagName(flush), mode, strategy, bytes, schedule.input_max, schedule.output_max, schedule.empty_every });
}
