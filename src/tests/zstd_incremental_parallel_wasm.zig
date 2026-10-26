//! Real bounded incremental-parallel Zstd consumers; no synthetic large stream.
const std = @import("std");
const zstd = @import("zstd");
const E = zstd.NativeIncrementalParallelFrameEncoder;
const P = @FieldType(@FieldType(E.Snapshot, "parallel"), "profile");
var storage: [8 * 1024 * 1024]u8 = undefined;
var values: [48]u64 = @splat(0);
fn require(ok: bool) error{IncrementalFrameMismatch}!void {
    if (!ok) return error.IncrementalFrameMismatch;
}
const Fixture = struct {
    fixed: std.heap.FixedBufferAllocator = std.heap.FixedBufferAllocator.init(&storage),
    profile: P = .{},
    fn allocator(self: *Fixture) std.mem.Allocator {
        return self.fixed.allocator();
    }
    fn options(self: *Fixture) E.Options {
        return .{ .frame = .{ .include_content_size = false, .selection = .raw_or_rle, .content_checksum = true, .block_size_max = 256, .window_log = 12 }, .parallel = .{ .io = std.Io.failing, .worker_count = 2, .job_size = 512, .max_inflight_jobs = 2, .max_inflight_bytes = 1024, .max_working_memory = 4 * 1024 * 1024, .profile = &self.profile } };
    }
};
fn fill(bytes: []u8) void {
    var r: u32 = 0x981327ab;
    for (bytes) |*b| {
        r = r *% 1664525 +% 1013904223;
        b.* = @truncate(r >> 24);
    }
}
fn bounds(encoder: *const E) !void {
    const snap = encoder.snapshot();
    const p = snap.parallel.profile;
    try require(p.enabled and p.serial_fallback and p.workers_started == 0 and p.workers_live == 0 and p.peak_active_workers == 0);
    try require(snap.parallel.inflight_jobs <= 2 and snap.parallel.inflight_bytes <= 1024 and p.live_requested_bytes <= 4 * 1024 * 1024);
}
fn feed(a: std.mem.Allocator, encoder: *E, wire: *std.ArrayList(u8), input: []const u8) !usize {
    var at: usize = 0;
    var overwrites: usize = 0;
    var staging: [73]u8 = undefined;
    var output: [3]u8 = undefined;
    for (0..10000) |_| {
        if (at == input.len) return overwrites;
        const n = @min(staging.len, input.len - at);
        @memcpy(staging[0..n], input[at..][0..n]);
        const step = try encoder.step(staging[0..n], &output);
        try require(step.progress.input_read <= n and step.progress.output_written <= output.len);
        @memset(staging[0..step.progress.input_read], 0xa5);
        overwrites += @intFromBool(step.progress.input_read != 0);
        at += step.progress.input_read;
        try wire.appendSlice(a, output[0..step.progress.output_written]);
        try bounds(encoder);
        try require(step.progress.input_read != 0 or step.progress.output_written != 0);
    }
    return error.IncrementalFrameMismatch;
}
fn drain(a: std.mem.Allocator, encoder: *E, wire: *std.ArrayList(u8), flush: bool) !usize {
    var credits: usize = 0;
    var output: [1]u8 = undefined;
    for (0..10000) |_| {
        const before = encoder.snapshot().parallel;
        const step = try encoder.step("", &output);
        try wire.appendSlice(a, output[0..step.progress.output_written]);
        const after = encoder.snapshot().parallel;
        if (before.delivering_job and before.delivering_output_bytes == 1) {
            try require(after.inflight_jobs + 1 == before.inflight_jobs and after.inflight_bytes <= before.inflight_bytes);
            try require(after.profile.delivered_jobs == before.profile.delivered_jobs + 1);
            credits += 1;
        } else if (before.delivering_job) {
            try require(after.inflight_bytes == before.inflight_bytes);
        }
        try bounds(encoder);
        if (step.status == .done or (flush and step.status == .need_input)) return credits;
        try require(step.progress.output_written != 0);
    }
    return error.IncrementalFrameMismatch;
}
fn header(a: std.mem.Allocator, encoder: *E, wire: *std.ArrayList(u8)) !void {
    const zero = try encoder.step("borrowed", &.{});
    try require(zero.progress.input_read == 0 and zero.progress.output_written == 0 and zero.status == .need_output);
    try require(encoder.snapshot().input_read == 0 and encoder.snapshot().parallel.owned_input_bytes == 0);
    _ = try drain(a, encoder, wire, true);
}
fn check(a: std.mem.Allocator, wire: []const u8, input: []const u8, format: zstd.FrameFormat, preset: ?zstd.NativeDictionary) !usize {
    const h = try zstd.inspectNativeFrameHeaderWithFormat(wire, format);
    try require(h.has_checksum);
    var at = h.payload_offset;
    var blocks: usize = 0;
    while (true) {
        try require(wire.len - at >= 3);
        const word = std.mem.readInt(u24, wire[at..][0..3], .little);
        at += 3;
        const kind = (word >> 1) & 3;
        try require(kind != 3);
        const n: usize = if (kind == 1) 1 else word >> 3;
        try require(n <= wire.len - at);
        at += n;
        blocks += 1;
        if (word & 1 != 0) break;
    }
    try require(at + 4 == wire.len and std.mem.readInt(u32, wire[at..][0..4], .little) == @as(u32, @truncate(std.hash.XxHash64.hash(0, input))));
    var output: [2048]u8 = undefined;
    const count = try zstd.decodeFrameIntoWithOptions(a, wire, output[0..input.len], .{ .format = format, .dictionary = preset, .expected_output_len = input.len });
    try require(count == input.len and std.mem.eql(u8, input, output[0..count]));
    return blocks;
}
fn seal(a: std.mem.Allocator, encoder: *E, wire: *std.ArrayList(u8), flush: bool) !usize {
    if (flush) encoder.flush() else encoder.finish();
    return drain(a, encoder, wire, flush);
}
fn serialEqual(a: std.mem.Allocator, settings: E.Options, wire: []const u8, input: []const u8, boundary: ?usize) !void {
    var profile: P = .{};
    var control = settings;
    control.parallel.worker_count = 1;
    control.parallel.profile = &profile;
    var encoder = try E.init(a, control);
    defer encoder.deinit();
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(a);
    for ([_]usize{ boundary orelse input.len, input.len }, 0..) |end, i| {
        const start = if (i == 0) 0 else boundary orelse input.len;
        _ = try feed(a, &encoder, &expected, input[start..end]);
        if (boundary != null) _ = try seal(a, &encoder, &expected, true);
    }
    _ = try seal(a, &encoder, &expected, false);
    try require(std.mem.eql(u8, wire, expected.items));
}
fn refusal(encoder: *E, input: []const u8, output: []u8, expected: anyerror, sticky: bool) !void {
    @memset(output, 0xa5);
    const before = encoder.snapshot();
    if (encoder.step(input, output)) |_| return error.ExpectedRefusal else |err| try require(err == expected);
    const progress = encoder.failedProgress() orelse return error.IncrementalFrameMismatch;
    const after = encoder.snapshot();
    try require(progress.input_read == 0 and progress.output_written == 0 and after.parallel.failed == sticky);
    try require(after.input_read == before.input_read and after.output_written == before.output_written);
    try require(after.parallel.last_step_progress.input_read == 0 and after.parallel.last_step_progress.output_written == 0);
    for (output) |byte| try require(byte == 0xa5);
}
fn streamGroup() !void {
    var f: Fixture = .{};
    const a = f.allocator();
    const settings = f.options();
    var encoder = try E.init(a, settings);
    defer values[6] = f.profile.live_requested_bytes;
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    try header(a, &encoder, &wire);
    var input: [1536]u8 = undefined;
    fill(&input);
    @memset(input[256..512], 'R');
    const overwrites = try feed(a, &encoder, &wire, &input);
    const credits = try seal(a, &encoder, &wire, false);
    const blocks = try check(a, wire.items, &input, .standard, null);
    const done = encoder.snapshot();
    try require(done.done and done.parallel.profile.delivered_blocks == blocks and done.parallel.inflight_bytes == 0);
    try serialEqual(a, settings, wire.items, &input, null);
    values[0..7].* = .{ input.len, wire.items.len, blocks, overwrites, credits, done.parallel.profile.peak_requested_bytes, 0 };
    values[40..48].* = .{ @bitSizeOf(usize), storage.len, 4 * 1024 * 1024, 1024, done.parallel.profile.workers_started, done.parallel.profile.workers_live, done.parallel.profile.peak_active_workers, @intFromBool(done.parallel.profile.serial_fallback) };
}
export fn zstdIncrementalParallelWasmStream() u32 {
    streamGroup() catch return 101;
    return 0;
}
fn creditGroup() !void {
    var f: Fixture = .{};
    const a = f.allocator();
    var settings = f.options();
    settings.frame.block_size_max = 64;
    settings.parallel.job_size = 128;
    settings.parallel.max_inflight_bytes = 64;
    var encoder = try E.init(a, settings);
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    try header(a, &encoder, &wire);
    var input: [65]u8 = undefined;
    fill(&input);
    const accepted = try encoder.step(input[0..64], &.{});
    try require(accepted.progress.input_read == 64);
    var output: [1]u8 = undefined;
    try refusal(&encoder, input[64..], &output, error.WorkingMemoryLimitExceeded, false);
    _ = try seal(a, &encoder, &wire, true);
    _ = try feed(a, &encoder, &wire, input[64..]);
    _ = try seal(a, &encoder, &wire, true);
    const prior_jobs = encoder.snapshot().parallel.profile.delivered_jobs;
    _ = try seal(a, &encoder, &wire, false);
    const blocks = try check(a, wire.items, &input, .standard, null);
    try require(encoder.snapshot().parallel.profile.delivered_jobs == prior_jobs + 1 and encoder.snapshot().parallel.inflight_bytes == 0);
    try serialEqual(a, settings, wire.items, &input, 64);
    values[8..15].* = .{ input.len, wire.items.len, blocks, prior_jobs, prior_jobs + 1, settings.parallel.job_size, 1 };
}
export fn zstdIncrementalParallelWasmCredit() u32 {
    creditGroup() catch return 201;
    return 0;
}
fn dictionaryGroup() !void {
    var f: Fixture = .{};
    const a = f.allocator();
    var settings = f.options();
    var prefix: [256]u8 = undefined;
    fill(&prefix);
    const preset = zstd.NativeDictionary.init(77, &prefix);
    var input: [512]u8 = undefined;
    @memcpy(input[0..256], &prefix);
    @memcpy(input[256..], &prefix);
    settings.frame.format = .magicless;
    settings.frame.strategy = .fast;
    settings.frame.selection = .auto;
    settings.frame.dictionary_id = 77;
    settings.frame.include_content_size = true;
    defer values[22] = f.profile.live_requested_bytes;
    var original = try E.initExactSizeWithPresetDictionary(a, settings, input.len, preset);
    var transferred = false;
    defer if (!transferred) original.deinit();
    var first: std.ArrayList(u8) = .empty;
    defer first.deinit(a);
    try header(a, &original, &first);
    var staging = input;
    const accepted = try original.step(&staging, &.{});
    @memset(staging[0..accepted.progress.input_read], 0xdd);
    try require(accepted.progress.input_read == input.len);
    var moved = original;
    original = undefined;
    transferred = true;
    defer moved.deinit();
    _ = try seal(a, &moved, &first, false);
    _ = try check(a, first.items, &input, .magicless, preset);
    try moved.nextFrameExactSizeWithPresetDictionary(settings, input.len, preset);
    var second: std.ArrayList(u8) = .empty;
    defer second.deinit(a);
    _ = try feed(a, &moved, &second, &input);
    _ = try seal(a, &moved, &second, false);
    _ = try check(a, second.items, &input, .magicless, preset);
    try require(std.mem.eql(u8, first.items, second.items) and moved.snapshot().frame_count == 2);
    const retained = moved.memorySnapshot().live_requested_bytes;
    const end = f.fixed.end_index;
    moved.reset();
    try require(f.fixed.end_index == end and moved.memorySnapshot().live_requested_bytes == retained and moved.snapshot().input_read == 0);
    values[16..23].* = .{ first.items.len, second.items.len, retained, 2, @bitSizeOf(@FieldType(E.Snapshot, "input_read")), (@as(u64, 1) << 32) + 7, 0 };
}
export fn zstdIncrementalParallelWasmDictionary() u32 {
    dictionaryGroup() catch return 301;
    return 0;
}
fn heapCase(limit: usize) !usize {
    var f: Fixture = .{};
    const a = f.allocator();
    var settings = f.options();
    settings.parallel.max_working_memory = limit;
    defer values[29] += f.profile.live_requested_bytes;
    var encoder = try E.init(a, settings);
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    var input: [128]u8 = undefined;
    fill(&input);
    _ = try feed(a, &encoder, &wire, &input);
    _ = try seal(a, &encoder, &wire, false);
    _ = try check(a, wire.items, &input, .standard, null);
    const peak = f.profile.peak_requested_bytes;

    return peak;
}
fn quotaGroup() !void {
    values[29] = 0;
    values[30..32].* = .{ 410, 0 };
    const peak = try heapCase(4 * 1024 * 1024);
    values[30] = 411;
    try require(peak > 1 and try heapCase(peak) == peak);
    values[30] = 412;
    if (heapCase(peak - 1)) |_| return error.ExpectedHeapRefusal else |err| try require(err == error.WorkingMemoryLimitExceeded);
    values[30] = 420;
    try frontQuota();
    values[24..26].* = .{ peak, 2 };
    try stickyQuota();
    values[30] = 0;
}
fn frontQuota() !void {
    var f: Fixture = .{};
    const a = f.allocator();
    var settings = f.options();
    settings.parallel.max_working_memory = 0;
    if (E.init(a, settings)) |encoder| {
        var unexpected = encoder;
        unexpected.deinit();
        return error.ExpectedInitialRefusal;
    } else |err| try require(err == error.WorkingMemoryLimitExceeded);
    try require(f.fixed.end_index == 0);
    settings.parallel.max_working_memory = 4 * 1024 * 1024;
    settings.max_pending_output_len = 12;
    defer values[29] += f.profile.live_requested_bytes;
    var encoder = try E.init(a, settings);
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    try header(a, &encoder, &wire);
    var input: [128]u8 = undefined;
    fill(&input);
    _ = try encoder.step(&input, &.{});
    encoder.finish();
    var output: [17]u8 = undefined;
    try refusal(&encoder, "", &output, error.OutputLimitExceeded, false);
    const encoded_jobs = encoder.snapshot().parallel.profile.encoded_jobs;
    try require(encoded_jobs == 1);
    encoder.options.max_pending_output_len = 4096;
    _ = try drain(a, &encoder, &wire, false);
    try require(encoder.snapshot().parallel.profile.encoded_jobs == encoded_jobs);
    _ = try check(a, wire.items, &input, .standard, null);
    values[26..28].* = .{ encoded_jobs, 1 };
}
fn stickyQuota() !void {
    var f: Fixture = .{};
    const a = f.allocator();
    var settings = f.options();
    settings.frame.strategy = .btopt;
    settings.frame.selection = .auto;
    settings.frame.hq = .{ .max_price_evaluations = 0 };
    defer values[29] += f.profile.live_requested_bytes;
    values[30] = 430;
    var encoder = try E.init(a, settings);
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    values[30] = 431;
    try header(a, &encoder, &wire);
    values[30] = 432;
    _ = try encoder.step("abcdabcdabcd", &.{});
    encoder.finish();
    var output: [17]u8 = undefined;
    values[30] = 433;
    try refusal(&encoder, "", &output, error.SearchLimitExceeded, true);
    values[30] = 434;
    try refusal(&encoder, "ignored", &output, error.SearchLimitExceeded, true);
    values[30] = 435;
    encoder.reset();
    wire.clearRetainingCapacity();
    values[30] = 436;
    _ = try seal(a, &encoder, &wire, false);
    values[30] = 437;
    _ = try check(a, wire.items, "", .standard, null);
    values[28] = 1;
}
export fn zstdIncrementalParallelWasmQuotas() u32 {
    quotaGroup() catch |err| {
        values[31] = switch (err) {
            error.InvalidBlockPlan => 1,
            error.WorkingMemoryLimitExceeded => 2,
            error.OutputLimitExceeded => 3,
            error.SearchLimitExceeded => 4,
            error.IncrementalFrameMismatch => 5,
            error.ExpectedRefusal => 6,
            else => 7,
        };
        return 401;
    };
    return 0;
}
export fn zstdIncrementalParallelWasmReport(index: u32) u64 {
    return if (index < values.len) values[index] else 0;
}
