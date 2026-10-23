const std = @import("std");
const lzma = @import("lzma");
const D = lzma.IncrementalDecoder;

const Config = struct {
    pattern: []const u8 = "mixed",
    max_output_len: usize = std.math.maxInt(usize),
    max_dictionary_size: usize = 65536,
    max_compressed_buffer_len: usize = 64,
    max_working_memory: usize = std.math.maxInt(usize),
    expected_output_len: ?usize = null,
    stop_after_end_marker: bool = false,
    end_marker_input_guard: usize = 0,
    expect_failure: bool = false,
    reset_after: bool = false,
    oom: bool = false,
    move_after_steps: ?usize = null,
};
const Report = struct {
    build_mode: []const u8 = @tagName(@import("builtin").mode),
    input_read: usize = 0,
    output_written: usize = 0,
    steps: usize = 0,
    zero_input_steps: usize = 0,
    zero_output_steps: usize = 0,
    first_output_input_offset: ?usize = null,
    max_compressed_live: usize = 0,
    max_compressed_capacity: usize = 0,
    max_output_capacity: usize = 0,
    max_dictionary_capacity: usize = 0,
    peak_working_bytes: usize = 0,
    @"error": ?[]const u8 = null,
    error_input_progress: usize = 0,
    error_output_progress: usize = 0,
    sticky_checks: usize = 0,
    reset_checks: usize = 0,
    moves: usize = 0,
    oom_failure_cases: usize = 0,
    snapshot: ?std.json.Value = null,
    diagnostics: ?std.json.Value = null,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const input_path = args.next() orelse return error.MissingInput;
    if (std.mem.eql(u8, input_path, "--encode-known")) {
        const source_path = args.next() orelse return error.MissingInput;
        const encoded_path = args.next() orelse return error.MissingOutput;
        const source = try read(init, source_path);
        defer init.gpa.free(source);
        const wire = try lzma.encodeAlloc(init.gpa, source, .{ .dictionary_size = 4096, .size_mode = .known });
        defer init.gpa.free(wire);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = encoded_path, .data = wire });
        return;
    }
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
    const config = parsed.value;
    var decoder = D.initWithOptions(init.gpa, options(config));
    defer decoder.deinit();
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(init.gpa);
    var report = try decode(init.gpa, &decoder, encoded, expected, config, &actual);
    try validate(report, actual.items, expected, config.expect_failure);
    if (config.reset_after) {
        decoder.reset();
        try resetCheck(init.gpa, &decoder, encoded, expected, config);
        try reconfigure(&decoder, options(config));
        try resetCheck(init.gpa, &decoder, encoded, expected, config);
        report.reset_checks = 2;
    }
    if (config.oom) report.oom_failure_cases = try oomCheck(init.gpa, encoded, expected, config);
    const snap_text = try std.json.Stringify.valueAlloc(init.gpa, decoder.snapshot(), .{});
    defer init.gpa.free(snap_text);
    const snap = try std.json.parseFromSlice(std.json.Value, init.gpa, snap_text, .{});
    defer snap.deinit();
    report.snapshot = snap.value;
    const diag_text = try std.json.Stringify.valueAlloc(init.gpa, decoder.diagnostics(), .{});
    defer init.gpa.free(diag_text);
    const diag = try std.json.parseFromSlice(std.json.Value, init.gpa, diag_text, .{});
    defer diag.deinit();
    report.diagnostics = diag.value;
    const json = try std.json.Stringify.valueAlloc(init.gpa, report, .{});
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
fn options(c: Config) D.Options {
    return .{ .max_output_len = c.max_output_len, .max_dictionary_size = c.max_dictionary_size, .max_compressed_buffer_len = c.max_compressed_buffer_len, .max_working_memory = c.max_working_memory, .expected_output_len = c.expected_output_len, .stop_after_end_marker = c.stop_after_end_marker, .end_marker_input_guard = c.end_marker_input_guard };
}
fn reconfigure(d: *D, opts: D.Options) !void {
    const value = d.resetWithOptions(opts);
    if (@TypeOf(value) != void) try value;
}
fn update(r: *Report, d: *const D) void {
    const s = d.snapshot();
    r.max_compressed_live = @max(r.max_compressed_live, s.buffered_compressed_bytes);
    r.max_compressed_capacity = @max(r.max_compressed_capacity, s.retained_compressed_capacity);
    r.max_output_capacity = @max(r.max_output_capacity, s.retained_output_capacity);
    r.max_dictionary_capacity = @max(r.max_dictionary_capacity, s.retained_dictionary_capacity);
    r.peak_working_bytes = @max(r.peak_working_bytes, s.peak_working_bytes);
}
fn publish(a: std.mem.Allocator, actual: *std.ArrayList(u8), expected: []const u8, bytes: []const u8) !void {
    if (actual.items.len > expected.len or bytes.len > expected.len - actual.items.len or !std.mem.eql(u8, bytes, expected[actual.items.len..][0..bytes.len])) return error.InvalidPublishedPrefix;
    try actual.appendSlice(a, bytes);
}
fn guards(storage: []const u8, output_len: usize) !void {
    for (storage[0..8]) |b| if (b != 0xa5) return error.CallerPrefixModified;
    for (storage[8 + output_len ..]) |b| if (b != 0xa5) return error.CallerSuffixModified;
}
fn sticky(d: *D, err: D.Error) !void {
    const before = d.snapshot();
    var output: [17]u8 = @splat(0xa5);
    if (d.step("retry", &output)) |_| return error.FatalRetrySucceeded else |again| if (again != err) return error.FatalRetryChanged;
    for (output) |b| if (b != 0xa5) return error.FatalRetryOutputModified;
    const after = d.snapshot();
    if (after.input_read != before.input_read or after.output_written != before.output_written or after.last_step_progress.input_read != 0 or after.last_step_progress.output_written != 0 or after.error_input_offset != before.error_input_offset or after.error_output_offset != before.error_output_offset) return error.FatalRetryProgressChanged;
}
fn decode(a: std.mem.Allocator, original: *D, encoded: []const u8, expected: []const u8, c: Config, actual: *std.ArrayList(u8)) !Report {
    var d = original;
    var relocated: D = undefined;
    var moved = false;
    defer if (moved) {
        original.* = relocated;
    };
    var r = Report{};
    var finished = false;
    var storage: [8208]u8 = undefined;
    const input_sizes = [_]usize{ 0, 1, 3, 0, 7, 31, 4096 };
    const output_sizes = [_]usize{ 0, 1, 0, 7, 31, 64, 273 };
    while (r.steps < encoded.len * 8 + expected.len * 8 + 10000) {
        if (c.move_after_steps) |at| if (!moved and r.steps >= at) {
            relocated = d.*;
            d.* = undefined;
            d = &relocated;
            moved = true;
            r.moves += 1;
        };
        const wide_input = std.mem.eql(u8, c.pattern, "wide") or std.mem.eql(u8, c.pattern, "wide_zero");
        const ilen = if (std.mem.eql(u8, c.pattern, "one")) 1 else if (wide_input) encoded.len else input_sizes[r.steps % input_sizes.len];
        const olen = if (std.mem.eql(u8, c.pattern, "one")) 1 else if (std.mem.eql(u8, c.pattern, "wide")) 31 else output_sizes[r.steps % output_sizes.len];
        const end = r.input_read + @min(encoded.len - r.input_read, ilen);
        @memset(&storage, 0xa5);
        const output = storage[8 .. 8 + olen];
        const before = d.snapshot();
        r.steps += 1;
        r.zero_input_steps += @intFromBool(end == r.input_read);
        r.zero_output_steps += @intFromBool(olen == 0);
        const step = d.step(encoded[r.input_read..end], output) catch |err| {
            const after = d.snapshot();
            if (after.input_read < before.input_read or after.output_written < before.output_written) return error.InvalidErrorProgress;
            const ip = after.input_read - before.input_read;
            const op = after.output_written - before.output_written;
            if (ip > end - r.input_read or op > olen or after.last_step_progress.input_read != ip or after.last_step_progress.output_written != op or after.error_input_offset != after.input_read or after.error_output_offset != after.output_written) return error.InvalidErrorProgress;
            r.input_read += ip;
            try publish(a, actual, expected, output[0..op]);
            r.output_written = actual.items.len;
            r.error_input_progress = ip;
            r.error_output_progress = op;
            r.@"error" = @errorName(err);
            try guards(&storage, olen);
            update(&r, d);
            try sticky(d, err);
            r.sticky_checks += 1;
            return r;
        };
        const after = d.snapshot();
        if (step.progress.input_read > end - r.input_read or step.progress.output_written > olen or after.input_read - before.input_read != step.progress.input_read or after.output_written - before.output_written != step.progress.output_written or after.last_step_progress.input_read != step.progress.input_read or after.last_step_progress.output_written != step.progress.output_written) return error.InvalidProgress;
        r.input_read += step.progress.input_read;
        try publish(a, actual, expected, output[0..step.progress.output_written]);
        r.output_written = actual.items.len;
        if (step.progress.output_written != 0 and r.first_output_input_offset == null) r.first_output_input_offset = r.input_read;
        try guards(&storage, olen);
        update(&r, d);
        if (step.status == .done) {
            if (r.input_read != encoded.len and !c.stop_after_end_marker) return error.TrailingInputIgnored;
            return r;
        }
        if (!finished and r.input_read == encoded.len) {
            d.finish();
            finished = true;
        }
    }
    return error.StreamDidNotFinish;
}
fn validate(r: Report, actual: []const u8, expected: []const u8, failure: bool) !void {
    if (failure) {
        if (r.@"error" == null) return error.UnexpectedSuccess;
    } else if (r.@"error" != null or !std.mem.eql(u8, actual, expected)) return error.DecodeMismatch;
}
fn resetCheck(a: std.mem.Allocator, d: *D, encoded: []const u8, expected: []const u8, c: Config) !void {
    const snap = d.snapshot();
    if (snap.input_read != 0 or snap.output_written != 0 or snap.last_error_name.len != 0 or snap.error_input_offset != null or snap.error_output_offset != null) return error.ResetStateNotCleared;
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(a);
    const r = try decode(a, d, encoded, expected, c, &actual);
    try validate(r, actual.items, expected, c.expect_failure);
}
fn oomCheck(a: std.mem.Allocator, encoded: []const u8, expected: []const u8, c: Config) !usize {
    var cases: usize = 0;
    inline for (.{ false, true }) |deny_resize| {
        for (0..1024) |index| {
            var failing = std.testing.FailingAllocator.init(a, .{ .fail_index = index, .resize_fail_index = if (deny_resize) 0 else std.math.maxInt(usize) });
            var d = D.initWithOptions(failing.allocator(), options(c));
            var actual: std.ArrayList(u8) = .empty;
            defer actual.deinit(a);
            const r = try decode(a, &d, encoded, expected, c, &actual);
            if (r.@"error") |name| {
                if (!std.mem.eql(u8, name, "OutOfMemory")) return error.UnexpectedAllocationError;
                cases += 1;
                d.reset();
                failing.fail_index = std.math.maxInt(usize);
                try resetCheck(a, &d, encoded, expected, c);
                try reconfigure(&d, options(c));
                try resetCheck(a, &d, encoded, expected, c);
            } else try validate(r, actual.items, expected, false);
            d.deinit();
            if (failing.allocated_bytes != failing.freed_bytes) return error.AllocationLeak;
            if (!failing.has_induced_failure) break;
            if (index == 1023) return error.AllocationWalkLimit;
        }
    }
    return cases;
}
