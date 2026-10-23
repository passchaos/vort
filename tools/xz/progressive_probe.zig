const std = @import("std");
const xz = @import("xz");

const Config = struct {
    format: []const u8 = "xz",
    pattern: []const u8 = "mixed",
    policy: []const u8 = "progressive",
    dictionary_property: u8 = 8,
    max_dictionary_size: usize = 65536,
    max_output_len: usize = std.math.maxInt(usize),
    expected_output_len: ?usize = null,
    max_compressed_buffer_len: ?usize = null,
    max_decoded_buffer_len: ?usize = null,
    max_working_memory: usize = std.math.maxInt(usize),
    stop_after_end_marker: bool = false,
    stop_after_first_stream: bool = false,
    reset_after: bool = false,
    oom: bool = false,
    check_limits: bool = false,
    expect_failure: bool = false,
    accepted_length: ?usize = null,
    one_shot_concatenated: bool = false,
};
const Report = struct {
    input_read: usize = 0,
    output_written: usize = 0,
    steps: usize = 0,
    zero_output_steps: usize = 0,
    zero_input_steps: usize = 0,
    first_output_input_offset: ?usize = null,
    max_compressed_live: usize = 0,
    max_compressed_capacity: usize = 0,
    max_decoded_scratch: usize = 0,
    max_pending_output: usize = 0,
    peak_working_bytes: usize = 0,
    @"error": ?[]const u8 = null,
    error_input_progress: usize = 0,
    error_output_progress: usize = 0,
    reset_checks: usize = 0,
    oom_failures: usize = 0,
    resource_checks: usize = 0,
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
    const encoded = try read(init, input_path);
    defer init.gpa.free(encoded);
    const expected = try read(init, expected_path);
    defer init.gpa.free(expected);
    const configuration = try read(init, config_path);
    defer init.gpa.free(configuration);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, configuration, .{});
    defer parsed.deinit();
    if (std.mem.eql(u8, parsed.value.format, "raw")) {
        var decoder = try xz.RawLzma2IncrementalDecoder.init(init.gpa, rawOptions(parsed.value));
        defer decoder.deinit();
        try exercise(init, &decoder, encoded, expected, output_path, parsed.value);
    } else {
        var decoder = xz.IncrementalDecoder.initWithOptions(init.gpa, xzOptions(parsed.value));
        defer decoder.deinit();
        try exercise(init, &decoder, encoded, expected, output_path, parsed.value);
    }
}

fn rawOptions(config: Config) xz.RawLzma2IncrementalDecoder.Options {
    return .{ .dictionary_property = config.dictionary_property, .max_dictionary_size = config.max_dictionary_size, .max_output_len = config.max_output_len, .expected_output_len = config.expected_output_len, .max_compressed_buffer_len = config.max_compressed_buffer_len orelse 64, .max_working_memory = config.max_working_memory, .stop_after_end_marker = config.stop_after_end_marker };
}
fn xzOptions(config: Config) xz.IncrementalDecoder.Options {
    return .{ .input_policy = if (std.mem.eql(u8, config.policy, "prevalidated")) .prevalidated_block else .progressive_block, .max_dictionary_size = config.max_dictionary_size, .max_output_len = config.max_output_len, .expected_output_len = config.expected_output_len, .max_compressed_buffer_len = config.max_compressed_buffer_len orelse 131072, .max_decoded_buffer_len = config.max_decoded_buffer_len orelse std.math.maxInt(usize), .max_working_memory = config.max_working_memory, .stop_after_first_stream = config.stop_after_first_stream };
}
fn read(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(64 * 1024 * 1024));
}

fn metric(snapshot: anytype, comptime names: []const []const u8) usize {
    inline for (names) |name| if (@hasField(@TypeOf(snapshot), name)) return @intCast(@field(snapshot, name));
    return 0;
}
fn update(report: *Report, decoder: anytype) void {
    const snap = decoder.snapshot();
    report.max_compressed_live = @max(report.max_compressed_live, metric(snap, &.{ "buffered_compressed_bytes", "buffered_input" }));
    report.max_compressed_capacity = @max(report.max_compressed_capacity, metric(snap, &.{ "retained_compressed_capacity", "retained_input_capacity" }));
    report.max_decoded_scratch = @max(report.max_decoded_scratch, metric(snap, &.{ "retained_output_capacity", "retained_decoded_capacity" }));
    report.max_pending_output = @max(report.max_pending_output, snap.pending_output);
    report.peak_working_bytes = @max(report.peak_working_bytes, snap.peak_working_bytes);
}

fn exercise(init: std.process.Init, decoder: anytype, encoded: []const u8, expected: []const u8, output_path: []const u8, config: Config) !void {
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(init.gpa);
    var report = try decode(init.gpa, decoder, encoded, expected, config, &actual);
    if (config.expect_failure) {
        if (report.@"error" == null) return error.UnexpectedSuccess;
    } else if (report.@"error" != null or !std.mem.eql(u8, actual.items, expected)) return error.DecodeMismatch;
    if (config.reset_after) {
        decoder.reset();
        var replay: std.ArrayList(u8) = .empty;
        defer replay.deinit(init.gpa);
        const retry = try decode(init.gpa, decoder, encoded, expected, config, &replay);
        if (retry.@"error" != null or !std.mem.eql(u8, replay.items, expected)) return error.ResetMismatch;
        report.reset_checks = 1;
    }
    if (config.oom) report.oom_failures = try checkOom(init.gpa, @TypeOf(decoder.*), encoded, expected, config);
    if (config.check_limits) report.resource_checks = try checkMemory(init.gpa, @TypeOf(decoder.*), encoded, expected, config, report.peak_working_bytes);
    if (!config.expect_failure and std.mem.eql(u8, config.format, "xz")) {
        const one_shot = if (config.one_shot_concatenated)
            try xz.decodeConcatenatedAllocLimited(init.gpa, encoded[0..report.input_read], expected.len)
        else
            try xz.decodeAllocLimited(init.gpa, encoded[0..report.input_read], expected.len);
        defer init.gpa.free(one_shot);
        if (!std.mem.eql(u8, one_shot, expected)) return error.OneShotMismatch;
        report.one_shot_verified = true;
    }
    const snapshot_text = try std.json.Stringify.valueAlloc(init.gpa, decoder.snapshot(), .{});
    defer init.gpa.free(snapshot_text);
    const snapshot = try std.json.parseFromSlice(std.json.Value, init.gpa, snapshot_text, .{});
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

fn decode(allocator: std.mem.Allocator, decoder: anytype, encoded: []const u8, expected: []const u8, config: Config, actual: *std.ArrayList(u8)) !Report {
    var report = Report{};
    var finished = false;
    var guard: [8208]u8 = undefined;
    const input_sizes = [_]usize{ 0, 1, 3, 0, 7, 31, 4096 };
    const output_sizes = [_]usize{ 0, 1, 0, 7, 31, 64, 273 };
    while (report.steps < encoded.len * 8 + expected.len * 8 + 10000) {
        const input_len: usize = if (std.mem.eql(u8, config.pattern, "one")) 1 else if (std.mem.eql(u8, config.pattern, "large")) encoded.len else input_sizes[report.steps % input_sizes.len];
        const output_len: usize = if (std.mem.eql(u8, config.pattern, "one")) 1 else if (std.mem.eql(u8, config.pattern, "large")) 31 else output_sizes[report.steps % output_sizes.len];
        const end = report.input_read + @min(encoded.len - report.input_read, input_len);
        @memset(&guard, 0xa5);
        const output = guard[8 .. 8 + output_len];
        const before = decoder.snapshot();
        report.steps += 1;
        report.zero_input_steps += @intFromBool(end == report.input_read);
        report.zero_output_steps += @intFromBool(output.len == 0);
        const stepped = decoder.step(encoded[report.input_read..end], output) catch |err| {
            const after = decoder.snapshot();
            if (after.input_read < before.input_read or after.output_written < before.output_written) return error.InvalidErrorProgress;
            const in_progress = after.input_read - before.input_read;
            const out_progress = after.output_written - before.output_written;
            if (in_progress > end - report.input_read or out_progress > output.len or after.last_step_progress.input_read != in_progress or
                after.last_step_progress.output_written != out_progress) return error.InvalidErrorProgress;
            report.input_read += in_progress;
            try publish(allocator, actual, expected, output[0..out_progress]);
            report.output_written = actual.items.len;
            report.@"error" = @errorName(err);
            report.error_input_progress = in_progress;
            report.error_output_progress = out_progress;
            update(&report, decoder);
            if (after.error_input_offset != after.input_read or after.error_output_offset != after.output_written)
                return error.InvalidErrorOffset;
            var retry_output: [16]u8 = @splat(0xa5);
            if (decoder.step("retry", &retry_output)) |_| return error.UnexpectedErrorRetry else |retry_error| {
                if (retry_error != err) return error.UnexpectedErrorRetry;
            }
            const retried = decoder.snapshot();
            if (retried.input_read != after.input_read or retried.output_written != after.output_written or
                retried.last_step_progress.input_read != 0 or retried.last_step_progress.output_written != 0)
                return error.InvalidErrorRetryProgress;
            for (retry_output) |byte| if (byte != 0xa5) return error.ErrorRetryOutputModified;
            return report;
        };
        if (stepped.progress.input_read > end - report.input_read or stepped.progress.output_written > output.len) return error.InvalidProgress;
        const after = decoder.snapshot();
        if (after.input_read - before.input_read != stepped.progress.input_read or after.output_written - before.output_written != stepped.progress.output_written or
            after.last_step_progress.input_read != stepped.progress.input_read or after.last_step_progress.output_written != stepped.progress.output_written)
            return error.InvalidProgress;
        report.input_read += stepped.progress.input_read;
        try publish(allocator, actual, expected, output[0..stepped.progress.output_written]);
        report.output_written = actual.items.len;
        if (stepped.progress.output_written != 0 and report.first_output_input_offset == null) report.first_output_input_offset = report.input_read;
        for (guard[0..8]) |byte| if (byte != 0xa5) return error.CallerPrefixModified;
        for (guard[8 + output_len ..]) |byte| if (byte != 0xa5) return error.CallerSuffixModified;
        update(&report, decoder);
        if (stepped.status == .done) return report;
        if (!finished and report.input_read == encoded.len) {
            decoder.finish();
            finished = true;
        }
    }
    return error.StreamDidNotFinish;
}

fn publish(allocator: std.mem.Allocator, actual: *std.ArrayList(u8), expected: []const u8, bytes: []const u8) !void {
    if (actual.items.len > expected.len or bytes.len > expected.len - actual.items.len or
        !std.mem.eql(u8, bytes, expected[actual.items.len..][0..bytes.len])) return error.InvalidPublishedPrefix;
    try actual.appendSlice(allocator, bytes);
}

fn checkOom(backing: std.mem.Allocator, comptime D: type, encoded: []const u8, expected: []const u8, config: Config) !usize {
    for (0..1024) |failure_index| {
        var failing = std.testing.FailingAllocator.init(backing, .{ .fail_index = failure_index });
        var decoder = if (D == xz.RawLzma2IncrementalDecoder) try D.init(failing.allocator(), rawOptions(config)) else D.initWithOptions(failing.allocator(), xzOptions(config));
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(backing);
        const report = try decode(backing, &decoder, encoded, expected, config, &output);
        decoder.deinit();
        if (failing.allocated_bytes != failing.freed_bytes) return error.OomAllocationLeak;
        if (report.@"error") |name| {
            if (!std.mem.eql(u8, name, "OutOfMemory")) return error.UnexpectedOomError;
        } else if (!std.mem.eql(u8, output.items, expected)) return error.OomOutputMismatch;
        if (!failing.has_induced_failure) return failure_index;
    }
    return error.OomWalkLimit;
}

fn checkMemory(backing: std.mem.Allocator, comptime D: type, encoded: []const u8, expected: []const u8, config: Config, peak: usize) !usize {
    if (peak == 0) return error.MissingWorkingMemoryAccounting;
    for ([_]usize{ peak, peak - 1 }, 0..) |limit, index| {
        var constrained = config;
        constrained.max_working_memory = limit;
        var decoder = if (D == xz.RawLzma2IncrementalDecoder) try D.init(backing, rawOptions(constrained)) else D.initWithOptions(backing, xzOptions(constrained));
        defer decoder.deinit();
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(backing);
        const report = try decode(backing, &decoder, encoded, expected, constrained, &output);
        if (index == 0) {
            if (report.@"error" != null or !std.mem.eql(u8, output.items, expected)) return error.ExactMemoryLimitMismatch;
        } else if (report.@"error" == null or !std.mem.eql(u8, report.@"error".?, "WorkingMemoryLimitExceeded"))
            return error.WorkingMemoryLimitNotEnforced;
    }
    return 2;
}
