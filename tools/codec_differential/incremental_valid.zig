//! Replay complete generated wires through caller-fragmented decoders. The
//! generator's plaintext is compared as it is published, without a staging
//! allocation that could hide output beyond the caller's offered span.
const std = @import("std");
const vort = @import("vort");

pub const Schedule = enum { progressive, pledged };
pub const schedules = [_]Schedule{ .progressive, .pledged };
pub const Outcome = enum { complete, truncated };
pub const Progress = struct {
    read: usize = 0,
    written: usize = 0,
    calls: usize = 0,
    empty_output_calls: usize = 0,
    error_phase: []const u8 = "",
};

const output_capacity = 257;
const canary: u8 = 0xa5;

fn commit(progress: *Progress, step: vort.Progress, input_len: usize, output_len: usize, storage: []const u8, plain: []const u8) !void {
    const read = step.input_read;
    const written = step.output_written;
    if (read > input_len or written > output_len) return error.InvalidProgress;
    if (!std.mem.allEqual(u8, storage[written..], canary)) return error.OutputCanaryChanged;
    if (written > plain.len - progress.written) return error.SurplusOutput;
    if (!std.mem.eql(u8, storage[0..written], plain[progress.written..][0..written])) return error.PlaintextMismatch;
    progress.read += read;
    progress.written += written;
}

fn failedProgress(decoder: anytype, progress: Progress) !vort.Progress {
    const diagnostics = decoder.diagnostics();
    if (diagnostics.last_step_progress) |step| return step;
    // The raw Deflate API exposes cumulative counts rather than per-call
    // error progress. The other facades publish the failed call directly.
    const read = diagnostics.frame_input_read orelse return error.MissingProgress;
    if (read < progress.read or diagnostics.output_written < progress.written) return error.InvalidProgress;
    return .{ .input_read = std.math.cast(usize, read - progress.read) orelse return error.InvalidProgress, .output_written = std.math.cast(usize, diagnostics.output_written - progress.written) orelse return error.InvalidProgress };
}

fn drive(decoder: anytype, wire: []const u8, plain: []const u8, schedule: Schedule, exercise_empty_output: bool, outcome: Outcome, progress: *Progress) !void {
    // Bytewise input exercises split fields on small wires. For long wires
    // keep the matrix bounded while splitting essentially every data block.
    const input_chunk: usize = switch (schedule) {
        .progressive => if (wire.len <= 1024) 1 else 37,
        .pledged => 509,
    };
    const output_chunk: usize = switch (schedule) {
        .progressive => if (plain.len <= 1024) 7 else 113,
        .pledged => output_capacity,
    };
    progress.* = .{};
    while (true) {
        const input = wire[progress.read..][0..@min(input_chunk, wire.len - progress.read)];
        var storage: [output_capacity + 16]u8 = @splat(canary);
        const offered = if (exercise_empty_output and progress.calls % 7 == 0) 0 else output_chunk;
        progress.calls += 1;
        progress.empty_output_calls += @intFromBool(offered == 0);
        const step = decoder.step(input, storage[0..offered]) catch |err| {
            progress.error_phase = decoder.diagnostics().last_error_phase_name;
            try commit(progress, try failedProgress(decoder, progress.*), input.len, offered, &storage, plain);
            if (outcome == .truncated and err == error.TruncatedFrame) return;
            return err;
        };
        try commit(progress, step.progress, input.len, offered, &storage, plain);

        if (progress.read == wire.len and step.status != .need_output) break;
        // Zstd can report .done at an intermediate frame boundary while the
        // caller still has the next frame. It can resume with fresh input.
        if (step.progress.input_read == 0 and step.progress.output_written == 0 and
            !(offered == 0 and step.status == .need_output)) return error.Stalled;
    }
    decoder.finish() catch |err| {
        if (outcome == .truncated and err == error.TruncatedFrame) return;
        return err;
    };
    if (outcome == .truncated) return error.UnexpectedCompleteInput;
    if (progress.written != plain.len) return error.ShortOutput;
}

pub fn check(
    allocator: std.mem.Allocator,
    codec: anytype,
    case: anytype,
    schedule: Schedule,
    outcome: Outcome,
    progress: *Progress,
) !void {
    const exact: ?vort.StreamCount = if (schedule == .pledged) case.source.len else null;
    switch (codec) {
        .raw => {
            const Decoder = vort.deflate.RawDeflateIncrementalFixedLiteralDecoder;
            var history: [32 * 1024]u8 = undefined;
            var decoder = try Decoder.initWithDictionary(.{ .expected_output_len = exact }, &history, case.dictionary orelse "");
            try drive(&decoder, case.wire, case.source, schedule, case.upstream_real, outcome, progress);
        },
        .zlib => {
            const Decoder = vort.deflate.ZlibIncrementalDecoder;
            var history: [32 * 1024]u8 = undefined;
            const options: Decoder.Options = .{ .expected_output_len = exact };
            var decoder = if (case.dictionary) |dictionary|
                try Decoder.initWithDictionary(options, &history, dictionary)
            else
                try Decoder.init(options, &history);
            try drive(&decoder, case.wire, case.source, schedule, case.upstream_real, outcome, progress);
        },
        .gzip => {
            const Decoder = vort.deflate.GzipIncrementalDecoder;
            var history: [32 * 1024]u8 = undefined;
            var decoder = try Decoder.init(.{ .expected_output_len = exact, .allow_concatenated = case.gzip_multi_member }, &history);
            try drive(&decoder, case.wire, case.source, schedule, case.upstream_real, outcome, progress);
        },
        .zstd => {
            const Decoder = vort.zstd.NativeIncrementalFrameDecoder;
            const options: Decoder.Options = .{
                .expected_output_len = exact,
                .format = if (case.zstd_magicless) .magicless else .standard,
                .input_policy = if (schedule == .pledged) .prevalidated_frame else .block_stream,
            };
            const dictionary: ?vort.zstd.NativeDictionary = if (case.standard_dictionary_bytes) |bytes|
                (try vort.zstd.NativeDictionary.initFromStandardDictionary(bytes)).dictionary
            else if (case.dictionary) |bytes|
                vort.zstd.NativeDictionary.initRawContent(bytes)
            else
                null;
            var decoder = if (dictionary) |dict|
                Decoder.initWithDictionaryAndOptions(allocator, dict, options)
            else
                Decoder.initWithOptions(allocator, options);
            defer decoder.deinit();
            try drive(&decoder, case.wire, case.source, schedule, case.upstream_real, outcome, progress);
        },
        .br => {
            const Decoder = vort.br.IncrementalStreamDecoder;
            const prefixes = [_][]const u8{case.dictionary orelse ""};
            var parsed: vort.br.SerializedSharedDictionary = undefined;
            var dictionary: vort.br.SharedDictionary = .{};
            if (case.brotli_shared_dictionary) dictionary.raw_prefixes = &prefixes;
            if (case.brotli_serialized_dictionary) {
                parsed = try vort.br.parseSerializedSharedDictionary(case.serialized_dictionary_bytes.?);
                dictionary.serialized = &parsed;
            }
            var decoder = Decoder.initWithOptions(allocator, .{
                .expected_output_len = exact,
                .decode = .{ .allow_large_window = case.brotli_large_window, .shared_dictionary = dictionary },
            });
            defer decoder.deinit();
            try drive(&decoder, case.wire, case.source, schedule, case.upstream_real, outcome, progress);
        },
    }
}
