//! Paired whole-call child protocol. Hash/load/decode are outside sample clocks.
const std = @import("std");
const builtin = @import("builtin");
const br = @import("br.zig");
const provenance = @import("audit_benchmark_provenance.zig");
const drive = @import("tests/br_total_memory_helpers.zig").drive;
const a = std.heap.c_allocator;

extern "c" fn read(fd: c_int, bytes: [*]u8, count: usize) isize;
extern "c" fn open(path: [*:0]const u8, flags: c_int, ...) c_int;
extern "c" fn close(fd: c_int) c_int;
extern "c" fn sched_getcpu() c_int;
extern "c" fn gnu_get_libc_version() [*:0]const u8;
extern fn vortBrStableFixedWidthRecord(input: [*]const u8, length: usize) callconv(.c) u8;

const Api = enum { one_shot, reusable, chunked, incremental };
const Kind = enum { plain, raw, serialized_raw, hq };
const Spec = struct { id: usize, name: []const u8, group: []const u8, path: []const u8, input_bytes: usize, input_sha256: []const u8, quality: u4, api: Api, kind: Kind, expected_record: bool, mode: br.PlannedMode, window_bits: u5, command_state_max_input_kib: u8, lifecycle: []const u8 };
const Manifest = struct { schema: []const u8, target_scope: []const u8, rows: []const Spec };
const Runtime = struct {
    spec: Spec,
    input: []u8,
    raw: [1][]const u8,
    serialized: br.SerializedSharedDictionary,
    encoder: ?*br.PlannedStreamEncoder = null,
    expected_wire: []u8,
    input_hash: [64]u8,
    wire_hash: [64]u8,
};
const Metadata = struct { spec: Spec, input_sha256: []const u8, wire_sha256: []const u8, wire_bytes: usize, first_byte: u8, record_eligible: bool, decoded_equal: bool = true, warmup_calls: usize = 1, retained_capacity_after_warmup: usize };
const Command = struct { op: enum { sample, calibrate, quit }, row: usize = 0, iterations: usize = 1 };
const serialized_bytes = [_]u8{ 0x91, 0, 3, 'r', 'a', 'w', 0, 0 };

fn load(io: std.Io, path: []const u8) ![]u8 {
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    const stat = try file.stat(io);
    const bytes = try a.alloc(u8, @intCast(stat.size));
    errdefer a.free(bytes);
    var buffer: [4096]u8 = undefined;
    var reader = file.reader(io, &buffer);
    if (try reader.interface.readSliceShort(bytes) != bytes.len) return error.TruncatedInput;
    return bytes;
}

fn dictionary(case: *const Runtime) br.SharedDictionary {
    return switch (case.spec.kind) {
        .raw => .{ .raw_prefixes = &case.raw },
        .serialized_raw => .{ .serialized = &case.serialized },
        else => .{},
    };
}

fn encode(case: *Runtime) ![]u8 {
    const hq: ?br.HqOptions = if (case.spec.kind == .hq) .{ .block_len = case.input.len, .search_depth = 8, .nice_len = 32, .beam_width = 2, .iterations = 1 } else null;
    const options: br.PlannedEncodeOptions = .{ .quality = case.spec.quality, .mode = case.spec.mode, .window_bits = case.spec.window_bits, .command_state_max_input_kib = case.spec.command_state_max_input_kib, .shared_dictionary = dictionary(case), .hq = hq };
    const stream: br.PlannedStreamChunksOptions = .{ .quality = case.spec.quality, .mode = case.spec.mode, .window_bits = case.spec.window_bits, .command_state_max_input_kib = case.spec.command_state_max_input_kib, .shared_dictionary = dictionary(case), .hq = hq, .block_len = case.input.len, .adaptive_blocks = false };
    return switch (case.spec.api) {
        .one_shot => br.encodePlannedStreamWithOptionsAlloc(a, case.input, options),
        .reusable => case.encoder.?.encodeWithOptionsAlloc(a, case.input, options),
        .chunked => br.encodePlannedStreamChunksWithOptionsAlloc(a, &.{ case.input[0 .. case.input.len / 3], case.input[case.input.len / 3 .. case.input.len * 2 / 3], case.input[case.input.len * 2 / 3 ..] }, stream),
        .incremental => block: {
            var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(a, .{ .stream = stream, .block_len = case.input.len });
            defer encoder.deinit();
            break :block drive(a, &encoder, case.input, 257, 17);
        },
    };
}

fn threads() !usize {
    const fd = open("/proc/self/status", 0);
    if (fd < 0) return error.ProcStatusUnavailable;
    defer _ = close(fd);
    var buffer: [16384]u8 = undefined;
    const n = read(fd, &buffer, buffer.len);
    if (n <= 0) return error.ProcStatusUnavailable;
    var lines = std.mem.splitScalar(u8, buffer[0..@intCast(n)], '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "Threads:")) return std.fmt.parseInt(usize, std.mem.trim(u8, line[8..], " \t"), 10);
    }
    return error.ProcThreadsMissing;
}

fn readCommandLine(buffer: []u8) !?[]const u8 {
    var length: usize = 0;
    while (length < buffer.len) {
        var byte: [1]u8 = undefined;
        const n = read(0, &byte, 1);
        if (n == 0) return if (length == 0) null else error.PartialCommand;
        if (n != 1) return error.CommandReadFailed;
        if (byte[0] == '\n') return buffer[0..length];
        buffer[length] = byte[0];
        length += 1;
    }
    return error.CommandTooLong;
}

fn write(io: std.Io, value: anytype) !void {
    const json = try std.json.Stringify.valueAlloc(a, value, .{});
    defer a.free(json);
    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(io, &buffer);
    try stdout.interface.writeAll(json);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}

fn check(case: *Runtime) !void {
    const wire = try encode(case);
    defer a.free(wire);
    if (!std.mem.eql(u8, wire, case.expected_wire)) return error.SuccessWireChanged;
}

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, a);
    defer args.deinit();
    _ = args.next();
    var manifest_path: ?[]const u8 = null;
    var requested_command_state: ?u8 = null;
    var requested_mode: ?[]const u8 = null;
    while (args.next()) |argument| {
        if (std.mem.startsWith(u8, argument, "--cases=")) manifest_path = argument[8..] else if (std.mem.startsWith(u8, argument, "--command-state-max-input-kib=")) requested_command_state = try std.fmt.parseInt(u8, argument[30..], 10) else if (std.mem.startsWith(u8, argument, "--mode=")) requested_mode = argument[7..] else return error.UnexpectedArgument;
    }
    if (requested_command_state != 8 or !std.mem.eql(u8, requested_mode orelse "", "generic")) return error.UnmatchedPolicy;
    const bytes = try load(init.io, manifest_path orelse return error.MissingCases);
    defer a.free(bytes);
    const parsed = try std.json.parseFromSlice(Manifest, a, bytes, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    const info = try provenance.capture(init.io, a, init.minimal.args, "single");
    defer info.deinit(a);
    const cases = try a.alloc(Runtime, parsed.value.rows.len);
    defer a.free(cases);
    var initialized: usize = 0;
    defer for (cases[0..initialized]) |case| {
        if (case.encoder) |encoder| {
            encoder.deinit();
            a.destroy(encoder);
        }
        a.free(case.expected_wire);
        a.free(case.input);
    };
    const metadata = try a.alloc(Metadata, cases.len);
    defer a.free(metadata);
    for (parsed.value.rows, cases, metadata, 0..) |spec, *case, *meta, id| {
        const expected_command_state: u8 = if (spec.quality >= 10) 8 else 255;
        if (spec.id != id or spec.command_state_max_input_kib != expected_command_state or spec.mode != .generic) return error.UnmatchedPolicy;
        const input = try load(init.io, spec.path);
        if (input.len != spec.input_bytes or input.len < 32) return error.InputSizeChanged;
        const input_hash = provenance.sha256Hex(input);
        if (!std.mem.eql(u8, &input_hash, spec.input_sha256)) return error.InputHashChanged;
        const eligible = input.len >= 4096 and input.len <= 65536 and input[input.len - 1] == '\n' and vortBrStableFixedWidthRecord(input.ptr, input.len) != 0;
        if (eligible != spec.expected_record) return error.RecordClassificationChanged;
        case.* = .{ .spec = spec, .input = input, .raw = .{input[0..32]}, .serialized = try br.parseSerializedSharedDictionary(&serialized_bytes), .expected_wire = &.{}, .input_hash = input_hash, .wire_hash = undefined };
        if (spec.api == .reusable) {
            case.encoder = try a.create(br.PlannedStreamEncoder);
            case.encoder.?.* = br.PlannedStreamEncoder.init(a);
        }
        case.expected_wire = try encode(case); // Untimed first warmup.
        case.wire_hash = provenance.sha256Hex(case.expected_wire);
        const decoded = try br.decodeStreamAllocExactSizeWithOptions(a, case.expected_wire, input.len, .{ .shared_dictionary = dictionary(case) });
        defer a.free(decoded);
        if (!std.mem.eql(u8, input, decoded)) return error.DecodedContentMismatch;
        initialized += 1;
        meta.* = .{ .spec = spec, .input_sha256 = &case.input_hash, .wire_sha256 = &case.wire_hash, .wire_bytes = case.expected_wire.len, .first_byte = case.expected_wire[0], .record_eligible = eligible, .retained_capacity_after_warmup = if (case.encoder) |encoder| encoder.retainedCapacity() else 0 };
    }
    if (try threads() != 1) return error.MultipleBenchmarkThreads;
    try write(init.io, .{ .schema = "vort.record-skip-paired-child.v1", .op = "ready", .provenance = info, .single_threaded_build = builtin.single_threaded, .allocator = "std.heap.c_allocator", .libc_version = std.mem.span(gnu_get_libc_version()), .benchmark_threads = try threads(), .cases = metadata });
    var command_buffer: [1024]u8 = undefined;
    while (try readCommandLine(&command_buffer)) |text| {
        const command = try std.json.parseFromSlice(Command, a, text, .{});
        defer command.deinit();
        const request = command.value;
        if (request.op == .quit) break;
        if (request.row >= cases.len or request.iterations == 0) return error.InvalidRequest;
        const case = &cases[request.row];
        try check(case); // Untimed per-window cache warmup + complete-wire check.
        const cpu_before = sched_getcpu();
        const threads_before = try threads();
        var mix: u64 = 0;
        const start = std.Io.Clock.awake.now(init.io);
        for (0..request.iterations) |_| {
            const wire = try encode(case);
            if (wire.len != case.expected_wire.len) return error.SuccessSizeChanged;
            mix +%= wire.len + wire[0];
            std.mem.doNotOptimizeAway(wire.ptr);
            a.free(wire); // Every output free is inside the measured lifecycle.
        }
        const end = std.Io.Clock.awake.now(init.io);
        const elapsed: u64 = @intCast(start.durationTo(end).nanoseconds);
        const cpu_after = sched_getcpu();
        const threads_after = try threads();
        try check(case); // Untimed post-window complete-wire check.
        if (threads_before != 1 or threads_after != 1 or cpu_before != cpu_after) return error.UnmatchedExecution;
        const expected_mix = request.iterations *% @as(u64, case.expected_wire.len + case.expected_wire[0]);
        if (mix != expected_mix) return error.ChecksumChanged;
        try write(init.io, .{ .op = request.op, .row = request.row, .iterations = request.iterations, .elapsed_ns = elapsed, .clock_start_ns = @as(u64, @intCast(start.nanoseconds)), .clock_end_ns = @as(u64, @intCast(end.nanoseconds)), .checksum = mix, .cpu_before = cpu_before, .cpu_after = cpu_after, .threads_before = threads_before, .threads_after = threads_after, .wire_sha256 = case.wire_hash[0..], .input_sha256 = case.input_hash[0..], .wire_bytes = case.expected_wire.len, .all_iteration_sizes_equal = true, .pre_post_complete_wire_equal = true });
    }
}
