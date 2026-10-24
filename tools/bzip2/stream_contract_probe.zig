const std = @import("std");
const bzip2 = @import("bzip2");
const Decoder = bzip2.IncrementalDecoder;
const Config = struct {
    pattern: []const u8 = "mixed",
    max_output_len: usize = std.math.maxInt(usize),
    max_working_memory: usize = std.math.maxInt(usize),
    max_compressed_block_len: usize = 4 * 1024 * 1024,
    max_decoded_block_len: usize = 64 * 1024 * 1024,
    expected_output_len: ?usize = null,
    first_stream_retry_granularity: usize = 0,
    stop_next: bool = false,
    stop_only: bool = false,
    reset_after: bool = false,
    reconfigure: bool = false,
    move_active: bool = false,
    check_limits: bool = false,
    oom: bool = false,
    expect_failure: bool = false,
    expected_error: ?[]const u8 = null,
};
const Report = struct {
    input_read: usize = 0,
    output_written: usize = 0,
    steps: usize = 0,
    zero_output_steps: usize = 0,
    zero_input_steps: usize = 0,
    first_output_input_offset: ?usize = null,
    first_output_validated_bytes: usize = 0,
    max_compressed_capacity: usize = 0,
    max_transformed_capacity: usize = 0,
    max_links_capacity: usize = 0,
    max_decoded_capacity: usize = 0,
    peak_working_bytes: usize = 0,
    @"error": ?[]const u8 = null,
    error_input_progress: usize = 0,
    error_output_progress: usize = 0,
    next_stream_calls: usize = 0,
    reset_checks: usize = 0,
    reconfiguration_checks: usize = 0,
    move_checks: usize = 0,
    resource_checks: usize = 0,
    oom_failures: usize = 0,
    one_shot_verified: bool = false,
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
    const input = try read(init, input_path);
    defer init.gpa.free(input);
    const expected = try read(init, expected_path);
    defer init.gpa.free(expected);
    const configuration = try read(init, config_path);
    defer init.gpa.free(configuration);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, configuration, .{});
    defer parsed.deinit();
    const config = parsed.value;
    var owner = Decoder.initWithOptions(init.gpa, options(config));
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(init.gpa);
    if (config.move_active) {
        var output: [1]u8 = undefined;
        const result = try owner.step(input, &output);
        try publish(init.gpa, &actual, expected, output[0..result.progress.output_written]);
    }
    var decoder = owner;
    if (config.move_active) @memset(std.mem.asBytes(&owner), 0xa5);
    defer decoder.deinit();
    var report = try decode(init.gpa, &decoder, input, expected, config, &actual);
    report.move_checks = @intFromBool(config.move_active);
    if (config.expected_error) |name| {
        if (report.@"error" == null or !std.mem.eql(u8, report.@"error".?, name)) return error.UnexpectedError;
    } else if (config.expect_failure) {
        if (report.@"error" == null) return error.UnexpectedSuccess;
    } else if (report.@"error" != null or !std.mem.eql(u8, actual.items, expected)) return error.DecodeMismatch;
    if (config.reset_after) {
        decoder.reset();
        try replay(init.gpa, &decoder, input, expected, config);
        report.reset_checks = 1;
    }
    if (config.reconfigure) {
        const previous = decoder.snapshot();
        var invalid = options(config);
        invalid.max_output_len = 0;
        invalid.expected_output_len = 1;
        decoder.resetWithOptions(invalid);
        const rejected = decoder.snapshot();
        if (rejected.input_read != previous.input_read or rejected.output_written != previous.output_written or
            rejected.retained_transformed_capacity != previous.retained_transformed_capacity or
            rejected.retained_links_capacity != previous.retained_links_capacity) return error.InvalidReconfigurationState;
        var guard: [8]u8 = @splat(0xa5);
        if (decoder.step("", &guard)) |_| return error.InvalidOptionsAccepted else |err| {
            if (err != error.InvalidBlockPlan) return err;
        }
        for (guard) |byte| if (byte != 0xa5) return error.InvalidOptionsOutputModified;
        decoder.reset();
        try replay(init.gpa, &decoder, input, expected, config);
        decoder.resetWithOptions(options(config));
        if (decoder.snapshot().input_read != 0 or decoder.snapshot().output_written != 0 or
            decoder.snapshot().retained_transformed_capacity != 0 or decoder.snapshot().retained_links_capacity != 0)
            return error.ReconfigurationState;
        try replay(init.gpa, &decoder, input, expected, config);
        report.reconfiguration_checks = 2;
    }
    if (config.check_limits) report.resource_checks = try checkLimits(init.gpa, input, expected, config, report.peak_working_bytes);
    if (config.oom) report.oom_failures = try checkOom(init.gpa, input, expected, config);
    if (!config.expect_failure and config.expected_error == null) {
        const consumed = if (config.stop_only) report.input_read - decoder.trailingInput().len else report.input_read;
        const one_shot = try bzip2.decodeConcatenatedAllocLimited(init.gpa, input[0..consumed], expected.len);
        defer init.gpa.free(one_shot);
        if (!std.mem.eql(u8, one_shot, expected)) return error.OneShotMismatch;
        report.one_shot_verified = true;
    }
    const snap_text = try std.json.Stringify.valueAlloc(init.gpa, decoder.snapshot(), .{});
    defer init.gpa.free(snap_text);
    const snapshot = try std.json.parseFromSlice(std.json.Value, init.gpa, snap_text, .{});
    defer snapshot.deinit();
    report.snapshot = snapshot.value;
    const json = try std.json.Stringify.valueAlloc(init.gpa, report, .{});
    defer init.gpa.free(json);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = actual.items });
    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    try stdout.interface.writeAll(json);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}

fn read(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
}
fn options(config: Config) Decoder.Options {
    return .{ .max_output_len = config.max_output_len, .max_working_memory = config.max_working_memory, .max_compressed_block_len = config.max_compressed_block_len, .max_decoded_block_len = config.max_decoded_block_len, .expected_output_len = config.expected_output_len, .stop_after_first_stream = config.stop_only or config.stop_next, .first_stream_retry_granularity = config.first_stream_retry_granularity };
}
fn update(report: *Report, decoder: *const Decoder) void {
    const snap = decoder.snapshot();
    report.max_compressed_capacity = @max(report.max_compressed_capacity, snap.retained_compressed_capacity);
    report.max_transformed_capacity = @max(report.max_transformed_capacity, snap.retained_transformed_capacity);
    report.max_links_capacity = @max(report.max_links_capacity, snap.retained_links_capacity);
    report.max_decoded_capacity = @max(report.max_decoded_capacity, snap.retained_decoded_capacity);
    report.peak_working_bytes = @max(report.peak_working_bytes, snap.peak_working_bytes);
}
fn publish(allocator: std.mem.Allocator, actual: *std.ArrayList(u8), expected: []const u8, output: []const u8) !void {
    if (actual.items.len > expected.len or output.len > expected.len - actual.items.len or
        !std.mem.eql(u8, output, expected[actual.items.len..][0..output.len])) return error.InvalidPublishedPrefix;
    try actual.appendSlice(allocator, output);
}
fn decode(allocator: std.mem.Allocator, decoder: *Decoder, input: []const u8, expected: []const u8, config: Config, actual: *std.ArrayList(u8)) !Report {
    var report = Report{ .input_read = decoder.snapshot().input_read, .output_written = actual.items.len };
    if (actual.items.len != 0) {
        report.first_output_input_offset = report.input_read;
        report.first_output_validated_bytes = decoder.snapshot().validated_output;
    }
    var finished = decoder.snapshot().input_finished;
    const input_sizes = [_]usize{ 0, 1, 3, 0, 7, 31, 4096 };
    const output_sizes = [_]usize{ 0, 1, 0, 7, 31, 64, 273 };
    const wide_outputs = [_]usize{ 0, 8192, 0, 4096, 31 };
    var guard: [8208]u8 = undefined;
    while (report.steps < input.len * 8 + expected.len * 8 + 10000) {
        const in_len: usize = if (std.mem.eql(u8, config.pattern, "one")) 1 else if (std.mem.eql(u8, config.pattern, "wide_zero")) input.len else input_sizes[report.steps % input_sizes.len];
        const out_len: usize = if (std.mem.eql(u8, config.pattern, "one")) 1 else if (std.mem.eql(u8, config.pattern, "wide_zero")) wide_outputs[report.steps % wide_outputs.len] else output_sizes[report.steps % output_sizes.len];
        const end = report.input_read + @min(input.len - report.input_read, in_len);
        @memset(&guard, 0xa5);
        const output = guard[8 .. 8 + out_len];
        const before = decoder.snapshot();
        report.steps += 1;
        report.zero_input_steps += @intFromBool(end == report.input_read);
        report.zero_output_steps += @intFromBool(output.len == 0);
        const result = decoder.step(input[report.input_read..end], output) catch |err| {
            const after = decoder.snapshot();
            const in_progress = after.input_read - before.input_read;
            const out_progress = after.output_written - before.output_written;
            if (in_progress > end - report.input_read or out_progress > output.len or
                after.last_step_progress.input_read != in_progress or after.last_step_progress.output_written != out_progress)
                return error.InvalidErrorProgress;
            report.input_read += in_progress;
            try publish(allocator, actual, expected, output[0..out_progress]);
            report.output_written = actual.items.len;
            report.@"error" = @errorName(err);
            report.error_input_progress = in_progress;
            report.error_output_progress = out_progress;
            update(&report, decoder);
            if (after.error_input_offset != after.input_read or after.error_output_offset != after.output_written) return error.InvalidErrorOffset;
            var retry: [8]u8 = @splat(0xa5);
            if (decoder.step("retry", &retry)) |_| return error.UnexpectedRetrySuccess else |retry_error| {
                if (retry_error != err) return error.UnexpectedRetryError;
            }
            const retried = decoder.snapshot();
            if (retried.input_read != after.input_read or retried.output_written != after.output_written or
                retried.last_step_progress.input_read != 0 or retried.last_step_progress.output_written != 0) return error.InvalidRetryProgress;
            for (retry) |byte| if (byte != 0xa5) return error.RetryOutputModified;
            return report;
        };
        const after = decoder.snapshot();
        if (result.progress.input_read > end - report.input_read or result.progress.output_written > output.len or
            after.input_read - before.input_read != result.progress.input_read or after.output_written - before.output_written != result.progress.output_written or
            after.last_step_progress.input_read != result.progress.input_read or after.last_step_progress.output_written != result.progress.output_written)
            return error.InvalidProgress;
        report.input_read += result.progress.input_read;
        try publish(allocator, actual, expected, output[0..result.progress.output_written]);
        report.output_written = actual.items.len;
        if (result.progress.output_written != 0 and report.first_output_input_offset == null) {
            report.first_output_input_offset = report.input_read;
            report.first_output_validated_bytes = after.validated_output;
        }
        for (guard[0..8]) |byte| if (byte != 0xa5) return error.CallerPrefixModified;
        for (guard[8 + out_len ..]) |byte| if (byte != 0xa5) return error.CallerSuffixModified;
        update(&report, decoder);
        if (result.status == .done) {
            if (config.stop_next and (report.input_read != input.len or decoder.trailingInput().len != 0)) {
                try decoder.nextStream();
                report.next_stream_calls += 1;
                continue;
            }
            return report;
        }
        if (!finished and report.input_read == input.len) {
            decoder.finish();
            finished = true;
        }
    }
    return error.StreamDidNotFinish;
}
fn replay(allocator: std.mem.Allocator, decoder: *Decoder, input: []const u8, expected: []const u8, config: Config) !void {
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    const report = try decode(allocator, decoder, input, expected, config, &output);
    if (report.@"error" != null or !std.mem.eql(u8, output.items, expected)) return error.ReplayMismatch;
}
fn checkLimits(backing: std.mem.Allocator, input: []const u8, expected: []const u8, config: Config, peak: usize) !usize {
    if (peak == 0) return error.MissingWorkingAccounting;
    for ([_]usize{ peak, peak - 1 }, 0..) |limit, index| {
        var constrained = config;
        constrained.max_working_memory = limit;
        var decoder = Decoder.initWithOptions(backing, options(constrained));
        defer decoder.deinit();
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(backing);
        const report = try decode(backing, &decoder, input, expected, constrained, &output);
        if (index == 0) {
            if (report.@"error" != null or !std.mem.eql(u8, output.items, expected)) return error.ExactWorkingLimitMismatch;
        } else if (report.@"error" == null or !std.mem.eql(u8, report.@"error".?, "WorkingMemoryLimitExceeded")) return error.WorkingLimitNotEnforced;
    }
    return 2;
}
fn checkOom(backing: std.mem.Allocator, input: []const u8, expected: []const u8, config: Config) !usize {
    for (0..1024) |failure_index| {
        var tracker = std.testing.FailingAllocator.init(backing, .{ .fail_index = failure_index });
        var decoder = Decoder.initWithOptions(tracker.allocator(), options(config));
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(backing);
        const report = try decode(backing, &decoder, input, expected, config, &output);
        decoder.deinit();
        if (tracker.allocated_bytes != tracker.freed_bytes) return error.OomAllocationLeak;
        if (report.@"error") |name| {
            if (!std.mem.eql(u8, name, "OutOfMemory")) return error.UnexpectedOomError;
        } else if (!std.mem.eql(u8, output.items, expected)) return error.OomDecodeMismatch;
        if (!tracker.has_induced_failure) return failure_index;
    }
    return error.OomWalkLimit;
}
