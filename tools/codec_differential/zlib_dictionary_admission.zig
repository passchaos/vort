//! Verify recoverable FDICT admission on a complete upstream zlib stream.
const std = @import("std");
const vort = @import("vort");

const Decoder = vort.ZlibIncrementalDecoder;
const header_bytes = 6; // CMF/FLG followed by the big-endian DICTID.
const input_chunk = 17;
const output_chunk = 31;
const guard_len = 8;
const canary: u8 = 0xa5;

const Schedule = enum { bytewise, whole };
const ScheduleReceipt = struct {
    initial_input: Schedule,
    pause_input_read: vort.StreamCount,
    pause_step_input_read: usize,
    pause_output_written: vort.StreamCount,
    requested_dictionary_id: u32,
    request_after_mismatch: u32,
    resumed_input_read: usize,
    resumed_output_written: usize,
    resume_calls: usize,
};

pub const Receipt = struct {
    wire_dictionary_id: u32,
    wrong_dictionary_id: u32,
    schedules: [2]ScheduleReceipt,
};

pub fn verify(wire: []const u8, plain: []const u8, dictionary: []const u8, wrong: []const u8) !Receipt {
    if (wire.len <= header_bytes or wire[1] & 0x20 == 0) return error.MissingZlibFdict;
    const wire_id = std.mem.readInt(u32, wire[2..header_bytes], .big);
    const wrong_id = vort.Adler32.hash(wrong);
    if (wrong_id == wire_id) return error.NonDistinctZlibDictionaryIds;

    return .{
        .wire_dictionary_id = wire_id,
        .wrong_dictionary_id = wrong_id,
        .schedules = .{
            try verifySchedule(wire, plain, dictionary, wrong, wire_id, .bytewise),
            try verifySchedule(wire, plain, dictionary, wrong, wire_id, .whole),
        },
    };
}

fn verifySchedule(wire: []const u8, plain: []const u8, dictionary: []const u8, wrong: []const u8, wire_id: u32, schedule: Schedule) !ScheduleReceipt {
    var history: [32 * 1024]u8 = undefined;
    var decoder = try Decoder.init(.{}, &history);
    var storage: [guard_len + output_chunk + guard_len]u8 = @splat(canary);
    const output = storage[guard_len..][0..output_chunk];

    var read: usize = 0;
    if (schedule == .bytewise) {
        while (read < header_bytes - 1) {
            const step = try decoder.step(wire[read..][0..1], output);
            try checkOutput(&storage, "");
            if (step.status != .need_input or step.progress.input_read != 1 or
                step.progress.output_written != 0 or decoder.requiredDictionaryId() != null)
                return error.InvalidZlibDictionaryPrefixProgress;
            read += step.progress.input_read;
        }
    }

    const initial = if (schedule == .bytewise) wire[read..][0..1] else wire;
    if (decoder.step(initial, output)) |_| return error.MissingZlibDictionaryPause else |err| {
        if (err != error.NeedDictionary) return err;
    }
    try checkOutput(&storage, "");
    const pause = decoder.snapshot();
    if (pause.last_step_progress.input_read != header_bytes - read or pause.last_step_progress.output_written != 0 or
        pause.total_input != header_bytes or pause.total_output != 0)
        return error.InvalidZlibDictionaryPauseProgress;
    read += pause.last_step_progress.input_read;
    const request = decoder.requiredDictionaryId() orelse return error.MissingZlibDictionaryId;
    if (request != wire_id) return error.UnexpectedZlibDictionaryId;

    if (decoder.provideDictionary(wrong)) |_| return error.AcceptedWrongZlibDictionary else |err| {
        if (err != error.DictionaryMismatch) return err;
    }
    const retained = decoder.requiredDictionaryId() orelse return error.LostZlibDictionaryRequest;
    if (retained != request) return error.LostZlibDictionaryRequest;
    const mismatch = decoder.snapshot();
    if (mismatch.total_input != pause.total_input or mismatch.total_output != pause.total_output)
        return error.InvalidZlibDictionaryPauseProgress;
    try decoder.provideDictionary(dictionary);
    if (decoder.requiredDictionaryId() != null) return error.UnresolvedZlibDictionaryRequest;

    // In the whole-input schedule this is the portion of the first offer
    // that the decoder declined to consume while it waited for the dictionary.
    const suffix = wire[read..];
    var resumed_read: usize = 0;
    var written: usize = 0;
    var calls: usize = 0;
    while (true) {
        const remaining = suffix[resumed_read..];
        const input = remaining[0..@min(input_chunk, remaining.len)];
        @memset(&storage, canary);
        const step = try decoder.step(input, output);
        const progress = step.progress;
        if (progress.input_read > input.len or progress.output_written > output.len or progress.output_written > plain.len - written)
            return error.InvalidZlibDictionaryResumeProgress;
        try checkOutput(&storage, plain[written..][0..progress.output_written]);
        resumed_read += progress.input_read;
        written += progress.output_written;
        calls += 1;

        if (step.status == .done) break;
        if (progress.input_read == 0 and progress.output_written == 0) return error.StalledZlibDictionaryResume;
    }
    if (resumed_read != suffix.len or written != plain.len) return error.IncompleteZlibDictionaryResume;
    try decoder.finish();
    const finished = decoder.snapshot();
    if (finished.total_input != wire.len or finished.total_output != plain.len or finished.stream_count != 1)
        return error.IncompleteZlibDictionaryResume;

    return .{
        .initial_input = schedule,
        .pause_input_read = pause.total_input,
        .pause_step_input_read = pause.last_step_progress.input_read,
        .pause_output_written = pause.total_output,
        .requested_dictionary_id = request,
        .request_after_mismatch = retained,
        .resumed_input_read = resumed_read,
        .resumed_output_written = written,
        .resume_calls = calls,
    };
}

fn checkOutput(storage: []const u8, expected: []const u8) !void {
    const end = guard_len + expected.len;
    if (!std.mem.allEqual(u8, storage[0..guard_len], canary) or !std.mem.allEqual(u8, storage[end..], canary))
        return error.ZlibDictionaryOutputCanaryChanged;
    if (!std.mem.eql(u8, storage[guard_len..end], expected)) return error.ZlibDictionaryPlaintextMismatch;
}
