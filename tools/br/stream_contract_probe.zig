const std = @import("std");
const br = @import("br");
const Owned = br.IncrementalStreamDecoder;
const Caller = br.IncrementalCopyStreamDecoder;

const Config = struct {
    kind: []const u8 = "owned",
    pattern: []const u8 = "mixed",
    max_output_len: usize = std.math.maxInt(usize),
    max_total_output_len: usize = std.math.maxInt(usize),
    max_compressed_len: usize = std.math.maxInt(usize),
    expected_compressed_len: ?usize = null,
    expected_output_len: ?usize = null,
    max_history_len: usize = 65536,
    max_compressed_header_len: usize = 1024 * 1024,
    max_working_memory: usize = std.math.maxInt(usize),
    warmup_stream_path: ?[]const u8 = null,
    warmup_header_limit: usize = 16385,
    header_scratch_len: usize = 0,
    retry_header_scratch_len: usize = 0,
    grow_header_on_exhaustion: bool = false,
    metadata_capacity: usize = 4096,
    allow_large_window: bool = false,
    allow_trailing_data: bool = false,
    dictionary_path: ?[]const u8 = null,
    frame_input_lengths: []const usize = &.{},
    frame_output_lengths: []const usize = &.{},
    expect_failure: bool = false,
    reset_after: bool = false,
    oom: bool = false,
    check_next_frame_retry: bool = false,
    next_frame_default_operation_caps: bool = false,
    move_after_steps: ?usize = null,
};
const Buffers = struct {
    history: []u8,
    header: []u8,
    replacement: []u8,
    warmup_wire: []const u8,
    metadata: []u8,
    metadata_lengths: []usize,
    dictionary: br.SharedDictionary,
};
const Report = struct {
    build_mode: []const u8 = @tagName(@import("builtin").mode),
    input_read: usize = 0,
    output_written: usize = 0,
    steps: usize = 0,
    frames: usize = 0,
    zero_input_steps: usize = 0,
    zero_output_steps: usize = 0,
    first_output_input_offset: ?usize = null,
    max_retained_input: usize = 0,
    max_header_capacity: usize = 0,
    max_owned_header_capacity: usize = 0,
    max_history_capacity: usize = 0,
    peak_working_bytes: usize = 0,
    @"error": ?[]const u8 = null,
    error_input_progress: usize = 0,
    error_output_progress: usize = 0,
    sticky_checks: usize = 0,
    reset_checks: usize = 0,
    moves: usize = 0,
    oom_failure_cases: usize = 0,
    next_frame_retry_checks: usize = 0,
    header_retry_checks: usize = 0,
    warmup_input_read: usize = 0,
    warmup_output_written: usize = 0,
    metadata_hex: ?[]const u8 = null,
    trailing_hex: ?[]const u8 = null,
    metadata_lengths: ?[]const usize = null,
    snapshot: ?std.json.Value = null,
    diagnostics: ?std.json.Value = null,
};
pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const input_path = args.next() orelse return error.MissingInput;
    if (std.mem.eql(u8, input_path, "--large-header")) {
        const path = args.next() orelse return error.MissingOutput;
        const wire = try br.IncrementalTestSupport.encodeLargeCompressedHeader(init.gpa);
        defer init.gpa.free(wire);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = wire });
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
    const c = parsed.value;
    const history = try init.gpa.alloc(u8, c.max_history_len);
    defer init.gpa.free(history);
    const header = try init.gpa.alloc(u8, c.header_scratch_len);
    defer init.gpa.free(header);
    const replacement = try init.gpa.alloc(u8, c.retry_header_scratch_len);
    defer init.gpa.free(replacement);
    const warmup_wire = if (c.warmup_stream_path) |path| try read(init, path) else try init.gpa.alloc(u8, 0);
    defer init.gpa.free(warmup_wire);
    const metadata = try init.gpa.alloc(u8, c.metadata_capacity);
    defer init.gpa.free(metadata);
    const metadata_lengths = try init.gpa.alloc(usize, 32);
    defer init.gpa.free(metadata_lengths);
    const dictionary_bytes = if (c.dictionary_path) |p| try read(init, p) else try init.gpa.alloc(u8, 0);
    defer init.gpa.free(dictionary_bytes);
    const prefixes = [_][]const u8{dictionary_bytes};
    const buffers = Buffers{ .history = history, .header = header, .replacement = replacement, .warmup_wire = warmup_wire, .metadata = metadata, .metadata_lengths = metadata_lengths, .dictionary = .{ .raw_prefixes = if (c.dictionary_path != null) &prefixes else &.{} } };
    if (std.mem.eql(u8, c.kind, "caller")) {
        var d = Caller.initWithOptions(history, callerOptions(c, buffers, 0));
        try exercise(init, &d, encoded, expected, output_path, c, buffers);
    } else {
        var d = Owned.initWithOptions(init.gpa, initialOwnedOptions(c, buffers));
        defer d.deinit();
        try exercise(init, &d, encoded, expected, output_path, c, buffers);
    }
}
fn read(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(64 * 1024 * 1024));
}
fn frameOutput(c: Config, i: usize) ?usize {
    return if (c.frame_output_lengths.len != 0) c.frame_output_lengths[i] else c.expected_output_len;
}
fn ownedOptions(c: Config, b: Buffers, i: usize) Owned.Options {
    return .{ .max_output_len = c.max_output_len, .max_total_output_len = c.max_total_output_len, .max_compressed_len = c.max_compressed_len, .expected_compressed_len = if (c.frame_input_lengths.len != 0) c.frame_input_lengths[i] else c.expected_compressed_len, .expected_output_len = frameOutput(c, i), .max_history_len = c.max_history_len, .max_compressed_header_len = c.max_compressed_header_len, .max_working_memory = c.max_working_memory, .decode = .{ .allow_large_window = c.allow_large_window, .shared_dictionary = b.dictionary }, .compressed_header_scratch = b.header, .metadata_output = b.metadata, .metadata_block_lengths = b.metadata_lengths, .allow_trailing_data = c.allow_trailing_data };
}
fn initialOwnedOptions(c: Config, b: Buffers) Owned.Options {
    var value = ownedOptions(c, b, 0);
    if (b.warmup_wire.len != 0) value.max_compressed_header_len = c.warmup_header_limit;
    return value;
}
fn callerOptions(c: Config, b: Buffers, i: usize) Caller.Options {
    return .{ .max_output_len = c.max_output_len, .max_total_output_len = c.max_total_output_len, .expected_output_len = frameOutput(c, i), .decode = .{ .allow_large_window = c.allow_large_window, .shared_dictionary = b.dictionary }, .compressed_header_scratch = b.header, .metadata_output = b.metadata, .metadata_block_lengths = b.metadata_lengths, .allow_trailing_data = c.allow_trailing_data };
}
fn opts(comptime D: type, c: Config, b: Buffers, i: usize) D.Options {
    var value = if (D == Owned) ownedOptions(c, b, i) else callerOptions(c, b, i);
    if (i != 0 and c.next_frame_default_operation_caps) {
        value.max_total_output_len = std.math.maxInt(usize);
        if (D == Owned) value.max_working_memory = std.math.maxInt(usize);
    }
    return value;
}
fn reconfigure(d: anytype, options: @TypeOf(d.*).Options) !void {
    const value = d.resetWithOptions(options);
    if (@TypeOf(value) != void) try value;
}
fn totalInput(s: anytype) usize {
    return s.total_compressed;
}
fn totalOutput(s: anytype) usize {
    return s.total_output;
}
fn update(r: *Report, d: anytype) void {
    const s = d.snapshot();
    r.max_retained_input = @max(r.max_retained_input, if (@hasField(@TypeOf(s), "retained_input_bytes")) s.retained_input_bytes else 0);
    r.max_header_capacity = @max(r.max_header_capacity, s.compressed_header_capacity);
    if (@TypeOf(d.*) == Owned) {
        r.max_owned_header_capacity = @max(r.max_owned_header_capacity, s.owned_compressed_header_capacity);
        r.max_history_capacity = @max(r.max_history_capacity, s.history_capacity);
        r.peak_working_bytes = @max(r.peak_working_bytes, s.peak_working_bytes);
        if (s.working_bytes != s.history_capacity + s.owned_compressed_header_capacity or s.working_bytes != d.workingMemoryBytes()) @panic("invalid heap accounting");
    } else r.max_history_capacity = d.history.len;
}
fn publish(a: std.mem.Allocator, actual: *std.ArrayList(u8), expected: []const u8, bytes: []const u8) !void {
    if (actual.items.len > expected.len or bytes.len > expected.len - actual.items.len or !std.mem.eql(u8, bytes, expected[actual.items.len..][0..bytes.len])) return error.InvalidPublishedPrefix;
    try actual.appendSlice(a, bytes);
}
fn guards(storage: []const u8, olen: usize) !void {
    for (storage[0..8]) |b| if (b != 0xa5) return error.CallerPrefixModified;
    for (storage[8 + olen ..]) |b| if (b != 0xa5) return error.CallerSuffixModified;
}
fn sticky(d: anytype, err: anyerror) !void {
    const before = d.snapshot();
    var output: [17]u8 = @splat(0xa5);
    if (d.step("retry", &output)) |_| return error.FatalRetrySucceeded else |again| if (again != err) return error.FatalRetryChanged;
    // A caller-owned header can be replaced before EOF is declared. That
    // resource error is repeatable, while finish would make it a truncation.
    if (!std.mem.eql(u8, d.diagnostics().recoverability_hint_name, "grow_compressed_header")) {
        if (d.finish()) |_| return error.FatalFinishSucceeded else |again| if (again != err) return error.FatalFinishChanged;
    }
    const after = d.snapshot();
    for (output) |byte| if (byte != 0xa5) return error.FatalRetryOutputModified;
    if (totalInput(after) != totalInput(before) or totalOutput(after) != totalOutput(before) or after.last_step_progress.input_read != 0 or after.last_step_progress.output_written != 0 or after.error_input_offset != before.error_input_offset or after.error_output_offset != before.error_output_offset) return error.FatalRetryProgressChanged;
}
fn decode(a: std.mem.Allocator, original: anytype, encoded: []const u8, expected: []const u8, c: Config, b: Buffers, actual: *std.ArrayList(u8)) !Report {
    const D = @TypeOf(original.*);
    var d = original;
    var relocated: D = undefined;
    var moved = false;
    defer if (moved) {
        original.* = relocated;
    };
    var r = Report{};
    var finished = false;
    var frame_start: usize = 0;
    var storage: [8208]u8 = undefined;
    const ins = [_]usize{ 0, 1, 3, 0, 7, 31, 4096 };
    const outs = [_]usize{ 0, 1, 0, 7, 31, 64, 273 };
    while (r.steps < encoded.len * 8 + expected.len * 8 + 10000) {
        if (c.move_after_steps) |at| if (!moved and r.steps >= at) {
            relocated = d.*;
            d.* = undefined;
            d = &relocated;
            moved = true;
            r.moves += 1;
        };
        const wide_input = std.mem.eql(u8, c.pattern, "wide") or std.mem.eql(u8, c.pattern, "wide_zero");
        const ilen = if (std.mem.eql(u8, c.pattern, "one")) 1 else if (wide_input) encoded.len else ins[r.steps % ins.len];
        const olen = if (std.mem.eql(u8, c.pattern, "one")) 1 else if (std.mem.eql(u8, c.pattern, "wide")) 31 else outs[r.steps % outs.len];
        const frame_end = if (c.frame_input_lengths.len != 0) frame_start + c.frame_input_lengths[r.frames] else encoded.len;
        const end = r.input_read + @min(frame_end - r.input_read, ilen);
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
            try guards(&storage, olen);
            update(&r, d);
            if (D == Caller and c.grow_header_on_exhaustion and std.mem.eql(u8, d.diagnostics().recoverability_hint_name, "grow_compressed_header")) {
                try d.replaceCompressedHeaderScratch(b.replacement);
                const recovered = d.snapshot();
                if (recovered.last_error_name.len != 0 or recovered.error_input_offset != null or recovered.error_output_offset != null or totalInput(recovered) != totalInput(after) or totalOutput(recovered) != totalOutput(after)) return error.HeaderRetryStateChanged;
                r.header_retry_checks += 1;
                continue;
            }
            r.@"error" = @errorName(err);
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
        update(&r, d);
        if (step.status == .done) {
            r.frames += 1;
            if (r.input_read != frame_end and !c.allow_trailing_data) return error.TrailingInputIgnored;
            if (c.frame_input_lengths.len == 0 or r.frames == c.frame_input_lengths.len) return r;
            if (c.check_next_frame_retry and D == Owned) {
                const live = d.workingMemoryBytes();
                if (live != 0) {
                    var narrow = opts(D, c, b, r.frames);
                    narrow.max_working_memory = live - 1;
                    if (d.nextFrame(narrow)) |_| return error.NarrowNextFrameSucceeded else |err| if (err != error.WorkingMemoryLimitExceeded) return err;
                    const unchanged = d.snapshot();
                    if (totalInput(unchanged) != totalInput(after) or totalOutput(unchanged) != totalOutput(after) or unchanged.phase != .done or unchanged.last_error_name.len != 0) return error.NextFrameRetryStateChanged;
                    r.next_frame_retry_checks += 1;
                }
            }
            try d.nextFrame(opts(D, c, b, r.frames));
            frame_start = frame_end;
            finished = false;
            continue;
        }
        if (!finished and r.input_read == frame_end and step.status == .need_input) {
            d.finish() catch |err| {
                r.@"error" = @errorName(err);
                update(&r, d);
                try sticky(d, err);
                r.sticky_checks += 1;
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
fn resetCheck(a: std.mem.Allocator, d: anytype, encoded: []const u8, expected: []const u8, c: Config, b: Buffers) !void {
    const s = d.snapshot();
    if (totalInput(s) != 0 or totalOutput(s) != 0 or s.last_error_name.len != 0 or s.error_input_offset != null or s.error_output_offset != null) return error.ResetStateNotCleared;
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(a);
    const r = try decode(a, d, encoded, expected, c, b, &actual);
    try validate(r, actual.items, expected, c.expect_failure);
}
// Reach retained owned scratch using public lifecycle methods: a legal large
// header hits a tighter header cap, reset retains that heap, a small independent
// frame finishes, and nextFrame raises only the header cap for the large frame.
fn warmup(a: std.mem.Allocator, d: *Owned, encoded: []const u8, expected: []const u8, c: Config, b: Buffers) !Report {
    if (b.warmup_wire.len == 0) return .{};
    var warm = c;
    warm.pattern = "wide";
    warm.move_after_steps = null;
    warm.frame_input_lengths = &.{};
    warm.frame_output_lengths = &.{};
    warm.expected_compressed_len = null;
    warm.expect_failure = true;
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(a);
    const limited = try decode(a, d, encoded, expected, warm, b, &actual);
    if (limited.@"error") |name| {
        if (std.mem.eql(u8, name, "OutOfMemory")) return error.OutOfMemory;
        if (!std.mem.eql(u8, name, "OutputLimitExceeded")) return error.UnexpectedWarmupError;
    } else return error.WarmupLimitNotReached;
    if (limited.output_written != 0 or d.snapshot().owned_compressed_header_capacity != c.warmup_header_limit) return error.WarmupRetentionMismatch;
    d.reset();
    actual.clearRetainingCapacity();
    warm.expect_failure = false;
    const small = try decode(a, d, b.warmup_wire, expected, warm, b, &actual);
    if (small.@"error") |name| {
        if (std.mem.eql(u8, name, "OutOfMemory")) return error.OutOfMemory;
        return error.WarmupSmallFrameFailed;
    }
    try validate(small, actual.items, expected, false);
    try d.nextFrame(ownedOptions(c, b, 0));
    return .{ .warmup_input_read = small.input_read, .warmup_output_written = small.output_written, .reset_checks = 1 };
}
fn exercise(init: std.process.Init, d: anytype, encoded: []const u8, expected: []const u8, output_path: []const u8, c: Config, b: Buffers) !void {
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(init.gpa);
    const primed = if (@TypeOf(d.*) == Owned) try warmup(init.gpa, d, encoded, expected, c, b) else Report{};
    var r = try decode(init.gpa, d, encoded, expected, c, b, &actual);
    r.warmup_input_read = primed.warmup_input_read;
    r.warmup_output_written = primed.warmup_output_written;
    r.reset_checks = primed.reset_checks;
    try validate(r, actual.items, expected, c.expect_failure);
    if (c.reset_after) {
        d.reset();
        // reset retains the last member's options. Restore the first member's
        // size contract when replaying a heterogeneous operation.
        if (c.frame_input_lengths.len != 0) try reconfigure(d, opts(@TypeOf(d.*), c, b, 0));
        try resetCheck(init.gpa, d, encoded, expected, c, b);
        try reconfigure(d, opts(@TypeOf(d.*), c, b, 0));
        try resetCheck(init.gpa, d, encoded, expected, c, b);
        r.reset_checks += 2;
    }
    if (c.oom and @TypeOf(d.*) == Owned) r.oom_failure_cases = try oomCheck(init.gpa, encoded, expected, c, b);
    const inner = if (@TypeOf(d.*) == Owned) if (d.progressive) |*value| value.snapshot() else null else d.snapshot();
    const mlen = if (@TypeOf(d.*) == Owned) if (inner) |s| s.metadata_written else 0 else inner.metadata_written;
    const mblocks = if (@TypeOf(d.*) == Owned) if (inner) |s| s.metadata_blocks_captured else 0 else inner.metadata_blocks_captured;
    const mhex = try init.gpa.alloc(u8, mlen * 2);
    defer init.gpa.free(mhex);
    const digits = "0123456789abcdef";
    for (b.metadata[0..mlen], 0..) |byte, i| {
        mhex[2 * i] = digits[byte >> 4];
        mhex[2 * i + 1] = digits[byte & 15];
    }
    r.metadata_hex = mhex;
    const trailing = d.trailingInput();
    const thex = try init.gpa.alloc(u8, trailing.len * 2);
    defer init.gpa.free(thex);
    for (trailing, 0..) |byte, i| {
        thex[2 * i] = digits[byte >> 4];
        thex[2 * i + 1] = digits[byte & 15];
    }
    r.trailing_hex = thex;
    r.metadata_lengths = b.metadata_lengths[0..mblocks];
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
    const json = try std.json.Stringify.valueAlloc(init.gpa, r, .{});
    defer init.gpa.free(json);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = actual.items });
    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    try stdout.interface.writeAll(json);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}
fn oomCheck(a: std.mem.Allocator, encoded: []const u8, expected: []const u8, c: Config, b: Buffers) !usize {
    var cases: usize = 0;
    inline for (.{ false, true }) |deny_resize| {
        for (0..1024) |index| {
            var failing = std.testing.FailingAllocator.init(a, .{ .fail_index = index, .resize_fail_index = if (deny_resize) 0 else std.math.maxInt(usize) });
            var d = Owned.initWithOptions(failing.allocator(), initialOwnedOptions(c, b));
            _ = warmup(a, &d, encoded, expected, c, b) catch |err| {
                if (err != error.OutOfMemory) return err;
                cases += 1;
                failing.fail_index = std.math.maxInt(usize);
                try d.resetWithOptions(initialOwnedOptions(c, b));
                _ = try warmup(a, &d, encoded, expected, c, b);
                var retry: std.ArrayList(u8) = .empty;
                defer retry.deinit(a);
                const recovered = try decode(a, &d, encoded, expected, c, b, &retry);
                try validate(recovered, retry.items, expected, false);
                d.deinit();
                if (failing.allocated_bytes != failing.freed_bytes) return error.AllocationLeak;
                continue;
            };
            var actual: std.ArrayList(u8) = .empty;
            defer actual.deinit(a);
            const r = try decode(a, &d, encoded, expected, c, b, &actual);
            if (failing.allocated_bytes - failing.freed_bytes != d.workingMemoryBytes()) return error.LiveHeapAccountingMismatch;
            if (r.@"error") |name| {
                if (!std.mem.eql(u8, name, "OutOfMemory")) return error.UnexpectedAllocationError;
                cases += 1;
                d.reset();
                failing.fail_index = std.math.maxInt(usize);
                try resetCheck(a, &d, encoded, expected, c, b);
                try d.resetWithOptions(ownedOptions(c, b, 0));
                try resetCheck(a, &d, encoded, expected, c, b);
            } else try validate(r, actual.items, expected, false);
            d.deinit();
            if (failing.allocated_bytes != failing.freed_bytes) return error.AllocationLeak;
            if (!failing.has_induced_failure) break;
            if (index == 1023) return error.AllocationWalkLimit;
        }
    }
    return cases;
}
