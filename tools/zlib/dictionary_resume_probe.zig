const std = @import("std");
const vort = @import("vort");
const Decoder = vort.ZlibIncrementalDecoder;

const Config = struct {
    pattern: []const u8 = "micro",
    initializer: []const u8 = "missing",
    dictionary_paths: []const []const u8,
    allow_concatenated: bool = false,
    max_output_len: usize = std.math.maxInt(usize),
    expected_output_len: ?usize = null,
    finish_on_need: bool = false,
    reset_after: bool = false,
    expected_error: ?[]const u8 = null,
};
const Request = struct {
    id: u32,
    input_offset: usize,
    output_offset: usize,
    stream_index: usize,
    error_input_progress: usize,
    error_output_progress: usize,
    last_error_input_offset: ?usize,
    last_error_output_offset: ?usize,
    wrong_dictionary_attempts: usize = 0,
    finish_error: ?[]const u8 = null,
};
const Report = struct {
    input_read: usize = 0,
    output_written: usize = 0,
    steps: usize = 0,
    zero_output_steps: usize = 0,
    zero_input_steps: usize = 0,
    requests: std.ArrayList(Request) = .empty,
    @"error": ?[]const u8 = null,
    error_input_progress: usize = 0,
    error_output_progress: usize = 0,
    reset_checks: usize = 0,
    snapshot: ?std.json.Value = null,
    diagnostics: ?std.json.Value = null,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const source_path = args.next() orelse return error.MissingInput;
    const expected_path = args.next() orelse return error.MissingExpected;
    const output_path = args.next() orelse return error.MissingOutput;
    const config_path = args.next() orelse return error.MissingConfig;
    if (args.next() != null) return error.TooManyArguments;
    const encoded = try read(init, source_path, 64 * 1024 * 1024);
    defer init.gpa.free(encoded);
    const expected = try read(init, expected_path, 64 * 1024 * 1024);
    defer init.gpa.free(expected);
    const configuration = try read(init, config_path, 16384);
    defer init.gpa.free(configuration);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, configuration, .{});
    defer parsed.deinit();
    const config = parsed.value;
    const dictionaries = try init.gpa.alloc([]u8, config.dictionary_paths.len);
    defer init.gpa.free(dictionaries);
    var loaded: usize = 0;
    defer for (dictionaries[0..loaded]) |dictionary| init.gpa.free(dictionary);
    for (config.dictionary_paths, dictionaries) |path, *dictionary| {
        dictionary.* = try read(init, path, 4 * 1024 * 1024);
        loaded += 1;
    }
    const entries = try init.gpa.alloc(vort.ZlibDictionaryEntry, dictionaries.len);
    defer init.gpa.free(entries);
    for (entries, dictionaries) |*entry, dictionary| entry.* = vort.ZlibDictionarySet.entry(dictionary);
    const options: Decoder.Options = .{ .allow_concatenated = config.allow_concatenated, .max_output_len = config.max_output_len, .expected_output_len = config.expected_output_len };
    var history: [32768]u8 = undefined;
    const miss_entries = [_]vort.ZlibDictionaryEntry{vort.ZlibDictionarySet.entry("unrelated dictionary set entry")};
    var decoder = if (std.mem.eql(u8, config.initializer, "set-miss"))
        try Decoder.initWithDictionarySet(options, &history, vort.ZlibDictionarySet.fromEntries(&miss_entries))
    else if (std.mem.eql(u8, config.initializer, "set-hit"))
        try Decoder.initWithDictionarySet(options, &history, vort.ZlibDictionarySet.fromEntries(entries))
    else if (std.mem.eql(u8, config.initializer, "correct"))
        try Decoder.initWithDictionary(options, &history, dictionaries[0])
    else if (std.mem.eql(u8, config.initializer, "wrong"))
        try Decoder.initWithDictionary(options, &history, "initial wrong dictionary")
    else
        try Decoder.init(options, &history);
    if (decoder.requiredDictionaryId() != null) return error.PrematureDictionaryId;
    if (decoder.provideDictionary(dictionaries[0])) |_| return error.UnexpectedInitialDictionaryProvide else |err| {
        if (err != error.InvalidStreamState) return err;
    }
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(init.gpa);
    var report = try decode(init.gpa, &decoder, encoded, expected, dictionaries, config, &actual);
    defer report.requests.deinit(init.gpa);
    if (config.expected_error) |name| {
        if (report.@"error" == null or !std.mem.eql(u8, report.@"error".?, name)) return error.UnexpectedError;
    } else if (report.@"error" != null or !std.mem.eql(u8, actual.items, expected)) return error.DecodeMismatch;
    if (config.reset_after) {
        decoder.reset();
        const reset = decoder.snapshot();
        if (reset.total_input != 0 or reset.total_output != 0 or reset.stream_count != 0 or decoder.requiredDictionaryId() != null)
            return error.ResetStateMismatch;
        var replay: std.ArrayList(u8) = .empty;
        defer replay.deinit(init.gpa);
        var replay_report = try decode(init.gpa, &decoder, encoded, expected, dictionaries, config, &replay);
        defer replay_report.requests.deinit(init.gpa);
        if (!std.mem.eql(u8, actual.items, replay.items)) return error.ResetOutputMismatch;
        report.reset_checks = 1;
    }
    const snapshot_json = try std.json.Stringify.valueAlloc(init.gpa, decoder.snapshot(), .{});
    defer init.gpa.free(snapshot_json);
    const snapshot = try std.json.parseFromSlice(std.json.Value, init.gpa, snapshot_json, .{});
    defer snapshot.deinit();
    report.snapshot = snapshot.value;
    const diagnostics_json = try std.json.Stringify.valueAlloc(init.gpa, decoder.diagnostics(), .{});
    defer init.gpa.free(diagnostics_json);
    const diagnostics = try std.json.parseFromSlice(std.json.Value, init.gpa, diagnostics_json, .{});
    defer diagnostics.deinit();
    report.diagnostics = diagnostics.value;
    // ArrayList ownership is retained in the probe. Serialize its items only.
    const json = try std.json.Stringify.valueAlloc(init.gpa, .{
        .input_read = report.input_read,
        .output_written = report.output_written,
        .steps = report.steps,
        .zero_output_steps = report.zero_output_steps,
        .zero_input_steps = report.zero_input_steps,
        .requests = report.requests.items,
        .@"error" = report.@"error",
        .error_input_progress = report.error_input_progress,
        .error_output_progress = report.error_output_progress,
        .reset_checks = report.reset_checks,
        .snapshot = report.snapshot,
        .diagnostics = report.diagnostics,
    }, .{});
    defer init.gpa.free(json);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = actual.items });
    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    try stdout.interface.writeAll(json);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}

fn read(init: std.process.Init, path: []const u8, limit: usize) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(limit));
}

fn publish(allocator: std.mem.Allocator, actual: *std.ArrayList(u8), expected: []const u8, produced: []const u8) !void {
    if (actual.items.len > expected.len or produced.len > expected.len - actual.items.len or
        !std.mem.eql(u8, produced, expected[actual.items.len..][0..produced.len])) return error.InvalidOutputPrefix;
    try actual.appendSlice(allocator, produced);
}

fn decode(allocator: std.mem.Allocator, decoder: *Decoder, encoded: []const u8, expected: []const u8, dictionaries: []const []u8, config: Config, actual: *std.ArrayList(u8)) !Report {
    var report = Report{};
    errdefer report.requests.deinit(allocator);
    const micro_input = [_]usize{ 1, 0, 2, 3, 0, 17, 64 };
    const micro_output = [_]usize{ 0, 1, 0, 7, 31, 64, 4096 };
    var guard: [4112]u8 = undefined;
    while (report.steps < encoded.len * 8 + expected.len * 8 + 10000) {
        const input_len: usize = if (std.mem.eql(u8, config.pattern, "one")) 1 else if (std.mem.eql(u8, config.pattern, "full")) encoded.len else micro_input[report.steps % micro_input.len];
        const output_len: usize = if (std.mem.eql(u8, config.pattern, "one")) 1 else if (std.mem.eql(u8, config.pattern, "full")) 4096 else micro_output[report.steps % micro_output.len];
        const end = report.input_read + @min(encoded.len - report.input_read, input_len);
        @memset(&guard, 0xa5);
        const output = guard[8 .. 8 + output_len];
        const before = decoder.snapshot();
        report.steps += 1;
        report.zero_input_steps += @intFromBool(end == report.input_read);
        report.zero_output_steps += @intFromBool(output.len == 0);
        const stepped = decoder.step(encoded[report.input_read..end], output) catch |err| {
            const after = decoder.snapshot();
            if (after.total_input < before.total_input or after.total_output < before.total_output) return error.InvalidErrorProgress;
            const input_progress = after.total_input - before.total_input;
            const output_progress = after.total_output - before.total_output;
            if (input_progress > end - report.input_read or output_progress > output.len or
                after.last_step_progress.input_read != input_progress or after.last_step_progress.output_written != output_progress)
                return error.InvalidErrorProgress;
            report.input_read += input_progress;
            try publish(allocator, actual, expected, output[0..output_progress]);
            report.output_written = actual.items.len;
            try checkGuard(&guard, output_len);
            if (after.last_error_input_offset != after.total_input or after.last_error_output_offset != after.total_output)
                return error.InvalidErrorOffset;
            if (err == error.NeedDictionary) {
                const id = decoder.requiredDictionaryId() orelse return error.MissingDictionaryId;
                if (after.dictid_received != 4) return error.PrematureDictionaryId;
                var request = Request{
                    .id = id,
                    .input_offset = report.input_read,
                    .output_offset = report.output_written,
                    .stream_index = after.stream_index,
                    .error_input_progress = input_progress,
                    .error_output_progress = output_progress,
                    .last_error_input_offset = after.last_error_input_offset,
                    .last_error_output_offset = after.last_error_output_offset,
                };
                var retry_output: [8]u8 = @splat(0xa5);
                if (decoder.step("", &retry_output)) |_| return error.UnexpectedDictionaryWaitSuccess else |wait_error| {
                    if (wait_error != error.NeedDictionary) return wait_error;
                }
                const waited = decoder.snapshot();
                if (waited.total_input != after.total_input or waited.total_output != after.total_output or
                    waited.last_step_progress.input_read != 0 or waited.last_step_progress.output_written != 0)
                    return error.DictionaryWaitProgress;
                for (retry_output) |byte| if (byte != 0xa5) return error.DictionaryWaitOutputModified;
                var found: ?[]const u8 = null;
                for (dictionaries) |dictionary| if (vort.ZlibDictionarySet.entry(dictionary).id == id) {
                    found = dictionary;
                    break;
                };
                const correct_dictionary = found orelse return error.DictionaryUnavailable;
                for ([_][]const u8{ "", "incorrect dictionary" }) |wrong| {
                    if (decoder.provideDictionary(wrong)) |_| return error.UnexpectedWrongDictionarySuccess else |wrong_error| {
                        if (wrong_error != error.DictionaryMismatch) return wrong_error;
                    }
                    request.wrong_dictionary_attempts += 1;
                    const rejected = decoder.snapshot();
                    if (decoder.requiredDictionaryId() != id or rejected.total_input != after.total_input or
                        rejected.total_output != after.total_output) return error.WrongDictionaryStateModified;
                }
                if (correct_dictionary.len > 32768) {
                    const suffix = correct_dictionary[correct_dictionary.len - 32768 ..];
                    if (vort.ZlibDictionarySet.entry(suffix).id != id) {
                        if (decoder.provideDictionary(suffix)) |_| return error.UnexpectedSuffixDictionarySuccess else |wrong_error| {
                            if (wrong_error != error.DictionaryMismatch) return wrong_error;
                        }
                        request.wrong_dictionary_attempts += 1;
                        if (decoder.requiredDictionaryId() != id or decoder.snapshot().total_input != after.total_input or
                            decoder.snapshot().total_output != after.total_output) return error.WrongDictionaryStateModified;
                    }
                }
                if (config.finish_on_need) {
                    decoder.finish() catch |finish_error| {
                        request.finish_error = @errorName(finish_error);
                    };
                }
                const transient = try allocator.dupe(u8, correct_dictionary);
                decoder.provideDictionary(transient) catch |provide_error| {
                    allocator.free(transient);
                    return provide_error;
                };
                @memset(transient, 0x3f);
                allocator.free(transient);
                if (decoder.requiredDictionaryId() != null or decoder.snapshot().last_error_name.len != 0)
                    return error.DictionaryRecoveryState;
                try report.requests.append(allocator, request);
                continue;
            }
            report.@"error" = @errorName(err);
            report.error_input_progress = input_progress;
            report.error_output_progress = output_progress;
            return report;
        };
        if (stepped.progress.input_read > end - report.input_read or stepped.progress.output_written > output.len)
            return error.InvalidProgress;
        const after = decoder.snapshot();
        if (after.total_input - before.total_input != stepped.progress.input_read or
            after.total_output - before.total_output != stepped.progress.output_written or
            after.last_step_progress.input_read != stepped.progress.input_read or
            after.last_step_progress.output_written != stepped.progress.output_written) return error.InvalidProgress;
        report.input_read += stepped.progress.input_read;
        try publish(allocator, actual, expected, output[0..stepped.progress.output_written]);
        report.output_written = actual.items.len;
        try checkGuard(&guard, output_len);
        if (stepped.status == .done) {
            if (report.input_read != encoded.len) return error.UnconsumedInput;
            try decoder.finish();
            return report;
        }
        if (report.input_read == encoded.len and stepped.progress.input_read == 0 and stepped.progress.output_written == 0 and stepped.status == .need_input) {
            decoder.finish() catch |err| {
                report.@"error" = @errorName(err);
                return report;
            };
            if (decoder.snapshot().done) return report;
            return error.StreamDidNotFinish;
        }
    }
    return error.StreamDidNotFinish;
}

fn checkGuard(guard: *const [4112]u8, output_len: usize) !void {
    for (guard[0..8]) |byte| if (byte != 0xa5) return error.CallerPrefixModified;
    for (guard[8 + output_len ..]) |byte| if (byte != 0xa5) return error.CallerSuffixModified;
}
