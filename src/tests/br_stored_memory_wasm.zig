//! Actual small public stored Brotli resource operations for wasm32-wasi.
const std = @import("std");
const vort = @import("vort");
const cap: usize = 16 * 1024 * 1024;
const metadata = "stored Wasm metadata";
var values: [48]u64 = @splat(0);

fn require(condition: bool) error{StoredMemoryConsumerMismatch}!void {
    if (!condition) return error.StoredMemoryConsumerMismatch;
}
fn untouched(bytes: []const u8) !void {
    for (bytes) |byte| try require(byte == 0xa5);
}
fn payload(bytes: []u8) void {
    for (bytes, 0..) |*byte, i| byte.* = @truncate(i *% 29 + 7);
}
fn decode(wire: []const u8, expected: []const u8, large: bool, expected_metadata: []const u8) !void {
    var history: [64]u8 = undefined;
    var captured: [384]u8 = undefined;
    var decoder = vort.BrotliIncrementalCopyStreamDecoder.initWithOptions(&history, .{
        .expected_output_len = expected.len,
        .decode = .{ .allow_large_window = large },
        .metadata_output = &captured,
    });
    var output: [256]u8 = undefined;
    var read: usize = 0;
    var written: usize = 0;
    for (0..2048) |_| {
        const result = try decoder.step(wire[read..@min(wire.len, read + 3)], output[written..@min(output.len, written + 5)]);
        read += result.progress.input_read;
        written += result.progress.output_written;
        if (result.status == .done) break;
        try require(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
    try decoder.finish();
    try require(read == wire.len and std.mem.eql(u8, expected, output[0..written]));
    try require(decoder.snapshot().metadata_total == expected_metadata.len and std.mem.eql(u8, expected_metadata, captured[0..expected_metadata.len]));
}

export fn brStoredMemoryReport(index: u32) u64 {
    return if (index < values.len) values[index] else 0;
}

fn freeInto() !void {
    var input: [128]u8 = undefined;
    payload(&input);
    var output: [256]u8 = undefined;
    const chunks = [_][]const u8{ input[0..57], "", input[57..] };
    for ([_]bool{ false, true }, 0..) |large, format| {
        var profile: vort.BrotliEncodeMemoryProfile = .{};
        const options: vort.BrotliStoredStreamOptions = .{ .large_window = large, .window_bits = if (large) 30 else 16, .metadata = metadata, .max_total_working_memory = 0, .memory_profile = &profile };
        for ([_]bool{ false, true }, 0..) |chunked, kind| {
            @memset(&output, 0xa5);
            const written = if (chunked)
                try vort.brEncodeStoredStreamChunksWithOptionsInto(&chunks, &output, options)
            else
                try vort.brEncodeStoredStreamWithOptionsInto(&input, &output, options);
            try decode(output[0..written], &input, large, metadata);
            try untouched(output[written..]);
            try require(profile.available and profile.limit == 0 and profile.peak_requested_bytes == 0 and profile.live_requested_bytes == 0);
            values[format * 2 + kind] = written;
        }
    }
    values[4] = input.len;
    values[5] = metadata.len;
    values[6] = 0;
}

export fn brStoredMemoryFreeInto() u32 {
    freeInto() catch return 101;
    return 0;
}

fn owned() !void {
    const a = std.heap.page_allocator;
    var input: [128]u8 = undefined;
    payload(&input);
    var profile: vort.BrotliEncodeMemoryProfile = .{};
    var options: vort.BrotliStoredStreamOptions = .{ .large_window = true, .window_bits = 30, .metadata = metadata, .memory_profile = &profile, .max_total_working_memory = cap };
    const first = try vort.brEncodeStoredStreamWithOptionsAlloc(a, &input, options);
    defer a.free(first);
    try decode(first, &input, true, metadata);
    const peak = profile.peak_requested_bytes;
    try require(peak >= first.len and peak <= cap and profile.live_requested_bytes == 0);
    profile.reset();
    options.max_total_working_memory = peak;
    const exact = try vort.brEncodeStoredStreamWithOptionsAlloc(a, &input, options);
    defer a.free(exact);
    try require(std.mem.eql(u8, first, exact) and profile.peak_requested_bytes == peak and profile.live_requested_bytes == 0);
    for ([_]usize{ 0, peak - 1 }) |limit| {
        profile.reset();
        options.max_total_working_memory = limit;
        if (vort.brEncodeStoredStreamWithOptionsAlloc(a, &input, options)) |_| return error.ExpectedOwnedQuotaRefusal else |err| try require(err == error.WorkingMemoryLimitExceeded);
        try require(profile.available and profile.live_requested_bytes == 0 and profile.peak_requested_bytes <= limit);
    }
    values[8] = peak;
    values[9] = first.len;
    values[10] = exact.len;
    values[11] = profile.live_requested_bytes;
    values[12] = 2;
}

export fn brStoredMemoryOwned() u32 {
    owned() catch return 201;
    return 0;
}

fn reusable() !void {
    const a = std.heap.page_allocator;
    var input: [128]u8 = undefined;
    payload(&input);
    var encoder = vort.BrotliStoredStreamEncoder.init(a);
    var live = true;
    defer if (live) encoder.deinit();
    const warm = try encoder.encodeScratch(&input);
    var old: [256]u8 = undefined;
    @memcpy(old[0..warm.len], warm);
    const old_len = warm.len;
    try encoder.scratch.ensureTotalCapacityPrecise(a, 1024);
    const retained = encoder.scratch.capacity;
    var profile: vort.BrotliEncodeMemoryProfile = .{};
    var options: vort.BrotliStoredStreamOptions = .{ .memory_profile = &profile, .max_total_working_memory = cap };
    const activated = try encoder.encodeScratchWithOptions(&input, options);
    try require(std.mem.eql(u8, old[0..old_len], activated));
    const snapshot = encoder.memorySnapshot();
    try require(snapshot.available and snapshot.live_requested_bytes == retained + snapshot.control_bytes and profile.live_requested_bytes == snapshot.live_requested_bytes);
    const pointer = encoder.scratch.items.ptr;
    options.max_total_working_memory = snapshot.live_requested_bytes - 1;
    if (encoder.encodeScratchWithOptions("replacement", options)) |_| return error.ExpectedRetainedQuotaRefusal else |err| try require(err == error.WorkingMemoryLimitExceeded);
    try require(encoder.scratch.items.ptr == pointer and encoder.scratch.capacity == retained and std.mem.eql(u8, old[0..old_len], encoder.scratch.items));
    options.max_total_working_memory = cap;
    // The source is the existing encoded wire, and both borrows overlap the
    // actual destination write span. Spare capacity outside that span does
    // not require a snapshot when the allocation is retained.
    options.metadata = encoder.scratch.items[0..metadata.len];
    options.max_total_working_memory = snapshot.live_requested_bytes;
    if (encoder.encodeScratchWithOptions(encoder.scratch.items, options)) |_| return error.ExpectedAliasQuotaRefusal else |err| try require(err == error.WorkingMemoryLimitExceeded);
    try require(encoder.scratch.items.ptr == pointer and std.mem.eql(u8, old[0..old_len], encoder.scratch.items));
    options.max_total_working_memory = cap;
    const aliased = try encoder.encodeScratchWithOptions(encoder.scratch.items, options);
    try decode(aliased, old[0..old_len], false, old[0..metadata.len]);
    const alias_peak = profile.peak_requested_bytes;
    // Storage remains alive, but sentinel fields model the end of this call's
    // borrowed profile lifetime. Later calls and destruction must not touch it.
    profile.live_requested_bytes = 777;
    profile.peak_requested_bytes = 1234;
    profile.limit = 3;
    const detached = profile;
    _ = try encoder.encodeScratchWithOptions("next", .{ .max_total_working_memory = cap });
    try require(std.meta.eql(detached, profile));
    var second: vort.BrotliEncodeMemoryProfile = .{};
    _ = try encoder.encodeScratchWithOptions("third", .{ .max_total_working_memory = cap, .memory_profile = &second });
    second.live_requested_bytes = 888;
    second.peak_requested_bytes = 2345;
    const detached_second = second;
    values[16] = retained;
    values[17] = snapshot.control_bytes;
    values[18] = snapshot.live_requested_bytes;
    values[19] = alias_peak;
    values[20] = encoder.memorySnapshot().live_requested_bytes;
    values[21] = 2;
    encoder.deinit();
    live = false;
    try require(std.meta.eql(detached, profile) and std.meta.eql(detached_second, second));
    values[22] = 1; // Call-scoped borrowed profiles are detached before deinit.
}

export fn brStoredMemoryReusable() u32 {
    reusable() catch return 301;
    return 0;
}

fn drain(encoder: *vort.BrotliIncrementalStoredStreamEncoder, wire: *std.ArrayList(u8), flush: bool) !void {
    var output: [17]u8 = undefined;
    for (0..256) |_| {
        const result = try encoder.step("", &output);
        try wire.appendSlice(std.heap.page_allocator, output[0..result.progress.output_written]);
        if (result.status == .done or (flush and result.status == .need_input)) return;
        try require(result.progress.output_written != 0);
    }
    return error.DrainNotComplete;
}

fn incremental() !void {
    const a = std.heap.page_allocator;
    var input: [128]u8 = undefined;
    payload(&input);
    var inserted_metadata: [256]u8 = undefined;
    payload(&inserted_metadata);
    var all_metadata: [metadata.len + inserted_metadata.len]u8 = undefined;
    @memcpy(all_metadata[0..metadata.len], metadata);
    @memcpy(all_metadata[metadata.len..], &inserted_metadata);
    var profile: vort.BrotliEncodeMemoryProfile = .{};
    var options: vort.BrotliIncrementalStoredStreamEncoder.Options = .{ .block_len = 128, .stream = .{ .large_window = true, .window_bits = 25, .metadata = metadata, .max_total_working_memory = 0, .memory_profile = &profile } };
    var encoder = vort.BrotliIncrementalStoredStreamEncoder.initWithOptions(a, options);
    var live = true;
    defer if (live) encoder.deinit();
    var output: [64]u8 = @splat(0xa5);
    const empty = encoder.snapshot();
    if (encoder.step(&input, &output)) |_| return error.ExpectedPrefixQuotaRefusal else |err| try require(err == error.WorkingMemoryLimitExceeded);
    try untouched(&output);
    try require(std.meta.eql(empty, encoder.snapshot()) and profile.available and profile.live_requested_bytes == 0);
    encoder.options.stream.max_total_working_memory = cap;
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    const prefix = try encoder.step("", &output);
    try wire.appendSlice(a, output[0..prefix.progress.output_written]);
    const accepted = try encoder.step(input[0..64], &.{});
    try require(accepted.progress.input_read == 64 and accepted.progress.output_written == 0);
    try encoder.writeMetadata(&inserted_metadata);
    encoder.options.stream.max_total_working_memory = encoder.memorySnapshot().live_requested_bytes;
    const before = encoder.snapshot();
    @memset(&output, 0xa5);
    if (encoder.step("", &output)) |_| return error.ExpectedMetadataQuotaRefusal else |err| try require(err == error.WorkingMemoryLimitExceeded);
    try untouched(&output);
    try require(encoder.snapshot().stream_input == before.stream_input and encoder.snapshot().stream_output == before.stream_output and encoder.snapshot().metadata_pending);
    encoder.options.stream.max_total_working_memory = cap;
    try drain(&encoder, &wire, true);
    const tail = try encoder.step(input[64..], &output);
    try require(tail.progress.input_read == 64);
    try wire.appendSlice(a, output[0..tail.progress.output_written]);
    encoder.flush();
    try drain(&encoder, &wire, true);
    try encoder.finish();
    try drain(&encoder, &wire, false);
    try decode(wire.items, &input, true, &all_metadata);
    const complete = encoder.snapshot();
    const occupied = encoder.memorySnapshot().live_requested_bytes;
    options.stream.max_total_working_memory = occupied - 1;
    if (encoder.nextStream(options)) |_| return error.ExpectedNextStreamQuotaRefusal else |err| try require(err == error.WorkingMemoryLimitExceeded);
    try require(std.meta.eql(complete, encoder.snapshot()));
    options.stream.max_total_working_memory = cap;
    try encoder.nextStream(options);
    var second: std.ArrayList(u8) = .empty;
    defer second.deinit(a);
    const next = try encoder.step("tiny", &output);
    try require(next.progress.input_read == 4);
    try second.appendSlice(a, output[0..next.progress.output_written]);
    try encoder.finish();
    try drain(&encoder, &second, false);
    try decode(second.items, "tiny", true, metadata);
    values[26] = input.len;
    values[27] = wire.items.len;
    values[28] = complete.stream_input;
    values[29] = complete.stream_count;
    values[30] = occupied;
    values[31] = profile.peak_requested_bytes;
    values[32] = encoder.snapshot().input_read;
    values[33] = encoder.snapshot().stream_count;
    values[34] = all_metadata.len;
    values[35] = @bitSizeOf(@FieldType(vort.BrotliIncrementalStoredStreamEncoder.Snapshot, "input_read"));
    encoder.deinit();
    live = false;
    try require(profile.live_requested_bytes == 0 and profile.peak_requested_bytes <= cap);
    values[36] = profile.live_requested_bytes;
}

export fn brStoredMemoryIncremental() u32 {
    incremental() catch return 401;
    return 0;
}
