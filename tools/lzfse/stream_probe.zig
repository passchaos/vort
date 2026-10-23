const std = @import("std");
const lzfse = @import("lzfse");

const Config = struct {
    mode: []const u8 = "decode",
    pattern: []const u8 = "micro",
    max_output_len: usize = std.math.maxInt(usize),
    max_history_len: usize = 262139,
    max_compressed_buffer_len: usize = 131072,
    max_working_memory: usize = std.math.maxInt(usize),
    expected_output_len: ?usize = null,
    stop_after_end_marker: bool = false,
    finish_before_input: bool = false,
    expected_error: ?[]const u8 = null,
};

const Result = struct {
    input_read: usize = 0,
    output_written: usize = 0,
    steps: usize = 0,
    zero_output_steps: usize = 0,
    zero_input_steps: usize = 0,
    output_before_end_marker: bool = false,
    first_output_input_offset: ?usize = null,
    max_buffered_input: usize = 0,
    max_retained_compressed_capacity: usize = 0,
    max_history_len: usize = 0,
    peak_working_bytes: usize = 0,
    payload_prefix_skipped: usize = 0,
    @"error": ?[]const u8 = null,
    error_partial_input: usize = 0,
    error_partial_output: usize = 0,
    streams: usize = 0,
    reset_checks: usize = 0,
    resource_checks: usize = 0,
    oom_failure_cases: usize = 0,
    diagnostics: ?std.json.Value = null,
    snapshot: ?std.json.Value = null,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const input_path = args.next() orelse return error.MissingInput;
    const expected_path = args.next() orelse return error.MissingExpected;
    const output_path = args.next() orelse return error.MissingOutput;
    const config_path = args.next() orelse return error.MissingConfig;
    if (args.next() != null) return error.TooManyArguments;
    const encoded = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(64 * 1024 * 1024));
    defer init.gpa.free(encoded);
    const expected = try std.Io.Dir.cwd().readFileAlloc(init.io, expected_path, init.gpa, .limited(64 * 1024 * 1024));
    defer init.gpa.free(expected);
    const configuration = try std.Io.Dir.cwd().readFileAlloc(init.io, config_path, init.gpa, .limited(4096));
    defer init.gpa.free(configuration);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, configuration, .{});
    defer parsed.deinit();
    const config = parsed.value;
    var decoder = lzfse.IncrementalDecoder.initWithOptions(init.gpa, toOptions(config));
    defer decoder.deinit();
    if (config.finish_before_input) try finish(&decoder);
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(init.gpa);
    var result = try execute(init.gpa, &decoder, encoded, expected, config, &actual);
    if (std.mem.eql(u8, config.mode, "error")) {
        if (result.@"error" == null or !std.mem.eql(u8, result.@"error".?, config.expected_error orelse return error.MissingExpectedError))
            return error.UnexpectedError;
    } else if (result.@"error" != null or !std.mem.eql(u8, actual.items, expected)) return error.DecodeMismatch;
    if (std.mem.eql(u8, config.mode, "reset")) {
        decoder.reset();
        try checkReset(init.gpa, &decoder, encoded, expected, config);
        try decoder.resetWithOptions(toOptions(config));
        try checkReset(init.gpa, &decoder, encoded, expected, config);
        result.reset_checks = 2;
    } else if (std.mem.eql(u8, config.mode, "limits")) {
        result.resource_checks = try checkLimits(init.gpa, encoded, expected, config, result);
    } else if (std.mem.eql(u8, config.mode, "oom")) {
        result.oom_failure_cases = try checkOom(init.gpa, encoded, expected, config);
    }
    const diagnostics_json = try std.json.Stringify.valueAlloc(init.gpa, decoder.diagnostics(), .{});
    defer init.gpa.free(diagnostics_json);
    const diagnostics = try std.json.parseFromSlice(std.json.Value, init.gpa, diagnostics_json, .{});
    defer diagnostics.deinit();
    result.diagnostics = diagnostics.value;
    const snapshot_json = try std.json.Stringify.valueAlloc(init.gpa, decoder.snapshot(), .{});
    defer init.gpa.free(snapshot_json);
    const snapshot = try std.json.parseFromSlice(std.json.Value, init.gpa, snapshot_json, .{});
    defer snapshot.deinit();
    result.snapshot = snapshot.value;
    const json = try std.json.Stringify.valueAlloc(init.gpa, result, .{});
    defer init.gpa.free(json);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = actual.items });
    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    try stdout.interface.writeAll(json);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}

fn toOptions(config: Config) lzfse.IncrementalDecodeOptions {
    return .{
        .max_output_len = config.max_output_len,
        .max_history_len = config.max_history_len,
        .max_compressed_buffer_len = config.max_compressed_buffer_len,
        .max_working_memory = config.max_working_memory,
        .expected_output_len = config.expected_output_len,
        .stop_after_end_marker = config.stop_after_end_marker,
    };
}

fn field(value: anytype, comptime names: []const []const u8) usize {
    inline for (names) |name| if (@hasField(@TypeOf(value), name)) return @intCast(@field(value, name));
    return 0;
}

fn update(result: *Result, decoder: *const lzfse.IncrementalDecoder) void {
    const snap = decoder.snapshot();
    result.max_buffered_input = @max(result.max_buffered_input, snap.buffered_compressed_bytes);
    result.max_retained_compressed_capacity = @max(result.max_retained_compressed_capacity, snap.retained_compressed_capacity);
    result.max_history_len = @max(result.max_history_len, field(snap, &.{ "history_len", "history_bytes", "retained_history_bytes" }));
    result.peak_working_bytes = @max(result.peak_working_bytes, field(snap, &.{ "peak_working_bytes", "peak_working_memory" }));
    result.payload_prefix_skipped = snap.payload_prefix_skipped;
}

fn finish(decoder: *lzfse.IncrementalDecoder) !void {
    const value = decoder.finish();
    if (@TypeOf(value) != void) try value;
}

fn execute(allocator: std.mem.Allocator, decoder: *lzfse.IncrementalDecoder, encoded: []const u8, expected: []const u8, config: Config, actual: *std.ArrayList(u8)) !Result {
    var result = Result{};
    var storage: [8208]u8 = undefined;
    var finished = false;
    const micro_input = [_]usize{ 1, 0, 3, 5, 0, 17, 64 };
    const micro_output = [_]usize{ 0, 1, 0, 7, 2, 31, 64 };
    while (result.steps < encoded.len * 8 + expected.len * 8 + 10000) {
        const input_len: usize = if (std.mem.eql(u8, config.pattern, "one")) 1 else if (std.mem.eql(u8, config.pattern, "wide")) 65536 else micro_input[result.steps % micro_input.len];
        const output_len: usize = if (std.mem.eql(u8, config.pattern, "one")) 1 else if (std.mem.eql(u8, config.pattern, "wide")) 8192 else micro_output[result.steps % micro_output.len];
        const input_end = result.input_read + @min(encoded.len - result.input_read, input_len);
        @memset(&storage, 0xa5);
        const output = storage[8 .. 8 + output_len];
        const before = decoder.snapshot();
        result.steps += 1;
        result.zero_output_steps += @intFromBool(output_len == 0);
        result.zero_input_steps += @intFromBool(input_end == result.input_read);
        const stepped = decoder.step(encoded[result.input_read..input_end], output) catch |err| {
            const after = decoder.snapshot();
            const before_input = field(before, &.{ "input_read", "total_input" });
            const after_input = field(after, &.{ "input_read", "total_input" });
            const before_output = field(before, &.{ "total_output", "output_written" });
            const after_output = field(after, &.{ "total_output", "output_written" });
            if (after_input < before_input or after_output < before_output) return error.InvalidErrorProgress;
            result.error_partial_input = after_input - before_input;
            result.error_partial_output = after_output - before_output;
            if (result.error_partial_input > input_end - result.input_read or result.error_partial_output > output.len)
                return error.InvalidErrorProgress;
            if (after.last_step_progress.input_read != result.error_partial_input or
                after.last_step_progress.output_written != result.error_partial_output) return error.InvalidErrorProgress;
            result.input_read += result.error_partial_input;
            try publish(allocator, actual, expected, output[0..result.error_partial_output]);
            result.output_written = actual.items.len;
            result.@"error" = @errorName(err);
            update(&result, decoder);
            try checkStickyError(decoder, err);
            return result;
        };
        if (stepped.progress.input_read > input_end - result.input_read or stepped.progress.output_written > output.len)
            return error.InvalidProgress;
        result.input_read += stepped.progress.input_read;
        try publish(allocator, actual, expected, output[0..stepped.progress.output_written]);
        result.output_written = actual.items.len;
        for (storage[0..8]) |byte| if (byte != 0xa5) return error.OutputPrefixModified;
        for (storage[8 + output_len ..]) |byte| if (byte != 0xa5) return error.OutputSuffixModified;
        if (stepped.progress.output_written != 0) {
            if (result.first_output_input_offset == null) result.first_output_input_offset = result.input_read;
            result.output_before_end_marker = result.output_before_end_marker or result.input_read < encoded.len;
        }
        update(&result, decoder);
        if (stepped.status == .done) {
            result.streams += 1;
            if (result.input_read != encoded.len) {
                if (config.stop_after_end_marker) {
                    try decoder.nextStream();
                    finished = false;
                    continue;
                }
                const before_trailing = decoder.snapshot();
                _ = decoder.step(encoded[result.input_read..], &.{}) catch |err| {
                    const after = decoder.snapshot();
                    result.error_partial_input = field(after, &.{ "input_read", "total_input" }) - field(before_trailing, &.{ "input_read", "total_input" });
                    result.input_read += result.error_partial_input;
                    result.@"error" = @errorName(err);
                    update(&result, decoder);
                    try checkStickyError(decoder, err);
                    return result;
                };
                return error.TrailingInputIgnored;
            }
            return result;
        }
        if (!finished and result.input_read == encoded.len) {
            finish(decoder) catch |err| {
                result.@"error" = @errorName(err);
                update(&result, decoder);
                return result;
            };
            finished = true;
        }
    }
    return error.StreamDidNotFinish;
}

fn checkStickyError(decoder: *lzfse.IncrementalDecoder, expected_error: anyerror) !void {
    const before = decoder.snapshot();
    var guard: [8]u8 = @splat(0xa5);
    if (decoder.step("retry", &guard)) |_| return error.UnexpectedErrorRetry else |err| {
        if (err != expected_error) return error.UnexpectedErrorRetry;
    }
    const after = decoder.snapshot();
    if (after.input_read != before.input_read or after.output_written != before.output_written or
        after.last_step_progress.input_read != 0 or after.last_step_progress.output_written != 0) return error.InvalidErrorRetryProgress;
    for (guard) |byte| if (byte != 0xa5) return error.ErrorRetryOutputModified;
}

fn publish(allocator: std.mem.Allocator, actual: *std.ArrayList(u8), expected: []const u8, output: []const u8) !void {
    if (actual.items.len > expected.len or output.len > expected.len - actual.items.len or
        !std.mem.eql(u8, output, expected[actual.items.len..][0..output.len])) return error.DecodeMismatch;
    try actual.appendSlice(allocator, output);
}

fn checkReset(allocator: std.mem.Allocator, decoder: *lzfse.IncrementalDecoder, encoded: []const u8, expected: []const u8, config: Config) !void {
    const initial = decoder.snapshot();
    if (initial.input_read != 0 or initial.output_written != 0 or initial.history_len != 0 or
        initial.buffered_compressed_bytes != 0 or initial.input_finished) return error.ResetStateMismatch;
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(allocator);
    const result = try execute(allocator, decoder, encoded, expected, config, &actual);
    if (result.@"error" != null or !std.mem.eql(u8, actual.items, expected)) return error.ResetMismatch;
}

fn runLimited(allocator: std.mem.Allocator, encoded: []const u8, expected: []const u8, config: Config, expected_error: ?[]const u8) !Result {
    var decoder = lzfse.IncrementalDecoder.initWithOptions(allocator, toOptions(config));
    defer decoder.deinit();
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(allocator);
    const result = try execute(allocator, &decoder, encoded, expected, config, &actual);
    if (expected_error) |name| {
        if (result.@"error" == null or !std.mem.eql(u8, result.@"error".?, name)) return error.UnexpectedLimitError;
    } else if (result.@"error" != null or !std.mem.eql(u8, actual.items, expected)) return error.LimitedDecodeMismatch;
    return result;
}

fn checkLimits(allocator: std.mem.Allocator, encoded: []const u8, expected: []const u8, config: Config, initial: Result) !usize {
    var checks: usize = 0;
    var limited = config;
    limited.max_output_len = expected.len;
    _ = try runLimited(allocator, encoded, expected, limited, null);
    limited.max_output_len = expected.len - 1;
    _ = try runLimited(allocator, encoded, expected, limited, "OutputLimitExceeded");
    checks += 2;
    limited = config;
    if (initial.peak_working_bytes != 0) {
        limited.max_working_memory = initial.peak_working_bytes;
        _ = try runLimited(allocator, encoded, expected, limited, null);
        limited.max_working_memory -= 1;
        _ = try runLimited(allocator, encoded, expected, limited, "WorkingMemoryLimitExceeded");
        checks += 2;
    } else return error.MissingMemoryAccounting;
    if (initial.max_buffered_input != 0) {
        limited = config;
        limited.max_compressed_buffer_len = initial.max_buffered_input;
        _ = try runLimited(allocator, encoded, expected, limited, null);
        limited.max_compressed_buffer_len -= 1;
        _ = try runLimited(allocator, encoded, expected, limited, "CompressedBufferLimitExceeded");
        checks += 2;
    }
    return checks;
}

fn checkOom(backing: std.mem.Allocator, encoded: []const u8, expected: []const u8, config: Config) !usize {
    for (0..1024) |failure_index| {
        var failing = std.testing.FailingAllocator.init(backing, .{ .fail_index = failure_index });
        var decoder = lzfse.IncrementalDecoder.initWithOptions(failing.allocator(), toOptions(config));
        var actual: std.ArrayList(u8) = .empty;
        defer actual.deinit(backing);
        const result = try execute(backing, &decoder, encoded, expected, config, &actual);
        if (result.@"error" != null and !std.mem.eql(u8, result.@"error".?, "OutOfMemory")) return error.UnexpectedOomError;
        if (result.@"error" != null) {
            try decoder.resetWithOptions(toOptions(config));
            failing.fail_index = std.math.maxInt(usize);
            try checkReset(backing, &decoder, encoded, expected, config);
        } else if (!std.mem.eql(u8, actual.items, expected)) return error.OomDecodeMismatch;
        decoder.deinit();
        if (failing.allocated_bytes != failing.freed_bytes) return error.OomAllocationLeak;
        if (!failing.has_induced_failure) return failure_index;
    }
    return error.AllocationFailureWalkLimit;
}
