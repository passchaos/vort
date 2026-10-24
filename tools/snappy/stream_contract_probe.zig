const std = @import("std");
const codec = @import("codec");
const native_module = @hasDecl(codec, "IncrementalFrameDecoder");

const Config = struct {
    format: []const u8 = "native",
    action: []const u8 = "stream",
    pattern: []const u8 = "mixed",
    max_chunk_payload_len: usize = 0xffffff,
    max_compressed_chunk_len: usize = 64 * 1024 * 1024,
    max_decoded_chunk_len: usize = 64 * 1024 * 1024,
    max_output_len: usize = std.math.maxInt(usize),
    max_total_output_len: usize = std.math.maxInt(usize),
    max_working_memory: usize = std.math.maxInt(usize),
    expected_output_len: ?usize = null,
    expect_failure: bool = false,
    check_one_shot: bool = false,
    reset_after: bool = false,
    oom: bool = false,
    move_after_steps: ?usize = null,
    move_when_output_pending: bool = false,
    finish_prefix_len: ?usize = null,
    finish_retry_error: []const u8 = "TruncatedFrame",
    frame_input_lengths: []const usize = &.{},
    frame_output_lengths: []const usize = &.{},
    next_stream_default_caps: bool = true,
};
const Report = struct {
    build_mode: []const u8 = @tagName(@import("builtin").mode),
    input_read: usize = 0,
    output_written: usize = 0,
    steps: usize = 0,
    streams: usize = 0,
    zero_input_steps: usize = 0,
    zero_output_steps: usize = 0,
    first_output_input_offset: ?usize = null,
    max_retained_compressed_capacity: usize = 0,
    max_history_capacity: usize = 0,
    max_required_history: ?usize = null,
    max_retained_decoded_capacity: usize = 0,
    peak_working_bytes: usize = 0,
    @"error": ?[]const u8 = null,
    finish_error: bool = false,
    error_input_progress: usize = 0,
    error_output_progress: usize = 0,
    sticky_checks: usize = 0,
    reset_checks: usize = 0,
    moves: usize = 0,
    finish_retry_checks: usize = 0,
    oom_failure_cases: usize = 0,
    one_shot_checks: usize = 0,
    one_shot_modified_bytes: usize = 0,
    snapshot: ?std.json.Value = null,
    diagnostics: ?std.json.Value = null,
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
    const c = parsed.value;
    if (native_module) {
        if (std.mem.eql(u8, c.action, "raw")) return rawCheck(init, encoded, expected, output_path, c);
        if (!std.mem.eql(u8, c.format, "native")) return error.WrongProbeModule;
        var d = codec.IncrementalFrameDecoder.initWithOptions(init.gpa, options(codec.IncrementalFrameDecoder, c, 0));
        defer d.deinit();
        try exercise(init, &d, encoded, expected, output_path, c);
    } else if (std.mem.eql(u8, c.format, "xerial")) {
        var d = codec.XerialIncrementalDecoder.initWithOptions(init.gpa, options(codec.XerialIncrementalDecoder, c, 0));
        defer d.deinit();
        try exercise(init, &d, encoded, expected, output_path, c);
    } else if (std.mem.eql(u8, c.format, "hadoop")) {
        var d = codec.HadoopIncrementalDecoder.initWithOptions(init.gpa, options(codec.HadoopIncrementalDecoder, c, 0));
        defer d.deinit();
        try exercise(init, &d, encoded, expected, output_path, c);
    } else return error.WrongProbeModule;
}
fn read(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(64 * 1024 * 1024));
}
fn options(comptime D: type, c: Config, index: usize) D.Options {
    var value: D.Options = if (native_module) .{
        .max_chunk_payload_len = c.max_chunk_payload_len,
        .max_output_len = c.max_output_len,
        .max_total_output_len = c.max_total_output_len,
        .max_working_memory = c.max_working_memory,
        .expected_output_len = if (c.frame_output_lengths.len != 0) c.frame_output_lengths[index] else c.expected_output_len,
    } else .{
        .max_compressed_chunk_len = c.max_compressed_chunk_len,
        .max_decoded_chunk_len = c.max_decoded_chunk_len,
        .max_output_len = c.max_output_len,
        .max_working_memory = c.max_working_memory,
        .expected_output_len = c.expected_output_len,
    };
    if (native_module and index != 0 and c.next_stream_default_caps) {
        value.max_total_output_len = std.math.maxInt(usize);
        value.max_working_memory = std.math.maxInt(usize);
    }
    return value;
}
fn totalInput(s: anytype) usize {
    return if (@hasField(@TypeOf(s), "total_input_read")) s.total_input_read else s.input_read;
}
fn totalOutput(s: anytype) usize {
    return if (@hasField(@TypeOf(s), "total_output")) s.total_output else s.output_written;
}
fn metric(s: anytype, comptime names: []const []const u8) usize {
    inline for (names) |name| if (@hasField(@TypeOf(s), name)) return @intCast(@field(s, name));
    return 0;
}
fn update(r: *Report, d: anytype) !void {
    const s = d.snapshot();
    r.max_retained_compressed_capacity = @max(r.max_retained_compressed_capacity, metric(s, &.{ "retained_chunk_capacity", "retained_compressed_capacity" }));
    r.max_history_capacity = @max(r.max_history_capacity, metric(s, &.{ "history_capacity", "retained_history_capacity" }));
    if (@hasField(@TypeOf(s), "required_history_len")) r.max_required_history = @max(r.max_required_history orelse 0, s.required_history_len);
    r.max_retained_decoded_capacity = @max(r.max_retained_decoded_capacity, s.retained_decoded_capacity);
    if (s.retained_decoded_capacity != 0) return error.DecodedHeapStagingRetained;
    r.peak_working_bytes = @max(r.peak_working_bytes, s.peak_working_bytes);
    if (s.working_bytes != d.workingMemoryBytes()) return error.WorkingMemoryGetterMismatch;
}
fn publish(a: std.mem.Allocator, actual: *std.ArrayList(u8), expected: []const u8, bytes: []const u8) !void {
    if (actual.items.len > expected.len or bytes.len > expected.len - actual.items.len or !std.mem.eql(u8, bytes, expected[actual.items.len..][0..bytes.len])) return error.InvalidPublishedPrefix;
    try actual.appendSlice(a, bytes);
}
fn guards(bytes: []const u8, output_len: usize) !void {
    for (bytes[0..8]) |byte| if (byte != 0xa5) return error.OutputPrefixGuardModified;
    for (bytes[8 + output_len ..]) |byte| if (byte != 0xa5) return error.OutputSuffixGuardModified;
}
fn sticky(d: anytype, err: anyerror) !void {
    const before = d.snapshot();
    var output: [17]u8 = @splat(0xa5);
    if (d.step("retry", &output)) |_| return error.FatalRetrySucceeded else |again| if (again != err) return error.FatalRetryChanged;
    if (d.finish()) |_| return error.FatalFinishSucceeded else |again| if (again != err) return error.FatalFinishChanged;
    const after = d.snapshot();
    for (output) |byte| if (byte != 0xa5) return error.FatalRetryOutputModified;
    if (totalInput(before) != totalInput(after) or totalOutput(before) != totalOutput(after) or after.last_step_progress.input_read != 0 or after.last_step_progress.output_written != 0 or before.error_input_offset != after.error_input_offset or before.error_output_offset != after.error_output_offset) return error.FatalRetryProgressChanged;
}
fn decode(a: std.mem.Allocator, original: anytype, encoded: []const u8, expected: []const u8, c: Config, actual: *std.ArrayList(u8)) !Report {
    const D = @TypeOf(original.*);
    var d = original;
    var relocated: D = undefined;
    var moved = false;
    defer if (moved) {
        original.* = relocated;
    };
    var r = Report{};
    var finished = false;
    var prefix_finished = c.finish_prefix_len == null;
    var stream_start: usize = 0;
    var storage: [8208]u8 = undefined;
    const ins = [_]usize{ 0, 1, 3, 0, 7, 31, 4096 };
    const outs = [_]usize{ 0, 1, 0, 7, 31, 64, 273 };
    while (r.steps < encoded.len * 8 + expected.len * 8 + 10000) {
        const by_step = if (c.move_after_steps) |at| r.steps >= at else false;
        if (!moved and (by_step or (c.move_when_output_pending and d.snapshot().payload_remaining != 0))) {
            relocated = d.*;
            d.* = undefined;
            d = &relocated;
            moved = true;
            r.moves += 1;
        }
        const wide = std.mem.eql(u8, c.pattern, "wide_zero");
        const ilen = if (std.mem.eql(u8, c.pattern, "one")) 1 else if (wide) encoded.len else ins[r.steps % ins.len];
        const olen = if (std.mem.eql(u8, c.pattern, "one")) 1 else outs[r.steps % outs.len];
        const stream_end = if (c.frame_input_lengths.len != 0) stream_start + c.frame_input_lengths[r.streams] else encoded.len;
        const limit = if (!prefix_finished) @min(stream_end, c.finish_prefix_len.?) else stream_end;
        const end = r.input_read + @min(limit - r.input_read, ilen);
        @memset(&storage, 0xa5);
        const output = storage[8 .. 8 + olen];
        const before = d.snapshot();
        r.steps += 1;
        r.zero_input_steps += @intFromBool(end == r.input_read);
        r.zero_output_steps += @intFromBool(olen == 0);
        const step = d.step(encoded[r.input_read..end], output) catch |err| {
            const after = d.snapshot();
            if (totalInput(after) < totalInput(before) or totalOutput(after) < totalOutput(before)) return error.InvalidErrorProgress;
            const ip = totalInput(after) - totalInput(before);
            const op = totalOutput(after) - totalOutput(before);
            if (ip > end - r.input_read or op > olen or after.last_step_progress.input_read != ip or after.last_step_progress.output_written != op or after.error_input_offset != totalInput(after) or after.error_output_offset != totalOutput(after)) return error.InvalidErrorProgress;
            r.input_read += ip;
            try publish(a, actual, expected, output[0..op]);
            r.output_written = actual.items.len;
            r.error_input_progress = ip;
            r.error_output_progress = op;
            r.@"error" = @errorName(err);
            try guards(&storage, olen);
            try update(&r, d);
            try sticky(d, err);
            r.sticky_checks += 1;
            return r;
        };
        const after = d.snapshot();
        if (step.progress.input_read > end - r.input_read or step.progress.output_written > olen or totalInput(after) - totalInput(before) != step.progress.input_read or totalOutput(after) - totalOutput(before) != step.progress.output_written or after.last_step_progress.input_read != step.progress.input_read or after.last_step_progress.output_written != step.progress.output_written) return error.InvalidProgress;
        r.input_read += step.progress.input_read;
        try publish(a, actual, expected, output[0..step.progress.output_written]);
        r.output_written = actual.items.len;
        if (step.progress.output_written != 0 and r.first_output_input_offset == null) r.first_output_input_offset = r.input_read;
        try guards(&storage, olen);
        try update(&r, d);
        if (!prefix_finished and r.input_read == limit and step.status == .need_input) {
            const saved = d.snapshot();
            if (d.finish()) |_| return error.EarlyFinishUnexpectedlySucceeded else |err| {
                if (!std.mem.eql(u8, @errorName(err), c.finish_retry_error)) return error.UnexpectedEarlyFinishError;
            }
            const rejected = d.snapshot();
            if (totalInput(saved) != totalInput(rejected) or totalOutput(saved) != totalOutput(rejected)) return error.FinishRetryProgressChanged;
            prefix_finished = true;
            r.finish_retry_checks += 1;
            continue;
        }
        if (step.status == .done or d.snapshot().phase == .done) {
            r.streams += 1;
            if (r.input_read != stream_end) return error.StreamBoundaryMismatch;
            if (r.input_read == encoded.len) return r;
            if (native_module) {
                try d.nextStream(options(D, c, r.streams));
                stream_start = stream_end;
                finished = false;
                continue;
            } else return error.UnexpectedMultipleStreams;
        }
        if (!finished and r.input_read == stream_end) {
            d.finish() catch |err| {
                r.@"error" = @errorName(err);
                r.finish_error = true;
                try update(&r, d);
                if (!native_module and err != error.TruncatedFrame) {
                    try sticky(d, err);
                    r.sticky_checks += 1;
                }
                return r;
            };
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
fn reconfigure(d: anytype, opts: @TypeOf(d.*).Options) !void {
    const value = d.resetWithOptions(opts);
    if (@TypeOf(value) != void) try value;
}
fn resetCheck(a: std.mem.Allocator, d: anytype, encoded: []const u8, expected: []const u8, c: Config) !void {
    const s = d.snapshot();
    if (totalInput(s) != 0 or totalOutput(s) != 0 or s.last_error_name.len != 0 or s.error_input_offset != null or s.error_output_offset != null) return error.ResetNotCleared;
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(a);
    const r = try decode(a, d, encoded, expected, c, &actual);
    try validate(r, actual.items, expected, c.expect_failure);
}
fn exercise(init: std.process.Init, d: anytype, encoded: []const u8, expected: []const u8, output_path: []const u8, c: Config) !void {
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(init.gpa);
    var r = try decode(init.gpa, d, encoded, expected, c, &actual);
    try validate(r, actual.items, expected, c.expect_failure);
    if (c.reset_after) {
        d.reset();
        if (c.frame_input_lengths.len != 0) try reconfigure(d, options(@TypeOf(d.*), c, 0));
        try resetCheck(init.gpa, d, encoded, expected, c);
        try reconfigure(d, options(@TypeOf(d.*), c, 0));
        try resetCheck(init.gpa, d, encoded, expected, c);
        r.reset_checks = 2;
    }
    if (c.oom) r.oom_failure_cases = try oomCheck(init.gpa, @TypeOf(d.*), encoded, expected, c);
    if (c.check_one_shot) {
        const out = try init.gpa.alloc(u8, expected.len);
        defer init.gpa.free(out);
        const n = if (native_module) try codec.decodeFrameInto(encoded, out) else if (std.mem.eql(u8, c.format, "xerial")) try codec.decodeXerialInto(encoded, out) else try codec.decodeHadoopInto(encoded, out);
        if (n != expected.len or !std.mem.eql(u8, out, expected)) return error.OneShotMismatch;
        r.one_shot_checks = 1;
    }
    const st = try std.json.Stringify.valueAlloc(init.gpa, d.snapshot(), .{});
    defer init.gpa.free(st);
    const snap = try std.json.parseFromSlice(std.json.Value, init.gpa, st, .{});
    defer snap.deinit();
    r.snapshot = snap.value;
    const dt = try std.json.Stringify.valueAlloc(init.gpa, d.diagnostics(), .{});
    defer init.gpa.free(dt);
    const diag = try std.json.parseFromSlice(std.json.Value, init.gpa, dt, .{});
    defer diag.deinit();
    r.diagnostics = diag.value;
    try writeReport(init, r, actual.items, output_path);
}
fn oomCheck(a: std.mem.Allocator, comptime D: type, encoded: []const u8, expected: []const u8, c: Config) !usize {
    var cases: usize = 0;
    inline for (.{ false, true }) |deny_resize| {
        for (0..256) |index| {
            var failing = std.testing.FailingAllocator.init(a, .{ .fail_index = index, .resize_fail_index = if (deny_resize) 0 else std.math.maxInt(usize) });
            var d = D.initWithOptions(failing.allocator(), options(D, c, 0));
            var actual: std.ArrayList(u8) = .empty;
            defer actual.deinit(a);
            const r = try decode(a, &d, encoded, expected, c, &actual);
            if (failing.allocated_bytes - failing.freed_bytes != d.workingMemoryBytes()) return error.LiveHeapMismatch;
            if (r.@"error") |name| {
                if (!std.mem.eql(u8, name, "OutOfMemory")) return error.UnexpectedAllocationError;
                cases += 1;
                failing.fail_index = std.math.maxInt(usize);
                d.reset();
                try resetCheck(a, &d, encoded, expected, c);
                try reconfigure(&d, options(D, c, 0));
                try resetCheck(a, &d, encoded, expected, c);
            } else try validate(r, actual.items, expected, false);
            d.deinit();
            if (failing.allocated_bytes != failing.freed_bytes) return error.AllocationLeak;
            if (!failing.has_induced_failure) break;
            if (index == 255) return error.AllocationWalkLimit;
        }
    }
    return cases;
}
fn rawCheck(init: std.process.Init, encoded: []const u8, expected: []const u8, output_path: []const u8, c: Config) !void {
    if (!native_module) return error.WrongProbeModule;
    var r = Report{};
    const out = try init.gpa.alloc(u8, expected.len + 16);
    defer init.gpa.free(out);
    @memset(out, 0xa5);
    const n = codec.decodeBlockInto(encoded, out[8 .. 8 + expected.len]) catch |err| blk: {
        r.@"error" = @errorName(err);
        break :blk 0;
    };
    try guards(out, expected.len);
    if (!c.expect_failure and (r.@"error" != null or n != expected.len or !std.mem.eql(u8, out[8 .. 8 + n], expected))) return error.RawOneShotMismatch;
    if (c.expect_failure and r.@"error" == null) return error.RawExpectedFailure;
    for (out[8 .. 8 + expected.len]) |byte| r.one_shot_modified_bytes += @intFromBool(byte != 0xa5);
    r.output_written = n;
    r.one_shot_checks = 1;
    try writeReport(init, r, out[8 .. 8 + n], output_path);
}
fn writeReport(init: std.process.Init, r: Report, actual: []const u8, path: []const u8) !void {
    const json = try std.json.Stringify.valueAlloc(init.gpa, r, .{});
    defer init.gpa.free(json);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = actual });
    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    try stdout.interface.writeAll(json);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}
