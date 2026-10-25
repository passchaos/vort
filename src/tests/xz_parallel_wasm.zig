//! Small real XZ public calls proving the unsupported-target serial fallback.
const std = @import("std");
const builtin = @import("builtin");
const xz = @import("xz");
var storage: [4 * 1024 * 1024]u8 = undefined;
var report: [24]u64 = @splat(0);
const block_size = 1024;
const text = "XZ Wasm fallback repeated payload | abcdefghabcdefgh |\n";

fn require(ok: bool) error{WasmFallbackMismatch}!void {
    if (!ok) return error.WasmFallbackMismatch;
}
fn options(profile: *xz.ParallelProfile) xz.EncodeOptions {
    return .{
        .block_size = block_size,
        .chunk_size = block_size,
        .dictionary_size = 4096,
        .parser = .fast,
        .check = .crc64,
        .parallel = .{
            .io = std.Io.failing,
            .worker_count = 3,
            .max_inflight_blocks = 2,
            .max_inflight_bytes = 2 * block_size,
            .max_working_memory = storage.len,
            .profile = profile,
        },
    };
}
fn case(comptime compressed: bool, input: []const u8, first_slot: usize) !void {
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    const a = fixed.allocator();
    var profile: xz.ParallelProfile = .{};
    const opts = options(&profile);
    var serial_opts = opts;
    serial_opts.parallel = null;
    const serial = if (compressed) try xz.encodeAlloc(a, input, serial_opts) else try xz.encodeStoredAlloc(a, input, serial_opts);
    defer a.free(serial);
    var output: [12 * 1024]u8 = @splat(0xa5);
    // Compressed Into uses source bytes in the actual caller destination.
    // Publication must consume the source completely before overwriting it.
    if (compressed) @memcpy(output[0..input.len], input);
    const source = if (compressed) output[0..input.len] else input;
    const written = if (compressed) try xz.encodeInto(a, source, &output, opts) else try xz.encodeStoredInto(a, source, &output, opts);
    try require(std.mem.eql(u8, serial, output[0..written]));
    const expected_blocks = input.len / block_size;
    try require(profile.serial_fallback and profile.workers_started == 0);
    try require(profile.completed_blocks == expected_blocks and profile.published_blocks == expected_blocks);
    try require(profile.peak_inflight_blocks <= 2 and profile.peak_inflight_bytes <= 2 * block_size);
    try require(profile.peak_requested_bytes > 0 and profile.peak_requested_bytes <= storage.len and profile.live_requested_bytes == 0);
    const info = try xz.inspect(a, output[0..written]);
    try require(info.block_count == expected_blocks);
    var decoded: [8192]u8 = undefined;
    const decoded_len = try xz.decodeInto(a, output[0..written], decoded[0..input.len]);
    try require(decoded_len == input.len and std.mem.eql(u8, input, decoded[0..decoded_len]));
    if (compressed) {
        const stored = try xz.encodeStoredAlloc(a, input, serial_opts);
        defer a.free(stored);
        try require(written < stored.len);
        report[20] = stored.len;
    }
    report[first_slot] = input.len;
    report[first_slot + 1] = written;
    report[first_slot + 2] = profile.completed_blocks;
    report[first_slot + 3] = profile.published_blocks;
    report[first_slot + 4] = profile.peak_inflight_blocks;
    report[first_slot + 5] = profile.peak_inflight_bytes;
    report[first_slot + 6] = profile.peak_requested_bytes;
    report[first_slot + 7] = profile.live_requested_bytes;
}
fn refusals(input: []const u8) !void {
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    var output: [12 * 1024]u8 = @splat(0xa5);
    for ([_]bool{ false, true }) |byte_credit| {
        var profile: xz.ParallelProfile = .{};
        var opts = options(&profile);
        if (byte_credit) opts.parallel.?.max_inflight_bytes = block_size - 1 else opts.parallel.?.max_working_memory = 0;
        const original_end = fixed.end_index;
        if (xz.encodeInto(fixed.allocator(), input, &output, opts)) |_| return error.ExpectedWorkingMemoryRefusal else |err| try require(err == error.WorkingMemoryLimitExceeded);
        for (output) |byte| try require(byte == 0xa5);
        try require(fixed.end_index == original_end and profile.live_requested_bytes == 0 and profile.workers_started == 0);
    }
    report[16] = 2;
    report[17] = block_size - 1;
    report[18] = @bitSizeOf(usize);
    report[19] = storage.len;
}
export fn xzParallelWasmReport(index: u32) u64 {
    return if (index < report.len) report[index] else 0;
}
export fn xzParallelWasmRun() u32 {
    if (!builtin.cpu.arch.isWasm() or @bitSizeOf(usize) != 32) return 1;
    var stored: [8192]u8 = undefined;
    for (&stored, 0..) |*byte, i| byte.* = @truncate(i *% 29 + 7);
    case(false, &stored, 0) catch return 101;
    var compressed: [2048]u8 = undefined;
    for (&compressed, 0..) |*byte, i| byte.* = text[i % text.len];
    case(true, &compressed, 8) catch return 201;
    refusals(&compressed) catch return 301;
    return 0;
}
