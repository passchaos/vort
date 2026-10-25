//! Real small persistent XZ fallback, ownership and recovery consumers.
const std = @import("std");
const builtin = @import("builtin");
const xz = @import("xz");
var storage: [4 * 1024 * 1024]u8 = undefined;
var values: [32]u64 = @splat(0);
const phrase = "incremental XZ owned jobs | abcdefghabcdefgh |\n";
fn require(ok: bool) error{IncrementalWasmMismatch}!void {
    if (!ok) return error.IncrementalWasmMismatch;
}
fn options(profile: *xz.ParallelProfile, stored: bool) xz.IncrementalEncoder.Options {
    return .{ .block_size = 1024, .chunk_size = 1024, .dictionary_size = 4096, .parser = .fast, .check = .crc64, .include_block_sizes = true, .payload_encoding = if (stored) .stored else .compressed, .parallel = .{ .io = std.Io.failing, .worker_count = 3, .max_inflight_blocks = 2, .max_inflight_bytes = 2048, .max_working_memory = storage.len, .profile = profile } };
}
fn bounds(encoder: *const xz.IncrementalEncoder) !void {
    const p = encoder.snapshot().parallel;
    try require(!p.enabled or (p.serial_fallback and p.workers_started == 0 and p.workers_live == 0 and p.inflight_blocks <= 2 and p.inflight_bytes <= 2048));
}
fn feed(a: std.mem.Allocator, encoder: *xz.IncrementalEncoder, wire: *std.ArrayList(u8), input: []const u8) !usize {
    var position: usize = 0;
    var overwrites: usize = 0;
    var staging: [73]u8 = undefined;
    var output: [3]u8 = undefined;
    for (0..20000) |_| {
        if (position == input.len) return overwrites;
        const offered = @min(input.len - position, staging.len);
        @memcpy(staging[0..offered], input[position..][0..offered]);
        const result = try encoder.step(staging[0..offered], &output);
        try require(result.progress.input_read <= offered and result.progress.output_written <= output.len);
        @memset(staging[0..result.progress.input_read], 0xa5);
        overwrites += @intFromBool(result.progress.input_read != 0);
        position += result.progress.input_read;
        try wire.appendSlice(a, output[0..result.progress.output_written]);
        try bounds(encoder);
        try require(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
    return error.IncrementalWasmMismatch;
}
fn drain(a: std.mem.Allocator, encoder: *xz.IncrementalEncoder, wire: *std.ArrayList(u8), flush: bool, credit: *usize) !void {
    var output: [1]u8 = undefined;
    for (0..20000) |_| {
        const before = encoder.snapshot().parallel;
        const result = try encoder.step("", &output);
        try wire.appendSlice(a, output[0..result.progress.output_written]);
        const after = encoder.snapshot().parallel;
        if (before.delivering_block and before.delivering_output_bytes == 1) {
            try require(before.inflight_bytes > 0 and after.delivered_blocks == before.delivered_blocks + 1);
            credit.* += 1;
        }
        try bounds(encoder);
        if (result.status == .done or (flush and result.status == .need_input)) return;
        try require(result.progress.output_written != 0);
    }
    return error.IncrementalWasmMismatch;
}
fn checkWire(a: std.mem.Allocator, wire: []const u8, input: []const u8, opts: xz.IncrementalEncoder.Options, split: ?usize) !void {
    var serial_options = opts;
    serial_options.parallel = null;
    var serial = try xz.IncrementalEncoder.initWithOptions(a, serial_options);
    defer serial.deinit();
    var old: std.ArrayList(u8) = .empty;
    defer old.deinit(a);
    var ignored: usize = 0;
    if (split) |at| {
        _ = try feed(a, &serial, &old, input[0..at]);
        serial.flush();
        try drain(a, &serial, &old, true, &ignored);
        _ = try feed(a, &serial, &old, input[at..]);
    } else _ = try feed(a, &serial, &old, input);
    serial.finish();
    try drain(a, &serial, &old, false, &ignored);
    try require(std.mem.eql(u8, old.items, wire));
    var decoded: [8192]u8 = undefined;
    const count = try xz.decodeInto(a, wire, decoded[0..input.len]);
    try require(count == input.len and std.mem.eql(u8, input, decoded[0..count]));
}
fn storedCase() !void {
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    const a = fixed.allocator();
    var profile: xz.ParallelProfile = .{};
    const opts = options(&profile, true);
    var encoder = try xz.IncrementalEncoder.initWithOptions(a, opts);
    var alive = true;
    defer if (alive) encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    var input: [8192]u8 = undefined;
    for (&input, 0..) |*byte, i| byte.* = @truncate(i *% 29 + 7);
    const overwrites = try feed(a, &encoder, &wire, &input);
    encoder.finish();
    var credit: usize = 0;
    try drain(a, &encoder, &wire, false, &credit);
    try checkWire(a, wire.items, &input, opts, null);
    const done = encoder.snapshot();
    try require(done.done and done.current_stream_blocks == 8 and done.parallel.delivered_blocks == 8 and done.parallel.live_requested_bytes > 0);
    values[0] = input.len;
    values[1] = wire.items.len;
    values[2] = done.parallel.delivered_blocks;
    values[3] = overwrites;
    values[4] = done.parallel.peak_requested_bytes;
    values[5] = done.parallel.live_requested_bytes;
    const end = fixed.end_index;
    encoder.reset();
    try require(fixed.end_index == end and encoder.snapshot().parallel.live_requested_bytes == done.parallel.live_requested_bytes);
    values[6] = 1;
    encoder.deinit();
    alive = false;
    try require(profile.live_requested_bytes == 0);
    values[7] = profile.live_requested_bytes;
}
fn moveCase() !void {
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    const a = fixed.allocator();
    var profile: xz.ParallelProfile = .{};
    const opts = options(&profile, false);
    var original = try xz.IncrementalEncoder.initWithOptions(a, opts);
    var moved_out = false;
    defer if (!moved_out) original.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    var header: [12]u8 = undefined;
    const head = try original.step("", &header);
    try wire.appendSlice(a, header[0..head.progress.output_written]);
    try require(head.progress.output_written == 12);
    var input: [2048]u8 = undefined;
    for (&input, 0..) |*byte, i| byte.* = phrase[i % phrase.len];
    var staging = input;
    const accepted = try original.step(&staging, &.{});
    @memset(staging[0..accepted.progress.input_read], 0xa5);
    const before = original.snapshot();
    try require(accepted.progress.input_read == input.len and before.parallel.accepted_blocks == 2 and before.parallel.inflight_blocks == 2);
    var moved = original;
    original = undefined;
    moved_out = true;
    var alive = true;
    defer if (alive) moved.deinit();
    moved.finish();
    var credit: usize = 0;
    try drain(a, &moved, &wire, false, &credit);
    try require(credit == 2);
    try checkWire(a, wire.items, &input, opts, null);
    const done = moved.snapshot();
    try require(done.done and done.parallel.delivered_blocks == 2 and done.parallel.inflight_bytes == 0 and done.parallel.live_requested_bytes > 0);
    values[8] = input.len;
    values[9] = wire.items.len;
    values[10] = before.parallel.accepted_blocks;
    values[11] = credit;
    values[12] = done.parallel.live_requested_bytes;
    values[13] = done.parallel.peak_requested_bytes;
    moved.deinit();
    alive = false;
    try require(profile.live_requested_bytes == 0);
    values[14] = profile.live_requested_bytes;
}
fn partialCredit() !void {
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    const a = fixed.allocator();
    var profile: xz.ParallelProfile = .{};
    var opts = options(&profile, true);
    opts.block_size = 128;
    opts.chunk_size = 128;
    opts.parallel.?.max_inflight_bytes = 64;
    var encoder = try xz.IncrementalEncoder.initWithOptions(a, opts);
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    var header: [12]u8 = undefined;
    const head = try encoder.step("", &header);
    try wire.appendSlice(a, header[0..head.progress.output_written]);
    var input: [65]u8 = undefined;
    for (&input, 0..) |*byte, i| byte.* = @truncate(i *% 7);
    const accepted = try encoder.step(input[0..64], &.{});
    try require(accepted.progress.input_read == 64);
    var output: [1]u8 = .{0xa5};
    if (encoder.step(input[64..], &output)) |_| return error.ExpectedCreditRefusal else |err| try require(err == error.WorkingMemoryLimitExceeded);
    const failed = encoder.snapshot();
    try require(!failed.parallel.failed and failed.parallel.partial_input_bytes == 64 and failed.parallel.inflight_bytes == 64);
    try require(failed.parallel.last_step_progress.input_read == 0 and failed.parallel.last_step_progress.output_written == 0 and output[0] == 0xa5 and encoder.options.block_size == 128);
    encoder.flush();
    var ignored: usize = 0;
    try drain(a, &encoder, &wire, true, &ignored);
    _ = try feed(a, &encoder, &wire, input[64..]);
    encoder.finish();
    try drain(a, &encoder, &wire, false, &ignored);
    try checkWire(a, wire.items, &input, opts, 64);
    try require(encoder.snapshot().current_stream_blocks == 2);
    values[16] = input.len;
    values[17] = wire.items.len;
    values[18] = failed.parallel.inflight_bytes;
    values[19] = encoder.snapshot().parallel.delivered_blocks;
    values[20] = 1;
}
fn zeroQuota() !void {
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    var profile: xz.ParallelProfile = .{};
    var opts = options(&profile, true);
    opts.parallel.?.max_working_memory = 0;
    if (xz.IncrementalEncoder.initWithOptions(fixed.allocator(), opts)) |_| return error.ExpectedInitialQuotaRefusal else |err| try require(err == error.WorkingMemoryLimitExceeded);
    try require(fixed.end_index == 0 and profile.live_requested_bytes == 0 and profile.workers_started == 0);
    values[22] = 1;
    values[23] = profile.live_requested_bytes;
    values[24] = @bitSizeOf(usize);
}
export fn xzIncrementalParallelWasmReport(index: u32) u64 {
    return if (index < values.len) values[index] else 0;
}
export fn xzIncrementalParallelWasmRun() u32 {
    if (!builtin.cpu.arch.isWasm()) return 1;
    storedCase() catch return 101;
    moveCase() catch return 201;
    partialCredit() catch return 301;
    zeroQuota() catch return 401;
    return 0;
}
