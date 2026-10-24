//! Actual small public HQ search consumers for wasm32-wasi. Full-span means
//! every position of one real 128 KiB input, not synthetic parser checkpoints.
const std = @import("std");
const vort = @import("vort");
const heap_cap: usize = 128 * 1024 * 1024;
const text = "Wasm HQ search abcdefghabcdefghXabcdefgh tail\n";
var report: [48]u64 = @splat(0);

fn require(condition: bool) error{HqSearchConsumerMismatch}!void {
    if (!condition) return error.HqSearchConsumerMismatch;
}
fn untouched(bytes: []const u8) !void {
    for (bytes) |byte| try require(byte == 0xa5);
}
fn fillText(bytes: []u8) void {
    for (bytes, 0..) |*byte, i| byte.* = text[i % text.len];
}
fn roundtrip(wire: []const u8, input: []const u8) !void {
    const a = std.heap.page_allocator;
    const decoded = try vort.zstdDecodeFrameAlloc(a, wire);
    defer a.free(decoded);
    try require(std.mem.eql(u8, input, decoded));
}

export fn zstdHqSearchReport(index: u32) u64 {
    return if (index < report.len) report[index] else 0;
}

fn wholeComplete() !void {
    const a = std.heap.page_allocator;
    var input: [512]u8 = undefined;
    fillText(&input);
    var profile: vort.ZstdEncoderControlProfile = .{};
    var memory: vort.ZstdEncodeMemoryProfile = .{};
    var options: vort.ZstdNativeFrameOptions = .{
        .strategy = .btopt,
        .hq = .{ .parse_mode = .whole_block, .match_lengths = .complete, .search_depth = 8, .nice_len = 32, .max_working_memory = heap_cap },
        .content_checksum = true,
        .control_profile = &profile,
        .memory_profile = &memory,
        .max_total_working_memory = heap_cap,
    };
    const actual = try vort.zstdEncodeNativeFrameWithOptionsAlloc(a, &input, options);
    defer a.free(actual.frame);
    try require(profile.whole_block_passes > 0 and profile.complete_length_passes > 0 and profile.baseline_searches > 0 and profile.guarded_frames > 0);
    try require(profile.bounded_passes > 0 and profile.sampled_length_passes > 0 and profile.max_parse_positions == input.len);
    try require(profile.max_match_length_considered >= 7 and profile.price_evaluations > profile.max_plan_price_evaluations and profile.max_plan_price_evaluations > 0);
    try require(profile.effective_hq_parse_mode == .whole_block and profile.effective_hq_match_lengths == .complete);
    try require(memory.live_requested_bytes == 0 and memory.peak_requested_bytes <= heap_cap);
    try roundtrip(actual.frame, &input);
    report[0] = input.len;
    report[1] = actual.frame.len;
    report[3] = profile.whole_block_passes;
    report[4] = profile.complete_length_passes;
    report[5] = profile.baseline_searches;
    report[6] = profile.max_parse_positions;
    report[7] = profile.max_match_length_considered;
    report[8] = profile.max_plan_price_evaluations;
    report[9] = profile.price_evaluations;
    report[12] = memory.peak_requested_bytes;
    var baseline = options;
    baseline.hq.?.parse_mode = .bounded;
    baseline.hq.?.match_lengths = .sampled;
    baseline.control_profile = null;
    baseline.memory_profile = null;
    const sampled = try vort.zstdEncodeNativeFrameWithOptionsAlloc(a, &input, baseline);
    defer a.free(sampled.frame);
    try require(actual.frame.len <= sampled.frame.len);
    try roundtrip(sampled.frame, &input);
    report[2] = sampled.frame.len;
    const cap = profile.max_plan_price_evaluations;
    const emitted = profile.emitted();
    var output: [1024]u8 = @splat(0xa5);
    for ([_]u64{ 0, cap - 1 }) |limit| {
        options.hq.?.max_price_evaluations = limit;
        if (vort.zstdEncodeNativeFrameIntoSlice(a, &input, options, &output)) |_| return error.ExpectedSearchRefusal else |err| try require(err == error.SearchLimitExceeded);
        try untouched(&output);
        try require(std.meta.eql(emitted, profile.emitted()));
        try require(memory.live_requested_bytes == 0);
    }
    options.hq.?.max_price_evaluations = cap;
    const exact = try vort.zstdEncodeNativeFrameWithOptionsAlloc(a, &input, options);
    defer a.free(exact.frame);
    try require(std.mem.eql(u8, actual.frame, exact.frame) and profile.max_plan_price_evaluations == cap and profile.price_evaluations > cap);
    try require(profile.effective_hq_max_price_evaluations == cap and memory.live_requested_bytes == 0);
    report[10] = profile.price_limit_refusals;
    report[11] = exact.frame.len;
    report[13] = profile.guarded_frames;
    report[14] = profile.baseline_selected_frames;
}

export fn zstdHqSearchWholeComplete() u32 {
    wholeComplete() catch return 101;
    return 0;
}

fn fullSpan() !void {
    const a = std.heap.page_allocator;
    const input = try a.alloc(u8, 128 * 1024);
    defer a.free(input);
    var random: u64 = 0x7c341abcd289;
    for (input) |*byte| {
        random = random *% 6364136223846793005 +% 1442695040888963407;
        byte.* = @truncate(random >> 32);
    }
    var profile: vort.ZstdEncoderControlProfile = .{};
    var memory: vort.ZstdEncodeMemoryProfile = .{};
    const options: vort.ZstdNativeFrameOptions = .{
        .strategy = .btopt,
        .hq = .{ .parse_mode = .whole_block, .match_lengths = .sampled, .min_match = 7, .nice_len = 32, .search_depth = 8, .max_working_memory = heap_cap },
        .content_checksum = true,
        .control_profile = &profile,
        .memory_profile = &memory,
        .max_total_working_memory = heap_cap,
    };
    const encoded = try vort.zstdEncodeNativeFrameWithOptionsAlloc(a, input, options);
    defer a.free(encoded.frame);
    try require(profile.max_parse_positions == input.len and profile.whole_block_passes > 0 and profile.sampled_length_passes > 0);
    try require(profile.baseline_searches > 0 and profile.bounded_passes > 0 and profile.complete_length_passes == 0);
    try require(profile.effective_hq_parse_mode == .whole_block and profile.effective_hq_match_lengths == .sampled and profile.effective_hq_min_match == 7);
    try require(memory.live_requested_bytes == 0 and memory.peak_requested_bytes <= heap_cap);
    try roundtrip(encoded.frame, input);
    report[16] = input.len;
    report[17] = profile.max_parse_positions;
    report[18] = encoded.frame.len;
    report[19] = profile.whole_block_passes;
    report[20] = profile.bounded_passes;
    report[21] = profile.complete_length_passes;
    report[22] = profile.peak_working_memory;
    report[23] = memory.peak_requested_bytes;
    report[24] = heap_cap;
}

export fn zstdHqSearchFullSpan() u32 {
    fullSpan() catch return 201;
    return 0;
}

fn drain(encoder: *vort.ZstdNativeIncrementalFrameEncoder, wire: *std.ArrayList(u8), flushing: bool) !void {
    var output: [257]u8 = undefined;
    for (0..512) |_| {
        const step = try encoder.step("", &output);
        try wire.appendSlice(std.heap.page_allocator, output[0..step.progress.output_written]);
        if (step.status == .done or (flushing and step.status == .need_input)) return;
        try require(step.progress.output_written != 0);
    }
    return error.DrainDidNotComplete;
}

fn incrementalRetry() !void {
    const a = std.heap.page_allocator;
    var input: [10 * 1024]u8 = undefined;
    fillText(&input);
    var profile: vort.ZstdEncoderControlProfile = .{};
    var memory: vort.ZstdEncodeMemoryProfile = .{};
    const options: vort.ZstdNativeFrameOptions = .{
        .strategy = .btopt,
        .hq = .{ .parse_mode = .whole_block, .match_lengths = .sampled, .search_depth = 8, .nice_len = 32, .max_price_evaluations = 0, .max_working_memory = heap_cap },
        .block_size_max = 8192,
        .content_checksum = true,
        .control_profile = &profile,
        .memory_profile = &memory,
        .max_total_working_memory = heap_cap,
    };
    var encoder = try vort.ZstdNativeIncrementalFrameEncoder.initExactSize(a, options, input.len);
    var live = true;
    defer if (live) encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    var output: [64]u8 = undefined;
    const header = try encoder.step("", &output);
    try wire.appendSlice(a, output[0..header.progress.output_written]);
    const accepted = try encoder.step(input[0..8192], &.{});
    try require(accepted.progress.input_read == 8192 and accepted.progress.output_written == 0);
    encoder.flush();
    const before_flush = encoder.snapshot();
    @memset(&output, 0xa5);
    if (encoder.step("", &output)) |_| return error.ExpectedFlushRefusal else |err| try require(err == error.SearchLimitExceeded);
    try untouched(&output);
    try require(std.meta.eql(before_flush, encoder.snapshot()) and encoder.block.items.len == 8192 and encoder.pending.items.len == 0);
    encoder.options.hq.?.max_price_evaluations = null;
    try drain(&encoder, &wire, true);
    const tail = try encoder.step(input[8192..], &.{});
    try require(tail.progress.input_read == input.len - 8192);
    encoder.options.hq.?.max_price_evaluations = 0;
    encoder.finish();
    const before_finish = encoder.snapshot();
    const emitted = profile.emitted();
    @memset(&output, 0xa5);
    if (encoder.step("", &output)) |_| return error.ExpectedFinishRefusal else |err| try require(err == error.SearchLimitExceeded);
    try untouched(&output);
    try require(std.meta.eql(before_finish, encoder.snapshot()) and std.meta.eql(emitted, profile.emitted()));
    encoder.options.hq.?.max_price_evaluations = null;
    try drain(&encoder, &wire, false);
    try require(encoder.snapshot().done and encoder.snapshot().frame_input == input.len);
    try require(profile.max_parse_positions == 8192 and profile.whole_block_passes > 0 and profile.baseline_searches > 0 and profile.bounded_passes > 0);
    try require(profile.guarded_frames == 0 and profile.price_limit_refusals >= 2 and profile.max_plan_price_evaluations > 0);
    try roundtrip(wire.items, &input);
    report[26] = input.len;
    report[27] = wire.items.len;
    report[28] = profile.max_parse_positions;
    report[29] = profile.whole_block_passes;
    report[30] = profile.baseline_searches;
    report[31] = profile.price_limit_refusals;
    report[32] = profile.max_plan_price_evaluations;
    report[33] = memory.peak_requested_bytes;
    report[34] = profile.guarded_frames;
    encoder.deinit();
    live = false;
    try require(memory.live_requested_bytes == 0);
    report[35] = memory.live_requested_bytes;
}

export fn zstdHqSearchIncrementalRetry() u32 {
    incrementalRetry() catch return 301;
    return 0;
}

const RefusingAllocator = struct {
    attempts: usize = 0,
    fn allocator(self: *@This()) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn alloc(raw: *anyopaque, _: usize, _: std.mem.Alignment, _: usize) ?[*]u8 {
        const self: *@This() = @ptrCast(@alignCast(raw));
        self.attempts += 1;
        return null;
    }
    fn resize(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) bool {
        return false;
    }
    fn remap(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) ?[*]u8 {
        return null;
    }
    fn free(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize) void {
        unreachable;
    }
};

fn unsupported() !void {
    var refusing: RefusingAllocator = .{};
    var output: [64]u8 = @splat(0xa5);
    for ([_]vort.ZstdHqOptions{ .{ .parse_mode = .whole_block }, .{ .match_lengths = .complete }, .{ .max_price_evaluations = 0 } }) |hq| {
        const options: vort.ZstdNativeFrameOptions = .{ .strategy = .lazy2, .hq = hq };
        if (vort.zstdEncodeNativeFrameWithOptionsAlloc(refusing.allocator(), text, options)) |_| return error.ExpectedOptionRefusal else |err| try require(err == error.InvalidBlockPlan);
        if (vort.zstdEncodeNativeFrameIntoSlice(refusing.allocator(), text, options, &output)) |_| return error.ExpectedOptionRefusal else |err| try require(err == error.InvalidBlockPlan);
        try untouched(&output);
    }
    try require(refusing.attempts == 0);
    report[38] = refusing.attempts;
    report[39] = 6;
    report[40] = @bitSizeOf(usize);
    report[41] = @bitSizeOf(@typeInfo(@FieldType(vort.ZstdHqOptions, "max_price_evaluations")).optional.child);
}

export fn zstdHqSearchUnsupported() u32 {
    unsupported() catch return 401;
    return 0;
}
