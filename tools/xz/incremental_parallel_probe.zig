//! Public persistent-parallel XZ protocol probe; all payloads are file-driven.
const std = @import("std");
const builtin = @import("builtin");
const xz = @import("xz");

const Scenario = enum { normal, flush, concat, reset, move, partial_credit, pending_retry, input_retry, heap_sticky };
const Config = struct {
    operation: enum { encode, decode } = .encode,
    parallel: bool = true,
    scenario: Scenario = .normal,
    check: xz.Check = .crc64,
    include_block_sizes: bool = true,
    payload: enum { stored, compressed } = .compressed,
    parser: xz.Parser = .greedy,
    preset: ?u32 = null,
    block_size: usize = 4096,
    chunk_size: usize = 4096,
    dictionary_size: usize = 4096,
    codec_memory_limit: ?usize = null,
    filters: []const xz.Filter = &.{},
    worker_count: usize = 3,
    max_inflight_blocks: usize = 4,
    max_inflight_bytes: usize = 16384,
    max_working_memory: usize = 128 * 1024 * 1024,
    max_pending_output_len: usize = 1024 * 1024,
    max_input_len: usize = 2 * 1024 * 1024,
    max_output_len: usize = 2 * 1024 * 1024,
    input_chunk: usize = 4096,
    flush_at: ?usize = null,
    next_parallel: ?bool = null,
};
const Point = struct { stage: []const u8, frame: usize, snapshot: xz.IncrementalEncoder.Snapshot };
const Frame = struct { start: usize, bytes: usize, input_bytes: usize, input_sha256: [64]u8 };
const Recovery = struct { error_name: []const u8, input_read: usize, output_written: usize, snapshot: xz.IncrementalEncoder.Snapshot };
const Report = struct {
    steps: usize = 0,
    input_read: usize = 0,
    output_written: usize = 0,
    zero_input_offers: usize = 0,
    zero_output_offers: usize = 0,
    staging_overwrites: usize = 0,
    overwrites_with_jobs: usize = 0,
    moves: usize = 0,
    move_with_jobs: bool = false,
    startup_zero_output_verified: bool = false,
    flush_acknowledgements: usize = 0,
    sticky_checks: usize = 0,
    serial_wire_equal: bool = false,
    serial_one_shot_equal: ?bool = null,
    self_decode_verified: bool = false,
    caller_guards_verified: bool = true,
    deinit_profile_live_bytes: usize = 0,
    profile: xz.ParallelProfile = .{},
    peak_active_workers: usize = 0,
    peak_inflight_blocks: usize = 0,
    peak_inflight_bytes: usize = 0,
    peak_requested_bytes: usize = 0,
    points: std.ArrayList(Point) = .empty,
    frames: std.ArrayList(Frame) = .empty,
    recoveries: std.ArrayList(Recovery) = .empty,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const input_path = args.next() orelse return error.MissingInput;
    const wire_path = args.next() orelse return error.MissingOutput;
    const config_path = args.next() orelse return error.MissingConfig;
    if (args.next() != null) return error.TooManyArguments;
    const input = try read(init, input_path);
    defer init.gpa.free(input);
    const configuration = try read(init, config_path);
    defer init.gpa.free(configuration);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, configuration, .{});
    defer parsed.deinit();
    const c = parsed.value;
    if (c.input_chunk == 0 or c.input_chunk > 65536 or (c.flush_at orelse 0) > input.len) return error.InvalidConfig;
    var report: Report = .{};
    defer report.points.deinit(init.gpa);
    defer report.frames.deinit(init.gpa);
    defer report.recoveries.deinit(init.gpa);
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(init.gpa);
    const input_sha = digest(input);
    var failure: ?[]const u8 = null;
    if (c.operation == .decode) {
        const decoded: ?[]u8 = xz.decodeConcatenatedAllocLimited(init.gpa, input, c.max_output_len) catch |err| blk: {
            failure = @errorName(err);
            break :blk null;
        };
        defer if (decoded) |bytes| init.gpa.free(bytes);
        if (decoded) |bytes| try wire.appendSlice(init.gpa, bytes);
    } else exercise(init, input, wire_path, c, &report, &wire) catch |err| {
        failure = @errorName(err);
    };
    const after_sha = digest(input);
    if (!std.mem.eql(u8, &input_sha, &after_sha)) return error.OriginalInputChanged;
    const output_sha = digest(wire.items);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = wire_path, .data = wire.items });
    const json = try std.json.Stringify.valueAlloc(init.gpa, .{
        .schema = "vort.xz.incremental-parallel-probe.v1",
        .config = c,
        .@"error" = failure,
        .input_bytes = input.len,
        .input_sha256 = input_sha[0..],
        .output_bytes = wire.items.len,
        .output_sha256 = output_sha[0..],
        .steps = report.steps,
        .input_read = report.input_read,
        .output_written = report.output_written,
        .zero_input_offers = report.zero_input_offers,
        .zero_output_offers = report.zero_output_offers,
        .staging_overwrites = report.staging_overwrites,
        .overwrites_with_jobs = report.overwrites_with_jobs,
        .moves = report.moves,
        .move_with_jobs = report.move_with_jobs,
        .startup_zero_output_verified = report.startup_zero_output_verified,
        .flush_acknowledgements = report.flush_acknowledgements,
        .sticky_checks = report.sticky_checks,
        .serial_wire_equal = report.serial_wire_equal,
        .serial_one_shot_equal = report.serial_one_shot_equal,
        .self_decode_verified = report.self_decode_verified,
        .caller_guards_verified = report.caller_guards_verified,
        .deinit_profile_live_bytes = report.deinit_profile_live_bytes,
        .profile = report.profile,
        .peak_active_workers = report.peak_active_workers,
        .peak_inflight_blocks = report.peak_inflight_blocks,
        .peak_inflight_bytes = report.peak_inflight_bytes,
        .peak_requested_bytes = report.peak_requested_bytes,
        .snapshots = report.points.items,
        .frames = report.frames.items,
        .recoveries = report.recoveries.items,
        .target = @tagName(builtin.cpu.arch),
        .cpu_model = builtin.cpu.model.name,
        .build_mode = @tagName(builtin.mode),
        .zig_version = builtin.zig_version_string,
        .scope = "actual incremental parallel jobs, owned accepted input, ordered publication/delivery and bounded caller protocol; no timing",
    }, .{});
    defer init.gpa.free(json);
    try std.Io.File.stdout().writeStreamingAll(init.io, json);
    try std.Io.File.stdout().writeStreamingAll(init.io, "\n");
}
fn options(init: std.process.Init, c: Config, profile: ?*xz.ParallelProfile) !xz.IncrementalEncoder.Options {
    var opts = if (c.preset) |level| try xz.IncrementalEncoder.Options.fromPreset(level, false) else xz.IncrementalEncoder.Options{ .parser = c.parser, .dictionary_size = c.dictionary_size };
    opts.check = c.check;
    opts.include_block_sizes = c.include_block_sizes;
    opts.payload_encoding = if (c.payload == .stored) .stored else .compressed;
    opts.block_size = c.block_size;
    opts.chunk_size = c.chunk_size;
    opts.filters = c.filters;
    if (c.codec_memory_limit) |limit| opts.match_options = .{ .finder = .hc4, .nice_len = 32, .depth = 8, .max_working_memory = limit };
    opts.max_input_len = c.max_input_len;
    opts.max_pending_output_len = c.max_pending_output_len;
    if (c.parallel) opts.parallel = .{ .io = init.io, .worker_count = c.worker_count, .max_inflight_blocks = c.max_inflight_blocks, .max_inflight_bytes = c.max_inflight_bytes, .max_working_memory = c.max_working_memory, .profile = profile };
    return opts;
}
fn remember(a: std.mem.Allocator, r: *Report, encoder: *xz.IncrementalEncoder, stage: []const u8, frame: usize) !void {
    const snapshot = encoder.snapshot();
    try r.points.append(a, .{ .stage = stage, .frame = frame, .snapshot = snapshot });
    const p = snapshot.parallel;
    r.peak_active_workers = @max(r.peak_active_workers, p.peak_active_workers);
    r.peak_inflight_blocks = @max(r.peak_inflight_blocks, p.inflight_blocks);
    r.peak_inflight_bytes = @max(r.peak_inflight_bytes, p.inflight_bytes);
    r.peak_requested_bytes = @max(r.peak_requested_bytes, p.peak_requested_bytes);
}
fn callStep(a: std.mem.Allocator, r: *Report, encoder: *xz.IncrementalEncoder, offered: []u8, capacity: usize, wire: *std.ArrayList(u8)) !struct { status: enum { need_input, need_output, done }, input_read: usize } {
    var guarded: [65552]u8 = undefined;
    @memset(&guarded, 0xa5);
    const before = encoder.snapshot();
    var failure: ?anyerror = null;
    const StepResult = @typeInfo(@TypeOf(encoder.step(offered, guarded[8..][0..capacity]))).error_union.payload;
    const result: ?StepResult = encoder.step(offered, guarded[8..][0..capacity]) catch |err| blk: {
        failure = err;
        break :blk null;
    };
    const after = encoder.snapshot();
    const read_count = after.input_read - before.input_read;
    const written = after.output_written - before.output_written;
    if (read_count > offered.len or written > capacity) return error.InvalidProgress;
    if (result) |value| if (value.progress.input_read != read_count or value.progress.output_written != written) return error.SnapshotProgressMismatch;
    if (after.parallel.enabled and (after.parallel.last_step_progress.input_read != read_count or after.parallel.last_step_progress.output_written != written)) return error.LastStepProgressMismatch;
    for (guarded[0..8]) |byte| if (byte != 0xa5) return error.OutputGuardChanged;
    for (guarded[8 + written ..]) |byte| if (byte != 0xa5) return error.OutputGuardChanged;
    try wire.appendSlice(a, guarded[8..][0..written]);
    r.steps += 1;
    r.input_read += read_count;
    r.output_written += written;
    if (offered.len == 0) r.zero_input_offers += 1;
    if (capacity == 0) r.zero_output_offers += 1;
    if (read_count != 0) {
        @memset(offered, 0xcc);
        r.staging_overwrites += 1;
        if (after.parallel.active_blocks + after.parallel.queued_blocks != 0) r.overwrites_with_jobs += 1;
    }
    if (failure) |err| {
        try r.recoveries.append(a, .{ .error_name = @errorName(err), .input_read = read_count, .output_written = written, .snapshot = after });
        return err;
    }
    const status = result.?.status;
    return .{ .status = @enumFromInt(@intFromEnum(status)), .input_read = read_count };
}
fn exercise(init: std.process.Init, input: []const u8, wire_path: []const u8, c: Config, r: *Report, wire: *std.ArrayList(u8)) !void {
    var original = try xz.IncrementalEncoder.initExactSize(init.gpa, try options(init, c, &r.profile), input.len);
    var moved: xz.IncrementalEncoder = undefined;
    var encoder = &original;
    defer {
        encoder.deinit();
        r.deinit_profile_live_bytes = r.profile.live_requested_bytes;
    }
    try remember(init.gpa, r, encoder, "initial", 0);
    if (c.parallel) {
        var offered: [1]u8 = .{if (input.len == 0) 0 else input[0]};
        const result = try callStep(init.gpa, r, encoder, offered[0..@intFromBool(input.len != 0)], 0, wire);
        const snapshot = encoder.snapshot();
        if (result.input_read != 0 or result.status != .need_output or snapshot.pending_output != 12) return error.InvalidZeroOutputStartup;
        r.startup_zero_output_verified = true;
        try remember(init.gpa, r, encoder, "zero_output_startup", 0);
    }
    try pump(init.gpa, input, c, &encoder, &original, &moved, wire, r, 0);
    if (c.scenario == .concat or c.scenario == .reset) {
        var next = c;
        next.parallel = c.next_parallel orelse !c.parallel;
        next.scenario = .normal;
        next.flush_at = null;
        if (c.scenario == .reset) {
            encoder.reset();
            next.parallel = c.parallel;
        } else try encoder.nextStreamExactSize(try options(init, next, &r.profile), input.len);
        try remember(init.gpa, r, encoder, "next_stream_initial", 1);
        try pump(init.gpa, input, next, &encoder, &original, &moved, wire, r, 1);
    }
    var serial = c;
    serial.parallel = false;
    serial.max_input_len = 2 * 1024 * 1024;
    serial.max_pending_output_len = 1024 * 1024;
    if (serial.scenario == .partial_credit) {
        serial.scenario = .flush;
        serial.flush_at = c.max_inflight_bytes;
    }
    if (serial.scenario == .pending_retry or serial.scenario == .input_retry or serial.scenario == .move) serial.scenario = .normal;
    var serial_original = try xz.IncrementalEncoder.initExactSize(init.gpa, try options(init, serial, null), input.len);
    defer serial_original.deinit();
    var serial_ptr = &serial_original;
    var serial_moved: xz.IncrementalEncoder = undefined;
    var serial_wire: std.ArrayList(u8) = .empty;
    defer serial_wire.deinit(init.gpa);
    var serial_report: Report = .{};
    defer serial_report.points.deinit(init.gpa);
    defer serial_report.frames.deinit(init.gpa);
    defer serial_report.recoveries.deinit(init.gpa);
    try pump(init.gpa, input, serial, &serial_ptr, &serial_original, &serial_moved, &serial_wire, &serial_report, 0);
    if (c.scenario == .concat or c.scenario == .reset) {
        try serial_original.nextStreamExactSize(try options(init, serial, null), input.len);
        var second = serial;
        second.scenario = .normal;
        second.flush_at = null;
        try pump(init.gpa, input, second, &serial_ptr, &serial_original, &serial_moved, &serial_wire, &serial_report, 1);
    }
    r.serial_wire_equal = std.mem.eql(u8, serial_wire.items, wire.items);
    const serial_path = try std.fmt.allocPrint(init.gpa, "{s}.serial.xz", .{wire_path});
    defer init.gpa.free(serial_path);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = serial_path, .data = serial_wire.items });
    if (r.frames.items.len == 1 and serial.flush_at == null) {
        const serial_options = (try options(init, serial, null)).writerOptions();
        const once = if (c.payload == .stored) try xz.encodeStoredAlloc(init.gpa, input, serial_options) else try xz.encodeAlloc(init.gpa, input, serial_options);
        defer init.gpa.free(once);
        r.serial_one_shot_equal = std.mem.eql(u8, once, wire.items);
    }
    const restored = if (r.frames.items.len > 1) try xz.decodeConcatenatedAllocLimited(init.gpa, wire.items, input.len * r.frames.items.len) else try xz.decodeAllocLimited(init.gpa, wire.items, input.len);
    defer init.gpa.free(restored);
    if (restored.len != input.len * r.frames.items.len) return error.RoundTripMismatch;
    for (0..r.frames.items.len) |index| if (!std.mem.eql(u8, input, restored[index * input.len ..][0..input.len])) return error.RoundTripMismatch;
    r.self_decode_verified = true;
}
fn pump(a: std.mem.Allocator, input: []const u8, c: Config, encoder_ptr: **xz.IncrementalEncoder, original: *xz.IncrementalEncoder, moved: *xz.IncrementalEncoder, wire: *std.ArrayList(u8), r: *Report, frame: usize) !void {
    const start = wire.items.len;
    var offset: usize = 0;
    var finishing = false;
    var flush_pending = false;
    var flushed = c.flush_at == null;
    var partial_recovered = false;
    var pending_recovered = false;
    var input_recovered = false;
    var stage: [65536]u8 = undefined;
    var local_step: usize = 0;
    const capacities = [_]usize{ 0, 1, 0, 31, 4096, 65536 };
    while (local_step < input.len * 16 + 8192) : (local_step += 1) {
        const encoder = encoder_ptr.*;
        if (!flushed and !flush_pending and offset == c.flush_at.?) {
            encoder.flush();
            flush_pending = true;
        }
        if (offset == input.len and !finishing and !flush_pending) {
            encoder.finish();
            finishing = true;
        }
        var count = @min(input.len - offset, if (local_step % 3 == 0) @as(usize, 0) else c.input_chunk);
        if (!flushed) count = @min(count, c.flush_at.? - offset);
        if (flush_pending or finishing) count = 0;
        @memcpy(stage[0..count], input[offset..][0..count]);
        const capacity = capacities[local_step % capacities.len];
        const recovery_count = r.recoveries.items.len;
        const result = callStep(a, r, encoder, stage[0..count], capacity, wire) catch |err| {
            if (r.recoveries.items.len == recovery_count) return err;
            const delta = r.recoveries.items[r.recoveries.items.len - 1].input_read;
            offset += delta;
            try remember(a, r, encoder, "error", frame);
            if (c.scenario == .partial_credit and err == error.WorkingMemoryLimitExceeded and !partial_recovered) {
                encoder.flush();
                flush_pending = true;
                partial_recovered = true;
                continue;
            }
            if (c.scenario == .pending_retry and err == error.OutputLimitExceeded and !pending_recovered) {
                encoder.options.max_pending_output_len = 1024 * 1024;
                pending_recovered = true;
                continue;
            }
            if (c.scenario == .input_retry and err == error.OutputLimitExceeded and !input_recovered) {
                encoder.options.max_input_len = 2 * 1024 * 1024;
                input_recovered = true;
                continue;
            }
            if (c.scenario == .heap_sticky) {
                const before = encoder.snapshot();
                var empty: [0]u8 = .{};
                _ = callStep(a, r, encoder, &empty, 0, wire) catch |again| {
                    const after = encoder.snapshot();
                    if (again != err or after.input_read != before.input_read or after.output_written != before.output_written) return error.StickyErrorChanged;
                    r.sticky_checks += 1;
                    return err;
                };
                return error.ExpectedStickyError;
            }
            return err;
        };
        offset += result.input_read;
        const snapshot = encoder.snapshot();
        if (r.points.items.len < 256 and (result.input_read != 0 or result.status == .done or flush_pending)) try remember(a, r, encoder, "step", frame);
        if (c.scenario == .move and r.moves == 0 and snapshot.parallel.queued_blocks + snapshot.parallel.active_blocks > 0) {
            moved.* = encoder.*;
            original.* = undefined;
            encoder_ptr.* = moved;
            r.moves += 1;
            r.move_with_jobs = true;
            try remember(a, r, encoder_ptr.*, "moved_with_jobs", frame);
        }
        if (flush_pending and result.status == .need_input) {
            flush_pending = false;
            flushed = true;
            r.flush_acknowledgements += 1;
            try remember(a, r, encoder_ptr.*, "flush_acknowledged", frame);
        }
        if (result.status == .done) {
            if (offset != input.len) return error.InputAccountingMismatch;
            const done = encoder_ptr.*.snapshot();
            if (done.parallel.enabled and (done.parallel.inflight_bytes != 0 or done.parallel.delivered_blocks != done.parallel.accepted_blocks)) return error.DoneWithUndeliveredBlocks;
            try r.frames.append(a, .{ .start = start, .bytes = wire.items.len - start, .input_bytes = input.len, .input_sha256 = digest(input) });
            try remember(a, r, encoder_ptr.*, "done", frame);
            return;
        }
    }
    return error.IncrementalDidNotFinish;
}
fn digest(data: []const u8) [64]u8 {
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(data, &hash, .{});
    return std.fmt.bytesToHex(hash, .lower);
}
fn read(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(4 * 1024 * 1024));
}
