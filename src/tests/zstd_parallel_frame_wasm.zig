//! Actual small single-frame MT APIs on Wasm's synchronous fallback.
const std = @import("std");
const builtin = @import("builtin");
const zstd = @import("zstd");
var storage: [8 * 1024 * 1024]u8 = undefined;
var values: [48]u64 = @splat(0);
fn require(ok: bool) error{ParallelFrameMismatch}!void {
    if (!ok) return error.ParallelFrameMismatch;
}
fn parallel(profile: *zstd.ParallelProfile) zstd.ParallelOptions {
    return .{ .io = std.Io.failing, .worker_count = 2, .job_size = 512, .max_inflight_jobs = 2, .max_inflight_bytes = 1024, .max_working_memory = 4 * 1024 * 1024, .profile = profile };
}
fn options(is_fast: bool) zstd.NativeFrameOptions {
    return .{ .strategy = if (is_fast) .fast else .auto, .selection = if (is_fast) .auto else .raw_or_rle, .block_size_max = 256, .window_log = 12, .max_match_history_len = 4096, .content_checksum = true };
}
fn fill(input: []u8, repeated: bool) void {
    var random: u32 = 0x718291ab;
    for (input, 0..) |*byte, i| {
        random = random *% 1664525 +% 1013904223;
        byte.* = if (repeated and i >= 256) input[i % 256] else @truncate(random >> 24);
        if (!repeated and (i / 256) % 2 == 0) byte.* = 'R';
    }
}
fn checkProfile(profile: zstd.ParallelProfile, input_len: usize) !void {
    try require(profile.available and profile.serial_fallback and profile.effective_workers == 1);
    try require(profile.workers_started == 0 and profile.workers_live == 0 and profile.peak_active_workers == 0);
    try require(profile.effective_job_size == 512 and profile.job_count == input_len / 512);
    try require(profile.encoded_jobs == profile.job_count and profile.published_jobs == profile.job_count);
    try require(profile.encoded_blocks == input_len / 256 and profile.published_blocks == input_len / 256);
    try require(profile.peak_inflight_jobs <= 2 and profile.peak_inflight_bytes <= 1024);
    try require(profile.peak_requested_bytes > 0 and profile.peak_requested_bytes <= 4 * 1024 * 1024 and profile.live_requested_bytes == 0);
}
fn checkFrame(a: std.mem.Allocator, wire: []const u8, input: []const u8, format: zstd.FrameFormat, preset_dictionary: ?zstd.NativeDictionary) !usize {
    const header = try zstd.inspectNativeFrameHeaderWithFormat(wire, format);
    try require(header.has_checksum and header.content_size == input.len);
    var at = header.payload_offset;
    var blocks: usize = 0;
    while (true) {
        try require(wire.len - at >= 3);
        const word = std.mem.readInt(u24, wire[at..][0..3], .little);
        at += 3;
        const kind = (word >> 1) & 3;
        try require(kind != 3);
        const packed_len: usize = if (kind == 1) 1 else word >> 3;
        try require(packed_len <= wire.len - at);
        at += packed_len;
        blocks += 1;
        if (word & 1 != 0) break;
    }
    try require(at + 4 == wire.len and std.mem.readInt(u32, wire[at..][0..4], .little) == @as(u32, @truncate(std.hash.XxHash64.hash(0, input))));
    var output: [2048]u8 = undefined;
    const count = try zstd.decodeFrameIntoWithOptions(a, wire, output[0..input.len], .{ .format = format, .dictionary = preset_dictionary, .expected_output_len = input.len });
    try require(count == input.len and std.mem.eql(u8, input, output[0..count]));
    return blocks;
}
fn record(slot: usize, profile: zstd.ParallelProfile, wire: []const u8) void {
    values[slot] = wire.len;
    values[slot + 1] = profile.job_count;
    values[slot + 2] = profile.published_blocks;
    values[slot + 3] = profile.peak_requested_bytes;
    values[slot + 4] = profile.live_requested_bytes;
    values[slot + 5] = profile.peak_inflight_jobs;
    values[slot + 6] = profile.peak_inflight_bytes;
}
fn raw() !void {
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    const a = fixed.allocator();
    var input: [2048]u8 = undefined;
    fill(&input, false);
    var profile: zstd.ParallelProfile = .{};
    const opts = options(false);
    const p = parallel(&profile);
    const bound = try zstd.encodedNativeParallelFrameBound(input.len, opts, p);
    const wire = try zstd.encodeNativeParallelFrameAlloc(a, &input, opts, p);
    defer a.free(wire);
    try checkProfile(profile, input.len);
    try require(wire.len <= bound and try checkFrame(a, wire, &input, .standard, null) == 8);
    record(0, profile, wire);
    values[7] = bound;
    var caller: [4096]u8 = @splat(0xa5);
    var appended: std.ArrayList(u8) = .{ .items = caller[0..7], .capacity = caller.len };
    const added = try zstd.encodeNativeParallelFrameAppend(a, &appended, &input, opts, p);
    try require(added == wire.len and std.mem.eql(u8, appended.items[7..], wire));
    for (caller[0..7]) |byte| try require(byte == 0xa5);
    @memcpy(caller[0..input.len], &input);
    const into = try zstd.encodeNativeParallelFrameIntoSlice(a, caller[0..input.len], opts, &caller, p);
    try require(into == wire.len and std.mem.eql(u8, caller[0..into], wire));
    values[36] = 1;
}
export fn zstdParallelFrameWasmRaw() u32 {
    raw() catch return 101;
    return 0;
}
fn fast() !void {
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    const a = fixed.allocator();
    var input: [2048]u8 = undefined;
    fill(&input, true);
    const original_hash = std.hash.XxHash64.hash(93, &input);
    var profile: zstd.ParallelProfile = .{};
    var work: zstd.EncoderControlProfile = .{};
    var opts = options(true);
    opts.control_profile = &work;
    var p = parallel(&profile);
    const wire = try zstd.encodeNativeParallelFrameAlloc(a, &input, opts, p);
    defer a.free(wire);
    try checkProfile(profile, input.len);
    try require(try checkFrame(a, wire, &input, .standard, null) == 8);
    try require(work.history_sequences > 0 and work.history_seed_positions > 0 and std.hash.XxHash64.hash(93, &input) == original_hash);
    record(8, profile, wire);
    values[15] = work.history_sequences;
    values[16] = work.max_distance;
    p.worker_count = 1;
    opts.control_profile = null;
    const serial = try zstd.encodeNativeParallelFrameAlloc(a, &input, opts, p);
    defer a.free(serial);
    try require(std.mem.eql(u8, wire, serial));
    values[17] = 1;
}
export fn zstdParallelFrameWasmFast() u32 {
    fast() catch return 201;
    return 0;
}
fn dictionary() !void {
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    const a = fixed.allocator();
    var prefix: [256]u8 = undefined;
    fill(&prefix, true);
    var input: [1024]u8 = undefined;
    for (&input, 0..) |*byte, i| byte.* = prefix[i % prefix.len];
    const dict = zstd.NativeDictionary.init(77, &prefix);
    var profile: zstd.ParallelProfile = .{};
    var work: zstd.EncoderControlProfile = .{};
    var opts = options(true);
    opts.format = .magicless;
    opts.control_profile = &work;
    const p = parallel(&profile);
    const wire = try zstd.encodeNativeParallelFrameWithDictionaryAlloc(a, &input, opts, dict, p);
    defer a.free(wire);
    try checkProfile(profile, input.len);
    try require(try checkFrame(a, wire, &input, .magicless, dict) == 4 and work.dictionary_sequences > 0);
    const entries = [_]zstd.NativeDictionary{dict};
    const set = zstd.NativeDictionarySet.init(&entries);
    opts.control_profile = null;
    const from_set = try zstd.encodeNativeParallelFrameWithDictionarySetAlloc(a, &input, opts, set, 77, p);
    defer a.free(from_set);
    try require(std.mem.eql(u8, wire, from_set));
    var normal = opts;
    normal.format = .standard;
    const standard = try zstd.encodeNativeParallelFrameWithDictionaryAlloc(a, &input, normal, dict, p);
    defer a.free(standard);
    try require(standard.len == wire.len + 4 and std.mem.eql(u8, standard[4..], wire));
    record(20, profile, wire);
    values[27] = work.dictionary_sequences;
    values[28] = 77;
}
export fn zstdParallelFrameWasmDictionary() u32 {
    dictionary() catch return 301;
    return 0;
}
fn quotas() !void {
    var input: [2048]u8 = undefined;
    fill(&input, false);
    const opts = options(false);
    var peak: usize = 0;
    var expected: [4096]u8 = undefined;
    var size: usize = 0;
    for (0..2) |pass| {
        var fixed = std.heap.FixedBufferAllocator.init(&storage);
        var profile: zstd.ParallelProfile = .{};
        var p = parallel(&profile);
        if (pass == 1) p.max_working_memory = peak;
        const wire = try zstd.encodeNativeParallelFrameAlloc(fixed.allocator(), &input, opts, p);
        if (pass == 0) {
            peak = profile.peak_requested_bytes;
            size = wire.len;
            @memcpy(expected[0..size], wire);
        } else try require(profile.peak_requested_bytes == peak and std.mem.eql(u8, expected[0..size], wire));
        fixed.allocator().free(wire);
        try require(profile.live_requested_bytes == 0);
    }
    for (0..3) |mode| {
        var fixed = std.heap.FixedBufferAllocator.init(&storage);
        var profile: zstd.ParallelProfile = .{};
        var p = parallel(&profile);
        if (mode == 2) p.max_inflight_bytes = 511 else p.max_working_memory = if (mode == 0) 0 else peak - 1;
        var output: [4096]u8 = @splat(0xa5);
        if (zstd.encodeNativeParallelFrameIntoSlice(fixed.allocator(), &input, opts, &output, p)) |_| return error.ExpectedQuotaRefusal else |err| try require(err == error.WorkingMemoryLimitExceeded);
        for (output) |byte| try require(byte == 0xa5);
        try require(profile.live_requested_bytes == 0);
        if (mode != 1) try require(fixed.end_index == 0);
    }
    values[30] = peak;
    values[31] = size;
    values[32] = 3;
    values[33] = 511;
    values[34] = @bitSizeOf(usize);
    values[35] = storage.len;
}
export fn zstdParallelFrameWasmQuotas() u32 {
    quotas() catch return 401;
    return 0;
}
export fn zstdParallelFrameWasmReport(index: u32) u64 {
    return if (index < values.len) values[index] else 0;
}
