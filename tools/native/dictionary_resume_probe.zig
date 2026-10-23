const std = @import("std");
const codec = @import("codec");
const Decoder = codec.NativeIncrementalFrameDecoder;
const Dictionary = codec.NativeDictionary;
const Set = codec.NativeDictionarySet;

const DictionaryConfig = struct { id: u32, path: []const u8, full: bool = false };
const Config = struct {
    pattern: []const u8 = "mixed",
    policy: []const u8 = "block_stream",
    initializer: []const u8 = "missing",
    dictionaries: []const DictionaryConfig,
    provide_set: bool = false,
    stop_next: bool = false,
    bad_metadata: bool = false,
    reset_after: bool = false,
    check_limits: bool = false,
    oom: bool = false,
    max_output_len: usize = std.math.maxInt(usize),
    max_working_memory: usize = std.math.maxInt(usize),
    expected_error: ?[]const u8 = null,
};
const Request = struct {
    id: u32,
    input_offset: usize,
    output_offset: usize,
    input_progress: usize,
    output_progress: usize,
    wrong_id_checks: usize = 0,
    metadata_rejections: usize = 0,
    provided_via_set: bool = false,
    finish_error: ?[]const u8 = null,
    set_miss_error: ?[]const u8 = null,
};
const Report = struct {
    input_received: usize = 0,
    output_written: usize = 0,
    steps: usize = 0,
    zero_output_steps: usize = 0,
    zero_input_steps: usize = 0,
    requests: std.ArrayList(Request) = .empty,
    @"error": ?[]const u8 = null,
    error_input_progress: usize = 0,
    error_output_progress: usize = 0,
    peak_working_bytes: usize = 0,
    next_stream_calls: usize = 0,
    reset_checks: usize = 0,
    resource_checks: usize = 0,
    oom_failures: usize = 0,
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
    const encoded = try read(init, source_path);
    defer init.gpa.free(encoded);
    const expected = try read(init, expected_path);
    defer init.gpa.free(expected);
    const configuration = try read(init, config_path);
    defer init.gpa.free(configuration);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, configuration, .{});
    defer parsed.deinit();
    const config = parsed.value;
    const dictionaries = try init.gpa.alloc(Dictionary, config.dictionaries.len);
    defer init.gpa.free(dictionaries);
    const bytes = try init.gpa.alloc([]u8, dictionaries.len);
    defer init.gpa.free(bytes);
    var loaded: usize = 0;
    defer for (bytes[0..loaded]) |dictionary| init.gpa.free(dictionary);
    for (config.dictionaries, bytes, dictionaries) |definition, *data, *dictionary| {
        data.* = try read(init, definition.path);
        loaded += 1;
        if (@hasDecl(Dictionary, "initFromStandardDictionary")) {
            dictionary.* = if (definition.full) (try Dictionary.initFromStandardDictionary(data.*)).dictionary else Dictionary.init(definition.id, data.*);
        } else dictionary.* = Dictionary.init(definition.id, data.*);
        if (dictionary.id != definition.id) return error.DictionaryIdMismatch;
    }
    var tracker = std.testing.FailingAllocator.init(init.gpa, .{});
    var decoder = initialize(tracker.allocator(), dictionaries, config);
    defer decoder.deinit();
    if (decoder.requiredDictionaryId() != null) return error.PrematureDictionaryId;
    if (decoder.provideDictionary(dictionaries[0])) |_| return error.UnexpectedInitialProvide else |err| {
        if (err != error.InvalidStreamState) return err;
    }
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(init.gpa);
    var report = try decode(init.gpa, &tracker, &decoder, encoded, expected, dictionaries, config, &actual);
    defer report.requests.deinit(init.gpa);
    if (config.expected_error) |name| {
        if (report.@"error" == null or !std.mem.eql(u8, report.@"error".?, name)) return error.UnexpectedError;
    } else if (report.@"error" != null or !std.mem.eql(u8, actual.items, expected)) return error.DecodeMismatch;
    if (config.reset_after) {
        decoder.reset();
        if (decoder.snapshot().input_received != 0 or decoder.snapshot().output_written != 0 or decoder.requiredDictionaryId() != null)
            return error.ResetStateMismatch;
        var replay: std.ArrayList(u8) = .empty;
        defer replay.deinit(init.gpa);
        var retry = try decode(init.gpa, &tracker, &decoder, encoded, expected, dictionaries, config, &replay);
        defer retry.requests.deinit(init.gpa);
        if (retry.@"error" != null or !std.mem.eql(u8, replay.items, expected)) return error.ResetMismatch;
        report.reset_checks = 1;
    }
    if (config.check_limits) report.resource_checks = try checkLimits(init.gpa, encoded, expected, dictionaries, config, report.peak_working_bytes);
    if (config.oom) report.oom_failures = try checkOom(init.gpa, encoded, expected, dictionaries, config);
    const snapshot_json = try std.json.Stringify.valueAlloc(init.gpa, decoder.snapshot(), .{});
    defer init.gpa.free(snapshot_json);
    const snapshot = try std.json.parseFromSlice(std.json.Value, init.gpa, snapshot_json, .{});
    defer snapshot.deinit();
    const json = try std.json.Stringify.valueAlloc(init.gpa, .{
        .input_received = report.input_received,
        .output_written = report.output_written,
        .steps = report.steps,
        .zero_input_steps = report.zero_input_steps,
        .zero_output_steps = report.zero_output_steps,
        .requests = report.requests.items,
        .@"error" = report.@"error",
        .error_input_progress = report.error_input_progress,
        .error_output_progress = report.error_output_progress,
        .peak_working_bytes = report.peak_working_bytes,
        .next_stream_calls = report.next_stream_calls,
        .reset_checks = report.reset_checks,
        .resource_checks = report.resource_checks,
        .oom_failures = report.oom_failures,
        .snapshot = snapshot.value,
    }, .{});
    defer init.gpa.free(json);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = actual.items });
    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    try stdout.interface.writeAll(json);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}

fn read(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(64 * 1024 * 1024));
}
fn options(config: Config) Decoder.Options {
    return .{ .input_policy = if (std.mem.eql(u8, config.policy, "prevalidated_frame")) .prevalidated_frame else .block_stream, .max_output_len = config.max_output_len, .max_working_memory = config.max_working_memory, .stop_after_first_frame = config.stop_next };
}
fn initialize(allocator: std.mem.Allocator, dictionaries: []const Dictionary, config: Config) Decoder {
    if (std.mem.eql(u8, config.initializer, "correct")) return Decoder.initWithDictionaryAndOptions(allocator, dictionaries[0], options(config));
    if (std.mem.eql(u8, config.initializer, "set-hit")) return Decoder.initWithDictionarySetAndOptions(allocator, Set.init(dictionaries), options(config));
    if (std.mem.eql(u8, config.initializer, "set-miss")) return Decoder.initWithDictionarySetAndOptions(allocator, Set.init(&.{}), options(config));
    if (std.mem.eql(u8, config.initializer, "wrong")) {
        const wrong = Dictionary.init(dictionaries[0].id ^ 1, dictionaries[0].content);
        return Decoder.initWithDictionaryAndOptions(allocator, wrong, options(config));
    }
    return Decoder.initWithOptions(allocator, options(config));
}
fn publish(allocator: std.mem.Allocator, actual: *std.ArrayList(u8), expected: []const u8, output: []const u8) !void {
    if (actual.items.len > expected.len or output.len > expected.len - actual.items.len or
        !std.mem.eql(u8, output, expected[actual.items.len..][0..output.len])) return error.InvalidPublishedPrefix;
    try actual.appendSlice(allocator, output);
}

fn decode(allocator: std.mem.Allocator, tracker: *std.testing.FailingAllocator, decoder: *Decoder, encoded: []const u8, expected: []const u8, dictionaries: []const Dictionary, config: Config, actual: *std.ArrayList(u8)) !Report {
    var report = Report{};
    errdefer report.requests.deinit(allocator);
    var guard: [4112]u8 = undefined;
    const input_sizes = [_]usize{ 1, 0, 2, 3, 0, 31, 4096 };
    const output_sizes = [_]usize{ 0, 1, 0, 7, 31, 64, 4096 };
    while (report.steps < encoded.len * 8 + expected.len * 8 + 10000) {
        const in_len: usize = if (std.mem.eql(u8, config.pattern, "one")) 1 else if (std.mem.eql(u8, config.pattern, "full")) encoded.len else input_sizes[report.steps % input_sizes.len];
        const out_len: usize = if (std.mem.eql(u8, config.pattern, "one")) 1 else if (std.mem.eql(u8, config.pattern, "full")) 4096 else output_sizes[report.steps % output_sizes.len];
        const end = report.input_received + @min(encoded.len - report.input_received, in_len);
        @memset(&guard, 0xa5);
        const output = guard[8 .. 8 + out_len];
        const before = decoder.snapshot();
        report.steps += 1;
        report.zero_input_steps += @intFromBool(end == report.input_received);
        report.zero_output_steps += @intFromBool(out_len == 0);
        const result = decoder.step(encoded[report.input_received..end], output) catch |err| {
            const after = decoder.snapshot();
            const input_progress = after.input_received - before.input_received;
            const output_progress = after.output_written - before.output_written;
            if (input_progress > end - report.input_received or output_progress > output.len or
                after.last_step_progress.input_read != input_progress or after.last_step_progress.output_written != output_progress)
                return error.InvalidErrorProgress;
            report.input_received += input_progress;
            try publish(allocator, actual, expected, output[0..output_progress]);
            report.output_written = actual.items.len;
            report.peak_working_bytes = @max(report.peak_working_bytes, after.peak_working_bytes);
            if (after.error_input_offset != after.input_received or after.error_output_offset != after.output_written)
                return error.InvalidErrorOffset;
            if (err == error.NeedDictionary) {
                const id = decoder.requiredDictionaryId() orelse return error.MissingDictionaryId;
                var request = Request{ .id = id, .input_offset = report.input_received, .output_offset = report.output_written, .input_progress = input_progress, .output_progress = output_progress };
                var retry_guard: [8]u8 = @splat(0xa5);
                if (decoder.step("retry", &retry_guard)) |_| return error.UnexpectedWaitSuccess else |wait_error| {
                    if (wait_error != error.NeedDictionary) return wait_error;
                }
                const waited = decoder.snapshot();
                if (waited.input_received != after.input_received or waited.output_written != after.output_written or
                    waited.last_step_progress.input_read != 0 or waited.last_step_progress.output_written != 0)
                    return error.DictionaryWaitProgress;
                for (retry_guard) |byte| if (byte != 0xa5) return error.DictionaryWaitOutputModified;
                var selected: ?Dictionary = null;
                for (dictionaries) |dictionary| if (dictionary.id == id) {
                    selected = dictionary;
                    break;
                };
                const dictionary = selected orelse return error.DictionaryUnavailable;
                const wrong = Dictionary.init(dictionary.id ^ 1, dictionary.content);
                const saved_failure_index = tracker.fail_index;
                const saved_failure_flag = tracker.has_induced_failure;
                tracker.has_induced_failure = false;
                tracker.fail_index = tracker.alloc_index;
                if (decoder.provideDictionary(wrong)) |_| return error.WrongDictionaryAccepted else |wrong_error| {
                    if (wrong_error != error.DictionaryMismatch) return wrong_error;
                }
                request.wrong_id_checks += 1;
                if (decoder.provideDictionarySet(Set.init(&.{wrong}))) |_| return error.WrongSetAccepted else |wrong_error| {
                    if (wrong_error != error.NeedDictionary) return wrong_error;
                    request.set_miss_error = @errorName(wrong_error);
                }
                request.wrong_id_checks += 1;
                if (tracker.has_induced_failure) return error.WrongIdAllocated;
                tracker.fail_index = saved_failure_index;
                tracker.has_induced_failure = saved_failure_flag;
                if (decoder.requiredDictionaryId() != id or decoder.snapshot().input_received != after.input_received or
                    decoder.snapshot().output_written != after.output_written) return error.WrongDictionaryStateModified;
                decoder.finish() catch |finish_error| {
                    request.finish_error = @errorName(finish_error);
                };
                if (@hasField(Dictionary, "standard_bytes")) {
                    if (config.bad_metadata and dictionary.standard_bytes != null) {
                        const corrupt = try allocator.dupe(u8, dictionary.standard_bytes.?);
                        defer allocator.free(corrupt);
                        corrupt[4] ^= 1;
                        var malformed = dictionary;
                        malformed.standard_bytes = corrupt;
                        if (decoder.provideDictionary(malformed)) |_| return error.BadMetadataAccepted else |metadata_error| {
                            if (metadata_error != error.InvalidDictionaryMetadata) return metadata_error;
                        }
                        request.metadata_rejections += 1;
                        if (decoder.requiredDictionaryId() != id) return error.MetadataRequestLost;
                    }
                }
                if (config.provide_set) {
                    const temporary_set = try allocator.alloc(Dictionary, 1);
                    temporary_set[0] = dictionary;
                    try decoder.provideDictionarySet(Set.init(temporary_set));
                    temporary_set[0] = wrong;
                    allocator.free(temporary_set);
                    request.provided_via_set = true;
                } else try decoder.provideDictionary(dictionary);
                if (decoder.requiredDictionaryId() != null) return error.DictionaryRequestNotCleared;
                try report.requests.append(allocator, request);
                continue;
            }
            report.@"error" = @errorName(err);
            report.error_input_progress = input_progress;
            report.error_output_progress = output_progress;
            var retry_guard: [8]u8 = @splat(0xa5);
            if (decoder.step("retry", &retry_guard)) |_| return error.UnexpectedErrorRetry else |retry_error| {
                if (retry_error != err) return error.UnexpectedErrorRetry;
            }
            if (decoder.snapshot().last_step_progress.input_read != 0 or decoder.snapshot().last_step_progress.output_written != 0)
                return error.ErrorRetryProgress;
            if (decoder.snapshot().input_received != after.input_received or decoder.snapshot().output_written != after.output_written)
                return error.ErrorRetryProgress;
            for (retry_guard) |byte| if (byte != 0xa5) return error.ErrorRetryOutputModified;
            return report;
        };
        const after = decoder.snapshot();
        if (result.progress.input_read > end - report.input_received or result.progress.output_written > output.len or
            after.input_received - before.input_received != result.progress.input_read or
            after.output_written - before.output_written != result.progress.output_written or
            after.last_step_progress.input_read != result.progress.input_read or after.last_step_progress.output_written != result.progress.output_written)
            return error.InvalidProgress;
        report.input_received += result.progress.input_read;
        try publish(allocator, actual, expected, output[0..result.progress.output_written]);
        report.output_written = actual.items.len;
        report.peak_working_bytes = @max(report.peak_working_bytes, after.peak_working_bytes);
        for (guard[0..8]) |byte| if (byte != 0xa5) return error.CallerPrefixModified;
        for (guard[8 + out_len ..]) |byte| if (byte != 0xa5) return error.CallerSuffixModified;
        if (result.status == .done) {
            if (config.stop_next and (report.input_received != encoded.len or decoder.trailingInput().len != 0)) {
                try decoder.nextStream();
                report.next_stream_calls += 1;
                continue;
            }
            return report;
        }
        if (report.input_received == encoded.len and result.progress.input_read == 0 and result.progress.output_written == 0 and result.status == .need_input) {
            decoder.finish() catch |err| {
                report.@"error" = @errorName(err);
                return report;
            };
            if (decoder.snapshot().phase == .done) return report;
        }
    }
    return error.StreamDidNotFinish;
}

fn variant(backing: std.mem.Allocator, encoded: []const u8, expected: []const u8, dictionaries: []const Dictionary, config: Config, fail_index: usize) !Report {
    var tracker = std.testing.FailingAllocator.init(backing, .{ .fail_index = fail_index });
    var decoder = initialize(tracker.allocator(), dictionaries, config);
    defer decoder.deinit();
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(backing);
    return decode(backing, &tracker, &decoder, encoded, expected, dictionaries, config, &output);
}
fn checkLimits(backing: std.mem.Allocator, encoded: []const u8, expected: []const u8, dictionaries: []const Dictionary, config: Config, peak: usize) !usize {
    if (peak == 0) return error.MissingMemoryAccounting;
    for ([_]usize{ peak, peak - 1 }, 0..) |limit, index| {
        var constrained = config;
        constrained.max_working_memory = limit;
        var report = try variant(backing, encoded, expected, dictionaries, constrained, std.math.maxInt(usize));
        defer report.requests.deinit(backing);
        if (index == 0) {
            if (report.@"error" != null or report.output_written != expected.len) return error.ExactMemoryMismatch;
        } else if (report.@"error" == null or !std.mem.eql(u8, report.@"error".?, "WorkingMemoryLimitExceeded")) return error.MemoryLimitNotEnforced;
    }
    return 2;
}
fn checkOom(backing: std.mem.Allocator, encoded: []const u8, expected: []const u8, dictionaries: []const Dictionary, config: Config) !usize {
    for (0..1024) |failure_index| {
        var tracker = std.testing.FailingAllocator.init(backing, .{ .fail_index = failure_index });
        var decoder = initialize(tracker.allocator(), dictionaries, config);
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(backing);
        var report = try decode(backing, &tracker, &decoder, encoded, expected, dictionaries, config, &output);
        defer report.requests.deinit(backing);
        decoder.deinit();
        if (tracker.allocated_bytes != tracker.freed_bytes) return error.OomAllocationLeak;
        if (report.@"error") |name| {
            if (!std.mem.eql(u8, name, "OutOfMemory")) return error.UnexpectedOomError;
        } else if (report.output_written != expected.len) return error.OomOutputMismatch;
        if (!tracker.has_induced_failure) return failure_index;
    }
    return error.OomWalkLimit;
}
